import type { SupabaseRestEnv } from "../document_rag.ts";
import {
  embedNormalizedQuery,
  type QueryEmbeddingConfig,
} from "./query_embedding.ts";
import { normalizeRagQuery, queryLanguages } from "./query_normalizer.ts";
import {
  fuseAndRerank,
  hasOwningDocumentCue,
  rerankerVersion,
} from "./retrieval_reranker.ts";
import type {
  NormalizedRagQuery,
  RetrievalCandidate,
  RetrievalResult,
} from "./types.ts";

export interface RetrievalPipelineConfig {
  supabase: SupabaseRestEnv;
  embedding: QueryEmbeddingConfig | null;
  corpusId?: string;
  candidateLimit?: number;
  rpcName?:
    | "search_document_chunks_hybrid"
    | "search_document_chunks_hybrid_v2"
    | "search_document_chunks_hybrid_v3";
}

export async function retrieveFitLogDocuments(
  config: RetrievalPipelineConfig,
  rawQuery: string,
  fetchImpl: typeof fetch = fetch,
): Promise<RetrievalResult> {
  const totalStartedAt = Date.now();
  const normalizationStartedAt = Date.now();
  const query = normalizeRagQuery(rawQuery);
  const normalizationMs = Date.now() - normalizationStartedAt;
  const issues: RetrievalResult["debug"]["issues"] = [];
  let embeddingMs: number | null = null;
  let embeddingStatus: RetrievalResult["debug"]["latency"]["embedding_status"] =
    "not_configured";
  let lexicalCandidateRpcMs: number | null = null;
  let hybridRpcMs = 0;
  const embeddingInput = query.query_variants.map((item) => item.trim())
    .filter(Boolean).slice(0, 6).join("\n");
  let rows: RetrievalCandidate[] = [];

  const embeddingPromise = timedEmbedding(config, query, fetchImpl);
  let lexicalCandidateIds: string[] | undefined;
  let lexicalIssue = false;
  if (config.rpcName === "search_document_chunks_hybrid_v3") {
    const [embedded, lexical] = await Promise.all([
      embeddingPromise,
      fetchLexicalCandidateIds(config, query, fetchImpl),
    ]);
    embeddingMs = embedded.latencyMs;
    lexicalCandidateRpcMs = lexical.latencyMs;
    lexicalCandidateIds = lexical.ids;
    lexicalIssue = lexical.issue;
    embeddingStatus = embedded.status;
    if (embedded.issue !== null) issues.push(embedded.issue);
  } else {
    const embedded = await embeddingPromise;
    embeddingMs = embedded.latencyMs;
    embeddingStatus = embedded.status;
    if (embedded.issue !== null) issues.push(embedded.issue);
  }
  const embedded = await embeddingPromise;
  const hybridConfig = lexicalIssue
    ? { ...config, rpcName: "search_document_chunks_hybrid_v2" as const }
    : config;
  if (lexicalIssue) issues.push("hybrid_rpc_unavailable");
  const hybrid = await fetchRetrievalRows({
    config: hybridConfig,
    query,
    vector: embedded.vector,
    lexicalCandidateIds,
    limit: candidateLimit(config),
    fetchImpl,
  });
  hybridRpcMs = hybrid.latencyMs;
  if (hybrid.issue) issues.push("hybrid_rpc_unavailable");
  rows = hybrid.rows;
  const rerankerStartedAt = Date.now();
  const hasDocumentIntent = query.canonical_concepts.length > 0 ||
    query.exercise_keys.length > 0 || hasOwningDocumentCue(query) ||
    /fitlog|本应用|本软件|the app|产品规则/i.test(query.normalized_query);
  const eligible = rows.filter((row) => {
    const meetsBranchThreshold = row.lexical_score >= 0.05 ||
      (row.vector_score ?? 0) >= 0.55;
    if (!meetsBranchThreshold) return false;
    return hasDocumentIntent || row.exact_score >= 0.8;
  });
  const reranked = fuseAndRerank(eligible, query);
  const rerankerMs = Date.now() - rerankerStartedAt;
  if (reranked.degraded) issues.push("reranker_degraded");
  return {
    query,
    candidates: reranked.candidates,
    debug: {
      pipeline_version: "rag_foundation_v1",
      reranker_version: rerankerVersion,
      branch_hits: {
        exact: rows.filter((row) => row.exact_score > 0).length,
        terms: rows.filter((row) => row.term_score > 0).length,
        full_text: rows.filter((row) => row.full_text_score > 0).length,
        trigram: rows.filter((row) => row.trigram_score > 0).length,
        lexical: rows.filter((row) => row.lexical_rank !== null).length,
        vector: rows.filter((row) => row.vector_rank !== null).length,
      },
      candidates_before_dedupe: rows.length,
      candidates_after_dedupe:
        new Set(rows.map((row) => `${row.doc_path}:${row.section_id}`)).size,
      final_hits: reranked.candidates.length,
      elimination_reasons: {
        below_minimum_score: rows.length - eligible.length,
      },
      issues: [...new Set(issues)],
      latency: {
        total_ms: Date.now() - totalStartedAt,
        normalization_ms: normalizationMs,
        embedding_ms: embeddingMs,
        lexical_candidate_rpc_ms: lexicalCandidateRpcMs,
        hybrid_rpc_ms: hybridRpcMs,
        reranker_ms: rerankerMs,
        embedding_status: embeddingStatus,
        embedding_input_chars: embeddingInput.length,
        query_variant_count: query.query_variants.slice(0, 6).length,
      },
    },
  };
}

