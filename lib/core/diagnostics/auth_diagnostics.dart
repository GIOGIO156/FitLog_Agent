import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:supabase/supabase.dart' as supabase;

/// Deliberately excludes exception messages, request bodies and credentials.
String authFailureCode(Object error) {
  if (error is supabase.AuthException) {
    final status = int.tryParse(error.statusCode ?? '');
    if (status == 429) return 'auth_rate_limited';
    if (status != null && status >= 500) return 'auth_server_error';
  }
  if (error is TimeoutException) return 'auth_timeout';
  if (error is HandshakeException || error is TlsException) {
    return 'auth_tls_error';
  }
  final text = error.toString().toLowerCase();
  if (text.contains('failed host lookup') ||
      text.contains('name resolution') ||
      text.contains('getaddrinfo')) {
    return 'auth_dns_error';
  }
  if (text.contains('handshake') || text.contains('certificate_verify')) {
    return 'auth_tls_error';
  }
  if (text.contains('timed out') || text.contains('timeout')) {
    return 'auth_timeout';
  }
  if (error is supabase.AuthRetryableFetchException ||
      error is SocketException ||
      text.contains('socket') ||
      text.contains('connection') ||
      text.contains('network')) {
    return 'auth_network_error';
  }
  if (error is supabase.AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'invalid_credentials';
      case 'email_not_confirmed':
      case 'email_not_verified':
        return 'email_not_confirmed';
      case 'user_already_exists':
      case 'email_exists':
        return 'email_already_registered';
      case 'otp_expired':
      case 'otp_disabled':
        return 'otp_invalid_or_expired';
      case 'refresh_token_not_found':
      case 'refresh_token_already_used':
      case 'session_not_found':
      case 'session_expired':
      case 'bad_jwt':
        return 'auth_session_invalid';
      case 'user_banned':
        return 'auth_user_banned';
      case 'captcha_failed':
        return 'auth_captcha_failed';
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
      case 'over_sms_send_rate_limit':
        return 'auth_rate_limited';
    }
  }
  if (text.contains('invalid login credentials')) return 'invalid_credentials';
  if (text.contains('email not confirmed')) return 'email_not_confirmed';
  if (text.contains('already registered')) return 'email_already_registered';
  if (text.contains('rate limit') || text.contains('too many requests')) {
    return 'auth_rate_limited';
  }
  if (error is FormatException) return 'auth_storage_invalid';
  return 'auth_failed';
}

class AuthDiagnostics {
  AuthDiagnostics({
    Future<Map<String, Object?>> Function()? snapshot,
    this.maxRecent = 200,
    this.maxIncidents = 20,
  }) : _snapshot = snapshot ?? _phoneSnapshot;

  static final instance = AuthDiagnostics();
  static const channel = MethodChannel('fitlog/auth_diagnostics');
  static const storageKey = 'fitlog.auth.diagnostics.v1';
  static final _processStartedAt = DateTime.now().toUtc();
  static final _processClock = Stopwatch()..start();
  static final _runId = _processStartedAt.microsecondsSinceEpoch.toString();
  final Future<Map<String, Object?>> Function() _snapshot;
  final int maxRecent;
  final int maxIncidents;
  Future<void> _pending = Future.value();
  List<Map<String, dynamic>> _recent = [];
  List<Map<String, dynamic>> _incidents = [];
  bool _loaded = false;
  int _sequence = 0;
  int _writeFailures = 0;
  String lifecycle = 'cold_start';

