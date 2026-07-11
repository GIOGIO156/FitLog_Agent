import type { GatewayRequest } from "./contracts.ts";
import { providerGatewayEnvelopeSchemaVersion } from "../_shared/ai_output_contract.ts";
import {
  answerLanguageInstruction,
  phase5PromptContext,
} from "./prompt_builder.ts";
import type {
  FetchLike,
  ProviderAdapter,
  ProviderCompletion,
  ProviderGenerationOptions,
} from "./providers.ts";
import { ProviderError } from "./providers.ts";

interface QwenProviderParams {
  apiKey: string;
  model: string;
  baseUrl: string;
  timeoutMs: number;
  fetchImpl: FetchLike;
}

export function createQwenProvider(
  params: QwenProviderParams,
): ProviderAdapter {
  const apiKey = params.apiKey.trim();
  const model = params.model.trim();
  const baseUrl = params.baseUrl.trim();
  if (apiKey === "" || model === "" || baseUrl === "") {
    throw new ProviderError("provider_failure");
  }

  return {
    providerId: "qwen",
    model,
    generateText(request, options) {
      return generateQwenText({
        ...params,
        apiKey,
        model,
        baseUrl,
        request,
        options,
      });
    },
  };
}

async function generateQwenText(
  params: QwenProviderParams & {
    apiKey: string;
    model: string;
    baseUrl: string;
    request: GatewayRequest;
    options?: ProviderGenerationOptions;
  },
): Promise<ProviderCompletion> {
  const controller = new AbortController();
  const timeout = setTimeout(
    () => controller.abort(),
    params.options?.timeoutMs ?? params.timeoutMs,
  );
  try {
    const response = await params.fetchImpl(params.baseUrl, {
      method: "POST",
      headers: {
        authorization: `Bearer ${params.apiKey}`,
        "content-type": "application/json",
      },
      signal: controller.signal,
      body: JSON.stringify(
        buildQwenRequestBody(params.request, params.model, params.options),
      ),
    });

    if (!response.ok) {
      throw new ProviderError("provider_failure");
    }

    const body = await response.json();
    return extractQwenCompletion(body);
  } catch (error) {
    if (error instanceof ProviderError) {
      throw error;
    }
    if (error instanceof DOMException && error.name === "AbortError") {
      throw new ProviderError("gateway_timeout");
    }
    throw new ProviderError("provider_failure");
  } finally {
    clearTimeout(timeout);
  }
}

export function extractQwenCompletion(body: unknown): ProviderCompletion {
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    throw new ProviderError("provider_failure");
  }
  const choices = (body as Record<string, unknown>).choices;
  if (!Array.isArray(choices) || choices.length === 0) {
    throw new ProviderError("provider_failure");
  }
  const first = choices[0];
  if (typeof first !== "object" || first === null || Array.isArray(first)) {
    throw new ProviderError("provider_failure");
  }
  const message = (first as Record<string, unknown>).message;
  if (
    typeof message !== "object" || message === null || Array.isArray(message)
  ) {
    throw new ProviderError("provider_failure");
  }
  const choice = first as Record<string, unknown>;
  const messageRecord = message as Record<string, unknown>;
  const finishReason = typeof choice.finish_reason === "string"
    ? choice.finish_reason
    : null;
  if (
    finishReason === "length" ||
    finishReason === "content_filter" ||
    finishReason === "incomplete"
  ) {
    return {
      status: finishReason === "content_filter" ? "refusal" : "incomplete",
      content: typeof messageRecord.content === "string"
        ? messageRecord.content
        : "",
      finishReason,
    };
  }
  if (typeof messageRecord.refusal === "string") {
    return { status: "refusal", content: "", finishReason: "refusal" };
  }
  const content = messageRecord.content;
  if (typeof content !== "string") {
    throw new ProviderError("provider_failure");
  }
  const text = content.trim();
  if (text === "") {
    throw new ProviderError("provider_failure");
  }
  return { status: "completed", content: text, finishReason };
}

