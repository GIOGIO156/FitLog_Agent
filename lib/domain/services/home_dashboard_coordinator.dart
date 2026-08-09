import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/repositories/profile_repository.dart';
import '../models/daily_summary.dart';
import '../models/daily_summary_entry.dart';
import '../models/user_profile.dart';
import 'daily_summary_service.dart';

class HomeDashboardSnapshot {
  const HomeDashboardSnapshot({
    required this.accountId,
    required this.date,
    required this.summary,
    required this.profile,
    required this.fingerprint,
    required this.source,
    this.cachedAt,
  });

  final String? accountId;
  final String date;
  final DailySummary summary;
  final UserProfile? profile;
  final String fingerprint;
  final String source;
  final DateTime? cachedAt;
}

class HomeDashboardCoordinator extends ChangeNotifier {
  HomeDashboardCoordinator({
    required DailySummaryService dailySummaryService,
    required ProfileRepository profileRepository,
    DateTime Function()? now,
  }) : _dailySummaryService = dailySummaryService,
       _profileRepository = profileRepository,
       _now = now ?? (() => DateTime.now().toUtc());

  static const Duration cacheFreshness = Duration(minutes: 5);
  static const Duration failureBackoff = Duration(seconds: 45);

  final DailySummaryService _dailySummaryService;
  final ProfileRepository _profileRepository;
  final DateTime Function() _now;

  final Map<String, Future<void>> _inFlightByKey = <String, Future<void>>{};
  final Map<String, DateTime> _failedAtByKey = <String, DateTime>{};

  String? _accountId;
  String? _selectedDate;
  bool _canUseOfficialCloud = false;
  int? _profileVersion;
  int _accountEpoch = 0;
  int _generation = 0;
  bool _initialLoading = false;
  bool _refreshing = false;
  Object? _error;
  HomeDashboardSnapshot? _snapshot;

  String? get accountId => _accountId;
  String? get selectedDate => _selectedDate;
  bool get canUseOfficialCloud => _canUseOfficialCloud;
  int? get profileVersion => _profileVersion;
  bool get isInitialLoading => _initialLoading;
  bool get isRefreshing => _refreshing;
  Object? get error => _error;
  HomeDashboardSnapshot? get snapshot => _snapshot;
  bool get hasSnapshot => _snapshot != null;

  void bindAccountContext({
    required String? accountId,
    required bool canUseOfficialCloud,
    required int? profileVersion,
    required int accountEpoch,
  }) {
    final normalizedAccountId = _normalizeAccountId(accountId);
    final accountChanged =
        normalizedAccountId != _accountId || accountEpoch != _accountEpoch;
    final cloudBecameReady = !_canUseOfficialCloud && canUseOfficialCloud;
    final profileChanged = _profileVersion != profileVersion;
    if (!accountChanged &&
        _canUseOfficialCloud == canUseOfficialCloud &&
        !profileChanged) {
      return;
    }

    _accountId = normalizedAccountId;
    _canUseOfficialCloud = canUseOfficialCloud;
    _profileVersion = profileVersion;
    _accountEpoch = accountEpoch;
    if (accountChanged) {
      _generation++;
      _snapshot = null;
      _error = null;
      _initialLoading = false;
      _refreshing = false;
      _failedAtByKey.clear();
    }
    notifyListeners();

    final selectedDate = _selectedDate;
    if (selectedDate == null) {
      return;
    }
    final shouldForceCloud =
        canUseOfficialCloud && (cloudBecameReady || profileChanged);
    _loadSelectedDate(
      reason: accountChanged ? 'account_changed' : 'context_changed',
      forceCloud: shouldForceCloud,
    );
  }

  void setSelectedDate(String date) {
    if (date == _selectedDate) {
      return;
    }
    _selectedDate = date;
    _error = null;
    if (_snapshot?.date != date) {
      _snapshot = null;
    }
    notifyListeners();
    _loadSelectedDate(reason: 'date_selected');
  }

  void refreshVisible({String reason = 'refresh', bool forceCloud = false}) {
    _loadSelectedDate(reason: reason, forceCloud: forceCloud);
  }

  void invalidateDates({
    required Iterable<String> days,
    required String? accountId,
    String reason = 'data_changed',
  }) {
    final normalizedAccountId = _normalizeAccountId(accountId);
    if (normalizedAccountId == null) {
      return;
    }
    final uniqueDays = days.where((day) => day.isNotEmpty).toSet();
    if (uniqueDays.isEmpty) {
      return;
    }
    for (final day in uniqueDays) {
      final isVisible =
          normalizedAccountId == _accountId && day == _selectedDate;
      if (isVisible) {
        _loadSelectedDate(reason: reason, forceCloud: true);
      } else {
        _rebuildDateInBackground(
          accountId: normalizedAccountId,
          day: day,
          reason: reason,
        );
      }
    }
  }

  void _loadSelectedDate({required String reason, bool forceCloud = false}) {
    final day = _selectedDate;
    if (day == null || day.isEmpty) {
      return;
    }
    final generation = _generation;
    final accountId = _accountId;
    final key = _keyFor(accountId: accountId, day: day);
    final existing = _inFlightByKey[key];
    if (existing != null) {
      return;
    }

    if (_snapshot == null || _snapshot?.date != day) {
      _initialLoading = true;
    } else {
      _refreshing = true;
    }
    _error = null;
    notifyListeners();

    final task = _loadDate(
      accountId: accountId,
      day: day,
      generation: generation,
      reason: reason,
      forceCloud: forceCloud,
    );
    _inFlightByKey[key] = task;
    unawaited(
      task.whenComplete(() {
        if (_inFlightByKey[key] == task) {
          _inFlightByKey.remove(key);
        }
      }),
    );
  }

