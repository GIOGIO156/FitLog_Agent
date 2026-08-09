import '../../core/utils/date_utils.dart';
import 'daily_summary_service.dart';

class WarmCacheCoordinator {
  WarmCacheCoordinator({required DailySummaryService dailySummaryService})
    : _dailySummaryService = dailySummaryService;

  final DailySummaryService _dailySummaryService;
  final Map<String, DateTime> _lastWarmAtByAccount = <String, DateTime>{};
  bool _running = false;
  String? _activeAccountId;
  int _generation = 0;

  static const int recentWindowDays = 30;
  static const Duration _startupDelay = Duration(milliseconds: 400);
  static const Duration _betweenDaysDelay = Duration(milliseconds: 60);
  static const Duration _minInterval = Duration(minutes: 10);

  void setActiveAccount(String? accountId) {
    final normalized = accountId == null || accountId.isEmpty
        ? null
        : accountId;
    if (normalized == _activeAccountId) {
      return;
    }
    _activeAccountId = normalized;
    _generation++;
  }

  Future<void> warmRecentWindow({required String? accountId}) async {
    if ((accountId ?? '').isEmpty || _running) {
      return;
    }
    final generation = _generation;

    final now = DateTime.now();
    final last = _lastWarmAtByAccount[accountId!];
    if (last != null && now.difference(last) < _minInterval) {
      return;
    }
    _lastWarmAtByAccount[accountId] = now;
    _running = true;

    try {
      await Future<void>.delayed(_startupDelay);
      for (var offset = 0; offset < recentWindowDays; offset++) {
        if (generation != _generation || _activeAccountId != accountId) {
          return;
        }
        final date = DateUtilsX.formatDate(
          now.subtract(Duration(days: offset)),
        );
        try {
          final cached = await _dailySummaryService.getCachedSummaryForDate(
            accountId: accountId,
            day: date,
          );
          if (cached == null) {
            await _dailySummaryService.getSummaryForDateAndCache(
              day: date,
              accountId: accountId,
            );
          }
        } catch (_) {
          // Warm cache is opportunistic and must never disrupt foreground use.
        }
        await Future<void>.delayed(_betweenDaysDelay);
      }
    } finally {
      _running = false;
    }
  }
}
