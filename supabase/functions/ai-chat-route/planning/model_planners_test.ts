import { assert, assertEquals } from "jsr:@std/assert@1";
import type { GatewayRequest } from "../contracts.ts";
import type { ProviderRuntimeConfig } from "../providers.ts";
import { createModelTaskPlanner, createRetrievalRewritePlanner } from "./model_planners.ts";

const config: ProviderRuntimeConfig = {
  openAiApiKey: "openai-key",
  openAiModel: "openai-model",
  qwenApiKey: "qwen-key",
  qwenModel: "qwen-model",
  qwenBaseUrl: "https://example.test/qwen",
  timeoutMs: 1000,
  allowMockProvider: false,
};

Deno.test("model task planner uses bounded provider JSON without user data tools", async () => {
  let body: Record<string, unknown> = {};
  const planner = createModelTaskPlanner("chatgpt", config, async (_url, init) => {
    body = JSON.parse(String(init?.body ?? "{}"));
    return new Response(JSON.stringify({ output_text: JSON.stringify({
      schema_version: "task_plan.v1",
      planned_workflow: "general_chat",
      expected_output: "text",
      entities: [],
      requested_context: [],
      retrieval_needs: [],
      confidence: 0.7,
      reasons: ["ambiguous_chat"],
      requires_clarification: false,
    }) }), { status: 200 });
  });
  assert(planner !== undefined);
  const result = await planner!({ message: "help", language: "en" }) as Record<string, unknown>;
  assertEquals(result.planned_workflow, "general_chat");
  assertEquals(JSON.stringify(body).includes("account_id"), false);
});

Deno.test("retrieval rewrite planner maps Qwen JSON action without broadening scope", async () => {
  const planner = createRetrievalRewritePlanner(request(), config, async (_url, init) => {
    const body = JSON.parse(String(init?.body ?? "{}"));
    assertEquals(body.enable_thinking, false);
    return new Response(JSON.stringify({ choices: [{ message: { content: JSON.stringify({
      action: "search_fitlog_docs",
      arguments: { query_variants: ["每侧次数 per_side_reps"], required_concepts: ["per_side_reps"] },
    }) } }] }), { status: 200 });
  });
  assert(planner !== undefined);
  const result = await planner!({ original_query: "每侧次数", normalized_concepts: ["per_side_reps"], missing_dimensions: ["canonical_concepts"] });
  assertEquals(result.action, "search_fitlog_docs");
});

function request(): GatewayRequest {
  return {
    sessionId: null,
    messageText: "每侧次数",
    language: "zh",
    modelChoice: "qwen",
    workflowType: "app_logic_answer",
    attachments: [],
    selectedDate: null,
    targetDate: null,
    dateResolutionSource: "unresolved",
    clientDraftSchemaVersion: "v3",
    profileVersion: null,
    deviceId: "device",
    allowRecordSummaryContext: false,
    conversationContext: null,
    phase5Context: null,
    expectedOutput: "text",
  };
}
