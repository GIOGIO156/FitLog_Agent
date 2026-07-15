import { assert, assertEquals } from "jsr:@std/assert@1";
import { explicitFoodFactsFromText, mergeFoodUnderstanding, validateFoodSemantics } from "./food_capability.ts";

Deno.test("food fact priority prevents lower sources from overriding explicit input", () => {
  const understanding = mergeFoodUnderstanding([
    { field: "protein_g", value: 20, unit: "g", source: "user_explicit", status: "resolved" },
    { field: "protein_g", value: 8.5, unit: "g", source: "model_estimate", status: "resolved" },
  ]);
  assertEquals(understanding.facts[0].value, 20);
});

function draft() {
  return {
    schema_version: "food_draft.v2" as const,
    date: "2026-07-14",
    meal_name: "鸡胸米饭",
    total_weight_g: 350,
    calories_kcal: 500,
    protein_g: 40,
    carbs_g: 55,
    fat_g: 12,
    confidence: 0.8,
    estimation_notes: "根据输入估算。",
    items: [{ name: "鸡胸", weight_g: 200, calories_kcal: 250, protein_g: 35, carbs_g: 0, fat_g: 8 }],
  };
}

Deno.test("semantic validator rejects explicit protein mismatch and wrong language", () => {
  const draft = { schema_version: "food_draft.v2" as const, date: "2026-07-14", meal_name: "Chicken rice meal", total_weight_g: 200, calories_kcal: 200, protein_g: 8.5, carbs_g: 20, fat_g: 5, confidence: 0.8, estimation_notes: "Estimated from the image", items: [] };
  const issues = validateFoodSemantics({ draft, responseLanguage: "zh", understanding: explicitFoodFactsFromText("这份食物蛋白质 20g") });
  assertEquals(issues.map((issue) => issue.reason).includes("user_explicit_fact_mismatch"), true);
  assertEquals(issues.map((issue) => issue.reason).includes("response_language_mismatch"), true);
});

Deno.test("macro energy differences with an explicit label explanation are allowed", () => {
  const draft = { schema_version: "food_draft.v2" as const, date: "2026-07-14", meal_name: "Nutrition label", total_weight_g: 100, calories_kcal: 400, protein_g: 10, carbs_g: 10, fat_g: 2, confidence: 1, estimation_notes: "Copied from package label; fiber and rounding explain the difference.", items: [] };
  assertEquals(validateFoodSemantics({ draft, responseLanguage: "en" }).some((issue) => issue.reason === "macro_energy_mismatch_unexplained"), false);
});

Deno.test("generic explicit weights, portions, and exclusions remain semantic gates", () => {
  const understanding = explicitFoodFactsFromText("鸡胸 200g，米饭 150g，只吃一半，不要酱汁");
  assertEquals(understanding.facts.filter((fact) => fact.field === "weight_g").length, 2);
  const issues = validateFoodSemantics({
    draft: { ...draft(), total_weight_g: 300, estimation_notes: "估算整份。", items: [{ ...draft().items[0], name: "鸡胸和酱汁" }] },
    responseLanguage: "zh",
    understanding,
  });
  assert(issues.some((issue) => issue.reason === "user_explicit_weight_mismatch"));
  assert(issues.some((issue) => issue.reason === "user_explicit_portion_unacknowledged"));
  assert(issues.some((issue) => issue.reason === "user_exclusion_violated"));
});
