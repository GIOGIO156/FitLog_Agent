import {
  buildQwenVisionRequestBody,
  extractQwenCompletion,
  parsePhotoAnalysisRequest,
  parseProviderFoodDraftBody,
} from "../../supabase/functions/ai-food-photo-analyze/contracts.ts";
import {
  createModelChatDecisionPlanner,
} from "../../supabase/functions/ai-chat-route/planning/model_planners.ts";
import {
  PlannerCallError,
} from "../../supabase/functions/ai-chat-route/planning/chat_decision_contract.ts";
import type {
  ProviderRuntimeConfig,
} from "../../supabase/functions/ai-chat-route/providers.ts";
import { foodDraftEvidencePolicy } from "../../supabase/functions/_shared/food_prompt_policy.ts";

const options = parseOptions(Deno.args);
const imageBytes = await Deno.readFile(options.imagePath);
const mimeType = mimeTypeForPath(options.imagePath);
const base64Data = bytesToBase64(imageBytes);
const qwenApiKey = requiredEnv("FITLOG_QWEN_API_KEY");
const qwenModel = requiredEnv("FITLOG_QWEN_MODEL");
const qwenBaseUrl = requiredEnv("FITLOG_QWEN_BASE_URL");

const providerConfig: ProviderRuntimeConfig = {
  openAiApiKey: "",
  openAiModel: "",
  qwenApiKey,
  qwenModel,
  qwenBaseUrl,
  timeoutMs: 60000,
  allowMockProvider: false,
};

const plannerResults: ProbeResult[] = [];
if (options.suite !== "food") {
  for (let index = 0; index < options.iterations; index += 1) {
    plannerResults.push(await probePlanner(false, index + 1));
    plannerResults.push(await probePlanner(true, index + 1));
  }
}

const request = parsePhotoAnalysisRequest({
  images: [{
    mime_type: mimeType,
    base64_data: base64Data,
    byte_length: imageBytes.byteLength,
  }],
  language: "zh",
  model_choice: "qwen",
  device_id: "diagnostic-device",
  selected_date: "2026-08-14",
  schema_version: "food_draft.v2",
  user_note: options.foodNote,
  client_request_id: "diagnostic-provider-probe",
});
const currentBody = buildQwenVisionRequestBody({
  request,
  model: qwenModel,
});
const baselineBody = withBaselineFoodPolicy(currentBody);
const foodResults: ProbeResult[] = [];
if (options.suite !== "planner") {
  for (let index = 0; index < options.iterations; index += 1) {
    const first = index % 2 === 0
      ? (["baseline", baselineBody] as const)
      : (["current", currentBody] as const);
    const second = first[0] === "baseline"
      ? (["current", currentBody] as const)
      : (["baseline", baselineBody] as const);
    foodResults.push(await probeFood(first[0], first[1], index + 1));
    foodResults.push(await probeFood(second[0], second[1], index + 1));
  }
}

console.log(JSON.stringify(
  {
    schema_version: "fitlog_provider_probe.v1",
    suite: options.suite,
    planner_timeout_ms: options.plannerTimeoutMs,
    image: {
      mime_type: mimeType,
      byte_length: imageBytes.byteLength,
    },
    planner: summarize(plannerResults),
    food: summarize(foodResults),
    samples: [...plannerResults, ...foodResults],
  },
  null,
  2,
));

