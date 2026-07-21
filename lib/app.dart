import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase/supabase.dart' as supabase;

import 'core/config/app_config.dart';
import 'core/config/supabase_pkce_storage.dart';
import 'core/localization/language_controller.dart';
import 'core/localization/localization_extensions.dart';
import 'core/theme/fitlog_theme.dart';
import 'core/utils/date_utils.dart';
import 'core/widgets/fitlog_bottom_nav_bar.dart';
import 'core/widgets/fitlog_notifications.dart';
import 'data/db/app_database.dart';
import 'data/remote/ai_gateway_client.dart';
import 'data/remote/ai_food_photo_analysis_client.dart';
import 'data/repositories/ai_local_context_permission_repository.dart';
import 'data/repositories/active_device_repository.dart';
import 'data/repositories/ai_chat_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/cloud_profile_repository.dart';
import 'data/repositories/custom_exercise_repository.dart';
import 'data/repositories/daily_summary_cache_repository.dart';
import 'data/repositories/daily_summary_cloud_repository.dart';
import 'data/repositories/food_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'data/repositories/subscription_repository.dart';
import 'data/repositories/workout_draft_repository.dart';
import 'data/repositories/workout_repository.dart';
import 'domain/models/auth_session.dart';
import 'domain/models/cloud_runtime_context.dart';
import 'domain/services/cache_maintenance_service.dart';
import 'domain/services/daily_summary_service.dart';
import 'domain/services/diet_plan_strategy_service.dart';
import 'domain/services/carb_taper_review_service.dart';
import 'domain/services/training_frequency_self_check_service.dart';
import 'domain/services/warm_cache_coordinator.dart';
import 'export/csv_export_service.dart';
import 'export/xlsx_export_service.dart';
import 'features/account/account_controller.dart';
import 'features/ai/ai_chat_controller.dart';
import 'features/ai/ai_chat_image_recovery.dart';
import 'features/ai/ai_page.dart';
import 'features/food/food_image_picker.dart';
import 'features/food/food_log_page.dart';
import 'features/food/photo_food_analysis_page.dart';
import 'features/food/photo_food_analysis_recovery.dart';
import 'features/home/home_page.dart';
import 'features/profile/profile_page.dart';
import 'features/workout/add_workout_page.dart';
import 'features/workout/workout_draft_notification.dart';
import 'features/workout/workout_editor_resume.dart';
import 'features/workout/workout_log_page.dart';

final GlobalKey<NavigatorState> fitLogNavigatorKey =
    GlobalKey<NavigatorState>();

const String fitLogFontFamily = 'NotoSansSC';
const List<String> fitLogChineseSansFallback = <String>[
  'Noto Sans CJK SC',
  'Noto Sans SC',
  'Source Han Sans SC',
  'PingFang SC',
  'Hiragino Sans GB',
  'Microsoft YaHei',
  'sans-serif',
];

SystemUiOverlayStyle fitLogSystemUiOverlayStyle(FitLogThemeData fitLogTheme) {
  final isDark = fitLogTheme.isDark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: fitLogTheme.pageBackground,
    systemNavigationBarIconBrightness: isDark
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  );
}

Widget _fitLogSystemUiBuilder(BuildContext context, Widget? child) {
  return AnnotatedRegion<SystemUiOverlayStyle>(
    value: fitLogSystemUiOverlayStyle(context.fitLogTheme),
    child: child ?? const SizedBox.shrink(),
  );
}

class FitLogApp extends StatefulWidget {
  const FitLogApp({
    super.key,
    this.config = const AppConfig(supabaseUrl: '', supabaseAnonKey: ''),
  });

  final AppConfig config;

  @override
  State<FitLogApp> createState() => _FitLogAppState();
}

class _FitLogAppState extends State<FitLogApp> {
  late final AppServices _services;
  late final LanguageController _languageController;
  late final FitLogThemeController _themeController;
  late final AccountController _accountController;
  late final CloudRuntimeContext _cloudRuntimeContext;
  late final AiChatRepository _aiChatRepository;
  StreamSubscription<supabase.AuthState>? _supabaseAuthSubscription;

