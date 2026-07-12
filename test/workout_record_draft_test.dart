import 'package:flutter_test/flutter_test.dart';

import 'package:fitlog_local/data/db/app_database.dart';
import 'package:fitlog_local/data/repositories/workout_draft_repository.dart';
import 'package:fitlog_local/domain/models/workout_record_draft.dart';

void main() {
  test('legacy edit draft is not an active new-record draft', () {
    const draft = WorkoutRecordDraft(
      id: WorkoutRecordDraft.activeDraftId,
      kind: WorkoutRecordDraft.kindEditRecord,
      sourcePlanId: 'plan-1',
      sourceSessionId: 12,
      date: '2026-06-11',
      recordName: '',
      notes: '',
      payloadJson:
          '{"exercises":[{"exercise_name":"Bench Press"},{"exercise_name":"Pull Up"}]}',
      createdAt: '2026-06-11T10:00:00.000',
      updatedAt: '2026-06-11T10:05:00.000',
    );

    expect(draft.isNewRecordDraft, isFalse);
    expect(draft.exerciseCount, 2);
    expect(draft.firstExerciseName, 'Bench Press');
  });

  test('round-trips repository map fields', () {
    final draft = WorkoutRecordDraft.fromMap(<String, dynamic>{
      'id': WorkoutRecordDraft.activeDraftId,
      'kind': WorkoutRecordDraft.kindNewRecord,
      'source_plan_id': null,
      'source_session_id': null,
      'date': '2026-06-11',
      'record_name': 'Leg Day',
      'notes': 'Keep rests short',
      'payload_json': '{"exercises":[]}',
      'created_at': '2026-06-11T08:00:00.000',
      'updated_at': '2026-06-11T08:03:00.000',
    });

    expect(draft.toMap()['record_name'], 'Leg Day');
    expect(draft.toMap()['payload_json'], '{"exercises":[]}');
    expect(draft.isNewRecordDraft, isTrue);
    expect(draft.exerciseCount, 0);
  });

  test('repository rejects legacy edit-record drafts', () async {
    const draft = WorkoutRecordDraft(
      id: WorkoutRecordDraft.activeDraftId,
      kind: WorkoutRecordDraft.kindEditRecord,
      sourcePlanId: 'plan-1',
      sourceSessionId: 12,
      date: '2026-06-11',
      recordName: 'Edited record',
      notes: '',
      payloadJson: '{"exercises":[]}',
      createdAt: '2026-06-11T10:00:00.000',
      updatedAt: '2026-06-11T10:05:00.000',
    );
    final repository = WorkoutDraftRepository(AppDatabase.instance);

    await expectLater(repository.saveActiveDraft(draft), throwsArgumentError);
  });
}
