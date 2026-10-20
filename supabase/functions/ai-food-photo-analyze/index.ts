import {
  buildOpenAiVisionRequestBody,
  buildQwenVisionRequestBody,
  errorMessageForCode,
  extractOpenAiVisionCompletion,
  extractQwenCompletion,
  type FoodDraft,
  foodDraftForClient,
  type FoodProviderCompletion,
  logStatusForCode,
  parsePhotoAnalysisRequest,
  parseProviderFoodDraftBody,
  type PhotoAnalysisRequest,
  photoGatewayAcceptedResponse,
  type PhotoGatewayErrorCode,
  PhotoGatewayRequestError,
  photoGatewayResponse,
  type PhotoGatewayStatus,
  stripImageDataForDebug,
} from "./contracts.ts";
import {
  OutputContractError,
  outputValidatorVersion,
} from "../_shared/ai_output_contract.ts";
import { explicitFoodFactsFromText } from "../_shared/food_capability.ts";
import {
  classifyResponseLanguage,
  type ResponseLanguageStatus,
} from "../_shared/response_language_policy.ts";

const minimumCorrectionBudgetMs = 1500;

interface PhotoOutputTelemetry {
  firstPassValidationStatus: "not_attempted" | "passed" | "failed";
  correctionAttemptCount: 0 | 1;
  correctionLatencyMs: number;
  finalValidationStatus: "not_attempted" | "passed" | "failed";
  languageValidationStatus: ResponseLanguageStatus;
  providerCompletionStatus:
    | "not_called"
    | "completed"
    | "refusal"
    | "incomplete";
}

interface PhotoStageTelemetry {
  preAcceptAssetUploadMs: number | null;
  claimMs: number;
  assetLoadMs: number;
  providerFirstPassMs: number;
  firstValidationMs: number;
  correctionMs: number;
  correctionValidationMs: number;
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
  let providerConfig: PhotoProviderConfig | null = null;
  let accountId: string | null = null;
  let parsedRequest: PhotoAnalysisRequest | null = null;
  let outputTelemetry = defaultPhotoOutputTelemetry();
  const stageTelemetry = defaultPhotoStageTelemetry();

