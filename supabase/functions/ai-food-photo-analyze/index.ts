import {
  buildQwenVisionRequestBody,
  errorMessageForCode,
  extractQwenCompletion,
  foodDraftForClient,
  type FoodDraft,
  logStatusForCode,
  parsePhotoAnalysisRequest,
  parseProviderFoodDraftBody,
  type PhotoAnalysisRequest,
  type PhotoGatewayErrorCode,
  PhotoGatewayRequestError,
  photoGatewayResponse,
  type PhotoGatewayStatus,
  type QwenFoodCompletion,
  stripImageDataForDebug,
} from "./contracts.ts";
import {
  OutputContractError,
  outputValidatorVersion,
} from "../_shared/ai_output_contract.ts";

const minimumCorrectionBudgetMs = 1500;

interface PhotoOutputTelemetry {
  firstPassValidationStatus: "not_attempted" | "passed" | "failed";
  correctionAttemptCount: 0 | 1;
  finalValidationStatus: "not_attempted" | "passed" | "failed";
  providerCompletionStatus:
    | "not_called"
    | "completed"
    | "refusal"
    | "incomplete";
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

class PhotoGatewayHttpError extends Error {
  readonly code: PhotoGatewayErrorCode;
  readonly status: number;

  constructor(code: PhotoGatewayErrorCode, status: number) {
    super(code);
    this.code = code;
    this.status = status;
  }
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse(
      photoGatewayResponse({
        error: {
          code: "request_schema_mismatch",
          message: errorMessageForCode("request_schema_mismatch"),
        },
      }),
      405,
    );
  }

  const startedAt = Date.now();
  let env: PhotoGatewayEnv | null = null;
  let providerConfig: QwenVisionConfig | null = null;
  let accountId: string | null = null;
  let parsedRequest: PhotoAnalysisRequest | null = null;
  let outputTelemetry = defaultPhotoOutputTelemetry();

  try {
    env = readPhotoGatewayEnv();
    providerConfig = readQwenVisionConfig();
    const token = extractBearerToken(request.headers.get("authorization"));
    if (token === null) {
      throw new PhotoGatewayHttpError("auth_required", 401);
    }

    accountId = await verifyAccount(env, token);
    const sessionId = extractSessionIdFromAccessToken(token);
    if (sessionId === null) {
      throw new PhotoGatewayHttpError("device_replaced", 409);
    }

    let body: unknown;
    try {
      body = await request.json();
    } catch (_) {
      throw new PhotoGatewayRequestError("request_schema_mismatch");
    }
    parsedRequest = parsePhotoAnalysisRequest(body);

    await checkSubscription(env, accountId);
    await assertActiveDevice(env, token, parsedRequest.deviceId, sessionId);

    const deadlineAt = startedAt + providerConfig.timeoutMs;
    let completion = await callQwenVisionProvider(
      providerConfig,
      parsedRequest,
      { timeoutMs: remainingDeadline(deadlineAt) },
    );
    outputTelemetry = {
      ...outputTelemetry,
      providerCompletionStatus: completion.status,
    };
    assertCompleted(completion);
    let parsedProvider;
    try {
      parsedProvider = parseProviderFoodDraftBody(
        completion.content,
        parsedRequest.selectedDate,
      );
      outputTelemetry = {
        ...outputTelemetry,
        firstPassValidationStatus: "passed",
        finalValidationStatus: "passed",
      };
    } catch (error) {
      if (!(error instanceof OutputContractError)) throw error;
      outputTelemetry = {
        ...outputTelemetry,
        firstPassValidationStatus: "failed",
      };
      const remaining = deadlineAt - Date.now();
      if (remaining < minimumCorrectionBudgetMs) {
        outputTelemetry = {
          ...outputTelemetry,
          finalValidationStatus: "failed",
        };
        throw error;
      }
      outputTelemetry = { ...outputTelemetry, correctionAttemptCount: 1 };
      completion = await callQwenVisionProvider(providerConfig, parsedRequest, {
        timeoutMs: remaining,
        correction: {
          previousOutput: completion.content,
          issues: error.issues,
        },
      });
      outputTelemetry = {
        ...outputTelemetry,
        providerCompletionStatus: completion.status,
      };
      assertCompleted(completion);
      try {
        parsedProvider = parseProviderFoodDraftBody(
          completion.content,
          parsedRequest.selectedDate,
        );
        outputTelemetry = {
          ...outputTelemetry,
          finalValidationStatus: "passed",
        };
      } catch (correctionError) {
        outputTelemetry = {
          ...outputTelemetry,
          finalValidationStatus: "failed",
        };
        throw correctionError;
      }
    }
    const persisted = await writePhotoLog(env, {
      accountId,
      request: parsedRequest,
      model: providerConfig.model,
      status: "ok",
      errorCode: null,
      latencyMs: Date.now() - startedAt,
      draft: parsedProvider.draft,
      schemaValidationStatus: parsedProvider.schemaValidationStatus,
      safetyFlags: [],
      telemetry: outputTelemetry,
    });

    return jsonResponse(
      photoGatewayResponse({
        modelProvider: "qwen",
        draft: foodDraftForClient(
          parsedProvider.draft,
          parsedRequest.schemaVersion,
        ),
        needsClarification: parsedProvider.needsClarification,
        clarificationQuestions: parsedProvider.clarificationQuestions,
        debugSummaryId: persisted.debugSummaryId,
        error: null,
      }),
      200,
    );
  } catch (error) {
    const gatewayError = toPhotoGatewayHttpError(error);
    if (
      env !== null &&
      accountId !== null &&
      gatewayError.code !== "auth_required"
    ) {
      await writePhotoLog(env, {
        accountId,
        request: parsedRequest,
        model: providerConfig?.model ?? null,
        status: logStatusForCode(gatewayError.code),
        errorCode: gatewayError.code,
        latencyMs: Date.now() - startedAt,
        draft: null,
        schemaValidationStatus: "failed",
        safetyFlags: [gatewayError.code],
        telemetry: outputTelemetry,
      });
    }

    return jsonResponse(
      photoGatewayResponse({
        modelProvider: "qwen",
        error: {
          code: gatewayError.code,
          message: errorMessageForCode(gatewayError.code),
        },
      }),
      200,
    );
  }
});

