import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/ai_chat_repository.dart';
import '../../data/repositories/custom_exercise_repository.dart';
import '../../data/repositories/phase2_repository_exception.dart';
import '../../domain/models/ai_chat_message.dart';
import '../../domain/models/ai_chat_clarification.dart';
import '../../domain/models/ai_chat_session.dart';
import '../../domain/models/ai_food_photo_analysis.dart';
import '../../domain/models/ai_exercise_reference.dart';
import '../../domain/models/ai_gateway_error.dart';
import '../../domain/models/ai_gateway_request.dart';
import '../../domain/models/ai_gateway_response.dart';
import '../../domain/models/ai_workout_draft.dart';
import '../../domain/services/ai_exercise_reference_builder.dart';

class AiChatController extends ChangeNotifier {
  AiChatController({
    required this.repository,
    this.customExerciseRepository,
    this.onDeviceReplaced,
  });

  final AiChatRepository repository;
  final CustomExerciseRepository? customExerciseRepository;
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
  Map<String, _ClarificationAttachmentLease> _clarificationAttachmentLeases =
      const <String, _ClarificationAttachmentLease>{};
  Map<String, String> _clarificationRetryRequestIds = const <String, String>{};
  AiChatClarification? _activeClarification;
  int _clientRequestSequence = 0;
  int _localDataEpoch = 0;
  AiGatewayError? _lastError;
  AiGatewayResponse? _lastSuccessfulResponse;
  final Set<String> _deletingSessionIds = <String>{};

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
  AiChatClarification? get activeClarification => _activeClarification;
  bool get deletingSession => _deletingSessionIds.isNotEmpty;
  bool isDeletingSession(String sessionId) =>
      _deletingSessionIds.contains(sessionId);
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

  AiChatClarification? clarificationFor(AiChatMessage message) {
    if (!message.isAssistant) return null;
    final clarification = message.clarification;
    if (clarification?.id != _activeClarification?.id) return null;
    return _activeClarification;
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
    _clarificationAttachmentLeases =
        const <String, _ClarificationAttachmentLease>{};
    _clarificationRetryRequestIds = const <String, String>{};
    _activeClarification = null;
    _lastSuccessfulResponse = null;
    _deletingSessionIds.clear();
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
    _clarificationAttachmentLeases =
        const <String, _ClarificationAttachmentLease>{};
    _clarificationRetryRequestIds = const <String, String>{};
    _activeClarification = null;
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
      final active = await repository.loadActiveClarification(
        accountId: activeAccountId,
        sessionId: sessionId,
      );
      _activeClarification =
          active != null &&
              active.needsRuntimeAttachment &&
              !_clarificationAttachmentLeases.containsKey(active.id)
          ? active.copyWith(
              attachmentPolicy: AiChatAttachmentPolicy.resendRequired,
            )
          : active;
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
    _clarificationAttachmentLeases =
        const <String, _ClarificationAttachmentLease>{};
    _clarificationRetryRequestIds = const <String, String>{};
    _activeClarification = null;
    _lastSuccessfulResponse = null;
    _clearErrorState();
    notifyListeners();
  }

