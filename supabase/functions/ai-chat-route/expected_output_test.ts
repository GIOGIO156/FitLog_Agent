import { parseGatewayRequest } from "./contracts.ts";
import { resolveOutputSelection } from "./expected_output.ts";

Deno.test("deterministic resolver abstains unless intent is high confidence", () => {
  assertSelection(request("hello"), "auto", "model");
  assertSelection(
    request("帮我生成一条饮食记录"),
    "food_draft",
    "deterministic",
  );
  assertSelection(
    request("记录 200ml 全脂牛奶"),
    "food_draft",
    "deterministic",
  );
  assertSelection(
    request("Create a workout draft for 3x10 squats"),
    "workout_draft",
    "deterministic",
  );
  assertSelection(
    request("Log bench press 20 kg for 3 sets"),
    "workout_draft",
    "deterministic",
  );
  assertSelection(
    request("设置卧推的草稿，20kg5次"),
    "workout_draft",
    "deterministic",
  );
});

Deno.test("read-only answer route resolves ordinary questions to text", () => {
  const base = request("解释一下 energy_ratio");
  assertSelection(
    {
      ...base,
      phase5Context: {
        route: {
          workflow: "app_logic_answer",
          confidence: 1,
          reasons: ["test"],
          required_context: [],
          safety_flags: [],
          read_only: true,
        },
        context_objects: [],
        document_sources: [],
        retrieved_dimensions: [],
        missing_dimensions: [],
        safety_flags: [],
        called_tools: [],
      },
    },
    "text",
    "deterministic",
  );
});

Deno.test("context workflow does not erase an explicit draft intent", () => {
  const base = request("帮我生成这份晚餐的饮食草稿");
  assertSelection(
    {
      ...base,
      phase5Context: {
        route: {
          workflow: "meal_decision",
          confidence: 0.9,
          reasons: ["test"],
          required_context: ["selected_day_summary"],
          safety_flags: [],
          read_only: true,
        },
        context_objects: [],
        document_sources: [],
        retrieved_dimensions: [],
        missing_dimensions: [],
        safety_flags: [],
        called_tools: [],
      },
    },
    "food_draft",
    "deterministic",
  );
});

Deno.test("dedicated food workflow bypasses chat intent inference", () => {
  const base = request("这张图是什么？");
  assertSelection(
    { ...base, workflowType: "food_logging" },
    "food_draft",
    "fixed_workflow",
  );
});

function request(message: string) {
  return parseGatewayRequest({
    message: { text: message },
    language: "zh",
    model_choice: "qwen",
    workflow_hint: "auto",
    device_id: "device-a",
  });
}

function assertEquals(actual: unknown, expected: unknown): void {
  if (actual !== expected) {
    throw new Error(`Expected ${expected}, got ${actual}`);
  }
}

function assertSelection(
  requestValue: ReturnType<typeof request>,
  expectedOutput: string,
  source: string,
): void {
  const selection = resolveOutputSelection(requestValue);
  assertEquals(selection.expectedOutput, expectedOutput);
  assertEquals(selection.source, source);
}
