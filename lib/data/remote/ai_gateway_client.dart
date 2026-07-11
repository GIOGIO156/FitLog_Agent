import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase/supabase.dart' as supabase;

import '../../domain/models/ai_gateway_error.dart';
import '../../domain/models/ai_gateway_request.dart';
import '../../domain/models/ai_gateway_response.dart';

abstract class AiGatewayClient {
  Future<AiGatewayResponse> send(AiGatewayRequest request);
}

typedef AiGatewayInvoke =
    Future<Object?> Function(Map<String, dynamic> payload);

class SupabaseAiGatewayClient implements AiGatewayClient {
  const SupabaseAiGatewayClient(this.client);

  final supabase.SupabaseClient client;

  @override
  Future<AiGatewayResponse> send(AiGatewayRequest request) async {
    Object? data;
    try {
      final response = await client.functions.invoke(
        'ai-chat-route',
        body: request.toJson(),
      );
      data = response.data;
    } catch (error) {
      final parsedError = _responseFromError(error);
      if (parsedError != null) {
        return parsedError;
      }
      return AiGatewayResponse(
        error: AiGatewayError(
          code: _isTransportError(error)
              ? AiGatewayErrorCode.networkFailure
              : AiGatewayErrorCode.providerFailure,
          rawCode: _isTransportError(error)
              ? AiGatewayErrorCode.networkFailure.value
              : AiGatewayErrorCode.providerFailure.value,
          message: error.toString(),
        ),
      );
    }
    return _decodeGatewayResponse(data, legacyDate: request.selectedDate);
  }
}

class TestAiGatewayClient implements AiGatewayClient {
  const TestAiGatewayClient(this.invoke);

  final AiGatewayInvoke invoke;

  @override
  Future<AiGatewayResponse> send(AiGatewayRequest request) async {
    Object? data;
    try {
      data = await invoke(request.toJson());
    } catch (error) {
      final parsedError = _responseFromError(error);
      if (parsedError != null) {
        return parsedError;
      }
      return AiGatewayResponse(
        error: AiGatewayError(
          code: _isTransportError(error)
              ? AiGatewayErrorCode.networkFailure
              : AiGatewayErrorCode.providerFailure,
          rawCode: _isTransportError(error)
              ? AiGatewayErrorCode.networkFailure.value
              : AiGatewayErrorCode.providerFailure.value,
          message: error.toString(),
        ),
      );
    }
    return _decodeGatewayResponse(data, legacyDate: request.selectedDate);
  }
}

AiGatewayResponse _decodeGatewayResponse(Object? data, {String? legacyDate}) {
  try {
    return _responseFromData(data, legacyDate: legacyDate);
  } catch (error) {
    return AiGatewayResponse(
      error: AiGatewayError(
        code: AiGatewayErrorCode.providerOutputInvalid,
        rawCode: AiGatewayErrorCode.providerOutputInvalid.value,
        message: error.toString(),
      ),
    );
  }
}

AiGatewayResponse _responseFromData(Object? data, {String? legacyDate}) {
  final parsed = _responseFromDataOrNull(data, legacyDate: legacyDate);
  if (parsed != null) {
    return parsed;
  }
  throw const FormatException('AI Gateway returned an invalid response body.');
}

bool _isTransportError(Object error) {
  return error is SocketException || error is TimeoutException;
}

AiGatewayResponse? _responseFromDataOrNull(Object? data, {String? legacyDate}) {
  try {
    if (data is Map) {
      return AiGatewayResponse.fromJson(
        Map<String, dynamic>.from(data),
        legacyDate: legacyDate,
      );
    }
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        return AiGatewayResponse.fromJson(
          Map<String, dynamic>.from(decoded),
          legacyDate: legacyDate,
        );
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

AiGatewayResponse? _responseFromError(Object error) {
  for (final candidate in _errorPayloadCandidates(error)) {
    final parsed = _responseFromDataOrNull(candidate);
    if (parsed != null) {
      return parsed;
    }
  }
  return null;
}

List<Object?> _errorPayloadCandidates(Object error) {
  final candidates = <Object?>[];
  final dynamic dynamicError = error;
  for (final read in <Object? Function()>[
    () => dynamicError.details,
    () => dynamicError.data,
    () => dynamicError.response,
  ]) {
    try {
      candidates.add(read());
    } catch (_) {
      // The concrete Supabase exception type varies by package version.
    }
  }
  candidates.add(error.toString());
  final embeddedJson = _firstJsonObject(error.toString());
  if (embeddedJson != null) {
    candidates.add(embeddedJson);
  }
  return candidates;
}

String? _firstJsonObject(String value) {
  final start = value.indexOf('{');
  if (start < 0) {
    return null;
  }
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var index = start; index < value.length; index += 1) {
    final char = value[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    if (char == '"') {
      inString = true;
    } else if (char == '{') {
      depth += 1;
    } else if (char == '}') {
      depth -= 1;
      if (depth == 0) {
        return value.substring(start, index + 1);
      }
    }
  }
  return null;
}
