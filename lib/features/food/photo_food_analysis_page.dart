import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/localization/localization_extensions.dart';
import '../../core/theme/fitlog_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/fitlog_bottom_nav_bar.dart';
import '../../core/widgets/fitlog_notifications.dart';
import '../../core/widgets/fitlog_ui.dart';
import '../../core/widgets/glass_panel.dart';
import '../../data/remote/ai_food_photo_analysis_client.dart';
import '../../domain/models/ai_availability.dart';
import '../../domain/models/ai_food_photo_analysis.dart';
import '../../domain/models/ai_gateway_error.dart';
import '../../domain/models/ai_gateway_request.dart';
import '../../domain/models/cloud_runtime_context.dart';
import '../account/account_controller.dart';
import 'food_image_picker.dart';
import 'food_preview_page.dart';

const int _maxPhotoAnalysisImageBytes = 4 * 1024 * 1024;
const int _maxPhotoAnalysisImages = 3;
const Set<String> _supportedPhotoMimeTypes = <String>{
  'image/jpeg',
  'image/png',
  'image/webp',
};

class PhotoFoodAnalysisPage extends StatefulWidget {
  const PhotoFoodAnalysisPage({
    super.key,
    this.initialDate,
    this.imagePicker,
    this.analysisClient,
  });

  final String? initialDate;
  final FoodImagePicker? imagePicker;
  final AiFoodPhotoAnalysisClient? analysisClient;

  @override
  State<PhotoFoodAnalysisPage> createState() => _PhotoFoodAnalysisPageState();
}

