import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/fitlog_icon_assets.dart';
import '../../core/localization/app_language.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/language_controller.dart';
import '../../core/localization/localization_extensions.dart';
import '../../core/theme/fitlog_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/number_utils.dart';
import '../../core/widgets/fitlog_bottom_nav_bar.dart';
import '../../core/widgets/fitlog_guide_sheet.dart';
import '../../core/widgets/fitlog_ui.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/profile_form_fields.dart';
import '../../data/repositories/phase2_repository_exception.dart';
import '../../domain/models/calorie_calibration_state.dart';
import '../../domain/models/carb_taper_review_result.dart';
import '../../domain/models/auth_session.dart';
import '../../domain/models/cloud_profile.dart';
import '../../domain/models/diet_adjustment_review.dart';
import '../../domain/models/subscription_status.dart';
import '../../domain/models/training_frequency_self_check_result.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/weight_log.dart';
import '../../domain/services/carb_cycling_calculator.dart';
import '../../domain/services/macro_target_calculator.dart';
import '../account/account_controller.dart';
import 'diet_plan_strategy_section.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

enum _BodyProfileField { age, height, weight, sex, bodyFat, waist }

enum _BodyTrendMetric { weight, bodyFat, waist }

enum _ProfileDraftSection {
  identity,
  body,
  plan,
  energyRatio,
  macroSettings,
  strategyDetails,
}

class _ProfileDraftChangeGroup {
  const _ProfileDraftChangeGroup({
    required this.section,
    required this.title,
    required this.fields,
  });

  final _ProfileDraftSection section;
  final String title;
  final List<String> fields;
}

class _ProfilePageState extends State<ProfilePage> {
  final _scrollController = ScrollController();
  final _settingsSectionKey = GlobalKey();
  final _selfCheckSectionKey = GlobalKey();

