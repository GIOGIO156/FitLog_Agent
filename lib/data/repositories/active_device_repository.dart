import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart' as supabase;

import '../../domain/models/auth_session.dart';
import '../../domain/models/cloud_runtime_context.dart';
import 'phase2_repository_exception.dart';

abstract class ActiveDeviceRepository {
  Future<void> claim(AuthSession session);

  Future<void> assertActive();

  Future<void> release();
}

class NoopActiveDeviceRepository implements ActiveDeviceRepository {
  const NoopActiveDeviceRepository();

  @override
  Future<void> claim(AuthSession session) async {}

  @override
  Future<void> assertActive() async {}

  @override
  Future<void> release() async {}
}

class SupabaseActiveDeviceRepository implements ActiveDeviceRepository {
  SupabaseActiveDeviceRepository({
    required this.client,
    required this.runtimeContext,
    this.platform = 'android',
    this.appVersion = 'phase3',
  });

  static const String _deviceIdKey = 'fitlog_active_device_id';

  final supabase.SupabaseClient client;
  final CloudRuntimeContext runtimeContext;
  final String platform;
  final String appVersion;

  @override
  Future<void> claim(AuthSession session) async {
    final accountId = session.accountId;
    final sessionId = session.sessionId;
    if ((accountId ?? '').isEmpty || (sessionId ?? '').isEmpty) {
      throw const Phase2RepositoryException('auth_required');
    }
    final deviceId = await _loadOrCreateDeviceId();
    try {
      await client.rpc(
        'claim_active_device',
        params: <String, dynamic>{
          'input_device_id': deviceId,
          'input_session_id': sessionId,
          'input_platform': platform,
          'input_app_version': appVersion,
        },
      );
      runtimeContext.bind(
        accountId: accountId!,
        deviceId: deviceId,
        sessionId: sessionId!,
      );
    } catch (error) {
      throw _activeDeviceExceptionFor('active_device_claim_failed', error);
    }
  }

  @override
  Future<void> assertActive() async {
    if (!runtimeContext.canUseOfficialCloud) {
      throw const Phase2RepositoryException('auth_required');
    }
    try {
      final result = await client.rpc(
        'assert_active_device',
        params: <String, dynamic>{
          'input_device_id': runtimeContext.deviceId,
          'input_session_id': runtimeContext.sessionId,
        },
      );
      if (!_resultAllowsActiveDevice(result)) {
        runtimeContext.markDeviceReplaced();
        throw const Phase2RepositoryException('device_replaced');
      }
    } on Phase2RepositoryException {
      rethrow;
    } catch (error) {
      final exception = _activeDeviceExceptionFor(
        'active_device_assert_failed',
        error,
      );
      if (exception.code == 'device_replaced') {
        runtimeContext.markDeviceReplaced();
      }
      throw exception;
    }
  }

  @override
  Future<void> release() async {
    if (!runtimeContext.canUseOfficialCloud) {
      runtimeContext.clear();
      return;
    }
    try {
      await client.rpc(
        'release_active_device',
        params: <String, dynamic>{
          'input_device_id': runtimeContext.deviceId,
          'input_session_id': runtimeContext.sessionId,
        },
      );
    } catch (_) {
      // Release is best-effort; server write guards remain authoritative.
    } finally {
      runtimeContext.clear();
    }
  }

  bool _resultAllowsActiveDevice(Object? result) {
    if (result == null) {
      return true;
    }
    if (result is bool) {
      return result;
    }
    if (result is Map) {
      final ok = result['ok'];
      if (ok is bool) {
        return ok;
      }
      final active = result['active'];
      if (active is bool) {
        return active;
      }
      final code = result['code']?.toString();
      return code == null || code == 'ok';
    }
    return result.toString().toLowerCase() != 'false';
  }

  Future<String> _loadOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if ((existing ?? '').isNotEmpty) {
      return existing!;
    }
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final deviceId = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    await prefs.setString(_deviceIdKey, deviceId);
    return deviceId;
  }

  Phase2RepositoryException _activeDeviceExceptionFor(
    String fallbackCode,
    Object error,
  ) {
    final raw = error.toString();
    final normalized = raw.toLowerCase();
    if (normalized.contains('device_replaced') ||
        normalized.contains('not_active_device') ||
        normalized.contains('active device')) {
      return Phase2RepositoryException('device_replaced', raw);
    }
    if (normalized.contains('socket') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('connection') ||
        normalized.contains('timeout') ||
        normalized.contains('network')) {
      return Phase2RepositoryException('active_device_network_error', raw);
    }
    if (normalized.contains('function') && normalized.contains('not found')) {
      return Phase2RepositoryException('active_device_rpc_missing', raw);
    }
    return Phase2RepositoryException(fallbackCode, raw);
  }
}
