import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FitLogThemeKey { green, blackOrange }

extension FitLogThemeKeyX on FitLogThemeKey {
  String get code {
    switch (this) {
      case FitLogThemeKey.green:
        return 'green';
      case FitLogThemeKey.blackOrange:
        return 'black_orange';
    }
  }

  static FitLogThemeKey fromCode(String? code) {
    switch (code) {
      case 'black_orange':
        return FitLogThemeKey.blackOrange;
      case 'green':
      default:
        return FitLogThemeKey.green;
    }
  }
}

class FitLogThemeController extends ChangeNotifier {
  FitLogThemeController();

  static const String _themeKey = 'theme_key';

  FitLogThemeKey _theme = FitLogThemeKey.green;
  bool _initialized = false;

  FitLogThemeKey get theme => _theme;
  bool get initialized => _initialized;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _theme = FitLogThemeKeyX.fromCode(prefs.getString(_themeKey));
    _initialized = true;
    notifyListeners();
  }

  Future<void> setTheme(FitLogThemeKey theme) async {
    if (_theme == theme) {
      return;
    }
    _theme = theme;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme.code);
  }
}

class FitLogThemeData extends ThemeExtension<FitLogThemeData> {
  const FitLogThemeData({
    required this.key,
    required this.pageGradient,
    required this.pageBackground,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceVariant,
    required this.outline,
    required this.outlineSubtle,
    required this.primary,
    required this.primaryBright,
    required this.primaryDeep,
    required this.primarySoft,
    required this.primarySoftPressed,
    required this.primarySoftSelected,
    required this.onPrimary,
    required this.textPrimary,
    required this.textSecondary,
    required this.mutedText,
    required this.disabledText,
    required this.navBackground,
    required this.navIndicator,
    required this.navSelectedText,
    required this.navUnselectedText,
    required this.shadow,
    required this.warningSurface,
    required this.warningBorder,
    required this.warningText,
    required this.modifiedSurface,
    required this.modifiedBorder,
    required this.modifiedText,
    required this.isDark,
  });

  final FitLogThemeKey key;
  final LinearGradient pageGradient;
  final Color pageBackground;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceVariant;
  final Color outline;
  final Color outlineSubtle;
  final Color primary;
  final Color primaryBright;
  final Color primaryDeep;
  final Color primarySoft;
  final Color primarySoftPressed;
  final Color primarySoftSelected;
  final Color onPrimary;
  final Color textPrimary;
  final Color textSecondary;
  final Color mutedText;
  final Color disabledText;
  final Color navBackground;
  final Color navIndicator;
  final Color navSelectedText;
  final Color navUnselectedText;
  final Color shadow;
  final Color warningSurface;
  final Color warningBorder;
  final Color warningText;
  final Color modifiedSurface;
  final Color modifiedBorder;
  final Color modifiedText;
  final bool isDark;

  static FitLogThemeData forKey(FitLogThemeKey key) {
    switch (key) {
      case FitLogThemeKey.blackOrange:
        return blackOrange;
      case FitLogThemeKey.green:
        return green;
    }
  }

