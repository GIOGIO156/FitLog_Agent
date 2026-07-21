import 'dart:async';
import 'dart:convert';

import 'package:fitlog_local/app.dart';
import 'package:fitlog_local/core/constants/exercise_definition.dart';
import 'package:fitlog_local/core/localization/language_controller.dart';
import 'package:fitlog_local/data/db/app_database.dart';
import 'package:fitlog_local/data/repositories/custom_exercise_repository.dart';
import 'package:fitlog_local/data/repositories/daily_summary_cache_repository.dart';
import 'package:fitlog_local/data/repositories/food_repository.dart';
import 'package:fitlog_local/data/repositories/profile_repository.dart';
import 'package:fitlog_local/data/repositories/phase2_repository_exception.dart';
import 'package:fitlog_local/data/repositories/workout_draft_repository.dart';
import 'package:fitlog_local/data/repositories/workout_repository.dart';
import 'package:fitlog_local/domain/models/calorie_calibration_state.dart';
import 'package:fitlog_local/domain/models/diet_adjustment_review.dart';
import 'package:fitlog_local/domain/models/user_profile.dart';
import 'package:fitlog_local/domain/models/weight_log.dart';
import 'package:fitlog_local/domain/models/workout_plan_commit.dart';
import 'package:fitlog_local/domain/models/workout_record_draft.dart';
import 'package:fitlog_local/domain/models/workout_session.dart';
import 'package:fitlog_local/domain/services/cache_maintenance_service.dart';
import 'package:fitlog_local/domain/services/carb_taper_review_service.dart';
import 'package:fitlog_local/domain/services/daily_summary_service.dart';
import 'package:fitlog_local/domain/services/diet_plan_strategy_service.dart';
import 'package:fitlog_local/domain/services/training_frequency_self_check_service.dart';
import 'package:fitlog_local/domain/services/warm_cache_coordinator.dart';
import 'package:fitlog_local/export/csv_export_service.dart';
import 'package:fitlog_local/export/xlsx_export_service.dart';
import 'package:fitlog_local/features/workout/add_workout_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'background lifecycle cannot recreate a draft during or after commit',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final draftRepository = _FakeWorkoutDraftRepository(_activeDraft());
      final workoutRepository = _FakeWorkoutRepository();
      await tester.pumpWidget(
        _buildTestApp(
          workoutRepository: workoutRepository,
          draftRepository: draftRepository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Workout Record'));
      for (var i = 0; i < 20 && workoutRepository.commitRequests.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(workoutRepository.commitRequests, hasLength(1));
      expect(draftRepository.saved.last.hasPendingCommit, isTrue);
      final writesBeforeBackground = draftRepository.saved.length;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(draftRepository.saved, hasLength(writesBeforeBackground));

      final request = workoutRepository.commitRequests.single;
      workoutRepository.commitCompleters.single.complete(
        WorkoutPlanCommitResult.committed(
          targetPlanId: request.targetPlanId,
          sessions: request.sessions,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(draftRepository.deleteCount, 1);
      final writesAfterSuccess = draftRepository.saved.length;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(draftRepository.saved, hasLength(writesAfterSuccess));
      expect(draftRepository.deleteCount, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    },
  );

  testWidgets('ambiguous save retry reuses the original mutation and payload', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final draftRepository = _FakeWorkoutDraftRepository(_activeDraft());
    final workoutRepository = _FakeWorkoutRepository();
    await tester.pumpWidget(
      _buildTestApp(
        workoutRepository: workoutRepository,
        draftRepository: draftRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Workout Record'));
    await _pumpUntilCommitCount(tester, workoutRepository, 1);
    final firstRequest = workoutRepository.commitRequests.single;
    workoutRepository.commitCompleters.single.completeError(
      const Phase2RepositoryException('record_network_error'),
    );
    await tester.pump();
    await tester.pump();

    expect(draftRepository.active?.saveState, 'commit_unknown');
    expect(draftRepository.deleteCount, 0);
    expect(find.text('Retry save confirmation'), findsOneWidget);
    final writesBeforeBackground = draftRepository.saved.length;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(draftRepository.saved, hasLength(writesBeforeBackground));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    await tester.tap(find.text('Retry save confirmation'));
    await _pumpUntilCommitCount(tester, workoutRepository, 2);
    final retryRequest = workoutRepository.commitRequests.last;
    expect(retryRequest.mutationId, firstRequest.mutationId);
    expect(retryRequest.targetPlanId, firstRequest.targetPlanId);
    expect(retryRequest.payloadHash, firstRequest.payloadHash);

    workoutRepository.commitCompleters.last.complete(
      WorkoutPlanCommitResult.committed(
        targetPlanId: retryRequest.targetPlanId,
        sessions: retryRequest.sessions,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(draftRepository.deleteCount, 1);
  });

  testWidgets('schema mismatch restores an editable draft with readable error', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final draftRepository = _FakeWorkoutDraftRepository(_activeDraft());
    final workoutRepository = _FakeWorkoutRepository();
    await tester.pumpWidget(
      _buildTestApp(
        workoutRepository: workoutRepository,
        draftRepository: draftRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Workout Record'));
    await _pumpUntilCommitCount(tester, workoutRepository, 1);
    workoutRepository.commitCompleters.single.completeError(
      const Phase2RepositoryException('record_schema_mismatch'),
    );
    await tester.pump();
    await tester.pump();

    expect(draftRepository.active?.saveState, 'editing');
    expect(draftRepository.active?.saveMutationId, isNull);
    expect(
      find.text(
        'Cloud Records schema is incomplete. Apply the latest Supabase migrations.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('PostgrestException'), findsNothing);
  });
}

Future<void> _pumpUntilCommitCount(
  WidgetTester tester,
  _FakeWorkoutRepository repository,
  int count,
) async {
  for (var i = 0; i < 20 && repository.commitRequests.length < count; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(repository.commitRequests, hasLength(count));
}

Widget _buildTestApp({
  required _FakeWorkoutRepository workoutRepository,
  required _FakeWorkoutDraftRepository draftRepository,
}) {
  final database = AppDatabase.instance;
  final foodRepository = _FakeFoodRepository(database);
  final profileRepository = _FakeProfileRepository(database);
  final customExerciseRepository = _FakeCustomExerciseRepository(database);
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
          workoutDraftRepository: draftRepository,
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
            dailySummaryCacheRepository: DailySummaryCacheRepository(database),
          ),
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
    child: const MaterialApp(home: AddWorkoutPage(initialDate: '2026-07-22')),
  );
}

class _FakeWorkoutRepository extends WorkoutRepository {
  _FakeWorkoutRepository() : super(AppDatabase.instance);

  final List<WorkoutPlanCommitRequest> commitRequests =
      <WorkoutPlanCommitRequest>[];
  final List<Completer<WorkoutPlanCommitResult>> commitCompleters =
      <Completer<WorkoutPlanCommitResult>>[];

  @override
  Future<WorkoutPlanCommitResult> commitWorkoutPlan(
    WorkoutPlanCommitRequest request,
  ) {
    commitRequests.add(request);
    final completer = Completer<WorkoutPlanCommitResult>();
    commitCompleters.add(completer);
    return completer.future;
  }

  @override
  Future<List<WorkoutSession>> getWorkoutSessionsByPlanId(
    String planId,
  ) async => const <WorkoutSession>[];

  @override
  Future<WorkoutSession?> getWorkoutSessionById(int id) async => null;
}

class _FakeWorkoutDraftRepository extends WorkoutDraftRepository {
  _FakeWorkoutDraftRepository(this.active) : super(AppDatabase.instance);

  WorkoutRecordDraft? active;
  final List<WorkoutRecordDraft> saved = <WorkoutRecordDraft>[];
  int deleteCount = 0;

  @override
  Future<WorkoutRecordDraft?> getActiveDraft() async => active;

  @override
  Future<void> saveActiveDraft(WorkoutRecordDraft draft) async {
    active = draft;
    saved.add(draft);
  }

  @override
  Future<void> deleteActiveDraft() async {
    active = null;
    deleteCount += 1;
  }
}

class _FakeCustomExerciseRepository extends CustomExerciseRepository {
  _FakeCustomExerciseRepository(super.database);

  @override
  Future<List<ExerciseDefinition>> getActiveDefinitions() async =>
      const <ExerciseDefinition>[];
}

class _FakeFoodRepository extends FoodRepository {
  _FakeFoodRepository(super.database);
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
  }) async => const <WeightLog>[];

  @override
  Future<DietAdjustmentReview?> getLatestDietAdjustmentReview({
    String? userDecision,
  }) async => null;
}

WorkoutRecordDraft _activeDraft() {
  return WorkoutRecordDraft(
    id: WorkoutRecordDraft.activeDraftId,
    kind: WorkoutRecordDraft.kindNewRecord,
    date: '2026-07-22',
    recordName: 'Lifecycle workout',
    notes: '',
    payloadJson: jsonEncode(<String, Object?>{
      'exercises': <Map<String, Object?>>[
        <String, Object?>{
          'exercise_key': 'barbell_flat_bench_press',
          'exercise_source': 'builtin',
          'body_part': 'Chest',
          'exercise_name': 'Barbell Flat Bench Press',
          'exercise_type': 'strength',
          'duration_text': '45',
          'sets': <Map<String, Object?>>[
            <String, Object?>{
              'weight_text': '80',
              'reps_text': '8',
              'is_completed': true,
              'completed_at': '2026-07-22T10:00:00.000Z',
            },
          ],
        },
      ],
    }),
    createdAt: '2026-07-22T09:00:00.000Z',
    updatedAt: '2026-07-22T10:00:00.000Z',
  );
}