async function probePlanner(
  includeImage: boolean,
  iteration: number,
): Promise<ProbeResult> {
  const label = includeImage ? "planner_image" : "planner_text";
  const planner = createModelChatDecisionPlanner(
    "qwen",
    providerConfig,
    fetch,
    options.plannerTimeoutMs,
  );
  if (planner === undefined) {
    return {
      label,
      iteration,
      duration_ms: 0,
      ok: false,
      reason: "not_configured",
    };
  }
  const startedAt = performance.now();
  try {
    const value = await planner({
      message: options.plannerText,
      language: "zh",
      image_count: includeImage ? 1 : 0,
      images: includeImage
        ? [{ mime_type: mimeType, base64_data: base64Data }]
        : [],
      workflow_hint: "auto",
      same_chat: null,
      allowed_output_families: ["text", "food_draft", "workout_draft"],
    });
    const row = recordValue(value);
    return {
      label,
      iteration,
      duration_ms: elapsedMs(startedAt),
      ok: true,
      reason: "completed",
      capability: stringValue(row.capability),
      output_family: stringValue(row.selected_output_family),
    };
  } catch (error) {
    return {
      label,
      iteration,
      duration_ms: elapsedMs(startedAt),
      ok: false,
      reason: error instanceof PlannerCallError ? error.reason : "unknown",
    };
  }
}

async function probeFood(
  label: "baseline" | "current",
  body: Record<string, unknown>,
  iteration: number,
): Promise<ProbeResult> {
  const startedAt = performance.now();
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 60000);
  try {
    const response = await fetch(qwenBaseUrl, {
      method: "POST",
      headers: {
        authorization: `Bearer ${qwenApiKey}`,
        "content-type": "application/json",
      },
      signal: controller.signal,
      body: JSON.stringify(body),
    });
    if (!response.ok) {
      return {
        label: `food_${label}`,
        iteration,
        duration_ms: elapsedMs(startedAt),
        ok: false,
        reason: `http_${response.status}`,
      };
    }
    const completion = extractQwenCompletion(await response.json());
    if (completion.status !== "completed") {
      return {
        label: `food_${label}`,
        iteration,
        duration_ms: elapsedMs(startedAt),
        ok: false,
        reason: completion.status,
        response_chars: completion.content.length,
      };
    }
    try {
      const parsed = parseProviderFoodDraftBody(
        completion.content,
        request.selectedDate,
      );
      return {
        label: `food_${label}`,
        iteration,
        duration_ms: elapsedMs(startedAt),
        ok: true,
        reason: parsed.needsClarification ? "clarification" : "valid_draft",
        response_chars: completion.content.length,
        item_count: parsed.draft?.items.length ?? 0,
        total_weight_g: parsed.draft?.total_weight_g ?? null,
      };
    } catch (_) {
      return {
        label: `food_${label}`,
        iteration,
        duration_ms: elapsedMs(startedAt),
        ok: false,
        reason: "contract_invalid",
        response_chars: completion.content.length,
      };
    }
  } catch (error) {
    return {
      label: `food_${label}`,
      iteration,
      duration_ms: elapsedMs(startedAt),
      ok: false,
      reason: error instanceof DOMException && error.name === "AbortError"
        ? "client_timeout"
        : "network_or_fetch_error",
    };
  } finally {
    clearTimeout(timeout);
  }
}

function withBaselineFoodPolicy(
  current: Record<string, unknown>,
): Record<string, unknown> {
  const copy = structuredClone(current);
  const messages = Array.isArray(copy.messages) ? copy.messages : [];
  const system = recordValue(messages[0]);
  const content = stringValue(system.content);
  system.content = content.replace(
    foodDraftEvidencePolicy("zh"),
    baselineFoodEvidencePolicyZh(),
  );
  messages[0] = system;
  copy.messages = messages;
  return copy;
}

function baselineFoodEvidencePolicyZh(): string {
  return [
    "文字和图片是并列、互补的证据，不是互相否定的完整清单。",
    "用户文字通常只补充、修正或说明餐食的一部分；除非用户明确表示只有、只记录、不要或不包含某些食物，不要因为文字未提到就忽略图片中其他合理可识别的食物。",
    "用户明确给出且作用对象清楚的食物名称、份量、重量、包装营养或食用量，只在对应食物和对应字段上优先于视觉观察和通用估算；不要把局部事实误套到整餐，也不要把大概、可能、像是等不确定表述当成确定事实。",
    "文字未覆盖的食物和字段继续根据全部图片合理识别和估算；图片未显示某个用户明确食物不能单独成为删除理由，图片中额外识别到的食物可以加入草稿。",
    "文字与图片冲突时，不要虚构确定结论、删除用户意图或把同一对象重复成两个条目；保留用户明确意图，在 confidence 和 estimation_notes 中说明冲突或不确定性，等待用户确认。",
  ].join(" ");
}

