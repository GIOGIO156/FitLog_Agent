import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fitlog_local/core/localization/language_controller.dart';
import 'package:fitlog_local/data/db/app_database.dart';
import 'package:fitlog_local/data/remote/ai_food_photo_analysis_client.dart';
import 'package:fitlog_local/data/repositories/ai_local_context_permission_repository.dart';
import 'package:fitlog_local/data/repositories/auth_repository.dart';
import 'package:fitlog_local/data/repositories/cloud_profile_repository.dart';
import 'package:fitlog_local/data/repositories/profile_repository.dart';
import 'package:fitlog_local/data/repositories/subscription_repository.dart';
import 'package:fitlog_local/domain/models/ai_food_photo_analysis.dart';
import 'package:fitlog_local/domain/models/ai_gateway_error.dart';
import 'package:fitlog_local/domain/models/ai_gateway_request.dart';
import 'package:fitlog_local/domain/models/auth_session.dart';
import 'package:fitlog_local/domain/models/cloud_profile.dart';
import 'package:fitlog_local/domain/models/cloud_runtime_context.dart';
import 'package:fitlog_local/domain/models/subscription_status.dart';
import 'package:fitlog_local/domain/models/user_profile.dart';
import 'package:fitlog_local/features/account/account_controller.dart';
import 'package:fitlog_local/features/food/food_image_picker.dart';
import 'package:fitlog_local/features/food/photo_food_analysis_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('photo analysis submit is disabled until an image is selected', (
    tester,
  ) async {
    final harness = _PhotoHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildPhotoTestApp(harness));

    final submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('photo_food_submit_button')),
    );
    expect(submit.onPressed, isNull);
  });

  testWidgets('selected image shows preview and enables submit', (
    tester,
  ) async {
    final harness = _PhotoHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildPhotoTestApp(harness));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('photo_food_gallery_button')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('photo_food_preview_image')),
      findsOneWidget,
    );
    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('photo_food_selected_image_0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('photo_food_remove_image_0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('photo_food_remove_button')),
      findsNothing,
    );
    final submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('photo_food_submit_button')),
    );
    expect(submit.onPressed, isNotNull);
  });

  testWidgets(
    'thumbnail keeps the three-image size when only one is selected',
    (tester) async {
      final harness = _PhotoHarness();
      addTearDown(harness.dispose);

      await tester.pumpWidget(_buildPhotoTestApp(harness));
      await _tapVisible(
        tester,
        find.byKey(const ValueKey<String>('photo_food_gallery_button')),
      );
      await tester.pump();

      final previewSize = tester.getSize(
        find.byKey(const ValueKey<String>('photo_food_preview_image')),
      );
      final thumbnailSize = tester.getSize(
        find.byKey(const ValueKey<String>('photo_food_selected_image_0')),
      );

      expect(thumbnailSize.width, lessThan(previewSize.width / 2));
      expect(thumbnailSize.width, closeTo(thumbnailSize.height, 0.1));
    },
  );

  testWidgets(
    'request payload includes the optional note and blocks duplicates',
    (tester) async {
      final harness = _PhotoHarness();
      final completer = Completer<AiFoodPhotoAnalysisResponse>();
      harness.client.handler = (_) => completer.future;
      addTearDown(harness.dispose);

      await tester.pumpWidget(_buildPhotoTestApp(harness));
      await _tapVisible(
        tester,
        find.byKey(const ValueKey<String>('photo_food_gallery_button')),
      );
      await tester.pump();
      await _scrollUntilVisible(
        tester,
        find.byKey(const ValueKey<String>('photo_food_note_field')),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('photo_food_note_field')),
        '米饭只吃了一半',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('photo_food_submit_button')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('photo_food_submit_button')),
      );
      await tester.pump();

      expect(harness.client.requests, hasLength(1));
      expect(harness.client.requests.single.userNote, '米饭只吃了一半');
      expect(harness.client.requests.single.images, hasLength(1));
      expect(find.text('Analyzing...'), findsWidgets);

      completer.complete(_successResponse());
    },
  );

  testWidgets('failure keeps selected image and note for retry', (
    tester,
  ) async {
    final harness = _PhotoHarness();
    harness.client.handler = (_) async {
      return const AiFoodPhotoAnalysisResponse(
        error: AiGatewayError(
          code: AiGatewayErrorCode.providerFailure,
          rawCode: 'provider_failure',
        ),
      );
    };
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildPhotoTestApp(harness));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('photo_food_gallery_button')),
    );
    await tester.pump();
    await _scrollUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('photo_food_note_field')),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('photo_food_note_field')),
      '去皮鸡腿',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('photo_food_submit_button')),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('photo_food_preview_image')),
      findsOneWidget,
    );
    expect(find.text('去皮鸡腿'), findsOneWidget);
    expect(
      find.text('AI provider could not answer. Try again later.'),
      findsOneWidget,
    );
  });

  testWidgets('success pushes the FoodPreviewPage with a parsed draft', (
    tester,
  ) async {
    final harness = _PhotoHarness();
    harness.client.handler = (_) async => _successResponse();
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildPhotoTestApp(harness));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('photo_food_gallery_button')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('photo_food_submit_button')),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Preview AI Result'), findsOneWidget);
    expect(find.text('Chicken rice'), findsOneWidget);
  });

  testWidgets('gallery selection can add up to three images in one pick', (
    tester,
  ) async {
    final harness = _PhotoHarness();
    harness.picker.multiImages = <PickedFoodImage>[
      harness.picker.image,
      PickedFoodImage(
        bytes: _onePixelPng,
        mimeType: 'image/png',
        name: 'food-2.png',
      ),
      PickedFoodImage(
        bytes: _onePixelPng,
        mimeType: 'image/png',
        name: 'food-3.png',
      ),
    ];
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildPhotoTestApp(harness));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('photo_food_gallery_button')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('photo_food_submit_button')),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('photo_food_preview_image')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('photo_food_preview_image_2')),
      findsOneWidget,
    );
    expect(harness.client.requests.single.images, hasLength(3));
  });

  testWidgets('thumbnail taps switch the enlarged preview image', (
    tester,
  ) async {
    final harness = _PhotoHarness();
    final secondBytes = Uint8List.fromList(_onePixelPng);
    final thirdBytes = Uint8List.fromList(_onePixelPng);
    harness.picker.multiImages = <PickedFoodImage>[
      harness.picker.image,
      PickedFoodImage(
        bytes: secondBytes,
        mimeType: 'image/png',
        name: 'food-2.png',
      ),
      PickedFoodImage(
        bytes: thirdBytes,
        mimeType: 'image/png',
        name: 'food-3.png',
      ),
    ];
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildPhotoTestApp(harness));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('photo_food_gallery_button')),
    );
    await tester.pump();

    var mainPreview = tester.widget<Image>(
      find.byKey(const ValueKey<String>('photo_food_preview_image')),
    );
    expect((mainPreview.image as MemoryImage).bytes, same(thirdBytes));
    expect(
      find.byKey(const ValueKey<String>('photo_food_selected_image_2')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('photo_food_select_image_1')),
    );
    await tester.pump();

    mainPreview = tester.widget<Image>(
      find.byKey(const ValueKey<String>('photo_food_preview_image')),
    );
    expect((mainPreview.image as MemoryImage).bytes, same(secondBytes));
    expect(
      find.byKey(const ValueKey<String>('photo_food_selected_image_1')),
      findsOneWidget,
    );
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

