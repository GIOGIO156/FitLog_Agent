class CarbTaperReviewResult {
  const CarbTaperReviewResult({
    required this.isApplicable,
    required this.isReviewDue,
    required this.windowDays,
    required this.currentCarbDeltaG,
    required this.suggestedAction,
    required this.suggestedCarbDeltaG,
    required this.projectedCarbDeltaAfterG,
    required this.foodLogCoverage,
    required this.activeTrainingDays,
    required this.confidence,
    this.startAvgWeightKg,
    this.endAvgWeightKg,
    this.weightChangeKg,
    this.lossRatePctPerWeek,
    this.targetLossPctPerWeek,
    this.trainingDropDetected = false,
    this.reasonCodes = const <String>[],
  });

  final bool isApplicable;
  final bool isReviewDue;
  final int windowDays;
  final double currentCarbDeltaG;
  final String suggestedAction;
  final double suggestedCarbDeltaG;
  final double projectedCarbDeltaAfterG;
  final double foodLogCoverage;
  final int activeTrainingDays;
  final double confidence;
  final double? startAvgWeightKg;
  final double? endAvgWeightKg;
  final double? weightChangeKg;
  final double? lossRatePctPerWeek;
  final double? targetLossPctPerWeek;
  final bool trainingDropDetected;
  final List<String> reasonCodes;
}
