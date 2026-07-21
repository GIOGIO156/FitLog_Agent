import 'package:fitlog_local/domain/models/workout_plan_commit.dart';
import 'package:fitlog_local/domain/models/workout_session.dart';
import 'package:fitlog_local/domain/models/workout_set.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payload hash is stable across retries with the same save snapshot', () {
    final first = _request();
    final retry = _request();

    expect(retry.payloadHash, first.payloadHash);
    expect(first.payloadHash, hasLength(64));
  });

  test('payload hash changes when official workout content changes', () {
    final first = _request();
    final changed = WorkoutPlanCommitRequest(
      mutationId: first.mutationId,
      operation: first.operation,
      targetPlanId: first.targetPlanId,
      sessions: <WorkoutSession>[
        first.sessions.single.copyWith(recordName: 'Changed'),
      ],
    );

    expect(changed.payloadHash, isNot(first.payloadHash));
  });

  test('abandoned recovery is distinct from committed and missing', () {
    final abandoned = WorkoutPlanCommitResult.abandoned();

    expect(abandoned.abandoned, isTrue);
    expect(abandoned.committed, isFalse);
    expect(abandoned.status, WorkoutPlanCommitStatus.abandoned);
  });
}

WorkoutPlanCommitRequest _request() {
  return const WorkoutPlanCommitRequest(
    mutationId: 'mutation-1',
    operation: WorkoutPlanCommitOperation.create,
    targetPlanId: 'plan-1',
    sessions: <WorkoutSession>[
      WorkoutSession(
        planId: 'plan-1',
        recordName: 'Workout',
        date: '2026-07-22',
        bodyPart: 'Chest',
        exerciseName: 'Bench Press',
        exerciseType: 'strength',
        durationMinutes: 45,
        intensity: 'medium',
        estimatedCalories: 120,
        notes: '',
        sets: <WorkoutSet>[
          WorkoutSet(
            setNumber: 1,
            weightKg: 80,
            reps: 8,
            isCompleted: true,
            completedAt: '2026-07-22T10:00:00.000Z',
          ),
        ],
      ),
    ],
  );
}