Widget _buildPhotoTestApp(_PhotoHarness harness) {
  return ChangeNotifierProvider<LanguageController>(
    create: (_) => LanguageController(),
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider<CloudRuntimeContext>.value(
          value: harness.runtimeContext,
        ),
        ChangeNotifierProvider<AccountController>.value(
          value: harness.accountController,
        ),
      ],
      child: MaterialApp(
        home: PhotoFoodAnalysisPage(
          initialDate: '2026-07-01',
          imagePicker: harness.picker,
          analysisClient: harness.client,
        ),
      ),
    ),
  );
}

class _PhotoHarness {
  _PhotoHarness() {
    runtimeContext.bind(
      accountId: 'acct_1',
      deviceId: 'device-a',
      sessionId: 'session-a',
    );
    accountController
      ..authSession = const AuthSession(
        status: AuthSessionStatus.signedIn,
        accountId: 'acct_1',
        sessionId: 'session-a',
        displayName: 'Tester',
      )
      ..subscriptionStatus = const SubscriptionStatus(
        state: SubscriptionState.active,
      )
      ..cloudProfileState = const CloudProfileState(
        status: CloudProfileStatus.ready,
        cloudProfile: CloudProfile(
          accountId: 'acct_1',
          profile: UserProfile.defaults,
          profileVersion: 7,
        ),
      );
  }