  try {
    env = readPhotoGatewayEnv();
    if (isPhotoDeliveryWorkerRequest(request, env)) {
      const workerBody = recordValue(await request.json().catch(() => ({})));
      if (workerBody.worker_action === "process_pending") {
        const processed = await processPhotoDeliveryQueue(
          env,
          boundedWorkerLimit(workerBody.limit),
        );
        return jsonResponse({ processed }, 200);
      }
      if (workerBody.worker_action === "process_one") {
        const requestId = typeof workerBody.request_id === "string"
          ? workerBody.request_id
          : null;
        if (requestId === null) {
          return jsonResponse({ processed: 0 }, 422);
        }
        await processPhotoDeliveryRequest(env, requestId);
        return jsonResponse({ processed: 1 }, 200);
      }
    }
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
    providerConfig = readPhotoProviderConfig(parsedRequest.modelChoice);

    await checkSubscription(env, accountId);
    await assertActiveDevice(env, token, parsedRequest.deviceId, sessionId);

    if (parsedRequest.deliveryMode === "async_v1") {
      const accepted = await acceptPhotoDeliveryRequest(
        env,
        accountId,
        parsedRequest,
        body,
      );
      waitUntil(processPhotoDeliveryRequest(env, accepted.requestId));
      return jsonResponse(
        photoGatewayAcceptedResponse({
          requestId: accepted.requestId,
          status: accepted.status,
          duplicateSubmit: accepted.duplicateSubmit,
          retryable: accepted.retryable,
          errorCode: accepted.errorCode,
        }),
        202,
      );
    }

    const deadlineAt = startedAt + providerConfig.timeoutMs;
    const providerStartedAt = Date.now();
    let completion: FoodProviderCompletion;
    try {
      completion = await callVisionProvider(
        providerConfig,
        parsedRequest,
        { timeoutMs: remainingDeadline(deadlineAt) },
      );
    } finally {
      stageTelemetry.providerFirstPassMs = Date.now() - providerStartedAt;
    }
    outputTelemetry = {
      ...outputTelemetry,
      providerCompletionStatus: completion.status,
    };
    assertCompleted(completion);
    let parsedProvider;
    const firstValidationStartedAt = Date.now();
    try {
      parsedProvider = parseAndValidateFood(completion.content, parsedRequest);
      stageTelemetry.firstValidationMs = Date.now() -
        firstValidationStartedAt;
      outputTelemetry = {
        ...outputTelemetry,
        firstPassValidationStatus: "passed",
        finalValidationStatus: "passed",
      };
    } catch (error) {
      stageTelemetry.firstValidationMs = Date.now() -
        firstValidationStartedAt;
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
      const correctionStartedAt = Date.now();
      completion = await callVisionProvider(providerConfig, parsedRequest, {
        timeoutMs: remaining,
        correction: {
          previousOutput: completion.content,
          issues: error.issues,
        },
      });
      outputTelemetry = {
        ...outputTelemetry,
        correctionLatencyMs: Date.now() - correctionStartedAt,
      };
      stageTelemetry.correctionMs = outputTelemetry.correctionLatencyMs;
      outputTelemetry = {
        ...outputTelemetry,
        providerCompletionStatus: completion.status,
      };
      assertCompleted(completion);
      const correctionValidationStartedAt = Date.now();
      try {
        parsedProvider = parseAndValidateFood(
          completion.content,
          parsedRequest,
        );
        outputTelemetry = {
          ...outputTelemetry,
          finalValidationStatus: "passed",
        };
        stageTelemetry.correctionValidationMs = Date.now() -
          correctionValidationStartedAt;
      } catch (correctionError) {
        stageTelemetry.correctionValidationMs = Date.now() -
          correctionValidationStartedAt;
        outputTelemetry = {
          ...outputTelemetry,
          finalValidationStatus: "failed",
        };
        throw correctionError;
      }
    }
    outputTelemetry = {
      ...outputTelemetry,
      languageValidationStatus: classifyResponseLanguage(
        parsedRequest.language,
        parsedProvider.draft === null
          ? parsedProvider.clarificationQuestions
          : [
            parsedProvider.draft.meal_name,
            parsedProvider.draft.estimation_notes,
            ...parsedProvider.draft.items.map((item) => item.name),
          ],
      ),
    };
    const persisted = await writePhotoLog(env, {
      accountId,
      request: parsedRequest,
      requestId: null,
      clientRequestId: parsedRequest.clientRequestId,
      model: providerConfig.model,
      status: "ok",
      errorCode: null,
      latencyMs: Date.now() - startedAt,
      draft: parsedProvider.draft,
      schemaValidationStatus: parsedProvider.schemaValidationStatus,
      safetyFlags: [],
      telemetry: outputTelemetry,
      stageTelemetry,
    });

    return jsonResponse(
      photoGatewayResponse({
        modelChoice: parsedRequest.modelChoice,
        modelProvider: providerConfig.provider,
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
        requestId: null,
        clientRequestId: parsedRequest?.clientRequestId ?? null,
        model: providerConfig?.model ?? null,
        status: logStatusForCode(gatewayError.code),
        errorCode: gatewayError.code,
        latencyMs: Date.now() - startedAt,
        draft: null,
        schemaValidationStatus: "failed",
        safetyFlags: [gatewayError.code],
        telemetry: outputTelemetry,
        stageTelemetry,
      });
    }

    return jsonResponse(
      photoGatewayResponse({
        modelChoice: parsedRequest?.modelChoice ?? "qwen",
        modelProvider: providerConfig?.provider ?? parsedRequest?.modelChoice ??
          "qwen",
        error: {
          code: gatewayError.code,
          message: errorMessageForCode(gatewayError.code),
        },
      }),
      200,
    );
  }
});

const photoDeliveryBucket = "fitlog-ai-temp-assets";
const photoDeliveryEdgeVersion = "ai_photo_async_delivery.v1";

interface AcceptedPhotoDelivery {
  requestId: string;
  status: "queued" | "running" | "succeeded" | "failed" | "cancelled";
  duplicateSubmit: boolean;
  retryable: boolean;
  errorCode: string | null;
}

interface PhotoDeliveryAssetRef {
  path: string;
  mime_type: "image/jpeg" | "image/png" | "image/webp";
  byte_length: number;
  name: string | null;
}

