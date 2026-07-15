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
      expect(find.text('One-time setup'), findsOneWidget);
      expect(
        find.text(
          'Send this prompt once in a new chat; afterward, upload food photos or add descriptions, then paste the complete JSON response below for parsing.\nFor ChatGPT, we recommend “FitLog 中文助手” or “FitLog Estimator”.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('paste_copy_food_prompt_action')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
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
    expect(find.text('只需设置一次'), findsOneWidget);
    expect(
      find.text(
        '在新对话中发送一次此 Prompt；之后只需上传食物图片或补充描述，再将返回的完整 JSON 粘贴到下方解析。\n推荐在 ChatGPT 中使用「FitLog 中文助手」或「FitLog Estimator」。',
      ),
      findsOneWidget,
    );
    expect(find.text('复制 Prompt'), findsOneWidget);
  });
}
