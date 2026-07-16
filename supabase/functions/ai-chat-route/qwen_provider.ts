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
import { buildFoodCapabilityRequest } from "../_shared/food_capability.ts";

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

export function buildQwenRequestBody(
  request: GatewayRequest,
  model: string,
  options?: ProviderGenerationOptions,
): Record<string, unknown> {
  const hasImage = request.attachments.length > 0 &&
    options?.correction === undefined;
  return {
    model,
    enable_thinking: false,
    max_tokens: outputTokenBudget(request),
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

function outputTokenBudget(request: GatewayRequest): number {
  return request.expectedOutput === "text" ? 384 : 1600;
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
    outputFamilySystemInstruction(request),
    request.workflowType === "app_logic_answer" &&
      request.expectedOutput === "text"
      ? "For every FitLog-specific fact, use only an explicit matching statement from Document sources. Answer only the asked rule, do not add adjacent FitLog rules or concepts, and say no matching documentation was found when the excerpts do not contain the answer."
      : "",
  ].filter((line) => line.trim() !== "").join("\n");
}

function textUserPrompt(
  request: GatewayRequest,
  options?: ProviderGenerationOptions,
): string {
  return [
    phase5PromptContext(request),
    conversationContextPrompt(request),
    answerLanguageInstruction(request.language),
    ...outputFamilyUserLines(request),
    `Workflow hint: ${request.workflowType}`,
    `Default date: ${request.selectedDate ?? "not provided"}`,
    `Resolved record date: ${request.targetDate ?? "unresolved"}`,
    `User message: ${request.messageText}`,
    finalOutputReminder(request),
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
    ...outputFamilyUserLines(request),
    "Use the image only as evidence for the selected output family; do not change output_type because an image is attached.",
    "If the user asks for meal decision support from a screenshot/photo, set output_type to text, keep draft null, and put the recommendation in message.text.",
    "If the image is unclear, set output_type to clarification, needs_clarification true, draft null, and include short clarification_questions.",
    "Use finite non-negative numbers in drafts. Do not claim the draft was saved.",
    `Workflow hint: ${request.workflowType}`,
    `Default date: ${selectedDate}`,
    `Resolved record date: ${
      request.targetDate ?? "unresolved"
    }. Copy it exactly into draft.date; if unresolved, clarify instead of guessing.`,
    `User message: ${userText}`,
    finalOutputReminder(request),
  ].join("\n");
}

function finalOutputReminder(request: GatewayRequest): string {
  if (request.expectedOutput === "text") {
    return "FINAL JSON REQUIREMENT: output_type must be text, draft must be null, needs_clarification must be false. If you cannot answer, use clarification with draft null. Never return food_draft or workout_draft.";
  }
  if (request.expectedOutput === "food_draft") {
    return `FINAL JSON REQUIREMENT: output_type must be food_draft with food_draft.v2 dated ${
      request.targetDate ?? "unresolved"
    }, or clarification with draft null. Never return text or workout_draft and never claim it was saved.`;
  }
  if (request.expectedOutput === "workout_draft") {
    return `FINAL JSON REQUIREMENT: output_type must be workout_draft with workout_draft.v3 dated ${
      request.targetDate ?? "unresolved"
    }, or clarification with draft null. Never return text or food_draft and never claim it was saved.`;
  }
  return "FINAL JSON REQUIREMENT: choose one output_type and make every envelope field consistent with it.";
}

function outputFamilySystemInstruction(request: GatewayRequest): string {
  if (request.expectedOutput === "text") {
    return "Return output_type=text with draft=null. If essential information is missing, return output_type=clarification with draft=null. Never return a food or workout draft.";
  }
  if (request.expectedOutput === "food_draft") {
    return `Return output_type=food_draft with exactly one food_draft.v2, or clarification with draft=null. Food capability request: ${
      JSON.stringify(
        buildFoodCapabilityRequest(request.messageText, request.language),
      )
    }. Copy resolved date ${
      request.targetDate ?? "unresolved"
    }; if unresolved, clarify. Never claim the draft was saved.`;
  }
  if (request.expectedOutput === "workout_draft") {
    return `Return output_type=workout_draft with exactly one workout_draft.v3, or clarification with draft=null. Copy resolved date ${
      request.targetDate ?? "unresolved"
    }; if unresolved, clarify. Use only one Approved Context exercise_definition and copy all identity/semantic fields exactly. A clarification must only state the missing facts and ask at most two short questions; do not append an answer or a secondary task. Never claim the draft was saved.`;
  }
  return "Infer exactly one output family from the request. Keep output_type, clarification state, and draft payload consistent; never claim the result was saved.";
}

function outputFamilyUserLines(request: GatewayRequest): string[] {
  const envelopePrefix = '{"schema_version":"provider_gateway_envelope.v2"';
  if (request.expectedOutput === "text") {
    return [
      "Return this exact text envelope shape; no draft keys beyond draft:null:",
      `${envelopePrefix},"output_type":"text","message":{"text":"Concise grounded answer."},"needs_clarification":false,"clarification_questions":[],"draft":null}`,
      "Keep every user-facing statement inside message.text and do not claim a draft or record was created.",
    ];
  }
  if (request.expectedOutput === "food_draft") {
    return [
      "Return this food envelope shape, or one clarification with draft:null:",
      `${envelopePrefix},"output_type":"food_draft","message":{"text":"请审核并确认草稿。"},"needs_clarification":false,"clarification_questions":[],"draft":{"schema_version":"food_draft.v2","date":"${
        request.targetDate ?? "unresolved"
      }","meal_name":"...","total_weight_g":0,"calories_kcal":0,"protein_g":0,"carbs_g":0,"fat_g":0,"confidence":0.0,"estimation_notes":"...","items":[{"name":"...","weight_g":0,"calories_kcal":0,"protein_g":0,"carbs_g":0,"fat_g":0}]}}`,
      "Item nutrition values are portion totals. Meal weight, kcal and macros must equal item sums. Preserve explicit user facts; estimate only missing values.",
    ];
  }
  if (request.expectedOutput === "workout_draft") {
    return [
      "Return this workout envelope shape, or one clarification with draft:null:",
      `${envelopePrefix},"output_type":"workout_draft","message":{"text":"请审核并确认草稿。"},"needs_clarification":false,"clarification_questions":[],"draft":{"schema_version":"workout_draft.v3","record_name":"...","date":"${
        request.targetDate ?? "unresolved"
      }","notes":"...","exercises":[{"exercise_name":"copy from context","exercise_key":"copy from context","exercise_source":"builtin","definition_hash":"copy from context","exercise_type":"strength","body_part":"copy from context","load_input_mode":"copy from context","reps_input_mode":"copy from context","set_metric_type":"copy from context","duration_minutes":null,"active_duration_minutes":null,"cardio_intensity_basis":null,"sets":[{"weight_kg":20,"reps":10,"duration_seconds":null}]}]}}`,
      "Copy exercise identity and semantic fields exactly from the single approved definition. Missing numeric set values may be null.",
    ];
  }
  return [
    "Return one provider_gateway_envelope.v2 JSON object. Infer exactly one output_type and keep draft plus clarification fields consistent.",
  ];
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
