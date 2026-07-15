class AiExerciseReference {
  const AiExerciseReference({
    required this.key,
    required this.name,
    required this.definitionHash,
    required this.exerciseType,
    required this.bodyPart,
    required this.strengthStructure,
    required this.strengthProfile,
    required this.loadInputMode,
    required this.repsInputMode,
    required this.setMetricType,
  });

  final String key;
  final String name;
  final String definitionHash;
  final String exerciseType;
  final String bodyPart;
  final String strengthStructure;
  final String strengthProfile;
  final String loadInputMode;
  final String repsInputMode;
  final String setMetricType;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'key': key,
    'name': name,
    'definition_hash': definitionHash,
    'exercise_type': exerciseType,
    'body_part': bodyPart,
    'strength_structure': strengthStructure,
    'strength_profile': strengthProfile,
    'load_input_mode': loadInputMode,
    'reps_input_mode': repsInputMode,
    'set_metric_type': setMetricType,
  };
}
