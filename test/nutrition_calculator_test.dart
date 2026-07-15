import 'package:fitlog_local/domain/services/nutrition_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const baseJson = '''
{
  "meal_name": "Lunch",
  "total_weight_g": 100,
  "total_calories_kcal": 165,
  "protein_g": 31,
  "carbs_g": 0,
  "fat_g": 3.6,
  "confidence": 0.9,
  "items": [
    {
      "name": "Chicken breast",
      "estimated_weight_g": 100,
      "calories_kcal": 165,
      "protein_g": 31,
      "carbs_g": 0,
      "fat_g": 3.6,
      "notes": ""
    }
  ],
  %s
}
''';

  test('parses the established estimation_notes field', () {
    final record = NutritionCalculator.parseAiFoodJson(
      baseJson.replaceFirst('%s', '"estimation_notes": "Skin removed"'),
    );

    expect(record.estimationNotes, 'Skin removed');
  });

}
