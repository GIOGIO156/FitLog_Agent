import 'dart:convert';

import 'daily_summary.dart';

class DailySummaryEntry {
  const DailySummaryEntry({
    required this.accountId,
    required this.summary,
    required this.summaryVersion,
    required this.cacheConfirmed,
    this.cachedAt,
    this.sourceUpdatedAt,
    this.cloudUpdatedAt,
    this.profileVersion,
    this.algorithmVersion,
    this.recordVersion,
    this.builtAt,
  });

  final String accountId;
  final DailySummary summary;
  final int summaryVersion;
  final bool cacheConfirmed;
  final DateTime? cachedAt;
  final DateTime? sourceUpdatedAt;
  final DateTime? cloudUpdatedAt;
  final int? profileVersion;
  final String? algorithmVersion;
  final int? recordVersion;
  final DateTime? builtAt;

  String get date => summary.date;

  String get payloadFingerprint => jsonEncode(summary.toCacheMap());

  bool isFreshAt(DateTime now, Duration maxAge) {
    final cached = cachedAt;
    return cached != null &&
        !cached.isAfter(now) &&
        now.difference(cached) <= maxAge;
  }
}

DateTime? parseDailySummaryEntryTime(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString())?.toUtc();
}

int parseDailySummaryEntryInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

DailySummaryEntry dailySummaryEntryFromCacheRow(
  Map<String, Object?> row, {
  required DailySummary summary,
}) {
  return DailySummaryEntry(
    accountId: row['account_id']?.toString() ?? '',
    summary: summary,
    summaryVersion: parseDailySummaryEntryInt(
      row['summary_version'],
      fallback: 1,
    ),
    cacheConfirmed: parseDailySummaryEntryInt(row['cache_confirmed']) == 1,
    cachedAt: parseDailySummaryEntryTime(row['cached_at']),
    sourceUpdatedAt: parseDailySummaryEntryTime(row['source_updated_at']),
    cloudUpdatedAt: parseDailySummaryEntryTime(row['cloud_updated_at']),
  );
}
