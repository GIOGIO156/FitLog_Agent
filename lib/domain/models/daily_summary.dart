import 'food_record.dart';
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
}
