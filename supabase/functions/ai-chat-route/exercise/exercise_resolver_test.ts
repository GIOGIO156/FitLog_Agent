import { assertEquals } from "jsr:@std/assert@1";
import { resolveExercise } from "./exercise_resolver.ts";

for (const text of ["保加利亚分腿蹲", "Bulgarian Split Squat", "Bulgarian Squat", "bulgarian_split_squat"]) {
  Deno.test(`resolves Bulgarian definition: ${text}`, () => {
    const result = resolveExercise(text);
    assertEquals(result.status, "resolved");
    if (result.status === "resolved") {
      assertEquals(result.definition.key, "bulgarian_split_squat");
      assertEquals(result.definition.reps_input_mode, "per_side_reps");
    }
  });
}

Deno.test("resolves reviewed single-arm row alias", () => {
  const result = resolveExercise("One-arm Dumbbell Row");
  assertEquals(result.status, "resolved");
  if (result.status === "resolved") assertEquals(result.definition.key, "single_arm_dumbbell_row");
});

Deno.test("custom definitions are request-scoped and duplicate names clarify", () => {
  const reference = { key: "custom_left", name: "我的单侧蹲", definitionHash: "1234abcd", exerciseType: "strength" as const, bodyPart: "Legs", strengthStructure: "compound", strengthProfile: "lower_body_compound", loadInputMode: "total_load" as const, repsInputMode: "per_side_reps" as const, setMetricType: "reps" as const };
  const resolved = resolveExercise("记录我的单侧蹲", [reference]);
  assertEquals(resolved.status, "resolved");
  assertEquals(resolveExercise("记录我的单侧蹲", [reference, { ...reference, key: "custom_right" }]).status, "ambiguous");
  assertEquals(resolveExercise("记录我的单侧蹲").status, "missing");
});