async function acceptPhotoDeliveryRequest(
  env: PhotoGatewayEnv,
  accountId: string,
  request: PhotoAnalysisRequest,
  rawBody: unknown,
): Promise<AcceptedPhotoDelivery> {
  const requestId = crypto.randomUUID();
  const assetUploadStartedAt = Date.now();
  const assets = await persistPhotoDeliveryAssets(
    env,
    accountId,
    requestId,
    request.images,
  );
  const payload = {
    ...sanitizePhotoDeliveryPayload(rawBody),
    delivery_observability: {
      schema_version: "photo_delivery_accept.v1",
      pre_accept_asset_upload_ms: Date.now() - assetUploadStartedAt,
    },
  };
  const response = await photoDeliveryBackendFetch(
    env,
    "rpc/accept_ai_delivery_request",
    {
      method: "POST",
      headers: serviceHeaders(env),
      body: JSON.stringify({
        input_request_id: requestId,
        input_account_id: accountId,
        input_kind: "food_photo_analysis",
        input_client_request_id: request.clientRequestId,
        input_session_id: null,
        input_request_payload_json: payload,
        input_asset_refs_json: assets,
        input_trace_id: requestId,
        input_app_version: appVersionFromPayload(payload),
        input_edge_function_version: photoDeliveryEdgeVersion,
        input_client_image_count: request.images.length,
        input_edge_asset_count: assets.length,
      }),
    },
  );
  if (!response.ok) {
    throw new PhotoGatewayHttpError("delivery_backend_unavailable", 502);
  }
  const result = recordValue(await response.json());
  const accepted = {
    requestId: requiredString(result, "request_id"),
    status: deliveryStatus(result.status),
    duplicateSubmit: result.duplicate_submit === true,
    retryable: result.retryable !== false,
    errorCode: optionalString(result.error_code),
  };
  if (accepted.duplicateSubmit) {
    await deletePhotoDeliveryAssets(env, assets);
  }
  return accepted;
}

async function photoDeliveryBackendFetch(
  env: PhotoGatewayEnv,
  restPath: string,
  init: RequestInit,
): Promise<Response> {
  try {
    return await fetch(`${env.supabaseUrl}/rest/v1/${restPath}`, init);
  } catch (_) {
    throw new PhotoGatewayHttpError("delivery_backend_unavailable", 502);
  }
}

async function processPhotoDeliveryQueue(
  env: PhotoGatewayEnv,
  limit: number,
): Promise<number> {
  let processed = 0;
  for (let index = 0; index < limit; index += 1) {
    const didProcess = await processPhotoDeliveryRequest(env, null);
    if (!didProcess) break;
    processed += 1;
  }
  return processed;
}

