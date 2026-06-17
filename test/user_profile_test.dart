import 'package:flutter_test/flutter_test.dart';
import 'package:fitlog_local/domain/models/user_profile.dart';

void main() {
  test('fromMap reads nickname and defaults keep compatibility', () {
    final profile = UserProfile.fromMap(<String, dynamic>{
      'id': 1,
      'nickname': 'Mark',
      'age': 28,
      'height_cm': 178,
      'weight_kg': 72,
      'sex_for_formula': 'male',
      'activity_level': 'moderately_active',
      'daily_energy_goal_type': 'deficit',
      'daily_energy_goal_kcal': 300,
      'protein_ratio_percent': 30,
      'carbs_ratio_percent': 40,
      'fat_ratio_percent': 30,
      'diet_goal_phase': 'cutting',
      'diet_calculation_mode': 'energy_ratio',
      'diet_plan_strategy': 'none',
      'training_frequency_per_week': 3,
      'macro_self_check_period_days': 14,
      'macro_self_check_enabled': 1,
      'created_at': '2026-06-07T00:00:00.000',
      'updated_at': '2026-06-07T00:00:00.000',
    });

    expect(profile.nickname, 'Mark');
    expect(profile.toMap()['nickname'], 'Mark');
  });

  test('copyWith preserves empty nickname for local fallback handling', () {
    final profile = UserProfile.defaults.copyWith(nickname: '');

    expect(profile.nickname, '');
  });
}
