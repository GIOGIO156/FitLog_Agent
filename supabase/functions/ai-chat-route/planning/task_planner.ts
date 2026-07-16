import type { GatewayRequest } from "../contracts.ts";
import { routeGatewayWorkflow } from "../workflow_router.ts";
import { applyContextPolicy } from "./context_policy.ts";
import { parseModelTaskPlan, type PlannedWorkflow, type TaskPlanV1 } from "./task_plan_contract.ts";

export type ModelTaskPlanner = (input: Record<string, unknown>) => Promise<unknown>;

export async function buildApprovedTaskPlan(request: GatewayRequest, modelPlanner?: ModelTaskPlanner): Promise<TaskPlanV1> {
  const deterministic = deterministicPlan(request);
  let plan = deterministic;
  if (plan === null) {
    if (modelPlanner === undefined) plan = clarificationFallback(request, "planner_unavailable");
    else {
      try {
        const parsed = parseModelTaskPlan(await modelPlanner(plannerInput(request)), request.workflowType);
        plan = parsed ?? clarificationFallback(request, "planner_output_invalid");
      } catch {
        plan = clarificationFallback(request, "planner_failure");
      }
    }
  }
  return applyContextPolicy(plan, request);
}

export function planToLegacyRoute(plan: TaskPlanV1) {
  return {
    workflow: plan.planned_workflow,
    confidence: plan.confidence,
    reasons: plan.reasons,
    required_context: plan.approved_context.filter((context) => context !== "exercise_definition" && context !== "exercise_history"),
    safety_flags: plan.safety_flags,
    read_only: ["meal_decision", "weekly_review", "app_logic_answer", "general_chat", "safety_boundary"].includes(plan.planned_workflow),
  } as const;
}

function deterministicPlan(request: GatewayRequest): TaskPlanV1 | null {
  const route = routeGatewayWorkflow(request);
  if (route.safety_flags.length > 0) return plan(request, "safety_boundary", "text", ["document_context"], ["deterministic_safety_block"], route.safety_flags, 0.99);
  if (request.workflowType === "food_logging") return plan(request, "food_logging", "food_draft", [], ["fixed_food_entry"], [], 1, "fixed_entry");
  if (request.workflowType === "workout_logging") {
    return plan(
      request,
      "workout_logging",
      "workout_draft",
      ["exercise_definition"],
      ["fixed_workout_entry"],
      [],
      1,
      "fixed_entry",
    );
  }
  if (request.workflowType !== "auto") {
    return plan(request, request.workflowType, "text", route.required_context as TaskPlanV1["requested_context"], ["fixed_workflow_hint"], [], 0.96, "fixed_entry");
  }

  const text = request.messageText.trim();
  const explicitWorkoutLog = hasExplicitWorkoutLogIntent(text);
  if (explicitWorkoutLog && isQuestionLike(text)) return clarificationPlan(request, "workout_write_and_question_intents");
  if (explicitWorkoutLog) return plan(request, "workout_logging", "workout_draft", ["exercise_definition"], ["explicit_workout_draft_intent"], [], 0.96);
  if (route.workflow === "app_logic_answer") {
    const exercise = /保加利亚|分腿蹲|split squat|reps per side|每侧次数/i.test(text);
    return plan(request, "app_logic_answer", "text", exercise ? ["document_context", "exercise_definition"] : ["document_context"], ["fitlog_rule_question"], [], 0.9);
  }
  if (isWorkoutRuleQuestion(text)) return plan(request, "app_logic_answer", "text", ["document_context", "exercise_definition"], ["workout_rule_question"], [], 0.9);
  if (isSameChatWorkoutContinuation(request)) return plan(request, "workout_logging", "workout_draft", ["exercise_definition"], ["same_chat_workout_artifact"], [], 0.9);
  if (isImplicitWorkoutLog(text)) return plan(request, "workout_logging", "workout_draft", ["exercise_definition"], ["implicit_workout_draft_intent"], [], 0.9);
  if (isImplicitFoodLog(text)) return plan(request, "food_logging", "food_draft", [], ["implicit_food_log"], [], 0.9);
  if (route.workflow === "weekly_review") return plan(request, "weekly_review", "text", route.required_context as TaskPlanV1["requested_context"], route.reasons, [], route.confidence ?? 0.8);
  if (route.workflow === "meal_decision") return plan(request, "meal_decision", "text", route.required_context as TaskPlanV1["requested_context"], route.reasons, [], route.confidence ?? 0.8);
  if (request.attachments.length > 0) return clarificationFallback(request, "image_intent_ambiguous");
  if (/^(你好|hello|hi|谢谢|thanks)[!！。.\s]*$/i.test(text)) return plan(request, "general_chat", "text", [], ["ordinary_chat"], [], 0.95);
  return null;
}

