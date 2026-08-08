import 'package:fitlog_local/core/theme/fitlog_theme.dart';
import 'package:fitlog_local/core/widgets/exercise_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('black theme exercise badge colors match the body-part palette', () {
    const expectedColors = <String, List<Color>>{
      'Chest': <Color>[Color(0xFF402824), Color(0xFF8B5A52)],
      'Back': <Color>[Color(0xFF27303D), Color(0xFF60718A)],
      'Legs': <Color>[Color(0xFF41341C), Color(0xFF9A7D40)],
      'Glutes': <Color>[Color(0xFFD66A3C), Color(0xFFF1A073)],
      'Shoulders': <Color>[Color(0xFF626A72), Color(0xFF9AA4AD)],
      'Arms': <Color>[Color(0xFF203838), Color(0xFF5D8989)],
      'Core': <Color>[Color(0xFF402830), Color(0xFF8B5A68)],
      'Cardio': <Color>[Color(0xFF21382D), Color(0xFF5F8B70)],
      'Full Body': <Color>[Color(0xFF68727E), Color(0xFFA0AABD)],
    };

    for (final entry in expectedColors.entries) {
      final style = ExerciseThumbnailBadgeStyle.resolve(
        bodyPart: entry.key,
        bodyPartColor: const Color(0xFFEF4444),
        fitLogTheme: FitLogThemeData.blackOrange,
        useDarkThemeBadgeColors: true,
      );

      expect(style.fillColor, entry.value[0], reason: '${entry.key} fill');
      expect(style.ringColor, entry.value[1], reason: '${entry.key} ring');
    }

    expect(
      expectedColors.values.map((colors) => colors[0]).toSet(),
      hasLength(expectedColors.length),
    );
    expect(
      expectedColors.values.map((colors) => colors[1]).toSet(),
      hasLength(expectedColors.length),
    );
  });

  test('non-black theme keeps the original translucent badge without ring', () {
    const bodyPartColor = Color(0xFFEF4444);

    final style = ExerciseThumbnailBadgeStyle.resolve(
      bodyPart: 'Chest',
      bodyPartColor: bodyPartColor,
      fitLogTheme: FitLogThemeData.green,
      useDarkThemeBadgeColors: true,
    );

    expect(style.fillColor, bodyPartColor.withValues(alpha: 0.14));
    expect(style.ringColor, isNull);
  });

  test(
    'black theme keeps original badge colors when dark badge is disabled',
    () {
      const bodyPartColor = Color(0xFF3B82F6);

      final style = ExerciseThumbnailBadgeStyle.resolve(
        bodyPart: 'Back',
        bodyPartColor: bodyPartColor,
        fitLogTheme: FitLogThemeData.blackOrange,
        useDarkThemeBadgeColors: false,
      );

      expect(style.fillColor, bodyPartColor.withValues(alpha: 0.14));
      expect(style.ringColor, isNull);
    },
  );
}
