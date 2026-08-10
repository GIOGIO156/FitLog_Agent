import { assertEquals } from "jsr:@std/assert@1";
import type { GatewayRequest } from "../contracts.ts";
import { validateGroundedText } from "./faithfulness_guard.ts";

Deno.test("FitLog claims require compatible approved evidence", () => {
  const request = baseRequest();
  assertEquals(
    validateGroundedText("FitLog 的每侧次数规则是这样。", request)[0]?.reason,
    "fitlog_claim_without_approved_evidence",
  );
  request.phase5Context!.document_sources.push({
    doc_path: "docs/zh/Algorithm.md",
    heading: "次数",
    heading_path: ["次数"],
    section_id: "algorithm-reps",
    chunk_index: 1,
    chunk_count: 1,
    status: "implemented",
    score: 1,
    context_prefix: "来源",
    context_note: null,
    excerpt: "per_side_reps",
  });
  assertEquals(
    validateGroundedText("FitLog 的每侧次数规则是这样。", request),
    [],
  );
});

Deno.test("grounding compares canonical concepts across Chinese aliases and internal values", () => {
  const request = baseRequest();
  request.phase5Context!.document_sources.push({
    doc_path: "docs/zh/Algorithm.md",
    heading: "每侧次数",
    heading_path: ["每侧次数"],
    section_id: "algorithm-reps-zh",
    chunk_index: 1,
    chunk_count: 1,
    status: "implemented",
    authority: "current_product",
    score: 1,
    context_prefix: "来源",
    context_note: null,
    excerpt: "单边动作按每侧次数记录，计算时换算为整组总次数。",
  });
  assertEquals(
    validateGroundedText(
      "FitLog 使用 per_side_reps，并换算 total_reps。",
      request,
    ),
    [],
  );
});

Deno.test("wrong-language or non-goal sources cannot ground current product claims", () => {
  const request = baseRequest();
  request.phase5Context!.document_sources.push({
    doc_path: "docs/en/Algorithm.md",
    heading: "Reps",
    heading_path: ["Reps"],
    section_id: "algorithm-reps",
    chunk_index: 1,
    chunk_count: 1,
    status: "implemented",
    authority: "current_product",
    score: 1,
    context_prefix: "Source",
    context_note: null,
    excerpt: "per_side_reps",
  });
  assertEquals(
    validateGroundedText("FitLog 的每侧次数规则是这样。", request)[0]?.reason,
    "fitlog_claim_exceeds_matching_evidence",
  );
  request.phase5Context!.document_sources[0] = {
    ...request.phase5Context!.document_sources[0],
    doc_path: "docs/zh/Algorithm.md",
    status: "non_goal",
  };
  assertEquals(
    validateGroundedText("FitLog 的每侧次数规则是这样。", request)[0]?.reason,
    "fitlog_claim_without_approved_evidence",
  );
});

Deno.test("general knowledge does not fabricate document evidence", () => {
  assertEquals(
    validateGroundedText("蛋白质通常提供每克约 4 kcal。", baseRequest()),
    [],
  );
});

Deno.test("brand mentions in meal advice are not FitLog rule claims", () => {
  const request = baseRequest({
    workflow: "meal_decision",
  });
  assertEquals(
    validateGroundedText(
      "FitLog 可以帮你整理这顿怎么吃，但这次建议不是正式记录。",
      request,
    ),
    [],
  );
});

Deno.test("meal advice cannot attribute ordinary recommendations to FitLog", () => {
  const request = baseRequest({
    workflow: "meal_decision",
  });
  assertEquals(
    validateGroundedText(
      "根据 FitLog 的建议，你训练前可以点一份鸡胸肉米饭。",
      request,
    )[0]?.reason,
    "unsupported_fitlog_attribution",
  );
});

Deno.test("product rule claims still require document evidence outside app logic", () => {
  const request = baseRequest({
    workflow: "meal_decision",
  });
  assertEquals(
    validateGroundedText("FitLog 的数据库会保存这类规则。", request)[0]
      ?.reason,
    "fitlog_claim_without_approved_evidence",
  );
});

function baseRequest(options: {
  workflow?: GatewayRequest["workflowType"];
} = {}): GatewayRequest {
  const workflow = options.workflow ?? "auto";
  return {
    sessionId: null,
    messageText: "",
    deliveryMode: "sync",
    language: "zh",
    modelChoice: "qwen",
    workflowType: workflow,
    attachments: [],
    selectedDate: null,
    targetDate: null,
    dateResolutionSource: "unresolved",
    clientDraftSchemaVersion: "v3",
    profileVersion: null,
    deviceId: "device",
    allowRecordSummaryContext: false,
    conversationContext: null,
    phase5Context: {
      route: {
        workflow,
        confidence: 1,
        reasons: [],
        required_context: [],
        safety_flags: [],
        read_only: true,
      },
      context_objects: [],
      document_sources: [],
      called_tools: [],
      retrieved_dimensions: [],
      missing_dimensions: [],
      safety_flags: [],
    },
    expectedOutput: "text",
    taskPlan: null,
    exerciseReferences: [],
  };
}
