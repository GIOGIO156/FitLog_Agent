import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/fitlog_icon_assets.dart';
import '../../core/localization/app_language.dart';
import '../../core/localization/language_controller.dart';
import '../../core/localization/localization_extensions.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/number_utils.dart';
import '../../core/widgets/fitlog_ui.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/profile_form_fields.dart';
import '../../domain/models/calorie_calibration_state.dart';
import '../../domain/models/carb_taper_review_result.dart';
import '../../domain/models/diet_adjustment_review.dart';
import '../../domain/models/training_frequency_self_check_result.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/services/carb_cycling_calculator.dart';
import '../../domain/services/macro_target_calculator.dart';
import 'diet_plan_strategy_section.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

enum _BodyProfileField { age, height, weight, sex }

class _ProfilePageState extends State<ProfilePage> {
  final _scrollController = ScrollController();
  final _settingsSectionKey = GlobalKey();
  final _selfCheckSectionKey = GlobalKey();

  final _nicknameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _goalKcalController = TextEditingController();
  final _proteinRatioController = TextEditingController();
  final _carbsRatioController = TextEditingController();
  final _fatRatioController = TextEditingController();

  String _sexForFormula = AppConstants.sexOptions.last;
  String _dailyGoalType = 'maintenance';
  String _dietGoalPhase = AppConstants.dietGoalPhaseCutting;
  String _dietCalculationMode = AppConstants.dietCalculationModeEnergyRatio;
  String _dietPlanStrategy = AppConstants.defaultDietPlanStrategy;
  Map<String, String> _carbCyclePattern =
      AppConstants.defaultCarbCyclePattern();
  int _carbTaperReviewPeriodDays =
      AppConstants.defaultCarbTaperReviewPeriodDays;
  double _carbTaperTargetLossPctPerWeek =
      AppConstants.defaultCarbTaperTargetLossPctPerWeek;
  double _carbTaperStepG = AppConstants.defaultCarbTaperStepG;
  double _carbTaperCurrentDeltaG = AppConstants.defaultCarbTaperCurrentDeltaG;
  String? _lastCarbTaperReviewAt;
  int _trainingFrequencyPerWeek = AppConstants.defaultTrainingFrequencyPerWeek;
  int _macroSelfCheckPeriodDays = AppConstants.defaultMacroSelfCheckPeriodDays;
  bool _macroSelfCheckEnabled = true;
  String? _lastMacroSelfCheckAt;

  UserProfile? _loadedProfile;
  bool _loading = true;
  bool _savingNickname = false;
  bool _savingBodyProfile = false;
  bool _savingEnergyRatio = false;
  bool _editingNickname = false;
  _BodyProfileField? _editingBodyField;
  bool _planGuideOverlayVisible = false;
  bool _exportingXlsx = false;
  bool _exportingCsv = false;
  CalorieCalibrationState? _calibrationState;
  double _todayExerciseCalories = 0;
  double _todayCaloriesIn = 0;
  TrainingFrequencySelfCheckResult? _trainingSelfCheckResult;
  CarbTaperReviewResult? _carbTaperReviewResult;
  DietAdjustmentReview? _pendingDietAdjustmentReview;
  bool _handlingSelfCheckAction = false;
  bool _handlingCarbTaperAction = false;
  final MacroTargetCalculator _macroTargetCalculator =
      const MacroTargetCalculator();
  final CarbCyclingCalculator _carbCyclingCalculator =
      const CarbCyclingCalculator();

  @override
  void initState() {
    super.initState();
    _ageController.addListener(_onAgeChanged);
    _load();
  }

