import 'package:sqflite/sqflite.dart';
import 'package:supabase/supabase.dart' as supabase;

import '../../core/utils/date_utils.dart';
import '../../domain/models/food_item.dart';
import '../../domain/models/food_record.dart';
import '../../domain/models/cloud_runtime_context.dart';
import 'active_device_repository.dart';
import 'phase2_repository_exception.dart';
import '../db/app_database.dart';

class FoodRepository {
  FoodRepository(this._database);

  final AppDatabase _database;
  String? _activeAccountId;

  void setActiveAccountId(String? accountId) {
    _activeAccountId = accountId == null || accountId.isEmpty
        ? null
        : accountId;
  }

  Future<int> insertFoodRecord(FoodRecord record) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();

    return db.transaction((txn) async {
      final int recordId = await txn.insert(
        'food_records',
        _recordToLocalMap(record.copyWith(createdAt: now, updatedAt: now))
          ..remove('id'),
      );

      await _insertItems(txn, foodRecordId: recordId, items: record.items);

      return recordId;
    });
  }

  Future<void> updateFoodRecord(FoodRecord record) async {
    if (record.id == null) {
      throw ArgumentError('Food record id is required for update.');
    }

    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    final existingRows = await db.query(
      'food_records',
      columns: <String>['created_at'],
      where: _withAccountWhere('id = ?'),
      whereArgs: _withAccountArgs(<Object?>[record.id]),
      limit: 1,
    );

    if (existingRows.isEmpty) {
      throw StateError('Food record not found: id=${record.id}');
    }

    final existingCreatedAt =
        existingRows.first['created_at']?.toString() ?? now;
    final payload = record.copyWith(
      createdAt: existingCreatedAt,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      await txn.update(
        'food_records',
        _recordToLocalMap(payload)..remove('id'),
        where: _withAccountWhere('id = ?'),
        whereArgs: _withAccountArgs(<Object?>[record.id]),
      );

      await txn.delete(
        'food_items',
        where: 'food_record_id = ?',
        whereArgs: <Object?>[record.id],
      );

      await _insertItems(txn, foodRecordId: record.id!, items: record.items);
    });
  }

  Future<void> deleteFoodRecord(int id) async {
    final db = await _database.database;
    await db.delete(
      'food_records',
      where: _withAccountWhere('id = ?'),
      whereArgs: _withAccountArgs(<Object?>[id]),
    );
  }

  Future<FoodRecord?> getFoodRecordById(int id) async {
    final db = await _database.database;
    final rows = await db.query(
      'food_records',
      where: _withAccountWhere('id = ?'),
      whereArgs: _withAccountArgs(<Object?>[id]),
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return _recordFromRow(rows.first);
  }

  Future<List<FoodRecord>> getAllFoodRecords() async {
    final db = await _database.database;
    final rows = await db.query(
      'food_records',
      where: _accountWhere,
      whereArgs: _accountArgs,
      orderBy: 'date DESC, created_at DESC',
    );

    return _recordsFromRows(rows);
  }

  Future<List<FoodRecord>> getFoodRecordsByDate(String day) async {
    final db = await _database.database;
    final rows = await db.query(
      'food_records',
      where: _withAccountWhere('date = ?'),
      whereArgs: _withAccountArgs(<Object?>[day]),
      orderBy: 'created_at DESC',
    );

    return _recordsFromRows(rows);
  }

  Future<List<FoodItem>> getFoodItemsByRecordId(int foodRecordId) async {
    final db = await _database.database;
    final rows = await db.query(
      'food_items',
      where: 'food_record_id = ?',
      whereArgs: <Object?>[foodRecordId],
      orderBy: 'id ASC',
    );

    return rows.map(FoodItem.fromMap).toList();
  }

  Future<double> getCaloriesInByDate(String day) async {
    final records = await getFoodRecordsByDate(day);
    return records.fold<double>(0, (sum, item) => sum + item.caloriesKcal);
  }

  Future<Map<String, double>> getDailyCaloriesBetween({
    required String startDate,
    required String endDate,
  }) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT date, SUM(calories_kcal) AS total
      FROM food_records
      WHERE date >= ? AND date <= ?
        AND deleted_at IS NULL
        ${_activeAccountId == null ? 'AND account_id IS NULL' : 'AND account_id = ?'}
      GROUP BY date
      ORDER BY date ASC
      ''',
      _activeAccountId == null
          ? <Object?>[startDate, endDate]
          : <Object?>[startDate, endDate, _activeAccountId],
    );

    final result = <String, double>{};
    for (final row in rows) {
      final key = row['date']?.toString() ?? '';
      if (key.isEmpty) {
        continue;
      }
      result[key] = (row['total'] as num?)?.toDouble() ?? 0;
    }
    return result;
  }

  Future<List<String>> getDistinctDates() async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT date FROM food_records
      WHERE deleted_at IS NULL
        ${_activeAccountId == null ? 'AND account_id IS NULL' : 'AND account_id = ?'}
      ORDER BY date DESC
      ''', _activeAccountId == null ? null : <Object?>[_activeAccountId]);
    return rows.map((row) => row['date'].toString()).toList();
  }

  Future<List<FoodRecord>> getTodayFoodRecords() async {
    return getFoodRecordsByDate(DateUtilsX.todayKey());
  }

  Future<List<FoodRecord>> _recordsFromRows(
    List<Map<String, Object?>> rows,
  ) async {
    final records = <FoodRecord>[];
    for (final row in rows) {
      records.add(await _recordFromRow(row));
    }
    return records;
  }

  Future<FoodRecord> _recordFromRow(Map<String, Object?> row) async {
    final int id = row['id'] as int;
    final items = await getFoodItemsByRecordId(id);
    return FoodRecord.fromMap(row, items: items);
  }

  Future<int?> localFoodRecordIdForCloudId(String cloudId) async {
    final db = await _database.database;
    final rows = await db.query(
      'food_records',
      columns: <String>['id'],
      where: _withAccountWhere('cloud_id = ?'),
      whereArgs: _withAccountArgs(<Object?>[cloudId]),
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['id'] as int?;
  }

  Future<String?> cloudIdForFoodRecord(int id) async {
    final db = await _database.database;
    final rows = await db.query(
      'food_records',
      columns: <String>['cloud_id'],
      where: _withAccountWhere('id = ?'),
      whereArgs: _withAccountArgs(<Object?>[id]),
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['cloud_id']?.toString();
  }

  Future<int> cacheConfirmedFoodRecord(
    FoodRecord record, {
    required String accountId,
    required String cloudId,
    required int recordVersion,
    required String cloudUpdatedAt,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    final existingId = await localFoodRecordIdForCloudId(cloudId);
    final payload = _recordToLocalMap(
      record.copyWith(
        id: existingId ?? record.id,
        createdAt: record.createdAt ?? now,
        updatedAt: record.updatedAt ?? cloudUpdatedAt,
      ),
      accountId: accountId,
      cloudId: cloudId,
      recordVersion: recordVersion,
      cloudUpdatedAt: cloudUpdatedAt,
      cachedAt: now,
    );

    return db.transaction((txn) async {
      final int localId;
      if (existingId == null) {
        localId = await txn.insert(
          'food_records',
          Map<String, dynamic>.from(payload)..remove('id'),
        );
      } else {
        localId = existingId;
        await txn.update(
          'food_records',
          Map<String, dynamic>.from(payload)..remove('id'),
          where: 'id = ?',
          whereArgs: <Object?>[existingId],
        );
        await txn.delete(
          'food_items',
          where: 'food_record_id = ?',
          whereArgs: <Object?>[existingId],
        );
      }
      await _insertItems(txn, foodRecordId: localId, items: record.items);
      return localId;
    });
  }

  Future<void> _insertItems(
    DatabaseExecutor executor, {
    required int foodRecordId,
    required List<FoodItem> items,
  }) async {
    for (final item in items) {
      await executor.insert(
        'food_items',
        item.copyWith(foodRecordId: foodRecordId).toMap()..remove('id'),
      );
    }
  }

  String get _accountWhere {
    final accountId = _activeAccountId;
    return accountId == null
        ? 'account_id IS NULL AND deleted_at IS NULL'
        : 'account_id = ? AND deleted_at IS NULL';
  }

  List<Object?>? get _accountArgs {
    final accountId = _activeAccountId;
    return accountId == null ? null : <Object?>[accountId];
  }

  String _withAccountWhere(String base) => '$base AND $_accountWhere';

  List<Object?> _withAccountArgs(List<Object?> args) {
    final accountId = _activeAccountId;
    if (accountId == null) {
      return args;
    }
    return <Object?>[...args, accountId];
  }

  Map<String, dynamic> _recordToLocalMap(
    FoodRecord record, {
    String? accountId,
    String? cloudId,
    int recordVersion = 0,
    String? cloudUpdatedAt,
    String? cachedAt,
  }) {
    return record.toMap()..addAll(<String, dynamic>{
      'account_id': accountId ?? _activeAccountId,
      'cloud_id': cloudId,
      'record_version': recordVersion,
      'cloud_updated_at': cloudUpdatedAt,
      'deleted_at': null,
      'cache_confirmed': 1,
      'cached_at': cachedAt,
    });
  }
}

class CloudBackedFoodRepository extends FoodRepository {
  CloudBackedFoodRepository({
    required AppDatabase database,
    required this.client,
    required this.runtimeContext,
    required this.activeDeviceRepository,
  }) : super(database);

  final supabase.SupabaseClient client;
  final CloudRuntimeContext runtimeContext;
  final ActiveDeviceRepository activeDeviceRepository;

  @override
  Future<int> insertFoodRecord(FoodRecord record) async {
    final accountId = _requireAccountId();
    await activeDeviceRepository.assertActive();
    final row = await _insertCloudFoodRecord(record);
    final cloudRecord = _foodRecordFromCloudRow(row);
    setActiveAccountId(accountId);
    return cacheConfirmedFoodRecord(
      cloudRecord,
      accountId: accountId,
      cloudId: row['id'].toString(),
      recordVersion: _recordVersion(row),
      cloudUpdatedAt: _updatedAt(row),
    );
  }

  @override
  Future<void> updateFoodRecord(FoodRecord record) async {
    final accountId = _requireAccountId();
    final localId = record.id;
    if (localId == null) {
      throw ArgumentError('Food record id is required for update.');
    }
    setActiveAccountId(accountId);
    final cloudId = await cloudIdForFoodRecord(localId);
    if ((cloudId ?? '').isEmpty) {
      throw const Phase2RepositoryException('cloud_record_missing');
    }
    await activeDeviceRepository.assertActive();
    final row = await _updateCloudFoodRecord(cloudId!, record);
    final cloudRecord = _foodRecordFromCloudRow(row).copyWith(id: localId);
    await cacheConfirmedFoodRecord(
      cloudRecord,
      accountId: accountId,
      cloudId: cloudId,
      recordVersion: _recordVersion(row),
      cloudUpdatedAt: _updatedAt(row),
    );
  }

  @override
  Future<void> deleteFoodRecord(int id) async {
    final accountId = _requireAccountId();
    setActiveAccountId(accountId);
    final cloudId = await cloudIdForFoodRecord(id);
    if ((cloudId ?? '').isEmpty) {
      throw const Phase2RepositoryException('cloud_record_missing');
    }
    await activeDeviceRepository.assertActive();
    final deletedAt = DateTime.now().toUtc().toIso8601String();
    try {
      await client
          .from('food_records')
          .update(<String, dynamic>{'deleted_at': deletedAt})
          .eq('id', cloudId!);
    } catch (error) {
      throw _cloudRecordExceptionFor('food_delete_failed', error);
    }
    await super.deleteFoodRecord(id);
  }

  @override
  Future<List<FoodRecord>> getFoodRecordsByDate(String day) async {
    final accountId = runtimeContext.accountId;
    if ((accountId ?? '').isEmpty) {
      return super.getFoodRecordsByDate(day);
    }
    setActiveAccountId(accountId);
    final cached = await super.getFoodRecordsByDate(day);
    if (cached.isNotEmpty) {
      return cached;
    }
    try {
      await activeDeviceRepository.assertActive();
      final rows = await _fetchCloudFoodRecordsByDate(day);
      for (final row in rows) {
        await cacheConfirmedFoodRecord(
          _foodRecordFromCloudRow(row),
          accountId: accountId!,
          cloudId: row['id'].toString(),
          recordVersion: _recordVersion(row),
          cloudUpdatedAt: _updatedAt(row),
        );
      }
      return super.getFoodRecordsByDate(day);
    } catch (_) {
      return cached;
    }
  }

  @override
  Future<List<FoodRecord>> getAllFoodRecords() async {
    final accountId = runtimeContext.accountId;
    if ((accountId ?? '').isEmpty) {
      return super.getAllFoodRecords();
    }
    setActiveAccountId(accountId);
    try {
      await activeDeviceRepository.assertActive();
      final rows = await _fetchAllCloudFoodRecords();
      for (final row in rows) {
        await cacheConfirmedFoodRecord(
          _foodRecordFromCloudRow(row),
          accountId: accountId!,
          cloudId: row['id'].toString(),
          recordVersion: _recordVersion(row),
          cloudUpdatedAt: _updatedAt(row),
        );
      }
      return super.getAllFoodRecords();
    } on Phase2RepositoryException {
      rethrow;
    } catch (error) {
      throw _cloudRecordExceptionFor('food_export_failed', error);
    }
  }

  @override
  Future<List<String>> getDistinctDates() {
    final accountId = runtimeContext.accountId;
    if ((accountId ?? '').isNotEmpty) {
      setActiveAccountId(accountId);
    }
    return super.getDistinctDates();
  }

  @override
  Future<FoodRecord?> getFoodRecordById(int id) {
    final accountId = runtimeContext.accountId;
    if ((accountId ?? '').isNotEmpty) {
      setActiveAccountId(accountId);
    }
    return super.getFoodRecordById(id);
  }

  Future<Map<String, dynamic>> _insertCloudFoodRecord(FoodRecord record) async {
    try {
      final rows = await client
          .from('food_records')
          .insert(_foodRecordToCloudPayload(record))
          .select()
          .limit(1);
      if (rows.isEmpty) {
        throw const Phase2RepositoryException('food_insert_no_row');
      }
      final row = Map<String, dynamic>.from(rows.first);
      await _replaceCloudFoodItems(row['id'].toString(), record.items);
      return _fetchCloudFoodRecord(row['id'].toString());
    } on Phase2RepositoryException {
      rethrow;
    } catch (error) {
      throw _cloudRecordExceptionFor('food_insert_failed', error);
    }
  }

  Future<Map<String, dynamic>> _updateCloudFoodRecord(
    String cloudId,
    FoodRecord record,
  ) async {
    try {
      final rows = await client
          .from('food_records')
          .update(_foodRecordToCloudPayload(record))
          .eq('id', cloudId)
          .select()
          .limit(1);
      if (rows.isEmpty) {
        throw const Phase2RepositoryException('food_update_no_row');
      }
      await _replaceCloudFoodItems(cloudId, record.items);
      return _fetchCloudFoodRecord(cloudId);
    } on Phase2RepositoryException {
      rethrow;
    } catch (error) {
      throw _cloudRecordExceptionFor('food_update_failed', error);
    }
  }

  Future<Map<String, dynamic>> _fetchCloudFoodRecord(String cloudId) async {
    final rows = await client
        .from('food_records')
        .select('*, food_items(*)')
        .eq('id', cloudId)
        .limit(1);
    if (rows.isEmpty) {
      throw const Phase2RepositoryException('food_fetch_no_row');
    }
    return Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> _fetchCloudFoodRecordsByDate(
    String day,
  ) async {
    final rows = await client
        .from('food_records')
        .select('*, food_items(*)')
        .eq('date', day)
        .filter('deleted_at', 'is', null)
        .order('created_at', ascending: false);
    return rows
        .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchAllCloudFoodRecords() async {
    const pageSize = 500;
    final result = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final rows = await client
          .from('food_records')
          .select('*, food_items(*)')
          .filter('deleted_at', 'is', null)
          .order('date', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + pageSize - 1);
      result.addAll(
        rows.map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row)),
      );
      if (rows.length < pageSize) {
        break;
      }
      offset += pageSize;
    }
    return result;
  }

  Future<void> _replaceCloudFoodItems(
    String cloudRecordId,
    List<FoodItem> items,
  ) async {
    await client
        .from('food_items')
        .delete()
        .eq('food_record_id', cloudRecordId);
    if (items.isEmpty) {
      return;
    }
    await client
        .from('food_items')
        .insert(
          items
              .map(
                (item) => <String, dynamic>{
                  'food_record_id': cloudRecordId,
                  'name': item.name,
                  'estimated_weight_g': item.estimatedWeightG,
                  'calories_kcal': item.caloriesKcal,
                  'protein_g': item.proteinG,
                  'carbs_g': item.carbsG,
                  'fat_g': item.fatG,
                  'notes': item.notes,
                },
              )
              .toList(),
        );
  }

  Map<String, dynamic> _foodRecordToCloudPayload(FoodRecord record) {
    return <String, dynamic>{
      'date': record.date,
      'meal_name': record.mealName,
      'total_weight_g': record.totalWeightG,
      'calories_kcal': record.caloriesKcal,
      'protein_g': record.proteinG,
      'carbs_g': record.carbsG,
      'fat_g': record.fatG,
      'confidence': record.confidence,
      'estimation_notes': record.estimationNotes,
      'source': record.source,
    };
  }

  FoodRecord _foodRecordFromCloudRow(Map<String, dynamic> row) {
    final rawItems = row['food_items'];
    final items = rawItems is List
        ? rawItems.whereType<Map>().map((item) {
            final mapped = Map<String, dynamic>.from(item)
              ..remove('id')
              ..remove('food_record_id');
            return FoodItem.fromMap(mapped);
          }).toList()
        : const <FoodItem>[];
    final recordMap = Map<String, dynamic>.from(row)
      ..remove('id')
      ..remove('food_items');
    return FoodRecord.fromMap(recordMap, items: items);
  }

  String _requireAccountId() {
    final accountId = runtimeContext.accountId;
    if ((accountId ?? '').isEmpty) {
      throw const Phase2RepositoryException('auth_required');
    }
    return accountId!;
  }

  int _recordVersion(Map<String, dynamic> row) {
    final value = row['record_version'];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _updatedAt(Map<String, dynamic> row) {
    return row['updated_at']?.toString() ?? DateTime.now().toIso8601String();
  }

  Phase2RepositoryException _cloudRecordExceptionFor(
    String fallbackCode,
    Object error,
  ) {
    if (error is Phase2RepositoryException) {
      return error;
    }
    final raw = error.toString();
    final normalized = raw.toLowerCase();
    if (normalized.contains('device_replaced') ||
        normalized.contains('not_active_device')) {
      runtimeContext.markDeviceReplaced();
      return Phase2RepositoryException('device_replaced', raw);
    }
    if (normalized.contains('row-level security') ||
        normalized.contains('permission denied') ||
        normalized.contains('401') ||
        normalized.contains('403')) {
      return Phase2RepositoryException('record_rls_denied', raw);
    }
    if (normalized.contains('socket') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('connection') ||
        normalized.contains('timeout') ||
        normalized.contains('network')) {
      return Phase2RepositoryException('record_network_error', raw);
    }
    if (normalized.contains('schema cache') ||
        normalized.contains('column') ||
        normalized.contains('does not exist')) {
      return Phase2RepositoryException('record_schema_mismatch', raw);
    }
    return Phase2RepositoryException(fallbackCode, raw);
  }
}
