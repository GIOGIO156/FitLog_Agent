import 'package:fitlog_local/core/constants/exercise_definition.dart';
import 'package:fitlog_local/data/db/app_database.dart';
import 'package:fitlog_local/data/repositories/custom_exercise_repository.dart';
import 'package:fitlog_local/domain/services/ai_exercise_reference_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only exact active custom exercise mentions are sent', () async {
    final builder = AiExerciseReferenceBuilder(
      _FakeRepository(<ExerciseDefinition>[
        _custom('custom_per_side', '我的单侧蹲'),
        _custom('custom_other', '我的推举'),
      ]),
    );
    final references = await builder.buildForMessage('记录 我的单侧蹲 3 组，每侧 12 次');
    expect(references, hasLength(1));
    expect(references.single.key, 'custom_per_side');
    expect(references.single.repsInputMode, ExerciseRepsInputMode.perSide);
    expect(references.single.definitionHash, matches(RegExp(r'^[a-f0-9]{8}$')));
  });

  test(
    'duplicate matching custom names remain candidates and cap at four',
    () async {
      final builder = AiExerciseReferenceBuilder(
        _FakeRepository(
          List<ExerciseDefinition>.generate(
            6,
            (index) => _custom('custom_$index', '同名动作'),
          ),
        ),
      );
      final references = await builder.buildForMessage('记录同名动作');
      expect(references, hasLength(4));
      expect(references.map((item) => item.key).toSet(), hasLength(4));
    },
  );

  test('no custom match sends no library data', () async {
    final builder = AiExerciseReferenceBuilder(
      _FakeRepository(<ExerciseDefinition>[_custom('custom', '私有动作')]),
    );
    expect(await builder.buildForMessage('普通聊天'), isEmpty);
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

class _FakeRepository extends CustomExerciseRepository {
  _FakeRepository(this.definitions) : super(AppDatabase.instance);

  final List<ExerciseDefinition> definitions;

  @override
  Future<List<ExerciseDefinition>> getActiveDefinitions() async => definitions;
}
