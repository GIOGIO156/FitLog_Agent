import type { Phase5ContextBundle, Phase5Evidence } from "./phase5_types.ts";
import type { TaskPlanV1 } from "./planning/task_plan_contract.ts";
import { validateGroundedText } from "./grounding/faithfulness_guard.ts";
import {
  type ExpectedOutput,
  type GatewayDraft,
  type ParsedProviderGatewayBody,
  type ProviderOutputType,
  OutputContractError,
  parseProviderGatewayEnvelope,
} from "../_shared/ai_output_contract.ts";
import {
  explicitFoodFactsFromText,
  validateFoodSemantics,
} from "../_shared/food_capability.ts";
import {
  type DateResolutionSource,
  isValidDateKey,
} from "./record_date_resolver.ts";

export type {
  ExpectedOutput,
  FoodDraft,
  FoodDraftItem,
  GatewayDraft,
  ParsedProviderGatewayBody,
  ProviderOutputType,
  WorkoutDraft,
  WorkoutDraftExercise,
  WorkoutDraftSet,
} from "../_shared/ai_output_contract.ts";

export type AiGatewayErrorCode =
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

export type AiGatewayStatus = "ok" | "blocked" | "error" | "timeout";

export type ModelChoice = "chatgpt" | "qwen";

export type WorkflowType =
  | "auto"
  | "food_logging"
  | "workout_logging"
  | "meal_decision"
  | "weekly_review"
  | "app_logic_answer"
  | "general_chat"
  | "safety_boundary";

export interface GatewayRequest {
  sessionId: string | null;
  messageText: string;
  language: "zh" | "en";
  modelChoice: ModelChoice;
  workflowType: WorkflowType;
  attachments: GatewayImageAttachment[];
  selectedDate: string | null;
  targetDate: string | null;
  dateResolutionSource: DateResolutionSource;
  clientDraftSchemaVersion: "v1" | "v2" | "v3";
  profileVersion: string | null;
  deviceId: string;
  allowRecordSummaryContext: boolean;
  conversationContext: GatewayConversationContext | null;
  exerciseReferences?: GatewayExerciseReference[];
  phase5Context: Phase5ContextBundle | null;
  taskPlan?: TaskPlanV1 | null;
  expectedOutput: ExpectedOutput;
}

export interface GatewayImageAttachment {
  kind: "image";
  mimeType: "image/jpeg" | "image/png" | "image/webp";
  base64Data: string;
  byteLength: number;
  name: string | null;
}

export interface GatewayExerciseReference {
  key: string;
  name: string;
  definitionHash: string;
  exerciseType: "strength" | "cardio";
  bodyPart: string;
  strengthStructure: string;
  strengthProfile: string;
  loadInputMode: "total_load" | "per_side_load" | "bodyweight_added" | "assistance_load";
  repsInputMode: "total_reps" | "per_side_reps";
  setMetricType: "reps" | "duration_seconds";
}

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

