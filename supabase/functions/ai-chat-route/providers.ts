import type {
  AiGatewayErrorCode,
  GatewayRequest,
  ModelChoice,
} from "./contracts.ts";
import type { OutputValidationIssue } from "../_shared/ai_output_contract.ts";
import { MockProviderError, runMockProvider } from "./mock_provider.ts";
import { createOpenAiProvider } from "./openai_provider.ts";
import { createQwenProvider } from "./qwen_provider.ts";

export interface ProviderAdapter {
  readonly providerId: "openai" | "qwen" | "mock";
  readonly model: string;
  generateText(
    request: GatewayRequest,
    options?: ProviderGenerationOptions,
  ): Promise<ProviderCompletion>;
}

export interface ProviderCompletion {
  status: "completed" | "refusal" | "incomplete";
  content: string;
  finishReason: string | null;
}

export interface ProviderGenerationOptions {
  timeoutMs?: number;
  correction?: {
    previousOutput: string;
    issues: OutputValidationIssue[];
  };
}

export type FetchLike = typeof fetch;

export class ProviderError extends Error {
  readonly code: AiGatewayErrorCode;

  constructor(code: AiGatewayErrorCode) {
    super(code);
    this.code = code;
  }
}

export interface ProviderRuntimeConfig {
  openAiApiKey: string;
  openAiModel: string;
  qwenApiKey: string;
  qwenModel: string;
  qwenBaseUrl: string;
  timeoutMs: number;
  allowMockProvider: boolean;
}

export function readProviderRuntimeConfig(): ProviderRuntimeConfig {
  return {
    openAiApiKey: Deno.env.get("FITLOG_OPENAI_API_KEY") ?? "",
    openAiModel: Deno.env.get("FITLOG_OPENAI_MODEL") ?? "",
    qwenApiKey: Deno.env.get("FITLOG_QWEN_API_KEY") ?? "",
    qwenModel: Deno.env.get("FITLOG_QWEN_MODEL") ?? "",
    qwenBaseUrl: Deno.env.get("FITLOG_QWEN_BASE_URL") ??
      "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
    timeoutMs: positiveInt(
      Deno.env.get("FITLOG_AI_PROVIDER_TIMEOUT_MS"),
      30000,
    ),
    allowMockProvider: (Deno.env.get("FITLOG_ALLOW_MOCK_PROVIDER") ?? "")
      .toLowerCase() === "true",
  };
}

export function providerForChoice(
  choice: ModelChoice,
  config: ProviderRuntimeConfig,
  fetchImpl: FetchLike = fetch,
): ProviderAdapter {
  if (config.allowMockProvider) {
    return mockProvider();
  }

  switch (choice) {
    case "chatgpt":
      return createOpenAiProvider({
        apiKey: config.openAiApiKey,
        model: config.openAiModel,
        timeoutMs: config.timeoutMs,
        fetchImpl,
      });
    case "qwen":
      return createQwenProvider({
        apiKey: config.qwenApiKey,
        model: config.qwenModel,
        baseUrl: config.qwenBaseUrl,
        timeoutMs: config.timeoutMs,
        fetchImpl,
      });
  }
}

function mockProvider(): ProviderAdapter {
  return {
    providerId: "mock",
    model: "mock-provider-v1",
    generateText(request, options) {
      try {
        return Promise.resolve(runMockProvider(request, options));
      } catch (error) {
        if (error instanceof MockProviderError) {
          throw new ProviderError(error.code);
        }
        throw new ProviderError("provider_failure");
      }
    },
  };
}

function positiveInt(
  value: string | null | undefined,
  fallback: number,
): number {
  if (value === null || value === undefined) {
    return fallback;
  }
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}
