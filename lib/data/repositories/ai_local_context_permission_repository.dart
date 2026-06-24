import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/ai_local_context_permission.dart';

class AiLocalContextPermissionRepository {
  const AiLocalContextPermissionRepository();

  static String _key(String accountId) =>
      'ai_local_context_permission_$accountId';

  Future<AiLocalContextPermission> get(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    return AiLocalContextPermission(
      accountId: accountId,
      allowed: prefs.getBool(_key(accountId)) ?? false,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Future<AiLocalContextPermission> set({
    required String accountId,
    required bool allowed,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(accountId), allowed);
    return AiLocalContextPermission(
      accountId: accountId,
      allowed: allowed,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
