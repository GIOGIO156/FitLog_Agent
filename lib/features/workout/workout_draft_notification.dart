import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../../core/constants/exercise_definition.dart';
import '../../core/constants/fitlog_icon_assets.dart';
import '../../core/localization/app_strings.dart';
import '../../core/utils/number_utils.dart';
import '../../domain/models/workout_record_draft.dart';

class WorkoutDraftNotificationContent {
  const WorkoutDraftNotificationContent({
    required this.title,
    required this.body,
    required this.imageAsset,
    required this.isComplete,
    this.exerciseName,
    this.exerciseIndex,
    this.setNumber,
    this.totalSets,
  });

  final String title;
  final String body;
  final String imageAsset;
  final bool isComplete;
  final String? exerciseName;
  final int? exerciseIndex;
  final int? setNumber;
  final int? totalSets;

  Map<String, Object?> toPlatformMap() {
    return <String, Object?>{
      'title': title,
      'body': body,
      'imageAsset': imageAsset,
      'isComplete': isComplete,
    };
  }
}

class WorkoutDraftNotificationBuilder {
  const WorkoutDraftNotificationBuilder._();

  static WorkoutDraftNotificationContent? fromDraft(
    WorkoutRecordDraft? draft,
    AppStrings strings,
  ) {
    if (draft == null) {
      return null;
    }
    final exercises = _exercisesFromDraft(draft);
    if (exercises.isEmpty) {
      return null;
    }

    final latestCompleted = _latestCompletedSet(exercises);
    _SetFocus? focus;
    if (latestCompleted == null) {
      focus = _firstIncompleteSet(exercises);
    } else {
      focus = _firstIncompleteSetInExercise(
        exercises,
        latestCompleted.exerciseIndex,
      );
      focus ??= _firstIncompleteSet(exercises);
    }

    if (focus == null) {
      final hasStrengthSets = exercises.any(
        (exercise) => !exercise.isCardio && exercise.sets.isNotEmpty,
      );
      if (!hasStrengthSets) {
        final exercise = exercises.first;
        return WorkoutDraftNotificationContent(
          title: strings.exerciseDisplayName(exercise.exerciseName),
          body: strings.workoutDraftNotificationContinueBody,
          imageAsset: exercise.imageAsset,
          isComplete: false,
          exerciseName: exercise.exerciseName,
          exerciseIndex: 0,
        );
      }
      final imageExercise = exercises.firstWhere(
        (exercise) => !exercise.isCardio,
        orElse: () => exercises.first,
      );
      return WorkoutDraftNotificationContent(
        title: strings.workoutDraftNotificationCompleteTitle,
        body: strings.workoutDraftNotificationCompleteBody,
        imageAsset: imageExercise.imageAsset,
        isComplete: true,
      );
    }

    final exercise = exercises[focus.exerciseIndex];
    final set = exercise.sets[focus.setIndex];
    final performance = _setPerformanceText(
      strings: strings,
      exercise: exercise,
      set: set,
    );
    return WorkoutDraftNotificationContent(
      title: strings.exerciseDisplayName(exercise.exerciseName),
      body: strings.workoutDraftNotificationSetBody(
        focus.setNumber,
        exercise.sets.length,
        performance,
      ),
      imageAsset: exercise.imageAsset,
      isComplete: false,
      exerciseName: exercise.exerciseName,
      exerciseIndex: focus.exerciseIndex,
      setNumber: focus.setNumber,
      totalSets: exercise.sets.length,
    );
  }

