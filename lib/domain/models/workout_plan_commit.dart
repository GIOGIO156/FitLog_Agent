import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'workout_session.dart';

enum WorkoutPlanCommitOperation {
  create('create'),
  replacePlan('replace_plan'),
  replaceSession('replace_session');

  const WorkoutPlanCommitOperation(this.wireValue);

  final String wireValue;
}

class WorkoutPlanCommitRequest {
  const WorkoutPlanCommitRequest({
    required this.mutationId,
    required this.operation,
    required this.targetPlanId,
    this.sourcePlanId,
    this.sourceSessionId,
    required this.sessions,
  });

  final String mutationId;
  final WorkoutPlanCommitOperation operation;
  final String targetPlanId;
  final String? sourcePlanId;
  final int? sourceSessionId;
  final List<WorkoutSession> sessions;

  Map<String, dynamic> get canonicalPayload => <String, dynamic>{
    'operation': operation.wireValue,
    'target_plan_id': targetPlanId,
    'source_plan_id': sourcePlanId,
    'source_session_id': sourceSessionId,
    'sessions': sessions.map(_sessionPayload).toList(),
  };

  String get payloadHash =>
      sha256.convert(utf8.encode(jsonEncode(canonicalPayload))).toString();

  static Map<String, dynamic> _sessionPayload(WorkoutSession session) {
    return <String, dynamic>{
      'record_name': session.recordName,
      'date': session.date,
      'body_part': session.bodyPart,
      'secondary_body_part': session.secondaryBodyPart,
      'exercise_name': session.exerciseName,
      'exercise_key': session.exerciseKey,
      'exercise_source': session.exerciseSource,
      'exercise_type': session.exerciseType,
      'duration_minutes': session.durationMinutes,
      'intensity': session.intensity,
      'strength_profile': session.strengthProfile,
      'load_input_mode': session.loadInputMode,
      'reps_input_mode': session.repsInputMode,
      'set_metric_type': session.setMetricType,
      'cardio_met': session.cardioMet,
      'cardio_intensity_basis': session.cardioIntensityBasis,
      'cardio_active_minutes': session.cardioActiveMinutes,
      'body_weight_kg_at_calculation': session.bodyWeightKgAtCalculation,
      'exercise_snapshot_json': session.exerciseSnapshotJson,
      'estimated_calories': session.estimatedCalories,
      'notes': session.notes,
      'workout_sets': session.sets
          .map(
            (set) => <String, dynamic>{
              'set_number': set.setNumber,
              'weight_kg': set.weightKg,
              'reps': set.reps,
              'input_weight_kg': set.inputWeightKg,
              'input_reps': set.inputReps,
              'input_duration_seconds': set.inputDurationSeconds,
              'calculation_load_kg': set.calculationLoadKg,
              'calculation_reps': set.calculationReps,
              'load_input_mode': set.loadInputMode,
              'reps_input_mode': set.repsInputMode,
              'set_metric_type': set.setMetricType,
              'is_completed': set.isCompleted,
              'completed_at': set.completedAt,
            },
          )
          .toList(),
    };
  }
}

class WorkoutPlanCommitResult {
  const WorkoutPlanCommitResult._({
    required this.status,
    required this.targetPlanId,
    required this.sessions,
  });

  factory WorkoutPlanCommitResult.committed({
    required String targetPlanId,
    List<WorkoutSession> sessions = const <WorkoutSession>[],
  }) {
    return WorkoutPlanCommitResult._(
      status: WorkoutPlanCommitStatus.committed,
      targetPlanId: targetPlanId,
      sessions: sessions,
    );
  }

  factory WorkoutPlanCommitResult.notFound() {
    return const WorkoutPlanCommitResult._(
      status: WorkoutPlanCommitStatus.notFound,
      targetPlanId: null,
      sessions: <WorkoutSession>[],
    );
  }

  factory WorkoutPlanCommitResult.abandoned() {
    return const WorkoutPlanCommitResult._(
      status: WorkoutPlanCommitStatus.abandoned,
      targetPlanId: null,
      sessions: <WorkoutSession>[],
    );
  }

  final WorkoutPlanCommitStatus status;
  final String? targetPlanId;
  final List<WorkoutSession> sessions;

  bool get committed => status == WorkoutPlanCommitStatus.committed;
  bool get abandoned => status == WorkoutPlanCommitStatus.abandoned;
}

enum WorkoutPlanCommitStatus { committed, notFound, abandoned }
