import type { ExpectedOutput, WorkflowType } from "../contracts.ts";
import {
  type PlannedContextType,
  type PlannedWorkflow,
  type TaskPlanV1,
} from "./task_plan_contract.ts";

export type ChatDecisionSource =
  | "clarification_reply"
  | "fixed_entry"
  | "deterministic"
  | "model";

export type ChatCapability =
  | "answer"
  | "food_draft"
  | "workout_draft"
  | "meal_decision"
  | "weekly_review"
  | "safety_boundary"
  | "general_chat";

export type ChatAttachmentPolicy =
  | "none"
  | "consume_current"
  | "runtime_rebind_available"
  | "resend_required";

export type ClarificationKind =
  | "intent_selection"
  | "missing_business_fields";

export interface ChatClarificationOptionV2 {
  id: "answer" | "food_draft" | "workout_draft";
  label_zh: string;
  label_en: string;
  resulting_output: Exclude<ExpectedOutput, "auto">;
  resulting_workflow: PlannedWorkflow;
}

export interface ChatClarificationSpecV2 {
  kind: ClarificationKind;
  options: ChatClarificationOptionV2[];
  missing_dimensions: string[];
  attachment_policy: ChatAttachmentPolicy;
}

export interface ChatDecisionV2 {
  schema_version: "chat_decision.v2";
  source: ChatDecisionSource;
  confidence: number;
  original_workflow_hint: WorkflowType;
  capability: ChatCapability;
  planned_workflow: PlannedWorkflow;
  allowed_output_families: Array<Exclude<ExpectedOutput, "auto">>;
  selected_output_family: Exclude<ExpectedOutput, "auto">;
  entities: TaskPlanV1["entities"];
  requested_context: PlannedContextType[];
  retrieval_needs: PlannedContextType[];
  approved_context: PlannedContextType[];
  rejected_context: PlannedContextType[];
  reasons: string[];
  safety_flags: string[];
  requires_clarification: boolean;
  clarification: ChatClarificationSpecV2 | null;
  attachment_policy: ChatAttachmentPolicy;
}

export class ChatDecisionPlanningError extends Error {
  constructor(
    readonly code: "planner_unavailable" | "planner_output_invalid",
  ) {
    super(code);
  }
}

export function parseModelChatDecision(
  value: unknown,
  hint: WorkflowType,
  hasAttachments: boolean,
): ChatDecisionV2 | null {
  if (!isRecord(value) || value.schema_version !== "chat_decision.v2") {
    return null;
  }
  const workflows = new Set<PlannedWorkflow>([
    "auto",
    "food_logging",
    "workout_logging",
    "meal_decision",
    "weekly_review",
    "app_logic_answer",
    "general_chat",
    "safety_boundary",
  ]);
  const outputs = new Set<Exclude<ExpectedOutput, "auto">>([
    "text",
    "food_draft",
    "workout_draft",
  ]);
  const capabilities = new Set<ChatCapability>([
    "answer",
    "food_draft",
    "workout_draft",
    "meal_decision",
    "weekly_review",
    "safety_boundary",
    "general_chat",
  ]);
  if (
    !workflows.has(value.planned_workflow as PlannedWorkflow) ||
    !outputs.has(
      value.selected_output_family as Exclude<ExpectedOutput, "auto">,
    ) ||
    !capabilities.has(value.capability as ChatCapability)
  ) {
    return null;
  }
  const allowed = outputArray(value.allowed_output_families);
  const selected = value.selected_output_family as Exclude<
    ExpectedOutput,
    "auto"
  >;
  if (allowed === null || !allowed.includes(selected)) return null;
  const requested = contextArray(value.requested_context);
  if (requested === null) return null;
  const requiresClarification = value.requires_clarification === true;
  const clarification = requiresClarification
    ? parseClarification(value.clarification, hasAttachments)
    : null;
  if (requiresClarification && clarification === null) return null;
  return {
    schema_version: "chat_decision.v2",
    source: "model",
    confidence: finiteConfidence(value.confidence),
    original_workflow_hint: hint,
    capability: value.capability as ChatCapability,
    planned_workflow: value.planned_workflow as PlannedWorkflow,
    allowed_output_families: allowed,
    selected_output_family: selected,
    entities: entityArray(value.entities),
    requested_context: requested,
    retrieval_needs: contextArray(value.retrieval_needs) ?? requested,
    approved_context: [],
    rejected_context: [],
    reasons: stringArray(value.reasons).slice(0, 6),
    safety_flags: [],
    requires_clarification: requiresClarification,
    clarification,
    attachment_policy: requiresClarification
      ? clarification!.attachment_policy
      : hasAttachments
      ? "consume_current"
      : "none",
  };
}

