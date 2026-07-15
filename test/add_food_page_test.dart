import 'package:fitlog_local/app.dart';
import 'package:fitlog_local/core/localization/language_controller.dart';
import 'package:fitlog_local/features/food/add_food_page.dart';
import 'package:flutter/material.dart';
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
    expect(
      find.byKey(const ValueKey<String>('copy_food_prompt_action')),
      findsNothing,
    );
    expect(find.text('Paste AI Result'), findsOneWidget);
    expect(find.text('Manual Entry'), findsOneWidget);

    final photoTop = tester.getTopLeft(find.text('AI Food Analysis')).dy;
    final pasteTop = tester.getTopLeft(find.text('Paste AI Result')).dy;
    final manualTop = tester.getTopLeft(find.text('Manual Entry')).dy;

    expect(photoTop, lessThan(pasteTop));
    expect(pasteTop, lessThan(manualTop));
  });
}
