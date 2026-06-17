import 'package:sqflite/sqflite.dart';

import '../../core/constants/exercise_catalog.dart';
import '../../core/constants/exercise_definition.dart';
import '../db/app_database.dart';

class CustomExerciseRepository {
  CustomExerciseRepository(this._database);

  final AppDatabase _database;

  Future<List<ExerciseDefinition>> getActiveDefinitions() async {
    final db = await _database.database;
    final rows = await db.query(
      'custom_exercises',
      where: 'is_hidden = 0',
      orderBy: 'created_at ASC',
    );
    return rows.map(_definitionFromRow).toList();
  }

  Future<List<ExerciseDefinition>> getAllDefinitions() async {
    final db = await _database.database;
    final rows = await db.query('custom_exercises', orderBy: 'created_at ASC');
    return rows.map(_definitionFromRow).toList();
  }

  Future<void> saveDefinition(ExerciseDefinition definition) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('custom_exercises', <String, Object?>{
      'exercise_key': definition.key,
      'name': definition.name,
      'exercise_type': definition.exerciseType,
      'body_part': definition.bodyPart,
      'secondary_body_part': definition.secondaryBodyPart,
      'strength_structure': definition.strengthStructure,
      'strength_profile': definition.strengthProfile,
      'load_input_mode': definition.loadInputMode,
      'reps_input_mode': definition.repsInputMode,
      'set_metric_type': definition.setMetricType,
      'default_cardio_intensity': definition.defaultCardioIntensity,
      'is_hidden': 0,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> hideDefinition(String exerciseKey) async {
    final db = await _database.database;
    await db.update(
      'custom_exercises',
      <String, Object?>{
        'is_hidden': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'exercise_key = ?',
      whereArgs: <Object?>[exerciseKey],
    );
  }

  ExerciseDefinition _definitionFromRow(Map<String, Object?> row) {
    final exerciseType =
        row['exercise_type']?.toString() ?? ExerciseType.strength;
    final bodyPart = row['body_part']?.toString() ?? 'Full Body';
    return ExerciseDefinition(
      key: row['exercise_key']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      bodyPart: exerciseType == ExerciseType.cardio ? 'Cardio' : bodyPart,
      exerciseType: exerciseType,
      secondaryBodyPart: row['secondary_body_part']?.toString(),
      strengthStructure:
          row['strength_structure']?.toString() ?? ExerciseStructure.compound,
      strengthProfile:
          row['strength_profile']?.toString() ??
          ExerciseStrengthProfile.upperBodyCompound,
      loadInputMode:
          row['load_input_mode']?.toString() ?? ExerciseLoadInputMode.totalLoad,
      repsInputMode:
          row['reps_input_mode']?.toString() ?? ExerciseRepsInputMode.totalReps,
      setMetricType:
          row['set_metric_type']?.toString() ?? ExerciseSetMetricType.reps,
      defaultCardioIntensity:
          row['default_cardio_intensity']?.toString() ??
          CardioIntensityBasis.moderate30To60,
      cardioMetByIntensity: exerciseType == ExerciseType.cardio
          ? ExerciseCatalog.genericCardioMetByIntensity
          : const <String, double>{},
      isBuiltin: false,
      isHidden: (row['is_hidden'] as int? ?? 0) != 0,
    );
  }
}
