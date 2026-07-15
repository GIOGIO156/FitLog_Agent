import {
  foodAnalysisEnvelopeJsonSchema,
  type FoodDraft,
  type OutputValidationIssue,
  parseFoodAnalysisEnvelope,
} from "../_shared/ai_output_contract.ts";
import {
  buildFoodCapabilityRequest,
  explicitFoodFactsFromText,
} from "../_shared/food_capability.ts";

export type {
  FoodDraft,
  FoodDraftItem,
} from "../_shared/ai_output_contract.ts";

export type PhotoGatewayErrorCode =
  | "auth_required"
  | "subscription_required"
  | "device_replaced"
  | "gateway_timeout"
  | "provider_failure"
  | "request_schema_mismatch"
  | "provider_output_invalid"
  | "provider_refusal"
  | "provider_incomplete"
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
  modelChoice: "chatgpt" | "qwen";
  deviceId: string;
  selectedDate: string;
  schemaVersion: "food_draft.v1" | "food_draft.v2";
  userNote: string | null;
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
      throw new PhotoGatewayRequestError("request_schema_mismatch");
    }
  }

  const userNote = nullableString(body.user_note);
  const images = parseImages(body, userNote);

  const language = stringOrEmpty(body.language).trim();
  if (language !== "zh" && language !== "en") {
    throw new PhotoGatewayRequestError("request_schema_mismatch");
  }

  const modelChoice = stringOrEmpty(body.model_choice).trim();
  if (modelChoice !== "qwen" && modelChoice !== "chatgpt") {
    throw new PhotoGatewayRequestError("request_schema_mismatch");
  }

  const requestedSchemaVersion = stringOrEmpty(body.schema_version).trim();
  if (
    requestedSchemaVersion !== "food_draft.v1" &&
    requestedSchemaVersion !== "food_draft.v2"
  ) {
    throw new PhotoGatewayRequestError("request_schema_mismatch");
  }

  const deviceId = stringOrEmpty(body.device_id).trim();
  const selectedDate = stringOrEmpty(body.selected_date).trim();
  if (deviceId === "" || !isValidDateKey(selectedDate)) {
    throw new PhotoGatewayRequestError("request_schema_mismatch");
  }

  return {
    images,
    language,
    modelChoice,
    deviceId,
    selectedDate,
    schemaVersion: requestedSchemaVersion,
    userNote,
  };
}

export function buildQwenVisionRequestBody(params: {
  request: PhotoAnalysisRequest;
  model: string;
  correction?: {
    previousOutput: string;
    issues: OutputValidationIssue[];
  };
}): Record<string, unknown> {
  const request = params.request;
  const correction = params.correction;
  return {
    model: params.model,
    enable_thinking: false,
    max_tokens: 1200,
    response_format: { type: "json_object" },
    messages: [
      {
        role: "system",
        content: systemPrompt(request.language),
      },
      {
        role: "user",
        content: correction === undefined
          ? [
            { type: "text", text: userPrompt(request) },
            ...request.images.map((image) => ({
              type: "image_url",
              image_url: {
                url: `data:${image.mimeType};base64,${image.base64Data}`,
              },
            })),
          ]
          : correctionPrompt(correction, request),
      },
    ],
  };
}

export interface QwenFoodCompletion {
  status: "completed" | "refusal" | "incomplete";
  content: string;
  finishReason: string | null;
}

export type FoodProviderCompletion = QwenFoodCompletion;

export function buildOpenAiVisionRequestBody(params: {
  request: PhotoAnalysisRequest;
  model: string;
  correction?: { previousOutput: string; issues: OutputValidationIssue[] };
}): Record<string, unknown> {
  const content = params.correction === undefined
    ? [
      { type: "input_text", text: userPrompt(params.request) },
      ...params.request.images.map((image) => ({
        type: "input_image",
        image_url: `data:${image.mimeType};base64,${image.base64Data}`,
      })),
    ]
    : [{
      type: "input_text",
      text: correctionPrompt(params.correction, params.request),
    }];
  return {
    model: params.model,
    instructions: systemPrompt(params.request.language),
    input: [{ role: "user", content }],
    text: {
      format: {
        type: "json_schema",
        name: "fitlog_food_analysis_envelope",
        strict: true,
        schema: foodAnalysisEnvelopeJsonSchema,
      },
    },
  };
}

export function extractOpenAiVisionCompletion(
  body: unknown,
): FoodProviderCompletion {
  const map = recordOrThrow(body);
  if (map.status === "incomplete") {
    return {
      status: "incomplete",
      content: typeof map.output_text === "string" ? map.output_text : "",
      finishReason: "incomplete",
    };
  }
  if (typeof map.output_text === "string" && map.output_text.trim() !== "") {
    return {
      status: "completed",
      content: map.output_text.trim(),
      finishReason: "stop",
    };
  }
  const output = map.output;
  if (Array.isArray(output)) {
    for (const item of output) {
      const record = recordOrThrow(item);
      const content = record.content;
      if (!Array.isArray(content)) continue;
      for (const part of content) {
        const value = recordOrThrow(part);
        if (value.type === "refusal") {
          return { status: "refusal", content: "", finishReason: "refusal" };
        }
        if (typeof value.text === "string" && value.text.trim() !== "") {
          return {
            status: "completed",
            content: value.text.trim(),
            finishReason: "stop",
          };
        }
      }
    }
  }
  throw new Error("provider_failure");
}

