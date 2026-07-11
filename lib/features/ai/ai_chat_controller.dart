import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/ai_chat_repository.dart';
import '../../data/repositories/phase2_repository_exception.dart';
import '../../domain/models/ai_chat_message.dart';
import '../../domain/models/ai_chat_session.dart';
import '../../domain/models/ai_food_photo_analysis.dart';
import '../../domain/models/ai_gateway_error.dart';
import '../../domain/models/ai_gateway_request.dart';
import '../../domain/models/ai_gateway_response.dart';
import '../../domain/models/ai_workout_draft.dart';

class AiChatController extends ChangeNotifier {
  AiChatController({required this.repository, this.onDeviceReplaced});

  final AiChatRepository repository;
  final VoidCallback? onDeviceReplaced;

  String? _accountId;
  String? _selectedSessionId;
  List<AiChatSession> _sessions = const <AiChatSession>[];
  List<AiChatMessage> _messages = const <AiChatMessage>[];
  bool _loadingSessions = false;
  bool _loadingMessages = false;
  bool _sending = false;
  String? _pendingUserText;
  List<AiGatewayImageAttachment> _pendingUserAttachments =
      const <AiGatewayImageAttachment>[];
  Map<String, List<AiGatewayImageAttachment>> _runtimeUserAttachments =
      const <String, List<AiGatewayImageAttachment>>{};
  Map<String, AiFoodDraft> _runtimeAssistantFoodDrafts =
      const <String, AiFoodDraft>{};
  Map<String, AiWorkoutDraft> _runtimeAssistantWorkoutDrafts =
      const <String, AiWorkoutDraft>{};
  AiGatewayError? _lastError;
  AiGatewayResponse? _lastSuccessfulResponse;

  String? get accountId => _accountId;
  String? get selectedSessionId => _selectedSessionId;
  List<AiChatSession> get sessions => _sessions;
  List<AiChatMessage> get messages => _messages;
  bool get loadingSessions => _loadingSessions;
  bool get loadingMessages => _loadingMessages;
  bool get sending => _sending;
  String? get pendingUserText => _pendingUserText;
  List<AiGatewayImageAttachment> get pendingUserAttachments =>
      _pendingUserAttachments;
  AiGatewayError? get lastError => _lastError;
  AiGatewayResponse? get lastSuccessfulResponse => _lastSuccessfulResponse;
  bool get hasVisibleConversation =>
      _messages.isNotEmpty ||
      (_pendingUserText ?? '').isNotEmpty ||
      _pendingUserAttachments.isNotEmpty ||
      _sending ||
      _loadingMessages;

  List<AiGatewayImageAttachment> runtimeAttachmentsFor(AiChatMessage message) {
    if (!message.isUser) {
      return const <AiGatewayImageAttachment>[];
    }
    return _runtimeUserAttachments[message.id] ??
        const <AiGatewayImageAttachment>[];
  }

  AiFoodDraft? foodDraftFor(AiChatMessage message) {
    return foodDraftArtifactFor(message)?.draft;
  }

  AiFoodDraftArtifact? foodDraftArtifactFor(AiChatMessage message) {
    if (!message.isAssistant) {
      return null;
    }
    return message.foodDraftArtifactSnapshot ??
        _foodArtifactFromRuntime(_runtimeAssistantFoodDrafts[message.id]);
  }

  AiWorkoutDraftArtifact? workoutDraftArtifactFor(AiChatMessage message) {
    if (!message.isAssistant) {
      return null;
    }
    return message.workoutDraftArtifactSnapshot ??
        _workoutArtifactFromRuntime(_runtimeAssistantWorkoutDrafts[message.id]);
  }

  void showLocalError(AiGatewayError error) {
    _setTransientError(error);
    notifyListeners();
  }

  void clearError() {
    if (_lastError == null) return;
    _clearErrorState();
    notifyListeners();
  }

  void syncAccount({required String? accountId, required bool canUseAi}) {
    final nextAccountId = canUseAi && (accountId ?? '').isNotEmpty
        ? accountId
        : null;
    if (_accountId == nextAccountId) {
      return;
    }
    _accountId = nextAccountId;
    _selectedSessionId = null;
    _sessions = const <AiChatSession>[];
    _messages = const <AiChatMessage>[];
    _pendingUserText = null;
    _pendingUserAttachments = const <AiGatewayImageAttachment>[];
    _runtimeUserAttachments = const <String, List<AiGatewayImageAttachment>>{};
    _runtimeAssistantFoodDrafts = const <String, AiFoodDraft>{};
    _runtimeAssistantWorkoutDrafts = const <String, AiWorkoutDraft>{};
    _lastSuccessfulResponse = null;
    _clearErrorState();
    notifyListeners();
    if (_accountId != null) {
      unawaited(loadSessions());
    }
  }

