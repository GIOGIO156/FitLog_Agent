import 'package:fitlog_local/core/localization/language_controller.dart';
import 'package:fitlog_local/features/ai/ai_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('disabled AI page keeps composer editable but send disabled', (
    tester,
  ) async {
    await tester.pumpWidget(_buildAiTestApp(const AiPage()));

    expect(find.byKey(const ValueKey<String>('ai_page')), findsOneWidget);
    expect(find.text('Sign in to use FitLog AI'), findsOneWidget);
    expect(find.text('Signed out'), findsOneWidget);
    expect(find.text('Ask away with FitLog'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('ai_composer_field')),
      'What can I still eat today?',
    );
    await tester.pump();

    expect(find.text('What can I still eat today?'), findsOneWidget);

    final sendButton = tester.widget<IconButton>(
      find.byKey(const ValueKey<String>('ai_send_button')),
    );
    expect(sendButton.onPressed, isNull);
  });

  testWidgets('AI page can switch provider without leaving the shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildAiTestApp(const AiPage(mode: AiShellMode.ready)),
    );

    expect(find.text('ChatGPT'), findsOneWidget);
    expect(find.text('Qwen'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('ai_provider_qwen')));
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('ai_page')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI page keeps an unfinished prompt when switching tabs', (
    tester,
  ) async {
    await tester.pumpWidget(_buildAiTestApp(const _AiIndexedStackHarness()));

    await tester.enterText(
      find.byKey(const ValueKey<String>('ai_composer_field')),
      'Please help me plan dinner after training.',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('open_fake_tab')));
    await tester.pump();

    expect(find.text('Fake content'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('open_ai_tab')));
    await tester.pump();

    expect(
      find.text('Please help me plan dinner after training.'),
      findsOneWidget,
    );
  });

  testWidgets('AI page fits a small phone viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_buildAiTestApp(const AiPage()));
    await tester.enterText(
      find.byKey(const ValueKey<String>('ai_composer_field')),
      'A very long prompt that should wrap inside the composer instead of breaking the AI shell layout.',
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'AI page keeps status above the composer when keyboard is visible',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _buildAiTestApp(const AiPage(), resizeToAvoidBottomInset: false),
      );
      await tester.pump();

      final statusBottom = tester
          .getRect(find.text('Sign in to use FitLog AI'))
          .bottom;
      final providerTop = tester.getRect(find.text('ChatGPT')).top;
      final sendButtonBottom = tester
          .getRect(find.byKey(const ValueKey<String>('ai_send_button')))
          .bottom;

      expect(statusBottom, lessThan(providerTop - 16));
      expect(sendButtonBottom, lessThan(852 - 336));
      expect(tester.takeException(), isNull);
    },
  );
}

class _AiIndexedStackHarness extends StatefulWidget {
  const _AiIndexedStackHarness();

  @override
  State<_AiIndexedStackHarness> createState() => _AiIndexedStackHarnessState();
}

class _AiIndexedStackHarnessState extends State<_AiIndexedStackHarness> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            TextButton(
              key: const ValueKey<String>('open_ai_tab'),
              onPressed: () => setState(() => _index = 0),
              child: const Text('AI tab'),
            ),
            TextButton(
              key: const ValueKey<String>('open_fake_tab'),
              onPressed: () => setState(() => _index = 1),
              child: const Text('Fake tab'),
            ),
          ],
        ),
        Expanded(
          child: IndexedStack(
            index: _index,
            children: const <Widget>[
              AiPage(),
              Center(child: Text('Fake content')),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _buildAiTestApp(Widget child, {bool resizeToAvoidBottomInset = true}) {
  return ChangeNotifierProvider<LanguageController>(
    create: (_) => LanguageController(),
    child: MaterialApp(
      home: Scaffold(
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        body: child,
      ),
    ),
  );
}
