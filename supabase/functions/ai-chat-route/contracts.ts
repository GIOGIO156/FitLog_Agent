import type {
  Phase5ContextBundle,
  Phase5Evidence,
} from "./phase5_types.ts";

export type AiGatewayErrorCode =
  | "auth_required"
  | "subscription_required"
  | "device_replaced"
  | "gateway_timeout"
  | "provider_failure"
  | "record_schema_mismatch";

export type AiGatewayStatus = "ok" | "blocked" | "error" | "timeout";

export type ModelChoice = "chatgpt" | "qwen";

export type WorkflowType =
  | "auto"
  | "food_logging"
  | "meal_decision"
  | "weekly_review"
  | "app_logic_answer";

export interface GatewayRequest {
  sessionId: string | null;
  messageText: string;
  language: "zh" | "en";
  modelChoice: ModelChoice;
  workflowType: WorkflowType;
  attachments: GatewayImageAttachment[];
  selectedDate: string | null;
  profileVersion: string | null;
  deviceId: string;
  allowRecordSummaryContext: boolean;
  conversationContext: GatewayConversationContext | null;
  phase5Context: Phase5ContextBundle | null;
}

export interface GatewayImageAttachment {
  kind: "image";
  mimeType: "image/jpeg" | "image/png" | "image/webp";
  base64Data: string;
  byteLength: number;
  name: string | null;
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

export interface WorkoutDraft {
  schema_version: "workout_draft.v1";
  record_name: string;
  date: string | null;
  notes: string;
  exercises: WorkoutDraftExercise[];
}

export interface WorkoutDraftExercise {
  exercise_name: string;
  exercise_key: string | null;
  exercise_type: "strength" | "cardio" | null;
  body_part: string | null;
  duration_minutes: number | null;
  active_duration_minutes: number | null;
  cardio_intensity_basis: string | null;
  sets: WorkoutDraftSet[];
}

export interface WorkoutDraftSet {
  weight_kg: number | null;
  reps: number | null;
  duration_seconds: number | null;
}

export type GatewayDraft = FoodDraft | WorkoutDraft;

export interface GatewayConversationContext {
  messages: GatewayContextMessage[];
  artifacts: GatewayArtifactSummary[];
}

export interface GatewayContextMessage {
  role: "user" | "assistant";
  text: string;
}

export interface GatewayArtifactSummary {
  type: "food_draft" | "workout_draft";
  title: string;
  summary: string;
}

export interface ParsedProviderGatewayBody {
  messageText: string;
  draft: GatewayDraft | null;
  needsClarification: boolean;
  clarificationQuestions: string[];
}

export interface PersistedTurn {
  sessionId: string;
  assistantMessageId: string;
  debugSummaryId: string;
}

export interface GatewayErrorBody {
  code: AiGatewayErrorCode;
  message: string;
}

export class GatewayRequestError extends Error {
  readonly code: AiGatewayErrorCode;
  readonly status: number;