  Future<void> loadSessions() async {
    final activeAccountId = _accountId;
    if ((activeAccountId ?? '').isEmpty) {
      return;
    }
    _loadingSessions = true;
    _clearErrorState();
    notifyListeners();
    try {
      _sessions = await repository.listSessions(accountId: activeAccountId!);
      if (_selectedSessionId != null &&
          !_sessions.any((session) => session.id == _selectedSessionId)) {
        _selectedSessionId = null;
        _messages = const <AiChatMessage>[];
      }
    } on Phase2RepositoryException catch (error) {
      _setTransientError(_errorFromCode(error.code));
    } catch (_) {
      _setTransientError(_errorFromCode('ai_chat_sessions_load_failed'));
    } finally {
      _loadingSessions = false;
      notifyListeners();
    }
  }

  Future<void> selectSession(String? sessionId) async {
    if (_selectedSessionId == sessionId) {
      return;
    }
    _selectedSessionId = sessionId;
    _messages = const <AiChatMessage>[];
    _pendingUserText = null;
    _pendingUserAttachments = const <AiGatewayImageAttachment>[];
    _runtimeAssistantFoodDrafts = const <String, AiFoodDraft>{};
    _runtimeAssistantWorkoutDrafts = const <String, AiWorkoutDraft>{};
    _lastSuccessfulResponse = null;
    _clearErrorState();
    notifyListeners();
    if ((sessionId ?? '').isNotEmpty) {
      await loadMessages(sessionId!);
    }
  }

  Future<void> loadMessages(String sessionId) async {
    final activeAccountId = _accountId;
    if ((activeAccountId ?? '').isEmpty || sessionId.isEmpty) {
      return;
    }
    _loadingMessages = true;
    _clearErrorState();
    notifyListeners();
    try {
      _messages = await repository.listMessages(
        accountId: activeAccountId!,
        sessionId: sessionId,
      );
    } on Phase2RepositoryException catch (error) {
      _setTransientError(_errorFromCode(error.code));
    } catch (_) {
      _setTransientError(_errorFromCode('ai_chat_messages_load_failed'));
    } finally {
      _loadingMessages = false;
      notifyListeners();
    }
  }

  void startNewSession() {
    _selectedSessionId = null;
    _messages = const <AiChatMessage>[];
    _pendingUserText = null;
    _pendingUserAttachments = const <AiGatewayImageAttachment>[];
    _runtimeAssistantFoodDrafts = const <String, AiFoodDraft>{};
    _runtimeAssistantWorkoutDrafts = const <String, AiWorkoutDraft>{};
    _lastSuccessfulResponse = null;
    _clearErrorState();
    notifyListeners();
  }

