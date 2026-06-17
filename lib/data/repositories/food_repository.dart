import 'package:sqflite/sqflite.dart';

import '../../core/utils/date_utils.dart';
import '../../domain/models/food_item.dart';
import '../../domain/models/food_record.dart';
import '../db/app_database.dart';

class FoodRepository {
  FoodRepository(this._database);

  final AppDatabase _database;

  Future<int> insertFoodRecord(FoodRecord record) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();

    return db.transaction((txn) async {
      final int recordId = await txn.insert(
        'food_records',
        record.copyWith(createdAt: now, updatedAt: now).toMap()..remove('id'),
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
      where: 'id = ?',
      whereArgs: <Object?>[record.id],
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
        payload.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: <Object?>[record.id],
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
    await db.delete('food_records', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<FoodRecord?> getFoodRecordById(int id) async {
    final db = await _database.database;
    final rows = await db.query(
      'food_records',
      where: 'id = ?',
      whereArgs: <Object?>[id],
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
      orderBy: 'date DESC, created_at DESC',
    );

    return _recordsFromRows(rows);
  }

  Future<List<FoodRecord>> getFoodRecordsByDate(String day) async {
    final db = await _database.database;
    final rows = await db.query(
      'food_records',
      where: 'date = ?',
      whereArgs: <Object?>[day],
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
      GROUP BY date
      ORDER BY date ASC
      ''',
      <Object?>[startDate, endDate],
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
    final rows = await db.rawQuery(
      'SELECT DISTINCT date FROM food_records ORDER BY date DESC',
    );
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
}