  final _nicknameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _waistController = TextEditingController();
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
  bool _savingProfileDraft = false;
  bool _draftChangesExpanded = false;
  bool _editingNickname = false;
  _BodyProfileField? _editingBodyField;
  UserProfile? _bodyProfileEditSnapshot;
  bool _exportingXlsx = false;
  bool _exportingCsv = false;
  bool _refreshingSubscription = false;
  CalorieCalibrationState? _calibrationState;
  double _todayExerciseCalories = 0;
  double _todayCaloriesIn = 0;
  TrainingFrequencySelfCheckResult? _trainingSelfCheckResult;
  CarbTaperReviewResult? _carbTaperReviewResult;
  DietAdjustmentReview? _pendingDietAdjustmentReview;
  List<WeightLog> _bodyMetricLogs = const <WeightLog>[];
  _BodyTrendMetric _bodyTrendMetric = _BodyTrendMetric.weight;
  int _bodyTrendRangeDays = 14;
  String? _selectedBodyTrendDate;
  bool _handlingSelfCheckAction = false;
  bool _handlingCarbTaperAction = false;
  String? _loadedCloudAccountId;
  int? _loadedCloudProfileVersion;
  bool _cloudReloadScheduled = false;
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
    _bodyFatController.dispose();
    _waistController.dispose();
    _goalKcalController.dispose();
    _proteinRatioController.dispose();
    _carbsRatioController.dispose();
    _fatRatioController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final services = context.read<AppServices>();
    final accountController = _maybeAccountController(listen: false);
    final cloudProfile = accountController?.cloudProfileState.cloudProfile;
    final localProfile = cloudProfile == null
        ? await services.profileRepository.getProfile()
        : null;
    final profile =
        cloudProfile?.profile ?? localProfile ?? UserProfile.defaults;
    final calibrationState = await services.profileRepository
        .getCalorieCalibrationState();
    final exerciseCalories = await services.workoutRepository
        .getExerciseCaloriesByDate(DateUtilsX.todayKey());
    final caloriesIn = await services.foodRepository.getCaloriesInByDate(
      DateUtilsX.todayKey(),
    );
    final bodyMetricLogs = await _loadBodyMetricLogs();
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
      _syncDraftFromProfile(profile);
      _calibrationState = calibrationState;
      _todayExerciseCalories = exerciseCalories;
      _todayCaloriesIn = caloriesIn;
      _bodyMetricLogs = bodyMetricLogs;
      _selectedBodyTrendDate = null;
      _trainingSelfCheckResult = trainingSelfCheckResult;
      _pendingDietAdjustmentReview = pendingDietAdjustmentReview;
      _carbTaperReviewResult = carbTaperReviewResult;
      _editingNickname = false;
      _editingBodyField = null;
      _loadedCloudAccountId =
          cloudProfile?.accountId ??
          (accountController?.hasCurrentAccountCachedCloudProfile == true
              ? accountController?.cachedCloudProfileAccountId
              : null);
      _loadedCloudProfileVersion =
          cloudProfile?.profileVersion ??
          (accountController?.hasCurrentAccountCachedCloudProfile == true
              ? accountController?.cachedCloudProfileVersion
              : null);
      _loading = false;
    });
  }

  void _syncDraftFromProfile(UserProfile profile) {
    _nicknameController.text = profile.nickname ?? '';
    _ageController.text = profile.age.toString();
    _heightController.text = profile.heightCm.toStringAsFixed(1);
    _weightController.text = profile.weightKg.toStringAsFixed(1);
    _bodyFatController.text = profile.bodyFatPercent == null
        ? ''
        : profile.bodyFatPercent!.toStringAsFixed(1);
    _waistController.text = profile.waistCm == null
        ? ''
        : profile.waistCm!.toStringAsFixed(1);
    _goalKcalController.text = profile.dailyEnergyGoalKcal.toStringAsFixed(0);
    _proteinRatioController.text = profile.proteinRatioPercent.toStringAsFixed(
      0,
    );
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
    _bodyProfileEditSnapshot = null;
    _draftChangesExpanded = false;
    _normalizeGoalByAge();
    _normalizeStrategyByContext();
  }

  Future<List<WeightLog>> _loadBodyMetricLogs() async {
    final end = DateUtilsX.parseDay(DateUtilsX.todayKey());
    final start = end.subtract(const Duration(days: 27));
    return context.read<AppServices>().profileRepository.getWeightLogsBetween(
      startDate: DateUtilsX.formatDate(start),
      endDate: DateUtilsX.formatDate(end),
    );
  }

  AccountController? _maybeAccountController({required bool listen}) {
    try {
      return Provider.of<AccountController>(context, listen: listen);
    } catch (_) {
      return null;
    }
  }

  int get _age => NumberUtils.toInt(_ageController.text, fallback: 0);

  double get _heightCm =>
      NumberUtils.toDouble(_heightController.text, fallback: 0);

  double get _weightKg =>
      NumberUtils.toDouble(_weightController.text, fallback: 0);

  double? get _bodyFatPercent =>
      _nullableProfileDouble(_bodyFatController.text);

  double? get _waistCm => _nullableProfileDouble(_waistController.text);

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
        _nullableDoubleChanged(_bodyFatPercent, profile.bodyFatPercent) ||
        _nullableDoubleChanged(_waistCm, profile.waistCm) ||
        _sexForFormula != profile.sexForFormula;
  }

  List<_ProfileDraftChangeGroup> _buildProfileDraftChanges(AppStrings strings) {
    final profile = _loadedProfile;
    if (profile == null) {
      return const <_ProfileDraftChangeGroup>[];
    }
    final groups = <_ProfileDraftChangeGroup>[];

    void addGroup(
      _ProfileDraftSection section,
      String title,
      List<String> fields,
    ) {
      if (fields.isEmpty) {
        return;
      }
      groups.add(
        _ProfileDraftChangeGroup(
          section: section,
          title: title,
          fields: fields,
        ),
      );
    }

    addGroup(
      _ProfileDraftSection.identity,
      strings.nicknameLabel,
      _nicknameController.text.trim() != (profile.nickname ?? '').trim()
          ? <String>[strings.nicknameLabel]
          : const <String>[],
    );

    addGroup(
      _ProfileDraftSection.body,
      strings.isChinese ? '身体资料' : 'Body Profile',
      <String>[
        if (_age != profile.age) strings.ageLabel,
        if (_doubleChanged(_heightCm, profile.heightCm))
          _labelWithoutUnit(strings.heightCmLabel),
        if (_doubleChanged(_weightKg, profile.weightKg))
          _labelWithoutUnit(strings.weightKgLabel),
        if (_nullableDoubleChanged(_bodyFatPercent, profile.bodyFatPercent))
          _labelWithoutUnit(strings.bodyFatPercentLabel),
        if (_nullableDoubleChanged(_waistCm, profile.waistCm))
          _labelWithoutUnit(strings.waistCmLabel),
        if (_sexForFormula != profile.sexForFormula) strings.sexForFormulaLabel,
      ],
    );

    addGroup(
      _ProfileDraftSection.plan,
      strings.isChinese ? '计划矩阵' : 'Plan Matrix',
      <String>[
        if (_dietGoalPhase != profile.dietGoalPhase) strings.goalPhaseLabel,
        if (_dietCalculationMode != profile.dietCalculationMode)
          strings.dietCalculationModeLabel,
        if (_dietPlanStrategy != profile.dietPlanStrategy)
          strings.dietPlanStrategyLabel,
      ],
    );

    addGroup(
      _ProfileDraftSection.energyRatio,
      strings.isChinese ? '热量比例设置' : 'Energy Ratio Setup',
      <String>[
        if (_doubleChanged(_goalKcal, profile.dailyEnergyGoalKcal))
          strings.isChinese ? '目标热量' : 'Target kcal',
        if (_doubleChanged(_proteinRatioPercent, profile.proteinRatioPercent))
          strings.proteinRatioPercentLabel,
        if (_doubleChanged(_carbsRatioPercent, profile.carbsRatioPercent))
          strings.carbsRatioPercentLabel,
        if (_doubleChanged(_fatRatioPercent, profile.fatRatioPercent))
          strings.fatRatioPercentLabel,
      ],
    );

    addGroup(
      _ProfileDraftSection.macroSettings,
      strings.macroSelfCheckTitle,
      <String>[
        if (_trainingFrequencyPerWeek != profile.trainingFrequencyPerWeek)
          strings.trainingFrequencyPerWeekLabel,
        if (_macroSelfCheckPeriodDays != profile.macroSelfCheckPeriodDays)
          strings.macroSelfCheckPeriodLabel,
        if (_macroSelfCheckEnabled != profile.macroSelfCheckEnabled)
          strings.macroSelfCheckEnabledLabel,
      ],
    );

    final currentPattern = _carbCyclePattern;
    final savedPattern = profile.carbCyclePattern;
    addGroup(
      _ProfileDraftSection.strategyDetails,
      strings.isChinese ? '策略细节' : 'Strategy Details',
      <String>[
        if (!_sameStringMap(currentPattern, savedPattern))
          strings.carbCyclePreviewLabel,
        if (_carbTaperReviewPeriodDays != profile.carbTaperReviewPeriodDays)
          strings.carbTaperReviewPeriodLabel,
        if (_doubleChanged(
          _carbTaperTargetLossPctPerWeek,
          profile.carbTaperTargetLossPctPerWeek,
        ))
          strings.carbTaperTargetLossLabel,
        if (_doubleChanged(_carbTaperStepG, profile.carbTaperStepG))
          strings.carbTaperStepLabel,
      ],
    );

    return groups;
  }

  bool _doubleChanged(double a, double b) => (a - b).abs() > 0.01;

  bool _nullableDoubleChanged(double? a, double? b) {
    if (a == null && b == null) {
      return false;
    }
    if (a == null || b == null) {
      return true;
    }
    return _doubleChanged(a, b);
  }

  double? _nullableProfileDouble(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return NumberUtils.toDouble(trimmed, fallback: 0);
  }

  bool _sameStringMap(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  String _labelWithoutUnit(String label) {
    final parenIndex = label.indexOf('(');
    if (parenIndex <= 0) {
      return label;
    }
    return label.substring(0, parenIndex).trim();
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
      if (_editingBodyField == null) {
        _bodyProfileEditSnapshot = _buildDraftProfile();
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
      bodyFatPercent: _bodyFatPercent,
      waistCm: _waistCm,
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
    final strings = context.stringsRead;
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

    showFitLogGuideSheet<void>(
      context: context,
      leading: FitLogIconCircle(
        icon: Icons.info_outline_rounded,
        color: context.fitLogTheme.primary,
        size: 44,
      ),
      title: strings.isChinese ? '计算方法说明' : 'Method Guide',
      body: Column(
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
                rows: AppConstants.trainingFrequencyPerWeekOptions.map((
                  frequency,
                ) {
                  final targets = _macroTargetCalculator.calculateByGramPerKg(
                    profile: profile.copyWith(
                      trainingFrequencyPerWeek: frequency,
                    ),
                  );
                  final weight = math.max(profile.weightKg, 1);
                  return <String>[
                    '${frequency}d',
                    (targets.proteinTargetG / weight).toStringAsFixed(1),
                    (targets.carbsTargetG / weight).toStringAsFixed(1),
                    (targets.fatTargetG / weight).toStringAsFixed(1),
                  ];
                }).toList(),
              ),
            ),
          if (!isGramPerKgMode)
            _ProfileGuideSectionCard(
              title: strings.isChinese ? '默认起步参考' : 'Default starting point',
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
                    profile.dietGoalPhase == AppConstants.dietGoalPhaseBulking
                        ? strings.bulkingMacroRatioSuggestion
                        : (strings.isChinese
                              ? '减脂/维持默认起步比例是蛋白质 30% / 碳水 40% / 脂肪 30%，你可以在下方卡片里继续手动改。'
                              : 'The default cutting or maintenance starting split is protein 30% / carbs 40% / fat 30%, and you can still override it below.'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.fitLogTheme.textSecondary,
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
                rows: AppConstants.trainingFrequencyPerWeekOptions
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
                    strings.gramPerKgPhaseNotice(profile.dietGoalPhase),
                    strings.isChinese
                        ? '同一个频率下，不同性别与阶段会切到不同表；如果你选择“不透露”，FitLog 会取男女两张表的中间值。'
                        : 'At the same frequency, different sex and phase combinations switch to different tables; if you choose prefer-not-to-say, FitLog uses the midpoint between the male and female rows.',
                  ]
                : <String>[
                    strings.energyRatioPhaseNotice(profile.dietGoalPhase),
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
    );
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

  String _formatOptionalMetric(double? value) {
    return value == null ? '--' : value.toStringAsFixed(1);
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
    final bodyFat = _bodyFatPercent;
    if (bodyFat != null && (bodyFat <= 0 || bodyFat > 100)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.enterValidBodyFat)));
      return false;
    }
    final waist = _waistCm;
    if (waist != null && waist <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.enterValidWaist)));
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

  Future<void> _refreshSubscriptionStatus() async {
    if (_refreshingSubscription) {
      return;
    }
    final accountController = _maybeAccountController(listen: false);
    if (accountController == null) {
      return;
    }
    setState(() => _refreshingSubscription = true);
    try {
      await accountController.refreshSubscriptionStatus();
    } catch (error) {
      if (mounted) {
        final strings = context.stringsRead;
        final message = error is Phase2RepositoryException
            ? strings.phase2ErrorMessage(error.code)
            : strings.phase2ErrorMessage('subscription_load_failed');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() => _refreshingSubscription = false);
      }
    }
  }

  Future<void> _openSubscriptionSheet() async {
    final accountController = _maybeAccountController(listen: false);
    if (accountController == null) {
      return;
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.stringsRead.subscriptionTitle,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _ProfileSubscriptionDialog(
          accountController: accountController,
          refreshing: _refreshingSubscription,
          onRefresh: _refreshSubscriptionStatus,
          onRedeem: () {
            Navigator.of(dialogContext).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _openRedeemCodeSheet();
              }
            });
          },
          onClose: () => Navigator.of(dialogContext).pop(),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _openRedeemCodeSheet() async {
    final accountController = _maybeAccountController(listen: false);
    if (accountController == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.fitLogTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SubscriptionRedeemSheet(
        accountController: accountController,
        onRedeemed: () {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.stringsRead.redeemCodeSuccess)),
          );
        },
      ),
    );
  }

  Future<void> _persistProfile(UserProfile profile) async {
    final services = context.read<AppServices>();
    final refreshNotifier = context.read<RefreshNotifier>();
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.stringsRead;

    final accountController = _maybeAccountController(listen: false);
    if (accountController != null && accountController.authSession.isSignedIn) {
      await accountController.saveCloudProfile(profile);
      await services.profileRepository.upsertWeightLog(
        accountId: accountController.authSession.accountId,
        date: DateUtilsX.todayKey(),
        weightKg: profile.weightKg,
        bodyFatPercent: profile.bodyFatPercent,
        waistCm: profile.waistCm,
        source: 'profile_save',
      );
    } else {
      await services.profileRepository.saveProfile(profile);
    }
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
    final bodyMetricLogs = await _loadBodyMetricLogs();

    if (!mounted) {
      return;
    }

    refreshNotifier.markDataChanged();
    context.refreshDailySummaryCacheForDate(DateUtilsX.todayKey());
    final updatedAccountController = _maybeAccountController(listen: false);
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
      _bodyMetricLogs = bodyMetricLogs;
      _selectedBodyTrendDate = null;
      _loadedCloudAccountId = updatedAccountController?.authSession.accountId;
      _loadedCloudProfileVersion = updatedAccountController
          ?.cloudProfileState
          .cloudProfile
          ?.profileVersion;
      _bodyProfileEditSnapshot = null;
      _draftChangesExpanded = false;
    });
    messenger.showSnackBar(SnackBar(content: Text(strings.profileSaved)));
  }

  void _completeNicknameDraft() {
    FocusScope.of(context).unfocus();
    setState(() => _editingNickname = false);
  }

  void _completeBodyProfileDraft() {
    if (_hasBodyProfileDraft && !_validateBodyProfile()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _editingBodyField = null;
      _bodyProfileEditSnapshot = null;
    });
  }

  void _cancelBodyProfileEdit() {
    final snapshot = _bodyProfileEditSnapshot ?? _loadedProfile;
    if (snapshot == null) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _ageController.text = snapshot.age.toString();
      _heightController.text = snapshot.heightCm.toStringAsFixed(1);
      _weightController.text = snapshot.weightKg.toStringAsFixed(1);
      _bodyFatController.text = snapshot.bodyFatPercent == null
          ? ''
          : snapshot.bodyFatPercent!.toStringAsFixed(1);
      _waistController.text = snapshot.waistCm == null
          ? ''
          : snapshot.waistCm!.toStringAsFixed(1);
      _sexForFormula = snapshot.sexForFormula;
      _editingBodyField = null;
      _bodyProfileEditSnapshot = null;
      _normalizeGoalByAge();
      _normalizeStrategyByContext();
    });
  }

  Future<void> _saveProfileDraft() async {
    if (_savingProfileDraft) {
      return;
    }
    if (_editingBodyField != null && !_validateBodyProfile()) {
      return;
    }
    if (!_isGramPerKgMode && !_validateEnergyRatioFields()) {
      return;
    }
    final changes = _buildProfileDraftChanges(context.stringsRead);
    if (changes.isEmpty) {
      FocusScope.of(context).unfocus();
      setState(() {
        _editingNickname = false;
        _editingBodyField = null;
        _bodyProfileEditSnapshot = null;
        _draftChangesExpanded = false;
      });
      return;
    }

    setState(() => _savingProfileDraft = true);
    try {
      await _persistProfile(_buildDraftProfile());
      if (mounted) {
        FocusScope.of(context).unfocus();
        setState(() {
          _editingNickname = false;
          _editingBodyField = null;
          _bodyProfileEditSnapshot = null;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.stringsRead.summaryError(error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingProfileDraft = false);
      }
    }
  }

  void _discardProfileDraft() {
    final profile = _loadedProfile;
    if (profile == null) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _syncDraftFromProfile(profile);
      _editingNickname = false;
      _editingBodyField = null;
    });
  }

  void _updatePlanMatrixDraft({String? phase, String? mode, String? strategy}) {
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
  }

  void _updateMacroSettingsDraft({
    int? trainingFrequencyPerWeek,
    int? selfCheckPeriodDays,
    bool? selfCheckEnabled,
  }) {
    final nextFrequency = trainingFrequencyPerWeek ?? _trainingFrequencyPerWeek;
    final nextPeriod = selfCheckPeriodDays ?? _macroSelfCheckPeriodDays;
    final nextEnabled = selfCheckEnabled ?? _macroSelfCheckEnabled;
    setState(() {
      _trainingFrequencyPerWeek = nextFrequency;
      _macroSelfCheckPeriodDays = nextPeriod;
      _macroSelfCheckEnabled = nextEnabled;
    });
  }

  void _updateStrategyDetailsDraft({
    Map<String, String>? carbCyclePattern,
    int? carbTaperReviewPeriodDays,
    double? carbTaperTargetLossPctPerWeek,
    double? carbTaperStepG,
  }) {
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
  }

  Future<void> _exportXlsx() async {
    final service = context.read<AppServices>().xlsxExportService;
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.stringsRead;

    setState(() => _exportingXlsx = true);
    try {
      final filePath = await service.export();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(strings.exportReady('XLSX', filePath))),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      final message = e is Phase2RepositoryException
          ? strings.phase2ErrorMessage(e.code)
          : strings.exportFailed('XLSX', e);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _exportingXlsx = false);
      }
    }
  }

  Future<void> _exportCsvZip() async {
    final service = context.read<AppServices>().csvExportService;
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.stringsRead;

    setState(() => _exportingCsv = true);
    try {
      final filePath = await service.exportZip();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(strings.exportReady('CSV', filePath))),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      final message = e is Phase2RepositoryException
          ? strings.phase2ErrorMessage(e.code)
          : strings.exportFailed('CSV', e);
      messenger.showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> _signOutAccount() async {
    final accountController = _maybeAccountController(listen: false);
    if (accountController == null) {
      return;
    }
    final strings = context.stringsRead;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(strings.signOutAccountTitle),
              content: Text(strings.signOutAccountBody),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(strings.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(strings.signOutAccount),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    try {
      await accountController.signOut();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(strings.signedOut)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is Phase2RepositoryException
          ? strings.phase2ErrorMessage(error.code)
          : strings.phase2ErrorMessage('auth_failed');
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
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
    final accountController = _maybeAccountController(listen: true);
    final gate = _buildAccountGate(accountController);
    if (gate != null) {
      return gate;
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final strings = context.strings;
    final languageController = context.watch<LanguageController>();
    final themeController = context.watch<FitLogThemeController>();
    final fitTheme = context.fitLogTheme;

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
    final draftChanges = _buildProfileDraftChanges(strings);
    final draftHasChanges = draftChanges.isNotEmpty;
    final draftSections = draftChanges.map((group) => group.section).toSet();
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final navReservedHeight = FitLogBottomNavBar.reservedHeightFor(context);
    final draftBarBottomOffset =
        navReservedHeight - FitLogBottomNavBar.topContentGap + 8;
    final draftBarHeight = draftHasChanges
        ? (_draftChangesExpanded ? 236.0 : 128.0)
        : 0.0;

    return SafeArea(
      child: Stack(
        children: <Widget>[
          ListView(
            controller: _scrollController,
            padding: EdgeInsets.only(
              bottom: navReservedHeight + 28 + draftBarHeight + keyboardInset,
            ),
            children: <Widget>[
              FitLogPageHeader(
                title: strings.isChinese ? '用户设置' : 'User Settings',
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                trailing: accountController == null
                    ? null
                    : _ProfileSubscriptionEntryButton(
                        accountController: accountController,
                        onPressed: _openSubscriptionSheet,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: <Widget>[
                    Text(
                      strings.nicknameLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: fitTheme.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (draftSections.contains(_ProfileDraftSection.identity))
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _ModifiedBadge(label: strings.modified),
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
                                    color: fitTheme.textPrimary,
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
                                        color: fitTheme.textPrimary,
                                        height: 1.0,
                                      ),
                                ),
                              ),
                            ),
                    ),
                    if (_editingNickname) ...<Widget>[
                      const SizedBox(width: 8),
                      _InlineCompactSaveButton(
                        saving: false,
                        label: strings.done,
                        onPressed: _completeNicknameDraft,
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
                modified: draftSections.contains(_ProfileDraftSection.body),
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
                            label: _labelWithoutUnit(strings.heightCmLabel),
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
                            label: _labelWithoutUnit(strings.weightKgLabel),
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
                                      color: fitTheme.textPrimary,
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
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _BodyProfileTile(
                            label: _labelWithoutUnit(
                              strings.bodyFatPercentLabel,
                            ),
                            icon: Icons.percent_rounded,
                            value: _formatOptionalMetric(_bodyFatPercent),
                            unit: '%',
                            editing: _editingBodyField != null,
                            onTap: () => _activateBodyProfileField(
                              _BodyProfileField.bodyFat,
                            ),
                            editor: _InlineUnitEditor(
                              controller: _bodyFatController,
                              autofocus:
                                  _editingBodyField ==
                                  _BodyProfileField.bodyFat,
                              unit: '%',
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
                            label: _labelWithoutUnit(strings.waistCmLabel),
                            icon: Icons.vertical_align_center_rounded,
                            value: _formatOptionalMetric(_waistCm),
                            unit: 'cm',
                            editing: _editingBodyField != null,
                            onTap: () => _activateBodyProfileField(
                              _BodyProfileField.waist,
                            ),
                            editor: _InlineUnitEditor(
                              controller: _waistController,
                              autofocus:
                                  _editingBodyField == _BodyProfileField.waist,
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
                    if (_editingBodyField != null) ...<Widget>[
                      const SizedBox(height: 14),
                      _InlineSaveActions(
                        saving: false,
                        saveLabel: strings.done,
                        onCancel: _cancelBodyProfileEdit,
                        onSave: _completeBodyProfileDraft,
                      ),
                    ],
                  ],
                ),
              ),
              _BodyTrendCard(
                logs: _bodyMetricLogs,
                metric: _bodyTrendMetric,
                rangeDays: _bodyTrendRangeDays,
                selectedDate: _selectedBodyTrendDate,
                onMetricChanged: (metric) {
                  setState(() {
                    _bodyTrendMetric = metric;
                    _selectedBodyTrendDate = null;
                  });
                },
                onRangeChanged: (rangeDays) {
                  setState(() {
                    _bodyTrendRangeDays = rangeDays;
                    _selectedBodyTrendDate = null;
                  });
                },
                onPointSelected: (date) {
                  setState(() => _selectedBodyTrendDate = date);
                },
              ),
              _ProfileSummarySectionCard(
                title: strings.isChinese ? '计划矩阵' : 'Plan Matrix',
                icon: Icons.grid_view_rounded,
                modified: draftSections.contains(_ProfileDraftSection.plan),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _ProfileChipRow(
                      label: strings.goalPhaseLabel,
                      children: AppConstants.dietGoalPhases.map((phase) {
                        return _SelectablePill(
                          key: ValueKey<String>('profile_phase_$phase'),
                          label: strings.phaseLabel(phase),
                          selected: _dietGoalPhase == phase,
                          compact: true,
                          onTap: () {
                            _updatePlanMatrixDraft(phase: phase);
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
                            _updatePlanMatrixDraft(mode: mode);
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
                                  _updatePlanMatrixDraft(strategy: strategy);
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
                  modified: draftSections.contains(
                    _ProfileDraftSection.macroSettings,
                  ),
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
                                  _updateMacroSettingsDraft(
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
                                  _updateMacroSettingsDraft(
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
                          _updateMacroSettingsDraft(selfCheckEnabled: value);
                        },
                      ),
                    ],
                  ),
                ),
              if (!_isGramPerKgMode)
                _ProfileSummarySectionCard(
                  title: strings.isChinese ? '热量比例设置' : 'Energy Ratio Setup',
                  icon: Icons.pie_chart_outline_rounded,
                  modified: draftSections.contains(
                    _ProfileDraftSection.energyRatio,
                  ),
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
                    ],
                  ),
                ),
              if (!_isGramPerKgMode)
                _ProfileSummarySectionCard(
                  title: strings.macroSelfCheckTitle,
                  icon: Icons.fitness_center_rounded,
                  modified: draftSections.contains(
                    _ProfileDraftSection.macroSettings,
                  ),
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
                                  _updateMacroSettingsDraft(
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
                                  _updateMacroSettingsDraft(
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
                          _updateMacroSettingsDraft(selfCheckEnabled: value);
                        },
                      ),
                    ],
                  ),
                ),
              if (_dietPlanStrategy != AppConstants.dietPlanStrategyNone)
                _ProfileSummarySectionCard(
                  title: strings.isChinese ? '策略细节' : 'Strategy Details',
                  icon: Icons.shield_outlined,
                  modified: draftSections.contains(
                    _ProfileDraftSection.strategyDetails,
                  ),
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
                      _updateStrategyDetailsDraft(
                        carbCyclePattern: <String, String>{
                          ..._carbCyclePattern,
                          key: value,
                        },
                      );
                    },
                    onCarbTaperReviewPeriodChanged: (value) {
                      if (value != null) {
                        _updateStrategyDetailsDraft(
                          carbTaperReviewPeriodDays: value,
                        );
                      }
                    },
                    onCarbTaperTargetLossChanged: (value) {
                      if (value != null) {
                        _updateStrategyDetailsDraft(
                          carbTaperTargetLossPctPerWeek: value,
                        );
                      }
                    },
                    onCarbTaperStepChanged: (value) {
                      if (value != null) {
                        _updateStrategyDetailsDraft(carbTaperStepG: value);
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
                title: strings.themeSettings,
                icon: Icons.palette_outlined,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    SizedBox(
                      width: 132,
                      child: _SelectablePill(
                        label: strings.greenTheme,
                        selected: themeController.theme == FitLogThemeKey.green,
                        expand: true,
                        onTap: () {
                          themeController.setTheme(FitLogThemeKey.green);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 132,
                      child: _SelectablePill(
                        label: strings.blackTheme,
                        selected:
                            themeController.theme == FitLogThemeKey.blackOrange,
                        expand: true,
                        onTap: () {
                          themeController.setTheme(FitLogThemeKey.blackOrange);
                        },
                      ),
                    ),
                  ],
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
              if (accountController != null)
                _ProfileSummarySectionCard(
                  title: strings.accountActionsTitle,
                  icon: Icons.logout_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      OutlinedButton.icon(
                        key: const ValueKey<String>('profile_sign_out_button'),
                        onPressed: _signOutAccount,
                        icon: const Icon(Icons.logout_rounded),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.fitLogTheme.primaryDeep,
                          side: BorderSide(color: context.fitLogTheme.outline),
                        ),
                        label: Text(strings.signOutAccount),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (draftHasChanges)
            Positioned(
              left: 14,
              right: 14,
              bottom: draftBarBottomOffset,
              child: _ProfileDraftSaveBar(
                changes: draftChanges,
                expanded: _draftChangesExpanded,
                saving: _savingProfileDraft,
                onToggleExpanded: () {
                  setState(() {
                    _draftChangesExpanded = !_draftChangesExpanded;
                  });
                },
                onDiscard: _discardProfileDraft,
                onSave: _saveProfileDraft,
              ),
            ),
        ],
      ),
    );
  }

  Widget? _buildAccountGate(AccountController? accountController) {
    if (accountController == null) {
      return null;
    }
    final strings = context.strings;
    if (!accountController.initialized ||
        accountController.authSession.status == AuthSessionStatus.loading) {
      return Center(child: Text(strings.loading));
    }
    if (!accountController.authSession.isSignedIn) {
      return _ProfileSignInGate(accountController: accountController);
    }
    final cloudState = accountController.cloudProfileState;
    switch (cloudState.status) {
      case CloudProfileStatus.unknown:
      case CloudProfileStatus.loading:
        if (_canShowCachedProfileFor(accountController)) {
          return null;
        }
        return Center(child: Text(strings.cloudProfileLoading));
      case CloudProfileStatus.saving:
        return _loadedProfile == null
            ? Center(child: Text(strings.cloudProfileLoading))
            : null;
      case CloudProfileStatus.missing:
        return _CloudProfileSetupGate(accountController: accountController);
      case CloudProfileStatus.error:
      case CloudProfileStatus.conflict:
        final errorCode = cloudState.errorCode ?? 'profile_load_failed';
        return _ProfilePhase2ErrorGate(
          message: strings.phase2ErrorMessage(errorCode),
          errorCode: errorCode,
          onRetry: accountController.refreshAccountState,
        );
      case CloudProfileStatus.offlineReadonly:
      case CloudProfileStatus.ready:
        final cloudProfile = cloudState.cloudProfile;
        if (cloudProfile != null &&
            (_loadedCloudAccountId != cloudProfile.accountId ||
                _loadedCloudProfileVersion != cloudProfile.profileVersion)) {
          final canShowCache = _canShowCachedProfileFor(accountController);
          _scheduleCloudProfileReload(showLoading: !canShowCache);
          return canShowCache
              ? null
              : Center(child: Text(strings.cloudProfileLoading));
        }
        return null;
    }
  }

  bool _canShowCachedProfileFor(AccountController accountController) {
    return !_loading &&
        _loadedProfile != null &&
        accountController.hasCurrentAccountCachedCloudProfile &&
        _loadedCloudAccountId == accountController.authSession.accountId;
  }

  void _scheduleCloudProfileReload({bool showLoading = true}) {
    if (_cloudReloadScheduled) {
      return;
    }
    _cloudReloadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      if (showLoading) {
        setState(() => _loading = true);
      }
      await _load();
      if (!mounted) {
        return;
      }
      setState(() => _cloudReloadScheduled = false);
    });
  }
}

class _ProfileSignInGate extends StatefulWidget {
  const _ProfileSignInGate({required this.accountController});

  final AccountController accountController;

  @override
  State<_ProfileSignInGate> createState() => _ProfileSignInGateState();
}

enum _ProfileAuthMode { landing, signIn, register }

class _ProfileSignInGateState extends State<_ProfileSignInGate>
    with SingleTickerProviderStateMixin {
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerCodeController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();
  late final AnimationController _logoController;
  _ProfileAuthMode _mode = _ProfileAuthMode.landing;
  bool _sendingRegistrationCode = false;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerCodeController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final textTheme = Theme.of(context).textTheme;
    return ColoredBox(
      color: const Color(0xFFF7FAF4),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
            final keyboardVisible = keyboardInset > 0;
            final isRegister = _mode == _ProfileAuthMode.register;
            final logoSize = (constraints.maxWidth * (isRegister ? 0.30 : 0.36))
                .clamp(isRegister ? 112.0 : 132.0, isRegister ? 146.0 : 176.0)
                .toDouble();
            final logoTop = (constraints.maxHeight * (isRegister ? 0.09 : 0.18))
                .clamp(isRegister ? 56.0 : 118.0, isRegister ? 104.0 : 178.0)
                .toDouble();
            final formTop = switch (_mode) {
              _ProfileAuthMode.landing =>
                (constraints.maxHeight * 0.66).clamp(410.0, 540.0).toDouble(),
              _ProfileAuthMode.signIn =>
                (constraints.maxHeight * 0.54).clamp(330.0, 455.0).toDouble(),
              _ProfileAuthMode.register =>
                (constraints.maxHeight * 0.34).clamp(244.0, 306.0).toDouble(),
            };
            final contentHeight =
                constraints.maxHeight +
                (keyboardVisible ? keyboardInset + 24 : 0);
            final content = SizedBox(
              height: contentHeight,
              child: Stack(
                children: <Widget>[
                  if (!widget.accountController.backendConfigured)
                    Positioned(
                      top: 12,
                      left: 30,
                      right: 30,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: _Phase2NoticeBox(
                            text: strings.phase2BackendNotConfigured,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: logoTop,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _AnimatedFitLogAgentLogo(
                        animation: _logoController,
                        size: logoSize,
                      ),
                    ),
                  ),
                  Positioned(
                    top: formTop,
                    left: 30,
                    right: 30,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: AutofillGroup(child: _buildAuthPanel(textTheme)),
                      ),
                    ),
                  ),
                ],
              ),
            );
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: keyboardVisible
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              child: content,
            );
          },
        ),
      ),
    );
  }

  Widget _buildAuthPanel(TextTheme textTheme) {
    return switch (_mode) {
      _ProfileAuthMode.landing => _buildLandingPanel(textTheme),
      _ProfileAuthMode.signIn => _buildSignInPanel(textTheme),
      _ProfileAuthMode.register => _buildRegisterPanel(textTheme),
    };
  }

  Widget _buildLandingPanel(TextTheme textTheme) {
    final strings = context.strings;
    return Column(
      children: <Widget>[
        _ProfileAuthPrimaryButton(
          key: const ValueKey<String>('phase2_sign_in_entry_button'),
          label: strings.signInToFitLog,
          loading: false,
          onPressed: _switchToSignIn,
        ),
        const SizedBox(height: 14),
        _ProfileAuthTextLink(
          key: const ValueKey<String>('phase2_register_link'),
          label: strings.imNewToFitLog,
          onPressed: _switchToRegister,
        ),
      ],
    );
  }

  Widget _buildSignInPanel(TextTheme textTheme) {
    final strings = context.strings;
    return Column(
      children: <Widget>[
        _ProfileSignInField(
          fieldKey: const ValueKey<String>('phase2_login_email_field'),
          controller: _loginEmailController,
          label: strings.emailLabel,
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.email],
        ),
        const SizedBox(height: 14),
        _ProfileSignInField(
          fieldKey: const ValueKey<String>('phase2_login_password_field'),
          controller: _loginPasswordController,
          label: strings.passwordLabel,
          icon: Icons.lock_outline_rounded,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          obscureText: true,
          autofillHints: const <String>[AutofillHints.password],
          onSubmitted: (_) => _signIn(),
        ),
        const SizedBox(height: 16),
        _ProfileAuthPrimaryButton(
          key: const ValueKey<String>('phase2_login_button'),
          label: strings.signInAccount,
          loading: _authenticating,
          onPressed: _authenticating ? null : _signIn,
        ),
        const SizedBox(height: 14),
        _ProfileAuthTextLink(
          key: const ValueKey<String>('phase2_register_link'),
          label: strings.imNewToFitLog,
          onPressed: _switchToRegister,
        ),
      ],
    );
  }

  Widget _buildRegisterPanel(TextTheme textTheme) {
    final strings = context.strings;
    return Column(
      children: <Widget>[
        _ProfileSignInField(
          fieldKey: const ValueKey<String>('phase2_register_email_field'),
          controller: _registerEmailController,
          label: strings.emailLabel,
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.email],
          suffix: TextButton(
            key: const ValueKey<String>('phase2_register_send_code_button'),
            onPressed: _sendingRegistrationCode ? null : _sendRegistrationCode,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF3D8D3A),
              textStyle: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            child: _sendingRegistrationCode
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(strings.sendOtp),
          ),
        ),
        const SizedBox(height: 14),
        _ProfileSignInField(
          fieldKey: const ValueKey<String>('phase2_register_code_field'),
          controller: _registerCodeController,
          label: strings.otpCodeLabel,
          icon: Icons.pin_outlined,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.oneTimeCode],
        ),
        const SizedBox(height: 24),
        _ProfileSignInField(
          fieldKey: const ValueKey<String>('phase2_register_password_field'),
          controller: _registerPasswordController,
          label: strings.passwordLabel,
          icon: Icons.lock_outline_rounded,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.next,
          obscureText: true,
          autofillHints: const <String>[AutofillHints.newPassword],
        ),
        const SizedBox(height: 14),
        _ProfileSignInField(
          fieldKey: const ValueKey<String>(
            'phase2_register_confirm_password_field',
          ),
          controller: _registerConfirmPasswordController,
          label: strings.confirmPasswordLabel,
          icon: Icons.lock_reset_rounded,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          obscureText: true,
          autofillHints: const <String>[AutofillHints.newPassword],
          onSubmitted: (_) => _completeRegistration(),
        ),
        const SizedBox(height: 16),
        _ProfileAuthPrimaryButton(
          key: const ValueKey<String>('phase2_create_account_button'),
          label: strings.createAccount,
          loading: _authenticating,
          onPressed: _authenticating ? null : _completeRegistration,
        ),
        const SizedBox(height: 12),
        _ProfileAuthTextLink(
          key: const ValueKey<String>('phase2_sign_in_link'),
          label: strings.alreadyHaveAccountSignIn,
          onPressed: _switchToSignIn,
        ),
      ],
    );
  }

  void _switchToSignIn() {
    if (_loginEmailController.text.trim().isEmpty) {
      _loginEmailController.text = _registerEmailController.text.trim();
    }
    setState(() => _mode = _ProfileAuthMode.signIn);
  }

  void _switchToRegister() {
    if (_registerEmailController.text.trim().isEmpty) {
      _registerEmailController.text = _loginEmailController.text.trim();
    }
    setState(() => _mode = _ProfileAuthMode.register);
  }

  Future<void> _signIn() async {
    final strings = context.stringsRead;
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;
    if (email.isEmpty) {
      _showMessage(strings.emailRequired);
      return;
    }
    if (password.isEmpty) {
      _showMessage(strings.passwordRequired);
      return;
    }
    setState(() => _authenticating = true);
    try {
      await widget.accountController.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _authenticating = false);
      }
    }
  }

  Future<void> _sendRegistrationCode() async {
    final strings = context.stringsRead;
    final email = _registerEmailController.text.trim();
    if (email.isEmpty) {
      _showMessage(strings.emailRequired);
      return;
    }
    setState(() => _sendingRegistrationCode = true);
    try {
      await widget.accountController.sendRegistrationOtp(email);
      _showMessage(strings.registrationCodeSent);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _sendingRegistrationCode = false);
      }
    }
  }

  Future<void> _completeRegistration() async {
    final strings = context.stringsRead;
    final email = _registerEmailController.text.trim();
    final code = _registerCodeController.text.trim();
    final password = _registerPasswordController.text;
    final confirmPassword = _registerConfirmPasswordController.text;
    if (email.isEmpty) {
      _showMessage(strings.emailRequired);
      return;
    }
    if (code.isEmpty) {
      _showMessage(strings.otpRequired);
      return;
    }
    if (password.isEmpty) {
      _showMessage(strings.passwordRequired);
      return;
    }
    if (password.length < 8) {
      _showMessage(strings.passwordTooShort);
      return;
    }
    if (password != confirmPassword) {
      _showMessage(strings.passwordMismatch);
      return;
    }
    setState(() => _authenticating = true);
    try {
      await widget.accountController.completeRegistration(
        email: email,
        token: code,
        password: password,
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _authenticating = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    final strings = context.stringsRead;
    final message = error is Phase2RepositoryException
        ? strings.phase2ErrorMessage(error.code)
        : strings.phase2ErrorMessage('auth_failed');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProfileSignInField extends StatelessWidget {
  const _ProfileSignInField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.icon,
    required this.keyboardType,
    required this.textInputAction,
    this.autofillHints,
    this.suffix,
    this.onSubmitted,
    this.obscureText = false,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fitTheme = context.fitLogTheme;
    final fieldTextStyle = textTheme.bodyLarge?.copyWith(
      color: fitTheme.textPrimary,
      fontWeight: FontWeight.w500,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(29),
      borderSide: BorderSide(color: fitTheme.outline),
    );
    return SizedBox(
      height: 58,
      child: TextField(
        key: fieldKey,
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onSubmitted: onSubmitted,
        obscureText: obscureText,
        enableSuggestions: !obscureText,
        autocorrect: !obscureText,
        scrollPadding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom + 80,
        ),
        style: fieldTextStyle,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: fieldTextStyle?.copyWith(color: fitTheme.mutedText),
          filled: true,
          fillColor: fitTheme.surface,
          prefixIcon: Icon(icon, color: fitTheme.mutedText),
          suffixIcon: suffix == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: suffix,
                ),
          suffixIconConstraints: const BoxConstraints(
            minHeight: 40,
            minWidth: 96,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.never,
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: fitTheme.primaryBright, width: 1.4),
          ),
        ),
      ),
    );
  }
}

