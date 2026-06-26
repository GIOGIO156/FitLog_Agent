import '../../core/utils/number_utils.dart';
import 'food_item.dart';
import 'food_record.dart';
import 'workout_set.dart';
import 'workout_session.dart';

class DailySummary {
  const DailySummary({
    required this.date,
    required this.caloriesIn,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.exerciseCalories,
    required this.bmr,
    required this.tdeeReference,
    required this.targetIntake,
    required this.remainingCalories,
    required this.targetProteinG,
    required this.targetCarbsG,
    required this.targetFatG,
    required this.remainingProteinG,
    required this.remainingCarbsG,
    required this.remainingFatG,
    required this.dietGoalPhase,
    required this.dietCalculationMode,
    required this.dietPlanStrategy,
    this.carbDayType,
    required this.isEnergyTargetMode,
    required this.baseTargetCalories,
    required this.baseProteinTargetG,
    required this.baseCarbsTargetG,
    required this.baseFatTargetG,
    required this.finalTargetCalories,
    required this.finalProteinTargetG,
    required this.finalCarbsTargetG,
    required this.finalFatTargetG,
    required this.carbAdjustmentG,
    required this.carbTaperCurrentDeltaG,
    required this.baseMacroEnergyEquivalentKcal,
    required this.finalMacroEnergyEquivalentKcal,
    required this.dietStrategyReasonCodes,
    required this.dietStrategyConfidence,
    required this.macroEnergyEquivalentKcal,
    required this.lifestyleFactorUsed,
    required this.exerciseCaloriesNet,
    required this.noExerciseBaselineTdee,
    required this.noExerciseTargetIntake,
    required this.calibrationConfidence,
    required this.calibrationWindowDays,
    required this.calibrationValidDays,
    this.macroSelfCheckCurrentFrequency,
    this.macroSelfCheckRecommendedFrequency,
    this.macroSelfCheckActiveTrainingDays,
    this.macroSelfCheckPeriodDays,
    this.macroSelfCheckAverageWeeklyFrequency,
    this.macroSelfCheckShouldSuggest = false,
    this.macroSelfCheckHasValidTrainingData = false,
    this.macroSelfCheckBelowRecommendedRange = false,
    this.calibrationUpdatedToday = false,
    this.hasPendingDietAdjustmentReview = false,
    this.pendingDietAdjustmentAction,
    this.foodRecords = const <FoodRecord>[],
    this.workoutSessions = const <WorkoutSession>[],
  });

  final String date;
  final double caloriesIn;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double exerciseCalories;
  final double bmr;
  final double tdeeReference;
  final double targetIntake;
  final double remainingCalories;
  final double targetProteinG;
  final double targetCarbsG;
  final double targetFatG;
  final double remainingProteinG;
  final double remainingCarbsG;
  final double remainingFatG;
  final String dietGoalPhase;
  final String dietCalculationMode;
  final String dietPlanStrategy;
  final String? carbDayType;
  final bool isEnergyTargetMode;
  final double baseTargetCalories;
  final double baseProteinTargetG;
  final double baseCarbsTargetG;
  final double baseFatTargetG;
  final double finalTargetCalories;
  final double finalProteinTargetG;
  final double finalCarbsTargetG;
  final double finalFatTargetG;
  final double carbAdjustmentG;
  final double carbTaperCurrentDeltaG;
  final double baseMacroEnergyEquivalentKcal;
  final double finalMacroEnergyEquivalentKcal;
  final List<String> dietStrategyReasonCodes;
  final double dietStrategyConfidence;
  final double macroEnergyEquivalentKcal;
  final double lifestyleFactorUsed;
  final double exerciseCaloriesNet;
  final double noExerciseBaselineTdee;
  final double noExerciseTargetIntake;
  final double calibrationConfidence;
  final int calibrationWindowDays;
  final int calibrationValidDays;
  final int? macroSelfCheckCurrentFrequency;
  final int? macroSelfCheckRecommendedFrequency;
  final int? macroSelfCheckActiveTrainingDays;
  final int? macroSelfCheckPeriodDays;
  final double? macroSelfCheckAverageWeeklyFrequency;
  final bool macroSelfCheckShouldSuggest;
  final bool macroSelfCheckHasValidTrainingData;
  final bool macroSelfCheckBelowRecommendedRange;
  final bool calibrationUpdatedToday;
  final bool hasPendingDietAdjustmentReview;
  final String? pendingDietAdjustmentAction;
  final List<FoodRecord> foodRecords;
  final List<WorkoutSession> workoutSessions;

