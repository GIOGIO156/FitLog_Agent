import 'dart:convert';

import '../../core/constants/app_constants.dart';
import '../../core/utils/number_utils.dart';

class DietAdjustmentReview {
  const DietAdjustmentReview({
    this.id,
    required this.reviewDate,
    required this.windowDays,
    required this.dietGoalPhase,
    required this.dietCalculationMode,
    required this.dietPlanStrategy,
    this.startAvgWeightKg,
    this.endAvgWeightKg,
    this.weightChangeKg,
    this.lossRatePctPerWeek,
    this.targetLossPctPerWeek,
    required this.foodLogCoverage,
    required this.activeTrainingDays,
    required this.suggestedAction,
    required this.suggestedCarbDeltaG,
    this.appliedDeltaAfterG,
    required this.confidence,
    this.reasonCodes = const <String>[],
    required this.userDecision,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String reviewDate;
  final int windowDays;
  final String dietGoalPhase;
  final String dietCalculationMode;
  final String dietPlanStrategy;
  final double? startAvgWeightKg;
  final double? endAvgWeightKg;
  final double? weightChangeKg;
  final double? lossRatePctPerWeek;
  final double? targetLossPctPerWeek;
  final double foodLogCoverage;
  final int activeTrainingDays;
  final String suggestedAction;
  final double suggestedCarbDeltaG;
  final double? appliedDeltaAfterG;
  final double confidence;
  final List<String> reasonCodes;
  final String userDecision;
  final String? createdAt;
  final String? updatedAt;

  String get reasonCodesJson => jsonEncode(reasonCodes);

  DietAdjustmentReview copyWith({
    int? id,
    String? reviewDate,
    int? windowDays,
    String? dietGoalPhase,
    String? dietCalculationMode,
    String? dietPlanStrategy,
    double? startAvgWeightKg,
    double? endAvgWeightKg,
    double? weightChangeKg,
    double? lossRatePctPerWeek,
    double? targetLossPctPerWeek,
    double? foodLogCoverage,
    int? activeTrainingDays,
    String? suggestedAction,
    double? suggestedCarbDeltaG,
    double? appliedDeltaAfterG,
    double? confidence,
    List<String>? reasonCodes,
    String? userDecision,
    String? createdAt,
    String? updatedAt,
  }) {
    return DietAdjustmentReview(
      id: id ?? this.id,
      reviewDate: reviewDate ?? this.reviewDate,
      windowDays: windowDays ?? this.windowDays,
      dietGoalPhase: dietGoalPhase ?? this.dietGoalPhase,
      dietCalculationMode: dietCalculationMode ?? this.dietCalculationMode,
      dietPlanStrategy: dietPlanStrategy ?? this.dietPlanStrategy,
      startAvgWeightKg: startAvgWeightKg ?? this.startAvgWeightKg,
      endAvgWeightKg: endAvgWeightKg ?? this.endAvgWeightKg,
      weightChangeKg: weightChangeKg ?? this.weightChangeKg,
      lossRatePctPerWeek: lossRatePctPerWeek ?? this.lossRatePctPerWeek,
      targetLossPctPerWeek: targetLossPctPerWeek ?? this.targetLossPctPerWeek,
      foodLogCoverage: foodLogCoverage ?? this.foodLogCoverage,
      activeTrainingDays: activeTrainingDays ?? this.activeTrainingDays,
      suggestedAction: suggestedAction ?? this.suggestedAction,
      suggestedCarbDeltaG: suggestedCarbDeltaG ?? this.suggestedCarbDeltaG,
      appliedDeltaAfterG: appliedDeltaAfterG ?? this.appliedDeltaAfterG,
      confidence: confidence ?? this.confidence,
      reasonCodes: reasonCodes ?? this.reasonCodes,
      userDecision: userDecision ?? this.userDecision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'review_date': reviewDate,
      'window_days': windowDays,
      'diet_goal_phase': dietGoalPhase,
      'diet_calculation_mode': dietCalculationMode,
      'diet_plan_strategy': dietPlanStrategy,
      'start_avg_weight_kg': startAvgWeightKg,
      'end_avg_weight_kg': endAvgWeightKg,
      'weight_change_kg': weightChangeKg,
      'loss_rate_pct_per_week': lossRatePctPerWeek,
      'target_loss_pct_per_week': targetLossPctPerWeek,
      'food_log_coverage': foodLogCoverage,
      'active_training_days': activeTrainingDays,
      'suggested_action': suggestedAction,
      'suggested_carb_delta_g': suggestedCarbDeltaG,
      'applied_delta_after_g': appliedDeltaAfterG,
      'confidence': confidence,
      'reason_codes_json': reasonCodesJson,
      'user_decision': userDecision,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory DietAdjustmentReview.fromMap(Map<String, dynamic> map) {
    final rawReasons = map['reason_codes_json']?.toString();
    final decodedReasons = <String>[];
    if (rawReasons != null && rawReasons.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(rawReasons);
        if (parsed is List) {
          decodedReasons.addAll(parsed.map((item) => item.toString()));
        }
      } catch (_) {}
    }
    return DietAdjustmentReview(
      id: NumberUtils.toNullableInt(map['id']),
      reviewDate: (map['review_date'] ?? '').toString(),
      windowDays: NumberUtils.toInt(map['window_days']),
      dietGoalPhase: (map['diet_goal_phase'] ?? '').toString(),
      dietCalculationMode: (map['diet_calculation_mode'] ?? '').toString(),
      dietPlanStrategy:
          (map['diet_plan_strategy'] ??
                  AppConstants.dietPlanStrategyCarbTapering)
              .toString(),
      startAvgWeightKg: map['start_avg_weight_kg'] == null
          ? null
          : NumberUtils.toDouble(map['start_avg_weight_kg']),
      endAvgWeightKg: map['end_avg_weight_kg'] == null
          ? null
          : NumberUtils.toDouble(map['end_avg_weight_kg']),
      weightChangeKg: map['weight_change_kg'] == null
          ? null
          : NumberUtils.toDouble(map['weight_change_kg']),
      lossRatePctPerWeek: map['loss_rate_pct_per_week'] == null
          ? null
          : NumberUtils.toDouble(map['loss_rate_pct_per_week']),
      targetLossPctPerWeek: map['target_loss_pct_per_week'] == null
          ? null
          : NumberUtils.toDouble(map['target_loss_pct_per_week']),
      foodLogCoverage: NumberUtils.toDouble(map['food_log_coverage']),
      activeTrainingDays: NumberUtils.toInt(map['active_training_days']),
      suggestedAction:
          (map['suggested_action'] ?? AppConstants.dietAdjustmentActionKeep)
              .toString(),
      suggestedCarbDeltaG: NumberUtils.toDouble(map['suggested_carb_delta_g']),
      appliedDeltaAfterG: map['applied_delta_after_g'] == null
          ? null
          : NumberUtils.toDouble(map['applied_delta_after_g']),
      confidence: NumberUtils.toDouble(map['confidence']),
      reasonCodes: decodedReasons,
      userDecision:
          (map['user_decision'] ?? AppConstants.dietAdjustmentDecisionPending)
              .toString(),
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }
}
