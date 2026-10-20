import 'ai_delivery_transport.dart';
import 'ai_food_photo_analysis.dart';

class AiDeliveryRequest {
  const AiDeliveryRequest({
    required this.requestId,
    required this.kind,
    required this.clientRequestId,
    required this.status,
    this.sessionId,
    this.messageText,
    this.photoSelectedDate,
    this.photoUserNote,
    this.resultJson,
    this.errorCode,
    this.retryable = false,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  final String requestId;
  final AiDeliveryKind kind;
  final String clientRequestId;
  final AiDeliveryStatus status;
  final String? sessionId;
  final String? messageText;
  final String? photoSelectedDate;
  final String? photoUserNote;
  final Map<String, dynamic>? resultJson;
  final String? errorCode;
  final bool retryable;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  bool get isPending =>
      status == AiDeliveryStatus.queued || status == AiDeliveryStatus.running;
  bool get isSucceeded => status == AiDeliveryStatus.succeeded;
  bool get isFailed => status == AiDeliveryStatus.failed;
  bool get isCancelled => status == AiDeliveryStatus.cancelled;

  AiFoodPhotoAnalysisResponse? get photoResult {
    final result = resultJson;
    if (result == null || kind != AiDeliveryKind.foodPhotoAnalysis) {
      return null;
    }
    try {
      return AiFoodPhotoAnalysisResponse.fromJson(result);
    } on FormatException {
      return null;
    }
  }

  factory AiDeliveryRequest.fromMap(Map<String, dynamic> map) {
    return AiDeliveryRequest(
      requestId: (map['request_id'] ?? '').toString(),
      kind: _kindFromValue(map['kind']?.toString()),
      clientRequestId: (map['client_request_id'] ?? '').toString(),
      status: _statusFromValue(map['status']?.toString()),
      sessionId: map['session_id']?.toString(),
      messageText: _messageTextFromPayload(map['request_payload_json']),
      photoSelectedDate: _textFromPayload(
        map['request_payload_json'],
        'selected_date',
      ),
      photoUserNote: _textFromPayload(map['request_payload_json'], 'user_note'),
      resultJson: _mapOrNull(map['result_json']),
      errorCode: map['error_code']?.toString(),
      retryable: map['retryable'] == true,
      createdAt: _dateOrNull(map['created_at']),
      updatedAt: _dateOrNull(map['updated_at']),
      completedAt: _dateOrNull(map['completed_at']),
    );
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

Map<String, dynamic>? _mapOrNull(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

DateTime? _dateOrNull(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '');
}

String? _messageTextFromPayload(Object? value) {
  final payload = _mapOrNull(value);
  final message = _mapOrNull(payload?['message']);
  final text = message?['text']?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

String? _textFromPayload(Object? value, String key) {
  final payload = _mapOrNull(value);
  final text = payload?[key]?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