  @override
  void initState() {
    super.initState();

    final database = AppDatabase.instance;
    _cloudRuntimeContext = CloudRuntimeContext();
    final customExerciseRepository = CustomExerciseRepository(database);
    final workoutDraftRepository = WorkoutDraftRepository(database);
    final authSessionStorage = widget.config.hasSupabase
        ? const SharedPreferencesSupabaseAuthSessionStorage()
        : null;
    final supabaseClient = widget.config.hasSupabase
        ? supabase.SupabaseClient(
            widget.config.supabaseUrl,
            widget.config.supabaseAnonKey,
            authOptions: const supabase.AuthClientOptions(
              pkceAsyncStorage: SharedPreferencesGotrueAsyncStorage(),
            ),
          )
        : null;
    final activeDeviceRepository = supabaseClient == null
        ? const NoopActiveDeviceRepository()
        : SupabaseActiveDeviceRepository(
            client: supabaseClient,
            runtimeContext: _cloudRuntimeContext,
          );
    _aiChatRepository = supabaseClient == null
        ? const NoopAiChatRepository()
        : SupabaseAiChatRepository(
            client: supabaseClient,
            gatewayClient: SupabaseAiGatewayClient(supabaseClient),
          );
    final aiFoodPhotoAnalysisClient = supabaseClient == null
        ? const NoopAiFoodPhotoAnalysisClient()
        : SupabaseAiFoodPhotoAnalysisClient(supabaseClient);
    final foodRepository = supabaseClient == null
        ? FoodRepository(database)
        : CloudBackedFoodRepository(
            database: database,
            client: supabaseClient,
            runtimeContext: _cloudRuntimeContext,
            activeDeviceRepository: activeDeviceRepository,
          );
    final workoutRepository = supabaseClient == null
        ? WorkoutRepository(database)
        : CloudBackedWorkoutRepository(
            database: database,
            client: supabaseClient,
            runtimeContext: _cloudRuntimeContext,
            activeDeviceRepository: activeDeviceRepository,
          );
    final profileRepository = supabaseClient == null
        ? ProfileRepository(database)
        : CloudBackedProfileRepository(
            database: database,
            client: supabaseClient,
            runtimeContext: _cloudRuntimeContext,
            activeDeviceRepository: activeDeviceRepository,
          );
    if (supabaseClient != null && authSessionStorage != null) {
      _supabaseAuthSubscription = supabaseClient.auth.onAuthStateChange.listen((
        state,
      ) async {
        final session = state.session;
        if (state.event == supabase.AuthChangeEvent.signedOut ||
            session == null) {
          await authSessionStorage.clear();
        } else {
          await authSessionStorage.writeSession(session);
        }
      });
    }
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
    final dailySummaryCacheRepository = DailySummaryCacheRepository(database);
    final dailySummaryCloudRepository = supabaseClient == null
        ? const NoopDailySummaryCloudRepository()
        : SupabaseDailySummaryCloudRepository(
            client: supabaseClient,
            runtimeContext: _cloudRuntimeContext,
            activeDeviceRepository: activeDeviceRepository,
          );

    final dailySummaryService = DailySummaryService(
      foodRepository: foodRepository,
      workoutRepository: workoutRepository,
      profileRepository: profileRepository,
      trainingFrequencySelfCheckService: trainingFrequencySelfCheckService,
      dietPlanStrategyService: dietPlanStrategyService,
      dailySummaryCacheRepository: dailySummaryCacheRepository,
      dailySummaryCloudRepository: dailySummaryCloudRepository,
    );
    final warmCacheCoordinator = WarmCacheCoordinator(
      dailySummaryService: dailySummaryService,
    );
    final cacheMaintenanceService = CacheMaintenanceService(
      database: database,
      dailySummaryCacheRepository: dailySummaryCacheRepository,
    );

    _services = AppServices(
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
      warmCacheCoordinator: warmCacheCoordinator,
      cacheMaintenanceService: cacheMaintenanceService,
      database: database,
      aiFoodPhotoAnalysisClient: aiFoodPhotoAnalysisClient,
    );

    _accountController = AccountController(
      authRepository: supabaseClient == null
          ? const UnconfiguredAuthRepository()
          : SupabaseAuthRepository(
              supabaseClient,
              sessionStorage: authSessionStorage!,
            ),
      subscriptionRepository: supabaseClient == null
          ? const UnconfiguredSubscriptionRepository()
          : SupabaseSubscriptionRepository(supabaseClient),
      cloudProfileRepository: supabaseClient == null
          ? const UnconfiguredCloudProfileRepository()
          : SupabaseCloudProfileRepository(
              client: supabaseClient,
              activeDeviceRepository: activeDeviceRepository,
            ),
      profileRepository: profileRepository,
      contextPermissionRepository: const AiLocalContextPermissionRepository(),
      activeDeviceRepository: activeDeviceRepository,
      cloudRuntimeContext: _cloudRuntimeContext,
      backendConfigured: widget.config.hasSupabase,
    )..initialize();

    _languageController = LanguageController()..load();
    _themeController = FitLogThemeController()..load();
    MethodChannelWorkoutDraftNotificationPlatform.instance.setTapHandler(
      _handleWorkoutDraftNotificationTap,
    );
    unawaited(
      MethodChannelWorkoutDraftNotificationPlatform.instance
          .consumeInitialTapIfAny(),
    );
  }

