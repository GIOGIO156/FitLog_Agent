import 'package:supabase/supabase.dart' as supabase;

import '../../domain/models/ai_chat_message.dart';
import '../../domain/models/ai_chat_clarification.dart';
import '../../domain/models/ai_chat_session.dart';
import '../../domain/models/ai_delivery_request.dart';
import '../../domain/models/ai_gateway_request.dart';
import '../../domain/models/ai_gateway_response.dart';
import '../remote/ai_gateway_client.dart';
import 'phase2_repository_exception.dart';

abstract class AiChatRepository {
  const AiChatRepository();

  Future<List<AiChatSession>> listSessions({required String accountId});

  Future<List<AiChatMessage>> listMessages({
    required String accountId,
    required String sessionId,
  });

  Future<AiGatewayResponse> sendMessage(AiGatewayRequest request);

  Future<List<AiDeliveryRequest>> listRecentDeliveryRequests({
    required String accountId,
  }) async => const <AiDeliveryRequest>[];

  Future<AiDeliveryRequest?> getDeliveryRequest({
    required String accountId,
    required String requestId,
  }) async => null;

  Future<void> retryDeliveryRequest({
    required String accountId,
    required String requestId,
  }) async {}

  Future<AiChatClarification?> loadActiveClarification({
    required String accountId,
    required String sessionId,
  }) async => null;

  Future<void> archiveSession(String sessionId, {required bool archived});

  Future<void> renameSession(String sessionId, String title);

  Future<void> deleteSession(String sessionId);
}

class NoopAiChatRepository extends AiChatRepository {
  const NoopAiChatRepository();

  @override
  Future<List<AiChatSession>> listSessions({required String accountId}) async {
    return const <AiChatSession>[];
  }

  @override
  Future<List<AiChatMessage>> listMessages({
    required String accountId,
    required String sessionId,
  }) async {
    return const <AiChatMessage>[];
  }

  @override
  Future<AiGatewayResponse> sendMessage(AiGatewayRequest request) async {
    throw const Phase2RepositoryException('backend_not_configured');
  }

  @override
  Future<void> archiveSession(
    String sessionId, {
    required bool archived,
  }) async {
    throw const Phase2RepositoryException('backend_not_configured');
  }

  @override
  Future<void> renameSession(String sessionId, String title) async {
    throw const Phase2RepositoryException('backend_not_configured');
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    throw const Phase2RepositoryException('backend_not_configured');
  }
}

class SupabaseAiChatRepository extends AiChatRepository {
  const SupabaseAiChatRepository({
    required this.client,
    required this.gatewayClient,
  });

  final supabase.SupabaseClient client;
  final AiGatewayClient gatewayClient;