  Map<String, dynamic> toCacheMap() {
    return <String, dynamic>{
      'date': date,
      'calories_in': caloriesIn,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'exercise_calories': exerciseCalories,
      'bmr': bmr,
      'tdee_reference': tdeeReference,
      'target_intake': targetIntake,
      'remaining_calories': remainingCalories,
      'target_protein_g': targetProteinG,
      'target_carbs_g': targetCarbsG,
      'target_fat_g': targetFatG,
      'remaining_protein_g': remainingProteinG,
      'remaining_carbs_g': remainingCarbsG,
      'remaining_fat_g': remainingFatG,
      'diet_goal_phase': dietGoalPhase,
      'diet_calculation_mode': dietCalculationMode,
      'diet_plan_strategy': dietPlanStrategy,
      'carb_day_type': carbDayType,
      'is_energy_target_mode': isEnergyTargetMode,
      'base_target_calories': baseTargetCalories,
      'base_protein_target_g': baseProteinTargetG,
      'base_carbs_target_g': baseCarbsTargetG,
      'base_fat_target_g': baseFatTargetG,
      'final_target_calories': finalTargetCalories,
      'final_protein_target_g': finalProteinTargetG,
      'final_carbs_target_g': finalCarbsTargetG,
      'final_fat_target_g': finalFatTargetG,
      'carb_adjustment_g': carbAdjustmentG,
      'carb_taper_current_delta_g': carbTaperCurrentDeltaG,
      'base_macro_energy_equivalent_kcal': baseMacroEnergyEquivalentKcal,
      'final_macro_energy_equivalent_kcal': finalMacroEnergyEquivalentKcal,
      'diet_strategy_reason_codes': dietStrategyReasonCodes,
      'diet_strategy_confidence': dietStrategyConfidence,
      'macro_energy_equivalent_kcal': macroEnergyEquivalentKcal,
      'lifestyle_factor_used': lifestyleFactorUsed,
      'exercise_calories_net': exerciseCaloriesNet,
      'no_exercise_baseline_tdee': noExerciseBaselineTdee,
      'no_exercise_target_intake': noExerciseTargetIntake,
      'calibration_confidence': calibrationConfidence,
      'calibration_window_days': calibrationWindowDays,
      'calibration_valid_days': calibrationValidDays,
      'macro_self_check_current_frequency': macroSelfCheckCurrentFrequency,
      'macro_self_check_recommended_frequency':
          macroSelfCheckRecommendedFrequency,
      'macro_self_check_active_training_days': macroSelfCheckActiveTrainingDays,
      'macro_self_check_period_days': macroSelfCheckPeriodDays,
      'macro_self_check_average_weekly_frequency':
          macroSelfCheckAverageWeeklyFrequency,
      'macro_self_check_should_suggest': macroSelfCheckShouldSuggest,
      'macro_self_check_has_valid_training_data':
          macroSelfCheckHasValidTrainingData,
      'macro_self_check_below_recommended_range':
          macroSelfCheckBelowRecommendedRange,
      'calibration_updated_today': calibrationUpdatedToday,
      'has_pending_diet_adjustment_review': hasPendingDietAdjustmentReview,
      'pending_diet_adjustment_action': pendingDietAdjustmentAction,
      'food_records': foodRecords.map((record) {
        return <String, dynamic>{
          ...record.toMap(),
          'items': record.items.map((item) => item.toMap()).toList(),
        };
      }).toList(),
      'workout_sessions': workoutSessions.map((session) {
        return <String, dynamic>{
          ...session.toMap(),
          'sets': session.sets.map((set) => set.toMap()).toList(),
        };
      }).toList(),
    };
  }

