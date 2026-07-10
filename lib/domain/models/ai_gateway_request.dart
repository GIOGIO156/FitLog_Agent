enum AiGatewayModelChoice { chatgpt, qwen }

extension AiGatewayModelChoiceValue on AiGatewayModelChoice {
  String get value {
    switch (this) {
      case AiGatewayModelChoice.chatgpt:
        return 'chatgpt';
      case AiGatewayModelChoice.qwen:
        return 'qwen';
    }
  }
}

AiGatewayModelChoice aiGatewayModelChoiceFromValue(String value) {
  switch (value) {
    case 'chatgpt':
      return AiGatewayModelChoice.chatgpt;
    case 'qwen':
      return AiGatewayModelChoice.qwen;
    default:
      throw FormatException('Unsupported AI model choice: $value');
  }
}

enum AiGatewayWorkflowHint {
  auto,
  foodLogging,
  mealDecision,
  weeklyReview,
  appLogicAnswer,
}

extension AiGatewayWorkflowHintValue on AiGatewayWorkflowHint {
  String get value {
    switch (this) {
      case AiGatewayWorkflowHint.auto:
        return 'auto';
      case AiGatewayWorkflowHint.foodLogging:
        return 'food_logging';
      case AiGatewayWorkflowHint.mealDecision:
        return 'meal_decision';
      case AiGatewayWorkflowHint.weeklyReview:
        return 'weekly_review';
      case AiGatewayWorkflowHint.appLogicAnswer:
        return 'app_logic_answer';
    }
  }
}

class AiGatewayRequest {
  const AiGatewayRequest({
    this.sessionId,
    required this.messageText,
    required this.language,
    required this.modelChoice,
    this.workflowHint = AiGatewayWorkflowHint.auto,
    this.attachments = const <AiGatewayImageAttachment>[],
    this.selectedDate,
    this.profileVersion,
    required this.deviceId,
    this.allowRecordSummaryContext = false,
    this.client = const <String, dynamic>{},
    this.conversationContext,
  });

  final String? sessionId;
  final String messageText;
  final String language;
  final AiGatewayModelChoice modelChoice;
  final AiGatewayWorkflowHint workflowHint;
  final List<AiGatewayImageAttachment> attachments;
  final String? selectedDate;
  final String? profileVersion;
  final String deviceId;
  final bool allowRecordSummaryContext;
  final Map<String, dynamic> client;
  final AiGatewayConversationContext? conversationContext;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (sessionId != null) 'session_id': sessionId,
      'message': <String, dynamic>{'text': messageText},
      'language': language,
      'model_choice': modelChoice.value,
      'workflow_hint': workflowHint.value,
      if (attachments.isNotEmpty)
        'attachments': attachments
            .map((attachment) => attachment.toJson())
            .toList(growable: false),
      if (selectedDate != null) 'selected_date': selectedDate,
      if (profileVersion != null) 'profile_version': profileVersion,
      'device_id': deviceId,
      'allow_record_summary_context': allowRecordSummaryContext,
      if (client.isNotEmpty) 'client': Map<String, dynamic>.from(client),
      if (conversationContext?.isNotEmpty == true)
        'conversation_context': conversationContext!.toJson(),
    };
  }
}

class AiGatewayConversationContext {
  const AiGatewayConversationContext({
    this.messages = const <AiGatewayContextMessage>[],
    this.artifacts = const <AiGatewayArtifactSummary>[],
  });

  final List<AiGatewayContextMessage> messages;
  final List<AiGatewayArtifactSummary> artifacts;

  bool get isNotEmpty => messages.isNotEmpty || artifacts.isNotEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (messages.isNotEmpty)
        'messages': messages.map((message) => message.toJson()).toList(),
      if (artifacts.isNotEmpty)
        'artifacts': artifacts.map((artifact) => artifact.toJson()).toList(),
    };
  }
}

class AiGatewayContextMessage {
  const AiGatewayContextMessage({required this.role, required this.text});

  final String role;
  final String text;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'role': role, 'text': text};
  }
}

class AiGatewayArtifactSummary {
  const AiGatewayArtifactSummary({
    required this.type,
    required this.title,
    required this.summary,
  });

  final String type;
  final String title;
  final String summary;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'type': type, 'title': title, 'summary': summary};
  }
}

class AiGatewayImageAttachment {
  const AiGatewayImageAttachment({
    required this.mimeType,
    required this.base64Data,
    required this.byteLength,
    this.name,
  });

  final String mimeType;
  final String base64Data;
  final int byteLength;
  final String? name;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': 'image',
      'mime_type': mimeType,
      'base64_data': base64Data,
      'byte_length': byteLength,
      if ((name ?? '').trim().isNotEmpty) 'name': name!.trim(),
    };
  }
}
