export type PhotoGatewayErrorCode =
  | "auth_required"
  | "subscription_required"
  | "device_replaced"
  | "gateway_timeout"
  | "provider_failure"
  | "record_schema_mismatch";

export type PhotoGatewayStatus = "ok" | "blocked" | "error" | "timeout";
export type PhotoLanguage = "zh" | "en";

export interface PhotoAnalysisImage {
  mimeType: "image/jpeg" | "image/png" | "image/webp";
  base64Data: string;
  byteLength: number;
}

export interface PhotoAnalysisRequest {
  images: PhotoAnalysisImage[];
  language: PhotoLanguage;
  modelChoice: "qwen";
  deviceId: string;
  selectedDate: string;
  schemaVersion: "food_draft.v1";
  userNote: string | null;
}

export interface FoodDraft {
  meal_name: string;
  total_weight_g: number;
  calories_kcal: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  confidence: number | null;
  estimation_notes: string;
  items: FoodDraftItem[];
}

export interface FoodDraftItem {
  name: string;
  weight_g: number;
  calories_kcal: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
}

export interface ParsedProviderFoodResponse {
  draft: FoodDraft | null;
  needsClarification: boolean;
  clarificationQuestions: string[];
  schemaValidationStatus: "passed" | "needs_clarification";
}

export class PhotoGatewayRequestError extends Error {
  readonly code: PhotoGatewayErrorCode;
  readonly status: number;

  constructor(code: PhotoGatewayErrorCode, status = 422) {
    super(code);
    this.code = code;
    this.status = status;
  }
}

const supportedMimeTypes = new Set(["image/jpeg", "image/png", "image/webp"]);
const maxImageBytes = 4 * 1024 * 1024;
const maxImages = 3;
const unsupportedFutureFields = [
  "attachments",
  "context_objects",
  "official_record_write",
  "rag_context",
  "tool_calls",
];

export function parsePhotoAnalysisRequest(
  value: unknown,
): PhotoAnalysisRequest {
  const body = objectOrThrow(value);
  for (const field of unsupportedFutureFields) {
    if (field in body) {
      throw new PhotoGatewayRequestError("record_schema_mismatch");
    }
  }

  const userNote = nullableString(body.user_note);
  const images = parseImages(body, userNote);

  const language = stringOrEmpty(body.language).trim();
  if (language !== "zh" && language !== "en") {
    throw new PhotoGatewayRequestError("record_schema_mismatch");
  }

  if (stringOrEmpty(body.model_choice).trim() !== "qwen") {
    throw new PhotoGatewayRequestError("record_schema_mismatch");
  }

  if (stringOrEmpty(body.schema_version).trim() !== "food_draft.v1") {
    throw new PhotoGatewayRequestError("record_schema_mismatch");
  }

  const deviceId = stringOrEmpty(body.device_id).trim();
  const selectedDate = stringOrEmpty(body.selected_date).trim();
  if (deviceId === "" || selectedDate === "") {
    throw new PhotoGatewayRequestError("record_schema_mismatch");
  }

  return {
    images,
    language,
    modelChoice: "qwen",
    deviceId,
    selectedDate,
    schemaVersion: "food_draft.v1",
    userNote,
  };
}

export function buildQwenVisionRequestBody(params: {
  request: PhotoAnalysisRequest;
  model: string;
}): Record<string, unknown> {
  const request = params.request;
  return {
    model: params.model,
    enable_thinking: false,
    response_format: { type: "json_object" },
    messages: [
      {
        role: "system",
        content: systemPrompt(request.language),
      },
      {
        role: "user",
        content: [
          { type: "text", text: userPrompt(request) },
          ...request.images.map((image) => ({
            type: "image_url",
            image_url: {
              url:
                `data:${image.mimeType};base64,${image.base64Data}`,
            },
          })),
        ],
      },
    ],
  };
}

