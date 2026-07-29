import 'package:fitlog_local/core/localization/app_language.dart';
import 'package:fitlog_local/core/localization/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home workout summary labels the count as exercise actions', () {
    final chinese = AppStrings(AppLanguage.chinese);
    final english = AppStrings(AppLanguage.english);

    expect(chinese.workoutRecordsSummary(3), '已记录 3 个动作');
    expect(english.workoutRecordsSummary(1), '1 exercise');
    expect(english.workoutRecordsSummary(3), '3 exercises');
  });
}