  @override
  void dispose() {
    MethodChannelWorkoutDraftNotificationPlatform.instance.setTapHandler(null);
    _supabaseAuthSubscription?.cancel();
    _accountController.dispose();
    _cloudRuntimeContext.dispose();
    _themeController.dispose();
    super.dispose();
  }

  Future<void> _handleWorkoutDraftNotificationTap() async {
    await WorkoutDraftNotificationTapCoordinator.instance.handleTap(
      loadActiveDraft: _services.workoutDraftRepository.getActiveDraft,
      cancelNotification:
          MethodChannelWorkoutDraftNotificationPlatform.instance.cancel,
      openDraft: (draft) async {
        final navigator = fitLogNavigatorKey.currentState;
        final navigatorContext = fitLogNavigatorKey.currentContext;
        if (!mounted || navigator == null || navigatorContext == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              unawaited(_handleWorkoutDraftNotificationTap());
            }
          });
          return;
        }
        try {
          navigatorContext.read<RootTabController>().setIndex(
            RootTabIndex.workout,
          );
        } catch (_) {
          // Notification resume should still open the draft if tab state is absent.
        }
        await navigator.push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => AddWorkoutPage(initialDate: draft.date),
          ),
        );
        if (!mounted || !navigatorContext.mounted) {
          return;
        }
        try {
          navigatorContext.read<RefreshNotifier>().markDataChanged();
        } catch (_) {
          // The editor save/discard path remains the authoritative refresh source.
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppServices>.value(value: _services),
        ChangeNotifierProvider<AccountController>.value(
          value: _accountController,
        ),
        ChangeNotifierProvider<CloudRuntimeContext>.value(
          value: _cloudRuntimeContext,
        ),
        ChangeNotifierProvider<AiChatController>(
          create: (_) => AiChatController(
            repository: _aiChatRepository,
            customExerciseRepository: _services.customExerciseRepository,
            onDeviceReplaced: _cloudRuntimeContext.markDeviceReplaced,
          ),
        ),
        ChangeNotifierProvider<AiChatImageRecoveryController>(
          create: (_) => AiChatImageRecoveryController(),
        ),
        ChangeNotifierProvider<RefreshNotifier>(
          create: (_) => RefreshNotifier(),
        ),
        ChangeNotifierProvider<RootTabController>(
          create: (_) => RootTabController(),
        ),
        ChangeNotifierProvider<RootInteractionLockController>(
          create: (_) => RootInteractionLockController(),
        ),
        ChangeNotifierProvider<SelectedDateNotifier>(
          create: (_) => SelectedDateNotifier(),
        ),
        ChangeNotifierProvider<LanguageController>.value(
          value: _languageController,
        ),
        ChangeNotifierProvider<FitLogThemeController>.value(
          value: _themeController,
        ),
      ],
      child: Consumer2<LanguageController, FitLogThemeController>(
        builder: (context, languageController, themeController, _) {
          if (!languageController.initialized || !themeController.initialized) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildFitLogTheme(Brightness.light),
              builder: _fitLogSystemUiBuilder,
              home: Scaffold(
                body: Center(child: Text(context.strings.loading)),
              ),
            );
          }

          return MaterialApp(
            title: context.strings.appName,
            navigatorKey: fitLogNavigatorKey,
            navigatorObservers: <NavigatorObserver>[
              FitLogNotifications.navigatorObserver,
            ],
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.light,
            theme: buildFitLogTheme(
              Brightness.light,
              themeKey: themeController.theme,
            ),
            darkTheme: buildFitLogTheme(
              Brightness.dark,
              themeKey: themeController.theme,
            ),
            builder: _fitLogSystemUiBuilder,
            home: const _RootAuthGate(),
          );
        },
      ),
    );
  }
}

