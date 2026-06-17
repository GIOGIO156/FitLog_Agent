import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/localization/app_strings.dart';
import '../../core/widgets/profile_form_fields.dart';
import '../../domain/models/carb_taper_review_result.dart';

class DietPlanStrategySection extends StatelessWidget {
  const DietPlanStrategySection({
    super.key,
    required this.strings,
    this.showStrategyPicker = true,
    required this.canUseCuttingStrategy,
    required this.isBulkingPhase,
    required this.dietPlanStrategy,
    required this.carbCyclePattern,
    required this.carbCyclePreview,
    required this.carbTaperReviewPeriodDays,
    required this.carbTaperTargetLossPctPerWeek,
    required this.carbTaperStepG,
    required this.carbTaperCurrentDeltaG,
    required this.carbTaperReviewResult,
    required this.hasPendingDietAdjustmentReview,
    required this.handlingCarbTaperAction,
    required this.onStrategyChanged,
    required this.onCarbCycleDayTypeChanged,
    required this.onCarbTaperReviewPeriodChanged,
    required this.onCarbTaperTargetLossChanged,
    required this.onCarbTaperStepChanged,
    required this.onApplyCarbTaperSuggestion,
    required this.onDismissCarbTaperSuggestion,
  });

  final AppStrings strings;
  final bool showStrategyPicker;
  final bool canUseCuttingStrategy;
  final bool isBulkingPhase;
  final String dietPlanStrategy;
  final Map<String, String> carbCyclePattern;
  final List<CarbCyclePreviewRow> carbCyclePreview;
  final int carbTaperReviewPeriodDays;
  final double carbTaperTargetLossPctPerWeek;
  final double carbTaperStepG;
  final double carbTaperCurrentDeltaG;
  final CarbTaperReviewResult? carbTaperReviewResult;
  final bool hasPendingDietAdjustmentReview;
  final bool handlingCarbTaperAction;
  final ValueChanged<String?>? onStrategyChanged;
  final void Function(String weekdayKey, String value)
  onCarbCycleDayTypeChanged;
  final ValueChanged<int?> onCarbTaperReviewPeriodChanged;
  final ValueChanged<double?> onCarbTaperTargetLossChanged;
  final ValueChanged<double?> onCarbTaperStepChanged;
  final VoidCallback? onApplyCarbTaperSuggestion;
  final VoidCallback? onDismissCarbTaperSuggestion;

  @override
  Widget build(BuildContext context) {
    if (isBulkingPhase) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          strings.strategyDisabledForBulking,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showStrategyPicker) ...<Widget>[
          ProfileOptionField<String>(
            value: dietPlanStrategy,
            labelText: strings.dietPlanStrategyLabel,
            options: AppConstants.dietPlanStrategies,
            labelBuilder: strings.strategyLabel,
            onChanged: onStrategyChanged,
          ),
          const SizedBox(height: 8),
        ],
        Text(
          canUseCuttingStrategy
              ? strings.cuttingOnlyStrategyNotice
              : strings.minorStrategyBlockedNotice,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (dietPlanStrategy ==
            AppConstants.dietPlanStrategyCarbCycling) ...<Widget>[
          const SizedBox(height: 12),
          _CarbCyclingSection(
            strings: strings,
            carbCyclePattern: carbCyclePattern,
            carbCyclePreview: carbCyclePreview,
            onCarbCycleDayTypeChanged: onCarbCycleDayTypeChanged,
          ),
        ],
        if (dietPlanStrategy ==
            AppConstants.dietPlanStrategyCarbTapering) ...<Widget>[
          const SizedBox(height: 12),
          _CarbTaperingSection(
            strings: strings,
            carbTaperReviewPeriodDays: carbTaperReviewPeriodDays,
            carbTaperTargetLossPctPerWeek: carbTaperTargetLossPctPerWeek,
            carbTaperStepG: carbTaperStepG,
            carbTaperCurrentDeltaG: carbTaperCurrentDeltaG,
            carbTaperReviewResult: carbTaperReviewResult,
            hasPendingDietAdjustmentReview: hasPendingDietAdjustmentReview,
            handlingCarbTaperAction: handlingCarbTaperAction,
            onCarbTaperReviewPeriodChanged: onCarbTaperReviewPeriodChanged,
            onCarbTaperTargetLossChanged: onCarbTaperTargetLossChanged,
            onCarbTaperStepChanged: onCarbTaperStepChanged,
            onApplyCarbTaperSuggestion: onApplyCarbTaperSuggestion,
            onDismissCarbTaperSuggestion: onDismissCarbTaperSuggestion,
          ),
        ],
      ],
    );
  }
}

