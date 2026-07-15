import type { GatewayRequest } from "./contracts.ts";
import type {
  Phase5DocumentSource,
  Phase5RetrievalDebug,
} from "./phase5_types.ts";
import type { PipelineRuntimeConfig } from "./pipeline_config.ts";
import type { QueryEmbeddingConfig } from "./rag/query_embedding.ts";
import {
  type RetrievalRewritePlanner,
  retrieveWithSingleRetry,
} from "./rag/retrieval_retry.ts";

export interface SupabaseRestEnv {
  supabaseUrl: string;
  supabaseServiceRoleKey: string;
  pipeline?: PipelineRuntimeConfig;
  documentEmbedding?: QueryEmbeddingConfig | null;
  retrievalRewritePlanner?: RetrievalRewritePlanner;
}

export interface DocumentSearchOutcome {
  sources: Phase5DocumentSource[];
  debug: Phase5RetrievalDebug | null;
}

export async function searchDocumentSources(
  env: SupabaseRestEnv,
  request: GatewayRequest,
  limit = 6,
): Promise<Phase5DocumentSource[]> {
  return (await searchDocumentContext(env, request, limit)).sources;
}

export async function searchDocumentContext(
  env: SupabaseRestEnv,
  request: GatewayRequest,
  limit = 6,
): Promise<DocumentSearchOutcome> {
  if (env.pipeline?.contextPipelineVersion === "rag_foundation_v1") {
    return searchHybridDocumentContext(env, request, limit);
  }
  const response = await fetch(
    `${env.supabaseUrl}/rest/v1/rpc/search_document_chunks`,
    {
      method: "POST",
      headers: serviceHeaders(env),
      body: JSON.stringify({
        input_language: documentLanguage(request),
        input_query: request.messageText,
        input_limit: limit,
      }),
    },
  );
  if (!response.ok) {
    return { sources: [], debug: null };
  }
  const rows = await response.json();
  if (!Array.isArray(rows)) {
    return { sources: [], debug: null };
  }
  return {
    sources: rows.map(documentSourceFromRow).filter((item) => item !== null),
    debug: null,
  };
}

async function searchHybridDocumentContext(
  env: SupabaseRestEnv,
  request: GatewayRequest,
  limit: number,
): Promise<DocumentSearchOutcome> {
  const outcome = await retrieveWithSingleRetry({
    config: {
      supabase: env,
      embedding: env.documentEmbedding ?? null,
      corpusId: "fitlog_user_stable_docs",
      rpcName: "search_document_chunks_hybrid_v3",
      candidateLimit: 30,
    },
    rawQuery: request.messageText,
    requiredDimensions: ["document_context"],
    retryEnabled: env.pipeline?.documentRagRetryEnabled === true &&
      env.retrievalRewritePlanner !== undefined,
    rewritePlanner: env.retrievalRewritePlanner ??
      (async () => ({ action: "stop" })),
  });
  const attempt = outcome.attempts;
  const sources = outcome.result.candidates.slice(
    0,
    Math.min(Math.max(limit, 1), 12),
  )
    .map((candidate): Phase5DocumentSource => ({
      doc_path: candidate.doc_path,
      heading: candidate.heading,
      heading_path: candidate.heading_path.length === 0
        ? [candidate.heading]
        : candidate.heading_path,
      section_id: candidate.section_id,
      chunk_index: candidate.chunk_index,
      chunk_count: candidate.chunk_count,
      status: candidate.status,
      score: candidate.rerank_score ?? candidate.fused_score ??
        candidate.lexical_score,
      context_prefix: candidate.context_prefix,
      context_note: null,
      excerpt: candidate.content.length > 900
        ? `${candidate.content.slice(0, 900)}...`
        : candidate.content,
      authority: candidate.authority,
      retrieval_attempt: attempt,
      coverage_status: outcome.coverage.status,
    }));
  return {
    sources,
    debug: {
      pipeline_version: "rag_foundation_v1",
      query_language_profile: outcome.result.query.language_profile.value,
      canonical_concept_ids: outcome.result.query.canonical_concepts,
      corpus_id: "fitlog_user_stable_docs",
      corpus_build_id: outcome.result.candidates[0]?.build_id ?? null,
      embedding_model: env.documentEmbedding?.model ?? null,
      reranker_version: outcome.result.debug.reranker_version,
      branch_hits: outcome.result.debug.branch_hits,
      final_hit_count: sources.length,
      first_coverage_status: outcome.first_coverage.status,
      first_missing_dimensions: outcome.first_coverage.missing_dimensions,
      coverage_status: outcome.coverage.status,
      missing_dimensions: outcome.coverage.missing_dimensions,
      retry_reason: outcome.retry_reason,
      retry_count: outcome.attempts === 2 ? 1 : 0,
      retry_action: outcome.retry_action,
      retry_query_changed: outcome.retry_query_changed,
      retry_gain: outcome.retry_gain,
      issue_codes: [
        ...outcome.result.debug.issues,
        ...(outcome.issue === null ? [] : [outcome.issue]),
      ],
      latency_breakdown: outcome.latency,
    },
  };
}

