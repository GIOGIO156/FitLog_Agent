import '../../core/utils/number_utils.dart';
import 'workout_set.dart';

class WorkoutSession {
  const WorkoutSession({
    this.id,
    this.planId,
    this.recordName,
    required this.date,
    required this.bodyPart,
    this.secondaryBodyPart,
    required this.exerciseName,
    this.exerciseKey,
    this.exerciseSource,
    required this.exerciseType,
    required this.durationMinutes,
    required this.intensity,
    this.strengthProfile,
    this.loadInputMode,
    this.repsInputMode,
    this.setMetricType,
    this.cardioMet,
    this.cardioIntensityBasis,
    this.cardioActiveMinutes,
    this.bodyWeightKgAtCalculation,
    this.exerciseSnapshotJson,
    required this.estimatedCalories,
    required this.notes,
    this.createdAt,
    this.updatedAt,
    this.sets = const <WorkoutSet>[],
  });

  final int? id;
  final String? planId;
  final String? recordName;
  final String date;
  final String bodyPart;
  final String? secondaryBodyPart;
  final String exerciseName;
  final String? exerciseKey;
  final String? exerciseSource;
  final String exerciseType;
  final int durationMinutes;
  final String intensity;
  final String? strengthProfile;
  final String? loadInputMode;
  final String? repsInputMode;
  final String? setMetricType;
  final double? cardioMet;
  final String? cardioIntensityBasis;
  final int? cardioActiveMinutes;
  final double? bodyWeightKgAtCalculation;
  final String? exerciseSnapshotJson;
  final double estimatedCalories;
  final String notes;
  final String? createdAt;
  final String? updatedAt;
  final List<WorkoutSet> sets;

  WorkoutSession copyWith({
    int? id,
    String? planId,
    String? recordName,
    String? date,
    String? bodyPart,
    String? secondaryBodyPart,
    String? exerciseName,
    String? exerciseKey,
    String? exerciseSource,
    String? exerciseType,
    int? durationMinutes,
    String? intensity,
    String? strengthProfile,
    String? loadInputMode,
    String? repsInputMode,
    String? setMetricType,
    double? cardioMet,
    String? cardioIntensityBasis,
    int? cardioActiveMinutes,
    double? bodyWeightKgAtCalculation,
    String? exerciseSnapshotJson,
    double? estimatedCalories,
    String? notes,
    String? createdAt,
    String? updatedAt,
    List<WorkoutSet>? sets,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      recordName: recordName ?? this.recordName,
      date: date ?? this.date,
      bodyPart: bodyPart ?? this.bodyPart,
      secondaryBodyPart: secondaryBodyPart ?? this.secondaryBodyPart,
      exerciseName: exerciseName ?? this.exerciseName,
      exerciseKey: exerciseKey ?? this.exerciseKey,
      exerciseSource: exerciseSource ?? this.exerciseSource,
      exerciseType: exerciseType ?? this.exerciseType,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      intensity: intensity ?? this.intensity,
      strengthProfile: strengthProfile ?? this.strengthProfile,
      loadInputMode: loadInputMode ?? this.loadInputMode,
      repsInputMode: repsInputMode ?? this.repsInputMode,
      setMetricType: setMetricType ?? this.setMetricType,
      cardioMet: cardioMet ?? this.cardioMet,
      cardioIntensityBasis: cardioIntensityBasis ?? this.cardioIntensityBasis,
      cardioActiveMinutes: cardioActiveMinutes ?? this.cardioActiveMinutes,
      bodyWeightKgAtCalculation:
          bodyWeightKgAtCalculation ?? this.bodyWeightKgAtCalculation,
      exerciseSnapshotJson: exerciseSnapshotJson ?? this.exerciseSnapshotJson,
      estimatedCalories: estimatedCalories ?? this.estimatedCalories,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sets: sets ?? this.sets,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'plan_id': planId,
      'record_name': recordName,
      'date': date,
      'body_part': bodyPart,
      'secondary_body_part': secondaryBodyPart,
      'exercise_name': exerciseName,
      'exercise_key': exerciseKey,
      'exercise_source': exerciseSource,
      'exercise_type': exerciseType,
      'duration_minutes': durationMinutes,
      'intensity': intensity,
      'strength_profile': strengthProfile,
      'load_input_mode': loadInputMode,
      'reps_input_mode': repsInputMode,
      'set_metric_type': setMetricType,
      'cardio_met': cardioMet,
      'cardio_intensity_basis': cardioIntensityBasis,
      'cardio_active_minutes': cardioActiveMinutes,
      'body_weight_kg_at_calculation': bodyWeightKgAtCalculation,
      'exercise_snapshot_json': exerciseSnapshotJson,
      'estimated_calories': estimatedCalories,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory WorkoutSession.fromMap(
    Map<String, dynamic> map, {
    List<WorkoutSet> sets = const <WorkoutSet>[],
  }) {
    return WorkoutSession(
      id: NumberUtils.toNullableInt(map['id']),
      planId: map['plan_id']?.toString(),
      recordName: map['record_name']?.toString(),
      date: (map['date'] ?? '').toString(),
      bodyPart: (map['body_part'] ?? '').toString(),
      secondaryBodyPart: map['secondary_body_part']?.toString(),
      exerciseName: (map['exercise_name'] ?? '').toString(),
      exerciseKey: map['exercise_key']?.toString(),
      exerciseSource: map['exercise_source']?.toString(),
      exerciseType: (map['exercise_type'] ?? '').toString(),
      durationMinutes: NumberUtils.toInt(map['duration_minutes']),
      intensity: (map['intensity'] ?? '').toString(),
      strengthProfile: map['strength_profile']?.toString(),
      loadInputMode: map['load_input_mode']?.toString(),
      repsInputMode: map['reps_input_mode']?.toString(),
      setMetricType: map['set_metric_type']?.toString(),
      cardioMet: map['cardio_met'] == null
          ? null
          : NumberUtils.toDouble(map['cardio_met']),
      cardioIntensityBasis: map['cardio_intensity_basis']?.toString(),
      cardioActiveMinutes: map['cardio_active_minutes'] == null
          ? null
          : NumberUtils.toInt(map['cardio_active_minutes']),
      bodyWeightKgAtCalculation: map['body_weight_kg_at_calculation'] == null
          ? null
          : NumberUtils.toDouble(map['body_weight_kg_at_calculation']),
      exerciseSnapshotJson: map['exercise_snapshot_json']?.toString(),
      estimatedCalories: NumberUtils.toDouble(map['estimated_calories']),
      notes: (map['notes'] ?? '').toString(),
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
      sets: sets,
    );
  }
}
