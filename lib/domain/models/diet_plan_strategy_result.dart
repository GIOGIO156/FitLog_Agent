class DietPlanStrategyResult {
  const DietPlanStrategyResult({
    required this.finalTargetIntakeKcal,
    required this.finalProteinG,
    required this.finalCarbsG,
    required this.finalFatG,
    required this.finalMacroEnergyEquivalentKcal,
    required this.dietPlanStrategy,
    this.carbDayType,
    required this.carbAdjustmentG,
    required this.carbTaperCurrentDeltaG,
    this.pendingDietAdjustmentAction,
    this.confidence = 0,
    this.reasonCodes = const <String>[],
  });

  final double finalTargetIntakeKcal;
  final double finalProteinG;
  final double finalCarbsG;
  final double finalFatG;
  final double finalMacroEnergyEquivalentKcal;
  final String dietPlanStrategy;
  final String? carbDayType;
  final double carbAdjustmentG;
  final double carbTaperCurrentDeltaG;
  final String? pendingDietAdjustmentAction;
  final double confidence;
  final List<String> reasonCodes;
}
