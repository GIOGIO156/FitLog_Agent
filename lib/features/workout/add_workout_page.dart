import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/exercise_catalog.dart';
import '../../core/constants/exercise_definition.dart';
import '../../core/constants/exercise_visuals.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/localization_extensions.dart';
import '../../core/theme/fitlog_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/number_utils.dart';
import '../../core/widgets/exercise_thumbnail.dart';
import '../../core/widgets/fitlog_notifications.dart';
import '../../core/widgets/fitlog_ui.dart';
import '../../core/widgets/glass_panel.dart';
import '../../domain/models/workout_record_draft.dart';
import '../../domain/models/workout_session.dart';
import '../../domain/models/workout_set.dart';
import '../../domain/services/workout_calorie_calculator.dart';
import 'workout_draft_notification.dart';
import 'workout_draft_mutation_queue.dart';
import 'workout_editor_resume.dart';

const String _customExerciseGroupKey = 'Custom';

String _customExerciseGroupLabel(AppStrings strings) {
  return strings.isChinese ? '自定义动作' : 'Custom exercises';
}

String _cardioDurationHelperText(AppStrings strings) {
  return strings.isChinese
      ? '有氧消耗按时长和体重计算。'
      : 'Cardio calories are calculated from duration and body weight.';
}

String _noSavedCustomExercisesLabel(AppStrings strings) {
  return strings.isChinese ? '还没有已保存的自定义动作。' : 'No saved custom exercises yet.';
}

String _deleteCustomExerciseTitle(AppStrings strings) {
  return strings.isChinese ? '删除自定义动作？' : 'Delete custom exercise?';
}

String _deleteCustomExerciseMessage(AppStrings strings, String exerciseName) {
  return strings.isChinese
      ? '要从可复用自定义动作库中删除“$exerciseName”吗？历史训练记录不会被改动。'
      : 'Delete $exerciseName from the reusable custom library? Historical workout records will stay unchanged.';
}

String _customExerciseDeletedLabel(AppStrings strings) {
  return strings.isChinese ? '自定义动作已删除。' : 'Custom exercise deleted.';
}

String _customExerciseDeleteFailedLabel(AppStrings strings) {
  return strings.isChinese ? '删除失败，请重试。' : 'Failed to delete custom exercise.';
}

class AddWorkoutPage extends StatefulWidget {
  const AddWorkoutPage({
    super.key,
    this.initialDate,
    this.editingPlanId,
    this.seedSessionId,
  });

  final String? initialDate;
  final String? editingPlanId;
  final int? seedSessionId;

  @override
  State<AddWorkoutPage> createState() => _AddWorkoutPageState();
}

