import 'package:fitlog_local/domain/models/workout_record_draft.dart';
import 'package:fitlog_local/features/workout/workout_editor_resume.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'recent active editor draft auto resumes after process rebuild',
    () async {
      final now = DateTime.parse('2026-07-19T12:00:00.000');
      await WorkoutEditorResumeStore.markActive();

      expect(
        await WorkoutEditorResumeStore.shouldAutoResume(
          _draft(updatedAt: now.subtract(const Duration(minutes: 29))),
          now: now,
        ),
        isTrue,
      );
    },
  );

  test('draft older than window remains manual only', () async {
    final now = DateTime.parse('2026-07-19T12:00:00.000');
    await WorkoutEditorResumeStore.markActive();

    expect(
      await WorkoutEditorResumeStore.shouldAutoResume(
        _draft(updatedAt: now.subtract(const Duration(minutes: 31))),
        now: now,
      ),
      isFalse,
    );
  });

  test(
    'explicit exit clears automatic resume without deleting draft',
    () async {
      final now = DateTime.parse('2026-07-19T12:00:00.000');
      await WorkoutEditorResumeStore.markActive();
      await WorkoutEditorResumeStore.clear();

      expect(
        await WorkoutEditorResumeStore.shouldAutoResume(
          _draft(updatedAt: now.subtract(const Duration(minutes: 1))),
          now: now,
        ),
        isFalse,
      );
    },
  );

  test('pending commit never auto resumes as an editable workout', () async {
    final now = DateTime.parse('2026-07-19T12:00:00.000');
    await WorkoutEditorResumeStore.markActive();

    expect(
      await WorkoutEditorResumeStore.shouldAutoResume(
        _draft(updatedAt: now).copyWith(
          saveState: WorkoutRecordDraft.saveStateCommitUnknown,
          saveMutationId: 'mutation-1',
        ),
        now: now,
      ),
      isFalse,
    );
  });
}

WorkoutRecordDraft _draft({required DateTime updatedAt}) {
  return WorkoutRecordDraft(
    id: WorkoutRecordDraft.activeDraftId,
    kind: WorkoutRecordDraft.kindNewRecord,
    date: '2026-07-19',
    recordName: '',
    notes: '',
    payloadJson: '{"exercises":[]}',
    createdAt: '2026-07-19T10:00:00.000',
    updatedAt: updatedAt.toIso8601String(),
  );
}
