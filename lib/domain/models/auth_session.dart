enum AuthSessionStatus { unknown, loading, signedOut, signedIn, error }

class AuthSession {
  const AuthSession({
    required this.status,
    this.accountId,
    this.sessionId,
    this.email,
    this.displayName,
    this.accessTokenExpiresAt,
    this.errorCode,
  });

  const AuthSession.unknown() : this(status: AuthSessionStatus.unknown);

  const AuthSession.loading() : this(status: AuthSessionStatus.loading);

  const AuthSession.signedOut() : this(status: AuthSessionStatus.signedOut);

  const AuthSession.error(String code)
    : this(status: AuthSessionStatus.error, errorCode: code);

  final AuthSessionStatus status;
  final String? accountId;
  final String? sessionId;
  final String? email;
  final String? displayName;
  final DateTime? accessTokenExpiresAt;
  final String? errorCode;

  bool get isSignedIn =>
      status == AuthSessionStatus.signedIn && (accountId ?? '').isNotEmpty;

  AuthSession copyWith({
    AuthSessionStatus? status,
    String? accountId,
    String? sessionId,
    String? email,
    String? displayName,
    DateTime? accessTokenExpiresAt,
    String? errorCode,
  }) {
    return AuthSession(
      status: status ?? this.status,
      accountId: accountId ?? this.accountId,
      sessionId: sessionId ?? this.sessionId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
      errorCode: errorCode ?? this.errorCode,
    );
  }
}
