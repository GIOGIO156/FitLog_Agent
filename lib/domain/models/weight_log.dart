import '../../core/utils/number_utils.dart';

class WeightLog {
  const WeightLog({
    this.id,
    required this.date,
    required this.weightKg,
    required this.source,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String date;
  final double weightKg;
  final String source;
  final String? createdAt;
  final String? updatedAt;

  WeightLog copyWith({
    int? id,
    String? date,
    double? weightKg,
    String? source,
    String? createdAt,
    String? updatedAt,
  }) {
    return WeightLog(
      id: id ?? this.id,
      date: date ?? this.date,
      weightKg: weightKg ?? this.weightKg,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'date': date,
      'weight_kg': weightKg,
      'source': source,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory WeightLog.fromMap(Map<String, dynamic> map) {
    return WeightLog(
      id: NumberUtils.toNullableInt(map['id']),
      date: (map['date'] ?? '').toString(),
      weightKg: NumberUtils.toDouble(map['weight_kg']),
      source: (map['source'] ?? '').toString(),
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }
}
