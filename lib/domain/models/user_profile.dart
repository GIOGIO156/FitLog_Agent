import 'dart:convert';

import '../../core/constants/app_constants.dart';
import '../../core/utils/number_utils.dart';

class UserProfile {
  const UserProfile({
    this.id,
    this.nickname,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.sexForFormula,
    required this.activityLevel,
    required this.dailyEnergyGoalType,
    required this.dailyEnergyGoalKcal,
    required this.proteinRatioPercent,
    required this.carbsRatioPercent,
    required this.fatRatioPercent,
    required this.dietGoalPhase,
    required this.dietCalculationMode,
    required this.dietPlanStrategy,
    this.carbCyclePatternJson,
    required this.carbCycleHighMultiplier,
    required this.carbCycleMediumMultiplier,
    required this.carbCycleLowMultiplier,
    required this.carbTaperReviewPeriodDays,
    required this.carbTaperTargetLossPctPerWeek,
    required this.carbTaperStepG,
    required this.carbTaperCurrentDeltaG,
    this.lastCarbTaperReviewAt,
    required this.trainingFrequencyPerWeek,
    required this.macroSelfCheckPeriodDays,
    required this.macroSelfCheckEnabled,
    this.lastMacroSelfCheckAt,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String? nickname;
  final int age;
  final double heightCm;
  final double weightKg;
  final String sexForFormula;
  final String activityLevel;
  final String dailyEnergyGoalType;
  final double dailyEnergyGoalKcal;
  final double proteinRatioPercent;
  final double carbsRatioPercent;
  final double fatRatioPercent;
  final String dietGoalPhase;
  final String dietCalculationMode;
  final String dietPlanStrategy;
  final String? carbCyclePatternJson;
  final double carbCycleHighMultiplier;
  final double carbCycleMediumMultiplier;
  final double carbCycleLowMultiplier;
  final int carbTaperReviewPeriodDays;
  final double carbTaperTargetLossPctPerWeek;
  final double carbTaperStepG;
  final double carbTaperCurrentDeltaG;
  final String? lastCarbTaperReviewAt;
  final int trainingFrequencyPerWeek;
  final int macroSelfCheckPeriodDays;
  final bool macroSelfCheckEnabled;
  final String? lastMacroSelfCheckAt;
  final String? createdAt;
  final String? updatedAt;

  static const UserProfile defaults = UserProfile(
    id: 1,
    nickname: null,
    age: 25,
    heightCm: 170,
    weightKg: 65,
    sexForFormula: 'prefer_not_to_say',
    activityLevel: 'lightly_active',
    dailyEnergyGoalType: 'maintenance',
    dailyEnergyGoalKcal: 300,
    proteinRatioPercent: AppConstants.defaultProteinRatioPercent,
    carbsRatioPercent: AppConstants.defaultCarbsRatioPercent,
    fatRatioPercent: AppConstants.defaultFatRatioPercent,
    dietGoalPhase: AppConstants.dietGoalPhaseCutting,
    dietCalculationMode: AppConstants.dietCalculationModeEnergyRatio,
    dietPlanStrategy: AppConstants.defaultDietPlanStrategy,
    carbCycleHighMultiplier: AppConstants.defaultCarbCycleHighMultiplier,
    carbCycleMediumMultiplier: AppConstants.defaultCarbCycleMediumMultiplier,
    carbCycleLowMultiplier: AppConstants.defaultCarbCycleLowMultiplier,
    carbTaperReviewPeriodDays: AppConstants.defaultCarbTaperReviewPeriodDays,
    carbTaperTargetLossPctPerWeek:
        AppConstants.defaultCarbTaperTargetLossPctPerWeek,
    carbTaperStepG: AppConstants.defaultCarbTaperStepG,
    carbTaperCurrentDeltaG: AppConstants.defaultCarbTaperCurrentDeltaG,
    trainingFrequencyPerWeek: AppConstants.defaultTrainingFrequencyPerWeek,
    macroSelfCheckPeriodDays: AppConstants.defaultMacroSelfCheckPeriodDays,
    macroSelfCheckEnabled: true,
  );

  bool get isMinor => age < 18;

  double get macroRatioTotal =>
      proteinRatioPercent + carbsRatioPercent + fatRatioPercent;

  bool get hasValidMacroRatio => macroRatioTotal > 0;

  Map<String, String> get carbCyclePattern {
    final fallback = AppConstants.defaultCarbCyclePattern();
    final raw = carbCyclePatternJson;
    if (raw == null || raw.trim().isEmpty) {
      return fallback;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return fallback;
      }
      return <String, String>{
        for (final key in AppConstants.carbCycleWeekdayKeys)
          key: AppConstants.resolveCarbDayType(decoded[key]?.toString()),
      };
    } catch (_) {
      return fallback;
    }
  }

  UserProfile copyWith({
    int? id,
    String? nickname,
    int? age,
    double? heightCm,
    double? weightKg,
    String? sexForFormula,
    String? activityLevel,
    String? dailyEnergyGoalType,
    double? dailyEnergyGoalKcal,
    double? proteinRatioPercent,
    double? carbsRatioPercent,
    double? fatRatioPercent,
    String? dietGoalPhase,
    String? dietCalculationMode,
    String? dietPlanStrategy,
    String? carbCyclePatternJson,
    double? carbCycleHighMultiplier,
    double? carbCycleMediumMultiplier,
    double? carbCycleLowMultiplier,
    int? carbTaperReviewPeriodDays,
    double? carbTaperTargetLossPctPerWeek,
    double? carbTaperStepG,
    double? carbTaperCurrentDeltaG,
    String? lastCarbTaperReviewAt,
    int? trainingFrequencyPerWeek,
    int? macroSelfCheckPeriodDays,
    bool? macroSelfCheckEnabled,
    String? lastMacroSelfCheckAt,
    String? createdAt,
    String? updatedAt,
  }) {
    final safePhase = AppConstants.resolveDietGoalPhase(
      dietGoalPhase ?? this.dietGoalPhase,
    );
    final phaseGoalType = safePhase == AppConstants.dietGoalPhaseBulking
        ? 'surplus'
        : 'deficit';
    final requestedGoalType = dailyEnergyGoalType ?? phaseGoalType;
    final String safeGoal =
        (age ?? this.age) < 18 && requestedGoalType == 'deficit'
        ? 'maintenance'
        : requestedGoalType;

    return UserProfile(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      sexForFormula: sexForFormula ?? this.sexForFormula,
      activityLevel: AppConstants.resolveActivityLevel(
        activityLevel ?? this.activityLevel,
      ),
      dailyEnergyGoalType: AppConstants.dailyEnergyGoalTypes.contains(safeGoal)
          ? safeGoal
          : 'maintenance',
      dailyEnergyGoalKcal: dailyEnergyGoalKcal ?? this.dailyEnergyGoalKcal,
      proteinRatioPercent: proteinRatioPercent ?? this.proteinRatioPercent,
      carbsRatioPercent: carbsRatioPercent ?? this.carbsRatioPercent,
      fatRatioPercent: fatRatioPercent ?? this.fatRatioPercent,
      dietGoalPhase: safePhase,
      dietCalculationMode: AppConstants.resolveDietCalculationMode(
        dietCalculationMode ?? this.dietCalculationMode,
      ),
      dietPlanStrategy: AppConstants.resolveDietPlanStrategy(
        dietPlanStrategy ?? this.dietPlanStrategy,
      ),
      carbCyclePatternJson: carbCyclePatternJson ?? this.carbCyclePatternJson,
      carbCycleHighMultiplier:
          carbCycleHighMultiplier ?? this.carbCycleHighMultiplier,
      carbCycleMediumMultiplier:
          carbCycleMediumMultiplier ?? this.carbCycleMediumMultiplier,
      carbCycleLowMultiplier:
          carbCycleLowMultiplier ?? this.carbCycleLowMultiplier,
      carbTaperReviewPeriodDays: AppConstants.resolveCarbTaperReviewPeriodDays(
        carbTaperReviewPeriodDays ?? this.carbTaperReviewPeriodDays,
      ),
      carbTaperTargetLossPctPerWeek:
          AppConstants.resolveCarbTaperTargetLossPctPerWeek(
            carbTaperTargetLossPctPerWeek ?? this.carbTaperTargetLossPctPerWeek,
          ),
      carbTaperStepG: AppConstants.resolveCarbTaperStepG(
        carbTaperStepG ?? this.carbTaperStepG,
      ),
      carbTaperCurrentDeltaG:
          carbTaperCurrentDeltaG ?? this.carbTaperCurrentDeltaG,
      lastCarbTaperReviewAt:
          lastCarbTaperReviewAt ?? this.lastCarbTaperReviewAt,
      trainingFrequencyPerWeek: AppConstants.resolveTrainingFrequencyPerWeek(
        trainingFrequencyPerWeek ?? this.trainingFrequencyPerWeek,
      ),
      macroSelfCheckPeriodDays: AppConstants.resolveMacroSelfCheckPeriodDays(
        macroSelfCheckPeriodDays ?? this.macroSelfCheckPeriodDays,
      ),
      macroSelfCheckEnabled:
          macroSelfCheckEnabled ?? this.macroSelfCheckEnabled,
      lastMacroSelfCheckAt: lastMacroSelfCheckAt ?? this.lastMacroSelfCheckAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nickname': nickname,
      'age': age,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'sex_for_formula': sexForFormula,
      'activity_level': activityLevel,
      'daily_energy_goal_type': dailyEnergyGoalType,
      'daily_energy_goal_kcal': dailyEnergyGoalKcal,
      'protein_ratio_percent': proteinRatioPercent,
      'carbs_ratio_percent': carbsRatioPercent,
      'fat_ratio_percent': fatRatioPercent,
      'diet_goal_phase': dietGoalPhase,
      'diet_calculation_mode': dietCalculationMode,
      'diet_plan_strategy': dietPlanStrategy,
      'carb_cycle_pattern_json': carbCyclePatternJson,
      'carb_cycle_high_multiplier': carbCycleHighMultiplier,
      'carb_cycle_medium_multiplier': carbCycleMediumMultiplier,
      'carb_cycle_low_multiplier': carbCycleLowMultiplier,
      'carb_taper_review_period_days': carbTaperReviewPeriodDays,
      'carb_taper_target_loss_pct_per_week': carbTaperTargetLossPctPerWeek,
      'carb_taper_step_g': carbTaperStepG,
      'carb_taper_current_delta_g': carbTaperCurrentDeltaG,
      'last_carb_taper_review_at': lastCarbTaperReviewAt,
      'training_frequency_per_week': trainingFrequencyPerWeek,
      'macro_self_check_period_days': macroSelfCheckPeriodDays,
      'macro_self_check_enabled': macroSelfCheckEnabled ? 1 : 0,
      'last_macro_self_check_at': lastMacroSelfCheckAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: NumberUtils.toNullableInt(map['id']),
      nickname: map['nickname']?.toString(),
      age: NumberUtils.toInt(map['age'], fallback: 25),
      heightCm: NumberUtils.toDouble(map['height_cm'], fallback: 170),
      weightKg: NumberUtils.toDouble(map['weight_kg'], fallback: 65),
      sexForFormula: (map['sex_for_formula'] ?? 'prefer_not_to_say').toString(),
      activityLevel: AppConstants.resolveActivityLevel(
        (map['activity_level'] ??
                AppConstants.activityLevelForTrainingFrequency(
                  AppConstants.defaultTrainingFrequencyPerWeek,
                ))
            .toString(),
      ),
      dailyEnergyGoalType: (map['daily_energy_goal_type'] ?? 'maintenance')
          .toString(),
      dailyEnergyGoalKcal: NumberUtils.toDouble(
        map['daily_energy_goal_kcal'],
        fallback: 300,
      ),
      proteinRatioPercent: NumberUtils.toDouble(
        map['protein_ratio_percent'],
        fallback: AppConstants.defaultProteinRatioPercent,
      ),
      carbsRatioPercent: NumberUtils.toDouble(
        map['carbs_ratio_percent'],
        fallback: AppConstants.defaultCarbsRatioPercent,
      ),
      fatRatioPercent: NumberUtils.toDouble(
        map['fat_ratio_percent'],
        fallback: AppConstants.defaultFatRatioPercent,
      ),
      dietGoalPhase: AppConstants.resolveDietGoalPhase(
        (map['diet_goal_phase'] ?? AppConstants.dietGoalPhaseCutting)
            .toString(),
      ),
      dietCalculationMode: AppConstants.resolveDietCalculationMode(
        (map['diet_calculation_mode'] ??
                AppConstants.dietCalculationModeEnergyRatio)
            .toString(),
      ),
      dietPlanStrategy: AppConstants.resolveDietPlanStrategy(
        (map['diet_plan_strategy'] ?? AppConstants.defaultDietPlanStrategy)
            .toString(),
      ),
      carbCyclePatternJson: map['carb_cycle_pattern_json']?.toString(),
      carbCycleHighMultiplier: NumberUtils.toDouble(
        map['carb_cycle_high_multiplier'],
        fallback: AppConstants.defaultCarbCycleHighMultiplier,
      ),
      carbCycleMediumMultiplier: NumberUtils.toDouble(
        map['carb_cycle_medium_multiplier'],
        fallback: AppConstants.defaultCarbCycleMediumMultiplier,
      ),
      carbCycleLowMultiplier: NumberUtils.toDouble(
        map['carb_cycle_low_multiplier'],
        fallback: AppConstants.defaultCarbCycleLowMultiplier,
      ),
      carbTaperReviewPeriodDays: AppConstants.resolveCarbTaperReviewPeriodDays(
        NumberUtils.toInt(
          map['carb_taper_review_period_days'],
          fallback: AppConstants.defaultCarbTaperReviewPeriodDays,
        ),
      ),
      carbTaperTargetLossPctPerWeek:
          AppConstants.resolveCarbTaperTargetLossPctPerWeek(
            NumberUtils.toDouble(
              map['carb_taper_target_loss_pct_per_week'],
              fallback: AppConstants.defaultCarbTaperTargetLossPctPerWeek,
            ),
          ),
      carbTaperStepG: AppConstants.resolveCarbTaperStepG(
        NumberUtils.toDouble(
          map['carb_taper_step_g'],
          fallback: AppConstants.defaultCarbTaperStepG,
        ),
      ),
      carbTaperCurrentDeltaG: NumberUtils.toDouble(
        map['carb_taper_current_delta_g'],
        fallback: AppConstants.defaultCarbTaperCurrentDeltaG,
      ),
      lastCarbTaperReviewAt: map['last_carb_taper_review_at']?.toString(),
      trainingFrequencyPerWeek: AppConstants.resolveTrainingFrequencyPerWeek(
        NumberUtils.toInt(
          map['training_frequency_per_week'],
          fallback: AppConstants.defaultTrainingFrequencyPerWeek,
        ),
      ),
      macroSelfCheckPeriodDays: AppConstants.resolveMacroSelfCheckPeriodDays(
        NumberUtils.toInt(
          map['macro_self_check_period_days'],
          fallback: AppConstants.defaultMacroSelfCheckPeriodDays,
        ),
      ),
      macroSelfCheckEnabled:
          NumberUtils.toInt(map['macro_self_check_enabled'], fallback: 1) == 1,
      lastMacroSelfCheckAt: map['last_macro_self_check_at']?.toString(),
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }
}
