import 'dart:async';
import 'dart:convert';

import 'package:fitlog_local/core/localization/language_controller.dart';
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
    expect(
      harness.repository.lastRequest?.modelChoice,
      AiGatewayModelChoice.qwen,
    );
    expect(harness.repository.lastRequest?.profileVersion, 'profile_7');
    expect(harness.chatController.selectedSessionId, 'session_1');
    expect(find.text('我在。'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    expect(tester.getRect(find.byTooltip('Chat history')).left, lessThan(80));
    expect(
      tester.getRect(find.byTooltip('Account and subscription')).right,
      greaterThan(313),
    );
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

    expect(listTop, greaterThan(historyBottom));
    expect(listTop, lessThan(76));
    expect(questionTop, greaterThanOrEqualTo(listTop));
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
        .getRect(find.byKey(const ValueKey<String>('ai_composer_field')))
        .top;

    expect(finalLineBottom, lessThan(composerTop - 8));
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();
    await tester.pump();

    final listTop = tester
        .getRect(find.byKey(const ValueKey<String>('ai_message_list')))
        .top;
    final newQuestionTop = tester
        .getRect(find.text('New anchored question'))
        .top;
    final loadingTop = tester
        .getRect(
          find.byKey(const ValueKey<String>('ai_assistant_loading_bubble')),
        )
        .top;

    expect(newQuestionTop, greaterThanOrEqualTo(listTop));
    expect(newQuestionTop, lessThan(listTop + 28));
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
      'Can this work after training?',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('ai_send_button')));
    await tester.pump();
    await tester.pump();

    expect(
      harness.repository.lastRequest?.modelChoice,
      AiGatewayModelChoice.qwen,
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
  });

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
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Thinking'), findsOneWidget);
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
  });

  testWidgets('assistant messages render basic Markdown without raw markers', (
    tester,
  ) async {
    final harness = _readyAiHarness();
    harness.repository.sendHandler = (request) async {
      const assistantText =
          '### 1. 营养方面：做减法\n\n'
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
    expect(find.textContaining('###', findRichText: true), findsNothing);
    expect(find.textContaining('回答文本问题', findRichText: true), findsOneWidget);
    expect(find.textContaining('**回答文本问题**', findRichText: true), findsNothing);
    expect(find.textContaining('不会写入正式记录', findRichText: true), findsOneWidget);
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
    expect(find.byType(FoodPreviewPage), findsNothing);

    await tester.tap(find.text('Review and confirm'));
    await tester.pumpAndSettle();

    expect(find.byType(FoodPreviewPage), findsOneWidget);
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
      expect(
        find.byKey(const ValueKey<String>('ai_composer_error')),
        findsOneWidget,
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
    expect(
      find.byKey(const ValueKey<String>('ai_composer_error')),
      findsOneWidget,
    );
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

    final qwenText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('ai_provider_qwen')),
        matching: find.text('Qwen'),
      ),
    );
    expect(qwenText.style?.fontWeight, FontWeight.w800);
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

  testWidgets('AI background keeps animating while the keyboard is visible', (
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

Widget _buildReadyAiTestApp(
  _ReadyAiHarness harness, {
  FoodImagePicker? imagePicker,
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
      ],
      child: AiPage(imagePicker: imagePicker),
    ),
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
    'schema_version': 'ai_chat_artifacts.v1',
    'artifacts': <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'food_draft',
        'schema_version': 'food_draft.v1',
        'draft': _validFoodDraftJson(),
        'selected_date': '2026-07-01',
        'model_choice': 'qwen',
      },
    ],
  };
}

Map<String, dynamic> _validFoodDraftJson() {
  return <String, dynamic>{
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
