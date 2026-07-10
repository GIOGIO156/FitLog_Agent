import 'ai_gateway_error.dart';
import 'ai_gateway_evidence.dart';
import 'ai_gateway_request.dart';
import 'ai_food_photo_analysis.dart';
import 'ai_workout_draft.dart';

class AiGatewayResponse {
  const AiGatewayResponse({
    this.sessionId,
    this.assistantMessageId,
    this.modelChoice,
    this.modelProvider,
    this.messageText,
    this.messageLanguage,
    this.workflow = 'auto',
    this.needsClarification = false,
    this.clarificationQuestions = const <String>[],
    this.foodDraft,
    this.workoutDraft,
    this.evidence,
    this.debugSummaryId,
    this.error,
    this.hasUnsupportedDraftPayload = false,
  });

  final String? sessionId;
  final String? assistantMessageId;
  final AiGatewayModelChoice? modelChoice;
  final String? modelProvider;
  final String? messageText;
  final String? messageLanguage;
  final String workflow;
  final bool needsClarification;
  final List<String> clarificationQuestions;
  final AiFoodDraft? foodDraft;
  final AiWorkoutDraft? workoutDraft;
  final AiGatewayEvidence? evidence;
  final String? debugSummaryId;
  final AiGatewayError? error;
  final bool hasUnsupportedDraftPayload;

  bool get isSuccess => error == null;
  bool get canShowAssistantText =>
      isSuccess && (messageText ?? '').trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (sessionId != null) 'session_id': sessionId,
      if (assistantMessageId != null)
        'assistant_message_id': assistantMessageId,
      if (modelChoice != null) 'model_choice': modelChoice!.value,
      if (modelProvider != null) 'model_provider': modelProvider,
      'message': <String, dynamic>{
        if (messageText != null) 'text': messageText,
        if (messageLanguage != null) 'language': messageLanguage,
      },
      'workflow': workflow,
      'needs_clarification': needsClarification,
      'clarification_questions': clarificationQuestions,
      'draft': foodDraft != null ? foodDraft!.toJson() : workoutDraft?.toJson(),
      'evidence': evidence?.toJson(),
      if (debugSummaryId != null) 'debug_summary_id': debugSummaryId,
      'error': error?.toJson(),
    };
  }

  factory AiGatewayResponse.fromJson(Map<String, dynamic> json) {
    final message = _mapOrEmpty(json['message']);
    final rawModelChoice = json['model_choice']?.toString();
    final rawDraft = json['draft'];
    AiFoodDraft? foodDraft;
    AiWorkoutDraft? workoutDraft;
    var hasUnsupportedDraftPayload = false;
    if (rawDraft is Map) {
      try {
        final draft = Map<String, dynamic>.from(rawDraft);
        if (draft['schema_version'] == aiWorkoutDraftSchemaVersion) {
          workoutDraft = AiWorkoutDraft.fromJson(draft);
        } else {
          foodDraft = AiFoodDraft.fromJson(draft);
        }
      } on FormatException {
        hasUnsupportedDraftPayload = true;
      }
    } else if (rawDraft != null) {
      hasUnsupportedDraftPayload = true;
    }

    return AiGatewayResponse(
      sessionId: json['session_id']?.toString(),
      assistantMessageId: json['assistant_message_id']?.toString(),
      modelChoice: rawModelChoice == null
          ? null
          : aiGatewayModelChoiceFromValue(rawModelChoice),
      modelProvider: json['model_provider']?.toString(),
      messageText: message['text']?.toString(),
      messageLanguage: message['language']?.toString(),
      workflow: (json['workflow'] ?? 'auto').toString(),
      needsClarification: json['needs_clarification'] == true,
      clarificationQuestions: _stringList(json['clarification_questions']),
      foodDraft: foodDraft,
      workoutDraft: workoutDraft,
      evidence: AiGatewayEvidence.fromJsonOrNull(json['evidence']),
      debugSummaryId: json['debug_summary_id']?.toString(),
      error: AiGatewayError.fromJsonOrNull(json['error']),
      hasUnsupportedDraftPayload: hasUnsupportedDraftPayload,
    );
  }
}

Map<String, dynamic> _mapOrEmpty(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.map((item) => item.toString()).toList(growable: false);
}