export function extractQwenContent(body: unknown): string {
  const map = recordOrThrow(body);
  const choices = map.choices;
  if (!Array.isArray(choices) || choices.length === 0) {
    throw new Error("provider_failure");
  }
  const first = recordOrThrow(choices[0]);
  const message = recordOrThrow(first.message);
  const content = message.content;
  if (typeof content !== "string" || content.trim() === "") {
    throw new Error("provider_failure");
  }
  return content.trim();
}

export function parseProviderFoodDraftBody(
  content: string,
): ParsedProviderFoodResponse {
  const root = parseJsonObjectFromContent(content);
  if (root === null) {
    throw new Error("record_schema_mismatch");
  }
  const needsClarification = root.needs_clarification === true;
  const clarificationQuestions = stringList(root.clarification_questions);
  const rawDraft = isRecord(root.draft)
    ? root.draft
    : isRecord(root.food_draft)
    ? root.food_draft
    : isRecord(root.data)
    ? root.data
    : isRecord(root.result)
    ? root.result
    : isRecord(root) && "meal_name" in root
    ? root
    : null;

  if (needsClarification && rawDraft === null) {
    return {
      draft: null,
      needsClarification: true,
      clarificationQuestions,
      schemaValidationStatus: "needs_clarification",
    };
  }
  if (rawDraft === null) {
    throw new Error("record_schema_mismatch");
  }

  return {
    draft: validateFoodDraft(rawDraft),
    needsClarification: false,
    clarificationQuestions: [],
    schemaValidationStatus: "passed",
  };
}

export function photoGatewayResponse(params: {
  modelProvider?: string | null;
  draft?: FoodDraft | null;
  needsClarification?: boolean;
  clarificationQuestions?: string[];
  debugSummaryId?: string | null;
  error?: { code: PhotoGatewayErrorCode; message: string } | null;
}): Record<string, unknown> {
  return {
    model_choice: "qwen",
    model_provider: params.modelProvider ?? "qwen",
    draft: params.draft ?? null,
    needs_clarification: params.needsClarification ?? false,
    clarification_questions: params.clarificationQuestions ?? [],
    debug_summary_id: params.debugSummaryId ?? null,
    error: params.error ?? null,
  };
}

export function errorMessageForCode(code: PhotoGatewayErrorCode): string {
  switch (code) {
    case "auth_required":
      return "Sign in is required.";
    case "subscription_required":
      return "AI subscription is required.";
    case "device_replaced":
      return "This device session is no longer active.";
    case "gateway_timeout":
      return "The AI Gateway timed out.";
    case "provider_failure":
      return "The AI Gateway could not complete the request.";
    case "record_schema_mismatch":
      return "The AI food analysis request or draft schema is not supported.";
  }
}

export function logStatusForCode(
  code: PhotoGatewayErrorCode,
): PhotoGatewayStatus {
  switch (code) {
    case "subscription_required":
    case "device_replaced":
      return "blocked";
    case "gateway_timeout":
      return "timeout";
    default:
      return "error";
  }
}

export function stripImageDataForDebug(request: PhotoAnalysisRequest | null) {
  if (request === null) {
    return [];
  }
  if (request.images.length === 0) {
    return [{
      input_kind: "text",
      selected_date: request.selectedDate,
      has_user_note: request.userNote !== null,
    }];
  }
  return request.images.map((image) => ({
    input_kind: "image",
    mime_type: image.mimeType,
    byte_length: image.byteLength,
    selected_date: request.selectedDate,
    has_user_note: request.userNote !== null,
  }));
}

