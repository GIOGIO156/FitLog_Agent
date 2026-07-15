import type { GatewayRequest } from "./contracts.ts";

export function answerLanguageInstruction(language: "zh" | "en"): string {
  return language === "zh"
    ? "Answer language: Chinese. Answer in Chinese even if previous conversation context or retrieved documents contain English."
    : "Answer language: English. Answer in English even if previous conversation context or retrieved documents contain Chinese.";
}

export function phase5PromptContext(request: GatewayRequest): string {
  const context = request.phase5Context;
  if (context === null) {
    return "";
  }

  const contextObjects = context.context_objects.filter((object) =>
    object.type !== "document_context"
  );
  const sources = context.document_sources.map((source) => ({
    doc_path: source.doc_path,
    heading: source.heading,
    heading_path: source.heading_path,
    section_id: source.section_id,
    status: source.status,
    authority: source.authority,
    context_prefix: source.context_prefix,
    excerpt: source.excerpt,
  }));

  return [
    "FitLog controlled context follows. Treat it as read-only evidence.",
    answerLanguageInstruction(request.language),
    `Routed workflow: ${context.route.workflow}`,
    `Routing reasons: ${context.route.reasons.join(", ") || "none"}`,
    request.expectedOutput === "text"
      ? "Allowed actions for this request: explain, summarize, suggest user-confirmed UI steps, or ask a clarification. Do not create a Food or Workout draft."
      : "Allowed actions for this request: create only the editable draft selected by the output contract, or ask one clarification. Do not switch output families.",
    "Forbidden actions: save official records, delete records, modify Profile, change goals, apply carb tapering, change carb cycling, request full raw history, expose debug traces.",
    "If status is planned or non_goal, say that clearly and do not present it as implemented.",
    "Document source context_prefix and heading_path define the chunk location and meaning; use them before interpreting the excerpt.",
    "User record summaries are included only when the user enabled record-summary context; if missing because permission is off, say so instead of guessing.",
    "For meal_decision, inspect selected_day_summary.data.diet_calculation_mode before answering. If it is gram_per_kg, lead with macro gram gaps as the decision basis and treat kcal remaining only as an auxiliary monitoring value; do not frame kcal remaining as the gating limit. If it is energy_ratio, lead with kcal remaining as the decision basis and use macros only as secondary structure.",
    "For app_logic_answer, ground FitLog rule or algorithm explanations in Document sources when available. If document_context is missing for app_logic_answer, say no matching FitLog documentation was found instead of inventing a source.",
    "If a required context dimension is missing, say what is missing instead of inventing it.",
    `Context objects JSON:\n${JSON.stringify(contextObjects)}`,
    sources.length === 0
      ? "Document sources JSON: []"
      : `Document sources JSON:\n${JSON.stringify(sources)}`,
    `Missing dimensions: ${context.missing_dimensions.join(", ") || "none"}`,
    `Safety flags: ${context.safety_flags.join(", ") || "none"}`,
  ].join("\n");
}

export function prependMealDecisionImageTip(
  messageText: string,
  request: GatewayRequest,
): string {
  if (
    request.workflowType !== "meal_decision" ||
    request.attachments.length > 0
  ) {
    return messageText;
  }
  const alreadyIncluded = request.language === "zh"
    ? /上传.{0,16}(?:食材|照片|图片|外卖).{0,20}(?:截图|推荐)|外卖.{0,12}截图/i
      .test(
        messageText,
      )
    : /upload.{0,20}(?:ingredient|food|delivery).{0,24}(?:photo|screenshot)/i
      .test(messageText);
  if (alreadyIncluded) return messageText;
  const tip = request.language === "zh"
    ? "你也可以上传现有食材照片或外卖平台截图，我可以结合图片帮你做推荐。"
    : "You can also upload a photo of ingredients you have or a delivery-app screenshot, and I can use it to help with the recommendation.";
  return `${tip}\n\n${messageText}`;
}
