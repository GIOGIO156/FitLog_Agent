import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/localization_extensions.dart';
import '../../core/theme/fitlog_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/fitlog_bottom_nav_bar.dart';
import '../../core/widgets/fitlog_notifications.dart';
import '../../core/widgets/fitlog_sliding_segmented_control.dart';
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
import 'photo_food_analysis_recovery.dart';

const int _maxPhotoAnalysisImageBytes = 4 * 1024 * 1024;
const int _maxPhotoAnalysisImages = 3;
const String _photoFoodModelPreferenceKey = 'photo_food_ai_model_choice_v1';
const double _photoKeyboardGap = 12;
const Set<String> _supportedPhotoMimeTypes = <String>{
  'image/jpeg',
  'image/png',
  'image/webp',
};

class PhotoFoodAnalysisPage extends StatefulWidget {
  const PhotoFoodAnalysisPage({
    super.key,
    this.initialDate,
    this.initialNote,
    this.initialImages = const <PickedFoodImage>[],
    this.imagePicker,
    this.analysisClient,
  });

  final String? initialDate;
  final String? initialNote;
  final List<PickedFoodImage> initialImages;
  final FoodImagePicker? imagePicker;
  final AiFoodPhotoAnalysisClient? analysisClient;

  @override
  State<PhotoFoodAnalysisPage> createState() => _PhotoFoodAnalysisPageState();
}

class _PhotoFoodAnalysisPageState extends State<PhotoFoodAnalysisPage> {
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _notePanelKey = GlobalKey();
  late final FoodImagePicker _imagePicker;
  late final PhotoFoodAnalysisRecoveryLease _recoveryLease;
  List<PickedFoodImage> _images = const <PickedFoodImage>[];
  int _selectedImageIndex = 0;
  bool _analyzing = false;
  double? _noteRestingBottom;
  AiGatewayModelChoice _modelChoice = AiGatewayModelChoice.qwen;

  @override
  void initState() {
    super.initState();
    _recoveryLease = PhotoFoodAnalysisRecoveryCoordinator.instance
        .acquireOwner();
    _imagePicker = widget.imagePicker ?? ImagePickerFoodImagePicker();
    _images = List<PickedFoodImage>.unmodifiable(
      widget.initialImages.take(_maxPhotoAnalysisImages),
    );
    _selectedImageIndex = _images.isEmpty ? 0 : _images.length - 1;
    _noteController.text = widget.initialNote ?? '';
    _noteController.addListener(_handleNoteChanged);
    _noteFocusNode.addListener(_handleNoteFocusChanged);
    _loadModelChoice();
  }

  @override
  void dispose() {
    FitLogNotifications.dismiss();
    _recoveryLease.release();
    _scrollController.dispose();
    _noteFocusNode.removeListener(_handleNoteFocusChanged);
    _noteFocusNode.dispose();
    _noteController.removeListener(_handleNoteChanged);
    _noteController.dispose();
    super.dispose();
  }

  String get _analysisDate => widget.initialDate ?? DateUtilsX.todayKey();

  bool get _hasAnalyzableInput =>
      _images.isNotEmpty || _noteController.text.trim().isNotEmpty;

  void _handleNoteChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleNoteFocusChanged() {
    if (!_noteFocusNode.hasFocus || !mounted) {
      return;
    }
    final view = View.of(context);
    if (view.viewInsets.bottom / view.devicePixelRatio > 0.5) {
      return;
    }
    final noteBox = _notePanelKey.currentContext?.findRenderObject();
    if (noteBox is! RenderBox) {
      return;
    }
    final restingBottom = noteBox
        .localToGlobal(Offset(0, noteBox.size.height))
        .dy;
    if (_noteRestingBottom == restingBottom) {
      return;
    }
    setState(() => _noteRestingBottom = restingBottom);
  }

