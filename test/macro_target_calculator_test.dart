import 'package:fitlog_local/core/constants/app_constants.dart';
import 'package:fitlog_local/domain/models/user_profile.dart';
import 'package:fitlog_local/domain/services/daily_summary_service.dart';
import 'package:fitlog_local/domain/services/macro_target_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = MacroTargetCalculator();

  group('MacroTargetCalculator.calculateByGramPerKg', () {
    test('cutting male 80kg 2 sessions uses cutting table', () {
      final targets = calculator.calculateByGramPerKg(
        profile: _profile(
          dietGoalPhase: AppConstants.dietGoalPhaseCutting,
          sexForFormula: 'male',
          trainingFrequencyPerWeek: 2,
        ),
      );

      expect(targets.proteinTargetG, closeTo(112, 0.001));
      expect(targets.carbsTargetG, closeTo(120, 0.001));
      expect(targets.fatTargetG, closeTo(64, 0.001));
    });

    test('cutting female 80kg 5 sessions uses cutting table', () {
      final targets = calculator.calculateByGramPerKg(
        profile: _profile(
          dietGoalPhase: AppConstants.dietGoalPhaseCutting,
          sexForFormula: 'female',
          trainingFrequencyPerWeek: 5,
        ),
      );

      expect(targets.proteinTargetG, closeTo(144, 0.001));
      expect(targets.carbsTargetG, closeTo(152, 0.001));
      expect(targets.fatTargetG, closeTo(96, 0.001));
    });

    test('bulking male 80kg 2 sessions uses bulking table', () {
      final targets = calculator.calculateByGramPerKg(
        profile: _profile(
          dietGoalPhase: AppConstants.dietGoalPhaseBulking,
          sexForFormula: 'male',
          trainingFrequencyPerWeek: 2,
        ),
      );

      expect(targets.proteinTargetG, closeTo(128, 0.001));
      expect(targets.carbsTargetG, closeTo(240, 0.001));
      expect(targets.fatTargetG, closeTo(64, 0.001));
    });

    test('bulking male 80kg 5 sessions uses bulking table', () {
      final targets = calculator.calculateByGramPerKg(
        profile: _profile(
          dietGoalPhase: AppConstants.dietGoalPhaseBulking,
          sexForFormula: 'male',
          trainingFrequencyPerWeek: 5,
        ),
      );

      expect(targets.proteinTargetG, closeTo(160, 0.001));
      expect(targets.carbsTargetG, closeTo(336, 0.001));
      expect(targets.fatTargetG, closeTo(80, 0.001));
    });

    test('bulking female 80kg 2 sessions uses bulking table', () {
      final targets = calculator.calculateByGramPerKg(
        profile: _profile(
          dietGoalPhase: AppConstants.dietGoalPhaseBulking,
          sexForFormula: 'female',
          trainingFrequencyPerWeek: 2,
        ),
      );

      expect(targets.proteinTargetG, closeTo(128, 0.001));
      expect(targets.carbsTargetG, closeTo(224, 0.001));
      expect(targets.fatTargetG, closeTo(72, 0.001));
    });

    test('bulking female 80kg 5 sessions uses bulking table', () {
      final targets = calculator.calculateByGramPerKg(
        profile: _profile(
          dietGoalPhase: AppConstants.dietGoalPhaseBulking,
          sexForFormula: 'female',
          trainingFrequencyPerWeek: 5,
        ),
      );

      expect(targets.proteinTargetG, closeTo(160, 0.001));
      expect(targets.carbsTargetG, closeTo(304, 0.001));
      expect(targets.fatTargetG, closeTo(88, 0.001));
    });

    test('bulking prefer_not_to_say averages male and female coefficients', () {
      final targets = calculator.calculateByGramPerKg(
        profile: _profile(
          dietGoalPhase: AppConstants.dietGoalPhaseBulking,
          sexForFormula: 'prefer_not_to_say',
          trainingFrequencyPerWeek: 5,
        ),
      );

      expect(targets.proteinTargetG, closeTo(160, 0.001));
      expect(targets.carbsTargetG, closeTo(320, 0.001));
      expect(targets.fatTargetG, closeTo(84, 0.001));
      expect(targets.macroEnergyEquivalentKcal, closeTo(2676, 0.001));
    });
  });

  group('MacroTargetCalculator.calculateByEnergyRatio', () {
    test('still converts target intake kcal by macro ratios', () {
      final targets = calculator.calculateByEnergyRatio(
        profile: _profile(
          proteinRatioPercent: 30,
          carbsRatioPercent: 40,
          fatRatioPercent: 30,
        ),
        targetIntakeKcal: 2000,
      );

      expect(targets.proteinTargetG, closeTo(150, 0.001));
      expect(targets.carbsTargetG, closeTo(200, 0.001));
      expect(targets.fatTargetG, closeTo(2000 * 0.3 / 9, 0.001));
      expect(targets.macroEnergyEquivalentKcal, closeTo(2000, 0.001));
    });

    test(
      'ignores training frequency when target intake and ratios are same',
      () {
        final lowFrequencyTargets = calculator.calculateByEnergyRatio(
          profile: _profile(
            dietCalculationMode: AppConstants.dietCalculationModeEnergyRatio,
            trainingFrequencyPerWeek: 2,
            proteinRatioPercent: 25,
            carbsRatioPercent: 50,
            fatRatioPercent: 25,
          ),
          targetIntakeKcal: 2600,
        );
        final highFrequencyTargets = calculator.calculateByEnergyRatio(
          profile: _profile(
            dietCalculationMode: AppConstants.dietCalculationModeEnergyRatio,
            trainingFrequencyPerWeek: 5,
            proteinRatioPercent: 25,
            carbsRatioPercent: 50,
            fatRatioPercent: 25,
          ),
          targetIntakeKcal: 2600,
        );

        expect(
          lowFrequencyTargets.proteinTargetG,
          closeTo(highFrequencyTargets.proteinTargetG, 0.001),
        );
        expect(
          lowFrequencyTargets.carbsTargetG,
          closeTo(highFrequencyTargets.carbsTargetG, 0.001),
        );
        expect(
          lowFrequencyTargets.fatTargetG,
          closeTo(highFrequencyTargets.fatTargetG, 0.001),
        );
      },
    );
  });

  group('MacroTargetCalculator isolation', () {
    test('g/kg ignores activity level and daily energy goal kcal', () {
      final sedentaryTargets = calculator.calculateByGramPerKg(
        profile: _profile(
          sexForFormula: 'male',
          trainingFrequencyPerWeek: 3,
          activityLevel: 'sedentary',
          dailyEnergyGoalKcal: 200,
        ),
      );
      final veryActiveTargets = calculator.calculateByGramPerKg(
        profile: _profile(
          sexForFormula: 'male',
          trainingFrequencyPerWeek: 3,
          activityLevel: 'very_active',
          dailyEnergyGoalKcal: 900,
        ),
      );

      expect(
        sedentaryTargets.proteinTargetG,
        closeTo(veryActiveTargets.proteinTargetG, 0.001),
      );
      expect(
        sedentaryTargets.carbsTargetG,
        closeTo(veryActiveTargets.carbsTargetG, 0.001),
      );
      expect(
        sedentaryTargets.fatTargetG,
        closeTo(veryActiveTargets.fatTargetG, 0.001),
      );
    });
  });

  group('DailySummaryService phase target direction', () {
    test('cutting energy ratio subtracts daily goal kcal', () {
      final target = DailySummaryService.resolveNoExerciseTargetIntake(
        baselineNoExerciseTdee: 2200,
        profile: _profile(
          dietGoalPhase: AppConstants.dietGoalPhaseCutting,
          dietCalculationMode: AppConstants.dietCalculationModeEnergyRatio,
          dailyEnergyGoalKcal: 500,
        ),
      );

      expect(target, closeTo(1700, 0.001));
    });

    test('bulking energy ratio adds daily goal kcal', () {
      final target = DailySummaryService.resolveNoExerciseTargetIntake(
        baselineNoExerciseTdee: 2200,
        profile: _profile(
          dietGoalPhase: AppConstants.dietGoalPhaseBulking,
          dietCalculationMode: AppConstants.dietCalculationModeEnergyRatio,
          dailyEnergyGoalKcal: 500,
        ),
      );

      expect(target, closeTo(2700, 0.001));
    });

    test('logged net exercise kcal is added back to target intake', () {
      final targetIntake = DailySummaryService.resolveEnergyTargetIntake(
        noExerciseTargetIntake: 2100,
        loggedNetExerciseKcal: 320,
      );

      expect(targetIntake, closeTo(2420, 0.001));
    });
  });
}

