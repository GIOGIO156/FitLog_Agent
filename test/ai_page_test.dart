import 'dart:async';
import 'dart:convert';

import 'package:fitlog_local/app.dart';
import 'package:fitlog_local/core/localization/language_controller.dart';
import 'package:fitlog_local/core/theme/fitlog_theme.dart';
import 'package:fitlog_local/core/widgets/fitlog_notifications.dart';
import 'package:fitlog_local/data/db/app_database.dart';
import 'package:fitlog_local/data/repositories/ai_chat_repository.dart';
import 'package:fitlog_local/data/repositories/ai_local_context_permission_repository.dart';
import 'package:fitlog_local/data/repositories/auth_repository.dart';
import 'package:fitlog_local/data/repositories/cloud_profile_repository.dart';
import 'package:fitlog_local/data/repositories/profile_repository.dart';
import 'package:fitlog_local/data/repositories/subscription_repository.dart';
import 'package:fitlog_local/domain/models/ai_chat_message.dart';
import 'package:fitlog_local/domain/models/ai_chat_session.dart';
import 'package:fitlog_local/domain/models/ai_food_photo_analysis.dart';
import 'package:fitlog_local/domain/models/ai_gateway_error.dart';
import 'package:fitlog_local/domain/models/ai_gateway_request.dart';
import 'package:fitlog_local/domain/models/ai_gateway_response.dart';
import 'package:fitlog_local/domain/models/auth_session.dart';
import 'package:fitlog_local/domain/models/cloud_profile.dart';
import 'package:fitlog_local/domain/models/cloud_runtime_context.dart';
import 'package:fitlog_local/domain/models/subscription_status.dart';
import 'package:fitlog_local/domain/models/user_profile.dart';
import 'package:fitlog_local/features/account/account_controller.dart';
import 'package:fitlog_local/features/ai/ai_chat_controller.dart';
import 'package:fitlog_local/features/ai/ai_chat_image_recovery.dart';
import 'package:fitlog_local/features/ai/ai_page.dart';
import 'package:fitlog_local/features/food/food_image_picker.dart';
import 'package:fitlog_local/features/food/food_preview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('disabled AI page keeps composer editable but send disabled', (
    tester,
  ) async {
    await tester.pumpWidget(_buildAiTestApp(const AiPage()));

    expect(find.byKey(const ValueKey<String>('ai_page')), findsOneWidget);
    expect(find.text('Sign in to use FitLog AI'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
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

  testWidgets('ready AI page sends through the chat controller', (
    tester,
  ) async {
    final harness = _readyAiHarness();
    harness.repository.sendHandler = (request) async {
      harness.repository.sessions = <AiChatSession>[
        _session('session_1', 'Plan dinner'),
      ];
      harness.repository.messages['session_1'] = <AiChatMessage>[
        _message(
          'u1',
          'session_1',
          1,
          AiChatMessageRole.user,
          request.messageText,
        ),
        _message('a1', 'session_1', 2, AiChatMessageRole.assistant, '我在。'),
      ];
      return const AiGatewayResponse(
        sessionId: 'session_1',
        assistantMessageId: 'a1',
        messageText: '我在。',
      );
    };
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildReadyAiTestApp(harness));

    final indicator = tester.widget<Container>(
      find.byKey(const ValueKey<String>('ai_status_indicator')),
    );
    final decoration = indicator.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFF5FA94D));

    await tester.tap(find.byKey(const ValueKey<String>('ai_provider_qwen')));
    await tester.enterText(
      find.byKey(const ValueKey<String>('ai_composer_field')),
      '你能做什么',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('ai_send_button')));
    await tester.pump();
    await tester.pump();

    expect(harness.repository.lastRequest?.messageText, '你能做什么');
    expect(harness.repository.lastRequest?.deviceId, 'device-a');
    expect(harness.repository.lastRequest?.language, 'zh');
    expect(
      harness.repository.lastRequest?.modelChoice,
      AiGatewayModelChoice.qwen,
    );
    expect(harness.repository.lastRequest?.profileVersion, 'profile_7');
    expect(harness.chatController.selectedSessionId, 'session_1');
    expect(find.text('我在。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready AI page sends English requests with English language', (
    tester,
  ) async {
    final harness = _readyAiHarness();
    harness.repository.sendHandler = (request) async {
      harness.repository.sessions = <AiChatSession>[
        _session('session_1', 'Carb tapering'),
      ];
      harness.repository.messages['session_1'] = <AiChatMessage>[
        _message(
          'u1',
          'session_1',
          1,
          AiChatMessageRole.user,
          request.messageText,
        ),
        _message('a1', 'session_1', 2, AiChatMessageRole.assistant, 'Done.'),
      ];
      return const AiGatewayResponse(
        sessionId: 'session_1',
        assistantMessageId: 'a1',
        messageText: 'Done.',
      );
    };
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildReadyAiTestApp(harness));
    await tester.enterText(
      find.byKey(const ValueKey<String>('ai_composer_field')),
      'How does carb tapering work in FitLog?',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('ai_send_button')));
    await tester.pump();
    await tester.pump();

    expect(harness.repository.lastRequest?.language, 'en');
    expect(
      harness.repository.lastRequest?.messageText,
      contains('carb tapering'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI chat accents follow the active FitLog theme', (tester) async {
    final harness = _readyAiHarness();
    final completer = Completer<AiGatewayResponse>();
    harness.repository.sendHandler = (_) => completer.future;
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      _buildReadyAiTestApp(harness, themeKey: FitLogThemeKey.blackOrange),
    );
    await tester.pump();

    final indicator = tester.widget<Container>(
      find.byKey(const ValueKey<String>('ai_status_indicator')),
    );
    final indicatorDecoration = indicator.decoration! as BoxDecoration;
    expect(indicatorDecoration.color, const Color(0xFF5FA94D));

    await tester.enterText(
      find.byKey(const ValueKey<String>('ai_composer_field')),
      '黑橙主题消息',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('ai_send_button')));
    await tester.pump();
    await tester.pump();

    final pendingBubbleDecoration =
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byKey(
                          const ValueKey<String>('ai_pending_user_bubble'),
                        ),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(pendingBubbleDecoration.color, const Color(0xFFFF7A1A));

    completer.complete(
      const AiGatewayResponse(
        sessionId: 'session_1',
        assistantMessageId: 'a1',
        messageText: '收到。',
      ),
    );
    await tester.pump();
    await tester.pump();
  });

  testWidgets('AI draft card keeps black orange actions warm and readable', (
    tester,
  ) async {
    final harness = _readyAiHarness();
    harness.repository.sessions = <AiChatSession>[
      _session('session_1', 'Food draft'),
    ];
    harness.repository.messages['session_1'] = <AiChatMessage>[
      _message(
        'a1',
        'session_1',
        1,
        AiChatMessageRole.assistant,
        '已为你生成饮食草稿。',
        finalAnswerJson: _foodDraftArtifactJson(),
      ),
    ];
    harness.chatController.syncAccount(accountId: 'acct_1', canUseAi: true);
    await harness.chatController.selectSession('session_1');
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      _buildReadyAiTestApp(harness, themeKey: FitLogThemeKey.blackOrange),
    );
    await tester.pump();

    final cardDecoration =
        tester
                .widget<DecoratedBox>(
                  find.byKey(
                    const ValueKey<String>('ai_food_draft_artifact_card'),
                  ),
                )
                .decoration
            as BoxDecoration;
    final cardBorder = cardDecoration.border! as Border;
    expect(cardDecoration.color, const Color(0xFFFFF3E8));
    expect(cardBorder.top.color, const Color(0xFFF3C6A3));

    final action = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Review and confirm'),
    );
    expect(
      action.style?.backgroundColor?.resolve(<WidgetState>{}),
      const Color(0xFFFF6B01),
    );
  });

  testWidgets('AI assistant message renders Phase 5 evidence sources', (
    tester,
  ) async {
    final harness = _readyAiHarness();
    harness.repository.sessions = <AiChatSession>[
      _session('session_1', 'RAG answer'),
    ];
    harness.repository.messages['session_1'] = <AiChatMessage>[
      _message(
        'a1',
        'session_1',
        1,
        AiChatMessageRole.assistant,
        'FitLog 会优先从 AI 页面发起 Agent 工作流。',
        finalAnswerJson: _phase5EvidenceSnapshotJson(),
      ),
    ];
    harness.chatController.syncAccount(accountId: 'acct_1', canUseAi: true);
    await harness.chatController.selectSession('session_1');
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildReadyAiTestApp(harness));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('ai_phase5_evidence')),
      findsOneWidget,
    );
    expect(find.text('Answer basis'), findsOneWidget);
    expect(find.text('AppGuide · AI'), findsOneWidget);
    expect(find.text('Selected-day summary'), findsOneWidget);
    expect(find.text('Profile unavailable'), findsOneWidget);
    expect(find.text('Strategy changes need confirmation'), findsOneWidget);
    expect(find.text('No matching document source'), findsNothing);
    expect(find.textContaining('docs/zh/AppGuide.md'), findsNothing);
    expect(find.text('document_context'), findsNothing);
    expect(find.text('profile_context'), findsNothing);
  });

  testWidgets('conversation keeps top actions fixed while provider moves up', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = _readyAiHarness();
    harness.repository.sendHandler = (request) async {
      harness.repository.sessions = <AiChatSession>[
        _session('session_1', 'Plan dinner'),
      ];
      harness.repository.messages['session_1'] = <AiChatMessage>[
        _message(
          'u1',
          'session_1',
          1,
          AiChatMessageRole.user,
          request.messageText,
        ),
        _message('a1', 'session_1', 2, AiChatMessageRole.assistant, '我在。'),
      ];
      return const AiGatewayResponse(
        sessionId: 'session_1',
        assistantMessageId: 'a1',
        messageText: '我在。',
      );
    };
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildReadyAiTestApp(harness));
    await tester.tap(find.byKey(const ValueKey<String>('ai_provider_qwen')));
    await tester.enterText(
      find.byKey(const ValueKey<String>('ai_composer_field')),
      '你能做什么',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('ai_send_button')));
    await tester.pump();
    await tester.pump();

    expect(tester.getRect(find.byTooltip('Chat history')).top, lessThan(80));
    expect(
      tester.getRect(find.byTooltip('Account and subscription')).top,
      lessThan(80),
    );
    expect(tester.getRect(find.text('Qwen')).top, lessThan(80));
    expect(
      tester
          .getRect(find.byKey(const ValueKey<String>('ai_status_indicator')))
          .center
          .dy,
      closeTo(
        tester
            .getRect(find.byKey(const ValueKey<String>('ai_provider_selector')))
            .center
            .dy,
        0.5,
      ),
    );
    expect(tester.getRect(find.byTooltip('Chat history')).left, lessThan(80));
    expect(
      tester.getRect(find.byTooltip('Account and subscription')).right,
      greaterThan(313),
    );
  });

  testWidgets('AI account sheet does not expose sign out', (tester) async {
    final harness = _readyAiHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildReadyAiTestApp(harness));
    await tester.tap(find.byTooltip('Account and subscription'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey<String>('ai_local_context_permission_switch')),
      findsOneWidget,
    );
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('conversation reading area starts below the top controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = _readyAiHarness();
    harness.repository.sessions = <AiChatSession>[
      _session('session_1', 'Existing chat'),
    ];
    harness.repository.messages['session_1'] = <AiChatMessage>[
      _message('u1', 'session_1', 1, AiChatMessageRole.user, 'Top question'),
      _message('a1', 'session_1', 2, AiChatMessageRole.assistant, 'Top answer'),
    ];
    harness.chatController.syncAccount(accountId: 'acct_1', canUseAi: true);
    await harness.chatController.selectSession('session_1');
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildReadyAiTestApp(harness));
    await tester.pump();

    final listTop = tester
        .getRect(find.byKey(const ValueKey<String>('ai_message_list')))
        .top;
    final historyBottom = tester.getRect(find.byTooltip('Chat history')).bottom;
    final questionTop = tester.getRect(find.text('Top question')).top;

    expect(
      find.byKey(const ValueKey<String>('ai_message_soft_edges')),
      findsOneWidget,
    );
    expect(listTop, greaterThan(historyBottom));
    expect(questionTop, greaterThan(historyBottom));
    expect(_aiBackgroundMotion(tester), contains('quietChat'));
  });

  testWidgets('manual scroll keeps the final message above the composer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = _readyAiHarness();
    harness.repository.sessions = <AiChatSession>[
      _session('session_1', 'Long chat'),
    ];
    harness.repository.messages['session_1'] = <AiChatMessage>[
      for (var index = 0; index < 8; index++) ...<AiChatMessage>[
        _message(
          'u$index',
          'session_1',
          index * 2 + 1,
          AiChatMessageRole.user,
          'Question $index',
        ),
        _message(
          'a$index',
          'session_1',
          index * 2 + 2,
          AiChatMessageRole.assistant,
          'Answer $index\n\n- one\n- two\n- three',
        ),
      ],
      _message(
        'u-final',
        'session_1',
        99,
        AiChatMessageRole.user,
        'Final question',
      ),
      _message(
        'a-final',
        'session_1',
        100,
        AiChatMessageRole.assistant,
        'Final readable line',
      ),
    ];
    harness.chatController.syncAccount(accountId: 'acct_1', canUseAi: true);
    await harness.chatController.selectSession('session_1');
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildReadyAiTestApp(harness));
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey<String>('ai_message_list')),
      const Offset(0, -2400),
    );
    await tester.pump(const Duration(milliseconds: 240));

    final finalLineBottom = tester
        .getRect(find.text('Final readable line'))
        .bottom;
    final composerTop = tester
        .getRect(find.byKey(const ValueKey<String>('ai_composer_surface')))
        .top;
    final listBottom = tester
        .getRect(find.byKey(const ValueKey<String>('ai_message_list')))
        .bottom;

    expect(finalLineBottom, lessThan(composerTop - 8));
    expect(listBottom, lessThanOrEqualTo(composerTop - 8));
  });

  testWidgets(
    'keyboard reuses the resting message separation and locks scrolling',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final harness = _readyAiHarness();
      harness.repository.sessions = <AiChatSession>[
        _session('session_1', 'Short chat'),
      ];
      harness.repository.messages['session_1'] = <AiChatMessage>[
        for (var index = 0; index < 6; index++) ...<AiChatMessage>[
          _message(
            'u$index',
            'session_1',
            index * 2 + 1,
            AiChatMessageRole.user,
            'Keyboard question $index',
          ),
          _message(
            'a$index',
            'session_1',
            index * 2 + 2,
            AiChatMessageRole.assistant,
            'Keyboard answer $index\n\n- one\n- two\n- three',
          ),
        ],
        _message(
          'u-final',
          'session_1',
          99,
          AiChatMessageRole.user,
          '200毫升牛奶。',
        ),
        _message(
          'a-final',
          'session_1',
          100,
          AiChatMessageRole.assistant,
          'Keyboard final readable line',
        ),
      ];
      harness.chatController.syncAccount(accountId: 'acct_1', canUseAi: true);
      await harness.chatController.selectSession('session_1');
      addTearDown(harness.dispose);

      await tester.pumpWidget(
        _buildReadyAiTestApp(harness, resizeToAvoidBottomInset: false),
      );
      await tester.pump();
      await tester.pump();
      await tester.drag(
        find.byKey(const ValueKey<String>('ai_message_list')),
        const Offset(0, -1800),
      );
      await tester.pump(const Duration(milliseconds: 240));

      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      await tester.pump();
      final messageList = tester.widget<ListView>(
        find.byKey(const ValueKey<String>('ai_message_list')),
      );
      final lockedOffset = messageList.controller!.offset;
      await tester.dragFrom(const Offset(196, 240), const Offset(0, 180));
      await tester.pump(const Duration(milliseconds: 240));

      final listBottom = tester
          .getRect(find.byKey(const ValueKey<String>('ai_message_list')))
          .bottom;
      final composerRect = tester.getRect(
        find.byKey(const ValueKey<String>('ai_composer_surface')),
      );
      final composerDecoration =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey<String>('ai_composer_surface')),
                  )
                  .decoration
              as BoxDecoration;
      expect(
        find.byKey(const ValueKey<String>('ai_composer_keyboard_veil')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('ai_keyboard_dismiss_region')),
        findsOneWidget,
      );
      expect(messageList.physics, isA<NeverScrollableScrollPhysics>());
      expect(messageList.controller!.offset, closeTo(lockedOffset, 0.1));
      expect(composerRect.bottom, closeTo(852 - 336 - 12, 0.1));
      expect(composerDecoration.color, Colors.white.withValues(alpha: 0.76));
      expect(composerDecoration.border, isA<Border>());
      final composerBorder = composerDecoration.border! as Border;
      expect(composerBorder.top.width, closeTo(0.8, 0.01));
      expect(composerDecoration.boxShadow, hasLength(2));
      expect(composerDecoration.boxShadow!.first.blurRadius, 30);
      expect(listBottom, closeTo(composerRect.top - 10, 0.5));
      expect(messageList.padding, const EdgeInsets.fromLTRB(2, 0, 2, 14));
    },
  );

  testWidgets('keyboard closing keeps the composer above navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _buildAiTestApp(
        const AiPage(mode: AiShellMode.ready),
        resizeToAvoidBottomInset: false,
      ),
    );
    await tester.pump();

    double composerBottomDistance() {
      final composerRect = tester.getRect(
        find.byKey(const ValueKey<String>('ai_composer_surface')),
      );
      return 852 - composerRect.bottom;
    }

    final restingBottomDistance = composerBottomDistance();
    expect(restingBottomDistance, greaterThan(4));

    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    await tester.pump();
    expect(composerBottomDistance(), closeTo(336 + 12, 0.1));

    final closingInset = restingBottomDistance / 2;
    tester.view.viewInsets = FakeViewPadding(bottom: closingInset);
    await tester.pump();
    expect(composerBottomDistance(), closeTo(restingBottomDistance, 0.1));
    expect(composerBottomDistance(), greaterThan(closingInset));

    tester.view.viewInsets = const FakeViewPadding(bottom: 0);
    await tester.pump();
    expect(composerBottomDistance(), closeTo(restingBottomDistance, 0.1));
  });

  testWidgets('tapping outside the keyboard composer dismisses focus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _buildAiTestApp(
        const AiPage(mode: AiShellMode.ready),
        resizeToAvoidBottomInset: false,
      ),
    );
    await tester.pump();

    final field = find.byKey(const ValueKey<String>('ai_composer_field'));
    await tester.tap(field);
    await tester.pump();
    final editable = tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    await tester.pump();
    await tester.tapAt(const Offset(20, 120));
    await tester.pump();

    expect(editable.focusNode.hasFocus, isFalse);
  });

  testWidgets('dragging the message area dismisses the keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _buildAiTestApp(
        const AiPage(mode: AiShellMode.ready),
        resizeToAvoidBottomInset: false,
      ),
    );
    await tester.pump();

    final field = find.byKey(const ValueKey<String>('ai_composer_field'));
    await tester.tap(field);
    await tester.pump();
    final editable = tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    await tester.pump();
    await tester.dragFrom(const Offset(196, 240), const Offset(0, -160));
    await tester.pump();

    expect(editable.focusNode.hasFocus, isFalse);
  });

  testWidgets('sending anchors the new user bubble to the reading top', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = _readyAiHarness();
    harness.repository.sessions = <AiChatSession>[
      _session('session_1', 'Existing chat'),
    ];
    harness.repository.messages['session_1'] = <AiChatMessage>[
      for (var index = 0; index < 10; index++) ...<AiChatMessage>[
        _message(
          'old-u$index',
          'session_1',
          index * 2 + 1,
          AiChatMessageRole.user,
          'Old question $index',
        ),
        _message(
          'old-a$index',
          'session_1',
          index * 2 + 2,
          AiChatMessageRole.assistant,
          'Old answer $index\n\n- detail one\n- detail two',
        ),
      ],
    ];
    final completer = Completer<AiGatewayResponse>();
    harness.repository.sendHandler = (_) => completer.future;
    harness.chatController.syncAccount(accountId: 'acct_1', canUseAi: true);
    await harness.chatController.selectSession('session_1');
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildReadyAiTestApp(harness));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('ai_composer_field')),
      'New anchored question',
    );
    await tester.pump();
    final sendButton = tester.widget<IconButton>(
      find.byKey(const ValueKey<String>('ai_send_button')),
    );
    expect(sendButton.onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey<String>('ai_send_button')));
    await tester.pump();
    expect(
      harness.repository.lastRequest?.messageText,
      'New anchored question',
    );
    final firstFramePendingTop = tester
        .getRect(find.byKey(const ValueKey<String>('ai_pending_user_bubble')))
        .top;
    final firstFrameHistoryBottom = tester
        .getRect(find.byTooltip('Chat history'))
        .bottom;
    expect(
      firstFramePendingTop,
      greaterThanOrEqualTo(firstFrameHistoryBottom + 10),
    );
    await tester.pump();
    final secondFramePendingTop = tester
        .getRect(find.byKey(const ValueKey<String>('ai_pending_user_bubble')))
        .top;
    expect(secondFramePendingTop, closeTo(firstFrameHistoryBottom + 10, 1));
    await tester.pump();
    final settledPendingTop = tester
        .getRect(find.byKey(const ValueKey<String>('ai_pending_user_bubble')))
        .top;
    expect(settledPendingTop, closeTo(secondFramePendingTop, 1));
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();
    await tester.pump();

    final listTop = tester
        .getRect(find.byKey(const ValueKey<String>('ai_message_list')))
        .top;
    final historyBottom = tester.getRect(find.byTooltip('Chat history')).bottom;
    final newQuestionTop = tester
        .getRect(find.text('New anchored question'))
        .top;
    final pendingBubbleTop = tester
        .getRect(find.byKey(const ValueKey<String>('ai_pending_user_bubble')))
        .top;
    final pendingBubbleDecoration =
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byKey(
                          const ValueKey<String>('ai_pending_user_bubble'),
                        ),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    final loadingTop = tester
        .getRect(
          find.byKey(const ValueKey<String>('ai_assistant_loading_bubble')),
        )
        .top;
    final readableAnchorTop = historyBottom + 10;

    expect(pendingBubbleTop, closeTo(readableAnchorTop, 1));
    expect(listTop, greaterThan(historyBottom));
    expect(pendingBubbleTop, closeTo(listTop, 1));
    expect(
      pendingBubbleDecoration.color,
      const Color(0xFF5FA94D).withValues(alpha: 0.92),
    );
    expect(newQuestionTop, greaterThan(pendingBubbleTop));
    expect(newQuestionTop, greaterThan(historyBottom));
    expect(newQuestionTop, lessThan(historyBottom + 32));
    expect(loadingTop, greaterThan(newQuestionTop));
    expect(
      find.byKey(const ValueKey<String>('ai_send_anchor_spacer')),
      findsNothing,
    );
    expect(
      tester
          .widget<ListView>(
            find.byKey(const ValueKey<String>('ai_message_list')),
          )
          .physics,
      isA<NeverScrollableScrollPhysics>(),
    );

    await tester.drag(
      find.byKey(const ValueKey<String>('ai_message_list')),
      const Offset(0, -600),
    );
    await tester.pump();

    expect(find.text('New anchored question'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('ai_assistant_loading_bubble')),
      findsOneWidget,
    );

    completer.complete(
      const AiGatewayResponse(
        sessionId: 'session_1',
        assistantMessageId: 'new-a',
        messageText: 'Done',
      ),
    );
    await tester.pump();
    await tester.pump();
  });

  testWidgets(
    'keyboard sending anchors the new user bubble to the reading top',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      addTearDown(tester.view.reset);

      final harness = _readyAiHarness();
      harness.repository.sessions = <AiChatSession>[
        _session('session_1', 'Existing chat'),
      ];
      harness.repository.messages['session_1'] = <AiChatMessage>[
        for (var index = 0; index < 10; index++) ...<AiChatMessage>[
          _message(
            'old-u$index',
            'session_1',
            index * 2 + 1,
            AiChatMessageRole.user,
            'Old keyboard question $index',
          ),
          _message(
            'old-a$index',
            'session_1',
            index * 2 + 2,
            AiChatMessageRole.assistant,
            'Old keyboard answer $index\n\n- detail one\n- detail two',
          ),
        ],
      ];
      final completer = Completer<AiGatewayResponse>();
      harness.repository.sendHandler = (_) => completer.future;
      harness.chatController.syncAccount(accountId: 'acct_1', canUseAi: true);
      await harness.chatController.selectSession('session_1');
      addTearDown(harness.dispose);

      await tester.pumpWidget(
        _buildReadyAiTestApp(harness, resizeToAvoidBottomInset: false),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey<String>('ai_composer_field')),
        'Keyboard anchored question',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('ai_send_button')));
      await tester.pump();
      final firstFramePendingTop = tester
          .getRect(find.byKey(const ValueKey<String>('ai_pending_user_bubble')))
          .top;
      final firstFrameHistoryBottom = tester
          .getRect(find.byTooltip('Chat history'))
          .bottom;
      expect(
        firstFramePendingTop,
        greaterThanOrEqualTo(firstFrameHistoryBottom + 10),
      );
      await tester.pump();
      final secondFramePendingTop = tester
          .getRect(find.byKey(const ValueKey<String>('ai_pending_user_bubble')))
          .top;
      expect(secondFramePendingTop, closeTo(firstFrameHistoryBottom + 10, 1));
      await tester.pump();
      final settledPendingTop = tester
          .getRect(find.byKey(const ValueKey<String>('ai_pending_user_bubble')))
          .top;
      expect(settledPendingTop, closeTo(secondFramePendingTop, 1));
      await tester.pump(const Duration(milliseconds: 260));
      await tester.pump();
      await tester.pump();

      final listTop = tester
          .getRect(find.byKey(const ValueKey<String>('ai_message_list')))
          .top;
      final historyBottom = tester
          .getRect(find.byTooltip('Chat history'))
          .bottom;
      final pendingBubbleTop = tester
          .getRect(find.byKey(const ValueKey<String>('ai_pending_user_bubble')))
          .top;
      final newQuestionTop = tester
          .getRect(find.text('Keyboard anchored question'))
          .top;
      final loadingTop = tester
          .getRect(
            find.byKey(const ValueKey<String>('ai_assistant_loading_bubble')),
          )
          .top;
      final readableAnchorTop = historyBottom + 10;

      expect(pendingBubbleTop, closeTo(readableAnchorTop, 1));
      expect(listTop, greaterThan(historyBottom));
      expect(pendingBubbleTop, closeTo(listTop, 1));
      expect(newQuestionTop, greaterThan(pendingBubbleTop));
      expect(loadingTop, greaterThan(newQuestionTop));

      completer.complete(
        const AiGatewayResponse(
          sessionId: 'session_1',
          assistantMessageId: 'keyboard-new-a',
          messageText: 'Done',
        ),
      );
      await tester.pump();
      await tester.pump();
    },
  );

  testWidgets('ready AI page sends up to three Qwen image attachments', (
    tester,
  ) async {
    final harness = _readyAiHarness();
    final picker = _FakeFoodImagePicker(
      _tinyPngImage(),
      images: <PickedFoodImage>[
        _tinyPngImage(),
        _tinyPngImage(),
        _tinyPngImage(),
      ],
    );
    harness.repository.sendHandler = (request) async {
      harness.repository.sessions = <AiChatSession>[
        _session('session_1', 'Photo meal'),
      ];
      harness.repository.messages['session_1'] = <AiChatMessage>[
        _message(
          'u1',
          'session_1',
          1,
          AiChatMessageRole.user,
          request.messageText,
        ),
        _message('a1', 'session_1', 2, AiChatMessageRole.assistant, '可以。'),
      ];
      return const AiGatewayResponse(
        sessionId: 'session_1',
        assistantMessageId: 'a1',
        messageText: '可以。',
      );
    };
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildReadyAiTestApp(harness, imagePicker: picker));
    await tester.tap(find.byKey(const ValueKey<String>('ai_provider_qwen')));
    await tester.pump();

    await _attachAiGalleryImage(tester);

    expect(picker.lastSource, FoodImageSource.gallery);
    expect(picker.pickCount, 1);
    expect(
      find.byKey(const ValueKey<String>('ai_attached_image_preview')),
      findsOneWidget,
    );
    expect(find.byTooltip('Remove'), findsNWidgets(3));

    await tester.enterText(
      find.byKey(const ValueKey<String>('ai_composer_field')),
      'Can this work after training if I already ate rice and chicken earlier today?',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('ai_send_button')));
    await tester.pump();
    await tester.pump();

    expect(
      harness.repository.lastRequest?.modelChoice,
      AiGatewayModelChoice.qwen,
    );
    expect(
      harness.repository.lastRequest?.messageText,
      'Can this work after training if I already ate rice and chicken earlier today?',
    );
    expect(harness.repository.lastRequest?.attachments, hasLength(3));
    expect(
      harness.repository.lastRequest?.attachments.first.mimeType,
      'image/png',
    );
    expect(
      harness.repository.lastRequest?.attachments.first.base64Data,
      base64Encode(_tinyPngImage().bytes),
    );
    expect(
      find.byKey(const ValueKey<String>('ai_message_image_thumbnail')),
      findsNWidgets(3),
    );
    expect(
      find.byKey(const ValueKey<String>('ai_user_attachment_media')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('ai_user_text_bubble')),
      findsOneWidget,
    );

    final attachmentMediaRect = tester.getRect(
      find.byKey(const ValueKey<String>('ai_user_attachment_media')),
    );
    final textBubbleRect = tester.getRect(
      find.byKey(const ValueKey<String>('ai_user_text_bubble')),
    );
    expect(textBubbleRect.top, greaterThan(attachmentMediaRect.bottom));
    expect(
      (textBubbleRect.right - attachmentMediaRect.right).abs(),
      lessThanOrEqualTo(1),
    );
    expect(textBubbleRect.width, greaterThan(attachmentMediaRect.width));
  });

  testWidgets(
    'unconfigured ChatGPT reports unavailable and slides back to Qwen',
    (tester) async {
      final harness = _readyAiHarness();
      final picker = _FakeFoodImagePicker(_tinyPngImage());
      addTearDown(harness.dispose);

      await tester.pumpWidget(
        _buildReadyAiTestApp(harness, imagePicker: picker),
      );
      await _attachAiGalleryImage(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('ai_composer_field')),
        'Estimate this meal.',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('ai_provider_chatgpt')),
      );
      await tester.pump();
      expect(find.text('The current model is unavailable.'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      expect(
        tester
            .widget<AnimatedPositioned>(
              find.byKey(const ValueKey<String>('ai_provider_indicator')),
            )
            .left,
        3,
      );
      expect(harness.repository.lastRequest, isNull);

      await tester.pump(const Duration(milliseconds: 240));
      expect(
        tester
            .widget<AnimatedPositioned>(
              find.byKey(const ValueKey<String>('ai_provider_indicator')),
            )
            .left,
        greaterThan(3),
      );
      await tester.pump(const Duration(milliseconds: 240));

      expect(harness.repository.lastRequest, isNull);
      expect(find.text('Estimate this meal.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('ai_attached_image_preview')),
        findsOneWidget,
      );
      expect(find.text('The current model is unavailable.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('The current model is unavailable.'), findsNothing);
    },
  );

  testWidgets('sent image media stays bare and stable across keyboard inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = _readyAiHarness();
    final picker = _FakeFoodImagePicker(_tinyPngImage());
    harness.repository.sendHandler = (request) async {
      harness.repository.sessions = <AiChatSession>[
        _session('session_1', 'Photo meal'),
      ];
      harness.repository.messages['session_1'] = <AiChatMessage>[
        _message(
          'u1',
          'session_1',
          1,
          AiChatMessageRole.user,
          request.messageText,
        ),
        _message('a1', 'session_1', 2, AiChatMessageRole.assistant, '收到。'),
      ];
      return const AiGatewayResponse(
        sessionId: 'session_1',
        assistantMessageId: 'a1',
        messageText: '收到。',
      );
    };
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildReadyAiTestApp(harness, imagePicker: picker));
    await tester.tap(find.byKey(const ValueKey<String>('ai_provider_qwen')));
    await tester.pump();
    await _attachAiGalleryImage(tester);
    await tester.enterText(
      find.byKey(const ValueKey<String>('ai_composer_field')),
      'Two beers',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('ai_send_button')));
    await tester.pump();
    await tester.pump();

    final mediaFinder = find.byKey(
      const ValueKey<String>('ai_user_attachment_media'),
    );
    expect(mediaFinder, findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('ai_user_attachment_bubble')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('ai_message_image_thumbnail')),
      findsOneWidget,
    );
    expect(
      find
          .descendant(of: mediaFinder, matching: find.byType(Image))
          .evaluate()
          .map((element) => element.widget as Image)
          .single
          .gaplessPlayback,
      isTrue,
    );

    final mediaDecorations = find
        .descendant(of: mediaFinder, matching: find.byType(DecoratedBox))
        .evaluate()
        .map((element) => (element.widget as DecoratedBox).decoration)
        .whereType<BoxDecoration>()
        .toList(growable: false);
    expect(
      mediaDecorations.map((decoration) => decoration.color),
      isNot(contains(const Color(0xFF5FA94D).withValues(alpha: 0.92))),
    );

    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(mediaFinder, findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('ai_message_image_thumbnail')),
      findsOneWidget,
    );
    expect(find.text('Two beers'), findsOneWidget);
  });

  testWidgets(
    'AI page restores recovered camera attachment and composer text',
    (tester) async {
      final harness = _readyAiHarness();
      final recoveryController = AiChatImageRecoveryController();
      addTearDown(harness.dispose);
      addTearDown(recoveryController.dispose);

      await tester.pumpWidget(
        _buildReadyAiTestApp(
          harness,
          imageRecoveryController: recoveryController,
        ),
      );

      recoveryController.restore(
        RecoveredAiChatImages(
          messageText: 'Log this meal',
          provider: 'qwen',
          images: <PickedFoodImage>[_tinyPngImage()],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Log this meal'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('ai_attached_image_preview')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('ai_send_button')));
      await tester.pump();
      await tester.pump();

      expect(harness.repository.lastRequest?.messageText, 'Log this meal');
      expect(
        harness.repository.lastRequest?.modelChoice,
        AiGatewayModelChoice.qwen,
      );
      expect(harness.repository.lastRequest?.attachments, hasLength(1));
    },
  );

  testWidgets(
    'AI page keeps ready recovery background while send remains disabled',
    (tester) async {
      final harness = _readyAiHarness()
        ..accountController.subscriptionStatus =
            const SubscriptionStatus.loading();
      final recoveryController = AiChatImageRecoveryController();
      addTearDown(harness.dispose);
      addTearDown(recoveryController.dispose);

      recoveryController.restore(
        RecoveredAiChatImages(
          messageText: 'Log this meal',
          provider: 'qwen',
          images: <PickedFoodImage>[_tinyPngImage()],
          wasReadyVisual: true,
        ),
      );

      await tester.pumpWidget(
        _buildReadyAiTestApp(
          harness,
          imageRecoveryController: recoveryController,
        ),
      );

      expect(_aiBackgroundMode(tester), contains('ready'));
      await tester.pump();

      expect(find.text('Log this meal'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('ai_attached_image_preview')),
        findsOneWidget,
      );
      expect(_aiBackgroundMode(tester), contains('ready'));

      final sendButton = tester.widget<IconButton>(
        find.byKey(const ValueKey<String>('ai_send_button')),
      );
      expect(sendButton.onPressed, isNull);
      expect(harness.repository.lastRequest, isNull);
    },
  );
  testWidgets('AI page blocks the fourth image attachment', (tester) async {
    final harness = _readyAiHarness();
    final picker = _FakeFoodImagePicker(
      _tinyPngImage(),
      images: <PickedFoodImage>[
        _tinyPngImage(),
        _tinyPngImage(),
        _tinyPngImage(),
      ],
    );
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildReadyAiTestApp(harness, imagePicker: picker));
    await tester.tap(find.byKey(const ValueKey<String>('ai_provider_qwen')));
    await tester.pump();

    await _attachAiGalleryImage(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('ai_attach_image_button')),
    );
    await tester.pump();

    expect(picker.pickCount, 1);
    expect(find.text('You can attach up to 3 images.'), findsOneWidget);
    expect(
      tester.getRect(find.text('You can attach up to 3 images.')).bottom,
      lessThan(tester.getRect(find.text('Qwen')).top),
    );
    expect(find.byTooltip('Remove'), findsNWidgets(3));
  });

  testWidgets('sending clears the composer and shows assistant loading', (
    tester,
  ) async {
    final harness = _readyAiHarness();
    final completer = Completer<AiGatewayResponse>();
    harness.repository.sendHandler = (request) {
      harness.repository.sessions = <AiChatSession>[
        _session('session_1', 'Plan dinner'),
      ];
      harness.repository.messages['session_1'] = <AiChatMessage>[
        _message(
          'u1',
          'session_1',
          1,
          AiChatMessageRole.user,
          request.messageText,
        ),
        _message('a1', 'session_1', 2, AiChatMessageRole.assistant, '收到，我来处理。'),
      ];
      return completer.future;
    };
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildReadyAiTestApp(harness));
    await tester.enterText(
      find.byKey(const ValueKey<String>('ai_composer_field')),
      '请帮我看看今天还能吃什么',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('ai_send_button')));
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('ai_composer_field')),
    );
    expect(field.controller?.text, isEmpty);
    expect(find.text('请帮我看看今天还能吃什么'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('ai_assistant_loading_bubble')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('ai_status_indicator')),
      findsOneWidget,
    );
    expect(find.text('Sending your question...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('Waiting for the reply...'), findsOneWidget);
    expect(_aiBackgroundMotion(tester), contains('quietChat'));

    completer.complete(
      const AiGatewayResponse(
        sessionId: 'session_1',
        assistantMessageId: 'a1',
        messageText: '收到，我来处理。',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('ai_assistant_loading_bubble')),
      findsNothing,
    );
    expect(find.text('收到，我来处理。'), findsOneWidget);
    expect(find.text('Waiting for the reply...'), findsNothing);
  });

  testWidgets(
    'image sends show conservative progress without claiming results',
    (tester) async {
      final harness = _readyAiHarness();
      final picker = _FakeFoodImagePicker(_tinyPngImage());
      final completer = Completer<AiGatewayResponse>();
      harness.repository.sendHandler = (request) {
        harness.repository.sessions = <AiChatSession>[
          _session('session_1', 'Photo meal'),
        ];
        harness.repository.messages['session_1'] = <AiChatMessage>[
          _message(
            'u1',
            'session_1',
            1,
            AiChatMessageRole.user,
            request.messageText,
          ),
          _message('a1', 'session_1', 2, AiChatMessageRole.assistant, '收到。'),
        ];
        return completer.future;
      };
      addTearDown(harness.dispose);

      await tester.pumpWidget(
        _buildReadyAiTestApp(harness, imagePicker: picker),
      );
      await tester.tap(find.byKey(const ValueKey<String>('ai_provider_qwen')));
      await tester.pump();
      await _attachAiGalleryImage(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('ai_composer_field')),
        'Please estimate this meal.',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('ai_send_button')));
      await tester.pump();

      expect(find.text('Sending images and description...'), findsOneWidget);
      expect(find.textContaining('recognized'), findsNothing);
      expect(find.textContaining('nutrition'), findsNothing);
      expect(find.textContaining('FitLog rules'), findsNothing);

      await tester.pump(const Duration(milliseconds: 1600));
      expect(
        find.text('This includes images, so it may take a few more seconds.'),
        findsOneWidget,
      );
      expect(find.textContaining('recognized'), findsNothing);
      expect(find.textContaining('nutrition'), findsNothing);
      expect(find.textContaining('FitLog rules'), findsNothing);

      await tester.pump(const Duration(milliseconds: 4500));
      expect(find.text('Still waiting for the server...'), findsOneWidget);

      completer.complete(
        const AiGatewayResponse(
          sessionId: 'session_1',
          assistantMessageId: 'a1',
          messageText: '收到。',
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('ai_assistant_loading_bubble')),
        findsNothing,
      );
      expect(find.text('收到。'), findsOneWidget);
      expect(find.textContaining('waiting', findRichText: true), findsNothing);
    },
  );

  testWidgets('assistant messages render basic Markdown without raw markers', (
    tester,
  ) async {
    final harness = _readyAiHarness();
    harness.repository.sendHandler = (request) async {
      const assistantText =
          '#### 1. 营养方面：做减法\n\n'
          '1. **回答文本问题**：处理健身相关问题\n'
          '2. `建议`：给出简要建议\n\n'
          '- 不会写入正式记录';
      harness.repository.sessions = <AiChatSession>[
        _session('session_1', 'Plan dinner'),
      ];
      harness.repository.messages['session_1'] = <AiChatMessage>[
        _message(
          'u1',
          'session_1',
          1,
          AiChatMessageRole.user,
          request.messageText,
        ),
        _message(
          'a1',
          'session_1',
          2,
          AiChatMessageRole.assistant,
          assistantText,
        ),
      ];
      return const AiGatewayResponse(
        sessionId: 'session_1',
        assistantMessageId: 'a1',
        messageText: assistantText,
      );
    };
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildReadyAiTestApp(harness));
    await tester.enterText(
      find.byKey(const ValueKey<String>('ai_composer_field')),
      '你能做什么',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('ai_send_button')));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('营养方面：做减法', findRichText: true), findsOneWidget);
    expect(find.textContaining('####', findRichText: true), findsNothing);
    expect(find.textContaining('回答文本问题', findRichText: true), findsOneWidget);
    expect(find.textContaining('**回答文本问题**', findRichText: true), findsNothing);
    expect(find.textContaining('不会写入正式记录', findRichText: true), findsOneWidget);
  });

  testWidgets('message bubbles keep text selectable without copy buttons', (
    tester,
  ) async {
    final harness = _readyAiHarness();
    harness.repository.sessions = <AiChatSession>[
      _session('session_1', 'Existing chat'),
    ];
    harness.repository.messages['session_1'] = <AiChatMessage>[
      _message(
        'u1',
        'session_1',
        1,
        AiChatMessageRole.user,
        'Copy my question',
      ),
      _message(
        'a1',
        'session_1',
        2,
        AiChatMessageRole.assistant,
        'Copy **this** answer',
      ),
    ];
    harness.chatController.syncAccount(accountId: 'acct_1', canUseAi: true);
    await harness.chatController.selectSession('session_1');
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildReadyAiTestApp(harness));
    await tester.pump();

    expect(find.byTooltip('Copy message'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText && widget.data == 'Copy my question',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Copy', findRichText: true), findsWidgets);
    expect(find.textContaining('this', findRichText: true), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('food draft response shows a review card before preview', (
    tester,
  ) async {
    final harness = _readyAiHarness();
    final draft = AiFoodDraft.fromJson(_validFoodDraftJson());
    harness.repository.sendHandler = (request) async {
      harness.repository.sessions = <AiChatSession>[
        _session('session_1', 'Photo meal'),
      ];
      harness.repository.messages['session_1'] = <AiChatMessage>[
        _message(
          'u1',
          'session_1',
          1,
          AiChatMessageRole.user,
          request.messageText,
        ),
        _message(
          'a1',
          'session_1',
          2,
          AiChatMessageRole.assistant,
          '### 识别到的餐食\n\n- 鸡腿饭\n- 青菜',
          finalAnswerJson: _foodDraftArtifactJson(),
        ),
      ];
      return AiGatewayResponse(
        sessionId: 'session_1',
        assistantMessageId: 'a1',
        messageText: '### 识别到的餐食\n\n- 鸡腿饭\n- 青菜',
        foodDraft: draft,
      );
    };
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildReadyAiTestApp(harness));
    await tester.tap(find.byKey(const ValueKey<String>('ai_provider_qwen')));
    await tester.enterText(
      find.byKey(const ValueKey<String>('ai_composer_field')),
      '请分析这张图',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('ai_send_button')));
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('ai_food_draft_artifact_card')),
      findsOneWidget,
    );
    expect(find.text('Review and confirm'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('ai_draft_date_2026-07-01')),
      findsOneWidget,
    );
    expect(find.byType(FoodPreviewPage), findsNothing);

    await tester.tap(find.text('Review and confirm'));
    await tester.pumpAndSettle();

    expect(find.byType(FoodPreviewPage), findsOneWidget);
    expect(find.text('Jul 1, 2026'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_outlined), findsWidgets);
  });

  testWidgets(
    'failed send restores the draft after clearing it optimistically',
    (tester) async {
      final harness = _readyAiHarness();
      harness.repository.sendHandler = (_) async {
        return const AiGatewayResponse(
          error: AiGatewayError(
            code: AiGatewayErrorCode.providerFailure,
            rawCode: 'provider_failure',
          ),
        );
      };
      addTearDown(harness.dispose);

      await tester.pumpWidget(_buildReadyAiTestApp(harness));
      await tester.enterText(
        find.byKey(const ValueKey<String>('ai_composer_field')),
        '请保留失败草稿',
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey<String>('ai_send_button')));
      await tester.pump();
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('ai_composer_field')),
      );
      expect(field.controller?.text, '请保留失败草稿');
      expect(
        find.text('AI provider could not answer. Try again later.'),
        findsOneWidget,
      );
      expect(find.byKey(FitLogNotifications.errorKey), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('ai_composer_error_close')),
        findsNothing,
      );
    },
  );

  testWidgets('network failure says the message was kept for retry', (
    tester,
  ) async {
    final harness = _readyAiHarness();
    harness.repository.sendHandler = (_) async {
      return const AiGatewayResponse(
        error: AiGatewayError(
          code: AiGatewayErrorCode.networkFailure,
          rawCode: 'network_failure',
        ),
      );
    };
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildReadyAiTestApp(harness));
    await tester.enterText(
      find.byKey(const ValueKey<String>('ai_composer_field')),
      '请保留这条消息',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('ai_send_button')));
    await tester.pump();
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('ai_composer_field')),
    );
    expect(field.controller?.text, '请保留这条消息');
    expect(
      find.text('Network failed. Your message was kept for retry.'),
      findsOneWidget,
    );
    expect(find.byKey(FitLogNotifications.errorKey), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey<String>('ai_composer_field')),
      '请保留这条消息，稍后重试',
    );
    await tester.pump();
    expect(find.byKey(FitLogNotifications.errorKey), findsNothing);
  });

  testWidgets('backgrounding does not cancel an in-flight AI request', (
    tester,
  ) async {
    final harness = _readyAiHarness();
    final completer = Completer<AiGatewayResponse>();
    harness.repository.sendHandler = (request) async {
      final response = await completer.future;
      harness.repository.sessions = <AiChatSession>[
        _session('session_1', 'Background request'),
      ];
      harness.repository.messages['session_1'] = <AiChatMessage>[
        _message(
          'u1',
          'session_1',
          1,
          AiChatMessageRole.user,
          request.messageText,
        ),
        _message('a1', 'session_1', 2, AiChatMessageRole.assistant, '请求已完成'),
      ];
      return response;
    };
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildReadyAiTestApp(harness));
    await tester.enterText(
      find.byKey(const ValueKey<String>('ai_composer_field')),
      '切后台继续请求',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('ai_send_button')));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(harness.chatController.sending, isTrue);
    expect(find.byKey(FitLogNotifications.errorKey), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    completer.complete(
      const AiGatewayResponse(
        sessionId: 'session_1',
        assistantMessageId: 'a1',
        messageText: '请求已完成',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(harness.chatController.sending, isFalse);
    expect(find.text('请求已完成'), findsOneWidget);
    expect(find.byKey(FitLogNotifications.errorKey), findsNothing);
  });

  testWidgets('conversation switches the background to quiet motion', (
    tester,
  ) async {
    final harness = _readyAiHarness();
    harness.repository.sendHandler = (request) async {
      harness.repository.sessions = <AiChatSession>[
        _session('session_1', 'Plan dinner'),
      ];
      harness.repository.messages['session_1'] = <AiChatMessage>[
        _message(
          'u1',
          'session_1',
          1,
          AiChatMessageRole.user,
          request.messageText,
        ),
        _message('a1', 'session_1', 2, AiChatMessageRole.assistant, 'Hello'),
      ];
      return const AiGatewayResponse(
        sessionId: 'session_1',
        assistantMessageId: 'a1',
        messageText: 'Hello',
      );
    };
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildReadyAiTestApp(harness));
    await tester.enterText(
      find.byKey(const ValueKey<String>('ai_composer_field')),
      'Hi',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('ai_send_button')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Hello'), findsOneWidget);
    expect(_aiBackgroundMotion(tester), contains('quietChat'));
  });

  testWidgets('idle landing keeps the background in visible motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildAiTestApp(const AiPage(mode: AiShellMode.ready)),
    );

    expect(_aiBackgroundMotion(tester), contains('idleLanding'));
    final firstProgress = _aiBackgroundProgress(tester);
    await tester.pump(const Duration(milliseconds: 150));
    final secondProgress = _aiBackgroundProgress(tester);

    expect(secondProgress, isNot(firstProgress));
  });

  testWidgets('provider selector restores the locally persisted Qwen choice', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'fitlog.ai.selected_provider': 'qwen',
    });

    await tester.pumpWidget(
      _buildAiTestApp(const AiPage(mode: AiShellMode.ready)),
    );
    await tester.pump();

    final qwenStyle = tester.widget<AnimatedDefaultTextStyle>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('ai_provider_qwen')),
        matching: find.byType(AnimatedDefaultTextStyle),
      ),
    );
    expect(qwenStyle.style.fontWeight, FontWeight.w800);
  });

  testWidgets('provider selector writes the local provider preference', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildAiTestApp(const AiPage(mode: AiShellMode.ready)),
    );

    await tester.tap(find.byKey(const ValueKey<String>('ai_provider_qwen')));
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('fitlog.ai.selected_provider'), 'qwen');
  });

  testWidgets('history removes archive and requires confirm before delete', (
    tester,
  ) async {
    final harness = _readyAiHarness();
    harness.repository.sessions = <AiChatSession>[
      _session('session_1', 'Dinner chat'),
    ];
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildReadyAiTestApp(harness));
    await tester.pump();
    await tester.tap(find.byTooltip('Chat history'));
    await tester.pump();

    expect(find.byTooltip('Archive chat'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey<String>('ai_delete_chat_button')),
    );
    await tester.pump();

    expect(harness.repository.deletedSessionIds, isEmpty);
    expect(find.text('Delete chat?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(harness.repository.deletedSessionIds, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey<String>('ai_delete_chat_button')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('ai_confirm_delete_chat_button')),
    );
    await tester.pump();
    await tester.pump();

    expect(harness.repository.deletedSessionIds, contains('session_1'));
  });

  testWidgets(
    'dark AI surfaces use chat-title color for history heading and entered text',
    (tester) async {
      final harness = _readyAiHarness();
      harness.repository.sessions = <AiChatSession>[
        _session('session_1', 'Dinner chat'),
      ];
      addTearDown(harness.dispose);

      await tester.pumpWidget(
        _buildReadyAiTestApp(
          harness,
          themeKey: FitLogThemeKey.blackOrange,
          brightness: Brightness.dark,
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('ai_composer_field')),
        'Nina',
      );
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('ai_composer_field')),
      );
      expect(field.style?.color, const Color(0xFF3A332D));
      expect(field.decoration?.hintText, 'Ask away with FitLog');
      expect(field.decoration?.hintStyle, isNull);

      await tester.tap(find.byTooltip('Chat history'));
      await tester.pump();

      final heading = tester.widget<Text>(find.text('Chat history'));
      expect(heading.style?.color, const Color(0xFF3A332D));
    },
  );

  testWidgets('history supports inline rename', (tester) async {
    final harness = _readyAiHarness();
    harness.repository.sessions = <AiChatSession>[
      _session('session_1', 'Dinner chat'),
    ];
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildReadyAiTestApp(harness));
    await tester.pump();
    await tester.tap(find.byTooltip('Chat history'));
    await tester.pump();

    final tileBefore = tester.getSize(
      find.byKey(const ValueKey<String>('ai_history_tile_session_1')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('ai_rename_chat_button')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('ai_rename_chat_field')),
      findsOneWidget,
    );
    final tileDuring = tester.getSize(
      find.byKey(const ValueKey<String>('ai_history_tile_session_1')),
    );
    expect(tileDuring.height, tileBefore.height);

    await tester.enterText(
      find.byKey(const ValueKey<String>('ai_rename_chat_field')),
      'Updated dinner',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();

    expect(harness.repository.renamedSessions['session_1'], 'Updated dinner');
    expect(find.text('Updated dinner'), findsOneWidget);
  });

  testWidgets('ready AI page sends Markdown-like user text as plain text', (
    tester,
  ) async {
    final harness = _readyAiHarness();
    harness.repository.sendHandler = (request) async {
      harness.repository.sessions = <AiChatSession>[
        _session('session_1', 'Plan dinner'),
      ];
      harness.repository.messages['session_1'] = <AiChatMessage>[
        _message(
          'u1',
          'session_1',
          1,
          AiChatMessageRole.user,
          request.messageText,
        ),
        _message('a1', 'session_1', 2, AiChatMessageRole.assistant, '我在。'),
      ];
      return const AiGatewayResponse(
        sessionId: 'session_1',
        assistantMessageId: 'a1',
        messageText: '我在。',
      );
    };
    addTearDown(harness.dispose);

    await tester.pumpWidget(_buildReadyAiTestApp(harness));
    await tester.enterText(
      find.byKey(const ValueKey<String>('ai_composer_field')),
      '**普通用户文本**',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('ai_send_button')));
    await tester.pump();

    expect(find.text('**普通用户文本**'), findsOneWidget);
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

  testWidgets('AI background keeps landing motion while typing before chat', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _buildAiTestApp(
        const AiPage(mode: AiShellMode.ready),
        resizeToAvoidBottomInset: false,
      ),
    );

    final firstProgress = _aiBackgroundProgress(tester);
    await tester.pump(const Duration(milliseconds: 150));
    final secondProgress = _aiBackgroundProgress(tester);

    expect(secondProgress, isNot(firstProgress));
    expect(_aiBackgroundMotion(tester), contains('idleLanding'));
    expect(tester.takeException(), isNull);
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

Widget _buildAiTestApp(
  Widget child, {
  bool resizeToAvoidBottomInset = true,
  FitLogThemeKey themeKey = FitLogThemeKey.green,
  Brightness brightness = Brightness.light,
}) {
  return ChangeNotifierProvider<LanguageController>(
    create: (_) => LanguageController(),
    child: MaterialApp(
      theme: buildFitLogTheme(brightness, themeKey: themeKey),
      home: Scaffold(
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        body: child,
      ),
    ),
  );
}

Widget _buildReadyAiTestApp(
  _ReadyAiHarness harness, {
  FoodImagePicker? imagePicker,
  AiChatImageRecoveryController? imageRecoveryController,
  bool resizeToAvoidBottomInset = true,
  FitLogThemeKey themeKey = FitLogThemeKey.green,
  Brightness brightness = Brightness.light,
}) {
  return _buildAiTestApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CloudRuntimeContext>.value(
          value: harness.runtimeContext,
        ),
        ChangeNotifierProvider<AccountController>.value(
          value: harness.accountController,
        ),
        ChangeNotifierProvider<AiChatController>.value(
          value: harness.chatController,
        ),
        if (imageRecoveryController != null)
          ChangeNotifierProvider<AiChatImageRecoveryController>.value(
            value: imageRecoveryController,
          ),
      ],
      child: AiPage(imagePicker: imagePicker),
    ),
    resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    themeKey: themeKey,
    brightness: brightness,
  );
}

