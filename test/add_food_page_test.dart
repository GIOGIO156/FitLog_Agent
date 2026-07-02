import 'package:fitlog_local/app.dart';
import 'package:fitlog_local/core/localization/language_controller.dart';
import 'package:fitlog_local/features/food/add_food_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Add Food promotes photo AI and keeps fallback entries', (
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

    expect(find.text('Photo AI Analysis'), findsOneWidget);
    expect(find.text('Copy AI Food Prompt'), findsNothing);
    expect(find.text('Paste AI Result'), findsOneWidget);
    expect(find.text('Manual Entry'), findsOneWidget);

    final photoTop = tester.getTopLeft(find.text('Photo AI Analysis')).dy;
    final pasteTop = tester.getTopLeft(find.text('Paste AI Result')).dy;
    final manualTop = tester.getTopLeft(find.text('Manual Entry')).dy;

    expect(photoTop, lessThan(pasteTop));
    expect(pasteTop, lessThan(manualTop));
  });
}