function buildQwenRequestBody(
  request: GatewayRequest,
  model: string,
  options?: ProviderGenerationOptions,
): Record<string, unknown> {
  const hasImage = request.attachments.length > 0 &&
    options?.correction === undefined;
  return {
    model,
    enable_thinking: false,
    response_format: { type: "json_object" },
    messages: [
      {
        role: "system",
        content: systemMessage(request),
      },
      {
        role: "user",
        content: hasImage
          ? multimodalUserContent(request)
          : textUserPrompt(request, options),
      },
    ],
  };
}

function multimodalUserContent(
  request: GatewayRequest,
): Record<string, unknown>[] {
  return [
    { type: "text", text: multimodalUserPrompt(request) },
    ...request.attachments.map((image) => ({
      type: "image_url",
      image_url: {
        url: `data:${image.mimeType};base64,${image.base64Data}`,
      },
    })),
  ];
}

function systemMessage(request: GatewayRequest): string {
  const base = request.language === "zh"
    ? "你是 FitLog 的 AI 助手。只能使用本次服务端受控上下文、当前消息和当前请求图片；不能保存或修改正式记录、目标或策略。所有草稿必须由用户审核确认。"
    : "You are FitLog's AI assistant. Use only this request's server-controlled context, message, and images. Never save or modify official records, goals, or strategies. Every draft requires user review and confirmation.";
  return [
    base,
    `只返回一个 ${providerGatewayEnvelopeSchemaVersion} JSON 对象，JSON 外禁止任何文字或 Markdown 围栏。`,
    `Expected output: ${request.expectedOutput}. Markdown is allowed only in message.text.`,
    "If Expected output is auto, infer the user's natural intent from the message, images, and conversation context, then select exactly one output_type: text, food_draft, workout_draft, or clarification.",
    "output_type must match the payload. For text, draft must be null and message.text must not claim a draft was created. For a requested draft, return the exact draft type or one clarification with draft null. Never claim the result was saved.",
  ].join("\n");
}

function textUserPrompt(
  request: GatewayRequest,
  options?: ProviderGenerationOptions,
): string {
  return [
    phase5PromptContext(request),
    conversationContextPrompt(request),
    answerLanguageInstruction(request.language),
    "Return exactly one JSON object using this envelope; no fence or outside prose:",
    '{"schema_version":"provider_gateway_envelope.v2","output_type":"text","message":{"text":"Friendly user-facing Markdown."},"needs_clarification":false,"clarification_questions":[],"draft":null}',
    "Put all user-facing explanation, uncertainty, and review instructions inside message.text. The app displays message.text and renders draft as a native review card; never print the draft JSON as visible prose.",
    "Food Draft shape:",
    '{"schema_version":"food_draft.v1","meal_name":"...","total_weight_g":0,"calories_kcal":0,"protein_g":0,"carbs_g":0,"fat_g":0,"confidence":0.0,"estimation_notes":"...","items":[{"name":"...","weight_g":0,"calories_kcal":0,"protein_g":0,"carbs_g":0,"fat_g":0}]}',
    "When Food Draft items is non-empty, item values are totals for that item portion, not per-100g values; meal-level total_weight_g, calories_kcal, protein_g, carbs_g, and fat_g must equal the sum of items.",
    "Workout Draft shape:",
    '{"schema_version":"workout_draft.v1","record_name":"...","date":null,"notes":"...","exercises":[{"exercise_name":"Bench Press","exercise_key":null,"exercise_type":"strength","body_part":null,"duration_minutes":null,"active_duration_minutes":null,"cardio_intensity_basis":null,"sets":[{"weight_kg":20,"reps":10,"duration_seconds":null}]}]}',
    "Workout Draft policy: ask at most one clarification. If you ask, include every missing field in that one question and keep draft null. If the conversation already includes a workout clarification or the user replies without full data, return a best-effort workout_draft.v1 with missing numeric fields as null and uncertainty in notes. For cardio with duration but no distance, heart rate, or calories, still create a draft from duration and type.",
    "Never claim a draft or official record has been saved. Say the user must review and confirm.",
    `Workflow hint: ${request.workflowType}`,
    `Selected date: ${request.selectedDate ?? "not provided"}`,
    `User message: ${request.messageText}`,
    correctionPrompt(options),
  ].filter((line) => line.trim() !== "").join("\n");
}

