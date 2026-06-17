import '../localization/app_language.dart';

class PromptTemplates {
  PromptTemplates._();

  static const String chineseGptName = 'FitLog 食物营养估算助手';
  static const String englishGptName = 'FitLog Food Estimator';

  static const String aiFoodPromptZh = '''请根据这张食物图片，估算这份食物的总重量、总热量、蛋白质、碳水和脂肪。

请注意：
- 这是通过图片进行的估算，不需要完全精确，但要给出合理数值。
- 如果图片中有多个食物，请分别估算每个食物项目。
- 如果无法确定具体食材，请根据外观给出最可能的名称和估算。
- 请只输出严格 JSON，不要 Markdown，不要解释文字，不要使用代码块。

格式如下：

{
  "meal_name": "string",
  "total_weight_g": number,
  "total_calories_kcal": number,
  "protein_g": number,
  "carbs_g": number,
  "fat_g": number,
  "confidence": number,
  "items": [
    {
      "name": "string",
      "estimated_weight_g": number,
      "calories_kcal": number,
      "protein_g": number,
      "carbs_g": number,
      "fat_g": number,
      "notes": "string"
    }
  ],
  "estimation_notes": "string"
}

注意：
1. 所有数字都用 number，不要写单位。
2. 如果不确定，也要给出一个合理估算值。
3. confidence 范围是 0 到 1。
4. 只输出 JSON。''';

  static const String aiFoodPromptEn =
      '''Based on this food photo, estimate the meal's total weight, total calories, protein, carbs, and fat.

Please note:
- This is an image-based estimate and does not need to be perfectly accurate, but values should be reasonable.
- If there are multiple foods, estimate each item separately.
- If exact ingredients are unclear, provide the most likely names and estimates from appearance.
- Output strict JSON only. No Markdown, no explanations, no code block.

Use this format:

{
  "meal_name": "string",
  "total_weight_g": number,
  "total_calories_kcal": number,
  "protein_g": number,
  "carbs_g": number,
  "fat_g": number,
  "confidence": number,
  "items": [
    {
      "name": "string",
      "estimated_weight_g": number,
      "calories_kcal": number,
      "protein_g": number,
      "carbs_g": number,
      "fat_g": number,
      "notes": "string"
    }
  ],
  "estimation_notes": "string"
}

Notes:
1. Use number for all numeric fields and do not include units.
2. If uncertain, still provide a reasonable estimate.
3. confidence must be between 0 and 1.
4. Output JSON only.''';

  static String promptForLanguage(AppLanguage language) {
    if (language == AppLanguage.chinese) {
      return aiFoodPromptZh;
    }
    return aiFoodPromptEn;
  }
}
