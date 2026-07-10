import type { GatewayRequest } from "./contracts.ts";
import {
  answerLanguageInstruction,
  phase5PromptContext,
} from "./prompt_builder.ts";
import type { FetchLike, ProviderAdapter } from "./providers.ts";
import { ProviderError } from "./providers.ts";

interface QwenProviderParams {
  apiKey: string;
  model: string;
  baseUrl: string;
  timeoutMs: number;
  fetchImpl: FetchLike;
}

export function createQwenProvider(params: QwenProviderParams): ProviderAdapter {
  const apiKey = params.apiKey.trim();
  const model = params.model.trim();
  const baseUrl = params.baseUrl.trim();
  if (apiKey === "" || model === "" || baseUrl === "") {
    throw new ProviderError("provider_failure");
  }

  return {
    providerId: "qwen",
    model,
    generateText(request) {
      return generateQwenText({ ...params, apiKey, model, baseUrl, request });
    },
  };
}

async function generateQwenText(
  params: QwenProviderParams & {
    apiKey: string;
    model: string;
    baseUrl: string;
    request: GatewayRequest;
  },
): Promise<string> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), params.timeoutMs);
  try {
    const response = await params.fetchImpl(params.baseUrl, {
      method: "POST",
      headers: {
        authorization: `Bearer ${params.apiKey}`,
        "content-type": "application/json",
      },
      signal: controller.signal,
      body: JSON.stringify(buildQwenRequestBody(params.request, params.model)),
    });

    if (!response.ok) {
      throw new ProviderError("provider_failure");
    }

    const body = await response.json();
    return extractQwenText(body);
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

export function extractQwenText(body: unknown): string {
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
  if (typeof message !== "object" || message === null || Array.isArray(message)) {
    throw new ProviderError("provider_failure");
  }
  const content = (message as Record<string, unknown>).content;
  if (typeof content !== "string") {
    throw new ProviderError("provider_failure");
  }
  const text = content.trim();
  if (text === "") {
    throw new ProviderError("provider_failure");
  }
  return text;
}

function buildQwenRequestBody(
  request: GatewayRequest,
  model: string,
): Record<string, unknown> {
  const hasImage = request.attachments.length > 0;
  return {
    model,
    enable_thinking: false,
    ...(hasImage ? { response_format: { type: "json_object" } } : {}),
    messages: [
      {
        role: "system",
        content: systemMessage(request),
      },
      {
        role: "user",
        content: hasImage ? multimodalUserContent(request) : textUserPrompt(request),
      },
    ],
  };
}

function multimodalUserContent(request: GatewayRequest): Record<string, unknown>[] {
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
  const hasImage = request.attachments.length > 0;
  if (!hasImage) {
    return request.language === "zh"
      ? "你是 FitLog 的 AI 聊天助手。你可以回答健身、饮食、FitLog 使用和复盘类文本问题，也可以在用户明确要求时生成需要用户确认的 Food Draft 或 Workout Draft。普通问答可用简洁 Markdown；草稿类回复必须只输出一个 JSON 对象，把面向用户的解释写进 message.text，把结构化草稿写进 draft，不能在 JSON 外再写说明。你只能使用服务端提供的 Phase 5 受控上下文和用户当前消息，不能写入或修改任何正式记录，不能自动修改目标。训练草稿最多追问一次；如果用户回答仍不完整或说不知道，就生成可编辑的不完整 Workout Draft，并把不确定处写进 notes。回答应简洁、诚实。"
      : "You are FitLog's AI chat assistant. You can answer text questions about fitness, food, FitLog usage, and review, and you may generate a user-confirmed Food Draft or Workout Draft when the user clearly asks for one. Normal answers may use concise Markdown; draft replies must output exactly one JSON object, with user-facing explanation in message.text and structured data in draft, and no prose outside JSON. You may use only the server-provided Phase 5 controlled context and the current user message, and you must not write or modify official records or change goals automatically. Ask at most one clarifying turn for workout drafts; if the user still gives incomplete data or says they do not know, create an editable incomplete Workout Draft and put uncertainties in notes. Keep answers concise and honest.";
  }
  return request.language === "zh"
    ? "你是 FitLog 的多模态 AI 助手。你可以读取本次请求最多三张图片，用于拍照识食物、截图/拍照配餐建议或复盘说明。你只能使用服务端提供的 Phase 5 受控上下文、用户当前消息和本次图片，不能保存正式记录，不能修改目标。食物识别只能返回可编辑 Food Draft；训练记录只能返回可编辑 Workout Draft。所有草稿都必须由用户确认保存后才成为正式记录。输出严格 JSON。"
    : "You are FitLog's multimodal AI assistant. You may inspect up to three images in this request for food recognition, screenshot/photo meal decision support, or review explanations. You may use only the server-provided Phase 5 controlled context, the current user message, and this request's images; do not save official records or change goals. Food recognition may only return an editable Food Draft; workout logging may only return an editable Workout Draft. All drafts require user confirmation before official saving. Output strict JSON.";
}

function textUserPrompt(request: GatewayRequest): string {
  return [
    phase5PromptContext(request),
    conversationContextPrompt(request),
    answerLanguageInstruction(request.language),
    "Answer normal questions in concise Markdown.",
    "If the user explicitly asks FitLog to create a food or workout record draft, or if the user is replying to a draft clarification, return exactly one JSON object using this envelope. Do not wrap it in Markdown fences and do not add prose before or after the JSON:",
    '{"message":{"text":"Friendly user-facing explanation and review instructions go here."},"needs_clarification":false,"clarification_questions":[],"draft":null}',
    "Put all user-facing explanation, uncertainty, and review instructions inside message.text. The app displays message.text and renders draft as a native review card; never print the draft JSON as visible prose.",
    "Food Draft shape:",
    '{"meal_name":"...","total_weight_g":0,"calories_kcal":0,"protein_g":0,"carbs_g":0,"fat_g":0,"confidence":0.0,"estimation_notes":"...","items":[{"name":"...","weight_g":0,"calories_kcal":0,"protein_g":0,"carbs_g":0,"fat_g":0}]}',
    "When Food Draft items is non-empty, item values are totals for that item portion, not per-100g values; meal-level total_weight_g, calories_kcal, protein_g, carbs_g, and fat_g must equal the sum of items.",
    "Workout Draft shape:",
    '{"schema_version":"workout_draft.v1","record_name":"...","date":null,"notes":"...","exercises":[{"exercise_name":"Bench Press","exercise_key":null,"exercise_type":"strength","body_part":null,"duration_minutes":null,"active_duration_minutes":null,"cardio_intensity_basis":null,"sets":[{"weight_kg":20,"reps":10,"duration_seconds":null}]}]}',
    "Workout Draft policy: ask at most one clarification. If you ask, include every missing field in that one question and keep draft null. If the conversation already includes a workout clarification or the user replies without full data, return a best-effort workout_draft.v1 with missing numeric fields as null and uncertainty in notes. For cardio with duration but no distance, heart rate, or calories, still create a draft from duration and type.",
    "Never claim a draft or official record has been saved. Say the user must review and confirm.",
    `Workflow hint: ${request.workflowType}`,
    `Selected date: ${request.selectedDate ?? "not provided"}`,
    `User message: ${request.messageText}`,
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
    '{"message":{"text":"..."},"needs_clarification":false,"clarification_questions":[],"draft":null}',
    "If the image is a food photo and the user wants food recognition/logging, return draft as food_draft.v1 with this shape:",
    '{"meal_name":"...","total_weight_g":0,"calories_kcal":0,"protein_g":0,"carbs_g":0,"fat_g":0,"confidence":0.0,"estimation_notes":"...","items":[{"name":"...","weight_g":0,"calories_kcal":0,"protein_g":0,"carbs_g":0,"fat_g":0}]}',
    "When Food Draft items is non-empty, item values are totals for that item portion, not per-100g values; meal-level total_weight_g, calories_kcal, protein_g, carbs_g, and fat_g must equal the sum of items.",
    "If the user asks for meal decision support from a screenshot/photo, keep draft null and put the recommendation in message.text.",
    "If the user asks for a workout record draft, use workout_draft.v1 and keep it editable; do not save it.",
    "Workout Draft shape:",
    '{"schema_version":"workout_draft.v1","record_name":"...","date":null,"notes":"...","exercises":[{"exercise_name":"Bench Press","exercise_key":null,"exercise_type":"strength","body_part":null,"duration_minutes":null,"active_duration_minutes":null,"cardio_intensity_basis":null,"sets":[{"weight_kg":20,"reps":10,"duration_seconds":null}]}]}',
    "Workout Draft policy: ask at most one clarification. If the user reply is incomplete, return a best-effort workout_draft.v1 with uncertainty in notes.",
    "If the image is unclear, set needs_clarification true, draft null, and include short clarification_questions.",
    "Use finite non-negative numbers in drafts. Do not claim the draft was saved.",
    `Workflow hint: ${request.workflowType}`,
    `Selected date: ${selectedDate}`,
    `User message: ${userText}`,
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
    lines.push(`artifact ${artifact.type}: ${artifact.title} - ${artifact.summary}`);
  }
  return lines.join("\n");
}