class CarbCyclePreviewRow {
  const CarbCyclePreviewRow({
    required this.weekdayKey,
    required this.date,
    required this.carbDayType,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.macroKcal,
  });

  final String weekdayKey;
  final String date;
  final String carbDayType;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double macroKcal;
}

class _CarbCyclingSection extends StatelessWidget {
  const _CarbCyclingSection({
    required this.strings,
    required this.carbCyclePattern,
    required this.carbCyclePreview,
    required this.onCarbCycleDayTypeChanged,
  });

  final AppStrings strings;
  final Map<String, String> carbCyclePattern;
  final List<CarbCyclePreviewRow> carbCyclePreview;
  final void Function(String weekdayKey, String value)
  onCarbCycleDayTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          strings.weeklyCarbPatternLabel,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          strings.carbCyclingIntro,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        ...AppConstants.carbCycleWeekdayKeys.map(
          (key) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ProfileOptionField<String>(
              value: carbCyclePattern[key] ?? AppConstants.carbDayMedium,
              labelText: strings.weekdayShortLabel(key),
              options: AppConstants.carbDayTypes,
              labelBuilder: strings.carbDayTypeFullLabel,
              onChanged: (value) {
                if (value != null) {
                  onCarbCycleDayTypeChanged(key, value);
                }
              },
            ),
          ),
        ),
        Text(
          '${strings.carbCycleMultiplierLabel}: High ${AppConstants.defaultCarbCycleHighMultiplier.toStringAsFixed(2)} / Medium ${AppConstants.defaultCarbCycleMediumMultiplier.toStringAsFixed(2)} / Low ${AppConstants.defaultCarbCycleLowMultiplier.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Text(
          strings.carbCyclePreviewLabel,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        ...carbCyclePreview.map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${strings.weekdayShortLabel(row.weekdayKey)} ${row.date}: ${strings.carbDayTypeFullLabel(row.carbDayType)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'P ${row.proteinG.toStringAsFixed(1)} / C ${row.carbsG.toStringAsFixed(1)} / F ${row.fatG.toStringAsFixed(1)} - ${row.macroKcal.toStringAsFixed(0)} kcal',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CarbTaperingSection extends StatelessWidget {
  const _CarbTaperingSection({
    required this.strings,
    required this.carbTaperReviewPeriodDays,
    required this.carbTaperTargetLossPctPerWeek,
    required this.carbTaperStepG,
    required this.carbTaperCurrentDeltaG,
    required this.carbTaperReviewResult,
    required this.hasPendingDietAdjustmentReview,
    required this.handlingCarbTaperAction,
    required this.onCarbTaperReviewPeriodChanged,
    required this.onCarbTaperTargetLossChanged,
    required this.onCarbTaperStepChanged,
    required this.onApplyCarbTaperSuggestion,
    required this.onDismissCarbTaperSuggestion,
  });

  final AppStrings strings;
  final int carbTaperReviewPeriodDays;
  final double carbTaperTargetLossPctPerWeek;
  final double carbTaperStepG;
  final double carbTaperCurrentDeltaG;
  final CarbTaperReviewResult? carbTaperReviewResult;
  final bool hasPendingDietAdjustmentReview;
  final bool handlingCarbTaperAction;
  final ValueChanged<int?> onCarbTaperReviewPeriodChanged;
  final ValueChanged<double?> onCarbTaperTargetLossChanged;
  final ValueChanged<double?> onCarbTaperStepChanged;
  final VoidCallback? onApplyCarbTaperSuggestion;
  final VoidCallback? onDismissCarbTaperSuggestion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          strings.carbTaperingIntro,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        ProfileOptionField<int>(
          value: carbTaperReviewPeriodDays,
          labelText: strings.carbTaperReviewPeriodLabel,
          options: AppConstants.carbTaperReviewPeriodDayOptions,
          labelBuilder: strings.macroSelfCheckPeriodOptionLabel,
          onChanged: onCarbTaperReviewPeriodChanged,
        ),
        const SizedBox(height: 10),
        ProfileOptionField<double>(
          value: carbTaperTargetLossPctPerWeek,
          labelText: strings.carbTaperTargetLossLabel,
          options: const <double>[0.25, 0.50, 0.75, 1.0],
          labelBuilder: (value) => '${value.toStringAsFixed(2)}% / week',
          onChanged: onCarbTaperTargetLossChanged,
        ),
        const SizedBox(height: 10),
        ProfileOptionField<double>(
          value: carbTaperStepG,
          labelText: strings.carbTaperStepLabel,
          options: AppConstants.carbTaperStepOptionsG,
          labelBuilder: (value) => '${value.toStringAsFixed(0)} g/day',
          onChanged: onCarbTaperStepChanged,
        ),
        const SizedBox(height: 8),
        Text(
          '${strings.carbTaperCurrentOffsetLabel}: ${strings.carbOffsetText(carbTaperCurrentDeltaG)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (carbTaperReviewResult != null) ...<Widget>[
          const SizedBox(height: 12),
          CarbTaperReviewCard(
            strings: strings,
            review: carbTaperReviewResult!,
            hasPendingReview: hasPendingDietAdjustmentReview,
            handlingAction: handlingCarbTaperAction,
            onApply: onApplyCarbTaperSuggestion,
            onDismiss: onDismissCarbTaperSuggestion,
          ),
        ],
      ],
    );
  }
}