Future<void> _attachAiGalleryImage(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey<String>('ai_attach_image_button')),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 260));
  await tester.tap(find.text('Gallery'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 260));
}

class _ReadyAiHarness {
  _ReadyAiHarness({
    required this.runtimeContext,
    required this.accountController,
    required this.chatController,
    required this.repository,
  });

  final CloudRuntimeContext runtimeContext;
  final AccountController accountController;
  final AiChatController chatController;
  final _FakeAiChatRepository repository;

  void dispose() {
    accountController.dispose();
    chatController.dispose();
    runtimeContext.dispose();
  }
}

_ReadyAiHarness _readyAiHarness() {
  final runtimeContext = CloudRuntimeContext()
    ..bind(accountId: 'acct_1', deviceId: 'device-a', sessionId: 'session-a');
  final accountController =
      AccountController(
          authRepository: const UnconfiguredAuthRepository(),
          subscriptionRepository: const UnconfiguredSubscriptionRepository(),
          cloudProfileRepository: const UnconfiguredCloudProfileRepository(),
          profileRepository: ProfileRepository(AppDatabase.instance),
          contextPermissionRepository:
              const AiLocalContextPermissionRepository(),
          cloudRuntimeContext: runtimeContext,
          backendConfigured: true,
        )
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
  final repository = _FakeAiChatRepository();
  final chatController = AiChatController(repository: repository);
  return _ReadyAiHarness(
    runtimeContext: runtimeContext,
    accountController: accountController,
    chatController: chatController,
    repository: repository,
  );
}