function summarize(results: ProbeResult[]): Record<string, unknown>[] {
  const labels = [...new Set(results.map((result) => result.label))];
  return labels.map((label) => {
    const samples = results.filter((result) => result.label === label);
    const durations = samples.map((sample) => sample.duration_ms).sort((a, b) =>
      a - b
    );
    return {
      label,
      samples: samples.length,
      successes: samples.filter((sample) => sample.ok).length,
      average_ms: Math.round(
        durations.reduce((sum, value) => sum + value, 0) / durations.length,
      ),
      median_ms: durations[Math.floor(durations.length / 2)],
      min_ms: durations[0],
      max_ms: durations[durations.length - 1],
      reasons: Object.fromEntries(
        [...new Set(samples.map((sample) => sample.reason))].map((reason) => [
          reason,
          samples.filter((sample) => sample.reason === reason).length,
        ]),
      ),
    };
  });
}

interface ProbeResult {
  label: string;
  iteration: number;
  duration_ms: number;
  ok: boolean;
  reason: string;
  capability?: string;
  output_family?: string;
  response_chars?: number;
  item_count?: number;
  total_weight_g?: number | null;
}

function parseOptions(args: string[]): {
  imagePath: string;
  iterations: number;
  plannerText: string;
  foodNote: string;
  suite: "all" | "planner" | "food";
  plannerTimeoutMs: number;
} {
  const values = new Map<string, string>();
  for (let index = 0; index < args.length; index += 2) {
    const key = args[index];
    const value = args[index + 1];
    if (!key?.startsWith("--") || value === undefined) {
      throw new Error("Arguments must use --key value pairs.");
    }
    values.set(key.slice(2), value);
  }
  const imagePath = values.get("image")?.trim() ?? "";
  if (imagePath === "") throw new Error("--image is required.");
  const iterations = Number(values.get("iterations") ?? "3");
  if (!Number.isInteger(iterations) || iterations < 1 || iterations > 10) {
    throw new Error("--iterations must be between 1 and 10.");
  }
  const suite = values.get("suite") ?? "all";
  if (suite !== "all" && suite !== "planner" && suite !== "food") {
    throw new Error("--suite must be all, planner, or food.");
  }
  const plannerTimeoutMs = Number(values.get("planner-timeout-ms") ?? "8000");
  if (
    !Number.isInteger(plannerTimeoutMs) || plannerTimeoutMs < 1000 ||
    plannerTimeoutMs > 30000
  ) {
    throw new Error("--planner-timeout-ms must be between 1000 and 30000.");
  }
  return {
    imagePath,
    iterations,
    plannerText: values.get("planner-text") ?? "请分析这张图片。",
    foodNote: values.get("food-note") ?? "请分析这份餐食。",
    suite,
    plannerTimeoutMs,
  };
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim() ?? "";
  if (value === "") throw new Error(`${name} is required.`);
  return value;
}

function mimeTypeForPath(
  path: string,
): "image/jpeg" | "image/png" | "image/webp" {
  const normalized = path.toLowerCase();
  if (normalized.endsWith(".jpg") || normalized.endsWith(".jpeg")) {
    return "image/jpeg";
  }
  if (normalized.endsWith(".png")) return "image/png";
  if (normalized.endsWith(".webp")) return "image/webp";
  throw new Error("Only JPEG, PNG, and WebP images are supported.");
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunkSize = 0x8000;
  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    binary += String.fromCharCode(
      ...bytes.subarray(offset, offset + chunkSize),
    );
  }
  return btoa(binary);
}

function elapsedMs(startedAt: number): number {
  return Math.round(performance.now() - startedAt);
}

function recordValue(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value : "";
}
