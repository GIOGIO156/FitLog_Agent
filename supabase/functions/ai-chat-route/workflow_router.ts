import type { GatewayRequest, WorkflowType } from "./contracts.ts";
import type { Phase5WorkflowRoute } from "./phase5_types.ts";

export function routeGatewayWorkflow(
  request: GatewayRequest,
): Phase5WorkflowRoute {
  const text = request.messageText.trim();
  const lower = text.toLowerCase();
  const safetyFlags = safetyFlagsForText(lower);

  if (safetyFlags.length > 0) {
    return {
      workflow: "app_logic_answer",
      confidence: 0.98,
      reasons: ["unsupported_write_or_privacy_request"],
      required_context: ["document_context"],
      safety_flags: safetyFlags,
      read_only: true,
    };
  }

  const hinted = routeFromHint(request.workflowType);
  if (hinted !== null) {
    return hinted;
  }

  if (isWeeklyReview(lower)) {
    return {
      workflow: "weekly_review",
      confidence: 0.84,
      reasons: ["weekly_review_terms"],
      required_context: [
        "profile_context",
        "recent_food_summary",
        "recent_workout_summary",
        "body_metric_summary",
        "weight_trend_summary",
        "strategy_context",
      ],
      safety_flags: [],
      read_only: true,
    };
  }

  if (isAppLogicQuestion(lower)) {
    return {
      workflow: "app_logic_answer",
      confidence: 0.82,
      reasons: ["fitlog_rule_terms"],
      required_context: ["document_context"],
      safety_flags: [],
      read_only: true,
    };
  }

  if (isMealDecision(lower, request.attachments.length)) {
    return {
      workflow: "meal_decision",
      confidence: 0.78,
      reasons: request.attachments.length > 0
        ? ["meal_decision_terms", "current_request_images"]
        : ["meal_decision_terms"],
      required_context: [
        "profile_context",
        "selected_day_summary",
        "strategy_context",
      ],
      safety_flags: [],
      read_only: true,
    };
  }

  return {
    workflow: "auto",
    confidence: null,
    reasons: ["fallback_chat"],
    required_context: [],
    safety_flags: [],
    read_only: false,
  };
}

function routeFromHint(hint: WorkflowType): Phase5WorkflowRoute | null {
  switch (hint) {
    case "app_logic_answer":
      return {
        workflow: hint,
        confidence: 0.92,
        reasons: ["client_workflow_hint"],
        required_context: ["document_context"],
        safety_flags: [],
        read_only: true,
      };
    case "meal_decision":
      return {
        workflow: hint,
        confidence: 0.92,
        reasons: ["client_workflow_hint"],
        required_context: [
          "profile_context",
          "selected_day_summary",
          "strategy_context",
        ],
        safety_flags: [],
        read_only: true,
      };
    case "weekly_review":
      return {
        workflow: hint,
        confidence: 0.92,
        reasons: ["client_workflow_hint"],
        required_context: [
          "profile_context",
          "recent_food_summary",
          "recent_workout_summary",
          "body_metric_summary",
          "weight_trend_summary",
          "strategy_context",
        ],
        safety_flags: [],
        read_only: true,
      };
    case "food_logging":
    case "workout_logging":
      return {
        workflow: hint,
        confidence: 0.92,
        reasons: ["client_workflow_hint"],
        required_context: [],
        safety_flags: [],
        read_only: false,
      };
    case "general_chat":
      return {
        workflow: hint,
        confidence: 1,
        reasons: ["server_planned_workflow"],
        required_context: [],
        safety_flags: [],
        read_only: true,
      };
    case "safety_boundary":
      return {
        workflow: hint,
        confidence: 1,
        reasons: ["server_planned_workflow"],
        required_context: ["document_context"],
        safety_flags: ["safety_boundary"],
        read_only: true,
      };
    case "auto":
      return null;
  }
}

function safetyFlagsForText(lower: string): string[] {
  const flags: string[] = [];
  if (
    includesAny(lower, [
      "直接帮我改",
      "帮我修改目标",
      "修改目标",
      "改目标",
      "change my goal",
      "update my goal",
    ])
  ) {
    flags.push("profile_or_goal_write_requested");
  }
  if (
    includesAny(lower, [
      "应用 carb taper",
      "应用carb taper",
      "自动应用",
      "apply carb taper",
      "apply the taper",
    ])
  ) {
    flags.push("strategy_write_requested");
  }
  if (
    includesAny(lower, [
      "删除今天",
      "删除所有",
      "删掉所有",
      "delete all",
      "delete today's",
      "delete today",
    ])
  ) {
    flags.push("record_delete_requested");
  }
  if (
    includesAny(lower, [
      "完整原始历史",
      "完整历史",
      "raw history",
      "full history",
      "ignore system",
      "忽略系统",
      "绕过",
      "bypass",
    ])
  ) {
    flags.push("privacy_or_prompt_injection_request");
  }
  return flags;
}

function isWeeklyReview(lower: string): boolean {
  return includesAny(lower, [
    "复盘",
    "过去 7",
    "过去7",
    "过去 14",
    "过去14",
    "最近没瘦",
    "最近沒有瘦",
    "weekly review",
    "past 7",
    "past seven",
    "past 14",
    "why am i not losing",
    "why haven't i lost",
  ]);
}

function isAppLogicQuestion(lower: string): boolean {
  return includesAny(lower, [
    "fitlog",
    "gram_per_kg",
    "energy_ratio",
    "carb taper",
    "carb_taper",
    "carb cycling",
    "carb_cycling",
    "bmr",
    "tdee",
    "怎么计算",
    "怎么算",
    "为什么",
    "规则",
    "算法",
    "数据库",
    "隐私",
    "source of truth",
    "how does",
    "how is",
  ]);
}

function isMealDecision(lower: string, imageCount: number): boolean {
  if (imageCount > 0 && includesAny(lower, ["晚餐", "dinner", "meal", "can this"])) {
    return true;
  }
  return includesAny(lower, [
    "今天还能吃",
    "晚饭还能",
    "晚餐还能",
    "这个外卖",
    "能不能点",
    "能点吗",
    "怎么补",
    "还差多少",
    "what can i eat",
    "can i order",
    "can this work",
    "for dinner",
    "next meal",
    "protein gap",
  ]);
}

function includesAny(value: string, terms: string[]): boolean {
  return terms.some((term) => value.includes(term));
}
