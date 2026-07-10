import 'dart:convert';

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
    try {
      final response = await client.functions.invoke(
        'ai-chat-route',
        body: request.toJson(),
      );
      return _responseFromData(response.data);
    } on FormatException catch (error) {
      return AiGatewayResponse(
        error: AiGatewayError(
          code: AiGatewayErrorCode.providerOutputInvalid,
          rawCode: AiGatewayErrorCode.providerOutputInvalid.value,
          message: error.message,
        ),
      );
    } catch (error) {
      final parsedError = _responseFromError(error);
      if (parsedError != null) {
        return parsedError;
      }
      return AiGatewayResponse(
        error: AiGatewayError(
          code: AiGatewayErrorCode.networkFailure,
          rawCode: AiGatewayErrorCode.networkFailure.value,
          message: error.toString(),
        ),
      );
    }
  }
}

class TestAiGatewayClient implements AiGatewayClient {
  const TestAiGatewayClient(this.invoke);

  final AiGatewayInvoke invoke;

  @override
  Future<AiGatewayResponse> send(AiGatewayRequest request) async {
    try {
      return _responseFromData(await invoke(request.toJson()));
    } on FormatException catch (error) {
      return AiGatewayResponse(
        error: AiGatewayError(
          code: AiGatewayErrorCode.providerOutputInvalid,
          rawCode: AiGatewayErrorCode.providerOutputInvalid.value,
          message: error.message,
        ),
      );
    } catch (error) {
      final parsedError = _responseFromError(error);
      if (parsedError != null) {
        return parsedError;
      }
      return AiGatewayResponse(
        error: AiGatewayError(
          code: AiGatewayErrorCode.networkFailure,
          rawCode: AiGatewayErrorCode.networkFailure.value,
          message: error.toString(),
        ),
      );
    }
  }
}

AiGatewayResponse _responseFromData(Object? data) {
  final parsed = _responseFromDataOrNull(data);
  if (parsed != null) {
    return parsed;
  }
  return const AiGatewayResponse(
    error: AiGatewayError(code: AiGatewayErrorCode.unknown, rawCode: 'unknown'),
  );
}

AiGatewayResponse? _responseFromDataOrNull(Object? data) {
  if (data is Map) {
    return AiGatewayResponse.fromJson(Map<String, dynamic>.from(data));
  }
  if (data is String) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        return AiGatewayResponse.fromJson(Map<String, dynamic>.from(decoded));
      }
    } on FormatException {
      return null;
    }
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