async function processPhotoDeliveryRequest(
  env: PhotoGatewayEnv,
  requestId: string | null,
): Promise<boolean> {
  const claimStartedAt = Date.now();
  const claimed = await claimPhotoDeliveryRequest(env, requestId);
  if (claimed === null) return false;
  const deliveryRequestId = requiredString(claimed, "request_id");
  const accountId = requiredString(claimed, "account_id");
  let parsedRequest: PhotoAnalysisRequest | null = null;
  let assetRefs: PhotoDeliveryAssetRef[] = [];
  let providerConfig: PhotoProviderConfig | null = null;
  let outputTelemetry = defaultPhotoOutputTelemetry();
  const stageTelemetry = defaultPhotoStageTelemetry();
  stageTelemetry.claimMs = Date.now() - claimStartedAt;
  const startedAt = Date.now();

  try {
    const payload = recordValue(claimed.request_payload_json);
    const acceptObservability = recordValue(payload.delivery_observability);
    stageTelemetry.preAcceptAssetUploadMs = boundedTelemetryMs(
      acceptObservability.pre_accept_asset_upload_ms,
    );
    assetRefs = parsePhotoDeliveryAssets(claimed.asset_refs_json);
    const assetLoadStartedAt = Date.now();
    const images = await loadPhotoDeliveryImages(env, assetRefs);
    stageTelemetry.assetLoadMs = Date.now() - assetLoadStartedAt;
    const payloadWithImages = {
      ...payload,
      images: images.map((image) => ({
        mime_type: image.mimeType,
        base64_data: image.base64Data,
        byte_length: image.byteLength,
      })),
    };
    parsedRequest = {
      ...parsePhotoAnalysisRequest(payloadWithImages),
      deliveryMode: "sync",
      deliveryRequestId,
    };
    providerConfig = readPhotoProviderConfig(parsedRequest.modelChoice);
    const deadlineAt = startedAt + providerConfig.timeoutMs;
    const providerStartedAt = Date.now();
    let completion: FoodProviderCompletion;
    try {
      completion = await callVisionProvider(providerConfig, parsedRequest, {
        timeoutMs: remainingDeadline(deadlineAt),
      });
    } finally {
      stageTelemetry.providerFirstPassMs = Date.now() - providerStartedAt;
    }
    outputTelemetry = {
      ...outputTelemetry,
      providerCompletionStatus: completion.status,
    };
    assertCompleted(completion);
    let parsedProvider;
    const firstValidationStartedAt = Date.now();
    try {
      parsedProvider = parseAndValidateFood(completion.content, parsedRequest);
      stageTelemetry.firstValidationMs = Date.now() -
        firstValidationStartedAt;
      outputTelemetry = {
        ...outputTelemetry,
        firstPassValidationStatus: "passed",
        finalValidationStatus: "passed",
      };
    } catch (error) {
      stageTelemetry.firstValidationMs = Date.now() -
        firstValidationStartedAt;
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
      const correctionStartedAt = Date.now();
      completion = await callVisionProvider(providerConfig, parsedRequest, {
        timeoutMs: remaining,
        correction: {
          previousOutput: completion.content,
          issues: error.issues,
        },
      });
      outputTelemetry = {
        ...outputTelemetry,
        correctionLatencyMs: Date.now() - correctionStartedAt,
        providerCompletionStatus: completion.status,
      };
      stageTelemetry.correctionMs = outputTelemetry.correctionLatencyMs;
      assertCompleted(completion);
      const correctionValidationStartedAt = Date.now();
      try {
        parsedProvider = parseAndValidateFood(
          completion.content,
          parsedRequest,
        );
        outputTelemetry = {
          ...outputTelemetry,
          finalValidationStatus: "passed",
        };
        stageTelemetry.correctionValidationMs = Date.now() -
          correctionValidationStartedAt;
      } catch (correctionError) {
        stageTelemetry.correctionValidationMs = Date.now() -
          correctionValidationStartedAt;
        outputTelemetry = {
          ...outputTelemetry,
          finalValidationStatus: "failed",
        };
        throw correctionError;
      }
    }
    outputTelemetry = {
      ...outputTelemetry,
      languageValidationStatus: classifyResponseLanguage(
        parsedRequest.language,
        parsedProvider.draft === null
          ? parsedProvider.clarificationQuestions
          : [
            parsedProvider.draft.meal_name,
            parsedProvider.draft.estimation_notes,
            ...parsedProvider.draft.items.map((item) => item.name),
          ],
      ),
    };
    const persisted = await writePhotoLog(env, {
      accountId,
      request: parsedRequest,
      requestId: deliveryRequestId,
      clientRequestId: parsedRequest.clientRequestId,
      model: providerConfig.model,
      status: "ok",
      errorCode: null,
      latencyMs: Date.now() - startedAt,
      draft: parsedProvider.draft,
      schemaValidationStatus: parsedProvider.schemaValidationStatus,
      safetyFlags: [],
      telemetry: outputTelemetry,
      stageTelemetry,
    });
    const responseBody = photoGatewayResponse({
      modelChoice: parsedRequest.modelChoice,
      modelProvider: providerConfig.provider,
      draft: foodDraftForClient(
        parsedProvider.draft,
        parsedRequest.schemaVersion,
      ),
      needsClarification: parsedProvider.needsClarification,
      clarificationQuestions: parsedProvider.clarificationQuestions,
      debugSummaryId: persisted.debugSummaryId,
      error: null,
    });
    const finished = await finishPhotoDeliveryRequest(env, {
      requestId: deliveryRequestId,
      succeeded: true,
      result: responseBody,
      provider: providerConfig.provider,
      providerRequestCount: 1 + outputTelemetry.correctionAttemptCount,
      providerImageCount: parsedRequest.images.length,
    });
    if (isTerminalDeliveryStatus(finished.status)) {
      await deletePhotoDeliveryAssets(env, assetRefs);
    }
    return true;
  } catch (error) {
    const gatewayError = toPhotoGatewayHttpError(error);
    await writePhotoLog(env, {
      accountId,
      request: parsedRequest,
      requestId: deliveryRequestId,
      clientRequestId: parsedRequest?.clientRequestId ?? null,
      model: providerConfig?.model ?? null,
      status: logStatusForCode(gatewayError.code),
      errorCode: gatewayError.code,
      latencyMs: Date.now() - startedAt,
      draft: null,
      schemaValidationStatus: "failed",
      safetyFlags: [gatewayError.code],
      telemetry: outputTelemetry,
      stageTelemetry,
    });
    const finished = await finishPhotoDeliveryRequest(env, {
      requestId: deliveryRequestId,
      succeeded: false,
      errorCode: gatewayError.code,
      failureStage: failureStageForPhotoError(gatewayError.code),
      retryable: isRetryablePhotoDeliveryError(gatewayError.code),
      result: null,
      provider: providerConfig?.provider ?? null,
      providerRequestCount: outputTelemetry.providerCompletionStatus ===
          "not_called"
        ? 0
        : 1 + outputTelemetry.correctionAttemptCount,
      providerImageCount: parsedRequest?.images.length ?? 0,
    });
    if (isTerminalDeliveryStatus(finished.status)) {
      await deletePhotoDeliveryAssets(env, assetRefs);
    }
    return true;
  }
}

