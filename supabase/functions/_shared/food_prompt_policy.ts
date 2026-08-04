export type FoodPromptLanguage = "zh" | "en";

export function foodDraftEvidencePolicy(
  language: FoodPromptLanguage,
): string {
  return language === "zh"
    ? [
      "文字和图片是并列、互补的证据，不是互相否定的完整清单。",
      "用户文字通常只补充、修正或说明餐食的一部分；除非用户明确表示只有、只记录、不要或不包含某些食物，不要因为文字未提到就忽略图片中其他合理可识别的食物。",
      "用户明确给出且作用对象清楚的食物名称、份量、重量、包装营养或食用量，只在对应食物和对应字段上优先于视觉观察和通用估算；不要把局部事实误套到整餐，也不要把大概、可能、像是等不确定表述当成确定事实。",
      "文字未覆盖的食物和字段继续根据全部图片合理识别和估算；图片未显示某个用户明确食物不能单独成为删除理由，图片中额外识别到的食物可以加入草稿。",
      "文字与图片冲突时，不要虚构确定结论、删除用户意图或把同一对象重复成两个条目；保留用户明确意图，在 confidence 和 estimation_notes 中说明冲突或不确定性，等待用户确认。",
    ].join(" ")
    : [
      "Text and images are parallel, complementary evidence rather than mutually exclusive complete inventories.",
      "User text usually supplements, corrects, or describes only part of the meal; unless the user explicitly says only, log only, exclude, or without, do not ignore other reasonably identifiable foods merely because the text did not mention them.",
      "A clear user statement with an unambiguous scope about a food name, portion, weight, package nutrition, or consumed amount takes priority over visual observation and generic estimation only for that food and field; do not apply an item-specific fact to the whole meal, and treat words such as approximately, maybe, or looks like as uncertain clues rather than confirmed facts.",
      "Continue using all images to identify and estimate foods and fields not covered by the text; visual absence alone must not delete a user-explicit food, and additional foods reasonably identified in the images may be added to the draft.",
      "When text and images conflict, do not invent certainty, discard the user's intent, or duplicate one physical item as two entries; preserve the clear intent, explain the conflict or uncertainty in confidence and estimation_notes, and leave the draft for user confirmation.",
    ].join(" ");
}
