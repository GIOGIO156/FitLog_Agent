import '../../data/repositories/custom_exercise_repository.dart';
import '../models/ai_exercise_reference.dart';

class AiExerciseReferenceBuilder {
  const AiExerciseReferenceBuilder(this._repository);

  final CustomExerciseRepository _repository;

  Future<List<AiExerciseReference>> buildForMessage(String message) async {
    final normalizedMessage = _normalize(message);
    if (normalizedMessage.isEmpty) return const <AiExerciseReference>[];
    final definitions = await _repository.getActiveDefinitions();
    return definitions
        .where((definition) {
          final name = _normalize(definition.name);
          return name.isNotEmpty && normalizedMessage.contains(name);
        })
        .take(4)
        .map(
          (definition) => AiExerciseReference(
            key: definition.key,
            name: definition.name,
            definitionHash: aiCustomExerciseDefinitionHash(<String>[
              definition.key,
              definition.name,
              definition.exerciseType,
              definition.bodyPart,
              definition.strengthStructure,
              definition.strengthProfile,
              definition.loadInputMode,
              definition.repsInputMode,
              definition.setMetricType,
            ]),
            exerciseType: definition.exerciseType,
            bodyPart: definition.bodyPart,
            strengthStructure: definition.strengthStructure,
            strengthProfile: definition.strengthProfile,
            loadInputMode: definition.loadInputMode,
            repsInputMode: definition.repsInputMode,
            setMetricType: definition.setMetricType,
          ),
        )
        .toList(growable: false);
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[\s\-_.,，。()（）/\\]+'), '');
}

String aiCustomExerciseDefinitionHash(List<String> fields) {
  var hash = 0x811c9dc5;
  for (final codeUnit in fields.join('\u001f').codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