  @override
  void dispose() {
    _ageController.removeListener(_onAgeChanged);
    _scrollController.dispose();
    _nicknameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _goalKcalController.dispose();
    _proteinRatioController.dispose();
    _carbsRatioController.dispose();
    _fatRatioController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final services = context.read<AppServices>();
    final profile =
        await services.profileRepository.getProfile() ?? UserProfile.defaults;
    final calibrationState = await services.profileRepository
        .getCalorieCalibrationState();
    final exerciseCalories = await services.workoutRepository
        .getExerciseCaloriesByDate(DateUtilsX.todayKey());
    final caloriesIn = await services.foodRepository.getCaloriesInByDate(
      DateUtilsX.todayKey(),
    );
    final trainingSelfCheckResult = await services
        .trainingFrequencySelfCheckService
        .evaluate(
          profile: profile,
          referenceDay: DateUtilsX.todayKey(),
          respectReminderCooldown: true,
        );
    var pendingDietAdjustmentReview = await services.profileRepository
        .getLatestDietAdjustmentReview(
          userDecision: AppConstants.dietAdjustmentDecisionPending,
        );
    final carbTaperReviewResult = await _loadCarbTaperReview(
      profile,
      pendingDietAdjustmentReview: pendingDietAdjustmentReview,
    );
    pendingDietAdjustmentReview = await services.profileRepository
        .getLatestDietAdjustmentReview(
          userDecision: AppConstants.dietAdjustmentDecisionPending,
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _loadedProfile = profile;
      _nicknameController.text = profile.nickname ?? '';
      _ageController.text = profile.age.toString();
      _heightController.text = profile.heightCm.toStringAsFixed(1);
      _weightController.text = profile.weightKg.toStringAsFixed(1);
      _goalKcalController.text = profile.dailyEnergyGoalKcal.toStringAsFixed(0);
      _proteinRatioController.text = profile.proteinRatioPercent
          .toStringAsFixed(0);
      _carbsRatioController.text = profile.carbsRatioPercent.toStringAsFixed(0);
      _fatRatioController.text = profile.fatRatioPercent.toStringAsFixed(0);
      _sexForFormula = profile.sexForFormula;
      _dailyGoalType = profile.dailyEnergyGoalType;
      _dietGoalPhase = profile.dietGoalPhase;
      _dietCalculationMode = profile.dietCalculationMode;
      _dietPlanStrategy = profile.dietPlanStrategy;
      _carbCyclePattern = profile.carbCyclePattern;
      _carbTaperReviewPeriodDays = profile.carbTaperReviewPeriodDays;
      _carbTaperTargetLossPctPerWeek = profile.carbTaperTargetLossPctPerWeek;
      _carbTaperStepG = profile.carbTaperStepG;
      _carbTaperCurrentDeltaG = profile.carbTaperCurrentDeltaG;
      _lastCarbTaperReviewAt = profile.lastCarbTaperReviewAt;
      _trainingFrequencyPerWeek = profile.trainingFrequencyPerWeek;
      _macroSelfCheckPeriodDays = profile.macroSelfCheckPeriodDays;
      _macroSelfCheckEnabled = profile.macroSelfCheckEnabled;
      _lastMacroSelfCheckAt = profile.lastMacroSelfCheckAt;
      _calibrationState = calibrationState;
      _todayExerciseCalories = exerciseCalories;
      _todayCaloriesIn = caloriesIn;
      _trainingSelfCheckResult = trainingSelfCheckResult;
      _pendingDietAdjustmentReview = pendingDietAdjustmentReview;
      _carbTaperReviewResult = carbTaperReviewResult;
      _editingNickname = false;
      _editingBodyField = null;
      _normalizeGoalByAge();
      _normalizeStrategyByContext();
      _loading = false;
    });
  }

  int get _age => NumberUtils.toInt(_ageController.text, fallback: 0);

  double get _heightCm =>
      NumberUtils.toDouble(_heightController.text, fallback: 0);

  double get _weightKg =>
      NumberUtils.toDouble(_weightController.text, fallback: 0);

  double get _goalKcal =>
      NumberUtils.toDouble(_goalKcalController.text, fallback: 0);

  double get _proteinRatioPercent =>
      NumberUtils.toDouble(_proteinRatioController.text, fallback: 0);

  double get _carbsRatioPercent =>
      NumberUtils.toDouble(_carbsRatioController.text, fallback: 0);

  double get _fatRatioPercent =>
      NumberUtils.toDouble(_fatRatioController.text, fallback: 0);

  double get _macroRatioTotal =>
      _proteinRatioPercent + _carbsRatioPercent + _fatRatioPercent;

  UserProfile get _persistedProfile => _loadedProfile ?? UserProfile.defaults;

  bool get _isGramPerKgMode =>
      _dietCalculationMode == AppConstants.dietCalculationModeGramPerKg;

  bool get _isMinor => _age > 0 && _age < 18;

  bool get _isBulkingPhase =>
      _dietGoalPhase == AppConstants.dietGoalPhaseBulking;

  bool get _canUseCuttingStrategy => !_isMinor && !_isBulkingPhase;

  bool get _hasNicknameDraft =>
      _nicknameController.text.trim() !=
      (_loadedProfile?.nickname ?? '').trim();

  bool get _hasBodyProfileDraft {
    final profile = _loadedProfile;
    if (profile == null) {
      return false;
    }
    return _age != profile.age ||
        (_heightCm - profile.heightCm).abs() > 0.01 ||
        (_weightKg - profile.weightKg).abs() > 0.01 ||
        _sexForFormula != profile.sexForFormula;
  }

  bool get _hasEnergyRatioDraft {
    final profile = _loadedProfile;
    if (profile == null || _isGramPerKgMode) {
      return false;
    }
    return (_goalKcal - profile.dailyEnergyGoalKcal).abs() > 0.01 ||
        (_proteinRatioPercent - profile.proteinRatioPercent).abs() > 0.01 ||
        (_carbsRatioPercent - profile.carbsRatioPercent).abs() > 0.01 ||
        (_fatRatioPercent - profile.fatRatioPercent).abs() > 0.01;
  }

  void _openNicknameEditor() {
    FocusScope.of(context).unfocus();
    setState(() {
      if (_editingBodyField != null && !_hasBodyProfileDraft) {
        _editingBodyField = null;
      }
      _editingNickname = true;
    });
  }

  void _activateBodyProfileField(_BodyProfileField field) {
    FocusScope.of(context).unfocus();
    setState(() {
      if (_editingNickname && !_hasNicknameDraft) {
        _editingNickname = false;
      }
      _editingBodyField = field;
    });
  }

  void _onAgeChanged() {
    setState(_normalizeGoalByAge);
  }

  void _normalizeGoalByAge() {
    _dailyGoalType = _dailyGoalTypeForPhase();
    if (_isMinor && _dailyGoalType == 'deficit') {
      _dailyGoalType = 'maintenance';
    }
  }

  void _normalizeStrategyByContext() {
    if (_canUseCuttingStrategy) {
      return;
    }
    _dietPlanStrategy = AppConstants.dietPlanStrategyNone;
    _carbTaperCurrentDeltaG = 0;
  }

  String _dailyGoalTypeForPhase() {
    return _isBulkingPhase ? 'surplus' : 'deficit';
  }

  UserProfile _buildDraftProfile() {
    final safeStrategy = _canUseCuttingStrategy
        ? _dietPlanStrategy
        : AppConstants.dietPlanStrategyNone;
    final activityLevel = AppConstants.activityLevelForTrainingFrequency(
      _trainingFrequencyPerWeek,
    );
    return UserProfile(
      nickname: _nicknameController.text.trim(),
      age: _age,
      heightCm: _heightCm,
      weightKg: _weightKg,
      sexForFormula: _sexForFormula,
      activityLevel: activityLevel,
      dailyEnergyGoalType: _dailyGoalType,
      dailyEnergyGoalKcal: _goalKcal,
      proteinRatioPercent: _proteinRatioPercent,
      carbsRatioPercent: _carbsRatioPercent,
      fatRatioPercent: _fatRatioPercent,
      dietGoalPhase: _dietGoalPhase,
      dietCalculationMode: _dietCalculationMode,
      dietPlanStrategy: safeStrategy,
      carbCyclePatternJson: jsonEncode(_carbCyclePattern),
      carbCycleHighMultiplier: AppConstants.defaultCarbCycleHighMultiplier,
      carbCycleMediumMultiplier: AppConstants.defaultCarbCycleMediumMultiplier,
      carbCycleLowMultiplier: AppConstants.defaultCarbCycleLowMultiplier,
      carbTaperReviewPeriodDays: _carbTaperReviewPeriodDays,
      carbTaperTargetLossPctPerWeek: _carbTaperTargetLossPctPerWeek,
      carbTaperStepG: _carbTaperStepG,
      carbTaperCurrentDeltaG:
          safeStrategy == AppConstants.dietPlanStrategyCarbTapering
          ? _carbTaperCurrentDeltaG
          : 0,
      lastCarbTaperReviewAt: _lastCarbTaperReviewAt,
      trainingFrequencyPerWeek: _trainingFrequencyPerWeek,
      macroSelfCheckPeriodDays: _macroSelfCheckPeriodDays,
      macroSelfCheckEnabled: _macroSelfCheckEnabled,
      lastMacroSelfCheckAt: _lastMacroSelfCheckAt,
    );
  }

  Future<CarbTaperReviewResult?> _loadCarbTaperReview(
    UserProfile profile, {
    required DietAdjustmentReview? pendingDietAdjustmentReview,
  }) async {
    if (profile.dietPlanStrategy != AppConstants.dietPlanStrategyCarbTapering &&
        pendingDietAdjustmentReview == null) {
      return null;
    }
    final baseCarbsG = _resolveBaseMacroTargets(profile).carbsTargetG;
    final services = context.read<AppServices>();
    final result = await services.carbTaperReviewService.evaluate(
      profile: profile,
      referenceDay: DateUtilsX.todayKey(),
      latestPendingReviewDate: pendingDietAdjustmentReview?.reviewDate,
      baseCarbsGOverride: baseCarbsG,
      respectCooldown: true,
    );
    if (result.isReviewDue &&
        pendingDietAdjustmentReview == null &&
        result.isApplicable) {
      final createdReview = await services.profileRepository
          .insertDietAdjustmentReview(
            DietAdjustmentReview(
              reviewDate: DateUtilsX.todayKey(),
              windowDays: result.windowDays,
              dietGoalPhase: profile.dietGoalPhase,
              dietCalculationMode: profile.dietCalculationMode,
              dietPlanStrategy: profile.dietPlanStrategy,
              startAvgWeightKg: result.startAvgWeightKg,
              endAvgWeightKg: result.endAvgWeightKg,
              weightChangeKg: result.weightChangeKg,
              lossRatePctPerWeek: result.lossRatePctPerWeek,
              targetLossPctPerWeek: result.targetLossPctPerWeek,
              foodLogCoverage: result.foodLogCoverage,
              activeTrainingDays: result.activeTrainingDays,
              suggestedAction: result.suggestedAction,
              suggestedCarbDeltaG: result.suggestedCarbDeltaG,
              confidence: result.confidence,
              reasonCodes: result.reasonCodes,
              userDecision: AppConstants.dietAdjustmentDecisionPending,
            ),
          );
      _pendingDietAdjustmentReview = createdReview;
    }
    return result;
  }

  MacroTargets _resolveBaseMacroTargets(UserProfile profile) {
    if (profile.dietCalculationMode ==
        AppConstants.dietCalculationModeGramPerKg) {
      return _macroTargetCalculator.calculateByGramPerKg(profile: profile);
    }
    final bmr = context.read<AppServices>().dailySummaryService.calculateBmr(
      profile,
    );
    final baselineNoExerciseTdee = bmr * _currentLifestyleFactor();
    final targetIntake = context
        .read<AppServices>()
        .dailySummaryService
        .calculateNoExerciseTargetIntake(
          baselineNoExerciseTdee: baselineNoExerciseTdee,
          profile: profile,
        );
    return _macroTargetCalculator.calculateByEnergyRatio(
      profile: profile,
      targetIntakeKcal: targetIntake + _todayExerciseCalories,
    );
  }

  double _calculateBmr() {
    final profile = _buildDraftProfile();
    return context.read<AppServices>().dailySummaryService.calculateBmr(
      profile,
    );
  }

  double _calculateNoExerciseBaseline(double bmr) {
    return bmr * _currentLifestyleFactor();
  }

  double _currentLifestyleFactor() {
    final calibrated = _calibrationState?.lifestyleFactor;
    if (calibrated != null && calibrated > 0) {
      return calibrated;
    }
    return context
        .read<AppServices>()
        .dailySummaryService
        .defaultLifestyleFactorForTrainingFrequency(_trainingFrequencyPerWeek);
  }

  double _calculateTargetIntake(double bmr) {
    if (_isGramPerKgMode) {
      return 0;
    }
    final baselineNoExerciseTdee = _calculateNoExerciseBaseline(bmr);
    final noExerciseTarget = context
        .read<AppServices>()
        .dailySummaryService
        .calculateNoExerciseTargetIntake(
          baselineNoExerciseTdee: baselineNoExerciseTdee,
          profile: _buildDraftProfile(),
        );
    return noExerciseTarget + _todayExerciseCalories;
  }

  MacroTargets _resolveDisplayedMacroTargets(UserProfile profile) {
    final base = _resolveBaseMacroTargets(profile);
    if (profile.dietPlanStrategy == AppConstants.dietPlanStrategyCarbCycling) {
      final result = _carbCyclingCalculator.calculate(
        profile: profile,
        day: DateUtilsX.todayKey(),
        isEnergyTargetMode: false,
        baseProteinG: base.proteinTargetG,
        baseCarbsG: base.carbsTargetG,
        baseFatG: base.fatTargetG,
      );
      return MacroTargets(
        proteinTargetG: result.finalProteinG,
        carbsTargetG: result.finalCarbsG,
        fatTargetG: result.finalFatG,
        macroEnergyEquivalentKcal: result.finalMacroEnergyEquivalentKcal,
      );
    }
    if (profile.dietPlanStrategy == AppConstants.dietPlanStrategyCarbTapering &&
        profile.dietGoalPhase == AppConstants.dietGoalPhaseCutting &&
        !profile.isMinor) {
      final floor = _carbCyclingCalculator.minimumCarbsGForWeight(
        profile.weightKg,
      );
      final carbs = (base.carbsTargetG + profile.carbTaperCurrentDeltaG).clamp(
        floor,
        double.infinity,
      );
      return MacroTargets(
        proteinTargetG: base.proteinTargetG,
        carbsTargetG: carbs,
        fatTargetG: base.fatTargetG,
        macroEnergyEquivalentKcal:
            base.proteinTargetG * 4 + carbs * 4 + base.fatTargetG * 9,
      );
    }
    return base;
  }

  void _openPlanMethodGuide() {
    setState(() => _planGuideOverlayVisible = true);
    if (_planGuideOverlayVisible) {
      return;
    }

    final strings = context.strings;
    final profile = _buildDraftProfile();
    final isGramPerKgMode =
        profile.dietCalculationMode ==
        AppConstants.dietCalculationModeGramPerKg;
    final phaseLabel = strings.phaseLabel(profile.dietGoalPhase);
    final sexLabel = strings.sexOptionLabel(profile.sexForFormula);
    final ratioSummary =
        profile.dietGoalPhase == AppConstants.dietGoalPhaseBulking
        ? const <String>['25%', '50%', '25%']
        : const <String>['30%', '40%', '30%'];

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                      const FitLogIconCircle(
                        icon: Icons.info_outline_rounded,
                        color: Color(0xFF4E9E3B),
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          strings.isChinese ? '计算方法说明' : 'Method Guide',
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
                            lines: isGramPerKgMode
                                ? <String>[
                                    strings.gramPerKgModeNotice,
                                    strings.isChinese
                                        ? '当前展示的是 $phaseLabel / $sexLabel 的粗略查表档位。训练频率只决定你落在哪一行，不会推断训练强度、动作量或表现水平。'
                                        : 'This sheet is showing the coarse $phaseLabel / $sexLabel lookup row. Training frequency only decides which row you use; it does not estimate intensity, volume, or performance.',
                                  ]
                                : <String>[
                                    strings.isChinese
                                        ? '热量比例法会先算 BMR，再按每周训练频率选一个默认生活活动系数，随后叠加减脂/增肌目标，最后把当天净运动消耗加回今日可吃热量。'
                                        : 'Energy-ratio mode starts from BMR, picks a default lifestyle factor from your weekly training frequency, applies the cutting or bulking target, then adds today\'s net exercise calories back into the intake target.',
                                    strings.isChinese
                                        ? '在这个模式里，蛋白质 / 碳水 / 脂肪比例主要由你自己填写；训练频率不会直接改三大营养素百分比。'
                                        : 'In this mode, protein, carbs, and fat percentages are mainly user-controlled; training frequency does not directly rewrite the macro percentages.',
                                  ],
                          ),
                          if (isGramPerKgMode)
                            _ProfileGuideSectionCard(
                              title: strings.isChinese
                                  ? '当前 g/kg 系数表'
                                  : 'Current g/kg coefficient table',
                              subtitle: '$phaseLabel · $sexLabel',
                              child: _ProfileGuideTable(
                                headers: <String>[
                                  strings.isChinese ? '频率' : 'Freq',
                                  'P',
                                  'C',
                                  'F',
                                ],
                                rows: AppConstants
                                    .trainingFrequencyPerWeekOptions
                                    .map((frequency) {
                                      final targets = _macroTargetCalculator
                                          .calculateByGramPerKg(
                                            profile: profile.copyWith(
                                              trainingFrequencyPerWeek:
                                                  frequency,
                                            ),
                                          );
                                      final weight = math.max(
                                        profile.weightKg,
                                        1,
                                      );
                                      return <String>[
                                        '${frequency}d',
                                        (targets.proteinTargetG / weight)
                                            .toStringAsFixed(1),
                                        (targets.carbsTargetG / weight)
                                            .toStringAsFixed(1),
                                        (targets.fatTargetG / weight)
                                            .toStringAsFixed(1),
                                      ];
                                    })
                                    .toList(),
                              ),
                            ),
                          if (!isGramPerKgMode)
                            _ProfileGuideSectionCard(
                              title: strings.isChinese
                                  ? '默认起步参考'
                                  : 'Default starting point',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  _ProfileGuideTable(
                                    headers: <String>[
                                      strings.proteinLabel,
                                      strings.carbsLabel,
                                      strings.fatLabel,
                                    ],
                                    rows: <List<String>>[ratioSummary],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    profile.dietGoalPhase ==
                                            AppConstants.dietGoalPhaseBulking
                                        ? strings.bulkingMacroRatioSuggestion
                                        : (strings.isChinese
                                              ? '减脂/维持默认起步比例是蛋白质 30% / 碳水 40% / 脂肪 30%，你可以在下方卡片里继续手动改。'
                                              : 'The default cutting or maintenance starting split is protein 30% / carbs 40% / fat 30%, and you can still override it below.'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: const Color(0xFF5D6B58),
                                          height: 1.45,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          if (!isGramPerKgMode)
                            _ProfileGuideSectionCard(
                              title: strings.isChinese
                                  ? '训练频率对应的默认活动系数'
                                  : 'Default lifestyle factor by frequency',
                              child: _ProfileGuideTable(
                                headers: <String>[
                                  strings.isChinese ? '频率' : 'Freq',
                                  strings.isChinese ? '系数' : 'Factor',
                                ],
                                rows: AppConstants
                                    .trainingFrequencyPerWeekOptions
                                    .map(
                                      (frequency) => <String>[
                                        '${frequency}d',
                                        AppConstants.defaultLifestyleFactorForTrainingFrequency(
                                          frequency,
                                        ).toStringAsFixed(3),
                                      ],
                                    )
                                    .toList(),
                              ),
                            ),
                          FitLogStrategyGuideSection(
                            title: strings.strategyGuideNumbersTitle,
                            lines: isGramPerKgMode
                                ? <String>[
                                    strings.gramPerKgPhaseNotice(
                                      profile.dietGoalPhase,
                                    ),
                                    strings.isChinese
                                        ? '同一个频率下，不同性别与阶段会切到不同表；如果你选择“不透露”，FitLog 会取男女两张表的中间值。'
                                        : 'At the same frequency, different sex and phase combinations switch to different tables; if you choose prefer-not-to-say, FitLog uses the midpoint between the male and female rows.',
                                  ]
                                : <String>[
                                    strings.energyRatioPhaseNotice(
                                      profile.dietGoalPhase,
                                    ),
                                    strings.isChinese
                                        ? '如果本地校准已经积累了足够历史，实际计算会优先使用校准后的生活活动系数，而不是死守上表默认值。'
                                        : 'If local calibration has enough history, the real calculation can replace the default lifestyle factor above with the calibrated factor.',
                                  ],
                          ),
                          FitLogStrategyGuideSection(
                            title: strings.strategyGuideKnowTitle,
                            lines: isGramPerKgMode
                                ? <String>[
                                    strings.isChinese
                                        ? 'g/kg 模式下，宏量营养素目标才是主目标，kcal 只是把这组宏量换算成一个辅助能量值，方便你理解数量级。'
                                        : 'In g/kg mode, macro targets are the primary target, while kcal is only an auxiliary energy-equivalent number for context.',
                                    strings.isChinese
                                        ? '如果你的真实训练量和恢复状态长期变化很大，优先通过阶段、频率、体重和策略设置去修正，而不是把这张表当成自动自适应引擎。'
                                        : 'If your real workload or recovery changes a lot over time, adjust phase, frequency, body weight, and strategy settings first instead of treating this table like an auto-adapting engine.',
                                  ]
                                : <String>[
                                    strings.isChinese
                                        ? '热量比例法更适合你想先抓住总热量与剩余量的时候；真正决定减脂/增肌节奏的，仍然是长期记录与执行稳定度。'
                                        : 'Energy-ratio mode is better when you want to steer by total calories and remaining intake; long-term logging and consistency still drive the real cutting or bulking pace.',
                                    strings.isChinese
                                        ? '训练频率在这里是一个本地起步档位，不是医疗级活动评估；如果你后续记录越来越完整，校准会比默认档位更贴近你的实际情况。'
                                        : 'Training frequency here is only a local starting tier, not a medical-grade activity assessment; once your history is fuller, calibration can become a better fit than the default tier.',
                                  ],
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

  void _closePlanMethodGuideOverlay() {
    setState(() => _planGuideOverlayVisible = false);
  }

  String _dietModeLabel(BuildContext context) {
    final strings = context.strings;
    return _isGramPerKgMode
        ? strings.gramPerKgModeLabel
        : strings.energyRatioModeLabel;
  }

  String _strategyLabel(BuildContext context) {
    return context.strings.strategyLabel(_dietPlanStrategy);
  }

  String _trainingSummaryLabel(BuildContext context) {
    final strings = context.strings;
    if (!strings.isChinese) {
      return '$_trainingFrequencyPerWeek times/wk · ${_macroSelfCheckPeriodDays}d check';
    }
    return strings.isChinese
        ? '每周训练 $_trainingFrequencyPerWeek 次 · $_macroSelfCheckPeriodDays 天自检'
        : '$_trainingFrequencyPerWeek sessions/week · $_macroSelfCheckPeriodDays-day self-check';
  }

  bool _validateBodyProfile() {
    final strings = context.stringsRead;
    if (_age <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.enterValidAge)));
      return false;
    }
    if (_heightCm <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.enterValidHeight)));
      return false;
    }
    if (_weightKg <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.enterValidWeight)));
      return false;
    }
    return true;
  }

  bool _validateEnergyRatioFields() {
    final strings = context.stringsRead;
    if (_goalKcal <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.dailyGoalKcalLabel)));
      return false;
    }
    final ratios = <double>[
      _proteinRatioPercent,
      _carbsRatioPercent,
      _fatRatioPercent,
    ];
    if (ratios.any((value) => value < 0 || value > 100)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.enterValidMacroRatio)));
      return false;
    }
    if ((_macroRatioTotal - 100).abs() > 0.01) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.macroRatioTotalInvalid)));
      return false;
    }
    return true;
  }

  Future<void> _persistProfile(UserProfile profile) async {
    final services = context.read<AppServices>();
    final refreshNotifier = context.read<RefreshNotifier>();
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.stringsRead;

    await services.profileRepository.saveProfile(profile);
    var pendingDietAdjustmentReview = await services.profileRepository
        .getLatestDietAdjustmentReview(
          userDecision: AppConstants.dietAdjustmentDecisionPending,
        );
    final trainingSelfCheckResult = await services
        .trainingFrequencySelfCheckService
        .evaluate(
          profile: profile,
          referenceDay: DateUtilsX.todayKey(),
          respectReminderCooldown: true,
        );
    final carbTaperReviewResult = await _loadCarbTaperReview(
      profile,
      pendingDietAdjustmentReview: pendingDietAdjustmentReview,
    );
    pendingDietAdjustmentReview = await services.profileRepository
        .getLatestDietAdjustmentReview(
          userDecision: AppConstants.dietAdjustmentDecisionPending,
        );

    if (!mounted) {
      return;
    }

    refreshNotifier.markDataChanged();
    setState(() {
      _loadedProfile = profile;
      _dailyGoalType = profile.dailyEnergyGoalType;
      _dietGoalPhase = profile.dietGoalPhase;
      _dietCalculationMode = profile.dietCalculationMode;
      _dietPlanStrategy = profile.dietPlanStrategy;
      _carbCyclePattern = profile.carbCyclePattern;
      _carbTaperReviewPeriodDays = profile.carbTaperReviewPeriodDays;
      _carbTaperTargetLossPctPerWeek = profile.carbTaperTargetLossPctPerWeek;
      _carbTaperStepG = profile.carbTaperStepG;
      _carbTaperCurrentDeltaG = profile.carbTaperCurrentDeltaG;
      _lastCarbTaperReviewAt = profile.lastCarbTaperReviewAt;
      _trainingFrequencyPerWeek = profile.trainingFrequencyPerWeek;
      _macroSelfCheckPeriodDays = profile.macroSelfCheckPeriodDays;
      _macroSelfCheckEnabled = profile.macroSelfCheckEnabled;
      _lastMacroSelfCheckAt = profile.lastMacroSelfCheckAt;
      _trainingSelfCheckResult = trainingSelfCheckResult;
      _pendingDietAdjustmentReview = pendingDietAdjustmentReview;
      _carbTaperReviewResult = carbTaperReviewResult;
    });
    messenger.showSnackBar(SnackBar(content: Text(strings.profileSaved)));
  }

  Future<void> _saveNickname() async {
    if (!_hasNicknameDraft) {
      FocusScope.of(context).unfocus();
      setState(() => _editingNickname = false);
      return;
    }
    setState(() => _savingNickname = true);
    try {
      await _persistProfile(
        _persistedProfile.copyWith(nickname: _nicknameController.text.trim()),
      );
      if (mounted) {
        setState(() => _editingNickname = false);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.stringsRead.summaryError(error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingNickname = false);
      }
    }
  }

  Future<void> _saveBodyProfile() async {
    if (!_hasBodyProfileDraft) {
      FocusScope.of(context).unfocus();
      setState(() => _editingBodyField = null);
      return;
    }
    if (!_validateBodyProfile()) {
      return;
    }
    setState(() => _savingBodyProfile = true);
    try {
      final activityLevel = AppConstants.activityLevelForTrainingFrequency(
        _trainingFrequencyPerWeek,
      );
      await _persistProfile(
        _persistedProfile.copyWith(
          age: _age,
          heightCm: _heightCm,
          weightKg: _weightKg,
          sexForFormula: _sexForFormula,
          activityLevel: activityLevel,
        ),
      );
      if (mounted) {
        setState(() => _editingBodyField = null);
      }
    } finally {
      if (mounted) {
        setState(() => _savingBodyProfile = false);
      }
    }
  }

  Future<void> _saveEnergyRatioSettings() async {
    if (!_validateEnergyRatioFields()) {
      return;
    }
    setState(() => _savingEnergyRatio = true);
    try {
      await _persistProfile(
        _persistedProfile.copyWith(
          dailyEnergyGoalType: _dailyGoalType,
          dailyEnergyGoalKcal: _goalKcal,
          proteinRatioPercent: _proteinRatioPercent,
          carbsRatioPercent: _carbsRatioPercent,
          fatRatioPercent: _fatRatioPercent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingEnergyRatio = false);
      }
    }
  }

  Future<void> _savePlanMatrix({
    String? phase,
    String? mode,
    String? strategy,
  }) async {
    final updatedPhase = phase ?? _dietGoalPhase;
    final updatedMode = mode ?? _dietCalculationMode;
    final updatedStrategy = strategy ?? _dietPlanStrategy;
    final safeStrategy =
        !_canUseCuttingStrategy &&
            updatedStrategy != AppConstants.dietPlanStrategyNone
        ? AppConstants.dietPlanStrategyNone
        : updatedStrategy;

    setState(() {
      _dietGoalPhase = updatedPhase;
      _dietCalculationMode = updatedMode;
      _dietPlanStrategy = safeStrategy;
      _normalizeGoalByAge();
      _normalizeStrategyByContext();
    });

    await _persistProfile(
      _persistedProfile.copyWith(
        dietGoalPhase: _dietGoalPhase,
        dietCalculationMode: _dietCalculationMode,
        dietPlanStrategy: _dietPlanStrategy,
        dailyEnergyGoalType: _dailyGoalType,
        carbTaperCurrentDeltaG:
            _dietPlanStrategy == AppConstants.dietPlanStrategyCarbTapering
            ? _carbTaperCurrentDeltaG
            : 0,
      ),
    );
  }

  Future<void> _saveMacroSettings({
    int? trainingFrequencyPerWeek,
    int? selfCheckPeriodDays,
    bool? selfCheckEnabled,
  }) async {
    final nextFrequency = trainingFrequencyPerWeek ?? _trainingFrequencyPerWeek;
    final nextPeriod = selfCheckPeriodDays ?? _macroSelfCheckPeriodDays;
    final nextEnabled = selfCheckEnabled ?? _macroSelfCheckEnabled;
    setState(() {
      _trainingFrequencyPerWeek = nextFrequency;
      _macroSelfCheckPeriodDays = nextPeriod;
      _macroSelfCheckEnabled = nextEnabled;
    });
    await _persistProfile(
      _persistedProfile.copyWith(
        trainingFrequencyPerWeek: nextFrequency,
        macroSelfCheckPeriodDays: nextPeriod,
        macroSelfCheckEnabled: nextEnabled,
        activityLevel: AppConstants.activityLevelForTrainingFrequency(
          nextFrequency,
        ),
      ),
    );
  }

  Future<void> _saveStrategyDetails({
    Map<String, String>? carbCyclePattern,
    int? carbTaperReviewPeriodDays,
    double? carbTaperTargetLossPctPerWeek,
    double? carbTaperStepG,
  }) async {
    if (carbCyclePattern != null) {
      setState(() => _carbCyclePattern = carbCyclePattern);
    }
    if (carbTaperReviewPeriodDays != null) {
      setState(() => _carbTaperReviewPeriodDays = carbTaperReviewPeriodDays);
    }
    if (carbTaperTargetLossPctPerWeek != null) {
      setState(
        () => _carbTaperTargetLossPctPerWeek = carbTaperTargetLossPctPerWeek,
      );
    }
    if (carbTaperStepG != null) {
      setState(() => _carbTaperStepG = carbTaperStepG);
    }

    await _persistProfile(
      _persistedProfile.copyWith(
        carbCyclePatternJson: jsonEncode(_carbCyclePattern),
        carbTaperReviewPeriodDays: _carbTaperReviewPeriodDays,
        carbTaperTargetLossPctPerWeek: _carbTaperTargetLossPctPerWeek,
        carbTaperStepG: _carbTaperStepG,
      ),
    );
  }

  Future<void> _exportXlsx() async {
    final service = context.read<AppServices>().xlsxExportService;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _exportingXlsx = true);
    try {
      final filePath = await service.export();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('XLSX: $filePath')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('XLSX error: $e')));
    } finally {
      if (mounted) {
        setState(() => _exportingXlsx = false);
      }
    }
  }

  Future<void> _exportCsvZip() async {
    final service = context.read<AppServices>().csvExportService;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _exportingCsv = true);
    try {
      final filePath = await service.exportZip();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('CSV: $filePath')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('CSV error: $e')));
    } finally {
      if (mounted) {
        setState(() => _exportingCsv = false);
      }
    }
  }

  Future<void> _clearAllData() async {
    final services = context.read<AppServices>();
    final refreshNotifier = context.read<RefreshNotifier>();
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.stringsRead;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(strings.clearAllDataTitle),
              content: Text(strings.clearAllDataBody),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(strings.cancel),
                ),
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(strings.clearData),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    await services.database.clearAllLocalData();

    if (!mounted) {
      return;
    }

    refreshNotifier.markDataChanged();
    await _load();

    if (!mounted) {
      return;
    }

    messenger.showSnackBar(SnackBar(content: Text(strings.allDataCleared)));
  }

  Future<void> _applySelfCheckSuggestion() async {
    final result = _trainingSelfCheckResult;
    if (result == null) {
      return;
    }
    final now = DateTime.now().toIso8601String();
    final services = context.read<AppServices>();
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.stringsRead;

    setState(() => _handlingSelfCheckAction = true);
    try {
      await services.profileRepository.saveMacroSelfCheckFeedback(
        trainingFrequencyPerWeek: result.recommendedTrainingFrequency,
        lastMacroSelfCheckAt: now,
      );
      if (!mounted) {
        return;
      }
      context.read<RefreshNotifier>().markDataChanged();
      await _load();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(strings.profileSaved)));
    } finally {
      if (mounted) {
        setState(() => _handlingSelfCheckAction = false);
      }
    }
  }

  Future<void> _keepCurrentSelfCheckSetting() async {
    final now = DateTime.now().toIso8601String();
    final services = context.read<AppServices>();
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.stringsRead;

    setState(() => _handlingSelfCheckAction = true);
    try {
      await services.profileRepository.saveMacroSelfCheckFeedback(
        lastMacroSelfCheckAt: now,
      );
      if (!mounted) {
        return;
      }
      context.read<RefreshNotifier>().markDataChanged();
      await _load();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(strings.profileSaved)));
    } finally {
      if (mounted) {
        setState(() => _handlingSelfCheckAction = false);
      }
    }
  }

  Future<void> _applyCarbTaperSuggestion() async {
    final review = _pendingDietAdjustmentReview;
    final result = _carbTaperReviewResult;
    if (review == null || result == null) {
      return;
    }
    final services = context.read<AppServices>();
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.stringsRead;
    final reviewedAt = DateTime.now().toIso8601String();

    setState(() => _handlingCarbTaperAction = true);
    try {
      await services.profileRepository.saveCarbTaperReviewDecision(
        review: review,
        userDecision: AppConstants.dietAdjustmentDecisionAccepted,
        reviewedAt: reviewedAt,
        carbTaperCurrentDeltaG: result.projectedCarbDeltaAfterG,
      );
      if (!mounted) {
        return;
      }
      context.read<RefreshNotifier>().markDataChanged();
      await _load();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(strings.profileSaved)));
    } finally {
      if (mounted) {
        setState(() => _handlingCarbTaperAction = false);
      }
    }
  }

  Future<void> _dismissCarbTaperSuggestion() async {
    final review = _pendingDietAdjustmentReview;
    if (review == null) {
      return;
    }
    final services = context.read<AppServices>();
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.stringsRead;
    final reviewedAt = DateTime.now().toIso8601String();

    setState(() => _handlingCarbTaperAction = true);
    try {
      await services.profileRepository.saveCarbTaperReviewDecision(
        review: review,
        userDecision: AppConstants.dietAdjustmentDecisionDismissed,
        reviewedAt: reviewedAt,
        carbTaperCurrentDeltaG: _carbTaperCurrentDeltaG,
      );
      if (!mounted) {
        return;
      }
      context.read<RefreshNotifier>().markDataChanged();
      await _load();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(strings.profileSaved)));
    } finally {
      if (mounted) {
        setState(() => _handlingCarbTaperAction = false);
      }
    }
  }

  List<CarbCyclePreviewRow> _buildCarbCyclePreview({
    required UserProfile profile,
    required MacroTargets base,
  }) {
    final start = DateUtilsX.parseDay(DateUtilsX.todayKey()).subtract(
      Duration(days: DateUtilsX.parseDay(DateUtilsX.todayKey()).weekday - 1),
    );
    return List<CarbCyclePreviewRow>.generate(7, (index) {
      final day = start.add(Duration(days: index));
      final dateKey = DateUtilsX.formatDate(day);
      final result = _carbCyclingCalculator.calculate(
        profile: profile,
        day: dateKey,
        isEnergyTargetMode:
            profile.dietCalculationMode !=
            AppConstants.dietCalculationModeGramPerKg,
        baseProteinG: base.proteinTargetG,
        baseCarbsG: base.carbsTargetG,
        baseFatG: base.fatTargetG,
      );
      return CarbCyclePreviewRow(
        weekdayKey: AppConstants.weekdayKeyFromDateTime(day),
        date: dateKey,
        carbDayType: result.carbDayType ?? AppConstants.carbDayMedium,
        proteinG: result.finalProteinG,
        carbsG: result.finalCarbsG,
        fatG: result.finalFatG,
        macroKcal: result.finalMacroEnergyEquivalentKcal,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final strings = context.strings;
    final languageController = context.watch<LanguageController>();

    final bmr = _calculateBmr();
    final lifestyleFactor = _currentLifestyleFactor();
    final tdeeReference = _calculateNoExerciseBaseline(bmr);
    final targetIntake = _calculateTargetIntake(bmr);
    final remaining = targetIntake - _todayCaloriesIn;
    final draftProfile = _buildDraftProfile();
    final displayedMacroTargets = _resolveDisplayedMacroTargets(draftProfile);
    final baseMacroTargets = _resolveBaseMacroTargets(draftProfile);
    final carbCyclePreview =
        _dietPlanStrategy == AppConstants.dietPlanStrategyCarbCycling
        ? _buildCarbCyclePreview(profile: draftProfile, base: baseMacroTargets)
        : const <CarbCyclePreviewRow>[];
    final displayNickname = _nicknameController.text.trim().isEmpty
        ? strings.nicknameFallback
        : _nicknameController.text.trim();

    return SafeArea(
      child: Stack(
        children: <Widget>[
          ListView(
            controller: _scrollController,
            padding: EdgeInsets.only(
              bottom:
                  MediaQuery.paddingOf(context).bottom +
                  kBottomNavigationBarHeight +
                  28,
            ),
            children: <Widget>[
              FitLogPageHeader(
                title: strings.isChinese ? '用户设置' : 'User Settings',
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: <Widget>[
                    Text(
                      strings.nicknameLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6B7A67),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _editingNickname
                          ? TextField(
                              controller: _nicknameController,
                              autofocus: true,
                              onChanged: (_) => setState(() {}),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF152013),
                                    height: 1.0,
                                  ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: strings.nicknameHint,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            )
                          : InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _openNicknameEditor,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Text(
                                  displayNickname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF152013),
                                        height: 1.0,
                                      ),
                                ),
                              ),
                            ),
                    ),
                    if (_editingNickname) ...<Widget>[
                      const SizedBox(width: 8),
                      _InlineCompactSaveButton(
                        saving: _savingNickname,
                        label: strings.isChinese ? '保存' : 'Save',
                        onPressed: _saveNickname,
                      ),
                    ],
                  ],
                ),
              ),
              _ProfilePlanHeroCard(
                strings: strings,
                phaseLabel: strings.phaseLabel(_dietGoalPhase),
                modeLabel: _dietModeLabel(context),
                trainingSummary: _trainingSummaryLabel(context),
                strategyLabel: _strategyLabel(context),
                macros: displayedMacroTargets,
                onInfoTap: _openPlanMethodGuide,
              ),
              _ProfileSummarySectionCard(
                title: strings.isChinese ? '身体资料' : 'Body Profile',
                icon: Icons.person_outline_rounded,
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _BodyProfileTile(
                            label: strings.ageLabel,
                            icon: Icons.accessibility_new_rounded,
                            value: _ageController.text,
                            editing: _editingBodyField != null,
                            onTap: () => _activateBodyProfileField(
                              _BodyProfileField.age,
                            ),
                            editor: _BorderlessProfileTextField(
                              controller: _ageController,
                              autofocus:
                                  _editingBodyField == _BodyProfileField.age,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BodyProfileTile(
                            label: strings.heightCmLabel.split(' ').first,
                            icon: Icons.straighten_rounded,
                            value: _heightCm.toStringAsFixed(1),
                            unit: 'cm',
                            editing: _editingBodyField != null,
                            onTap: () => _activateBodyProfileField(
                              _BodyProfileField.height,
                            ),
                            editor: _InlineUnitEditor(
                              controller: _heightController,
                              autofocus:
                                  _editingBodyField == _BodyProfileField.height,
                              unit: 'cm',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _BodyProfileTile(
                            label: strings.weightKgLabel.split(' ').first,
                            icon: Icons.monitor_weight_outlined,
                            value: _weightKg.toStringAsFixed(1),
                            unit: 'kg',
                            editing: _editingBodyField != null,
                            onTap: () => _activateBodyProfileField(
                              _BodyProfileField.weight,
                            ),
                            editor: _InlineUnitEditor(
                              controller: _weightController,
                              autofocus:
                                  _editingBodyField == _BodyProfileField.weight,
                              unit: 'kg',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BodyProfileTile(
                            label: strings.sexForFormulaLabel,
                            icon: Icons.person_2_outlined,
                            value: strings.sexOptionLabel(_sexForFormula),
                            editing: _editingBodyField != null,
                            onTap: () => _activateBodyProfileField(
                              _BodyProfileField.sex,
                            ),
                            editor: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _sexForFormula,
                                isExpanded: true,
                                icon: const Icon(Icons.expand_more_rounded),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF152013),
                                    ),
                                items: AppConstants.sexOptions.map((value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(strings.sexOptionLabel(value)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _sexForFormula = value);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_editingBodyField != null) ...<Widget>[
                      const SizedBox(height: 14),
                      _InlineSaveActions(
                        saving: _savingBodyProfile,
                        saveLabel: strings.saveProfile,
                        onCancel: () {
                          final profile = _loadedProfile;
                          if (profile == null) {
                            return;
                          }
                          setState(() {
                            _ageController.text = profile.age.toString();
                            _heightController.text = profile.heightCm
                                .toStringAsFixed(1);
                            _weightController.text = profile.weightKg
                                .toStringAsFixed(1);
                            _sexForFormula = profile.sexForFormula;
                            _editingBodyField = null;
                          });
                        },
                        onSave: () {
                          _saveBodyProfile();
                        },
                      ),
                    ],
                  ],
                ),
              ),
              _ProfileSummarySectionCard(
                title: strings.isChinese ? '计划矩阵' : 'Plan Matrix',
                icon: Icons.grid_view_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _ProfileChipRow(
                      label: strings.goalPhaseLabel,
                      children: AppConstants.dietGoalPhases.map((phase) {
                        return _SelectablePill(
                          label: strings.phaseLabel(phase),
                          selected: _dietGoalPhase == phase,
                          compact: true,
                          onTap: () {
                            _savePlanMatrix(phase: phase);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    _ProfileChipRow(
                      label: strings.dietCalculationModeLabel,
                      children: AppConstants.dietCalculationModes.map((mode) {
                        return _SelectablePill(
                          label:
                              mode == AppConstants.dietCalculationModeGramPerKg
                              ? strings.gramPerKgModeLabel
                              : strings.energyRatioModeLabel,
                          selected: _dietCalculationMode == mode,
                          compact: true,
                          onTap: () {
                            _savePlanMatrix(mode: mode);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    _ProfileChipRow(
                      label: strings.dietPlanStrategyLabel,
                      children: AppConstants.dietPlanStrategies.map((strategy) {
                        final disabled =
                            strategy != AppConstants.dietPlanStrategyNone &&
                            !_canUseCuttingStrategy;
                        return _SelectablePill(
                          label: strings.strategyLabel(strategy),
                          selected: _dietPlanStrategy == strategy,
                          disabled: disabled,
                          compact: true,
                          onTap: disabled
                              ? null
                              : () {
                                  _savePlanMatrix(strategy: strategy);
                                },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              if (_isGramPerKgMode)
                _ProfileSummarySectionCard(
                  /*
                    ? '训练频率与自检'
                */
                  title: strings.macroSelfCheckTitle,
                  icon: Icons.fitness_center_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _EvenPillRow(
                        label: strings.trainingFrequencyPerWeekLabel,
                        children: AppConstants.trainingFrequencyPerWeekOptions
                            .map((value) {
                              return _SelectablePill(
                                label: '$value',
                                selected: _trainingFrequencyPerWeek == value,
                                compact: true,
                                expand: true,
                                onTap: () {
                                  _saveMacroSettings(
                                    trainingFrequencyPerWeek: value,
                                  );
                                },
                              );
                            })
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      _EvenPillRow(
                        label: strings.macroSelfCheckPeriodLabel,
                        children: AppConstants.macroSelfCheckPeriodDayOptions
                            .map((value) {
                              return _SelectablePill(
                                label: strings.macroSelfCheckPeriodOptionLabel(
                                  value,
                                ),
                                selected: _macroSelfCheckPeriodDays == value,
                                compact: true,
                                expand: true,
                                onTap: () {
                                  _saveMacroSettings(
                                    selfCheckPeriodDays: value,
                                  );
                                },
                              );
                            })
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _macroSelfCheckEnabled,
                        title: Text(strings.macroSelfCheckEnabledLabel),
                        onChanged: (value) {
                          _saveMacroSettings(selfCheckEnabled: value);
                        },
                      ),
                    ],
                  ),
                ),
              if (!_isGramPerKgMode)
                _ProfileSummarySectionCard(
                  title: strings.isChinese ? '热量比例设置' : 'Energy Ratio Setup',
                  icon: Icons.pie_chart_outline_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ProfileNumericField(
                        controller: _goalKcalController,
                        labelText: strings.dailyGoalKcalLabelForPhase(
                          _dietGoalPhase,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      if (_isBulkingPhase)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            strings.bulkingMacroRatioSuggestion,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ProfileNumericField(
                        controller: _proteinRatioController,
                        labelText: strings.proteinRatioPercentLabel,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          final ratio = NumberUtils.toDouble(
                            value,
                            fallback: -1,
                          );
                          if (ratio < 0 || ratio > 100) {
                            return strings.enterValidMacroRatio;
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      ProfileNumericField(
                        controller: _carbsRatioController,
                        labelText: strings.carbsRatioPercentLabel,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          final ratio = NumberUtils.toDouble(
                            value,
                            fallback: -1,
                          );
                          if (ratio < 0 || ratio > 100) {
                            return strings.enterValidMacroRatio;
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      ProfileNumericField(
                        controller: _fatRatioController,
                        labelText: strings.fatRatioPercentLabel,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          final ratio = NumberUtils.toDouble(
                            value,
                            fallback: -1,
                          );
                          if (ratio < 0 || ratio > 100) {
                            return strings.enterValidMacroRatio;
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${strings.macroRatioHint} (${_macroRatioTotal.toStringAsFixed(1)}%)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if ((_macroRatioTotal - 100).abs() > 0.01)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            strings.macroRatioTotalInvalid,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (_dailyGoalType == 'deficit' && _goalKcal > 700)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            strings.aggressiveGoalWarning,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (_hasEnergyRatioDraft) ...<Widget>[
                        const SizedBox(height: 14),
                        _InlineSaveActions(
                          saving: _savingEnergyRatio,
                          saveLabel: strings.saveChanges,
                          onCancel: () {
                            final profile = _loadedProfile;
                            if (profile == null) {
                              return;
                            }
                            setState(() {
                              _goalKcalController.text = profile
                                  .dailyEnergyGoalKcal
                                  .toStringAsFixed(0);
                              _proteinRatioController.text = profile
                                  .proteinRatioPercent
                                  .toStringAsFixed(0);
                              _carbsRatioController.text = profile
                                  .carbsRatioPercent
                                  .toStringAsFixed(0);
                              _fatRatioController.text = profile.fatRatioPercent
                                  .toStringAsFixed(0);
                            });
                          },
                          onSave: () {
                            _saveEnergyRatioSettings();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              if (!_isGramPerKgMode)
                _ProfileSummarySectionCard(
                  title: strings.macroSelfCheckTitle,
                  icon: Icons.fitness_center_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _EvenPillRow(
                        label: strings.trainingFrequencyPerWeekLabel,
                        children: AppConstants.trainingFrequencyPerWeekOptions
                            .map((value) {
                              return _SelectablePill(
                                label: '$value',
                                selected: _trainingFrequencyPerWeek == value,
                                compact: true,
                                expand: true,
                                onTap: () {
                                  _saveMacroSettings(
                                    trainingFrequencyPerWeek: value,
                                  );
                                },
                              );
                            })
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      _EvenPillRow(
                        label: strings.macroSelfCheckPeriodLabel,
                        children: AppConstants.macroSelfCheckPeriodDayOptions
                            .map((value) {
                              return _SelectablePill(
                                label: strings.macroSelfCheckPeriodOptionLabel(
                                  value,
                                ),
                                selected: _macroSelfCheckPeriodDays == value,
                                compact: true,
                                expand: true,
                                onTap: () {
                                  _saveMacroSettings(
                                    selfCheckPeriodDays: value,
                                  );
                                },
                              );
                            })
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _macroSelfCheckEnabled,
                        title: Text(strings.macroSelfCheckEnabledLabel),
                        onChanged: (value) {
                          _saveMacroSettings(selfCheckEnabled: value);
                        },
                      ),
                    ],
                  ),
                ),
              if (_dietPlanStrategy != AppConstants.dietPlanStrategyNone)
                _ProfileSummarySectionCard(
                  title: strings.isChinese ? '策略细节' : 'Strategy Details',
                  icon: Icons.shield_outlined,
                  child: DietPlanStrategySection(
                    strings: strings,
                    showStrategyPicker: false,
                    canUseCuttingStrategy: _canUseCuttingStrategy,
                    isBulkingPhase: _isBulkingPhase,
                    dietPlanStrategy: _dietPlanStrategy,
                    carbCyclePattern: _carbCyclePattern,
                    carbCyclePreview: carbCyclePreview,
                    carbTaperReviewPeriodDays: _carbTaperReviewPeriodDays,
                    carbTaperTargetLossPctPerWeek:
                        _carbTaperTargetLossPctPerWeek,
                    carbTaperStepG: _carbTaperStepG,
                    carbTaperCurrentDeltaG: _carbTaperCurrentDeltaG,
                    carbTaperReviewResult: _carbTaperReviewResult,
                    hasPendingDietAdjustmentReview:
                        _pendingDietAdjustmentReview != null,
                    handlingCarbTaperAction: _handlingCarbTaperAction,
                    onStrategyChanged: null,
                    onCarbCycleDayTypeChanged: (key, value) {
                      _saveStrategyDetails(
                        carbCyclePattern: <String, String>{
                          ..._carbCyclePattern,
                          key: value,
                        },
                      );
                    },
                    onCarbTaperReviewPeriodChanged: (value) {
                      if (value != null) {
                        _saveStrategyDetails(carbTaperReviewPeriodDays: value);
                      }
                    },
                    onCarbTaperTargetLossChanged: (value) {
                      if (value != null) {
                        _saveStrategyDetails(
                          carbTaperTargetLossPctPerWeek: value,
                        );
                      }
                    },
                    onCarbTaperStepChanged: (value) {
                      if (value != null) {
                        _saveStrategyDetails(carbTaperStepG: value);
                      }
                    },
                    onApplyCarbTaperSuggestion:
                        _pendingDietAdjustmentReview != null &&
                            _carbTaperReviewResult?.suggestedAction ==
                                AppConstants.dietAdjustmentActionDecreaseCarbs
                        ? _applyCarbTaperSuggestion
                        : null,
                    onDismissCarbTaperSuggestion:
                        _pendingDietAdjustmentReview != null
                        ? _dismissCarbTaperSuggestion
                        : null,
                  ),
                ),
              if (_trainingSelfCheckResult != null)
                _ProfileSummarySectionCard(
                  title: strings.macroSelfCheckTitle,
                  icon: Icons.checklist_rounded,
                  key: _selfCheckSectionKey,
                  child: _TrainingSelfCheckSummary(
                    strings: strings,
                    result: _trainingSelfCheckResult!,
                    handlingAction: _handlingSelfCheckAction,
                    onApply: _applySelfCheckSuggestion,
                    onKeep: _keepCurrentSelfCheckSetting,
                  ),
                ),
              _ProfileSummarySectionCard(
                title: strings.languageSettings,
                icon: Icons.translate_rounded,
                key: _settingsSectionKey,
                child: SegmentedButton<AppLanguage>(
                  segments: <ButtonSegment<AppLanguage>>[
                    ButtonSegment<AppLanguage>(
                      value: AppLanguage.english,
                      label: Text(strings.english),
                    ),
                    ButtonSegment<AppLanguage>(
                      value: AppLanguage.chinese,
                      label: Text(strings.chinese),
                    ),
                  ],
                  selected: <AppLanguage>{languageController.language},
                  onSelectionChanged: (selection) {
                    languageController.setLanguage(selection.first);
                  },
                ),
              ),
              _ProfileSummarySectionCard(
                title: strings.calculatedReference,
                icon: Icons.calculate_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _Line(label: 'BMR', value: bmr.toStringAsFixed(0)),
                    _Line(
                      label: strings.lifestyleFactorLabel,
                      value: lifestyleFactor.toStringAsFixed(3),
                    ),
                    _Line(
                      label: strings.tdeeReferenceLabel,
                      value: tdeeReference.toStringAsFixed(0),
                    ),
                    if (_calibrationState != null)
                      _Line(
                        label: strings.calibrationConfidenceLabel,
                        value:
                            '${(_calibrationState!.confidence * 100).toStringAsFixed(0)}%',
                      ),
                    if (_calibrationState != null &&
                        _calibrationState!.windowDays > 0)
                      _Line(
                        label: strings.calibrationWindowLabel,
                        value:
                            '${_calibrationState!.windowDays} d (${_calibrationState!.validDays} valid)',
                      ),
                    _Line(
                      label: strings.goalPhaseLabel,
                      value: strings.phaseLabel(_dietGoalPhase),
                    ),
                    _Line(
                      label: strings.trainingFrequencyPerWeekLabel,
                      value: strings.trainingFrequencyOptionLabel(
                        _trainingFrequencyPerWeek,
                      ),
                    ),
                    _Line(
                      label: strings.todayExerciseCaloriesLabel,
                      value: _todayExerciseCalories.toStringAsFixed(0),
                    ),
                    if (!_isGramPerKgMode) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          strings.energyRatioPhaseNotice(_dietGoalPhase),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      _Line(
                        label: strings.targetIntakeTodayLabel,
                        value: targetIntake.toStringAsFixed(0),
                      ),
                      _Line(
                        label: strings.remainingTodayLabel,
                        value: remaining.toStringAsFixed(0),
                      ),
                    ],
                    if (_isGramPerKgMode) ...<Widget>[
                      const SizedBox(height: 8),
                      _Line(
                        label: '${strings.proteinLabel} (g)',
                        value: displayedMacroTargets.proteinTargetG
                            .toStringAsFixed(1),
                      ),
                      _Line(
                        label: '${strings.carbsLabel} (g)',
                        value: displayedMacroTargets.carbsTargetG
                            .toStringAsFixed(1),
                      ),
                      _Line(
                        label: '${strings.fatLabel} (g)',
                        value: displayedMacroTargets.fatTargetG.toStringAsFixed(
                          1,
                        ),
                      ),
                      _Line(
                        label: strings.macroEquivalentEnergyLabel,
                        value:
                            '${displayedMacroTargets.macroEnergyEquivalentKcal.toStringAsFixed(0)} kcal',
                      ),
                    ],
                  ],
                ),
              ),
              _ProfileSummarySectionCard(
                title: strings.exportData,
                icon: Icons.storage_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: _exportingXlsx ? null : _exportXlsx,
                      icon: _exportingXlsx
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.grid_on_outlined),
                      label: Text(
                        _exportingXlsx ? strings.saving : strings.exportXlsx,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _exportingCsv ? null : _exportCsvZip,
                      icon: _exportingCsv
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.folder_zip_outlined),
                      label: Text(
                        _exportingCsv ? strings.saving : strings.exportCsv,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _clearAllData,
                      icon: const Icon(Icons.delete_forever_outlined),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF9A3F32),
                        side: const BorderSide(color: Color(0xFFE9C9C3)),
                      ),
                      label: Text(strings.clearAllData),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_planGuideOverlayVisible)
            _ProfilePlanGuideInPageOverlay(
              strings: strings,
              profile: draftProfile,
              macroTargetCalculator: _macroTargetCalculator,
              onDismiss: _closePlanMethodGuideOverlay,
            ),
        ],
      ),
    );
  }
}

class _ProfilePlanGuideInPageOverlay extends StatelessWidget {
  const _ProfilePlanGuideInPageOverlay({
    required this.strings,
    required this.profile,
    required this.macroTargetCalculator,
    required this.onDismiss,
  });

  final dynamic strings;
  final UserProfile profile;
  final MacroTargetCalculator macroTargetCalculator;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isGramPerKgMode =
        profile.dietCalculationMode ==
        AppConstants.dietCalculationModeGramPerKg;
    final phaseLabel = strings.phaseLabel(profile.dietGoalPhase);
    final sexLabel = strings.sexOptionLabel(profile.sexForFormula);
    final ratioSummary =
        profile.dietGoalPhase == AppConstants.dietGoalPhaseBulking
        ? const <String>['25%', '50%', '25%']
        : const <String>['30%', '40%', '30%'];

    return Positioned.fill(
      child: Material(
        color: const Color(0x66000000),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: GlassPanel(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const FitLogIconCircle(
                            icon: Icons.info_outline_rounded,
                            color: Color(0xFF4E9E3B),
                            size: 44,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              strings.isChinese ? '计算方法说明' : 'Method Guide',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            onPressed: onDismiss,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: math.min(
                          MediaQuery.of(context).size.height * 0.68,
                          620,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              FitLogStrategyGuideSection(
                                title: strings.strategyGuideBaseMethodTitle,
                                lines: isGramPerKgMode
                                    ? <String>[
                                        strings.gramPerKgModeNotice,
                                        strings.isChinese
                                            ? '当前展示的是 $phaseLabel / $sexLabel 的粗略查表档位。训练频率只决定你落在哪一行，不会推断训练强度、动作量或表现水平。'
                                            : 'This sheet is showing the coarse $phaseLabel / $sexLabel lookup row. Training frequency only decides which row you use; it does not estimate intensity, volume, or performance.',
                                      ]
                                    : <String>[
                                        strings.isChinese
                                            ? '热量比例法会先算 BMR，再按每周训练频率选一个默认生活活动系数，随后叠加减脂/增肌目标，最后把当天净运动消耗加回今日可吃热量。'
                                            : 'Energy-ratio mode starts from BMR, picks a default lifestyle factor from your weekly training frequency, applies the cutting or bulking target, then adds today\'s net exercise calories back into the intake target.',
                                        strings.isChinese
                                            ? '在这个模式里，蛋白质 / 碳水 / 脂肪比例主要由你自己填写；训练频率不会直接改三大营养素百分比。'
                                            : 'In this mode, protein, carbs, and fat percentages are mainly user-controlled; training frequency does not directly rewrite the macro percentages.',
                                      ],
                              ),
                              if (isGramPerKgMode)
                                _ProfileGuideSectionCard(
                                  title: strings.isChinese
                                      ? '当前 g/kg 系数表'
                                      : 'Current g/kg coefficient table',
                                  subtitle: '$phaseLabel · $sexLabel',
                                  child: _ProfileGuideTable(
                                    headers: <String>[
                                      strings.isChinese ? '频率' : 'Freq',
                                      'P',
                                      'C',
                                      'F',
                                    ],
                                    rows: AppConstants
                                        .trainingFrequencyPerWeekOptions
                                        .map((frequency) {
                                          final targets = macroTargetCalculator
                                              .calculateByGramPerKg(
                                                profile: profile.copyWith(
                                                  trainingFrequencyPerWeek:
                                                      frequency,
                                                ),
                                              );
                                          final weight = math.max(
                                            profile.weightKg,
                                            1,
                                          );
                                          return <String>[
                                            '${frequency}d',
                                            (targets.proteinTargetG / weight)
                                                .toStringAsFixed(1),
                                            (targets.carbsTargetG / weight)
                                                .toStringAsFixed(1),
                                            (targets.fatTargetG / weight)
                                                .toStringAsFixed(1),
                                          ];
                                        })
                                        .toList(),
                                  ),
                                ),
                              if (!isGramPerKgMode)
                                _ProfileGuideSectionCard(
                                  title: strings.isChinese
                                      ? '默认起步参考'
                                      : 'Default starting point',
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      _ProfileGuideTable(
                                        headers: <String>[
                                          strings.proteinLabel,
                                          strings.carbsLabel,
                                          strings.fatLabel,
                                        ],
                                        rows: <List<String>>[ratioSummary],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        profile.dietGoalPhase ==
                                                AppConstants
                                                    .dietGoalPhaseBulking
                                            ? strings
                                                  .bulkingMacroRatioSuggestion
                                            : (strings.isChinese
                                                  ? '减脂/维持默认起步比例是蛋白质 30% / 碳水 40% / 脂肪 30%，你可以在下方卡片里继续手动改。'
                                                  : 'The default cutting or maintenance starting split is protein 30% / carbs 40% / fat 30%, and you can still override it below.'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: const Color(0xFF5D6B58),
                                              height: 1.45,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (!isGramPerKgMode)
                                _ProfileGuideSectionCard(
                                  title: strings.isChinese
                                      ? '训练频率对应的默认活动系数'
                                      : 'Default lifestyle factor by frequency',
                                  child: _ProfileGuideTable(
                                    headers: <String>[
                                      strings.isChinese ? '频率' : 'Freq',
                                      strings.isChinese ? '系数' : 'Factor',
                                    ],
                                    rows: AppConstants
                                        .trainingFrequencyPerWeekOptions
                                        .map(
                                          (frequency) => <String>[
                                            '${frequency}d',
                                            AppConstants.defaultLifestyleFactorForTrainingFrequency(
                                              frequency,
                                            ).toStringAsFixed(3),
                                          ],
                                        )
                                        .toList(),
                                  ),
                                ),
                              FitLogStrategyGuideSection(
                                title: strings.strategyGuideNumbersTitle,
                                lines: isGramPerKgMode
                                    ? <String>[
                                        strings.gramPerKgPhaseNotice(
                                          profile.dietGoalPhase,
                                        ),
                                        strings.isChinese
                                            ? '同一频率下，不同性别与阶段会切到不同表；如果你选择“不透露”，FitLog 会取男女两张表的中间值。'
                                            : 'At the same frequency, different sex and phase combinations switch to different tables; if you choose prefer-not-to-say, FitLog uses the midpoint between the male and female rows.',
                                      ]
                                    : <String>[
                                        strings.energyRatioPhaseNotice(
                                          profile.dietGoalPhase,
                                        ),
                                        strings.isChinese
                                            ? '如果本地校准已经积累了足够历史，实际计算会优先使用校准后的生活活动系数，而不是死守上表默认值。'
                                            : 'If local calibration has enough history, the real calculation can replace the default lifestyle factor above with the calibrated factor.',
                                      ],
                              ),
                              FitLogStrategyGuideSection(
                                title: strings.strategyGuideKnowTitle,
                                lines: isGramPerKgMode
                                    ? <String>[
                                        strings.isChinese
                                            ? 'g/kg 模式下，宏量营养素目标才是主目标，kcal 只是把这组宏量换算成一个辅助能量值，方便你理解数量级。'
                                            : 'In g/kg mode, macro targets are the primary target, while kcal is only an auxiliary energy-equivalent number for context.',
                                        strings.isChinese
                                            ? '如果真实训练量和恢复状态长期变化很大，优先通过阶段、频率、体重和策略设置去修正，而不是把这张表当成自动自适应引擎。'
                                            : 'If your real workload or recovery changes a lot over time, adjust phase, frequency, body weight, and strategy settings first instead of treating this table like an auto-adapting engine.',
                                      ]
                                    : <String>[
                                        strings.isChinese
                                            ? '热量比例法更适合你想先抓住总热量与剩余量的时候；真正决定减脂/增肌节奏的，仍然是长期记录与执行稳定度。'
                                            : 'Energy-ratio mode is better when you want to steer by total calories and remaining intake; long-term logging and consistency still drive the real cutting or bulking pace.',
                                        strings.isChinese
                                            ? '训练频率在这里是一个本地起步档位，不是医疗级活动评估；如果后续记录越来越完整，校准会比默认档位更贴近实际情况。'
                                            : 'Training frequency here is only a local starting tier, not a medical-grade activity assessment; once your history is fuller, calibration can become a better fit than the default tier.',
                                      ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePlanHeroCard extends StatelessWidget {
  const _ProfilePlanHeroCard({
    required this.strings,
    required this.phaseLabel,
    required this.modeLabel,
    required this.trainingSummary,
    required this.strategyLabel,
    required this.macros,
    required this.onInfoTap,
  });

  final dynamic strings;
  final String phaseLabel;
  final String modeLabel;
  final String trainingSummary;
  final String strategyLabel;
  final MacroTargets macros;
  final VoidCallback onInfoTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.flag_outlined,
                color: Color(0xFF4E9E3B),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.isChinese ? '当前计划' : 'Current Plan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF355A32),
                  ),
                ),
              ),
              _ProfileInfoButton(
                label: strings.isChinese ? '计算方法说明' : 'Open method guide',
                onTap: onInfoTap,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  phaseLabel,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF152013),
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _OutlinedMetaPill(label: modeLabel),
            ],
          ),
          const SizedBox(height: 16),
          _ProfilePlanInfoRow(
            leadingSize: 28,
            leading: const Icon(
              Icons.fitness_center_rounded,
              color: Color(0xFF355A32),
              size: 20,
            ),
            text: trainingSummary,
          ),
          const SizedBox(height: 10),
          _ProfilePlanInfoRow(
            leadingSize: 28,
            leading: _SmallAssetBadge(
              assetName: FitLogIconAssets.strategy,
              iconSize: 23,
              badgeSize: 28,
              backgroundColor: const Color(0xFFEAF6E3),
            ),
            text: '${strings.isChinese ? '策略' : 'Strategy'}: $strategyLabel',
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFBFDF9),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2ECDD)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _MacroTargetColumn(
                    label: strings.proteinLabel,
                    value: macros.proteinTargetG.toStringAsFixed(0),
                    assetName: FitLogIconAssets.macroProtein,
                  ),
                ),
                const _MacroDivider(),
                Expanded(
                  child: _MacroTargetColumn(
                    label: strings.carbsLabel,
                    value: macros.carbsTargetG.toStringAsFixed(0),
                    assetName: FitLogIconAssets.macroCarbs,
                  ),
                ),
                const _MacroDivider(),
                Expanded(
                  child: _MacroTargetColumn(
                    label: strings.fatLabel,
                    value: macros.fatTargetG.toStringAsFixed(0),
                    assetName: FitLogIconAssets.macroFat,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoButton extends StatefulWidget {
  const _ProfileInfoButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_ProfileInfoButton> createState() => _ProfileInfoButtonState();
}

class _ProfileInfoButtonState extends State<_ProfileInfoButton> {
  static const double _tapSlop = 18;

  bool _pressed = false;
  bool _openQueued = false;
  bool _canceled = false;
  Offset? _downLocalPosition;

  void _queueOpen(Duration delay) {
    if (_openQueued || _canceled) {
      return;
    }
    _openQueued = true;
    Future<void>.delayed(delay, () {
      if (mounted && !_canceled) {
        widget.onTap();
      }
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        _openQueued = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        _canceled = false;
        _downLocalPosition = event.localPosition;
        setState(() => _pressed = true);
        Future<void>.delayed(const Duration(milliseconds: 220), () {
          if (mounted && _pressed && !_canceled) {
            _queueOpen(Duration.zero);
          }
        });
      },
      onPointerMove: (event) {
        final downLocalPosition = _downLocalPosition;
        if (downLocalPosition == null) {
          return;
        }
        if ((event.localPosition - downLocalPosition).distance > _tapSlop) {
          _canceled = true;
          setState(() => _pressed = false);
        }
      },
      onPointerUp: (_) {
        setState(() => _pressed = false);
        _queueOpen(const Duration(milliseconds: 40));
      },
      onPointerCancel: (_) {
        _canceled = true;
        setState(() => _pressed = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _pressed ? const Color(0xFFDCEFD1) : const Color(0xFFEAF6E3),
          shape: BoxShape.circle,
          boxShadow: _pressed
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x22355A32),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: const Icon(
          Icons.info_outline_rounded,
          size: 28,
          color: Color(0xFF4E7B42),
        ),
      ),
    );
  }
}

class _ProfileSummarySectionCard extends StatelessWidget {
  const _ProfileSummarySectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: const Color(0xFF355A32), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF152013),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _BodyProfileTile extends StatelessWidget {
  const _BodyProfileTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.editing,
    required this.editor,
    required this.onTap,
    this.unit,
  });

  final String label;
  final IconData icon;
  final String value;
  final String? unit;
  final bool editing;
  final Widget editor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2ECDD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: const Color(0xFF5B7C54), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF70806D),
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          editing ? editor : _ProfileTileValue(value: value, unit: unit),
        ],
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: editing ? null : onTap,
      child: tile,
    );
  }
}

class _ProfileTileValue extends StatelessWidget {
  const _ProfileTileValue({required this.value, this.unit});

  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final valueStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: const Color(0xFF152013),
    );
    final unitStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: const Color(0xFF42513F),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: RichText(
          maxLines: 1,
          text: TextSpan(
            style: valueStyle,
            children: <InlineSpan>[
              TextSpan(text: value),
              if ((unit ?? '').isNotEmpty)
                TextSpan(text: ' $unit', style: unitStyle),
            ],
          ),
        ),
      ),
    );
  }
}

class _BorderlessProfileTextField extends StatelessWidget {
  const _BorderlessProfileTextField({
    required this.controller,
    required this.autofocus,
    required this.keyboardType,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool autofocus;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      autofocus: autofocus,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: const Color(0xFF152013),
      ),
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

class _InlineUnitEditor extends StatelessWidget {
  const _InlineUnitEditor({
    required this.controller,
    required this.autofocus,
    required this.unit,
    required this.keyboardType,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool autofocus;
  final String unit;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF152013),
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            unit,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF42513F),
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineSaveActions extends StatelessWidget {
  const _InlineSaveActions({
    required this.saving,
    required this.saveLabel,
    required this.onCancel,
    required this.onSave,
  });

  final bool saving;
  final String saveLabel;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        TextButton(
          onPressed: saving ? null : onCancel,
          child: Text(context.strings.cancel),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(saveLabel),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: const Color(0xFF4E9E3B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineCompactSaveButton extends StatelessWidget {
  const _InlineCompactSaveButton({
    required this.saving,
    required this.label,
    required this.onPressed,
  });

  final bool saving;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: saving ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(58, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: const Color(0xFF4E9E3B),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: saving
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

class _ProfileChipRow extends StatelessWidget {
  const _ProfileChipRow({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF32412E),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children
              .map((child) => IntrinsicWidth(child: child))
              .toList(),
        ),
      ],
    );
  }
}

class _EvenPillRow extends StatelessWidget {
  const _EvenPillRow({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF32412E),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            for (var index = 0; index < children.length; index++) ...<Widget>[
              if (index > 0) const SizedBox(width: 8),
              Expanded(child: children[index]),
            ],
          ],
        ),
      ],
    );
  }
}

class _SelectablePill extends StatelessWidget {
  const _SelectablePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.disabled = false,
    this.compact = false,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;
  final bool compact;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: expand ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 16,
          vertical: compact ? 9 : 9,
        ),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE9F7DF) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? const Color(0xFF74BF56)
                : disabled
                ? const Color(0xFFE8ECE4)
                : const Color(0xFFDDE7D8),
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: disabled
                  ? const Color(0xFF98A494)
                  : selected
                  ? const Color(0xFF3E7A31)
                  : const Color(0xFF2E3C2E),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrainingSelfCheckSummary extends StatelessWidget {
  const _TrainingSelfCheckSummary({
    required this.strings,
    required this.result,
    required this.handlingAction,
    required this.onApply,
    required this.onKeep,
  });

  final dynamic strings;
  final TrainingFrequencySelfCheckResult result;
  final bool handlingAction;
  final VoidCallback onApply;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    if (!result.isEnabled) {
      return Text(strings.macroSelfCheckEnabledLabel);
    }
    if (!result.hasValidTrainingData) {
      return Text(strings.macroSelfCheckNoData);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          strings.macroSelfCheckCurrentFrequencyText(
            result.currentTrainingFrequency,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          strings.macroSelfCheckActiveDaysText(
            result.periodDays,
            result.activeTrainingDays,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          strings.macroSelfCheckAverageFrequencyText(
            result.averageWeeklyTrainingFrequency,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          result.isConsistent
              ? strings.macroSelfCheckConsistent
              : strings.macroSelfCheckRecommendedText(
                  result.recommendedTrainingFrequency,
                ),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF2E4E2A),
          ),
        ),
        if (result.belowRecommendedRange) ...<Widget>[
          const SizedBox(height: 8),
          Text(strings.macroSelfCheckBelowRangeNotice),
        ],
        if (!result.isConsistent && result.shouldSuggestAdjustment) ...<Widget>[
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: handlingAction ? null : onApply,
                  child: Text(strings.applySuggestion),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: handlingAction ? null : onKeep,
                  child: Text(strings.keepCurrentSetting),
                ),
              ),
            ],
          ),
        ] else if (!result.isConsistent) ...<Widget>[
          const SizedBox(height: 8),
          Text(strings.macroSelfCheckReminderCooldownHint),
        ],
      ],
    );
  }
}

class _ProfilePlanInfoRow extends StatelessWidget {
  const _ProfilePlanInfoRow({
    required this.leading,
    required this.text,
    this.leadingSize = 20,
  });

  final Widget leading;
  final String text;
  final double leadingSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: leadingSize,
          height: leadingSize,
          child: Center(child: leading),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF31412F),
            ),
          ),
        ),
      ],
    );
  }
}

class _OutlinedMetaPill extends StatelessWidget {
  const _OutlinedMetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF74BF56)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF3E7A31),
        ),
      ),
    );
  }
}

