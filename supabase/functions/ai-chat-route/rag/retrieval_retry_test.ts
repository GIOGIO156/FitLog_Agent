import { assert, assertEquals } from "jsr:@std/assert@1";
import { retrieveWithSingleRetry } from "./retrieval_retry.ts";
import {
  openAiRetrievalToolDefinition,
  parseSearchFitLogDocsArguments,
  qwenRetrievalToolDefinition,
} from "./retrieval_tool.ts";

Deno.test("provider tool mappings preserve the same strict server arguments", () => {
  assertEquals(
    openAiRetrievalToolDefinition().parameters,
    qwenRetrievalToolDefinition().function.parameters,
  );
  assert(
    parseSearchFitLogDocsArguments({
      query_variants: ["每侧次数 per_side_reps"],
      required_concepts: ["per_side_reps"],
    }) !== null,
  );
  assertEquals(
    parseSearchFitLogDocsArguments({
      query_variants: ["SELECT * FROM users"],
      required_concepts: [],
      account_id: "x",
    }),
    null,
  );
});

Deno.test("complete first retrieval does not invoke rewrite planner", async () => {
  let plannerCalls = 0;
  const outcome = await retrieveWithSingleRetry({
    config: config(),
    rawQuery: "per_side_reps",
    retryEnabled: true,
    rewritePlanner: () => {
      plannerCalls += 1;
      return Promise.resolve({ action: "stop" });
    },
    fetchImpl: fetchSequence([[row("per_side_reps is the internal value")]]),
  });
  assertEquals(outcome.attempts, 1);
  assertEquals(outcome.first_coverage.status, "complete");
  assertEquals(outcome.retry_action, "not_needed");
  assertEquals(outcome.retry_query_changed, false);
  assertEquals(plannerCalls, 0);
  assertEquals(outcome.latency.attempts.length, 1);
  assertEquals(outcome.latency.rewrite_planner_ms, null);
});

Deno.test("insufficient retrieval retries exactly once and reports gain", async () => {
  let plannerCalls = 0;
  const outcome = await retrieveWithSingleRetry({
    config: config(),
    rawQuery: "每侧次数",
    retryEnabled: true,
    rewritePlanner: () => {
      plannerCalls += 1;
      return Promise.resolve({
        action: "search_fitlog_docs",
        arguments: {
          query_variants: ["per_side_reps"],
          required_concepts: ["per_side_reps"],
        },
      });
    },
    fetchImpl: fetchSequence([[], [row("per_side_reps 每侧次数")]]),
  });
  assertEquals(plannerCalls, 1);
  assertEquals(outcome.attempts, 2);
  assertEquals(outcome.coverage.status, "complete");
  assertEquals(outcome.first_coverage.status, "insufficient");
  assertEquals(outcome.retry_action, "search");
  assertEquals(outcome.retry_query_changed, true);
  assertEquals(outcome.retry_gain, true);
  assertEquals(outcome.latency.attempts.length, 2);
  assert(outcome.latency.rewrite_planner_ms !== null);
  assert(outcome.latency.rewrite_planner_ms >= 0);
});

Deno.test("invalid retry arguments stop without a second search", async () => {
  let fetchCalls = 0;
  const fetchImpl = ((..._args: Parameters<typeof fetch>) => {
    fetchCalls += 1;
    return Promise.resolve(new Response("[]", { status: 200 }));
  }) as typeof fetch;
  const outcome = await retrieveWithSingleRetry({
    config: config(),
    rawQuery: "unknown",
    retryEnabled: true,
    rewritePlanner: () =>
      Promise.resolve({
        action: "search_fitlog_docs",
        arguments: {
          query_variants: ["drop table docs"],
          required_concepts: [],
        },
      }),
    fetchImpl,
  });
  assertEquals(fetchCalls, 1);
  assertEquals(outcome.issue, "retrieval_retry_invalid");
  assertEquals(outcome.retry_action, "invalid");
  assertEquals(outcome.retry_query_changed, false);
  assertEquals(outcome.latency.attempts.length, 1);
  assert(outcome.latency.rewrite_planner_ms !== null);
});

