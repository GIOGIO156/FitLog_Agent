import 'package:fitlog_local/core/constants/exercise_definition.dart';
import 'package:fitlog_local/domain/models/workout_session.dart';
import 'package:fitlog_local/domain/models/workout_set.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workout metadata fields round-trip through model maps', () {
    const set = WorkoutSet(
      id: 7,
      workoutSessionId: 42,
      setNumber: 1,
      weightKg: 60,
      reps: 20,
      inputWeightKg: 30,
      inputReps: 10,
      calculationLoadKg: 60,
      calculationReps: 20,
      loadInputMode: ExerciseLoadInputMode.perSideLoad,
      repsInputMode: ExerciseRepsInputMode.perSide,
      setMetricType: ExerciseSetMetricType.reps,
      isCompleted: true,
      completedAt: '2026-06-11T10:00:00.000',
    );

    final mappedSet = WorkoutSet.fromMap(set.toMap());
    expect(mappedSet.inputWeightKg, 30);
    expect(mappedSet.inputReps, 10);
    expect(mappedSet.calculationLoadKg, 60);
    expect(mappedSet.calculationReps, 20);
    expect(mappedSet.loadInputMode, ExerciseLoadInputMode.perSideLoad);
    expect(mappedSet.repsInputMode, ExerciseRepsInputMode.perSide);
    expect(mappedSet.setMetricType, ExerciseSetMetricType.reps);
    expect(mappedSet.displayWeightKg, 30);
    expect(mappedSet.displayReps, 10);
    expect(mappedSet.effectiveCalculationLoadKg, 60);
    expect(mappedSet.effectiveCalculationReps, 20);

    final session = WorkoutSession(
      id: 42,
      planId: 'plan-1',
      recordName: 'Leg day',
      date: '2026-06-11',
      bodyPart: 'Legs',
      secondaryBodyPart: 'Glutes',
      exerciseName: 'Bulgarian Split Squat',
      exerciseKey: 'bulgarian_split_squat',
      exerciseSource: ExerciseSource.builtin,
      exerciseType: ExerciseType.strength,
      durationMinutes: 20,
      intensity: 'medium',
      strengthProfile: ExerciseStrengthProfile.lowerBodyCompound,
      loadInputMode: ExerciseLoadInputMode.totalLoad,
      repsInputMode: ExerciseRepsInputMode.perSide,
      setMetricType: ExerciseSetMetricType.reps,
      bodyWeightKgAtCalculation: 80,
      exerciseSnapshotJson: '{"key":"bulgarian_split_squat"}',
      estimatedCalories: 35,
      notes: 'steady',
      sets: const <WorkoutSet>[set],
    );

    final mappedSession = WorkoutSession.fromMap(session.toMap());
    expect(mappedSession.secondaryBodyPart, 'Glutes');
    expect(mappedSession.exerciseKey, 'bulgarian_split_squat');
    expect(mappedSession.exerciseSource, ExerciseSource.builtin);
    expect(
      mappedSession.strengthProfile,
      ExerciseStrengthProfile.lowerBodyCompound,
    );
    expect(mappedSession.loadInputMode, ExerciseLoadInputMode.totalLoad);
    expect(mappedSession.repsInputMode, ExerciseRepsInputMode.perSide);
    expect(mappedSession.setMetricType, ExerciseSetMetricType.reps);
    expect(mappedSession.bodyWeightKgAtCalculation, 80);
    expect(
      mappedSession.exerciseSnapshotJson,
      '{"key":"bulgarian_split_squat"}',
    );
  });
}
