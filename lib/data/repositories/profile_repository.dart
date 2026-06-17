import '../../core/utils/date_utils.dart';
import '../../domain/models/calorie_calibration_state.dart';
import '../../domain/models/diet_adjustment_review.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/weight_log.dart';
import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';

class ProfileRepository {
  ProfileRepository(this._database);

  final AppDatabase _database;

  Future<UserProfile?> getProfile() async {
    final db = await _database.database;
    final rows = await db.query(
      'user_profile',
      orderBy: 'updated_at DESC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return UserProfile.fromMap(rows.first);
  }

  Future<void> saveProfile(UserProfile profile) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();

    final UserProfile payload = profile.copyWith(
      id: profile.id ?? 1,
      createdAt: profile.createdAt ?? now,
      updatedAt: now,
    );

    await db.insert(
      'user_profile',
      payload.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final today = DateUtilsX.todayKey();
    await upsertWeightLog(
      date: today,
      weightKg: payload.weightKg,
      source: 'profile_save',
    );
  }

  Future<void> saveMacroSelfCheckFeedback({
    int? trainingFrequencyPerWeek,
    required String lastMacroSelfCheckAt,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    final current = await getProfile() ?? UserProfile.defaults;
    final payload = current.copyWith(
      id: current.id ?? 1,
      trainingFrequencyPerWeek:
          trainingFrequencyPerWeek ?? current.trainingFrequencyPerWeek,
      lastMacroSelfCheckAt: lastMacroSelfCheckAt,
      createdAt: current.createdAt ?? now,
      updatedAt: now,
    );

    await db.insert(
      'user_profile',
      payload.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveCarbTaperReviewDecision({
    required DietAdjustmentReview review,
    required String userDecision,
    required String reviewedAt,
    double? carbTaperCurrentDeltaG,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    final current = await getProfile() ?? UserProfile.defaults;

    await db.transaction((txn) async {
      await txn.update(
        'diet_adjustment_reviews',
        <String, dynamic>{
          'user_decision': userDecision,
          'applied_delta_after_g': carbTaperCurrentDeltaG,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[review.id],
      );

      final updatedProfile = current.copyWith(
        id: current.id ?? 1,
        carbTaperCurrentDeltaG:
            carbTaperCurrentDeltaG ?? current.carbTaperCurrentDeltaG,
        lastCarbTaperReviewAt: reviewedAt,
        createdAt: current.createdAt ?? now,
        updatedAt: now,
      );
      await txn.insert(
        'user_profile',
        updatedProfile.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> clearProfile() async {
    final db = await _database.database;
    await db.delete('user_profile');
  }

  Future<DietAdjustmentReview?> getLatestDietAdjustmentReview({
    String? userDecision,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'diet_adjustment_reviews',
      where: userDecision == null ? null : 'user_decision = ?',
      whereArgs: userDecision == null ? null : <Object?>[userDecision],
      orderBy: 'review_date DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return DietAdjustmentReview.fromMap(rows.first);
  }

  Future<List<DietAdjustmentReview>> getAllDietAdjustmentReviews() async {
    final db = await _database.database;
    final rows = await db.query(
      'diet_adjustment_reviews',
      orderBy: 'review_date DESC, id DESC',
    );
    return rows.map(DietAdjustmentReview.fromMap).toList();
  }

  Future<DietAdjustmentReview> insertDietAdjustmentReview(
    DietAdjustmentReview review,
  ) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    final payload = review.copyWith(
      createdAt: review.createdAt ?? now,
      updatedAt: now,
    );
    final id = await db.insert(
      'diet_adjustment_reviews',
      payload.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return payload.copyWith(id: id);
  }

  Future<void> upsertWeightLog({
    required String date,
    required double weightKg,
    String source = 'manual',
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();

    final rows = await db.query(
      'user_weight_logs',
      columns: <String>['id', 'created_at'],
      where: 'date = ?',
      whereArgs: <Object?>[date],
      limit: 1,
    );

    if (rows.isEmpty) {
      await db.insert('user_weight_logs', <String, dynamic>{
        'date': date,
        'weight_kg': weightKg,
        'source': source,
        'created_at': now,
        'updated_at': now,
      });
      return;
    }

    final existingId = rows.first['id'] as int;
    final existingCreatedAt = rows.first['created_at']?.toString() ?? now;
    await db.update(
      'user_weight_logs',
      <String, dynamic>{
        'date': date,
        'weight_kg': weightKg,
        'source': source,
        'created_at': existingCreatedAt,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: <Object?>[existingId],
    );
  }

  Future<List<WeightLog>> getWeightLogsBetween({
    required String startDate,
    required String endDate,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'user_weight_logs',
      where: 'date >= ? AND date <= ?',
      whereArgs: <Object?>[startDate, endDate],
      orderBy: 'date ASC',
    );
    return rows.map(WeightLog.fromMap).toList();
  }

  Future<CalorieCalibrationState?> getCalorieCalibrationState() async {
    final db = await _database.database;
    final rows = await db.query(
      'calorie_calibration_state',
      where: 'id = ?',
      whereArgs: <Object?>[1],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return CalorieCalibrationState.fromMap(rows.first);
  }

  Future<void> saveCalorieCalibrationState(
    CalorieCalibrationState state,
  ) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    final existing = await getCalorieCalibrationState();
    final payload = state.copyWith(
      id: 1,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await db.insert(
      'calorie_calibration_state',
      payload.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
