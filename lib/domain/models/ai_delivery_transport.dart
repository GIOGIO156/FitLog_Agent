enum AiDeliveryKind { aiChat, foodPhotoAnalysis }

enum AiDeliveryStatus { queued, running, succeeded, failed, cancelled }

class AiDeliveryTransport {
  const AiDeliveryTransport({
    required this.requestId,
    required this.kind,
    required this.status,
    this.accepted = false,
    this.retryable = false,
    this.duplicateSubmit = false,
    this.errorCode,
  });

  final String requestId;
  final AiDeliveryKind kind;
  final AiDeliveryStatus status;
  final bool accepted;
  final bool retryable;
  final bool duplicateSubmit;
  final String? errorCode;

  bool get isAccepted => accepted && requestId.isNotEmpty;
  bool get isPending =>
      status == AiDeliveryStatus.queued || status == AiDeliveryStatus.running;

  factory AiDeliveryTransport.fromJson(Map<String, dynamic> json) {
    return AiDeliveryTransport(
      requestId: (json['request_id'] ?? '').toString(),
      kind: _kindFromValue(json['kind']?.toString()),
      status: _statusFromValue(json['status']?.toString()),
      accepted: json['accepted'] == true,
      retryable: json['retryable'] == true,
      duplicateSubmit: json['duplicate_submit'] == true,
      errorCode: json['error_code']?.toString(),
    );
  }

  static AiDeliveryTransport? fromJsonOrNull(Object? value) {
    if (value is! Map) {
      return null;
    }
    final transport = AiDeliveryTransport.fromJson(
      Map<String, dynamic>.from(value),
    );
    return transport.requestId.isEmpty ? null : transport;
  }
}

AiDeliveryKind _kindFromValue(String? value) {
  switch (value) {
    case 'food_photo_analysis':
      return AiDeliveryKind.foodPhotoAnalysis;
    case 'ai_chat':
    default:
      return AiDeliveryKind.aiChat;
  }
}

AiDeliveryStatus _statusFromValue(String? value) {
  switch (value) {
    case 'running':
      return AiDeliveryStatus.running;
    case 'succeeded':
      return AiDeliveryStatus.succeeded;
    case 'failed':
      return AiDeliveryStatus.failed;
    case 'cancelled':
      return AiDeliveryStatus.cancelled;
    case 'queued':
    default:
      return AiDeliveryStatus.queued;
  }
}