function validateFoodDraft(value: Record<string, unknown>): FoodDraft {
  const mealName = stringOrEmpty(value.meal_name).trim();
  if (mealName === "") {
    throw new Error("record_schema_mismatch");
  }
  const requestedTotals = {
    total_weight_g: nonNegativeFiniteNumber(value.total_weight_g),
    calories_kcal: nonNegativeFiniteNumber(value.calories_kcal),
    protein_g: nonNegativeFiniteNumber(value.protein_g),
    carbs_g: nonNegativeFiniteNumber(value.carbs_g),
    fat_g: nonNegativeFiniteNumber(value.fat_g),
  };
  const items = foodDraftItems(value.items);
  const totals = items.length === 0 ? requestedTotals : foodDraftTotals(items);
  return {
    meal_name: mealName,
    total_weight_g: totals.total_weight_g,
    calories_kcal: totals.calories_kcal,
    protein_g: totals.protein_g,
    carbs_g: totals.carbs_g,
    fat_g: totals.fat_g,
    confidence: value.confidence === null || value.confidence === undefined
      ? null
      : nullableNonNegativeFiniteNumber(value.confidence),
    estimation_notes: stringOrEmpty(value.estimation_notes).trim(),
    items,
  };
}
function foodDraftItems(value: unknown): FoodDraftItem[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.map((item) => {
    const map = recordOrThrow(item);
    const name = stringOrEmpty(map.name).trim();
    if (name === "") {
      throw new Error("record_schema_mismatch");
    }
    return {
      name,
      weight_g: nonNegativeFiniteNumber(map.weight_g),
      calories_kcal: nonNegativeFiniteNumber(map.calories_kcal),
      protein_g: nonNegativeFiniteNumber(map.protein_g),
      carbs_g: nonNegativeFiniteNumber(map.carbs_g),
      fat_g: nonNegativeFiniteNumber(map.fat_g),
    };
  });
}

function systemPrompt(language: PhotoLanguage): string {
  return language === "zh"
    ? "你是 FitLog 的 AI 食物分析助手。你只能根据本次请求的用户描述和零到三张图片生成可编辑食物草稿，不能写入正式记录，不能修改目标，不能调用 RAG。输出必须是严格 JSON。"
    : "You are FitLog's AI food analysis assistant. Use only the user's description and zero to three images in this request to create an editable food draft. Do not write official records, change goals, or use RAG. Output strict JSON only.";
}

function userPrompt(request: PhotoAnalysisRequest): string {
  const note = request.userNote === null
    ? ""
    : `\nUser note: ${request.userNote}`;
  const clarificationInstruction = request.images.length === 0
    ? "If the description is too unclear to estimate safely, set needs_clarification true, draft null, and include short clarification_questions."
    : "If the image or description is too unclear, set needs_clarification true, draft null, and include short clarification_questions.";
  return [
    "Return JSON with this shape:",
    '{"needs_clarification":false,"clarification_questions":[],"draft":{"meal_name":"...","total_weight_g":0,"calories_kcal":0,"protein_g":0,"carbs_g":0,"fat_g":0,"confidence":0.0,"estimation_notes":"...","items":[{"name":"...","weight_g":0,"calories_kcal":0,"protein_g":0,"carbs_g":0,"fat_g":0}]}}',
    "When items is non-empty, item values are totals for that item portion, not per-100g values; draft meal totals must equal the sum of items.",
    clarificationInstruction,
    "Use finite non-negative numbers. Estimate honestly and keep notes brief.",
    `Image count: ${request.images.length}`,
    `Selected date: ${request.selectedDate}`,
    note,
  ].join("\n");
}

function parseImages(
  body: Record<string, unknown>,
  userNote: string | null,
): PhotoAnalysisImage[] {
  const rawImages = Array.isArray(body.images)
    ? body.images
    : body.image === undefined
    ? []
    : [body.image];
  if (rawImages.length > maxImages) {
    throw new PhotoGatewayRequestError("record_schema_mismatch");
  }
  if (rawImages.length === 0) {
    if (userNote === null) {
      throw new PhotoGatewayRequestError("record_schema_mismatch");
    }
    return [];
  }
  return rawImages.map((item) => {
    const image = objectOrThrow(item);
    const mimeType = stringOrEmpty(image.mime_type).trim();
    const base64Data = stringOrEmpty(image.base64_data).trim();
    const byteLength = numberOrNaN(image.byte_length);
    if (
      !supportedMimeTypes.has(mimeType) ||
      base64Data === "" ||
      !Number.isInteger(byteLength) ||
      byteLength <= 0 ||
      byteLength > maxImageBytes
    ) {
      throw new PhotoGatewayRequestError("record_schema_mismatch");
    }
    return {
      mimeType: mimeType as "image/jpeg" | "image/png" | "image/webp",
      base64Data,
      byteLength,
    };
  });
}