  static List<_NotificationExerciseDraft> _exercisesFromDraft(
    WorkoutRecordDraft draft,
  ) {
    final exercises = <_NotificationExerciseDraft>[];
    final payloads = draft.exercisePayloads;
    for (var i = 0; i < payloads.length; i++) {
      final payload = payloads[i];
      final isCardio = _isCardioExercise(payload);
      final rawSets = payload['sets'];
      final sets = rawSets is List
          ? rawSets
                .whereType<Map>()
                .map((entry) => _StrengthSetDraft.fromJson(entry))
                .toList()
          : <_StrengthSetDraft>[];
      final exerciseName = (payload['exercise_name'] ?? '').toString().trim();
      final exerciseKey = (payload['exercise_key'] ?? '').toString().trim();
      final bodyPart = (payload['body_part'] ?? '').toString().trim();
      exercises.add(
        _NotificationExerciseDraft(
          originalIndex: i,
          exerciseKey: exerciseKey,
          exerciseName: exerciseName.isEmpty ? 'Workout' : exerciseName,
          bodyPart: bodyPart.isEmpty ? 'Full Body' : bodyPart,
          isCardio: isCardio,
          setMetricType:
              (payload['set_metric_type'] ?? ExerciseSetMetricType.reps)
                  .toString(),
          sets: sets,
        ),
      );
    }
    return exercises;
  }

  static bool _isCardioExercise(Map<String, dynamic> payload) {
    final exerciseType = (payload['exercise_type'] ?? '').toString();
    if (exerciseType == ExerciseType.cardio) {
      return true;
    }
    if (exerciseType.isNotEmpty) {
      return false;
    }
    return (payload['body_part'] ?? '').toString() == 'Cardio';
  }

  static _CompletedSetRef? _latestCompletedSet(
    List<_NotificationExerciseDraft> exercises,
  ) {
    _CompletedSetRef? latest;
    var traversalOrder = 0;
    for (
      var exerciseIndex = 0;
      exerciseIndex < exercises.length;
      exerciseIndex++
    ) {
      final exercise = exercises[exerciseIndex];
      for (var setIndex = 0; setIndex < exercise.sets.length; setIndex++) {
        final set = exercise.sets[setIndex];
        if (!set.isCompleted) {
          traversalOrder++;
          continue;
        }
        final candidate = _CompletedSetRef(
          exerciseIndex: exerciseIndex,
          setIndex: setIndex,
          completedAt: DateTime.tryParse(set.completedAt ?? ''),
          fallbackOrder: traversalOrder,
        );
        if (latest == null || candidate.isAfter(latest)) {
          latest = candidate;
        }
        traversalOrder++;
      }
    }
    return latest;
  }

  static _SetFocus? _firstIncompleteSetInExercise(
    List<_NotificationExerciseDraft> exercises,
    int exerciseIndex,
  ) {
    if (exerciseIndex < 0 || exerciseIndex >= exercises.length) {
      return null;
    }
    final exercise = exercises[exerciseIndex];
    for (var setIndex = 0; setIndex < exercise.sets.length; setIndex++) {
      if (!exercise.sets[setIndex].isCompleted) {
        return _SetFocus(exerciseIndex: exerciseIndex, setIndex: setIndex);
      }
    }
    return null;
  }

  static _SetFocus? _firstIncompleteSet(
    List<_NotificationExerciseDraft> exercises,
  ) {
    for (
      var exerciseIndex = 0;
      exerciseIndex < exercises.length;
      exerciseIndex++
    ) {
      final focus = _firstIncompleteSetInExercise(exercises, exerciseIndex);
      if (focus != null) {
        return focus;
      }
    }
    return null;
  }

  static String _setPerformanceText({
    required AppStrings strings,
    required _NotificationExerciseDraft exercise,
    required _StrengthSetDraft set,
  }) {
    final weight = _formatDecimalText(set.weightText);
    if (exercise.setMetricType == ExerciseSetMetricType.durationSeconds) {
      return strings.workoutDraftNotificationSetDurationPerformance(
        weight,
        _formatMetricText(set.metricText),
      );
    }
    return strings.workoutDraftNotificationSetPerformance(
      weight,
      _formatRepsText(set.metricText),
    );
  }

  static String _formatDecimalText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '--';
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      return trimmed;
    }
    if (parsed == parsed.roundToDouble()) {
      return parsed.toStringAsFixed(0);
    }
    return parsed.toStringAsFixed(1);
  }

  static String _formatRepsText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '--';
    }
    final parsed = NumberUtils.toInt(trimmed, fallback: -1);
    return parsed < 0 ? trimmed : parsed.toString();
  }

  static String _formatMetricText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '--' : trimmed;
  }
}