  Future<bool> sendText({
    required String text,
    required String language,
    required AiGatewayModelChoice modelChoice,
    required String deviceId,
    String? selectedDate,
    String? profileVersion,
    bool allowRecordSummaryContext = false,
    List<AiGatewayImageAttachment> attachments =
        const <AiGatewayImageAttachment>[],
  }) async {
    final trimmed = text.trim();
    final activeAccountId = _accountId;
    if ((trimmed.isEmpty && attachments.isEmpty) || _sending) {
      return false;
    }
    if ((activeAccountId ?? '').isEmpty) {
      _setTransientError(_errorFromCode(AiGatewayErrorCode.authRequired.value));
      notifyListeners();
      return false;
    }

    _sending = true;
    _pendingUserText = trimmed;
    _pendingUserAttachments = List<AiGatewayImageAttachment>.unmodifiable(
      attachments,
    );
    _lastSuccessfulResponse = null;
    _clearErrorState();
    notifyListeners();

    final request = AiGatewayRequest(
      sessionId: _selectedSessionId,
      messageText: trimmed,
      language: language,
      modelChoice: modelChoice,
      attachments: attachments,
      selectedDate: selectedDate,
      profileVersion: profileVersion,
      deviceId: deviceId,
      allowRecordSummaryContext: allowRecordSummaryContext,
      client: const <String, dynamic>{
        'platform': 'flutter',
        'app_version': 'phase4',
      },
      conversationContext: _buildConversationContext(),
    );

    try {
      final response = await repository.sendMessage(request);
      if (response.error != null) {
        _setTransientError(response.error!);
        if (response.error!.isDeviceReplaced) {
          onDeviceReplaced?.call();
        }
        await _refreshSelectedMessagesAfterFailure();
        return false;
      }
      final nextSessionId = response.sessionId;
      if ((nextSessionId ?? '').isEmpty) {
        _setTransientError(_errorFromCode('unknown'));
        return false;
      }
      _selectedSessionId = nextSessionId;
      _lastSuccessfulResponse = response;
      await loadSessions();
      await loadMessages(nextSessionId!);
      _rememberRuntimeAttachmentsForLatestUserMessage(
        sessionId: nextSessionId,
        text: trimmed,
        attachments: attachments,
      );
      _rememberRuntimeDraftForAssistantMessage(response);
      _pendingUserText = null;
      _pendingUserAttachments = const <AiGatewayImageAttachment>[];
      return true;
    } catch (_) {
      _setTransientError(
        _errorFromCode(AiGatewayErrorCode.networkFailure.value),
      );
      await _refreshSelectedMessagesAfterFailure();
      return false;
    } finally {
      _sending = false;
      _pendingUserText = null;
      _pendingUserAttachments = const <AiGatewayImageAttachment>[];
      notifyListeners();
    }
  }

  Future<void> archiveSelectedSession() async {
    final sessionId = _selectedSessionId;
    if ((sessionId ?? '').isEmpty) {
      return;
    }
    await archiveSession(sessionId!);
  }

  Future<void> archiveSession(String sessionId) async {
    try {
      await repository.archiveSession(sessionId, archived: true);
      if (_selectedSessionId == sessionId) {
        startNewSession();
      }
      await loadSessions();
    } catch (_) {
      _setTransientError(_errorFromCode('ai_chat_archive_failed'));
      notifyListeners();
    }
  }

