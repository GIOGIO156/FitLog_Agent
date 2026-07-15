import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const terms = JSON.parse(await readFile("assets/rag/domain_terms.v1.json", "utf8"));
const exercises = JSON.parse(await readFile("assets/rag/exercise_terms.v1.json", "utf8"));

test("domain concepts are unique and aliases do not cross do-not-merge boundaries", () => {
  assert.equal(terms.schema_version, "fitlog_domain_terms.v1");
  const byConcept = new Map(terms.concepts.map((item) => [item.concept, item]));
  assert.equal(byConcept.size, terms.concepts.length);
  for (const item of terms.concepts) {
    assert.ok(item.official.zh.length > 0);
    assert.ok(item.official.en.length > 0);
    assert.ok(item.internal_values.length > 0);
    for (const forbidden of item.do_not_merge_with) {
      const other = byConcept.get(forbidden);
      if (!other) continue;
      const ownTerms = new Set([
        item.official.zh,
        item.official.en.toLowerCase(),
        ...item.aliases.zh,
        ...item.aliases.en.map((value) => value.toLowerCase()),
        ...item.internal_values,
      ]);
      const otherTerms = [
        other.official.zh,
        other.official.en.toLowerCase(),
        ...other.aliases.zh,
        ...other.aliases.en.map((value) => value.toLowerCase()),
        ...other.internal_values,
      ];
      assert.equal(otherTerms.some((value) => ownTerms.has(value)), false);
    }
  }
  assert.ok(byConcept.get("per_side_reps").aliases.zh.includes("单侧次数"));
  assert.ok(byConcept.get("total_reps").do_not_merge_with.includes("per_side_reps"));
});

test("exercise terminology covers the full catalog and the Bulgarian trigger", () => {
  assert.equal(exercises.schema_version, "fitlog_exercise_terms.v1");
  assert.ok(exercises.exercises.length > 50);
  const keys = new Set(exercises.exercises.map((item) => item.key));
  assert.equal(keys.size, exercises.exercises.length);
  const bulgarian = exercises.exercises.find((item) => item.key === "bulgarian_split_squat");
  assert.equal(bulgarian.name_zh, "保加利亚分腿蹲");
  assert.equal(bulgarian.name_en, "Bulgarian Split Squat");
  assert.equal(bulgarian.reps_input_mode, "per_side_reps");
  assert.ok(bulgarian.aliases.zh.includes("保加利亚蹲"));
});