  final CloudRuntimeContext runtimeContext = CloudRuntimeContext();
  late final AccountController accountController = AccountController(
    authRepository: const UnconfiguredAuthRepository(),
    subscriptionRepository: const UnconfiguredSubscriptionRepository(),
    cloudProfileRepository: const UnconfiguredCloudProfileRepository(),
    profileRepository: ProfileRepository(AppDatabase.instance),
    contextPermissionRepository: const AiLocalContextPermissionRepository(),
    cloudRuntimeContext: runtimeContext,
    backendConfigured: true,
  );
  final _FakeFoodImagePicker picker = _FakeFoodImagePicker();
  final _FakePhotoAnalysisClient client = _FakePhotoAnalysisClient();

  void dispose() {
    accountController.dispose();
    runtimeContext.dispose();
  }
}

class _FakeFoodImagePicker extends FoodImagePicker {
  _FakeFoodImagePicker();

  final PickedFoodImage image = PickedFoodImage(
    bytes: _onePixelPng,
    mimeType: 'image/png',
    name: 'food.png',
  );
  List<PickedFoodImage>? multiImages;

  @override
  Future<PickedFoodImage?> pick(FoodImageSource source) async {
    return image;
  }

  @override
  Future<List<PickedFoodImage>> pickMultiple(
    FoodImageSource source, {
    required int limit,
  }) async {
    final images = multiImages ?? <PickedFoodImage>[image];
    return images.take(limit).toList(growable: false);
  }
}

class _FakePhotoAnalysisClient extends AiFoodPhotoAnalysisClient {
  final requests = <AiFoodPhotoAnalysisRequest>[];
  Future<AiFoodPhotoAnalysisResponse> Function(
    AiFoodPhotoAnalysisRequest request,
  )?
  handler;

  @override
  Future<AiFoodPhotoAnalysisResponse> analyze(
    AiFoodPhotoAnalysisRequest request,
  ) {
    requests.add(request);
    return handler?.call(request) ?? Future.value(_successResponse());
  }
}

AiFoodPhotoAnalysisResponse _successResponse() {
  return const AiFoodPhotoAnalysisResponse(
    modelChoice: AiGatewayModelChoice.qwen,
    modelProvider: 'qwen',
    draft: AiFoodDraft(
      mealName: 'Chicken rice',
      totalWeightG: 320,
      caloriesKcal: 520,
      proteinG: 32,
      carbsG: 62,
      fatG: 14,
      confidence: 0.72,
      estimationNotes: 'Estimated from visible plate.',
      items: <AiFoodDraftItem>[
        AiFoodDraftItem(
          name: 'Chicken',
          weightG: 120,
          caloriesKcal: 220,
          proteinG: 28,
          carbsG: 0,
          fatG: 10,
        ),
      ],
    ),
  );
}

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
);
