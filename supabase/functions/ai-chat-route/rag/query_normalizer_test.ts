import { assert, assertEquals } from "jsr:@std/assert@1";
import { normalizeRagQuery, queryLanguages } from "./query_normalizer.ts";

for (const text of ["每侧次数", "单侧次数", "单边次数", "每边次数", "per-side reps", "reps per side", "unilateral reps", "per_side_reps"]) {
  Deno.test(`normalizes per-side reps without total-reps confusion: ${text}`, () => {
    const query = normalizeRagQuery(text);
    assert(query.canonical_concepts.includes("per_side_reps"));
    assert(!query.canonical_concepts.includes("total_reps"));
    assertEquals(query.technical_identifiers, []);
  });
}

Deno.test("normalizes total reps without per-side confusion", () => {
  const query = normalizeRagQuery("总次数怎么算");
  assertEquals(query.canonical_concepts, ["total_reps"]);
});

Deno.test("recognizes exercise, concepts, and mixed language variants", () => {
  const query = normalizeRagQuery("保加利亚 split squat reps per side 怎么算训练量");
  assert(query.exercise_keys.includes("bulgarian_split_squat"));
  assert(query.canonical_concepts.includes("per_side_reps"));
  assertEquals(query.language_profile.value, "mixed");
  assertEquals(queryLanguages(query), ["zh", "en"]);
});

Deno.test("keeps cloud authority and local cache separate", () => {
  const query = normalizeRagQuery("Cloud source of truth 和 SQLite cache 有什么区别");
  assert(query.canonical_concepts.includes("cloud_source_of_truth"));
  assert(query.canonical_concepts.includes("local_cache"));
  assert(
    query.concept_evidence_terms.cloud_source_of_truth.includes("云端正式数据源"),
  );
});

Deno.test("Chinese segmentation keeps short phrases and overlapping boundaries", () => {
  const normalized = normalizeRagQuery("FitLog 的产品承诺是什么");
  assert(normalized.tokens.includes("产品承诺"));
  assert(normalized.tokens.includes("承诺"));
  assert(normalized.tokens.includes("是什么"));
});

Deno.test("preserves technical identifiers as exact coverage requirements", () => {
  const normalized = normalizeRagQuery(
    "FitLog 的 imaginary_latency_rule_9471 文档规则是什么？",
  );
  assertEquals(normalized.technical_identifiers, [
    "imaginary_latency_rule_9471",
  ]);
});
