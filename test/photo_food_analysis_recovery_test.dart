import 'dart:async';

import 'package:fitlog_local/features/food/photo_food_analysis_recovery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
