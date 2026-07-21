import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'food_image_picker.dart';

class PhotoFoodAnalysisRecoveryDraft {
  const PhotoFoodAnalysisRecoveryDraft({
    required this.initialDate,
    required this.note,
    required this.selectedImageIndex,
    required this.images,
  });

  final String? initialDate;
  final String note;
  final int selectedImageIndex;
  final List<PhotoFoodAnalysisRecoveryImage> images;
}

class PhotoFoodAnalysisRecoveryImage {
  const PhotoFoodAnalysisRecoveryImage({
    required this.path,
    required this.mimeType,
    required this.name,
  });

  final String path;
  final String mimeType;
  final String name;

  Map<String, Object?> toJson() {
    return <String, Object?>{'path': path, 'mimeType': mimeType, 'name': name};
  }

  static PhotoFoodAnalysisRecoveryImage? fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }
    final path = value['path'];
    final mimeType = value['mimeType'];
    final name = value['name'];
    if (path is! String || mimeType is! String || name is! String) {
      return null;
    }
    return PhotoFoodAnalysisRecoveryImage(
      path: path,
      mimeType: mimeType,
      name: name,
    );
  }
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
  static const String _selectedImageIndexKey =
      'fitlog.photo_food_analysis.selected_image_index';
  static const String _imagesKey = 'fitlog.photo_food_analysis.images';
  static const String _directoryName = 'photo_food_analysis_recovery';

  static Directory? debugDirectoryOverride;
  static Future<List<PickedFoodImage>> Function(
    PhotoFoodAnalysisRecoveryDraft draft,
  )?
  debugLoadImagesOverride;
  static bool debugSkipImageWrites = false;

  static Future<void> savePending({
    required String? initialDate,
    required String note,
    required List<PickedFoodImage> images,
    required int selectedImageIndex,
  }) async {
    await _clearPendingMetadata();
    final persistedImages = <PhotoFoodAnalysisRecoveryImage>[];
    if (images.isNotEmpty && !debugSkipImageWrites) {
      final directory = await _recoveryDirectory();
      await directory.create(recursive: true);
      for (var index = 0; index < images.length; index += 1) {
        final image = images[index];
        final file = File(
          p.join(directory.path, 'image_$index${_extensionFor(image)}'),
        );
        await file.writeAsBytes(image.bytes, flush: true);
        persistedImages.add(
          PhotoFoodAnalysisRecoveryImage(
            path: file.path,
            mimeType: image.mimeType,
            name: image.name,
          ),
        );
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKey, true);
    if ((initialDate ?? '').trim().isEmpty) {
      await prefs.remove(_initialDateKey);
    } else {
      await prefs.setString(_initialDateKey, initialDate!.trim());
    }
    await prefs.setString(_noteKey, note);
    await prefs.setInt(_selectedImageIndexKey, selectedImageIndex);
    await prefs.setString(
      _imagesKey,
      jsonEncode(
        persistedImages.map((image) => image.toJson()).toList(growable: false),
      ),
    );
  }

  static Future<PhotoFoodAnalysisRecoveryDraft?> loadPending() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_pendingKey) != true) {
      return null;
    }
    final images = <PhotoFoodAnalysisRecoveryImage>[];
    try {
      final decoded = jsonDecode(prefs.getString(_imagesKey) ?? '[]');
      if (decoded is List<Object?>) {
        for (final value in decoded) {
          final image = PhotoFoodAnalysisRecoveryImage.fromJson(value);
          if (image != null) {
            images.add(image);
          }
        }
      }
    } catch (_) {
      // Stale or corrupt image metadata should not block text-only recovery.
    }
    return PhotoFoodAnalysisRecoveryDraft(
      initialDate: prefs.getString(_initialDateKey),
      note: prefs.getString(_noteKey) ?? '',
      selectedImageIndex: prefs.getInt(_selectedImageIndexKey) ?? 0,
      images: List<PhotoFoodAnalysisRecoveryImage>.unmodifiable(images),
    );
  }

  static Future<List<PickedFoodImage>> loadPendingImages(
    PhotoFoodAnalysisRecoveryDraft draft,
  ) async {
    final override = debugLoadImagesOverride;
    if (override != null) {
      return override(draft);
    }
    final images = <PickedFoodImage>[];
    for (final persistedImage in draft.images) {
      try {
        final file = File(persistedImage.path);
        if (!await file.exists()) {
          continue;
        }
        images.add(
          PickedFoodImage(
            bytes: await file.readAsBytes(),
            mimeType: persistedImage.mimeType,
            name: persistedImage.name,
          ),
        );
      } catch (_) {
        // A missing or unreadable temporary image should not block recovery.
      }
    }
    return List<PickedFoodImage>.unmodifiable(images);
  }

  static Future<void> clearPending({bool deleteImages = true}) async {
    await _clearPendingMetadata();
    if (deleteImages) {
      await clearRecoveryImages();
    }
  }

  static Future<void> clearRecoveryImages() async {
    await _deleteRecoveryDirectory();
  }

  static Future<void> _clearPendingMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
    await prefs.remove(_initialDateKey);
    await prefs.remove(_noteKey);
    await prefs.remove(_selectedImageIndexKey);
    await prefs.remove(_imagesKey);
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
      if (await directory.exists()) {
        if (override == null) {
          await directory.delete(recursive: true);
        } else {
          await for (final entity in directory.list()) {
            await entity.delete(recursive: true);
          }
        }
      }
    } catch (_) {
      // Recovery cleanup is best effort; stale files are overwritten next time.
    }
  }

  static String _extensionFor(PickedFoodImage image) {
    final lowerName = image.name.toLowerCase();
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return '.jpg';
    }
    if (lowerName.endsWith('.png')) {
      return '.png';
    }
    if (lowerName.endsWith('.webp')) {
      return '.webp';
    }
    switch (image.mimeType) {
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/webp':
        return '.webp';
    }
    return '.img';
  }
}
