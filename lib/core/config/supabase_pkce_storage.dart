import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart' as supabase;

import '../diagnostics/auth_diagnostics.dart';

class SharedPreferencesGotrueAsyncStorage extends supabase.GotrueAsyncStorage {
  const SharedPreferencesGotrueAsyncStorage({
    this.keyPrefix = 'fitlog.supabase.pkce.',
  });

  final String keyPrefix;

  @override
  Future<String?> getItem({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storageKey(key));
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey(key), value);
  }

  @override
  Future<void> removeItem({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey(key));
  }

  String _storageKey(String key) => '$keyPrefix$key';
}

class SharedPreferencesSupabaseAuthSessionStorage {
  const SharedPreferencesSupabaseAuthSessionStorage({
    this.storageKey = 'fitlog.supabase.auth.session',
  });

  final String storageKey;

  Future<String?> readSessionJson() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(storageKey);
      AuthDiagnostics.instance.record(
        'session_storage_read',
        data: {'stored_session_present': value != null},
      );
      return value;
    } catch (error) {
      AuthDiagnostics.instance.record(
        'session_storage_failure',
        failure: true,
        data: {'storage_operation': 'read'},
        error: error,
      );
      rethrow;
    }
  }

  Future<void> writeSession(supabase.Session session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString(
        storageKey,
        jsonEncode(session.toJson()),
      );
      AuthDiagnostics.instance.record(
        'session_storage_write',
        failure: !saved,
        data: {
          'outcome': saved ? 'saved' : 'not_saved',
          'access_expires_at': session.expiresAt,
        },
      );
    } catch (error) {
      AuthDiagnostics.instance.record(
        'session_storage_failure',
        failure: true,
        data: {'storage_operation': 'write'},
        error: error,
      );
      rethrow;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final removed = await prefs.remove(storageKey);
      AuthDiagnostics.instance.record(
        'session_storage_clear',
        failure: !removed,
        data: {'outcome': removed ? 'cleared' : 'not_cleared'},
      );
    } catch (error) {
      AuthDiagnostics.instance.record(
        'session_storage_failure',
        failure: true,
        data: {'storage_operation': 'clear'},
        error: error,
      );
      rethrow;
    }
  }
}
