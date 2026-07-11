import type { Phase5ContextBundle, Phase5Evidence } from "./phase5_types.ts";
import {
  type ExpectedOutput,
  type GatewayDraft,
  type ParsedProviderGatewayBody,
  type ProviderOutputType,
  parseProviderGatewayEnvelope,
} from "../_shared/ai_output_contract.ts";

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
  expectedOutput: ExpectedOutput;
}

export interface GatewayImageAttachment {
  kind: "image";
  mimeType: "image/jpeg" | "image/png" | "image/webp";
  base64Data: string;
  byteLength: number;
  name: string | null;
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
  if (attachments.length > 0 && modelChoice !== "qwen") {
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
    expectedOutput: "auto",
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
  outputType?: ProviderOutputType | null;
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
  return parseProviderGatewayEnvelope(content, request.expectedOutput);
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
