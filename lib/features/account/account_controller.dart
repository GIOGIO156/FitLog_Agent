import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/ai_local_context_permission_repository.dart';
import '../../data/repositories/active_device_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/cloud_profile_repository.dart';
import '../../data/repositories/phase2_repository_exception.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/subscription_repository.dart';
import '../../domain/models/ai_availability.dart';
import '../../domain/models/ai_local_context_permission.dart';
import '../../domain/models/auth_session.dart';
import '../../domain/models/cloud_runtime_context.dart';
import '../../domain/models/cloud_profile.dart';
import '../../domain/models/network_status.dart';
import '../../domain/models/subscription_status.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/services/cloud_profile_mapper.dart';

class AccountController extends ChangeNotifier {
  AccountController({
    required this.authRepository,
    required this.subscriptionRepository,
    required this.cloudProfileRepository,
    required this.profileRepository,
    required this.contextPermissionRepository,
    this.activeDeviceRepository = const NoopActiveDeviceRepository(),
    this.cloudRuntimeContext,
    this.mapper = const CloudProfileMapper(),
    required this.backendConfigured,
  }) {
    cloudRuntimeContext?.addListener(_handleCloudRuntimeChanged);
  }

  final AuthRepository authRepository;
  final SubscriptionRepository subscriptionRepository;
  final CloudProfileRepository cloudProfileRepository;
  final ProfileRepository profileRepository;
  final AiLocalContextPermissionRepository contextPermissionRepository;
  final ActiveDeviceRepository activeDeviceRepository;
  final CloudRuntimeContext? cloudRuntimeContext;
  final CloudProfileMapper mapper;
  final bool backendConfigured;

  AuthSession authSession = const AuthSession.unknown();
  SubscriptionStatus subscriptionStatus = const SubscriptionStatus.unknown();
  CloudProfileState cloudProfileState = const CloudProfileState.unknown();
  NetworkStatus networkStatus = const NetworkStatus.online();
  AiLocalContextPermission? localContextPermission;
  bool initialized = false;
  int accountChangeEpoch = 0;
  String? cachedCloudProfileAccountId;
  int? cachedCloudProfileVersion;
  bool _handlingDeviceReplacement = false;
  Future<void>? _backgroundAccountStateTask;

  static const String _cacheAccountIdKey = 'cached_cloud_profile_account_id';
  static const String _cacheVersionKey = 'cached_cloud_profile_version';
  static const String _cacheSyncedAtKey = 'cached_cloud_profile_synced_at';

  bool get hasCurrentAccountCachedCloudProfile {
    final accountId = authSession.accountId;
    return accountId != null &&
        accountId.isNotEmpty &&
        cachedCloudProfileAccountId == accountId &&
        cachedCloudProfileVersion != null;
  }

  AiAvailability get aiAvailability {
    if (!authSession.isSignedIn) {
      return const AiAvailability(
        status: AiAvailabilityStatus.signedOut,
        canEditComposer: true,
        canSend: false,
        reason: 'signed_out',
      );
    }
    if (networkStatus.isOffline) {
      return const AiAvailability(
        status: AiAvailabilityStatus.offline,
        canEditComposer: true,
        canSend: false,
        reason: 'offline',
      );
    }
    if (!subscriptionStatus.isActive) {
      return const AiAvailability(
        status: AiAvailabilityStatus.subscriptionInactive,
        canEditComposer: true,
        canSend: false,
        reason: 'subscription_inactive',
      );
    }
    if (!cloudProfileState.isReady) {
      return const AiAvailability(
        status: AiAvailabilityStatus.profileMissing,
        canEditComposer: true,
        canSend: false,
        reason: 'profile_missing',
      );
    }
    return const AiAvailability(
      status: AiAvailabilityStatus.readyForPhase3,
      canEditComposer: true,
      canSend: false,
      reason: 'phase3_required',
    );
  }

