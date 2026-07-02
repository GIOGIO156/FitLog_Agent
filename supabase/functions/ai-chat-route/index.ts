import {
  type AiGatewayErrorCode,
  type AiGatewayStatus,
  errorMessageForCode,
  estimateTokens,
  extractBearerToken,
  extractSessionIdFromAccessToken,
  type GatewayDraft,
  gatewayResponse,
  type GatewayRequest,
  GatewayRequestError,
  logStatusForCode,
  parseGatewayRequest,
  parseProviderGatewayBody,
  type PersistedTurn,
  stringField,
} from "./contracts.ts";
import {
  ProviderError,
  providerForChoice,
  readProviderRuntimeConfig,
} from "./providers.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

class GatewayHttpError extends Error {
  readonly code: AiGatewayErrorCode;
  readonly status: number;

  constructor(code: AiGatewayErrorCode, status: number) {
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
      gatewayResponse({
        error: {
          code: "record_schema_mismatch",
          message: errorMessageForCode("record_schema_mismatch"),
        },
      }),
      405,
    );
  }

  const startedAt = Date.now();
  let env: GatewayEnv | null = null;
  let accountId: string | null = null;
  let parsedRequest: GatewayRequest | null = null;

  try {
    env = readGatewayEnv();
    const token = extractBearerToken(request.headers.get("authorization"));
    if (token === null) {
      throw new GatewayHttpError("auth_required", 401);
    }

    accountId = await verifyAccount(env, token);
    const sessionId = extractSessionIdFromAccessToken(token);
    if (sessionId === null) {
      throw new GatewayHttpError("device_replaced", 409);
    }

    let body: unknown;
    try {
      body = await request.json();
    } catch (_) {
      throw new GatewayRequestError("record_schema_mismatch");
    }
    parsedRequest = parseGatewayRequest(body);

    await checkSubscription(env, accountId);
    await assertActiveDevice(env, token, parsedRequest.deviceId, sessionId);

    const provider = providerForChoice(
      parsedRequest.modelChoice,
      readProviderRuntimeConfig(),
    );
    const providerContent = await provider.generateText(parsedRequest);
    const parsedProvider = parseProviderGatewayBody(
      providerContent,
      parsedRequest,
    );
    const persisted = await recordChatTurn(
      env,
      accountId,
      parsedRequest,
      provider.providerId,
      provider.model,
      parsedProvider.messageText,
      finalAnswerSnapshot(parsedProvider.draft, parsedRequest),
      Date.now() - startedAt,
    );

    return jsonResponse(
      gatewayResponse({
        sessionId: persisted.sessionId,
        assistantMessageId: persisted.assistantMessageId,
        modelChoice: parsedRequest.modelChoice,
        modelProvider: provider.providerId,
        messageText: parsedProvider.messageText,
        language: parsedRequest.language,
        workflow: parsedRequest.workflowType,
        draft: parsedProvider.draft,
        needsClarification: parsedProvider.needsClarification,
        clarificationQuestions: parsedProvider.clarificationQuestions,
        debugSummaryId: persisted.debugSummaryId,
        error: null,
      }),
      200,
    );
  } catch (error) {
    const gatewayError = toGatewayHttpError(error);
    if (
      env !== null &&
      accountId !== null &&
      gatewayError.code !== "auth_required"
    ) {
      await writeGatewayFailureLog(env, {
        accountId,
        request: parsedRequest,
        code: gatewayError.code,
        status: logStatusForCode(gatewayError.code),
        latencyMs: Date.now() - startedAt,
      });
    }

    return jsonResponse(
      gatewayResponse({
        modelChoice: parsedRequest?.modelChoice ?? null,
        modelProvider: providerIdForChoice(parsedRequest?.modelChoice ?? null),
        language: parsedRequest?.language ?? "zh",
        workflow: parsedRequest?.workflowType ?? "auto",
        error: {
          code: gatewayError.code,
          message: errorMessageForCode(gatewayError.code),
        },
      }),
      gatewayError.status,
    );
  }
});

