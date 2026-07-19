import 'package:shared_preferences/shared_preferences.dart';

class PhotoFoodAnalysisRecoveryDraft {
  const PhotoFoodAnalysisRecoveryDraft({
    required this.initialDate,
    required this.note,
  });

  final String? initialDate;
  final String note;
}

class PhotoFoodAnalysisRecoveryLease {
  PhotoFoodAnalysisRecoveryLease._(this._coordinator);

  PhotoFoodAnalysisRecoveryCoordinator? _coordinator;

  void release() {
    _coordinator?._releaseOwner();
    _coordinator = null;
  }
}

class PhotoFoodAnalysisRecoveryCoordinator {
  PhotoFoodAnalysisRecoveryCoordinator();

  static final PhotoFoodAnalysisRecoveryCoordinator instance =
      PhotoFoodAnalysisRecoveryCoordinator();

  int _ownerCount = 0;
  bool _rootRecoveryInFlight = false;

  bool get hasActiveOwner => _ownerCount > 0;

  PhotoFoodAnalysisRecoveryLease acquireOwner() {
    _ownerCount++;
    return PhotoFoodAnalysisRecoveryLease._(this);
  }

  Future<bool> runRootRecovery(Future<void> Function() recovery) async {
    if (hasActiveOwner || _rootRecoveryInFlight) {
      return false;
    }
    _rootRecoveryInFlight = true;
    try {
      await recovery();
      return true;
    } finally {
      _rootRecoveryInFlight = false;
    }
  }

  void _releaseOwner() {
    if (_ownerCount > 0) {
      _ownerCount--;
    }
  }
}

class PhotoFoodAnalysisRecoveryStore {
  const PhotoFoodAnalysisRecoveryStore._();

  static const String _pendingKey = 'fitlog.photo_food_analysis.pending';
  static const String _initialDateKey =
      'fitlog.photo_food_analysis.initial_date';
  static const String _noteKey = 'fitlog.photo_food_analysis.note';

  static Future<void> savePending({
    required String? initialDate,
    required String note,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKey, true);
    if ((initialDate ?? '').trim().isEmpty) {
      await prefs.remove(_initialDateKey);
    } else {
      await prefs.setString(_initialDateKey, initialDate!.trim());
    }
    await prefs.setString(_noteKey, note);
  }

  static Future<PhotoFoodAnalysisRecoveryDraft?> loadPending() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_pendingKey) != true) {
      return null;
    }
    return PhotoFoodAnalysisRecoveryDraft(
      initialDate: prefs.getString(_initialDateKey),
      note: prefs.getString(_noteKey) ?? '',
    );
  }

  static Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
    await prefs.remove(_initialDateKey);
    await prefs.remove(_noteKey);
  }
}