Deno.test("disabled retry records the first-pass decision without planning", async () => {
  let plannerCalls = 0;
  const outcome = await retrieveWithSingleRetry({
    config: config(),
    rawQuery: "unknown",
    retryEnabled: false,
    rewritePlanner: () => {
      plannerCalls += 1;
      return Promise.resolve({ action: "stop" });
    },
    fetchImpl: fetchSequence([[]]),
  });
  assertEquals(plannerCalls, 0);
  assertEquals(outcome.first_coverage.status, "insufficient");
  assertEquals(outcome.coverage.status, "insufficient");
  assertEquals(outcome.retry_action, "disabled");
  assertEquals(outcome.retry_reason, "insufficient");
});

Deno.test("planner stop is observable and does not issue a second search", async () => {
  let fetchCalls = 0;
  const fetchImpl = ((..._args: Parameters<typeof fetch>) => {
    fetchCalls += 1;
    return Promise.resolve(new Response("[]", { status: 200 }));
  }) as typeof fetch;
  const outcome = await retrieveWithSingleRetry({
    config: config(),
    rawQuery: "unknown",
    retryEnabled: true,
    rewritePlanner: () => Promise.resolve({ action: "stop" }),
    fetchImpl,
  });
  assertEquals(fetchCalls, 1);
  assertEquals(outcome.retry_action, "planner_stop");
  assertEquals(outcome.retry_query_changed, false);
  assertEquals(outcome.attempts, 1);
});

Deno.test("retry skips a planner rewrite that adds no material query term", async () => {
  let fetchCalls = 0;
  const fetchImpl = ((..._args: Parameters<typeof fetch>) => {
    fetchCalls += 1;
    return Promise.resolve(new Response("[]", { status: 200 }));
  }) as typeof fetch;
  const outcome = await retrieveWithSingleRetry({
    config: config(),
    rawQuery: "FitLog product promise",
    retryEnabled: true,
    rewritePlanner: () =>
      Promise.resolve({
        action: "search_fitlog_docs",
        arguments: {
          query_variants: ["product promise"],
          required_concepts: ["FitLog"],
        },
      }),
    fetchImpl,
  });
  assertEquals(fetchCalls, 1);
  assertEquals(outcome.retry_action, "no_change");
  assertEquals(outcome.retry_query_changed, false);
  assertEquals(outcome.attempts, 1);
});

Deno.test("unknown technical identifier stops without a predictably useless retry", async () => {
  let plannerCalls = 0;
  const outcome = await retrieveWithSingleRetry({
    config: config(),
    rawQuery: "FitLog imaginary_latency_rule_9471",
    retryEnabled: true,
    rewritePlanner: () => {
      plannerCalls += 1;
      return Promise.resolve({ action: "stop" });
    },
    fetchImpl: fetchSequence([[row("FitLog product rules")]]),
  });
  assertEquals(plannerCalls, 0);
  assertEquals(outcome.retry_action, "unsupported_identifier_stop");
  assertEquals(outcome.attempts, 1);
  assertEquals(outcome.coverage.status, "partial");
});

function config() {
  return {
    supabase: {
      supabaseUrl: "https://example.test",
      supabaseServiceRoleKey: "secret",
    },
    embedding: null,
  };
}

function fetchSequence(resultSets: unknown[][]): typeof fetch {
  let index = 0;
  return (() =>
    Promise.resolve(
      new Response(JSON.stringify(resultSets[index++] ?? []), { status: 200 }),
    )) as typeof fetch;
}

function row(content: string) {
  return {
    id: crypto.randomUUID(),
    build_id: "build-test",
    language: "zh",
    doc_path: "docs/zh/Algorithm.md",
    heading: "训练次数",
    heading_path: ["训练次数"],
    section_id: crypto.randomUUID(),
    chunk_index: 1,
    chunk_count: 1,
    content,
    context_prefix: "来源",
    tags: ["algorithm"],
    status: "implemented",
    authority: "current_product",
    lexical_score: 0.9,
    exact_score: 0,
    term_score: 0.9,
    full_text_score: 0,
    trigram_score: 0.8,
    vector_score: null,
    lexical_rank: 1,
    vector_rank: null,
    matched_terms: [],
    matched_fields: ["content"],
  };
}
