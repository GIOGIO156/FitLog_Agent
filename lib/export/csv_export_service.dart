import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../core/utils/date_utils.dart';
import '../data/repositories/custom_exercise_repository.dart';
import '../data/repositories/food_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/workout_repository.dart';
import '../domain/services/daily_summary_service.dart';
import 'export_table_builder.dart';

class CsvExportService {
  CsvExportService({
    required FoodRepository foodRepository,
    required CustomExerciseRepository customExerciseRepository,
    required WorkoutRepository workoutRepository,
    required ProfileRepository profileRepository,
    required DailySummaryService dailySummaryService,
  }) : _foodRepository = foodRepository,
       _customExerciseRepository = customExerciseRepository,
       _workoutRepository = workoutRepository,
       _profileRepository = profileRepository,
       _dailySummaryService = dailySummaryService;

  final FoodRepository _foodRepository;
  final CustomExerciseRepository _customExerciseRepository;
  final WorkoutRepository _workoutRepository;
  final ProfileRepository _profileRepository;
  final DailySummaryService _dailySummaryService;

  Future<String> exportZip() async {
    final tables = await ExportTableBuilder(
      foodRepository: _foodRepository,
      customExerciseRepository: _customExerciseRepository,
      workoutRepository: _workoutRepository,
      profileRepository: _profileRepository,
      dailySummaryService: _dailySummaryService,
    ).build();

    final archive = Archive();
    for (final table in tables) {
      _addCsvToArchive(archive, table.fileName, table.rows);
    }

    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) {
      throw Exception('Failed to create CSV zip archive.');
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'fitlog_local_${DateUtilsX.formatForExport(DateTime.now())}.zip';
    final filePath = path.join(dir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    return file.path;
  }

  void _addCsvToArchive(
    Archive archive,
    String fileName,
    List<List<dynamic>> rows,
  ) {
    final csvContent = const ListToCsvConverter().convert(rows);
    final encoded = utf8.encode(csvContent);
    archive.addFile(ArchiveFile(fileName, encoded.length, encoded));
  }
}