export function documentLanguage(request: GatewayRequest): "zh" | "en" {
  const text = request.messageText;
  const cjk = [...text].filter((char) => {
    const code = char.codePointAt(0) ?? 0;
    return (code >= 0x4e00 && code <= 0x9fff) ||
      (code >= 0x3400 && code <= 0x4dbf);
  }).length;
  const asciiLetters = [...text].filter((char) => /[A-Za-z]/.test(char)).length;
  if (cjk > 0 && cjk >= asciiLetters * 0.2) {
    return "zh";
  }
  return request.language;
}

function documentSourceFromRow(row: unknown): Phase5DocumentSource | null {
  if (typeof row !== "object" || row === null || Array.isArray(row)) {
    return null;
  }
  const map = row as Record<string, unknown>;
  const docPath = stringField(map, "doc_path");
  const heading = stringField(map, "heading");
  const headingPath = stringArrayField(map, "heading_path");
  const sectionId = stringField(map, "section_id");
  const status = stringField(map, "status") || "implemented";
  const content = stringField(map, "content");
  const contextPrefix = stringField(map, "context_prefix");
  const contextNote = nullableStringField(map, "context_note");
  const chunkIndex = integerField(map, "chunk_index", 1);
  const chunkCount = Math.max(integerField(map, "chunk_count", 1), chunkIndex);
  if (docPath === "" || heading === "" || sectionId === "" || content === "") {
    return null;
  }
  return {
    doc_path: docPath,
    heading,
    heading_path: headingPath.length === 0 ? [heading] : headingPath,
    section_id: sectionId,
    chunk_index: chunkIndex,
    chunk_count: chunkCount,
    status,
    score: numberField(map, "score"),
    context_prefix: contextPrefix,
    context_note: contextNote,
    excerpt: content.length > 900 ? `${content.slice(0, 900)}...` : content,
  };
}

function serviceHeaders(env: SupabaseRestEnv): HeadersInit {
  return {
    apikey: env.supabaseServiceRoleKey,
    authorization: `Bearer ${env.supabaseServiceRoleKey}`,
    "content-type": "application/json",
  };
}

function stringField(map: Record<string, unknown>, key: string): string {
  const value = map[key];
  return typeof value === "string" ? value.trim() : "";
}

function nullableStringField(
  map: Record<string, unknown>,
  key: string,
): string | null {
  const value = stringField(map, key);
  return value === "" ? null : value;
}

function stringArrayField(map: Record<string, unknown>, key: string): string[] {
  const value = map[key];
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .map((item) => String(item).trim())
    .filter((item) => item !== "");
}

function numberField(map: Record<string, unknown>, key: string): number {
  const value = map[key];
  const parsed = typeof value === "number"
    ? value
    : Number.parseFloat(String(value ?? ""));
  return Number.isFinite(parsed) ? parsed : 0;
}

function integerField(
  map: Record<string, unknown>,
  key: string,
  fallback: number,
): number {
  const parsed = Math.trunc(numberField(map, key));
  return parsed >= 1 ? parsed : fallback;
}
