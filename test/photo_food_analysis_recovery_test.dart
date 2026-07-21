import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fitlog_local/features/food/food_image_picker.dart';
import 'package:fitlog_local/features/food/photo_food_analysis_recovery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory recoveryDirectory;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    recoveryDirectory = Directory.systemTemp.createTempSync(
      'fitlog_photo_food_recovery_test_',
    );
    PhotoFoodAnalysisRecoveryStore.debugDirectoryOverride = recoveryDirectory;
    PhotoFoodAnalysisRecoveryStore.debugSkipImageWrites = false;
  });

  tearDown(() async {
    await PhotoFoodAnalysisRecoveryStore.clearPending();
    PhotoFoodAnalysisRecoveryStore.debugLoadImagesOverride = null;
    PhotoFoodAnalysisRecoveryStore.debugSkipImageWrites = false;
    PhotoFoodAnalysisRecoveryStore.debugDirectoryOverride = null;
    if (await recoveryDirectory.exists()) {
      await recoveryDirectory.delete(recursive: true);
    }
  });

  test(
    'live photo page owns recovery and blocks root duplicate push',
    () async {
      final coordinator = PhotoFoodAnalysisRecoveryCoordinator();
      final lease = coordinator.acquireOwner();
      var recoveryCount = 0;

      final recovered = await coordinator.runRootRecovery(() async {
        recoveryCount++;
      });

      expect(recovered, isFalse);
      expect(recoveryCount, 0);

      lease.release();
      expect(
        await coordinator.runRootRecovery(() async => recoveryCount++),
        isTrue,
      );
      expect(recoveryCount, 1);
    },
  );

  test('root photo recovery is single flight', () async {
    final coordinator = PhotoFoodAnalysisRecoveryCoordinator();
    final gate = Completer<void>();
    var recoveryCount = 0;

    final first = coordinator.runRootRecovery(() async {
      recoveryCount++;
      await gate.future;
    });
    final second = coordinator.runRootRecovery(() async {
      recoveryCount++;
    });

    expect(await second, isFalse);
    gate.complete();
    expect(await first, isTrue);
    expect(recoveryCount, 1);
  });

  test(
    'pending photo recovery stores images outside SharedPreferences',
    () async {
      final image = PickedFoodImage(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        mimeType: 'image/png',
        name: 'food.png',
      );

      await PhotoFoodAnalysisRecoveryStore.savePending(
        initialDate: '2026-07-01',
        note: '去皮鸡腿',
        images: <PickedFoodImage>[image],
        selectedImageIndex: 0,
      );

      final draft = await PhotoFoodAnalysisRecoveryStore.loadPending();
      expect(draft, isNotNull);
      expect(draft!.initialDate, '2026-07-01');
      expect(draft.note, '去皮鸡腿');
      expect(draft.selectedImageIndex, 0);
      expect(draft.images, hasLength(1));
      expect(await File(draft.images.single.path).exists(), isTrue);

      final restoredImages =
          await PhotoFoodAnalysisRecoveryStore.loadPendingImages(draft);
      expect(restoredImages.single.mimeType, 'image/png');
      expect(restoredImages.single.name, 'food.png');
      expect(restoredImages.single.bytes, <int>[1, 2, 3]);

      await PhotoFoodAnalysisRecoveryStore.clearPending();

      expect(await PhotoFoodAnalysisRecoveryStore.loadPending(), isNull);
      expect(await recoveryDirectory.list().toList(), isEmpty);
    },
  );
}