  constructor(code: AiGatewayErrorCode, status = 422) {
    super(code);
    this.code = code;
    this.status = status;
  }
}

const modelChoices = new Set<ModelChoice>(["chatgpt", "qwen"]);
const workflows = new Set<WorkflowType>([
  "auto",
  "food_logging",
  "meal_decision",
  "weekly_review",
  "app_logic_answer",
]);
const languages = new Set(["zh", "en"]);
const unsupportedFutureFields = [
  "context_objects",
  "draft",
  "evidence",
  "official_record_write",
  "phase5_context",
  "rag_context",
  "tool_calls",
];
const supportedImageMimeTypes = new Set(["image/jpeg", "image/png", "image/webp"]);
const maxImageAttachments = 3;
const maxImageBytes = 4 * 1024 * 1024;
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function parseGatewayRequest(value: unknown): GatewayRequest {
  const body = objectOrThrow(value);

  for (const field of unsupportedFutureFields) {
    if (field in body) {
      throw new GatewayRequestError("record_schema_mismatch");
    }
  }

  const message = objectOrThrow(body.message);
  const messageText = stringOrEmpty(message.text).trim();
  const attachments = parseAttachments(body.attachments);
  if (
    (messageText.length === 0 && attachments.length === 0) ||
    messageText.length > 4000
  ) {
    throw new GatewayRequestError("record_schema_mismatch");
  }

  const language = stringOrEmpty(body.language).trim();
  if (!languages.has(language)) {
    throw new GatewayRequestError("record_schema_mismatch");
  }

  const modelChoice = stringOrEmpty(body.model_choice).trim();
  if (!modelChoices.has(modelChoice as ModelChoice)) {
    throw new GatewayRequestError("record_schema_mismatch");
  }
  if (attachments.length > 0 && modelChoice !== "qwen") {
    throw new GatewayRequestError("record_schema_mismatch");
  }

  const workflowType = stringOrEmpty(body.workflow_hint || "auto").trim();
  if (!workflows.has(workflowType as WorkflowType)) {
    throw new GatewayRequestError("record_schema_mismatch");
  }

  const deviceId = stringOrEmpty(body.device_id).trim();
  if (deviceId.length === 0) {
    throw new GatewayRequestError("record_schema_mismatch");
  }

  const sessionId = nullableString(body.session_id);
  if (sessionId !== null && !uuidPattern.test(sessionId)) {
    throw new GatewayRequestError("record_schema_mismatch");
  }

  return {
    sessionId,
    messageText,
    language: language as "zh" | "en",
    modelChoice: modelChoice as ModelChoice,
    workflowType: workflowType as WorkflowType,
    attachments,
    selectedDate: nullableString(body.selected_date),
    profileVersion: nullableString(body.profile_version),
    deviceId,
    allowRecordSummaryContext: body.allow_record_summary_context === true,
    conversationContext: parseConversationContext(body.conversation_context),
    phase5Context: null,
  };
}

export function extractBearerToken(header: string | null): string | null {
  if (header === null) {
    return null;
  }
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  return match?.[1]?.trim() || null;
}

export function extractSessionIdFromAccessToken(token: string): string | null {
  const parts = token.split(".");
  if (parts.length < 2) {
    return null;
  }

  try {
    const payload = JSON.parse(base64UrlDecode(parts[1]));
    if (!isRecord(payload)) {
      return null;
    }
    return nullableString(payload.session_id) ??
      nullableString(payload.sid) ??
      nullableString(payload.jti);
  } catch (_) {
    return null;
  }
}

export function gatewayResponse(params: {
  sessionId?: string | null;
  assistantMessageId?: string | null;
  modelChoice?: ModelChoice | null;
  modelProvider?: string | null;
  messageText?: string | null;
  language?: string | null;
  workflow?: WorkflowType | string | null;
  draft?: GatewayDraft | null;
  needsClarification?: boolean;
  clarificationQuestions?: string[];
  debugSummaryId?: string | null;
  evidence?: Phase5Evidence | null;
  error?: GatewayErrorBody | null;
}): Record<string, unknown> {
  return {
    session_id: params.sessionId ?? null,
    assistant_message_id: params.assistantMessageId ?? null,
    model_choice: params.modelChoice ?? null,
    model_provider: params.modelProvider ?? null,
    message: {
      ...(params.messageText ? { text: params.messageText } : {}),
      language: params.language ?? "zh",
    },
    workflow: params.workflow ?? "auto",
    needs_clarification: params.needsClarification ?? false,
    clarification_questions: params.clarificationQuestions ?? [],
    draft: params.draft ?? null,
    evidence: params.evidence ?? null,
    error: params.error ?? null,
    debug_summary_id: params.debugSummaryId ?? null,
  };
}

export function parseProviderGatewayBody(
  content: string,
  request: GatewayRequest,
): ParsedProviderGatewayBody {
  const root = parseJsonObjectFromContent(content);
  if (root === null) {
    return {
      messageText: content.trim(),
      draft: null,
      needsClarification: false,
      clarificationQuestions: [],
    };
  }

  const messageMap = isRecord(root.message) ? root.message : {};
  const rawDraft = isRecord(root.draft)
    ? root.draft
    : root.schema_version === "workout_draft.v1" || "meal_name" in root
    ? root
    : null;
  const draft = rawDraft === null ? null : validateDraft(rawDraft);
  const messageText = (
    stringOrEmpty(messageMap.text) ||
    stringOrEmpty(root.message_text) ||
    (draft === null
      ? fallbackImageMessage(request.language)
      : fallbackDraftMessage(request.language, draft))
  ).trim();
  const needsClarification = root.needs_clarification === true;
  const clarificationQuestions = stringList(root.clarification_questions);

  if (messageText === "" && draft === null && !needsClarification) {
    throw new Error("record_schema_mismatch");
  }

  return {
    messageText,
    draft,
    needsClarification,
    clarificationQuestions,
  };
}

function parseConversationContext(value: unknown): GatewayConversationContext | null {
  if (value === undefined || value === null) {
    return null;
  }
  const context = objectOrThrow(value);
  const messages = parseContextMessages(context.messages);
  const artifacts = parseArtifactSummaries(context.artifacts);
  if (messages.length === 0 && artifacts.length === 0) {
    return null;
  }
  return { messages, artifacts };
}

function parseContextMessages(value: unknown): GatewayContextMessage[] {
  if (value === undefined || value === null) {
    return [];
  }
  if (!Array.isArray(value) || value.length > 8) {
    throw new GatewayRequestError("record_schema_mismatch");
  }
  return value.map((item) => {
    const map = objectOrThrow(item);
    const role = stringOrEmpty(map.role).trim();
    const text = stringOrEmpty(map.text).trim();
    if ((role !== "user" && role !== "assistant") || text === "" || text.length > 900) {
      throw new GatewayRequestError("record_schema_mismatch");
    }
    return { role: role as "user" | "assistant", text };
  });
}

function parseArtifactSummaries(value: unknown): GatewayArtifactSummary[] {
  if (value === undefined || value === null) {
    return [];
  }
  if (!Array.isArray(value) || value.length > 4) {
    throw new GatewayRequestError("record_schema_mismatch");
  }
  return value.map((item) => {
    const map = objectOrThrow(item);
    const type = stringOrEmpty(map.type).trim();
    const title = stringOrEmpty(map.title).trim();
    const summary = stringOrEmpty(map.summary).trim();
    if (
      (type !== "food_draft" && type !== "workout_draft") ||
      title === "" ||
      title.length > 120 ||
      summary.length > 240
    ) {
      throw new GatewayRequestError("record_schema_mismatch");
    }
    return { type: type as "food_draft" | "workout_draft", title, summary };
  });
}

function validateDraft(value: Record<string, unknown>): GatewayDraft {
  if (value.schema_version === "workout_draft.v1") {
    return validateWorkoutDraft(value);
  }
  return validateFoodDraft(value);
}

export function estimateTokens(userText: string, assistantText: string): number {
  return Math.ceil((userText.length + assistantText.length) / 4);
}

export function stringField(value: unknown, key: string): string {
  if (typeof value === "object" && value !== null && !Array.isArray(value)) {
    const raw = (value as Record<string, unknown>)[key];
    if (typeof raw === "string" && raw.trim() !== "") {
      return raw;
    }
  }
  throw new Error(`Missing string field: ${key}`);
}

export function errorMessageForCode(code: AiGatewayErrorCode): string {
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
      return "The AI request is not supported by this version.";
  }
}

