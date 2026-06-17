import 'dart:convert';

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/number_utils.dart';
import '../models/food_item.dart';
import '../models/food_record.dart';

class NutritionCalculator {
  NutritionCalculator._();

  static FoodRecord parseAiFoodJson(String rawJson) {
    late final Map<String, dynamic> decoded;
    try {
      final dynamic data = jsonDecode(rawJson);
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Top-level JSON must be an object.');
      }
      decoded = data;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid JSON format.');
    }

    final dynamic rawItems = _readAny(decoded, <String>['items', '食物项', '项目']);
    if (rawItems != null && rawItems is! List) {
      throw const FormatException('items must be an array.');
    }

    final List<FoodItem>
    items = (rawItems as List<dynamic>? ?? <dynamic>[]).map((dynamic item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Each item must be an object.');
      }
      return FoodItem(
        name: (_readAny(item, <String>['name', '名称']) ?? '').toString().trim(),
        estimatedWeightG: _requiredNumber(item, <String>[
          'estimated_weight_g',
          '估算重量_g',
          '估算重量',
        ]),
        caloriesKcal: _requiredNumber(item, <String>[
          'calories_kcal',
          '热量_kcal',
          '热量',
        ]),
        proteinG: _requiredNumber(item, <String>['protein_g', '蛋白质_g', '蛋白质']),
        carbsG: _requiredNumber(item, <String>['carbs_g', '碳水_g', '碳水']),
        fatG: _requiredNumber(item, <String>['fat_g', '脂肪_g', '脂肪']),
        notes: (_readAny(item, <String>['notes', '备注']) ?? '').toString(),
      );
    }).toList();

    return FoodRecord(
      date: DateUtilsX.todayKey(),
      mealName: (_readAny(decoded, <String>['meal_name', '餐食名称', '餐名']) ?? '')
          .toString()
          .trim(),
      totalWeightG: _requiredNumber(decoded, <String>[
        'total_weight_g',
        '总重量_g',
        '总重量',
      ]),
      caloriesKcal: _requiredNumber(decoded, <String>[
        'total_calories_kcal',
        '总热量_kcal',
        '总热量',
      ]),
      proteinG: _requiredNumber(decoded, <String>['protein_g', '蛋白质_g', '蛋白质']),
      carbsG: _requiredNumber(decoded, <String>['carbs_g', '碳水_g', '碳水']),
      fatG: _requiredNumber(decoded, <String>['fat_g', '脂肪_g', '脂肪']),
      confidence: _readAny(decoded, <String>['confidence', '置信度']) == null
          ? null
          : NumberUtils.toDouble(
              _readAny(decoded, <String>['confidence', '置信度']),
            ),
      estimationNotes:
          (_readAny(decoded, <String>['estimation_notes', '估算备注', '估算说明']) ??
                  '')
              .toString(),
      source: AppConstants.sourceAiPaste,
      items: items,
    );
  }

  static double sumProtein(List<FoodRecord> records) {
    return records.fold<double>(0, (sum, item) => sum + item.proteinG);
  }

  static double sumCarbs(List<FoodRecord> records) {
    return records.fold<double>(0, (sum, item) => sum + item.carbsG);
  }

  static double sumFat(List<FoodRecord> records) {
    return records.fold<double>(0, (sum, item) => sum + item.fatG);
  }

  static double sumCalories(List<FoodRecord> records) {
    return records.fold<double>(0, (sum, item) => sum + item.caloriesKcal);
  }

  static dynamic _readAny(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      if (source.containsKey(key)) {
        return source[key];
      }
    }
    return null;
  }

  static double _requiredNumber(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    final value = _readAny(source, keys);
    if (value == null) {
      throw FormatException('Missing required field: ${keys.first}');
    }

    final double parsed = NumberUtils.toDouble(value, fallback: double.nan);
    if (parsed.isNaN) {
      throw FormatException('Field "${keys.first}" must be a number.');
    }
    return parsed;
  }
}
