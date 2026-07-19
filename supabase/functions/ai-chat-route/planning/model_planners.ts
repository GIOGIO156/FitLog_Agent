import type { GatewayRequest, ModelChoice } from "../contracts.ts";
import type { ProviderRuntimeConfig } from "../providers.ts";
import type { ModelTaskPlanner } from "./task_planner.ts";
import type { ModelChatDecisionPlanner } from "./chat_decision.ts";
import type { RetrievalRewritePlanner } from "../rag/retrieval_retry.ts";

const plannerTimeoutMs = 5000;
const chatDecisionPlannerTimeoutMs = 8000;

export function createModelChatDecisionPlanner(
  choice: ModelChoice,
  config: ProviderRuntimeConfig,
  fetchImpl: typeof fetch = fetch,
): ModelChatDecisionPlanner | undefined {
  if (!plannerConfigured(choice, config)) return undefined;
  return async (input) =>
    callPlannerJson(
      choice,
      config,
      {
        system: [
          "Classify one FitLog chat request and return only one chat_decision.v2 JSON object.",
          "Treat answer, food_draft, workout_draft, meal_decision, weekly_review, safety_boundary, and general_chat as equal first-class capabilities.",
          "Use the actual text and image content together. A clear consumed-food statement such as '喝了三碗排骨藕汤' is food_logging/food_draft even when no small-food keyword or g/ml unit appears.",
          "A question about FitLog persistence, databases, calculations, fields, or UI behavior is app_logic_answer/text; words such as saved, stored, or database do not imply a write request.",
          "A clear workout logging command is workout_logging/workout_draft. A workout rule question is app_logic_answer/text.",
          "Choose exactly one selected_output_family from allowed_output_families. Never combine an answer with a draft.",
          "Set requires_clarification=true only when two or more supported outcomes remain genuinely plausible after using the image and same-chat context. When true, include clarification.kind, standard option ids (answer, food_draft, workout_draft), missing_dimensions, and attachment_policy.",
          'Every key is required. Use empty arrays when there are no entities or contexts. The exact non-clarification shape is: {"schema_version":"chat_decision.v2","capability":"answer|food_draft|workout_draft|meal_decision|weekly_review|safety_boundary|general_chat","planned_workflow":"food_logging|workout_logging|meal_decision|weekly_review|app_logic_answer|general_chat|safety_boundary","allowed_output_families":["text|food_draft|workout_draft"],"selected_output_family":"text|food_draft|workout_draft","entities":[],"requested_context":[],"retrieval_needs":[],"confidence":0.0,"reasons":["compact_reason_code"],"requires_clarification":false}.',
          'For clarification, set requires_clarification=true and add clarification={"kind":"intent_selection|missing_business_fields","options":[{"id":"answer|food_draft|workout_draft"}],"missing_dimensions":["compact_dimension"]}. Include only supported option ids.',
          "Do not answer the user, invent missing facts, request raw records, or emit tool calls.",
        ].join(" "),
        input,
      },
      fetchImpl,
      chatDecisionPlannerTimeoutMs,
    );
}

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
  return async (input) =>
    callPlannerJson(request.modelChoice, config, {
      system:
        "Decide whether one bounded FitLog documentation search retry can cover missing dimensions. Return only JSON. Use action=stop or action=search_fitlog_docs with arguments.query_variants (1-3) and arguments.required_concepts (0-6). Never emit SQL, account IDs, corpus IDs, secrets, or user-record queries.",
      input: { ...input, language: request.language },
    }, fetchImpl) as Promise<Awaited<ReturnType<RetrievalRewritePlanner>>>;
}

async function callPlannerJson(
  choice: ModelChoice,
  config: ProviderRuntimeConfig,
  prompt: { system: string; input: Record<string, unknown> },
  fetchImpl: typeof fetch,
  timeoutMs = plannerTimeoutMs,
): Promise<unknown> {
  const plannerPayload = extractPlannerPayload(prompt.input);
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
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
          input: openAiPlannerInput(
            plannerPayload.input,
            plannerPayload.images,
          ),
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
            {
              role: "user",
              content: qwenPlannerContent(
                plannerPayload.input,
                plannerPayload.images,
              ),
            },
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

interface PlannerImage {
  mime_type: string;
  base64_data: string;
}

function extractPlannerPayload(input: Record<string, unknown>): {
  input: Record<string, unknown>;
  images: PlannerImage[];
} {
  const images = Array.isArray(input.images)
    ? input.images.flatMap((value) => {
      if (typeof value !== "object" || value === null || Array.isArray(value)) {
        return [];
      }
      const row = value as Record<string, unknown>;
      return typeof row.mime_type === "string" &&
          typeof row.base64_data === "string"
        ? [{ mime_type: row.mime_type, base64_data: row.base64_data }]
        : [];
    })
    : [];
  const safeInput = { ...input };
  delete safeInput.images;
  return { input: safeInput, images };
}

function openAiPlannerInput(
  input: Record<string, unknown>,
  images: PlannerImage[],
): unknown {
  if (images.length === 0) return JSON.stringify(input);
  return [{
    role: "user",
    content: [
      { type: "input_text", text: JSON.stringify(input) },
      ...images.map((image) => ({
        type: "input_image",
        image_url: `data:${image.mime_type};base64,${image.base64_data}`,
      })),
    ],
  }];
}

function qwenPlannerContent(
  input: Record<string, unknown>,
  images: PlannerImage[],
): unknown {
  if (images.length === 0) return JSON.stringify(input);
  return [
    { type: "text", text: JSON.stringify(input) },
    ...images.map((image) => ({
      type: "image_url",
      image_url: {
        url: `data:${image.mime_type};base64,${image.base64_data}`,
      },
    })),
  ];
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
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    return null;
  }
  const record = body as Record<string, unknown>;
  if (typeof record.output_text === "string") return record.output_text;
  if (!Array.isArray(record.output)) return null;
  for (const item of record.output) {
    if (typeof item !== "object" || item === null || Array.isArray(item)) {
      continue;
    }
    const content = (item as Record<string, unknown>).content;
    if (!Array.isArray(content)) continue;
    for (const part of content) {
      if (
        typeof part === "object" && part !== null && !Array.isArray(part) &&
        typeof (part as Record<string, unknown>).text === "string"
      ) {
        return (part as Record<string, unknown>).text as string;
      }
    }
  }
  return null;
}