abstract class WorkoutDraftNotificationPlatform {
  Future<void> show(WorkoutDraftNotificationContent content);

  Future<void> cancel();
}

class MethodChannelWorkoutDraftNotificationPlatform
    implements WorkoutDraftNotificationPlatform {
  MethodChannelWorkoutDraftNotificationPlatform._();

  static final MethodChannelWorkoutDraftNotificationPlatform instance =
      MethodChannelWorkoutDraftNotificationPlatform._();

  static const MethodChannel _channel = MethodChannel(
    'fitlog/workout_draft_notification',
  );

  Future<void> Function()? _tapHandler;

  void setTapHandler(Future<void> Function()? handler) {
    _tapHandler = handler;
    _channel.setMethodCallHandler(handler == null ? null : _handleMethodCall);
  }

  Future<void> consumeInitialTapIfAny() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      final consumed =
          await _channel.invokeMethod<bool>(
            'consumeInitialWorkoutDraftNotificationTap',
          ) ??
          false;
      if (consumed) {
        await _tapHandler?.call();
      }
    } on MissingPluginException {
      // Native notification support is Android-only.
    } on PlatformException {
      // A failed tap query should not block app startup.
    }
  }

  @override
  Future<void> show(WorkoutDraftNotificationContent content) async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(
        'showWorkoutDraftNotification',
        content.toPlatformMap(),
      );
    } on MissingPluginException {
      // Tests and non-Android builds do not register this channel.
    } on PlatformException {
      // Notification permission or platform display failure must not affect drafts.
    }
  }

  @override
  Future<void> cancel() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('cancelWorkoutDraftNotification');
    } on MissingPluginException {
      // Tests and non-Android builds do not register this channel.
    } on PlatformException {
      // Cancellation is best effort; the workout draft remains authoritative.
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'workoutDraftNotificationTapped') {
      await _tapHandler?.call();
    }
  }
}

class WorkoutDraftNotificationSync {
  const WorkoutDraftNotificationSync._();

  static Future<void> syncFromDraft(
    WorkoutRecordDraft? draft,
    AppStrings strings, {
    WorkoutDraftNotificationPlatform? platform,
  }) async {
    final targetPlatform =
        platform ?? MethodChannelWorkoutDraftNotificationPlatform.instance;
    try {
      final content = WorkoutDraftNotificationBuilder.fromDraft(draft, strings);
      if (content == null) {
        await targetPlatform.cancel();
        return;
      }
      await targetPlatform.show(content);
    } catch (_) {
      // Notification rendering is best effort and must never fail draft writes.
    }
  }
}

class WorkoutDraftNotificationScheduler {
  WorkoutDraftNotificationScheduler({
    required this.strings,
    this.platform,
    this.delay = const Duration(seconds: 2),
  });

  final AppStrings strings;
  final WorkoutDraftNotificationPlatform? platform;
  final Duration delay;

  Timer? _timer;
  WorkoutRecordDraft? _pendingDraft;
  bool _hasPendingDraft = false;
  Future<void> _syncTail = Future<void>.value();

  void schedule(WorkoutRecordDraft draft) {
    _pendingDraft = draft;
    _hasPendingDraft = true;
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(flush()));
  }

  Future<void> syncNow(WorkoutRecordDraft draft) {
    _pendingDraft = draft;
    _hasPendingDraft = true;
    return flush();
  }

  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    if (!_hasPendingDraft) {
      return _syncTail;
    }
    final draft = _pendingDraft;
    _pendingDraft = null;
    _hasPendingDraft = false;
    _syncTail = _syncTail.then(
      (_) => WorkoutDraftNotificationSync.syncFromDraft(
        draft,
        strings,
        platform: platform,
      ),
    );
    return _syncTail;
  }

  Future<void> cancelNow() {
    _timer?.cancel();
    _timer = null;
    _pendingDraft = null;
    _hasPendingDraft = false;
    _syncTail = _syncTail.then(
      (_) => WorkoutDraftNotificationSync.syncFromDraft(
        null,
        strings,
        platform: platform,
      ),
    );
    return _syncTail;
  }

  void dispose() {
    _timer?.cancel();
  }
}