export function extractQwenCompletion(body: unknown): QwenFoodCompletion {
  const map = recordOrThrow(body);
  const choices = map.choices;
  if (!Array.isArray(choices) || choices.length === 0) {
    throw new Error("provider_failure");
  }
  const first = recordOrThrow(choices[0]);
  const message = recordOrThrow(first.message);
  const finishReason = typeof first.finish_reason === "string"
    ? first.finish_reason
    : null;
  if (finishReason === "length" || finishReason === "incomplete") {
    return {
      status: "incomplete",
      content: typeof message.content === "string" ? message.content : "",
      finishReason,
    };
  }
  if (
    finishReason === "content_filter" || typeof message.refusal === "string"
  ) {
    return {
      status: "refusal",
      content: "",
      finishReason: finishReason ?? "refusal",
    };
  }
  const content = message.content;
  if (typeof content !== "string" || content.trim() === "") {
    throw new Error("provider_failure");
  }
  return { status: "completed", content: content.trim(), finishReason };
}

export function parseProviderFoodDraftBody(
  content: string,
  selectedDate?: string,
): ParsedProviderFoodResponse {
  const parsed = parseFoodAnalysisEnvelope(content, selectedDate);
  return {
    draft: parsed.draft,
    needsClarification: parsed.needsClarification,
    clarificationQuestions: parsed.clarificationQuestions,
    schemaValidationStatus: parsed.needsClarification
      ? "needs_clarification"
      : "passed",
  };
}

export function photoGatewayResponse(params: {
  modelChoice?: "chatgpt" | "qwen" | null;
  modelProvider?: string | null;
  draft?: FoodDraft | Record<string, unknown> | null;
  needsClarification?: boolean;
  clarificationQuestions?: string[];
  debugSummaryId?: string | null;
  error?: { code: PhotoGatewayErrorCode; message: string } | null;
}): Record<string, unknown> {
  return {
    model_choice: params.modelChoice ?? "qwen",
    model_provider: params.modelProvider ?? params.modelChoice ?? "qwen",
    draft: params.draft ?? null,
    needs_clarification: params.needsClarification ?? false,
    clarification_questions: params.clarificationQuestions ?? [],
    debug_summary_id: params.debugSummaryId ?? null,
    error: params.error ?? null,
  };
}

export function foodDraftForClient(
  draft: FoodDraft | null,
  requestedSchemaVersion: PhotoAnalysisRequest["schemaVersion"],
): FoodDraft | Record<string, unknown> | null {
  if (draft === null || requestedSchemaVersion === "food_draft.v2") {
    return draft;
  }
  const legacy = { ...draft } as Record<string, unknown>;
  legacy.schema_version = "food_draft.v1";
  delete legacy.date;
  return legacy;
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
    case "request_schema_mismatch":
      return "The AI food analysis request is not supported.";
    case "provider_output_invalid":
      return "The AI food analysis result could not be validated. Please try again.";
    case "provider_refusal":
      return "The AI provider declined this request.";
    case "provider_incomplete":
      return "The AI food analysis ended before it was complete. Please try again.";
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
    '{"schema_version":"food_analysis_envelope.v1","needs_clarification":false,"clarification_questions":[],"draft":{"schema_version":"food_draft.v2","date":"2026-07-10","meal_name":"...","total_weight_g":0,"calories_kcal":0,"protein_g":0,"carbs_g":0,"fat_g":0,"confidence":0.0,"estimation_notes":"...","items":[{"name":"...","weight_g":0,"calories_kcal":0,"protein_g":0,"carbs_g":0,"fat_g":0}]}}',
    "When items is non-empty, item values are totals for that item portion, not per-100g values; draft meal totals must equal the sum of items.",
    clarificationInstruction,
    "Use finite non-negative numbers. Estimate honestly and keep notes brief.",
    `Food capability request: ${
      JSON.stringify(
        buildFoodCapabilityRequest(request.userNote ?? "", request.language),
      )
    }. Preserve higher-priority facts and use image/model estimates only for missing fields.`,
    `Image count: ${request.images.length}`,
    `Selected date: ${request.selectedDate}`,
    "Copy the selected date exactly into draft.date.",
    note,
  ].join("\n");
}

function isValidDateKey(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day;
}

function correctionPrompt(params: {
  previousOutput: string;
  issues: OutputValidationIssue[];
}, request: PhotoAnalysisRequest): string {
  const issues = params.issues
    .slice(0, 12)
    .map((item) => `${item.path}: ${item.reason}`)
    .join("; ");
  return [
    "Correct the previous food analysis response.",
    "Return exactly one food_analysis_envelope.v1 JSON object and no outside prose.",
    `Validation errors: ${issues}`,
    `Target language: ${request.language}. Selected date: ${request.selectedDate}.`,
    `Original normalized user facts: ${
      JSON.stringify(explicitFoodFactsFromText(request.userNote ?? ""))
    }`,
    `Previous response: ${params.previousOutput.slice(0, 12000)}`,
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
    throw new PhotoGatewayRequestError("request_schema_mismatch");
  }
  if (rawImages.length === 0) {
    if (userNote === null) {
      throw new PhotoGatewayRequestError("request_schema_mismatch");
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
      throw new PhotoGatewayRequestError("request_schema_mismatch");
    }
    return {
      mimeType: mimeType as "image/jpeg" | "image/png" | "image/webp",
      base64Data,
      byteLength,
    };
  });
}

function objectOrThrow(value: unknown): Record<string, unknown> {
  if (!isRecord(value)) {
    throw new PhotoGatewayRequestError("request_schema_mismatch");
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