async function claimPhotoDeliveryRequest(
  env: PhotoGatewayEnv,
  requestId: string | null,
): Promise<Record<string, unknown> | null> {
  const response = await photoDeliveryBackendFetch(
    env,
    "rpc/claim_ai_delivery_request",
    {
      method: "POST",
      headers: serviceHeaders(env),
      body: JSON.stringify({
        input_kind: "food_photo_analysis",
        input_request_id: requestId,
        input_worker_id: `food_photo_${crypto.randomUUID()}`,
        input_lease_seconds: 120,
      }),
    },
  );
  if (!response.ok) {
    throw new PhotoGatewayHttpError("delivery_backend_unavailable", 502);
  }
  const body = await response.json();
  if (body === null) return null;
  return recordValue(body);
}

async function finishPhotoDeliveryRequest(
  env: PhotoGatewayEnv,
  params: {
    requestId: string;
    succeeded: boolean;
    result: Record<string, unknown> | null;
    errorCode?: string | null;
    failureStage?: string | null;
    retryable?: boolean;
    provider?: string | null;
    providerRequestCount: number;
    providerImageCount: number;
  },
): Promise<Record<string, unknown>> {
  const response = await fetch(
    `${env.supabaseUrl}/rest/v1/rpc/finish_ai_delivery_request`,
    {
      method: "POST",
      headers: serviceHeaders(env),
      body: JSON.stringify({
        input_request_id: params.requestId,
        input_succeeded: params.succeeded,
        input_result_json: params.result,
        input_error_code: params.errorCode ?? null,
        input_failure_stage: params.failureStage ?? null,
        input_retryable: params.retryable ?? false,
        input_provider: params.provider ?? null,
        input_provider_request_count: params.providerRequestCount,
        input_provider_image_count: params.providerImageCount,
      }),
    },
  );
  if (!response.ok) {
    throw new PhotoGatewayHttpError("delivery_backend_unavailable", 502);
  }
  return recordValue(await response.json());
}

async function persistPhotoDeliveryAssets(
  env: PhotoGatewayEnv,
  accountId: string,
  requestId: string,
  images: PhotoAnalysisRequest["images"],
): Promise<PhotoDeliveryAssetRef[]> {
  const refs: PhotoDeliveryAssetRef[] = [];
  for (let index = 0; index < images.length; index += 1) {
    const image = images[index];
    const path = `${accountId}/${requestId}/${index}${
      extensionForMime(image.mimeType)
    }`;
    const response = await fetch(photoStorageObjectUrl(env, path), {
      method: "PUT",
      headers: {
        apikey: env.supabaseServiceRoleKey,
        authorization: `Bearer ${env.supabaseServiceRoleKey}`,
        "content-type": image.mimeType,
        "x-upsert": "false",
      },
      body: base64ToBlob(image.base64Data, image.mimeType),
    });
    if (!response.ok) {
      throw new PhotoGatewayHttpError("delivery_backend_unavailable", 502);
    }
    refs.push({
      path,
      mime_type: image.mimeType,
      byte_length: image.byteLength,
      name: null,
    });
  }
  return refs;
}

async function deletePhotoDeliveryAssets(
  env: PhotoGatewayEnv,
  assets: PhotoDeliveryAssetRef[],
): Promise<void> {
  await Promise.all(
    assets.map((asset) =>
      fetch(photoStorageObjectUrl(env, asset.path), {
        method: "DELETE",
        headers: {
          apikey: env.supabaseServiceRoleKey,
          authorization: `Bearer ${env.supabaseServiceRoleKey}`,
        },
      }).catch(() => null)
    ),
  );
}

