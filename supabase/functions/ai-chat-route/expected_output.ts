import type { ExpectedOutput, GatewayRequest } from "./contracts.ts";

const foodDraftIntent =
  /(?:记录|生成|创建|整理|做成|转成|添加|设置).{0,24}(?:饮食|食物|餐|摄入|早餐|午餐|晚餐|加餐|吃|喝|牛奶|米饭|鸡胸|鸡腿|牛肉|猪肉|鱼|虾|鸡蛋|面|蛋白质|kcal)|(?:饮食|食物|餐|早餐|午餐|晚餐|加餐).{0,24}(?:草稿|记录)|(?:food|meal|breakfast|lunch|dinner|snack|milk|rice|chicken|beef|pork|fish|egg).{0,18}(?:draft|record|log|add)|(?:draft|record|log|add).{0,24}(?:food|meal|breakfast|lunch|dinner|snack|milk|rice|chicken|beef|pork|fish|egg)/i;
const workoutDraftIntent =
  /(?:记录|生成|创建|整理|做成|转成|添加|设置).{0,24}(?:训练|运动|锻炼|深蹲|卧推|硬拉|跑步|划船|引体|组|次数|公斤|分钟)|(?:训练|运动|锻炼|深蹲|卧推|硬拉|跑步|划船|引体).{0,24}(?:草稿|记录)|(?:草稿|记录).{0,24}(?:训练|运动|锻炼|深蹲|卧推|硬拉|跑步|划船|引体)|(?:workout|exercise|training|squat|bench press|deadlift|run|row|pull-up).{0,18}(?:draft|record|log|add)|(?:draft|record|log|add).{0,24}(?:workout|exercise|training|squat|bench press|deadlift|run|sets?|reps?|kg|minutes?)/i;
const clarificationReply =
  /^(?:不知道|不清楚|没有|就这些|是的|对|嗯|ok|okay|yes|no|not sure|that's all)[。.!！?？\s]*$/i;

export type IntentResolutionSource =
  | "fixed_workflow"
  | "deterministic"
  | "model";

export interface OutputSelection {
  expectedOutput: ExpectedOutput;
  source: IntentResolutionSource;
  reason: string;
}

export function resolveOutputSelection(request: GatewayRequest): OutputSelection {
  if (request.workflowType === "food_logging") {
    return {
      expectedOutput: "food_draft",
      source: "fixed_workflow",
      reason: "dedicated_food_logging_workflow",
    };
  }
  if ((request.phase5Context?.route.safety_flags.length ?? 0) > 0) {
    return {
      expectedOutput: "text",
      source: "deterministic",
      reason: "safety_boundary",
    };
  }

  const message = request.messageText.trim();
  if (workoutDraftIntent.test(message)) {
    return {
      expectedOutput: "workout_draft",
      source: "deterministic",
      reason: "explicit_workout_draft_intent",
    };
  }
  if (foodDraftIntent.test(message)) {
    return {
      expectedOutput: "food_draft",
      source: "deterministic",
      reason: "explicit_food_draft_intent",
    };
  }
  if (request.phase5Context?.route.read_only === true) {
    return {
      expectedOutput: "text",
      source: "deterministic",
      reason: "read_only_answer_workflow",
    };
  }

  const context = request.conversationContext;
  if (context !== null && clarificationReply.test(message)) {
    const latestArtifact = [...context.artifacts].reverse()[0];
    if (latestArtifact?.type === "workout_draft") {
      return {
        expectedOutput: "workout_draft",
        source: "deterministic",
        reason: "workout_clarification_context",
      };
    }
    if (latestArtifact?.type === "food_draft") {
      return {
        expectedOutput: "food_draft",
        source: "deterministic",
        reason: "food_clarification_context",
      };
    }

    const recentText = context.messages.slice(-2).map((item) => item.text).join(
      "\n",
    );
    if (/训练|运动|workout|exercise/i.test(recentText)) {
      return {
        expectedOutput: "workout_draft",
        source: "deterministic",
        reason: "workout_clarification_context",
      };
    }
    if (/饮食|食物|餐|food|meal/i.test(recentText)) {
      return {
        expectedOutput: "food_draft",
        source: "deterministic",
        reason: "food_clarification_context",
      };
    }
  }
  return {
    expectedOutput: "auto",
    source: "model",
    reason: "deterministic_resolver_abstained",
  };
}
