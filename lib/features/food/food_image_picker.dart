import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

enum FoodImageSource { camera, gallery }

class PickedFoodImage {
  const PickedFoodImage({
    required this.bytes,
    required this.mimeType,
    required this.name,
  });

  final Uint8List bytes;
  final String mimeType;
  final String name;

  int get byteLength => bytes.lengthInBytes;
}

abstract class FoodImagePicker {
  const FoodImagePicker();

  Future<PickedFoodImage?> pick(FoodImageSource source);

  Future<List<PickedFoodImage>> retrieveLostImages({required int limit}) async {
    return const <PickedFoodImage>[];
  }

  Future<List<PickedFoodImage>> pickMultiple(
    FoodImageSource source, {
    required int limit,
  }) async {
    final image = await pick(source);
    return image == null ? const <PickedFoodImage>[] : <PickedFoodImage>[image];
  }
}

class ImagePickerFoodImagePicker extends FoodImagePicker {
  ImagePickerFoodImagePicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedFoodImage?> pick(FoodImageSource source) async {
    final file = await _picker.pickImage(
      source: source == FoodImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 82,
    );
    if (file == null) {
      return null;
    }
    return _pickedImageFromFile(file);
  }

  @override
  Future<List<PickedFoodImage>> pickMultiple(
    FoodImageSource source, {
    required int limit,
  }) async {
    if (source == FoodImageSource.camera || limit <= 1) {
      final image = await pick(source);
      return image == null
          ? const <PickedFoodImage>[]
          : <PickedFoodImage>[image];
    }
    final files = await _picker.pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 82,
      limit: limit,
    );
    final images = <PickedFoodImage>[];
    for (final file in files.take(limit)) {
      images.add(await _pickedImageFromFile(file));
    }
    return List<PickedFoodImage>.unmodifiable(images);
  }

  @override
  Future<List<PickedFoodImage>> retrieveLostImages({required int limit}) async {
    if (limit <= 0) {
      return const <PickedFoodImage>[];
    }
    final response = await _picker.retrieveLostData();
    if (response.isEmpty) {
      return const <PickedFoodImage>[];
    }
    if (response.exception != null) {
      throw response.exception!;
    }
    final files = response.files;
    if (files != null && files.isNotEmpty) {
      final images = <PickedFoodImage>[];
      for (final file in files.take(limit)) {
        images.add(await _pickedImageFromFile(file));
      }
      return List<PickedFoodImage>.unmodifiable(images);
    }
    final file = response.file;
    if (file == null) {
      return const <PickedFoodImage>[];
    }
    return <PickedFoodImage>[await _pickedImageFromFile(file)];
  }

  Future<PickedFoodImage> _pickedImageFromFile(XFile file) async {
    final bytes = await file.readAsBytes();
    return PickedFoodImage(
      bytes: bytes,
      mimeType: file.mimeType ?? _mimeTypeForName(file.name),
      name: file.name,
    );
  }
}

String _mimeTypeForName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  return '';
}
