import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PhotoFoodAnalysisLegacyRecoveryCleanup {
  const PhotoFoodAnalysisLegacyRecoveryCleanup._();

  static const String _pendingKey = 'fitlog.photo_food_analysis.pending';
  static const String _initialDateKey =
      'fitlog.photo_food_analysis.initial_date';
  static const String _noteKey = 'fitlog.photo_food_analysis.note';
  static const String _selectedImageIndexKey =
      'fitlog.photo_food_analysis.selected_image_index';
  static const String _imagesKey = 'fitlog.photo_food_analysis.images';
  static const String _purposeKey = 'fitlog.photo_food_analysis.purpose';
  static const String _directoryName = 'photo_food_analysis_recovery';

  static Directory? debugDirectoryOverride;

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
    await prefs.remove(_initialDateKey);
    await prefs.remove(_noteKey);
    await prefs.remove(_selectedImageIndexKey);
    await prefs.remove(_imagesKey);
    await prefs.remove(_purposeKey);
    await _deleteRecoveryDirectory();
  }

  static Future<Directory> _recoveryDirectory() async {
    final override = debugDirectoryOverride;
    if (override != null) {
      return override;
    }
    final supportDirectory = await getApplicationSupportDirectory();
    return Directory(p.join(supportDirectory.path, _directoryName));
  }

  static Future<void> _deleteRecoveryDirectory() async {
    try {
      final override = debugDirectoryOverride;
      final directory = override ?? await _recoveryDirectory();
      if (!await directory.exists()) {
        return;
      }
      if (override == null) {
        await directory.delete(recursive: true);
        return;
      }
      await for (final entity in directory.list()) {
        await entity.delete(recursive: true);
      }
    } catch (_) {
      // Cleanup is best-effort; stale legacy files are harmless.
    }
  }
}
