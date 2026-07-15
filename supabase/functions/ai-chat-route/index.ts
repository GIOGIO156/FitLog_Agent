import { buildPhase5Context } from "./context_builders.ts";
import {
  OutputContractError,
  type OutputValidationIssue,
  outputValidatorVersion,
} from "../_shared/ai_output_contract.ts";
import {
  type AiGatewayErrorCode,
  type AiGatewayStatus,
  errorMessageForCode,
  estimateTokens,
  extractBearerToken,
  extractSessionIdFromAccessToken,
  type GatewayDraft,
  type GatewayRequest,
  GatewayRequestError,
  gatewayResponse,
  logStatusForCode,
  parseGatewayRequest,
  parseProviderGatewayBody,
  type PersistedTurn,
  type ProviderOutputType,
  stringField,
} from "./contracts.ts";
import type { Phase5Evidence } from "./phase5_types.ts";
import {
  phase5PromptContext,
  prependMealDecisionImageTip,
} from "./prompt_builder.ts";
import {
  type ProviderCompletion,
  ProviderError,
  providerForChoice,
  readProviderRuntimeConfig,
} from "./providers.ts";
import {
  type IntentResolutionSource,
  resolveOutputSelection,
} from "./expected_output.ts";
import { routeGatewayWorkflow } from "./workflow_router.ts";
import { resolveRecordDate } from "./record_date_resolver.ts";
import { draftConfirmationMessage } from "./draft_response_builder.ts";
import {
  type PipelineRuntimeConfig,
  readPipelineRuntimeConfig,
} from "./pipeline_config.ts";
import {
  buildApprovedTaskPlan,
  planToLegacyRoute,
} from "./planning/task_planner.ts";
import {
  type QueryEmbeddingConfig,
  qwenEmbeddingEndpoint,
} from "./rag/query_embedding.ts";
import {
  createModelTaskPlanner,
  createRetrievalRewritePlanner,
} from "./planning/model_planners.ts";
import { explicitFoodFactsFromText } from "../_shared/food_capability.ts";

const phase5PromptVersion = "phase5_rag_readonly_v1";
const phase5SchemaVersion = "ai_chat_response.v2";
const minimumCorrectionBudgetMs = 1500;
const edgeRuntimeStartedAt = Date.now();

interface OutputContractTelemetry {
  expectedOutput: "auto" | "text" | "food_draft" | "workout_draft";
  intentResolutionSource: IntentResolutionSource | null;
  selectedOutputType: ProviderOutputType | null;
  validationIssueCodes: string[];
  firstPassValidationStatus: "not_attempted" | "passed" | "failed" | "blocked";
  correctionAttemptCount: 0 | 1;
  finalValidationStatus: "not_attempted" | "passed" | "failed" | "blocked";
  providerCompletionStatus:
    | "not_called"
    | "completed"
    | "refusal"
    | "incomplete";
}