async function loadPhotoDeliveryImages(
  env: PhotoGatewayEnv,
  assets: PhotoDeliveryAssetRef[],
): Promise<PhotoAnalysisRequest["images"]> {
  const images: PhotoAnalysisRequest["images"] = [];
  for (const asset of assets) {
    const response = await fetch(photoStorageObjectUrl(env, asset.path), {
      headers: {
        apikey: env.supabaseServiceRoleKey,
        authorization: `Bearer ${env.supabaseServiceRoleKey}`,
      },
    });
    if (!response.ok) {
      throw new PhotoGatewayHttpError("record_schema_mismatch", 422);
    }
    const bytes = new Uint8Array(await response.arrayBuffer());
    if (bytes.byteLength !== asset.byte_length) {
      throw new PhotoGatewayHttpError("record_schema_mismatch", 422);
    }
    images.push({
      mimeType: asset.mime_type,
      base64Data: bytesToBase64(bytes),
      byteLength: bytes.byteLength,
    });
  }
  return images;
}

function sanitizePhotoDeliveryPayload(value: unknown): Record<string, unknown> {
  const payload = { ...recordValue(value) };
  delete payload.images;
  delete payload.image;
  const client = { ...recordValue(payload.client) };
  client.delivery_mode = "sync";
  payload.client = client;
  return payload;
}

function parsePhotoDeliveryAssets(value: unknown): PhotoDeliveryAssetRef[] {
  if (!Array.isArray(value)) return [];
  return value.map((item) => {
    const row = recordValue(item);
    const path = requiredString(row, "path");
    const mime = requiredString(row, "mime_type");
    if (
      mime !== "image/jpeg" && mime !== "image/png" && mime !== "image/webp"
    ) {
      throw new PhotoGatewayHttpError("record_schema_mismatch", 422);
    }
    const byteLength = Number(row.byte_length);
    if (!Number.isInteger(byteLength) || byteLength <= 0) {
      throw new PhotoGatewayHttpError("record_schema_mismatch", 422);
    }
    return {
      path,
      mime_type: mime,
      byte_length: byteLength,
      name: typeof row.name === "string" ? row.name : null,
    };
  });
}

function isPhotoDeliveryWorkerRequest(
  request: Request,
  env: PhotoGatewayEnv,
): boolean {
  const token = extractBearerToken(request.headers.get("authorization"));
  if (token !== null && token === env.supabaseServiceRoleKey) {
    return true;
  }
  const secret = Deno.env.get("FITLOG_AI_WORKER_SECRET")?.trim() ?? "";
  return secret !== "" &&
    request.headers.get("x-fitlog-worker-secret") === secret;
}

function waitUntil(promise: Promise<unknown>): void {
  const runtime = (globalThis as unknown as {
    EdgeRuntime?: { waitUntil?: (promise: Promise<unknown>) => void };
  }).EdgeRuntime;
  if (typeof runtime?.waitUntil === "function") {
    runtime.waitUntil(promise);
    return;
  }
  promise.catch((error) => {
    console.warn("photo_delivery_wait_until_failed", String(error));
  });
}

function boundedWorkerLimit(value: unknown): number {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? Math.min(parsed, 10) : 3;
}

function deliveryStatus(value: unknown): AcceptedPhotoDelivery["status"] {
  return value === "running" ||
      value === "succeeded" ||
      value === "failed" ||
      value === "cancelled"
    ? value
    : "queued";
}

function isTerminalDeliveryStatus(value: unknown): boolean {
  return value === "succeeded" || value === "failed" || value === "cancelled";
}

function isRetryablePhotoDeliveryError(code: PhotoGatewayErrorCode): boolean {
  return code === "gateway_timeout" ||
    code === "provider_failure" ||
    code === "provider_incomplete";
}

function failureStageForPhotoError(code: PhotoGatewayErrorCode): string {
  switch (code) {
    case "request_schema_mismatch":
    case "record_schema_mismatch":
      return "schema_validation";
    case "provider_output_invalid":
      return "output_validation";
    case "gateway_timeout":
    case "provider_failure":
    case "provider_refusal":
    case "provider_incomplete":
      return "provider";
    default:
      return "preflight";
  }
}

function appVersionFromPayload(
  payload: Record<string, unknown>,
): string | null {
  const client = recordValue(payload.client);
  return typeof client.app_version === "string" ? client.app_version : null;
}

function photoStorageObjectUrl(env: PhotoGatewayEnv, path: string): string {
  return `${env.supabaseUrl}/storage/v1/object/${photoDeliveryBucket}/${
    path.split("/").map(encodeURIComponent).join("/")
  }`;
}