async function fetchRetrievalRows(params: {
  config: RetrievalPipelineConfig;
  query: NormalizedRagQuery;
  vector: number[] | null;
  lexicalCandidateIds?: string[];
  limit: number;
  fetchImpl: typeof fetch;
}): Promise<{
  rows: RetrievalCandidate[];
  latencyMs: number;
  issue: boolean;
}> {
  const startedAt = Date.now();
  const rpcBody: Record<string, unknown> = {
    input_corpus_id: params.config.corpusId ?? "fitlog_user_stable_docs",
    input_languages: queryLanguages(params.query),
    input_query: params.query.normalized_query,
    input_query_terms: queryTerms(params.query),
    input_embedding: params.vector === null
      ? null
      : `[${params.vector.join(",")}]`,
    input_limit: params.limit,
    input_embedding_model: params.vector === null
      ? null
      : params.config.embedding?.model ?? null,
  };
  if (params.config.rpcName === "search_document_chunks_hybrid_v3") {
    rpcBody.input_lexical_candidate_ids = params.lexicalCandidateIds ?? [];
  }
  const response = await params.fetchImpl(
    `${params.config.supabase.supabaseUrl}/rest/v1/rpc/${
      params.config.rpcName ?? "search_document_chunks_hybrid"
    }`,
    {
      method: "POST",
      headers: {
        apikey: params.config.supabase.supabaseServiceRoleKey,
        authorization:
          `Bearer ${params.config.supabase.supabaseServiceRoleKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(rpcBody),
    },
  );
  if (!response.ok) {
    return { rows: [], latencyMs: Date.now() - startedAt, issue: true };
  }
  const body = await response.json();
  if (!Array.isArray(body)) {
    return { rows: [], latencyMs: Date.now() - startedAt, issue: true };
  }
  const rows = body.map(candidateFromRow).filter((
    item,
  ): item is RetrievalCandidate => item !== null);
  return { rows, latencyMs: Date.now() - startedAt, issue: false };
}

async function timedEmbedding(
  config: RetrievalPipelineConfig,
  query: NormalizedRagQuery,
  fetchImpl: typeof fetch,
): Promise<{
  vector: number[] | null;
  issue: "embedding_unavailable" | null;
  status: "not_configured" | "completed" | "unavailable";
  latencyMs: number | null;
}> {
  if (config.embedding === null) {
    return {
      vector: null,
      issue: "embedding_unavailable",
      status: "not_configured",
      latencyMs: null,
    };
  }
  const startedAt = Date.now();
  const result = await embedNormalizedQuery(
    config.embedding,
    query.query_variants,
    fetchImpl,
  );
  return {
    ...result,
    status: result.issue === null && result.vector !== null
      ? "completed"
      : "unavailable",
    latencyMs: Date.now() - startedAt,
  };
}

async function fetchLexicalCandidateIds(
  config: RetrievalPipelineConfig,
  query: NormalizedRagQuery,
  fetchImpl: typeof fetch,
): Promise<{ ids: string[]; latencyMs: number; issue: boolean }> {
  const startedAt = Date.now();
  const response = await fetchImpl(
    `${config.supabase.supabaseUrl}/rest/v1/rpc/search_document_chunk_lexical_candidates_v1`,
    {
      method: "POST",
      headers: {
        apikey: config.supabase.supabaseServiceRoleKey,
        authorization: `Bearer ${config.supabase.supabaseServiceRoleKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        input_corpus_id: config.corpusId ?? "fitlog_user_stable_docs",
        input_languages: queryLanguages(query),
        input_query: query.normalized_query,
        input_query_terms: queryTerms(query),
      }),
    },
  );
  if (!response.ok) {
    return { ids: [], latencyMs: Date.now() - startedAt, issue: true };
  }
  const body = await response.json();
  if (!Array.isArray(body)) {
    return { ids: [], latencyMs: Date.now() - startedAt, issue: true };
  }
  const ids = body.flatMap((row) => {
    if (!isRecord(row) || typeof row.id !== "string") return [];
    return uuidPattern.test(row.id) ? [row.id] : [];
  });
  return {
    ids: [...new Set(ids)],
    latencyMs: Date.now() - startedAt,
    issue: false,
  };
}

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function candidateLimit(config: RetrievalPipelineConfig): number {
  return Math.min(
    Math.max(Math.trunc(config.candidateLimit ?? 60), 12),
    60,
  );
}

