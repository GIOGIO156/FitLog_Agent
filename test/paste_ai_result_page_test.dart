import 'package:fitlog_local/app.dart';
import 'package:fitlog_local/core/constants/prompt_templates.dart';
import 'package:fitlog_local/core/localization/app_language.dart';
import 'package:fitlog_local/core/localization/language_controller.dart';
import 'package:fitlog_local/core/theme/fitlog_theme.dart';
import 'package:fitlog_local/core/widgets/fitlog_notifications.dart';
import 'package:fitlog_local/features/food/paste_ai_result_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });
  tearDown(FitLogNotifications.dismiss);

  testWidgets(
    'Paste AI Result explains reusable setup and copies the English prompt',
    (tester) async {
      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText =
                  (call.arguments as Map<Object?, Object?>)['text'] as String?;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<LanguageController>(
          create: (_) => LanguageController(),
          child: MaterialApp(
            theme: buildFitLogTheme(Brightness.light),
            home: const PasteAiResultPage(),
          ),
        ),
      );

      expect(
        find.text('Set up a reusable food-estimation chat'),
        findsOneWidget,
      );
      expect(find.text('One-time setup'), findsNothing);
      expect(find.text('How to use'), findsOneWidget);
      expect(
        find.text(
          'Send this Prompt once in a new chat; afterward, upload food photos or add descriptions, then paste the complete JSON response below for parsing.',
        ),
        findsOneWidget,
      );
      expect(find.text('Recommended GPTs'), findsOneWidget);
      expect(
        find.text(
          'For ChatGPT, we recommend “FitLog 中文助手” or “FitLog Estimator”.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('paste_copy_food_prompt_action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('paste_prompt_instruction_panel')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.forum_outlined), findsNothing);
      expect(find.byIcon(Icons.content_copy_rounded), findsOneWidget);
      expect(find.byIcon(Icons.copy_all_rounded), findsNothing);
      expect(find.text('Parse'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('paste_copy_food_prompt_action')),
      );
      await tester.pump();
      expect(copiedText, PromptTemplates.aiFoodPromptEn);
    },
  );

  testWidgets('Paste AI Result keeps the confirmed Chinese copy order', (
    tester,
  ) async {
    final languageController = LanguageController();
    await languageController.setLanguage(AppLanguage.chinese);
    addTearDown(languageController.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageController>.value(
        value: languageController,
        child: MaterialApp(
          theme: buildFitLogTheme(Brightness.light),
          home: const PasteAiResultPage(),
        ),
      ),
    );

    expect(find.text('建立长期食物估算对话'), findsOneWidget);
    expect(find.text('只需设置一次'), findsNothing);
    expect(find.byIcon(Icons.forum_outlined), findsNothing);
    expect(find.text('使用方式'), findsOneWidget);
    expect(
      find.text('在新对话中发送一次此 Prompt；之后只需上传食物图片或补充描述，再将返回的完整 JSON 粘贴到下方解析。'),
      findsOneWidget,
    );
    expect(find.text('推荐 GPT'), findsOneWidget);
    expect(
      find.text('推荐在 ChatGPT 中使用「FitLog 中文助手」或「FitLog Estimator」。'),
      findsOneWidget,
    );
    final usageTop = tester.getTopLeft(find.text('使用方式')).dy;
    final recommendationTop = tester.getTopLeft(find.text('推荐 GPT')).dy;
    expect(usageTop, lessThan(recommendationTop));
    expect(
      find.byKey(const ValueKey<String>('paste_prompt_instruction_panel')),
      findsOneWidget,
    );
    expect(find.text('复制 Prompt'), findsOneWidget);
  });

  testWidgets(
    'Paste AI Result keeps fixed geometry and follows keyboard inset once',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final languageController = LanguageController();
      addTearDown(languageController.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<LanguageController>.value(
          value: languageController,
          child: MaterialApp(
            theme: buildFitLogTheme(Brightness.light),
            home: const PasteAiResultPage(),
          ),
        ),
      );

      final editor = find.byKey(const ValueKey<String>('paste_json_editor'));
      final promptPanel = find.byKey(
        const ValueKey<String>('paste_prompt_instruction_panel'),
      );
      final parseButton = find.byKey(
        const ValueKey<String>('paste_ai_parse_button'),
      );
      final promptSlot = find.byKey(
        const ValueKey<String>('paste_prompt_supporting_slot'),
      );
      final parseSlot = find.byKey(
        const ValueKey<String>('paste_parse_supporting_slot'),
      );
      expect(promptPanel, findsOneWidget);
      expect(parseButton, findsOneWidget);
      final initialEditorRect = tester.getRect(editor);
      final initialPromptRect = tester.getRect(promptSlot);
      final initialActionRect = tester.getRect(parseSlot);
      final promptFade = find.byKey(
        const ValueKey<String>('paste_prompt_keyboard_fade'),
      );
      expect(tester.widget<Opacity>(promptFade).opacity, 1);
      final textField = tester.widget<TextField>(editor);
      final editorFocusNode = textField.focusNode;
      final editorController = textField.controller;

      await tester.tap(editor);
      await tester.pump();
      await tester.enterText(editor, '{"meal_name":"test"}');
      expect(editorFocusNode?.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);

      var previousTop = initialEditorRect.top;
      final editorTops = <double, double>{};
      final promptOpacities = <double, double>{};
      for (final inset in <double>[40, 52, 64, 80, 180, 336]) {
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        await tester.pump();

        expect(tester.takeException(), isNull);
        final currentRect = tester.getRect(editor);
        editorTops[inset] = currentRect.top;
        promptOpacities[inset] = tester.widget<Opacity>(promptFade).opacity;
        expect(currentRect.size, initialEditorRect.size);
        expect(currentRect.top, lessThanOrEqualTo(previousTop));
        expect(currentRect.bottom, lessThanOrEqualTo(844 - inset - 12));
        expect(tester.getRect(promptSlot), initialPromptRect);
        expect(tester.getRect(parseSlot), initialActionRect);
        expect(
          tester
              .widget<IgnorePointer>(
                find.byKey(
                  const ValueKey<String>('paste_prompt_keyboard_guard'),
                ),
              )
              .ignoring,
          isTrue,
        );
        previousTop = currentRect.top;
      }

      expect(promptPanel, findsOneWidget);
      expect(parseButton, findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(promptOpacities[40], allOf(greaterThan(0), lessThan(1)));
      expect(promptOpacities[80], lessThan(promptOpacities[40]!));
      expect(promptOpacities[80], greaterThan(0));
      expect(promptOpacities[180], 0);
      expect(promptOpacities[336], 0);
      expect(
        find.descendant(of: parseSlot, matching: find.byType(Opacity)),
        findsNothing,
      );
      expect(
        tester
            .widget<IgnorePointer>(
              find.byKey(const ValueKey<String>('paste_action_keyboard_guard')),
            )
            .ignoring,
        isTrue,
      );
      expect(editorTops[40], initialEditorRect.top);
      expect(
        initialEditorRect.top - editorTops[52]!,
        moreOrLessEquals(3, epsilon: 0.1),
      );
      expect(
        initialEditorRect.top - editorTops[64]!,
        moreOrLessEquals(12, epsilon: 0.1),
      );

      for (final inset in <double>[180, 80, 0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        await tester.pump();

        final currentRect = tester.getRect(editor);
        expect(currentRect.size, initialEditorRect.size);
        expect(currentRect.top, greaterThanOrEqualTo(previousTop));
        expect(tester.getRect(promptSlot), initialPromptRect);
        expect(tester.getRect(parseSlot), initialActionRect);
        previousTop = currentRect.top;
      }

      expect(tester.getRect(editor), initialEditorRect);
      expect(tester.widget<Opacity>(promptFade).opacity, 1);
      expect(editorFocusNode?.hasFocus, isTrue);
      expect(editorController?.text, '{"meal_name":"test"}');

      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      await tester.pump();
      final repeatedOpenRect = tester.getRect(editor);
      tester.view.viewInsets = const FakeViewPadding(bottom: 0);
      await tester.pump();
      expect(tester.getRect(editor), initialEditorRect);
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      await tester.pump();
      expect(tester.getRect(editor), repeatedOpenRect);
      expect(editorController?.text, '{"meal_name":"test"}');
    },
  );

  testWidgets('Paste AI Result remains bounded on a short viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final languageController = LanguageController();
    addTearDown(languageController.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageController>.value(
        value: languageController,
        child: MaterialApp(
          theme: buildFitLogTheme(Brightness.light),
          home: const PasteAiResultPage(),
        ),
      ),
    );

    final editor = find.byKey(const ValueKey<String>('paste_json_editor'));
    final initialSize = tester.getSize(editor);
    expect(initialSize.height, greaterThan(0));
    expect(tester.takeException(), isNull);

    await tester.tap(editor);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump();

    expect(tester.getSize(editor), initialSize);
    expect(tester.getRect(editor).bottom, lessThanOrEqualTo(600 - 280 - 12));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'expanded JSON waits for keyboard close and returns edited text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final languageController = LanguageController();
      addTearDown(languageController.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<LanguageController>.value(
          value: languageController,
          child: MaterialApp(
            theme: buildFitLogTheme(
              Brightness.light,
              themeKey: FitLogThemeKey.blackOrange,
            ),
            home: const PasteAiResultPage(),
          ),
        ),
      );

      final compactEditor = find.byKey(
        const ValueKey<String>('paste_json_editor'),
      );
      final expandButton = find.byKey(
        const ValueKey<String>('paste_expand_json_editor'),
      );
      expect(
        find.descendant(
          of: expandButton,
          matching: find.byIcon(Icons.fullscreen_rounded),
        ),
        findsOneWidget,
      );
      final expandButtonWidget = tester.widget<IconButton>(expandButton);
      expect(expandButtonWidget.iconSize, 21);
      expect(
        expandButtonWidget.style?.foregroundColor?.resolve(<WidgetState>{}),
        FitLogThemeData.blackOrange.textSecondary,
      );
      expect(
        expandButtonWidget.style?.backgroundColor?.resolve(<WidgetState>{}),
        FitLogThemeData.blackOrange.surfaceVariant.withValues(alpha: 0.56),
      );
      await tester.tap(compactEditor);
      await tester.enterText(compactEditor, '{"meal_name":"before"}');
      final compactField = tester.widget<TextField>(compactEditor);
      compactField.controller!.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 8,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      await tester.pump();

      tester
          .widget<IconButton>(
            find.byKey(const ValueKey<String>('paste_expand_json_editor')),
          )
          .onPressed!
          .call();
      await tester.pump();

      expect(compactField.focusNode?.hasFocus, isFalse);
      expect(
        find.byKey(const ValueKey<String>('paste_expanded_json_modal')),
        findsNothing,
      );

      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      await tester.pumpAndSettle();

      final modal = find.byKey(
        const ValueKey<String>('paste_expanded_json_modal'),
      );
      final expandedEditor = find.byKey(
        const ValueKey<String>('paste_expanded_json_field'),
      );
      expect(modal, findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('fitlog_modal_backdrop_filter')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: modal,
          matching: find.byKey(
            const ValueKey<String>('paste_prompt_instruction_panel'),
          ),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: modal,
          matching: find.byKey(const ValueKey<String>('paste_ai_parse_button')),
        ),
        findsNothing,
      );
      final expandedField = tester.widget<TextField>(expandedEditor);
      expect(expandedField.controller?.text, '{"meal_name":"before"}');
      expect(
        expandedField.controller?.selection,
        const TextSelection(baseOffset: 2, extentOffset: 8),
      );
      expect(expandedField.focusNode?.hasFocus, isFalse);
      final collapseButton = find.byKey(
        const ValueKey<String>('paste_collapse_json_editor'),
      );
      expect(
        find.descendant(
          of: collapseButton,
          matching: find.byIcon(Icons.fullscreen_exit_rounded),
        ),
        findsOneWidget,
      );
      expect(tester.widget<IconButton>(collapseButton).iconSize, 21);

      await tester.tap(expandedEditor);
      await tester.enterText(expandedEditor, '{"meal_name":"after"}');
      await tester.tap(
        find.byKey(const ValueKey<String>('paste_collapse_json_editor')),
      );
      await tester.pumpAndSettle();

      expect(modal, findsNothing);
      expect(compactField.controller?.text, '{"meal_name":"after"}');
    },
  );
}