class _FakeAiChatRepository extends AiChatRepository {
  List<AiChatSession> sessions = const <AiChatSession>[];
  Map<String, List<AiChatMessage>> messages = <String, List<AiChatMessage>>{};
  Future<AiGatewayResponse> Function(AiGatewayRequest request)? sendHandler;
  AiGatewayRequest? lastRequest;
  final Set<String> deletedSessionIds = <String>{};
  final Map<String, String> renamedSessions = <String, String>{};

  @override
  Future<List<AiChatSession>> listSessions({required String accountId}) async {
    return sessions;
  }

  @override
  Future<List<AiChatMessage>> listMessages({
    required String accountId,
    required String sessionId,
  }) async {
    return messages[sessionId] ?? const <AiChatMessage>[];
  }

  @override
  Future<AiGatewayResponse> sendMessage(AiGatewayRequest request) {
    lastRequest = request;
    final handler = sendHandler;
    if (handler != null) {
      return handler(request);
    }
    return Future<AiGatewayResponse>.value(
      const AiGatewayResponse(sessionId: 'session_1'),
    );
  }

  @override
  Future<void> archiveSession(
    String sessionId, {
    required bool archived,
  }) async {}

  @override
  Future<void> renameSession(String sessionId, String title) async {
    renamedSessions[sessionId] = title;
    sessions = sessions
        .map(
          (session) => session.id == sessionId
              ? AiChatSession(
                  id: session.id,
                  accountId: session.accountId,
                  title: title,
                  language: session.language,
                  lastMessageAt: session.lastMessageAt,
                  archivedAt: session.archivedAt,
                  deletedAt: session.deletedAt,
                  createdAt: session.createdAt,
                  updatedAt: session.updatedAt,
                )
              : session,
        )
        .toList(growable: false);
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    deletedSessionIds.add(sessionId);
  }
}

