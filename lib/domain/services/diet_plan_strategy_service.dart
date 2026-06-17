import '../../core/constants/app_constants.dart';
import '../models/diet_plan_strategy_result.dart';
import '../models/user_profile.dart';
import 'carb_cycling_calculator.dart';
import 'carb_taper_review_service.dart';

class DietPlanStrategyService {
  const DietPlanStrategyService({
    CarbCyclingCalculator? carbCyclingCalculator,
    required CarbTaperReviewService carbTaperReviewService,
  }) : _carbCyclingCalculator =
           carbCyclingCalculator ?? const CarbCyclingCalculator(),
       _carbTaperReviewService = carbTaperReviewService;

  final CarbCyclingCalculator _carbCyclingCalculator;
  final CarbTaperReviewService _carbTaperReviewService;

  Future<DietPlanStrategyResult> apply({
    required UserProfile profile,
    required String day,
    required bool isEnergyTargetMode,
    required double baseProteinG,
    required double baseCarbsG,
    required double baseFatG,
    required String? latestPendingDietAdjustmentAction,
  }) async {
    switch (profile.dietPlanStrategy) {
      case AppConstants.dietPlanStrategyCarbCycling:
        return _carbCyclingCalculator.calculate(
          profile: profile,
          day: day,
          isEnergyTargetMode: isEnergyTargetMode,
          baseProteinG: baseProteinG,
          baseCarbsG: baseCarbsG,
          baseFatG: baseFatG,
        );
      case AppConstants.dietPlanStrategyCarbTapering:
        return _applyCarbTapering(
          profile: profile,
          isEnergyTargetMode: isEnergyTargetMode,
          baseProteinG: baseProteinG,
          baseCarbsG: baseCarbsG,
          baseFatG: baseFatG,
          latestPendingDietAdjustmentAction: latestPendingDietAdjustmentAction,
        );
      case AppConstants.dietPlanStrategyNone:
      default:
        return _buildBaseResult(
          isEnergyTargetMode: isEnergyTargetMode,
          baseProteinG: baseProteinG,
          baseCarbsG: baseCarbsG,
          baseFatG: baseFatG,
        );
    }
  }

  Future<DietPlanStrategyResult> _applyCarbTapering({
    required UserProfile profile,
    required bool isEnergyTargetMode,
    required double baseProteinG,
    required double baseCarbsG,
    required double baseFatG,
    required String? latestPendingDietAdjustmentAction,
  }) async {
    if (profile.isMinor ||
        profile.dietGoalPhase != AppConstants.dietGoalPhaseCutting) {
      return _buildBaseResult(
        isEnergyTargetMode: isEnergyTargetMode,
        baseProteinG: baseProteinG,
        baseCarbsG: baseCarbsG,
        baseFatG: baseFatG,
        reasonCodes: <String>[
          if (profile.isMinor) 'minor_cutting_strategy_blocked',
          if (profile.dietGoalPhase != AppConstants.dietGoalPhaseCutting)
            'unsupported_goal_phase',
        ],
      );
    }
    final minCarbsG = _carbTaperReviewService.minimumCarbsGForWeight(
      profile.weightKg,
    );
    var finalCarbsG = baseCarbsG + profile.carbTaperCurrentDeltaG;
    final reasonCodes = <String>[];
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
      dietPlanStrategy: AppConstants.dietPlanStrategyCarbTapering,
      carbAdjustmentG: finalCarbsG - baseCarbsG,
      carbTaperCurrentDeltaG: profile.carbTaperCurrentDeltaG,
      pendingDietAdjustmentAction: latestPendingDietAdjustmentAction,
      reasonCodes: reasonCodes,
    );
  }

  DietPlanStrategyResult _buildBaseResult({
    required bool isEnergyTargetMode,
    required double baseProteinG,
    required double baseCarbsG,
    required double baseFatG,
    List<String> reasonCodes = const <String>[],
  }) {
    final macroKcal = _macroKcal(
      proteinG: baseProteinG,
      carbsG: baseCarbsG,
      fatG: baseFatG,
    );
    return DietPlanStrategyResult(
      finalTargetIntakeKcal: isEnergyTargetMode ? macroKcal : 0,
      finalProteinG: baseProteinG,
      finalCarbsG: baseCarbsG,
      finalFatG: baseFatG,
      finalMacroEnergyEquivalentKcal: macroKcal,
      dietPlanStrategy: AppConstants.dietPlanStrategyNone,
      carbAdjustmentG: 0,
      carbTaperCurrentDeltaG: 0,
      reasonCodes: reasonCodes,
    );
  }

  double _macroKcal({
    required double proteinG,
    required double carbsG,
    required double fatG,
  }) {
    return proteinG * 4 + carbsG * 4 + fatG * 9;
  }
}