ThemeData buildFitLogTheme(
  Brightness brightness, {
  FitLogThemeKey themeKey = FitLogThemeKey.green,
}) {
  final fitLogTheme = FitLogThemeData.forKey(themeKey);
  final effectiveBrightness = fitLogTheme.isDark ? Brightness.dark : brightness;
  final isDark = effectiveBrightness == Brightness.dark;
  final base = ThemeData(
    useMaterial3: true,
    brightness: effectiveBrightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: fitLogTheme.primaryBright,
      brightness: effectiveBrightness,
    ),
  );
  final textTheme = base.textTheme
      .apply(
        fontFamily: fitLogFontFamily,
        fontFamilyFallback: fitLogChineseSansFallback,
      )
      .copyWith(
        headlineSmall: _withFontFallback(
          base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: fitLogTheme.textPrimary,
          ),
        ),
        titleLarge: _withFontFallback(
          base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: fitLogTheme.textPrimary,
          ),
        ),
        titleMedium: _withFontFallback(
          base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: fitLogTheme.textPrimary,
          ),
        ),
        bodyMedium: _withFontFallback(
          base.textTheme.bodyMedium?.copyWith(color: fitLogTheme.textSecondary),
        ),
      );

  return base.copyWith(
    splashFactory: isDark ? NoSplash.splashFactory : InkRipple.splashFactory,
    splashColor: isDark ? Colors.transparent : base.splashColor,
    highlightColor: isDark ? Colors.transparent : base.highlightColor,
    hoverColor: isDark ? Colors.transparent : base.hoverColor,
    scaffoldBackgroundColor: fitLogTheme.pageBackground,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: fitLogTheme.textPrimary,
      iconTheme: IconThemeData(color: fitLogTheme.textPrimary),
      systemOverlayStyle: fitLogSystemUiOverlayStyle(fitLogTheme),
      titleTextStyle: _withFontFallback(
        TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: fitLogTheme.textPrimary,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      color: fitLogTheme.surface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: _withFontFallback(TextStyle(color: fitLogTheme.mutedText)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: fitLogTheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: fitLogTheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: fitLogTheme.primaryBright, width: 1.4),
      ),
      filled: true,
      fillColor: fitLogTheme.surfaceVariant,
      isDense: true,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedItemColor: fitLogTheme.primary,
      selectedLabelStyle: _withFontFallback(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      unselectedItemColor: fitLogTheme.navUnselectedText,
      unselectedLabelStyle: _withFontFallback(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      backgroundColor: fitLogTheme.navBackground,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: fitLogTheme.primary,
        foregroundColor: fitLogTheme.onPrimary,
        disabledBackgroundColor: fitLogTheme.primarySoftPressed,
        disabledForegroundColor: fitLogTheme.disabledText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: fitLogTheme.primaryDeep,
        side: BorderSide(color: fitLogTheme.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: fitLogTheme.primaryDeep),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return fitLogTheme.primaryDeep;
          }
          return fitLogTheme.textPrimary;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return fitLogTheme.primarySoftSelected;
          }
          return fitLogTheme.surface;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BorderSide(color: fitLogTheme.primaryBright);
          }
          return BorderSide(color: fitLogTheme.outline);
        }),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: fitLogTheme.surfaceVariant,
      selectedColor: fitLogTheme.primarySoftSelected,
      disabledColor: fitLogTheme.primarySoftPressed,
      labelStyle: _withFontFallback(
        TextStyle(color: fitLogTheme.textPrimary, fontWeight: FontWeight.w700),
      ),
      secondaryLabelStyle: _withFontFallback(
        TextStyle(color: fitLogTheme.primaryDeep, fontWeight: FontWeight.w800),
      ),
      side: BorderSide(color: fitLogTheme.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: fitLogTheme.surfaceElevated,
      contentTextStyle: _withFontFallback(
        TextStyle(color: fitLogTheme.textPrimary),
      ),
      actionTextColor: fitLogTheme.primaryBright,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: fitLogTheme.surfaceElevated,
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: fitLogTheme.surfaceElevated,
      surfaceTintColor: Colors.transparent,
    ),
    extensions: <ThemeExtension<dynamic>>[fitLogTheme],
    textTheme: textTheme,
  );
}