  Future<void> _loadModelChoice() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_photoFoodModelPreferenceKey);
    if (!mounted || value == null) return;
    try {
      final choice = aiGatewayModelChoiceFromValue(value);
      if (choice == AiGatewayModelChoice.chatgpt &&
          !fitLogOpenAiProviderEnabled) {
        await preferences.setString(
          _photoFoodModelPreferenceKey,
          AiGatewayModelChoice.qwen.value,
        );
        return;
      }
      setState(() => _modelChoice = choice);
    } on FormatException {
      // Keep the independent photo-analysis default for stale preferences.
    }
  }

  Future<void> _setModelChoice(AiGatewayModelChoice value) async {
    if (value == AiGatewayModelChoice.chatgpt && !fitLogOpenAiProviderEnabled) {
      setState(() => _modelChoice = value);
      FitLogNotifications.topError(
        context,
        context.stringsRead.aiCurrentModelUnavailable,
      );
      await Future<void>.delayed(const Duration(milliseconds: 240));
      if (!mounted || _modelChoice != AiGatewayModelChoice.chatgpt) {
        return;
      }
      setState(() => _modelChoice = AiGatewayModelChoice.qwen);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _photoFoodModelPreferenceKey,
        AiGatewayModelChoice.qwen.value,
      );
      return;
    }
    setState(() => _modelChoice = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_photoFoodModelPreferenceKey, value.value);
  }

  Future<void> _openImageSourceSheet() async {
    if (_analyzing) {
      return;
    }
    final replaceSelected = _images.length >= _maxPhotoAnalysisImages;
    final source = await showModalBottomSheet<FoodImageSource>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => _PhotoImageSourceSheet(
        imageCount: _images.length,
        replaceSelected: replaceSelected,
      ),
    );
    if (source == null || !mounted) {
      return;
    }
    await _pickImage(source, replaceSelected: replaceSelected);
  }

  Future<void> _pickImage(
    FoodImageSource source, {
    required bool replaceSelected,
  }) async {
    final strings = context.stringsRead;
    final availableSlots = replaceSelected
        ? 1
        : _maxPhotoAnalysisImages - _images.length;
    if (availableSlots <= 0) {
      _showError(strings.photoAiSelectionLimitExceeded);
      return;
    }
    try {
      await PhotoFoodAnalysisRecoveryStore.savePending(
        initialDate: widget.initialDate,
        note: _noteController.text,
      );
      final pickedImages = await _imagePicker.pickMultiple(
        source,
        limit: availableSlots,
      );
      if (!mounted) {
        return;
      }
      await PhotoFoodAnalysisRecoveryStore.clearPending();
      if (pickedImages.isEmpty) {
        return;
      }
      if (pickedImages.length > availableSlots) {
        _showError(strings.photoAiSelectionLimitExceeded);
        return;
      }
      final nextImages = replaceSelected
          ? (<PickedFoodImage>[..._images]
              ..[_selectedImageIndex] = pickedImages.first)
          : <PickedFoodImage>[..._images, ...pickedImages];
      setState(() {
        _images = List<PickedFoodImage>.unmodifiable(nextImages);
        if (!replaceSelected) {
          _selectedImageIndex = nextImages.length - 1;
        }
      });
      final validationError = _validationErrorForImages(nextImages);
      if (validationError != null) {
        _showError(validationError);
      }
    } on FoodImageSelectionLimitException {
      if (mounted) {
        await PhotoFoodAnalysisRecoveryStore.clearPending();
        _showError(strings.photoAiSelectionLimitExceeded);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      final pickFailedMessage = context.strings.photoAiPickFailed;
      await PhotoFoodAnalysisRecoveryStore.clearPending();
      if (mounted) {
        FitLogNotifications.topError(context, pickFailedMessage);
      }
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
    if (_modelChoice == AiGatewayModelChoice.chatgpt &&
        !fitLogOpenAiProviderEnabled) {
      FitLogNotifications.topError(context, strings.aiCurrentModelUnavailable);
      return;
    }
    final images = _images;
    final userNote = _noteController.text.trim();
    if (images.isEmpty && userNote.isEmpty) {
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
      modelChoice: _modelChoice,
      deviceId: deviceId!,
      selectedDate: _analysisDate,
      userNote: userNote,
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
      date: _analysisDate,
      modelProvider: response.modelProvider,
      userNote: userNote,
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
      case AiGatewayErrorCode.providerUnavailable:
        return strings.aiCurrentModelUnavailable;
      case AiGatewayErrorCode.providerFailure:
        return strings.aiProviderFailure;
      case AiGatewayErrorCode.requestSchemaMismatch:
      case AiGatewayErrorCode.recordSchemaMismatch:
        return strings.aiRequestUnsupported;
      case AiGatewayErrorCode.providerOutputInvalid:
        return strings.aiOutputInvalid;
      case AiGatewayErrorCode.providerRefusal:
        return strings.aiProviderRefusal;
      case AiGatewayErrorCode.providerIncomplete:
        return strings.aiProviderIncomplete;
      case AiGatewayErrorCode.plannerUnavailable:
      case AiGatewayErrorCode.plannerOutputInvalid:
        return strings.aiPlannerFailure;
      case AiGatewayErrorCode.clarificationConflict:
        return strings.aiClarificationConflict;
      case AiGatewayErrorCode.clarificationExpired:
        return strings.aiClarificationExpired;
      case AiGatewayErrorCode.attachmentUnavailable:
        return strings.aiAttachmentUnavailable;
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
    final canSubmit = _hasAnalyzableInput && !_analyzing;
    final bottomPadding = math.max(
      MediaQuery.viewPaddingOf(context).bottom,
      FitLogBottomNavBar.bottomInset,
    );
    final scrollBottomPadding =
        FitLogBottomNavBar.floatingControlHeight + bottomPadding + 24;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: Text(strings.photoAiAnalysis)),
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: _PhotoKeyboardScrollable(
              controller: _scrollController,
              padding: EdgeInsets.only(bottom: scrollBottomPadding),
              children: <Widget>[
                FitLogPageHeader(
                  title: strings.photoAiAnalysis,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child:
                          FitLogSlidingSegmentedControl<AiGatewayModelChoice>(
                            key: const ValueKey<String>(
                              'photo_food_model_choice',
                            ),
                            indicatorKey: const ValueKey<String>(
                              'photo_food_model_indicator',
                            ),
                            segments:
                                <FitLogSlidingSegment<AiGatewayModelChoice>>[
                                  FitLogSlidingSegment<AiGatewayModelChoice>(
                                    value: AiGatewayModelChoice.chatgpt,
                                    label: strings.aiProviderChatGpt,
                                    key: const ValueKey<String>(
                                      'photo_food_provider_chatgpt',
                                    ),
                                  ),
                                  FitLogSlidingSegment<AiGatewayModelChoice>(
                                    value: AiGatewayModelChoice.qwen,
                                    label: strings.aiProviderQwen,
                                    key: const ValueKey<String>(
                                      'photo_food_provider_qwen',
                                    ),
                                  ),
                                ],
                            selected: _modelChoice,
                            onChanged: _analyzing ? null : _setModelChoice,
                            backgroundColor: context.fitLogTheme.navBackground
                                .withValues(alpha: 0.54),
                            borderColor: context.fitLogTheme.outline.withValues(
                              alpha: 0.72,
                            ),
                            indicatorColor: context.fitLogTheme.navIndicator,
                            selectedTextColor:
                                context.fitLogTheme.navSelectedText,
                            unselectedTextColor:
                                context.fitLogTheme.navUnselectedText,
                          ),
                    ),
                  ),
                ),
                RepaintBoundary(
                  child: _PhotoPickerPanel(
                    images: _images,
                    selectedIndex: _selectedImageIndex,
                    onOpenPicker: _openImageSourceSheet,
                    onSelect: (index) =>
                        setState(() => _selectedImageIndex = index),
                    onRemove: _removeImageAt,
                  ),
                ),
                _buildNotePanel(strings),
              ],
            ),
          ),
          _PhotoKeyboardSubmitGuard(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _PhotoFoodSubmitOverlay(
                enabled: canSubmit,
                analyzing: _analyzing,
                onPressed: _analyze,
              ),
            ),
          ),
          if (_analyzing) const _PhotoFoodLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildNotePanel(AppStrings strings) {
    return _PhotoKeyboardNoteFollower(
      restingBottom: _noteRestingBottom,
      child: GlassPanel(
        key: _notePanelKey,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(14),
        child: TextField(
          key: const ValueKey<String>('photo_food_note_field'),
          controller: _noteController,
          focusNode: _noteFocusNode,
          minLines: 3,
          maxLines: 5,
          textInputAction: TextInputAction.newline,
          scrollPadding: EdgeInsets.zero,
          onTapOutside: (_) => _noteFocusNode.unfocus(),
          decoration: InputDecoration(
            labelText: strings.photoAiNoteLabel,
            hintText: strings.photoAiNoteHint,
            alignLabelWithHint: true,
          ),
        ),
      ),
    );
  }
}