  static const FitLogThemeData green = FitLogThemeData(
    key: FitLogThemeKey.green,
    pageGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFFFAFCF7), Color(0xFFF3F7EE), Color(0xFFF7FAF3)],
    ),
    pageBackground: Color(0xFFF5F8F1),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF8FBF5),
    outline: Color(0xFFE2ECDD),
    outlineSubtle: Color(0xFFE9EFE4),
    primary: Color(0xFF4E9E3B),
    primaryBright: Color(0xFF78BE5B),
    primaryDeep: Color(0xFF3D6E36),
    primarySoft: Color(0xFFEAF6E3),
    primarySoftPressed: Color(0xFFDCEFD1),
    primarySoftSelected: Color(0xFFE9F7DF),
    onPrimary: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF152013),
    textSecondary: Color(0xFF51614E),
    mutedText: Color(0xFF70806D),
    disabledText: Color(0xFF98A494),
    navBackground: Color(0xFFFFFFFF),
    navIndicator: Color(0xFFEAF6E3),
    navSelectedText: Color(0xFF234120),
    navUnselectedText: Color(0xFF7A8973),
    shadow: Color(0xFF13200F),
    warningSurface: Color(0xFFFFF7E6),
    warningBorder: Color(0xFFF0DCA8),
    warningText: Color(0xFF715310),
    modifiedSurface: Color(0xFFFFF1D8),
    modifiedBorder: Color(0xFFF0C77B),
    modifiedText: Color(0xFF8A5515),
    isDark: false,
  );

  static const FitLogThemeData blackOrange = FitLogThemeData(
    key: FitLogThemeKey.blackOrange,
    pageGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFF171813), Color(0xFF171813), Color(0xFF171813)],
    ),
    pageBackground: Color(0xFF171813),
    surface: Color(0xFF24231F),
    surfaceElevated: Color(0xFF24231F),
    surfaceVariant: Color(0xFF2A2924),
    outline: Color(0xFF373631),
    outlineSubtle: Color(0xFF302F2A),
    primary: Color(0xFFFF6B01),
    primaryBright: Color(0xFFFF7A1A),
    primaryDeep: Color(0xFFFF8A33),
    primarySoft: Color(0xFF2A2924),
    primarySoftPressed: Color(0xFF373631),
    primarySoftSelected: Color(0xFF332A21),
    onPrimary: Color(0xFF171813),
    textPrimary: Color(0xFFF6F4EC),
    textSecondary: Color(0xFFB8B5AA),
    mutedText: Color(0xFF9D9D94),
    disabledText: Color(0xFF6F6E66),
    navBackground: Color(0xFF24231F),
    navIndicator: Color(0xFF2A2924),
    navSelectedText: Color(0xFFFF8A33),
    navUnselectedText: Color(0xFF9D9D94),
    shadow: Color(0xFF000000),
    warningSurface: Color(0xFF332A21),
    warningBorder: Color(0xFFFF8A33),
    warningText: Color(0xFFFFB066),
    modifiedSurface: Color(0xFF332A21),
    modifiedBorder: Color(0xFFFF8A33),
    modifiedText: Color(0xFFFFB066),
    isDark: true,
  );

  @override
  FitLogThemeData copyWith({
    FitLogThemeKey? key,
    LinearGradient? pageGradient,
    Color? pageBackground,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceVariant,
    Color? outline,
    Color? outlineSubtle,
    Color? primary,
    Color? primaryBright,
    Color? primaryDeep,
    Color? primarySoft,
    Color? primarySoftPressed,
    Color? primarySoftSelected,
    Color? onPrimary,
    Color? textPrimary,
    Color? textSecondary,
    Color? mutedText,
    Color? disabledText,
    Color? navBackground,
    Color? navIndicator,
    Color? navSelectedText,
    Color? navUnselectedText,
    Color? shadow,
    Color? warningSurface,
    Color? warningBorder,
    Color? warningText,
    Color? modifiedSurface,
    Color? modifiedBorder,
    Color? modifiedText,
    bool? isDark,
  }) {
    return FitLogThemeData(
      key: key ?? this.key,
      pageGradient: pageGradient ?? this.pageGradient,
      pageBackground: pageBackground ?? this.pageBackground,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      outline: outline ?? this.outline,
      outlineSubtle: outlineSubtle ?? this.outlineSubtle,
      primary: primary ?? this.primary,
      primaryBright: primaryBright ?? this.primaryBright,
      primaryDeep: primaryDeep ?? this.primaryDeep,
      primarySoft: primarySoft ?? this.primarySoft,
      primarySoftPressed: primarySoftPressed ?? this.primarySoftPressed,
      primarySoftSelected: primarySoftSelected ?? this.primarySoftSelected,
      onPrimary: onPrimary ?? this.onPrimary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      mutedText: mutedText ?? this.mutedText,
      disabledText: disabledText ?? this.disabledText,
      navBackground: navBackground ?? this.navBackground,
      navIndicator: navIndicator ?? this.navIndicator,
      navSelectedText: navSelectedText ?? this.navSelectedText,
      navUnselectedText: navUnselectedText ?? this.navUnselectedText,
      shadow: shadow ?? this.shadow,
      warningSurface: warningSurface ?? this.warningSurface,
      warningBorder: warningBorder ?? this.warningBorder,
      warningText: warningText ?? this.warningText,
      modifiedSurface: modifiedSurface ?? this.modifiedSurface,
      modifiedBorder: modifiedBorder ?? this.modifiedBorder,
      modifiedText: modifiedText ?? this.modifiedText,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  FitLogThemeData lerp(ThemeExtension<FitLogThemeData>? other, double t) {
    if (other is! FitLogThemeData) {
      return this;
    }

    LinearGradient lerpGradient(LinearGradient a, LinearGradient b) {
      final count = a.colors.length < b.colors.length
          ? a.colors.length
          : b.colors.length;
      return LinearGradient(
        begin: AlignmentGeometry.lerp(a.begin, b.begin, t) ?? a.begin,
        end: AlignmentGeometry.lerp(a.end, b.end, t) ?? a.end,
        colors: <Color>[
          for (var i = 0; i < count; i++)
            Color.lerp(a.colors[i], b.colors[i], t) ?? a.colors[i],
        ],
      );
    }

    return copyWith(
      key: t < 0.5 ? key : other.key,
      pageGradient: lerpGradient(pageGradient, other.pageGradient),
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t),
      surface: Color.lerp(surface, other.surface, t),
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t),
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t),
      outline: Color.lerp(outline, other.outline, t),
      outlineSubtle: Color.lerp(outlineSubtle, other.outlineSubtle, t),
      primary: Color.lerp(primary, other.primary, t),
      primaryBright: Color.lerp(primaryBright, other.primaryBright, t),
      primaryDeep: Color.lerp(primaryDeep, other.primaryDeep, t),
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t),
      primarySoftPressed: Color.lerp(
        primarySoftPressed,
        other.primarySoftPressed,
        t,
      ),
      primarySoftSelected: Color.lerp(
        primarySoftSelected,
        other.primarySoftSelected,
        t,
      ),
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t),
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t),
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t),
      mutedText: Color.lerp(mutedText, other.mutedText, t),
      disabledText: Color.lerp(disabledText, other.disabledText, t),
      navBackground: Color.lerp(navBackground, other.navBackground, t),
      navIndicator: Color.lerp(navIndicator, other.navIndicator, t),
      navSelectedText: Color.lerp(navSelectedText, other.navSelectedText, t),
      navUnselectedText: Color.lerp(
        navUnselectedText,
        other.navUnselectedText,
        t,
      ),
      shadow: Color.lerp(shadow, other.shadow, t),
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t),
      warningBorder: Color.lerp(warningBorder, other.warningBorder, t),
      warningText: Color.lerp(warningText, other.warningText, t),
      modifiedSurface: Color.lerp(modifiedSurface, other.modifiedSurface, t),
      modifiedBorder: Color.lerp(modifiedBorder, other.modifiedBorder, t),
      modifiedText: Color.lerp(modifiedText, other.modifiedText, t),
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension FitLogThemeExtension on BuildContext {
  FitLogThemeData get fitLogTheme =>
      Theme.of(this).extension<FitLogThemeData>() ?? FitLogThemeData.green;
}
