import '../../core/constants/exercise_definition.dart';
import '../../core/constants/generated/exercise_definition_hashes.dart';
import '../../data/repositories/custom_exercise_repository.dart';
import '../models/ai_workout_draft.dart';
import 'ai_exercise_reference_builder.dart';

class AiWorkoutDraftHandoffValidator {
  const AiWorkoutDraftHandoffValidator(this._customExerciseRepository);

  final CustomExerciseRepository _customExerciseRepository;

  Future<void> validate(AiWorkoutDraft draft) async {
    if (draft.schemaVersion != aiWorkoutDraftSchemaVersion) return;
    final customDefinitions = await _customExerciseRepository
        .getActiveDefinitions();
    final customByKey = <String, ExerciseDefinition>{
      for (final definition in customDefinitions) definition.key: definition,
    };
    for (final exercise in draft.exercises) {
      switch (exercise.exerciseSource) {
        case ExerciseSource.builtin:
          if (exerciseDefinitionHashes[exercise.exerciseKey] !=
              exercise.definitionHash) {
            throw const FormatException(
              'The built-in exercise definition changed before handoff.',
            );
          }
          break;
        case ExerciseSource.custom:
          final definition = customByKey[exercise.exerciseKey];
          if (definition == null ||
              definition.isHidden ||
              _customHash(definition) != exercise.definitionHash ||
              definition.name != exercise.exerciseName ||
              definition.exerciseType != exercise.exerciseType ||
              definition.bodyPart != exercise.bodyPart ||
              definition.loadInputMode != exercise.loadInputMode ||
              definition.repsInputMode != exercise.repsInputMode ||
              definition.setMetricType != exercise.setMetricType) {
            throw const FormatException(
              'The custom exercise definition changed before handoff.',
            );
          }
          break;
        default:
          throw const FormatException(
            'Workout draft v3 requires an approved exercise source.',
          );
      }
    }
  }

  String _customHash(ExerciseDefinition definition) {
    return aiCustomExerciseDefinitionHash(<String>[
      definition.key,
      definition.name,
      definition.exerciseType,
      definition.bodyPart,
      definition.strengthStructure,
      definition.strengthProfile,
      definition.loadInputMode,
      definition.repsInputMode,
      definition.setMetricType,
    ]);
  }
}