  Future<bool> renameSession(String sessionId, String title) async {
    final trimmed = title.trim();
    if (sessionId.isEmpty || trimmed.isEmpty) {
      _setTransientError(_errorFromCode('ai_chat_rename_failed'));
      notifyListeners();
      return false;
    }
    final previousSessions = _sessions;
    _sessions = _sessions
        .map(
          (session) => session.id == sessionId
              ? _copySessionWithTitle(session, trimmed)
              : session,
        )
        .toList(growable: false);
    _clearErrorState();
    notifyListeners();
    try {
      await repository.renameSession(sessionId, trimmed);
      await loadSessions();
      return true;
    } catch (_) {
      _sessions = previousSessions;
      _setTransientError(_errorFromCode('ai_chat_rename_failed'));
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteSelectedSession() async {
    final sessionId = _selectedSessionId;
    if ((sessionId ?? '').isEmpty) {
      return;
    }
    await deleteSession(sessionId!);
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      await repository.deleteSession(sessionId);
      if (_selectedSessionId == sessionId) {
        startNewSession();
      }
      await loadSessions();
    } catch (_) {
      _setTransientError(_errorFromCode('ai_chat_delete_failed'));
      notifyListeners();
    }
  }

  Future<void> _refreshSelectedMessagesAfterFailure() async {
    final sessionId = _selectedSessionId;
    if ((sessionId ?? '').isNotEmpty) {
      await loadMessages(sessionId!);
    }
  }

  void _rememberRuntimeAttachmentsForLatestUserMessage({
    required String sessionId,
    required String text,
    required List<AiGatewayImageAttachment> attachments,
  }) {
    if (attachments.isEmpty) {
      return;
    }
    final trimmed = text.trim();
    final userMessages = _messages
        .where((message) => message.sessionId == sessionId && message.isUser)
        .toList(growable: false);
    if (userMessages.isEmpty) {
      return;
    }

    AiChatMessage selected = userMessages.last;
    for (final message in userMessages.reversed) {
      if (message.contentText.trim() == trimmed) {
        selected = message;
        break;
      }
    }

    _runtimeUserAttachments =
        Map<String, List<AiGatewayImageAttachment>>.unmodifiable(<
          String,
          List<AiGatewayImageAttachment>
        >{
          ..._runtimeUserAttachments,
          selected.id: List<AiGatewayImageAttachment>.unmodifiable(attachments),
        });
  }

  void _rememberRuntimeDraftForAssistantMessage(AiGatewayResponse response) {
    final assistantMessageId = response.assistantMessageId;
    if ((assistantMessageId ?? '').isEmpty) {
      return;
    }
    final foodDraft = response.foodDraft;
    if (foodDraft != null) {
      _runtimeAssistantFoodDrafts = Map<String, AiFoodDraft>.unmodifiable(
        <String, AiFoodDraft>{
          ..._runtimeAssistantFoodDrafts,
          assistantMessageId!: foodDraft,
        },
      );
    }
    final workoutDraft = response.workoutDraft;
    if (workoutDraft != null) {
      _runtimeAssistantWorkoutDrafts = Map<String, AiWorkoutDraft>.unmodifiable(
        <String, AiWorkoutDraft>{
          ..._runtimeAssistantWorkoutDrafts,
          assistantMessageId!: workoutDraft,
        },
      );
    }
  }

  AiGatewayConversationContext? _buildConversationContext() {
    if (_messages.isEmpty) {
      return null;
    }
    final recentMessages = _messages
        .where((message) => !message.isDeleted)
        .toList(growable: false);
    if (recentMessages.isEmpty) {
      return null;
    }
    final contextMessages = recentMessages
        .skip(recentMessages.length > 8 ? recentMessages.length - 8 : 0)
        .map(
          (message) => AiGatewayContextMessage(
            role: message.role.value,
            text: _truncateContextText(message.contentText),
          ),
        )
        .where((message) => message.text.trim().isNotEmpty)
        .toList(growable: false);
    final artifactSummaries = <AiGatewayArtifactSummary>[];
    for (final message in recentMessages.reversed) {
      if (!message.isAssistant) {
        continue;
      }
      final food = foodDraftArtifactFor(message);
      if (food != null) {
        artifactSummaries.add(
          AiGatewayArtifactSummary(
            type: 'food_draft',
            title: food.mealName,
            summary: food.caloriesKcal == null
                ? 'Food draft artifact'
                : 'Food draft artifact, about ${food.caloriesKcal!.round()} kcal',
          ),
        );
      }
      final workout = workoutDraftArtifactFor(message);
      if (workout != null) {
        artifactSummaries.add(
          AiGatewayArtifactSummary(
            type: 'workout_draft',
            title: workout.recordName,
            summary:
                'Workout draft artifact, ${workout.exerciseCount} exercises',
          ),
        );
      }
      if (artifactSummaries.length >= 4) {
        break;
      }
    }
    final context = AiGatewayConversationContext(
      messages: contextMessages,
      artifacts: artifactSummaries.reversed.toList(growable: false),
    );
    return context.isNotEmpty ? context : null;
  }

  String _truncateContextText(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 800) {
      return trimmed;
    }
    return '${trimmed.substring(0, 800)}...';
  }

  AiGatewayError _errorFromCode(String code) {
    final mapped = aiGatewayErrorCodeFromValue(code);
    return AiGatewayError(code: mapped, rawCode: code);
  }

  void _setTransientError(AiGatewayError error) {
    _lastError = error;
  }

  void _clearErrorState() {
    _lastError = null;
  }
}

AiFoodDraftArtifact? _foodArtifactFromRuntime(AiFoodDraft? draft) {
  if (draft == null) {
    return null;
  }
  return AiFoodDraftArtifact(
    mealName: draft.mealName,
    caloriesKcal: draft.caloriesKcal,
    draft: draft,
  );
}

AiWorkoutDraftArtifact? _workoutArtifactFromRuntime(AiWorkoutDraft? draft) {
  if (draft == null) {
    return null;
  }
  return AiWorkoutDraftArtifact(
    recordName: draft.recordName,
    exerciseCount: draft.exercises.length,
    draft: draft,
  );
}

AiChatSession _copySessionWithTitle(AiChatSession session, String title) {
  return AiChatSession(
    id: session.id,
    accountId: session.accountId,
    title: title,
    language: session.language,
    lastMessageAt: session.lastMessageAt,
    archivedAt: session.archivedAt,
    deletedAt: session.deletedAt,
    createdAt: session.createdAt,
    updatedAt: DateTime.now().toUtc(),
  );
}