  @override
  Future<List<AiChatSession>> listSessions({required String accountId}) async {
    if (accountId.isEmpty) {
      return const <AiChatSession>[];
    }
    try {
      final rows = await client
          .from('ai_chat_sessions')
          .select()
          .eq('account_id', accountId)
          .filter('archived_at', 'is', null)
          .filter('deleted_at', 'is', null)
          .order('updated_at', ascending: false);
      return rows
          .map((row) => AiChatSession.fromMap(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (error) {
      throw _aiChatExceptionFor('ai_chat_sessions_load_failed', error);
    }
  }

  @override
  Future<List<AiChatMessage>> listMessages({
    required String accountId,
    required String sessionId,
  }) async {
    if (accountId.isEmpty || sessionId.isEmpty) {
      return const <AiChatMessage>[];
    }
    try {
      final rows = await client
          .from('ai_chat_messages')
          .select()
          .eq('account_id', accountId)
          .eq('session_id', sessionId)
          .filter('deleted_at', 'is', null)
          .order('message_sequence')
          .order('created_at')
          .order('id');
      final messages = rows
          .map((row) => AiChatMessage.fromMap(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      messages.sort(AiChatMessage.compareByStableOrder);
      return messages;
    } catch (error) {
      throw _aiChatExceptionFor('ai_chat_messages_load_failed', error);
    }
  }

  @override
  Future<AiGatewayResponse> sendMessage(AiGatewayRequest request) {
    return gatewayClient.send(request);
  }

  @override
  Future<List<AiDeliveryRequest>> listRecentDeliveryRequests({
    required String accountId,
  }) async {
    if (accountId.isEmpty) {
      return const <AiDeliveryRequest>[];
    }
    try {
      final rows = await client
          .from('ai_delivery_requests')
          .select()
          .eq('account_id', accountId)
          .eq('kind', 'ai_chat')
          .neq('status', 'cancelled')
          .order('updated_at', ascending: false)
          .limit(20);
      return rows
          .map(
            (row) => AiDeliveryRequest.fromMap(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    } catch (error) {
      throw _aiChatExceptionFor('ai_delivery_requests_load_failed', error);
    }
  }

  @override
  Future<AiDeliveryRequest?> getDeliveryRequest({
    required String accountId,
    required String requestId,
  }) async {
    if (accountId.isEmpty || requestId.isEmpty) {
      return null;
    }
    try {
      final rows = await client
          .from('ai_delivery_requests')
          .select()
          .eq('account_id', accountId)
          .eq('request_id', requestId)
          .eq('kind', 'ai_chat')
          .neq('status', 'cancelled')
          .limit(1);
      if (rows.isEmpty) {
        return null;
      }
      return AiDeliveryRequest.fromMap(Map<String, dynamic>.from(rows.first));
    } catch (error) {
      throw _aiChatExceptionFor('ai_delivery_requests_load_failed', error);
    }
  }

  @override
  Future<void> retryDeliveryRequest({
    required String accountId,
    required String requestId,
  }) async {
    if (accountId.isEmpty || requestId.isEmpty) {
      return;
    }
    try {
      await client.functions.invoke(
        'ai-chat-route',
        body: <String, dynamic>{'action': 'retry_one', 'request_id': requestId},
      );
    } catch (error) {
      throw _aiChatExceptionFor('ai_delivery_retry_failed', error);
    }
  }

  @override
  Future<AiChatClarification?> loadActiveClarification({
    required String accountId,
    required String sessionId,
  }) async {
    if (accountId.isEmpty || sessionId.isEmpty) return null;
    try {
      final rows = await client
          .from('ai_chat_clarifications')
          .select()
          .eq('account_id', accountId)
          .eq('session_id', sessionId)
          .inFilter('state', const <String>['pending', 'resolving'])
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      final clarification = AiChatClarification.fromJson(
        Map<String, dynamic>.from(rows.first),
      );
      return clarification.isActive ? clarification : null;
    } catch (error) {
      throw _aiChatExceptionFor('ai_chat_clarification_load_failed', error);
    }
  }

  @override
  Future<void> archiveSession(
    String sessionId, {
    required bool archived,
  }) async {
    try {
      await client.rpc(
        'archive_ai_chat_session',
        params: <String, dynamic>{
          'input_session_id': sessionId,
          'input_archived': archived,
        },
      );
    } catch (error) {
      throw _aiChatExceptionFor('ai_chat_archive_failed', error);
    }
  }

  @override
  Future<void> renameSession(String sessionId, String title) async {
    try {
      await client.rpc(
        'rename_ai_chat_session',
        params: <String, dynamic>{
          'input_session_id': sessionId,
          'input_title': title,
        },
      );
    } catch (error) {
      throw _aiChatExceptionFor('ai_chat_rename_failed', error);
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    try {
      await client.rpc(
        'soft_delete_ai_chat_session',
        params: <String, dynamic>{'input_session_id': sessionId},
      );
    } catch (error) {
      throw _aiChatExceptionFor('ai_chat_delete_failed', error);
    }
  }

  Phase2RepositoryException _aiChatExceptionFor(
    String fallbackCode,
    Object error,
  ) {
    if (error is Phase2RepositoryException) {
      return error;
    }
    final raw = error.toString();
    final normalized = raw.toLowerCase();
    if (normalized.contains('device_replaced') ||
        normalized.contains('not_active_device')) {
      return Phase2RepositoryException('device_replaced', raw);
    }
    if (normalized.contains('row-level security') ||
        normalized.contains('permission denied') ||
        normalized.contains('401') ||
        normalized.contains('403')) {
      return Phase2RepositoryException('record_rls_denied', raw);
    }
    if (normalized.contains('socket') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('connection') ||
        normalized.contains('timeout') ||
        normalized.contains('network')) {
      return Phase2RepositoryException('record_network_error', raw);
    }
    if (normalized.contains('schema cache') ||
        normalized.contains('column') ||
        normalized.contains('does not exist') ||
        normalized.contains('record_schema_mismatch')) {
      return Phase2RepositoryException('record_schema_mismatch', raw);
    }
    return Phase2RepositoryException(fallbackCode, raw);
  }
}