  Future<void> _loadDate({
    required String? accountId,
    required String day,
    required int generation,
    required String reason,
    required bool forceCloud,
  }) async {
    var publishedDuringLoad = false;
    final key = _keyFor(accountId: accountId, day: day);
    try {
      if (accountId == null) {
        final data = await Future.wait<Object?>(<Future<Object?>>[
          _dailySummaryService.getSummaryForDate(day),
          _profileRepository.getProfile(),
        ]);
        _publishIfCurrent(
          generation: generation,
          snapshot: _snapshotFromSummary(
            accountId: null,
            summary: data[0]! as DailySummary,
            profile: data[1] as UserProfile?,
            source: 'local_compute',
          ),
        );
        publishedDuringLoad = true;
        return;
      }

      if (!forceCloud) {
        final local = await _dailySummaryService.getLocalCachedSummaryEntry(
          accountId: accountId,
          day: day,
        );
        if (local != null) {
          final profile = await _profileRepository.getProfile();
          _publishIfCurrent(
            generation: generation,
            snapshot: _snapshotFromEntry(
              entry: local,
              profile: profile,
              source: 'local_cache',
            ),
          );
          publishedDuringLoad = true;
          if (local.isFreshAt(_now(), cacheFreshness) ||
              !_canUseOfficialCloud ||
              _isInFailureBackoff(key)) {
            return;
          }
        } else if (!_canUseOfficialCloud) {
          return;
        }
      } else if (!_canUseOfficialCloud && _snapshot != null) {
        return;
      }

      if (!_canUseOfficialCloud) {
        return;
      }

      final summary = await _dailySummaryService.getSummaryForDateAndCache(
        day: day,
        accountId: accountId,
        refreshOfficialRecords: true,
        profileVersion: _profileVersion,
      );
      final profile = await _profileRepository.getProfile();
      _failedAtByKey.remove(key);
      _publishIfCurrent(
        generation: generation,
        snapshot: _snapshotFromSummary(
          accountId: accountId,
          summary: summary,
          profile: profile,
          source: 'cloud_revalidated',
        ),
      );
      publishedDuringLoad = true;
    } catch (error) {
      _failedAtByKey[key] = _now();
      if (generation == _generation) {
        _error = error;
      }
    } finally {
      if (generation == _generation) {
        _initialLoading = false;
        _refreshing = false;
        if (publishedDuringLoad) {
          _error = null;
        }
        notifyListeners();
      }
    }
  }

  void _rebuildDateInBackground({
    required String accountId,
    required String day,
    required String reason,
  }) {
    if (!_canUseOfficialCloud) {
      return;
    }
    final key = _keyFor(accountId: accountId, day: day);
    if (_inFlightByKey.containsKey(key) || _isInFailureBackoff(key)) {
      return;
    }
    final task = _dailySummaryService
        .getSummaryForDateAndCache(
          day: day,
          accountId: accountId,
          refreshOfficialRecords: true,
          profileVersion: _profileVersion,
        )
        .then<void>((_) {
          _failedAtByKey.remove(key);
        })
        .catchError((Object error) {
          _failedAtByKey[key] = _now();
        });
    _inFlightByKey[key] = task;
    unawaited(
      task.whenComplete(() {
        if (_inFlightByKey[key] == task) {
          _inFlightByKey.remove(key);
        }
      }),
    );
  }

  void _publishIfCurrent({
    required int generation,
    required HomeDashboardSnapshot snapshot,
  }) {
    if (generation != _generation ||
        snapshot.date != _selectedDate ||
        _normalizeAccountId(snapshot.accountId) != _accountId) {
      return;
    }
    if (_snapshot?.fingerprint == snapshot.fingerprint) {
      return;
    }
    _snapshot = snapshot;
    _error = null;
    notifyListeners();
  }

  HomeDashboardSnapshot _snapshotFromEntry({
    required DailySummaryEntry entry,
    required UserProfile? profile,
    required String source,
  }) {
    return _snapshotFromSummary(
      accountId: entry.accountId,
      summary: entry.summary,
      profile: profile,
      source: source,
      cachedAt: entry.cachedAt,
    );
  }

  HomeDashboardSnapshot _snapshotFromSummary({
    required String? accountId,
    required DailySummary summary,
    required UserProfile? profile,
    required String source,
    DateTime? cachedAt,
  }) {
    return HomeDashboardSnapshot(
      accountId: accountId,
      date: summary.date,
      summary: summary,
      profile: profile,
      fingerprint: _fingerprintFor(summary: summary, profile: profile),
      source: source,
      cachedAt: cachedAt,
    );
  }

  String _fingerprintFor({
    required DailySummary summary,
    required UserProfile? profile,
  }) {
    return jsonEncode(<String, Object?>{
      'summary': summary.toCacheMap(),
      'profile': profile?.toMap(),
    });
  }

  bool _isInFailureBackoff(String key) {
    final failedAt = _failedAtByKey[key];
    return failedAt != null && _now().difference(failedAt) < failureBackoff;
  }

  String _keyFor({required String? accountId, required String day}) {
    return '${accountId ?? 'local'}|$day';
  }

  String? _normalizeAccountId(String? accountId) {
    return accountId == null || accountId.isEmpty ? null : accountId;
  }
}
