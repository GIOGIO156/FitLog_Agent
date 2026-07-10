import type { GatewayRequest } from "./contracts.ts";
import {
  answerLanguageInstruction,
  phase5PromptContext,
} from "./prompt_builder.ts";
import type { FetchLike, ProviderAdapter } from "./providers.ts";
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
    generateText(request) {
      return generateOpenAiText({ ...params, apiKey, model, request });
    },
  };
}

async function generateOpenAiText(
  params: OpenAiProviderParams & {
    apiKey: string;
    model: string;
    request: GatewayRequest;
  },
): Promise<string> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), params.timeoutMs);
  try {
    if (params.request.attachments.length > 0) {
      throw new ProviderError("record_schema_mismatch");
    }
    const response = await params.fetchImpl("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        authorization: `Bearer ${params.apiKey}`,
        "content-type": "application/json",
      },
      signal: controller.signal,
      body: JSON.stringify({
        model: params.model,
        instructions: systemInstructions(params.request.language),
        input: textInput(params.request),
      }),
    });

    if (!response.ok) {
      throw new ProviderError("provider_failure");
    }

    const body = await response.json();
    return extractOpenAiText(body);
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

export function extractOpenAiText(body: unknown): string {
  if (typeof body === "object" && body !== null && !Array.isArray(body)) {
    const record = body as Record<string, unknown>;
    if (typeof record.output_text === "string") {
      return nonEmptyText(record.output_text);
    }
    const output = record.output;
    if (Array.isArray(output)) {
      for (const item of output) {
        const text = textFromOutputItem(item);
        if (text !== null) {
          return text;
        }
      }
    }
  }
  throw new ProviderError("provider_failure");
}

function textFromOutputItem(item: unknown): string | null {
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
    if (typeof record.text === "string") {
      return nonEmptyText(record.text);
    }
  }
  return null;
}

function nonEmptyText(value: string): string {
  const text = value.trim();
  if (text === "") {
    throw new ProviderError("provider_failure");
  }
  return text;
}

function systemInstructions(language: "zh" | "en"): string {
  return language === "zh"
    ? "你是 FitLog 的文本聊天助手。当前 OpenAI 路径只处理文字请求；图片请求由支持视觉输入的多模态 provider 处理。你只能使用服务端提供的 Phase 5 受控上下文和用户当前消息，不能写入或修改任何正式记录。回答应简洁、诚实，并在数据不足时说明缺少什么。"
    : "You are FitLog's text chat assistant. The current OpenAI path handles text requests only; image requests are handled by a multimodal provider with vision input. You may use only the server-provided Phase 5 controlled context and the current user message, and you must not write or modify official records. Keep answers concise and say what is missing when data is insufficient.";
}

function textInput(request: GatewayRequest): string {
  const context = request.conversationContext;
  const phase5Context = phase5PromptContext(request);
  if (context === null && phase5Context.trim() === "") {
    return request.messageText;
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
      lines.push(`artifact ${artifact.type}: ${artifact.title} - ${artifact.summary}`);
    }
  }
  lines.push(`User message: ${request.messageText}`);
  return lines.filter((line) => line.trim() !== "").join("\n");
}