export function decisionToTaskPlan(decision: ChatDecisionV2): TaskPlanV1 {
  return {
    schema_version: "task_plan.v1",
    source: decision.source === "clarification_reply"
      ? "deterministic"
      : decision.source,
    confidence: decision.confidence,
    original_workflow_hint: decision.original_workflow_hint,
    planned_workflow: decision.planned_workflow,
    expected_output: decision.selected_output_family,
    entities: decision.entities,
    requested_context: decision.requested_context,
    retrieval_needs: decision.retrieval_needs,
    approved_context: decision.approved_context,
    rejected_context: decision.rejected_context,
    reasons: decision.reasons,
    safety_flags: decision.safety_flags,
    requires_clarification: decision.requires_clarification,
  };
}

function parseClarification(
  value: unknown,
  hasAttachments: boolean,
): ChatClarificationSpecV2 | null {
  if (!isRecord(value)) return null;
  const kind = value.kind;
  if (kind !== "intent_selection" && kind !== "missing_business_fields") {
    return null;
  }
  const options = optionArray(value.options);
  if (options.length === 0) return null;
  return {
    kind,
    options,
    missing_dimensions: stringArray(value.missing_dimensions).slice(0, 8),
    attachment_policy: hasAttachments ? "runtime_rebind_available" : "none",
  };
}

function optionArray(value: unknown): ChatClarificationOptionV2[] {
  if (!Array.isArray(value)) return [];
  const ids = new Set<string>();
  return value.flatMap((item) => {
    if (!isRecord(item)) return [];
    const option = standardOption(String(item.id));
    if (option === null || ids.has(option.id)) return [];
    ids.add(option.id);
    return [option];
  }).slice(0, 3);
}

export function standardOption(
  id: string,
): ChatClarificationOptionV2 | null {
  switch (id) {
    case "answer":
      return {
        id,
        label_zh: "回答问题",
        label_en: "Answer the question",
        resulting_output: "text",
        resulting_workflow: "app_logic_answer",
      };
    case "food_draft":
      return {
        id,
        label_zh: "生成食物草稿",
        label_en: "Create a food draft",
        resulting_output: "food_draft",
        resulting_workflow: "food_logging",
      };
    case "workout_draft":
      return {
        id,
        label_zh: "生成训练草稿",
        label_en: "Create a workout draft",
        resulting_output: "workout_draft",
        resulting_workflow: "workout_logging",
      };
    default:
      return null;
  }
}

function outputArray(
  value: unknown,
): Array<Exclude<ExpectedOutput, "auto">> | null {
  const allowed = new Set(["text", "food_draft", "workout_draft"]);
  if (
    !Array.isArray(value) || value.length === 0 || value.length > 3 ||
    value.some((item) => !allowed.has(String(item)))
  ) return null;
  return [...new Set(value as Array<Exclude<ExpectedOutput, "auto">>)];
}

function contextArray(value: unknown): PlannedContextType[] | null {
  const allowed = new Set<PlannedContextType>([
    "document_context",
    "profile_context",
    "selected_day_summary",
    "recent_food_summary",
    "recent_workout_summary",
    "body_metric_summary",
    "weight_trend_summary",
    "strategy_context",
    "exercise_definition",
    "exercise_history",
  ]);
  if (
    !Array.isArray(value) || value.length > 10 ||
    value.some((item) => !allowed.has(item))
  ) return null;
  return [...new Set(value as PlannedContextType[])];
}

function entityArray(value: unknown): TaskPlanV1["entities"] {
  if (!Array.isArray(value)) return [];
  const allowed = new Set(["exercise", "food", "date"]);
  return value.flatMap((item) => {
    if (
      !isRecord(item) || !allowed.has(String(item.type)) ||
      typeof item.value !== "string" || item.value.trim() === ""
    ) return [];
    return [{
      type: item.type as TaskPlanV1["entities"][number]["type"],
      value: item.value.trim().slice(0, 120),
    }];
  }).slice(0, 8);
}

function stringArray(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string")
    : [];
}

function finiteConfidence(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value)
    ? Math.min(Math.max(value, 0), 1)
    : 0;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