class CarbTaperReviewCard extends StatelessWidget {
  const CarbTaperReviewCard({
    super.key,
    required this.strings,
    required this.review,
    required this.hasPendingReview,
    required this.handlingAction,
    required this.onApply,
    required this.onDismiss,
  });

  final AppStrings strings;
  final CarbTaperReviewResult review;
  final bool hasPendingReview;
  final bool handlingAction;
  final VoidCallback? onApply;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final visibleReasonCodes = review.reasonCodes
        .where((code) => code != 'review_cooldown_active')
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings.carbTaperReviewTitle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('${strings.carbTaperReviewPeriodLabel}: ${review.windowDays} d'),
          if (review.lossRatePctPerWeek != null)
            Text(strings.weightTrendText(review.lossRatePctPerWeek!)),
          if (review.targetLossPctPerWeek != null)
            Text(strings.targetLossRateText(review.targetLossPctPerWeek!)),
          Text(strings.foodCoverageText(review.foodLogCoverage)),
          Text(strings.trainingDaysText(review.activeTrainingDays)),
          Text(
            '${strings.strategyBadgeLabel}: ${strings.carbTaperReviewActionLabel(review.suggestedAction)}',
          ),
          if (visibleReasonCodes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: visibleReasonCodes
                    .map(
                      (code) => Text(
                        strings.carbTaperReasonLabel(code),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                    .toList(),
              ),
            ),
          if (hasPendingReview) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                if (onApply != null)
                  Expanded(
                    child: FilledButton(
                      onPressed: handlingAction ? null : onApply,
                      child: Text(
                        strings.applyCarbDeltaButton(
                          review.suggestedCarbDeltaG.abs(),
                        ),
                      ),
                    ),
                  ),
                if (onApply != null) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: handlingAction ? null : onDismiss,
                    child: Text(strings.dismissLabel),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