class _ProfileAuthPrimaryButton extends StatelessWidget {
  const _ProfileAuthPrimaryButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fitTheme = context.fitLogTheme;
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: fitTheme.primaryBright,
          disabledBackgroundColor: fitTheme.primarySoftPressed,
          foregroundColor: fitTheme.onPrimary,
          disabledForegroundColor: fitTheme.disabledText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(29),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fitTheme.onPrimary,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class _ProfileAuthTextLink extends StatelessWidget {
  const _ProfileAuthTextLink({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF3D8D3A),
        textStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      child: Text(label),
    );
  }
}

class _AnimatedFitLogAgentLogo extends StatelessWidget {
  const _AnimatedFitLogAgentLogo({required this.animation, required this.size});

  static const String _assetName = 'assets/branding/fitlog_logo_base.png';

  final Animation<double> animation;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: Image.asset(
        _assetName,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      ),
      builder: (context, child) {
        return SizedBox.square(
          dimension: size,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                left: size * 0.02,
                top: size * 0.03,
                width: size * 0.78,
                height: size * 0.78,
                child: child!,
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _FitLogAgentSparklePainter(animation.value),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FitLogAgentSparklePainter extends CustomPainter {
  const _FitLogAgentSparklePainter(this.progress);

  static const List<_SparklePulse> _topMainPulses = <_SparklePulse>[
    _SparklePulse(0.90, 1.24, 1.70, 0.75),
    _SparklePulse(1.82, 2.16, 2.58),
    _SparklePulse(3.08, 3.42, 3.78, 0.76),
    _SparklePulse(5.02, 5.40, 5.86, 0.80),
  ];
  static const List<_SparklePulse> _leftMainPulses = <_SparklePulse>[
    _SparklePulse(0.62, 1.12, 1.82),
    _SparklePulse(2.74, 3.22, 3.86, 0.70),
    _SparklePulse(4.78, 5.30, 5.82, 0.88),
  ];
  static const List<_SparklePulse> _rightMainPulses = <_SparklePulse>[
    _SparklePulse(0.34, 0.88, 1.58),
    _SparklePulse(2.64, 3.14, 3.70, 0.92),
    _SparklePulse(4.62, 5.16, 5.74),
  ];
  static const List<_SparklePulse> _leftMiniPulses = <_SparklePulse>[
    _SparklePulse(0.42, 0.58, 0.82),
    _SparklePulse(2.92, 3.08, 3.28, 0.75),
    _SparklePulse(4.60, 4.78, 4.98, 0.85),
  ];
  static const List<_SparklePulse> _rightMiniPulses = <_SparklePulse>[
    _SparklePulse(0.54, 0.72, 0.96),
    _SparklePulse(3.18, 3.34, 3.58, 0.70),
    _SparklePulse(4.96, 5.12, 5.36, 0.90),
  ];

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 192;
    canvas.save();
    canvas.scale(scale);
    _paintSparkles(canvas);
    canvas.restore();
  }

  void _paintSparkles(Canvas canvas) {
    final seconds = progress * 6;
    _paintMainSparkle(
      canvas,
      center: const Offset(173, 20),
      radius: 9.8,
      baseScale: 0.78,
      peakScale: 1.08,
      baseOpacity: 0.42,
      pulse: _pulseGroup(seconds, _topMainPulses),
    );
    _paintMainSparkle(
      canvas,
      center: const Offset(151, 42),
      radius: 25.5,
      baseScale: 0.78,
      peakScale: 1.22,
      baseOpacity: 0.38,
      pulse: _pulseGroup(seconds, _leftMainPulses),
    );
    _paintMainSparkle(
      canvas,
      center: const Offset(176, 66),
      radius: 10.2,
      baseScale: 0.78,
      peakScale: 1.12,
      baseOpacity: 0.40,
      pulse: _pulseGroup(seconds, _rightMainPulses),
    );
    _paintMiniSparkle(
      canvas,
      center: const Offset(164, 29),
      radius: 4.2,
      pulse: _pulseGroup(seconds, _leftMiniPulses),
    );
    _paintMiniSparkle(
      canvas,
      center: const Offset(168, 55),
      radius: 4.0,
      pulse: _pulseGroup(seconds, _rightMiniPulses),
    );
  }

  void _paintMainSparkle(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double baseScale,
    required double peakScale,
    required double baseOpacity,
    required double pulse,
  }) {
    final path = _sparklePath(radius);
    final bounds = _sparkleBounds(radius);
    final scale = _lerp(baseScale, peakScale, pulse);
    final opacity = _lerp(baseOpacity, 1, pulse);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF22D9AF).withValues(alpha: opacity * 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.lerp(
              const Color(0xFF69DF58),
              Colors.white,
              pulse * 0.08,
            )!.withValues(alpha: opacity),
            Color.lerp(
              const Color(0xFF12C9D2),
              Colors.white,
              pulse * 0.04,
            )!.withValues(alpha: opacity),
          ],
        ).createShader(bounds),
    );
    canvas.restore();
  }

  void _paintMiniSparkle(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double pulse,
  }) {
    if (pulse <= 0) {
      return;
    }

    final path = _sparklePath(radius);
    final bounds = _sparkleBounds(radius);
    final scale = _lerp(0.40, 0.90, pulse);
    final opacity = math.min(0.90, pulse * 0.90);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF24D7BD).withValues(alpha: opacity * 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.lerp(
              const Color(0xFF76E65B),
              Colors.white,
              pulse * 0.12,
            )!.withValues(alpha: opacity),
            Color.lerp(
              const Color(0xFF12CBD7),
              Colors.white,
              pulse * 0.06,
            )!.withValues(alpha: opacity),
          ],
        ).createShader(bounds),
    );
    canvas.restore();
  }

  Path _sparklePath(double radius) {
    const halfSvgHeight = 448.0;
    final unit = radius / halfSvgHeight;
    double sx(double x) => (x - 512) * unit;
    double sy(double y) => (y - 512) * unit;
    final path = Path();
    path
      ..moveTo(sx(512), sy(64))
      ..cubicTo(sx(555), sy(64), sx(585), sy(184), sx(608), sy(262))
      ..cubicTo(sx(633), sy(347), sx(678), sy(386), sx(762), sy(410))
      ..cubicTo(sx(840), sy(433), sx(928), sy(466), sx(928), sy(512))
      ..cubicTo(sx(928), sy(558), sx(840), sy(591), sx(762), sy(614))
      ..cubicTo(sx(678), sy(638), sx(633), sy(677), sx(608), sy(762))
      ..cubicTo(sx(585), sy(840), sx(555), sy(960), sx(512), sy(960))
      ..cubicTo(sx(469), sy(960), sx(439), sy(840), sx(416), sy(762))
      ..cubicTo(sx(391), sy(677), sx(346), sy(638), sx(262), sy(614))
      ..cubicTo(sx(184), sy(591), sx(96), sy(558), sx(96), sy(512))
      ..cubicTo(sx(96), sy(466), sx(184), sy(433), sx(262), sy(410))
      ..cubicTo(sx(346), sy(386), sx(391), sy(347), sx(416), sy(262))
      ..cubicTo(sx(439), sy(184), sx(469), sy(64), sx(512), sy(64));
    return path..close();
  }

  Rect _sparkleBounds(double radius) {
    return Rect.fromLTRB(
      -radius * 416 / 448,
      -radius,
      radius * 416 / 448,
      radius,
    );
  }

  double _pulseGroup(double seconds, List<_SparklePulse> pulses) {
    var value = 0.0;
    for (final pulse in pulses) {
      value = math.max(value, _pulse(seconds, pulse) * pulse.strength);
    }
    return value.clamp(0.0, 1.0).toDouble();
  }

  double _pulse(double seconds, _SparklePulse pulse) {
    if (seconds <= pulse.start || seconds >= pulse.end) {
      return 0;
    }
    if (seconds <= pulse.peak) {
      return _interval(seconds, pulse.start, pulse.peak, Curves.easeInOutCubic);
    }
    return 1 - _interval(seconds, pulse.peak, pulse.end, Curves.easeInOutCubic);
  }

  double _lerp(double start, double end, double value) {
    return start + (end - start) * value;
  }

  double _interval(double value, double start, double end, Curve curve) {
    if (value <= start) {
      return 0;
    }
    if (value >= end) {
      return 1;
    }
    return curve.transform((value - start) / (end - start));
  }

  @override
  bool shouldRepaint(covariant _FitLogAgentSparklePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _SparklePulse {
  const _SparklePulse(this.start, this.peak, this.end, [this.strength = 1]);

  final double start;
  final double peak;
  final double end;
  final double strength;
}

class _CloudProfileSetupGate extends StatefulWidget {
  const _CloudProfileSetupGate({required this.accountController});

  final AccountController accountController;

  @override
  State<_CloudProfileSetupGate> createState() => _CloudProfileSetupGateState();
}

class _CloudProfileSetupGateState extends State<_CloudProfileSetupGate> {
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 120),
        children: <Widget>[
          FitLogPageHeader(
            title: strings.completeCloudProfile,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          Text(
            strings.cloudProfileMissingBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5B6858),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey<String>('phase2_create_cloud_profile_button'),
            onPressed: _creating ? null : _create,
            icon: _creating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_done_outlined),
            label: Text(strings.createDefaultCloudProfile),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      await widget.accountController.createDefaultCloudProfile();
    } catch (error) {
      if (mounted) {
        final strings = context.stringsRead;
        final message = error is Phase2RepositoryException
            ? strings.phase2ErrorMessage(error.code)
            : strings.phase2ErrorMessage('profile_save_failed');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }
}

class _ProfilePhase2ErrorGate extends StatelessWidget {
  const _ProfilePhase2ErrorGate({
    required this.message,
    required this.errorCode,
    required this.onRetry,
  });

  final String message;
  final String errorCode;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                '${context.strings.phase2ErrorCodeLabel}: $errorCode',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6C7668)),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onRetry,
                child: Text(context.strings.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Phase2NoticeBox extends StatelessWidget {
  const _Phase2NoticeBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0DCA8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF715310),
            height: 1.4,
          ),
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
    final fitTheme = context.fitLogTheme;
    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.flag_outlined, color: fitTheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.isChinese ? '当前计划' : 'Current Plan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: fitTheme.primaryDeep,
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
                    color: fitTheme.textPrimary,
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
            leading: Icon(
              Icons.fitness_center_rounded,
              color: fitTheme.primaryDeep,
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
              backgroundColor: fitTheme.primarySoft,
            ),
            text: '${strings.isChinese ? '策略' : 'Strategy'}: $strategyLabel',
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: fitTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: fitTheme.outline),
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
    final fitTheme = context.fitLogTheme;
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
          color: _pressed ? fitTheme.primarySoftPressed : fitTheme.primarySoft,
          shape: BoxShape.circle,
          boxShadow: _pressed
              ? <BoxShadow>[
                  BoxShadow(
                    color: fitTheme.shadow.withValues(alpha: 0.14),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : <BoxShadow>[],
        ),
        child: Icon(
          Icons.info_outline_rounded,
          size: 28,
          color: fitTheme.primaryDeep,
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
    this.modified = false,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final bool modified;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: fitTheme.primaryDeep, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: fitTheme.textPrimary,
                  ),
                ),
              ),
              if (modified) _ModifiedBadge(label: context.strings.modified),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SubscriptionRedeemSheet extends StatefulWidget {
  const _SubscriptionRedeemSheet({
    required this.accountController,
    required this.onRedeemed,
  });

  final AccountController accountController;
  final VoidCallback onRedeemed;

  @override
  State<_SubscriptionRedeemSheet> createState() =>
      _SubscriptionRedeemSheetState();
}