  void handleLocalDataCleared() {
    _localDataEpoch += 1;
    _pendingUserAttachments = const <AiGatewayImageAttachment>[];
    _runtimeUserAttachments = const <String, List<AiGatewayImageAttachment>>{};
    _runtimeAssistantFoodDrafts = const <String, AiFoodDraft>{};
    _runtimeAssistantWorkoutDrafts = const <String, AiWorkoutDraft>{};
    _clarificationAttachmentLeases =
        const <String, _ClarificationAttachmentLease>{};
    _clarificationRetryRequestIds = const <String, String>{};
    final active = _activeClarification;
    if (active?.needsRuntimeAttachment == true) {
      _activeClarification = active!.copyWith(
        attachmentPolicy: AiChatAttachmentPolicy.resendRequired,
      );
    }
    _lastSuccessfulResponse = null;
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
    AiChatClarificationReply? clarificationReply,
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

    var outboundAttachments = attachments;
    final continuationClarification =
        clarificationReply == null &&
            _activeClarification?.isMissingBusinessFields == true
        ? _activeClarification
        : null;
    final consumedClarificationId =
        clarificationReply?.clarificationId ?? continuationClarification?.id;
    if (continuationClarification?.needsRuntimeAttachment == true) {
      final lease = _validClarificationLease(continuationClarification!.id);
      if (lease == null) {
        _setTransientError(
          _errorFromCode(AiGatewayErrorCode.attachmentUnavailable.value),
        );
        notifyListeners();
        return false;
      }
      outboundAttachments = lease.attachments;
    }

    _sending = true;
    final sendLocalDataEpoch = _localDataEpoch;
    _pendingUserText = trimmed;
    _pendingUserAttachments = List<AiGatewayImageAttachment>.unmodifiable(
      outboundAttachments,
    );
    _lastSuccessfulResponse = null;
    _clearErrorState();
    notifyListeners();

    var exerciseReferences = const <AiExerciseReference>[];
    try {
      if (customExerciseRepository != null) {
        exerciseReferences = await AiExerciseReferenceBuilder(
          customExerciseRepository!,
        ).buildForMessage(trimmed);
      }
    } catch (_) {
      exerciseReferences = const <AiExerciseReference>[];
    }
    final request = AiGatewayRequest(
      sessionId: _selectedSessionId,
      messageText: trimmed,
      language: language,
      modelChoice: modelChoice,
      attachments: outboundAttachments,
      selectedDate: selectedDate,
      profileVersion: profileVersion,
      deviceId: deviceId,
      allowRecordSummaryContext: allowRecordSummaryContext,
      client: const <String, dynamic>{
        'platform': 'flutter',
        'app_version': 'phase4',
        'draft_schema_version': 'v3',
      },
      conversationContext: _buildConversationContext(),
      exerciseReferences: exerciseReferences,
      clientRequestId:
          clarificationReply?.clientRequestId ??
          (continuationClarification == null
              ? _nextClientRequestId()
              : _requestIdForClarification(continuationClarification.id)),
      clarificationReply: clarificationReply,
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
      if (sendLocalDataEpoch == _localDataEpoch) {
        _rememberRuntimeAttachmentsForLatestUserMessage(
          sessionId: nextSessionId,
          text: trimmed,
          attachments: outboundAttachments,
        );
        _rememberRuntimeDraftForAssistantMessage(response);
      }
      if (consumedClarificationId != null) {
        _consumeClarificationLease(consumedClarificationId);
      }
      if (sendLocalDataEpoch == _localDataEpoch) {
        _rememberClarificationRuntime(response, outboundAttachments);
      }
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

  Future<bool> sendClarificationOption({
    required AiChatClarificationOption option,
    required String language,
    required AiGatewayModelChoice modelChoice,
    required String deviceId,
    String? selectedDate,
    String? profileVersion,
    bool allowRecordSummaryContext = false,
  }) async {
    final clarification = _activeClarification;
    if (clarification == null ||
        !clarification.options.any((candidate) => candidate.id == option.id)) {
      _setTransientError(
        _errorFromCode(AiGatewayErrorCode.clarificationConflict.value),
      );
      notifyListeners();
      return false;
    }
    var attachments = const <AiGatewayImageAttachment>[];
    if (clarification.needsRuntimeAttachment) {
      final lease = _validClarificationLease(clarification.id);
      if (lease == null) {
        _setTransientError(
          _errorFromCode(AiGatewayErrorCode.attachmentUnavailable.value),
        );
        notifyListeners();
        return false;
      }
      attachments = lease.attachments;
    }
    final requestId = _requestIdForClarification(clarification.id);
    return sendText(
      text: option.labelFor(language),
      language: language,
      modelChoice: modelChoice,
      deviceId: deviceId,
      selectedDate: selectedDate,
      profileVersion: profileVersion,
      allowRecordSummaryContext: allowRecordSummaryContext,
      attachments: attachments,
      clarificationReply: AiChatClarificationReply(
        clarificationId: clarification.id,
        optionId: option.id,
        clientRequestId: requestId,
      ),
    );
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
    if (sessionId.isEmpty || deletingSession) {
      return;
    }
    _deletingSessionIds.add(sessionId);
    _clearErrorState();
    notifyListeners();
    try {
      await repository.deleteSession(sessionId);
      if (_selectedSessionId == sessionId) {
        startNewSession();
      }
      await loadSessions();
    } catch (_) {
      _setTransientError(_errorFromCode('ai_chat_delete_failed'));
    } finally {
      _deletingSessionIds.remove(sessionId);
      notifyListeners();
    }
  }

  Future<void> _refreshSelectedMessagesAfterFailure() async {
    final sessionId = _selectedSessionId;
    if ((sessionId ?? '').isNotEmpty) {
      final sendError = _lastError;
      await loadMessages(sessionId!);
      if (sendError != null) {
        _lastError = sendError;
      }
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

  void _rememberClarificationRuntime(
    AiGatewayResponse response,
    List<AiGatewayImageAttachment> attachments,
  ) {
    final clarification = response.clarification;
    final accountId = _accountId;
    final sessionId = response.sessionId ?? _selectedSessionId;
    if (clarification == null ||
        (accountId ?? '').isEmpty ||
        (sessionId ?? '').isEmpty) {
      return;
    }
    _activeClarification = clarification;
    if (clarification.needsRuntimeAttachment && attachments.isNotEmpty) {
      _clarificationAttachmentLeases =
          Map<String, _ClarificationAttachmentLease>.unmodifiable(
            <String, _ClarificationAttachmentLease>{
              ..._clarificationAttachmentLeases,
              clarification.id: _ClarificationAttachmentLease(
                accountId: accountId!,
                sessionId: sessionId!,
                attachments: List<AiGatewayImageAttachment>.unmodifiable(
                  attachments,
                ),
              ),
            },
          );
    } else if (clarification.needsRuntimeAttachment) {
      _activeClarification = clarification.copyWith(
        attachmentPolicy: AiChatAttachmentPolicy.resendRequired,
      );
    }
  }

  _ClarificationAttachmentLease? _validClarificationLease(String id) {
    final lease = _clarificationAttachmentLeases[id];
    if (lease == null ||
        lease.accountId != _accountId ||
        lease.sessionId != _selectedSessionId ||
        lease.attachments.isEmpty) {
      return null;
    }
    return lease;
  }

  void _consumeClarificationLease(String id) {
    if (_clarificationAttachmentLeases.containsKey(id)) {
      final next = Map<String, _ClarificationAttachmentLease>.from(
        _clarificationAttachmentLeases,
      )..remove(id);
      _clarificationAttachmentLeases = Map.unmodifiable(next);
    }
    if (_activeClarification?.id == id) {
      _activeClarification = null;
    }
    if (_clarificationRetryRequestIds.containsKey(id)) {
      final next = Map<String, String>.from(_clarificationRetryRequestIds)
        ..remove(id);
      _clarificationRetryRequestIds = Map.unmodifiable(next);
    }
  }

  String _requestIdForClarification(String clarificationId) {
    final existing = _clarificationRetryRequestIds[clarificationId];
    if (existing != null) return existing;
    final created = _nextClientRequestId();
    _clarificationRetryRequestIds = Map<String, String>.unmodifiable(
      <String, String>{
        ..._clarificationRetryRequestIds,
        clarificationId: created,
      },
    );
    return created;
  }

  String _nextClientRequestId() {
    _clientRequestSequence += 1;
    return 'ai_${DateTime.now().toUtc().microsecondsSinceEpoch}_$_clientRequestSequence';
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
    if (code == 'record_network_error' ||
        code == 'active_device_network_error') {
      return AiGatewayError(
        code: AiGatewayErrorCode.networkFailure,
        rawCode: code,
      );
    }
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
    date: draft.date,
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
    date: draft.date,
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

class _ClarificationAttachmentLease {
  const _ClarificationAttachmentLease({
    required this.accountId,
    required this.sessionId,
    required this.attachments,
  });

  final String accountId;
  final String sessionId;
  final List<AiGatewayImageAttachment> attachments;
}
