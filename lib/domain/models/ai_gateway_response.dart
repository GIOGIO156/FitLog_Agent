import 'ai_gateway_error.dart';
import 'ai_gateway_evidence.dart';
import 'ai_gateway_request.dart';
import 'ai_food_photo_analysis.dart';
import 'ai_workout_draft.dart';

enum AiGatewayOutputType { text, foodDraft, workoutDraft, clarification }

extension AiGatewayOutputTypeValue on AiGatewayOutputType {
  String get value => switch (this) {
    AiGatewayOutputType.text => 'text',
    AiGatewayOutputType.foodDraft => 'food_draft',
    AiGatewayOutputType.workoutDraft => 'workout_draft',
    AiGatewayOutputType.clarification => 'clarification',
  };
}

class AiGatewayResponse {
  const AiGatewayResponse({
    this.sessionId,
    this.assistantMessageId,
    this.modelChoice,
    this.modelProvider,
    this.messageText,
    this.messageLanguage,
    this.workflow = 'auto',
    this.outputType,
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
  final AiGatewayOutputType? outputType;
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
      if (outputType != null) 'output_type': outputType!.value,
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

    final error = AiGatewayError.fromJsonOrNull(json['error']);
    if (error == null && (message['text']?.toString().trim() ?? '').isEmpty) {
      throw const FormatException(
        'Successful AI response requires message.text.',
      );
    }
    final outputType = _outputTypeFromJson(
      json['output_type'],
      needsClarification: json['needs_clarification'] == true,
      foodDraft: foodDraft,
      workoutDraft: workoutDraft,
      allowMissing: error != null,
    );
    if (hasUnsupportedDraftPayload) {
      throw const FormatException('Unsupported AI draft payload.');
    }
    _validateOutputPayload(
      outputType: outputType,
      needsClarification: json['needs_clarification'] == true,
      foodDraft: foodDraft,
      workoutDraft: workoutDraft,
    );

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
      outputType: outputType,
      needsClarification: json['needs_clarification'] == true,
      clarificationQuestions: _stringList(json['clarification_questions']),
      foodDraft: foodDraft,
      workoutDraft: workoutDraft,
      evidence: AiGatewayEvidence.fromJsonOrNull(json['evidence']),
      debugSummaryId: json['debug_summary_id']?.toString(),
      error: error,
      hasUnsupportedDraftPayload: hasUnsupportedDraftPayload,
    );
  }
}

AiGatewayOutputType? _outputTypeFromJson(
  Object? value, {
  required bool needsClarification,
  required AiFoodDraft? foodDraft,
  required AiWorkoutDraft? workoutDraft,
  required bool allowMissing,
}) {
  switch (value?.toString()) {
    case 'text':
      return AiGatewayOutputType.text;
    case 'food_draft':
      return AiGatewayOutputType.foodDraft;
    case 'workout_draft':
      return AiGatewayOutputType.workoutDraft;
    case 'clarification':
      return AiGatewayOutputType.clarification;
    case null:
    case '':
      if (needsClarification) return AiGatewayOutputType.clarification;
      if (foodDraft != null) return AiGatewayOutputType.foodDraft;
      if (workoutDraft != null) return AiGatewayOutputType.workoutDraft;
      return allowMissing ? null : AiGatewayOutputType.text;
    default:
      throw FormatException('Unsupported AI output_type: $value');
  }
}

void _validateOutputPayload({
  required AiGatewayOutputType? outputType,
  required bool needsClarification,
  required AiFoodDraft? foodDraft,
  required AiWorkoutDraft? workoutDraft,
}) {
  if (outputType == null) return;
  final hasDraft = foodDraft != null || workoutDraft != null;
  final valid = switch (outputType) {
    AiGatewayOutputType.text => !needsClarification && !hasDraft,
    AiGatewayOutputType.foodDraft =>
      !needsClarification && foodDraft != null && workoutDraft == null,
    AiGatewayOutputType.workoutDraft =>
      !needsClarification && workoutDraft != null && foodDraft == null,
    AiGatewayOutputType.clarification => needsClarification && !hasDraft,
  };
  if (!valid) {
    throw const FormatException('AI output_type does not match its payload.');
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
