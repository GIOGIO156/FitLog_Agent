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
    } catch (error) {
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
    } catch (error) {
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
  if (data is Map) {
    return AiGatewayResponse.fromJson(Map<String, dynamic>.from(data));
  }
  return const AiGatewayResponse(
    error: AiGatewayError(code: AiGatewayErrorCode.unknown, rawCode: 'unknown'),
  );
}