class _ProfileGuideSectionCard extends StatelessWidget {
  const _ProfileGuideSectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFDF9),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2ECDD)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1C2818),
              ),
            ),
            if ((subtitle ?? '').trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF70806D)),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ProfileGuideTable extends StatelessWidget {
  const _ProfileGuideTable({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2ECDD)),
      ),
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: <int, TableColumnWidth>{
          for (var index = 0; index < headers.length; index++)
            index: index == 0
                ? const FixedColumnWidth(64)
                : const FlexColumnWidth(),
        },
        children: <TableRow>[
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF4F8EF)),
            children: headers
                .map(
                  (header) =>
                      _ProfileGuideTableCell(text: header, isHeader: true),
                )
                .toList(),
          ),
          for (final row in rows)
            TableRow(
              children: row
                  .map((cell) => _ProfileGuideTableCell(text: cell))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _ProfileGuideTableCell extends StatelessWidget {
  const _ProfileGuideTableCell({required this.text, this.isHeader = false});

  final String text;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Color(0xFFE9EFE4)),
          bottom: BorderSide(color: Color(0xFFE9EFE4)),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            (isHeader
                    ? Theme.of(context).textTheme.bodySmall
                    : Theme.of(context).textTheme.bodyMedium)
                ?.copyWith(
                  fontWeight: isHeader ? FontWeight.w800 : FontWeight.w700,
                  color: const Color(0xFF253223),
                ),
      ),
    );
  }
}

class _MacroTargetColumn extends StatelessWidget {
  const _MacroTargetColumn({
    required this.label,
    required this.value,
    required this.assetName,
  });

  final String label;
  final String value;
  final String assetName;

  @override
  Widget build(BuildContext context) {
    final iconSize = assetName == FitLogIconAssets.macroCarbs ? 30.0 : 24.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _SmallAssetBadge(
          assetName: assetName,
          iconSize: iconSize,
          backgroundColor: const Color(0xFFF0F6E8),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF6E7C69),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF152013),
            ),
            children: <InlineSpan>[
              TextSpan(text: value),
              TextSpan(
                text: ' g',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF445142),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SmallAssetBadge extends StatelessWidget {
  const _SmallAssetBadge({
    required this.assetName,
    required this.iconSize,
    required this.backgroundColor,
    this.badgeSize = 40,
  });

  final String assetName;
  final double iconSize;
  final Color backgroundColor;
  final double badgeSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
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

class _MacroDivider extends StatelessWidget {
  const _MacroDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: const Color(0xFFE2ECDD),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