interface RuntimeStageTelemetry {
  edgeRuntimeUptimeMsAtStart: number;
  environmentLatencyMs: number;
  authLatencyMs: number;
  requestParseLatencyMs: number;
  subscriptionDeviceLatencyMs: number;
  plannerLatencyMs: number;
  retrievalLatencyMs: number;
  providerFirstPassLatencyMs: number;
  firstValidationLatencyMs: number;
  correctionLatencyMs: number;
  correctionValidationLatencyMs: number;
  persistenceLatencyMs: number;
}

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
          code: "request_schema_mismatch",
          message: errorMessageForCode("request_schema_mismatch"),
        },
      }),
      405,
    );
  }

  const startedAt = Date.now();
  let env: GatewayEnv | null = null;
  let accountId: string | null = null;
  let parsedRequest: GatewayRequest | null = null;
  let outputTelemetry: OutputContractTelemetry = defaultOutputTelemetry();
  const stageTelemetry: RuntimeStageTelemetry = {
    edgeRuntimeUptimeMsAtStart: startedAt - edgeRuntimeStartedAt,
    environmentLatencyMs: 0,
    authLatencyMs: 0,
    requestParseLatencyMs: 0,
    subscriptionDeviceLatencyMs: 0,
    plannerLatencyMs: 0,
    retrievalLatencyMs: 0,
    providerFirstPassLatencyMs: 0,
    firstValidationLatencyMs: 0,
    correctionLatencyMs: 0,
    correctionValidationLatencyMs: 0,
    persistenceLatencyMs: 0,
  };

  try {
    const environmentStartedAt = Date.now();
    env = readGatewayEnv();
    stageTelemetry.environmentLatencyMs = Date.now() - environmentStartedAt;
    const token = extractBearerToken(request.headers.get("authorization"));
    if (token === null) {
      throw new GatewayHttpError("auth_required", 401);
    }

    const authStartedAt = Date.now();
    accountId = await verifyAccount(env, token);
    stageTelemetry.authLatencyMs = Date.now() - authStartedAt;
    const sessionId = extractSessionIdFromAccessToken(token);
    if (sessionId === null) {
      throw new GatewayHttpError("device_replaced", 409);
    }

    const requestParseStartedAt = Date.now();
    let body: unknown;
    try {
      body = await request.json();
    } catch (_) {
      throw new GatewayRequestError("request_schema_mismatch");
    }
    parsedRequest = parseGatewayRequest(body);
    stageTelemetry.requestParseLatencyMs = Date.now() - requestParseStartedAt;

    const subscriptionDeviceStartedAt = Date.now();
    await Promise.all([
      checkSubscription(env, accountId),
      assertActiveDevice(env, token, parsedRequest.deviceId, sessionId),
    ]);
    stageTelemetry.subscriptionDeviceLatencyMs = Date.now() -
      subscriptionDeviceStartedAt;

    const providerConfig = readProviderRuntimeConfig();
    const modelTaskPlanner = createModelTaskPlanner(
      parsedRequest.modelChoice,
      providerConfig,
    );
    const plannerStartedAt = Date.now();
    const taskPlan = env.pipeline.contextPipelineVersion === "rag_foundation_v1"
      ? await buildApprovedTaskPlan(parsedRequest, modelTaskPlanner)
      : null;
    stageTelemetry.plannerLatencyMs = Date.now() - plannerStartedAt;
    const route = taskPlan === null
      ? routeGatewayWorkflow(parsedRequest)
      : planToLegacyRoute(taskPlan);
    const retrievalStartedAt = Date.now();
    parsedRequest = {
      ...parsedRequest,
      workflowType: route.workflow,
      taskPlan,
    };
    parsedRequest = {
      ...parsedRequest,
      phase5Context: await buildPhase5Context(
        {
          ...env,
          retrievalRewritePlanner: createRetrievalRewritePlanner(
            parsedRequest,
            providerConfig,
          ),
        },
        accountId,
        parsedRequest,
        route,
      ),
    };
    stageTelemetry.retrievalLatencyMs = Date.now() - retrievalStartedAt;
    const outputSelection = taskPlan === null
      ? resolveOutputSelection(parsedRequest)
      : {
        expectedOutput: taskPlan.expected_output,
        source: taskPlan.source === "model"
          ? "model" as const
          : "deterministic" as const,
        reason: taskPlan.reasons[0] ?? "task_plan",
      };
    const dateResolution = resolveRecordDate(
      parsedRequest.messageText,
      parsedRequest.selectedDate,
    );
    parsedRequest = {
      ...parsedRequest,
      expectedOutput: outputSelection.expectedOutput,
      targetDate: dateResolution.targetDate,
      dateResolutionSource: dateResolution.source,
    };
    outputTelemetry = {
      ...outputTelemetry,
      expectedOutput: parsedRequest.expectedOutput,
      intentResolutionSource: outputSelection.source,
    };

    if (taskPlan?.requires_clarification === true) {
      outputTelemetry = {
        ...outputTelemetry,
        selectedOutputType: "clarification",
        firstPassValidationStatus: "passed",
        finalValidationStatus: "passed",
      };
      const assistantText = plannerClarificationMessage(parsedRequest.language);
      const evidence = evidenceFromRequest(parsedRequest, "read_only");
      const persistenceStartedAt = Date.now();
      const persisted = await recordChatTurn(
        env,
        accountId,
        parsedRequest,
        providerIdForChoice(parsedRequest.modelChoice) ?? "qwen",
        "task_plan.v1",
        assistantText,
        finalAnswerSnapshot(null, parsedRequest, evidence),
        Date.now() - startedAt,
      );
      stageTelemetry.persistenceLatencyMs = Date.now() - persistenceStartedAt;
      await updateDebugSummary(
        env,
        persisted.debugSummaryId,
        persisted.requestId,
        parsedRequest,
        evidence,
        providerIdForChoice(parsedRequest.modelChoice) ?? "qwen",
        stageTelemetry,
        outputTelemetry,
      );
      await updateOutputContractTelemetry(
        env,
        persisted.requestId,
        outputTelemetry,
      );
      return jsonResponse(
        gatewayResponse({
          sessionId: persisted.sessionId,
          assistantMessageId: persisted.assistantMessageId,
          modelChoice: parsedRequest.modelChoice,
          modelProvider: null,
          messageText: assistantText,
          language: parsedRequest.language,
          workflow: parsedRequest.workflowType,
          outputType: "clarification",
          draft: null,
          needsClarification: true,
          clarificationQuestions: [assistantText],
          debugSummaryId: persisted.debugSummaryId,
          evidence,
          error: null,
        }),
        200,
      );
    }

    if (route.safety_flags.length > 0) {
      outputTelemetry = {
        ...outputTelemetry,
        firstPassValidationStatus: "blocked",
        finalValidationStatus: "blocked",
      };
      const assistantText = readOnlyBoundaryMessage(parsedRequest.language);
      const evidence = evidenceFromRequest(parsedRequest, "blocked");
      const persistenceStartedAt = Date.now();
      const persisted = await recordChatTurn(
        env,
        accountId,
        parsedRequest,
        providerIdForChoice(parsedRequest.modelChoice) ?? "openai",
        "phase5-read-only-boundary",
        assistantText,
        finalAnswerSnapshot(null, parsedRequest, evidence),
        Date.now() - startedAt,
      );
      stageTelemetry.persistenceLatencyMs = Date.now() - persistenceStartedAt;
      await updateDebugSummary(
        env,
        persisted.debugSummaryId,
        persisted.requestId,
        parsedRequest,
        evidence,
        providerIdForChoice(parsedRequest.modelChoice) ?? "openai",
        stageTelemetry,
        outputTelemetry,
      );
      await updateOutputContractTelemetry(
        env,
        persisted.requestId,
        outputTelemetry,
      );

      return jsonResponse(
        gatewayResponse({
          sessionId: persisted.sessionId,
          assistantMessageId: persisted.assistantMessageId,
          modelChoice: parsedRequest.modelChoice,
          modelProvider: providerIdForChoice(parsedRequest.modelChoice),
          messageText: assistantText,
          language: parsedRequest.language,
          workflow: parsedRequest.workflowType,
          outputType: "text",
          draft: null,
          needsClarification: false,
          clarificationQuestions: [],
          debugSummaryId: persisted.debugSummaryId,
          evidence,
          error: null,
        }),
        200,
      );
    }

    const provider = providerForChoice(
      parsedRequest.modelChoice,
      providerConfig,
    );
    const deadlineAt = startedAt + providerConfig.timeoutMs;
    const providerFirstPassStartedAt = Date.now();
    let completion: ProviderCompletion;
    try {
      completion = await provider.generateText(parsedRequest, {
        timeoutMs: remainingDeadline(deadlineAt),
      });
    } finally {
      stageTelemetry.providerFirstPassLatencyMs = Date.now() -
        providerFirstPassStartedAt;
    }
    outputTelemetry = {
      ...outputTelemetry,
      providerCompletionStatus: completion.status,
    };
    assertCompleted(completion);

    let parsedProvider;
    const firstValidationStartedAt = Date.now();
    try {
      parsedProvider = parseProviderGatewayBody(
        completion.content,
        parsedRequest,
      );
      outputTelemetry = {
        ...outputTelemetry,
        selectedOutputType: parsedProvider.outputType,
        firstPassValidationStatus: "passed",
        finalValidationStatus: "passed",
      };
    } catch (error) {
      stageTelemetry.firstValidationLatencyMs = Date.now() -
        firstValidationStartedAt;
      if (!(error instanceof OutputContractError)) throw error;
      outputTelemetry = {
        ...outputTelemetry,
        firstPassValidationStatus: "failed",
        validationIssueCodes: validationIssueCodes(error.issues),
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
      const correctionStartedAt = Date.now();
      try {
        completion = await provider.generateText(parsedRequest, {
          timeoutMs: remaining,
          correction: {
            previousOutput: completion.content,
            issues: error.issues,
          },
        });
      } finally {
        stageTelemetry.correctionLatencyMs = Date.now() - correctionStartedAt;
      }
      outputTelemetry = {
        ...outputTelemetry,
        providerCompletionStatus: completion.status,
      };
      assertCompleted(completion);
      const correctionValidationStartedAt = Date.now();
      try {
        parsedProvider = parseProviderGatewayBody(
          completion.content,
          parsedRequest,
        );
        outputTelemetry = {
          ...outputTelemetry,
          selectedOutputType: parsedProvider.outputType,
          finalValidationStatus: "passed",
        };
        stageTelemetry.correctionValidationLatencyMs = Date.now() -
          correctionValidationStartedAt;
      } catch (correctionError) {
        stageTelemetry.correctionValidationLatencyMs = Date.now() -
          correctionValidationStartedAt;
        outputTelemetry = {
          ...outputTelemetry,
          finalValidationStatus: "failed",
          validationIssueCodes: correctionError instanceof OutputContractError
            ? validationIssueCodes(correctionError.issues)
            : outputTelemetry.validationIssueCodes,
        };
        throw correctionError;
      }
    }
    if (stageTelemetry.firstValidationLatencyMs === 0) {
      stageTelemetry.firstValidationLatencyMs = Date.now() -
        firstValidationStartedAt;
    }
    const providerGuard = guardProviderOutput(
      parsedProvider.messageText,
      parsedRequest,
    );
    const draft = providerGuard.allowDraft ? parsedProvider.draft : null;
    const assistantText = draft !== null
      ? draftConfirmationMessage(parsedRequest.language, draft)
      : parsedProvider.outputType === "text"
      ? prependMealDecisionImageTip(providerGuard.messageText, parsedRequest)
      : providerGuard.messageText;
    const evidence = evidenceFromRequest(
      parsedRequest,
      draft === null ? "read_only" : "artifact_returned",
      providerGuard.safetyFlag,
    );
    const persistenceStartedAt = Date.now();
    const persisted = await recordChatTurn(
      env,
      accountId,
      parsedRequest,
      provider.providerId,
      provider.model,
      assistantText,
      finalAnswerSnapshot(draft, parsedRequest, evidence),
      Date.now() - startedAt,
    );
    stageTelemetry.persistenceLatencyMs = Date.now() - persistenceStartedAt;
    await updateDebugSummary(
      env,
      persisted.debugSummaryId,
      persisted.requestId,
      parsedRequest,
      evidence,
      provider.providerId,
      stageTelemetry,
      outputTelemetry,
    );
    await updateOutputContractTelemetry(
      env,
      persisted.requestId,
      outputTelemetry,
    );

    return jsonResponse(
      gatewayResponse({
        sessionId: persisted.sessionId,
        assistantMessageId: persisted.assistantMessageId,
        modelChoice: parsedRequest.modelChoice,
        modelProvider: provider.providerId,
        messageText: assistantText,
        language: parsedRequest.language,
        workflow: parsedRequest.workflowType,
        outputType: parsedProvider.outputType,
        draft: draftForClient(draft, parsedRequest),
        needsClarification: providerGuard.allowDraft
          ? parsedProvider.needsClarification
          : false,
        clarificationQuestions: providerGuard.allowDraft
          ? parsedProvider.clarificationQuestions
          : [],
        debugSummaryId: persisted.debugSummaryId,
        evidence,
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
        telemetry: outputTelemetry,
        stageTelemetry,
      });
    }

    return jsonResponse(
      gatewayResponse({
        modelChoice: parsedRequest?.modelChoice ?? null,
        modelProvider: providerIdForChoice(parsedRequest?.modelChoice ?? null),
        language: parsedRequest?.language ?? "zh",
        workflow: parsedRequest?.workflowType ?? "auto",
        outputType: null,
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
  pipeline: PipelineRuntimeConfig;
  documentEmbedding: QueryEmbeddingConfig | null;
}

function draftForClient(
  draft: GatewayDraft | null,
  request: GatewayRequest,
): GatewayDraft | Record<string, unknown> | null {
  if (draft === null || request.clientDraftSchemaVersion === "v3") {
    return draft;
  }
  const legacy = { ...draft } as Record<string, unknown>;
  if (draft.schema_version === "food_draft.v2") {
    legacy.schema_version = "food_draft.v1";
    delete legacy.date;
  } else {
    legacy.schema_version = request.clientDraftSchemaVersion === "v2"
      ? "workout_draft.v2"
      : "workout_draft.v1";
    legacy.exercises = draft.exercises.map((exercise) => {
      const value = { ...exercise } as Record<string, unknown>;
      delete value.exercise_source;
      delete value.definition_hash;
      delete value.load_input_mode;
      delete value.reps_input_mode;
      delete value.set_metric_type;
      return value;
    });
  }
  return legacy;
}

function readGatewayEnv(): GatewayEnv {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    "";
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
    pipeline: readPipelineRuntimeConfig(),
    documentEmbedding: documentEmbeddingConfig(),
  };
}

function documentEmbeddingConfig(): QueryEmbeddingConfig | null {
  const apiKey = Deno.env.get("FITLOG_QWEN_API_KEY")?.trim() ?? "";
  const baseUrl = Deno.env.get("FITLOG_QWEN_BASE_URL")?.trim() ?? "";
  const model = Deno.env.get("FITLOG_DOCUMENT_EMBEDDING_MODEL")?.trim() ?? "";
  if (apiKey === "" || baseUrl === "" || model === "") return null;
  try {
    return {
      endpoint: qwenEmbeddingEndpoint(baseUrl),
      apiKey,
      model,
      timeoutMs: 5000,
    };
  } catch {
    return null;
  }
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
  const userMessageText = request.messageText.trim() ||
    imageOnlyMessage(request);
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
        input_prompt_version: phase5PromptVersion,
        input_schema_version: phase5SchemaVersion,
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
    requestId: stringField(result, "request_id"),
    sessionId: stringField(result, "session_id"),
    assistantMessageId: stringField(result, "assistant_message_id"),
    debugSummaryId: stringField(result, "debug_summary_id"),
  };
}

function finalAnswerSnapshot(
  draft: GatewayDraft | null,
  request: GatewayRequest,
  evidence: Phase5Evidence | null,
): Record<string, unknown> | null {
  const hasVisibleEvidence = evidence !== null &&
    (evidence.context_objects.length > 0 ||
      evidence.document_sources.length > 0 ||
      evidence.missing_dimensions.length > 0 ||
      evidence.safety_flags.length > 0);
  if (draft === null) {
    return hasVisibleEvidence
      ? {
        schema_version: "ai_chat_evidence.v1",
        evidence,
      }
      : null;
  }
  const isWorkoutDraft = draft.schema_version === "workout_draft.v3";
  return {
    schema_version: "ai_chat_artifacts.v2",
    artifacts: [
      isWorkoutDraft
        ? {
          type: "workout_draft",
          schema_version: "workout_draft.v3",
          record_name: draft.record_name,
          exercise_count: draft.exercises.length,
          draft,
          target_date: draft.date,
          date_resolution_source: request.dateResolutionSource,
          model_choice: request.modelChoice,
        }
        : {
          type: "food_draft",
          schema_version: "food_draft.v2",
          draft,
          target_date: draft.date,
          date_resolution_source: request.dateResolutionSource,
          model_choice: request.modelChoice,
        },
    ],
    ...(hasVisibleEvidence ? { evidence } : {}),
  };
}

function evidenceFromRequest(
  request: GatewayRequest,
  action: Phase5Evidence["user_final_action"],
  extraSafetyFlag?: string | null,
): Phase5Evidence {
  const context = request.phase5Context;
  const safetyFlags = unique([
    ...(context?.safety_flags ?? []),
    ...(extraSafetyFlag === null || extraSafetyFlag === undefined
      ? []
      : [extraSafetyFlag]),
  ]);
  return {
    workflow: request.workflowType,
    context_objects: context?.context_objects.map((object) => object.type) ??
      [],
    document_sources: context?.document_sources ?? [],
    missing_dimensions: context?.missing_dimensions ?? [],
    safety_flags: safetyFlags,
    user_final_action: action,
  };
}

function guardProviderOutput(
  messageText: string,
  request: GatewayRequest,
): {
  messageText: string;
  allowDraft: boolean;
  safetyFlag: string | null;
} {
  const route = request.phase5Context?.route;
  if (
    route?.read_only !== true ||
    request.expectedOutput === "food_draft" ||
    request.expectedOutput === "workout_draft"
  ) {
    return { messageText, allowDraft: true, safetyFlag: null };
  }
  if (providerClaimedWrite(messageText)) {
    return {
      messageText: readOnlyBoundaryMessage(request.language),
      allowDraft: false,
      safetyFlag: "provider_claimed_write_blocked",
    };
  }
  return { messageText, allowDraft: false, safetyFlag: null };
}

function providerClaimedWrite(value: string): boolean {
  return /已保存|已修改|已应用|已删除|已经保存|已经修改|saved|deleted|changed your goal|updated your goal|applied carb taper/i
    .test(value);
}

function validationIssueCodes(issues: OutputValidationIssue[]): string[] {
  return unique(issues.map((item) => {
    if (
      /approved_evidence|matching_evidence|missing_dimension/i.test(item.reason)
    ) {
      return `grounding_${item.reason}`;
    }
    if (/response_language|explicit_fact|macro_energy/i.test(item.reason)) {
      return `semantic_${item.reason}`;
    }
    if (item.path === "$" && /json|object/i.test(item.reason)) {
      return "json_syntax_or_root";
    }
    if (item.path === "$.output_type") return "output_type_mismatch";
    if (item.reason.includes("claim that a draft was created")) {
      return "false_draft_success_claim";
    }
    if (item.path.startsWith("$.clarification")) {
      return "clarification_inconsistent";
    }
    if (item.path.startsWith("$.draft.schema_version")) {
      return "draft_family_mismatch";
    }
    if (item.path === "$.draft.date") return "draft_date_mismatch";
    if (item.path.startsWith("$.draft")) return "draft_contract_invalid";
    return "envelope_contract_invalid";
  })).slice(0, 8);
}

function readOnlyBoundaryMessage(language: "zh" | "en"): string {
  return language === "zh"
    ? "我不能直接写入、删除记录、修改目标或应用策略。请在对应页面手动确认这些操作；我可以说明需要检查哪些数据和下一步怎么操作。"
    : "I cannot directly write records, delete records, change goals, or apply strategies. Use the normal confirmed UI for those actions; I can explain what to check and what to do next.";
}

function plannerClarificationMessage(language: "zh" | "en"): string {
  return language === "zh"
    ? "请说明你希望我回答问题、估算并生成食物草稿，还是生成训练草稿。"
    : "Please say whether you want an answer, a food estimate and draft, or a workout draft.";
}

async function updateDebugSummary(
  env: GatewayEnv,
  debugSummaryId: string,
  requestId: string,
  request: GatewayRequest,
  evidence: Phase5Evidence,
  providerId: string,
  stageTelemetry: RuntimeStageTelemetry,
  outputTelemetry: OutputContractTelemetry,
): Promise<void> {
  const context = request.phase5Context;
  try {
    const response = await fetch(
      `${env.supabaseUrl}/rest/v1/ai_debug_summaries?id=eq.${debugSummaryId}`,
      {
        method: "PATCH",
        headers: {
          ...serviceHeaders(env),
          prefer: "return=minimal",
        },
        body: JSON.stringify({
          intent: request.workflowType,
          intent_confidence: context?.route.confidence ?? null,
          called_tools_json: unique([
            providerId,
            ...(context?.called_tools ?? []),
          ]),
          retrieved_dimensions_json: [
            ...(context?.retrieved_dimensions ?? []),
            ...evidence.document_sources.map((source) =>
              `${source.doc_path}#${source.section_id}`
            ),
          ],
          missing_dimensions_json: evidence.missing_dimensions,
          safety_flags_json: evidence.safety_flags,
          schema_validation_status: evidence.user_final_action === "blocked"
            ? "blocked"
            : "passed",
          user_final_action: evidence.user_final_action,
        }),
      },
    );
    if (!response.ok) {
      console.warn("phase5_debug_summary_patch_failed", {
        status: response.status,
      });
      return;
    }
    const retrieval = context?.retrieval_debug;
    const taskPlan = request.taskPlan;
    const foodUnderstanding = explicitFoodFactsFromText(request.messageText);
    const logResponse = await fetch(
      `${env.supabaseUrl}/rest/v1/ai_request_logs?request_id=eq.${requestId}`,
      {
        method: "PATCH",
        headers: {
          ...serviceHeaders(env),
          prefer: "return=minimal",
        },
        body: JSON.stringify({
          surface: "ai_chat",
          capability: request.expectedOutput,
          provider_adapter_version: "provider_adapters.v2",
          policy_version: "rag_context_policy.v1",
          target_response_language: request.language,
          language_validation_status: outputTelemetry.finalValidationStatus,
          task_plan_version: taskPlan?.schema_version ?? null,
          task_plan_source: taskPlan?.source ?? null,
          task_plan_confidence: taskPlan?.confidence ?? null,
          planned_workflow: taskPlan?.planned_workflow ?? request.workflowType,
          requested_context_types_json: taskPlan?.requested_context ?? [],
          approved_context_types_json: taskPlan?.approved_context ?? [],
          rejected_context_types_json: taskPlan?.rejected_context ?? [],
          query_language_profile: retrieval?.query_language_profile ?? null,
          canonical_concept_ids_json: retrieval?.canonical_concept_ids ?? [],
          corpus_id: retrieval?.corpus_id ?? null,
          corpus_build_id: retrieval?.corpus_build_id ?? null,
          embedding_model: retrieval?.embedding_model ?? null,
          reranker_version: retrieval?.reranker_version ?? null,
          retrieval_branch_counts_json: retrieval?.branch_hits ?? {},
          retrieval_final_hit_count: retrieval?.final_hit_count ?? 0,
          retrieval_coverage_status: retrieval?.coverage_status ?? null,
          retrieval_missing_dimensions_json: retrieval?.missing_dimensions ??
            [],
          retrieval_retry_reason: retrieval?.retry_reason ?? null,
          retrieval_retry_count: retrieval?.retry_count ?? 0,
          retrieval_retry_gain: retrieval?.retry_gain ?? false,
          retrieval_issue_codes_json: retrieval?.issue_codes ?? [],
          planner_latency_ms: stageTelemetry.plannerLatencyMs,
          retrieval_latency_ms: stageTelemetry.retrievalLatencyMs,
          correction_latency_ms: stageTelemetry.correctionLatencyMs,
          latency_breakdown_json: latencyBreakdownJson(stageTelemetry, request),
          prompt_context_bytes: new TextEncoder().encode(
            phase5PromptContext(request),
          ).length,
          grounding_validation_status: taskPlan !== null &&
              taskPlan !== undefined && request.expectedOutput === "text"
            ? outputTelemetry.finalValidationStatus
            : "not_applicable",
          grounding_issue_codes_json: outputTelemetry.validationIssueCodes
            .filter((code) =>
              code.includes("ground") || code.includes("evidence")
            ),
          food_fact_count: foodUnderstanding.facts.length,
          food_conflict_count: foodUnderstanding.conflict_count,
          semantic_validation_status: request.expectedOutput === "food_draft"
            ? outputTelemetry.finalValidationStatus
            : "not_applicable",
          semantic_issue_codes_json: outputTelemetry.validationIssueCodes,
          final_action: evidence.user_final_action,
        }),
      },
    );
    if (!logResponse.ok) {
      console.warn("rag_request_log_patch_failed", {
        status: logResponse.status,
      });
    }
  } catch (error) {
    console.warn("phase5_debug_summary_patch_error", {
      message: error instanceof Error ? error.message : String(error),
    });
    return;
  }
}

async function writeGatewayFailureLog(
  env: GatewayEnv,
  params: {
    accountId: string;
    request: GatewayRequest | null;
    code: AiGatewayErrorCode;
    status: AiGatewayStatus;
    latencyMs: number;
    telemetry: OutputContractTelemetry;
    stageTelemetry: RuntimeStageTelemetry;
  },
): Promise<void> {
  const requestId = crypto.randomUUID();
  const request = params.request;
  const retrieval = request?.phase5Context?.retrieval_debug;
  const failurePersistenceStartedAt = Date.now();
  const logResponse = await fetch(
    `${env.supabaseUrl}/rest/v1/ai_request_logs`,
    {
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
        prompt_version: phase5PromptVersion,
        schema_version: phase5SchemaVersion,
        profile_version: request?.profileVersion ?? null,
        status: params.status,
        error_code: params.code,
        latency_ms: params.latencyMs,
        token_estimate: request === null
          ? null
          : Math.ceil(request.messageText.length / 4),
        image_count: request?.attachments.length ?? 0,
        expected_output: params.telemetry.expectedOutput,
        intent_resolution_source: params.telemetry.intentResolutionSource,
        selected_output_type: params.telemetry.selectedOutputType,
        validation_issue_codes_json: params.telemetry.validationIssueCodes,
        validator_version: outputValidatorVersion,
        first_pass_validation_status:
          params.telemetry.firstPassValidationStatus,
        correction_attempt_count: params.telemetry.correctionAttemptCount,
        final_validation_status: params.telemetry.finalValidationStatus,
        provider_completion_status: params.telemetry.providerCompletionStatus,
        surface: "ai_chat",
        capability: request?.expectedOutput ?? "unknown",
        provider_adapter_version: "provider_adapters.v2",
        policy_version: "rag_context_policy.v1",
        target_response_language: request?.language ?? null,
        task_plan_version: request?.taskPlan?.schema_version ?? null,
        task_plan_source: request?.taskPlan?.source ?? null,
        task_plan_confidence: request?.taskPlan?.confidence ?? null,
        planned_workflow: request?.taskPlan?.planned_workflow ??
          request?.workflowType ?? null,
        requested_context_types_json: request?.taskPlan?.requested_context ??
          [],
        approved_context_types_json: request?.taskPlan?.approved_context ?? [],
        rejected_context_types_json: request?.taskPlan?.rejected_context ?? [],
        query_language_profile: retrieval?.query_language_profile ?? null,
        canonical_concept_ids_json: retrieval?.canonical_concept_ids ?? [],
        corpus_id: retrieval?.corpus_id ?? null,
        corpus_build_id: retrieval?.corpus_build_id ?? null,
        embedding_model: retrieval?.embedding_model ?? null,
        reranker_version: retrieval?.reranker_version ?? null,
        retrieval_branch_counts_json: retrieval?.branch_hits ?? {},
        retrieval_final_hit_count: retrieval?.final_hit_count ?? 0,
        retrieval_coverage_status: retrieval?.coverage_status ?? null,
        retrieval_missing_dimensions_json: retrieval?.missing_dimensions ?? [],
        retrieval_retry_reason: retrieval?.retry_reason ?? null,
        retrieval_retry_count: retrieval?.retry_count ?? 0,
        retrieval_retry_gain: retrieval?.retry_gain ?? false,
        retrieval_issue_codes_json: retrieval?.issue_codes ?? [],
        semantic_validation_status: request?.expectedOutput === "food_draft"
          ? params.telemetry.finalValidationStatus
          : "not_applicable",
        semantic_issue_codes_json: params.telemetry.validationIssueCodes,
        final_action: "none",
        planner_latency_ms: params.stageTelemetry.plannerLatencyMs,
        retrieval_latency_ms: params.stageTelemetry.retrievalLatencyMs,
        correction_latency_ms: params.stageTelemetry.correctionLatencyMs,
        latency_breakdown_json: latencyBreakdownJson(
          params.stageTelemetry,
          request,
        ),
      }),
    },
  );

  if (!logResponse.ok) {
    return;
  }

  params.stageTelemetry.persistenceLatencyMs = Date.now() -
    failurePersistenceStartedAt;
  await fetch(
    `${env.supabaseUrl}/rest/v1/ai_request_logs?request_id=eq.${requestId}`,
    {
      method: "PATCH",
      headers: {
        ...serviceHeaders(env),
        prefer: "return=minimal",
      },
      body: JSON.stringify({
        latency_breakdown_json: latencyBreakdownJson(
          params.stageTelemetry,
          request,
        ),
      }),
    },
  );

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

function latencyBreakdownJson(
  telemetry: RuntimeStageTelemetry,
  request: GatewayRequest | null,
): Record<string, unknown> {
  const retrieval = request?.phase5Context?.retrieval_debug?.latency_breakdown;
  const retrievalDebug = request?.phase5Context?.retrieval_debug;
  const initial = retrieval?.attempts[0];
  const retry = retrieval?.attempts[1];
  return {
    schema_version: "ai_latency_breakdown.v1",
    edge_runtime_uptime_ms_at_start: telemetry.edgeRuntimeUptimeMsAtStart,
    environment_ms: telemetry.environmentLatencyMs,
    auth_ms: telemetry.authLatencyMs,
    request_parse_ms: telemetry.requestParseLatencyMs,
    subscription_device_ms: telemetry.subscriptionDeviceLatencyMs,
    planner_ms: telemetry.plannerLatencyMs,
    context_build_ms: telemetry.retrievalLatencyMs,
    first_retrieval_coverage_status: retrievalDebug?.first_coverage_status ??
      "not_requested",
    first_missing_dimension_count:
      retrievalDebug?.first_missing_dimensions.length ?? 0,
    retrieval_attempt_count: retrieval?.attempts.length ?? 0,
    retry_action: retrievalDebug?.retry_action ?? "not_requested",
    retry_query_changed: retrievalDebug?.retry_query_changed ?? false,
    final_retrieval_coverage_status: retrievalDebug?.coverage_status ??
      "not_requested",
    initial_query_normalization_ms: initial?.normalization_ms ?? null,
    initial_embedding_ms: initial?.embedding_ms ?? null,
    initial_embedding_status: initial?.embedding_status ?? "not_requested",
    initial_embedding_input_chars: initial?.embedding_input_chars ?? 0,
    initial_query_variant_count: initial?.query_variant_count ?? 0,
    initial_lexical_candidate_rpc_ms: initial?.lexical_candidate_rpc_ms ?? null,
    initial_hybrid_rpc_ms: initial?.hybrid_rpc_ms ?? null,
    initial_reranker_ms: initial?.reranker_ms ?? null,
    rewrite_planner_ms: retrieval?.rewrite_planner_ms ?? null,
    retry_query_normalization_ms: retry?.normalization_ms ?? null,
    retry_embedding_ms: retry?.embedding_ms ?? null,
    retry_embedding_status: retry?.embedding_status ?? "not_requested",
    retry_lexical_candidate_rpc_ms: retry?.lexical_candidate_rpc_ms ?? null,
    retry_hybrid_rpc_ms: retry?.hybrid_rpc_ms ?? null,
    retry_reranker_ms: retry?.reranker_ms ?? null,
    provider_first_pass_ms: telemetry.providerFirstPassLatencyMs,
    provider_first_validation_ms: telemetry.firstValidationLatencyMs,
    provider_correction_ms: telemetry.correctionLatencyMs,
    provider_correction_validation_ms: telemetry.correctionValidationLatencyMs,
    persistence_ms: telemetry.persistenceLatencyMs,
  };
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
  if (error instanceof OutputContractError) {
    return new GatewayHttpError("provider_output_invalid", 502);
  }
  return new GatewayHttpError("provider_failure", 502);
}

function defaultOutputTelemetry(): OutputContractTelemetry {
  return {
    expectedOutput: "auto",
    intentResolutionSource: null,
    selectedOutputType: null,
    validationIssueCodes: [],
    firstPassValidationStatus: "not_attempted",
    correctionAttemptCount: 0,
    finalValidationStatus: "not_attempted",
    providerCompletionStatus: "not_called",
  };
}

function remainingDeadline(deadlineAt: number): number {
  const remaining = deadlineAt - Date.now();
  if (remaining <= 0) throw new GatewayHttpError("gateway_timeout", 504);
  return remaining;
}

function assertCompleted(completion: ProviderCompletion): void {
  switch (completion.status) {
    case "completed":
      return;
    case "refusal":
      throw new GatewayHttpError("provider_refusal", 422);
    case "incomplete":
      throw new GatewayHttpError("provider_incomplete", 502);
  }
}

async function updateOutputContractTelemetry(
  env: GatewayEnv,
  requestId: string,
  telemetry: OutputContractTelemetry,
): Promise<void> {
  try {
    const response = await fetch(
      `${env.supabaseUrl}/rest/v1/ai_request_logs?request_id=eq.${requestId}`,
      {
        method: "PATCH",
        headers: { ...serviceHeaders(env), prefer: "return=minimal" },
        body: JSON.stringify({
          expected_output: telemetry.expectedOutput,
          intent_resolution_source: telemetry.intentResolutionSource,
          selected_output_type: telemetry.selectedOutputType,
          validation_issue_codes_json: telemetry.validationIssueCodes,
          validator_version: outputValidatorVersion,
          first_pass_validation_status: telemetry.firstPassValidationStatus,
          correction_attempt_count: telemetry.correctionAttemptCount,
          final_validation_status: telemetry.finalValidationStatus,
          provider_completion_status: telemetry.providerCompletionStatus,
        }),
      },
    );
    if (!response.ok) {
      console.warn("output_contract_telemetry_patch_failed", {
        status: response.status,
      });
    }
  } catch (error) {
    console.warn("output_contract_telemetry_patch_error", {
      message: error instanceof Error ? error.message : String(error),
    });
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
  return request.language === "zh"
    ? "请分析这些图片。"
    : "Please analyze these images.";
}

function unique(values: string[]): string[] {
  return [...new Set(values.filter((value) => value.trim() !== ""))];
}