class _PhotoKeyboardScrollable extends StatelessWidget {
  const _PhotoKeyboardScrollable({
    required this.controller,
    required this.padding,
    required this.children,
  });

  final ScrollController controller;
  final EdgeInsetsGeometry padding;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0.5;
    return Listener(
      onPointerMove: keyboardVisible
          ? (_) => FocusManager.instance.primaryFocus?.unfocus()
          : null,
      child: ListView(
        controller: controller,
        physics: keyboardVisible ? const NeverScrollableScrollPhysics() : null,
        padding: padding,
        children: children,
      ),
    );
  }
}

class _PhotoKeyboardNoteFollower extends StatelessWidget {
  const _PhotoKeyboardNoteFollower({
    required this.restingBottom,
    required this.child,
  });

  final double? restingBottom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final availableBottom =
        MediaQuery.sizeOf(context).height - keyboardInset - _photoKeyboardGap;
    final offsetY = restingBottom == null
        ? 0.0
        : math.min(0.0, availableBottom - restingBottom!);
    return Transform.translate(
      key: const ValueKey<String>('photo_food_note_keyboard_follower'),
      offset: Offset(0, offsetY),
      child: child,
    );
  }
}

class _PhotoKeyboardSubmitGuard extends StatelessWidget {
  const _PhotoKeyboardSubmitGuard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return IgnorePointer(
      key: const ValueKey<String>('photo_food_submit_keyboard_guard'),
      ignoring: keyboardInset > 0.5,
      child: child,
    );
  }
}

