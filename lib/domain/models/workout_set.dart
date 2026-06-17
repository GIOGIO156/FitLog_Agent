import '../../core/utils/number_utils.dart';

class WorkoutSet {
  const WorkoutSet({
    this.id,
    this.workoutSessionId,
    required this.setNumber,
    required this.weightKg,
    required this.reps,
    this.inputWeightKg,
    this.inputReps,
    this.inputDurationSeconds,
    this.calculationLoadKg,
    this.calculationReps,
    this.loadInputMode,
    this.repsInputMode,
    this.setMetricType,
    required this.isCompleted,
    this.completedAt,
  });

  final int? id;
  final int? workoutSessionId;
  final int setNumber;
  final double weightKg;
  final int reps;
  final double? inputWeightKg;
  final int? inputReps;
  final int? inputDurationSeconds;
  final double? calculationLoadKg;
  final int? calculationReps;
  final String? loadInputMode;
  final String? repsInputMode;
  final String? setMetricType;
  final bool isCompleted;
  final String? completedAt;

  double get displayWeightKg => inputWeightKg ?? weightKg;
  int get displayReps => inputReps ?? reps;
  double get effectiveCalculationLoadKg => calculationLoadKg ?? weightKg;
  int get effectiveCalculationReps => calculationReps ?? reps;

  WorkoutSet copyWith({
    int? id,
    int? workoutSessionId,
    int? setNumber,
    double? weightKg,
    int? reps,
    double? inputWeightKg,
    int? inputReps,
    int? inputDurationSeconds,
    double? calculationLoadKg,
    int? calculationReps,
    String? loadInputMode,
    String? repsInputMode,
    String? setMetricType,
    bool? isCompleted,
    String? completedAt,
    bool clearCompletedAt = false,
  }) {
    return WorkoutSet(
      id: id ?? this.id,
      workoutSessionId: workoutSessionId ?? this.workoutSessionId,
      setNumber: setNumber ?? this.setNumber,
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
      inputWeightKg: inputWeightKg ?? this.inputWeightKg,
      inputReps: inputReps ?? this.inputReps,
      inputDurationSeconds: inputDurationSeconds ?? this.inputDurationSeconds,
      calculationLoadKg: calculationLoadKg ?? this.calculationLoadKg,
      calculationReps: calculationReps ?? this.calculationReps,
      loadInputMode: loadInputMode ?? this.loadInputMode,
      repsInputMode: repsInputMode ?? this.repsInputMode,
      setMetricType: setMetricType ?? this.setMetricType,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'workout_session_id': workoutSessionId,
      'set_number': setNumber,
      'weight_kg': weightKg,
      'reps': reps,
      'input_weight_kg': inputWeightKg,
      'input_reps': inputReps,
      'input_duration_seconds': inputDurationSeconds,
      'calculation_load_kg': calculationLoadKg,
      'calculation_reps': calculationReps,
      'load_input_mode': loadInputMode,
      'reps_input_mode': repsInputMode,
      'set_metric_type': setMetricType,
      'is_completed': isCompleted ? 1 : 0,
      'completed_at': completedAt,
    };
  }

  factory WorkoutSet.fromMap(Map<String, dynamic> map) {
    return WorkoutSet(
      id: NumberUtils.toNullableInt(map['id']),
      workoutSessionId: NumberUtils.toNullableInt(map['workout_session_id']),
      setNumber: NumberUtils.toInt(map['set_number']),
      weightKg: NumberUtils.toDouble(map['weight_kg']),
      reps: NumberUtils.toInt(map['reps']),
      inputWeightKg: map['input_weight_kg'] == null
          ? null
          : NumberUtils.toDouble(map['input_weight_kg']),
      inputReps: map['input_reps'] == null
          ? null
          : NumberUtils.toInt(map['input_reps']),
      inputDurationSeconds: map['input_duration_seconds'] == null
          ? null
          : NumberUtils.toInt(map['input_duration_seconds']),
      calculationLoadKg: map['calculation_load_kg'] == null
          ? null
          : NumberUtils.toDouble(map['calculation_load_kg']),
      calculationReps: map['calculation_reps'] == null
          ? null
          : NumberUtils.toInt(map['calculation_reps']),
      loadInputMode: map['load_input_mode']?.toString(),
      repsInputMode: map['reps_input_mode']?.toString(),
      setMetricType: map['set_metric_type']?.toString(),
      isCompleted: NumberUtils.toInt(map['is_completed']) == 1,
      completedAt: map['completed_at']?.toString(),
    );
  }
}
