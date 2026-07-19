import { assertEquals } from "jsr:@std/assert@1";
import type { TaskPlanV1 } from "./task_plan_contract.ts";
import type { ChatDecisionV2 } from "./chat_decision_contract.ts";
import { compareLegacyPlanToChatDecision } from "./chat_decision_shadow.ts";

const legacy: TaskPlanV1 = {
  schema_version: "task_plan.v1",
  source: "deterministic",
  confidence: 0.9,
  original_workflow_hint: "auto",
  planned_workflow: "app_logic_answer",
  expected_output: "text",
  entities: [],
  requested_context: ["document_context"],
  retrieval_needs: ["document_context"],
  approved_context: ["document_context"],
  rejected_context: [],
  reasons: ["database_question"],
  safety_flags: [],
  requires_clarification: false,
};

const shadow: ChatDecisionV2 = {
  schema_version: "chat_decision.v2",
  source: "deterministic",
  confidence: 0.9,
  original_workflow_hint: "auto",
  capability: "answer",
  planned_workflow: "app_logic_answer",
  allowed_output_families: ["text"],
  selected_output_family: "text",
  entities: [],
  requested_context: ["document_context"],
  retrieval_needs: ["document_context"],
  approved_context: ["document_context"],
  rejected_context: [],
  reasons: ["database_question"],
  safety_flags: [],
  requires_clarification: false,
  clarification: null,
  attachment_policy: "none",
};

Deno.test("shadow comparison reports no mismatch for equivalent decisions", () => {
  assertEquals(compareLegacyPlanToChatDecision(legacy, shadow), null);
});

Deno.test("shadow comparison reports only behavior-relevant categories", () => {
  assertEquals(
    compareLegacyPlanToChatDecision(legacy, {
      ...shadow,
      planned_workflow: "food_logging",
      selected_output_family: "food_draft",
      allowed_output_families: ["food_draft"],
      approved_context: [],
      requires_clarification: true,
      clarification: {
        kind: "intent_selection",
        options: [],
        missing_dimensions: ["requested_output_family"],
        attachment_policy: "none",
      },
    }),
    "workflow,output,clarification,context",
  );
});
