import 'package:sqflite/sqflite.dart';

import '../../core/utils/date_utils.dart';
import '../../domain/models/workout_session.dart';
import '../../domain/models/workout_set.dart';
import '../db/app_database.dart';

class WorkoutRepository {
  WorkoutRepository(this._database);

  final AppDatabase _database;

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
        where: 'plan_id = ?',
        whereArgs: <Object?>[planId],
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
        where: 'id = ?',
        whereArgs: <Object?>[sessionId],
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
      where: 'id = ?',
      whereArgs: <Object?>[session.id],
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
        payload.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: <Object?>[session.id],
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
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> deleteWorkoutPlan(String planId) async {
    final db = await _database.database;
    await db.delete(
      'workout_sessions',
      where: 'plan_id = ?',
      whereArgs: <Object?>[planId],
    );
  }

  Future<List<WorkoutSession>> getAllWorkoutSessions() async {
    final db = await _database.database;
    final rows = await db.query(
      'workout_sessions',
      orderBy: 'date DESC, created_at DESC',
    );

    return _sessionsFromRows(rows);
  }

  Future<List<WorkoutSession>> getWorkoutSessionsByDate(String day) async {
    final db = await _database.database;
    final rows = await db.query(
      'workout_sessions',
      where: 'date = ?',
      whereArgs: <Object?>[day],
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
      where: 'date >= ? AND date <= ?',
      whereArgs: <Object?>[startDate, endDate],
      orderBy: 'date ASC, created_at ASC',
    );

    return _sessionsFromRows(rows);
  }

  Future<WorkoutSession?> getWorkoutSessionById(int id) async {
    final db = await _database.database;
    final rows = await db.query(
      'workout_sessions',
      where: 'id = ?',
      whereArgs: <Object?>[id],
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
      where: 'exercise_name = ?',
      whereArgs: <Object?>[exerciseName],
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
      where: 'plan_id = ?',
      whereArgs: <Object?>[planId],
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
      'SELECT DISTINCT date FROM workout_sessions ORDER BY date DESC',
    );
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

  Future<int> _insertSessionWithSets(
    DatabaseExecutor executor,
    WorkoutSession session,
  ) async {
    final sessionId = await executor.insert(
      'workout_sessions',
      session.toMap()..remove('id'),
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
}
