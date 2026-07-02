import 'dart:convert';

import '../../core/constants/exercise_catalog.dart';
import '../../core/constants/exercise_definition.dart';
import '../../core/utils/number_utils.dart';
import 'workout_record_draft.dart';

const String aiWorkoutDraftSchemaVersion = 'workout_draft.v1';

class AiWorkoutDraft {
  const AiWorkoutDraft({
    required this.recordName,
    required this.date,
    required this.notes,
    required this.exercises,
  });

  final String recordName;
  final String? date;
  final String notes;
  final List<AiWorkoutDraftExercise> exercises;

  factory AiWorkoutDraft.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schema_version']?.toString();
    if (schemaVersion != null && schemaVersion != aiWorkoutDraftSchemaVersion) {
      throw FormatException('Unsupported workout draft schema: $schemaVersion');
    }
    final exercises = _exerciseList(json['exercises']);
    if (exercises.isEmpty) {
      throw const FormatException('Workout draft requires exercises.');
    }
    final firstName = exercises.first.exerciseName.trim();
    return AiWorkoutDraft(
      recordName:
          _stringOrNull(json['record_name']) ??
          (firstName.isEmpty ? 'Workout record' : firstName),
      date: _validDateOrNull(json['date']),
      notes: _stringOrNull(json['notes']) ?? '',
      exercises: exercises,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schema_version': aiWorkoutDraftSchemaVersion,
      'record_name': recordName,
      'date': date,
      'notes': notes,
      'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
    };
  }

  WorkoutRecordDraft toWorkoutRecordDraft({
    required String dateFallback,
    DateTime? now,
  }) {
    final resolvedDate = date ?? dateFallback;
    final timestamp = (now ?? DateTime.now()).toIso8601String();
    final payload = <String, dynamic>{
      'kind': WorkoutRecordDraft.kindNewRecord,
      'date': resolvedDate,
      'record_name': recordName,
      'notes': notes,
      'exercises': exercises
          .map((exercise) => exercise.toWorkoutPayload())
          .toList(),
    };
    return WorkoutRecordDraft(
      id: WorkoutRecordDraft.activeDraftId,
      kind: WorkoutRecordDraft.kindNewRecord,
      date: resolvedDate,
      recordName: recordName,
      notes: notes,
      payloadJson: jsonEncode(payload),
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }
}

class AiWorkoutDraftExercise {
  const AiWorkoutDraftExercise({
    required this.exerciseName,
    this.exerciseKey,
    this.exerciseType,
    this.bodyPart,
    this.durationMinutes,
    this.activeDurationMinutes,
    this.cardioIntensityBasis,
    this.sets = const <AiWorkoutDraftSet>[],
  });

  final String exerciseName;
  final String? exerciseKey;
  final String? exerciseType;
  final String? bodyPart;
  final double? durationMinutes;
  final double? activeDurationMinutes;
  final String? cardioIntensityBasis;
  final List<AiWorkoutDraftSet> sets;

  factory AiWorkoutDraftExercise.fromJson(Map<String, dynamic> json) {
    final exerciseName = _stringOrNull(json['exercise_name']) ?? '';
    if (exerciseName.trim().isEmpty) {
      throw const FormatException('Workout exercise name is required.');
    }
    return AiWorkoutDraftExercise(
      exerciseName: exerciseName,
      exerciseKey: _stringOrNull(json['exercise_key']),
      exerciseType: _stringOrNull(json['exercise_type']),
      bodyPart: _stringOrNull(json['body_part']),
      durationMinutes: _positiveDoubleOrNull(json['duration_minutes']),
      activeDurationMinutes: _positiveDoubleOrNull(
        json['active_duration_minutes'],
      ),
      cardioIntensityBasis: _stringOrNull(json['cardio_intensity_basis']),
      sets: _setList(json['sets']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'exercise_name': exerciseName,
      'exercise_key': exerciseKey,
      'exercise_type': exerciseType,
      'body_part': bodyPart,
      'duration_minutes': durationMinutes,
      'active_duration_minutes': activeDurationMinutes,
      'cardio_intensity_basis': cardioIntensityBasis,
      'sets': sets.map((set) => set.toJson()).toList(),
    };
  }

  Map<String, dynamic> toWorkoutPayload() {
    final definition = _resolveDefinition();
    final resolvedType =
        definition?.exerciseType ??
        _normalizeExerciseType(exerciseType, durationMinutes, sets);
    final resolvedBodyPart =
        definition?.bodyPart ??
        _bodyPartFor(bodyPart, resolvedType, exerciseName);
    final durationText = _formatMinutes(durationMinutes);
    final activeDurationText = _formatMinutes(activeDurationMinutes);
    final source = definition == null
        ? ExerciseSource.adHoc
        : ExerciseSource.builtin;
    return <String, dynamic>{
      'exercise_key': definition?.key ?? _adHocKey(exerciseName),
      'exercise_source': source,
      'body_part': resolvedBodyPart,
      'secondary_body_part': definition?.secondaryBodyPart,
      'exercise_name': definition?.name ?? exerciseName.trim(),
      'exercise_type': resolvedType,
      'strength_profile':
          definition?.strengthProfile ??
          _strengthProfileFor(resolvedBodyPart, resolvedType),
      'load_input_mode':
          definition?.loadInputMode ?? ExerciseLoadInputMode.totalLoad,
      'reps_input_mode':
          definition?.repsInputMode ?? ExerciseRepsInputMode.totalReps,
      'set_metric_type':
          definition?.setMetricType ?? ExerciseSetMetricType.reps,
      'cardio_intensity_basis':
          _normalizeCardioIntensity(cardioIntensityBasis) ??
          definition?.defaultCardioIntensity ??
          CardioIntensityBasis.moderate30To60,
      'default_duration': durationText,
      'duration_text': durationText,
      'default_active_duration': activeDurationText,
      'active_duration_text': activeDurationText,
      'sets': sets.map((set) => set.toWorkoutPayload()).toList(),
    };
  }

  ExerciseDefinition? _resolveDefinition() {
    return ExerciseCatalog.byKey(exerciseKey) ??
        ExerciseCatalog.byName(exerciseName) ??
        ExerciseCatalog.byName(_exerciseNameAliases[exerciseName.trim()]);
  }
}

class AiWorkoutDraftSet {
  const AiWorkoutDraftSet({this.weightKg, this.reps, this.durationSeconds});