  // A separate incident ring protects failures and their surrounding events
  // from eviction by later successful requests. Only new incidents evict it.
  Future<void> record(
    String event, {
    bool failure = false,
    Map<String, Object?> data = const {},
    Object? error,
  }) {
    final time = DateTime.now().toUtc();
    final elapsed = _processClock.elapsedMilliseconds;
    final snapshot = Future<Map<String, Object?>>.sync(_snapshot).catchError(
      (Object _) => <String, Object?>{'snapshot_status': 'unavailable'},
    );
    final state = Platform.isAndroid
        ? snapshot.timeout(
            const Duration(seconds: 1),
            onTimeout: () => {'snapshot_status': 'timeout'},
          )
        : snapshot;
    final stateAtEvent = lifecycle;
    final fields = _safeFields(data);
    final sequence = ++_sequence;
    _pending = _pending.then((_) async {
      try {
        await _load();
        final entry = <String, dynamic>{
          'time_utc': time.toIso8601String(),
          'run_id': _runId,
          'sequence': sequence,
          'process_age_ms': elapsed,
          'lifecycle': stateAtEvent,
          'event': event,
          'failure': failure,
          ...fields,
          if (error != null) ...{
            'failure_category': authFailureCode(error),
            'exception_type': error.runtimeType.toString(),
            if (error is supabase.AuthException) ...{
              'http_status': int.tryParse(error.statusCode ?? ''),
              'auth_error_code': safeServerCode(error.code),
            },
          },
          'phone': _safeFields(await state),
        };
        for (final incident in _incidents) {
          final after = incident['after'] as List;
          if (after.length < 5) after.add(entry);
        }
        if (failure) {
          _incidents.add({
            'before': _recent
                .skip((_recent.length - 5).clamp(0, _recent.length))
                .toList(),
            'failure': entry,
            'after': <Map<String, dynamic>>[],
          });
          if (_incidents.length > maxIncidents) _incidents.removeAt(0);
        }
        _recent.add(entry);
        if (_recent.length > maxRecent) _recent.removeAt(0);
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString(storageKey, jsonEncode(_journal()))) {
          _writeFailures++;
        }
      } catch (_) {
        _writeFailures++;
      }
    });
    return _pending;
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(storageKey);
    if (saved == null) return;
    try {
      final json = jsonDecode(saved) as Map;
      _recent = (json['recent'] as List)
          .cast<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _incidents = (json['incidents'] as List)
          .cast<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      _writeFailures++;
    }
  }

  Map<String, Object?> _journal() => {
    'schema': 'fitlog.auth.diagnostics.v1',
    'recent': _recent,
    'incidents': _incidents,
  };

  Future<String> exportJson() async {
    await record('export_requested');
    return const JsonEncoder.withIndent('  ').convert({
      ..._journal(),
      'exported_at_utc': DateTime.now().toUtc().toIso8601String(),
      'process_started_at_utc': _processStartedAt.toIso8601String(),
      'journal_write_failures_this_run': _writeFailures,
      'limits': {
        'recent_events': maxRecent,
        'incidents': maxIncidents,
        'context_each_side': 5,
      },
    });
  }

  Future<String> exportFile() async {
    final json = await exportJson();
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      path.join(
        directory.path,
        'fitlog-auth-diagnostics-${DateTime.now().toUtc().microsecondsSinceEpoch}.json',
      ),
    );
    await file.writeAsString(json, flush: true);
    return file.path;
  }

  static Future<Map<String, Object?>> _phoneSnapshot() async =>
      Map<String, Object?>.from(
        await channel.invokeMapMethod<String, Object?>('snapshot') ?? {},
      );

  static String? safeServerCode(String? code) {
    const codes = {
      'invalid_credentials',
      'email_not_confirmed',
      'email_not_verified',
      'user_already_exists',
      'email_exists',
      'otp_expired',
      'otp_disabled',
      'refresh_token_not_found',
      'refresh_token_already_used',
      'session_not_found',
      'session_expired',
      'bad_jwt',
      'user_banned',
      'over_request_rate_limit',
      'over_email_send_rate_limit',
      'over_sms_send_rate_limit',
      'unexpected_failure',
      'validation_failed',
      'captcha_failed',
      'weak_password',
      'same_password',
    };
    return code == null ? null : (codes.contains(code) ? code : 'unrecognized');
  }

  static Map<String, Object?> _safeFields(Map<String, Object?> fields) {
    const allowed = {
      'operation',
      'outcome',
      'reason',
      'session_present',
      'stored_session_present',
      'access_expired',
      'access_expires_at',
      'duration_ms',
      'http_status',
      'server_clock_offset_ms',
      'auth_host',
      'auth_error_code',
      'snapshot_status',
      'app_version',
      'build_number',
      'android_sdk',
      'android_release',
      'model',
      'manufacturer',
      'network',
      'network_validated',
      'network_internet',
      'vpn_active',
      'proxy_configured',
      'auto_time',
      'power_save',
      'battery_optimization_exempt',
      'background_restricted',
      'first_install_ms',
      'last_update_ms',
      'storage_operation',
      'device_check',
    };
    return {
      for (final e in fields.entries)
        if (allowed.contains(e.key) &&
            (e.value is bool ||
                e.value is num ||
                e.value == null ||
                e.value is String))
          e.key: e.value is String
              ? (e.value as String).substring(
                  0,
                  (e.value as String).length.clamp(0, 100),
                )
              : e.value,
    };
  }
}
