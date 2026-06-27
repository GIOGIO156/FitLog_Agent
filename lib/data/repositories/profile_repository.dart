import '../../core/utils/date_utils.dart';
import '../../domain/models/calorie_calibration_state.dart';
import '../../domain/models/diet_adjustment_review.dart';
import '../../domain/models/cloud_runtime_context.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/weight_log.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase/supabase.dart' as supabase;

import 'active_device_repository.dart';
import '../db/app_database.dart';
import 'phase2_repository_exception.dart';

class ProfileRepository {
  ProfileRepository(this._database);

  final AppDatabase _database;
  String? _activeAccountId;

  void setActiveAccountId(String? accountId) {
    _activeAccountId = accountId == null || accountId.isEmpty
        ? null
        : accountId;
  }

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

  Future<void> saveProfile(UserProfile profile, {String? accountId}) async {
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
    await _upsertLocalWeightLog(
      accountId: accountId ?? _activeAccountId,
      date: today,
      weightKg: payload.weightKg,
      bodyFatPercent: payload.bodyFatPercent,
      waistCm: payload.waistCm,
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
    String? accountId,
    required String date,
    required double weightKg,
    double? bodyFatPercent,
    double? waistCm,
    String source = 'manual',
  }) async {
    await _upsertLocalWeightLog(
      accountId: accountId,
      date: date,
      weightKg: weightKg,
      bodyFatPercent: bodyFatPercent,
      waistCm: waistCm,
      source: source,
    );
  }