  factory DailySummary.fromCacheMap(Map<String, dynamic> map) {
    final foodRecords = _mapList(map['food_records']).map((recordMap) {
      final items = _mapList(recordMap['items']).map(FoodItem.fromMap).toList();
      return FoodRecord.fromMap(recordMap, items: items);
    }).toList();
    final workoutSessions = _mapList(map['workout_sessions']).map((sessionMap) {
      final sets = _mapList(
        sessionMap['sets'],
      ).map(WorkoutSet.fromMap).toList();
      return WorkoutSession.fromMap(sessionMap, sets: sets);
    }).toList();

    return DailySummary(
      date: (map['date'] ?? '').toString(),
      caloriesIn: NumberUtils.toDouble(map['calories_in']),
      proteinG: NumberUtils.toDouble(map['protein_g']),
      carbsG: NumberUtils.toDouble(map['carbs_g']),
      fatG: NumberUtils.toDouble(map['fat_g']),
      exerciseCalories: NumberUtils.toDouble(map['exercise_calories']),
      bmr: NumberUtils.toDouble(map['bmr']),
      tdeeReference: NumberUtils.toDouble(map['tdee_reference']),
      targetIntake: NumberUtils.toDouble(map['target_intake']),
      remainingCalories: NumberUtils.toDouble(map['remaining_calories']),
      targetProteinG: NumberUtils.toDouble(map['target_protein_g']),
      targetCarbsG: NumberUtils.toDouble(map['target_carbs_g']),
      targetFatG: NumberUtils.toDouble(map['target_fat_g']),
      remainingProteinG: NumberUtils.toDouble(map['remaining_protein_g']),
      remainingCarbsG: NumberUtils.toDouble(map['remaining_carbs_g']),
      remainingFatG: NumberUtils.toDouble(map['remaining_fat_g']),
      dietGoalPhase: (map['diet_goal_phase'] ?? '').toString(),
      dietCalculationMode: (map['diet_calculation_mode'] ?? '').toString(),
      dietPlanStrategy: (map['diet_plan_strategy'] ?? '').toString(),
      carbDayType: map['carb_day_type']?.toString(),
      isEnergyTargetMode: _bool(map['is_energy_target_mode']),
      baseTargetCalories: NumberUtils.toDouble(map['base_target_calories']),
      baseProteinTargetG: NumberUtils.toDouble(map['base_protein_target_g']),
      baseCarbsTargetG: NumberUtils.toDouble(map['base_carbs_target_g']),
      baseFatTargetG: NumberUtils.toDouble(map['base_fat_target_g']),
      finalTargetCalories: NumberUtils.toDouble(map['final_target_calories']),
      finalProteinTargetG: NumberUtils.toDouble(map['final_protein_target_g']),
      finalCarbsTargetG: NumberUtils.toDouble(map['final_carbs_target_g']),
      finalFatTargetG: NumberUtils.toDouble(map['final_fat_target_g']),
      carbAdjustmentG: NumberUtils.toDouble(map['carb_adjustment_g']),
      carbTaperCurrentDeltaG: NumberUtils.toDouble(
        map['carb_taper_current_delta_g'],
      ),
      baseMacroEnergyEquivalentKcal: NumberUtils.toDouble(
        map['base_macro_energy_equivalent_kcal'],
      ),
      finalMacroEnergyEquivalentKcal: NumberUtils.toDouble(
        map['final_macro_energy_equivalent_kcal'],
      ),
      dietStrategyReasonCodes: _stringList(map['diet_strategy_reason_codes']),
      dietStrategyConfidence: NumberUtils.toDouble(
        map['diet_strategy_confidence'],
      ),
      macroEnergyEquivalentKcal: NumberUtils.toDouble(
        map['macro_energy_equivalent_kcal'],
      ),
      lifestyleFactorUsed: NumberUtils.toDouble(map['lifestyle_factor_used']),
      exerciseCaloriesNet: NumberUtils.toDouble(map['exercise_calories_net']),
      noExerciseBaselineTdee: NumberUtils.toDouble(
        map['no_exercise_baseline_tdee'],
      ),
      noExerciseTargetIntake: NumberUtils.toDouble(
        map['no_exercise_target_intake'],
      ),
      calibrationConfidence: NumberUtils.toDouble(
        map['calibration_confidence'],
      ),
      calibrationWindowDays: NumberUtils.toInt(map['calibration_window_days']),
      calibrationValidDays: NumberUtils.toInt(map['calibration_valid_days']),
      macroSelfCheckCurrentFrequency: NumberUtils.toNullableInt(
        map['macro_self_check_current_frequency'],
      ),
      macroSelfCheckRecommendedFrequency: NumberUtils.toNullableInt(
        map['macro_self_check_recommended_frequency'],
      ),
      macroSelfCheckActiveTrainingDays: NumberUtils.toNullableInt(
        map['macro_self_check_active_training_days'],
      ),
      macroSelfCheckPeriodDays: NumberUtils.toNullableInt(
        map['macro_self_check_period_days'],
      ),
      macroSelfCheckAverageWeeklyFrequency:
          map['macro_self_check_average_weekly_frequency'] == null
          ? null
          : NumberUtils.toDouble(
              map['macro_self_check_average_weekly_frequency'],
            ),
      macroSelfCheckShouldSuggest: _bool(
        map['macro_self_check_should_suggest'],
      ),
      macroSelfCheckHasValidTrainingData: _bool(
        map['macro_self_check_has_valid_training_data'],
      ),
      macroSelfCheckBelowRecommendedRange: _bool(
        map['macro_self_check_below_recommended_range'],
      ),
      calibrationUpdatedToday: _bool(map['calibration_updated_today']),
      hasPendingDietAdjustmentReview: _bool(
        map['has_pending_diet_adjustment_review'],
      ),
      pendingDietAdjustmentAction: map['pending_diet_adjustment_action']
          ?.toString(),
      foodRecords: foodRecords,
      workoutSessions: workoutSessions,
    );
  }

  static bool _bool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    return value?.toString().toLowerCase() == 'true';
  }

  static List<String> _stringList(Object? value) {
    if (value is Iterable) {
      return value.map((item) => item.toString()).toList();
    }
    return const <String>[];
  }

  static List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! Iterable) {
      return const <Map<String, dynamic>>[];
    }
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
