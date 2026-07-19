import type { GatewayRequest } from "../contracts.ts";
import { routeGatewayWorkflow } from "../workflow_router.ts";
import { applyContextPolicy } from "./context_policy.ts";
import {
  type ChatCapability,
  type ChatClarificationSpecV2,
  ChatDecisionPlanningError,
  type ChatDecisionSource,
  type ChatDecisionV2,
  decisionToTaskPlan,
  parseModelChatDecision,
  standardOption,
} from "./chat_decision_contract.ts";
import type {
  PlannedContextType,
  PlannedWorkflow,
  TaskPlanV1,
} from "./task_plan_contract.ts";

export type ModelChatDecisionPlanner = (
  input: Record<string, unknown>,
) => Promise<unknown>;

export async function buildApprovedChatDecision(
  request: GatewayRequest,
  modelPlanner?: ModelChatDecisionPlanner,
): Promise<ChatDecisionV2> {
  let decision = deterministicDecision(request);
  if (decision === null) {
    if (modelPlanner === undefined) {
      throw new ChatDecisionPlanningError("planner_unavailable");
    }
    let raw: unknown;
    try {
      raw = await modelPlanner(plannerInput(request));
    } catch {
      throw new ChatDecisionPlanningError("planner_unavailable");
    }
    decision = parseModelChatDecision(
      raw,
      request.workflowType,
      request.attachments.length > 0,
    );
    if (decision === null) {
      throw new ChatDecisionPlanningError("planner_output_invalid");
    }
  }
  const approvedTaskPlan = applyContextPolicy(
    decisionToTaskPlan(decision),
    request,
  );
  return {
    ...decision,
    approved_context: approvedTaskPlan.approved_context,
    rejected_context: approvedTaskPlan.rejected_context,
  };
}

export function chatDecisionToTaskPlan(
  decision: ChatDecisionV2,
): TaskPlanV1 {
  return decisionToTaskPlan(decision);
}