  Future<void> _upsertLocalWeightLog({
    String? accountId,
    required String date,
    required double weightKg,
    double? bodyFatPercent,
    double? waistCm,
    String source = 'manual',
    String? cloudId,
    int recordVersion = 0,
    String? cloudUpdatedAt,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    final effectiveAccountId = accountId ?? _activeAccountId;
    final where = effectiveAccountId == null
        ? 'date = ? AND account_id IS NULL'
        : 'date = ? AND account_id = ?';
    final whereArgs = effectiveAccountId == null
        ? <Object?>[date]
        : <Object?>[date, effectiveAccountId];

    final rows = await db.query(
      'user_weight_logs',
      columns: <String>['id', 'created_at'],
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );

    if (rows.isEmpty) {
      await db.insert('user_weight_logs', <String, dynamic>{
        'account_id': effectiveAccountId,
        'date': date,
        'weight_kg': weightKg,
        'body_fat_percent': bodyFatPercent,
        'waist_cm': waistCm,
        'source': source,
        'cloud_id': cloudId,
        'record_version': recordVersion,
        'cloud_updated_at': cloudUpdatedAt,
        'deleted_at': null,
        'cache_confirmed': 1,
        'cached_at': now,
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
        'account_id': effectiveAccountId,
        'weight_kg': weightKg,
        'body_fat_percent': bodyFatPercent,
        'waist_cm': waistCm,
        'source': source,
        'cloud_id': cloudId,
        'record_version': recordVersion,
        'cloud_updated_at': cloudUpdatedAt,
        'deleted_at': null,
        'cache_confirmed': 1,
        'cached_at': now,
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
    String? accountId,
  }) async {
    final db = await _database.database;
    final effectiveAccountId = accountId ?? _activeAccountId;
    final where = effectiveAccountId == null
        ? 'date >= ? AND date <= ? AND account_id IS NULL AND deleted_at IS NULL'
        : 'date >= ? AND date <= ? AND account_id = ? AND deleted_at IS NULL';
    final whereArgs = effectiveAccountId == null
        ? <Object?>[startDate, endDate]
        : <Object?>[startDate, endDate, effectiveAccountId];
    final rows = await db.query(
      'user_weight_logs',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'date ASC',
    );
    return rows.map(WeightLog.fromMap).toList();
  }

  Future<List<WeightLog>> getAllWeightLogs({String? accountId}) async {
    final db = await _database.database;
    final effectiveAccountId = accountId ?? _activeAccountId;
    final where = effectiveAccountId == null
        ? 'account_id IS NULL AND deleted_at IS NULL'
        : 'account_id = ? AND deleted_at IS NULL';
    final rows = await db.query(
      'user_weight_logs',
      where: where,
      whereArgs: effectiveAccountId == null
          ? null
          : <Object?>[effectiveAccountId],
      orderBy: 'date DESC, updated_at DESC',
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

class CloudBackedProfileRepository extends ProfileRepository {
  CloudBackedProfileRepository({
    required AppDatabase database,
    required this.client,
    required this.runtimeContext,
    required this.activeDeviceRepository,
  }) : super(database);

  final supabase.SupabaseClient client;
  final CloudRuntimeContext runtimeContext;
  final ActiveDeviceRepository activeDeviceRepository;

  @override
  Future<void> upsertWeightLog({
    String? accountId,
    required String date,
    required double weightKg,
    double? bodyFatPercent,
    double? waistCm,
    String source = 'manual',
  }) async {
    final effectiveAccountId = accountId ?? _requireAccountId();
    setActiveAccountId(effectiveAccountId);
    await activeDeviceRepository.assertActive();
    try {
      final rows = await client
          .from('body_metric_logs')
          .upsert(<String, dynamic>{
            'account_id': effectiveAccountId,
            'date': date,
            'weight_kg': weightKg,
            'body_fat_percent': bodyFatPercent,
            'waist_cm': waistCm,
            'source': source,
          }, onConflict: 'account_id,date')
          .select()
          .limit(1);
      if (rows.isEmpty) {
        throw const Phase2RepositoryException('body_metric_save_no_row');
      }
      final row = Map<String, dynamic>.from(rows.first);
      await _upsertLocalWeightLog(
        accountId: effectiveAccountId,
        date: row['date']?.toString() ?? date,
        weightKg: _toDouble(row['weight_kg'], fallback: weightKg),
        bodyFatPercent: _toNullableDouble(row['body_fat_percent']),
        waistCm: _toNullableDouble(row['waist_cm']),
        source: row['source']?.toString() ?? source,
        cloudId: row['id']?.toString(),
        recordVersion: _recordVersion(row),
        cloudUpdatedAt: _updatedAt(row),
      );
    } on Phase2RepositoryException {
      rethrow;
    } catch (error) {
      throw _cloudRecordExceptionFor('body_metric_save_failed', error);
    }
  }

  @override
  Future<List<WeightLog>> getWeightLogsBetween({
    required String startDate,
    required String endDate,
    String? accountId,
  }) async {
    final effectiveAccountId = accountId ?? runtimeContext.accountId;
    if ((effectiveAccountId ?? '').isEmpty) {
      return super.getWeightLogsBetween(
        startDate: startDate,
        endDate: endDate,
        accountId: accountId,
      );
    }
    setActiveAccountId(effectiveAccountId);
    final cached = await super.getWeightLogsBetween(
      startDate: startDate,
      endDate: endDate,
      accountId: effectiveAccountId,
    );
    if (cached.isNotEmpty) {
      return cached;
    }
    try {
      await activeDeviceRepository.assertActive();
      final rows = await client
          .from('body_metric_logs')
          .select()
          .gte('date', startDate)
          .lte('date', endDate)
          .filter('deleted_at', 'is', null)
          .order('date', ascending: true);
      for (final rawRow in rows) {
        await _cacheCloudWeightLogRow(
          accountId: effectiveAccountId!,
          row: Map<String, dynamic>.from(rawRow),
        );
      }
      return super.getWeightLogsBetween(
        startDate: startDate,
        endDate: endDate,
        accountId: effectiveAccountId,
      );
    } catch (_) {
      return cached;
    }
  }

  @override
  Future<List<WeightLog>> getAllWeightLogs({String? accountId}) async {
    final effectiveAccountId = accountId ?? runtimeContext.accountId;
    if ((effectiveAccountId ?? '').isEmpty) {
      return super.getAllWeightLogs(accountId: accountId);
    }
    setActiveAccountId(effectiveAccountId);
    try {
      await activeDeviceRepository.assertActive();
      final rows = await _fetchAllCloudWeightLogs();
      for (final row in rows) {
        await _cacheCloudWeightLogRow(accountId: effectiveAccountId!, row: row);
      }
      return super.getAllWeightLogs(accountId: effectiveAccountId);
    } on Phase2RepositoryException {
      rethrow;
    } catch (error) {
      throw _cloudRecordExceptionFor('body_metric_export_failed', error);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAllCloudWeightLogs() async {
    const pageSize = 500;
    final result = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final rows = await client
          .from('body_metric_logs')
          .select()
          .filter('deleted_at', 'is', null)
          .order('date', ascending: false)
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

  Future<void> _cacheCloudWeightLogRow({
    required String accountId,
    required Map<String, dynamic> row,
  }) async {
    await _upsertLocalWeightLog(
      accountId: accountId,
      date: row['date']?.toString() ?? '',
      weightKg: _toDouble(row['weight_kg']),
      bodyFatPercent: _toNullableDouble(row['body_fat_percent']),
      waistCm: _toNullableDouble(row['waist_cm']),
      source: row['source']?.toString() ?? 'cloud',
      cloudId: row['id']?.toString(),
      recordVersion: _recordVersion(row),
      cloudUpdatedAt: _updatedAt(row),
    );
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

  double _toDouble(Object? value, {double fallback = 0}) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double? _toNullableDouble(Object? value) {
    if (value == null) {
      return null;
    }
    return _toDouble(value);
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
