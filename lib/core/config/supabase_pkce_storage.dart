import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart' as supabase;

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
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(storageKey);
  }

  Future<void> writeSession(supabase.Session session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}
