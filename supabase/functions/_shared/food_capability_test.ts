import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  explicitFoodFactsFromText,
  mergeFoodUnderstanding,
  validateFoodSemantics,
} from "./food_capability.ts";
import { foodDraftEvidencePolicy } from "./food_prompt_policy.ts";
import {
  classifyResponseLanguage,
  userFacingLanguageInstruction,
} from "./response_language_policy.ts";

Deno.test("food fact priority prevents lower sources from overriding explicit input", () => {
  const understanding = mergeFoodUnderstanding([
    {
      field: "protein_g",
      value: 20,
      unit: "g",
      source: "user_explicit",
      status: "resolved",
    },
    {
      field: "protein_g",
      value: 8.5,
      unit: "g",
      source: "model_estimate",
      status: "resolved",
    },
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
    items: [{
      name: "鸡胸",
      weight_g: 200,
      calories_kcal: 250,
      protein_g: 35,
      carbs_g: 0,
      fat_g: 8,
    }],
  };
}

Deno.test("semantic validator stays non-blocking while prompt owns scoped explicit facts", () => {
  const draft = {
    schema_version: "food_draft.v2" as const,
    date: "2026-07-14",
    meal_name: "Chicken rice meal",
    total_weight_g: 200,
    calories_kcal: 200,
    protein_g: 8.5,
    carbs_g: 20,
    fat_g: 5,
    confidence: 0.8,
    estimation_notes: "Estimated from the image",
    items: [],
  };
  const issues = validateFoodSemantics({
    draft,
    responseLanguage: "zh",
    understanding: explicitFoodFactsFromText("这份食物蛋白质 20g"),
  });
  assertEquals(issues, []);
  assertEquals(
    classifyResponseLanguage("zh", [
      draft.meal_name,
      draft.estimation_notes,
    ]),
    "mismatched",
  );
  const policy = foodDraftEvidencePolicy("zh");
  assert(policy.includes("只在对应食物和对应字段上优先"));
  assert(policy.includes("不要把局部事实误套到整餐"));
  assert(policy.includes("不要因为文字未提到就忽略图片中其他"));
  assert(policy.includes("常见标准商品或品牌规格"));
  assert(policy.includes("40mm 标准乒乓球"));
  assert(policy.includes("不得声称进行了网页搜索"));
  assert(policy.includes("不要凭整张图的直觉直接估整餐总重量"));
  const enPolicy = foodDraftEvidencePolicy("en");
  assert(enPolicy.includes("standard product or brand-size knowledge"));
  assert(enPolicy.includes("40 mm standard ping-pong ball"));
  assert(enPolicy.includes("never claim that you browsed the web"));
  assert(enPolicy.includes("Do not estimate total meal weight"));
});

Deno.test("response language policy guides generation without becoming a hard gate", () => {
  const zh = userFacingLanguageInstruction("zh");
  const en = userFacingLanguageInstruction("en");
  assert(zh.includes("用户可见自然语言内容使用简洁中文"));
  assert(zh.includes("品牌名"));
  assert(en.includes("user-visible natural-language content"));
  assertEquals(
    classifyResponseLanguage("zh", ["三文鱼刺身", "Based on visual estimate"]),
    "mixed",
  );
  assertEquals(
    classifyResponseLanguage("en", ["Salmon sashimi", "Estimated portion"]),
    "matched",
  );
});

Deno.test("macro energy differences are handled as model uncertainty, not hard failure", () => {
  const draft = {
    schema_version: "food_draft.v2" as const,
    date: "2026-07-14",
    meal_name: "Nutrition label",
    total_weight_g: 100,
    calories_kcal: 400,
    protein_g: 10,
    carbs_g: 10,
    fat_g: 2,
    confidence: 1,
    estimation_notes:
      "Copied from package label; fiber and rounding explain the difference.",
    items: [],
  };
  assertEquals(validateFoodSemantics({ draft, responseLanguage: "en" }), []);
});

Deno.test("generic explicit weights, portions, and exclusions are not regex hard gates", () => {
  const understanding = explicitFoodFactsFromText(
    "鸡胸 200g，米饭 150g，只吃一半，不要酱汁",
  );
  assertEquals(
    understanding.facts.filter((fact) => fact.field === "weight_g").length,
    2,
  );
  const issues = validateFoodSemantics({
    draft: {
      ...draft(),
      total_weight_g: 300,
      estimation_notes: "估算整份。",
      items: [{ ...draft().items[0], name: "鸡胸和酱汁" }],
    },
    responseLanguage: "zh",
    understanding,
  });
  assertEquals(issues, []);
});

Deno.test("screenshot-style additive notes do not fail whole-meal semantic validation", () => {
  const shrimpDraft = {
    ...draft(),
    total_weight_g: 430,
    calories_kcal: 780,
    protein_g: 70,
    carbs_g: 60,
    fat_g: 28,
    meal_name: "虾仁牛肉春饼",
    estimation_notes: "按用户描述与图片估算。",
    items: [
      {
        name: "虾仁",
        weight_g: 160,
        calories_kcal: 160,
        protein_g: 32,
        carbs_g: 2,
        fat_g: 2,
      },
      {
        name: "韩式牛肉",
        weight_g: 150,
        calories_kcal: 330,
        protein_g: 30,
        carbs_g: 8,
        fat_g: 20,
      },
      {
        name: "春饼",
        weight_g: 120,
        calories_kcal: 290,
        protein_g: 8,
        carbs_g: 50,
        fat_g: 6,
      },
    ],
  };
  const proteinShakeDraft = {
    ...draft(),
    total_weight_g: 780,
    calories_kcal: 980,
    protein_g: 82,
    carbs_g: 110,
    fat_g: 25,
    meal_name: "盒饭烤鸡胸奶昔",
    estimation_notes:
      "奶昔按用户说明含约20g蛋白质，整餐蛋白质另含鸡胸和米饭贡献。",
  };

  assertEquals(
    validateFoodSemantics({
      draft: shrimpDraft,
      responseLanguage: "zh",
      understanding: explicitFoodFactsFromText(
        "炒（160g生虾仁 加150g生韩式牛肉） 加几张春饼（蒸）",
      ),
    }),
    [],
  );
  assertEquals(
    validateFoodSemantics({
      draft: proteinShakeDraft,
      responseLanguage: "zh",
      understanding: explicitFoodFactsFromText("还有一杯20g蛋白质的奶昔"),
    }),
    [],
  );
});