function extensionForMime(mime: string): string {
  switch (mime) {
    case "image/jpeg":
      return ".jpg";
    case "image/png":
      return ".png";
    case "image/webp":
      return ".webp";
    default:
      return ".img";
  }
}

function base64ToBytes(value: string): Uint8Array {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function base64ToBlob(value: string, mimeType: string): Blob {
  const bytes = base64ToBytes(value);
  const body = new ArrayBuffer(bytes.byteLength);
  new Uint8Array(body).set(bytes);
  return new Blob([body], { type: mimeType });
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunkSize = 0x8000;
  for (let index = 0; index < bytes.length; index += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(index, index + chunkSize));
  }
  return btoa(binary);
}

function recordValue(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function requiredString(
  value: Record<string, unknown>,
  key: string,
): string {
  const text = typeof value[key] === "string" ? value[key].trim() : "";
  if (text === "") {
    throw new PhotoGatewayHttpError("record_schema_mismatch", 422);
  }
  return text;
}

function optionalString(value: unknown): string | null {
  return typeof value === "string" && value.trim() !== "" ? value.trim() : null;
}

interface PhotoGatewayEnv {
  supabaseUrl: string;
  supabaseAnonKey: string;
  supabaseServiceRoleKey: string;
}

function parseAndValidateFood(content: string, request: PhotoAnalysisRequest) {
  return parseProviderFoodDraftBody(content, request.selectedDate);
}

interface PhotoProviderConfig {
  provider: "openai" | "qwen";
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

function readPhotoProviderConfig(
  choice: "chatgpt" | "qwen",
): PhotoProviderConfig {
  const isOpenAi = choice === "chatgpt";
  const apiKey =
    Deno.env.get(isOpenAi ? "FITLOG_OPENAI_API_KEY" : "FITLOG_QWEN_API_KEY") ??
      "";
  const model = Deno.env.get(
    isOpenAi ? "FITLOG_OPENAI_MODEL" : "FITLOG_QWEN_MODEL",
  ) ?? "";
  const baseUrl = isOpenAi
    ? "https://api.openai.com/v1/responses"
    : Deno.env.get("FITLOG_QWEN_BASE_URL") ??
      "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions";
  if (apiKey.trim() === "" || model.trim() === "" || baseUrl.trim() === "") {
    throw new PhotoGatewayHttpError("provider_failure", 502);
  }
  return {
    provider: isOpenAi ? "openai" : "qwen",
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

async function callVisionProvider(
  config: PhotoProviderConfig,
  request: PhotoAnalysisRequest,
  options: {
    timeoutMs: number;
    correction?: {
      previousOutput: string;
      issues: OutputContractError["issues"];
    };
  },
): Promise<FoodProviderCompletion> {
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
        (config.provider === "openai"
          ? buildOpenAiVisionRequestBody
          : buildQwenVisionRequestBody)({
            request,
            model: config.model,
            correction: options.correction,
          }),
      ),
    });
    if (!response.ok) {
      throw new PhotoGatewayHttpError("provider_failure", 502);
    }
    const body = await response.json();
    return config.provider === "openai"
      ? extractOpenAiVisionCompletion(body)
      : extractQwenCompletion(body);
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
    requestId?: string | null;
    clientRequestId?: string | null;
    model: string | null;
    status: PhotoGatewayStatus;
    errorCode: PhotoGatewayErrorCode | null;
    latencyMs: number;
    draft: FoodDraft | null;
    schemaValidationStatus: string;
    safetyFlags: string[];
    telemetry: PhotoOutputTelemetry;
    stageTelemetry: PhotoStageTelemetry;
  },
): Promise<{ debugSummaryId: string | null }> {
  const requestId = params.requestId ?? crypto.randomUUID();
  const request = params.request;
  const existingDebugSummaryId = await existingPhotoDebugSummary(
    env,
    requestId,
    params.accountId,
  );
  if (existingDebugSummaryId !== undefined) {
    return { debugSummaryId: existingDebugSummaryId };
  }
  const foodUnderstanding = explicitFoodFactsFromText(request?.userNote ?? "");
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
        model_choice: request?.modelChoice ?? "qwen",
        model_provider: request?.modelChoice === "chatgpt" ? "openai" : "qwen",
        model: params.model,
        prompt_version: "phase4_food_photo_v1",
        schema_version: "food_draft.v2",
        profile_version: null,
        status: params.status,
        error_code: params.errorCode,
        latency_ms: params.latencyMs,
        token_estimate: null,
        image_count: request === null ? 0 : request.images.length,
        client_request_id: params.clientRequestId ?? null,
        expected_output: "food_draft",
        validator_version: outputValidatorVersion,
        first_pass_validation_status:
          params.telemetry.firstPassValidationStatus,
        correction_attempt_count: params.telemetry.correctionAttemptCount,
        final_validation_status: params.telemetry.finalValidationStatus,
        provider_completion_status: params.telemetry.providerCompletionStatus,
        surface: "add_food_analysis",
        capability: "food_draft",
        provider_adapter_version: "food_vision_adapters.v2",
        policy_version: "food_capability.v1",
        target_response_language: request?.language ?? null,
        language_validation_status: params.telemetry.languageValidationStatus,
        food_fact_count: foodUnderstanding.facts.length,
        food_conflict_count: foodUnderstanding.conflict_count,
        semantic_validation_status: params.telemetry.finalValidationStatus,
        semantic_issue_codes_json: params.safetyFlags,
        correction_latency_ms: params.telemetry.correctionLatencyMs,
        latency_breakdown_json: photoLatencyBreakdownJson(
          params.stageTelemetry,
          params.latencyMs,
        ),
        final_action: params.status === "ok" ? "artifact_returned" : "none",
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
      called_tools_json: [
        request?.modelChoice === "chatgpt" ? "openai_vision" : "qwen_vision",
      ],
      retrieved_dimensions_json: stripImageDataForDebug(request),
      missing_dimensions_json: params.draft === null ? ["food_draft"] : [],
      safety_flags_json: params.safetyFlags,
      schema_validation_status: params.schemaValidationStatus,
      user_final_action: params.status === "ok" ? "draft_returned" : "none",
    }),
  });
  return { debugSummaryId };
}

