import '../../core/utils/date_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/daily_summary_cache_repository.dart';

class CacheMaintenanceService {
  CacheMaintenanceService({
    required AppDatabase database,
    required DailySummaryCacheRepository dailySummaryCacheRepository,
  }) : _database = database,
       _dailySummaryCacheRepository = dailySummaryCacheRepository;

  final AppDatabase _database;
  final DailySummaryCacheRepository _dailySummaryCacheRepository;
  final Map<String, DateTime> _lastPrunedAtByAccount = <String, DateTime>{};

  static const int retainedRecentDays = 30;
  static const Duration _minInterval = Duration(hours: 6);

  Future<void> pruneForAccount(String? accountId) async {
    if ((accountId ?? '').isEmpty) {
      return;
    }

    final now = DateTime.now();
    final last = _lastPrunedAtByAccount[accountId!];
    if (last != null && now.difference(last) < _minInterval) {
      return;
    }
    _lastPrunedAtByAccount[accountId] = now;

    final cutoff = DateUtilsX.formatDate(
      now.subtract(const Duration(days: retainedRecentDays)),
    );
    await _dailySummaryCacheRepository.pruneConfirmedBefore(
      accountId: accountId,
      beforeDate: cutoff,
    );
    await _database.pruneConfirmedCloudCacheForAccount(
      accountId: accountId,
      beforeDate: cutoff,
    );
  }
}
