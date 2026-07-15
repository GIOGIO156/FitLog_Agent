import 'package:fitlog_local/core/constants/exercise_catalog.dart';
import 'package:fitlog_local/core/localization/app_language.dart';
import 'package:fitlog_local/core/localization/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every built-in exercise has one catalog-owned Chinese name', () {
    for (final exercise in ExerciseCatalog.builtInExercises) {
      final translated = ExerciseCatalog.localizedNamesZh[exercise.name];
      expect(translated, isNotNull, reason: exercise.key);
      expect(translated, isNotEmpty, reason: exercise.key);
    }
  });

  test('AppStrings uses catalog names and preserves English names', () {
    final zh = AppStrings(AppLanguage.chinese);
    final en = AppStrings(AppLanguage.english);

    expect(zh.exerciseDisplayName('Bulgarian Split Squat'), '保加利亚分腿蹲');
    expect(
      en.exerciseDisplayName('Bulgarian Split Squat'),
      'Bulgarian Split Squat',
    );
    expect(
      zh.exerciseDisplayName('Unknown Local Exercise'),
      'Unknown Local Exercise',
    );
  });
}
