import type { GatewayRequest } from "../contracts.ts";
import type { PlannedContextType, PlannedWorkflow, TaskPlanV1 } from "./task_plan_contract.ts";

const allowedByWorkflow: Record<PlannedWorkflow, PlannedContextType[]> = {
  auto: [],
  general_chat: ["document_context"],
  food_logging: [],
  workout_logging: ["exercise_definition", "exercise_history"],
  meal_decision: ["profile_context", "selected_day_summary", "strategy_context", "document_context"],
  weekly_review: ["profile_context", "recent_food_summary", "recent_workout_summary", "body_metric_summary", "weight_trend_summary", "strategy_context"],
  app_logic_answer: ["document_context", "exercise_definition"],
  safety_boundary: ["document_context"],
};

const protectedRecordContext = new Set<PlannedContextType>(["selected_day_summary", "recent_food_summary", "recent_workout_summary", "body_metric_summary", "weight_trend_summary", "exercise_history"]);

export function applyContextPolicy(plan: TaskPlanV1, request: GatewayRequest): TaskPlanV1 {
  const allowed = new Set(allowedByWorkflow[plan.planned_workflow]);
  const approved: PlannedContextType[] = [];
  const rejected: PlannedContextType[] = [];
  for (const context of plan.requested_context) {
    const permitted = allowed.has(context) && (!protectedRecordContext.has(context) || request.allowRecordSummaryContext);
    (permitted ? approved : rejected).push(context);
  }
  if (plan.planned_workflow === "general_chat" && !plan.reasons.includes("fitlog_rule_question")) {
    const index = approved.indexOf("document_context");
    if (index >= 0) { approved.splice(index, 1); rejected.push("document_context"); }
  }
  return { ...plan, approved_context: [...new Set(approved)], rejected_context: [...new Set(rejected)] };
}