class _SubscriptionRedeemSheetState extends State<_SubscriptionRedeemSheet> {
  final _codeController = TextEditingController();
  bool _redeeming = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final strings = context.stringsRead;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.redeemCodeRequired)));
      return;
    }
    setState(() => _redeeming = true);
    try {
      await widget.accountController.redeemSubscriptionCode(code);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      widget.onRedeemed();
    } catch (error) {
      if (mounted) {
        final message = error is Phase2RepositoryException
            ? strings.phase2ErrorMessage(error.code)
            : strings.phase2ErrorMessage('redeem_failed');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() => _redeeming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final fitTheme = context.fitLogTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            strings.redeemCodeTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: fitTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey<String>('subscription_redeem_code_field'),
            controller: _codeController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (_) => _redeeming ? null : _redeem(),
            decoration: InputDecoration(
              labelText: strings.redeemCodeLabel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey<String>('subscription_redeem_submit_button'),
            onPressed: _redeeming ? null : _redeem,
            style: FilledButton.styleFrom(
              backgroundColor: fitTheme.primary,
              foregroundColor: fitTheme.onPrimary,
              minimumSize: const Size.fromHeight(48),
            ),
            child: _redeeming
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(strings.redeemCodeAction),
          ),
        ],
      ),
    );
  }
}