interface PhotoGatewayEnv {
  supabaseUrl: string;
  supabaseAnonKey: string;
  supabaseServiceRoleKey: string;
}

interface QwenVisionConfig {
  apiKey: string;
  model: string;
  baseUrl: string;
  timeoutMs: number;
}

function readPhotoGatewayEnv(): PhotoGatewayEnv {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    "";
  if (
    supabaseUrl.trim() === "" ||
    supabaseAnonKey.trim() === "" ||
    supabaseServiceRoleKey.trim() === ""
  ) {
    throw new PhotoGatewayHttpError("provider_failure", 502);
  }
  return {
    supabaseUrl: supabaseUrl.replace(/\/+$/, ""),
    supabaseAnonKey,
    supabaseServiceRoleKey,
  };
}

function readQwenVisionConfig(): QwenVisionConfig {
  const apiKey = Deno.env.get("FITLOG_QWEN_API_KEY") ?? "";
  const model = Deno.env.get("FITLOG_QWEN_VISION_MODEL") ??
    Deno.env.get("FITLOG_QWEN_MODEL") ??
    "";
  const baseUrl = Deno.env.get("FITLOG_QWEN_BASE_URL") ??
    "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions";
  if (apiKey.trim() === "" || model.trim() === "" || baseUrl.trim() === "") {
    throw new PhotoGatewayHttpError("provider_failure", 502);
  }
  return {
    apiKey: apiKey.trim(),
    model: model.trim(),
    baseUrl: baseUrl.trim(),
    timeoutMs: positiveInt(
      Deno.env.get("FITLOG_AI_PROVIDER_TIMEOUT_MS"),
      30000,
    ),
  };
}

async function verifyAccount(
  env: PhotoGatewayEnv,
  token: string,
): Promise<string> {
  const response = await fetch(`${env.supabaseUrl}/auth/v1/user`, {
    headers: {
      apikey: env.supabaseAnonKey,
      authorization: `Bearer ${token}`,
    },
  });
  if (!response.ok) {
    throw new PhotoGatewayHttpError("auth_required", 401);
  }
  const user = await response.json();
  const accountId = typeof user?.id === "string" ? user.id : "";
  if (accountId.trim() === "") {
    throw new PhotoGatewayHttpError("auth_required", 401);
  }
  return accountId;
}