TextStyle? _withFontFallback(TextStyle? style) {
  return style?.copyWith(
    fontFamily: fitLogFontFamily,
    fontFamilyFallback: fitLogChineseSansFallback,
  );
}

class _RootAuthGate extends StatelessWidget {
  const _RootAuthGate();

  @override
  Widget build(BuildContext context) {
    final accountController = context.watch<AccountController>();
    final status = accountController.authSession.status;
    if (!accountController.initialized ||
        status == AuthSessionStatus.unknown ||
        status == AuthSessionStatus.loading) {
      return Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: context.fitLogTheme.pageGradient),
          child: Center(child: Text(context.strings.loading)),
        ),
      );
    }
    if (!accountController.authSession.isSignedIn) {
      return const Scaffold(
        resizeToAvoidBottomInset: false,
        body: ProfilePage(),
      );
    }
    return const _RootShell();
  }
}

class _RootShell extends StatefulWidget {
  const _RootShell();

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> with WidgetsBindingObserver {
  late final List<Widget> _pages = const <Widget>[
    HomePage(),
    FoodLogPage(),
    AiPage(),
    WorkoutLogPage(),
    ProfilePage(),
  ];
  String? _lastBackgroundAccountId;
  String? _lastRecordHydrationKey;
  bool _recordHydrationRefreshScheduled = false;
  bool _restoringLostPickerImages = false;
  bool _checkedWorkoutEditorResume = false;
  bool _initialFirstFrameDeferred = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.deferFirstFrame();
    _initialFirstFrameDeferred = true;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_runInitialRecoveryThenAllowFirstFrame());
        unawaited(_syncActiveWorkoutDraftNotification());
      }
    });
  }

  @override
  void dispose() {
    _allowInitialFirstFrame();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    FitLogNotifications.handleAppLifecycleState(state);
    if (state != AppLifecycleState.resumed || !mounted) {
      return;
    }
    _scheduleSelectedDateHydrationRefresh();
    unawaited(_restoreLostPickerImagesIfNeeded());
    unawaited(_syncActiveWorkoutDraftNotification());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final accountController = context.watch<AccountController>();
    final runtimeContext = context.watch<CloudRuntimeContext>();
    final accountId = accountController.authSession.accountId;
    _bindLocalRecordAccount(accountId);
    _scheduleHydrationRefreshWhenContextChanges(
      accountId: accountId,
      runtimeContext: runtimeContext,
    );
    if ((accountId ?? '').isEmpty || accountId == _lastBackgroundAccountId) {
      return;
    }
    _lastBackgroundAccountId = accountId;
    final services = context.read<AppServices>();
    unawaited(
      services.warmCacheCoordinator.warmRecentWindow(accountId: accountId),
    );
    unawaited(services.cacheMaintenanceService.pruneForAccount(accountId));
  }

  void _bindLocalRecordAccount(String? accountId) {
    final services = context.read<AppServices>();
    services.foodRepository.setActiveAccountId(accountId);
    services.workoutRepository.setActiveAccountId(accountId);
    services.profileRepository.setActiveAccountId(accountId);
  }

  void _scheduleHydrationRefreshWhenContextChanges({
    required String? accountId,
    required CloudRuntimeContext runtimeContext,
  }) {
    final key = [
      accountId ?? '',
      runtimeContext.accountId ?? '',
      runtimeContext.deviceId ?? '',
      runtimeContext.sessionId ?? '',
      runtimeContext.deviceReplaced ? 'replaced' : 'active',
    ].join('|');
    if (key == _lastRecordHydrationKey) {
      return;
    }
    _lastRecordHydrationKey = key;
    _scheduleSelectedDateHydrationRefresh();
  }

  void _scheduleSelectedDateHydrationRefresh() {
    if (_recordHydrationRefreshScheduled) {
      return;
    }
    _recordHydrationRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordHydrationRefreshScheduled = false;
      if (!mounted) {
        return;
      }
      context.read<RefreshNotifier>().markDataChanged();
    });
  }

  Future<void> _runInitialRecoveryThenAllowFirstFrame() async {
    var restoredPickerRoute = false;
    try {
      restoredPickerRoute = await _restoreLostPickerImagesIfNeeded(
        routeOnly: true,
      );
    } finally {
      _allowInitialFirstFrame();
    }
    if (!mounted) {
      return;
    }
    if (restoredPickerRoute) {
      return;
    }
    await _restoreRecentWorkoutEditorIfNeeded();
  }

  void _allowInitialFirstFrame() {
    if (!_initialFirstFrameDeferred) {
      return;
    }
    _initialFirstFrameDeferred = false;
    WidgetsBinding.instance.allowFirstFrame();
  }

  Future<bool> _restoreLostPickerImagesIfNeeded({
    bool routeOnly = false,
  }) async {
    if (_restoringLostPickerImages) {
      return false;
    }
    _restoringLostPickerImages = true;
    var chatRestoreContinues = false;
    try {
      final photoDraft = await PhotoFoodAnalysisRecoveryStore.loadPending();
      final chatDraft = await AiChatImageRecoveryStore.loadPending();
      if (photoDraft == null && chatDraft == null) {
        return false;
      }
      if (photoDraft != null) {
        if (chatDraft != null) {
          await AiChatImageRecoveryStore.clearPending();
        }
        return await PhotoFoodAnalysisRecoveryCoordinator.instance
            .runRootRecovery(() => _restoreLostPhotoAnalysis(photoDraft));
      }
      if (chatDraft != null) {
        _restoreLostAiChatImages(chatDraft, const <PickedFoodImage>[]);
        if (routeOnly) {
          chatRestoreContinues = true;
          unawaited(
            _retrieveAndRestoreLostChatImagesSafely(
              chatDraft,
            ).whenComplete(() => _restoringLostPickerImages = false),
          );
          return true;
        }
        await _retrieveAndRestoreLostChatImages(chatDraft);
        return true;
      }
      return false;
    } catch (_) {
      await PhotoFoodAnalysisRecoveryStore.clearPending();
      await AiChatImageRecoveryStore.clearPending();
      return false;
    } finally {
      if (!chatRestoreContinues) {
        _restoringLostPickerImages = false;
      }
    }
  }

  Future<void> _retrieveAndRestoreLostChatImagesSafely(
    AiChatImageRecoveryDraft draft,
  ) async {
    try {
      await _retrieveAndRestoreLostChatImages(draft);
    } catch (_) {
      await AiChatImageRecoveryStore.clearPending();
    }
  }

  Future<void> _retrieveAndRestoreLostChatImages(
    AiChatImageRecoveryDraft draft,
  ) async {
    final images = await ImagePickerFoodImagePicker().retrieveLostImages(
      limit: 3,
    );
    await AiChatImageRecoveryStore.clearPending();
    if (!mounted) {
      return;
    }
    _restoreLostAiChatImages(draft, images);
  }

  Future<void> _restoreLostPhotoAnalysis(
    PhotoFoodAnalysisRecoveryDraft draft,
  ) async {
    final restoredDate = draft.initialDate ?? DateUtilsX.todayKey();
    context.read<SelectedDateNotifier>().setDate(restoredDate);
    context.read<RootTabController>().setIndex(RootTabIndex.food);
    final savedFuture = Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PhotoFoodAnalysisPage(
          initialDate: draft.initialDate,
          initialNote: draft.note,
          restoreLostImagesOnStart: true,
        ),
      ),
    );
    unawaited(
      savedFuture
          .then((saved) {
            if (saved == true && mounted) {
              context.read<RefreshNotifier>().markDataChanged();
            }
          })
          .catchError((_) {}),
    );
  }

  void _restoreLostAiChatImages(
    AiChatImageRecoveryDraft draft,
    List<PickedFoodImage> images,
  ) {
    if (images.isEmpty && draft.messageText.trim().isEmpty) {
      return;
    }
    context.read<RootTabController>().setIndex(RootTabIndex.ai);
    context.read<AiChatImageRecoveryController>().restore(
      RecoveredAiChatImages(
        messageText: draft.messageText,
        provider: draft.provider,
        images: images,
        wasReadyVisual: draft.wasReadyVisual,
      ),
    );
  }

  Future<void> _syncActiveWorkoutDraftNotification() async {
    final draft = await context
        .read<AppServices>()
        .workoutDraftRepository
        .getActiveDraft();
    if (!mounted) {
      return;
    }
    await WorkoutDraftNotificationSync.syncFromDraft(
      draft,
      context.stringsRead,
    );
  }

  Future<void> _restoreRecentWorkoutEditorIfNeeded() async {
    if (_checkedWorkoutEditorResume ||
        WorkoutDraftNotificationTapCoordinator.instance.editorOpen) {
      return;
    }
    _checkedWorkoutEditorResume = true;
    final draft = await context
        .read<AppServices>()
        .workoutDraftRepository
        .getActiveDraft();
    final shouldResume = await WorkoutEditorResumeStore.shouldAutoResume(draft);
    if (!mounted || !shouldResume || draft == null) {
      if (!shouldResume) {
        await WorkoutEditorResumeStore.clear();
      }
      return;
    }

    WorkoutDraftNotificationTapCoordinator.instance.markEditorOpen();
    context.read<RootTabController>().setIndex(RootTabIndex.workout);
    try {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => AddWorkoutPage(initialDate: draft.date),
        ),
      );
    } catch (_) {
      WorkoutDraftNotificationTapCoordinator.instance.markEditorClosed();
      return;
    }
    if (mounted) {
      context.read<RefreshNotifier>().markDataChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final navController = context.watch<RootTabController>();
    final interactionLock = context.watch<RootInteractionLockController>();
    final items = <FitLogNavItem>[
      FitLogNavItem(
        label: strings.navHome,
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      FitLogNavItem(
        label: strings.navFood,
        icon: Icons.restaurant_menu_outlined,
        activeIcon: Icons.restaurant_menu_rounded,
      ),
      FitLogNavItem(
        label: strings.navAi,
        icon: Icons.auto_awesome_outlined,
        activeIcon: Icons.auto_awesome_rounded,
      ),
      FitLogNavItem(
        label: strings.navWorkout,
        icon: Icons.fitness_center_outlined,
        activeIcon: Icons.fitness_center_rounded,
      ),
      FitLogNavItem(
        label: strings.navProfile,
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
      ),
    ];
    final resizeForKeyboard =
        navController.index != RootTabIndex.ai &&
        navController.index != RootTabIndex.profile;
    final fitLogTheme = context.fitLogTheme;
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: resizeForKeyboard,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: fitLogTheme.pageGradient),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: IndexedStack(index: navController.index, children: _pages),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: interactionLock.navigationLocked,
                child: _RootLockedNavigationSurface(
                  locked: interactionLock.navigationLocked,
                  child: FitLogBottomNavBar(
                    items: items,
                    currentIndex: navController.index,
                    onTap: (index) {
                      FitLogNotifications.dismiss();
                      if (index != RootTabIndex.ai) {
                        context.read<AiChatController>().clearError();
                      }
                      navController.setIndex(index);
                    },
                    surface: navController.index == RootTabIndex.ai
                        ? FitLogBottomNavSurface.glass
                        : FitLogBottomNavSurface.solid,
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

class _RootLockedNavigationSurface extends StatelessWidget {
  const _RootLockedNavigationSurface({
    required this.locked,
    required this.child,
  });

  final bool locked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: locked ? 0.34 : 1,
      child: child,
    );
  }
}

class RefreshNotifier extends ChangeNotifier {
  int _version = 0;

  int get version => _version;

  void markDataChanged() {
    _version++;
    notifyListeners();
  }
}

extension DailySummaryCacheRefresh on BuildContext {
  void refreshDailySummaryCacheForDate(String day) {
    final accountId = read<AccountController>().authSession.accountId;
    read<AppServices>().refreshDailySummaryCacheForDates(
      days: <String>[day],
      accountId: accountId,
    );
  }

  void refreshDailySummaryCacheForDates(Iterable<String> days) {
    final accountId = read<AccountController>().authSession.accountId;
    read<AppServices>().refreshDailySummaryCacheForDates(
      days: days,
      accountId: accountId,
    );
  }
}

class RootTabIndex {
  const RootTabIndex._();

  static const int home = 0;
  static const int food = 1;
  static const int ai = 2;
  static const int workout = 3;
  static const int profile = 4;
}

class RootTabController extends ChangeNotifier {
  int _index = 0;

  int get index => _index;

  void setIndex(int index) {
    if (_index == index) {
      return;
    }
    _index = index;
    notifyListeners();
  }
}

class RootInteractionLockController extends ChangeNotifier {
  bool _navigationLocked = false;

  bool get navigationLocked => _navigationLocked;

  void setNavigationLocked(bool locked) {
    if (_navigationLocked == locked) {
      return;
    }
    _navigationLocked = locked;
    notifyListeners();
  }
}

class SelectedDateNotifier extends ChangeNotifier {
  String _selectedDate = DateUtilsX.todayKey();

  String get selectedDate => _selectedDate;

  void setDate(String date) {
    if (_selectedDate == date) {
      return;
    }
    _selectedDate = date;
    notifyListeners();
  }
}

class AppServices {
  const AppServices({
    required this.foodRepository,
    required this.customExerciseRepository,
    required this.workoutRepository,
    required this.workoutDraftRepository,
    required this.profileRepository,
    required this.dailySummaryService,
    required this.xlsxExportService,
    required this.csvExportService,
    required this.carbTaperReviewService,
    required this.dietPlanStrategyService,
    required this.trainingFrequencySelfCheckService,
    required this.warmCacheCoordinator,
    required this.cacheMaintenanceService,
    required this.database,
    this.aiFoodPhotoAnalysisClient = const NoopAiFoodPhotoAnalysisClient(),
  });

  final FoodRepository foodRepository;
  final CustomExerciseRepository customExerciseRepository;
  final WorkoutRepository workoutRepository;
  final WorkoutDraftRepository workoutDraftRepository;
  final ProfileRepository profileRepository;
  final DailySummaryService dailySummaryService;
  final XlsxExportService xlsxExportService;
  final CsvExportService csvExportService;
  final CarbTaperReviewService carbTaperReviewService;
  final DietPlanStrategyService dietPlanStrategyService;
  final TrainingFrequencySelfCheckService trainingFrequencySelfCheckService;
  final WarmCacheCoordinator warmCacheCoordinator;
  final CacheMaintenanceService cacheMaintenanceService;
  final AppDatabase database;
  final AiFoodPhotoAnalysisClient aiFoodPhotoAnalysisClient;

  void refreshDailySummaryCacheForDates({
    required Iterable<String> days,
    required String? accountId,
  }) {
    if ((accountId ?? '').isEmpty) {
      return;
    }
    final uniqueDays = days.where((day) => day.isNotEmpty).toSet().toList();
    if (uniqueDays.isEmpty) {
      return;
    }
    unawaited(_refreshDailySummaryCacheForDates(uniqueDays, accountId!));
  }

  Future<void> _refreshDailySummaryCacheForDates(
    List<String> days,
    String accountId,
  ) async {
    for (final day in days) {
      try {
        await dailySummaryService.getSummaryForDateAndCache(
          day: day,
          accountId: accountId,
        );
      } catch (_) {
        // Summary cache refresh is a read-model repair path, not the write result.
      }
    }
  }
}
