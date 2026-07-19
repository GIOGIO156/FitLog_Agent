enum AiChatClarificationKind { intentSelection, missingBusinessFields }

enum AiChatAttachmentPolicy {
  none,
  consumeCurrent,
  runtimeRebindAvailable,
  resendRequired,
}

class AiChatClarificationOption {
  const AiChatClarificationOption({
    required this.id,
    required this.labelZh,
    required this.labelEn,
    this.resultingOutput = 'text',
  });

  final String id;
  final String labelZh;
  final String labelEn;
  final String resultingOutput;

  String labelFor(String language) => language == 'zh' ? labelZh : labelEn;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label_zh': labelZh,
    'label_en': labelEn,
    'resulting_output': resultingOutput,
  };

  factory AiChatClarificationOption.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString();
    if (!const <String>{'answer', 'food_draft', 'workout_draft'}.contains(id)) {
      throw FormatException('Unsupported clarification option: $id');
    }
    return AiChatClarificationOption(
      id: id,
      labelZh: (json['label_zh'] ?? '').toString(),
      labelEn: (json['label_en'] ?? '').toString(),
      resultingOutput:
          (json['resulting_output'] ??
                  switch (id) {
                    'answer' => 'text',
                    'food_draft' => 'food_draft',
                    'workout_draft' => 'workout_draft',
                    _ => 'text',
                  })
              .toString(),
    );
  }
}

class AiChatClarification {
  const AiChatClarification({
    required this.id,
    required this.kind,
    required this.options,
    required this.missingDimensions,
    required this.attachmentPolicy,
    this.question = '',
    this.attempt = 1,
    this.expiresAt,
    this.state = 'pending',
  });

  final String id;
  final AiChatClarificationKind kind;
  final List<AiChatClarificationOption> options;
  final List<String> missingDimensions;
  final AiChatAttachmentPolicy attachmentPolicy;
  final String question;
  final int attempt;
  final DateTime? expiresAt;
  final String state;

  bool get isIntentSelection => kind == AiChatClarificationKind.intentSelection;
  bool get isMissingBusinessFields =>
      kind == AiChatClarificationKind.missingBusinessFields;
  bool get needsRuntimeAttachment =>
      attachmentPolicy == AiChatAttachmentPolicy.runtimeRebindAvailable ||
      attachmentPolicy == AiChatAttachmentPolicy.resendRequired;
  bool get isActive =>
      (state == 'pending' || state == 'resolving') &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now().toUtc()));

  AiChatClarification copyWith({
    AiChatAttachmentPolicy? attachmentPolicy,
    String? state,
  }) {
    return AiChatClarification(
      id: id,
      kind: kind,
      options: options,
      missingDimensions: missingDimensions,
      attachmentPolicy: attachmentPolicy ?? this.attachmentPolicy,
      question: question,
      attempt: attempt,
      expiresAt: expiresAt,
      state: state ?? this.state,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'schema_version': 'ai_chat_clarification.v2',
    'clarification_id': id,
    'kind': kind == AiChatClarificationKind.intentSelection
        ? 'intent_selection'
        : 'missing_business_fields',
    'options': options.map((option) => option.toJson()).toList(growable: false),
    'missing_dimensions': missingDimensions,
    'attachment_policy': switch (attachmentPolicy) {
      AiChatAttachmentPolicy.none => 'none',
      AiChatAttachmentPolicy.consumeCurrent => 'consume_current',
      AiChatAttachmentPolicy.runtimeRebindAvailable =>
        'runtime_rebind_available',
      AiChatAttachmentPolicy.resendRequired => 'resend_required',
    },
    'question': question,
    'attempt': attempt,
    if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
    'state': state,
  };

  factory AiChatClarification.fromJson(Map<String, dynamic> json) {
    final id = (json['clarification_id'] ?? json['id'] ?? '').toString();
    final schema = (json['schema_version'] ?? 'ai_chat_clarification.v2')
        .toString();
    if (id.isEmpty ||
        (schema != 'ai_chat_clarification.v2' &&
            schema != 'chat_clarification.v2')) {
      throw const FormatException('Invalid chat clarification identity.');
    }
    final rawKind = (json['kind'] ?? '').toString();
    final kind = switch (rawKind) {
      'intent_selection' => AiChatClarificationKind.intentSelection,
      'missing_business_fields' =>
        AiChatClarificationKind.missingBusinessFields,
      _ => throw FormatException('Unsupported clarification kind: $rawKind'),
    };
    final rawOptions = json['options'] ?? json['options_json'];
    final options = <AiChatClarificationOption>[];
    if (rawOptions is List) {
      for (final value in rawOptions.whereType<Map>()) {
        try {
          options.add(
            AiChatClarificationOption.fromJson(
              Map<String, dynamic>.from(value),
            ),
          );
        } on FormatException {
          // The service-only "continue" option is consumed by free-text input.
        }
      }
    }
    if (kind == AiChatClarificationKind.intentSelection && options.isEmpty) {
      throw const FormatException('Intent clarification requires options.');
    }
    final rawPolicy = (json['attachment_policy'] ?? 'none').toString();
    final attachmentPolicy = switch (rawPolicy) {
      'none' => AiChatAttachmentPolicy.none,
      'consume_current' => AiChatAttachmentPolicy.consumeCurrent,
      'runtime_rebind_available' =>
        AiChatAttachmentPolicy.runtimeRebindAvailable,
      'resend_required' => AiChatAttachmentPolicy.resendRequired,
      _ => throw FormatException(
        'Unsupported clarification attachment policy: $rawPolicy',
      ),
    };
    final rawMissing =
        json['missing_dimensions'] ?? json['missing_dimensions_json'];
    return AiChatClarification(
      id: id,
      kind: kind,
      options: options,
      missingDimensions: rawMissing is List
          ? rawMissing.map((value) => value.toString()).toList(growable: false)
          : const <String>[],
      attachmentPolicy: attachmentPolicy,
      question: (json['question'] ?? '').toString(),
      attempt: switch (json['attempt'] ?? json['attempt_count']) {
        final int value => value,
        final num value => value.toInt(),
        _ => 1,
      },
      expiresAt: DateTime.tryParse(
        (json['expires_at'] ?? '').toString(),
      )?.toUtc(),
      state: (json['state'] ?? 'pending').toString(),
    );
  }

  static AiChatClarification? fromJsonOrNull(Object? value) {
    if (value is! Map) return null;
    try {
      return AiChatClarification.fromJson(Map<String, dynamic>.from(value));
    } on FormatException {
      return null;
    }
  }
}

class AiChatClarificationReply {
  const AiChatClarificationReply({
    required this.clarificationId,
    required this.optionId,
    required this.clientRequestId,
  });

  final String clarificationId;
  final String optionId;
  final String clientRequestId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'clarification_id': clarificationId,
    'option_id': optionId,
    'client_request_id': clientRequestId,
  };
}