export interface PersistedTurn {
  requestId: string;
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
  "workout_logging",
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
const supportedImageMimeTypes = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
]);
const maxImageAttachments = 3;
const maxImageBytes = 4 * 1024 * 1024;
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function parseGatewayRequest(value: unknown): GatewayRequest {
  const body = objectOrThrow(value);

  for (const field of unsupportedFutureFields) {
    if (field in body) {
      throw new GatewayRequestError("request_schema_mismatch");
    }
  }

  const message = objectOrThrow(body.message);
  const messageText = stringOrEmpty(message.text).trim();
  const attachments = parseAttachments(body.attachments);
  if (
    (messageText.length === 0 && attachments.length === 0) ||
    messageText.length > 4000
  ) {
    throw new GatewayRequestError("request_schema_mismatch");
  }

  const language = stringOrEmpty(body.language).trim();
  if (!languages.has(language)) {
    throw new GatewayRequestError("request_schema_mismatch");
  }

  const modelChoice = stringOrEmpty(body.model_choice).trim();
  if (!modelChoices.has(modelChoice as ModelChoice)) {
    throw new GatewayRequestError("request_schema_mismatch");
  }
  const workflowType = stringOrEmpty(body.workflow_hint || "auto").trim();
  if (!workflows.has(workflowType as WorkflowType)) {
    throw new GatewayRequestError("request_schema_mismatch");
  }

  const deviceId = stringOrEmpty(body.device_id).trim();
  if (deviceId.length === 0) {
    throw new GatewayRequestError("request_schema_mismatch");
  }

  const sessionId = nullableString(body.session_id);
  if (sessionId !== null && !uuidPattern.test(sessionId)) {
    throw new GatewayRequestError("request_schema_mismatch");
  }

  const selectedDate = nullableString(body.selected_date);
  if (selectedDate !== null && !isValidDateKey(selectedDate)) {
    throw new GatewayRequestError("request_schema_mismatch");
  }

  const client = body.client === undefined || body.client === null
    ? {}
    : objectOrThrow(body.client);
  const clientDraftSchemaVersion = stringOrEmpty(
    client.draft_schema_version || "v1",
  ).trim();
  if (
    clientDraftSchemaVersion !== "v1" && clientDraftSchemaVersion !== "v2" && clientDraftSchemaVersion !== "v3"
  ) {
    throw new GatewayRequestError("request_schema_mismatch");
  }

  return {
    sessionId,
    messageText,
    language: language as "zh" | "en",
    modelChoice: modelChoice as ModelChoice,
    workflowType: workflowType as WorkflowType,
    attachments,
    selectedDate,
    targetDate: null,
    dateResolutionSource: "unresolved",
    clientDraftSchemaVersion,
    profileVersion: nullableString(body.profile_version),
    deviceId,
    allowRecordSummaryContext: body.allow_record_summary_context === true,
    conversationContext: parseConversationContext(body.conversation_context),
    exerciseReferences: parseExerciseReferences(body.exercise_references),
    phase5Context: null,
    taskPlan: null,
    expectedOutput: "auto",
  };
}

function parseExerciseReferences(value: unknown): GatewayExerciseReference[] {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value) || value.length > 4) throw new GatewayRequestError("request_schema_mismatch");
  const keys = new Set<string>();
  return value.map((item) => {
    const row = objectOrThrow(item);
    const key = stringOrEmpty(row.key).trim();
    const name = stringOrEmpty(row.name).trim();
    const definitionHash = stringOrEmpty(row.definition_hash).trim();
    const exerciseType = stringOrEmpty(row.exercise_type).trim();
    const loadInputMode = stringOrEmpty(row.load_input_mode).trim();
    const repsInputMode = stringOrEmpty(row.reps_input_mode).trim();
    const setMetricType = stringOrEmpty(row.set_metric_type).trim();
    if (!/^[a-z0-9][a-z0-9_-]{0,79}$/i.test(key) || name === "" || name.length > 120 || !/^[a-f0-9]{8,64}$/i.test(definitionHash) || !["strength", "cardio"].includes(exerciseType) || !["total_load", "per_side_load", "bodyweight_added", "assistance_load"].includes(loadInputMode) || !["total_reps", "per_side_reps"].includes(repsInputMode) || !["reps", "duration_seconds"].includes(setMetricType) || keys.has(key)) {
      throw new GatewayRequestError("request_schema_mismatch");
    }
    keys.add(key);
    return {
      key,
      name,
      definitionHash,
      exerciseType: exerciseType as GatewayExerciseReference["exerciseType"],
      bodyPart: stringOrEmpty(row.body_part).trim().slice(0, 80),
      strengthStructure: stringOrEmpty(row.strength_structure).trim().slice(0, 80),
      strengthProfile: stringOrEmpty(row.strength_profile).trim().slice(0, 80),
      loadInputMode: loadInputMode as GatewayExerciseReference["loadInputMode"],
      repsInputMode: repsInputMode as GatewayExerciseReference["repsInputMode"],
      setMetricType: setMetricType as GatewayExerciseReference["setMetricType"],
    };
  });
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
  outputType?: ProviderOutputType | null;
  draft?: GatewayDraft | Record<string, unknown> | null;
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
    output_type: params.outputType ?? null,
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
  const parsed = parseProviderGatewayEnvelope(
    content,
    request.expectedOutput,
    request.targetDate,
  );
  validateWorkoutBindings(parsed, request);
  if (parsed.outputType === "food_draft" && parsed.draft?.schema_version === "food_draft.v2") {
    const issues = validateFoodSemantics({
      draft: parsed.draft,
      responseLanguage: request.language,
      understanding: explicitFoodFactsFromText(request.messageText),
    });
    if (issues.length > 0) throw new OutputContractError(issues);
  }
  if (request.taskPlan != null && parsed.outputType === "text") {
    const issues = validateGroundedText(parsed.messageText, request);
    if (issues.length > 0) throw new OutputContractError(issues);
  }
  return parsed;
}

