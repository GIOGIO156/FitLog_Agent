import type { TaskPlanV1 } from "./task_plan_contract.ts";
import type { ChatDecisionV2 } from "./chat_decision_contract.ts";

export function compareLegacyPlanToChatDecision(
  legacy: TaskPlanV1,
  shadow: ChatDecisionV2,
): string | null {
  const mismatches: string[] = [];
  if (legacy.planned_workflow !== shadow.planned_workflow) {
    mismatches.push("workflow");
  }
  if (legacy.expected_output !== shadow.selected_output_family) {
    mismatches.push("output");
  }
  if (legacy.requires_clarification !== shadow.requires_clarification) {
    mismatches.push("clarification");
  }
  if (!sameSet(legacy.approved_context, shadow.approved_context)) {
    mismatches.push("context");
  }
  return mismatches.length === 0 ? null : mismatches.join(",");
}

function sameSet(left: string[], right: string[]): boolean {
  if (left.length !== right.length) return false;
  const expected = new Set(left);
  return right.every((value) => expected.has(value));
}
