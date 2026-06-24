import 'package:fitlog_local/app.dart';
import 'package:fitlog_local/core/constants/exercise_definition.dart';
import 'package:fitlog_local/core/localization/language_controller.dart';
import 'package:fitlog_local/data/db/app_database.dart';
import 'package:fitlog_local/data/repositories/custom_exercise_repository.dart';
import 'package:fitlog_local/data/repositories/food_repository.dart';
import 'package:fitlog_local/data/repositories/profile_repository.dart';
import 'package:fitlog_local/data/repositories/workout_draft_repository.dart';
import 'package:fitlog_local/data/repositories/workout_repository.dart';
import 'package:fitlog_local/domain/models/calorie_calibration_state.dart';
import 'package:fitlog_local/domain/models/diet_adjustment_review.dart';
import 'package:fitlog_local/domain/models/user_profile.dart';
import 'package:fitlog_local/domain/models/weight_log.dart';
import 'package:fitlog_local/domain/models/workout_record_draft.dart';
import 'package:fitlog_local/domain/models/workout_session.dart';
import 'package:fitlog_local/domain/services/carb_taper_review_service.dart';
import 'package:fitlog_local/domain/services/daily_summary_service.dart';
import 'package:fitlog_local/domain/services/diet_plan_strategy_service.dart';
import 'package:fitlog_local/domain/services/training_frequency_self_check_service.dart';
import 'package:fitlog_local/export/csv_export_service.dart';
import 'package:fitlog_local/export/xlsx_export_service.dart';
import 'package:fitlog_local/features/workout/add_workout_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('custom exercise delete action is tappable after a short swipe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final customRepository =
        _FakeCustomExerciseRepository(const <ExerciseDefinition>[
          ExerciseDefinition(
            key: 'custom:test-custom-row',
            name: 'Test custom row',
            bodyPart: 'Chest',
            exerciseType: ExerciseType.strength,
            isBuiltin: false,
          ),
        ]);

    await tester.pumpWidget(_buildAddWorkoutTestApp(customRepository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Exercise Library'), findsOneWidget);

    final filterList = find.byWidgetPredicate(
      (widget) =>
          widget is ListView && widget.scrollDirection == Axis.horizontal,
    );
    await tester.drag(filterList, const Offset(-1200, 0));
    await tester.pumpAndSettle();
    expect(find.text('Custom exercises'), findsOneWidget);
    await tester.ensureVisible(find.text('Custom exercises'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom exercises'));
    await tester.pumpAndSettle();

    expect(find.text('Test custom row'), findsOneWidget);

    await tester.drag(find.text('Test custom row'), const Offset(-96, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete custom exercise?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(customRepository.hiddenKeys, contains('custom:test-custom-row'));
    expect(find.text('Test custom row'), findsNothing);
  });
}

Widget _buildAddWorkoutTestApp(
  _FakeCustomExerciseRepository customExerciseRepository,
) {
  final database = AppDatabase.instance;
  final foodRepository = _FakeFoodRepository(database);
  final workoutRepository = _FakeWorkoutRepository(database);
  final workoutDraftRepository = _FakeWorkoutDraftRepository(database);
  final profileRepository = _FakeProfileRepository(database);
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
          database: database,
        ),
      ),
      ChangeNotifierProvider<RefreshNotifier>(create: (_) => RefreshNotifier()),
      ChangeNotifierProvider<RootTabController>(
        create: (_) => RootTabController(),
      ),
      ChangeNotifierProvider<SelectedDateNotifier>(
        create: (_) => SelectedDateNotifier(),
      ),
      ChangeNotifierProvider<LanguageController>(
        create: (_) => LanguageController(),
      ),
    ],
    child: const MaterialApp(home: AddWorkoutPage(initialDate: '2026-06-12')),
  );
}

class _FakeCustomExerciseRepository extends CustomExerciseRepository {
  _FakeCustomExerciseRepository(this._definitions)
    : super(AppDatabase.instance);

  List<ExerciseDefinition> _definitions;
  final List<String> hiddenKeys = <String>[];

  @override
  Future<List<ExerciseDefinition>> getActiveDefinitions() async =>
      List<ExerciseDefinition>.from(_definitions);

  @override
  Future<void> hideDefinition(String exerciseKey) async {
    hiddenKeys.add(exerciseKey);
    _definitions = _definitions
        .where((definition) => definition.key != exerciseKey)
        .toList();
  }
}

class _FakeFoodRepository extends FoodRepository {
  _FakeFoodRepository(super.database);
}

class _FakeWorkoutRepository extends WorkoutRepository {
  _FakeWorkoutRepository(super.database);

  @override
  Future<List<WorkoutSession>> getWorkoutSessionsByPlanId(
    String planId,
  ) async => const <WorkoutSession>[];

  @override
  Future<WorkoutSession?> getWorkoutSessionById(int id) async => null;
}

class _FakeWorkoutDraftRepository extends WorkoutDraftRepository {
  _FakeWorkoutDraftRepository(super.database);

  @override
  Future<WorkoutRecordDraft?> getActiveDraft() async => null;

  @override
  Future<void> saveActiveDraft(WorkoutRecordDraft draft) async {}

  @override
  Future<void> deleteActiveDraft() async {}
}

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository(super.database);

  @override
  Future<UserProfile?> getProfile() async => UserProfile.defaults;

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
