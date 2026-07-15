import { assertEquals } from "jsr:@std/assert@1";
import { normalizeRagQuery } from "./query_normalizer.ts";
import { assessRetrievalCoverage } from "./retrieval_coverage.ts";
import type { RetrievalCandidate } from "./types.ts";

Deno.test("coverage accepts official concept wording without requiring internal IDs", () => {
  const query = normalizeRagQuery(
    "Cloud source of truth 和 SQLite cache 有什么区别",
  );
  const coverage = assessRetrievalCoverage(query, [
    candidate(
      "云端正式数据源是正式记录权威；SQLite 只保存本地缓存。",
    ),
  ]);
  assertEquals(coverage.status, "complete");
  assertEquals(coverage.missing_dimensions, []);
  assertEquals(
    coverage.covered_concepts.sort(),
    ["cloud_source_of_truth", "local_cache"],
  );
});

Deno.test("coverage still reports a genuinely missing independent concept", () => {
  const query = normalizeRagQuery(
    "Cloud source of truth 和 SQLite cache 有什么区别",
  );
  const coverage = assessRetrievalCoverage(query, [
    candidate("云端正式数据源是正式记录权威。"),
  ]);
  assertEquals(coverage.status, "partial");
  assertEquals(coverage.missing_dimensions, ["canonical_concepts"]);
  assertEquals(coverage.covered_concepts, ["cloud_source_of_truth"]);
});

Deno.test("coverage cannot treat a semantically adjacent chunk as exact technical evidence", () => {
  const query = normalizeRagQuery(
    "FitLog 的 imaginary_latency_rule_9471 文档规则是什么？",
  );
  const coverage = assessRetrievalCoverage(query, [
    candidate("FitLog documents its supported product rules."),
  ]);
  assertEquals(coverage.status, "partial");
  assertEquals(coverage.missing_dimensions, ["technical_identifiers"]);
});

function candidate(content: string): RetrievalCandidate {
  return {
    id: "id",
    build_id: "build",
    language: "zh",
    doc_path: "docs/zh/CloudLocalDataBoundary.md",
    heading: "数据权威",
    heading_path: ["数据权威"],
    section_id: "authority",
    chunk_index: 1,
    chunk_count: 1,
    content,
    context_prefix: "",
    tags: [],
    status: "implemented",
    authority: "current_product",
    lexical_score: 1,
    exact_score: 1,
    term_score: 1,
    full_text_score: 1,
    trigram_score: 1,
    vector_score: null,
    lexical_rank: 1,
    vector_rank: null,
    matched_terms: [],
    matched_fields: ["content"],
  };
}