export function logStatusForCode(code: AiGatewayErrorCode): AiGatewayStatus {
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

function objectOrThrow(value: unknown): Record<string, unknown> {
  if (!isRecord(value)) {
    throw new GatewayRequestError("record_schema_mismatch");
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

function parseAttachments(value: unknown): GatewayImageAttachment[] {
  if (value === undefined || value === null) {
    return [];
  }
  if (!Array.isArray(value) || value.length > maxImageAttachments) {
    throw new GatewayRequestError("record_schema_mismatch");
  }
  return value.map((item) => {
    const image = objectOrThrow(item);
    const kind = stringOrEmpty(image.kind).trim();
    const mimeType = stringOrEmpty(image.mime_type).trim();
    const base64Data = stringOrEmpty(image.base64_data).trim();
    const byteLength = numberOrNaN(image.byte_length);
    if (
      kind !== "image" ||
      !supportedImageMimeTypes.has(mimeType) ||
      base64Data === "" ||
      !Number.isInteger(byteLength) ||
      byteLength <= 0 ||
      byteLength > maxImageBytes
    ) {
      throw new GatewayRequestError("record_schema_mismatch");
    }
    return {
      kind: "image",
      mimeType: mimeType as "image/jpeg" | "image/png" | "image/webp",
      base64Data,
      byteLength,
      name: nullableString(image.name),
    };
  });
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
      : nonNegativeFiniteNumber(value.confidence),
    estimation_notes: stringOrEmpty(value.estimation_notes).trim(),
    items,
  };
}

function validateWorkoutDraft(value: Record<string, unknown>): WorkoutDraft {
  const recordName = stringOrEmpty(value.record_name).trim();
  const exercises = workoutDraftExercises(value.exercises);
  if (recordName === "" || exercises.length === 0) {
    throw new Error("record_schema_mismatch");
  }
  return {
    schema_version: "workout_draft.v1",
    record_name: recordName,
    date: validDateOrNull(value.date),
    notes: stringOrEmpty(value.notes).trim(),
    exercises,
  };
}

function workoutDraftExercises(value: unknown): WorkoutDraftExercise[] {
  if (!Array.isArray(value) || value.length === 0) {
    throw new Error("record_schema_mismatch");
  }
  return value.map((item) => {
    const map = recordOrThrow(item);
    const exerciseName = stringOrEmpty(map.exercise_name).trim();
    if (exerciseName === "") {
      throw new Error("record_schema_mismatch");
    }
    return {
      exercise_name: exerciseName,
      exercise_key: nullableString(map.exercise_key),
      exercise_type: workoutExerciseTypeOrNull(map.exercise_type),
      body_part: nullableString(map.body_part),
      duration_minutes: nullableNonNegativeFiniteNumber(map.duration_minutes),
      active_duration_minutes: nullableNonNegativeFiniteNumber(
        map.active_duration_minutes,
      ),
      cardio_intensity_basis: nullableString(map.cardio_intensity_basis),
      sets: workoutDraftSets(map.sets),
    };
  });
}

function workoutDraftSets(value: unknown): WorkoutDraftSet[] {
  if (value === undefined || value === null) {
    return [];
  }
  if (!Array.isArray(value)) {
    throw new Error("record_schema_mismatch");
  }
  return value.map((item) => {
    const map = recordOrThrow(item);
    return {
      weight_kg: nullableNonNegativeFiniteNumber(map.weight_kg),
      reps: nullableNonNegativeInteger(map.reps),
      duration_seconds: nullableNonNegativeInteger(map.duration_seconds),
    };
  });
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
  if (value === null || value === undefined || value === "") {
    return null;
  }
  return nonNegativeFiniteNumber(value);
}

function nullableNonNegativeInteger(value: unknown): number | null {
  const parsed = nullableNonNegativeFiniteNumber(value);
  if (parsed === null) {
    return null;
  }
  if (!Number.isInteger(parsed)) {
    throw new Error("record_schema_mismatch");
  }
  return parsed;
}

function workoutExerciseTypeOrNull(value: unknown): "strength" | "cardio" | null {
  const text = nullableString(value);
  if (text === null) {
    return null;
  }
  if (text !== "strength" && text !== "cardio") {
    throw new Error("record_schema_mismatch");
  }
  return text;
}

function validDateOrNull(value: unknown): string | null {
  const text = nullableString(value);
  if (text === null) {
    return null;
  }
  return /^\d{4}-\d{2}-\d{2}$/.test(text) ? text : null;
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

function fallbackImageMessage(language: "zh" | "en"): string {
  return language === "zh"
    ? "我已分析本次图片。"
    : "I analyzed the images in this request.";
}

function fallbackDraftMessage(language: "zh" | "en", draft: GatewayDraft): string {
  const isWorkoutDraft = "schema_version" in draft &&
    draft.schema_version === "workout_draft.v1";
  if (language === "zh") {
    return isWorkoutDraft
      ? "已生成训练草稿，请确认后再保存。"
      : "已生成饮食草稿，请确认后再保存。";
  }
  return isWorkoutDraft
    ? "I created a workout draft for your review."
    : "I created a food draft for your review.";
}

function stripJsonFence(value: string): string {
  const trimmed = value.trim();
  const fence = /^```(?:json)?\s*([\s\S]*?)\s*```$/i.exec(trimmed);
  return fence?.[1]?.trim() ?? trimmed;
}

function parseJsonObjectFromContent(value: string): Record<string, unknown> | null {
  let fallback: Record<string, unknown> | null = null;
  for (const candidate of jsonObjectCandidates(value)) {
    try {
      const parsed = JSON.parse(candidate);
      if (isRecord(parsed)) {
        fallback ??= parsed;
        if (isProviderGatewayShape(parsed)) {
          return parsed;
        }
      }
    } catch (_) {
      // Try the next candidate.
    }
  }
  return fallback;
}

function isProviderGatewayShape(value: Record<string, unknown>): boolean {
  return isRecord(value.message) ||
    isRecord(value.draft) ||
    value.schema_version === "workout_draft.v1" ||
    "meal_name" in value;
}

function jsonObjectCandidates(value: string): string[] {
  const trimmed = value.trim();
  const candidates: string[] = [stripJsonFence(trimmed), trimmed];
  const fencePattern = /```(?:json)?\s*([\s\S]*?)\s*```/gi;
  for (const match of trimmed.matchAll(fencePattern)) {
    candidates.push(match[1].trim());
  }
  for (const balanced of balancedJsonObjects(trimmed)) {
    candidates.push(balanced);
  }
  return candidates.filter((candidate, index) =>
    candidate !== "" && candidates.indexOf(candidate) === index
  );
}

function balancedJsonObjects(value: string): string[] {
  const candidates: string[] = [];
  let start = value.indexOf("{");
  while (start >= 0) {
    const candidate = balancedJsonObjectFrom(value, start);
    if (candidate !== null) {
      candidates.push(candidate);
    }
    start = value.indexOf("{", start + 1);
  }
  return candidates;
}

function balancedJsonObjectFrom(value: string, start: number): string | null {
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

function base64UrlDecode(value: string): string {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const paddingLength = (4 - (normalized.length % 4)) % 4;
  return atob(normalized + "=".repeat(paddingLength));
}
