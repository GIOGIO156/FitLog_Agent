import { assert, assertEquals } from "jsr:@std/assert@1";
import { assessRetrievalCoverage } from "./retrieval_coverage.ts";
import { retrieveFitLogDocuments } from "./retrieval_pipeline.ts";
import { fuseAndRerank } from "./retrieval_reranker.ts";
import { normalizeRagQuery } from "./query_normalizer.ts";
import type { RetrievalCandidate } from "./types.ts";

Deno.test("hybrid pipeline degrades to lexical without inventing sources", async () => {
  const calls: string[] = [];
  let rpcBody: Record<string, unknown> = {};
  const fetchMock = ((url: string | URL | Request, init?: RequestInit) => {
    calls.push(String(url));
    rpcBody = JSON.parse(String(init?.body));
    return Promise.resolve(
      new Response(
        JSON.stringify([candidate({
          doc_path: "docs/zh/Algorithm.md",
          heading: "力量训练量",
          content:
            "bulgarian_split_squat 使用 per_side_reps，每侧 12 次换算为总次数 24。",
          lexical_rank: 1,
        })]),
        { status: 200 },
      ),
    );
  }) as typeof fetch;
  const result = await retrieveFitLogDocuments(
    {
      supabase: {
        supabaseUrl: "https://example.test",
        supabaseServiceRoleKey: "secret",
      },
      embedding: null,
    },
    "保加利亚分腿蹲的每侧次数怎么算训练量",
    fetchMock,
  );
  assertEquals(calls.length, 1);
  assert(Array.isArray(rpcBody.input_query_terms));
  assertEquals(rpcBody.input_limit, 60);
  assert((rpcBody.input_query_terms as string[]).includes("保加利亚"));
  assertEquals(result.debug.issues, ["embedding_unavailable"]);
  assertEquals(result.debug.latency.embedding_status, "not_configured");
  assertEquals(result.debug.latency.embedding_ms, null);
  assert(result.debug.latency.embedding_input_chars > 0);
  assert(result.debug.latency.query_variant_count > 0);
  assert(result.debug.latency.hybrid_rpc_ms >= 0);
  assert(result.debug.latency.total_ms >= result.debug.latency.hybrid_rpc_ms);
  assertEquals(result.candidates[0].doc_path, "docs/zh/Algorithm.md");
  assertEquals(
    assessRetrievalCoverage(result.query, result.candidates).status,
    "complete",
  );
});

Deno.test("reranker prioritizes exact official concept and current authority", () => {
  const query = normalizeRagQuery("per_side_reps");
  const broad = candidate({
    section_id: "broad",
    heading: "Workout",
    content: "General workout repetitions.",
    lexical_rank: 1,
  });
  const exact = candidate({
    section_id: "exact",
    heading: "Repetition Modes",
    content: "The internal value is per_side_reps.",
    lexical_rank: 2,
  });
  const result = fuseAndRerank([broad, exact], query);
  assertEquals(result.candidates[0].section_id, "exact");
});

Deno.test("reranker applies stable owning-document cues beyond one fixture", () => {
  const permissionQuery = normalizeRagQuery("AI 能直接修改饮食目标吗");
  const generic = candidate({
    section_id: "generic",
    doc_path: "README.md",
    heading: "AI",
    content: "AI helps with diet goals.",
    lexical_rank: 1,
    vector_rank: 1,
  });
  const permissionOwner = candidate({
    section_id: "permission-owner",
    doc_path: "docs/zh/AgentDesign.md",
    heading: "写入权限",
    content: "AI 不能直接修改饮食目标，必须由用户确认。",
    lexical_rank: 4,
    vector_rank: 4,
  });
  assertEquals(
    fuseAndRerank([generic, permissionOwner], permissionQuery).candidates[0]
      .section_id,
    "permission-owner",
  );

  const evidenceQuery = normalizeRagQuery(
    "Which evidence may support the BMR method claim?",
  );
  const method = candidate({
    language: "en",
    section_id: "method",
    doc_path: "docs/en/Methodology.md",
    heading: "BMR",
    content: "BMR is an estimation method.",
    lexical_rank: 1,
    vector_rank: 1,
  });
  const evidenceOwner = candidate({
    language: "en",
    section_id: "reference-owner",
    doc_path: "docs/en/References.md",
    heading: "Claim Boundaries",
    content: "The BMR reference supports only the bounded method claim.",
    lexical_rank: 4,
    vector_rank: 4,
  });
  assertEquals(
    fuseAndRerank([method, evidenceOwner], evidenceQuery).candidates[0]
      .section_id,
    "reference-owner",
  );

  const productQuery = normalizeRagQuery("What does FitLog promise?");
  const agent = candidate({
    language: "en",
    section_id: "agent",
    doc_path: "docs/en/AgentDesign.md",
    lexical_rank: 1,
  });
  const productOwner = candidate({
    language: "en",
    section_id: "product-owner",
    doc_path: "docs/en/Product.md",
    content: "FitLog promises confirmation-first health tracking.",
    lexical_rank: 5,
  });
  assertEquals(
    fuseAndRerank([agent, productOwner], productQuery).candidates[0].section_id,
    "product-owner",
  );
});

