import 'package:sqflite/sqflite.dart';
import 'package:supabase/supabase.dart' as supabase;

import '../../core/utils/date_utils.dart';
import '../../domain/models/cloud_runtime_context.dart';
import '../../domain/models/workout_session.dart';
import '../../domain/models/workout_set.dart';
import 'active_device_repository.dart';
import 'phase2_repository_exception.dart';
import '../db/app_database.dart';

class WorkoutRepository {
  WorkoutRepository(this._database);

  final AppDatabase _database;
  String? _activeAccountId;

  void setActiveAccountId(String? accountId) {
    _activeAccountId = accountId == null || accountId.isEmpty
        ? null
        : accountId;
  }

  Future<int> insertWorkoutSession(WorkoutSession session) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();

    return db.transaction((txn) async {
      return _insertSessionWithSets(
        txn,
        session.copyWith(createdAt: now, updatedAt: now),
      );
    });
  }

  Future<void> insertWorkoutPlan(List<WorkoutSession> sessions) async {
    if (sessions.isEmpty) {
      return;
    }

    final db = await _database.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      for (final session in sessions) {
        await _insertSessionWithSets(
          txn,
          session.copyWith(createdAt: now, updatedAt: now),
        );
      }
    });
  }

  Future<void> replaceWorkoutPlan({
    required String planId,
    required List<WorkoutSession> sessions,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.delete(
        'workout_sessions',
        where: _withAccountWhere('plan_id = ?'),
        whereArgs: _withAccountArgs(<Object?>[planId]),
      );

      for (final session in sessions) {
        await _insertSessionWithSets(
          txn,
          session.copyWith(
            planId: planId,
            createdAt: session.createdAt ?? now,
            updatedAt: now,
          ),
        );
      }
    });
  }

  Future<void> replaceSingleWorkoutRecord({
    required int sessionId,
    required List<WorkoutSession> sessions,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.delete(
        'workout_sessions',
        where: _withAccountWhere('id = ?'),
        whereArgs: _withAccountArgs(<Object?>[sessionId]),
      );

      for (final session in sessions) {
        await _insertSessionWithSets(
          txn,
          session.copyWith(createdAt: now, updatedAt: now),
        );
      }
    });
  }

  Future<void> updateWorkoutSession(WorkoutSession session) async {
    if (session.id == null) {
      throw ArgumentError('Workout session id is required for update.');
    }

    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    final existingRows = await db.query(
      'workout_sessions',
      columns: <String>['created_at'],
      where: _withAccountWhere('id = ?'),
      whereArgs: _withAccountArgs(<Object?>[session.id]),
      limit: 1,
    );

    if (existingRows.isEmpty) {
      throw StateError('Workout session not found: id=${session.id}');
    }

    final existingCreatedAt =
        existingRows.first['created_at']?.toString() ?? now;
    final payload = session.copyWith(
      createdAt: session.createdAt ?? existingCreatedAt,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      await txn.update(
        'workout_sessions',
        _sessionToLocalMap(payload)..remove('id'),
        where: _withAccountWhere('id = ?'),
        whereArgs: _withAccountArgs(<Object?>[session.id]),
      );

      await txn.delete(
        'workout_sets',
        where: 'workout_session_id = ?',
        whereArgs: <Object?>[session.id],
      );

      await _insertSets(txn, workoutSessionId: session.id!, sets: session.sets);
    });
  }

  Future<void> deleteWorkoutSession(int id) async {
    final db = await _database.database;
    await db.delete(
      'workout_sessions',
      where: _withAccountWhere('id = ?'),
      whereArgs: _withAccountArgs(<Object?>[id]),
    );
  }

  Future<void> deleteWorkoutPlan(String planId) async {
    final db = await _database.database;
    await db.delete(
      'workout_sessions',
      where: _withAccountWhere('plan_id = ?'),
      whereArgs: _withAccountArgs(<Object?>[planId]),
    );
  }

  Future<List<WorkoutSession>> getAllWorkoutSessions() async {
    final db = await _database.database;
    final rows = await db.query(
      'workout_sessions',
      where: _accountWhere,
      whereArgs: _accountArgs,
      orderBy: 'date DESC, created_at DESC',
    );

    return _sessionsFromRows(rows);
  }

  Future<List<WorkoutSession>> getWorkoutSessionsByDate(String day) async {
    final db = await _database.database;
    final rows = await db.query(
      'workout_sessions',
      where: _withAccountWhere('date = ?'),
      whereArgs: _withAccountArgs(<Object?>[day]),
      orderBy: 'created_at DESC',
    );

    return _sessionsFromRows(rows);
  }

  Future<List<WorkoutSession>> getWorkoutSessionsBetween({
    required String startDate,
    required String endDate,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'workout_sessions',
      where: _withAccountWhere('date >= ? AND date <= ?'),
      whereArgs: _withAccountArgs(<Object?>[startDate, endDate]),
      orderBy: 'date ASC, created_at ASC',
    );

    return _sessionsFromRows(rows);
  }

  Future<WorkoutSession?> getWorkoutSessionById(int id) async {
    final db = await _database.database;
    final rows = await db.query(
      'workout_sessions',
      where: _withAccountWhere('id = ?'),
      whereArgs: _withAccountArgs(<Object?>[id]),
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return _sessionFromRow(rows.first);
  }

  Future<WorkoutSession?> getLatestSessionByExerciseName(
    String exerciseName,
  ) async {
    final db = await _database.database;
    final rows = await db.query(
      'workout_sessions',
      where: _withAccountWhere('exercise_name = ?'),
      whereArgs: _withAccountArgs(<Object?>[exerciseName]),
      orderBy: 'created_at DESC, id DESC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return _sessionFromRow(rows.first);
  }

  Future<List<WorkoutSession>> getWorkoutSessionsByPlanId(String planId) async {
    final db = await _database.database;
    final rows = await db.query(
      'workout_sessions',
      where: _withAccountWhere('plan_id = ?'),
      whereArgs: _withAccountArgs(<Object?>[planId]),
      orderBy: 'created_at ASC',
    );

    return _sessionsFromRows(rows);
  }

  Future<List<WorkoutSet>> getSetsBySessionId(int sessionId) async {
    final db = await _database.database;
    final rows = await db.query(
      'workout_sets',
      where: 'workout_session_id = ?',
      whereArgs: <Object?>[sessionId],
      orderBy: 'set_number ASC',
    );

    return rows.map(WorkoutSet.fromMap).toList();
  }

  Future<void> completeSet({
    required int setId,
    required bool completed,
  }) async {
    final db = await _database.database;
    final completedAt = completed ? DateTime.now().toIso8601String() : null;
    await db.update(
      'workout_sets',
      <String, dynamic>{
        'is_completed': completed ? 1 : 0,
        'completed_at': completedAt,
      },
      where: 'id = ?',
      whereArgs: <Object?>[setId],
    );
  }

  Future<double> getExerciseCaloriesByDate(String day) async {
    final sessions = await getWorkoutSessionsByDate(day);
    return sessions.fold<double>(
      0,
      (sum, item) => sum + item.estimatedCalories,
    );
  }

  Future<Map<String, double>> getDailyExerciseCaloriesBetween({
    required String startDate,
    required String endDate,
  }) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT date, SUM(estimated_calories) AS total
      FROM workout_sessions
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
      SELECT DISTINCT date FROM workout_sessions
      WHERE deleted_at IS NULL
        ${_activeAccountId == null ? 'AND account_id IS NULL' : 'AND account_id = ?'}
      ORDER BY date DESC
      ''', _activeAccountId == null ? null : <Object?>[_activeAccountId]);
    return rows.map((row) => row['date'].toString()).toList();
  }

  Future<List<WorkoutSession>> getTodayWorkoutSessions() async {
    return getWorkoutSessionsByDate(DateUtilsX.todayKey());
  }

  Future<List<WorkoutSession>> _sessionsFromRows(
    List<Map<String, Object?>> rows,
  ) async {
    final sessions = <WorkoutSession>[];
    for (final row in rows) {
      sessions.add(await _sessionFromRow(row));
    }
    return sessions;
  }

  Future<WorkoutSession> _sessionFromRow(Map<String, Object?> row) async {
    final int id = row['id'] as int;
    final sets = await getSetsBySessionId(id);
    return WorkoutSession.fromMap(row, sets: sets);
  }

  Future<int?> localWorkoutSessionIdForCloudId(String cloudId) async {
    final db = await _database.database;
    final rows = await db.query(
      'workout_sessions',
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

  Future<String?> cloudIdForWorkoutSession(int id) async {
    final db = await _database.database;
    final rows = await db.query(
      'workout_sessions',
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

  Future<int> cacheConfirmedWorkoutSession(
    WorkoutSession session, {
    required String accountId,
    required String cloudId,
    required int recordVersion,
    required String cloudUpdatedAt,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    final existingId = await localWorkoutSessionIdForCloudId(cloudId);
    final payload = _sessionToLocalMap(
      session.copyWith(
        id: existingId ?? session.id,
        createdAt: session.createdAt ?? now,
        updatedAt: session.updatedAt ?? cloudUpdatedAt,
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
          'workout_sessions',
          Map<String, dynamic>.from(payload)..remove('id'),
        );
      } else {
        localId = existingId;
        await txn.update(
          'workout_sessions',
          Map<String, dynamic>.from(payload)..remove('id'),
          where: 'id = ?',
          whereArgs: <Object?>[existingId],
        );
        await txn.delete(
          'workout_sets',
          where: 'workout_session_id = ?',
          whereArgs: <Object?>[existingId],
        );
      }
      await _insertSets(txn, workoutSessionId: localId, sets: session.sets);
      return localId;
    });
  }

  Future<int> _insertSessionWithSets(
    DatabaseExecutor executor,
    WorkoutSession session,
  ) async {
    final sessionId = await executor.insert(
      'workout_sessions',
      _sessionToLocalMap(session)..remove('id'),
    );
    await _insertSets(
      executor,
      workoutSessionId: sessionId,
      sets: session.sets,
    );
    return sessionId;
  }

  Future<void> _insertSets(
    DatabaseExecutor executor, {
    required int workoutSessionId,
    required List<WorkoutSet> sets,
  }) async {
    for (final set in sets) {
      await executor.insert(
        'workout_sets',
        set.copyWith(workoutSessionId: workoutSessionId).toMap()..remove('id'),
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

  Map<String, dynamic> _sessionToLocalMap(
    WorkoutSession session, {
    String? accountId,
    String? cloudId,
    int recordVersion = 0,
    String? cloudUpdatedAt,
    String? cachedAt,
  }) {
    return session.toMap()..addAll(<String, dynamic>{
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

class CloudBackedWorkoutRepository extends WorkoutRepository {
  CloudBackedWorkoutRepository({
    required AppDatabase database,
    required this.client,
    required this.runtimeContext,
    required this.activeDeviceRepository,
  }) : super(database);

  final supabase.SupabaseClient client;
  final CloudRuntimeContext runtimeContext;
  final ActiveDeviceRepository activeDeviceRepository;

  @override
  Future<int> insertWorkoutSession(WorkoutSession session) async {
    final accountId = _requireAccountId();
    await activeDeviceRepository.assertActive();
    final row = await _insertCloudWorkoutSession(session);
    final cloudSession = _workoutSessionFromCloudRow(row);
    setActiveAccountId(accountId);
    return cacheConfirmedWorkoutSession(
      cloudSession,
      accountId: accountId,
      cloudId: row['id'].toString(),
      recordVersion: _recordVersion(row),
      cloudUpdatedAt: _updatedAt(row),
    );
  }

  @override
  Future<void> insertWorkoutPlan(List<WorkoutSession> sessions) async {
    for (final session in sessions) {
      await insertWorkoutSession(session);
    }
  }

  @override
  Future<void> replaceWorkoutPlan({
    required String planId,
    required List<WorkoutSession> sessions,
  }) async {
    final accountId = _requireAccountId();
    setActiveAccountId(accountId);
    await activeDeviceRepository.assertActive();
    final existing = await super.getWorkoutSessionsByPlanId(planId);
    for (final session in existing) {
      final cloudId = session.id == null
          ? null
          : await cloudIdForWorkoutSession(session.id!);
      if ((cloudId ?? '').isNotEmpty) {
        await _softDeleteCloudWorkoutSession(cloudId!);
      }
    }
    await super.deleteWorkoutPlan(planId);
    for (final session in sessions) {
      await insertWorkoutSession(session.copyWith(planId: planId));
    }
  }

  @override
  Future<void> replaceSingleWorkoutRecord({
    required int sessionId,
    required List<WorkoutSession> sessions,
  }) async {
    final accountId = _requireAccountId();
    setActiveAccountId(accountId);
    await activeDeviceRepository.assertActive();
    final cloudId = await cloudIdForWorkoutSession(sessionId);
    if ((cloudId ?? '').isNotEmpty) {
      await _softDeleteCloudWorkoutSession(cloudId!);
    }
    await super.deleteWorkoutSession(sessionId);
    for (final session in sessions) {
      await insertWorkoutSession(session);
    }
  }

  @override
  Future<void> updateWorkoutSession(WorkoutSession session) async {
    final accountId = _requireAccountId();
    final localId = session.id;
    if (localId == null) {
      throw ArgumentError('Workout session id is required for update.');
    }
    setActiveAccountId(accountId);
    final cloudId = await cloudIdForWorkoutSession(localId);
    if ((cloudId ?? '').isEmpty) {
      throw const Phase2RepositoryException('cloud_record_missing');
    }
    await activeDeviceRepository.assertActive();
    final row = await _updateCloudWorkoutSession(cloudId!, session);
    await cacheConfirmedWorkoutSession(
      _workoutSessionFromCloudRow(row).copyWith(id: localId),
      accountId: accountId,
      cloudId: cloudId,
      recordVersion: _recordVersion(row),
      cloudUpdatedAt: _updatedAt(row),
    );
  }

  @override
  Future<void> deleteWorkoutSession(int id) async {
    final accountId = _requireAccountId();
    setActiveAccountId(accountId);
    final cloudId = await cloudIdForWorkoutSession(id);
    if ((cloudId ?? '').isEmpty) {
      throw const Phase2RepositoryException('cloud_record_missing');
    }
    await activeDeviceRepository.assertActive();
    await _softDeleteCloudWorkoutSession(cloudId!);
    await super.deleteWorkoutSession(id);
  }

  @override
  Future<void> deleteWorkoutPlan(String planId) async {
    final accountId = _requireAccountId();
    setActiveAccountId(accountId);
    final sessions = await super.getWorkoutSessionsByPlanId(planId);
    await activeDeviceRepository.assertActive();
    for (final session in sessions) {
      final id = session.id;
      if (id == null) {
        continue;
      }
      final cloudId = await cloudIdForWorkoutSession(id);
      if ((cloudId ?? '').isNotEmpty) {
        await _softDeleteCloudWorkoutSession(cloudId!);
      }
    }
    await super.deleteWorkoutPlan(planId);
  }

  @override
  Future<List<WorkoutSession>> getWorkoutSessionsByDate(String day) async {
    final accountId = runtimeContext.accountId;
    if ((accountId ?? '').isEmpty) {
      return super.getWorkoutSessionsByDate(day);
    }
    setActiveAccountId(accountId);
    final cached = await super.getWorkoutSessionsByDate(day);
    if (cached.isNotEmpty) {
      return cached;
    }
    try {
      await activeDeviceRepository.assertActive();
      final rows = await _fetchCloudWorkoutSessionsByDate(day);
      for (final row in rows) {
        await cacheConfirmedWorkoutSession(
          _workoutSessionFromCloudRow(row),
          accountId: accountId!,
          cloudId: row['id'].toString(),
          recordVersion: _recordVersion(row),
          cloudUpdatedAt: _updatedAt(row),
        );
      }
      return super.getWorkoutSessionsByDate(day);
    } catch (_) {
      return cached;
    }
  }

  @override
  Future<List<WorkoutSession>> getAllWorkoutSessions() async {
    final accountId = runtimeContext.accountId;
    if ((accountId ?? '').isEmpty) {
      return super.getAllWorkoutSessions();
    }
    setActiveAccountId(accountId);
    try {
      await activeDeviceRepository.assertActive();
      final rows = await _fetchAllCloudWorkoutSessions();
      for (final row in rows) {
        await cacheConfirmedWorkoutSession(
          _workoutSessionFromCloudRow(row),
          accountId: accountId!,
          cloudId: row['id'].toString(),
          recordVersion: _recordVersion(row),
          cloudUpdatedAt: _updatedAt(row),
        );
      }
      return super.getAllWorkoutSessions();
    } on Phase2RepositoryException {
      rethrow;
    } catch (error) {
      throw _cloudRecordExceptionFor('workout_export_failed', error);
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
  Future<WorkoutSession?> getWorkoutSessionById(int id) {
    final accountId = runtimeContext.accountId;
    if ((accountId ?? '').isNotEmpty) {
      setActiveAccountId(accountId);
    }
    return super.getWorkoutSessionById(id);
  }

  @override
  Future<List<WorkoutSession>> getWorkoutSessionsByPlanId(String planId) {
    final accountId = runtimeContext.accountId;
    if ((accountId ?? '').isNotEmpty) {
      setActiveAccountId(accountId);
    }
    return super.getWorkoutSessionsByPlanId(planId);
  }

  Future<Map<String, dynamic>> _insertCloudWorkoutSession(
    WorkoutSession session,
  ) async {
    try {
      final rows = await client
          .from('workout_sessions')
          .insert(_workoutSessionToCloudPayload(session))
          .select()
          .limit(1);
      if (rows.isEmpty) {
        throw const Phase2RepositoryException('workout_insert_no_row');
      }
      final row = Map<String, dynamic>.from(rows.first);
      await _replaceCloudWorkoutSets(row['id'].toString(), session.sets);
      return _fetchCloudWorkoutSession(row['id'].toString());
    } on Phase2RepositoryException {
      rethrow;
    } catch (error) {
      throw _cloudRecordExceptionFor('workout_insert_failed', error);
    }
  }

  Future<Map<String, dynamic>> _updateCloudWorkoutSession(
    String cloudId,
    WorkoutSession session,
  ) async {
    try {
      final rows = await client
          .from('workout_sessions')
          .update(_workoutSessionToCloudPayload(session))
          .eq('id', cloudId)
          .select()
          .limit(1);
      if (rows.isEmpty) {
        throw const Phase2RepositoryException('workout_update_no_row');
      }
      await _replaceCloudWorkoutSets(cloudId, session.sets);
      return _fetchCloudWorkoutSession(cloudId);
    } on Phase2RepositoryException {
      rethrow;
    } catch (error) {
      throw _cloudRecordExceptionFor('workout_update_failed', error);
    }
  }

  Future<Map<String, dynamic>> _fetchCloudWorkoutSession(String cloudId) async {
    final rows = await client
        .from('workout_sessions')
        .select('*, workout_sets(*)')
        .eq('id', cloudId)
        .limit(1);
    if (rows.isEmpty) {
      throw const Phase2RepositoryException('workout_fetch_no_row');
    }
    return Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> _fetchCloudWorkoutSessionsByDate(
    String day,
  ) async {
    final rows = await client
        .from('workout_sessions')
        .select('*, workout_sets(*)')
        .eq('date', day)
        .filter('deleted_at', 'is', null)
        .order('created_at', ascending: false);
    return rows
        .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchAllCloudWorkoutSessions() async {
    const pageSize = 500;
    final result = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final rows = await client
          .from('workout_sessions')
          .select('*, workout_sets(*)')
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

  Future<void> _replaceCloudWorkoutSets(
    String cloudSessionId,
    List<WorkoutSet> sets,
  ) async {
    await client
        .from('workout_sets')
        .delete()
        .eq('workout_session_id', cloudSessionId);
    if (sets.isEmpty) {
      return;
    }
    await client
        .from('workout_sets')
        .insert(
          sets
              .map(
                (set) => <String, dynamic>{
                  'workout_session_id': cloudSessionId,
                  'set_number': set.setNumber,
                  'weight_kg': set.weightKg,
                  'reps': set.reps,
                  'input_weight_kg': set.inputWeightKg,
                  'input_reps': set.inputReps,
                  'input_duration_seconds': set.inputDurationSeconds,
                  'calculation_load_kg': set.calculationLoadKg,
                  'calculation_reps': set.calculationReps,
                  'load_input_mode': set.loadInputMode,
                  'reps_input_mode': set.repsInputMode,
                  'set_metric_type': set.setMetricType,
                  'is_completed': set.isCompleted,
                  'completed_at': set.completedAt,
                },
              )
              .toList(),
        );
  }

  Future<void> _softDeleteCloudWorkoutSession(String cloudId) async {
    final deletedAt = DateTime.now().toUtc().toIso8601String();
    try {
      await client
          .from('workout_sessions')
          .update(<String, dynamic>{'deleted_at': deletedAt})
          .eq('id', cloudId);
    } catch (error) {
      throw _cloudRecordExceptionFor('workout_delete_failed', error);
    }
  }

  Map<String, dynamic> _workoutSessionToCloudPayload(WorkoutSession session) {
    return <String, dynamic>{
      'plan_id': session.planId,
      'record_name': session.recordName,
      'date': session.date,
      'body_part': session.bodyPart,
      'secondary_body_part': session.secondaryBodyPart,
      'exercise_name': session.exerciseName,
      'exercise_key': session.exerciseKey,
      'exercise_source': session.exerciseSource,
      'exercise_type': session.exerciseType,
      'duration_minutes': session.durationMinutes,
      'intensity': session.intensity,
      'strength_profile': session.strengthProfile,
      'load_input_mode': session.loadInputMode,
      'reps_input_mode': session.repsInputMode,
      'set_metric_type': session.setMetricType,
      'cardio_met': session.cardioMet,
      'cardio_intensity_basis': session.cardioIntensityBasis,
      'cardio_active_minutes': session.cardioActiveMinutes,
      'body_weight_kg_at_calculation': session.bodyWeightKgAtCalculation,
      'exercise_snapshot_json': session.exerciseSnapshotJson,
      'estimated_calories': session.estimatedCalories,
      'notes': session.notes,
    };
  }

  WorkoutSession _workoutSessionFromCloudRow(Map<String, dynamic> row) {
    final rawSets = row['workout_sets'];
    final sets = rawSets is List
        ? rawSets.whereType<Map>().map((set) {
            final mapped = Map<String, dynamic>.from(set)
              ..remove('id')
              ..remove('workout_session_id');
            final completed = mapped['is_completed'];
            if (completed is bool) {
              mapped['is_completed'] = completed ? 1 : 0;
            }
            return WorkoutSet.fromMap(mapped);
          }).toList()
        : const <WorkoutSet>[];
    final sessionMap = Map<String, dynamic>.from(row)
      ..remove('id')
      ..remove('workout_sets');
    return WorkoutSession.fromMap(sessionMap, sets: sets);
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