class _ProfileSubscriptionEntryButton extends StatelessWidget {
  const _ProfileSubscriptionEntryButton({
    required this.accountController,
    required this.onPressed,
  });

  final AccountController accountController;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final subscription = accountController.subscriptionStatus;
    final fitTheme = context.fitLogTheme;
    final baseColor = switch (subscription.state) {
      SubscriptionState.active => fitTheme.primaryDeep,
      SubscriptionState.error => fitTheme.warningText,
      SubscriptionState.loading => fitTheme.mutedText,
      SubscriptionState.unknown ||
      SubscriptionState.inactive => fitTheme.mutedText,
    };
    final baseBackground = switch (subscription.state) {
      SubscriptionState.active => fitTheme.primarySoft,
      SubscriptionState.error => fitTheme.warningSurface,
      SubscriptionState.loading => fitTheme.surfaceVariant,
      SubscriptionState.unknown ||
      SubscriptionState.inactive => fitTheme.surfaceVariant,
    };
    final badgeIcon = switch (subscription.state) {
      SubscriptionState.active => Icons.check_rounded,
      SubscriptionState.error => Icons.priority_high_rounded,
      SubscriptionState.loading => Icons.more_horiz_rounded,
      SubscriptionState.unknown ||
      SubscriptionState.inactive => Icons.remove_rounded,
    };

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        IconButton.filledTonal(
          key: const ValueKey<String>('subscription_entry_button'),
          tooltip: context.strings.subscriptionTitle,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: baseBackground,
            foregroundColor: baseColor,
            minimumSize: const Size.square(46),
          ),
          icon: const Icon(Icons.workspace_premium_outlined),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: baseColor,
              shape: BoxShape.circle,
              border: Border.all(color: fitTheme.surface, width: 2),
            ),
            child: Icon(badgeIcon, size: 12, color: fitTheme.onPrimary),
          ),
        ),
      ],
    );
  }
}

