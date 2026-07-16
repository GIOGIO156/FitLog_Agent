import type { GatewayRequest, ModelChoice } from "../contracts.ts";
import type { ProviderRuntimeConfig } from "../providers.ts";
import type { ModelTaskPlanner } from "./task_planner.ts";
import type { RetrievalRewritePlanner } from "../rag/retrieval_retry.ts";

const plannerTimeoutMs = 5000;

export function createModelTaskPlanner(
  choice: ModelChoice,
  config: ProviderRuntimeConfig,
  fetchImpl: typeof fetch = fetch,
): ModelTaskPlanner | undefined {
  if (!plannerConfigured(choice, config)) return undefined;
  return async (input) =>
    callPlannerJson(choice, config, {
      system: [
        "Classify one FitLog chat request and return only one task_plan.v1 JSON object.",
        "Choose exactly one planned_workflow and expected_output; never combine an answer with a food or workout draft.",
        "A workout question containing numbers, reps, sets, or weight is app_logic_answer/text when it asks how, why, whether, or how a value is calculated and does not explicitly ask to log or save.",
        "An explicit logging command such as '记录分腿蹲3组每侧12次' is workout_logging/workout_draft. A complete non-question workout statement such as '深蹲80kg 3组10次' may also be workout_logging/workout_draft.",
        "If the user explicitly requests both logging and an answer, set requires_clarification=true instead of combining outputs.",
        "Include schema_version, planned_workflow, expected_output, entities, requested_context, retrieval_needs, confidence, reasons, and requires_clarification.",
        "Do not answer the user and do not request raw records. Choose the minimum context needed.",
      ].join(" "),
      input,
    }, fetchImpl);
}

export function createRetrievalRewritePlanner(
  request: GatewayRequest,
  config: ProviderRuntimeConfig,
  fetchImpl: typeof fetch = fetch,
): RetrievalRewritePlanner | undefined {
  if (!plannerConfigured(request.modelChoice, config)) return undefined;
  return async (input) => callPlannerJson(request.modelChoice, config, {
    system: "Decide whether one bounded FitLog documentation search retry can cover missing dimensions. Return only JSON. Use action=stop or action=search_fitlog_docs with arguments.query_variants (1-3) and arguments.required_concepts (0-6). Never emit SQL, account IDs, corpus IDs, secrets, or user-record queries.",
    input: { ...input, language: request.language },
  }, fetchImpl) as Promise<Awaited<ReturnType<RetrievalRewritePlanner>>>;
}

async function callPlannerJson(
  choice: ModelChoice,
  config: ProviderRuntimeConfig,
  prompt: { system: string; input: Record<string, unknown> },
  fetchImpl: typeof fetch,
): Promise<unknown> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), plannerTimeoutMs);
  try {
    const response = choice === "chatgpt"
      ? await fetchImpl("https://api.openai.com/v1/responses", {
        method: "POST",
        headers: {
          authorization: `Bearer ${config.openAiApiKey}`,
          "content-type": "application/json",
        },
        signal: controller.signal,
        body: JSON.stringify({
          model: config.openAiModel,
          instructions: prompt.system,
          input: JSON.stringify(prompt.input),
          text: { format: { type: "json_object" } },
        }),
      })
      : await fetchImpl(config.qwenBaseUrl, {
        method: "POST",
        headers: {
          authorization: `Bearer ${config.qwenApiKey}`,
          "content-type": "application/json",
        },
        signal: controller.signal,
        body: JSON.stringify({
          model: config.qwenModel,
          messages: [
            { role: "system", content: prompt.system },
            { role: "user", content: JSON.stringify(prompt.input) },
          ],
          response_format: { type: "json_object" },
          enable_thinking: false,
        }),
      });
    if (!response.ok) throw new Error("planner_provider_failure");
    const body = await response.json();
    const text = choice === "chatgpt"
      ? openAiOutputText(body)
      : body?.choices?.[0]?.message?.content;
    if (typeof text !== "string" || text.trim() === "") {
      throw new Error("planner_output_missing");
    }
    return JSON.parse(text);
  } finally {
    clearTimeout(timeout);
  }
}

function plannerConfigured(
  choice: ModelChoice,
  config: ProviderRuntimeConfig,
): boolean {
  return choice === "chatgpt"
    ? config.openAiApiKey.trim() !== "" && config.openAiModel.trim() !== ""
    : config.qwenApiKey.trim() !== "" && config.qwenModel.trim() !== "" &&
      config.qwenBaseUrl.trim() !== "";
}

function openAiOutputText(body: unknown): string | null {
  if (typeof body !== "object" || body === null || Array.isArray(body)) return null;
  const record = body as Record<string, unknown>;
  if (typeof record.output_text === "string") return record.output_text;
  if (!Array.isArray(record.output)) return null;
  for (const item of record.output) {
    if (typeof item !== "object" || item === null || Array.isArray(item)) continue;
    const content = (item as Record<string, unknown>).content;
    if (!Array.isArray(content)) continue;
    for (const part of content) {
      if (typeof part === "object" && part !== null && !Array.isArray(part) &&
        typeof (part as Record<string, unknown>).text === "string") {
        return (part as Record<string, unknown>).text as string;
      }
    }
  }
  return null;
}
