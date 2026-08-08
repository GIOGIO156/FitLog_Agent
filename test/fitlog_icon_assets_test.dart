import 'dart:io';

import 'package:fitlog_local/core/constants/exercise_catalog.dart';
import 'package:fitlog_local/core/constants/fitlog_icon_assets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every built-in exercise key resolves to an existing dedicated PNG', () {
    for (final exercise in ExerciseCatalog.builtInExercises) {
      final asset = FitLogIconAssets.exerciseAssetForExerciseKey(exercise.key);

      expect(asset, isNotNull, reason: exercise.key);
      expect(asset, endsWith('.png'), reason: exercise.key);
      expect(
        File(asset!).existsSync(),
        isTrue,
        reason: '${exercise.key}: $asset',
      );
    }
  });

  test('built-in names and legacyNames resolve to the canonical PNG', () {
    for (final exercise in ExerciseCatalog.builtInExercises) {
      final canonicalAsset = FitLogIconAssets.exerciseAssetForExerciseKey(
        exercise.key,
      );

      expect(
        FitLogIconAssets.exerciseAssetForExercise(exercise.name),
        canonicalAsset,
        reason: exercise.name,
      );

      for (final legacyName in exercise.legacyNames) {
        expect(
          FitLogIconAssets.exerciseAssetForExercise(legacyName),
          canonicalAsset,
          reason: '${exercise.key}: $legacyName',
        );
      }
    }
  });

  test(
    'reviewed aliases resolve to the canonical PNG without catalog entries',
    () {
      for (final entry in ExerciseCatalog.reviewedAliasesByKey.entries) {
        final canonicalAsset = FitLogIconAssets.exerciseAssetForExerciseKey(
          entry.key,
        );

        for (final alias in entry.value) {
          expect(
            FitLogIconAssets.exerciseAssetForExercise(alias),
            canonicalAsset,
            reason: '${entry.key}: $alias',
          );
        }
      }
    },
  );

  test('bench press variants keep distinct dedicated images', () {
    final barbellFlat =
        '${FitLogIconAssets.exerciseDirectory}/barbell_flat_bench_press.png';
    final closeGrip =
        '${FitLogIconAssets.exerciseDirectory}/close_grip_bench_press.png';

    expect(
      FitLogIconAssets.exerciseAssetForExerciseKey('barbell_flat_bench_press'),
      barbellFlat,
    );
    expect(
      FitLogIconAssets.exerciseAssetForExercise('Bench Press'),
      barbellFlat,
    );
    expect(FitLogIconAssets.exerciseAssetForExercise('杠铃平板卧推'), barbellFlat);
    expect(FitLogIconAssets.exerciseAssetForExercise('杠铃卧推'), barbellFlat);
    expect(FitLogIconAssets.exerciseAssetForExercise('平板卧推'), barbellFlat);
    expect(
      FitLogIconAssets.exerciseAssetForExerciseKey('close_grip_bench_press'),
      closeGrip,
    );
    expect(
      FitLogIconAssets.exerciseAssetForExercise('Close-grip Bench Press'),
      closeGrip,
    );
    expect(FitLogIconAssets.exerciseAssetForExercise('杠铃窄距平板卧推'), closeGrip);
    expect(closeGrip, isNot(barbellFlat));
  });

  test(
    'barbell overhead press uses the shared overhead press PNG filename',
    () {
      final overhead =
          '${FitLogIconAssets.exerciseDirectory}/overhead_press.png';

      expect(
        FitLogIconAssets.exerciseAssetForExerciseKey('barbell_overhead_press'),
        overhead,
      );
      expect(
        FitLogIconAssets.exerciseAssetForExercise('Overhead Press'),
        overhead,
      );
    },
  );

  test('unknown exercises leave image selection to the body-part fallback', () {
    expect(FitLogIconAssets.exerciseAssetForExerciseKey('unknown_key'), isNull);
    expect(
      FitLogIconAssets.exerciseAssetForExercise('Custom Rope Press'),
      isNull,
    );
  });
}
