import type { ExpectedOutput, WorkflowType } from "../contracts.ts";

export type PlannedWorkflow = WorkflowType | "workout_logging" | "general_chat" | "safety_boundary";
export type PlannedContextType =
  | "document_context"
  | "profile_context"
  | "selected_day_summary"
  | "recent_food_summary"
  | "recent_workout_summary"
  | "body_metric_summary"
  | "weight_trend_summary"
  | "strategy_context"
  | "exercise_definition"
  | "exercise_history";

export interface TaskPlanV1 {
  schema_version: "task_plan.v1";
  source: "fixed_entry" | "deterministic" | "model" | "failure_fallback";
  confidence: number;
  original_workflow_hint: WorkflowType;
  planned_workflow: PlannedWorkflow;
  expected_output: ExpectedOutput;
  entities: Array<{
    type: "exercise" | "food" | "date";
    value: string;
  }>;
  requested_context: PlannedContextType[];
  retrieval_needs: PlannedContextType[];
  approved_context: PlannedContextType[];
  rejected_context: PlannedContextType[];
  reasons: string[];
  safety_flags: string[];
  requires_clarification: boolean;
}

export function parseModelTaskPlan(value: unknown, hint: WorkflowType): TaskPlanV1 | null {
  if (!isRecord(value) || value.schema_version !== "task_plan.v1") return null;
  const workflows = new Set<PlannedWorkflow>(["auto", "food_logging", "workout_logging", "meal_decision", "weekly_review", "app_logic_answer", "general_chat", "safety_boundary"]);
  const outputs = new Set(["auto", "text", "food_draft", "workout_draft"]);
  if (!workflows.has(value.planned_workflow as PlannedWorkflow) || !outputs.has(String(value.expected_output))) return null;
  const requested = contextArray(value.requested_context);
  if (requested === null) return null;
  return {
    schema_version: "task_plan.v1",
    source: "model",
    confidence: finiteConfidence(value.confidence),
    original_workflow_hint: hint,
    planned_workflow: value.planned_workflow as PlannedWorkflow,
    expected_output: value.expected_output as ExpectedOutput,
    entities: entityArray(value.entities),
    requested_context: requested,
    retrieval_needs: contextArray(value.retrieval_needs) ?? requested,
    approved_context: [],
    rejected_context: [],
    reasons: stringArray(value.reasons).slice(0, 6),
    safety_flags: [],
    requires_clarification: value.requires_clarification === true,
  };
}

function entityArray(value: unknown): TaskPlanV1["entities"] {
  if (!Array.isArray(value)) return [];
  const allowed = new Set(["exercise", "food", "date"]);
  return value.flatMap((item) => {
    if (!isRecord(item) || !allowed.has(String(item.type)) ||
      typeof item.value !== "string" || item.value.trim() === "") return [];
    return [{
      type: item.type as TaskPlanV1["entities"][number]["type"],
      value: item.value.trim().slice(0, 120),
    }];
  }).slice(0, 8);
}

function contextArray(value: unknown): PlannedContextType[] | null {
  const allowed = new Set<PlannedContextType>(["document_context", "profile_context", "selected_day_summary", "recent_food_summary", "recent_workout_summary", "body_metric_summary", "weight_trend_summary", "strategy_context", "exercise_definition", "exercise_history"]);
  if (!Array.isArray(value) || value.length > 10 || value.some((item) => !allowed.has(item))) return null;
  return [...new Set(value as PlannedContextType[])];
}

function stringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];
}

function finiteConfidence(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? Math.min(Math.max(value, 0), 1) : 0;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
