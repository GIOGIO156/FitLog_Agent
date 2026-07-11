import 'dart:async';

import 'package:fitlog_local/features/workout/workout_draft_mutation_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('final delete runs after an older delayed draft save', () async {
    final queue = WorkoutDraftMutationQueue();
    final delayedSave = Completer<void>();
    var draftExists = false;

    final save = queue.run(() async {
      await delayedSave.future;
      draftExists = true;
    });
    final delete = queue.run(() async {
      draftExists = false;
    });

    delayedSave.complete();
    await Future.wait(<Future<void>>[save, delete]);

    expect(draftExists, isFalse);
  });

  test(
    'a failed older write cannot prevent the final delete barrier',
    () async {
      final queue = WorkoutDraftMutationQueue();
      var deleted = false;

      final failed = queue.run(() async {
        throw StateError('draft write failed');
      });
      final delete = queue.run(() async {
        deleted = true;
      });

      await expectLater(failed, throwsStateError);
      await delete;
      expect(deleted, isTrue);
    },
  );
}