function multimodalUserPrompt(request: GatewayRequest): string {
  const selectedDate = request.selectedDate ?? "not provided";
  const userText = request.messageText.trim() === ""
    ? "Analyze these images."
    : request.messageText.trim();
  return [
    phase5PromptContext(request),
    conversationContextPrompt(request),
    answerLanguageInstruction(request.language),
    "Return strict JSON only:",
    '{"schema_version":"provider_gateway_envelope.v2","output_type":"text","message":{"text":"..."},"needs_clarification":false,"clarification_questions":[],"draft":null}',
    "Infer the user's natural intent from the message, images, and conversation context. Set output_type to text, food_draft, workout_draft, or clarification and keep it consistent with the payload.",
    "If the image is a food photo and the user wants food recognition/logging, set output_type to food_draft and return draft as food_draft.v1 with this shape:",
    '{"schema_version":"food_draft.v1","meal_name":"...","total_weight_g":0,"calories_kcal":0,"protein_g":0,"carbs_g":0,"fat_g":0,"confidence":0.0,"estimation_notes":"...","items":[{"name":"...","weight_g":0,"calories_kcal":0,"protein_g":0,"carbs_g":0,"fat_g":0}]}',
    "When Food Draft items is non-empty, item values are totals for that item portion, not per-100g values; meal-level total_weight_g, calories_kcal, protein_g, carbs_g, and fat_g must equal the sum of items.",
    "If the user asks for meal decision support from a screenshot/photo, set output_type to text, keep draft null, and put the recommendation in message.text.",
    "If the user asks for a workout record draft, set output_type to workout_draft, use workout_draft.v1, and keep it editable; do not save it.",
    "Workout Draft shape:",
    '{"schema_version":"workout_draft.v1","record_name":"...","date":null,"notes":"...","exercises":[{"exercise_name":"Bench Press","exercise_key":null,"exercise_type":"strength","body_part":null,"duration_minutes":null,"active_duration_minutes":null,"cardio_intensity_basis":null,"sets":[{"weight_kg":20,"reps":10,"duration_seconds":null}]}]}',
    "Workout Draft policy: ask at most one clarification. If the user reply is incomplete, return a best-effort workout_draft.v1 with uncertainty in notes.",
    "If the image is unclear, set output_type to clarification, needs_clarification true, draft null, and include short clarification_questions.",
    "Use finite non-negative numbers in drafts. Do not claim the draft was saved.",
    `Workflow hint: ${request.workflowType}`,
    `Selected date: ${selectedDate}`,
    `User message: ${userText}`,
  ].join("\n");
}

function correctionPrompt(options?: ProviderGenerationOptions): string {
  if (options?.correction === undefined) return "";
  const issues = options.correction.issues
    .slice(0, 12)
    .map((item) => `${item.path}: ${item.reason}`)
    .join("; ");
  return [
    "Correct the previous response. Return one corrected JSON object only.",
    `Validation errors: ${issues}`,
    `Previous response: ${options.correction.previousOutput.slice(0, 12000)}`,
  ].join("\n");
}

function conversationContextPrompt(request: GatewayRequest): string {
  const context = request.conversationContext;
  if (context === null) {
    return "";
  }
  const lines = [
    "Conversation context summary. Artifact summaries are valid context, but do not treat omitted images as available pixels:",
  ];
  for (const message of context.messages) {
    lines.push(`${message.role}: ${message.text}`);
  }
  for (const artifact of context.artifacts) {
    lines.push(
      `artifact ${artifact.type}: ${artifact.title} - ${artifact.summary}`,
    );
  }
  return lines.join("\n");
}