  final double? weightKg;
  final int? reps;
  final int? durationSeconds;

  factory AiWorkoutDraftSet.fromJson(Map<String, dynamic> json) {
    return AiWorkoutDraftSet(
      weightKg: _positiveDoubleOrNull(json['weight_kg']),
      reps: _positiveIntOrNull(json['reps']),
      durationSeconds: _positiveIntOrNull(json['duration_seconds']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'weight_kg': weightKg,
      'reps': reps,
      'duration_seconds': durationSeconds,
    };
  }

  Map<String, dynamic> toWorkoutPayload() {
    final weight = _formatNumber(weightKg);
    final repsText = durationSeconds == null
        ? (reps == null ? '' : reps.toString())
        : _formatDurationSeconds(durationSeconds);
    return <String, dynamic>{
      'default_weight': weight,
      'default_reps': repsText,
      'weight_text': weight,
      'reps_text': repsText,
      'is_completed': true,
      'show_weight_as_default': weight.isNotEmpty,
      'show_reps_as_default': repsText.isNotEmpty,
    };
  }
}

const Map<String, String> _exerciseNameAliases = <String, String>{
  '卧推': 'Bench Press',
  '杠铃卧推': 'Bench Press',
  '平板卧推': 'Barbell Flat Bench Press',
  '深蹲': 'Squat',
  '硬拉': 'Deadlift',
  '引体向上': 'Pull-up',
  '高位下拉': 'Lat Pulldown',
  '坐姿划船': 'Seated Row',
  '杠铃划船': 'Bent-over Barbell Row',
  '推举': 'Overhead Press',
  '肩推': 'Overhead Press',
  '侧平举': 'Lateral Raise',
  '二头弯举': 'Dumbbell Biceps Curl',
  '跑步': 'Running',
  '慢跑': 'Running',
  '散步': 'Walking',
  '走路': 'Walking',
  '步行': 'Walking',
  '骑车': 'Cycling',
  '骑行': 'Cycling',
  '划船机': 'Rowing Machine',
};

List<AiWorkoutDraftExercise> _exerciseList(Object? value) {
  if (value is! List) {
    return const <AiWorkoutDraftExercise>[];
  }
  return value
      .whereType<Map>()
      .map((item) => AiWorkoutDraftExercise.fromJson(item.cast()))
      .toList(growable: false);
}

List<AiWorkoutDraftSet> _setList(Object? value) {
  if (value is! List) {
    return const <AiWorkoutDraftSet>[];
  }
  return value
      .whereType<Map>()
      .map((item) => AiWorkoutDraftSet.fromJson(item.cast()))
      .toList(growable: false);
}

String? _stringOrNull(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

double? _positiveDoubleOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  final parsed = NumberUtils.toDouble(value, fallback: double.nan);
  return parsed.isFinite && parsed > 0 ? parsed : null;
}

int? _positiveIntOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  final parsed = NumberUtils.toInt(value, fallback: -1);
  return parsed > 0 ? parsed : null;
}

String? _validDateOrNull(Object? value) {
  final text = _stringOrNull(value);
  if (text == null) {
    return null;
  }
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ? text : null;
}

String _normalizeExerciseType(
  String? value,
  double? durationMinutes,
  List<AiWorkoutDraftSet> sets,
) {
  final text = value?.trim();
  if (text == ExerciseType.strength || text == ExerciseType.cardio) {
    return text!;
  }
  return durationMinutes != null && sets.isEmpty
      ? ExerciseType.cardio
      : ExerciseType.strength;
}

String _bodyPartFor(String? value, String exerciseType, String exerciseName) {
  final text = value?.trim();
  if (text != null && text.isNotEmpty) {
    return text;
  }
  if (exerciseType == ExerciseType.cardio) {
    return 'Cardio';
  }
  return exerciseName.contains('深蹲') || exerciseName.contains('硬拉')
      ? 'Legs'
      : 'Full Body';
}

String _strengthProfileFor(String bodyPart, String exerciseType) {
  if (exerciseType == ExerciseType.cardio) {
    return ExerciseStrengthProfile.upperBodyCompound;
  }
  if (bodyPart == 'Legs') {
    return ExerciseStrengthProfile.lowerBodyCompound;
  }
  if (bodyPart == 'Full Body') {
    return ExerciseStrengthProfile.fullBodyPowerOrHighDensity;
  }
  return ExerciseStrengthProfile.upperBodyCompound;
}

String? _normalizeCardioIntensity(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return CardioIntensityBasis.values.contains(text) ? text : null;
}

String _adHocKey(String name) {
  final normalized = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return 'ai_${normalized.isEmpty ? 'workout' : normalized}';
}

String _formatMinutes(double? value) {
  if (value == null || value <= 0) {
    return '';
  }
  return _formatNumber(value);
}

String _formatNumber(double? value) {
  if (value == null || value <= 0 || !value.isFinite) {
    return '';
  }
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

String _formatDurationSeconds(int? value) {
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
