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

  const sources = context.document_sources.map((source) => ({
    doc_path: source.doc_path,
    heading: source.heading,
    heading_path: source.heading_path,
    section_id: source.section_id,
    chunk_index: source.chunk_index,
    chunk_count: source.chunk_count,
    status: source.status,
    context_prefix: source.context_prefix,
    context_note: source.context_note,
    excerpt: source.excerpt,
  }));

  return [
    "FitLog Phase 5 controlled context follows. Treat it as read-only evidence.",
    answerLanguageInstruction(request.language),
    `Routed workflow: ${context.route.workflow}`,
    `Routing reasons: ${context.route.reasons.join(", ") || "none"}`,
    "Allowed actions: explain, summarize, suggest user-confirmed UI steps, ask a clarification.",
    "Forbidden actions: save official records, delete records, modify Profile, change goals, apply carb tapering, change carb cycling, request full raw history, expose debug traces.",
    "If status is planned or non_goal, say that clearly and do not present it as implemented.",
    "Document source context_prefix and heading_path define the chunk location and meaning; use them before interpreting the excerpt.",
    "User record summaries are included only when the user enabled record-summary context; if missing because permission is off, say so instead of guessing.",
    "For meal_decision, inspect selected_day_summary.data.diet_calculation_mode before answering. If it is gram_per_kg, lead with macro gram gaps as the decision basis and treat kcal remaining only as an auxiliary monitoring value; do not frame kcal remaining as the gating limit. If it is energy_ratio, lead with kcal remaining as the decision basis and use macros only as secondary structure.",
    "For app_logic_answer, ground FitLog rule or algorithm explanations in Document sources when available. If document_context is missing for app_logic_answer, say no matching FitLog documentation was found instead of inventing a source.",
    "If a required context dimension is missing, say what is missing instead of inventing it.",
    `Context objects JSON:\n${JSON.stringify(context.context_objects, null, 2)}`,
    sources.length === 0
      ? "Document sources JSON: []"
      : `Document sources JSON:\n${JSON.stringify(sources, null, 2)}`,
    `Missing dimensions: ${context.missing_dimensions.join(", ") || "none"}`,
    `Safety flags: ${context.safety_flags.join(", ") || "none"}`,
  ].join("\n");
}