class _PhotoFoodAnalysisPageState extends State<PhotoFoodAnalysisPage> {
  final TextEditingController _noteController = TextEditingController();
  late final FoodImagePicker _imagePicker;
  List<PickedFoodImage> _images = const <PickedFoodImage>[];
  int _selectedImageIndex = 0;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    _imagePicker = widget.imagePicker ?? ImagePickerFoodImagePicker();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(FoodImageSource source) async {
    final strings = context.stringsRead;
    if (_images.length >= _maxPhotoAnalysisImages) {
      _showError(strings.aiImageLimitReached);
      return;
    }
    try {
      final pickedImages = await _imagePicker.pickMultiple(
        source,
        limit: _maxPhotoAnalysisImages - _images.length,
      );
      if (!mounted || pickedImages.isEmpty) {
        return;
      }
      final nextImages = <PickedFoodImage>[
        ..._images,
        ...pickedImages.take(_maxPhotoAnalysisImages - _images.length),
      ];
      setState(() {
        _images = List<PickedFoodImage>.unmodifiable(nextImages);
        _selectedImageIndex = nextImages.length - 1;
      });
      final validationError = _validationErrorForImages(nextImages);
      if (validationError != null) {
        _showError(validationError);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      FitLogNotifications.topError(context, context.strings.photoAiPickFailed);
    }
  }

  void _removeImageAt(int index) {
    if (index < 0 || index >= _images.length) {
      return;
    }
    setState(() {
      final nextImages = <PickedFoodImage>[..._images]..removeAt(index);
      _images = List<PickedFoodImage>.unmodifiable(nextImages);
      if (nextImages.isEmpty) {
        _selectedImageIndex = 0;
      } else {
        _selectedImageIndex = _selectedImageIndex
            .clamp(0, nextImages.length - 1)
            .toInt();
      }
    });
  }

  Future<void> _analyze() async {
    final strings = context.stringsRead;
    final images = _images;
    if (images.isEmpty) {
      _showError(strings.photoAiPickImageFirst);
      return;
    }
    final validationError = _validationErrorForImages(images);
    if (validationError != null) {
      _showError(validationError);
      return;
    }

    final accountController = context.read<AccountController>();
    if (!accountController.aiAvailability.canSend) {
      FitLogNotifications.topError(
        context,
        _aiReadinessLabel(accountController),
      );
      return;
    }
    final deviceId = context.read<CloudRuntimeContext>().deviceId;
    if ((deviceId ?? '').isEmpty) {
      FitLogNotifications.topError(
        context,
        strings.phase2ErrorMessage('device_replaced'),
      );
      return;
    }

    setState(() => _analyzing = true);
    final request = AiFoodPhotoAnalysisRequest(
      images: images
          .map(
            (image) => AiFoodPhotoImagePayload(
              mimeType: image.mimeType,
              base64Data: base64Encode(image.bytes),
              byteLength: image.byteLength,
            ),
          )
          .toList(growable: false),
      language: strings.isChinese ? 'zh' : 'en',
      modelChoice: AiGatewayModelChoice.qwen,
      deviceId: deviceId!,
      selectedDate: widget.initialDate ?? DateUtilsX.todayKey(),
      userNote: _noteController.text,
      client: const <String, dynamic>{
        'platform': 'flutter',
        'app_version': 'phase4',
      },
    );

    final response = await _analysisClient(context).analyze(request);
    if (!mounted) {
      return;
    }
    setState(() => _analyzing = false);
    if (response.error != null) {
      _showError(_aiErrorLabel(response.error!));
      return;
    }
    final draft = response.draft;
    if (draft == null) {
      _showError(
        response.needsClarification
            ? _clarificationText(response.clarificationQuestions)
            : strings.photoAiNoDraft,
      );
      return;
    }

    final record = draft.toFoodRecord(
      date: widget.initialDate ?? DateUtilsX.todayKey(),
      modelProvider: response.modelProvider,
      userNote: _noteController.text,
    );
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FoodPreviewPage(initialRecord: record),
      ),
    );
    if (saved == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  AiFoodPhotoAnalysisClient _analysisClient(BuildContext context) {
    return widget.analysisClient ??
        context.read<AppServices>().aiFoodPhotoAnalysisClient;
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    FitLogNotifications.topError(context, message);
  }

  String? _validationErrorForImages(List<PickedFoodImage> images) {
    final strings = context.stringsRead;
    if (images.length > _maxPhotoAnalysisImages) {
      return strings.aiImageLimitReached;
    }
    for (final image in images) {
      if (!_supportedPhotoMimeTypes.contains(image.mimeType)) {
        return strings.photoAiUnsupportedImage;
      }
      if (image.byteLength > _maxPhotoAnalysisImageBytes) {
        return strings.photoAiImageTooLarge;
      }
    }
    return null;
  }

  String _aiReadinessLabel(AccountController accountController) {
    final strings = context.stringsRead;
    final availability = accountController.aiAvailability;
    switch (availability.status) {
      case AiAvailabilityStatus.signedOut:
        return strings.authRequired;
      case AiAvailabilityStatus.offline:
        return strings.aiOfflineStatus;
      case AiAvailabilityStatus.subscriptionInactive:
        return strings.subscriptionInactive;
      case AiAvailabilityStatus.profileMissing:
        return strings.profileRequired;
      case AiAvailabilityStatus.gatewayPending:
        return strings.aiGatewayPending;
    }
  }

  String _aiErrorLabel(AiGatewayError error) {
    final strings = context.stringsRead;
    switch (error.code) {
      case AiGatewayErrorCode.authRequired:
        return strings.authRequired;
      case AiGatewayErrorCode.subscriptionRequired:
        return strings.subscriptionInactive;
      case AiGatewayErrorCode.deviceReplaced:
        return strings.phase2ErrorMessage('device_replaced');
      case AiGatewayErrorCode.gatewayTimeout:
        return strings.aiGatewayTimeout;
      case AiGatewayErrorCode.providerFailure:
        return strings.aiProviderFailure;
      case AiGatewayErrorCode.recordSchemaMismatch:
        return strings.aiRequestUnsupported;
      case AiGatewayErrorCode.networkFailure:
        return strings.photoAiNetworkFailure;
      case AiGatewayErrorCode.unknown:
        return strings.aiUnknownFailure;
    }
  }

  String _clarificationText(List<String> questions) {
    if (questions.isEmpty) {
      return context.stringsRead.photoAiNeedsClarification;
    }
    return '${context.stringsRead.photoAiNeedsClarification}\n${questions.join('\n')}';
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final canSubmit = _images.isNotEmpty && !_analyzing;
    return Scaffold(
      appBar: AppBar(title: Text(strings.photoAiAnalysis)),
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: <Widget>[
                FitLogPageHeader(
                  title: strings.photoAiAnalysis,
                  subtitle: strings.photoAiHeaderBody,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                ),
                _PhotoPickerPanel(
                  images: _images,
                  selectedIndex: _selectedImageIndex,
                  onCamera: () => _pickImage(FoodImageSource.camera),
                  onGallery: () => _pickImage(FoodImageSource.gallery),
                  onSelect: (index) =>
                      setState(() => _selectedImageIndex = index),
                  onRemove: _removeImageAt,
                ),
                GlassPanel(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  padding: const EdgeInsets.all(14),
                  child: TextField(
                    key: const ValueKey<String>('photo_food_note_field'),
                    controller: _noteController,
                    minLines: 3,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      labelText: strings.photoAiNoteLabel,
                      hintText: strings.photoAiNoteHint,
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_analyzing) const _PhotoFoodLoadingOverlay(),
        ],
      ),
      bottomNavigationBar: _PhotoFoodSubmitBar(
        enabled: canSubmit,
        analyzing: _analyzing,
        onPressed: _analyze,
      ),
    );
  }
}

class _PhotoFoodSubmitBar extends StatelessWidget {
  const _PhotoFoodSubmitBar({
    required this.enabled,
    required this.analyzing,
    required this.onPressed,
  });

