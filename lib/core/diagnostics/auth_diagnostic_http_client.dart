import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_diagnostics.dart';

class AuthDiagnosticHttpClient extends http.BaseClient {
  AuthDiagnosticHttpClient(this.inner, {AuthDiagnostics? diagnostics})
    : diagnostics = diagnostics ?? AuthDiagnostics.instance;

  final http.Client inner;
  final AuthDiagnostics diagnostics;
  int _requestSequence = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!request.url.path.startsWith('/auth/v1/')) return inner.send(request);
    final clock = Stopwatch()..start();
    final sequence = ++_requestSequence;
    final grant = request.url.queryParameters['grant_type'];
    final operation = switch (request.url.path.split('/').last) {
      'token' => grant == 'refresh_token' ? 'refresh' : 'password_login',
      'otp' => 'send_otp',
      'verify' => 'verify_otp',
      'logout' => 'logout',
      'user' => 'user_update',
      _ => 'other_auth',
    };
    // No credentials, arbitrary headers, URL query values or body contents enter
    // the journal. Only validated response tracing IDs are retained below.
    diagnostics.record(
      'auth_http_start',
      data: {
        'operation': operation,
        'auth_host': request.url.host,
        'request_sequence': sequence,
      },
    );
    var responseReceived = false;
    int? responseStatus;
    String? serverRequestId;
    try {
      final response = await inner.send(request);
      responseReceived = true;
      responseStatus = response.statusCode;
      serverRequestId = _requestId(response.headers);
      final bytes = await response.stream.toBytes();
      String? code;
      if (response.statusCode >= 400) {
        try {
          final body = jsonDecode(utf8.decode(bytes)) as Map;
          code = AuthDiagnostics.safeServerCode(
            (body['code'] ?? body['error_code']) as String?,
          );
        } catch (_) {
          // HTML gateway errors and malformed bodies still retain HTTP status.
        }
      }
      int? offset;
      try {
        offset = HttpDate.parse(
          response.headers['date']!,
        ).difference(DateTime.now().toUtc()).inMilliseconds;
      } catch (_) {
        // Some transports do not expose the server Date header.
      }
      diagnostics.record(
        'auth_http_result',
        failure: response.statusCode >= 400,
        data: {
          'operation': operation,
          'request_sequence': sequence,
          'http_response_received': true,
          'duration_ms': clock.elapsedMilliseconds,
          'http_status': response.statusCode,
          'auth_error_code': code,
          'server_clock_offset_ms': offset,
          'server_request_id': serverRequestId,
        },
      );
      return http.StreamedResponse(
        Stream.value(bytes),
        response.statusCode,
        contentLength: bytes.length,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (error) {
      diagnostics.record(
        'auth_http_failure',
        failure: true,
        error: error,
        data: {
          'operation': operation,
          'request_sequence': sequence,
          'http_response_received': responseReceived,
          'http_status': responseStatus,
          'server_request_id': serverRequestId,
          'duration_ms': clock.elapsedMilliseconds,
        },
      );
      rethrow;
    }
  }

  String? _requestId(Map<String, String> headers) {
    // Accept only UUID-shaped tracing IDs, never arbitrary header contents.
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    for (final name in ['sb-request-id', 'x-request-id']) {
      final value = headers[name];
      if (value != null && uuid.hasMatch(value)) return value;
    }
    return null;
  }

  @override
  void close() => inner.close();
}