function validateWorkoutBindings(parsed: ParsedProviderGatewayBody, request: GatewayRequest): void {
  if (parsed.outputType !== "workout_draft" || parsed.draft?.schema_version !== "workout_draft.v3") return;
  const registry = new Map<string, Record<string, unknown>>();
  for (const context of request.phase5Context?.context_objects ?? []) {
    if (context.type !== "exercise_definition") continue;
    const key = typeof context.data.key === "string" ? context.data.key : "";
    if (key !== "") registry.set(key, context.data);
  }
  const issues: { path: string; reason: string }[] = [];
  for (let index = 0; index < parsed.draft.exercises.length; index += 1) {
    const exercise = parsed.draft.exercises[index];
    const definition = registry.get(exercise.exercise_key);
    const path = `$.draft.exercises[${index}]`;
    if (definition === undefined) {
      issues.push({ path: `${path}.exercise_key`, reason: "exercise key is not in approved definition context" });
      continue;
    }
    for (const [field, expected] of [
      ["definition_hash", exercise.definition_hash],
      ["source", exercise.exercise_source],
      ["exercise_type", exercise.exercise_type],
      ["body_part", exercise.body_part],
      ["load_input_mode", exercise.load_input_mode],
      ["reps_input_mode", exercise.reps_input_mode],
      ["set_metric_type", exercise.set_metric_type],
    ] as const) {
      if (definition[field] !== expected) issues.push({ path: `${path}.${field}`, reason: "does not match approved exercise definition" });
    }
  }
  if (issues.length > 0) throw new OutputContractError(issues);
}

function parseConversationContext(
  value: unknown,
): GatewayConversationContext | null {
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
    throw new GatewayRequestError("request_schema_mismatch");
  }
  return value.map((item) => {
    const map = objectOrThrow(item);
    const role = stringOrEmpty(map.role).trim();
    const text = stringOrEmpty(map.text).trim();
    if (
      (role !== "user" && role !== "assistant") || text === "" ||
      text.length > 900
    ) {
      throw new GatewayRequestError("request_schema_mismatch");
    }
    return { role: role as "user" | "assistant", text };
  });
}

function parseArtifactSummaries(value: unknown): GatewayArtifactSummary[] {
  if (value === undefined || value === null) {
    return [];
  }
  if (!Array.isArray(value) || value.length > 4) {
    throw new GatewayRequestError("request_schema_mismatch");
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
      throw new GatewayRequestError("request_schema_mismatch");
    }
    return { type: type as "food_draft" | "workout_draft", title, summary };
  });
}

export function estimateTokens(
  userText: string,
  assistantText: string,
): number {
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
    case "request_schema_mismatch":
      return "The AI request is not supported by this version.";
    case "provider_output_invalid":
      return "The AI response could not be validated. Please try again.";
    case "provider_refusal":
      return "The AI provider declined this request.";
    case "provider_incomplete":
      return "The AI response ended before it was complete. Please try again.";
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
    throw new GatewayRequestError("request_schema_mismatch");
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
    throw new GatewayRequestError("request_schema_mismatch");
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
      throw new GatewayRequestError("request_schema_mismatch");
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

function numberOrNaN(value: unknown): number {
  return typeof value === "number" ? value : Number.parseInt(String(value), 10);
}

function base64UrlDecode(value: string): string {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const paddingLength = (4 - (normalized.length % 4)) % 4;
  return atob(normalized + "=".repeat(paddingLength));
}
