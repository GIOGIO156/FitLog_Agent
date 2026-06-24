import 'dart:convert';

import '../../core/constants/app_constants.dart';
import '../../core/utils/number_utils.dart';
import '../models/cloud_profile.dart';
import '../models/user_profile.dart';

class CloudProfileMapper {
  const CloudProfileMapper();

  CloudProfile fromRow(Map<String, dynamic> row) {
    final accountId = row['account_id']?.toString() ?? '';
    return CloudProfile(
      accountId: accountId,
      profileVersion: NumberUtils.toInt(row['profile_version'], fallback: 1),
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
      profile: UserProfile(
        id: 1,
        nickname:
            row['display_name']?.toString() ?? row['nickname']?.toString(),
        age: NumberUtils.toInt(row['age'], fallback: UserProfile.defaults.age),
        heightCm: NumberUtils.toDouble(
          row['height_cm'],
          fallback: UserProfile.defaults.heightCm,
        ),
        weightKg: NumberUtils.toDouble(
          row['weight_kg'],
          fallback: UserProfile.defaults.weightKg,
        ),
        bodyFatPercent: row['body_fat_percent'] == null
            ? null
            : NumberUtils.toDouble(row['body_fat_percent']),
        waistCm: row['waist_cm'] == null
            ? null
            : NumberUtils.toDouble(row['waist_cm']),
        sexForFormula:
            row['sex_for_formula']?.toString() ??
            UserProfile.defaults.sexForFormula,
        activityLevel: AppConstants.activityLevelForTrainingFrequency(
          NumberUtils.toInt(
            row['training_frequency_per_week'],
            fallback: UserProfile.defaults.trainingFrequencyPerWeek,
          ),
        ),
        dailyEnergyGoalType: _goalTypeForPhase(
          row['diet_goal_phase']?.toString() ??
              UserProfile.defaults.dietGoalPhase,
        ),
        dailyEnergyGoalKcal: NumberUtils.toDouble(
          row['daily_energy_goal_kcal'],
          fallback: UserProfile.defaults.dailyEnergyGoalKcal,
        ),
        proteinRatioPercent: NumberUtils.toDouble(
          row['protein_ratio_percent'],
          fallback: UserProfile.defaults.proteinRatioPercent,
        ),
        carbsRatioPercent: NumberUtils.toDouble(
          row['carbs_ratio_percent'],
          fallback: UserProfile.defaults.carbsRatioPercent,
        ),
        fatRatioPercent: NumberUtils.toDouble(
          row['fat_ratio_percent'],
          fallback: UserProfile.defaults.fatRatioPercent,
        ),
        dietGoalPhase: AppConstants.resolveDietGoalPhase(
          row['diet_goal_phase']?.toString() ??
              UserProfile.defaults.dietGoalPhase,
        ),
        dietCalculationMode: AppConstants.resolveDietCalculationMode(
          row['diet_calculation_mode']?.toString() ??
              UserProfile.defaults.dietCalculationMode,
        ),
        dietPlanStrategy: AppConstants.resolveDietPlanStrategy(
          row['diet_plan_strategy']?.toString() ??
              UserProfile.defaults.dietPlanStrategy,
        ),
        carbCyclePatternJson: _encodeJson(row['carb_cycle_pattern_json']),
        carbCycleHighMultiplier: NumberUtils.toDouble(
          row['carb_cycle_high_multiplier'],
          fallback: UserProfile.defaults.carbCycleHighMultiplier,
        ),
        carbCycleMediumMultiplier: NumberUtils.toDouble(
          row['carb_cycle_medium_multiplier'],
          fallback: UserProfile.defaults.carbCycleMediumMultiplier,
        ),
        carbCycleLowMultiplier: NumberUtils.toDouble(
          row['carb_cycle_low_multiplier'],
          fallback: UserProfile.defaults.carbCycleLowMultiplier,
        ),
        carbTaperReviewPeriodDays:
            AppConstants.resolveCarbTaperReviewPeriodDays(
              NumberUtils.toInt(
                row['carb_taper_review_period_days'],
                fallback: UserProfile.defaults.carbTaperReviewPeriodDays,
              ),
            ),
        carbTaperTargetLossPctPerWeek:
            AppConstants.resolveCarbTaperTargetLossPctPerWeek(
              NumberUtils.toDouble(
                row['carb_taper_target_loss_pct_per_week'],
                fallback: UserProfile.defaults.carbTaperTargetLossPctPerWeek,
              ),
            ),
        carbTaperStepG: AppConstants.resolveCarbTaperStepG(
          NumberUtils.toDouble(
            row['carb_taper_step_g'],
            fallback: UserProfile.defaults.carbTaperStepG,
          ),
        ),
        carbTaperCurrentDeltaG: NumberUtils.toDouble(
          row['carb_taper_current_delta_g'],
          fallback: UserProfile.defaults.carbTaperCurrentDeltaG,
        ),
        trainingFrequencyPerWeek: AppConstants.resolveTrainingFrequencyPerWeek(
          NumberUtils.toInt(
            row['training_frequency_per_week'],
            fallback: UserProfile.defaults.trainingFrequencyPerWeek,
          ),
        ),
        macroSelfCheckPeriodDays: AppConstants.resolveMacroSelfCheckPeriodDays(
          NumberUtils.toInt(
            row['macro_self_check_period_days'],
            fallback: UserProfile.defaults.macroSelfCheckPeriodDays,
          ),
        ),
        macroSelfCheckEnabled: row['macro_self_check_enabled'] is bool
            ? row['macro_self_check_enabled'] as bool
            : UserProfile.defaults.macroSelfCheckEnabled,
        createdAt: row['created_at']?.toString(),
        updatedAt: row['updated_at']?.toString(),
      ),
    );
  }