class WorkoutDraftNotificationTapCoordinator {
  WorkoutDraftNotificationTapCoordinator();

  static final WorkoutDraftNotificationTapCoordinator instance =
      WorkoutDraftNotificationTapCoordinator();

  bool _editorOpen = false;

  bool get editorOpen => _editorOpen;

  void markEditorOpen() {
    _editorOpen = true;
  }

  void markEditorClosed() {
    _editorOpen = false;
  }

  Future<void> handleTap({
    required Future<WorkoutRecordDraft?> Function() loadActiveDraft,
    required Future<void> Function(WorkoutRecordDraft draft) openDraft,
    required Future<void> Function() cancelNotification,
  }) async {
    if (_editorOpen) {
      return;
    }
    final draft = await loadActiveDraft();
    if (draft == null) {
      await cancelNotification();
      return;
    }
    await openDraft(draft);
  }
}

class _NotificationExerciseDraft {
  const _NotificationExerciseDraft({
    required this.originalIndex,
    required this.exerciseKey,
    required this.exerciseName,
    required this.bodyPart,
    required this.isCardio,
    required this.setMetricType,
    required this.sets,
  });

  final int originalIndex;
  final String exerciseKey;
  final String exerciseName;
  final String bodyPart;
  final bool isCardio;
  final String setMetricType;
  final List<_StrengthSetDraft> sets;

  String get imageAsset {
    return FitLogIconAssets.exerciseAssetForExerciseKey(exerciseKey) ??
        FitLogIconAssets.exerciseAssetForExercise(exerciseName) ??
        FitLogIconAssets.workoutAssetForBodyPart(bodyPart);
  }
}

class _StrengthSetDraft {
  const _StrengthSetDraft({
    required this.weightText,
    required this.metricText,
    required this.isCompleted,
    this.completedAt,
  });

  factory _StrengthSetDraft.fromJson(Map<dynamic, dynamic> map) {
    final weightText = _firstText(map, const <String>[
      'weight_text',
      'default_weight',
    ]);
    final metricText = _firstText(map, const <String>[
      'reps_text',
      'default_reps',
    ]);
    return _StrengthSetDraft(
      weightText: weightText,
      metricText: metricText,
      isCompleted:
          map['is_completed'] == true ||
          NumberUtils.toInt(map['is_completed'], fallback: 0) == 1,
      completedAt: _nullableText(map['completed_at']),
    );
  }

  final String weightText;
  final String metricText;
  final bool isCompleted;
  final String? completedAt;

  static String _firstText(Map<dynamic, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = (map[key] ?? '').toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class _SetFocus {
  const _SetFocus({required this.exerciseIndex, required this.setIndex});

  final int exerciseIndex;
  final int setIndex;

  int get setNumber => setIndex + 1;
}

class _CompletedSetRef {
  const _CompletedSetRef({
    required this.exerciseIndex,
    required this.setIndex,
    required this.completedAt,
    required this.fallbackOrder,
  });

  final int exerciseIndex;
  final int setIndex;
  final DateTime? completedAt;
  final int fallbackOrder;

  bool isAfter(_CompletedSetRef other) {
    final thisTime = completedAt;
    final otherTime = other.completedAt;
    if (thisTime != null && otherTime != null) {
      final compared = thisTime.compareTo(otherTime);
      if (compared != 0) {
        return compared > 0;
      }
      return fallbackOrder > other.fallbackOrder;
    }
    if (thisTime != null) {
      return true;
    }
    if (otherTime != null) {
      return false;
    }
    return fallbackOrder > other.fallbackOrder;
  }
}
