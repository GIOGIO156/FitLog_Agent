import 'dart:io';

import 'package:fitlog_local/features/food/photo_food_analysis_recovery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory legacyDirectory;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    legacyDirectory = Directory.systemTemp.createTempSync(
      'fitlog_photo_food_legacy_recovery_test_',
    );
    PhotoFoodAnalysisLegacyRecoveryCleanup.debugDirectoryOverride =
        legacyDirectory;
  });

  tearDown(() async {
    PhotoFoodAnalysisLegacyRecoveryCleanup.debugDirectoryOverride = null;
    if (await legacyDirectory.exists()) {
      await legacyDirectory.delete(recursive: true);
    }
  });

  test(
    'legacy photo analysis recovery marker is cleared without restore',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('fitlog.photo_food_analysis.pending', true);
      await prefs.setString(
        'fitlog.photo_food_analysis.initial_date',
        '2026-07-01',
      );
      await prefs.setString('fitlog.photo_food_analysis.note', '旧版输入');
      await prefs.setInt('fitlog.photo_food_analysis.selected_image_index', 1);
      await prefs.setString('fitlog.photo_food_analysis.images', '[]');
      await prefs.setString(
        'fitlog.photo_food_analysis.purpose',
        'analysis_retry',
      );
      final staleImage = File(
        '${legacyDirectory.path}${Platform.pathSeparator}image_0.png',
      );
      await staleImage.writeAsBytes(<int>[1, 2, 3], flush: true);

      await PhotoFoodAnalysisLegacyRecoveryCleanup.clear();

      expect(prefs.getBool('fitlog.photo_food_analysis.pending'), isNull);
      expect(
        prefs.getString('fitlog.photo_food_analysis.initial_date'),
        isNull,
      );
      expect(prefs.getString('fitlog.photo_food_analysis.note'), isNull);
      expect(
        prefs.getInt('fitlog.photo_food_analysis.selected_image_index'),
        isNull,
      );
      expect(prefs.getString('fitlog.photo_food_analysis.images'), isNull);
      expect(prefs.getString('fitlog.photo_food_analysis.purpose'), isNull);
      expect(await legacyDirectory.list().toList(), isEmpty);
    },
  );
}
