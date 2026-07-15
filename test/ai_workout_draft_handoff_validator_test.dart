import 'package:fitlog_local/core/constants/exercise_definition.dart';
import 'package:fitlog_local/core/constants/generated/exercise_definition_hashes.dart';
import 'package:fitlog_local/data/db/app_database.dart';
import 'package:fitlog_local/data/repositories/custom_exercise_repository.dart';
import 'package:fitlog_local/domain/models/ai_workout_draft.dart';
import 'package:fitlog_local/domain/services/ai_exercise_reference_builder.dart';
import 'package:fitlog_local/domain/services/ai_workout_draft_handoff_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts current built-in definition hash', () async {
    final draft = _draft(
      key: 'bulgarian_split_squat',
      name: 'Bulgarian Split Squat',
      source: 'builtin',
      hash: exerciseDefinitionHashes['bulgarian_split_squat']!,
      loadMode: ExerciseLoadInputMode.totalLoad,
      repsMode: ExerciseRepsInputMode.perSide,
    );
    await AiWorkoutDraftHandoffValidator(
      _FakeRepository(const <ExerciseDefinition>[]),
    ).validate(draft);
  });

  test('rejects changed or hidden custom definition', () async {
    final current = _custom('custom_split', '我的单侧蹲');
    final hash = aiCustomExerciseDefinitionHash(_hashFields(current));
    final draft = _draft(
      key: current.key,
      name: current.name,
      source: 'custom',
      hash: hash,
      loadMode: current.loadInputMode,
      repsMode: current.repsInputMode,
    );
    await AiWorkoutDraftHandoffValidator(
      _FakeRepository(<ExerciseDefinition>[current]),
    ).validate(draft);
    expect(
      () => AiWorkoutDraftHandoffValidator(
        _FakeRepository(<ExerciseDefinition>[
          current.copyWith(repsInputMode: ExerciseRepsInputMode.totalReps),
        ]),
      ).validate(draft),
      throwsFormatException,
    );
    expect(
      () => AiWorkoutDraftHandoffValidator(
        _FakeRepository(const <ExerciseDefinition>[]),
      ).validate(draft),
      throwsFormatException,
    );
  });
}

AiWorkoutDraft _draft({
  required String key,
  required String name,
  required String source,
  required String hash,
  required String loadMode,
  required String repsMode,
}) {
  return AiWorkoutDraft.fromJson(<String, dynamic>{
    'schema_version': aiWorkoutDraftSchemaVersion,
    'record_name': 'Draft',
    'date': '2026-07-14',
    'notes': '',
    'exercises': <Map<String, dynamic>>[
      <String, dynamic>{
        'exercise_name': name,
        'exercise_key': key,
        'exercise_source': source,
        'definition_hash': hash,
        'exercise_type': ExerciseType.strength,
        'body_part': 'Legs',
        'load_input_mode': loadMode,
        'reps_input_mode': repsMode,
        'set_metric_type': ExerciseSetMetricType.reps,
        'sets': <Map<String, dynamic>>[
          <String, dynamic>{'weight_kg': 20, 'reps': 12},
        ],
      },
    ],
  });
}

ExerciseDefinition _custom(String key, String name) => ExerciseDefinition(
  key: key,
  name: name,
  bodyPart: 'Legs',
  exerciseType: ExerciseType.strength,
  strengthProfile: ExerciseStrengthProfile.lowerBodyCompound,
  loadInputMode: ExerciseLoadInputMode.totalLoad,
  repsInputMode: ExerciseRepsInputMode.perSide,
  setMetricType: ExerciseSetMetricType.reps,
  isBuiltin: false,
);

List<String> _hashFields(ExerciseDefinition definition) => <String>[
  definition.key,
  definition.name,
  definition.exerciseType,
  definition.bodyPart,
  definition.strengthStructure,
  definition.strengthProfile,
  definition.loadInputMode,
  definition.repsInputMode,
  definition.setMetricType,
];

class _FakeRepository extends CustomExerciseRepository {
  _FakeRepository(this.definitions) : super(AppDatabase.instance);

  final List<ExerciseDefinition> definitions;

  @override
  Future<List<ExerciseDefinition>> getActiveDefinitions() async => definitions;
}
