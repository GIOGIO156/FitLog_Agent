import 'package:supabase/supabase.dart' as supabase;

import '../../core/config/supabase_pkce_storage.dart';
import '../../domain/models/auth_session.dart';
import 'phase2_repository_exception.dart';

abstract class AuthRepository {
  Future<AuthSession> loadSession();

  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> sendRegistrationOtp(String email);

  Future<AuthSession> completeRegistration({
    required String email,
    required String token,
    required String password,
  });

  Future<void> signOut();
}

class UnconfiguredAuthRepository implements AuthRepository {
  const UnconfiguredAuthRepository();

  @override
  Future<AuthSession> loadSession() async => const AuthSession.signedOut();

  @override
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    throw const Phase2RepositoryException('backend_not_configured');
  }

  @override
  Future<void> sendRegistrationOtp(String email) async {
    throw const Phase2RepositoryException('backend_not_configured');
  }

  @override
  Future<AuthSession> completeRegistration({
    required String email,
    required String token,
    required String password,
  }) async {
    throw const Phase2RepositoryException('backend_not_configured');
  }

  @override
  Future<void> signOut() async {}
}

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(
    this.client, {
    this.sessionStorage = const SharedPreferencesSupabaseAuthSessionStorage(),
  });

  final supabase.SupabaseClient client;
  final SharedPreferencesSupabaseAuthSessionStorage sessionStorage;

  @override
  Future<AuthSession> loadSession() async {
    try {
      final storedSessionJson = await sessionStorage.readSessionJson();
      if (storedSessionJson != null && storedSessionJson.trim().isNotEmpty) {
        final response = await client.auth.recoverSession(storedSessionJson);
        final recoveredSession = response.session ?? client.auth.currentSession;
        final recoveredUser =
            response.user ?? recoveredSession?.user ?? client.auth.currentUser;
        if (recoveredSession != null && recoveredUser != null) {
          await sessionStorage.writeSession(recoveredSession);
          return _toAuthSession(session: recoveredSession, user: recoveredUser);
        }
      }

      final session = client.auth.currentSession;
      final user = client.auth.currentUser;
      if (session == null || user == null) {
        return const AuthSession.signedOut();
      }
      await sessionStorage.writeSession(session);
      return _toAuthSession(session: session, user: user);
    } catch (error) {
      await sessionStorage.clear();
      throw _authExceptionFor(error);
    }
  }

  @override
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final session = response.session ?? client.auth.currentSession;
      final user = response.user ?? client.auth.currentUser;
      if (session == null || user == null) {
        throw const Phase2RepositoryException('auth_failed');
      }
      await sessionStorage.writeSession(session);
      return _toAuthSession(session: session, user: user);
    } on Phase2RepositoryException {
      rethrow;
    } catch (error) {
      throw _authExceptionFor(error);
    }
  }

  @override
  Future<void> sendRegistrationOtp(String email) async {
    try {
      await client.auth.signInWithOtp(
        email: email.trim(),
        shouldCreateUser: true,
      );
    } catch (error) {
      throw _authExceptionFor(error);
    }
  }

  @override
  Future<AuthSession> completeRegistration({
    required String email,
    required String token,
    required String password,
  }) async {
    try {
      final response = await client.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: supabase.OtpType.email,
      );
      await client.auth.updateUser(supabase.UserAttributes(password: password));
      final session = response.session ?? client.auth.currentSession;
      final user = response.user ?? client.auth.currentUser;
      if (session == null || user == null) {
        throw const Phase2RepositoryException('auth_failed');
      }
      await sessionStorage.writeSession(session);
      return _toAuthSession(session: session, user: user);
    } on Phase2RepositoryException {
      rethrow;
    } catch (error) {
      throw _authExceptionFor(error);
    }
  }

  @override
  Future<void> signOut() async {
    await sessionStorage.clear();
    try {
      await client.auth.signOut();
    } catch (error) {
      final exception = _authExceptionFor(error);
      if (exception.code != 'auth_network_error') {
        throw exception;
      }
    }
  }

  Phase2RepositoryException _authExceptionFor(Object error) {
    final details = error.toString();
    final normalized = details.toLowerCase();
    if (normalized.contains('invalid login credentials') ||
        normalized.contains('invalid_credentials')) {
      return Phase2RepositoryException('invalid_credentials', details);
    }
    if (normalized.contains('email not confirmed') ||
        normalized.contains('email_not_confirmed') ||
        normalized.contains('email_not_verified')) {
      return Phase2RepositoryException('email_not_confirmed', details);
    }
    if (normalized.contains('already registered') ||
        normalized.contains('already exists') ||
        normalized.contains('user_already_exists')) {
      return Phase2RepositoryException('email_already_registered', details);
    }
    if (normalized.contains('otp') ||
        normalized.contains('token') ||
        normalized.contains('expired')) {
      return Phase2RepositoryException('otp_invalid_or_expired', details);
    }
    if (normalized.contains('rate limit') ||
        normalized.contains('too many') ||
        normalized.contains('over email send rate limit')) {
      return Phase2RepositoryException('auth_rate_limited', details);
    }
    if (normalized.contains('socket') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('network') ||
        normalized.contains('connection')) {
      return Phase2RepositoryException('auth_network_error', details);
    }
    return Phase2RepositoryException('auth_failed', details);
  }

  AuthSession _toAuthSession({
    required supabase.Session session,
    required supabase.User user,
  }) {
    final expiresAt = session.expiresAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
    final displayName = user.userMetadata?['display_name']?.toString();
    return AuthSession(
      status: AuthSessionStatus.signedIn,
      accountId: user.id,
      email: user.email,
      displayName: displayName,
      accessTokenExpiresAt: expiresAt,
    );
  }
}