class _AddWorkoutPageState extends State<AddWorkoutPage>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _recordNameController = TextEditingController();
  final _notesController = TextEditingController();

  final Map<String, _ExercisePlanDraft> _selectedPlans =
      <String, _ExercisePlanDraft>{};

  List<_ExerciseOption> _exerciseOptions = <_ExerciseOption>[];
  Map<String, _ExerciseOption> _exerciseOptionsByKey =
      <String, _ExerciseOption>{};

  late String _date;
  late final String _entryDate;
  double _profileWeightKg = 65;
  bool _loadingPage = true;
  bool _saving = false;
  bool _updatingExerciseSelection = false;
  bool _allowPop = false;
  String? _editingPlanId;
  int? _editingSeedSessionId;
  String? _draftCreatedAt;
  Timer? _draftSaveDebounce;
  final WorkoutDraftMutationQueue _draftMutationQueue =
      WorkoutDraftMutationQueue();
  WorkoutDraftNotificationScheduler? _notificationScheduler;

  bool get _isEditing =>
      (_editingPlanId ?? '').trim().isNotEmpty || _editingSeedSessionId != null;

  @override
  void initState() {
    super.initState();
    WorkoutDraftNotificationTapCoordinator.instance.markEditorOpen();
    WidgetsBinding.instance.addObserver(this);
    _entryDate = widget.initialDate ?? DateUtilsX.todayKey();
    _date = _entryDate;
    _editingPlanId = _normalizePlanId(widget.editingPlanId);
    _editingSeedSessionId = widget.seedSessionId;
    _setExerciseOptions(ExerciseCatalog.builtInExercises);
    _recordNameController.addListener(_scheduleDraftSave);
    _notesController.addListener(_scheduleDraftSave);
    _loadInitialState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WorkoutDraftNotificationTapCoordinator.instance.markEditorClosed();
    _draftSaveDebounce?.cancel();
    _notificationScheduler?.dispose();
    _recordNameController.dispose();
    _notesController.dispose();
    for (final draft in _selectedPlans.values) {
      draft.dispose();
    }
    super.dispose();
  }

  List<_ExercisePlanDraft> get _selectedDrafts =>
      _selectedPlans.values.toList();

  Future<void> _reloadExerciseOptions() async {
    final customDefinitions = await context
        .read<AppServices>()
        .customExerciseRepository
        .getActiveDefinitions();
    if (!mounted) {
      return;
    }
    setState(() {
      _setExerciseOptions(<ExerciseDefinition>[
        ...ExerciseCatalog.builtInExercises,
        ...customDefinitions,
      ]);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_saving) {
        return;
      }
      unawaited(_persistDraftNow(syncNotificationImmediately: true));
    }
  }

  Future<void> _loadInitialState() async {
    _notificationScheduler ??= WorkoutDraftNotificationScheduler(
      strings: context.stringsRead,
    );
    final services = context.read<AppServices>();
    final profileFuture = services.profileRepository.getProfile();
    final draftFuture = services.workoutDraftRepository.getActiveDraft();
    final sessionsFuture = _loadSeedSessions(services);
    final customDefinitionsFuture = services.customExerciseRepository
        .getActiveDefinitions();

    final profile = await profileFuture;
    final activeDraft = await draftFuture;
    final sessions = await sessionsFuture;
    final customDefinitions = await customDefinitionsFuture;

    if (!mounted) {
      return;
    }

    if (profile != null) {
      _profileWeightKg = profile.weightKg;
    }
    _setExerciseOptions(<ExerciseDefinition>[
      ...ExerciseCatalog.builtInExercises,
      ...customDefinitions,
    ]);

    if (sessions.isNotEmpty) {
      _applySessions(sessions);
    } else {
      _resetToEmptyState();
    }
    final restorableDraft = _resolveRestorableDraft(activeDraft);
    if (restorableDraft != null) {
      _applyStoredDraft(restorableDraft);
    }

    if (!mounted) {
      return;
    }

    setState(() => _loadingPage = false);
    unawaited(_saveOrClearDraft());
  }

  DateTime _createdAtRaw(WorkoutSession session) {
    final created = DateTime.tryParse(session.createdAt ?? '');
    if (created != null) {
      return created;
    }
    return DateUtilsX.parseDay(session.date);
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateUtilsX.parseDay(_date),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected != null && mounted) {
      setState(() => _date = DateUtilsX.formatDate(selected));
      _scheduleDraftSave();
    }
  }

  void _setExerciseOptions(List<ExerciseDefinition> definitions) {
    _exerciseOptions = definitions
        .map((definition) => _ExerciseOption(definition: definition))
        .toList();
    _exerciseOptionsByKey = <String, _ExerciseOption>{
      for (final option in _exerciseOptions) option.key(): option,
    };
  }

  String _createPlanId() => DateTime.now().microsecondsSinceEpoch.toString();

  String? _normalizePlanId(String? value) {
    final trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<List<WorkoutSession>> _loadSeedSessions(AppServices services) async {
    if ((_editingPlanId ?? '').isNotEmpty) {
      final sessions = await services.workoutRepository
          .getWorkoutSessionsByPlanId(_editingPlanId!);
      sessions.sort((a, b) => _createdAtRaw(a).compareTo(_createdAtRaw(b)));
      return sessions;
    }
    if (_editingSeedSessionId != null) {
      final session = await services.workoutRepository.getWorkoutSessionById(
        _editingSeedSessionId!,
      );
      if (session == null) {
        return const <WorkoutSession>[];
      }
      return <WorkoutSession>[session];
    }
    return const <WorkoutSession>[];
  }

  WorkoutRecordDraft? _resolveRestorableDraft(WorkoutRecordDraft? activeDraft) {
    if (activeDraft == null || _isEditing) {
      return null;
    }
    return activeDraft;
  }

  void _resetToEmptyState() {
    _date = _entryDate;
    _recordNameController.text = '';
    _notesController.text = '';
    _replaceSelectedPlans(const <String, _ExercisePlanDraft>{});
  }

  void _applySessions(List<WorkoutSession> sessions) {
    if (sessions.isEmpty) {
      _resetToEmptyState();
      return;
    }
    final reordered = <String, _ExercisePlanDraft>{};
    for (final session in sessions) {
      final draft = _ExercisePlanDraft.fromSession(session);
      reordered[draft.exerciseKey] = draft;
    }
    _date = sessions.first.date;
    _recordNameController.text = sessions.first.recordName?.trim() ?? '';
    _notesController.text = sessions.first.notes;
    _replaceSelectedPlans(reordered);
  }

  void _applyStoredDraft(WorkoutRecordDraft draft) {
    final payload = draft.payload;
    final rawExercises = payload['exercises'];
    final reordered = <String, _ExercisePlanDraft>{};
    if (rawExercises is List) {
      for (final entry in rawExercises.whereType<Map>()) {
        final exerciseDraft = _ExercisePlanDraft.fromJson(
          entry.cast<String, dynamic>(),
        );
        reordered[exerciseDraft.exerciseKey] = exerciseDraft;
      }
    }
    _draftCreatedAt = draft.createdAt;
    _date = draft.date;
    _recordNameController.text = draft.recordName;
    _notesController.text = draft.notes;
    _replaceSelectedPlans(reordered);
  }

  void _replaceSelectedPlans(Map<String, _ExercisePlanDraft> drafts) {
    for (final draft in _selectedPlans.values) {
      draft.dispose();
    }
    _selectedPlans
      ..clear()
      ..addAll(drafts);
  }

  Map<String, dynamic> _buildDraftPayload() {
    return <String, dynamic>{
      'kind': WorkoutRecordDraft.kindNewRecord,
      'date': _date,
      'record_name': _recordNameController.text.trim(),
      'notes': _notesController.text.trim(),
      'exercises': _selectedDrafts.map((draft) => draft.toJson()).toList(),
    };
  }

  bool get _hasMeaningfulDraftContent {
    if (_recordNameController.text.trim().isNotEmpty ||
        _notesController.text.trim().isNotEmpty ||
        _selectedPlans.isNotEmpty) {
      return true;
    }
    return _date != _entryDate;
  }

  bool get _shouldPersistDraft => _hasMeaningfulDraftContent;

  void _scheduleDraftSave() {
    if (_loadingPage) {
      return;
    }
    _draftSaveDebounce?.cancel();
    _draftSaveDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_saveOrClearDraft());
    });
  }

  Future<void> _persistDraftNow({
    bool syncNotificationImmediately = false,
  }) async {
    _draftSaveDebounce?.cancel();
    await _saveOrClearDraft(
      syncNotificationImmediately: syncNotificationImmediately,
    );
  }

  Future<void> _saveOrClearDraft({
    bool notifyRefresh = false,
    bool syncNotificationImmediately = false,
  }) async {
    if (!mounted || _loadingPage || _saving || _isEditing) {
      return;
    }
    final services = context.read<AppServices>();
    final strings = context.stringsRead;
    if (!_shouldPersistDraft) {
      await _draftMutationQueue.run(() async {
        await services.workoutDraftRepository.deleteActiveDraft();
        await WorkoutEditorResumeStore.clear();
      });
      if (_notificationScheduler case final scheduler?) {
        await scheduler.cancelNow();
      } else {
        await WorkoutDraftNotificationSync.syncFromDraft(null, strings);
      }
      _draftCreatedAt = null;
      if (notifyRefresh && mounted) {
        context.read<RefreshNotifier>().markDataChanged();
      }
      return;
    }

    final now = DateTime.now().toIso8601String();
    final createdAt = _draftCreatedAt ?? now;
    _draftCreatedAt = createdAt;
    final draft = WorkoutRecordDraft(
      id: WorkoutRecordDraft.activeDraftId,
      kind: WorkoutRecordDraft.kindNewRecord,
      date: _date,
      recordName: _recordNameController.text.trim(),
      notes: _notesController.text.trim(),
      payloadJson: jsonEncode(_buildDraftPayload()),
      createdAt: createdAt,
      updatedAt: now,
    );
    await _draftMutationQueue.run(() async {
      await services.workoutDraftRepository.saveActiveDraft(draft);
      await WorkoutEditorResumeStore.markActive();
    });
    if (syncNotificationImmediately) {
      await _notificationScheduler?.syncNow(draft);
    } else {
      _notificationScheduler?.schedule(draft);
    }
    if (notifyRefresh && mounted) {
      context.read<RefreshNotifier>().markDataChanged();
    }
  }

  Future<void> _deleteActiveDraftBarrier(
    AppServices services,
    AppStrings strings,
  ) async {
    await _draftMutationQueue.run(() async {
      await services.workoutDraftRepository.deleteActiveDraft();
      await WorkoutEditorResumeStore.clear();
    });
    if (_notificationScheduler case final scheduler?) {
      await scheduler.cancelNow();
    } else {
      await WorkoutDraftNotificationSync.syncFromDraft(null, strings);
    }
  }

  Future<void> _exitPage() async {
    if (_saving) {
      return;
    }
    await _persistDraftNow(syncNotificationImmediately: true);
    await WorkoutEditorResumeStore.clear();
    if (!mounted) {
      return;
    }
    context.read<RefreshNotifier>().markDataChanged();
    setState(() => _allowPop = true);
    Navigator.of(context).pop(false);
  }

  Future<void> _discardCurrentDraft() async {
    final strings = context.stringsRead;
    final refreshNotifier = context.read<RefreshNotifier>();
    final services = context.read<AppServices>();
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(
                _isEditing
                    ? strings.discardWorkoutChangesTitle
                    : strings.discardWorkoutDraftTitle,
              ),
              content: Text(
                _isEditing
                    ? strings.discardWorkoutChangesMessage
                    : strings.discardWorkoutDraftMessage,
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(strings.cancel),
                ),
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    _isEditing
                        ? strings.discardWorkoutChangesAction
                        : strings.discardWorkoutDraftAction,
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    await _deleteActiveDraftBarrier(services, strings);
    if (!mounted) {
      return;
    }
    refreshNotifier.markDataChanged();
    setState(() => _allowPop = true);
    Navigator.of(context).pop(false);
  }

  Future<void> _openExerciseLibraryPicker() async {
    final selectedKeys = _selectedPlans.keys.toList();
    final pickedKeys = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute<List<String>>(
        builder: (_) => _ExerciseLibraryPickerPage(
          options: _exerciseOptions,
          initiallySelectedKeys: selectedKeys,
        ),
      ),
    );

    await _reloadExerciseOptions();

    if (pickedKeys == null || !mounted) {
      return;
    }

    await _applyExerciseSelection(pickedKeys);
  }

  Future<void> _openCustomExercise() async {
    final definition = await Navigator.of(context).push<ExerciseDefinition>(
      MaterialPageRoute(builder: (_) => const _CustomExercisePage()),
    );
    if (definition == null || !mounted) {
      return;
    }

    final draft = _ExercisePlanDraft.fromDefinition(
      definition: definition,
      exerciseSource: ExerciseSource.adHoc,
    );
    setState(() {
      final replaced = _selectedPlans.remove(draft.exerciseKey);
      replaced?.dispose();
      _selectedPlans[draft.exerciseKey] = draft;
    });
    unawaited(_persistDraftNow(syncNotificationImmediately: true));
  }

  Future<void> _applyExerciseSelection(List<String> pickedKeysInOrder) async {
    setState(() => _updatingExerciseSelection = true);

    final removedKeys = _selectedPlans.keys
        .where((key) => !pickedKeysInOrder.contains(key))
        .toList();
    for (final key in removedKeys) {
      _selectedPlans.remove(key)?.dispose();
    }

    final repository = context.read<AppServices>().workoutRepository;
    final newDrafts = <String, _ExercisePlanDraft>{};
    for (final key in pickedKeysInOrder) {
      if (_selectedPlans.containsKey(key)) {
        continue;
      }
      final option = _exerciseOptionsByKey[key];
      if (option == null) {
        continue;
      }
      final latestSession = await repository.getLatestSessionByExerciseName(
        option.name,
      );
      if (!mounted) {
        return;
      }
      newDrafts[key] = _ExercisePlanDraft.fromHistory(
        definition: option.definition,
        latestSession: latestSession,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      final reordered = <String, _ExercisePlanDraft>{};
      for (final key in pickedKeysInOrder) {
        final existing = _selectedPlans[key] ?? newDrafts[key];
        if (existing != null) {
          reordered[key] = existing;
        }
      }

      for (final entry in newDrafts.entries) {
        reordered.putIfAbsent(entry.key, () => entry.value);
      }

      _selectedPlans
        ..clear()
        ..addAll(reordered);
      _updatingExerciseSelection = false;
    });
    await _persistDraftNow(syncNotificationImmediately: true);
  }

  void _addSet(_ExercisePlanDraft draft) {
    var defaultWeight = '';
    var defaultReps = '';
    if (draft.sets.isNotEmpty) {
      final last = draft.sets.last;
      defaultWeight = last.effectiveWeightText;
      defaultReps = last.effectiveRepsText;
    }

    setState(() {
      draft.sets.add(
        _SetDraft(defaultWeight: defaultWeight, defaultReps: defaultReps),
      );
    });
    unawaited(_persistDraftNow(syncNotificationImmediately: true));
  }

  void _removeSet(_ExercisePlanDraft draft, int index) {
    final target = draft.sets.removeAt(index);
    target.dispose();
    setState(() {});
    unawaited(_persistDraftNow(syncNotificationImmediately: true));
  }

  void _removeExercise(_ExercisePlanDraft draft) {
    final target = _selectedPlans.remove(draft.exerciseKey);
    target?.dispose();
    setState(() {});
    unawaited(_persistDraftNow(syncNotificationImmediately: true));
  }

  void _toggleSetCompleted(_SetDraft draft) {
    setState(() {
      if (draft.isCompleted) {
        draft.isCompleted = false;
        draft.completedAt = null;
      } else {
        draft.isCompleted = true;
        draft.completedAt = DateTime.now().toIso8601String();
      }
    });
    unawaited(_persistDraftNow(syncNotificationImmediately: true));
  }

  int _durationForDraft(_ExercisePlanDraft draft) {
    return NumberUtils.toInt(draft.effectiveDurationText, fallback: 0);
  }

  int _parseDurationSeconds(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      if (parts.length != 2) {
        return 0;
      }
      final minutes = NumberUtils.toInt(parts.first, fallback: -1);
      final seconds = NumberUtils.toInt(parts.last, fallback: -1);
      if (minutes < 0 || seconds < 0 || seconds >= 60) {
        return 0;
      }
      return minutes * 60 + seconds;
    }
    return NumberUtils.toInt(trimmed, fallback: 0);
  }

  WorkoutSet _buildSetForDraft({
    required _ExercisePlanDraft draft,
    required _SetDraft setDraft,
    required int setNumber,
    String? completedAt,
  }) {
    final inputWeight = NumberUtils.toDouble(
      setDraft.effectiveWeightText,
      fallback: 0,
    );
    final safeInputWeight = inputWeight < 0 ? 0.0 : inputWeight;
    final isDurationSet = draft.usesDurationSets;
    final inputDurationSeconds = isDurationSet
        ? _parseDurationSeconds(setDraft.effectiveRepsText)
        : null;
    final inputReps = isDurationSet
        ? null
        : NumberUtils.toInt(setDraft.effectiveRepsText, fallback: 0);
    final calculationLoad =
        draft.loadInputMode == ExerciseLoadInputMode.perSideLoad
        ? safeInputWeight * 2
        : safeInputWeight;
    final calculationReps = isDurationSet
        ? (inputDurationSeconds == null || inputDurationSeconds <= 0
              ? 0
              : (inputDurationSeconds / 4).round().clamp(1, 9999).toInt())
        : (draft.repsInputMode == ExerciseRepsInputMode.perSide
              ? (inputReps ?? 0) * 2
              : inputReps ?? 0);

    return WorkoutSet(
      setNumber: setNumber,
      weightKg: calculationLoad,
      reps: calculationReps,
      inputWeightKg: safeInputWeight,
      inputReps: inputReps,
      inputDurationSeconds: inputDurationSeconds,
      calculationLoadKg: calculationLoad,
      calculationReps: calculationReps,
      loadInputMode: draft.loadInputMode,
      repsInputMode: draft.repsInputMode,
      setMetricType: draft.setMetricType,
      isCompleted: setDraft.isCompleted,
      completedAt: completedAt,
    );
  }

  List<WorkoutSet> _buildSetsForPreview(_ExercisePlanDraft draft) {
    final sets = <WorkoutSet>[];
    for (var i = 0; i < draft.sets.length; i++) {
      final setDraft = draft.sets[i];
      if (!setDraft.isCompleted) {
        continue;
      }
      final set = _buildSetForDraft(
        draft: draft,
        setDraft: setDraft,
        setNumber: i + 1,
      );
      if (set.effectiveCalculationReps <= 0) {
        continue;
      }
      sets.add(set);
    }
    return sets;
  }

  double _estimateCaloriesForDraft(_ExercisePlanDraft draft) {
    final durationMinutes = _durationForDraft(draft);
    if (draft.isCardio) {
      if (durationMinutes <= 0) {
        return 0;
      }
      final activeMinutes = draft.usesIntervalCardio
          ? NumberUtils.toInt(draft.effectiveActiveDurationText, fallback: 0)
          : null;
      final met = ExerciseCatalog.cardioMetFor(
        definition: draft.definition,
        intensity: draft.cardioIntensityBasis,
      );
      return WorkoutCalorieCalculator.estimateCardioCalories(
        exerciseName: draft.exerciseName,
        bodyWeightKg: _profileWeightKg,
        durationMinutes: durationMinutes,
        definition: draft.definition,
        intensityBasis: draft.cardioIntensityBasis,
        met: met,
        activeDurationMinutes: activeMinutes,
      );
    }

    final sets = _buildSetsForPreview(draft);
    return WorkoutCalorieCalculator.estimateStrengthCalories(
      exerciseName: draft.exerciseName,
      bodyWeightKg: _profileWeightKg,
      sets: sets,
      totalSessionDurationMinutes: durationMinutes,
      definition: draft.definition,
      strengthProfile: draft.strengthProfile,
    );
  }

  double get _estimatedTotalCalories {
    return _selectedDrafts.fold<double>(
      0,
      (sum, draft) => sum + _estimateCaloriesForDraft(draft),
    );
  }

  bool get _hasSelectedStrengthExercise =>
      _selectedDrafts.any((draft) => !draft.isCardio);

  Widget _buildSetValueInput({
    required BuildContext context,
    required TextEditingController controller,
    required TextInputType keyboardType,
    required String hintText,
    required bool showAsDefaultValue,
    bool enabled = true,
    VoidCallback? onInputTap,
    void Function(String value)? onValueChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeTextColor = isDark ? Colors.white : Colors.black87;
    final defaultTextColor = isDark
        ? Colors.white.withValues(alpha: 0.42)
        : Colors.black.withValues(alpha: 0.42);

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      textAlign: TextAlign.center,
      textAlignVertical: TextAlignVertical.center,
      selectAllOnFocus: true,
      onTap: onInputTap,
      onChanged: (value) {
        onValueChanged?.call(value);
        setState(() {});
        _scheduleDraftSave();
      },
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: showAsDefaultValue ? defaultTextColor : activeTextColor,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: hintText.isEmpty ? '--' : hintText,
        hintStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: isDark
              ? Colors.white.withValues(alpha: 0.34)
              : Colors.black.withValues(alpha: 0.34),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
      ),
    );
  }

  String? _validateWorkoutRecord(AppStrings strings) {
    if (!_formKey.currentState!.validate()) {
      return null;
    }
    if (_selectedPlans.isEmpty) {
      return strings.chooseAtLeastOneExercise;
    }
    if (_recordNameController.text.trim().isEmpty) {
      return strings.workoutRecordNameRequired;
    }

    for (final draft in _selectedDrafts) {
      final durationMinutes = _durationForDraft(draft);
      if (durationMinutes <= 0) {
        return strings.invalidDurationForExercise(
          strings.exerciseDisplayName(draft.exerciseName),
        );
      }
      if (draft.isCardio) {
        if (draft.usesIntervalCardio) {
          final activeMinutes = NumberUtils.toInt(
            draft.effectiveActiveDurationText,
            fallback: 0,
          );
          if (activeMinutes <= 0 || activeMinutes > durationMinutes) {
            return strings.invalidActiveDurationForExercise(
              strings.exerciseDisplayName(draft.exerciseName),
            );
          }
        }
        continue;
      }
      for (final setDraft in draft.completedSets) {
        final weight = NumberUtils.toDouble(
          setDraft.effectiveWeightText,
          fallback: double.nan,
        );
        final validMetric = draft.usesDurationSets
            ? _parseDurationSeconds(setDraft.effectiveRepsText) > 0
            : NumberUtils.toInt(setDraft.effectiveRepsText, fallback: -1) > 0;
        if (!validMetric || weight.isNaN || weight < 0) {
          return strings.invalidSetValue(
            strings.exerciseDisplayName(draft.exerciseName),
          );
        }
      }
    }
    return null;
  }

  List<WorkoutSession> _buildSessionsForCommit({
    required String planId,
    required String now,
    required String recordName,
    required String notes,
  }) {
    final sessions = <WorkoutSession>[];
    for (final draft in _selectedDrafts) {
      final durationMinutes = _durationForDraft(draft);
      final sets = <WorkoutSet>[];
      if (!draft.isCardio) {
        final completedSets = draft.completedSets;
        for (var i = 0; i < completedSets.length; i++) {
          final setDraft = completedSets[i];
          final set = _buildSetForDraft(
            draft: draft,
            setDraft: setDraft,
            setNumber: i + 1,
            completedAt: setDraft.isCompleted ? now : null,
          );
          if (set.effectiveCalculationReps > 0) {
            sets.add(set);
          }
        }
      }

      if (!draft.isCardio && sets.isEmpty) {
        continue;
      }

      final cardioMet = draft.isCardio
          ? ExerciseCatalog.cardioMetFor(
              definition: draft.definition,
              intensity: draft.cardioIntensityBasis,
            )
          : null;
      final activeMinutes = draft.isCardio && draft.usesIntervalCardio
          ? NumberUtils.toInt(draft.effectiveActiveDurationText, fallback: 0)
          : null;
      sessions.add(
        WorkoutSession(
          planId: planId,
          recordName: recordName,
          date: _date,
          bodyPart: draft.bodyPart,
          secondaryBodyPart: draft.secondaryBodyPart,
          exerciseName: draft.exerciseName,
          exerciseKey: draft.exerciseKey,
          exerciseSource: draft.exerciseSource,
          exerciseType: draft.isCardio ? 'cardio' : 'strength',
          durationMinutes: durationMinutes,
          intensity: draft.isCardio ? draft.cardioIntensityBasis : 'medium',
          strengthProfile: draft.isCardio ? null : draft.strengthProfile,
          loadInputMode: draft.isCardio ? null : draft.loadInputMode,
          repsInputMode: draft.isCardio ? null : draft.repsInputMode,
          setMetricType: draft.isCardio ? null : draft.setMetricType,
          cardioMet: cardioMet,
          cardioIntensityBasis: draft.isCardio
              ? draft.cardioIntensityBasis
              : null,
          cardioActiveMinutes: activeMinutes,
          bodyWeightKgAtCalculation: _profileWeightKg,
          exerciseSnapshotJson: draft.snapshotJson(),
          estimatedCalories: draft.isCardio
              ? WorkoutCalorieCalculator.estimateCardioCalories(
                  exerciseName: draft.exerciseName,
                  bodyWeightKg: _profileWeightKg,
                  durationMinutes: durationMinutes,
                  definition: draft.definition,
                  intensityBasis: draft.cardioIntensityBasis,
                  met: cardioMet,
                  activeDurationMinutes: activeMinutes,
                )
              : WorkoutCalorieCalculator.estimateStrengthCalories(
                  exerciseName: draft.exerciseName,
                  bodyWeightKg: _profileWeightKg,
                  sets: sets,
                  totalSessionDurationMinutes: durationMinutes,
                  definition: draft.definition,
                  strengthProfile: draft.strengthProfile,
                ),
          notes: notes,
          sets: sets,
        ),
      );
    }
    return sessions;
  }

  Future<void> _maybeSaveAdHocExercises(AppStrings strings) async {
    final adHocDrafts = _selectedDrafts
        .where((draft) => draft.exerciseSource == ExerciseSource.adHoc)
        .toList();
    if (adHocDrafts.isEmpty) {
      return;
    }

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(strings.saveCustomExercisesTitle),
          content: Text(strings.saveCustomExercisesMessage(adHocDrafts.length)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.notNow),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(strings.save),
            ),
          ],
        );
      },
    );
    if (shouldSave != true || !mounted) {
      return;
    }

    final repository = context.read<AppServices>().customExerciseRepository;
    for (final draft in adHocDrafts) {
      await repository.saveDefinition(
        draft.definition.copyWith(isBuiltin: false),
      );
      draft.exerciseSource = ExerciseSource.custom;
    }
    _setExerciseOptions(<ExerciseDefinition>[
      ...ExerciseCatalog.builtInExercises,
      ...await repository.getActiveDefinitions(),
    ]);
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final strings = context.stringsRead;
    final validationMessage = _validateWorkoutRecord(strings);
    if (validationMessage != null) {
      FitLogNotifications.error(context, validationMessage);
      return;
    }

    _draftSaveDebounce?.cancel();
    setState(() => _saving = true);
    final now = DateTime.now().toIso8601String();
    final planId = (_editingPlanId ?? '').isNotEmpty
        ? _editingPlanId!
        : _createPlanId();
    final recordName = _recordNameController.text.trim();
    final notes = _notesController.text.trim();
    final services = context.read<AppServices>();
    final refreshNotifier = context.read<RefreshNotifier>();
    List<WorkoutSession> sessions = const <WorkoutSession>[];
    var saved = false;
    try {
      await _maybeSaveAdHocExercises(strings);
      if (!mounted) {
        return;
      }
      sessions = _buildSessionsForCommit(
        planId: planId,
        now: now,
        recordName: recordName,
        notes: notes,
      );
      if (sessions.isEmpty) {
        FitLogNotifications.error(context, strings.noCompletedSetsToSave);
        return;
      }

      if ((_editingPlanId ?? '').isNotEmpty) {
        await services.workoutRepository.replaceWorkoutPlan(
          planId: _editingPlanId!,
          sessions: sessions,
        );
      } else if (_editingSeedSessionId != null) {
        await services.workoutRepository.replaceSingleWorkoutRecord(
          sessionId: _editingSeedSessionId!,
          sessions: sessions,
        );
      } else {
        await services.workoutRepository.insertWorkoutPlan(sessions);
      }

      await _deleteActiveDraftBarrier(services, strings);
      _draftCreatedAt = null;
      if (!mounted) {
        return;
      }
      context.refreshDailySummaryCacheForDates(
        sessions.map((session) => session.date),
      );

      saved = true;
    } catch (error) {
      if (mounted) {
        FitLogNotifications.error(context, strings.failedToLoadWorkout(error));
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }

    if (!mounted || !saved) {
      return;
    }

    final successMessage = strings.workoutRecordSavedCount(sessions.length);
    final navigator = Navigator.of(context);
    refreshNotifier.markDataChanged();
    setState(() => _allowPop = true);
    FitLogNotifications.successAfterNavigation(context, successMessage);
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    if (_loadingPage) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing ? strings.editWorkoutRecord : strings.addWorkout,
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope<bool>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await _exitPage();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _exitPage),
          title: Text(
            _isEditing ? strings.editWorkoutRecord : strings.addWorkout,
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              bottom:
                  MediaQuery.paddingOf(context).bottom +
                  kBottomNavigationBarHeight +
                  100,
            ),
            children: <Widget>[
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          strings.selectedExercises,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.7),
                          ),
                          child: Text(
                            strings.selectedExercisesCount(
                              _selectedPlans.length,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      strings.exercisePickerCollapsedHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: (_saving || _updatingExerciseSelection)
                                ? null
                                : _openExerciseLibraryPicker,
                            icon: _updatingExerciseSelection
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.fitness_center),
                            label: Text(strings.addExercises),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _openCustomExercise,
                            icon: const Icon(Icons.add_box_outlined),
                            label: Text(strings.customExercise),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      strings.workoutRecordDetails,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_selectedPlans.isEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(strings.noExerciseSelectedYet),
                          const SizedBox(height: 4),
                          Text(
                            strings.tapAddExerciseToBuildPlan,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      )
                    else ...<Widget>[
                      Text(
                        strings.completeBeforeSaveHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      ..._selectedDrafts.map((draft) {
                        final color = ExerciseVisuals.colorForBodyPart(
                          draft.bodyPart,
                          context,
                        );
                        final durationHint = draft.defaultDurationHint.isEmpty
                            ? '--'
                            : draft.defaultDurationHint;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.24),
                              border: Border.all(
                                color: color.withValues(alpha: 0.16),
                              ),
                            ),
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    ExerciseThumbnail(
                                      bodyPart: draft.bodyPart,
                                      exerciseName: draft.exerciseName,
                                      color: color,
                                      size: 48,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            strings.exerciseDisplayName(
                                              draft.exerciseName,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            strings.bodyPartLabel(
                                              draft.bodyPart,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _removeExercise(draft),
                                      icon: const Icon(Icons.close_rounded),
                                      tooltip: strings.removeExercise,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (draft.isCardio)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        _cardioDurationHelperText(strings),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: draft.durationController,
                                        keyboardType: TextInputType.number,
                                        selectAllOnFocus: true,
                                        enabled: !_saving,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          labelText:
                                              strings.durationMinutesLabel,
                                          hintText: durationHint,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                        ),
                                        onChanged: (_) {
                                          setState(() {});
                                          _scheduleDraftSave();
                                        },
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        strings.cardioIntensityQuestion,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 10),
                                      DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        initialValue:
                                            draft.cardioIntensityBasis,
                                        decoration: InputDecoration(
                                          labelText:
                                              strings.cardioIntensityFieldLabel,
                                        ),
                                        items: CardioIntensityBasis.values
                                            .map(
                                              (
                                                value,
                                              ) => DropdownMenuItem<String>(
                                                value: value,
                                                child: Text(
                                                  strings
                                                      .cardioIntensityOptionLabel(
                                                        value,
                                                      ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: _saving
                                            ? null
                                            : (value) {
                                                if (value == null) {
                                                  return;
                                                }
                                                setState(() {
                                                  draft.cardioIntensityBasis =
                                                      value;
                                                });
                                                _scheduleDraftSave();
                                              },
                                      ),
                                      if (draft.usesIntervalCardio) ...<Widget>[
                                        const SizedBox(height: 10),
                                        TextFormField(
                                          controller:
                                              draft.activeDurationController,
                                          keyboardType: TextInputType.number,
                                          enabled: !_saving,
                                          decoration: InputDecoration(
                                            labelText:
                                                strings.activeDurationLabel,
                                            helperText: strings
                                                .activeDurationHelperText,
                                          ),
                                          onChanged: (_) {
                                            setState(() {});
                                            _scheduleDraftSave();
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                if (!draft.isCardio) ...<Widget>[
                                  TextFormField(
                                    controller: draft.durationController,
                                    keyboardType: TextInputType.number,
                                    selectAllOnFocus: true,
                                    enabled: !_saving,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: strings.durationMinutesLabel,
                                      hintText: durationHint,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                    ),
                                    onChanged: (_) {
                                      setState(() {});
                                      _scheduleDraftSave();
                                    },
                                  ),
                                  const SizedBox(height: 6),
                                  const SizedBox(height: 10),
                                  if (draft.usesBodyweightLoad)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        draft.usesAssistanceLoad
                                            ? strings.bodyweightAssistLoadHint
                                            : strings.bodyweightAddedLoadHint,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: <Widget>[
                                        SizedBox(
                                          width: 30,
                                          child: Text(
                                            '#',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 6,
                                          child: Text(
                                            draft.weightLabel(strings),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            draft.metricLabel(strings),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 68),
                                      ],
                                    ),
                                  ),
                                  ...draft.sets.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final setDraft = entry.value;
                                    final isLast =
                                        index == draft.sets.length - 1;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Column(
                                        children: <Widget>[
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 3,
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: setDraft.isCompleted
                                                    ? Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                          .withValues(
                                                            alpha: 0.18,
                                                          )
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 2,
                                                  ),
                                              child: Row(
                                                children: <Widget>[
                                                  SizedBox(
                                                    width: 30,
                                                    child: Text(
                                                      '${index + 1}',
                                                      style: const TextStyle(
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 6,
                                                    child: _buildSetValueInput(
                                                      context: context,
                                                      controller: setDraft
                                                          .weightController,
                                                      keyboardType:
                                                          const TextInputType.numberWithOptions(
                                                            decimal: true,
                                                          ),
                                                      hintText: setDraft
                                                          .defaultWeightHint,
                                                      showAsDefaultValue: setDraft
                                                          .showWeightAsDefault,
                                                      enabled: !_saving,
                                                      onInputTap: setDraft
                                                          .prepareWeightForEditing,
                                                      onValueChanged: setDraft
                                                          .markWeightInput,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    flex: 3,
                                                    child: _buildSetValueInput(
                                                      context: context,
                                                      controller: setDraft
                                                          .repsController,
                                                      keyboardType:
                                                          draft.usesDurationSets
                                                          ? TextInputType.text
                                                          : TextInputType
                                                                .number,
                                                      hintText: setDraft
                                                          .defaultRepsHint,
                                                      showAsDefaultValue:
                                                          setDraft
                                                              .showRepsAsDefault,
                                                      enabled: !_saving,
                                                      onInputTap: setDraft
                                                          .prepareRepsForEditing,
                                                      onValueChanged: setDraft
                                                          .markRepsInput,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  IconButton(
                                                    onPressed: _saving
                                                        ? null
                                                        : () =>
                                                              _toggleSetCompleted(
                                                                setDraft,
                                                              ),
                                                    icon: Icon(
                                                      setDraft.isCompleted
                                                          ? Icons.check_circle
                                                          : Icons
                                                                .radio_button_unchecked,
                                                    ),
                                                    color: setDraft.isCompleted
                                                        ? Theme.of(
                                                            context,
                                                          ).colorScheme.primary
                                                        : null,
                                                    tooltip:
                                                        setDraft.isCompleted
                                                        ? strings.completed
                                                        : strings.completeSet,
                                                    iconSize: 24,
                                                    padding: EdgeInsets.zero,
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    constraints:
                                                        const BoxConstraints.tightFor(
                                                          width: 32,
                                                          height: 32,
                                                        ),
                                                  ),
                                                  const SizedBox(width: 2),
                                                  IconButton(
                                                    onPressed: _saving
                                                        ? null
                                                        : () => _removeSet(
                                                            draft,
                                                            index,
                                                          ),
                                                    icon: const Icon(
                                                      Icons
                                                          .remove_circle_outline,
                                                    ),
                                                    tooltip: strings.removeSet,
                                                    iconSize: 24,
                                                    padding: EdgeInsets.zero,
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    constraints:
                                                        const BoxConstraints.tightFor(
                                                          width: 32,
                                                          height: 32,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (!isLast)
                                            Divider(
                                              height: 1,
                                              color: Theme.of(context)
                                                  .dividerColor
                                                  .withValues(alpha: 0.18),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
                                  TextButton.icon(
                                    onPressed: _saving
                                        ? null
                                        : () => _addSet(draft),
                                    icon: const Icon(Icons.add_circle_outline),
                                    label: Text(strings.addSet),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      strings.workoutRecordMeta,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _recordNameController,
                      decoration: InputDecoration(
                        labelText: strings.workoutRecordNameLabel,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings.date),
                      subtitle: Text(DateUtilsX.formatReadable(_date)),
                      trailing: TextButton(
                        onPressed: _pickDate,
                        child: Text(strings.change),
                      ),
                    ),
                    if (_hasSelectedStrengthExercise) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        strings.strengthDurationNotice,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      strings.usingProfileWeight(_profileWeightKg),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${strings.estimatedTotalCaloriesLabel}: ${_estimatedTotalCalories.toStringAsFixed(0)} kcal',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      strings.notesLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: strings.notesLabel,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _discardCurrentDraft,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(
                    _isEditing
                        ? strings.discardWorkoutChangesAction
                        : strings.discardWorkoutDraftAction,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade200),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? strings.saving : strings.saveWorkoutPlan),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetDraft {
  _SetDraft({required String defaultWeight, required String defaultReps})
    : _defaultWeight = defaultWeight.trim(),
      _defaultReps = defaultReps.trim(),
      weightController = TextEditingController(text: defaultWeight.trim()),
      repsController = TextEditingController(text: defaultReps.trim()),
      _showWeightAsDefault = defaultWeight.trim().isNotEmpty,
      _showRepsAsDefault = defaultReps.trim().isNotEmpty;

  _SetDraft.existing({
    required String weight,
    required String reps,
    required this.isCompleted,
    this.completedAt,
  }) : _defaultWeight = '',
       _defaultReps = '',
       weightController = TextEditingController(text: weight.trim()),
       repsController = TextEditingController(text: reps.trim()),
       _showWeightAsDefault = false,
       _showRepsAsDefault = false;

  factory _SetDraft.fromJson(Map<String, dynamic> map) {
    final draft = _SetDraft(
      defaultWeight: (map['default_weight'] ?? '').toString(),
      defaultReps: (map['default_reps'] ?? '').toString(),
    );
    draft.weightController.text = (map['weight_text'] ?? '').toString();
    draft.repsController.text = (map['reps_text'] ?? '').toString();
    draft.isCompleted = map['is_completed'] == true || map['is_completed'] == 1;
    final completedAt = (map['completed_at'] ?? '').toString().trim();
    draft.completedAt = completedAt.isEmpty ? null : completedAt;
    draft._showWeightAsDefault =
        map['show_weight_as_default'] == true ||
        map['show_weight_as_default'] == 1;
    draft._showRepsAsDefault =
        map['show_reps_as_default'] == true || map['show_reps_as_default'] == 1;
    return draft;
  }

  final String _defaultWeight;
  final String _defaultReps;

  final TextEditingController weightController;
  final TextEditingController repsController;
  bool isCompleted = false;
  String? completedAt;
  bool _showWeightAsDefault;
  bool _showRepsAsDefault;

  String get defaultWeightHint => _defaultWeight.isEmpty ? '--' : '';
  String get defaultRepsHint => _defaultReps.isEmpty ? '--' : '';
  bool get showWeightAsDefault => _showWeightAsDefault;
  bool get showRepsAsDefault => _showRepsAsDefault;

  void prepareWeightForEditing() {
    _selectDefaultValueIfNeeded(
      controller: weightController,
      defaultValue: _defaultWeight,
      showAsDefaultValue: _showWeightAsDefault,
    );
  }

  void prepareRepsForEditing() {
    _selectDefaultValueIfNeeded(
      controller: repsController,
      defaultValue: _defaultReps,
      showAsDefaultValue: _showRepsAsDefault,
    );
  }

  void markWeightInput(String value) {
    final typed = value.trim();
    _showWeightAsDefault = _defaultWeight.isNotEmpty && typed == _defaultWeight;
  }

  void markRepsInput(String value) {
    final typed = value.trim();
    _showRepsAsDefault = _defaultReps.isNotEmpty && typed == _defaultReps;
  }

  String get effectiveWeightText {
    return weightController.text.trim();
  }

  String get effectiveRepsText {
    return repsController.text.trim();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'default_weight': _defaultWeight,
      'default_reps': _defaultReps,
      'weight_text': weightController.text.trim(),
      'reps_text': repsController.text.trim(),
      'is_completed': isCompleted,
      'completed_at': completedAt,
      'show_weight_as_default': _showWeightAsDefault,
      'show_reps_as_default': _showRepsAsDefault,
    };
  }

  void _selectDefaultValueIfNeeded({
    required TextEditingController controller,
    required String defaultValue,
    required bool showAsDefaultValue,
  }) {
    if (!showAsDefaultValue || defaultValue.isEmpty) {
      return;
    }
    if (controller.text.trim() != defaultValue) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.text.isEmpty) {
        return;
      }
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
    });
  }

  void dispose() {
    weightController.dispose();
    repsController.dispose();
  }
}

class _ExercisePlanDraft {
  _ExercisePlanDraft({
    required this.definition,
    required this.exerciseSource,
    required this.sets,
    required String defaultDuration,
    String? cardioIntensityBasis,
    String defaultActiveDuration = '',
  }) : _defaultDuration = defaultDuration.trim(),
       _defaultActiveDuration = defaultActiveDuration.trim(),
       cardioIntensityBasis =
           cardioIntensityBasis ?? definition.defaultCardioIntensity,
       durationController = TextEditingController(),
       activeDurationController = TextEditingController();

  factory _ExercisePlanDraft.fromDefinition({
    required ExerciseDefinition definition,
    required String exerciseSource,
  }) {
    return _ExercisePlanDraft(
      definition: definition,
      exerciseSource: exerciseSource,
      sets: definition.isCardio ? <_SetDraft>[] : <_SetDraft>[],
      defaultDuration: '',
    );
  }

  factory _ExercisePlanDraft.fromHistory({
    required ExerciseDefinition definition,
    WorkoutSession? latestSession,
  }) {
    final historySets = latestSession?.sets ?? const <WorkoutSet>[];
    final defaultDuration =
        latestSession == null || latestSession.durationMinutes <= 0
        ? ''
        : latestSession.durationMinutes.toString();

    return _ExercisePlanDraft(
      definition: definition,
      exerciseSource: definition.isBuiltin
          ? ExerciseSource.builtin
          : ExerciseSource.custom,
      sets: definition.isCardio
          ? <_SetDraft>[]
          : historySets
                .map(
                  (set) => _SetDraft(
                    defaultWeight: _formatWeight(set.displayWeightKg),
                    defaultReps: definition.usesDurationSets
                        ? _formatDurationSeconds(set.inputDurationSeconds)
                        : set.displayReps <= 0
                        ? ''
                        : set.displayReps.toString(),
                  ),
                )
                .toList(),
      defaultDuration: defaultDuration,
      cardioIntensityBasis:
          latestSession?.cardioIntensityBasis ??
          definition.defaultCardioIntensity,
      defaultActiveDuration:
          latestSession?.cardioActiveMinutes?.toString() ?? '',
    );
  }

  factory _ExercisePlanDraft.fromSession(WorkoutSession session) {
    final fallback = ExerciseCatalog.fallbackForSession(
      exerciseName: session.exerciseName,
      bodyPart: session.bodyPart,
      exerciseType: session.exerciseType,
    );
    final definition = fallback.copyWith(
      key: session.exerciseKey ?? fallback.key,
      name: session.exerciseName,
      bodyPart: session.bodyPart,
      secondaryBodyPart: session.secondaryBodyPart,
      strengthProfile: session.strengthProfile ?? fallback.strengthProfile,
      loadInputMode: session.loadInputMode ?? fallback.loadInputMode,
      repsInputMode: session.repsInputMode ?? fallback.repsInputMode,
      setMetricType: session.setMetricType ?? fallback.setMetricType,
      cardioMetByIntensity: fallback.cardioMetByIntensity,
      isBuiltin: session.exerciseSource == null
          ? fallback.isBuiltin
          : session.exerciseSource == ExerciseSource.builtin,
    );
    final draft = _ExercisePlanDraft(
      definition: definition,
      exerciseSource:
          session.exerciseSource ??
          (definition.isBuiltin
              ? ExerciseSource.builtin
              : ExerciseSource.custom),
      sets: session.exerciseType == ExerciseType.cardio
          ? <_SetDraft>[]
          : session.sets
                .map(
                  (set) => _SetDraft.existing(
                    weight: _formatWeight(set.displayWeightKg),
                    reps: definition.usesDurationSets
                        ? _formatDurationSeconds(set.inputDurationSeconds)
                        : set.displayReps.toString(),
                    isCompleted: set.isCompleted,
                    completedAt: set.completedAt,
                  ),
                )
                .toList(),
      defaultDuration: '',
      cardioIntensityBasis:
          session.cardioIntensityBasis ?? definition.defaultCardioIntensity,
      defaultActiveDuration: session.cardioActiveMinutes?.toString() ?? '',
    );
    draft.durationController.text = session.durationMinutes.toString();
    draft.activeDurationController.text =
        session.cardioActiveMinutes?.toString() ?? '';
    return draft;
  }

  factory _ExercisePlanDraft.fromJson(Map<String, dynamic> map) {
    final rawSets = map['sets'];
    final sets = rawSets is List
        ? rawSets
              .whereType<Map>()
              .map((entry) => _SetDraft.fromJson(entry.cast<String, dynamic>()))
              .toList()
        : <_SetDraft>[];
    final exerciseName = (map['exercise_name'] ?? '').toString();
    final bodyPart = (map['body_part'] ?? '').toString();
    final exerciseType = (map['exercise_type'] ?? '').toString().trim().isEmpty
        ? (bodyPart == 'Cardio' ? ExerciseType.cardio : ExerciseType.strength)
        : map['exercise_type'].toString();
    final fallback = ExerciseCatalog.fallbackForSession(
      exerciseName: exerciseName,
      bodyPart: bodyPart,
      exerciseType: exerciseType,
    );
    final definition = fallback.copyWith(
      key: (map['exercise_key'] ?? fallback.key).toString(),
      name: exerciseName,
      bodyPart: bodyPart,
      secondaryBodyPart: map['secondary_body_part']?.toString(),
      strengthProfile: (map['strength_profile'] ?? fallback.strengthProfile)
          .toString(),
      loadInputMode: (map['load_input_mode'] ?? fallback.loadInputMode)
          .toString(),
      repsInputMode: (map['reps_input_mode'] ?? fallback.repsInputMode)
          .toString(),
      setMetricType: (map['set_metric_type'] ?? fallback.setMetricType)
          .toString(),
      isBuiltin: map['exercise_source'] == null
          ? fallback.isBuiltin
          : map['exercise_source'] == ExerciseSource.builtin,
    );
    final draft = _ExercisePlanDraft(
      definition: definition,
      exerciseSource: (map['exercise_source'] ?? ExerciseSource.builtin)
          .toString(),
      sets: sets,
      defaultDuration: (map['default_duration'] ?? '').toString(),
      cardioIntensityBasis:
          (map['cardio_intensity_basis'] ?? definition.defaultCardioIntensity)
              .toString(),
      defaultActiveDuration: (map['default_active_duration'] ?? '').toString(),
    );
    draft.durationController.text = (map['duration_text'] ?? '').toString();
    draft.activeDurationController.text = (map['active_duration_text'] ?? '')
        .toString();
    return draft;
  }

  final ExerciseDefinition definition;
  String exerciseSource;
  final List<_SetDraft> sets;
  final String _defaultDuration;
  final String _defaultActiveDuration;
  final TextEditingController durationController;
  final TextEditingController activeDurationController;
  String cardioIntensityBasis;

  String get exerciseKey => definition.key;
  String get bodyPart => definition.bodyPart;
  String? get secondaryBodyPart => definition.secondaryBodyPart;
  String get exerciseName => definition.name;
  String get exerciseType => definition.exerciseType;
  String get strengthProfile => definition.strengthProfile;
  String get loadInputMode => definition.loadInputMode;
  String get repsInputMode => definition.repsInputMode;
  String get setMetricType => definition.setMetricType;
  bool get isCardio => definition.isCardio;
  bool get usesDurationSets => definition.usesDurationSets;
  bool get usesBodyweightLoad =>
      definition.usesBodyweight || definition.usesAssistance;
  bool get usesAssistanceLoad => definition.usesAssistance;
  bool get usesIntervalCardio =>
      cardioIntensityBasis == CardioIntensityBasis.intervalUnder3;
  List<_SetDraft> get completedSets =>
      sets.where((set) => set.isCompleted).toList();

  String get defaultDurationHint => _defaultDuration;
  String get effectiveDurationText {
    final typed = durationController.text.trim();
    return typed.isNotEmpty ? typed : _defaultDuration;
  }

  String get effectiveActiveDurationText {
    final typed = activeDurationController.text.trim();
    return typed.isNotEmpty ? typed : _defaultActiveDuration;
  }

  String weightLabel(AppStrings strings) {
    switch (loadInputMode) {
      case ExerciseLoadInputMode.perSideLoad:
        return strings.perSideWeightKgShortLabel;
      case ExerciseLoadInputMode.bodyweightAdded:
        return strings.addedWeightKgShortLabel;
      case ExerciseLoadInputMode.assistanceLoad:
        return strings.assistWeightKgShortLabel;
      case ExerciseLoadInputMode.totalLoad:
      default:
        return strings.weightKgShortLabel;
    }
  }

  String metricLabel(AppStrings strings) {
    if (usesDurationSets) {
      return strings.setDurationLabel;
    }
    if (repsInputMode == ExerciseRepsInputMode.perSide) {
      return strings.perSideRepsLabel;
    }
    return strings.repsLabel;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'exercise_key': exerciseKey,
      'exercise_source': exerciseSource,
      'body_part': bodyPart,
      'secondary_body_part': secondaryBodyPart,
      'exercise_name': exerciseName,
      'exercise_type': exerciseType,
      'strength_profile': strengthProfile,
      'load_input_mode': loadInputMode,
      'reps_input_mode': repsInputMode,
      'set_metric_type': setMetricType,
      'cardio_intensity_basis': cardioIntensityBasis,
      'default_duration': _defaultDuration,
      'duration_text': durationController.text.trim(),
      'default_active_duration': _defaultActiveDuration,
      'active_duration_text': activeDurationController.text.trim(),
      'sets': sets.map((set) => set.toJson()).toList(),
    };
  }

  String snapshotJson() => jsonEncode(<String, dynamic>{
    'exercise_key': exerciseKey,
    'exercise_source': exerciseSource,
    'body_part': bodyPart,
    'secondary_body_part': secondaryBodyPart,
    'exercise_name': exerciseName,
    'exercise_type': exerciseType,
    'strength_profile': strengthProfile,
    'load_input_mode': loadInputMode,
    'reps_input_mode': repsInputMode,
    'set_metric_type': setMetricType,
    'cardio_intensity_basis': cardioIntensityBasis,
  });

  static String _formatWeight(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  static String _formatDurationSeconds(int? value) {
    final seconds = value ?? 0;
    if (seconds <= 0) {
      return '';
    }
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes <= 0) {
      return seconds.toString();
    }
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void dispose() {
    durationController.dispose();
    activeDurationController.dispose();
    for (final set in sets) {
      set.dispose();
    }
  }
}

class _ExerciseOption {
  const _ExerciseOption({required this.definition});

  final ExerciseDefinition definition;

  String get bodyPart => definition.bodyPart;
  String get groupKey =>
      definition.isBuiltin ? definition.bodyPart : _customExerciseGroupKey;
  bool get isCustom => !definition.isBuiltin;
  String get name => definition.name;

  String key() => definition.key;
}

class _CustomExercisePage extends StatefulWidget {
  const _CustomExercisePage();

  @override
  State<_CustomExercisePage> createState() => _CustomExercisePageState();
}

class _CustomExercisePageState extends State<_CustomExercisePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isCardio = false;
  String _bodyPart = 'Chest';
  String? _secondaryBodyPart;
  String _strengthStructure = ExerciseStructure.compound;
  String _loadInputMode = ExerciseLoadInputMode.totalLoad;
  String _repsInputMode = ExerciseRepsInputMode.totalReps;
  String _setMetricType = ExerciseSetMetricType.reps;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final name = _nameController.text.trim();
    final key =
        'custom_${DateTime.now().microsecondsSinceEpoch}_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
    final bodyPart = _isCardio ? 'Cardio' : _bodyPart;
    final structure = bodyPart == 'Full Body'
        ? ExerciseStructure.fullBodyAuto
        : _strengthStructure;
    final definition = ExerciseDefinition(
      key: key,
      name: name,
      bodyPart: bodyPart,
      exerciseType: _isCardio ? ExerciseType.cardio : ExerciseType.strength,
      secondaryBodyPart: _isCardio ? null : _secondaryBodyPart,
      strengthStructure: structure,
      strengthProfile: _isCardio
          ? ExerciseStrengthProfile.upperBodyCompound
          : _resolveStrengthProfile(bodyPart, structure),
      loadInputMode: _isCardio
          ? ExerciseLoadInputMode.totalLoad
          : _loadInputMode,
      repsInputMode: _isCardio
          ? ExerciseRepsInputMode.totalReps
          : _repsInputMode,
      setMetricType: _isCardio ? ExerciseSetMetricType.reps : _setMetricType,
      defaultCardioIntensity: CardioIntensityBasis.moderate30To60,
      cardioMetByIntensity: _isCardio
          ? ExerciseCatalog.genericCardioMetByIntensity
          : const <String, double>{},
      isBuiltin: false,
    );
    Navigator.of(context).pop(definition);
  }

  Future<void> _pickStringValue({
    required String title,
    required String currentValue,
    required List<String> options,
    required String Function(String value) labelBuilder,
    required ValueChanged<String> onPicked,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: options.map((value) {
                    final selected = value == currentValue;
                    return ListTile(
                      title: Text(labelBuilder(value)),
                      trailing: selected
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => Navigator.of(context).pop(value),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      onPicked(selected);
    }
  }

  Future<void> _pickNullableStringValue({
    required String title,
    required String? currentValue,
    required List<String?> options,
    required String Function(String? value) labelBuilder,
    required ValueChanged<String?> onPicked,
  }) async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: options.map((value) {
                    final selected = value == currentValue;
                    return ListTile(
                      title: Text(labelBuilder(value)),
                      trailing: selected
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => Navigator.of(context).pop(value),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null || currentValue != null) {
      onPicked(selected);
    }
  }

  String _resolveStrengthProfile(String bodyPart, String structure) {
    if (bodyPart == 'Full Body') {
      return ExerciseStrengthProfile.fullBodyPowerOrHighDensity;
    }
    if (structure == ExerciseStructure.isolation) {
      return ExerciseStrengthProfile.isolation;
    }
    if (bodyPart == 'Legs' || bodyPart == 'Glutes') {
      return ExerciseStrengthProfile.lowerBodyCompound;
    }
    return ExerciseStrengthProfile.upperBodyCompound;
  }

  String _primaryBodyPartTileLabel(AppStrings strings) {
    return strings.isChinese ? '主要部位' : 'Primary';
  }

  String _secondaryBodyPartTileLabel(AppStrings strings) {
    return strings.isChinese ? '副部位' : 'Secondary';
  }

  String _structureTileLabel(AppStrings strings) {
    return strings.isChinese ? '动作结构' : 'Structure';
  }

  String _loadRuleTileLabel(AppStrings strings) {
    return strings.isChinese ? '重量口径' : 'Load';
  }

  String _entryRuleTileLabel(AppStrings strings) {
    return strings.isChinese ? '组内填写' : 'Entry';
  }

  String _repsRuleTileLabel(AppStrings strings) {
    if (_setMetricType == ExerciseSetMetricType.durationSeconds) {
      return strings.isChinese ? '时长统计' : 'Duration';
    }
    return strings.isChinese ? '次数统计' : 'Reps';
  }

  String _shortLoadInputModeLabel(AppStrings strings) {
    switch (_loadInputMode) {
      case ExerciseLoadInputMode.perSideLoad:
        return strings.isChinese ? '每侧重量' : 'Per-side';
      case ExerciseLoadInputMode.bodyweightAdded:
        return strings.isChinese ? '自重加重' : 'Added load';
      case ExerciseLoadInputMode.assistanceLoad:
        return strings.isChinese ? '辅助重量' : 'Assistance';
      case ExerciseLoadInputMode.totalLoad:
      default:
        return strings.isChinese ? '总重量' : 'Total load';
    }
  }

  String _shortSetMetricTypeLabel(AppStrings strings) {
    if (_setMetricType == ExerciseSetMetricType.durationSeconds) {
      return strings.isChinese ? '时长' : 'Duration';
    }
    return strings.isChinese ? '次数' : 'Reps';
  }

  String _shortRepsInputModeLabel(AppStrings strings) {
    if (_setMetricType == ExerciseSetMetricType.durationSeconds) {
      return strings.isChinese ? '总时长' : 'Total duration';
    }
    switch (_repsInputMode) {
      case ExerciseRepsInputMode.perSide:
        return strings.isChinese ? '每侧次数' : 'Per-side reps';
      case ExerciseRepsInputMode.totalReps:
      default:
        return strings.isChinese ? '总次数' : 'Total reps';
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final fitTheme = context.fitLogTheme;
    final strengthBodyParts = AppConstants.bodyParts
        .where((part) => part != 'Cardio')
        .toList();
    final secondaryOptions = <String?>[null, ...strengthBodyParts];
    final pageTitleStyle = Theme.of(
      context,
    ).appBarTheme.titleTextStyle?.copyWith(color: fitTheme.textPrimary);
    final contentBottomPadding = MediaQuery.paddingOf(context).bottom + 124;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 12, 16, contentBottomPadding),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 18),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: fitTheme.textPrimary,
                      iconSize: 32,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        strings.customExercise,
                        style: pageTitleStyle,
                      ),
                    ),
                  ],
                ),
              ),
              _CustomExerciseModeToggle(
                isCardio: _isCardio,
                strengthLabel: strings.strengthExercise,
                cardioLabel: strings.cardioExercise,
                onChanged: (isCardio) => setState(() => _isCardio = isCardio),
              ),
              const SizedBox(height: 12),
              _CustomExerciseSectionCard(
                icon: const Icon(Icons.person_outline_rounded),
                title: strings.isChinese ? '动作名称' : 'Exercise Name',
                child: TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: strings.exerciseNameLabel,
                  ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: fitTheme.textPrimary,
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return strings.exerciseNameRequired;
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (!_isCardio) ...<Widget>[
                _CustomExerciseSectionCard(
                  icon: const Icon(Icons.sell_outlined),
                  title: strings.isChinese ? '动作归类' : 'Exercise Category',
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final stackTwoColumnTiles = constraints.maxWidth < 290;
                      final primaryTile = _CustomExerciseInfoTile(
                        label: _primaryBodyPartTileLabel(strings),
                        value: strings.bodyPartLabel(_bodyPart),
                        leading: FitLogAssetIcon(
                          assetName: fitLogWorkoutAssetForBodyPart(_bodyPart),
                          size: 30,
                        ),
                        compact: true,
                        onTap: () => _pickStringValue(
                          title: strings.primaryBodyPart,
                          currentValue: _bodyPart,
                          options: strengthBodyParts,
                          labelBuilder: strings.bodyPartLabel,
                          onPicked: (value) {
                            setState(() {
                              _bodyPart = value;
                              if (_secondaryBodyPart == value) {
                                _secondaryBodyPart = null;
                              }
                            });
                          },
                        ),
                      );
                      final secondaryTile = _CustomExerciseInfoTile(
                        label: _secondaryBodyPartTileLabel(strings),
                        value: _secondaryBodyPart == null
                            ? strings.noneOption
                            : strings.bodyPartLabel(_secondaryBodyPart!),
                        leading: const Icon(Icons.hub_rounded),
                        compact: true,
                        onTap: () => _pickNullableStringValue(
                          title: strings.secondaryBodyPartOptional,
                          currentValue: _secondaryBodyPart,
                          options: secondaryOptions
                              .where(
                                (part) => part == null || part != _bodyPart,
                              )
                              .toList(),
                          labelBuilder: (value) => value == null
                              ? strings.noneOption
                              : strings.bodyPartLabel(value),
                          onPicked: (value) {
                            setState(() => _secondaryBodyPart = value);
                          },
                        ),
                      );

                      return Column(
                        children: <Widget>[
                          if (stackTwoColumnTiles)
                            Column(
                              children: <Widget>[
                                primaryTile,
                                const SizedBox(height: 12),
                                secondaryTile,
                              ],
                            )
                          else
                            Row(
                              children: <Widget>[
                                Expanded(child: primaryTile),
                                const SizedBox(width: 10),
                                Expanded(child: secondaryTile),
                              ],
                            ),
                          const SizedBox(height: 12),
                          _CustomExerciseInfoTile(
                            label: _structureTileLabel(strings),
                            value: _bodyPart == 'Full Body'
                                ? strings.isChinese
                                      ? '全身动作'
                                      : 'Full-body movement'
                                : strings.exerciseStructureLabelFor(
                                    _strengthStructure,
                                  ),
                            leading: const Icon(Icons.layers_outlined),
                            onTap: _bodyPart == 'Full Body'
                                ? null
                                : () => _pickStringValue(
                                    title: strings.exerciseStructureLabel,
                                    currentValue: _strengthStructure,
                                    options: const <String>[
                                      ExerciseStructure.compound,
                                      ExerciseStructure.isolation,
                                    ],
                                    labelBuilder:
                                        strings.exerciseStructureLabelFor,
                                    onPicked: (value) {
                                      setState(
                                        () => _strengthStructure = value,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _CustomExerciseSectionCard(
                  icon: const Icon(Icons.tune_rounded),
                  title: strings.isChinese ? '记录规则' : 'Recording Rules',
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final stackRuleTiles = constraints.maxWidth < 290;
                      final loadTile = _CustomExerciseInfoTile(
                        label: _loadRuleTileLabel(strings),
                        value: _shortLoadInputModeLabel(strings),
                        leading: const Icon(Icons.fitness_center_rounded),
                        onTap: () => _pickStringValue(
                          title: strings.loadInputMode,
                          currentValue: _loadInputMode,
                          options: const <String>[
                            ExerciseLoadInputMode.totalLoad,
                            ExerciseLoadInputMode.perSideLoad,
                            ExerciseLoadInputMode.bodyweightAdded,
                            ExerciseLoadInputMode.assistanceLoad,
                          ],
                          labelBuilder: strings.loadInputModeLabel,
                          onPicked: (value) {
                            setState(() => _loadInputMode = value);
                          },
                        ),
                      );
                      final entryTile = _CustomExerciseInfoTile(
                        label: _entryRuleTileLabel(strings),
                        value: _shortSetMetricTypeLabel(strings),
                        leading: const Icon(Icons.edit_rounded),
                        compact: true,
                        onTap: () => _pickStringValue(
                          title: strings.setEntryMode,
                          currentValue: _setMetricType,
                          options: const <String>[
                            ExerciseSetMetricType.reps,
                            ExerciseSetMetricType.durationSeconds,
                          ],
                          labelBuilder: strings.setMetricTypeLabel,
                          onPicked: (value) {
                            setState(() => _setMetricType = value);
                          },
                        ),
                      );
                      final repsTile = _CustomExerciseInfoTile(
                        label: _repsRuleTileLabel(strings),
                        value: _shortRepsInputModeLabel(strings),
                        leading: const Icon(Icons.bar_chart_rounded),
                        compact: true,
                        onTap: _setMetricType == ExerciseSetMetricType.reps
                            ? () => _pickStringValue(
                                title: strings.repsInputMode,
                                currentValue: _repsInputMode,
                                options: const <String>[
                                  ExerciseRepsInputMode.totalReps,
                                  ExerciseRepsInputMode.perSide,
                                ],
                                labelBuilder: strings.repsInputModeLabel,
                                onPicked: (value) {
                                  setState(() => _repsInputMode = value);
                                },
                              )
                            : null,
                      );

                      if (stackRuleTiles) {
                        return Column(
                          children: <Widget>[
                            loadTile,
                            const SizedBox(height: 12),
                            entryTile,
                            const SizedBox(height: 12),
                            repsTile,
                          ],
                        );
                      }

                      return Column(
                        children: <Widget>[
                          loadTile,
                          const SizedBox(height: 12),
                          Row(
                            children: <Widget>[
                              Expanded(child: entryTile),
                              const SizedBox(width: 10),
                              Expanded(child: repsTile),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ] else ...<Widget>[
                _CustomExerciseSectionCard(
                  icon: const Icon(Icons.tune_rounded),
                  title: strings.isChinese ? '记录规则' : 'Recording Rules',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _CustomExerciseInfoTile(
                        label: strings.isChinese ? '主要记录' : 'Primary record',
                        value: strings.isChinese ? '时长' : 'Duration',
                        leading: const Icon(Icons.timelapse_rounded),
                      ),
                      const SizedBox(height: 12),
                      _CustomExerciseInfoTile(
                        label: strings.isChinese ? '辅助记录' : 'Secondary record',
                        value: strings.isChinese ? '本次强度' : 'Session intensity',
                        leading: const Icon(Icons.speed_rounded),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        strings.customCardioDefinitionHint,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6A7A66),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _CustomExerciseTinyChip(
                            label: strings.isChinese ? '不记录：重量' : 'No weight',
                          ),
                          _CustomExerciseTinyChip(
                            label: strings.isChinese ? '不记录：次数' : 'No reps',
                          ),
                          _CustomExerciseTinyChip(
                            label: strings.isChinese ? '不记录：组数' : 'No sets',
                          ),
                          _CustomExerciseTinyChip(
                            label: strings.isChinese
                                ? '不记录：部位'
                                : 'No body part',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check_rounded),
          label: Text(strings.addExercise),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(62),
            backgroundColor: fitTheme.primary,
            foregroundColor: fitTheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: fitTheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomExerciseModeToggle extends StatelessWidget {
  const _CustomExerciseModeToggle({
    required this.isCardio,
    required this.strengthLabel,
    required this.cardioLabel,
    required this.onChanged,
  });

  final bool isCardio;
  final String strengthLabel;
  final String cardioLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    Widget buildSegment({
      required bool value,
      required String label,
      required IconData icon,
    }) {
      final selected = isCardio == value;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onChanged(value),
            child: SizedBox(
              height: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    icon,
                    color: selected ? fitTheme.primaryDeep : fitTheme.mutedText,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? fitTheme.primaryDeep
                          : fitTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 336),
        child: Container(
          height: 72,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: fitTheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: fitTheme.outline),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: fitTheme.shadow.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final thumbWidth = (constraints.maxWidth - 4) / 2;
              return Stack(
                children: <Widget>[
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: isCardio
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: thumbWidth,
                      height: 64,
                      decoration: BoxDecoration(
                        color: fitTheme.primarySoftSelected,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: fitTheme.primaryBright),
                      ),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      buildSegment(
                        value: false,
                        label: strengthLabel,
                        icon: Icons.fitness_center_rounded,
                      ),
                      buildSegment(
                        value: true,
                        label: cardioLabel,
                        icon: Icons.directions_run_rounded,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CustomExerciseSectionCard extends StatelessWidget {
  const _CustomExerciseSectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final Widget icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    return GlassPanel(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(18),
      borderRadius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: fitTheme.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: IconTheme(
                  data: IconThemeData(color: fitTheme.primaryDeep, size: 24),
                  child: icon,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: fitTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _CustomExerciseInfoTile extends StatelessWidget {
  const _CustomExerciseInfoTile({
    required this.label,
    required this.value,
    required this.leading,
    this.onTap,
    this.compact = false,
  });

  final String label;
  final String value;
  final Widget leading;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    final tile = Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 14,
        compact ? 11 : 12,
        compact ? 12 : 14,
        compact ? 11 : 12,
      ),
      decoration: BoxDecoration(
        color: fitTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: fitTheme.outline),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: compact ? 28 : 32,
            height: compact ? 28 : 32,
            child: IconTheme(
              data: IconThemeData(
                color: fitTheme.primaryDeep,
                size: compact ? 22 : 24,
              ),
              child: Center(child: leading),
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style:
                      (compact
                              ? Theme.of(context).textTheme.bodyMedium
                              : Theme.of(context).textTheme.bodySmall)
                          ?.copyWith(
                            color: fitTheme.mutedText,
                            fontWeight: FontWeight.w700,
                          ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: compact ? 3 : 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: fitTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              color: fitTheme.mutedText,
              size: compact ? 20 : 24,
            ),
        ],
      ),
    );

    if (onTap == null) {
      return tile;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: tile,
    );
  }
}

class _CustomExerciseTinyChip extends StatelessWidget {
  const _CustomExerciseTinyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: fitTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fitTheme.outline),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: fitTheme.textSecondary,
        ),
      ),
    );
  }
}

class _ExerciseLibraryPickerPage extends StatefulWidget {
  const _ExerciseLibraryPickerPage({
    required this.options,
    required this.initiallySelectedKeys,
  });

  final List<_ExerciseOption> options;
  final List<String> initiallySelectedKeys;

  @override
  State<_ExerciseLibraryPickerPage> createState() =>
      _ExerciseLibraryPickerPageState();
}

class _ExerciseLibraryPickerPageState
    extends State<_ExerciseLibraryPickerPage> {
  final _searchController = TextEditingController();
  String? _selectedBodyPartFilter;
  String? _openCustomDeleteKey;
  late List<_ExerciseOption> _options;
  late final List<String> _selectedKeysInOrder;

  @override
  void initState() {
    super.initState();
    _options = List<_ExerciseOption>.from(widget.options);
    _selectedKeysInOrder = List<String>.from(widget.initiallySelectedKeys);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_ExerciseOption> _filteredOptions(AppStrings strings) {
    final queryLower = _searchController.text.trim().toLowerCase();
    return _options.where((option) {
      final bodyPartMatch =
          _selectedBodyPartFilter == null ||
          option.groupKey == _selectedBodyPartFilter;
      if (!bodyPartMatch) {
        return false;
      }
      if (queryLower.isEmpty) {
        return true;
      }
      final candidates = <String>{
        option.name.toLowerCase(),
        strings.exerciseDisplayName(option.name).toLowerCase(),
        option.bodyPart.toLowerCase(),
        strings.bodyPartLabel(option.bodyPart).toLowerCase(),
        option.isCustom ? _customExerciseGroupLabel(strings).toLowerCase() : '',
      };
      return candidates.any((value) => value.contains(queryLower));
    }).toList();
  }

  List<_ExerciseOption> get _customOptions =>
      _options.where((option) => option.isCustom).toList();

  List<String> _filterKeys() {
    final keys = <String>[
      ...AppConstants.bodyParts,
      if (_customOptions.isNotEmpty) _customExerciseGroupKey,
    ];
    return keys;
  }

  void _toggleOption(_ExerciseOption option) {
    final key = option.key();
    setState(() {
      _openCustomDeleteKey = null;
      if (_selectedKeysInOrder.contains(key)) {
        _selectedKeysInOrder.remove(key);
      } else {
        _selectedKeysInOrder.add(key);
      }
    });
  }

  void _submitSelection() {
    Navigator.of(context).pop(List<String>.from(_selectedKeysInOrder));
  }

  Future<bool> _deleteCustomOption(_ExerciseOption option) async {
    final strings = context.stringsRead;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_deleteCustomExerciseTitle(strings)),
          content: Text(
            _deleteCustomExerciseMessage(
              strings,
              strings.exerciseDisplayName(option.name),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.notNow),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(strings.delete),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return false;
    }

    try {
      await context.read<AppServices>().customExerciseRepository.hideDefinition(
        option.key(),
      );
    } catch (_) {
      if (!mounted) {
        return false;
      }
      FitLogNotifications.error(
        context,
        _customExerciseDeleteFailedLabel(strings),
      );
      return false;
    }
    if (!mounted) {
      return false;
    }

    setState(() {
      _openCustomDeleteKey = null;
      _options.removeWhere((candidate) => candidate.key() == option.key());
      _selectedKeysInOrder.remove(option.key());
      if (_selectedBodyPartFilter == _customExerciseGroupKey &&
          _customOptions.isEmpty) {
        _selectedBodyPartFilter = null;
      }
    });
    FitLogNotifications.success(context, _customExerciseDeletedLabel(strings));
    return true;
  }

  Widget _buildExerciseOptionTile(
    BuildContext context,
    _ExerciseOption option,
    bool selected,
    int selectedIndex,
  ) {
    final strings = context.strings;
    final color = ExerciseVisuals.colorForBodyPart(option.bodyPart, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: selected
            ? color.withValues(alpha: 0.16)
            : Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
      ),
      child: Row(
        children: <Widget>[
          ExerciseThumbnail(
            bodyPart: option.bodyPart,
            exerciseName: option.name,
            color: color,
            size: 54,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.exerciseDisplayName(option.name),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  option.isCustom
                      ? _customExerciseSummary(option, strings)
                      : strings.bodyPartLabel(option.bodyPart),
                ),
              ],
            ),
          ),
          selected
              ? Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                  child: Text(
                    '${selectedIndex + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : const Icon(Icons.radio_button_unchecked),
        ],
      ),
    );
  }

  Widget _buildCustomDeleteAction(AppStrings strings, VoidCallback onDelete) {
    return SizedBox(
      width: _CustomExerciseSwipeDeleteTile.deleteActionWidth,
      child: Material(
        color: const Color(0xFFCE3D3D),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onDelete,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.delete_outline_rounded, color: Colors.white),
                const SizedBox(height: 4),
                Text(
                  strings.delete,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomSwipeTile(
    _ExerciseOption option,
    Widget child,
    VoidCallback onTap,
  ) {
    final key = option.key();
    return _CustomExerciseSwipeDeleteTile(
      key: ValueKey<String>('custom-delete-$key'),
      open: _openCustomDeleteKey == key,
      deleteAction: _buildCustomDeleteAction(context.strings, () {
        _deleteCustomOption(option);
      }),
      onOpenChanged: (open) {
        setState(() {
          _openCustomDeleteKey = open ? key : null;
        });
      },
      onTap: onTap,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final filtered = _filteredOptions(strings);

    return Scaffold(
      appBar: AppBar(title: Text(strings.exercisesLibrary)),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: strings.searchExercise,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: _selectedBodyPartFilter == null,
                          label: Text(strings.allBodyParts),
                          onSelected: (_) {
                            setState(() => _selectedBodyPartFilter = null);
                          },
                        ),
                      ),
                      ..._filterKeys().map((bodyPart) {
                        final label = bodyPart == _customExerciseGroupKey
                            ? _customExerciseGroupLabel(strings)
                            : strings.bodyPartLabel(bodyPart);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            selected: _selectedBodyPartFilter == bodyPart,
                            label: Text(label),
                            onSelected: (_) {
                              setState(
                                () => _selectedBodyPartFilter = bodyPart,
                              );
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                filtered.isEmpty &&
                    _selectedBodyPartFilter == _customExerciseGroupKey &&
                    _searchController.text.trim().isEmpty
                ? Center(
                    child: Text(
                      _noSavedCustomExercisesLabel(strings),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final option = filtered[index];
                      final key = option.key();
                      final selectedIndex = _selectedKeysInOrder.indexOf(key);
                      final selected = selectedIndex >= 0;
                      final tile = InkWell(
                        onTap: () => _toggleOption(option),
                        borderRadius: BorderRadius.circular(14),
                        child: _buildExerciseOptionTile(
                          context,
                          option,
                          selected,
                          selectedIndex,
                        ),
                      );
                      final canDeleteInline =
                          _selectedBodyPartFilter == _customExerciseGroupKey &&
                          option.isCustom;
                      if (!canDeleteInline) {
                        return tile;
                      }
                      return _buildCustomSwipeTile(
                        option,
                        _buildExerciseOptionTile(
                          context,
                          option,
                          selected,
                          selectedIndex,
                        ),
                        () => _toggleOption(option),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: FilledButton(
            onPressed: _submitSelection,
            child: Text(
              strings.addExercisesWithCount(_selectedKeysInOrder.length),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomExerciseSwipeDeleteTile extends StatefulWidget {
  const _CustomExerciseSwipeDeleteTile({
    super.key,
    required this.child,
    required this.deleteAction,
    required this.open,
    required this.onOpenChanged,
    required this.onTap,
  });

  static const double deleteActionWidth = 88;

  final Widget child;
  final Widget deleteAction;
  final bool open;
  final ValueChanged<bool> onOpenChanged;
  final VoidCallback onTap;

  @override
  State<_CustomExerciseSwipeDeleteTile> createState() =>
      _CustomExerciseSwipeDeleteTileState();
}

class _CustomExerciseSwipeDeleteTileState
    extends State<_CustomExerciseSwipeDeleteTile> {
  double _dragExtent = 0;
  bool _dragging = false;

  @override
  void didUpdateWidget(_CustomExerciseSwipeDeleteTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.open && _dragExtent != 0) {
      _dragExtent = 0;
    } else if (widget.open && _dragExtent == 0) {
      _dragExtent = _CustomExerciseSwipeDeleteTile.deleteActionWidth;
    }
  }

  void _setOpen(bool open) {
    setState(() {
      _dragging = false;
      _dragExtent = open ? _CustomExerciseSwipeDeleteTile.deleteActionWidth : 0;
    });
    widget.onOpenChanged(open);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final nextExtent = (_dragExtent - details.delta.dx)
        .clamp(0, _CustomExerciseSwipeDeleteTile.deleteActionWidth)
        .toDouble();
    setState(() {
      _dragging = true;
      _dragExtent = nextExtent;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final shouldOpen =
        _dragExtent >= _CustomExerciseSwipeDeleteTile.deleteActionWidth * 0.35;
    _setOpen(shouldOpen);
  }

  void _handleTap() {
    if (_dragExtent > 0 || widget.open) {
      _setOpen(false);
      return;
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final duration = _dragging
        ? Duration.zero
        : const Duration(milliseconds: 160);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: <Widget>[
          const SizedBox(height: 70),
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: _CustomExerciseSwipeDeleteTile.deleteActionWidth,
            child: widget.deleteAction,
          ),
          AnimatedPositioned(
            duration: duration,
            curve: Curves.easeOutCubic,
            top: 0,
            left: -_dragExtent,
            right: _dragExtent,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleTap,
              onHorizontalDragUpdate: _handleDragUpdate,
              onHorizontalDragEnd: _handleDragEnd,
              onHorizontalDragCancel: () => _setOpen(widget.open),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _customExerciseSummary(_ExerciseOption option, AppStrings strings) {
  if (option.definition.exerciseType == ExerciseType.cardio) {
    return strings.isChinese ? '自定义有氧' : 'Custom cardio';
  }
  final bodyPart = strings.bodyPartLabel(option.bodyPart);
  return strings.isChinese ? '自定义 · $bodyPart' : 'Custom · $bodyPart';
}