Deno.test("reranker keeps monolingual top results in the requested language", () => {
  const query = normalizeRagQuery("每侧次数怎么算训练量");
  const zh = candidate({ section_id: "zh", language: "zh", lexical_rank: 2 });
  const en = candidate({ section_id: "en", language: "en", lexical_rank: 1 });
  const result = fuseAndRerank([en, zh], query);
  assertEquals(result.candidates.map((item) => item.language), ["zh", "en"]);
});

Deno.test("invalid candidate rows are omitted rather than fabricated", async () => {
  const fetchMock = (() =>
    Promise.resolve(
      new Response(JSON.stringify([{ bad: true }]), { status: 200 }),
    )) as typeof fetch;
  const result = await retrieveFitLogDocuments(
    {
      supabase: {
        supabaseUrl: "https://example.test",
        supabaseServiceRoleKey: "secret",
      },
      embedding: null,
    },
    "unknown",
    fetchMock,
  );
  assertEquals(result.candidates, []);
  assertEquals(
    assessRetrievalCoverage(result.query, []).status,
    "insufficient",
  );
});

Deno.test("diagnostics can select the indexed v2 RPC without changing production default", async () => {
  const calls: string[] = [];
  let rpcBody: Record<string, unknown> = {};
  const fetchMock = ((url: string | URL | Request, init?: RequestInit) => {
    calls.push(String(url));
    rpcBody = JSON.parse(String(init?.body));
    return Promise.resolve(new Response("[]", { status: 200 }));
  }) as typeof fetch;
  await retrieveFitLogDocuments(
    {
      supabase: {
        supabaseUrl: "https://example.test",
        supabaseServiceRoleKey: "secret",
      },
      embedding: null,
      rpcName: "search_document_chunks_hybrid_v2",
      candidateLimit: 36,
    },
    "FitLog product promise",
    fetchMock,
  );
  assertEquals(
    calls[0],
    "https://example.test/rest/v1/rpc/search_document_chunks_hybrid_v2",
  );
  assertEquals(rpcBody.input_limit, 36);
});

Deno.test("indexed retrieval preserves SQL hybrid fusion in one bounded RPC", async () => {
  let rpcCalls = 0;
  let rpcBody: Record<string, unknown> = {};
  const fetchMock = ((url: string | URL | Request, init?: RequestInit) => {
    if (String(url).includes("/embeddings")) {
      return Promise.resolve(
        new Response(
          JSON.stringify({
            model: "model",
            data: [{ embedding: Array(1536).fill(0) }],
          }),
          { status: 200 },
        ),
      );
    }
    rpcCalls += 1;
    rpcBody = JSON.parse(String(init?.body));
    return Promise.resolve(
      new Response(
        JSON.stringify([candidate({
          content: "FitLog product promise",
          lexical_score: 0.6,
          lexical_rank: 1,
          vector_score: 0.9,
          vector_rank: 1,
        })]),
        { status: 200 },
      ),
    );
  }) as typeof fetch;
  const result = await retrieveFitLogDocuments(
    {
      supabase: {
        supabaseUrl: "https://example.test",
        supabaseServiceRoleKey: "secret",
      },
      embedding: {
        endpoint: "https://example.test/embeddings",
        apiKey: "secret",
        model: "model",
        timeoutMs: 5000,
      },
      rpcName: "search_document_chunks_hybrid_v2",
      candidateLimit: 36,
    },
    "FitLog product promise",
    fetchMock,
  );
  assertEquals(rpcCalls, 1);
  assertEquals(rpcBody.input_limit, 36);
  assert(Array.isArray(rpcBody.input_query_terms));
  assertEquals(typeof rpcBody.input_embedding, "string");
  assertEquals(result.debug.latency.embedding_status, "completed");
  assertEquals(result.candidates.length, 1);
});

