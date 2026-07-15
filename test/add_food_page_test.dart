import 'package:fitlog_local/app.dart';
import 'package:fitlog_local/core/constants/prompt_templates.dart';
import 'package:fitlog_local/core/localization/app_language.dart';
import 'package:fitlog_local/core/localization/language_controller.dart';
import 'package:fitlog_local/features/food/add_food_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Add Food promotes AI food analysis and keeps fallback entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageController>(
        create: (_) => LanguageController(),
        child: MaterialApp(
          theme: buildFitLogTheme(Brightness.light),
          home: const AddFoodPage(initialDate: '2026-07-01'),
        ),
      ),
    );

    expect(find.text('AI Food Analysis'), findsOneWidget);
    expect(find.text('Copy reusable AI prompt'), findsOneWidget);
    expect(find.text('Paste AI Result'), findsOneWidget);
    expect(find.text('Manual Entry'), findsOneWidget);

    final photoTop = tester.getTopLeft(find.text('AI Food Analysis')).dy;
    final copyTop = tester.getTopLeft(find.text('Copy reusable AI prompt')).dy;
    final pasteTop = tester.getTopLeft(find.text('Paste AI Result')).dy;
    final manualTop = tester.getTopLeft(find.text('Manual Entry')).dy;

    expect(photoTop, lessThan(copyTop));
    expect(copyTop, lessThan(pasteTop));
    expect(pasteTop, lessThan(manualTop));
  });

  testWidgets('Add Food copies the reusable English prompt', (tester) async {
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
          home: const AddFoodPage(),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('copy_food_prompt_action')),
    );
    await tester.pump();

    expect(copiedText, PromptTemplates.aiFoodPromptEn);
  });

  testWidgets('Add Food copies the reusable Chinese prompt in Chinese mode', (
    tester,
  ) async {
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

    final languageController = LanguageController();
    await languageController.setLanguage(AppLanguage.chinese);
    addTearDown(languageController.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageController>.value(
        value: languageController,
        child: MaterialApp(
          theme: buildFitLogTheme(Brightness.light),
          home: const AddFoodPage(),
        ),
      ),
    );

    expect(find.text('复制长期对话 Prompt'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('copy_food_prompt_action')),
    );
    await tester.pump();

    expect(copiedText, PromptTemplates.aiFoodPromptZh);
  });
}
