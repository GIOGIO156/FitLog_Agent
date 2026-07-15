import 'package:fitlog_local/app.dart';
import 'package:fitlog_local/core/constants/prompt_templates.dart';
import 'package:fitlog_local/core/localization/language_controller.dart';
import 'package:fitlog_local/features/food/paste_ai_result_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'Paste AI Result offers the reusable prompt instead of a GPT card',
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

      expect(find.text('Copy reusable AI prompt'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('paste_copy_food_prompt_action')),
        findsOneWidget,
      );
      expect(find.text('Recommended GPT'), findsNothing);
      expect(find.text('Parse'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('paste_copy_food_prompt_action')),
      );
      await tester.pump();
      expect(copiedText, PromptTemplates.aiFoodPromptEn);
    },
  );
}
