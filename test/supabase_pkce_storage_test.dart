import 'package:fitlog_local/core/config/supabase_pkce_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'SharedPreferencesGotrueAsyncStorage stores and removes values',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const storage = SharedPreferencesGotrueAsyncStorage();

      await storage.setItem(key: 'code-verifier', value: 'verifier-123');

      expect(await storage.getItem(key: 'code-verifier'), 'verifier-123');

      await storage.removeItem(key: 'code-verifier');

      expect(await storage.getItem(key: 'code-verifier'), isNull);
    },
  );
}
