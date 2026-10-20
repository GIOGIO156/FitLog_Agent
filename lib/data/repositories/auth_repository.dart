import 'dart:convert';

import 'package:supabase/supabase.dart' as supabase;

import '../../core/config/supabase_pkce_storage.dart';
import '../../core/diagnostics/auth_diagnostics.dart';
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
    AuthDiagnostics.instance.record('session_restore_start');
    try {
      final storedSessionJson = await sessionStorage.readSessionJson();
      AuthDiagnostics.instance.record(
        'session_restore_storage',
        data: {
          'stored_session_present':
              storedSessionJson != null && storedSessionJson.trim().isNotEmpty,
        },
      );
      if (storedSessionJson != null && storedSessionJson.trim().isNotEmpty) {
        try {
          final stored = supabase.Session.fromJson(
            jsonDecode(storedSessionJson) as Map<String, dynamic>,
          );
          AuthDiagnostics.instance.record(
            'session_restore_metadata',
            data: {
              'access_expired': stored?.isExpired,
              'access_expires_at': stored?.expiresAt,
            },
          );
        } catch (_) {
          // Recovery below remains responsible for validation and auth behavior.
        }
        final response = await client.auth.recoverSession(storedSessionJson);
        final recoveredSession = response.session ?? client.auth.currentSession;
        final recoveredUser =
            response.user ?? recoveredSession?.user ?? client.auth.currentUser;
        if (recoveredSession != null && recoveredUser != null) {
          await sessionStorage.writeSession(recoveredSession);
          AuthDiagnostics.instance.record('session_restore_success');
          return _toAuthSession(session: recoveredSession, user: recoveredUser);
        }
      }

      final session = client.auth.currentSession;
      final user = client.auth.currentUser;
      if (session == null || user == null) {
        AuthDiagnostics.instance.record(
          'session_restore_signed_out',
          data: {'reason': 'no_session'},
        );
        return const AuthSession.signedOut();
      }
      await sessionStorage.writeSession(session);
      return _toAuthSession(session: session, user: user);
    } catch (error) {
      AuthDiagnostics.instance.record(
        'session_restore_failure',
        failure: true,
        error: error,
      );
      AuthDiagnostics.instance.record(
        'session_clear_requested',
        data: {'reason': 'restore_exception'},
      );
      await sessionStorage.clear();
      throw _authExceptionFor(error);
    }
  }

  @override
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    AuthDiagnostics.instance.record('password_login_start');
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
      AuthDiagnostics.instance.record('password_login_success');
      return _toAuthSession(session: session, user: user);
    } on Phase2RepositoryException {
      AuthDiagnostics.instance.record(
        'password_login_failure',
        failure: true,
        data: {'reason': 'missing_session'},
      );
      rethrow;
    } catch (error) {
      AuthDiagnostics.instance.record(
        'password_login_failure',
        failure: true,
        error: error,
      );
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
    AuthDiagnostics.instance.record(
      'session_clear_requested',
      data: {'reason': 'sign_out'},
    );
    await sessionStorage.clear();
    try {
      await client.auth.signOut();
    } catch (error) {
      final exception = _authExceptionFor(error);
      // Preserve the pre-diagnostics sign-out downgrade, independently of the
      // more precise error categories now presented to users.
      final text = error.toString().toLowerCase();
      final previouslyNonNetwork = const [
        'invalid login credentials',
        'invalid_credentials',
        'email not confirmed',
        'email_not_confirmed',
        'email_not_verified',
        'already registered',
        'already exists',
        'user_already_exists',
        'otp',
        'token',
        'expired',
        'rate limit',
        'too many',
      ].any(text.contains);
      final previouslyNetwork = const [
        'socket',
        'failed host lookup',
        'network',
        'connection',
      ].any(text.contains);
      if (previouslyNonNetwork || !previouslyNetwork) {
        throw exception;
      }
    }
  }

  Phase2RepositoryException _authExceptionFor(Object error) {
    return Phase2RepositoryException(authFailureCode(error));
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
      sessionId: _sessionIdFromAccessToken(session.accessToken),
      email: user.email,
      displayName: displayName,
      accessTokenExpiresAt: expiresAt,
    );
  }

  String? _sessionIdFromAccessToken(String accessToken) {
    final parts = accessToken.split('.');
    if (parts.length < 2) {
      return null;
    }
    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (payload is! Map) {
        return null;
      }
      return payload['session_id']?.toString() ??
          payload['sid']?.toString() ??
          payload['jti']?.toString();
    } catch (_) {
      return null;
    }
  }
}