  Map<String, dynamic> toRow(CloudProfile cloudProfile) {
    final profile = cloudProfile.profile;
    return <String, dynamic>{
      'account_id': cloudProfile.accountId,
      'display_name': profile.nickname,
      'age': profile.age,
      'height_cm': profile.heightCm,
      'weight_kg': profile.weightKg,
      'body_fat_percent': profile.bodyFatPercent,
      'waist_cm': profile.waistCm,
      'sex_for_formula': profile.sexForFormula,
      'diet_goal_phase': profile.dietGoalPhase,
      'diet_calculation_mode': profile.dietCalculationMode,
      'daily_energy_goal_kcal': profile.dailyEnergyGoalKcal.round(),
      'protein_ratio_percent': profile.proteinRatioPercent.round(),
      'carbs_ratio_percent': profile.carbsRatioPercent.round(),
      'fat_ratio_percent': profile.fatRatioPercent.round(),
      'training_frequency_per_week': profile.trainingFrequencyPerWeek,
      'diet_plan_strategy': profile.dietPlanStrategy,
      'carb_cycle_pattern_json': _decodeJson(profile.carbCyclePatternJson),
      'carb_cycle_high_multiplier': profile.carbCycleHighMultiplier,
      'carb_cycle_medium_multiplier': profile.carbCycleMediumMultiplier,
      'carb_cycle_low_multiplier': profile.carbCycleLowMultiplier,
      'carb_taper_review_period_days': profile.carbTaperReviewPeriodDays,
      'carb_taper_target_loss_pct_per_week':
          profile.carbTaperTargetLossPctPerWeek,
      'carb_taper_step_g': profile.carbTaperStepG,
      'carb_taper_current_delta_g': profile.carbTaperCurrentDeltaG,
      'macro_self_check_period_days': profile.macroSelfCheckPeriodDays,
      'macro_self_check_enabled': profile.macroSelfCheckEnabled,
      'profile_version': cloudProfile.profileVersion,
      'updated_at':
          cloudProfile.updatedAt?.toUtc().toIso8601String() ??
          DateTime.now().toUtc().toIso8601String(),
      if (cloudProfile.createdAt != null)
        'created_at': cloudProfile.createdAt!.toUtc().toIso8601String(),
    };
  }

  CloudProfile defaultForAccount(String accountId) {
    final now = DateTime.now().toUtc();
    return CloudProfile(
      accountId: accountId,
      profile: UserProfile.defaults.copyWith(createdAt: now.toIso8601String()),
      profileVersion: 1,
      createdAt: now,
      updatedAt: now,
    );
  }

  CloudProfile updateFromUserProfile({
    required CloudProfile? existing,
    required String accountId,
    required UserProfile profile,
  }) {
    final now = DateTime.now().toUtc();
    return CloudProfile(
      accountId: accountId,
      profile: profile.copyWith(updatedAt: now.toIso8601String()),
      profileVersion: (existing?.profileVersion ?? 0) + 1,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
  }

  String _goalTypeForPhase(String phase) {
    return AppConstants.resolveDietGoalPhase(phase) ==
            AppConstants.dietGoalPhaseBulking
        ? 'surplus'
        : 'deficit';
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

  Object? _decodeJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  String? _encodeJson(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    return jsonEncode(value);
  }
}
