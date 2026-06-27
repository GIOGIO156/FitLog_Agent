import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String _dbName = 'fitlog_local.db';
  static const int dbVersion = 15;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = path.join(directory.path, _dbName);

    return openDatabase(
      dbPath,
      version: dbVersion,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (Database db, int version) async {
        await _createTables(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE workout_sessions ADD COLUMN plan_id TEXT',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE user_profile ADD COLUMN protein_ratio_percent REAL NOT NULL DEFAULT 30',
          );
          await db.execute(
            'ALTER TABLE user_profile ADD COLUMN carbs_ratio_percent REAL NOT NULL DEFAULT 40',
          );
          await db.execute(
            'ALTER TABLE user_profile ADD COLUMN fat_ratio_percent REAL NOT NULL DEFAULT 30',
          );
        }
        if (oldVersion < 4) {
          await _createWeightAndCalibrationTables(db);
        }
        if (oldVersion < 5) {
          await db.execute(
            "ALTER TABLE user_profile ADD COLUMN diet_calculation_mode TEXT NOT NULL DEFAULT 'energy_ratio'",
          );
          await db.execute(
            'ALTER TABLE user_profile ADD COLUMN training_frequency_per_week INTEGER NOT NULL DEFAULT 3',
          );
          await db.execute(
            'ALTER TABLE user_profile ADD COLUMN macro_self_check_period_days INTEGER NOT NULL DEFAULT 14',
          );
          await db.execute(
            'ALTER TABLE user_profile ADD COLUMN macro_self_check_enabled INTEGER NOT NULL DEFAULT 1',
          );
          await db.execute(
            'ALTER TABLE user_profile ADD COLUMN last_macro_self_check_at TEXT',
          );
        }
        if (oldVersion < 6) {
          await db.execute(
            "ALTER TABLE user_profile ADD COLUMN diet_goal_phase TEXT NOT NULL DEFAULT 'cutting'",
          );
        }
        if (oldVersion < 7) {
          await db.execute(
            "ALTER TABLE user_profile ADD COLUMN diet_plan_strategy TEXT NOT NULL DEFAULT 'none'",
          );
          await db.execute(
            'ALTER TABLE user_profile ADD COLUMN carb_cycle_pattern_json TEXT',
          );
          await db.execute(
            'ALTER TABLE user_profile ADD COLUMN carb_cycle_high_multiplier REAL NOT NULL DEFAULT 1.20',
          );
          await db.execute(
            'ALTER TABLE user_profile ADD COLUMN carb_cycle_medium_multiplier REAL NOT NULL DEFAULT 1.00',
          );
          await db.execute(
            'ALTER TABLE user_profile ADD COLUMN carb_cycle_low_multiplier REAL NOT NULL DEFAULT 0.80',
          );
          await db.execute(
            'ALTER TABLE user_profile ADD COLUMN carb_taper_review_period_days INTEGER NOT NULL DEFAULT 14',
          );
          await db.execute(
            'ALTER TABLE user_profile ADD COLUMN carb_taper_target_loss_pct_per_week REAL NOT NULL DEFAULT 0.50',
          );
          await db.execute(
            'ALTER TABLE user_profile ADD COLUMN carb_taper_step_g REAL NOT NULL DEFAULT 10.0',
          );
          await db.execute(
            'ALTER TABLE user_profile ADD COLUMN carb_taper_current_delta_g REAL NOT NULL DEFAULT 0.0',
          );
          await db.execute(
            'ALTER TABLE user_profile ADD COLUMN last_carb_taper_review_at TEXT',
          );
          await _createDietAdjustmentReviewTable(db);
        }
        if (oldVersion < 8) {
          await db.execute(
            'ALTER TABLE workout_sessions ADD COLUMN record_name TEXT',
          );
        }
        if (oldVersion < 9) {
          await db.execute('ALTER TABLE user_profile ADD COLUMN nickname TEXT');
        }
        if (oldVersion < 10) {
          await _createWorkoutDraftTable(db);
        }
        if (oldVersion < 11) {
          await _createCustomExerciseTable(db);
          await _addWorkoutSnapshotColumns(db);
          await _addWorkoutSetInputColumns(db);
        }
        if (oldVersion < 12) {
          await _addBodyMetricProfileColumns(db);
          await _migrateWeightLogsForBodyMetrics(db);
        }
        if (oldVersion < 13) {
          await _addCloudCacheColumns(db);
          await _createDailySummaryCacheTable(db);
        }
        if (oldVersion < 14) {
          await _addCloudCacheColumns(db);
          await _createDailySummaryCacheTable(db);
        }
        if (oldVersion < 15) {
          await _createDailySummaryCacheTable(db);
          await _ensureDailySummaryCacheColumns(db);
          await _dedupeDailySummaryCache(db);
          await _createDailySummaryCacheIndexes(db);
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY,
        nickname TEXT,
        age INTEGER NOT NULL,
        height_cm REAL NOT NULL,
        weight_kg REAL NOT NULL,
        body_fat_percent REAL,
        waist_cm REAL,
        sex_for_formula TEXT NOT NULL,
        activity_level TEXT NOT NULL,
        daily_energy_goal_type TEXT NOT NULL,
        daily_energy_goal_kcal REAL NOT NULL,
        protein_ratio_percent REAL NOT NULL,
        carbs_ratio_percent REAL NOT NULL,
        fat_ratio_percent REAL NOT NULL,
        diet_goal_phase TEXT NOT NULL DEFAULT 'cutting',
        diet_calculation_mode TEXT NOT NULL DEFAULT 'energy_ratio',
        diet_plan_strategy TEXT NOT NULL DEFAULT 'none',
        carb_cycle_pattern_json TEXT,
        carb_cycle_high_multiplier REAL NOT NULL DEFAULT 1.20,
        carb_cycle_medium_multiplier REAL NOT NULL DEFAULT 1.00,
        carb_cycle_low_multiplier REAL NOT NULL DEFAULT 0.80,
        carb_taper_review_period_days INTEGER NOT NULL DEFAULT 14,
        carb_taper_target_loss_pct_per_week REAL NOT NULL DEFAULT 0.50,
        carb_taper_step_g REAL NOT NULL DEFAULT 10.0,
        carb_taper_current_delta_g REAL NOT NULL DEFAULT 0.0,
        last_carb_taper_review_at TEXT,
        training_frequency_per_week INTEGER NOT NULL DEFAULT 3,
        macro_self_check_period_days INTEGER NOT NULL DEFAULT 14,
        macro_self_check_enabled INTEGER NOT NULL DEFAULT 1,
        last_macro_self_check_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE food_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id TEXT,
        cloud_id TEXT,
        date TEXT NOT NULL,
        meal_name TEXT NOT NULL,
        total_weight_g REAL NOT NULL,
        calories_kcal REAL NOT NULL,
        protein_g REAL NOT NULL,
        carbs_g REAL NOT NULL,
        fat_g REAL NOT NULL,
        confidence REAL,
        estimation_notes TEXT,
        source TEXT NOT NULL,
        record_version INTEGER NOT NULL DEFAULT 0,
        cloud_updated_at TEXT,
        deleted_at TEXT,
        cache_confirmed INTEGER NOT NULL DEFAULT 1,
        cached_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE food_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cloud_id TEXT,
        food_record_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        estimated_weight_g REAL NOT NULL,
        calories_kcal REAL NOT NULL,
        protein_g REAL NOT NULL,
        carbs_g REAL NOT NULL,
        fat_g REAL NOT NULL,
        notes TEXT,
        FOREIGN KEY (food_record_id) REFERENCES food_records (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id TEXT,
        cloud_id TEXT,
        plan_id TEXT,
        record_name TEXT,
        date TEXT NOT NULL,
        body_part TEXT NOT NULL,
        secondary_body_part TEXT,
        exercise_name TEXT NOT NULL,
        exercise_key TEXT,
        exercise_source TEXT,
        exercise_type TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL,
        intensity TEXT NOT NULL,
        strength_profile TEXT,
        load_input_mode TEXT,
        reps_input_mode TEXT,
        set_metric_type TEXT,
        cardio_met REAL,
        cardio_intensity_basis TEXT,
        cardio_active_minutes INTEGER,
        body_weight_kg_at_calculation REAL,
        exercise_snapshot_json TEXT,
        estimated_calories REAL NOT NULL,
        notes TEXT,
        record_version INTEGER NOT NULL DEFAULT 0,
        cloud_updated_at TEXT,
        deleted_at TEXT,
        cache_confirmed INTEGER NOT NULL DEFAULT 1,
        cached_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cloud_id TEXT,
        workout_session_id INTEGER NOT NULL,
        set_number INTEGER NOT NULL,
        weight_kg REAL NOT NULL,
        reps INTEGER NOT NULL,
        input_weight_kg REAL,
        input_reps INTEGER,
        input_duration_seconds INTEGER,
        calculation_load_kg REAL,
        calculation_reps INTEGER,
        load_input_mode TEXT,
        reps_input_mode TEXT,
        set_metric_type TEXT,
        is_completed INTEGER NOT NULL,
        completed_at TEXT,
        FOREIGN KEY (workout_session_id) REFERENCES workout_sessions (id) ON DELETE CASCADE
      )
    ''');

    await _createWeightAndCalibrationTables(db);
    await _createDietAdjustmentReviewTable(db);
    await _createWorkoutDraftTable(db);
    await _createCustomExerciseTable(db);
    await _createDailySummaryCacheTable(db);
  }

  Future<void> _addWorkoutSnapshotColumns(Database db) async {
    await db.execute(
      'ALTER TABLE workout_sessions ADD COLUMN secondary_body_part TEXT',
    );
    await db.execute(
      'ALTER TABLE workout_sessions ADD COLUMN exercise_key TEXT',
    );
    await db.execute(
      'ALTER TABLE workout_sessions ADD COLUMN exercise_source TEXT',
    );
    await db.execute(
      'ALTER TABLE workout_sessions ADD COLUMN strength_profile TEXT',
    );
    await db.execute(
      'ALTER TABLE workout_sessions ADD COLUMN load_input_mode TEXT',
    );
    await db.execute(
      'ALTER TABLE workout_sessions ADD COLUMN reps_input_mode TEXT',
    );
    await db.execute(
      'ALTER TABLE workout_sessions ADD COLUMN set_metric_type TEXT',
    );
    await db.execute('ALTER TABLE workout_sessions ADD COLUMN cardio_met REAL');
    await db.execute(
      'ALTER TABLE workout_sessions ADD COLUMN cardio_intensity_basis TEXT',
    );
    await db.execute(
      'ALTER TABLE workout_sessions ADD COLUMN cardio_active_minutes INTEGER',
    );
    await db.execute(
      'ALTER TABLE workout_sessions ADD COLUMN body_weight_kg_at_calculation REAL',
    );
    await db.execute(
      'ALTER TABLE workout_sessions ADD COLUMN exercise_snapshot_json TEXT',
    );
  }

  Future<void> _addWorkoutSetInputColumns(Database db) async {
    await db.execute(
      'ALTER TABLE workout_sets ADD COLUMN input_weight_kg REAL',
    );
    await db.execute('ALTER TABLE workout_sets ADD COLUMN input_reps INTEGER');
    await db.execute(
      'ALTER TABLE workout_sets ADD COLUMN input_duration_seconds INTEGER',
    );
    await db.execute(
      'ALTER TABLE workout_sets ADD COLUMN calculation_load_kg REAL',
    );
    await db.execute(
      'ALTER TABLE workout_sets ADD COLUMN calculation_reps INTEGER',
    );
    await db.execute(
      'ALTER TABLE workout_sets ADD COLUMN load_input_mode TEXT',
    );
    await db.execute(
      'ALTER TABLE workout_sets ADD COLUMN reps_input_mode TEXT',
    );
    await db.execute(
      'ALTER TABLE workout_sets ADD COLUMN set_metric_type TEXT',
    );
  }

  Future<void> _createWeightAndCalibrationTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_weight_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id TEXT,
        cloud_id TEXT,
        date TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        body_fat_percent REAL,
        waist_cm REAL,
        source TEXT NOT NULL,
        record_version INTEGER NOT NULL DEFAULT 0,
        cloud_updated_at TEXT,
        deleted_at TEXT,
        cache_confirmed INTEGER NOT NULL DEFAULT 1,
        cached_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(account_id, date)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS calorie_calibration_state (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        lifestyle_factor REAL NOT NULL,
        confidence REAL NOT NULL,
        window_days INTEGER NOT NULL,
        valid_days INTEGER NOT NULL,
        last_calibrated_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createDietAdjustmentReviewTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS diet_adjustment_reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        review_date TEXT NOT NULL,
        window_days INTEGER NOT NULL,
        diet_goal_phase TEXT NOT NULL,
        diet_calculation_mode TEXT NOT NULL,
        diet_plan_strategy TEXT NOT NULL,
        start_avg_weight_kg REAL,
        end_avg_weight_kg REAL,
        weight_change_kg REAL,
        loss_rate_pct_per_week REAL,
        target_loss_pct_per_week REAL,
        food_log_coverage REAL,
        active_training_days INTEGER,
        suggested_action TEXT NOT NULL,
        suggested_carb_delta_g REAL NOT NULL DEFAULT 0,
        applied_delta_after_g REAL,
        confidence REAL NOT NULL DEFAULT 0,
        reason_codes_json TEXT,
        user_decision TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _addBodyMetricProfileColumns(Database db) async {
    await db.execute(
      'ALTER TABLE user_profile ADD COLUMN body_fat_percent REAL',
    );
    await db.execute('ALTER TABLE user_profile ADD COLUMN waist_cm REAL');
  }

  Future<void> _migrateWeightLogsForBodyMetrics(Database db) async {
    await db.execute('''
      CREATE TABLE user_weight_logs_body_metrics_migration (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id TEXT,
        cloud_id TEXT,
        date TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        body_fat_percent REAL,
        waist_cm REAL,
        source TEXT NOT NULL,
        record_version INTEGER NOT NULL DEFAULT 0,
        cloud_updated_at TEXT,
        deleted_at TEXT,
        cache_confirmed INTEGER NOT NULL DEFAULT 1,
        cached_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(account_id, date)
      )
    ''');
    await db.execute('''
      INSERT INTO user_weight_logs_body_metrics_migration (
        id,
        account_id,
        cloud_id,
        date,
        weight_kg,
        body_fat_percent,
        waist_cm,
        source,
        record_version,
        cloud_updated_at,
        deleted_at,
        cache_confirmed,
        cached_at,
        created_at,
        updated_at
      )
      SELECT
        id,
        NULL,
        NULL,
        date,
        weight_kg,
        NULL,
        NULL,
        source,
        0,
        NULL,
        NULL,
        1,
        NULL,
        created_at,
        updated_at
      FROM user_weight_logs
    ''');
    await db.execute('DROP TABLE user_weight_logs');
    await db.execute(
      'ALTER TABLE user_weight_logs_body_metrics_migration RENAME TO user_weight_logs',
    );
  }

  Future<void> _createWorkoutDraftTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_record_drafts (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        source_plan_id TEXT,
        source_session_id INTEGER,
        date TEXT NOT NULL,
        record_name TEXT NOT NULL,
        notes TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createCustomExerciseTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise_key TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        exercise_type TEXT NOT NULL,
        body_part TEXT NOT NULL,
        secondary_body_part TEXT,
        strength_structure TEXT,
        strength_profile TEXT,
        load_input_mode TEXT,
        reps_input_mode TEXT,
        set_metric_type TEXT,
        default_cardio_intensity TEXT,
        is_hidden INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createDailySummaryCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_summary_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id TEXT NOT NULL,
        date TEXT NOT NULL,
        summary_json TEXT NOT NULL,
        summary_version INTEGER NOT NULL DEFAULT 0,
        source_updated_at TEXT,
        cloud_updated_at TEXT,
        cache_confirmed INTEGER NOT NULL DEFAULT 1,
        cached_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(account_id, date)
      )
    ''');
    await _ensureDailySummaryCacheColumns(db);
    await _dedupeDailySummaryCache(db);
    await _createDailySummaryCacheIndexes(db);
  }

  Future<void> _ensureDailySummaryCacheColumns(Database db) async {
    await _addColumnIfMissing(db, 'daily_summary_cache', 'account_id TEXT');
    await _addColumnIfMissing(db, 'daily_summary_cache', 'date TEXT');
    await _addColumnIfMissing(db, 'daily_summary_cache', 'summary_json TEXT');
    await _addColumnIfMissing(
      db,
      'daily_summary_cache',
      'summary_version INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'daily_summary_cache',
      'source_updated_at TEXT',
    );
    await _addColumnIfMissing(
      db,
      'daily_summary_cache',
      'cloud_updated_at TEXT',
    );
    await _addColumnIfMissing(
      db,
      'daily_summary_cache',
      'cache_confirmed INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumnIfMissing(db, 'daily_summary_cache', 'cached_at TEXT');
    await _addColumnIfMissing(db, 'daily_summary_cache', 'created_at TEXT');
    await _addColumnIfMissing(db, 'daily_summary_cache', 'updated_at TEXT');
  }

  Future<void> _dedupeDailySummaryCache(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(daily_summary_cache)');
    final names = columns.map((column) => column['name']).toSet();
    if (!names.contains('id') ||
        !names.contains('account_id') ||
        !names.contains('date')) {
      return;
    }
    await db.execute('''
      DELETE FROM daily_summary_cache
      WHERE id NOT IN (
        SELECT MAX(id)
        FROM daily_summary_cache
        GROUP BY account_id, date
      )
    ''');
  }

  Future<void> _createDailySummaryCacheIndexes(Database db) async {
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_daily_summary_cache_account_date ON daily_summary_cache(account_id, date)',
    );
  }

  Future<void> _addCloudCacheColumns(Database db) async {
    await _addColumnIfMissing(db, 'food_records', 'account_id TEXT');
    await _addColumnIfMissing(db, 'food_records', 'cloud_id TEXT');
    await _addColumnIfMissing(
      db,
      'food_records',
      'record_version INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(db, 'food_records', 'cloud_updated_at TEXT');
    await _addColumnIfMissing(db, 'food_records', 'deleted_at TEXT');
    await _addColumnIfMissing(
      db,
      'food_records',
      'cache_confirmed INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumnIfMissing(db, 'food_records', 'cached_at TEXT');
    await _addColumnIfMissing(db, 'food_items', 'cloud_id TEXT');

    await _addColumnIfMissing(db, 'workout_sessions', 'account_id TEXT');
    await _addColumnIfMissing(db, 'workout_sessions', 'cloud_id TEXT');
    await _addColumnIfMissing(
      db,
      'workout_sessions',
      'record_version INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(db, 'workout_sessions', 'cloud_updated_at TEXT');
    await _addColumnIfMissing(db, 'workout_sessions', 'deleted_at TEXT');
    await _addColumnIfMissing(
      db,
      'workout_sessions',
      'cache_confirmed INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumnIfMissing(db, 'workout_sessions', 'cached_at TEXT');
    await _addColumnIfMissing(db, 'workout_sets', 'cloud_id TEXT');

    await _addColumnIfMissing(db, 'user_weight_logs', 'cloud_id TEXT');
    await _addColumnIfMissing(
      db,
      'user_weight_logs',
      'record_version INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(db, 'user_weight_logs', 'cloud_updated_at TEXT');
    await _addColumnIfMissing(db, 'user_weight_logs', 'deleted_at TEXT');
    await _addColumnIfMissing(
      db,
      'user_weight_logs',
      'cache_confirmed INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumnIfMissing(db, 'user_weight_logs', 'cached_at TEXT');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_food_records_account_date ON food_records(account_id, date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_food_records_cloud_id ON food_records(cloud_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_workout_sessions_account_date ON workout_sessions(account_id, date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_workout_sessions_cloud_id ON workout_sessions(cloud_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_weight_logs_account_date ON user_weight_logs(account_id, date)',
    );
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String columnDefinition,
  ) async {
    final columnName = columnDefinition.split(' ').first;
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((column) => column['name'] == columnName);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnDefinition');
    }
  }

  Future<void> clearAllLocalData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('food_items');
      await txn.delete('food_records');
      await txn.delete('workout_sets');
      await txn.delete('workout_sessions');
      await txn.delete('workout_record_drafts');
      await txn.delete('custom_exercises');
      await txn.delete('user_weight_logs');
      await txn.delete('calorie_calibration_state');
      await txn.delete('diet_adjustment_reviews');
      await txn.delete('user_profile');
      await txn.delete('daily_summary_cache');
    });
  }

  Future<void> pruneConfirmedCloudCacheForAccount({
    required String accountId,
    required String beforeDate,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'food_items',
        where: '''
          food_record_id IN (
            SELECT id FROM food_records
            WHERE account_id = ?
              AND date < ?
              AND cache_confirmed = 1
              AND cloud_id IS NOT NULL
          )
        ''',
        whereArgs: <Object?>[accountId, beforeDate],
      );
      await txn.delete(
        'food_records',
        where:
            'account_id = ? AND date < ? AND cache_confirmed = 1 AND cloud_id IS NOT NULL',
        whereArgs: <Object?>[accountId, beforeDate],
      );

      await txn.delete(
        'workout_sets',
        where: '''
          workout_session_id IN (
            SELECT id FROM workout_sessions
            WHERE account_id = ?
              AND date < ?
              AND cache_confirmed = 1
              AND cloud_id IS NOT NULL
          )
        ''',
        whereArgs: <Object?>[accountId, beforeDate],
      );
      await txn.delete(
        'workout_sessions',
        where:
            'account_id = ? AND date < ? AND cache_confirmed = 1 AND cloud_id IS NOT NULL',
        whereArgs: <Object?>[accountId, beforeDate],
      );
      await txn.delete(
        'user_weight_logs',
        where:
            'account_id = ? AND date < ? AND cache_confirmed = 1 AND cloud_id IS NOT NULL',
        whereArgs: <Object?>[accountId, beforeDate],
      );
    });
  }
}
