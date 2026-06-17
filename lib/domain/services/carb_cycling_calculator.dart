import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';
import '../models/diet_plan_strategy_result.dart';
import '../models/user_profile.dart';

class CarbCyclingCalculator {
  const CarbCyclingCalculator();

  DietPlanStrategyResult calculate({
    required UserProfile profile,
    required String day,
    required bool isEnergyTargetMode,
    required double baseProteinG,
    required double baseCarbsG,
    required double baseFatG,
  }) {
    if (profile.isMinor ||
        profile.dietGoalPhase != AppConstants.dietGoalPhaseCutting ||
        profile.dietPlanStrategy != AppConstants.dietPlanStrategyCarbCycling) {
      return _baseResult(
        profile: profile,
        isEnergyTargetMode: isEnergyTargetMode,
        proteinG: baseProteinG,
        carbsG: baseCarbsG,
        fatG: baseFatG,
        reasonCodes: <String>[
          if (profile.isMinor) 'minor_cutting_strategy_blocked',
          if (profile.dietGoalPhase != AppConstants.dietGoalPhaseCutting)
            'unsupported_goal_phase',
        ],
      );
    }

    final pattern = profile.carbCyclePattern;
    final multipliers = <String, double>{
      AppConstants.carbDayHigh: profile.carbCycleHighMultiplier,
      AppConstants.carbDayMedium: profile.carbCycleMediumMultiplier,
      AppConstants.carbDayLow: profile.carbCycleLowMultiplier,
    };
    final rawSum = AppConstants.carbCycleWeekdayKeys.fold<double>(
      0,
      (sum, key) => sum + (multipliers[pattern[key]] ?? 1.0),
    );
    final normalizer = rawSum <= 0 ? 1.0 : 7 / rawSum;
    final dayType =
        pattern[AppConstants.weekdayKeyFromDateTime(
          DateUtilsX.parseDay(day),
        )] ??
        AppConstants.carbDayMedium;
    final normalizedMultiplier = (multipliers[dayType] ?? 1.0) * normalizer;
    var finalCarbsG = baseCarbsG * normalizedMultiplier;
    final reasonCodes = <String>[];
    final minCarbsG = _minimumCarbsG(profile.weightKg);
    if (finalCarbsG < minCarbsG) {
      finalCarbsG = minCarbsG;
      reasonCodes.add('carb_floor_applied');
    }
    final finalMacroEnergyEquivalentKcal = _macroKcal(
      proteinG: baseProteinG,
      carbsG: finalCarbsG,
      fatG: baseFatG,
    );

    return DietPlanStrategyResult(
      finalTargetIntakeKcal: isEnergyTargetMode
          ? finalMacroEnergyEquivalentKcal
          : 0,
      finalProteinG: baseProteinG,
      finalCarbsG: finalCarbsG,
      finalFatG: baseFatG,
      finalMacroEnergyEquivalentKcal: finalMacroEnergyEquivalentKcal,
      dietPlanStrategy: AppConstants.dietPlanStrategyCarbCycling,
      carbDayType: dayType,
      carbAdjustmentG: finalCarbsG - baseCarbsG,
      carbTaperCurrentDeltaG: profile.carbTaperCurrentDeltaG,
      confidence: 1,
      reasonCodes: reasonCodes,
    );
  }

  double minimumCarbsGForWeight(double weightKg) => _minimumCarbsG(weightKg);

  DietPlanStrategyResult _baseResult({
    required UserProfile profile,
    required bool isEnergyTargetMode,
    required double proteinG,
    required double carbsG,
    required double fatG,
    List<String> reasonCodes = const <String>[],
  }) {
    final macroKcal = _macroKcal(
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
    );
    return DietPlanStrategyResult(
      finalTargetIntakeKcal: isEnergyTargetMode ? macroKcal : 0,
      finalProteinG: proteinG,
      finalCarbsG: carbsG,
      finalFatG: fatG,
      finalMacroEnergyEquivalentKcal: macroKcal,
      dietPlanStrategy: AppConstants.dietPlanStrategyNone,
      carbAdjustmentG: 0,
      carbTaperCurrentDeltaG: profile.carbTaperCurrentDeltaG,
      reasonCodes: reasonCodes,
    );
  }

  double _minimumCarbsG(double weightKg) {
    final byWeight = weightKg * AppConstants.carbSafetyFloorPerKg;
    return byWeight > AppConstants.carbSafetyFloorMinimumG
        ? byWeight
        : AppConstants.carbSafetyFloorMinimumG;
  }

  double _macroKcal({
    required double proteinG,
    required double carbsG,
    required double fatG,
  }) {
    return proteinG * 4 + carbsG * 4 + fatG * 9;
  }
}
