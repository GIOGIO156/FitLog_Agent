import '../../core/utils/number_utils.dart';

class WeightLog {
  const WeightLog({
    this.id,
    this.accountId,
    required this.date,
    required this.weightKg,
    this.bodyFatPercent,
    this.waistCm,
    required this.source,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String? accountId;
  final String date;
  final double weightKg;
  final double? bodyFatPercent;
  final double? waistCm;
  final String source;
  final String? createdAt;
  final String? updatedAt;

  WeightLog copyWith({
    int? id,
    String? accountId,
    String? date,
    double? weightKg,
    double? bodyFatPercent,
    double? waistCm,
    String? source,
    String? createdAt,
    String? updatedAt,
  }) {
    return WeightLog(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      date: date ?? this.date,
      weightKg: weightKg ?? this.weightKg,
      bodyFatPercent: bodyFatPercent ?? this.bodyFatPercent,
      waistCm: waistCm ?? this.waistCm,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'account_id': accountId,
      'date': date,
      'weight_kg': weightKg,
      'body_fat_percent': bodyFatPercent,
      'waist_cm': waistCm,
      'source': source,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory WeightLog.fromMap(Map<String, dynamic> map) {
    return WeightLog(
      id: NumberUtils.toNullableInt(map['id']),
      accountId: map['account_id']?.toString(),
      date: (map['date'] ?? '').toString(),
      weightKg: NumberUtils.toDouble(map['weight_kg']),
      bodyFatPercent: map['body_fat_percent'] == null
          ? null
          : NumberUtils.toDouble(map['body_fat_percent']),
      waistCm: map['waist_cm'] == null
          ? null
          : NumberUtils.toDouble(map['waist_cm']),
      source: (map['source'] ?? '').toString(),
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }
}
