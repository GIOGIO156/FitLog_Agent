import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fitlog_local/core/localization/language_controller.dart';
import 'package:fitlog_local/core/widgets/glass_panel.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

MemoryImage _memoryImage(ImageProvider<Object> provider) {
  final resolved = provider is ResizeImage ? provider.imageProvider : provider;
  return resolved as MemoryImage;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('photo analysis submit is disabled until image or description', (
    tester,
  ) async {
    final harness = _PhotoHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildPhotoTestApp(harness));

    final submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('photo_food_submit_button')),
    );
    expect(submit.onPressed, isNull);

    await _scrollUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('photo_food_note_field')),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('photo_food_note_field')),
      '100g salmon',
    );
    await tester.pump();

    final enabledSubmit = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('photo_food_submit_button')),
    );
    expect(enabledSubmit.onPressed, isNotNull);
  });

  testWidgets('photo controls keep clear of the fixed analysis action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = _PhotoHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildPhotoTestApp(harness));
    final modelFinder = find.byKey(
      const ValueKey<String>('photo_food_model_choice'),
    );
    final previewFinder = find.byKey(
      const ValueKey<String>('photo_food_preview_action'),
    );
    expect(
      find.text(
        'FitLog AI estimates a draft from your description and up to 3 optional food images. Review and save on the next page.',
      ),
      findsNothing,
    );
    expect(
      tester.getTopLeft(modelFinder).dy,
      lessThan(tester.getTopLeft(previewFinder).dy),
    );
    expect(
      find.ancestor(of: modelFinder, matching: find.byType(GlassPanel)),
      findsNothing,
    );

    final noteFinder = find.byKey(
      const ValueKey<String>('photo_food_note_field'),
    );
    await _scrollUntilVisible(tester, noteFinder);
    final submitFinder = find.byKey(
      const ValueKey<String>('photo_food_submit_button'),
    );
    expect(
      tester.getRect(noteFinder).bottom,
      lessThanOrEqualTo(tester.getRect(submitFinder).top - 12),
    );
    final shieldFinder = find.byKey(
      const ValueKey<String>('photo_food_submit_shield'),
    );
    expect(shieldFinder, findsOneWidget);
    expect(
      tester.getSize(shieldFinder).width,
      closeTo(tester.getSize(submitFinder).width, 0.1),
    );
    expect(
      tester.getTopLeft(shieldFinder).dy,
      closeTo(tester.getCenter(submitFinder).dy, 0.1),
    );
  });

  testWidgets('food note follows keyboard while submit action stays fixed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.reset);
    final harness = _PhotoHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildPhotoTestApp(harness));
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).resizeToAvoidBottomInset,
      isFalse,
    );
    final initialListPadding = tester
        .widget<ListView>(find.byType(ListView))
        .padding;
    final noteFinder = find.byKey(
      const ValueKey<String>('photo_food_note_field'),
    );
    await _scrollUntilVisible(tester, noteFinder);
    final noteFocusNode = tester.widget<TextField>(noteFinder).focusNode;
    await tester.tap(noteFinder);
    await tester.pump();
    final restingNoteRect = tester.getRect(noteFinder);
    final submitFinder = find.byKey(
      const ValueKey<String>('photo_food_submit_button'),
    );
    final restingSubmitRect = tester.getRect(submitFinder);
    final restingListOffset = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;

    tester.view.padding = FakeViewPadding.zero;
    tester.view.viewInsets = const FakeViewPadding(bottom: 80);
    await tester.pump();
    final noteAt80 = tester.getRect(noteFinder);
    final submitAt80 = tester.getRect(submitFinder);

    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pump();
    final noteAt180 = tester.getRect(noteFinder);
    final submitAt180 = tester.getRect(submitFinder);

    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    await tester.pump();
    final noteAt336 = tester.getRect(noteFinder);
    final submitAt336 = tester.getRect(submitFinder);

    expect(
      find.byKey(const ValueKey<String>('photo_food_submit_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('photo_food_submit_shield')),
      findsOneWidget,
    );
    final submitGuardFinder = find.byKey(
      const ValueKey<String>('photo_food_submit_keyboard_guard'),
    );
    expect(tester.widget<IgnorePointer>(submitGuardFinder).ignoring, isTrue);
    expect(
      tester.widget<ListView>(find.byType(ListView)).padding,
      initialListPadding,
    );
    expect(tester.widget<TextField>(noteFinder).focusNode, same(noteFocusNode));
    expect(noteFocusNode?.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(noteAt80.size, restingNoteRect.size);
    expect(noteAt180.size, restingNoteRect.size);
    expect(noteAt336.size, restingNoteRect.size);
    expect(noteAt80.top, greaterThanOrEqualTo(noteAt180.top));
    expect(noteAt180.top, greaterThanOrEqualTo(noteAt336.top));
    expect(noteAt336.bottom, lessThanOrEqualTo(844 - 336 - 12 + 0.1));
    expect(submitAt80, restingSubmitRect);
    expect(submitAt180, restingSubmitRect);
    expect(submitAt336, restingSubmitRect);
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      restingListOffset,
    );
    expect(
      tester.widget<ListView>(find.byType(ListView)).padding,
      initialListPadding,
    );

    tester.view.padding = const FakeViewPadding(bottom: 24);
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('photo_food_submit_button')),
      findsOneWidget,
    );
    expect(tester.getRect(submitFinder), restingSubmitRect);
    expect(tester.widget<IgnorePointer>(submitGuardFinder).ignoring, isFalse);
    expect(tester.getRect(noteFinder), restingNoteRect);
    expect(tester.widget<TextField>(noteFinder).focusNode, same(noteFocusNode));
  });

  testWidgets('first keyboard drag dismisses focus without moving the page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = _PhotoHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildPhotoTestApp(harness));
    final noteFinder = find.byKey(
      const ValueKey<String>('photo_food_note_field'),
    );
    await _scrollUntilVisible(tester, noteFinder);
    await tester.tap(noteFinder);
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    await tester.pump();

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final initialOffset = scrollable.position.pixels;
    final focusNode = tester.widget<TextField>(noteFinder).focusNode!;
    expect(focusNode.hasFocus, isTrue);

    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
    expect(scrollable.position.pixels, initialOffset);

    tester.view.viewInsets = const FakeViewPadding(bottom: 0);
    await tester.pump();
  });

  testWidgets('photo ChatGPT choice slides back to Qwen without a request', (
    tester,
  ) async {
    final harness = _PhotoHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildPhotoTestApp(harness));
    await _scrollUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('photo_food_note_field')),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('photo_food_note_field')),
      '100g salmon',
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, 600));
    await tester.pump(const Duration(milliseconds: 220));
    final chatGptChoice = find.byKey(
      const ValueKey<String>('photo_food_provider_chatgpt'),
    );
    await tester.ensureVisible(chatGptChoice);
    await tester.pump();
    await tester.tap(chatGptChoice);
    await tester.pump();
    expect(find.text('The current model is unavailable.'), findsOneWidget);
    expect(
      tester
          .widget<AnimatedPositioned>(
            find.byKey(const ValueKey<String>('photo_food_model_indicator')),
          )
          .left,
      3,
    );
    expect(harness.client.requests, isEmpty);

    await tester.pump(const Duration(milliseconds: 240));
    expect(
      tester
          .widget<AnimatedPositioned>(
            find.byKey(const ValueKey<String>('photo_food_model_indicator')),
          )
          .left,
      greaterThan(3),
    );
    await tester.pump(const Duration(milliseconds: 240));

    expect(harness.client.requests, isEmpty);
    expect(
      tester
          .widget<TextField>(
            find.byKey(
              const ValueKey<String>('photo_food_note_field'),
              skipOffstage: false,
            ),
          )
          .controller
          ?.text,
      '100g salmon',
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('photo_food_ai_model_choice_v1'), 'qwen');
    expect(find.text('The current model is unavailable.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('The current model is unavailable.'), findsNothing);
  });

  testWidgets('selected image shows preview and enables submit', (
    tester,
  ) async {
    final harness = _PhotoHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildPhotoTestApp(harness));
    expect(
      find.byKey(const ValueKey<String>('photo_food_preview_add_icon')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('photo_food_empty_slot_0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('photo_food_empty_slot_2')),
      findsOneWidget,
    );
    await _pickFromGallery(tester);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('photo_food_preview_image')),
      findsOneWidget,
    );
    expect(find.text('Photo'), findsNothing);
    expect(find.text('Gallery'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('photo_food_preview_add_icon')),
      findsOneWidget,
    );
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
      await _pickFromGallery(tester);
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
      await _pickFromGallery(tester);
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
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey<String>('photo_food_submit_button')),
            )
            .onPressed,
        isNull,
      );

      expect(harness.client.requests, hasLength(1));
      expect(harness.client.requests.single.userNote, '米饭只吃了一半');
      expect(harness.client.requests.single.images, hasLength(1));
      expect(find.text('Analyzing...'), findsWidgets);

      completer.complete(_successResponse());
    },
  );

  testWidgets('description-only input submits without images', (tester) async {
    final harness = _PhotoHarness();
    harness.client.handler = (_) async => _successResponse();
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildPhotoTestApp(harness));
    await _scrollUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('photo_food_note_field')),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('photo_food_note_field')),
      '100g 三文鱼',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('photo_food_submit_button')),
    );
    await tester.pump();
    await tester.pump();

    expect(harness.client.requests.single.images, isEmpty);
    expect(harness.client.requests.single.userNote, '100g 三文鱼');
    expect(find.text('Preview AI Result'), findsOneWidget);
  });

  testWidgets('restored photo draft keeps recovered image and note', (
    tester,
  ) async {
    final harness = _PhotoHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      _buildPhotoTestApp(
        harness,
        initialNote: '100g salmon',
        initialImages: <PickedFoodImage>[harness.picker.image],
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('photo_food_preview_image')),
      findsOneWidget,
    );
    await _scrollUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('photo_food_note_field')),
    );
    expect(find.text('100g salmon'), findsOneWidget);
    final submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('photo_food_submit_button')),
    );
    expect(submit.onPressed, isNotNull);
  });

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
    await _pickFromGallery(tester);
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
    await _pickFromGallery(tester);
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
    await _pickFromGallery(tester);
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
    await _pickFromGallery(tester);
    await tester.pump();

    var mainPreview = tester.widget<Image>(
      find.byKey(const ValueKey<String>('photo_food_preview_image')),
    );
    expect(_memoryImage(mainPreview.image).bytes, same(thirdBytes));
    expect(
      find.byKey(const ValueKey<String>('photo_food_selected_image_2')),
      findsOneWidget,
    );

    tester
        .widget<InkWell>(
          find.byKey(const ValueKey<String>('photo_food_select_image_1')),
        )
        .onTap!
        .call();
    await tester.pump();

    mainPreview = tester.widget<Image>(
      find.byKey(const ValueKey<String>('photo_food_preview_image')),
    );
    expect(_memoryImage(mainPreview.image).bytes, same(secondBytes));
    expect(
      find.byKey(const ValueKey<String>('photo_food_selected_image_1')),
      findsOneWidget,
    );
  });

  testWidgets('preview can add more images and requests only free slots', (
    tester,
  ) async {
    final harness = _PhotoHarness();
    harness.picker.queuedSelections.addAll(<List<PickedFoodImage>>[
      <PickedFoodImage>[harness.picker.image],
      <PickedFoodImage>[
        PickedFoodImage(
          bytes: Uint8List.fromList(_onePixelPng),
          mimeType: 'image/png',
          name: 'food-2.png',
        ),
        PickedFoodImage(
          bytes: Uint8List.fromList(_onePixelPng),
          mimeType: 'image/png',
          name: 'food-3.png',
        ),
      ],
    ]);
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildPhotoTestApp(harness));
    await _pickFromGallery(tester);
    await _pickFromGallery(tester);

    expect(harness.picker.requestedLimits, <int>[3, 2]);
    expect(
      find.byKey(const ValueKey<String>('photo_food_selected_image_2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('photo_food_empty_slot_2')),
      findsNothing,
    );
  });

  testWidgets('full preview replaces the selected image instead of adding', (
    tester,
  ) async {
    final harness = _PhotoHarness();
    final replacement = PickedFoodImage(
      bytes: Uint8List.fromList(_onePixelPng),
      mimeType: 'image/png',
      name: 'replacement.png',
    );
    harness.picker.queuedSelections.addAll(<List<PickedFoodImage>>[
      <PickedFoodImage>[
        harness.picker.image,
        PickedFoodImage(
          bytes: Uint8List.fromList(_onePixelPng),
          mimeType: 'image/png',
          name: 'food-2.png',
        ),
        PickedFoodImage(
          bytes: Uint8List.fromList(_onePixelPng),
          mimeType: 'image/png',
          name: 'food-3.png',
        ),
      ],
      <PickedFoodImage>[replacement],
    ]);
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildPhotoTestApp(harness));
    await _pickFromGallery(tester);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('photo_food_preview_action')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Replace selected photo'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('photo_food_gallery_button')),
    );
    await tester.pumpAndSettle();

    expect(harness.picker.requestedLimits, <int>[3, 1]);
    expect(
      find.byKey(const ValueKey<String>('photo_food_preview_image_2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('photo_food_empty_slot_2')),
      findsNothing,
    );
  });

  testWidgets('picker overflow is rejected instead of silently truncated', (
    tester,
  ) async {
    final harness = _PhotoHarness();
    harness.picker.queuedSelections.add(<PickedFoodImage>[
      harness.picker.image,
      PickedFoodImage(
        bytes: Uint8List.fromList(_onePixelPng),
        mimeType: 'image/png',
        name: 'food-2.png',
      ),
      PickedFoodImage(
        bytes: Uint8List.fromList(_onePixelPng),
        mimeType: 'image/png',
        name: 'food-3.png',
      ),
      PickedFoodImage(
        bytes: Uint8List.fromList(_onePixelPng),
        mimeType: 'image/png',
        name: 'food-4.png',
      ),
    ]);
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildPhotoTestApp(harness));
    await _pickFromGallery(tester);

    expect(
      find.byKey(const ValueKey<String>('photo_food_preview_image')),
      findsNothing,
    );
    expect(
      find.text('Select no more than the remaining photo slots.'),
      findsOneWidget,
    );
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Future<void> _pickFromGallery(WidgetTester tester) async {
  await _tapVisible(
    tester,
    find.byKey(const ValueKey<String>('photo_food_preview_action')),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey<String>('photo_food_gallery_button')),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

Widget _buildPhotoTestApp(
  _PhotoHarness harness, {
  String? initialNote,
  List<PickedFoodImage> initialImages = const <PickedFoodImage>[],
}) {
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
          initialNote: initialNote,
          initialImages: initialImages,
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
  final List<List<PickedFoodImage>> queuedSelections =
      <List<PickedFoodImage>>[];
  final List<int> requestedLimits = <int>[];

  @override
  Future<PickedFoodImage?> pick(FoodImageSource source) async {
    return image;
  }

  @override
  Future<List<PickedFoodImage>> pickMultiple(
    FoodImageSource source, {
    required int limit,
  }) async {
    requestedLimits.add(limit);
    if (queuedSelections.isNotEmpty) {
      return queuedSelections.removeAt(0);
    }
    final images = multiImages ?? <PickedFoodImage>[image];
    return images;
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
      date: '2026-07-01',
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
        AiFoodDraftItem(
          name: 'Rice',
          weightG: 200,
          caloriesKcal: 300,
          proteinG: 4,
          carbsG: 62,
          fatG: 4,
        ),
      ],
    ),
  );
}

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
);
