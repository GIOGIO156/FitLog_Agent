export type ResponseLanguage = "zh" | "en";

export type ResponseLanguageStatus =
  | "matched"
  | "mixed"
  | "mismatched"
  | "unscorable"
  | "not_attempted";

export function userFacingLanguageInstruction(
  language: ResponseLanguage,
): string {
  return language === "zh"
    ? "目标回复语言为中文。JSON 字段名、schema/enum 固定值、标准单位、品牌名、包装原名和必要专有名词保持其要求或原文；其余所有用户可见自然语言内容使用简洁中文。普通食物已有常用中文名时，不要无必要在括号中附加英文翻译，只有保留包装或商品原名有助于消歧时才这样做。"
    : "Target response language is English. Keep JSON keys, required schema/enum values, standard units, brand names, original package names, and necessary proper nouns in their required or original form; write all other user-visible natural-language content in concise English. Do not add Chinese translations in parentheses for ordinary foods unless preserving an original package or product name helps disambiguation.";
}

export function classifyResponseLanguage(
  language: ResponseLanguage,
  values: string[],
): ResponseLanguageStatus {
  const visible = values.map((value) => value.trim()).filter(Boolean).join(
    "\n",
  );
  if (visible === "") return "unscorable";

  const cjkCharacters = visible.match(/[\u3400-\u9fff]/gu)?.length ?? 0;
  const latinWords = visible.match(/[A-Za-z]{3,}/g)?.length ?? 0;
  if (language === "zh") {
    if (cjkCharacters === 0 && latinWords >= 3) return "mismatched";
    if (cjkCharacters > 0 && latinWords >= 3) return "mixed";
    return cjkCharacters > 0 ? "matched" : "unscorable";
  }
  if (latinWords === 0 && cjkCharacters >= 4) return "mismatched";
  if (latinWords >= 3 && cjkCharacters >= 4) return "mixed";
  return latinWords >= 3 ? "matched" : "unscorable";
}
