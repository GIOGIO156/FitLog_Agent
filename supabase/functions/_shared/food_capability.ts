import type { FoodDraft, OutputValidationIssue } from "./ai_output_contract.ts";

export const foodSemanticValidatorVersion = "food_semantic_validator.v1";

export type FoodFactSource =
  | "user_explicit"
  | "package_ocr"
  | "image_observation"
  | "model_assumption"
  | "model_estimate";

export interface FoodUnderstandingFact {
  field:
    | "weight_g"
    | "calories_kcal"
    | "protein_g"
    | "carbs_g"
    | "fat_g"
    | "portion_ratio"
    | "exclusion";
  value: number | string;
  unit: string | null;
  source: FoodFactSource;
  status: "resolved" | "unresolved" | "conflicting";
  subject?: string;
}

export interface FoodUnderstandingV1 {
  schema_version: "food_understanding.v1";
  facts: FoodUnderstandingFact[];
  conflict_count: number;
  unresolved_count: number;
}

const sourcePriority: Record<FoodFactSource, number> = {
  user_explicit: 4,
  package_ocr: 3,
  image_observation: 2,
  model_assumption: 1,
  model_estimate: 0,
};

export function mergeFoodUnderstanding(
  facts: FoodUnderstandingFact[],
): FoodUnderstandingV1 {
  const selected = new Map<string, FoodUnderstandingFact>();
  let conflictCount = 0;
  for (const fact of facts.slice(0, 32)) {
    const key = `${fact.field}:${fact.subject ?? ""}:${fact.unit ?? ""}`;
    const existing = selected.get(key);
    if (
      existing === undefined ||
      sourcePriority[fact.source] > sourcePriority[existing.source]
    ) selected.set(key, fact);
    else if (
      sourcePriority[fact.source] === sourcePriority[existing.source] &&
      fact.value !== existing.value
    ) {
      conflictCount += 1;
      selected.set(key, { ...existing, status: "conflicting" });
    }
  }
  const values = [...selected.values()];
  return {
    schema_version: "food_understanding.v1",
    facts: values,
    conflict_count: conflictCount,
    unresolved_count:
      values.filter((fact) => fact.status !== "resolved").length,
  };
}

export function explicitFoodFactsFromText(text: string): FoodUnderstandingV1 {
  const facts: FoodUnderstandingFact[] = [];
  const patterns: [FoodUnderstandingFact["field"], RegExp][] = [
    [
      "protein_g",
      /(?:蛋白质?|protein)\s*(?:为|是|有|:|：)?\s*(\d+(?:\.\d+)?)\s*(?:g|克)/gi,
    ],
    ["protein_g", /(\d+(?:\.\d+)?)\s*(?:g|克)\s*(?:蛋白质?|protein)/gi],
    [
      "carbs_g",
      /(?:碳水(?:化合物)?|carbs?)\s*(?:为|是|有|:|：)?\s*(\d+(?:\.\d+)?)\s*(?:g|克)/gi,
    ],
    ["carbs_g", /(\d+(?:\.\d+)?)\s*(?:g|克)\s*(?:碳水(?:化合物)?|carbs?)/gi],
    [
      "fat_g",
      /(?:脂肪|fat)\s*(?:为|是|有|:|：)?\s*(\d+(?:\.\d+)?)\s*(?:g|克)/gi,
    ],
    ["fat_g", /(\d+(?:\.\d+)?)\s*(?:g|克)\s*(?:脂肪|fat)/gi],
    [
      "calories_kcal",
      /(?:热量|calories?|kcal)\s*(?:为|是|有|:|：)?\s*(\d+(?:\.\d+)?)\s*(?:kcal|千卡|大卡)?/gi,
    ],
    [
      "calories_kcal",
      /(\d+(?:\.\d+)?)\s*(?:kcal|千卡|大卡)(?:\s*(?:热量|calories?))?/gi,
    ],
  ];
  for (const [field, expression] of patterns) {
    for (const match of text.matchAll(expression)) {
      facts.push({
        field,
        value: Number(match[1]),
        unit: field === "calories_kcal" ? "kcal" : "g",
        source: "user_explicit",
        status: "resolved",
      });
    }
  }
  for (
    const match of text.matchAll(
      /([\p{L}\p{Script=Han}][\p{L}\p{Script=Han}\s]{0,24}?)\s*(\d+(?:\.\d+)?)\s*(?:g|克)(?!\s*(?:蛋白质?|protein|碳水|carbs?|脂肪|fat))/giu,
    )
  ) {
    const subject = match[1].trim().replace(
      /^(?:记录|添加|吃了|食用|log|add|ate)\s*/i,
      "",
    );
    if (!/(?:蛋白质?|protein|碳水|carbs?|脂肪|fat)$/i.test(subject)) {
      facts.push({
        field: "weight_g",
        subject,
        value: Number(match[2]),
        unit: "g",
        source: "user_explicit",
        status: "resolved",
      });
    }
  }
  if (/(?:一半|半份|half(?:\s+(?:of|a))?)/i.test(text)) {
    facts.push({
      field: "portion_ratio",
      value: 0.5,
      unit: "ratio",
      source: "user_explicit",
      status: "resolved",
    });
  }
  const exclusion = text.match(
    /(?:不要|不吃|去掉|不含|without|exclude|no)\s*([\p{L}\p{Script=Han}][\p{L}\p{Script=Han}\s]{0,30})/iu,
  )?.[1]?.trim();
  if (exclusion) {
    facts.push({
      field: "exclusion",
      value: exclusion,
      unit: null,
      source: "user_explicit",
      status: "resolved",
    });
  }
  return mergeFoodUnderstanding(facts);
}

export function validateFoodSemantics(params: {
  draft: FoodDraft;
  responseLanguage: "zh" | "en";
  understanding?: FoodUnderstandingV1;
}): OutputValidationIssue[] {
  void params;
  return [];
}
