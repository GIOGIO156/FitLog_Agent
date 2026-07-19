import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import type { GatewayRequest } from "../contracts.ts";
import { buildApprovedChatDecision } from "./chat_decision.ts";
import { ChatDecisionPlanningError } from "./chat_decision_contract.ts";

Deno.test("database persistence questions are symmetric app logic answers", async () => {
  for (
    const text of [
      "Where is the workout exercise snapshot persisted?",
      "锻炼快照保存在哪张数据库表？",
    ]
  ) {
    const result = await buildApprovedChatDecision(request(text));
    assertEquals(result.planned_workflow, "app_logic_answer");
    assertEquals(result.selected_output_family, "text");
    assertEquals(result.approved_context, ["document_context"]);
    assertEquals(result.requires_clarification, false);
  }
});

Deno.test("permission and RAG boundary questions are deterministic app logic answers", async () => {
  for (
    const text of [
      "AI 能直接修改饮食目标吗？",
      "Document RAG 会给用户记录做 embedding 吗？",
      "Can AI modify diet goals directly?",
      "Does Document RAG embed user records?",
    ]
  ) {
    let plannerCalled = false;
    const result = await buildApprovedChatDecision(request(text), async () => {
      plannerCalled = true;
      return null;
    });
    assertEquals(result.planned_workflow, "app_logic_answer");
    assertEquals(result.selected_output_family, "text");
    assertEquals(result.approved_context, ["document_context"]);
    assertEquals(result.requires_clarification, false);
    assertEquals(result.reasons, ["fitlog_capability_boundary_question"]);
    assertEquals(plannerCalled, false);
  }
});

Deno.test("capability questions do not convert direct write commands into answers", async () => {
  const result = await buildApprovedChatDecision(
    request("帮我直接修改饮食目标"),
    async () => ({
      schema_version: "chat_decision.v2",
      capability: "safety_boundary",
      planned_workflow: "safety_boundary",
      allowed_output_families: ["text"],
      selected_output_family: "text",
      entities: [],
      requested_context: ["document_context"],
      retrieval_needs: ["document_context"],
      confidence: 1,
      reasons: ["direct_write_request"],
      requires_clarification: false,
    }),
  );
  assertEquals(result.planned_workflow, "safety_boundary");
  assertEquals(result.selected_output_family, "text");
});

Deno.test("clear soup consumption with an image becomes a food draft", async () => {
  let plannerCalled = false;
  const result = await buildApprovedChatDecision(
    request("一锅武汉排骨藕汤，喝了三碗", { withImage: true }),
    async () => {
      plannerCalled = true;
      return null;
    },
  );
  assertEquals(result.planned_workflow, "food_logging");
  assertEquals(result.selected_output_family, "food_draft");
  assertEquals(result.requires_clarification, false);
  assertEquals(plannerCalled, false);
});

Deno.test("legacy implicit food quantities remain a deterministic food draft", async () => {
  const result = await buildApprovedChatDecision(
    request("鸡胸 200g 米饭 150g"),
  );
  assertEquals(result.planned_workflow, "food_logging");
  assertEquals(result.selected_output_family, "food_draft");
  assertEquals(result.reasons, ["implicit_food_draft_intent"]);
});

Deno.test("typed answer selection restores the origin capability", async () => {
  const result = await buildApprovedChatDecision(
    request("回答问题", {
      resolved: {
        clarificationId: "00000000-0000-4000-8000-000000000010",
        optionId: "answer",
        resultingOutput: "text",
        resultingWorkflow: "app_logic_answer",
        originMessageText: "Where is the snapshot persisted?",
        attachmentPolicy: "none",
      },
    }),
  );
  assertEquals(result.source, "clarification_reply");
  assertEquals(result.planned_workflow, "app_logic_answer");
  assertEquals(result.selected_output_family, "text");
  assertEquals(result.requires_clarification, false);
});

Deno.test("typed workout answer restores its exercise context", async () => {
  const origin =
    "请记录保加利亚分腿蹲80kg 3组每侧10次，这个动作的每侧次数如何计算训练量？";
  const result = await buildApprovedChatDecision(
    request("回答问题", {
      resolved: {
        clarificationId: "00000000-0000-4000-8000-000000000011",
        optionId: "answer",
        resultingOutput: "text",
        resultingWorkflow: "app_logic_answer",
        originMessageText: origin,
        attachmentPolicy: "none",
      },
    }),
  );
  assertEquals(result.planned_workflow, "app_logic_answer");
  assertEquals(
    result.approved_context,
    ["document_context", "exercise_definition"],
  );
});

Deno.test("mixed answer and workout write intent returns bounded typed options", async () => {
  const result = await buildApprovedChatDecision(
    request("请记录深蹲80kg 3组10次，这个训练量怎么算？"),
  );
  assertEquals(result.requires_clarification, true);
  assertEquals(
    result.clarification?.options.map((option) => option.id),
    ["answer", "workout_draft"],
  );
});

Deno.test("unclassified requests fail honestly when planner is unavailable", async () => {
  await assertRejects(
    () => buildApprovedChatDecision(request("帮我看看这个")),
    ChatDecisionPlanningError,
    "planner_unavailable",
  );
});

Deno.test("invalid model decisions are not converted into clarification", async () => {
  await assertRejects(
    () => buildApprovedChatDecision(request("帮我看看这个"), async () => ({})),
    ChatDecisionPlanningError,
    "planner_output_invalid",
  );
});

function request(
  messageText: string,
  options: {
    withImage?: boolean;
    resolved?: GatewayRequest["resolvedClarification"];
  } = {},
): GatewayRequest {
  return {
    sessionId: null,
    messageText,
    submittedMessageText: messageText,
    clientRequestId: "decision_test_1",
    language: /[\u3400-\u9fff]/u.test(messageText) ? "zh" : "en",
    modelChoice: "qwen",
    workflowType: "auto",
    attachments: options.withImage
      ? [{
        kind: "image",
        mimeType: "image/jpeg",
        base64Data: "aW1hZ2U=",
        byteLength: 5,
        name: "soup.jpg",
      }]
      : [],
    selectedDate: null,
    targetDate: null,
    dateResolutionSource: "unresolved",
    clientDraftSchemaVersion: "v3",
    profileVersion: null,
    deviceId: "device",
    allowRecordSummaryContext: false,
    conversationContext: null,
    phase5Context: null,
    clarificationReply: null,
    resolvedClarification: options.resolved ?? null,
    taskPlan: null,
    expectedOutput: "auto",
  };
}
