import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase/supabase.dart' as supabase;

import '../../domain/models/ai_food_photo_analysis.dart';
import '../../domain/models/ai_gateway_error.dart';

abstract class AiFoodPhotoAnalysisClient {
  const AiFoodPhotoAnalysisClient();

  Future<AiFoodPhotoAnalysisResponse> analyze(
    AiFoodPhotoAnalysisRequest request,
  );
}

class NoopAiFoodPhotoAnalysisClient extends AiFoodPhotoAnalysisClient {
  const NoopAiFoodPhotoAnalysisClient();

  @override
  Future<AiFoodPhotoAnalysisResponse> analyze(
    AiFoodPhotoAnalysisRequest request,
  ) async {
    return const AiFoodPhotoAnalysisResponse(
      error: AiGatewayError(
        code: AiGatewayErrorCode.providerFailure,
        rawCode: 'backend_not_configured',
      ),
    );
  }
}

class SupabaseAiFoodPhotoAnalysisClient extends AiFoodPhotoAnalysisClient {
  const SupabaseAiFoodPhotoAnalysisClient(this.client);

  final supabase.SupabaseClient client;

  @override
  Future<AiFoodPhotoAnalysisResponse> analyze(
    AiFoodPhotoAnalysisRequest request,
  ) async {
    Object? data;
    try {
      final response = await client.functions.invoke(
        'ai-food-photo-analyze',
        body: request.toJson(),
      );
      data = response.data;
    } catch (error) {
      final parsedError = _responseFromError(error);
      if (parsedError != null) {
        return parsedError;
      }
      return AiFoodPhotoAnalysisResponse(
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
    return _decodeFoodAnalysisResponse(data);
  }
}

AiFoodPhotoAnalysisResponse _decodeFoodAnalysisResponse(Object? data) {
  try {
    return _responseFromData(data);
  } catch (error) {
    return AiFoodPhotoAnalysisResponse(
      error: AiGatewayError(
        code: AiGatewayErrorCode.providerOutputInvalid,
        rawCode: AiGatewayErrorCode.providerOutputInvalid.value,
        message: error.toString(),
      ),
    );
  }
}

AiFoodPhotoAnalysisResponse _responseFromData(Object? data) {
  final parsed = _responseFromDataOrNull(data);
  if (parsed != null) {
    return parsed;
  }
  throw const FormatException(
    'Food photo analysis returned an invalid response body.',
  );
}

bool _isTransportError(Object error) {
  return error is SocketException || error is TimeoutException;
}

AiFoodPhotoAnalysisResponse? _responseFromDataOrNull(Object? data) {
  try {
    if (data is Map) {
      return AiFoodPhotoAnalysisResponse.fromJson(
        Map<String, dynamic>.from(data),
      );
    }
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        return AiFoodPhotoAnalysisResponse.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

AiFoodPhotoAnalysisResponse? _responseFromError(Object error) {
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