class _FakeFoodImagePicker extends FoodImagePicker {
  _FakeFoodImagePicker(this.image, {List<PickedFoodImage>? images})
    : images = images ?? <PickedFoodImage>[image];

  final PickedFoodImage image;
  final List<PickedFoodImage> images;
  FoodImageSource? lastSource;
  int pickCount = 0;

  @override
  Future<PickedFoodImage?> pick(FoodImageSource source) async {
    lastSource = source;
    pickCount += 1;
    return image;
  }

  @override
  Future<List<PickedFoodImage>> pickMultiple(
    FoodImageSource source, {
    required int limit,
  }) async {
    lastSource = source;
    pickCount += 1;
    return images.take(limit).toList(growable: false);
  }
}

PickedFoodImage _tinyPngImage() {
  return PickedFoodImage(
    bytes: base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
    ),
    mimeType: 'image/png',
    name: 'meal.png',
  );
}

AiChatSession _session(String id, String title) {
  return AiChatSession(
    id: id,
    accountId: 'acct_1',
    title: title,
    language: 'en',
    createdAt: DateTime.utc(2026, 6, 30),
    updatedAt: DateTime.utc(2026, 6, 30),
  );
}

AiChatMessage _message(
  String id,
  String sessionId,
  int sequence,
  AiChatMessageRole role,
  String text, {
  Map<String, dynamic>? finalAnswerJson,
}) {
  return AiChatMessage(
    id: id,
    sessionId: sessionId,
    accountId: 'acct_1',
    messageSequence: sequence,
    role: role,
    contentText: text,
    finalAnswerJson: finalAnswerJson,
    createdAt: DateTime.utc(2026, 6, 30, 1, sequence),
  );
}

