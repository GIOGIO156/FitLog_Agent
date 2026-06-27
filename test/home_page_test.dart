import 'package:fitlog_local/app.dart';
import 'package:fitlog_local/core/constants/app_constants.dart';
import 'package:fitlog_local/core/localization/language_controller.dart';
import 'package:fitlog_local/data/db/app_database.dart';
import 'package:fitlog_local/data/repositories/custom_exercise_repository.dart';
import 'package:fitlog_local/data/repositories/daily_summary_cache_repository.dart';
import 'package:fitlog_local/data/repositories/food_repository.dart';
import 'package:fitlog_local/data/repositories/profile_repository.dart';
import 'package:fitlog_local/data/repositories/workout_draft_repository.dart';
import 'package:fitlog_local/data/repositories/workout_repository.dart';
import 'package:fitlog_local/domain/models/calorie_calibration_state.dart';
import 'package:fitlog_local/domain/models/diet_adjustment_review.dart';
import 'package:fitlog_local/domain/models/food_record.dart';
import 'package:fitlog_local/domain/models/user_profile.dart';
import 'package:fitlog_local/domain/models/weight_log.dart';
import 'package:fitlog_local/domain/models/workout_session.dart';
import 'package:fitlog_local/domain/services/cache_maintenance_service.dart';
import 'package:fitlog_local/domain/services/carb_taper_review_service.dart';
import 'package:fitlog_local/domain/services/daily_summary_service.dart';
import 'package:fitlog_local/domain/services/diet_plan_strategy_service.dart';
import 'package:fitlog_local/domain/services/training_frequency_self_check_service.dart';
import 'package:fitlog_local/domain/services/warm_cache_coordinator.dart';
import 'package:fitlog_local/export/csv_export_service.dart';
import 'package:fitlog_local/export/xlsx_export_service.dart';
import 'package:fitlog_local/features/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('g/kg home keeps the first screen macro-first without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _buildHomeTestApp(
        profile: UserProfile.defaults.copyWith(
          nickname: 'Chris',
          dietCalculationMode: AppConstants.dietCalculationModeGramPerKg,
          dietPlanStrategy: AppConstants.dietPlanStrategyCarbCycling,
        ),
        foodRecords: <FoodRecord>[
          const FoodRecord(
            date: _referenceDay,
            mealName: 'Lunch',
            totalWeightG: 500,
            caloriesKcal: 1365,
            proteinG: 101,
            carbsG: 133,
            fatG: 46,
            estimationNotes: '',
            source: 'manual',
          ),
        ],
        workoutSessions: <WorkoutSession>[
          WorkoutSession(
            date: _referenceDay,
            bodyPart: 'Legs',
            exerciseName: 'Squat',
            exerciseType: 'strength',
            durationMinutes: 45,
            intensity: 'medium',
            estimatedCalories: 220,
            notes: '',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Today's Macro Progress"), findsOneWidget);
    expect(find.text("Today's Records"), findsNothing);
    expect(find.textContaining('Carb cycle'), findsNothing);
    expect(find.textContaining('1365', findRichText: true), findsOneWidget);
    expect(find.textContaining('220', findRichText: true), findsOneWidget);
    expect(find.text('Protein'), findsWidgets);
    expect(find.text('Carbs'), findsWidgets);
    expect(find.text('Fat'), findsWidgets);
    expect(find.textContaining('%'), findsWidgets);

    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();

    final strategyLabelFinder = find.textContaining('Carb cycle');
    expect(strategyLabelFinder, findsOneWidget);
    expect(tester.getTopLeft(strategyLabelFinder).dy, lessThan(800));
    expect(tester.takeException(), isNull);
  });

  testWidgets('energy_ratio home still shows today records card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _buildHomeTestApp(
        profile: UserProfile.defaults.copyWith(
          nickname: 'Chris',
          dietCalculationMode: AppConstants.dietCalculationModeEnergyRatio,
          dietPlanStrategy: AppConstants.dietPlanStrategyCarbCycling,
        ),
        foodRecords: <FoodRecord>[
          const FoodRecord(
            date: _referenceDay,
            mealName: 'Dinner',
            totalWeightG: 450,
            caloriesKcal: 820,
            proteinG: 48,
            carbsG: 72,
            fatG: 24,
            estimationNotes: '',
            source: 'manual',
          ),
        ],
        workoutSessions: <WorkoutSession>[
          WorkoutSession(
            date: _referenceDay,
            bodyPart: 'Back',
            exerciseName: 'Row',
            exerciseType: 'strength',
            durationMinutes: 35,
            intensity: 'medium',
            estimatedCalories: 180,
            notes: '',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final strategyLabelFinder = find.textContaining('Carb cycle');
    expect(strategyLabelFinder, findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(strategyLabelFinder, findsOneWidget);
    expect(tester.getTopLeft(strategyLabelFinder).dy, lessThan(844));
    expect(find.text("Today's Records"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'energy_ratio home fits compact first viewport without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _buildHomeTestApp(
          profile: UserProfile.defaults.copyWith(
            nickname: 'Chris',
            dietCalculationMode: AppConstants.dietCalculationModeEnergyRatio,
            dietPlanStrategy: AppConstants.dietPlanStrategyCarbCycling,
          ),
          foodRecords: <FoodRecord>[
            const FoodRecord(
              date: _referenceDay,
              mealName: 'Dinner',
              totalWeightG: 450,
              caloriesKcal: 1975,
              proteinG: 124,
              carbsG: 136,
              fatG: 102,
              estimationNotes: '',
              source: 'manual',
            ),
          ],
          workoutSessions: <WorkoutSession>[
            WorkoutSession(
              date: _referenceDay,
              bodyPart: 'Back',
              exerciseName: 'Row',
              exerciseType: 'strength',
              durationMinutes: 35,
              intensity: 'medium',
              estimatedCalories: 0,
              notes: '',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Calories'), findsOneWidget);
      expect(find.text('Macros'), findsOneWidget);
      expect(
        tester.getSize(find.byType(CircularProgressIndicator)),
        const Size(170, 170),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home keeps strategy below the first viewport on tall screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _buildHomeTestApp(
        profile: UserProfile.defaults.copyWith(
          nickname: 'Chris',
          dietCalculationMode: AppConstants.dietCalculationModeEnergyRatio,
          dietPlanStrategy: AppConstants.dietPlanStrategyCarbCycling,
        ),
        foodRecords: <FoodRecord>[
          const FoodRecord(
            date: _referenceDay,
            mealName: 'Dinner',
            totalWeightG: 450,
            caloriesKcal: 820,
            proteinG: 48,
            carbsG: 72,
            fatG: 24,
            estimationNotes: '',
            source: 'manual',
          ),
        ],
        workoutSessions: <WorkoutSession>[
          WorkoutSession(
            date: _referenceDay,
            bodyPart: 'Back',
            exerciseName: 'Row',
            exerciseType: 'strength',
            durationMinutes: 35,
            intensity: 'medium',
            estimatedCalories: 180,
            notes: '',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final strategyLabelFinder = find.textContaining('Carb cycle');
    expect(strategyLabelFinder, findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(strategyLabelFinder, findsOneWidget);
    expect(tester.getTopLeft(strategyLabelFinder).dy, lessThan(932));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home strategy title keeps English detail on its own line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<void> pumpStrategy(String strategy) async {
      await tester.pumpWidget(
        _buildHomeTestApp(
          profile: UserProfile.defaults.copyWith(
            nickname: 'Chris',
            dietCalculationMode: AppConstants.dietCalculationModeGramPerKg,
            dietPlanStrategy: strategy,
          ),
          foodRecords: const <FoodRecord>[],
          workoutSessions: const <WorkoutSession>[],
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
    }

    await pumpStrategy(AppConstants.dietPlanStrategyCarbCycling);
    expect(find.text('Carb cycle'), findsOneWidget);
    expect(find.text('- Medium carb day'), findsOneWidget);
    expect(find.textContaining('Carb cycle -'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpStrategy(AppConstants.dietPlanStrategyCarbTapering);
    expect(find.text('Carb Taper'), findsOneWidget);
    expect(find.text('- Current taper 0 g'), findsOneWidget);
    expect(find.textContaining('Carb Taper -'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home strategy guide opens in the shared guide sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _buildHomeTestApp(
        profile: UserProfile.defaults.copyWith(
          nickname: 'Chris',
          dietCalculationMode: AppConstants.dietCalculationModeEnergyRatio,
          dietPlanStrategy: AppConstants.dietPlanStrategyCarbCycling,
        ),
        foodRecords: <FoodRecord>[
          const FoodRecord(
            date: _referenceDay,
            mealName: 'Dinner',
            totalWeightG: 450,
            caloriesKcal: 820,
            proteinG: 48,
            carbsG: 72,
            fatG: 24,
            estimationNotes: '',
            source: 'manual',
          ),
        ],
        workoutSessions: <WorkoutSession>[
          WorkoutSession(
            date: _referenceDay,
            bodyPart: 'Back',
            exerciseName: 'Row',
            exerciseType: 'strength',
            durationMinutes: 35,
            intensity: 'medium',
            estimatedCalories: 180,
            notes: '',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final strategyLabelFinder = find.textContaining('Carb cycle');
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(strategyLabelFinder);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('fitlog_guide_sheet_panel')),
      findsOneWidget,
    );
    expect(find.byType(ModalBarrier), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

const String _referenceDay = '2026-06-08';

Widget _buildHomeTestApp({
  required UserProfile profile,
  required List<FoodRecord> foodRecords,
  required List<WorkoutSession> workoutSessions,
}) {
  final database = AppDatabase.instance;
  final foodRepository = _FakeFoodRepository(database)
    ..recordsByDate[_referenceDay] = foodRecords;
  final customExerciseRepository = CustomExerciseRepository(database);
  final workoutRepository = _FakeWorkoutRepository(database)
    ..sessionsByDate[_referenceDay] = workoutSessions;
  final workoutDraftRepository = WorkoutDraftRepository(database);
  final profileRepository = _FakeProfileRepository(database)..profile = profile;
  final trainingFrequencySelfCheckService = TrainingFrequencySelfCheckService(
    workoutRepository: workoutRepository,
  );
  final carbTaperReviewService = CarbTaperReviewService(
    foodRepository: foodRepository,
    workoutRepository: workoutRepository,
    profileRepository: profileRepository,
  );
  final dietPlanStrategyService = DietPlanStrategyService(
    carbTaperReviewService: carbTaperReviewService,
  );
  final dailySummaryService = DailySummaryService(
    foodRepository: foodRepository,
    workoutRepository: workoutRepository,
    profileRepository: profileRepository,
    trainingFrequencySelfCheckService: trainingFrequencySelfCheckService,
    dietPlanStrategyService: dietPlanStrategyService,
  );
  final dailySummaryCacheRepository = DailySummaryCacheRepository(database);
  final selectedDateNotifier = SelectedDateNotifier()..setDate(_referenceDay);
  final languageController = LanguageController();

  return MultiProvider(
    providers: [
      Provider<AppServices>.value(
        value: AppServices(
          foodRepository: foodRepository,
          customExerciseRepository: customExerciseRepository,
          workoutRepository: workoutRepository,
          workoutDraftRepository: workoutDraftRepository,
          profileRepository: profileRepository,
          dailySummaryService: dailySummaryService,
          xlsxExportService: XlsxExportService(
            foodRepository: foodRepository,
            customExerciseRepository: customExerciseRepository,
            workoutRepository: workoutRepository,
            profileRepository: profileRepository,
            dailySummaryService: dailySummaryService,
          ),
          csvExportService: CsvExportService(
            foodRepository: foodRepository,
            customExerciseRepository: customExerciseRepository,
            workoutRepository: workoutRepository,
            profileRepository: profileRepository,
            dailySummaryService: dailySummaryService,
          ),
          carbTaperReviewService: carbTaperReviewService,
          dietPlanStrategyService: dietPlanStrategyService,
          trainingFrequencySelfCheckService: trainingFrequencySelfCheckService,
          warmCacheCoordinator: WarmCacheCoordinator(
            dailySummaryService: dailySummaryService,
          ),
          cacheMaintenanceService: CacheMaintenanceService(
            database: database,
            dailySummaryCacheRepository: dailySummaryCacheRepository,
          ),
          database: database,
        ),
      ),
      ChangeNotifierProvider<RefreshNotifier>(create: (_) => RefreshNotifier()),
      ChangeNotifierProvider<RootTabController>(
        create: (_) => RootTabController(),
      ),
      ChangeNotifierProvider<SelectedDateNotifier>.value(
        value: selectedDateNotifier,
      ),
      ChangeNotifierProvider<LanguageController>.value(
        value: languageController,
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFFF5F8F1)),
          child: const HomePage(),
        ),
      ),
    ),
  );
}

class _FakeFoodRepository extends FoodRepository {
  _FakeFoodRepository(super.database);

  Map<String, List<FoodRecord>> recordsByDate = <String, List<FoodRecord>>{};

  @override
  Future<List<FoodRecord>> getFoodRecordsByDate(String day) async =>
      recordsByDate[day] ?? const <FoodRecord>[];

  @override
  Future<Map<String, double>> getDailyCaloriesBetween({
    required String startDate,
    required String endDate,
  }) async {
    return <String, double>{
      for (final entry in recordsByDate.entries)
        entry.key: entry.value.fold<double>(
          0,
          (sum, record) => sum + record.caloriesKcal,
        ),
    };
  }
}

class _FakeWorkoutRepository extends WorkoutRepository {
  _FakeWorkoutRepository(super.database);

  Map<String, List<WorkoutSession>> sessionsByDate =
      <String, List<WorkoutSession>>{};

  @override
  Future<List<WorkoutSession>> getWorkoutSessionsByDate(String day) async =>
      sessionsByDate[day] ?? const <WorkoutSession>[];

  @override
  Future<List<WorkoutSession>> getWorkoutSessionsBetween({
    required String startDate,
    required String endDate,
  }) async {
    return sessionsByDate.entries
        .where(
          (entry) =>
              entry.key.compareTo(startDate) >= 0 &&
              entry.key.compareTo(endDate) <= 0,
        )
        .expand((entry) => entry.value)
        .toList();
  }

  @override
  Future<Map<String, double>> getDailyExerciseCaloriesBetween({
    required String startDate,
    required String endDate,
  }) async {
    return <String, double>{
      for (final entry in sessionsByDate.entries)
        if (entry.key.compareTo(startDate) >= 0 &&
            entry.key.compareTo(endDate) <= 0)
          entry.key: entry.value.fold<double>(
            0,
            (sum, session) => sum + session.estimatedCalories,
          ),
    };
  }
}

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository(super.database);

  UserProfile? profile;

  @override
  Future<UserProfile?> getProfile() async => profile;

  @override
  Future<CalorieCalibrationState?> getCalorieCalibrationState() async => null;

  @override
  Future<List<WeightLog>> getWeightLogsBetween({
    String? accountId,
    required String startDate,
    required String endDate,
  }) async {
    return const <WeightLog>[];
  }

  @override
  Future<DietAdjustmentReview?> getLatestDietAdjustmentReview({
    String? userDecision,
  }) async {
    return null;
  }
}
