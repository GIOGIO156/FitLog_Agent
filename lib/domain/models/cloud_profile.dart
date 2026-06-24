import 'user_profile.dart';

enum CloudProfileStatus {
  unknown,
  loading,
  missing,
  ready,
  saving,
  offlineReadonly,
  error,
  conflict,
}

class CloudProfile {
  const CloudProfile({
    required this.accountId,
    required this.profile,
    required this.profileVersion,
    this.createdAt,
    this.updatedAt,
  });

  final String accountId;
  final UserProfile profile;
  final int profileVersion;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class CloudProfileState {
  const CloudProfileState({
    required this.status,
    this.cloudProfile,
    this.lastSyncedAt,
    this.errorCode,
  });

  const CloudProfileState.unknown() : this(status: CloudProfileStatus.unknown);

  const CloudProfileState.loading() : this(status: CloudProfileStatus.loading);

  const CloudProfileState.missing() : this(status: CloudProfileStatus.missing);

  const CloudProfileState.error(String code)
    : this(status: CloudProfileStatus.error, errorCode: code);

  final CloudProfileStatus status;
  final CloudProfile? cloudProfile;
  final DateTime? lastSyncedAt;
  final String? errorCode;

  bool get isReady =>
      status == CloudProfileStatus.ready && cloudProfile != null;

  CloudProfileState copyWith({
    CloudProfileStatus? status,
    CloudProfile? cloudProfile,
    DateTime? lastSyncedAt,
    String? errorCode,
  }) {
    return CloudProfileState(
      status: status ?? this.status,
      cloudProfile: cloudProfile ?? this.cloudProfile,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorCode: errorCode ?? this.errorCode,
    );
  }
}