function queryTerms(query: NormalizedRagQuery): string[] {
  return [...new Set([...query.tokens, ...query.query_variants])].slice(0, 24);
}

function candidateFromRow(value: unknown): RetrievalCandidate | null {
  if (!isRecord(value)) return null;
  const language = value.language === "zh" || value.language === "en"
    ? value.language
    : null;
  const required = [
    "id",
    "build_id",
    "doc_path",
    "heading",
    "section_id",
    "content",
    "authority",
    "status",
  ];
  if (
    language === null ||
    required.some((field) =>
      typeof value[field] !== "string" || String(value[field]).trim() === ""
    )
  ) return null;
  return {
    id: String(value.id),
    build_id: String(value.build_id),
    language,
    doc_path: String(value.doc_path),
    heading: String(value.heading),
    heading_path: stringArray(value.heading_path),
    section_id: String(value.section_id),
    chunk_index: positiveInteger(value.chunk_index),
    chunk_count: positiveInteger(value.chunk_count),
    content: String(value.content),
    context_prefix: typeof value.context_prefix === "string"
      ? value.context_prefix
      : "",
    tags: stringArray(value.tags),
    status: String(value.status),
    authority: String(value.authority),
    lexical_score: finiteNumber(value.lexical_score, 0),
    exact_score: finiteNumber(value.exact_score, 0),
    term_score: finiteNumber(value.term_score, 0),
    full_text_score: finiteNumber(value.full_text_score, 0),
    trigram_score: finiteNumber(value.trigram_score, 0),
    vector_score: nullableFiniteNumber(value.vector_score),
    lexical_rank: nullablePositiveInteger(value.lexical_rank),
    vector_rank: nullablePositiveInteger(value.vector_rank),
    matched_terms: stringArray(value.matched_terms),
    matched_fields: stringArray(value.matched_fields),
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function stringArray(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string")
    : [];
}

function finiteNumber(value: unknown, fallback: number): number {
  const number = typeof value === "number" ? value : Number(value);
  return Number.isFinite(number) ? number : fallback;
}

function nullableFiniteNumber(value: unknown): number | null {
  return value === null || value === undefined ? null : finiteNumber(value, 0);
}

function positiveInteger(value: unknown): number {
  return Math.max(1, Math.trunc(finiteNumber(value, 1)));
}

function nullablePositiveInteger(value: unknown): number | null {
  return value === null || value === undefined ? null : positiveInteger(value);
}