class _PhotoFoodSubmitOverlay extends StatelessWidget {
  const _PhotoFoodSubmitOverlay({
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
    final bottomPadding = math.max(
      MediaQuery.viewPaddingOf(context).bottom,
      FitLogBottomNavBar.bottomInset,
    );
    final shieldHeight =
        FitLogBottomNavBar.floatingControlHeight / 2 + bottomPadding + 1;

    return SafeArea(
      maintainBottomViewPadding: true,
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

class _PhotoImageSourceSheet extends StatelessWidget {
  const _PhotoImageSourceSheet({
    required this.imageCount,
    required this.replaceSelected,
  });

  final int imageCount;
  final bool replaceSelected;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              replaceSelected
                  ? strings.photoAiReplaceImageTitle
                  : strings.photoAiAddImageTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              strings.photoAiImageCount(imageCount),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.fitLogTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _PhotoSourceAction(
                    key: const ValueKey<String>('photo_food_camera_button'),
                    icon: Icons.photo_camera_outlined,
                    label: strings.takePhoto,
                    onTap: () =>
                        Navigator.of(context).pop(FoodImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PhotoSourceAction(
                    key: const ValueKey<String>('photo_food_gallery_button'),
                    icon: Icons.photo_library_outlined,
                    label: strings.chooseFromGallery,
                    onTap: () =>
                        Navigator.of(context).pop(FoodImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoSourceAction extends StatelessWidget {
  const _PhotoSourceAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    return Material(
      color: fitTheme.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: fitTheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 112,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 30, color: fitTheme.primaryBright),
              const SizedBox(height: 10),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPickerPanel extends StatelessWidget {
  const _PhotoPickerPanel({
    required this.images,
    required this.selectedIndex,
    required this.onOpenPicker,
    required this.onSelect,
    required this.onRemove,
  });

  final List<PickedFoodImage> images;
  final int selectedIndex;
  final VoidCallback onOpenPicker;
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
    final previewCacheWidth =
        ((MediaQuery.sizeOf(context).width - 32) *
                MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(1, 2048)
            .toInt();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            button: true,
            label: strings.photoAiPickPlaceholder,
            child: Material(
              key: const ValueKey<String>('photo_food_preview_action'),
              color: fitTheme.surfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: fitTheme.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onOpenPicker,
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (images.isEmpty)
                        Column(
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
                        )
                      else
                        Image.memory(
                          selectedImage!.bytes,
                          key: const ValueKey<String>(
                            'photo_food_preview_image',
                          ),
                          fit: BoxFit.cover,
                          cacheWidth: previewCacheWidth,
                        ),
                      if (images.isNotEmpty)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: DecoratedBox(
                            key: const ValueKey<String>(
                              'photo_food_preview_add_icon',
                            ),
                            decoration: BoxDecoration(
                              color: fitTheme.surface.withValues(alpha: 0.88),
                              shape: BoxShape.circle,
                              border: Border.all(color: fitTheme.outline),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.add_rounded,
                                size: 22,
                                color: fitTheme.primaryBright,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final thumbnailSize = ((constraints.maxWidth - gap * 2) / 3)
                  .clamp(48.0, 72.0)
                  .toDouble();
              return SizedBox(
                height: thumbnailSize + 4,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    for (
                      var index = 0;
                      index < _maxPhotoAnalysisImages;
                      index += 1
                    ) ...<Widget>[
                      SizedBox.square(
                        dimension: thumbnailSize,
                        child: index < images.length
                            ? _PhotoThumbnail(
                                image: images[index],
                                index: index,
                                selected: index == effectiveSelectedIndex,
                                onSelect: onSelect,
                                onRemove: onRemove,
                              )
                            : _EmptyPhotoThumbnailSlot(index: index),
                      ),
                      if (index < _maxPhotoAnalysisImages - 1)
                        const SizedBox(width: gap),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyPhotoThumbnailSlot extends StatelessWidget {
  const _EmptyPhotoThumbnailSlot({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    return DecoratedBox(
      key: ValueKey<String>('photo_food_empty_slot_$index'),
      decoration: BoxDecoration(
        color: fitTheme.surfaceVariant.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fitTheme.outline.withValues(alpha: 0.56)),
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
    final thumbnailCacheSize = (72 * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(1, 512)
        .toInt();
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
                        image: ResizeImage.resizeIfNeeded(
                          thumbnailCacheSize,
                          thumbnailCacheSize,
                          MemoryImage(image.bytes),
                        ),
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
