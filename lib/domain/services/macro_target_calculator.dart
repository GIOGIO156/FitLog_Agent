import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../models/user_profile.dart';

class MacroTargetCalculator {
  const MacroTargetCalculator();

  static const double _proteinCaloriesPerGram = 4;
  static const double _carbsCaloriesPerGram = 4;
  static const double _fatCaloriesPerGram = 9;

  static const Map<int, _GramPerKgMacroCoefficient> _maleCuttingGramPerKgTable =
      <int, _GramPerKgMacroCoefficient>{
        2: _GramPerKgMacroCoefficient(carbs: 1.5, protein: 1.4, fat: 0.8),
        3: _GramPerKgMacroCoefficient(carbs: 1.8, protein: 1.6, fat: 0.8),
        4: _GramPerKgMacroCoefficient(carbs: 2.0, protein: 1.7, fat: 0.9),
        5: _GramPerKgMacroCoefficient(carbs: 2.2, protein: 1.8, fat: 1.0),
      };

  static const Map<int, _GramPerKgMacroCoefficient>
  _femaleCuttingGramPerKgTable = <int, _GramPerKgMacroCoefficient>{
    2: _GramPerKgMacroCoefficient(carbs: 1.4, protein: 1.4, fat: 1.0),
    3: _GramPerKgMacroCoefficient(carbs: 1.6, protein: 1.6, fat: 1.0),
    4: _GramPerKgMacroCoefficient(carbs: 1.7, protein: 1.7, fat: 1.1),
    5: _GramPerKgMacroCoefficient(carbs: 1.9, protein: 1.8, fat: 1.2),
  };

  static const Map<int, _GramPerKgMacroCoefficient> _maleBulkingGramPerKgTable =
      <int, _GramPerKgMacroCoefficient>{
        2: _GramPerKgMacroCoefficient(carbs: 3.0, protein: 1.6, fat: 0.8),
        3: _GramPerKgMacroCoefficient(carbs: 3.4, protein: 1.7, fat: 0.9),
        4: _GramPerKgMacroCoefficient(carbs: 3.8, protein: 1.8, fat: 0.9),
        5: _GramPerKgMacroCoefficient(carbs: 4.2, protein: 2.0, fat: 1.0),
      };

  static const Map<int, _GramPerKgMacroCoefficient>
  _femaleBulkingGramPerKgTable = <int, _GramPerKgMacroCoefficient>{
    2: _GramPerKgMacroCoefficient(carbs: 2.8, protein: 1.6, fat: 0.9),
    3: _GramPerKgMacroCoefficient(carbs: 3.1, protein: 1.7, fat: 1.0),
    4: _GramPerKgMacroCoefficient(carbs: 3.4, protein: 1.8, fat: 1.0),
    5: _GramPerKgMacroCoefficient(carbs: 3.8, protein: 2.0, fat: 1.1),
  };

  MacroTargets calculateByEnergyRatio({
    required UserProfile profile,
    required double targetIntakeKcal,
  }) {
    final macroRatio = _resolveMacroRatio(profile);
    final proteinTargetG =
        targetIntakeKcal * macroRatio.protein / _proteinCaloriesPerGram;
    final carbsTargetG =
        targetIntakeKcal * macroRatio.carbs / _carbsCaloriesPerGram;
    final fatTargetG = targetIntakeKcal * macroRatio.fat / _fatCaloriesPerGram;
    final macroEnergyEquivalentKcal = _calculateMacroEquivalentKcal(
      proteinTargetG: proteinTargetG,
      carbsTargetG: carbsTargetG,
      fatTargetG: fatTargetG,
    );

    return MacroTargets(
      proteinTargetG: proteinTargetG,
      carbsTargetG: carbsTargetG,
      fatTargetG: fatTargetG,
      macroEnergyEquivalentKcal: macroEnergyEquivalentKcal,
    );
  }