async function checkSubscription(
  env: PhotoGatewayEnv,
  accountId: string,
): Promise<void> {
  const response = await fetch(
    `${env.supabaseUrl}/rest/v1/subscriptions?select=status&account_id=eq.${accountId}&limit=1`,
    { headers: serviceHeaders(env) },
  );
  if (!response.ok) {
    throw new PhotoGatewayHttpError("provider_failure", 502);
  }
  const rows = await response.json();
  const status = Array.isArray(rows) && rows.length > 0
    ? rows[0]?.status
    : null;
  if (status !== "active") {
    throw new PhotoGatewayHttpError("subscription_required", 403);
  }
}

async function assertActiveDevice(
  env: PhotoGatewayEnv,
  token: string,
  deviceId: string,
  sessionId: string,
): Promise<void> {
  const response = await fetch(
    `${env.supabaseUrl}/rest/v1/rpc/assert_active_device`,
    {
      method: "POST",
      headers: {
        apikey: env.supabaseAnonKey,
        authorization: `Bearer ${token}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        input_device_id: deviceId,
        input_session_id: sessionId,
      }),
    },
  );
  if (!response.ok) {
    throw new PhotoGatewayHttpError("provider_failure", 502);
  }
  const result = await response.json();
  if (!allowsActiveDevice(result)) {
    throw new PhotoGatewayHttpError("device_replaced", 409);
  }
}

async function callQwenVisionProvider(
  config: QwenVisionConfig,
  request: PhotoAnalysisRequest,
  options: {
    timeoutMs: number;
    correction?: {
      previousOutput: string;
      issues: OutputContractError["issues"];
    };
  },
): Promise<QwenFoodCompletion> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), options.timeoutMs);
  try {
    const response = await fetch(config.baseUrl, {
      method: "POST",
      headers: {
        authorization: `Bearer ${config.apiKey}`,
        "content-type": "application/json",
      },
      signal: controller.signal,
      body: JSON.stringify(
        buildQwenVisionRequestBody({
          request,
          model: config.model,
          correction: options.correction,
        }),
      ),
    });
    if (!response.ok) {
      throw new PhotoGatewayHttpError("provider_failure", 502);
    }
    return extractQwenCompletion(await response.json());
  } catch (error) {
    if (error instanceof PhotoGatewayHttpError) {
      throw error;
    }
    if (error instanceof DOMException && error.name === "AbortError") {
      throw new PhotoGatewayHttpError("gateway_timeout", 504);
    }
    throw new PhotoGatewayHttpError("provider_failure", 502);
  } finally {
    clearTimeout(timeout);
  }
}

async function writePhotoLog(
  env: PhotoGatewayEnv,
  params: {
    accountId: string;
    request: PhotoAnalysisRequest | null;
    model: string | null;
    status: PhotoGatewayStatus;
    errorCode: PhotoGatewayErrorCode | null;
    latencyMs: number;
    draft: FoodDraft | null;
    schemaValidationStatus: string;
    safetyFlags: string[];
    telemetry: PhotoOutputTelemetry;
  },
): Promise<{ debugSummaryId: string | null }> {
  const requestId = crypto.randomUUID();
  const request = params.request;
  const logResponse = await fetch(
    `${env.supabaseUrl}/rest/v1/ai_request_logs`,
    {
      method: "POST",
      headers: {
        ...serviceHeaders(env),
        prefer: "return=representation",
      },
      body: JSON.stringify({
        request_id: requestId,
        account_id: params.accountId,
        session_id: null,
        workflow_type: "food_logging",
        model_choice: "qwen",
        model_provider: "qwen",
        model: params.model,
        prompt_version: "phase4_food_photo_v1",
        schema_version: "food_draft.v2",
        profile_version: null,
        status: params.status,
        error_code: params.errorCode,
        latency_ms: params.latencyMs,
        token_estimate: null,
        image_count: request === null ? 0 : request.images.length,
        expected_output: "food_draft",
        validator_version: outputValidatorVersion,
        first_pass_validation_status:
          params.telemetry.firstPassValidationStatus,
        correction_attempt_count: params.telemetry.correctionAttemptCount,
        final_validation_status: params.telemetry.finalValidationStatus,
        provider_completion_status: params.telemetry.providerCompletionStatus,
      }),
    },
  );
  if (!logResponse.ok) {
    return { debugSummaryId: null };
  }

  const debugSummaryId = crypto.randomUUID();
  await fetch(`${env.supabaseUrl}/rest/v1/ai_debug_summaries`, {
    method: "POST",
    headers: {
      ...serviceHeaders(env),
      prefer: "return=minimal",
    },
    body: JSON.stringify({
      id: debugSummaryId,
      request_id: requestId,
      account_id: params.accountId,
      session_id: null,
      intent: "food_photo_analysis",
      intent_confidence: null,
      called_tools_json: ["qwen_vision"],
      retrieved_dimensions_json: stripImageDataForDebug(request),
      missing_dimensions_json: params.draft === null ? ["food_draft"] : [],
      safety_flags_json: params.safetyFlags,
      schema_validation_status: params.schemaValidationStatus,
      user_final_action: params.status === "ok" ? "draft_returned" : "none",
    }),
  });
  return { debugSummaryId };
}

function toPhotoGatewayHttpError(error: unknown): PhotoGatewayHttpError {
  if (error instanceof PhotoGatewayHttpError) {
    return error;
  }
  if (error instanceof PhotoGatewayRequestError) {
    return new PhotoGatewayHttpError(error.code, error.status);
  }
  if (error instanceof OutputContractError) {
    return new PhotoGatewayHttpError("provider_output_invalid", 502);
  }
  if (error instanceof SyntaxError) {
    return new PhotoGatewayHttpError("record_schema_mismatch", 422);
  }
  if (
    error instanceof Error &&
    (error.message === "record_schema_mismatch" ||
      error.message === "provider_failure")
  ) {
    return new PhotoGatewayHttpError(
      error.message as PhotoGatewayErrorCode,
      error.message === "record_schema_mismatch" ? 422 : 502,
    );
  }
  return new PhotoGatewayHttpError("provider_failure", 502);
}

function defaultPhotoOutputTelemetry(): PhotoOutputTelemetry {
  return {
    firstPassValidationStatus: "not_attempted",
    correctionAttemptCount: 0,
    finalValidationStatus: "not_attempted",
    providerCompletionStatus: "not_called",
  };
}

function remainingDeadline(deadlineAt: number): number {
  const remaining = deadlineAt - Date.now();
  if (remaining <= 0) {
    throw new PhotoGatewayHttpError("gateway_timeout", 504);
  }
  return remaining;
}

function assertCompleted(completion: QwenFoodCompletion): void {
  switch (completion.status) {
    case "completed":
      return;
    case "refusal":
      throw new PhotoGatewayHttpError("provider_refusal", 422);
    case "incomplete":
      throw new PhotoGatewayHttpError("provider_incomplete", 502);
  }
}

function jsonResponse(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json; charset=utf-8",
    },
  });
}

function extractBearerToken(header: string | null): string | null {
  if (header === null) {
    return null;
  }
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  return match?.[1]?.trim() || null;
}

function extractSessionIdFromAccessToken(token: string): string | null {
  const parts = token.split(".");
  if (parts.length < 2) {
    return null;
  }

  try {
    const payload = JSON.parse(base64UrlDecode(parts[1]));
    if (
      typeof payload !== "object" || payload === null || Array.isArray(payload)
    ) {
      return null;
    }
    const map = payload as Record<string, unknown>;
    return nullableString(map.session_id) ??
      nullableString(map.sid) ??
      nullableString(map.jti);
  } catch (_) {
    return null;
  }
}

function serviceHeaders(env: PhotoGatewayEnv): HeadersInit {
  return {
    apikey: env.supabaseServiceRoleKey,
    authorization: `Bearer ${env.supabaseServiceRoleKey}`,
    "content-type": "application/json",
  };
}

function allowsActiveDevice(result: unknown): boolean {
  if (result === null || result === undefined) {
    return true;
  }
  if (typeof result === "boolean") {
    return result;
  }
  if (typeof result === "object" && !Array.isArray(result)) {
    const map = result as Record<string, unknown>;
    if (typeof map.ok === "boolean") {
      return map.ok;
    }
    if (typeof map.active === "boolean") {
      return map.active;
    }
    return map.code === undefined || map.code === "ok";
  }
  return String(result).toLowerCase() !== "false";
}

function nullableString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed;
}

function base64UrlDecode(value: string): string {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const paddingLength = (4 - (normalized.length % 4)) % 4;
  return atob(normalized + "=".repeat(paddingLength));
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
