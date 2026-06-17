class TrainingFrequencySelfCheckResult {
  const TrainingFrequencySelfCheckResult({
    required this.isApplicable,
    required this.isEnabled,
    required this.periodDays,
    required this.activeTrainingDays,
    required this.averageWeeklyTrainingFrequency,
    required this.currentTrainingFrequency,
    required this.recommendedTrainingFrequency,
    required this.hasValidTrainingData,
    required this.shouldSuggestAdjustment,
    required this.belowRecommendedRange,
  });

  final bool isApplicable;
  final bool isEnabled;
  final int periodDays;
  final int activeTrainingDays;
  final double averageWeeklyTrainingFrequency;
  final int currentTrainingFrequency;
  final int recommendedTrainingFrequency;
  final bool hasValidTrainingData;
  final bool shouldSuggestAdjustment;
  final bool belowRecommendedRange;

  bool get isConsistent =>
      recommendedTrainingFrequency == currentTrainingFrequency;
}