  MacroTargets calculateByGramPerKg({required UserProfile profile}) {
    final weightKg = math.max(0, profile.weightKg);
    if (weightKg <= 0) {
      return const MacroTargets(
        proteinTargetG: 0,
        carbsTargetG: 0,
        fatTargetG: 0,
        macroEnergyEquivalentKcal: 0,
      );
    }

    final frequency = _resolveTrainingFrequency(
      profile.trainingFrequencyPerWeek,
    );
    final coefficient = _resolveGramPerKgCoefficient(
      dietGoalPhase: profile.dietGoalPhase,
      sexForFormula: profile.sexForFormula,
      frequencyPerWeek: frequency,
    );
    final proteinTargetG = weightKg * coefficient.protein;
    final carbsTargetG = weightKg * coefficient.carbs;
    final fatTargetG = weightKg * coefficient.fat;
    final macroEnergyEquivalentKcal = _calculateMacroEquivalentKcal(
      proteinTargetG: proteinTargetG,
      carbsTargetG: carbsTargetG,
      fatTargetG: fatTargetG,
    );

    return MacroTargets(
      proteinTargetG: proteinTargetG,
      carbsTargetG: carbsTargetG,
      fatTargetG: fatTargetG,
      macroEnergyEquivalentKcal: macroEnergyEquivalentKcal,
    );
  }

  _MacroRatio _resolveMacroRatio(UserProfile profile) {
    final protein = profile.proteinRatioPercent <= 0
        ? 0
        : profile.proteinRatioPercent;
    final carbs = profile.carbsRatioPercent <= 0
        ? 0
        : profile.carbsRatioPercent;
    final fat = profile.fatRatioPercent <= 0 ? 0 : profile.fatRatioPercent;
    final total = protein + carbs + fat;

    if (total <= 0) {
      return const _MacroRatio(protein: 0.3, carbs: 0.4, fat: 0.3);
    }

    return _MacroRatio(
      protein: protein / total,
      carbs: carbs / total,
      fat: fat / total,
    );
  }

  _GramPerKgMacroCoefficient _resolveGramPerKgCoefficient({
    required String dietGoalPhase,
    required String sexForFormula,
    required int frequencyPerWeek,
  }) {
    final useBulking = dietGoalPhase == AppConstants.dietGoalPhaseBulking;
    final male = useBulking
        ? _maleBulkingGramPerKgTable[frequencyPerWeek]!
        : _maleCuttingGramPerKgTable[frequencyPerWeek]!;
    final female = useBulking
        ? _femaleBulkingGramPerKgTable[frequencyPerWeek]!
        : _femaleCuttingGramPerKgTable[frequencyPerWeek]!;

    switch (sexForFormula) {
      case 'male':
        return male;
      case 'female':
        return female;
      case 'prefer_not_to_say':
      default:
        return _GramPerKgMacroCoefficient(
          carbs: (male.carbs + female.carbs) / 2,
          protein: (male.protein + female.protein) / 2,
          fat: (male.fat + female.fat) / 2,
        );
    }
  }

  int _resolveTrainingFrequency(int value) {
    return AppConstants.resolveTrainingFrequencyPerWeek(value);
  }

  double _calculateMacroEquivalentKcal({
    required double proteinTargetG,
    required double carbsTargetG,
    required double fatTargetG,
  }) {
    return proteinTargetG * _proteinCaloriesPerGram +
        carbsTargetG * _carbsCaloriesPerGram +
        fatTargetG * _fatCaloriesPerGram;
  }
}

class MacroTargets {
  const MacroTargets({
    required this.proteinTargetG,
    required this.carbsTargetG,
    required this.fatTargetG,
    required this.macroEnergyEquivalentKcal,
  });

  final double proteinTargetG;
  final double carbsTargetG;
  final double fatTargetG;
  final double macroEnergyEquivalentKcal;
}

class _MacroRatio {
  const _MacroRatio({
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final double protein;
  final double carbs;
  final double fat;
}

class _GramPerKgMacroCoefficient {
  const _GramPerKgMacroCoefficient({
    required this.carbs,
    required this.protein,
    required this.fat,
  });

  final double carbs;
  final double protein;
  final double fat;
}
