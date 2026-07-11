import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { draftConfirmationMessage } from "./draft_response_builder.ts";

Deno.test("draft confirmation text is derived from the validated draft date", () => {
  const message = draftConfirmationMessage("zh", {
    schema_version: "food_draft.v2",
    date: "2026-07-10",
    meal_name: "牛排南瓜",
    total_weight_g: 450,
    calories_kcal: 495,
    protein_g: 38,
    carbs_g: 30,
    fat_g: 22,
    confidence: 0.8,
    estimation_notes: "估算",
    items: [],
  });

  assertStringIncludes(message, "2026-07-10");
  assertStringIncludes(message, "牛排南瓜");
  assertEquals(message.includes("已保存"), false);
});
