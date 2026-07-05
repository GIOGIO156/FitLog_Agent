import 'dart:async';

import 'package:fitlog_local/data/repositories/ai_chat_repository.dart';
import 'package:fitlog_local/domain/models/ai_chat_message.dart';
import 'package:fitlog_local/domain/models/ai_chat_session.dart';
import 'package:fitlog_local/domain/models/ai_gateway_error.dart';
import 'package:fitlog_local/domain/models/ai_gateway_request.dart';
import 'package:fitlog_local/domain/models/ai_gateway_response.dart';
import 'package:fitlog_local/features/ai/ai_chat_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads sessions when account becomes AI-ready', () async {
    final repository = _FakeAiChatRepository();
    repository.sessions = <AiChatSession>[_session('session_1', 'Dinner')];
    final controller = AiChatController(repository: repository);

    controller.syncAccount(accountId: 'acct_1', canUseAi: true);
    await _flushAsync();

    expect(controller.sessions, hasLength(1));
    expect(controller.sessions.first.title, 'Dinner');
  });

  test('send shows pending user text and reloads canonical messages', () async {
    final repository = _FakeAiChatRepository();
    final sendCompleter = Completer<AiGatewayResponse>();
    repository.sendHandler = (request) => sendCompleter.future;
    final controller = AiChatController(repository: repository)
      ..syncAccount(accountId: 'acct_1', canUseAi: true);
    await _flushAsync();

    final sendFuture = controller.sendText(
      text: 'Plan dinner',
      language: 'en',
      modelChoice: AiGatewayModelChoice.chatgpt,
      deviceId: 'device-a',
      attachments: const <AiGatewayImageAttachment>[
        AiGatewayImageAttachment(
          mimeType: 'image/png',
          base64Data: 'abc123',
          byteLength: 6,
        ),
      ],
    );
    await _flushAsync();

    expect(controller.sending, isTrue);
    expect(controller.pendingUserText, 'Plan dinner');
    expect(controller.pendingUserAttachments, hasLength(1));

    repository.sessions = <AiChatSession>[_session('session_1', 'Plan dinner')];
    repository.messages['session_1'] = <AiChatMessage>[
      _message('u1', 'session_1', 1, AiChatMessageRole.user, 'Plan dinner'),
      _message(
        'a1',
        'session_1',
        2,
        AiChatMessageRole.assistant,
        'Choose fish and vegetables.',
      ),
    ];
    sendCompleter.complete(
      const AiGatewayResponse(
        sessionId: 'session_1',
        assistantMessageId: 'a1',
        messageText: 'Choose fish and vegetables.',
      ),
    );

    expect(await sendFuture, isTrue);
    expect(controller.sending, isFalse);
    expect(controller.pendingUserText, isNull);
    expect(controller.pendingUserAttachments, isEmpty);
    expect(controller.selectedSessionId, 'session_1');
    expect(controller.messages, hasLength(2));
    expect(
      controller.runtimeAttachmentsFor(controller.messages.first),
      hasLength(1),
    );
    expect(controller.messages.last.contentText, 'Choose fish and vegetables.');
  });

  test(
    'failed send keeps canonical messages clean and exposes stable error',
    () async {
      final repository = _FakeAiChatRepository();
      repository.sendHandler = (_) async {
        return const AiGatewayResponse(
          error: AiGatewayError(
            code: AiGatewayErrorCode.providerFailure,
            rawCode: 'provider_failure',
          ),
        );
      };
      final controller = AiChatController(repository: repository)
        ..syncAccount(accountId: 'acct_1', canUseAi: true);
      await _flushAsync();

      final success = await controller.sendText(
        text: 'Will fail',
        language: 'en',
        modelChoice: AiGatewayModelChoice.chatgpt,
        deviceId: 'device-a',
      );

      expect(success, isFalse);
      expect(controller.pendingUserText, isNull);
      expect(controller.messages, isEmpty);
      expect(controller.lastError?.code, AiGatewayErrorCode.providerFailure);
    },
  );

  test('send without synced account exposes an auth error', () async {
    final repository = _FakeAiChatRepository();
    final controller = AiChatController(repository: repository);

    final success = await controller.sendText(
      text: 'hello',
      language: 'en',
      modelChoice: AiGatewayModelChoice.qwen,
      deviceId: 'device-a',
    );

    expect(success, isFalse);
    expect(controller.lastError?.code, AiGatewayErrorCode.authRequired);
    expect(repository.lastRequest, isNull);
  });

  test('account switch clears runtime chat state', () async {
    final repository = _FakeAiChatRepository();
    final controller = AiChatController(repository: repository)
      ..syncAccount(accountId: 'acct_1', canUseAi: true);
    controller.startNewSession();
    await _flushAsync();
    repository.sessions = <AiChatSession>[_session('session_1', 'Dinner')];
    await controller.loadSessions();
    await controller.selectSession('session_1');

    controller.syncAccount(accountId: 'acct_2', canUseAi: true);

    expect(controller.accountId, 'acct_2');
    expect(controller.selectedSessionId, isNull);
    expect(controller.messages, isEmpty);
  });

  test(
    'archive and delete remove sessions through repository operations',
    () async {
      final repository = _FakeAiChatRepository();
      repository.sessions = <AiChatSession>[
        _session('session_1', 'Dinner'),
        _session('session_2', 'Training'),
      ];
      final controller = AiChatController(repository: repository)
        ..syncAccount(accountId: 'acct_1', canUseAi: true);
      await _flushAsync();

      await controller.archiveSession('session_1');
      expect(repository.archivedSessionIds, contains('session_1'));

      await controller.deleteSession('session_2');
      expect(repository.deletedSessionIds, contains('session_2'));
    },
  );

  test(
    'rename updates the session title through repository operation',
    () async {
      final repository = _FakeAiChatRepository();
      repository.sessions = <AiChatSession>[_session('session_1', 'Dinner')];
      final controller = AiChatController(repository: repository)
        ..syncAccount(accountId: 'acct_1', canUseAi: true);
      await _flushAsync();

      final success = await controller.renameSession(
        'session_1',
        'Dinner idea',
      );

      expect(success, isTrue);
      expect(repository.renamedSessions['session_1'], 'Dinner idea');
      expect(controller.sessions.first.title, 'Dinner idea');
    },
  );

  test('rename failure exposes a stable raw error', () async {
    final repository = _FakeAiChatRepository()..renameThrows = true;
    repository.sessions = <AiChatSession>[_session('session_1', 'Dinner')];
    final controller = AiChatController(repository: repository)
      ..syncAccount(accountId: 'acct_1', canUseAi: true);
    await _flushAsync();

    final success = await controller.renameSession('session_1', 'Dinner idea');

    expect(success, isFalse);
    expect(controller.sessions.first.title, 'Dinner');
    expect(controller.lastError?.rawCode, 'ai_chat_rename_failed');
  });

  test('provider choice is forwarded to gateway request', () async {
    final repository = _FakeAiChatRepository();
    repository.sendHandler = (request) async {
      repository.sessions = <AiChatSession>[_session('session_1', 'Hi')];
      repository.messages['session_1'] = <AiChatMessage>[
        _message(
          'u1',
          'session_1',
          1,
          AiChatMessageRole.user,
          request.messageText,
        ),
        _message('a1', 'session_1', 2, AiChatMessageRole.assistant, '你好'),
      ];
      return const AiGatewayResponse(
        sessionId: 'session_1',
        assistantMessageId: 'a1',
      );
    };
    final controller = AiChatController(repository: repository)
      ..syncAccount(accountId: 'acct_1', canUseAi: true);
    await _flushAsync();

    await controller.sendText(
      text: '你好',
      language: 'zh',
      modelChoice: AiGatewayModelChoice.qwen,
      deviceId: 'device-a',
    );

    expect(repository.lastRequest?.modelChoice, AiGatewayModelChoice.qwen);
  });

  test(
    'send forwards recent conversation context and artifact summary',
    () async {
      final repository = _FakeAiChatRepository();
      repository.sessions = <AiChatSession>[_session('session_1', 'Dinner')];
      repository.messages['session_1'] = <AiChatMessage>[
        _message('u1', 'session_1', 1, AiChatMessageRole.user, '刚才那张饭图能记录吗？'),
        _message(
          'a1',
          'session_1',
          2,
          AiChatMessageRole.assistant,
          '已生成饮食草稿。',
          finalAnswerJson: _foodDraftArtifactJson(),
        ),
      ];
      repository.sendHandler = (request) async {
        return const AiGatewayResponse(
          sessionId: 'session_1',
          assistantMessageId: 'a2',
        );
      };
      final controller = AiChatController(repository: repository)
        ..syncAccount(accountId: 'acct_1', canUseAi: true);
      await _flushAsync();
      await controller.selectSession('session_1');

      await controller.sendText(
        text: '那训练呢？',
        language: 'zh',
        modelChoice: AiGatewayModelChoice.qwen,
        deviceId: 'device-a',
      );

      final context = repository.lastRequest?.conversationContext;
      expect(context?.messages, hasLength(2));
      expect(context?.artifacts.single.type, 'food_draft');
      expect(context?.artifacts.single.title, 'Chicken rice');
    },
  );

  test('image attachments are forwarded to gateway request', () async {
    final repository = _FakeAiChatRepository();
    repository.sendHandler = (request) async {
      repository.sessions = <AiChatSession>[_session('session_1', 'Photo')];
      repository.messages['session_1'] = <AiChatMessage>[
        _message(
          'u1',
          'session_1',
          1,
          AiChatMessageRole.user,
          request.messageText,
        ),
        _message('a1', 'session_1', 2, AiChatMessageRole.assistant, 'ok'),
      ];
      return const AiGatewayResponse(
        sessionId: 'session_1',
        assistantMessageId: 'a1',
      );
    };
    final controller = AiChatController(repository: repository)
      ..syncAccount(accountId: 'acct_1', canUseAi: true);
    await _flushAsync();

    await controller.sendText(
      text: '看看这张图',
      language: 'zh',
      modelChoice: AiGatewayModelChoice.qwen,
      deviceId: 'device-a',
      attachments: const <AiGatewayImageAttachment>[
        AiGatewayImageAttachment(
          mimeType: 'image/png',
          base64Data: 'abc123',
          byteLength: 128,
        ),
        AiGatewayImageAttachment(
          mimeType: 'image/jpeg',
          base64Data: 'def456',
          byteLength: 256,
        ),
      ],
    );

    expect(repository.lastRequest?.attachments, hasLength(2));
    expect(repository.lastRequest?.attachments.first.mimeType, 'image/png');
    expect(repository.lastRequest?.attachments.last.mimeType, 'image/jpeg');
  });

  test(
    'food draft artifact can be restored from persisted message snapshot',
    () {
      final controller = AiChatController(repository: _FakeAiChatRepository());
      final message = _message(
        'a1',
        'session_1',
        2,
        AiChatMessageRole.assistant,
        'Review this draft.',
        finalAnswerJson: _foodDraftArtifactJson(),
      );

      final draft = controller.foodDraftFor(message);

      expect(draft?.mealName, 'Chicken rice');
      expect(draft?.caloriesKcal, 520);
    },
  );

  test('device replacement invokes boundary callback', () async {
    final repository = _FakeAiChatRepository();
    repository.sendHandler = (_) async {
      return const AiGatewayResponse(
        error: AiGatewayError(
          code: AiGatewayErrorCode.deviceReplaced,
          rawCode: 'device_replaced',
        ),
      );
    };
    var replaced = false;
    final controller = AiChatController(
      repository: repository,
      onDeviceReplaced: () => replaced = true,
    )..syncAccount(accountId: 'acct_1', canUseAi: true);
    await _flushAsync();

    await controller.sendText(
      text: 'hello',
      language: 'en',
      modelChoice: AiGatewayModelChoice.chatgpt,
      deviceId: 'device-a',
    );

    expect(replaced, isTrue);
  });
}

class _FakeAiChatRepository extends AiChatRepository {
  List<AiChatSession> sessions = const <AiChatSession>[];
  Map<String, List<AiChatMessage>> messages = <String, List<AiChatMessage>>{};
  Future<AiGatewayResponse> Function(AiGatewayRequest request)? sendHandler;
  AiGatewayRequest? lastRequest;
  final Set<String> archivedSessionIds = <String>{};
  final Set<String> deletedSessionIds = <String>{};
  final Map<String, String> renamedSessions = <String, String>{};
  bool renameThrows = false;

  @override
  Future<List<AiChatSession>> listSessions({required String accountId}) async {
    return sessions
        .where((session) => !archivedSessionIds.contains(session.id))
        .where((session) => !deletedSessionIds.contains(session.id))
        .toList(growable: false);
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
  }) async {
    archivedSessionIds.add(sessionId);
  }

  @override
  Future<void> renameSession(String sessionId, String title) async {
    if (renameThrows) {
      throw Exception('rename failed');
    }
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

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
