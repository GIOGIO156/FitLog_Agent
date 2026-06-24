import 'package:fitlog_local/core/constants/app_constants.dart';
import 'package:fitlog_local/domain/models/user_profile.dart';
import 'package:fitlog_local/domain/services/cloud_profile_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CloudProfileMapper preserves phase, mode, and strategy semantics', () {
    const mapper = CloudProfileMapper();
    final cloudProfile = mapper.fromRow(<String, dynamic>{
      'account_id': 'acct_1',
      'display_name': 'RINKO',
      'age': 28,
      'height_cm': 170,
      'weight_kg': 68,
      'body_fat_percent': 18.5,
      'waist_cm': 72.4,
      'sex_for_formula': 'female',
      'diet_goal_phase': AppConstants.dietGoalPhaseBulking,
      'diet_calculation_mode': AppConstants.dietCalculationModeGramPerKg,
      'daily_energy_goal_kcal': 2400,
      'protein_ratio_percent': 25,
      'carbs_ratio_percent': 50,
      'fat_ratio_percent': 25,
      'training_frequency_per_week': 4,
      'diet_plan_strategy': AppConstants.dietPlanStrategyCarbCycling,
      'profile_version': 7,
    });

    expect(
      cloudProfile.profile.dietGoalPhase,
      AppConstants.dietGoalPhaseBulking,
    );
    expect(
      cloudProfile.profile.dietCalculationMode,
      AppConstants.dietCalculationModeGramPerKg,
    );
    expect(
      cloudProfile.profile.dietPlanStrategy,
      AppConstants.dietPlanStrategyCarbCycling,
    );
    expect(cloudProfile.profile.bodyFatPercent, 18.5);
    expect(cloudProfile.profile.waistCm, 72.4);

    final row = mapper.toRow(cloudProfile);
    expect(row['diet_goal_phase'], AppConstants.dietGoalPhaseBulking);
    expect(
      row['diet_calculation_mode'],
      AppConstants.dietCalculationModeGramPerKg,
    );
    expect(row['diet_plan_strategy'], AppConstants.dietPlanStrategyCarbCycling);
    expect(row['daily_energy_goal_kcal'], 2400);
    expect(row['body_fat_percent'], 18.5);
    expect(row['waist_cm'], 72.4);
    expect(row['daily_energy_goal_kcal'], isA<int>());
    expect(row['protein_ratio_percent'], isA<int>());
    expect(row['carbs_ratio_percent'], isA<int>());
    expect(row['fat_ratio_percent'], isA<int>());
  });

  test('CloudProfileMapper increments version without converting modes', () {
    const mapper = CloudProfileMapper();
    final existing = mapper.defaultForAccount('acct_1');
    final updated = mapper.updateFromUserProfile(
      existing: existing,
      accountId: 'acct_1',
      profile: UserProfile.defaults.copyWith(
        dietGoalPhase: AppConstants.dietGoalPhaseCutting,
        dietCalculationMode: AppConstants.dietCalculationModeEnergyRatio,
        dietPlanStrategy: AppConstants.dietPlanStrategyNone,
      ),
    );

    expect(updated.profileVersion, existing.profileVersion + 1);
    expect(
      updated.profile.dietCalculationMode,
      AppConstants.dietCalculationModeEnergyRatio,
    );
    expect(updated.profile.dietGoalPhase, AppConstants.dietGoalPhaseCutting);
  });
}
