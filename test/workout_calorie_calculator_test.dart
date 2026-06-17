import 'package:fitlog_local/domain/models/workout_set.dart';
import 'package:fitlog_local/domain/services/workout_calorie_calculator.dart';
import 'package:fitlog_local/core/constants/exercise_catalog.dart';
import 'package:fitlog_local/core/constants/exercise_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkoutCalorieCalculator', () {
    test('cardio uses net MET (MET - 1)', () {
      final kcal = WorkoutCalorieCalculator.estimateCardioCalories(
        exerciseName: 'Running',
        bodyWeightKg: 80,
        durationMinutes: 30,
      );

      // (8 - 1) * 3.5 * 80 / 200 * 30 = 294
      expect(kcal, closeTo(294, 0.1));
    });

    test(
      'bench sample stays in plausible net range and uses capped duration-density modifier',
      () {
        final benchSets = <WorkoutSet>[
          const WorkoutSet(
            setNumber: 1,
            weightKg: 40,
            reps: 8,
            isCompleted: true,
          ),
          const WorkoutSet(
            setNumber: 2,
            weightKg: 50,
            reps: 8,
            isCompleted: true,
          ),
          const WorkoutSet(
            setNumber: 3,
            weightKg: 60,
            reps: 8,
            isCompleted: true,
          ),
          const WorkoutSet(
            setNumber: 4,
            weightKg: 72.5,
            reps: 5,
            isCompleted: true,
          ),
          const WorkoutSet(
            setNumber: 5,
            weightKg: 70,
            reps: 5,
            isCompleted: true,
          ),
          const WorkoutSet(
            setNumber: 6,
            weightKg: 70,
            reps: 5,
            isCompleted: true,
          ),
          const WorkoutSet(
            setNumber: 7,
            weightKg: 70,
            reps: 5,
            isCompleted: true,
          ),
          const WorkoutSet(
            setNumber: 8,
            weightKg: 70,
            reps: 5,
            isCompleted: true,
          ),
          const WorkoutSet(
            setNumber: 9,
            weightKg: 70,
            reps: 4,
            isCompleted: true,
          ),
        ];

        final kcal45 = WorkoutCalorieCalculator.estimateStrengthCalories(
          exerciseName: 'Bench Press',
          bodyWeightKg: 80,
          sets: benchSets,
          totalSessionDurationMinutes: 45,
        );
        final kcal120 = WorkoutCalorieCalculator.estimateStrengthCalories(
          exerciseName: 'Bench Press',
          bodyWeightKg: 80,
          sets: benchSets,
          totalSessionDurationMinutes: 120,
        );
        final kcal20 = WorkoutCalorieCalculator.estimateStrengthCalories(
          exerciseName: 'Bench Press',
          bodyWeightKg: 80,
          sets: benchSets,
          totalSessionDurationMinutes: 20,
        );
        final kcal100 = WorkoutCalorieCalculator.estimateStrengthCalories(
          exerciseName: 'Bench Press',
          bodyWeightKg: 80,
          sets: benchSets,
          totalSessionDurationMinutes: 100,
        );

        expect(kcal45, inInclusiveRange(58, 78));
        expect(kcal120, inInclusiveRange(52, 75));
        expect(kcal45, greaterThan(kcal120));
        expect(kcal45 / kcal120, lessThan(1.25));
        expect(kcal20 - kcal100, greaterThanOrEqualTo(2));
      },
    );

    test('same volume: lower body compound > upper compound > isolation', () {
      final sameVolumeSets = <WorkoutSet>[
        const WorkoutSet(
          setNumber: 1,
          weightKg: 60,
          reps: 10,
          isCompleted: true,
        ),
        const WorkoutSet(
          setNumber: 2,
          weightKg: 60,
          reps: 10,
          isCompleted: true,
        ),
        const WorkoutSet(
          setNumber: 3,
          weightKg: 60,
          reps: 10,
          isCompleted: true,
        ),
      ];

      final bench = WorkoutCalorieCalculator.estimateStrengthCalories(
        exerciseName: 'Bench Press',
        bodyWeightKg: 80,
        sets: sameVolumeSets,
        totalSessionDurationMinutes: 45,
      );
      final squat = WorkoutCalorieCalculator.estimateStrengthCalories(
        exerciseName: 'Squat',
        bodyWeightKg: 80,
        sets: sameVolumeSets,
        totalSessionDurationMinutes: 45,
      );
      final curl = WorkoutCalorieCalculator.estimateStrengthCalories(
        exerciseName: 'Biceps Curl',
        bodyWeightKg: 80,
        sets: sameVolumeSets,
        totalSessionDurationMinutes: 45,
      );

      expect(squat, greaterThan(bench));
      expect(bench, greaterThan(curl));
    });

    test(
      'assisted bodyweight movements treat entered weight as assistance',
      () {
        final assistedSets = <WorkoutSet>[
          const WorkoutSet(
            setNumber: 1,
            weightKg: 20,
            reps: 8,
            isCompleted: true,
          ),
          const WorkoutSet(
            setNumber: 2,
            weightKg: 20,
            reps: 8,
            isCompleted: true,
          ),
          const WorkoutSet(
            setNumber: 3,
            weightKg: 20,
            reps: 8,
            isCompleted: true,
          ),
        ];
        final unassistedSets = <WorkoutSet>[
          const WorkoutSet(
            setNumber: 1,
            weightKg: 0,
            reps: 8,
            isCompleted: true,
          ),
          const WorkoutSet(
            setNumber: 2,
            weightKg: 0,
            reps: 8,
            isCompleted: true,
          ),
          const WorkoutSet(
            setNumber: 3,
            weightKg: 0,
            reps: 8,
            isCompleted: true,
          ),
        ];

        final assistedPullUp =
            WorkoutCalorieCalculator.estimateStrengthCalories(
              exerciseName: 'Assisted Pull-up',
              bodyWeightKg: 80,
              sets: assistedSets,
              totalSessionDurationMinutes: 20,
            );
        final pullUp = WorkoutCalorieCalculator.estimateStrengthCalories(
          exerciseName: 'Pull-up',
          bodyWeightKg: 80,
          sets: unassistedSets,
          totalSessionDurationMinutes: 20,
        );

        expect(assistedPullUp, lessThan(pullUp));
        expect(assistedPullUp, greaterThan(0));
      },
    );

    test(
      'per-side load and reps are standardized before strength estimate',
      () {
        const dumbbellBench = WorkoutSet(
          setNumber: 1,
          weightKg: 30,
          reps: 10,
          inputWeightKg: 30,
          inputReps: 10,
          calculationLoadKg: 60,
          calculationReps: 10,
          loadInputMode: ExerciseLoadInputMode.perSideLoad,
          repsInputMode: ExerciseRepsInputMode.totalReps,
          setMetricType: ExerciseSetMetricType.reps,
          isCompleted: true,
        );
        const singleArmRow = WorkoutSet(
          setNumber: 1,
          weightKg: 30,
          reps: 20,
          inputWeightKg: 30,
          inputReps: 10,
          calculationLoadKg: 30,
          calculationReps: 20,
          loadInputMode: ExerciseLoadInputMode.totalLoad,
          repsInputMode: ExerciseRepsInputMode.perSide,
          setMetricType: ExerciseSetMetricType.reps,
          isCompleted: true,
        );

        final dumbbellBenchKcal =
            WorkoutCalorieCalculator.estimateStrengthCalories(
              exerciseName: 'Dumbbell Flat Bench Press',
              bodyWeightKg: 80,
              sets: const <WorkoutSet>[dumbbellBench],
              totalSessionDurationMinutes: 20,
              definition: ExerciseCatalog.byName('Dumbbell Flat Bench Press'),
            );
        final singleArmRowKcal =
            WorkoutCalorieCalculator.estimateStrengthCalories(
              exerciseName: 'Single-arm Dumbbell Row',
              bodyWeightKg: 80,
              sets: const <WorkoutSet>[singleArmRow],
              totalSessionDurationMinutes: 20,
              definition: ExerciseCatalog.byName('Single-arm Dumbbell Row'),
            );

        expect(dumbbellBenchKcal, greaterThan(0));
        expect(singleArmRowKcal, greaterThan(0));
      },
    );

    test('duration-based plank sets use seconds as the set metric', () {
      const plankSet = WorkoutSet(
        setNumber: 1,
        weightKg: 0,
        reps: 15,
        inputWeightKg: 0,
        inputDurationSeconds: 60,
        calculationLoadKg: 0,
        calculationReps: 15,
        loadInputMode: ExerciseLoadInputMode.bodyweightAdded,
        setMetricType: ExerciseSetMetricType.durationSeconds,
        isCompleted: true,
      );

      final kcal = WorkoutCalorieCalculator.estimateStrengthCalories(
        exerciseName: 'Plank',
        bodyWeightKg: 80,
        sets: const <WorkoutSet>[plankSet],
        totalSessionDurationMinutes: 5,
        definition: ExerciseCatalog.byName('Plank'),
      );

      expect(kcal, greaterThan(0));
    });

    test(
      'interval cardio can use active minutes instead of total duration',
      () {
        final running = ExerciseCatalog.byName('Running')!;
        final totalDurationKcal =
            WorkoutCalorieCalculator.estimateCardioCalories(
              exerciseName: 'Running',
              bodyWeightKg: 80,
              durationMinutes: 20,
              definition: running,
              intensityBasis: CardioIntensityBasis.intervalUnder3,
            );
        final activeOnlyKcal = WorkoutCalorieCalculator.estimateCardioCalories(
          exerciseName: 'Running',
          bodyWeightKg: 80,
          durationMinutes: 20,
          definition: running,
          intensityBasis: CardioIntensityBasis.intervalUnder3,
          activeDurationMinutes: 8,
        );

        expect(activeOnlyKcal, lessThan(totalDurationKcal));
        expect(activeOnlyKcal, greaterThan(0));
      },
    );
  });
}