function deterministicDecision(request: GatewayRequest): ChatDecisionV2 | null {
  const text = request.messageText.trim();
  const route = routeGatewayWorkflow(request);
  if (route.safety_flags.length > 0) {
    return decision(
      request,
      "safety_boundary",
      "safety_boundary",
      "text",
      ["document_context"],
      ["deterministic_safety_block"],
      0.99,
      "deterministic",
      route.safety_flags,
    );
  }

  const resolved = request.resolvedClarification;
  if (resolved !== null && resolved !== undefined) {
    return decision(
      request,
      capabilityForOutput(resolved.resultingOutput),
      resolved.resultingWorkflow,
      resolved.resultingOutput,
      contextsForResolvedClarification(resolved),
      ["typed_clarification_reply", resolved.optionId],
      1,
      "clarification_reply",
      [],
    );
  }

  if (request.workflowType === "food_logging") {
    return decision(
      request,
      "food_draft",
      "food_logging",
      "food_draft",
      [],
      ["fixed_food_entry"],
      1,
      "fixed_entry",
    );
  }
  if (request.workflowType === "workout_logging") {
    return decision(
      request,
      "workout_draft",
      "workout_logging",
      "workout_draft",
      ["exercise_definition"],
      ["fixed_workout_entry"],
      1,
      "fixed_entry",
    );
  }
  if (request.workflowType !== "auto") {
    return decision(
      request,
      capabilityForWorkflow(request.workflowType),
      request.workflowType,
      "text",
      route.required_context as PlannedContextType[],
      ["fixed_workflow_hint"],
      0.96,
      "fixed_entry",
    );
  }

  const explicitWorkout = hasExplicitWorkoutDraftIntent(text);
  if (explicitWorkout && isQuestionLike(text)) {
    return clarificationDecision(
      request,
      ["answer", "workout_draft"],
      "workout_write_and_question_intents",
    );
  }
  if (explicitWorkout || isImplicitWorkoutDraft(text)) {
    return decision(
      request,
      "workout_draft",
      "workout_logging",
      "workout_draft",
      ["exercise_definition"],
      [
        explicitWorkout
          ? "explicit_workout_draft_intent"
          : "implicit_workout_draft_intent",
      ],
      explicitWorkout ? 0.97 : 0.9,
      "deterministic",
    );
  }
  if (
    route.workflow === "app_logic_answer" ||
    isAppLogicPersistenceQuestion(text) ||
    isFitLogCapabilityBoundaryQuestion(text)
  ) {
    const exercise = /保加利亚|分腿蹲|split squat|reps per side|每侧次数/i
      .test(text);
    return decision(
      request,
      "answer",
      "app_logic_answer",
      "text",
      exercise
        ? ["document_context", "exercise_definition"]
        : ["document_context"],
      [
        isAppLogicPersistenceQuestion(text)
          ? "fitlog_persistence_question"
          : isFitLogCapabilityBoundaryQuestion(text)
          ? "fitlog_capability_boundary_question"
          : "fitlog_rule_question",
      ],
      0.94,
      "deterministic",
    );
  }
  if (isWorkoutRuleQuestion(text)) {
    return decision(
      request,
      "answer",
      "app_logic_answer",
      "text",
      ["document_context", "exercise_definition"],
      ["workout_rule_question"],
      0.9,
      "deterministic",
    );
  }
  if (isSameChatWorkoutContinuation(request)) {
    return decision(
      request,
      "workout_draft",
      "workout_logging",
      "workout_draft",
      ["exercise_definition"],
      ["same_chat_workout_artifact"],
      0.9,
      "deterministic",
    );
  }
  if (route.workflow === "weekly_review") {
    return decision(
      request,
      "weekly_review",
      "weekly_review",
      "text",
      route.required_context as PlannedContextType[],
      route.reasons,
      route.confidence ?? 0.8,
      "deterministic",
    );
  }
  if (route.workflow === "meal_decision") {
    return decision(
      request,
      "meal_decision",
      "meal_decision",
      "text",
      route.required_context as PlannedContextType[],
      route.reasons,
      route.confidence ?? 0.8,
      "deterministic",
    );
  }
  if (
    hasExplicitFoodDraftIntent(text) || isFoodConsumptionStatement(text) ||
    isImplicitFoodDraft(text)
  ) {
    return decision(
      request,
      "food_draft",
      "food_logging",
      "food_draft",
      [],
      [
        hasExplicitFoodDraftIntent(text)
          ? "explicit_food_draft_intent"
          : isFoodConsumptionStatement(text)
          ? "food_consumption_statement"
          : "implicit_food_draft_intent",
      ],
      0.94,
      "deterministic",
    );
  }
  if (/^(你好|hello|hi|谢谢|thanks)[!！。.　\s]*$/i.test(text)) {
    return decision(
      request,
      "general_chat",
      "general_chat",
      "text",
      [],
      ["ordinary_chat"],
      0.95,
      "deterministic",
    );
  }
  return null;
}

function contextsForResolvedClarification(
  resolved: NonNullable<GatewayRequest["resolvedClarification"]>,
): PlannedContextType[] {
  const base = contextsForWorkflow(resolved.resultingWorkflow);
  if (
    resolved.resultingOutput === "text" &&
    isWorkoutRuleQuestion(resolved.originMessageText)
  ) {
    return [
      ...new Set<PlannedContextType>([
        ...base,
        "exercise_definition",
      ]),
    ];
  }
  return base;
}

function decision(
  request: GatewayRequest,
  capability: ChatCapability,
  workflow: PlannedWorkflow,
  output: "text" | "food_draft" | "workout_draft",
  contexts: PlannedContextType[],
  reasons: string[],
  confidence: number,
  source: ChatDecisionSource,
  safetyFlags: string[] = [],
): ChatDecisionV2 {
  return {
    schema_version: "chat_decision.v2",
    source,
    confidence,
    original_workflow_hint: request.workflowType,
    capability,
    planned_workflow: workflow,
    allowed_output_families: [output],
    selected_output_family: output,
    entities: extractEntities(request.messageText),
    requested_context: contexts,
    retrieval_needs: contexts,
    approved_context: [],
    rejected_context: [],
    reasons,
    safety_flags: safetyFlags,
    requires_clarification: false,
    clarification: null,
    attachment_policy: request.attachments.length > 0
      ? "consume_current"
      : "none",
  };
}