  final bool enabled;
  final bool analyzing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final fitTheme = context.fitLogTheme;
    final theme = Theme.of(context);
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final bottomPadding = safeBottom > FitLogBottomNavBar.bottomInset
        ? safeBottom
        : FitLogBottomNavBar.bottomInset;
    final shieldHeight =
        FitLogBottomNavBar.floatingControlHeight / 2 + bottomPadding + 1;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        FitLogBottomNavBar.horizontalInset,
        0,
        FitLogBottomNavBar.horizontalInset,
        FitLogBottomNavBar.bottomInset,
      ),
      child: SizedBox(
        height: FitLogBottomNavBar.floatingControlHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: 0,
              right: 0,
              top: FitLogBottomNavBar.floatingControlHeight / 2,
              height: shieldHeight,
              child: DecoratedBox(
                key: const ValueKey<String>('photo_food_submit_shield'),
                decoration: BoxDecoration(color: fitTheme.pageBackground),
              ),
            ),
            Positioned.fill(
              child: FilledButton.icon(
                key: const ValueKey<String>('photo_food_submit_button'),
                onPressed: enabled ? onPressed : null,
                icon: analyzing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  analyzing
                      ? strings.photoAiAnalyzing
                      : strings.startPhotoAiAnalysis,
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(
                    0,
                    FitLogBottomNavBar.floatingControlHeight,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  textStyle: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPickerPanel extends StatelessWidget {
  const _PhotoPickerPanel({
    required this.images,
    required this.selectedIndex,
    required this.onCamera,
    required this.onGallery,
    required this.onSelect,
    required this.onRemove,
  });

  final List<PickedFoodImage> images;
  final int selectedIndex;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final fitTheme = context.fitLogTheme;
    final effectiveSelectedIndex = images.isEmpty
        ? 0
        : selectedIndex.clamp(0, images.length - 1).toInt();
    final selectedImage = images.isEmpty
        ? null
        : images[effectiveSelectedIndex];
    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: images.isEmpty
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: fitTheme.surfaceVariant,
                        border: Border.all(color: fitTheme.outline),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.photo_camera_outlined,
                            size: 36,
                            color: fitTheme.mutedText,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            strings.photoAiPickPlaceholder,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    )
                  : Image.memory(
                      selectedImage!.bytes,
                      key: const ValueKey<String>('photo_food_preview_image'),
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          if (images.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 8.0;
                final thumbnailSize = (constraints.maxWidth - gap * 2) / 3;
                return Row(
                  children: [
                    for (var index = 0; index < images.length; index += 1) ...[
                      SizedBox.square(
                        dimension: thumbnailSize,
                        child: _PhotoThumbnail(
                          image: images[index],
                          index: index,
                          selected: index == effectiveSelectedIndex,
                          onSelect: onSelect,
                          onRemove: onRemove,
                        ),
                      ),
                      if (index < images.length - 1) const SizedBox(width: gap),
                    ],
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey<String>('photo_food_camera_button'),
                  onPressed: onCamera,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(strings.takePhoto),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey<String>('photo_food_gallery_button'),
                  onPressed: onGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(strings.chooseFromGallery),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({
    required this.image,
    required this.index,
    required this.selected,
    required this.onSelect,
    required this.onRemove,
  });

  final PickedFoodImage image;
  final int index;
  final bool selected;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? const Color(0xFF5FA94D)
        : Colors.white.withValues(alpha: 0.68);
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        key: selected
            ? ValueKey<String>('photo_food_selected_image_$index')
            : null,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: selected ? 3 : 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Material(
                      color: Colors.transparent,
                      child: Ink.image(
                        image: MemoryImage(image.bytes),
                        key: ValueKey<String>(
                          'photo_food_preview_image_$index',
                        ),
                        fit: BoxFit.cover,
                        child: InkWell(
                          key: ValueKey<String>(
                            'photo_food_select_image_$index',
                          ),
                          onTap: () => onSelect(index),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: -6,
                top: -6,
                child: IconButton.filledTonal(
                  key: ValueKey<String>('photo_food_remove_image_$index'),
                  onPressed: () => onRemove(index),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  padding: EdgeInsets.zero,
                  tooltip: context.strings.removePhoto,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoFoodLoadingOverlay extends StatelessWidget {
  const _PhotoFoodLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.14),
          ),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.strings.photoAiAnalyzing,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