  Future<void> initialize() async {
    authSession = const AuthSession.loading();
    notifyListeners();
    try {
      authSession = await authRepository.loadSession();
      await _loadCacheMetadata();
      initialized = true;
      profileRepository.setActiveAccountId(authSession.accountId);
      if (authSession.isSignedIn) {
        await _loadCachedCloudProfileIfAvailable();
      } else {
        _clearAccountBoundState();
      }
      notifyListeners();
      if (authSession.isSignedIn) {
        _startBackgroundAccountStateLoad();
      }
    } on Phase2RepositoryException catch (error) {
      initialized = true;
      authSession = AuthSession.error(error.code);
      notifyListeners();
    } catch (_) {
      initialized = true;
      authSession = const AuthSession.error('auth_failed');
      notifyListeners();
    }
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _authenticate(
      () => authRepository.signInWithPassword(email: email, password: password),
    );
  }

  Future<void> sendRegistrationOtp(String email) async {
    await authRepository.sendRegistrationOtp(email);
  }

  Future<void> completeRegistration({
    required String email,
    required String token,
    required String password,
  }) async {
    await _authenticate(
      () => authRepository.completeRegistration(
        email: email,
        token: token,
        password: password,
      ),
    );
  }

  Future<void> _authenticate(Future<AuthSession> Function() action) async {
    final previousSession = authSession;
    final previousAccountId = authSession.accountId;
    try {
      authSession = await action();
      await _claimActiveDeviceIfNeeded();
      profileRepository.setActiveAccountId(authSession.accountId);
      if (previousAccountId != authSession.accountId) {
        accountChangeEpoch++;
      }
      notifyListeners();
      await _loadAccountBoundState();
    } on Phase2RepositoryException {
      authSession = previousSession.isSignedIn
          ? previousSession
          : const AuthSession.signedOut();
      notifyListeners();
      rethrow;
    } catch (_) {
      authSession = previousSession.isSignedIn
          ? previousSession
          : const AuthSession.signedOut();
      notifyListeners();
      throw const Phase2RepositoryException('auth_failed');
    }
  }

  Future<void> signOut() async {
    await activeDeviceRepository.release();
    await authRepository.signOut();
    await profileRepository.clearProfile();
    profileRepository.setActiveAccountId(null);
    cloudRuntimeContext?.clear();
    authSession = const AuthSession.signedOut();
    _clearAccountBoundState();
    accountChangeEpoch++;
    await _clearCacheMetadata();
    notifyListeners();
  }

  @override
  void dispose() {
    cloudRuntimeContext?.removeListener(_handleCloudRuntimeChanged);
    super.dispose();
  }

  Future<void> refreshAccountState() async {
    if (!authSession.isSignedIn) {
      profileRepository.setActiveAccountId(null);
      _clearAccountBoundState();
      notifyListeners();
      return;
    }
    profileRepository.setActiveAccountId(authSession.accountId);
    _backgroundAccountStateTask = _loadAccountBoundStateAfterDeviceClaim();
    await _backgroundAccountStateTask;
  }

  Future<void> waitForBackgroundAccountState() async {
    await _backgroundAccountStateTask;
  }

  Future<void> refreshSubscriptionStatus() async {
    final accountId = authSession.accountId;
    if (accountId == null || accountId.isEmpty) {
      subscriptionStatus = const SubscriptionStatus.unknown();
      notifyListeners();
      return;
    }
    await _loadSubscriptionStatus(accountId);
  }

  Future<void> redeemSubscriptionCode(String code) async {
    final accountId = authSession.accountId;
    if (accountId == null || accountId.isEmpty) {
      throw const Phase2RepositoryException('auth_required');
    }
    await subscriptionRepository.redeemCode(code);
    await _loadSubscriptionStatus(accountId);
  }

  Future<void> createDefaultCloudProfile() async {
    final accountId = authSession.accountId;
    if (accountId == null || accountId.isEmpty) {
      throw const Phase2RepositoryException('auth_required');
    }
    await saveCloudProfile(mapper.defaultForAccount(accountId).profile);
  }