function plan(request: GatewayRequest, workflow: PlannedWorkflow, expectedOutput: TaskPlanV1["expected_output"], contexts: TaskPlanV1["requested_context"], reasons: string[], safetyFlags: string[], confidence: number, source: TaskPlanV1["source"] = "deterministic"): TaskPlanV1 {
  return { schema_version: "task_plan.v1", source, confidence, original_workflow_hint: request.workflowType, planned_workflow: workflow, expected_output: expectedOutput, entities: extractEntities(request), requested_context: contexts, retrieval_needs: contexts, approved_context: [], rejected_context: [], reasons, safety_flags: safetyFlags, requires_clarification: false };
}

function clarificationFallback(request: GatewayRequest, reason: string): TaskPlanV1 {
  return { ...plan(request, "general_chat", "text", [], [reason], [], 0, "failure_fallback"), requires_clarification: true };
}

function clarificationPlan(request: GatewayRequest, reason: string): TaskPlanV1 {
  return { ...plan(request, "general_chat", "text", [], [reason], [], 0.99), requires_clarification: true };
}

function hasExplicitWorkoutLogIntent(text: string): boolean {
  return /(?:请|帮我|给我)?(?:记录|添加|保存|记下|生成|创建|log|record|save|add).{0,24}(?:训练|深蹲|分腿蹲|卧推|硬拉|组|reps?|sets?|workout)|(?:请|帮我|给我)?把.{0,24}(?:训练|深蹲|分腿蹲|卧推|硬拉).{0,12}(?:记录|保存)(?:下来|一下)/i.test(text);
}

function isImplicitWorkoutLog(text: string): boolean {
  return /(?:训练|深蹲|分腿蹲|卧推|硬拉|workout|bench press|squat|deadlift).{0,36}(?:\d+\s*组|\d+\s*(?:次|reps?)|\d+(?:\.\d+)?\s*kg)/i.test(text) && !isQuestionLike(text);
}

function isWorkoutRuleQuestion(text: string): boolean {
  return /(?:训练|深蹲|分腿蹲|卧推|硬拉|组|次数|重量|容量|workout|exercise|reps?|sets?|volume)/i.test(text) && isQuestionLike(text);
}

function isQuestionLike(text: string): boolean {
  return /(?:怎么|怎样|为什么|为何|是否|是不是|相当于|能不能|可不可以|如何|怎么填|怎么算|吗|呢|[?？]|\bhow\b|\bwhy\b|\bwhether\b|\bcan\s+i\b|\bshould\s+i\b|\bdoes?\b|\bis\s+it\b)/i.test(text);
}

function isImplicitFoodLog(text: string): boolean {
  return /(?:鸡胸|米饭|牛肉|鸡蛋|牛奶|chicken|rice|beef|egg).{0,18}\d+(?:\.\d+)?\s*(?:g|克|ml|毫升)/i.test(text) && !/(?:还能吃|可以吃|能不能|can i|should i)/i.test(text);
}

function isSameChatWorkoutContinuation(request: GatewayRequest): boolean {
  if (!/(?:它|这个|再加|加一组|改成|换成|去掉|删除|add another set|one more set|change it|remove)/i.test(request.messageText)) return false;
  return request.conversationContext?.artifacts.at(-1)?.type === "workout_draft";
}

function plannerInput(request: GatewayRequest) {
  return { message: request.messageText, language: request.language, image_count: request.attachments.length, workflow_hint: request.workflowType, same_chat: request.conversationContext };
}

function extractEntities(request: GatewayRequest): TaskPlanV1["entities"] {
  const entities: TaskPlanV1["entities"] = [];
  const exercise = request.messageText.match(/保加利亚分腿蹲|Bulgarian(?: Split)? Squat|卧推|bench press|深蹲|squat|硬拉|deadlift/i)?.[0];
  if (exercise !== undefined) entities.push({ type: "exercise", value: exercise });
  const food = request.messageText.match(/鸡胸|米饭|牛肉|鸡蛋|牛奶|chicken|rice|beef|egg/i)?.[0];
  if (food !== undefined) entities.push({ type: "food", value: food });
  const date = request.messageText.match(/\d{4}-\d{2}-\d{2}|今天|明天|昨天|today|tomorrow|yesterday/i)?.[0];
  if (date !== undefined) entities.push({ type: "date", value: date });
  return entities;
}
