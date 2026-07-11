import 'dart:io';

import 'package:fitlog_local/data/remote/ai_gateway_client.dart';
import 'package:fitlog_local/domain/models/ai_gateway_error.dart';
import 'package:fitlog_local/domain/models/ai_gateway_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TestAiGatewayClient parses success response data', () async {
    final client = TestAiGatewayClient((payload) async {
      expect(payload['model_choice'], 'chatgpt');
      return <String, dynamic>{
        'session_id': '00000000-0000-4000-8000-000000000001',
        'assistant_message_id': '00000000-0000-4000-8000-000000000002',
        'model_choice': 'chatgpt',
        'model_provider': 'openai',
        'message': <String, dynamic>{
          'text': 'A concise answer.',
          'language': 'en',
        },
        'workflow': 'auto',
        'needs_clarification': false,
        'clarification_questions': <String>[],
        'draft': null,
        'error': null,
      };
    });

    final response = await client.send(_request());

    expect(response.isSuccess, isTrue);
    expect(response.modelProvider, 'openai');
    expect(response.messageText, 'A concise answer.');
  });

  test('TestAiGatewayClient maps server error envelope', () async {
    final client = TestAiGatewayClient((_) async {
      return <String, dynamic>{
        'error': <String, dynamic>{'code': 'device_replaced'},
      };
    });

    final response = await client.send(_request());

    expect(response.isSuccess, isFalse);
    expect(response.error?.code, AiGatewayErrorCode.deviceReplaced);
  });

  test(
    'TestAiGatewayClient preserves an error envelope thrown by SDK',
    () async {
      final client = TestAiGatewayClient((_) async {
        throw _FunctionFailure(<String, dynamic>{
          'error': <String, dynamic>{'code': 'provider_output_invalid'},
        });
      });

      final response = await client.send(_request());

      expect(response.isSuccess, isFalse);
      expect(response.error?.code, AiGatewayErrorCode.providerOutputInvalid);
    },
  );

  test('TestAiGatewayClient maps a socket error to network failure', () async {
    final client = TestAiGatewayClient((_) async {
      throw const SocketException('offline');
    });

    final response = await client.send(_request());

    expect(response.isSuccess, isFalse);
    expect(response.error?.code, AiGatewayErrorCode.networkFailure);
  });

  test(
    'TestAiGatewayClient does not mislabel an unknown SDK failure as network',
    () async {
      final client = TestAiGatewayClient((_) async {
        throw StateError('SDK decode failed');
      });

      final response = await client.send(_request());

      expect(response.error?.code, AiGatewayErrorCode.providerFailure);
    },
  );

  test('TestAiGatewayClient rejects malformed successful payloads', () async {
    final client = TestAiGatewayClient((_) async {
      return <String, dynamic>{
        'message': <String, dynamic>{'text': 'Claims success'},
        'output_type': 'workout_draft',
        'draft': null,
        'error': null,
      };
    });

    final response = await client.send(_request());

    expect(response.error?.code, AiGatewayErrorCode.providerOutputInvalid);
  });
}

class _FunctionFailure implements Exception {
  const _FunctionFailure(this.details);

  final Object? details;
}

AiGatewayRequest _request() {
  return const AiGatewayRequest(
    messageText: 'hello',
    language: 'en',
    modelChoice: AiGatewayModelChoice.chatgpt,
    deviceId: 'device-a',
  );
}
