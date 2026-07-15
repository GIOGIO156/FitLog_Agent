import 'dart:convert';
import 'dart:io';

import 'package:fitlog_local/core/constants/exercise_catalog.dart';

void main() {
  final exercises =
      ExerciseCatalog.builtInExercises.map((exercise) {
        final reviewed = <String>{
          ...exercise.legacyNames,
          ...?ExerciseCatalog.reviewedAliasesByKey[exercise.key],
        };
        final aliasesZh = reviewed.where(_containsCjk).toList()..sort();
        final aliasesEn =
            reviewed.where((value) => !_containsCjk(value)).toList()..sort();
        return <String, Object?>{
          'key': exercise.key,
          'name_en': exercise.name,
          'name_zh': ExerciseCatalog.localizedNamesZh[exercise.name],
          'aliases': <String, Object>{'zh': aliasesZh, 'en': aliasesEn},
          'exercise_type': exercise.exerciseType,
          'body_part': exercise.bodyPart,
          'secondary_body_part': exercise.secondaryBodyPart,
          'strength_structure': exercise.strengthStructure,
          'strength_profile': exercise.strengthProfile,
          'load_input_mode': exercise.loadInputMode,
          'reps_input_mode': exercise.repsInputMode,
          'set_metric_type': exercise.setMetricType,
          'default_cardio_intensity': exercise.defaultCardioIntensity,
        };
      }).toList()..sort(
        (left, right) =>
            (left['key']! as String).compareTo(right['key']! as String),
      );

  final output = const JsonEncoder.withIndent('  ').convert(<String, Object>{
    'schema_version': 'fitlog_exercise_terms.v1',
    'catalog_version': 'exercise_catalog.v1',
    'exercises': exercises,
  });
  final target = File('assets/rag/exercise_terms.v1.json');
  target.parent.createSync(recursive: true);
  target.writeAsStringSync('$output\n');
  stdout.writeln('Wrote ${exercises.length} exercise terms.');
}

bool _containsCjk(String value) => RegExp(r'[\u3400-\u9fff]').hasMatch(value);
