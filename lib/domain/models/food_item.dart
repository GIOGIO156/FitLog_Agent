import '../../core/utils/number_utils.dart';

class FoodItem {
  const FoodItem({
    this.id,
    this.foodRecordId,
    required this.name,
    required this.estimatedWeightG,
    required this.caloriesKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.notes,
  });

  final int? id;
  final int? foodRecordId;
  final String name;
  final double estimatedWeightG;
  final double caloriesKcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String notes;

  FoodItem copyWith({
    int? id,
    int? foodRecordId,
    String? name,
    double? estimatedWeightG,
    double? caloriesKcal,
    double? proteinG,
    double? carbsG,
    double? fatG,
    String? notes,
  }) {
    return FoodItem(
      id: id ?? this.id,
      foodRecordId: foodRecordId ?? this.foodRecordId,
      name: name ?? this.name,
      estimatedWeightG: estimatedWeightG ?? this.estimatedWeightG,
      caloriesKcal: caloriesKcal ?? this.caloriesKcal,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'food_record_id': foodRecordId,
      'name': name,
      'estimated_weight_g': estimatedWeightG,
      'calories_kcal': caloriesKcal,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'notes': notes,
    };
  }

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: NumberUtils.toNullableInt(map['id']),
      foodRecordId: NumberUtils.toNullableInt(map['food_record_id']),
      name: (map['name'] ?? '').toString(),
      estimatedWeightG: NumberUtils.toDouble(map['estimated_weight_g']),
      caloriesKcal: NumberUtils.toDouble(map['calories_kcal']),
      proteinG: NumberUtils.toDouble(map['protein_g']),
      carbsG: NumberUtils.toDouble(map['carbs_g']),
      fatG: NumberUtils.toDouble(map['fat_g']),
      notes: (map['notes'] ?? '').toString(),
    );
  }
}
