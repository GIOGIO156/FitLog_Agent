import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../core/utils/date_utils.dart';
import '../data/repositories/custom_exercise_repository.dart';
import '../data/repositories/food_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/workout_repository.dart';
import '../domain/services/daily_summary_service.dart';
import 'export_table_builder.dart';

class XlsxExportService {
  XlsxExportService({
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

  Future<String> export() async {
    final tables = await ExportTableBuilder(
      foodRepository: _foodRepository,
      customExerciseRepository: _customExerciseRepository,
      workoutRepository: _workoutRepository,
      profileRepository: _profileRepository,
      dailySummaryService: _dailySummaryService,
    ).build();

    final excel = Excel.createExcel();
    final defaultSheetName = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheetName, tables.first.sheetName);

    for (var i = 0; i < tables.length; i++) {
      final table = tables[i];
      final sheet = excel[table.sheetName];
      for (final row in table.rows) {
        _appendRow(sheet, row);
      }
    }

    final List<int>? bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode XLSX data.');
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'fitlog_local_${DateUtilsX.formatForExport(DateTime.now())}.xlsx';
    final filePath = path.join(dir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  void _appendRow(Sheet sheet, List<dynamic> values) {
    sheet.appendRow(values.map(_toCell).toList());
  }

  CellValue _toCell(dynamic value) {
    if (value == null) {
      return TextCellValue('');
    }

    if (value is int) {
      return IntCellValue(value);
    }

    if (value is double) {
      return DoubleCellValue(value);
    }

    if (value is bool) {
      return BoolCellValue(value);
    }

    return TextCellValue(value.toString());
  }
}