function clarificationDecision(
  request: GatewayRequest,
  optionIds: Array<"answer" | "food_draft" | "workout_draft">,
  reason: string,
): ChatDecisionV2 {
  const options = optionIds.flatMap((id) => {
    const option = standardOption(id);
    return option === null ? [] : [option];
  });
  const clarification: ChatClarificationSpecV2 = {
    kind: "intent_selection",
    options,
    missing_dimensions: ["requested_output_family"],
    attachment_policy: request.attachments.length > 0
      ? "runtime_rebind_available"
      : "none",
  };
  return {
    ...decision(
      request,
      "general_chat",
      "general_chat",
      "text",
      [],
      [reason],
      0.99,
      "deterministic",
    ),
    allowed_output_families: options.map((item) => item.resulting_output),
    requires_clarification: true,
    clarification,
    attachment_policy: clarification.attachment_policy,
  };
}

function plannerInput(request: GatewayRequest): Record<string, unknown> {
  return {
    message: request.messageText,
    language: request.language,
    image_count: request.attachments.length,
    images: request.attachments.map((attachment) => ({
      mime_type: attachment.mimeType,
      base64_data: attachment.base64Data,
    })),
    workflow_hint: request.workflowType,
    same_chat: request.conversationContext,
    allowed_output_families: ["text", "food_draft", "workout_draft"],
  };
}

function hasExplicitFoodDraftIntent(text: string): boolean {
  return /(?:食物|饮食|餐|food|meal).{0,18}(?:草稿|draft)|(?:生成|创建|做成|整理|记录|估算|estimate|create|make|log).{0,24}(?:食物|饮食|餐|food|meal).{0,18}(?:草稿|draft|记录)?/i
    .test(text);
}

function isFoodConsumptionStatement(text: string): boolean {
  const consumed =
    /(?:我)?(?:吃了|喝了|食用了|摄入了|刚吃|刚喝)|\b(?:i\s+)?(?:ate|had|drank|consumed)\b/i
      .test(text);
  const quantity =
    /\d+(?:\.\d+)?\s*(?:碗|杯|份|个|只|片|块|勺|毫升|ml|克|g|bowls?|cups?|servings?|pieces?)/i
      .test(text);
  return consumed && (quantity || text.trim().length >= 4) &&
    !/(?:还能吃|可以吃|能不能|该不该|should i|can i|is it okay)/i.test(text);
}

function isImplicitFoodDraft(text: string): boolean {
  return /(?:鸡胸|米饭|牛肉|鸡蛋|牛奶|香蕉|燕麦|豆腐|chicken|rice|beef|egg|milk|banana|oats?|tofu).{0,48}\d+(?:\.\d+)?\s*(?:g|克|ml|毫升)/i
    .test(text) && !isQuestionLike(text);
}

function hasExplicitWorkoutDraftIntent(text: string): boolean {
  return /(?:请|帮我|给我)?(?:记录|添加|保存|记下|生成|创建|log|record|save|add).{0,24}(?:训练|深蹲|分腿蹲|卧推|硬拉|组|reps?|sets?|workout)|(?:workout|training).{0,16}(?:draft|log|record)/i
    .test(text);
}

function isImplicitWorkoutDraft(text: string): boolean {
  return /(?:训练|深蹲|分腿蹲|卧推|硬拉|workout|bench press|squat|deadlift).{0,36}(?:\d+\s*组|\d+\s*(?:次|reps?)|\d+(?:\.\d+)?\s*kg)/i
    .test(text) && !isQuestionLike(text);
}

