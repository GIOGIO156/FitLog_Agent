import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/fitlog_icon_assets.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/localization_extensions.dart';
import '../../core/theme/fitlog_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/fitlog_bottom_nav_bar.dart';
import '../../core/widgets/fitlog_ui.dart';
import '../../core/widgets/glass_panel.dart';
import '../../domain/models/daily_summary.dart';
import '../../domain/models/user_profile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<_HomePageData>? _dataFuture;
  String? _loadedDate;
  int? _loadedRefreshVersion;

  Future<_HomePageData> _loadData(BuildContext context, String day) async {
    final services = context.read<AppServices>();
    final results = await Future.wait<Object?>(<Future<Object?>>[
      services.dailySummaryService.getSummaryForDate(day),
      services.profileRepository.getProfile(),
    ]);

    return _HomePageData(
      summary: results[0]! as DailySummary,
      profile: results[1] as UserProfile?,
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    SelectedDateNotifier selectedDateNotifier,
  ) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateUtilsX.parseDay(selectedDateNotifier.selectedDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected != null && context.mounted) {
      selectedDateNotifier.setDate(DateUtilsX.formatDate(selected));
    }
  }

  String _greetingForNow(AppStrings strings) {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return strings.morningGreeting;
    }
    if (hour >= 12 && hour < 18) {
      return strings.afternoonGreeting;
    }
    return strings.eveningGreeting;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return SafeArea(
      child: Consumer2<RefreshNotifier, SelectedDateNotifier>(
        builder: (context, refresh, selectedDateNotifier, _) {
          refresh.version;
          final selectedDate = selectedDateNotifier.selectedDate;
          if (_dataFuture == null ||
              _loadedDate != selectedDate ||
              _loadedRefreshVersion != refresh.version) {
            _loadedDate = selectedDate;
            _loadedRefreshVersion = refresh.version;
            _dataFuture = _loadData(context, selectedDate);
          }

          return FutureBuilder<_HomePageData>(
            future: _dataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(strings.summaryError(snapshot.error!)),
                );
              }

              final data = snapshot.data;
              if (data == null) {
                return Center(child: Text(strings.noSummaryData));
              }

              final profile = data.profile;
              final summary = data.summary;
              final effectiveProfile = profile ?? UserProfile.defaults;
              final isGramPerKgMode =
                  summary.dietCalculationMode ==
                  AppConstants.dietCalculationModeGramPerKg;
              final nickname = ((profile?.nickname ?? '').trim().isEmpty)
                  ? strings.nicknameFallback
                  : profile!.nickname!.trim();
              final greetingPrefix = _greetingForNow(strings);

              return LayoutBuilder(
                builder: (context, constraints) {
                  final firstScreenBottomReserve =
                      FitLogBottomNavBar.homeFirstScreenBottomReserveFor(
                        context,
                      );
                  final firstScreenHeight = math.max(
                    0.0,
                    constraints.maxHeight - firstScreenBottomReserve,
                  );
                  return ListView(
                    padding: EdgeInsets.only(
                      bottom: FitLogBottomNavBar.scrollBottomPaddingFor(
                        context,
                      ),
                    ),
                    children: <Widget>[
                      SizedBox(
                        height: firstScreenHeight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            FitLogPageHeader(
                              title: '',
                              titleWidget: _HomeGreeting(
                                greetingPrefix: greetingPrefix,
                                nickname: nickname,
                                isChinese: strings.isChinese,
                              ),
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                              trailing: FitLogActionIconButton(
                                icon: Icons.calendar_today_outlined,
                                tooltip: strings.change,
                                onPressed: () =>
                                    _pickDate(context, selectedDateNotifier),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                              child: Text(
                                DateUtilsX.formatReadable(summary.date),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: context.fitLogTheme.mutedText,
                                    ),
                              ),
                            ),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, dashboardConstraints) {
                                  final dashboardHeight =
                                      dashboardConstraints.maxHeight;

                                  return isGramPerKgMode
                                      ? _GramPerKgDashboard(
                                          summary: summary,
                                          strings: strings,
                                          height: dashboardHeight,
                                        )
                                      : _EnergyRatioDashboard(
                                          summary: summary,
                                          strings: strings,
                                          height: dashboardHeight,
                                        );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: firstScreenBottomReserve),
                      if (isGramPerKgMode) ...<Widget>[
                        const SizedBox(height: 20),
                        _StrategyCard(
                          summary: summary,
                          profile: effectiveProfile,
                          strings: strings,
                        ),
                      ] else ...<Widget>[
                        _StrategyCard(
                          summary: summary,
                          profile: effectiveProfile,
                          strings: strings,
                        ),
                        _TodayRecordsCard(summary: summary, strings: strings),
                      ],
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _HomePageData {
  const _HomePageData({required this.summary, required this.profile});

  final DailySummary summary;
  final UserProfile? profile;
}

class _EnergyRatioDashboard extends StatelessWidget {
  const _EnergyRatioDashboard({
    required this.summary,
    required this.strings,
    required this.height,
  });

  final DailySummary summary;
  final AppStrings strings;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Column(
        children: <Widget>[
          _CaloriesHero(summary: summary, strings: strings),
          const Spacer(),
          _MacrosCard(summary: summary, strings: strings),
        ],
      ),
    );
  }
}

class _CaloriesHero extends StatelessWidget {
  const _CaloriesHero({required this.summary, required this.strings});

  final DailySummary summary;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    final isGramPerKgMode =
        summary.dietCalculationMode ==
        AppConstants.dietCalculationModeGramPerKg;
    final progressBase = isGramPerKgMode
        ? math.max(summary.macroEnergyEquivalentKcal, 1)
        : math.max(summary.targetIntake, 1);
    final progress = (summary.caloriesIn / progressBase).clamp(0.0, 1.0);
    final heroValue = isGramPerKgMode
        ? summary.macroEnergyEquivalentKcal
        : summary.caloriesIn;
    final energyRingState = _energyRingState(summary, fitTheme);
    final ringValue = isGramPerKgMode ? progress : energyRingState.ringValue;
    final ringColor = isGramPerKgMode
        ? fitTheme.primary
        : energyRingState.ringColor;
    final ringBackgroundColor = isGramPerKgMode
        ? fitTheme.primarySoft
        : energyRingState.backgroundColor;
    final remainingAccent = isGramPerKgMode
        ? fitTheme.primaryDeep
        : energyRingState.accentColor;
    const ringSize = 170.0;
    const panelPadding = EdgeInsets.fromLTRB(20, 20, 20, 22);
    const titleGap = 18.0;
    const sideGap = 20.0;
    const metricGap = 14.0;

    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: panelPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings.caloriesRingTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: titleGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: ringSize,
                height: ringSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: ringSize,
                      height: ringSize,
                      child: CircularProgressIndicator(
                        value: ringValue,
                        strokeWidth: 12,
                        backgroundColor: ringBackgroundColor,
                        valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          heroValue.toStringAsFixed(0),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: fitTheme.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'kcal',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: sideGap),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _HeroMetric(
                        label: isGramPerKgMode
                            ? strings.macroEquivalentEnergyLabel
                            : strings.remainingCaloriesLabel,
                        value: isGramPerKgMode
                            ? '${summary.macroEnergyEquivalentKcal.toStringAsFixed(0)} kcal'
                            : '${summary.remainingCalories.toStringAsFixed(0)} kcal',
                        emphasize: remainingAccent,
                      ),
                      SizedBox(height: metricGap),
                      _HeroMetric(
                        label: isGramPerKgMode
                            ? strings.caloriesInTodayLabel
                            : strings.targetIntakeLabel,
                        value: isGramPerKgMode
                            ? '${summary.caloriesIn.toStringAsFixed(0)} kcal'
                            : '${summary.targetIntake.toStringAsFixed(0)} kcal',
                      ),
                      SizedBox(height: metricGap),
                      _HeroMetric(
                        label: strings.exerciseCaloriesTodayLabel,
                        value:
                            '${summary.exerciseCalories.toStringAsFixed(0)} kcal',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value, this.emphasize});

  final String label;
  final String value;
  final Color? emphasize;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: fitTheme.mutedText),
        ),
        const SizedBox(height: 2),
        _HeroMetricValueLine(
          value: value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: emphasize ?? fitTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20.5,
          ),
        ),
      ],
    );
  }
}

