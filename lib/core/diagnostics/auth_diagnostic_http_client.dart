import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_diagnostics.dart';

class AuthDiagnosticHttpClient extends http.BaseClient {
  AuthDiagnosticHttpClient(this.inner, {AuthDiagnostics? diagnostics})
    : diagnostics = diagnostics ?? AuthDiagnostics.instance;

  final http.Client inner;
  final AuthDiagnostics diagnostics;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!request.url.path.startsWith('/auth/v1/')) return inner.send(request);
    final clock = Stopwatch()..start();
    final grant = request.url.queryParameters['grant_type'];
    final operation = switch (request.url.path.split('/').last) {
      'token' => grant == 'refresh_token' ? 'refresh' : 'password_login',
      'otp' => 'send_otp',
      'verify' => 'verify_otp',
      'logout' => 'logout',
      'user' => 'user_update',
      _ => 'other_auth',
    };
    // No headers, URL query values or body contents enter the journal.
    diagnostics.record(
      'auth_http_start',
      data: {'operation': operation, 'auth_host': request.url.host},
    );
    try {
      final response = await inner.send(request);
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
          'duration_ms': clock.elapsedMilliseconds,
          'http_status': response.statusCode,
          'auth_error_code': code,
          'server_clock_offset_ms': offset,
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
          'duration_ms': clock.elapsedMilliseconds,
        },
      );
      rethrow;
    }
  }

  @override
  void close() => inner.close();
}
