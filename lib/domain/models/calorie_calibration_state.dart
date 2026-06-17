import '../../core/utils/number_utils.dart';

class CalorieCalibrationState {
  const CalorieCalibrationState({
    this.id = 1,
    required this.lifestyleFactor,
    required this.confidence,
    required this.windowDays,
    required this.validDays,
    this.lastCalibratedDate,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final double lifestyleFactor;
  final double confidence;
  final int windowDays;
  final int validDays;
  final String? lastCalibratedDate;
  final String? createdAt;
  final String? updatedAt;

  CalorieCalibrationState copyWith({
    int? id,
    double? lifestyleFactor,
    double? confidence,
    int? windowDays,
    int? validDays,
    String? lastCalibratedDate,
    String? createdAt,
    String? updatedAt,
  }) {
    return CalorieCalibrationState(
      id: id ?? this.id,
      lifestyleFactor: lifestyleFactor ?? this.lifestyleFactor,
      confidence: confidence ?? this.confidence,
      windowDays: windowDays ?? this.windowDays,
      validDays: validDays ?? this.validDays,
      lastCalibratedDate: lastCalibratedDate ?? this.lastCalibratedDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'lifestyle_factor': lifestyleFactor,
      'confidence': confidence,
      'window_days': windowDays,
      'valid_days': validDays,
      'last_calibrated_date': lastCalibratedDate,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory CalorieCalibrationState.fromMap(Map<String, dynamic> map) {
    return CalorieCalibrationState(
      id: NumberUtils.toInt(map['id'], fallback: 1),
      lifestyleFactor: NumberUtils.toDouble(map['lifestyle_factor']),
      confidence: NumberUtils.toDouble(map['confidence']),
      windowDays: NumberUtils.toInt(map['window_days']),
      validDays: NumberUtils.toInt(map['valid_days']),
      lastCalibratedDate: map['last_calibrated_date']?.toString(),
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }
}
