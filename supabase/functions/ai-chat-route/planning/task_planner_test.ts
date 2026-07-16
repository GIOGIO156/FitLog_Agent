import { assertEquals } from "jsr:@std/assert@1";
import type { GatewayRequest } from "../contracts.ts";
import { buildApprovedTaskPlan } from "./task_planner.ts";

for (const item of [
  { text: "鸡胸 200g 米饭 150g", workflow: "food_logging", output: "food_draft" },
  { text: "今天还能吃这个吗", images: 1, workflow: "meal_decision", output: "text" },
  { text: "保加利亚分腿蹲每侧次数怎么算", workflow: "app_logic_answer", output: "text" },
  { text: "像保加利分腿蹲的单侧次数，如果我填12的话，相当于一组蹲了24次？一边12次，算总训练重量的时候怎么算的", workflow: "app_logic_answer", output: "text" },
  { text: "记录保加利亚分腿蹲 3 组，每侧 12", workflow: "workout_logging", output: "workout_draft" },
  { text: "深蹲 80kg 3 组 10 次", workflow: "workout_logging", output: "workout_draft" },
  { text: "你好", workflow: "general_chat", output: "text" },
] as const) {
  Deno.test(`task planner resolves ${item.text}`, async () => {
    const plan = await buildApprovedTaskPlan(request(item.text, item.images ?? 0));
    assertEquals(plan.planned_workflow, item.workflow);
    assertEquals(plan.expected_output, item.output);
  });
}

Deno.test("exercise rule question approves document and definition before context build", async () => {
  const plan = await buildApprovedTaskPlan(request("保加利亚分腿蹲每侧次数怎么算"));
  assertEquals(plan.approved_context, ["document_context", "exercise_definition"]);
});

Deno.test("fixed workout entry cannot be downgraded to text", async () => {
  const value = request("记录深蹲 3 组，每组 10 次，100kg");
  value.workflowType = "workout_logging";
  const plan = await buildApprovedTaskPlan(value);
  assertEquals(plan.planned_workflow, "workout_logging");
  assertEquals(plan.expected_output, "workout_draft");
  assertEquals(plan.approved_context, ["exercise_definition"]);
  assertEquals(plan.source, "fixed_entry");
});

Deno.test("record permission cannot be expanded by model planner", async () => {
  const plan = await buildApprovedTaskPlan(request("分析一下", 0, false), () => Promise.resolve({
    schema_version: "task_plan.v1", planned_workflow: "weekly_review", expected_output: "text",
    requested_context: ["recent_food_summary", "recent_workout_summary"], reasons: ["model"], confidence: 0.9,
  }));
  assertEquals(plan.approved_context, []);
  assertEquals(plan.rejected_context, ["recent_food_summary", "recent_workout_summary"]);
});

Deno.test("ambiguous image request clarifies without protected context", async () => {
  const plan = await buildApprovedTaskPlan(request("鸡胸", 1));
  assertEquals(plan.requires_clarification, true);
  assertEquals(plan.approved_context, []);
});

Deno.test("same-chat workout continuation inherits bounded workflow", async () => {
  const value = request("它再加一组");
  value.conversationContext = { messages: [], artifacts: [{ type: "workout_draft", title: "深蹲", summary: "3 组" }] };
  const plan = await buildApprovedTaskPlan(value);
  assertEquals(plan.planned_workflow, "workout_logging");
});

Deno.test("a workout question is not treated as continuation without a draft artifact", async () => {
  const value = request("这个怎么算？");
  value.conversationContext = { messages: [{ role: "assistant", text: "上一条解释了训练次数。" }], artifacts: [] };
  const plan = await buildApprovedTaskPlan(value);
  assertEquals(plan.planned_workflow, "app_logic_answer");
  assertEquals(plan.expected_output, "text");
});

Deno.test("explicit workout write plus question requires one intent clarification", async () => {
  const plan = await buildApprovedTaskPlan(request("帮我记录分腿蹲 3 组每侧 12 次，另外总容量怎么算？"));
  assertEquals(plan.requires_clarification, true);
  assertEquals(plan.expected_output, "text");
  assertEquals(plan.reasons, ["workout_write_and_question_intents"]);
  assertEquals(plan.source, "deterministic");
});

function request(text: string, imageCount = 0, permission = false): GatewayRequest {
  return {
    sessionId: null, messageText: text, language: "zh", modelChoice: "qwen", workflowType: "auto",
    attachments: Array.from({ length: imageCount }, () => ({ kind: "image" as const, mimeType: "image/jpeg" as const, base64Data: "AA==", byteLength: 1, name: null })),
    selectedDate: null, targetDate: null, dateResolutionSource: "unresolved", clientDraftSchemaVersion: "v2",
    profileVersion: null, deviceId: "device", allowRecordSummaryContext: permission, conversationContext: null,
    phase5Context: null, expectedOutput: "auto", taskPlan: null,
  };
}
