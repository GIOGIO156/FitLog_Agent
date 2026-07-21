import 'dart:async';
import 'dart:convert';

import 'package:fitlog_local/core/constants/exercise_catalog.dart';
import 'package:fitlog_local/core/constants/fitlog_icon_assets.dart';
import 'package:fitlog_local/core/localization/app_language.dart';
import 'package:fitlog_local/core/localization/app_strings.dart';
import 'package:fitlog_local/domain/models/workout_record_draft.dart';
import 'package:fitlog_local/features/workout/workout_draft_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = AppStrings(AppLanguage.english);
  final zh = AppStrings(AppLanguage.chinese);

  test('shows the first strength exercise first incomplete set', () {
    final content = WorkoutDraftNotificationBuilder.fromDraft(
      _draft(<Map<String, Object?>>[
        _exercise(
          name: 'Bench Press',
          bodyPart: 'Chest',
          sets: <Map<String, Object?>>[
            _set(weight: '40', reps: '8'),
            _set(weight: '60', reps: '8'),
          ],
        ),
      ]),
      zh,
    );

    expect(content?.title, '卧推');
    expect(content?.body, '第 1 组，共 2 组 - 40 kg x 8 次');
    expect(content?.setNumber, 1);
    expect(content?.totalSets, 2);
  });

  test('after completing set 1, focus stays on the same exercise set 2', () {
    final content = WorkoutDraftNotificationBuilder.fromDraft(
      _draft(<Map<String, Object?>>[
        _exercise(
          name: 'Bench Press',
          sets: <Map<String, Object?>>[
            _set(
              weight: '40',
              reps: '8',
              completed: true,
              completedAt: '2026-07-03T08:00:00.000',
            ),
            _set(weight: '60', reps: '8'),
          ],
        ),
      ]),
      zh,
    );

    expect(content?.title, '卧推');
    expect(content?.body, '第 2 组，共 2 组 - 60 kg x 8 次');
  });

  test('multi-exercise focus follows the latest completed set exercise', () {
    final content = WorkoutDraftNotificationBuilder.fromDraft(
      _draft(<Map<String, Object?>>[
        _exercise(
          name: 'Bench Press',
          sets: <Map<String, Object?>>[
            _set(
              weight: '40',
              reps: '8',
              completed: true,
              completedAt: '2026-07-03T08:00:00.000',
            ),
            _set(weight: '60', reps: '8'),
          ],
        ),
        _exercise(
          name: 'Squat',
          bodyPart: 'Legs',
          sets: <Map<String, Object?>>[
            _set(
              weight: '80',
              reps: '5',
              completed: true,
              completedAt: '2026-07-03T08:05:00.000',
            ),
            _set(weight: '90', reps: '5'),
          ],
        ),
      ]),
      en,
    );

    expect(content?.title, 'Squat');
    expect(content?.body, 'Set 2 of 2 - 90 kg x 5 reps');
  });

  test(
    'when the latest completed exercise is done, returns to first incomplete exercise',
    () {
      final content = WorkoutDraftNotificationBuilder.fromDraft(
        _draft(<Map<String, Object?>>[
          _exercise(
            name: 'Bench Press',
            sets: <Map<String, Object?>>[
              _set(
                weight: '40',
                reps: '8',
                completed: true,
                completedAt: '2026-07-03T08:00:00.000',
              ),
              _set(weight: '60', reps: '8'),
            ],
          ),
          _exercise(
            name: 'Squat',
            bodyPart: 'Legs',
            sets: <Map<String, Object?>>[
              _set(
                weight: '80',
                reps: '5',
                completed: true,
                completedAt: '2026-07-03T08:05:00.000',
              ),
            ],
          ),
        ]),
        en,
      );

      expect(content?.title, 'Bench Press');
      expect(content?.body, 'Set 2 of 2 - 60 kg x 8 reps');
    },
  );

  test(
    'unchecking the latest completed set recalculates from remaining completion',
    () {
      final before = WorkoutDraftNotificationBuilder.fromDraft(
        _draft(<Map<String, Object?>>[
          _exercise(
            name: 'Bench Press',
            sets: <Map<String, Object?>>[
              _set(
                weight: '40',
                reps: '8',
                completed: true,
                completedAt: '2026-07-03T08:00:00.000',
              ),
              _set(weight: '60', reps: '8'),
            ],
          ),
          _exercise(
            name: 'Squat',
            bodyPart: 'Legs',
            sets: <Map<String, Object?>>[
              _set(
                weight: '80',
                reps: '5',
                completed: true,
                completedAt: '2026-07-03T08:05:00.000',
              ),
              _set(weight: '90', reps: '5'),
            ],
          ),
        ]),
        en,
      );
      final after = WorkoutDraftNotificationBuilder.fromDraft(
        _draft(<Map<String, Object?>>[
          _exercise(
            name: 'Bench Press',
            sets: <Map<String, Object?>>[
              _set(
                weight: '40',
                reps: '8',
                completed: true,
                completedAt: '2026-07-03T08:00:00.000',
              ),
              _set(weight: '60', reps: '8'),
            ],
          ),
          _exercise(
            name: 'Squat',
            bodyPart: 'Legs',
            sets: <Map<String, Object?>>[
              _set(weight: '80', reps: '5'),
              _set(weight: '90', reps: '5'),
            ],
          ),
        ]),
        en,
      );

      expect(before?.title, 'Squat');
      expect(after?.title, 'Bench Press');
      expect(after?.body, 'Set 2 of 2 - 60 kg x 8 reps');
    },
  );

  test('editing weight and reps updates the notification body', () {
    final before = WorkoutDraftNotificationBuilder.fromDraft(
      _draft(<Map<String, Object?>>[
        _exercise(
          name: 'Bench Press',
          sets: <Map<String, Object?>>[_set(weight: '60', reps: '8')],
        ),
      ]),
      en,
    );
    final after = WorkoutDraftNotificationBuilder.fromDraft(
      _draft(<Map<String, Object?>>[
        _exercise(
          name: 'Bench Press',
          sets: <Map<String, Object?>>[_set(weight: '62.5', reps: '10')],
        ),
      ]),
      en,
    );

    expect(before?.body, 'Set 1 of 1 - 60 kg x 8 reps');
    expect(after?.body, 'Set 1 of 1 - 62.5 kg x 10 reps');
  });

  test(
    'deleting the current exercise shifts focus to the next reasonable exercise',
    () {
      final content = WorkoutDraftNotificationBuilder.fromDraft(
        _draft(<Map<String, Object?>>[
          _exercise(
            name: 'Bench Press',
            sets: <Map<String, Object?>>[
              _set(
                weight: '40',
                reps: '8',
                completed: true,
                completedAt: '2026-07-03T08:00:00.000',
              ),
              _set(weight: '60', reps: '8'),
            ],
          ),
        ]),
        en,
      );

      expect(content?.title, 'Bench Press');
      expect(content?.body, 'Set 2 of 2 - 60 kg x 8 reps');
    },
  );

  test('all strength sets complete enters complete state', () {
    final content = WorkoutDraftNotificationBuilder.fromDraft(
      _draft(<Map<String, Object?>>[
        _exercise(
          name: 'Bench Press',
          sets: <Map<String, Object?>>[
            _set(
              weight: '40',
              reps: '8',
              completed: true,
              completedAt: '2026-07-03T08:00:00.000',
            ),
          ],
        ),
      ]),
      en,
    );

    expect(content?.isComplete, isTrue);
    expect(content?.title, 'Sets complete');
    expect(content?.body, 'Return to save workout');
  });

  test(
    'selected exercise without sets still starts a continue notification',
    () {
      final content = WorkoutDraftNotificationBuilder.fromDraft(
        _draft(<Map<String, Object?>>[
          _exercise(name: 'Bench Press', sets: const <Map<String, Object?>>[]),
        ]),
        en,
      );

      expect(content?.isComplete, isFalse);
      expect(content?.title, 'Bench Press');
      expect(content?.body, 'Return to continue workout');
    },
  );

  test('barbell flat bench press uses the bench press png asset', () {
    final content = WorkoutDraftNotificationBuilder.fromDraft(
      _draft(<Map<String, Object?>>[
        _exercise(
          key: 'barbell_flat_bench_press',
          name: 'Barbell Flat Bench Press',
          bodyPart: 'Chest',
          sets: <Map<String, Object?>>[_set(weight: '20', reps: '10')],
        ),
      ]),
      zh,
    );

    expect(content?.title, '杠铃平板卧推');
    expect(content?.imageAsset, FitLogIconAssets.exerciseBenchPress);
  });

  test('chest press variants without dedicated png use chest image', () {
    const variants = <(String, String)>[
      ('barbell_incline_bench_press', 'Barbell Incline Bench Press'),
      ('machine_chest_press', 'Machine Chest Press'),
      ('machine_pec_fly', 'Machine Pec Fly'),
      ('incline_dumbbell_press', 'Incline Dumbbell Press'),
      ('dumbbell_flat_bench_press', 'Dumbbell Flat Bench Press'),
    ];

    for (final (key, name) in variants) {
      final content = WorkoutDraftNotificationBuilder.fromDraft(
        _draft(<Map<String, Object?>>[
          _exercise(
            key: key,
            name: name,
            bodyPart: 'Chest',
            sets: <Map<String, Object?>>[_set(weight: '20', reps: '10')],
          ),
        ]),
        zh,
      );

      expect(content?.imageAsset, FitLogIconAssets.workoutChest);
    }
  });

  test('exercise library omits the duplicate generic bench press entry', () {
    expect(ExerciseCatalog.byName('Bench Press'), isNull);
    expect(ExerciseCatalog.byKey('bench_press'), isNull);
    expect(ExerciseCatalog.byName('Barbell Flat Bench Press'), isNotNull);
  });

  test(
    'saving a workout cancels notification after the draft is removed',
    () async {
      final platform = _FakeWorkoutDraftNotificationPlatform();

      await WorkoutDraftNotificationSync.syncFromDraft(
        null,
        en,
        platform: platform,
      );

      expect(platform.cancelCount, 1);
      expect(platform.showCount, 0);
    },
  );

  test('pending commit cancels the editable workout notification', () async {
    final platform = _FakeWorkoutDraftNotificationPlatform();
    final draft =
        _draft(<Map<String, Object?>>[
          _exercise(
            name: 'Bench Press',
            sets: <Map<String, Object?>>[_set(weight: '80', reps: '8')],
          ),
        ]).copyWith(
          saveState: WorkoutRecordDraft.saveStateCommitUnknown,
          saveMutationId: 'mutation-1',
        );

    await WorkoutDraftNotificationSync.syncFromDraft(
      draft,
      en,
      platform: platform,
    );

    expect(platform.cancelCount, 1);
    expect(platform.showCount, 0);
  });

  test('cardio-only draft still starts a continue notification', () async {
    final platform = _FakeWorkoutDraftNotificationPlatform();

    await WorkoutDraftNotificationSync.syncFromDraft(
      _draft(<Map<String, Object?>>[
        _exercise(
          name: 'Running',
          bodyPart: 'Cardio',
          exerciseType: 'cardio',
          sets: const <Map<String, Object?>>[],
        ),
      ]),
      en,
      platform: platform,
    );

    expect(platform.cancelCount, 0);
    expect(platform.showCount, 1);
    expect(platform.lastContent?.title, 'Running');
    expect(platform.lastContent?.body, 'Return to continue workout');
  });

  test('deleting all exercises cancels notification', () async {
    final platform = _FakeWorkoutDraftNotificationPlatform();

    await WorkoutDraftNotificationSync.syncFromDraft(
      _draft(const <Map<String, Object?>>[]),
      en,
      platform: platform,
    );

    expect(platform.cancelCount, 1);
    expect(platform.showCount, 0);
  });

  test(
    'notification tap cancels the notification and skips duplicate editor push',
    () async {
      final coordinator = WorkoutDraftNotificationTapCoordinator();
      final draft = _draft(<Map<String, Object?>>[
        _exercise(
          name: 'Bench Press',
          sets: <Map<String, Object?>>[_set(weight: '60', reps: '8')],
        ),
      ]);
      var openCount = 0;
      var cancelCount = 0;

      await coordinator.handleTap(
        loadActiveDraft: () async => draft,
        openDraft: (openedDraft) async {
          openCount++;
          expect(openedDraft.id, WorkoutRecordDraft.activeDraftId);
        },
        cancelNotification: () async => cancelCount++,
      );
      coordinator.markEditorOpen();
      await coordinator.handleTap(
        loadActiveDraft: () async => draft,
        openDraft: (_) async => openCount++,
        cancelNotification: () async => cancelCount++,
      );

      expect(openCount, 1);
      expect(cancelCount, 2);
    },
  );

  test('concurrent notification taps open only one editor', () async {
    final coordinator = WorkoutDraftNotificationTapCoordinator();
    final draft = _draft(<Map<String, Object?>>[
      _exercise(
        name: 'Bench Press',
        sets: <Map<String, Object?>>[_set(weight: '60', reps: '8')],
      ),
    ]);
    final loadStarted = Completer<void>();
    final releaseLoad = Completer<void>();
    var openCount = 0;
    var cancelCount = 0;

    Future<void> handleTap() => coordinator.handleTap(
      loadActiveDraft: () async {
        if (!loadStarted.isCompleted) {
          loadStarted.complete();
        }
        await releaseLoad.future;
        return draft;
      },
      openDraft: (_) async => openCount++,
      cancelNotification: () async => cancelCount++,
    );

    final firstTap = handleTap();
    await loadStarted.future;
    final secondTap = handleTap();
    releaseLoad.complete();
    await Future.wait(<Future<void>>[firstTap, secondTap]);

    expect(openCount, 1);
    expect(cancelCount, 2);
  });

  test('stale notification cannot open a pending commit draft', () async {
    final coordinator = WorkoutDraftNotificationTapCoordinator();
    final draft =
        _draft(<Map<String, Object?>>[
          _exercise(
            name: 'Bench Press',
            sets: <Map<String, Object?>>[_set(weight: '60', reps: '8')],
          ),
        ]).copyWith(
          saveState: WorkoutRecordDraft.saveStateCommitUnknown,
          saveMutationId: 'mutation-1',
        );
    var openCount = 0;
    var cancelCount = 0;

    await coordinator.handleTap(
      loadActiveDraft: () async => draft,
      openDraft: (_) async => openCount++,
      cancelNotification: () async => cancelCount++,
    );

    expect(openCount, 0);
    expect(cancelCount, 1);
  });

  test('notification scheduler coalesces 320 rapid field updates', () async {
    final platform = _FakeWorkoutDraftNotificationPlatform();
    final scheduler = WorkoutDraftNotificationScheduler(
      strings: en,
      platform: platform,
      delay: const Duration(milliseconds: 10),
    );
    addTearDown(scheduler.dispose);
    for (var index = 0; index < 320; index++) {
      scheduler.schedule(
        _draft(<Map<String, Object?>>[
          _exercise(
            name: 'Bench Press',
            sets: <Map<String, Object?>>[
              _set(weight: '$index', reps: '${index + 1}'),
            ],
          ),
        ]),
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(platform.showCount, 1);
    expect(platform.lastContent?.body, 'Set 1 of 1 - 319 kg x 320 reps');
  });

  test(
    'notification cancellation cannot be followed by a stale update',
    () async {
      final platform = _FakeWorkoutDraftNotificationPlatform();
      final scheduler = WorkoutDraftNotificationScheduler(
        strings: en,
        platform: platform,
        delay: const Duration(milliseconds: 10),
      );
      addTearDown(scheduler.dispose);

      scheduler.schedule(
        _draft(<Map<String, Object?>>[
          _exercise(
            name: 'Bench Press',
            sets: <Map<String, Object?>>[_set(weight: '60', reps: '8')],
          ),
        ]),
      );
      await scheduler.cancelNow();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(platform.showCount, 0);
      expect(platform.cancelCount, 1);
    },
  );
}

WorkoutRecordDraft _draft(List<Map<String, Object?>> exercises) {
  return WorkoutRecordDraft(
    id: WorkoutRecordDraft.activeDraftId,
    kind: WorkoutRecordDraft.kindNewRecord,
    date: '2026-07-03',
    recordName: '',
    notes: '',
    payloadJson: jsonEncode(<String, Object?>{'exercises': exercises}),
    createdAt: '2026-07-03T07:00:00.000',
    updatedAt: '2026-07-03T07:00:00.000',
  );
}

Map<String, Object?> _exercise({
  String? key,
  required String name,
  String bodyPart = 'Chest',
  String exerciseType = 'strength',
  required List<Map<String, Object?>> sets,
}) {
  return <String, Object?>{
    'exercise_key': key ?? name.toLowerCase().replaceAll(' ', '_'),
    'exercise_name': name,
    'body_part': bodyPart,
    'exercise_type': exerciseType,
    'set_metric_type': 'reps',
    'sets': sets,
  };
}

Map<String, Object?> _set({
  required String weight,
  required String reps,
  bool completed = false,
  String? completedAt,
}) {
  return <String, Object?>{
    'weight_text': weight,
    'reps_text': reps,
    'is_completed': completed,
    'completed_at': completedAt,
  };
}

class _FakeWorkoutDraftNotificationPlatform
    implements WorkoutDraftNotificationPlatform {
  int showCount = 0;
  int cancelCount = 0;
  WorkoutDraftNotificationContent? lastContent;

  @override
  Future<void> show(WorkoutDraftNotificationContent content) async {
    showCount++;
    lastContent = content;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }
}
