import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase/supabase.dart' as supabase;

import 'core/config/app_config.dart';
import 'core/config/supabase_pkce_storage.dart';
import 'core/localization/language_controller.dart';
import 'core/localization/localization_extensions.dart';
import 'core/theme/fitlog_theme.dart';
import 'core/utils/date_utils.dart';
import 'core/widgets/fitlog_bottom_nav_bar.dart';
import 'data/db/app_database.dart';
import 'data/repositories/ai_local_context_permission_repository.dart';
import 'data/repositories/active_device_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/cloud_profile_repository.dart';
import 'data/repositories/custom_exercise_repository.dart';
import 'data/repositories/daily_summary_cache_repository.dart';
import 'data/repositories/food_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'data/repositories/subscription_repository.dart';
import 'data/repositories/workout_draft_repository.dart';
import 'data/repositories/workout_repository.dart';
import 'domain/models/auth_session.dart';
import 'domain/models/cloud_runtime_context.dart';
import 'domain/services/daily_summary_service.dart';
import 'domain/services/diet_plan_strategy_service.dart';
import 'domain/services/carb_taper_review_service.dart';
import 'domain/services/training_frequency_self_check_service.dart';
import 'export/csv_export_service.dart';
import 'export/xlsx_export_service.dart';
import 'features/account/account_controller.dart';
import 'features/ai/ai_page.dart';
import 'features/food/food_log_page.dart';
import 'features/home/home_page.dart';
import 'features/profile/profile_page.dart';
import 'features/workout/workout_log_page.dart';

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

    final dailySummaryService = DailySummaryService(
      foodRepository: foodRepository,
      workoutRepository: workoutRepository,
      profileRepository: profileRepository,
      trainingFrequencySelfCheckService: trainingFrequencySelfCheckService,
      dietPlanStrategyService: dietPlanStrategyService,
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
      database: database,
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
  }

  @override
  void dispose() {
    _supabaseAuthSubscription?.cancel();
    _accountController.dispose();
    _cloudRuntimeContext.dispose();
    _themeController.dispose();
    super.dispose();
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
        ChangeNotifierProvider<RefreshNotifier>(
          create: (_) => RefreshNotifier(),
        ),
        ChangeNotifierProvider<RootTabController>(
          create: (_) => RootTabController(),
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
              home: Scaffold(
                body: Center(child: Text(context.strings.loading)),
              ),
            );
          }

          return MaterialApp(
            title: context.strings.appName,
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
      return const Scaffold(body: ProfilePage());
    }
    return const _RootShell();
  }
}

class _RootShell extends StatefulWidget {
  const _RootShell();

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  late final List<Widget> _pages = const <Widget>[
    HomePage(),
    FoodLogPage(),
    AiPage(),
    WorkoutLogPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final navController = context.watch<RootTabController>();
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
              child: FitLogBottomNavBar(
                items: items,
                currentIndex: navController.index,
                onTap: navController.setIndex,
                surface: navController.index == RootTabIndex.ai
                    ? FitLogBottomNavSurface.glass
                    : FitLogBottomNavSurface.solid,
              ),
            ),
          ],
        ),
      ),
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
    required this.database,
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
  final AppDatabase database;
}