class _HeroMetricValueLine extends StatelessWidget {
  const _HeroMetricValueLine({required this.value, this.style});

  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final normalizedValue = value.replaceAll(' kcal', '\u00A0kcal');

    return SizedBox(
      width: double.infinity,
      height: 32,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            normalizedValue,
            maxLines: 1,
            softWrap: false,
            style: style,
          ),
        ),
      ),
    );
  }
}

class _MacrosCard extends StatelessWidget {
  const _MacrosCard({required this.summary, required this.strings});

  final DailySummary summary;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: <Widget>[
          FitLogSectionHeader(
            title: strings.macrosTitle,
            actionLabel: strings.details,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _MacroMetricCard(
                  label: strings.proteinLabel,
                  current: summary.proteinG,
                  target: summary.targetProteinG,
                  color: const Color(0xFF6DBA57),
                  iconAsset: FitLogIconAssets.macroProtein,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MacroMetricCard(
                  label: strings.carbsLabel,
                  current: summary.carbsG,
                  target: summary.targetCarbsG,
                  color: const Color(0xFFF2B545),
                  iconAsset: FitLogIconAssets.macroCarbs,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MacroMetricCard(
                  label: strings.fatLabel,
                  current: summary.fatG,
                  target: summary.targetFatG,
                  color: const Color(0xFFE89257),
                  iconAsset: FitLogIconAssets.macroFat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GramPerKgDashboard extends StatelessWidget {
  const _GramPerKgDashboard({
    required this.summary,
    required this.strings,
    required this.height,
  });

  final DailySummary summary;
  final AppStrings strings;
  final double height;

  @override
  Widget build(BuildContext context) {
    final navController = context.read<RootTabController>();
    final fitTheme = context.fitLogTheme;
    final proteinProgress = _macroProgress(
      summary.proteinG,
      summary.targetProteinG,
    );
    final carbsProgress = _macroProgress(summary.carbsG, summary.targetCarbsG);
    final fatProgress = _macroProgress(summary.fatG, summary.targetFatG);
    final focus = _macroFocus(summary, strings);
    final allComplete =
        proteinProgress >= 1 && carbsProgress >= 1 && fatProgress >= 1;

    const stripHeight = 160.0;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rightColumnWidth = math.min(constraints.maxWidth * 0.40, 166.0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    Text(
                      strings.gramPerKgHeroTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: fitTheme.textSecondary,
                      ),
                    ),
                    Text(
                      strings.gramPerKgHeroModeSuffix,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: fitTheme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Positioned(
                      left: 0,
                      top: 12,
                      bottom: -18,
                      width: constraints.maxWidth * 0.90,
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AspectRatio(
                            aspectRatio: 0.56,
                            child: ClipRect(
                              child: CustomPaint(
                                painter: _TripleMacroArcPainter(
                                  proteinProgress: proteinProgress,
                                  carbsProgress: carbsProgress,
                                  fatProgress: fatProgress,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 20,
                      right: 2,
                      width: rightColumnWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            allComplete
                                ? strings.gramPerKgAllCompleteTitle
                                : strings.gramPerKgFocusTitle,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: fitTheme.mutedText),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            allComplete
                                ? strings.gramPerKgAllCompleteBody
                                : focus.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: allComplete
                                      ? fitTheme.textPrimary
                                      : focus.color,
                                  height: 1.02,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            allComplete
                                ? strings.gramPerKgBalancedHint
                                : strings.gramPerKgRemainingHint(
                                    math.max(focus.target - focus.current, 0),
                                  ),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: fitTheme.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  height: 1.0,
                                ),
                          ),
                          const SizedBox(height: 52),
                          _DashboardEnergyLink(
                            label: strings.caloriesInTodayLabel,
                            value: summary.caloriesIn.toStringAsFixed(0),
                            subtitle: strings.foodRecordsSummary(
                              summary.foodRecords.length,
                            ),
                            color: fitTheme.primary,
                            onTap: () =>
                                navController.setIndex(RootTabIndex.food),
                          ),
                          const SizedBox(height: 16),
                          _DashboardEnergyLink(
                            label: strings.exerciseCaloriesTodayLabel,
                            value: summary.exerciseCalories.toStringAsFixed(0),
                            subtitle: strings.workoutRecordsSummary(
                              summary.workoutSessions.length,
                            ),
                            color: const Color(0xFF3F78C0),
                            onTap: () =>
                                navController.setIndex(RootTabIndex.workout),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                child: SizedBox(
                  height: stripHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: _GramPerKgMacroStripColumn(
                          label: strings.proteinLabel,
                          current: summary.proteinG,
                          target: summary.targetProteinG,
                          progress: proteinProgress,
                          color: const Color(0xFF6DBA57),
                          iconAsset: FitLogIconAssets.macroProtein,
                          contentAlignment: const Alignment(-0.72, -1),
                        ),
                      ),
                      const _MacroStripDivider(),
                      Expanded(
                        child: _GramPerKgMacroStripColumn(
                          label: strings.carbsLabel,
                          current: summary.carbsG,
                          target: summary.targetCarbsG,
                          progress: carbsProgress,
                          color: const Color(0xFFF2B545),
                          iconAsset: FitLogIconAssets.macroCarbs,
                          contentAlignment: Alignment.topCenter,
                        ),
                      ),
                      const _MacroStripDivider(),
                      Expanded(
                        child: _GramPerKgMacroStripColumn(
                          label: strings.fatLabel,
                          current: summary.fatG,
                          target: summary.targetFatG,
                          progress: fatProgress,
                          color: const Color(0xFFE89257),
                          iconAsset: FitLogIconAssets.macroFat,
                          contentAlignment: const Alignment(0.72, -1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardEnergyLink extends StatelessWidget {
  const _DashboardEnergyLink({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textWidth = math.max(
            0.0,
            math.min(122.0, constraints.maxWidth - 22),
          );

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: textWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: fitTheme.mutedText),
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          height: 34,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: RichText(
                                text: TextSpan(
                                  children: <InlineSpan>[
                                    TextSpan(
                                      text: value,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: color,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 21,
                                            height: 1.0,
                                          ),
                                    ),
                                    TextSpan(
                                      text: ' kcal',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: color,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: fitTheme.mutedText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: fitTheme.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GramPerKgMacroStripColumn extends StatelessWidget {
  const _GramPerKgMacroStripColumn({
    required this.label,
    required this.current,
    required this.target,
    required this.progress,
    required this.color,
    required this.iconAsset,
    required this.contentAlignment,
  });

  final String label;
  final double current;
  final double target;
  final double progress;
  final Color color;
  final String iconAsset;
  final Alignment contentAlignment;

  @override
  Widget build(BuildContext context) {
    final iconSize = iconAsset == FitLogIconAssets.macroCarbs ? 30.0 : 22.0;
    final isCenter = contentAlignment.x == 0;
    final isRight = contentAlignment.x > 0;
    final textAlign = isCenter
        ? TextAlign.center
        : isRight
        ? TextAlign.right
        : TextAlign.left;
    final columnAlignment = isCenter
        ? CrossAxisAlignment.center
        : isRight
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Align(
      alignment: contentAlignment,
      child: SizedBox(
        width: 82,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: columnAlignment,
          children: <Widget>[
            const SizedBox(height: 4),
            _PngBadgeIcon(
              assetName: iconAsset,
              backgroundColor: color.withValues(alpha: 0.12),
              size: 40,
              iconSize: iconSize,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: textAlign,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              context.strings.macroProgressText(current, target),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: textAlign,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.fitLogTheme.textSecondary,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.strings.macroPercentText(progress),
              textAlign: textAlign,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}

class _MacroStripDivider extends StatelessWidget {
  const _MacroStripDivider();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 1,
        height: 102,
        color: context.fitLogTheme.outline,
      ),
    );
  }
}

class _MacroFocusData {
  const _MacroFocusData({
    required this.label,
    required this.color,
    required this.current,
    required this.target,
    required this.progress,
  });

  final String label;
  final Color color;
  final double current;
  final double target;
  final double progress;
}

class _EnergyRingState {
  const _EnergyRingState({
    required this.ringValue,
    required this.ringColor,
    required this.backgroundColor,
    required this.accentColor,
  });

  final double ringValue;
  final Color ringColor;
  final Color backgroundColor;
  final Color accentColor;
}

double _macroProgress(double current, double target) {
  if (target <= 0) {
    return 0;
  }
  return (current / target).clamp(0.0, 1.0);
}

_MacroFocusData _macroFocus(DailySummary summary, AppStrings strings) {
  final options = <_MacroFocusData>[
    _MacroFocusData(
      label: strings.proteinLabel,
      color: const Color(0xFF6DBA57),
      current: summary.proteinG,
      target: summary.targetProteinG,
      progress: _macroProgress(summary.proteinG, summary.targetProteinG),
    ),
    _MacroFocusData(
      label: strings.carbsLabel,
      color: const Color(0xFFF2B545),
      current: summary.carbsG,
      target: summary.targetCarbsG,
      progress: _macroProgress(summary.carbsG, summary.targetCarbsG),
    ),
    _MacroFocusData(
      label: strings.fatLabel,
      color: const Color(0xFFE89257),
      current: summary.fatG,
      target: summary.targetFatG,
      progress: _macroProgress(summary.fatG, summary.targetFatG),
    ),
  ];

  options.sort((a, b) => a.progress.compareTo(b.progress));
  return options.first;
}

_EnergyRingState _energyRingState(
  DailySummary summary,
  FitLogThemeData fitTheme,
) {
  final green = fitTheme.primary;
  const softGreen = Color(0xFFEAF5E4);
  const softOrange = Color(0xFFF3C27A);
  const red = Color(0xFFE16759);
  const paleRed = Color(0xFFF7D9D5);

  final target = math.max(summary.targetIntake, 1);
  final intake = summary.caloriesIn;

  if (intake <= 0) {
    return const _EnergyRingState(
      ringValue: 1,
      ringColor: softOrange,
      backgroundColor: softOrange,
      accentColor: softOrange,
    );
  }

  if (intake > target) {
    return const _EnergyRingState(
      ringValue: 1,
      ringColor: red,
      backgroundColor: paleRed,
      accentColor: red,
    );
  }

  if ((intake - target).abs() < 0.5) {
    return _EnergyRingState(
      ringValue: 1,
      ringColor: green,
      backgroundColor: fitTheme.isDark ? fitTheme.primarySoft : softGreen,
      accentColor: green,
    );
  }

  return _EnergyRingState(
    ringValue: (intake / target).clamp(0.0, 1.0),
    ringColor: green,
    backgroundColor: softOrange,
    accentColor: softOrange,
  );
}

class _TripleMacroArcPainter extends CustomPainter {
  _TripleMacroArcPainter({
    required this.proteinProgress,
    required this.carbsProgress,
    required this.fatProgress,
  });

  final double proteinProgress;
  final double carbsProgress;
  final double fatProgress;

  @override
  void paint(Canvas canvas, Size size) {
    const startAngle = -math.pi / 2;
    const totalSweep = math.pi;
    const strokeWidth = 26.0;
    const ringStep = 38.0;

    final maxRadiusFromWidth = size.width - strokeWidth / 2;
    final maxRadiusFromHeight = (size.height - strokeWidth) / 2;
    final outerRadius = math.min(maxRadiusFromWidth, maxRadiusFromHeight);
    final adjustedRingStep = math.min(
      ringStep,
      (outerRadius - strokeWidth * 2) / 2,
    );
    final center = Offset(0, size.height / 2);
    final radii = <double>[
      outerRadius,
      outerRadius - adjustedRingStep,
      outerRadius - adjustedRingStep * 2,
    ];
    final colors = <Color>[
      const Color(0xFF6DBA57),
      const Color(0xFFF2B545),
      const Color(0xFFE89257),
    ];
    final backgrounds = <Color>[
      const Color(0xFFE8F2E3),
      const Color(0xFFF9E8BE),
      const Color(0xFFF8DFC9),
    ];
    final progresses = <double>[proteinProgress, carbsProgress, fatProgress];

    for (var i = 0; i < radii.length; i++) {
      final radius = math.max(radii[i], strokeWidth);
      final rect = Rect.fromCircle(center: center, radius: radius);
      final backgroundPaint = Paint()
        ..color = backgrounds[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      final progressPaint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, totalSweep, false, backgroundPaint);
      canvas.drawArc(
        rect,
        startAngle,
        totalSweep * progresses[i].clamp(0.0, 1.0),
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TripleMacroArcPainter oldDelegate) {
    return proteinProgress != oldDelegate.proteinProgress ||
        carbsProgress != oldDelegate.carbsProgress ||
        fatProgress != oldDelegate.fatProgress;
  }
}

class _MacroMetricCard extends StatelessWidget {
  const _MacroMetricCard({
    required this.label,
    required this.current,
    required this.target,
    required this.color,
    required this.iconAsset,
  });

  final String label;
  final double current;
  final double target;
  final Color color;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    final progress = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);

    return SizedBox(
      height: 184,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
        decoration: BoxDecoration(
          color: fitTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: fitTheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _MacroIconBadge(assetName: iconAsset, color: color),
            const SizedBox(height: 10),
            Text(
              current.toStringAsFixed(0),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 36,
              child: Text(
                context.strings.macroProgressText(current, target),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: fitTheme.mutedText,
                  height: 1.25,
                ),
              ),
            ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progress,
                backgroundColor: color.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeGreeting extends StatelessWidget {
  const _HomeGreeting({
    required this.greetingPrefix,
    required this.nickname,
    required this.isChinese,
  });

  final String greetingPrefix;
  final String nickname;
  final bool isChinese;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: context.fitLogTheme.textPrimary,
      height: 1.1,
    );
    final prefixText = isChinese ? '$greetingPrefix，' : '$greetingPrefix,';
    final nicknameText = isChinese ? '$nickname！' : '$nickname!';
    final fullText = isChinese
        ? '$greetingPrefix，$nickname！'
        : '$greetingPrefix, $nickname!';

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = math.max(0.0, constraints.maxWidth - 8);
        final fullTextPainter = TextPainter(
          text: TextSpan(text: fullText, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: availableWidth);
        final shouldBreakLine = fullTextPainter.didExceedMaxLines;

        if (shouldBreakLine) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(prefixText, style: style),
              const SizedBox(height: 2),
              Text(nicknameText, style: style),
            ],
          );
        }

        return Text(fullText, style: style);
      },
    );
  }
}

class _StrategyCard extends StatelessWidget {
  const _StrategyCard({
    required this.summary,
    required this.profile,
    required this.strings,
  });

  final DailySummary summary;
  final UserProfile profile;
  final AppStrings strings;

  void _openGuide(BuildContext context, String modeText) {
    if (summary.dietPlanStrategy == AppConstants.dietPlanStrategyNone) {
      return;
    }

    final strategyLabel =
        summary.dietPlanStrategy == AppConstants.dietPlanStrategyCarbCycling
        ? strings.carbCyclingLabel
        : strings.carbTaperingLabel;

    final baseCarbFloor = math.max(
      profile.weightKg * AppConstants.carbSafetyFloorPerKg,
      AppConstants.carbSafetyFloorMinimumG,
    );
    final guidePrinciple =
        summary.dietPlanStrategy == AppConstants.dietPlanStrategyCarbCycling
        ? strings.carbCyclingGuidePrinciple()
        : strings.carbTaperingGuidePrinciple();
    final guideNumbers =
        summary.dietPlanStrategy == AppConstants.dietPlanStrategyCarbCycling
        ? strings.carbCyclingGuideNumbers(
            highMultiplier: profile.carbCycleHighMultiplier,
            mediumMultiplier: profile.carbCycleMediumMultiplier,
            lowMultiplier: profile.carbCycleLowMultiplier,
            minimumCarbsG: baseCarbFloor,
          )
        : strings.carbTaperingGuideNumbers(
            reviewDays: profile.carbTaperReviewPeriodDays,
            targetLossPctPerWeek: profile.carbTaperTargetLossPctPerWeek,
            stepG: profile.carbTaperStepG,
            conservativeMaxStepG: math.min(20, profile.weightKg * 0.25),
            minimumCarbsG: baseCarbFloor,
          );
    final guideSetup =
        summary.dietPlanStrategy == AppConstants.dietPlanStrategyCarbCycling
        ? strings.carbCyclingGuideSetup()
        : strings.carbTaperingGuideSetup();
    final whatToKnow =
        summary.dietPlanStrategy == AppConstants.dietPlanStrategyCarbCycling
        ? strings.carbCyclingGuideKnow()
        : strings.carbTaperingGuideKnow();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final fitTheme = context.fitLogTheme;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: GlassPanel(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _PngBadgeIcon(
                        assetName: FitLogIconAssets.strategy,
                        backgroundColor: fitTheme.primarySoft,
                        size: 44,
                        iconSize: 29,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          strings.strategyGuideTitle(strategyLabel),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: math.min(
                      MediaQuery.of(context).size.height * 0.72,
                      620,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          FitLogStrategyGuideSection(
                            title: strings.strategyGuideBaseMethodTitle,
                            lines: <String>[
                              strings.strategyGuideBaseMethodBody(modeText),
                            ],
                          ),
                          FitLogStrategyGuideSection(
                            title: strings.strategyGuideCorePrincipleTitle,
                            lines: guidePrinciple,
                          ),
                          FitLogStrategyGuideSection(
                            title: strings.strategyGuideNumbersTitle,
                            lines: guideNumbers,
                          ),
                          FitLogStrategyGuideSection(
                            title: strings.strategyGuideSetupTitle,
                            lines: guideSetup,
                          ),
                          FitLogStrategyGuideSection(
                            title: strings.strategyGuideKnowTitle,
                            lines: whatToKnow,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    final strategyText =
        summary.dietPlanStrategy == AppConstants.dietPlanStrategyCarbCycling
        ? '${strings.carbCyclingLabel} - ${strings.carbDayTypeFullLabel(summary.carbDayType ?? AppConstants.carbDayMedium)}'
        : summary.dietPlanStrategy == AppConstants.dietPlanStrategyCarbTapering
        ? '${strings.carbTaperingLabel} - ${strings.currentTaperLabel} ${summary.carbTaperCurrentDeltaG.toStringAsFixed(0)} g'
        : strings.strategyNoneLabel;
    final modeText =
        summary.dietCalculationMode == AppConstants.dietCalculationModeGramPerKg
        ? strings.gramPerKgModeLabel
        : strings.energyRatioModeLabel;
    final canOpen =
        summary.dietPlanStrategy != AppConstants.dietPlanStrategyNone;

    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: canOpen ? () => _openGuide(context, modeText) : null,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _PngBadgeIcon(
                assetName: FitLogIconAssets.strategy,
                backgroundColor: fitTheme.primarySoft,
                size: 48,
                iconSize: 31,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${strings.phaseLabel(summary.dietGoalPhase)} - $modeText',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: fitTheme.mutedText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strategyText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (canOpen)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: fitTheme.mutedText,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayRecordsCard extends StatelessWidget {
  const _TodayRecordsCard({required this.summary, required this.strings});

  final DailySummary summary;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final navController = context.read<RootTabController>();
    final fitTheme = context.fitLogTheme;

    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: <Widget>[
          FitLogSectionHeader(
            title: strings.todayRecordsTitle,
            actionLabel: strings.viewAll,
          ),
          _RecordRow(
            assetName: FitLogIconAssets.food,
            color: fitTheme.primary,
            title: strings.foodLabel,
            subtitle: strings.foodRecordsSummary(summary.foodRecords.length),
            value: Text(
              '${summary.caloriesIn.toStringAsFixed(0)} kcal',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            onTap: () => navController.setIndex(RootTabIndex.food),
          ),
          const SizedBox(height: 12),
          _RecordRow(
            assetName: FitLogIconAssets.workout,
            color: const Color(0xFF6B9ED6),
            title: strings.navWorkout,
            subtitle: strings.workoutRecordsSummary(
              summary.workoutSessions.length,
            ),
            value: Text(
              '${summary.exerciseCalories.toStringAsFixed(0)} kcal',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            onTap: () => navController.setIndex(RootTabIndex.workout),
          ),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.assetName,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  final String assetName;
  final Color color;
  final String title;
  final String subtitle;
  final Widget value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fitTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: fitTheme.outline),
        ),
        child: Row(
          children: <Widget>[
            _PngBadgeIcon(
              assetName: assetName,
              backgroundColor: color.withValues(alpha: 0.14),
              size: 42,
              iconSize: 29,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Align(alignment: Alignment.centerRight, child: value),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: fitTheme.mutedText),
          ],
        ),
      ),
    );
  }
}

class _MacroIconBadge extends StatelessWidget {
  const _MacroIconBadge({required this.assetName, required this.color});

  final String assetName;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final iconSize = assetName == FitLogIconAssets.macroCarbs ? 32.0 : 29.0;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Image.asset(
        assetName,
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _PngBadgeIcon extends StatelessWidget {
  const _PngBadgeIcon({
    required this.assetName,
    required this.backgroundColor,
    required this.size,
    required this.iconSize,
  });

  final String assetName;
  final Color backgroundColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Image.asset(
        assetName,
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
