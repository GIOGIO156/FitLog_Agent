import type { FoodDraft, OutputValidationIssue } from "./ai_output_contract.ts";

export const foodCapabilityPolicyVersion = "food_capability_policy.v1";
export const foodSemanticValidatorVersion = "food_semantic_validator.v1";

export type FoodFactSource = "user_explicit" | "package_ocr" | "image_observation" | "model_assumption" | "model_estimate";

export interface FoodUnderstandingFact {
  field: "weight_g" | "calories_kcal" | "protein_g" | "carbs_g" | "fat_g" | "portion_ratio" | "exclusion";
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

export interface FoodCapabilityRequestV1 {
  schema_version: "food_capability_request.v1";
  policy_version: typeof foodCapabilityPolicyVersion;
  response_language: "zh" | "en";
  understanding: FoodUnderstandingV1;
  source_priority: FoodFactSource[];
}

export function buildFoodCapabilityRequest(
  text: string,
  responseLanguage: "zh" | "en",
): FoodCapabilityRequestV1 {
  return {
    schema_version: "food_capability_request.v1",
    policy_version: foodCapabilityPolicyVersion,
    response_language: responseLanguage,
    understanding: explicitFoodFactsFromText(text),
    source_priority: [
      "user_explicit",
      "package_ocr",
      "image_observation",
      "model_assumption",
      "model_estimate",
    ],
  };
}

const sourcePriority: Record<FoodFactSource, number> = {
  user_explicit: 4,
  package_ocr: 3,
  image_observation: 2,
  model_assumption: 1,
  model_estimate: 0,
};

export function mergeFoodUnderstanding(facts: FoodUnderstandingFact[]): FoodUnderstandingV1 {
  const selected = new Map<string, FoodUnderstandingFact>();
  let conflictCount = 0;
  for (const fact of facts.slice(0, 32)) {
    const key = `${fact.field}:${fact.subject ?? ""}:${fact.unit ?? ""}`;
    const existing = selected.get(key);
    if (existing === undefined || sourcePriority[fact.source] > sourcePriority[existing.source]) selected.set(key, fact);
    else if (sourcePriority[fact.source] === sourcePriority[existing.source] && fact.value !== existing.value) {
      conflictCount += 1;
      selected.set(key, { ...existing, status: "conflicting" });
    }
  }
  const values = [...selected.values()];
  return { schema_version: "food_understanding.v1", facts: values, conflict_count: conflictCount, unresolved_count: values.filter((fact) => fact.status !== "resolved").length };
}

export function explicitFoodFactsFromText(text: string): FoodUnderstandingV1 {
  const facts: FoodUnderstandingFact[] = [];
  const patterns: [FoodUnderstandingFact["field"], RegExp][] = [
    ["protein_g", /(?:蛋白质?|protein)\s*(?:为|是|有|:|：)?\s*(\d+(?:\.\d+)?)\s*(?:g|克)/gi],
    ["protein_g", /(\d+(?:\.\d+)?)\s*(?:g|克)\s*(?:蛋白质?|protein)/gi],
    ["carbs_g", /(?:碳水(?:化合物)?|carbs?)\s*(?:为|是|有|:|：)?\s*(\d+(?:\.\d+)?)\s*(?:g|克)/gi],
    ["carbs_g", /(\d+(?:\.\d+)?)\s*(?:g|克)\s*(?:碳水(?:化合物)?|carbs?)/gi],
    ["fat_g", /(?:脂肪|fat)\s*(?:为|是|有|:|：)?\s*(\d+(?:\.\d+)?)\s*(?:g|克)/gi],
    ["fat_g", /(\d+(?:\.\d+)?)\s*(?:g|克)\s*(?:脂肪|fat)/gi],
    ["calories_kcal", /(?:热量|calories?|kcal)\s*(?:为|是|有|:|：)?\s*(\d+(?:\.\d+)?)\s*(?:kcal|千卡|大卡)?/gi],
    ["calories_kcal", /(\d+(?:\.\d+)?)\s*(?:kcal|千卡|大卡)(?:\s*(?:热量|calories?))?/gi],
  ];
  for (const [field, expression] of patterns) {
    for (const match of text.matchAll(expression)) facts.push({ field, value: Number(match[1]), unit: field === "calories_kcal" ? "kcal" : "g", source: "user_explicit", status: "resolved" });
  }
  for (const match of text.matchAll(/([\p{L}\p{Script=Han}][\p{L}\p{Script=Han}\s]{0,24}?)\s*(\d+(?:\.\d+)?)\s*(?:g|克)(?!\s*(?:蛋白质?|protein|碳水|carbs?|脂肪|fat))/giu)) {
    const subject = match[1].trim().replace(/^(?:记录|添加|吃了|食用|log|add|ate)\s*/i, "");
    if (!/(?:蛋白质?|protein|碳水|carbs?|脂肪|fat)$/i.test(subject)) {
      facts.push({ field: "weight_g", subject, value: Number(match[2]), unit: "g", source: "user_explicit", status: "resolved" });
    }
  }
  if (/(?:一半|半份|half(?:\s+(?:of|a))?)/i.test(text)) {
    facts.push({ field: "portion_ratio", value: 0.5, unit: "ratio", source: "user_explicit", status: "resolved" });
  }
  const exclusion = text.match(/(?:不要|不吃|去掉|不含|without|exclude|no)\s*([\p{L}\p{Script=Han}][\p{L}\p{Script=Han}\s]{0,30})/iu)?.[1]?.trim();
  if (exclusion) facts.push({ field: "exclusion", value: exclusion, unit: null, source: "user_explicit", status: "resolved" });
  return mergeFoodUnderstanding(facts);
}

export function validateFoodSemantics(params: {
  draft: FoodDraft;
  responseLanguage: "zh" | "en";
  understanding?: FoodUnderstandingV1;
}): OutputValidationIssue[] {
  const issues: OutputValidationIssue[] = [];
  const visible = `${params.draft.meal_name}\n${params.draft.items.map((item) => item.name).join("\n")}\n${params.draft.estimation_notes}`;
  const cjk = [...visible].filter((character) => /[\u3400-\u9fff]/u.test(character)).length;
  const latinWords = visible.match(/[A-Za-z]{3,}/g)?.length ?? 0;
  if (params.responseLanguage === "zh" && cjk === 0 && latinWords >= 3) issues.push({ path: "$.draft", reason: "response_language_mismatch" });
  if (params.responseLanguage === "en" && cjk >= 8 && latinWords === 0) issues.push({ path: "$.draft", reason: "response_language_mismatch" });
  for (const fact of params.understanding?.facts ?? []) {
    if (fact.status !== "resolved" || fact.source !== "user_explicit" || typeof fact.value !== "number") continue;
    const actual = fact.field === "weight_g"
      ? null
      : params.draft[fact.field as "calories_kcal" | "protein_g" | "carbs_g" | "fat_g"];
    if (typeof actual === "number" && Math.abs(actual - fact.value) > 0.5) issues.push({ path: `$.draft.${fact.field}`, reason: "user_explicit_fact_mismatch" });
  }
  const explicitWeights = (params.understanding?.facts ?? []).filter((fact) => fact.field === "weight_g" && fact.source === "user_explicit" && fact.status === "resolved" && typeof fact.value === "number");
  if (explicitWeights.length > 0) {
    const total = explicitWeights.reduce((sum, fact) => sum + Number(fact.value), 0);
    if (Math.abs(params.draft.total_weight_g - total) > Math.max(1, total * 0.05)) {
      issues.push({ path: "$.draft.total_weight_g", reason: "user_explicit_weight_mismatch" });
    }
  }
  const portion = (params.understanding?.facts ?? []).find((fact) => fact.field === "portion_ratio" && fact.status === "resolved");
  if (portion !== undefined && !/(?:一半|半份|half|50%)/i.test(params.draft.estimation_notes)) {
    issues.push({ path: "$.draft.estimation_notes", reason: "user_explicit_portion_unacknowledged" });
  }
  const exclusions = (params.understanding?.facts ?? []).filter((fact) => fact.field === "exclusion" && fact.status === "resolved" && typeof fact.value === "string");
  for (const fact of exclusions) {
    if (params.draft.items.some((item) => item.name.toLowerCase().includes(String(fact.value).toLowerCase()))) {
      issues.push({ path: "$.draft.items", reason: "user_exclusion_violated" });
    }
  }
  const macroKcal = params.draft.protein_g * 4 + params.draft.carbs_g * 4 + params.draft.fat_g * 9;
  const tolerance = Math.max(50, params.draft.calories_kcal * 0.25);
  const explained = /fiber|fibre|sugar alcohol|alcohol|label|round|纤维|糖醇|酒精|标签|四舍五入/i.test(params.draft.estimation_notes);
  if (!explained && Math.abs(macroKcal - params.draft.calories_kcal) > tolerance) issues.push({ path: "$.draft.calories_kcal", reason: "macro_energy_mismatch_unexplained" });
  return issues;
}