function isWorkoutRuleQuestion(text: string): boolean {
  return /(?:训练|深蹲|分腿蹲|卧推|硬拉|组|次数|重量|容量|workout|exercise|reps?|sets?|volume)/i
    .test(text) && isQuestionLike(text);
}

function isAppLogicPersistenceQuestion(text: string): boolean {
  return /(?:数据库|database|哪张表|哪个表|which table|保存在哪里|存在哪里|持久化到哪里|where.{0,28}(?:stored|persisted|saved)|how.{0,20}(?:stored|persisted)|workout.{0,20}snapshot)/i
    .test(text) && isQuestionLike(text);
}

function isFitLogCapabilityBoundaryQuestion(text: string): boolean {
  if (!isQuestionLike(text)) return false;
  const fitLogSubject =
    /(?:\bai\b|\bagent\b|fitlog|模型|系统|document\s*rag|structured\s*rag|文档\s*rag|结构化\s*rag|embedding|向量)/i
      .test(text);
  const boundaryTopic =
    /(?:修改|更改|删除|写入|保存|应用|执行|确认|权限|隐私|目标|策略|记录|用户数据|embedding|embed|vector|向量|write|modify|change|delete|apply|confirm|permission|privacy|goals?|strateg(?:y|ies)|user\s+(?:data|records?))/i
      .test(text);
  return fitLogSubject && boundaryTopic;
}

function isQuestionLike(text: string): boolean {
  return /(?:怎么|怎样|为什么|为何|是否|是不是|相当于|能不能|可不可以|如何|哪里|哪张|哪个|吗|呢|[?？]|\bhow\b|\bwhy\b|\bwhere\b|\bwhich\b|\bwhether\b|\bcan\b|\bshould\b|\bdoes?\b|\bis\s+it\b)/i
    .test(text);
}

function isSameChatWorkoutContinuation(request: GatewayRequest): boolean {
  if (
    !/(?:它|这个|再加|加一组|改成|换成|去掉|删除|add another set|one more set|change it|remove)/i
      .test(request.messageText)
  ) {
    return false;
  }
  return request.conversationContext?.artifacts.at(-1)?.type ===
    "workout_draft";
}

function extractEntities(text: string): TaskPlanV1["entities"] {
  const entities: TaskPlanV1["entities"] = [];
  const exercise = text.match(
    /保加利亚分腿蹲|Bulgarian(?: Split)? Squat|卧推|bench press|深蹲|squat|硬拉|deadlift/i,
  )?.[0];
  if (exercise !== undefined) {
    entities.push({ type: "exercise", value: exercise });
  }
  const date = text.match(
    /\d{4}-\d{2}-\d{2}|今天|明天|昨天|today|tomorrow|yesterday/i,
  )?.[0];
  if (date !== undefined) entities.push({ type: "date", value: date });
  return entities;
}

function capabilityForOutput(
  output: "text" | "food_draft" | "workout_draft",
): ChatCapability {
  return output === "food_draft"
    ? "food_draft"
    : output === "workout_draft"
    ? "workout_draft"
    : "answer";
}

function capabilityForWorkflow(workflow: PlannedWorkflow): ChatCapability {
  switch (workflow) {
    case "food_logging":
      return "food_draft";
    case "workout_logging":
      return "workout_draft";
    case "meal_decision":
      return "meal_decision";
    case "weekly_review":
      return "weekly_review";
    case "safety_boundary":
      return "safety_boundary";
    case "app_logic_answer":
      return "answer";
    default:
      return "general_chat";
  }
}

function contextsForWorkflow(workflow: PlannedWorkflow): PlannedContextType[] {
  switch (workflow) {
    case "app_logic_answer":
      return ["document_context"];
    case "workout_logging":
      return ["exercise_definition"];
    case "meal_decision":
      return ["profile_context", "selected_day_summary", "strategy_context"];
    case "weekly_review":
      return [
        "profile_context",
        "recent_food_summary",
        "recent_workout_summary",
        "body_metric_summary",
        "weight_trend_summary",
        "strategy_context",
      ];
    default:
      return [];
  }
}
