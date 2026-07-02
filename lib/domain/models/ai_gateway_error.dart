enum AiGatewayErrorCode {
  authRequired,
  subscriptionRequired,
  deviceReplaced,
  gatewayTimeout,
  providerFailure,
  recordSchemaMismatch,
  networkFailure,
  unknown,
}

extension AiGatewayErrorCodeValue on AiGatewayErrorCode {
  String get value {
    switch (this) {
      case AiGatewayErrorCode.authRequired:
        return 'auth_required';
      case AiGatewayErrorCode.subscriptionRequired:
        return 'subscription_required';
      case AiGatewayErrorCode.deviceReplaced:
        return 'device_replaced';
      case AiGatewayErrorCode.gatewayTimeout:
        return 'gateway_timeout';
      case AiGatewayErrorCode.providerFailure:
        return 'provider_failure';
      case AiGatewayErrorCode.recordSchemaMismatch:
        return 'record_schema_mismatch';
      case AiGatewayErrorCode.networkFailure:
        return 'network_failure';
      case AiGatewayErrorCode.unknown:
        return 'unknown';
    }
  }
}

class AiGatewayError {
  const AiGatewayError({
    required this.code,
    required this.rawCode,
    this.message,
  });

  final AiGatewayErrorCode code;
  final String rawCode;
  final String? message;

  bool get isDeviceReplaced => code == AiGatewayErrorCode.deviceReplaced;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'code': rawCode,
      if (message != null) 'message': message,
    };
  }

  static AiGatewayError? fromJsonOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    return AiGatewayError.fromJson(value);
  }

  factory AiGatewayError.fromJson(Object value) {
    if (value is String) {
      return AiGatewayError(
        code: aiGatewayErrorCodeFromValue(value),
        rawCode: value,
      );
    }

    if (value is Map) {
      final rawCode = (value['code'] ?? 'unknown').toString();
      return AiGatewayError(
        code: aiGatewayErrorCodeFromValue(rawCode),
        rawCode: rawCode,
        message: value['message']?.toString(),
      );
    }

    return const AiGatewayError(
      code: AiGatewayErrorCode.unknown,
      rawCode: 'unknown',
    );
  }
}

AiGatewayErrorCode aiGatewayErrorCodeFromValue(String? value) {
  switch (value) {
    case 'auth_required':
      return AiGatewayErrorCode.authRequired;
    case 'subscription_required':
      return AiGatewayErrorCode.subscriptionRequired;
    case 'device_replaced':
      return AiGatewayErrorCode.deviceReplaced;
    case 'gateway_timeout':
      return AiGatewayErrorCode.gatewayTimeout;
    case 'provider_failure':
      return AiGatewayErrorCode.providerFailure;
    case 'record_schema_mismatch':
      return AiGatewayErrorCode.recordSchemaMismatch;
    case 'network_failure':
      return AiGatewayErrorCode.networkFailure;
    default:
      return AiGatewayErrorCode.unknown;
  }
}
