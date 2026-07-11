import type { GatewayRequest } from "./contracts.ts";
import {
  providerGatewayEnvelopeJsonSchema,
  providerGatewayEnvelopeSchemaVersion,
} from "../_shared/ai_output_contract.ts";
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

interface OpenAiProviderParams {
  apiKey: string;
  model: string;
  timeoutMs: number;
  fetchImpl: FetchLike;
}

export function createOpenAiProvider(
  params: OpenAiProviderParams,
): ProviderAdapter {
  const apiKey = params.apiKey.trim();
  const model = params.model.trim();
  if (apiKey === "" || model === "") {
    throw new ProviderError("provider_failure");
  }

  return {
    providerId: "openai",
    model,
    generateText(request, options) {
      return generateOpenAiText({ ...params, apiKey, model, request, options });
    },
  };
}

async function generateOpenAiText(
  params: OpenAiProviderParams & {
    apiKey: string;
    model: string;
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
    if (params.request.attachments.length > 0) {
      throw new ProviderError("request_schema_mismatch");
    }
    const response = await params.fetchImpl(
      "https://api.openai.com/v1/responses",
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${params.apiKey}`,
          "content-type": "application/json",
        },
        signal: controller.signal,
        body: JSON.stringify({
          model: params.model,
          instructions: systemInstructions(params.request),
          input: textInput(params.request, params.options),
          text: {
            format: {
              type: "json_schema",
              name: "fitlog_provider_gateway_envelope",
              strict: true,
              schema: providerGatewayEnvelopeJsonSchema,
            },
          },
        }),
      },
    );

    if (!response.ok) {
      throw new ProviderError("provider_failure");
    }

    const body = await response.json();
    return extractOpenAiCompletion(body);
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

export function extractOpenAiCompletion(body: unknown): ProviderCompletion {
  if (typeof body === "object" && body !== null && !Array.isArray(body)) {
    const record = body as Record<string, unknown>;
    const status = typeof record.status === "string" ? record.status : null;
    if (status === "incomplete") {
      return {
        status: "incomplete",
        content: typeof record.output_text === "string"
          ? record.output_text
          : "",
        finishReason: incompleteReason(record),
      };
    }
    if (typeof record.output_text === "string") {
      return completed(record.output_text);
    }
    const output = record.output;
    if (Array.isArray(output)) {
      for (const item of output) {
        const completion = completionFromOutputItem(item);
        if (completion !== null) {
          return completion;
        }
      }
    }
  }
  throw new ProviderError("provider_failure");
}

function completionFromOutputItem(item: unknown): ProviderCompletion | null {
  if (typeof item !== "object" || item === null || Array.isArray(item)) {
    return null;
  }
  const content = (item as Record<string, unknown>).content;
  if (!Array.isArray(content)) {
    return null;
  }
  for (const part of content) {
    if (typeof part !== "object" || part === null || Array.isArray(part)) {
      continue;
    }
    const record = part as Record<string, unknown>;
    if (record.type === "refusal" || typeof record.refusal === "string") {
      return {
        status: "refusal",
        content: "",
        finishReason: "refusal",
      };
    }
    if (typeof record.text === "string") {
      return completed(record.text);
    }
  }
  return null;
}

function completed(value: string): ProviderCompletion {
  const text = value.trim();
  if (text === "") {
    throw new ProviderError("provider_failure");
  }
  return { status: "completed", content: text, finishReason: "stop" };
}

function systemInstructions(request: GatewayRequest): string {
  const language = request.language;
  const base = language === "zh"
    ? "你是 FitLog 的文本聊天助手。你只能使用服务端提供的受控上下文和当前消息，不能写入或修改正式记录、目标或策略。回答应简洁、诚实，数据不足时明确说明。"
    : "You are FitLog's text chat assistant. Use only server-provided controlled context and the current message. Never write or modify official records, goals, or strategies. Be concise and state missing data.";
  return [
    base,
    `Return exactly one ${providerGatewayEnvelopeSchemaVersion} object that conforms to the supplied JSON Schema.`,
    `Expected output: ${request.expectedOutput}. Markdown is allowed only inside message.text.`,
    "If Expected output is auto, infer the user's natural intent from the message and conversation context, then select exactly one output_type: text, food_draft, workout_draft, or clarification.",
    "output_type must match the payload. For text, draft must be null and message.text must not claim a draft was created. For a requested draft, return that exact draft type or one clarification with draft null. Never claim anything was saved.",
    `Resolved record date: ${request.targetDate ?? "unresolved"}. Date source: ${request.dateResolutionSource}. For any draft, copy this exact date into draft.date. If unresolved, return clarification instead of guessing.`,
  ].join("\n");
}

function textInput(
  request: GatewayRequest,
  options?: ProviderGenerationOptions,
): string {
  const context = request.conversationContext;
  const phase5Context = phase5PromptContext(request);
  if (context === null && phase5Context.trim() === "") {
    return correctionPrompt(request.messageText, options);
  }
  const lines = [
    phase5Context,
    answerLanguageInstruction(request.language),
    "Conversation context summary. Do not infer omitted images as available pixels:",
  ];
  if (context !== null) {
    for (const message of context.messages) {
      lines.push(`${message.role}: ${message.text}`);
    }
    for (const artifact of context.artifacts) {
      lines.push(
        `artifact ${artifact.type}: ${artifact.title} - ${artifact.summary}`,
      );
    }
  }
  lines.push(`User message: ${request.messageText}`);
  if (options?.correction !== undefined) {
    lines.push(correctionPrompt("", options));
  }
  return lines.filter((line) => line.trim() !== "").join("\n");
}

function correctionPrompt(
  base: string,
  options?: ProviderGenerationOptions,
): string {
  if (options?.correction === undefined) return base;
  const errors = options.correction.issues
    .slice(0, 12)
    .map((item) => `${item.path}: ${item.reason}`)
    .join("; ");
  return [
    base,
    "Correct the previous response. Return one corrected JSON object only.",
    `Validation errors: ${errors}`,
    `Previous response: ${options.correction.previousOutput.slice(0, 12000)}`,
  ].filter((line) => line.trim() !== "").join("\n");
}

function incompleteReason(record: Record<string, unknown>): string {
  const details = record.incomplete_details;
  if (
    typeof details === "object" && details !== null && !Array.isArray(details)
  ) {
    const reason = (details as Record<string, unknown>).reason;
    if (typeof reason === "string" && reason.trim() !== "") return reason;
  }
  return "incomplete";
}
