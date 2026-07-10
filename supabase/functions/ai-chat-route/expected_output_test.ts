import { parseGatewayRequest } from "./contracts.ts";
import { resolveExpectedOutput } from "./expected_output.ts";

Deno.test("expected output is resolved server-side from route and explicit intent", () => {
  assertEquals(resolveExpectedOutput(request("hello")), "text");
  assertEquals(
    resolveExpectedOutput(request("帮我生成一条饮食记录")),
    "food_draft",
  );
  assertEquals(
    resolveExpectedOutput(request("记录 200ml 全脂牛奶")),
    "food_draft",
  );
  assertEquals(
    resolveExpectedOutput(request("Create a workout draft for 3x10 squats")),
    "workout_draft",
  );
  assertEquals(
    resolveExpectedOutput(request("Log bench press 20 kg for 3 sets")),
    "workout_draft",
  );
});

Deno.test("read-only route always resolves text", () => {
  const base = request("帮我生成一条饮食记录");
  assertEquals(
    resolveExpectedOutput({
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
    }),
    "text",
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
