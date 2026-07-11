import type { GatewayDraft } from "../_shared/ai_output_contract.ts";

export function draftConfirmationMessage(
  language: "zh" | "en",
  draft: GatewayDraft,
): string {
  if (draft.schema_version === "food_draft.v2") {
    const calories = Math.round(draft.calories_kcal);
    return language === "zh"
      ? `已生成 ${draft.date} 的饮食草稿：${draft.meal_name}，约 ${calories} kcal。请核对日期、份量和营养后保存。`
      : `Prepared a food draft for ${draft.date}: ${draft.meal_name}, about ${calories} kcal. Review the date, portions, and nutrition before saving.`;
  }
  return language === "zh"
    ? `已生成 ${draft.date} 的训练草稿：${draft.record_name}，共 ${draft.exercises.length} 个动作。请核对日期和训练内容后保存。`
    : `Prepared a workout draft for ${draft.date}: ${draft.record_name}, with ${draft.exercises.length} exercises. Review the date and workout details before saving.`;
}