  Future<void> saveCloudProfile(UserProfile profile) async {
    final accountId = authSession.accountId;
    if (accountId == null || accountId.isEmpty) {
      throw const Phase2RepositoryException('auth_required');
    }
    final previousState = cloudProfileState;
    final existing = cloudProfileState.cloudProfile;
    cloudProfileState = cloudProfileState.copyWith(
      status: CloudProfileStatus.saving,
    );
    notifyListeners();
    try {
      final next = mapper.updateFromUserProfile(
        existing: existing,
        accountId: accountId,
        profile: profile,
      );
      final saved = await cloudProfileRepository.save(next);
      await _cacheCloudProfileBestEffort(saved);
      cloudProfileState = CloudProfileState(
        status: CloudProfileStatus.ready,
        cloudProfile: saved,
        lastSyncedAt: DateTime.now().toUtc(),
      );
      notifyListeners();
    } on Phase2RepositoryException catch (error) {
      cloudProfileState = existing == null
          ? CloudProfileState.error(error.code)
          : previousState.copyWith(status: CloudProfileStatus.ready);
      notifyListeners();
      rethrow;
    } catch (_) {
      cloudProfileState = existing == null
          ? const CloudProfileState.error('profile_save_failed')
          : previousState.copyWith(status: CloudProfileStatus.ready);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setLocalContextAllowed(bool allowed) async {
    final accountId = authSession.accountId;
    if (accountId == null || accountId.isEmpty) {
      return;
    }
    localContextPermission = await contextPermissionRepository.set(
      accountId: accountId,
      allowed: allowed,
    );
    notifyListeners();
  }

  Future<void> _loadAccountBoundState() async {
    final accountId = authSession.accountId;
    if (accountId == null || accountId.isEmpty) {
      _clearAccountBoundState();
      notifyListeners();
      return;
    }
    final previousCloudProfileState = cloudProfileState;
    subscriptionStatus = const SubscriptionStatus.loading();
    if (!cloudProfileState.isReady) {
      cloudProfileState = const CloudProfileState.loading();
    }
    notifyListeners();

    await _loadSubscriptionStatus(accountId);

    try {
      var profile = await cloudProfileRepository.fetch(accountId);
      localContextPermission = await _loadLocalContextPermission(accountId);
      profile ??= await cloudProfileRepository.save(
        mapper.defaultForAccount(accountId),
      );
      await _cacheCloudProfileBestEffort(profile);
      cloudProfileState = CloudProfileState(
        status: CloudProfileStatus.ready,
        cloudProfile: profile,
        lastSyncedAt: DateTime.now().toUtc(),
      );
      networkStatus = const NetworkStatus.online();
      notifyListeners();
    } on Phase2RepositoryException catch (error) {
      if (error.code.contains('network')) {
        networkStatus = const NetworkStatus.offline();
      }
      cloudProfileState = previousCloudProfileState.isReady
          ? previousCloudProfileState
          : CloudProfileState.error(error.code);
      notifyListeners();
    } catch (_) {
      cloudProfileState = previousCloudProfileState.isReady
          ? previousCloudProfileState
          : const CloudProfileState.error('profile_load_failed');
      notifyListeners();
    }
  }

  Future<void> _claimActiveDeviceIfNeeded() async {
    if (!authSession.isSignedIn) {
      cloudRuntimeContext?.clear();
      return;
    }
    await activeDeviceRepository.claim(authSession);
  }

  void _startBackgroundAccountStateLoad() {
    _backgroundAccountStateTask = _loadAccountBoundStateAfterDeviceClaim();
    unawaited(_backgroundAccountStateTask);
  }

  Future<void> _loadAccountBoundStateAfterDeviceClaim() async {
    try {
      await _claimActiveDeviceIfNeeded();
    } on Phase2RepositoryException catch (error) {
      if (error.code == 'device_replaced') {
        await _handleDeviceReplaced();
        return;
      }
      if (error.code.contains('network')) {
        networkStatus = const NetworkStatus.offline();
        notifyListeners();
      } else {
        cloudProfileState = CloudProfileState.error(error.code);
        notifyListeners();
        return;
      }
    } catch (_) {
      cloudProfileState = const CloudProfileState.error(
        'active_device_claim_failed',
      );
      notifyListeners();
      return;
    }
    await _loadAccountBoundState();
  }

  Future<void> _loadCachedCloudProfileIfAvailable() async {
    if (!hasCurrentAccountCachedCloudProfile) {
      return;
    }
    try {
      final profile = await profileRepository.getProfile();
      final accountId = authSession.accountId;
      final profileVersion = cachedCloudProfileVersion;
      if (profile == null || accountId == null || profileVersion == null) {
        return;
      }
      cloudProfileState = CloudProfileState(
        status: CloudProfileStatus.ready,
        cloudProfile: CloudProfile(
          accountId: accountId,
          profile: profile,
          profileVersion: profileVersion,
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Cloud Profile cached read failed: $error');
      }
    }
  }

  void _handleCloudRuntimeChanged() {
    if (cloudRuntimeContext?.deviceReplaced != true ||
        !authSession.isSignedIn ||
        _handlingDeviceReplacement) {
      return;
    }
    unawaited(_handleDeviceReplaced());
  }

  Future<void> _handleDeviceReplaced() async {
    _handlingDeviceReplacement = true;
    try {
      try {
        await authRepository.signOut();
      } catch (_) {
        // The active-device server guard already prevents official writes.
      }
      try {
        await profileRepository.clearProfile();
      } catch (_) {
        // Local cache cleanup is best-effort; auth state still moves out.
      }
      profileRepository.setActiveAccountId(null);
      _clearAccountBoundState();
      await _clearCacheMetadata();
      authSession = const AuthSession.error('device_replaced');
      accountChangeEpoch++;
      notifyListeners();
    } finally {
      _handlingDeviceReplacement = false;
    }
  }

  Future<void> _loadSubscriptionStatus(String accountId) async {
    subscriptionStatus = const SubscriptionStatus.loading();
    notifyListeners();
    try {
      subscriptionStatus = await subscriptionRepository.getStatus(accountId);
      notifyListeners();
    } on Phase2RepositoryException catch (error) {
      subscriptionStatus = SubscriptionStatus.error(error.code);
      notifyListeners();
    } catch (_) {
      subscriptionStatus = const SubscriptionStatus.error(
        'subscription_load_failed',
      );
      notifyListeners();
    }
  }

  Future<AiLocalContextPermission> _loadLocalContextPermission(
    String accountId,
  ) async {
    try {
      return await contextPermissionRepository.get(accountId);
    } catch (_) {
      return AiLocalContextPermission(
        accountId: accountId,
        allowed: false,
        updatedAt: DateTime.now().toUtc(),
      );
    }
  }

  void _clearAccountBoundState() {
    subscriptionStatus = const SubscriptionStatus.unknown();
    cloudProfileState = const CloudProfileState.unknown();
    localContextPermission = null;
  }

  Future<void> _cacheCloudProfile(CloudProfile cloudProfile) async {
    await profileRepository.saveProfile(
      cloudProfile.profile,
      accountId: cloudProfile.accountId,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheAccountIdKey, cloudProfile.accountId);
    await prefs.setInt(_cacheVersionKey, cloudProfile.profileVersion);
    await prefs.setString(
      _cacheSyncedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    cachedCloudProfileAccountId = cloudProfile.accountId;
    cachedCloudProfileVersion = cloudProfile.profileVersion;
  }

  Future<void> _cacheCloudProfileBestEffort(CloudProfile cloudProfile) async {
    try {
      await _cacheCloudProfile(cloudProfile);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Cloud Profile local cache failed: $error');
      }
    }
  }

  Future<void> _clearCacheMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheAccountIdKey);
    await prefs.remove(_cacheVersionKey);
    await prefs.remove(_cacheSyncedAtKey);
    cachedCloudProfileAccountId = null;
    cachedCloudProfileVersion = null;
  }

  Future<void> _loadCacheMetadata() async {
    final accountId = authSession.accountId;
    if (accountId == null || accountId.isEmpty) {
      cachedCloudProfileAccountId = null;
      cachedCloudProfileVersion = null;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final cachedAccountId = prefs.getString(_cacheAccountIdKey);
    if (cachedAccountId != accountId) {
      cachedCloudProfileAccountId = null;
      cachedCloudProfileVersion = null;
      return;
    }
    cachedCloudProfileAccountId = cachedAccountId;
    cachedCloudProfileVersion = prefs.getInt(_cacheVersionKey);
  }
}