class _ProfileSubscriptionDialog extends StatelessWidget {
  const _ProfileSubscriptionDialog({
    required this.accountController,
    required this.refreshing,
    required this.onRefresh,
    required this.onRedeem,
    required this.onClose,
  });

  final AccountController accountController;
  final bool refreshing;
  final VoidCallback onRefresh;
  final VoidCallback onRedeem;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final fitTheme = context.fitLogTheme;
    return Material(
      color: Colors.transparent,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: ColoredBox(
          color: fitTheme.shadow.withValues(alpha: 0.22),
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  18 + mediaQuery.viewInsets.bottom,
                ),
                child: AnimatedBuilder(
                  animation: accountController,
                  builder: (context, _) {
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: _ProfileSubscriptionCard(
                        accountController: accountController,
                        refreshing: refreshing,
                        onRefresh: onRefresh,
                        onRedeem: onRedeem,
                        onClose: onClose,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSubscriptionCard extends StatelessWidget {
  const _ProfileSubscriptionCard({
    required this.accountController,
    required this.refreshing,
    required this.onRefresh,
    required this.onRedeem,
    required this.onClose,
  });

  final AccountController accountController;
  final bool refreshing;
  final VoidCallback onRefresh;
  final VoidCallback onRedeem;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final subscription = accountController.subscriptionStatus;
    final statusColor = _statusColor(context, subscription.state);
    final statusText = _statusText(strings, subscription.state);

    final theme = Theme.of(context);
    final fitTheme = context.fitLogTheme;
    return DecoratedBox(
      key: const ValueKey<String>('subscription_compact_dialog_card'),
      decoration: BoxDecoration(
        color: fitTheme.surfaceElevated.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: fitTheme.outline),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: fitTheme.shadow.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: fitTheme.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.workspace_premium_outlined,
                    color: fitTheme.primaryDeep,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    strings.subscriptionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: fitTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                  color: fitTheme.mutedText,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SubscriptionInfoLine(
              label: strings.emailLabel,
              value: accountController.authSession.email ?? '-',
            ),
            _SubscriptionInfoLine(
              label: strings.subscriptionStatusLabel,
              value: statusText,
              valueColor: statusColor,
            ),
            _SubscriptionInfoLine(
              label: strings.subscriptionPlanLabel,
              value: subscription.planId ?? '-',
            ),
            _SubscriptionInfoLine(
              label: strings.subscriptionEndLabel,
              value: _formatDate(subscription.currentPeriodEnd),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey<String>('subscription_refresh_button'),
                    onPressed: refreshing ? null : onRefresh,
                    icon: refreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                      strings.refreshSubscription,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey<String>('subscription_redeem_button'),
                    onPressed: onRedeem,
                    style: FilledButton.styleFrom(
                      backgroundColor: fitTheme.primary,
                      foregroundColor: fitTheme.onPrimary,
                    ),
                    icon: const Icon(Icons.card_giftcard_rounded),
                    label: Text(
                      strings.redeemCodeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context, SubscriptionState state) {
    switch (state) {
      case SubscriptionState.active:
        return context.fitLogTheme.primaryDeep;
      case SubscriptionState.error:
        return context.fitLogTheme.warningText;
      case SubscriptionState.loading:
        return context.fitLogTheme.mutedText;
      case SubscriptionState.unknown:
      case SubscriptionState.inactive:
        return context.fitLogTheme.mutedText;
    }
  }

  String _statusText(AppStrings strings, SubscriptionState state) {
    switch (state) {
      case SubscriptionState.active:
        return strings.subscriptionActiveShort;
      case SubscriptionState.loading:
        return strings.loading;
      case SubscriptionState.error:
        return strings.subscriptionUnavailableShort;
      case SubscriptionState.unknown:
      case SubscriptionState.inactive:
        return strings.subscriptionInactiveShort;
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

class _SubscriptionInfoLine extends StatelessWidget {
  const _SubscriptionInfoLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fitTheme = context.fitLogTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: fitTheme.mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: valueColor ?? fitTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModifiedBadge extends StatelessWidget {
  const _ModifiedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fitTheme.modifiedSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fitTheme.modifiedBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: fitTheme.modifiedText,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fitTheme.modifiedText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDraftSaveBar extends StatelessWidget {
  const _ProfileDraftSaveBar({
    required this.changes,
    required this.expanded,
    required this.saving,
    required this.onToggleExpanded,
    required this.onDiscard,
    required this.onSave,
  });

  final List<_ProfileDraftChangeGroup> changes;
  final bool expanded;
  final bool saving;
  final VoidCallback onToggleExpanded;
  final VoidCallback onDiscard;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final fitTheme = context.fitLogTheme;

    return Material(
      key: const ValueKey<String>('profile_draft_save_bar'),
      color: Colors.transparent,
      elevation: 10,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: fitTheme.surfaceElevated.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: fitTheme.outline),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: fitTheme.shadow.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            InkWell(
              key: const ValueKey<String>('profile_draft_changes_toggle'),
              borderRadius: BorderRadius.circular(16),
              onTap: onToggleExpanded,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: <Widget>[
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      color: fitTheme.primaryDeep,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        strings.profileUnsavedCount(
                          changes.fold<int>(
                            0,
                            (total, group) => total + group.fields.length,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: fitTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 108),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: changes
                          .map(
                            (group) => Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${group.title}: ${_summarizeFields(context, group.fields)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: fitTheme.textSecondary,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 160),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton(
                    key: const ValueKey<String>('profile_draft_discard_button'),
                    onPressed: saving ? null : onDiscard,
                    child: Text(strings.discardChanges),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey<String>('profile_draft_save_button'),
                    onPressed: saving ? null : onSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: fitTheme.primary,
                      foregroundColor: fitTheme.onPrimary,
                      minimumSize: const Size.fromHeight(38),
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            strings.saveProfileChanges,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _summarizeFields(BuildContext context, List<String> fields) {
    const visibleCount = 3;
    if (fields.length <= visibleCount) {
      return fields.join(context.strings.isChinese ? '、' : ', ');
    }
    final visible = fields
        .take(visibleCount)
        .join(context.strings.isChinese ? '、' : ', ');
    final hiddenCount = fields.length - visibleCount;
    return context.strings.isChinese
        ? '$visible 等 ${fields.length} 项'
        : '$visible +$hiddenCount';
  }
}

class _BodyTrendCard extends StatelessWidget {
  const _BodyTrendCard({
    required this.logs,
    required this.metric,
    required this.rangeDays,
    required this.selectedDate,
    required this.onMetricChanged,
    required this.onRangeChanged,
    required this.onPointSelected,
  });

  final List<WeightLog> logs;
  final _BodyTrendMetric metric;
  final int rangeDays;
  final String? selectedDate;
  final ValueChanged<_BodyTrendMetric> onMetricChanged;
  final ValueChanged<int> onRangeChanged;
  final ValueChanged<String> onPointSelected;

  static const List<int> _rangeOptions = <int>[7, 14, 21, 28];

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final points = _pointsForRange();
    final change = points.length >= 2
        ? points.last.value - points.first.value
        : null;
    final selectedPoint = _selectedPoint(points);
    final unit = _unitForMetric(metric);
    final fitTheme = context.fitLogTheme;

    return _ProfileSummarySectionCard(
      title: strings.bodyTrendsTitle,
      icon: Icons.show_chart_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  change == null
                      ? '${strings.bodyTrendChangeLabel(rangeDays)} --'
                      : '${strings.bodyTrendChangeLabel(rangeDays)} ${_formatChange(change)} $unit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: fitTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                strings.bodyTrendLogCount(points.length, rangeDays),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: fitTheme.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _BodyTrendChart(
            points: points,
            metric: metric,
            rangeDays: rangeDays,
            selectedPoint: selectedPoint,
            insufficientMessage: _insufficientMessage(strings, points.length),
            onPointSelected: onPointSelected,
          ),
          const SizedBox(height: 14),
          Row(
            children: _BodyTrendMetric.values.map((value) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: value == _BodyTrendMetric.values.last ? 0 : 8,
                  ),
                  child: _SelectablePill(
                    label: _labelForMetric(strings, value),
                    selected: metric == value,
                    compact: true,
                    onTap: () => onMetricChanged(value),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: _rangeOptions.map((days) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: days == _rangeOptions.last ? 0 : 8,
                  ),
                  child: _SelectablePill(
                    label: strings.bodyTrendRangeLabel(days),
                    selected: rangeDays == days,
                    compact: true,
                    onTap: () => onRangeChanged(days),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<_BodyTrendPoint> _pointsForRange() {
    final end = DateUtilsX.parseDay(DateUtilsX.todayKey());
    final start = end.subtract(Duration(days: rangeDays - 1));
    final points = <_BodyTrendPoint>[];
    for (final log in logs) {
      final date = DateUtilsX.parseDay(log.date);
      if (date.isBefore(start) || date.isAfter(end)) {
        continue;
      }
      final value = _valueForMetric(log);
      if (value == null || value <= 0) {
        continue;
      }
      points.add(_BodyTrendPoint(date: log.date, value: value));
    }
    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  _BodyTrendPoint? _selectedPoint(List<_BodyTrendPoint> points) {
    if (points.isEmpty) {
      return null;
    }
    if (selectedDate == null) {
      return points.last;
    }
    for (final point in points) {
      if (point.date == selectedDate) {
        return point;
      }
    }
    return points.last;
  }

  String _insufficientMessage(AppStrings strings, int pointCount) {
    if (pointCount == 0) {
      return strings.bodyTrendNoRecords;
    }
    if (pointCount == 1) {
      return strings.bodyTrendNeedTwoRecords;
    }
    return strings.bodyTrendNotEnoughRecords;
  }

  double? _valueForMetric(WeightLog log) {
    switch (metric) {
      case _BodyTrendMetric.weight:
        return log.weightKg;
      case _BodyTrendMetric.bodyFat:
        return log.bodyFatPercent;
      case _BodyTrendMetric.waist:
        return log.waistCm;
    }
  }

  String _labelForMetric(AppStrings strings, _BodyTrendMetric value) {
    switch (value) {
      case _BodyTrendMetric.weight:
        return strings.bodyTrendWeightLabel;
      case _BodyTrendMetric.bodyFat:
        return strings.bodyTrendFatLabel;
      case _BodyTrendMetric.waist:
        return strings.bodyTrendWaistLabel;
    }
  }

  String _unitForMetric(_BodyTrendMetric value) {
    switch (value) {
      case _BodyTrendMetric.weight:
        return 'kg';
      case _BodyTrendMetric.bodyFat:
        return '%';
      case _BodyTrendMetric.waist:
        return 'cm';
    }
  }

  String _formatChange(double value) {
    if (value > 0) {
      return '+${value.toStringAsFixed(1)}';
    }
    return value.toStringAsFixed(1);
  }
}

class _BodyTrendPoint {
  const _BodyTrendPoint({required this.date, required this.value});

  final String date;
  final double value;
}

class _BodyTrendChart extends StatelessWidget {
  const _BodyTrendChart({
    required this.points,
    required this.metric,
    required this.rangeDays,
    required this.selectedPoint,
    required this.insufficientMessage,
    required this.onPointSelected,
  });

  final List<_BodyTrendPoint> points;
  final _BodyTrendMetric metric;
  final int rangeDays;
  final _BodyTrendPoint? selectedPoint;
  final String insufficientMessage;
  final ValueChanged<String> onPointSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fitTheme = context.fitLogTheme;
    return Container(
      height: 224,
      width: double.infinity,
      decoration: BoxDecoration(
        color: fitTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fitTheme.outline),
      ),
      child: points.length < 2
          ? Center(
              child: Text(
                insufficientMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fitTheme.mutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final nearest = _nearestPoint(details.localPosition, size);
                    if (nearest != null) {
                      onPointSelected(nearest.date);
                    }
                  },
                  child: Stack(
                    children: <Widget>[
                      CustomPaint(
                        size: size,
                        painter: _BodyTrendChartPainter(
                          points: points,
                          rangeDays: rangeDays,
                          selectedDate: selectedPoint?.date,
                          lineColor: _lineColor(context, metric),
                          gridColor: fitTheme.outlineSubtle,
                          selectedColor: fitTheme.textPrimary,
                        ),
                      ),
                      if (selectedPoint != null)
                        Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: fitTheme.surfaceElevated.withValues(
                                  alpha: 0.9,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: fitTheme.outline),
                              ),
                              child: Text(
                                '${_compactDate(selectedPoint!.date)} · ${selectedPoint!.value.toStringAsFixed(1)} ${_unitForMetric(metric)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: fitTheme.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  _BodyTrendPoint? _nearestPoint(Offset tapPosition, Size size) {
    _BodyTrendPoint? nearest;
    var nearestDistance = double.infinity;
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final position = _positionForPointAt(index, size);
      final distance = (position - tapPosition).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = point;
      }
    }
    return nearestDistance <= 28 ? nearest : null;
  }

  Offset _positionForPointAt(int index, Size size) {
    const left = 18.0;
    const right = 18.0;
    const top = 34.0;
    const bottom = 22.0;
    final chartWidth = math.max(1.0, size.width - left - right);
    final chartHeight = math.max(1.0, size.height - top - bottom);
    final point = points[index];
    final firstDate = DateUtilsX.parseDay(points.first.date);
    final currentDate = DateUtilsX.parseDay(point.date);
    final rangeSpanDays = math.max(1, rangeDays - 1);
    final dayOffset = currentDate.difference(firstDate).inDays;
    final clampedDayOffset = dayOffset.clamp(0, rangeSpanDays).toDouble();
    final x = left + chartWidth * (clampedDayOffset / rangeSpanDays);
    final minValue = points.map((p) => p.value).reduce(math.min);
    final maxValue = points.map((p) => p.value).reduce(math.max);
    final span = math.max(0.1, maxValue - minValue);
    final y = top + chartHeight * (1 - ((point.value - minValue) / span));
    return Offset(x, y);
  }

  Color _lineColor(BuildContext context, _BodyTrendMetric value) {
    final fitTheme = context.fitLogTheme;
    switch (value) {
      case _BodyTrendMetric.weight:
        return fitTheme.primary;
      case _BodyTrendMetric.bodyFat:
        return fitTheme.isDark
            ? const Color(0xFFFFB066)
            : const Color(0xFFE0A12F);
      case _BodyTrendMetric.waist:
        return fitTheme.isDark
            ? const Color(0xFF62D3DC)
            : const Color(0xFF32A6B2);
    }
  }

  String _unitForMetric(_BodyTrendMetric value) {
    switch (value) {
      case _BodyTrendMetric.weight:
        return 'kg';
      case _BodyTrendMetric.bodyFat:
        return '%';
      case _BodyTrendMetric.waist:
        return 'cm';
    }
  }

  String _compactDate(String value) {
    final date = DateUtilsX.parseDay(value);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month-$day';
  }
}

class _BodyTrendChartPainter extends CustomPainter {
  const _BodyTrendChartPainter({
    required this.points,
    required this.rangeDays,
    required this.selectedDate,
    required this.lineColor,
    required this.gridColor,
    required this.selectedColor,
  });

  final List<_BodyTrendPoint> points;
  final int rangeDays;
  final String? selectedDate;
  final Color lineColor;
  final Color gridColor;
  final Color selectedColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 18.0;
    const right = 18.0;
    const top = 34.0;
    const bottom = 22.0;
    final chartHeight = math.max(1.0, size.height - top - bottom);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final ratio in <double>[0, 0.5, 1]) {
      final y = top + chartHeight * ratio;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
    }

    final positions = <Offset>[
      for (var index = 0; index < points.length; index++)
        _positionForPointAt(index, size),
    ];
    final path = Path()..moveTo(positions.first.dx, positions.first.dy);
    for (final position in positions.skip(1)) {
      path.lineTo(position.dx, position.dy);
    }
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = lineColor;
    final selectedPaint = Paint()..color = selectedColor;
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final position = positions[index];
      final selected = point.date == selectedDate;
      canvas.drawCircle(
        position,
        selected ? 5.2 : 3.2,
        selected ? selectedPaint : dotPaint,
      );
      if (selected) {
        final haloPaint = Paint()
          ..color = lineColor.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(position, 10, haloPaint);
      }
    }
  }

  Offset _positionForPointAt(int index, Size size) {
    const left = 18.0;
    const right = 18.0;
    const top = 34.0;
    const bottom = 22.0;
    final chartWidth = math.max(1.0, size.width - left - right);
    final chartHeight = math.max(1.0, size.height - top - bottom);
    final point = points[index];
    final firstDate = DateUtilsX.parseDay(points.first.date);
    final currentDate = DateUtilsX.parseDay(point.date);
    final rangeSpanDays = math.max(1, rangeDays - 1);
    final dayOffset = currentDate.difference(firstDate).inDays;
    final clampedDayOffset = dayOffset.clamp(0, rangeSpanDays).toDouble();
    final x = left + chartWidth * (clampedDayOffset / rangeSpanDays);
    final minValue = points.map((p) => p.value).reduce(math.min);
    final maxValue = points.map((p) => p.value).reduce(math.max);
    final span = math.max(0.1, maxValue - minValue);
    final y = top + chartHeight * (1 - ((point.value - minValue) / span));
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant _BodyTrendChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.rangeDays != rangeDays ||
        oldDelegate.selectedDate != selectedDate ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.selectedColor != selectedColor;
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
    final fitTheme = context.fitLogTheme;
    final tile = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: fitTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: fitTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: fitTheme.primaryDeep, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: fitTheme.mutedText,
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
    final fitTheme = context.fitLogTheme;
    final valueStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: fitTheme.textPrimary,
    );
    final unitStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: fitTheme.textSecondary,
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
    final fitTheme = context.fitLogTheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      autofocus: autofocus,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: fitTheme.textPrimary,
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
    final fitTheme = context.fitLogTheme;
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
              color: fitTheme.textPrimary,
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
              color: fitTheme.textSecondary,
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
    final fitTheme = context.fitLogTheme;
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
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(saveLabel),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: fitTheme.primary,
              foregroundColor: fitTheme.onPrimary,
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
    final fitTheme = context.fitLogTheme;
    return FilledButton(
      onPressed: saving ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(58, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: fitTheme.primary,
        foregroundColor: fitTheme.onPrimary,
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
    final fitTheme = context.fitLogTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: fitTheme.textPrimary,
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
    final fitTheme = context.fitLogTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: fitTheme.textSecondary,
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
    super.key,
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
    final fitTheme = context.fitLogTheme;
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
          color: selected ? fitTheme.primarySoftSelected : fitTheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? fitTheme.primaryBright
                : disabled
                ? fitTheme.outlineSubtle
                : fitTheme.outline,
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
                  ? fitTheme.disabledText
                  : selected
                  ? fitTheme.primaryDeep
                  : fitTheme.textPrimary,
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
    final fitTheme = context.fitLogTheme;
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
            color: fitTheme.primaryDeep,
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
    final fitTheme = context.fitLogTheme;
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
              color: fitTheme.textPrimary,
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
    final fitTheme = context.fitLogTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fitTheme.primaryBright),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: fitTheme.primaryDeep,
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
    final fitTheme = context.fitLogTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: fitTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: fitTheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: fitTheme.textPrimary,
              ),
            ),
            if ((subtitle ?? '').trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: fitTheme.mutedText),
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
    final fitTheme = context.fitLogTheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: fitTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fitTheme.outline),
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
            decoration: BoxDecoration(color: fitTheme.surfaceVariant),
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
    final fitTheme = context.fitLogTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: fitTheme.outline),
          bottom: BorderSide(color: fitTheme.outline),
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
                  color: fitTheme.isDark ? Colors.white : fitTheme.textPrimary,
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
    final fitTheme = context.fitLogTheme;
    final iconSize = assetName == FitLogIconAssets.macroCarbs ? 30.0 : 24.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _SmallAssetBadge(
          assetName: assetName,
          iconSize: iconSize,
          backgroundColor: fitTheme.primarySoft,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: fitTheme.mutedText,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: fitTheme.textPrimary,
            ),
            children: <InlineSpan>[
              TextSpan(text: value),
              TextSpan(
                text: ' g',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: fitTheme.textSecondary,
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
      color: context.fitLogTheme.outline,
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
