import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/localization/language_controller.dart';
import 'core/localization/localization_extensions.dart';
import 'core/utils/date_utils.dart';
import 'core/widgets/fitlog_bottom_nav_bar.dart';
import 'data/db/app_database.dart';
import 'data/repositories/custom_exercise_repository.dart';
import 'data/repositories/food_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'data/repositories/workout_draft_repository.dart';
import 'data/repositories/workout_repository.dart';
import 'domain/services/daily_summary_service.dart';
import 'domain/services/diet_plan_strategy_service.dart';
import 'domain/services/carb_taper_review_service.dart';
import 'domain/services/training_frequency_self_check_service.dart';
import 'export/csv_export_service.dart';
import 'export/xlsx_export_service.dart';
import 'features/ai/ai_page.dart';
import 'features/food/food_log_page.dart';
import 'features/home/home_page.dart';
import 'features/profile/profile_page.dart';
import 'features/workout/workout_log_page.dart';

const String _fitlogFontFamily = 'NotoSansSC';
const List<String> _fitlogChineseSansFallback = <String>[
  'Noto Sans CJK SC',
  'Noto Sans SC',
  'Source Han Sans SC',
  'PingFang SC',
  'Hiragino Sans GB',
  'Microsoft YaHei',
  'sans-serif',
];

class FitLogApp extends StatefulWidget {
  const FitLogApp({super.key});

  @override
  State<FitLogApp> createState() => _FitLogAppState();
}

class _FitLogAppState extends State<FitLogApp> {
  late final AppServices _services;
  late final LanguageController _languageController;

  @override
  void initState() {
    super.initState();

    final database = AppDatabase.instance;
    final foodRepository = FoodRepository(database);
    final customExerciseRepository = CustomExerciseRepository(database);
    final workoutRepository = WorkoutRepository(database);
    final workoutDraftRepository = WorkoutDraftRepository(database);
    final profileRepository = ProfileRepository(database);
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

    _languageController = LanguageController()..load();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppServices>.value(value: _services),
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
      ],
      child: Consumer<LanguageController>(
        builder: (context, languageController, _) {
          if (!languageController.initialized) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: Center(child: Text(context.strings.loading)),
              ),
            );
          }

          return MaterialApp(
            title: context.strings.appName,
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.light,
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            home: const _RootShell(),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF78BE5B),
        brightness: brightness,
      ),
    );
    final textTheme = base.textTheme
        .apply(
          fontFamily: _fitlogFontFamily,
          fontFamilyFallback: _fitlogChineseSansFallback,
        )
        .copyWith(
          headlineSmall: _withFontFallback(
            base.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF152013),
            ),
          ),
          titleLarge: _withFontFallback(
            base.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF152013),
            ),
          ),
          titleMedium: _withFontFallback(
            base.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF22311F),
            ),
          ),
          bodyMedium: _withFontFallback(
            base.textTheme.bodyMedium?.copyWith(color: const Color(0xFF51614E)),
          ),
        );

    return base.copyWith(
      splashFactory: isDark ? NoSplash.splashFactory : InkRipple.splashFactory,
      splashColor: isDark ? Colors.transparent : base.splashColor,
      highlightColor: isDark ? Colors.transparent : base.highlightColor,
      hoverColor: isDark ? Colors.transparent : base.hoverColor,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0E1117)
          : const Color(0xFFF5F8F1),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        titleTextStyle: _withFontFallback(
          TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        color: isDark
            ? const Color(0xFF171B22).withValues(alpha: 0.88)
            : const Color(0xFFFFFFFF),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: _withFontFallback(
          const TextStyle(color: Color(0xFF61715D)),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFDCE6D7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFDCE6D7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF78BE5B), width: 1.4),
        ),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
        isDense: true,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedItemColor: const Color(0xFF4E9E3B),
        selectedLabelStyle: _withFontFallback(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        unselectedItemColor: isDark
            ? Colors.white.withValues(alpha: 0.58)
            : const Color(0xFF7A8973),
        unselectedLabelStyle: _withFontFallback(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isDark
            ? const Color(0xFF11161F).withValues(alpha: 0.9)
            : Colors.white,
      ),
      textTheme: textTheme,
    );
  }
}

TextStyle? _withFontFallback(TextStyle? style) {
  return style?.copyWith(
    fontFamily: _fitlogFontFamily,
    fontFamilyFallback: _fitlogChineseSansFallback,
  );
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
    final extendBodyBehindNav = navController.index == RootTabIndex.ai;

    return Scaffold(
      extendBody: extendBodyBehindNav,
      resizeToAvoidBottomInset: !extendBodyBehindNav,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFFFAFCF7),
              Color(0xFFF3F7EE),
              Color(0xFFF7FAF3),
            ],
          ),
        ),
        child: IndexedStack(index: navController.index, children: _pages),
      ),
      bottomNavigationBar: FitLogBottomNavBar(
        items: items,
        currentIndex: navController.index,
        onTap: navController.setIndex,
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
