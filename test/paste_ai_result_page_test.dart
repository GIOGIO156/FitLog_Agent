import 'package:fitlog_local/app.dart';
import 'package:fitlog_local/core/constants/prompt_templates.dart';
import 'package:fitlog_local/core/localization/app_language.dart';
import 'package:fitlog_local/core/localization/language_controller.dart';
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

  testWidgets('Paste AI Result scrolls only while the keyboard is visible', (
    tester,
  ) async {
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

    final editor = find.byType(TextField);
    await tester.tap(editor);
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 220));

    expect(tester.takeException(), isNull);
    expect(tester.getRect(editor).top, lessThan(844 - 336 - 24));

    final position = tester
        .widget<SingleChildScrollView>(
          find.byKey(const ValueKey<String>('paste_ai_result_scroll')),
        )
        .controller!
        .position;
    expect(position.pixels, greaterThan(0));

    tester.view.viewInsets = const FakeViewPadding(bottom: 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 220));
    expect(MediaQuery.viewInsetsOf(tester.element(editor)).bottom, 0);
    final closedScroll = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey<String>('paste_ai_result_scroll')),
    );
    expect(closedScroll.physics, isA<NeverScrollableScrollPhysics>());
    final closedPosition = closedScroll.controller!.position;
    expect(closedPosition.maxScrollExtent, 0);
    expect(closedPosition.pixels, 0);

    await tester.drag(
      find.byKey(const ValueKey<String>('paste_ai_result_scroll')),
      const Offset(0, -120),
    );
    await tester.pump();
    expect(closedPosition.pixels, 0);
  });
}
