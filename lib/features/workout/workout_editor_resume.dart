import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/workout_record_draft.dart';

class WorkoutEditorResumeStore {
  const WorkoutEditorResumeStore._();

  static const Duration autoResumeWindow = Duration(minutes: 30);
  static const String _activeKey = 'fitlog.workout_editor.active';

  static Future<void> markActive() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_activeKey, true);
    } catch (_) {
      // Route restoration is optional; the SQLite draft remains authoritative.
    }
  }

  static Future<void> clear() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_activeKey);
    } catch (_) {
      // Failure to clear this hint must not affect workout draft persistence.
    }
  }

  static Future<bool> shouldAutoResume(
    WorkoutRecordDraft? draft, {
    DateTime? now,
  }) async {
    if (draft == null) {
      return false;
    }
    late final SharedPreferences preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      return false;
    }
    if (preferences.getBool(_activeKey) != true) {
      return false;
    }
    final updatedAt = DateTime.tryParse(draft.updatedAt);
    if (updatedAt == null) {
      return false;
    }
    final age = (now ?? DateTime.now()).difference(updatedAt);
    return !age.isNegative && age <= autoResumeWindow;
  }
}