Deno.test("v3 overlaps lexical acquisition with embedding and preserves SQL fusion", async () => {
  const lexicalId = "00000000-0000-4000-8000-000000000001";
  let embeddingStarted = false;
  let resolveEmbedding: ((response: Response) => void) | null = null;
  let finalBody: Record<string, unknown> = {};
  const fetchMock = ((url: string | URL | Request, init?: RequestInit) => {
    const value = String(url);
    if (value.includes("/embeddings")) {
      embeddingStarted = true;
      return new Promise<Response>((resolve) => {
        resolveEmbedding = resolve;
      });
    }
    if (value.endsWith("/search_document_chunk_lexical_candidates_v1")) {
      assert(embeddingStarted);
      resolveEmbedding!(
        new Response(
          JSON.stringify({
            model: "model",
            data: [{ embedding: Array(1536).fill(0) }],
          }),
          { status: 200 },
        ),
      );
      return Promise.resolve(
        new Response(JSON.stringify([{ id: lexicalId }]), { status: 200 }),
      );
    }
    assert(value.endsWith("/search_document_chunks_hybrid_v3"));
    finalBody = JSON.parse(String(init?.body));
    return Promise.resolve(
      new Response(
        JSON.stringify([candidate({
          content: "FitLog product promise",
          lexical_score: 0.6,
          lexical_rank: 1,
          vector_score: 0.9,
          vector_rank: 1,
        })]),
        { status: 200 },
      ),
    );
  }) as typeof fetch;
  const result = await retrieveFitLogDocuments(
    {
      supabase: {
        supabaseUrl: "https://example.test",
        supabaseServiceRoleKey: "secret",
      },
      embedding: {
        endpoint: "https://example.test/embeddings",
        apiKey: "secret",
        model: "model",
        timeoutMs: 5000,
      },
      rpcName: "search_document_chunks_hybrid_v3",
      candidateLimit: 36,
    },
    "FitLog product promise",
    fetchMock,
  );
  assertEquals(finalBody.input_lexical_candidate_ids, [lexicalId]);
  assertEquals(typeof finalBody.input_embedding, "string");
  assertEquals(result.debug.latency.embedding_status, "completed");
  assert(result.debug.latency.lexical_candidate_rpc_ms !== null);
  assertEquals(result.candidates.length, 1);
});

Deno.test("unscoped vector similarity does not fabricate a document answer", async () => {
  const fetchMock = (() =>
    Promise.resolve(
      new Response(
        JSON.stringify([candidate({
          section_id: "weather-vector",
          content: "Document RAG does not answer live weather questions.",
          lexical_score: 0,
          vector_score: 0.9,
          vector_rank: 1,
        })]),
        { status: 200 },
      ),
    )) as typeof fetch;
  const result = await retrieveFitLogDocuments(
    {
      supabase: {
        supabaseUrl: "https://example.test",
        supabaseServiceRoleKey: "secret",
      },
      embedding: null,
    },
    "明天上海会不会下雨",
    fetchMock,
  );
  assertEquals(result.candidates, []);
});

function candidate(overrides: Partial<RetrievalCandidate>): RetrievalCandidate {
  return {
    id: "id",
    build_id: "build-test",
    language: "zh",
    doc_path: "docs/zh/Product.md",
    heading: "Heading",
    heading_path: ["Heading"],
    section_id: "section",
    chunk_index: 1,
    chunk_count: 1,
    content: "Content",
    context_prefix: "Source",
    tags: ["algorithm"],
    status: "implemented",
    authority: "current_product",
    lexical_score: 0.8,
    exact_score: 0,
    term_score: 0,
    full_text_score: 0,
    trigram_score: 0.8,
    vector_score: null,
    lexical_rank: null,
    vector_rank: null,
    matched_terms: [],
    matched_fields: [],
    ...overrides,
  };
}