interface GatewayEnv {
  supabaseUrl: string;
  supabaseAnonKey: string;
  supabaseServiceRoleKey: string;
}

function readGatewayEnv(): GatewayEnv {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const supabaseServiceRoleKey =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (
    supabaseUrl.trim() === "" ||
    supabaseAnonKey.trim() === "" ||
    supabaseServiceRoleKey.trim() === ""
  ) {
    throw new GatewayHttpError("provider_failure", 502);
  }
  return {
    supabaseUrl: supabaseUrl.replace(/\/+$/, ""),
    supabaseAnonKey,
    supabaseServiceRoleKey,
  };
}

async function verifyAccount(env: GatewayEnv, token: string): Promise<string> {
  const response = await fetch(`${env.supabaseUrl}/auth/v1/user`, {
    headers: {
      apikey: env.supabaseAnonKey,
      authorization: `Bearer ${token}`,
    },
  });
  if (!response.ok) {
    throw new GatewayHttpError("auth_required", 401);
  }
  const user = await response.json();
  const accountId = typeof user?.id === "string" ? user.id : "";
  if (accountId.trim() === "") {
    throw new GatewayHttpError("auth_required", 401);
  }
  return accountId;
}

async function checkSubscription(
  env: GatewayEnv,
  accountId: string,
): Promise<void> {
  const response = await fetch(
    `${env.supabaseUrl}/rest/v1/subscriptions?select=status&account_id=eq.${accountId}&limit=1`,
    {
      headers: serviceHeaders(env),
    },
  );
  if (!response.ok) {
    throw new GatewayHttpError("provider_failure", 502);
  }
  const rows = await response.json();
  const status = Array.isArray(rows) && rows.length > 0
    ? rows[0]?.status
    : null;
  if (status !== "active") {
    throw new GatewayHttpError("subscription_required", 403);
  }
}

async function assertActiveDevice(
  env: GatewayEnv,
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
    throw new GatewayHttpError("provider_failure", 502);
  }
  const result = await response.json();
  if (!allowsActiveDevice(result)) {
    throw new GatewayHttpError("device_replaced", 409);
  }
}

async function recordChatTurn(
  env: GatewayEnv,
  accountId: string,
  request: GatewayRequest,
  providerId: string,
  model: string,
  assistantText: string,
  finalAnswerJson: Record<string, unknown> | null,
  latencyMs: number,
): Promise<PersistedTurn> {
  const userMessageText = request.messageText.trim() || imageOnlyMessage(request);
  const response = await fetch(
    `${env.supabaseUrl}/rest/v1/rpc/record_ai_chat_turn`,
    {
      method: "POST",
      headers: serviceHeaders(env),
      body: JSON.stringify({
        input_account_id: accountId,
        input_session_id: request.sessionId,
        input_message_text: userMessageText,
        input_language: request.language,
        input_model_choice: request.modelChoice,
        input_workflow_type: request.workflowType,
        input_model_provider: providerId,
        input_model: model,
        input_prompt_version: "phase4_context_drafts_v1",
        input_schema_version: "ai_chat_response.v1",
        input_profile_version: request.profileVersion,
        input_latency_ms: latencyMs,
        input_token_estimate: estimateTokens(userMessageText, assistantText),
        input_assistant_text: assistantText,
        input_final_answer_json: finalAnswerJson,
        input_image_count: request.attachments.length,
      }),
    },
  );

  if (!response.ok) {
    const details = await response.text();
    if (details.includes("record_schema_mismatch")) {
      throw new GatewayHttpError("record_schema_mismatch", 422);
    }
    throw new GatewayHttpError("provider_failure", 502);
  }

  const result = await response.json();
  return {
    sessionId: stringField(result, "session_id"),
    assistantMessageId: stringField(result, "assistant_message_id"),
    debugSummaryId: stringField(result, "debug_summary_id"),
  };
}