Map<String, dynamic> _foodDraftArtifactJson() {
  return <String, dynamic>{
    'schema_version': 'ai_chat_artifacts.v2',
    'artifacts': <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'food_draft',
        'schema_version': 'food_draft.v2',
        'draft': _validFoodDraftJson(),
        'target_date': '2026-07-01',
        'model_choice': 'qwen',
      },
    ],
  };
}

Map<String, dynamic> _phase5EvidenceSnapshotJson() {
  return <String, dynamic>{
    'schema_version': 'ai_chat_evidence.v1',
    'evidence': <String, dynamic>{
      'workflow': 'app_logic_answer',
      'context_objects': <String>['document_context', 'selected_day_summary'],
      'document_sources': <Map<String, dynamic>>[
        <String, dynamic>{
          'doc_path': 'docs/zh/AppGuide.md',
          'heading': 'AI',
          'section_id': 'ai',
          'status': 'implemented',
          'score': 1.4,
          'excerpt': 'AI 页面是 Agent 入口。',
        },
      ],
      'missing_dimensions': <String>['document_context', 'profile_context'],
      'safety_flags': <String>['strategy_write_requested'],
      'user_final_action': 'read_only',
    },
  };
}

Map<String, dynamic> _validFoodDraftJson() {
  return <String, dynamic>{
    'schema_version': 'food_draft.v2',
    'date': '2026-07-01',
    'meal_name': 'Chicken rice',
    'total_weight_g': 320,
    'calories_kcal': 520,
    'protein_g': 32,
    'carbs_g': 62,
    'fat_g': 14,
    'confidence': 0.72,
    'estimation_notes': 'AI estimate.',
    'items': <Map<String, dynamic>>[
      <String, dynamic>{
        'name': 'Chicken',
        'weight_g': 120,
        'calories_kcal': 220,
        'protein_g': 28,
        'carbs_g': 0,
        'fat_g': 10,
      },
      <String, dynamic>{
        'name': 'Rice',
        'weight_g': 200,
        'calories_kcal': 300,
        'protein_g': 4,
        'carbs_g': 62,
        'fat_g': 4,
      },
    ],
  };
}

double _aiBackgroundProgress(WidgetTester tester) {
  final painter = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((widget) => widget.painter)
      .where((painter) {
        return painter != null &&
            painter.runtimeType.toString() == '_AiFlowBackgroundPainter';
      })
      .single;
  return (painter as dynamic).progress as double;
}

String _aiBackgroundMode(WidgetTester tester) {
  final painter = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((widget) => widget.painter)
      .where((painter) {
        return painter != null &&
            painter.runtimeType.toString() == '_AiFlowBackgroundPainter';
      })
      .single;
  return (painter as dynamic).mode.toString();
}

String _aiBackgroundMotion(WidgetTester tester) {
  final painter = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((widget) => widget.painter)
      .where((painter) {
        return painter != null &&
            painter.runtimeType.toString() == '_AiFlowBackgroundPainter';
      })
      .single;
  return (painter as dynamic).motion.toString();
}
