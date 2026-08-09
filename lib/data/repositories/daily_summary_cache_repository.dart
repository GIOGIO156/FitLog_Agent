import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/models/daily_summary.dart';
import '../db/app_database.dart';

class DailySummaryCacheRepository {
  const DailySummaryCacheRepository(this._database);

  static const int summaryVersion = 1;

  final AppDatabase _database;

  Future<DailySummary?> getCachedSummary({
    required String accountId,
    required String date,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'daily_summary_cache',
      where:
          'account_id = ? AND date = ? AND summary_version = ? AND cache_confirmed = 1',
      whereArgs: <Object?>[accountId, date, summaryVersion],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final rawJson = rows.first['summary_json']?.toString();
    if (rawJson == null || rawJson.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      return null;
    }
    return DailySummary.fromCacheMap(Map<String, dynamic>.from(decoded));
  }

  Future<void> upsertConfirmedSummary({
    required String accountId,
    required DailySummary summary,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('daily_summary_cache', <String, Object?>{
      'account_id': accountId,
      'date': summary.date,
      'summary_json': jsonEncode(summary.toCacheMap()),
      'summary_version': summaryVersion,
      'cache_confirmed': 1,
      'cached_at': now,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> pruneConfirmedBefore({
    required String accountId,
    required String beforeDate,
  }) async {
    final db = await _database.database;
    return db.delete(
      'daily_summary_cache',
      where: 'account_id = ? AND date < ? AND cache_confirmed = 1',
      whereArgs: <Object?>[accountId, beforeDate],
    );
  }
}
