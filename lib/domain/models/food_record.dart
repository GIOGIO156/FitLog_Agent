import '../../core/utils/number_utils.dart';
import 'food_item.dart';

class FoodRecord {
  const FoodRecord({
    this.id,
    required this.date,
    required this.mealName,
    required this.totalWeightG,
    required this.caloriesKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.confidence,
    required this.estimationNotes,
    required this.source,
    this.createdAt,
    this.updatedAt,
    this.items = const <FoodItem>[],
  });

  final int? id;
  final String date;
  final String mealName;
  final double totalWeightG;
  final double caloriesKcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double? confidence;
  final String estimationNotes;
  final String source;
  final String? createdAt;
  final String? updatedAt;
  final List<FoodItem> items;

  FoodRecord copyWith({
    int? id,
    String? date,
    String? mealName,
    double? totalWeightG,
    double? caloriesKcal,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? confidence,
    bool clearConfidence = false,
    String? estimationNotes,
    String? source,
    String? createdAt,
    String? updatedAt,
    List<FoodItem>? items,
  }) {
    return FoodRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      mealName: mealName ?? this.mealName,
      totalWeightG: totalWeightG ?? this.totalWeightG,
      caloriesKcal: caloriesKcal ?? this.caloriesKcal,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      confidence: clearConfidence ? null : (confidence ?? this.confidence),
      estimationNotes: estimationNotes ?? this.estimationNotes,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'date': date,
      'meal_name': mealName,
      'total_weight_g': totalWeightG,
      'calories_kcal': caloriesKcal,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'confidence': confidence,
      'estimation_notes': estimationNotes,
      'source': source,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory FoodRecord.fromMap(
    Map<String, dynamic> map, {
    List<FoodItem> items = const <FoodItem>[],
  }) {
    return FoodRecord(
      id: NumberUtils.toNullableInt(map['id']),
      date: (map['date'] ?? '').toString(),
      mealName: (map['meal_name'] ?? '').toString(),
      totalWeightG: NumberUtils.toDouble(map['total_weight_g']),
      caloriesKcal: NumberUtils.toDouble(map['calories_kcal']),
      proteinG: NumberUtils.toDouble(map['protein_g']),
      carbsG: NumberUtils.toDouble(map['carbs_g']),
      fatG: NumberUtils.toDouble(map['fat_g']),
      confidence: map['confidence'] == null
          ? null
          : NumberUtils.toDouble(map['confidence']),
      estimationNotes: (map['estimation_notes'] ?? '').toString(),
      source: (map['source'] ?? '').toString(),
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
      items: items,
    );
  }
}