function finalAnswerSnapshot(
  draft: GatewayDraft | null,
  request: GatewayRequest,
): Record<string, unknown> | null {
  if (draft === null) {
    return null;
  }
  const isWorkoutDraft = "schema_version" in draft &&
    draft.schema_version === "workout_draft.v1";
  return {
    schema_version: "ai_chat_artifacts.v1",
    artifacts: [
      isWorkoutDraft
        ? {
          type: "workout_draft",
          schema_version: "workout_draft.v1",
          record_name: draft.record_name,
          exercise_count: draft.exercises.length,
          draft,
          selected_date: request.selectedDate,
          model_choice: request.modelChoice,
        }
        : {
          type: "food_draft",
          schema_version: "food_draft.v1",
          draft,
          selected_date: request.selectedDate,
          model_choice: request.modelChoice,
        },
    ],
  };
}

async function writeGatewayFailureLog(
  env: GatewayEnv,
  params: {
    accountId: string;
    request: GatewayRequest | null;
    code: AiGatewayErrorCode;
    status: AiGatewayStatus;
    latencyMs: number;
  },
): Promise<void> {
  const requestId = crypto.randomUUID();
  const request = params.request;
  const logResponse = await fetch(`${env.supabaseUrl}/rest/v1/ai_request_logs`, {
    method: "POST",
    headers: {
      ...serviceHeaders(env),
      prefer: "return=minimal",
    },
    body: JSON.stringify({
      request_id: requestId,
      account_id: params.accountId,
      session_id: null,
      workflow_type: request?.workflowType ?? "auto",
      model_choice: request?.modelChoice ?? null,
      model_provider: providerIdForChoice(request?.modelChoice ?? null),
      model: null,
      prompt_version: "phase4_context_drafts_v1",
      schema_version: "ai_chat_response.v1",
      profile_version: request?.profileVersion ?? null,
      status: params.status,
      error_code: params.code,
      latency_ms: params.latencyMs,
      token_estimate: request === null
        ? null
        : Math.ceil(request.messageText.length / 4),
      image_count: request?.attachments.length ?? 0,
    }),
  });

  if (!logResponse.ok) {
    return;
  }

  await fetch(`${env.supabaseUrl}/rest/v1/ai_debug_summaries`, {
    method: "POST",
    headers: {
      ...serviceHeaders(env),
      prefer: "return=minimal",
    },
    body: JSON.stringify({
      request_id: requestId,
      account_id: params.accountId,
      session_id: null,
      intent: request?.workflowType ?? "ai_chat",
      intent_confidence: null,
      called_tools_json: [],
      retrieved_dimensions_json: [],
      missing_dimensions_json: [],
      safety_flags_json: [params.code],
      schema_validation_status: params.status === "blocked"
        ? "blocked"
        : "failed",
      user_final_action: params.status === "blocked" ? "blocked" : "none",
    }),
  });
}

function toGatewayHttpError(error: unknown): GatewayHttpError {
  if (error instanceof GatewayHttpError) {
    return error;
  }
  if (error instanceof GatewayRequestError) {
    return new GatewayHttpError(error.code, error.status);
  }
  if (error instanceof ProviderError) {
    return new GatewayHttpError(
      error.code,
      error.code === "gateway_timeout" ? 504 : 502,
    );
  }
  return new GatewayHttpError("provider_failure", 502);
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

function serviceHeaders(env: GatewayEnv): HeadersInit {
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

function providerIdForChoice(choice: string | null): string | null {
  switch (choice) {
    case "chatgpt":
      return "openai";
    case "qwen":
      return "qwen";
    default:
      return null;
  }
}

function imageOnlyMessage(request: GatewayRequest): string {
  if (request.attachments.length === 0) {
    return request.messageText;
  }
  return request.language === "zh" ? "请分析这些图片。" : "Please analyze these images.";
}
