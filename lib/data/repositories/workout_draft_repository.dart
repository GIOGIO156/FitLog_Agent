import 'package:sqflite/sqflite.dart';

import '../../domain/models/workout_record_draft.dart';
import '../db/app_database.dart';

class WorkoutDraftRepository {
  WorkoutDraftRepository(this._database);

  final AppDatabase _database;

  Future<WorkoutRecordDraft?> getActiveDraft() async {
    final db = await _database.database;
    final rows = await db.query(
      'workout_record_drafts',
      where: 'id = ? AND kind = ?',
      whereArgs: <Object?>[
        WorkoutRecordDraft.activeDraftId,
        WorkoutRecordDraft.kindNewRecord,
      ],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return WorkoutRecordDraft.fromMap(rows.first);
  }

  Future<void> saveActiveDraft(WorkoutRecordDraft draft) async {
    if (!draft.isNewRecordDraft) {
      throw ArgumentError.value(
        draft.kind,
        'draft.kind',
        'Only new workout records can be retained as active drafts.',
      );
    }
    final db = await _database.database;
    final map = draft.toMap()..['id'] = WorkoutRecordDraft.activeDraftId;
    await db.insert(
      'workout_record_drafts',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteActiveDraft() async {
    final db = await _database.database;
    await db.delete(
      'workout_record_drafts',
      where: 'id = ?',
      whereArgs: <Object?>[WorkoutRecordDraft.activeDraftId],
    );
  }
}