function foodDraftTotals(items: FoodDraftItem[]) {
  return items.reduce((totals, item) => ({
    total_weight_g: totals.total_weight_g + item.weight_g,
    calories_kcal: totals.calories_kcal + item.calories_kcal,
    protein_g: totals.protein_g + item.protein_g,
    carbs_g: totals.carbs_g + item.carbs_g,
    fat_g: totals.fat_g + item.fat_g,
  }), {
    total_weight_g: 0,
    calories_kcal: 0,
    protein_g: 0,
    carbs_g: 0,
    fat_g: 0,
  });
}
function nonNegativeFiniteNumber(value: unknown): number {
  const number = typeof value === "number"
    ? value
    : Number.parseFloat(String(value ?? ""));
  if (!Number.isFinite(number) || number < 0) {
    throw new Error("record_schema_mismatch");
  }
  return number;
}

function nullableNonNegativeFiniteNumber(value: unknown): number | null {
  try {
    return nonNegativeFiniteNumber(value);
  } catch (_) {
    return null;
  }
}

function objectOrThrow(value: unknown): Record<string, unknown> {
  if (!isRecord(value)) {
    throw new PhotoGatewayRequestError("record_schema_mismatch");
  }
  return value;
}

function recordOrThrow(value: unknown): Record<string, unknown> {
  if (!isRecord(value)) {
    throw new Error("record_schema_mismatch");
  }
  return value;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function stringOrEmpty(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function nullableString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed;
}

function numberOrNaN(value: unknown): number {
  return typeof value === "number" ? value : Number.parseInt(String(value), 10);
}

function stringList(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.map((item) => String(item));
}

function stripJsonFence(value: string): string {
  const trimmed = value.trim();
  const fence = /^```(?:json)?\s*([\s\S]*?)\s*```$/i.exec(trimmed);
  return fence?.[1]?.trim() ?? trimmed;
}

function parseJsonObjectFromContent(value: string): Record<string, unknown> | null {
  for (const candidate of jsonObjectCandidates(value)) {
    try {
      const parsed = JSON.parse(candidate);
      if (isRecord(parsed)) {
        return parsed;
      }
    } catch (_) {
      // Try the next candidate.
    }
  }
  return null;
}

function jsonObjectCandidates(value: string): string[] {
  const trimmed = value.trim();
  const candidates: string[] = [stripJsonFence(trimmed), trimmed];
  const fencePattern = /```(?:json)?\s*([\s\S]*?)\s*```/gi;
  for (const match of trimmed.matchAll(fencePattern)) {
    candidates.push(match[1].trim());
  }
  const balanced = firstBalancedJsonObject(trimmed);
  if (balanced !== null) {
    candidates.push(balanced);
  }
  return candidates.filter((candidate, index) =>
    candidate !== "" && candidates.indexOf(candidate) === index
  );
}

function firstBalancedJsonObject(value: string): string | null {
  const start = value.indexOf("{");
  if (start < 0) {
    return null;
  }
  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let index = start; index < value.length; index += 1) {
    const char = value[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char === "\\") {
        escaped = true;
      } else if (char === '"') {
        inString = false;
      }
      continue;
    }
    if (char === '"') {
      inString = true;
    } else if (char === "{") {
      depth += 1;
    } else if (char === "}") {
      depth -= 1;
      if (depth === 0) {
        return value.slice(start, index + 1);
      }
    }
  }
  return null;
}