UserProfile _profile({
  String dietGoalPhase = AppConstants.dietGoalPhaseCutting,
  String sexForFormula = 'male',
  String activityLevel = 'very_active',
  int trainingFrequencyPerWeek = AppConstants.defaultTrainingFrequencyPerWeek,
  String dietCalculationMode = AppConstants.dietCalculationModeGramPerKg,
  double dailyEnergyGoalKcal = 700,
  double proteinRatioPercent = AppConstants.defaultProteinRatioPercent,
  double carbsRatioPercent = AppConstants.defaultCarbsRatioPercent,
  double fatRatioPercent = AppConstants.defaultFatRatioPercent,
}) {
  return UserProfile(
    age: 30,
    heightCm: 175,
    weightKg: 80,
    sexForFormula: sexForFormula,
    activityLevel: activityLevel,
    dailyEnergyGoalType: 'deficit',
    dailyEnergyGoalKcal: dailyEnergyGoalKcal,
    proteinRatioPercent: proteinRatioPercent,
    carbsRatioPercent: carbsRatioPercent,
    fatRatioPercent: fatRatioPercent,
    dietGoalPhase: dietGoalPhase,
    dietCalculationMode: dietCalculationMode,
    dietPlanStrategy: AppConstants.defaultDietPlanStrategy,
    carbCycleHighMultiplier: AppConstants.defaultCarbCycleHighMultiplier,
    carbCycleMediumMultiplier: AppConstants.defaultCarbCycleMediumMultiplier,
    carbCycleLowMultiplier: AppConstants.defaultCarbCycleLowMultiplier,
    carbTaperReviewPeriodDays: AppConstants.defaultCarbTaperReviewPeriodDays,
    carbTaperTargetLossPctPerWeek:
        AppConstants.defaultCarbTaperTargetLossPctPerWeek,
    carbTaperStepG: AppConstants.defaultCarbTaperStepG,
    carbTaperCurrentDeltaG: AppConstants.defaultCarbTaperCurrentDeltaG,
    trainingFrequencyPerWeek: trainingFrequencyPerWeek,
    macroSelfCheckPeriodDays: AppConstants.defaultMacroSelfCheckPeriodDays,
    macroSelfCheckEnabled: true,
  );
}