async function existingPhotoDebugSummary(
  env: PhotoGatewayEnv,
  requestId: string,
  accountId: string,
): Promise<string | null | undefined> {
  const response = await fetch(
    `${env.supabaseUrl}/rest/v1/ai_request_logs?select=request_id&request_id=eq.${requestId}&account_id=eq.${accountId}&limit=1`,
    { headers: serviceHeaders(env) },
  );
  if (!response.ok) return undefined;
  const rows = await response.json();
  if (!Array.isArray(rows) || rows.length === 0) return undefined;
  const debugResponse = await fetch(
    `${env.supabaseUrl}/rest/v1/ai_debug_summaries?select=id&request_id=eq.${requestId}&account_id=eq.${accountId}&limit=1`,
    { headers: serviceHeaders(env) },
  );
  if (!debugResponse.ok) return null;
  const debugRows = await debugResponse.json();
  return Array.isArray(debugRows) && typeof debugRows[0]?.id === "string"
    ? debugRows[0].id
    : null;
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
    correctionLatencyMs: 0,
    finalValidationStatus: "not_attempted",
    languageValidationStatus: "not_attempted",
    providerCompletionStatus: "not_called",
  };
}

function defaultPhotoStageTelemetry(): PhotoStageTelemetry {
  return {
    preAcceptAssetUploadMs: null,
    claimMs: 0,
    assetLoadMs: 0,
    providerFirstPassMs: 0,
    firstValidationMs: 0,
    correctionMs: 0,
    correctionValidationMs: 0,
  };
}

function photoLatencyBreakdownJson(
  telemetry: PhotoStageTelemetry,
  totalMs: number,
): Record<string, unknown> {
  return {
    schema_version: "photo_latency_breakdown.v1",
    pre_accept_asset_upload_ms: telemetry.preAcceptAssetUploadMs,
    claim_ms: telemetry.claimMs,
    asset_load_ms: telemetry.assetLoadMs,
    provider_first_pass_ms: telemetry.providerFirstPassMs,
    provider_first_validation_ms: telemetry.firstValidationMs,
    provider_correction_ms: telemetry.correctionMs,
    provider_correction_validation_ms: telemetry.correctionValidationMs,
    worker_or_sync_total_ms: totalMs,
  };
}

function boundedTelemetryMs(value: unknown): number | null {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= 0
    ? Math.min(Math.round(parsed), 300000)
    : null;
}

function remainingDeadline(deadlineAt: number): number {
  const remaining = deadlineAt - Date.now();
  if (remaining <= 0) {
    throw new PhotoGatewayHttpError("gateway_timeout", 504);
  }
  return remaining;
}

function assertCompleted(completion: FoodProviderCompletion): void {
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
