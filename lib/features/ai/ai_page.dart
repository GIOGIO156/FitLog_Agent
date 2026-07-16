import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
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
import '../../domain/models/ai_chat_message.dart';
import '../../domain/models/ai_availability.dart';
import '../../domain/models/ai_food_photo_analysis.dart';
import '../../domain/models/ai_gateway_evidence.dart';
import '../../domain/models/ai_gateway_error.dart';
import '../../domain/models/ai_gateway_request.dart';
import '../../domain/models/ai_workout_draft.dart';
import '../../domain/services/ai_workout_draft_handoff_validator.dart';
import '../../domain/models/cloud_runtime_context.dart';
import '../../domain/models/subscription_status.dart';
import '../account/account_controller.dart';
import '../food/food_image_picker.dart';
import '../food/food_preview_page.dart';
import '../workout/add_workout_page.dart';
import '../workout/workout_draft_notification.dart';
import 'ai_chat_controller.dart';
import 'ai_chat_image_recovery.dart';

enum AiShellMode { disabled, ready, processing, needsClarification }

enum _AiProvider { chatGpt, qwen }

enum _AiBackgroundMotion { idleLanding, quietChat }

enum _AiStatusTone { available, blocked, unavailable }

enum _AiLoadingProgressStage { sending, waiting, stillWaiting, slow }

const String _selectedAiProviderPreferenceKey = 'fitlog.ai.selected_provider';
const int _maxChatImages = 3;
const int _maxChatImageBytes = 4 * 1024 * 1024;
const double _aiTopBarHeight = 58;
const double _aiMessageTopGap = 2;
const double _aiMessageBottomGap = 10;
const double _aiMessageListTopPadding = 0;
const double _aiMessageListBottomSafePadding = 14;
const double _aiMessageBottomSoftEdgeHeight = 12;
const double _aiDefaultComposerHeight = 88;
const double _aiKeyboardComposerGap = 12;
const double _aiSendingTurnEstimatedHeight = 96;
const double _aiComposerHorizontalPadding = 16;
const double _aiComposerMaxWidth = 620;
const Duration _aiKeyboardTransitionSettleDelay = Duration(milliseconds: 180);
const Duration _aiImageRecoveryVisualOverrideTimeout = Duration(seconds: 6);
const Set<String> _supportedChatImageMimeTypes = <String>{
  'image/jpeg',
  'image/png',
  'image/webp',
};

class _AiStatusPresentation {
  const _AiStatusPresentation({required this.label, required this.tone});

  final String label;
  final _AiStatusTone tone;
}

class _AiThemePalette {
  const _AiThemePalette({
    required this.icon,
    required this.mutedText,
    required this.action,
    required this.onAction,
    required this.disabledActionBackground,
    required this.disabledActionForeground,
    required this.userBubble,
    required this.onUserBubble,
    required this.assistantText,
    required this.providerSelectedText,
    required this.providerText,
    required this.statusAvailableIndicator,
    required this.statusAvailableText,
    required this.statusUnavailableIndicator,
    required this.statusUnavailableText,
    required this.artifactSurface,
    required this.artifactDisabledSurface,
    required this.artifactBorder,
    required this.artifactDisabledBorder,
    required this.artifactTitle,
    required this.artifactBody,
    required this.artifactButtonDisabledBackground,
    required this.artifactButtonDisabledForeground,
    required this.markdownAuxText,
    required this.markdownCodeText,
    required this.markdownCodeBackground,
    required this.markdownCodeBlockBackground,
    required this.markdownTableBorder,
    required this.historySelectedSurface,
    required this.historySurface,
    required this.historySelectedText,
    required this.historyText,
  });

  final Color icon;
  final Color mutedText;
  final Color action;
  final Color onAction;
  final Color disabledActionBackground;
  final Color disabledActionForeground;
  final Color userBubble;
  final Color onUserBubble;
  final Color assistantText;
  final Color providerSelectedText;
  final Color providerText;
  final Color statusAvailableIndicator;
  final Color statusAvailableText;
  final Color statusUnavailableIndicator;
  final Color statusUnavailableText;
  final Color artifactSurface;
  final Color artifactDisabledSurface;
  final Color artifactBorder;
  final Color artifactDisabledBorder;
  final Color artifactTitle;
  final Color artifactBody;
  final Color artifactButtonDisabledBackground;
  final Color artifactButtonDisabledForeground;
  final Color markdownAuxText;
  final Color markdownCodeText;
  final Color markdownCodeBackground;
  final Color markdownCodeBlockBackground;
  final Color markdownTableBorder;
  final Color historySelectedSurface;
  final Color historySurface;
  final Color historySelectedText;
  final Color historyText;

  static final _AiThemePalette _green = _AiThemePalette(
    icon: const Color(0xFF506052),
    mutedText: const Color(0xFF647067),
    action: const Color(0xFF5FA94D),
    onAction: Colors.white,
    disabledActionBackground: const Color(0xFFD8E0D7),
    disabledActionForeground: const Color(0xFF8C978D),
    userBubble: const Color(0xFF5FA94D).withValues(alpha: 0.92),
    onUserBubble: Colors.white,
    assistantText: const Color(0xFF1A261D),
    providerSelectedText: const Color(0xFF284A31),
    providerText: const Color(0xFF66736B),
    statusAvailableIndicator: const Color(0xFF5FA94D),
    statusAvailableText: const Color(0xFF2F6F35),
    statusUnavailableIndicator: const Color(0xFF8E9A93),
    statusUnavailableText: const Color(0xFF66736B),
    artifactSurface: const Color(0xFFF4F9EE),
    artifactDisabledSurface: const Color(0xFFF1F3EF),
    artifactBorder: const Color(0xFFCFE8BC),
    artifactDisabledBorder: const Color(0xFFD8DED5),
    artifactTitle: const Color(0xFF315B2F),
    artifactBody: const Color(0xFF4F6251),
    artifactButtonDisabledBackground: const Color(0xFFB7BFB3),
    artifactButtonDisabledForeground: Colors.white,
    markdownAuxText: const Color(0xFF5A665C),
    markdownCodeText: const Color(0xFF243329),
    markdownCodeBackground: const Color(0xFFEAF1EA),
    markdownCodeBlockBackground: const Color(0xFFF0F4F1),
    markdownTableBorder: const Color(0xFFD8E3D6),
    historySelectedSurface: const Color(0xFFDDF2D7).withValues(alpha: 0.82),
    historySurface: Colors.white.withValues(alpha: 0.48),
    historySelectedText: const Color(0xFF284A31),
    historyText: const Color(0xFF334137),
  );

  factory _AiThemePalette.of(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    if (!fitTheme.isDark) {
      return _green;
    }

    const semanticReady = Color(0xFF5FA94D);
    const semanticReadyText = Color(0xFF2F6F35);
    const userOrange = Color(0xFFFF7A1A);
    const actionOrange = Color(0xFFFF6B01);
    const deepOrangeText = Color(0xFFA84F08);
    const warmBody = Color(0xFF5F5144);
    const warmSurface = Color(0xFFFFF3E8);
    const warmDisabledSurface = Color(0xFFFFF8F1);
    const warmBorder = Color(0xFFF3C6A3);
    const warmDisabledBorder = Color(0xFFF2D8C4);
    const warmSoft = Color(0xFFFFEFE0);

    return _AiThemePalette(
      icon: warmBody,
      mutedText: const Color(0xFF6F665E),
      action: actionOrange,
      onAction: fitTheme.onPrimary,
      disabledActionBackground: const Color(0xFFFFE6D1),
      disabledActionForeground: const Color(0xFF8A8075),
      userBubble: userOrange,
      onUserBubble: fitTheme.onPrimary,
      assistantText: const Color(0xFF1F1B16),
      providerSelectedText: deepOrangeText,
      providerText: const Color(0xFF6F665E),
      statusAvailableIndicator: semanticReady,
      statusAvailableText: semanticReadyText,
      statusUnavailableIndicator: const Color(0xFF9B9288),
      statusUnavailableText: const Color(0xFF6F665E),
      artifactSurface: warmSurface,
      artifactDisabledSurface: warmDisabledSurface,
      artifactBorder: warmBorder,
      artifactDisabledBorder: warmDisabledBorder,
      artifactTitle: deepOrangeText,
      artifactBody: warmBody,
      artifactButtonDisabledBackground: warmDisabledBorder,
      artifactButtonDisabledForeground: const Color(0xFF8A8075),
      markdownAuxText: const Color(0xFF6F665E),
      markdownCodeText: const Color(0xFF2A211A),
      markdownCodeBackground: warmSoft,
      markdownCodeBlockBackground: warmDisabledSurface,
      markdownTableBorder: warmDisabledBorder,
      historySelectedSurface: warmSoft.withValues(alpha: 0.86),
      historySurface: Colors.white.withValues(alpha: 0.48),
      historySelectedText: deepOrangeText,
      historyText: const Color(0xFF3A332D),
    );
  }
}

class AiPage extends StatefulWidget {
  const AiPage({super.key, this.mode, this.displayName, this.imagePicker});

  final AiShellMode? mode;
  final String? displayName;
  final FoodImagePicker? imagePicker;

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();
  final GlobalKey _composerLayoutKey = GlobalKey();
  final GlobalKey _latestUserMessageKey = GlobalKey();
  final ValueNotifier<bool> _keyboardTransitioning = ValueNotifier<bool>(false);
  late final FoodImagePicker _imagePicker;
  _AiProvider _provider = _AiProvider.qwen;
  bool _historyOpen = false;
  List<PickedFoodImage> _attachedImages = const <PickedFoodImage>[];
  Timer? _keyboardTransitionTimer;
  Timer? _imageRecoveryVisualOverrideTimer;
  String? _scheduledGatewayErrorCode;
  bool _isAppForeground = true;
  String? _accountBoundaryKey;
  String? _chatSyncKey;
  int _lastConsumedRecoveryVersion = 0;
  int _scheduledRecoveryVersion = 0;
  bool _imageRecoveryReadyVisualOverride = false;
  double? _lastKeyboardBottomInset;
  double _composerHeight = _aiDefaultComposerHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _imagePicker = widget.imagePicker ?? ImagePickerFoodImagePicker();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _lastKeyboardBottomInset = _currentViewKeyboardInset();
    });
    unawaited(_loadProviderPreference());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyboardTransitionTimer?.cancel();
    _imageRecoveryVisualOverrideTimer?.cancel();
    _keyboardTransitioning.dispose();
    _messageScrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final nextInset = _currentViewKeyboardInset();
    if (nextInset == null) {
      return;
    }
    final previousInset = _lastKeyboardBottomInset;
    _lastKeyboardBottomInset = nextInset;
    if (previousInset != null && (nextInset - previousInset).abs() < 0.5) {
      return;
    }
    if (!_keyboardTransitioning.value) {
      _keyboardTransitioning.value = true;
    }
    _keyboardTransitionTimer?.cancel();
    _keyboardTransitionTimer = Timer(_aiKeyboardTransitionSettleDelay, () {
      if (!mounted) {
        return;
      }
      _keyboardTransitioning.value = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final wasForeground = _isAppForeground;
    _isAppForeground = state == AppLifecycleState.resumed;
    if (!wasForeground && _isAppForeground && mounted) {
      setState(() {});
    }
  }

  double? _currentViewKeyboardInset() {
    final view = View.maybeOf(context);
    if (view == null) {
      return null;
    }
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  @override
  Widget build(BuildContext context) {
    final accountController = _maybeAccountController(listen: true);
    final chatController = _maybeChatController(listen: true);
    final cloudRuntimeContext = _maybeCloudRuntimeContext(listen: true);
    final imageRecoveryController = _maybeImageRecoveryController(listen: true);
    _scheduleImageRecovery(imageRecoveryController);
    _syncAccountDraftBoundary(accountController);
    _scheduleChatSync(accountController, chatController);
    final effectiveMode = _effectiveMode(
      accountController,
      imageRecoveryController,
    );
    final cloudNickname =
        accountController?.cloudProfileState.cloudProfile?.profile.nickname;
    final canUseGateway = widget.mode == null
        ? accountController?.aiAvailability.canSend ?? false
        : effectiveMode != AiShellMode.disabled;
    final hasConversation = chatController?.hasVisibleConversation ?? false;
    final mediaSize = MediaQuery.sizeOf(context);
    final mediaPadding = MediaQuery.paddingOf(context);
    final quietBackground =
        hasConversation || (chatController?.sending ?? false);
    final status = _statusPresentation(
      context,
      accountController: accountController,
      canSend: canUseGateway,
    );
    _scheduleGatewayErrorNotification(chatController);
    _scheduleComposerMeasure();

    return Stack(
      key: const ValueKey<String>('ai_page'),
      children: <Widget>[
        Positioned.fill(
          child: RepaintBoundary(
            child: _AiAnimatedBackground(
              mode: effectiveMode,
              motion: quietBackground
                  ? _AiBackgroundMotion.quietChat
                  : _AiBackgroundMotion.idleLanding,
              pauseListenable: _keyboardTransitioning,
            ),
          ),
        ),
        _AiKeyboardResponsiveLayer(
          screenSize: mediaSize,
          screenPadding: mediaPadding,
          hasConversation: hasConversation,
          chatController: chatController,
          messageScrollController: _messageScrollController,
          latestUserMessageKey: _latestUserMessageKey,
          composerLayoutKey: _composerLayoutKey,
          composerHeight: _composerHeight,
          controller: _controller,
          provider: _provider,
          canUseGateway: canUseGateway,
          sending: chatController?.sending ?? false,
          attachedImages: _attachedImages,
          mode: effectiveMode,
          status: status,
          displayName:
              widget.displayName ??
              cloudNickname ??
              accountController?.authSession.displayName,
          accountController: accountController,
          onProviderChanged: _selectProvider,
          onOpenHistory: () => setState(() => _historyOpen = true),
          onAttachPressed: _chooseImageAttachment,
          onRemoveAttachment: _removeImageAttachment,
          onComposerChanged: _handleComposerChanged,
          onSend: (text) => _sendMessage(
            text: text,
            chatController: chatController,
            accountController: accountController,
            cloudRuntimeContext: cloudRuntimeContext,
          ),
          onOpenFoodDraft: _openFoodDraftPreview,
          onOpenWorkoutDraft: _openWorkoutDraftPreview,
        ),
        if (_historyOpen)
          _AiHistoryPanel(
            controller: chatController,
            onClose: () => setState(() => _historyOpen = false),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: math.max(mediaPadding.bottom, 8),
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  AccountController? _maybeAccountController({required bool listen}) {
    try {
      return Provider.of<AccountController>(context, listen: listen);
    } catch (_) {
      return null;
    }
  }

  AiChatController? _maybeChatController({required bool listen}) {
    try {
      return Provider.of<AiChatController>(context, listen: listen);
    } catch (_) {
      return null;
    }
  }

  CloudRuntimeContext? _maybeCloudRuntimeContext({required bool listen}) {
    try {
      return Provider.of<CloudRuntimeContext>(context, listen: listen);
    } catch (_) {
      return null;
    }
  }

  AiChatImageRecoveryController? _maybeImageRecoveryController({
    required bool listen,
  }) {
    try {
      return Provider.of<AiChatImageRecoveryController>(
        context,
        listen: listen,
      );
    } catch (_) {
      return null;
    }
  }

  void _scheduleImageRecovery(AiChatImageRecoveryController? controller) {
    final pending = controller?.pending;
    final version = controller?.version ?? 0;
    if (controller == null || pending == null) {
      return;
    }
    if (version == _lastConsumedRecoveryVersion ||
        version == _scheduledRecoveryVersion) {
      return;
    }
    _scheduledRecoveryVersion = version;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final recovered = controller.consume(version);
      _lastConsumedRecoveryVersion = version;
      if (recovered == null) {
        return;
      }
      _applyRecoveredImages(recovered);
    });
  }

  void _applyRecoveredImages(RecoveredAiChatImages recovered) {
    final provider = _providerFromPreferenceValue(recovered.provider);
    final nextImages = <PickedFoodImage>[];
    String? validationError;
    for (final image in recovered.images) {
      validationError = _validationErrorForImage(image);
      if (validationError != null) {
        break;
      }
      if (_attachedImages.length + nextImages.length >= _maxChatImages) {
        validationError = context.stringsRead.aiImageLimitReached;
        break;
      }
      nextImages.add(image);
    }
    final messageText = recovered.messageText;
    if (messageText.isNotEmpty) {
      _controller.text = messageText;
      _controller.selection = TextSelection.collapsed(
        offset: messageText.length,
      );
    }
    if (recovered.wasReadyVisual) {
      _holdImageRecoveryReadyVisual();
    }
    setState(() {
      if (provider != null) {
        _provider = provider;
      }
      if (nextImages.isNotEmpty) {
        _attachedImages = <PickedFoodImage>[..._attachedImages, ...nextImages];
      }
    });
    if (validationError != null) {
      _showComposerNotice(validationError);
    } else if (nextImages.isNotEmpty || messageText.isNotEmpty) {
      _clearComposerNotice();
    }
  }

  AiShellMode _effectiveMode(
    AccountController? accountController,
    AiChatImageRecoveryController? imageRecoveryController,
  ) {
    final explicitMode = widget.mode;
    if (explicitMode != null) {
      return explicitMode;
    }
    if (accountController?.aiAvailability.isReadyVisual == true ||
        _shouldKeepImageRecoveryReadyVisual(imageRecoveryController)) {
      return AiShellMode.ready;
    }
    return AiShellMode.disabled;
  }

  bool _shouldKeepImageRecoveryReadyVisual(
    AiChatImageRecoveryController? controller,
  ) {
    return _imageRecoveryReadyVisualOverride ||
        (controller?.pending?.wasReadyVisual == true);
  }

  void _holdImageRecoveryReadyVisual() {
    _imageRecoveryVisualOverrideTimer?.cancel();
    _imageRecoveryReadyVisualOverride = true;
    _imageRecoveryVisualOverrideTimer = Timer(
      _aiImageRecoveryVisualOverrideTimeout,
      () {
        if (!mounted || !_imageRecoveryReadyVisualOverride) {
          return;
        }
        setState(() {
          _imageRecoveryReadyVisualOverride = false;
        });
      },
    );
  }

  _AiStatusPresentation _statusPresentation(
    BuildContext context, {
    required AccountController? accountController,
    required bool canSend,
  }) {
    final strings = context.strings;
    if (canSend) {
      return _AiStatusPresentation(
        label: strings.aiAvailableStatus,
        tone: _AiStatusTone.available,
      );
    }
    final availability = accountController?.aiAvailability;
    if (availability == null) {
      return _AiStatusPresentation(
        label: strings.aiUnavailableStatus,
        tone: _AiStatusTone.unavailable,
      );
    }
    switch (availability.status) {
      case AiAvailabilityStatus.signedOut:
        return _AiStatusPresentation(
          label: strings.aiUnavailableStatus,
          tone: _AiStatusTone.unavailable,
        );
      case AiAvailabilityStatus.offline:
        return _AiStatusPresentation(
          label: strings.aiUnavailableStatus,
          tone: _AiStatusTone.unavailable,
        );
      case AiAvailabilityStatus.subscriptionInactive:
        if (accountController?.subscriptionStatus.state ==
            SubscriptionState.error) {
          return _AiStatusPresentation(
            label: strings.aiUnavailableStatus,
            tone: _AiStatusTone.blocked,
          );
        }
        return _AiStatusPresentation(
          label: strings.aiUnavailableStatus,
          tone: _AiStatusTone.blocked,
        );
      case AiAvailabilityStatus.profileMissing:
        return _AiStatusPresentation(
          label: strings.aiUnavailableStatus,
          tone: _AiStatusTone.blocked,
        );
      case AiAvailabilityStatus.gatewayPending:
        return _AiStatusPresentation(
          label: strings.aiUnavailableStatus,
          tone: _AiStatusTone.blocked,
        );
    }
  }

  Future<void> _sendMessage({
    required String text,
    required AiChatController? chatController,
    required AccountController? accountController,
    required CloudRuntimeContext? cloudRuntimeContext,
  }) async {
    if (_provider == _AiProvider.chatGpt && !fitLogOpenAiProviderEnabled) {
      _showComposerNotice(context.stringsRead.aiCurrentModelUnavailable);
      return;
    }
    if (chatController == null ||
        accountController == null ||
        cloudRuntimeContext == null) {
      return;
    }
    chatController.syncAccount(
      accountId: accountController.authSession.accountId,
      canUseAi: accountController.aiAvailability.canSend,
    );
    final deviceId = cloudRuntimeContext.deviceId;
    if ((deviceId ?? '').isEmpty) {
      chatController.showLocalError(
        const AiGatewayError(
          code: AiGatewayErrorCode.unknown,
          rawCode: 'active_device_missing',
          message: 'Active device is not ready.',
        ),
      );
      return;
    }
    final cloudProfile = accountController.cloudProfileState.cloudProfile;
    final strings = context.stringsRead;
    final sentImages = List<PickedFoodImage>.unmodifiable(_attachedImages);
    String? validationError;
    for (final image in sentImages) {
      validationError = _validationErrorForImage(image);
      if (validationError != null) {
        break;
      }
    }
    if (validationError != null) {
      _showComposerNotice(validationError);
      return;
    }
    final enteredText = text.trim();
    final trimmed = enteredText.isEmpty && sentImages.isNotEmpty
        ? strings.aiImageOnlyMessage
        : enteredText;
    _clearComposerNotice();
    final attachments = sentImages
        .map(
          (image) => AiGatewayImageAttachment(
            mimeType: image.mimeType,
            base64Data: base64Encode(image.bytes),
            byteLength: image.byteLength,
            name: image.name,
          ),
        )
        .toList(growable: false);
    _controller.clear();
    if (sentImages.isNotEmpty) {
      setState(() => _attachedImages = const <PickedFoodImage>[]);
    }
    _prepareMessageListForSend();
    final sendFuture = chatController.sendText(
      text: trimmed,
      language: _languageForMessage(trimmed, strings),
      modelChoice: _modelChoiceFor(_provider),
      deviceId: deviceId!,
      selectedDate:
          context.read<SelectedDateNotifier?>()?.selectedDate ??
          DateUtilsX.todayKey(),
      profileVersion: cloudProfile == null
          ? null
          : 'profile_${cloudProfile.profileVersion}',
      allowRecordSummaryContext:
          accountController.localContextPermission?.allowed ?? false,
      attachments: attachments,
    );
    final success = await sendFuture;
    if (!mounted) {
      return;
    }
    if (success) {
      _controller.clear();
    } else if (_controller.text.isEmpty) {
      _controller.text = enteredText;
      _controller.selection = TextSelection.collapsed(
        offset: enteredText.length,
      );
      if (sentImages.isNotEmpty) {
        setState(() => _attachedImages = sentImages);
      }
    }
  }

  void _prepareMessageListForSend() {
    if (!_messageScrollController.hasClients) {
      return;
    }
    final position = _messageScrollController.position;
    if ((position.maxScrollExtent - position.pixels).abs() > 0.5) {
      _messageScrollController.jumpTo(position.maxScrollExtent);
    }
  }

  Future<void> _chooseImageAttachment() async {
    if (_attachedImages.length >= _maxChatImages) {
      _showComposerNotice(context.stringsRead.aiImageLimitReached);
      return;
    }
    final source = await showModalBottomSheet<FoodImageSource>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final strings = sheetContext.strings;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: Text(strings.takePhoto),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(FoodImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(strings.chooseFromGallery),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(FoodImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null) {
      return;
    }
    await _pickImageAttachment(source);
  }

  Future<void> _pickImageAttachment(FoodImageSource source) async {
    try {
      await AiChatImageRecoveryStore.savePending(
        messageText: _controller.text,
        provider: _providerPreferenceValue(_provider),
        wasReadyVisual:
            _maybeAccountController(
              listen: false,
            )?.aiAvailability.isReadyVisual ==
            true,
      );
      final remainingSlots = _maxChatImages - _attachedImages.length;
      final images = await _imagePicker.pickMultiple(
        source,
        limit: remainingSlots,
      );
      await AiChatImageRecoveryStore.clearPending();
      if (!mounted || images.isEmpty) {
        return;
      }
      final nextImages = <PickedFoodImage>[];
      String? validationError;
      for (final image in images) {
        validationError = _validationErrorForImage(image);
        if (validationError != null) {
          break;
        }
        if (_attachedImages.length + nextImages.length >= _maxChatImages) {
          validationError = context.strings.aiImageLimitReached;
          break;
        }
        nextImages.add(image);
      }
      if (validationError != null) {
        _showComposerNotice(validationError);
      }
      if (nextImages.isEmpty) {
        return;
      }
      _clearComposerNotice();
      setState(() {
        _attachedImages = <PickedFoodImage>[..._attachedImages, ...nextImages];
      });
    } catch (_) {
      await AiChatImageRecoveryStore.clearPending();
      if (!mounted) {
        return;
      }
      _showComposerNotice(context.strings.photoAiPickFailed);
    }
  }

  void _removeImageAttachment(int index) {
    if (index < 0 || index >= _attachedImages.length) {
      return;
    }
    final nextImages = List<PickedFoodImage>.from(_attachedImages)
      ..removeAt(index);
    _clearComposerNotice();
    setState(
      () => _attachedImages = List<PickedFoodImage>.unmodifiable(nextImages),
    );
  }

  void _showComposerNotice(String label) {
    FitLogNotifications.error(
      context,
      label,
      additionalBottomOffset: _composerHeight + 8,
    );
  }

  void _clearComposerNotice() {
    FitLogNotifications.dismiss();
  }

  void _handleComposerChanged(String _) {
    _dismissComposerError();
  }

  void _dismissComposerError() {
    _scheduledGatewayErrorCode = null;
    _clearComposerNotice();
    _maybeChatController(listen: false)?.clearError();
  }

  void _scheduleGatewayErrorNotification(AiChatController? controller) {
    final error = controller?.lastError;
    if (error == null) {
      _scheduledGatewayErrorCode = null;
      return;
    }
    if (!_isAppForeground) {
      return;
    }
    final key = '${error.rawCode}:${error.message ?? ''}';
    if (_scheduledGatewayErrorCode == key) return;
    _scheduledGatewayErrorCode = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isAppForeground || _scheduledGatewayErrorCode != key) {
        if (_scheduledGatewayErrorCode == key) {
          _scheduledGatewayErrorCode = null;
        }
        return;
      }
      FitLogNotifications.error(
        context,
        _aiErrorLabel(context, error),
        additionalBottomOffset: _composerHeight + 8,
      );
      controller?.clearError();
    });
  }

  String? _validationErrorForImage(PickedFoodImage image) {
    final strings = context.stringsRead;
    if (!_supportedChatImageMimeTypes.contains(image.mimeType)) {
      return strings.photoAiUnsupportedImage;
    }
    if (image.byteLength > _maxChatImageBytes) {
      return strings.photoAiImageTooLarge;
    }
    return null;
  }

  void _scheduleComposerMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final box =
          _composerLayoutKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        return;
      }
      final nextHeight = box.size.height;
      if ((nextHeight - _composerHeight).abs() < 0.5) {
        return;
      }
      setState(() => _composerHeight = nextHeight);
    });
  }

  Future<void> _openFoodDraftPreview(
    AiFoodDraft draft,
    String? modelProvider,
  ) async {
    final record = draft.toFoodRecord(
      modelProvider: switch (modelProvider) {
        'openai' => 'openai',
        'qwen' => 'qwen',
        _ => _provider == _AiProvider.chatGpt ? 'openai' : 'qwen',
      },
    );
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FoodPreviewPage(initialRecord: record),
      ),
    );
  }

  Future<void> _openWorkoutDraftPreview(AiWorkoutDraft draft) async {
    final services = context.read<AppServices>();
    try {
      await AiWorkoutDraftHandoffValidator(
        services.customExerciseRepository,
      ).validate(draft);
    } on FormatException {
      if (mounted) {
        _showComposerNotice(context.stringsRead.aiWorkoutDefinitionChanged);
      }
      return;
    }
    final existingDraft = await services.workoutDraftRepository
        .getActiveDraft();
    if (!mounted) {
      return;
    }
    if (existingDraft != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final strings = dialogContext.strings;
          return AlertDialog(
            title: Text(strings.aiWorkoutDraftReplaceTitle),
            content: Text(strings.aiWorkoutDraftReplaceMessage),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(strings.aiWorkoutDraftReplaceAction),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }
    final resolvedDate = draft.date;
    final recordDraft = draft.toWorkoutRecordDraft(dateFallback: resolvedDate);
    final strings = context.stringsRead;
    await services.workoutDraftRepository.saveActiveDraft(recordDraft);
    await WorkoutDraftNotificationSync.syncFromDraft(recordDraft, strings);
    if (!mounted) {
      return;
    }
    context.read<RefreshNotifier>().markDataChanged();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AddWorkoutPage(initialDate: resolvedDate),
      ),
    );
  }

  AiGatewayModelChoice _modelChoiceFor(_AiProvider provider) {
    switch (provider) {
      case _AiProvider.chatGpt:
        return AiGatewayModelChoice.chatgpt;
      case _AiProvider.qwen:
        return AiGatewayModelChoice.qwen;
    }
  }

  Future<void> _loadProviderPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = _providerFromPreferenceValue(
      prefs.getString(_selectedAiProviderPreferenceKey),
    );
    if (provider == _AiProvider.chatGpt && !fitLogOpenAiProviderEnabled) {
      await prefs.setString(
        _selectedAiProviderPreferenceKey,
        _providerPreferenceValue(_AiProvider.qwen),
      );
      return;
    }
    if (!mounted || provider == null || provider == _provider) {
      return;
    }
    setState(() => _provider = provider);
  }

  Future<void> _selectProvider(_AiProvider provider) async {
    if (provider == _AiProvider.chatGpt && !fitLogOpenAiProviderEnabled) {
      if (_provider != provider) {
        setState(() => _provider = provider);
      }
      _showComposerNotice(context.stringsRead.aiCurrentModelUnavailable);
      await Future<void>.delayed(const Duration(milliseconds: 240));
      if (!mounted || _provider != _AiProvider.chatGpt) {
        return;
      }
      setState(() => _provider = _AiProvider.qwen);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _selectedAiProviderPreferenceKey,
        _providerPreferenceValue(_AiProvider.qwen),
      );
      return;
    }
    if (_provider != provider) {
      setState(() => _provider = provider);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _selectedAiProviderPreferenceKey,
      _providerPreferenceValue(provider),
    );
  }

  _AiProvider? _providerFromPreferenceValue(String? value) {
    switch (value) {
      case 'chatgpt':
        return _AiProvider.chatGpt;
      case 'qwen':
        return _AiProvider.qwen;
      default:
        return null;
    }
  }

  String _providerPreferenceValue(_AiProvider provider) {
    switch (provider) {
      case _AiProvider.chatGpt:
        return 'chatgpt';
      case _AiProvider.qwen:
        return 'qwen';
    }
  }

  String _aiErrorLabel(BuildContext context, AiGatewayError error) {
    final strings = context.stringsRead;
    if (error.rawCode == 'ai_chat_delete_failed') {
      return strings.aiDeleteChatFailed;
    }
    if (error.rawCode == 'ai_chat_sessions_load_failed' ||
        error.rawCode == 'ai_chat_messages_load_failed') {
      return strings.aiChatHistoryLoadFailed;
    }
    if (error.rawCode == 'active_device_missing') {
      return strings.aiActiveDevicePreparing;
    }
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
      case AiGatewayErrorCode.requestSchemaMismatch:
      case AiGatewayErrorCode.recordSchemaMismatch:
        return strings.aiRequestUnsupported;
      case AiGatewayErrorCode.providerOutputInvalid:
        return strings.aiOutputInvalid;
      case AiGatewayErrorCode.providerRefusal:
        return strings.aiProviderRefusal;
      case AiGatewayErrorCode.providerIncomplete:
        return strings.aiProviderIncomplete;
      case AiGatewayErrorCode.networkFailure:
        return strings.aiChatNetworkFailure;
      case AiGatewayErrorCode.unknown:
        return strings.aiUnknownFailure;
    }
  }

  void _syncAccountDraftBoundary(AccountController? accountController) {
    final nextKey =
        '${accountController?.authSession.accountId ?? 'signed_out'}:${accountController?.accountChangeEpoch ?? 0}';
    final previousKey = _accountBoundaryKey;
    _accountBoundaryKey = nextKey;
    if (previousKey != null && previousKey != nextKey) {
      _controller.clear();
      _attachedImages = const <PickedFoodImage>[];
      FitLogNotifications.dismiss();
    }
  }

  void _scheduleChatSync(
    AccountController? accountController,
    AiChatController? chatController,
  ) {
    if (chatController == null) {
      return;
    }
    final accountId = accountController?.authSession.accountId;
    final canUseAi = accountController?.aiAvailability.canSend ?? false;
    final nextKey = '${accountId ?? 'none'}:$canUseAi';
    if (_chatSyncKey == nextKey) {
      return;
    }
    _chatSyncKey = nextKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      chatController.syncAccount(accountId: accountId, canUseAi: canUseAi);
    });
  }
}

class _AiKeyboardResponsiveLayer extends StatelessWidget {
  const _AiKeyboardResponsiveLayer({
    required this.screenSize,
    required this.screenPadding,
    required this.hasConversation,
    required this.chatController,
    required this.messageScrollController,
    required this.latestUserMessageKey,
    required this.composerLayoutKey,
    required this.composerHeight,
    required this.controller,
    required this.provider,
    required this.canUseGateway,
    required this.sending,
    required this.attachedImages,
    required this.mode,
    required this.status,
    required this.displayName,
    required this.accountController,
    required this.onProviderChanged,
    required this.onOpenHistory,
    required this.onAttachPressed,
    required this.onRemoveAttachment,
    required this.onComposerChanged,
    required this.onSend,
    required this.onOpenFoodDraft,
    required this.onOpenWorkoutDraft,
  });

  final Size screenSize;
  final EdgeInsets screenPadding;
  final bool hasConversation;
  final AiChatController? chatController;
  final ScrollController messageScrollController;
  final GlobalKey latestUserMessageKey;
  final GlobalKey composerLayoutKey;
  final double composerHeight;
  final TextEditingController controller;
  final _AiProvider provider;
  final bool canUseGateway;
  final bool sending;
  final List<PickedFoodImage> attachedImages;
  final AiShellMode mode;
  final _AiStatusPresentation status;
  final String? displayName;
  final AccountController? accountController;
  final ValueChanged<_AiProvider> onProviderChanged;
  final VoidCallback onOpenHistory;
  final VoidCallback onAttachPressed;
  final ValueChanged<int> onRemoveAttachment;
  final ValueChanged<String> onComposerChanged;
  final ValueChanged<String> onSend;
  final void Function(AiFoodDraft draft, String? modelProvider) onOpenFoodDraft;
  final ValueChanged<AiWorkoutDraft> onOpenWorkoutDraft;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final restingComposerBottomPadding =
        FitLogBottomNavBar.floatingControlScreenBottomPaddingFor(context);
    final composerAttachedToKeyboard =
        bottomInset > restingComposerBottomPadding;
    final composerBottomPadding = composerAttachedToKeyboard
        ? bottomInset + _aiKeyboardComposerGap
        : restingComposerBottomPadding;
    const messageViewportGap = _aiMessageBottomGap;
    final readableBottomObstruction =
        composerBottomPadding + composerHeight + messageViewportGap;
    final messageViewportBottomObstruction = readableBottomObstruction;
    const messageListBottomPadding = _aiMessageListBottomSafePadding;
    final contentTopPadding = hasConversation
        ? _aiTopBarHeight + _aiMessageTopGap
        : 74.0;
    const messageListTopPadding = _aiMessageListTopPadding;
    final viewportHeight =
        screenSize.height -
        screenPadding.top -
        contentTopPadding -
        readableBottomObstruction;
    final sendAnchorPadding = sending
        ? math.max(0.0, viewportHeight - _aiSendingTurnEstimatedHeight)
        : 0.0;

    return SafeArea(
      bottom: false,
      child: Stack(
        children: <Widget>[
          if (hasConversation)
            Positioned(
              left: 18,
              top: contentTopPadding,
              right: 18,
              bottom: messageViewportBottomObstruction,
              child: _AiMessageViewport(
                child: _AiMessageList(
                  controller: chatController!,
                  scrollController: messageScrollController,
                  latestUserKey: latestUserMessageKey,
                  topPadding: messageListTopPadding,
                  bottomPadding: messageListBottomPadding,
                  sendAnchorBottomPadding: sendAnchorPadding,
                  scrollingDisabled: composerAttachedToKeyboard,
                  onOpenFoodDraft: onOpenFoodDraft,
                  onOpenWorkoutDraft: onOpenWorkoutDraft,
                ),
              ),
            )
          else
            Positioned(
              left: 18,
              top: 18,
              right: 18,
              bottom: readableBottomObstruction,
              child: Center(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: _AiCenterStatus(mode: mode, displayName: displayName),
                ),
              ),
            ),
          _AiTopBar(
            accountController: accountController,
            showProviderStatus: hasConversation,
            provider: provider,
            status: status,
            onProviderChanged: onProviderChanged,
            onOpenHistory: onOpenHistory,
          ),
          if (composerAttachedToKeyboard) ...<Widget>[
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey<String>('ai_keyboard_dismiss_region'),
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                onVerticalDragStart: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
              ),
            ),
          ],
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                _aiComposerHorizontalPadding,
                0,
                _aiComposerHorizontalPadding,
                composerBottomPadding,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _aiComposerMaxWidth,
                ),
                child: KeyedSubtree(
                  key: composerLayoutKey,
                  child: _AiComposer(
                    controller: controller,
                    provider: provider,
                    canSend: canUseGateway,
                    sending: sending,
                    attachedImages: attachedImages,
                    mode: mode,
                    status: status,
                    hasConversation: hasConversation,
                    onProviderChanged: onProviderChanged,
                    onAttachPressed: onAttachPressed,
                    onRemoveAttachment: onRemoveAttachment,
                    onComposerChanged: onComposerChanged,
                    onSend: onSend,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiAnimatedBackground extends StatefulWidget {
  const _AiAnimatedBackground({
    required this.mode,
    required this.motion,
    required this.pauseListenable,
  });

  final AiShellMode mode;
  final _AiBackgroundMotion motion;
  final ValueListenable<bool> pauseListenable;

  @override
  State<_AiAnimatedBackground> createState() => _AiAnimatedBackgroundState();
}

class _AiAnimatedBackgroundState extends State<_AiAnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    widget.pauseListenable.addListener(_syncAnimationState);
    _syncAnimationState();
  }

  @override
  void didUpdateWidget(covariant _AiAnimatedBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pauseListenable != widget.pauseListenable) {
      oldWidget.pauseListenable.removeListener(_syncAnimationState);
      widget.pauseListenable.addListener(_syncAnimationState);
    }
    _controller.duration = _duration;
    _syncAnimationState();
  }

  @override
  void dispose() {
    widget.pauseListenable.removeListener(_syncAnimationState);
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimationState() {
    if (widget.pauseListenable.value) {
      if (_controller.isAnimating) {
        _controller.stop(canceled: false);
      }
      return;
    }
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  Duration get _duration {
    switch (widget.motion) {
      case _AiBackgroundMotion.idleLanding:
        return const Duration(milliseconds: 3800);
      case _AiBackgroundMotion.quietChat:
        return const Duration(seconds: 9);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          return CustomPaint(
            isComplex: true,
            willChange: true,
            painter: _AiFlowBackgroundPainter(
              progress: progress,
              mode: widget.mode,
              motion: widget.motion,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _AiFlowBackgroundPainter extends CustomPainter {
  const _AiFlowBackgroundPainter({
    required this.progress,
    required this.mode,
    required this.motion,
  });

  final double progress;
  final AiShellMode mode;
  final _AiBackgroundMotion motion;

  static const List<double> _fieldSamples = <double>[
    0.0,
    0.0625,
    0.125,
    0.1875,
    0.25,
    0.3125,
    0.375,
    0.4375,
    0.50,
    0.5625,
    0.625,
    0.6875,
    0.75,
    0.8125,
    0.875,
    0.9375,
    1.0,
  ];

  static const List<Color> _disabledPalette = <Color>[
    Color(0xFFF7F5F1),
    Color(0xFFEDE8E6),
    Color(0xFFE7EEE8),
    Color(0xFFE6EEF0),
  ];

  static const List<double> _disabledStops = <double>[0.0, 0.36, 0.70, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (rect.isEmpty) {
      return;
    }

    final disabled = mode == AiShellMode.disabled;
    final quiet = motion == _AiBackgroundMotion.quietChat;
    final time = progress * math.pi * 2;
    final motionScale = disabled ? 0.22 : (quiet ? 0.42 : 1.04);
    final tintScale = disabled ? 0.0 : (quiet ? 0.56 : 1.0);
    final emphasis = switch (mode) {
      AiShellMode.processing => 1.0,
      AiShellMode.ready => 0.88,
      AiShellMode.needsClarification => 0.48,
      AiShellMode.disabled => 0.0,
    };

    final paletteColors = disabled
        ? _disabledPalette
        : <Color>[
            Color.lerp(
              const Color(0xFFFFBCD1),
              const Color(0xFFFFD6E2),
              _wave01(time, 0.20),
            )!,
            Color.lerp(
              const Color(0xFFFFD9E4),
              const Color(0xFFFFE7EE),
              _wave01(time, 1.30),
            )!,
            Color.lerp(
              const Color(0xFFE4F4E8),
              const Color(0xFFCBF3E2),
              _wave01(time, 2.10),
            )!,
            Color.lerp(
              const Color(0xFFB8F0E0),
              const Color(0xFFA8EADF),
              _wave01(time, 3.40),
            )!,
            Color.lerp(
              const Color(0xFF9ADCF4),
              const Color(0xFF7CCDF8),
              _wave01(time, 4.20),
            )!,
            const Color(0xFF64BEF6),
          ];
    final paletteStops = disabled
        ? _disabledStops
        : _activePaletteStops(time, motionScale);

    final stripeCount = (size.height / 3).ceil().clamp(180, 420).toInt();
    final stripeHeight = size.height / stripeCount;
    for (var index = 0; index < stripeCount; index += 1) {
      final top = index * stripeHeight;
      final y = (top + stripeHeight * 0.5) / size.height;
      final stripeRect = Rect.fromLTWH(0, top, size.width, stripeHeight + 1.1);
      final sampleColors = <Color>[
        for (final sampleX in _fieldSamples)
          _sampleFieldColor(
            sampleX,
            y,
            time,
            motionScale: motionScale,
            emphasis: emphasis,
            paletteColors: paletteColors,
            paletteStops: paletteStops,
          ),
      ];
      final stripePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: sampleColors,
          stops: _fieldSamples,
        ).createShader(stripeRect);
      canvas.drawRect(stripeRect, stripePaint);
    }

    if (!disabled) {
      final atmosphericPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFFFFBED2).withValues(alpha: 0.10 * tintScale),
            Colors.white.withValues(alpha: 0.05 * tintScale),
            const Color(0xFF83D1F8).withValues(alpha: 0.08 * tintScale),
          ],
          stops: const <double>[0.0, 0.48, 1.0],
          transform: GradientRotation(math.sin(time) * 0.08),
        ).createShader(rect);
      canvas.drawRect(rect, atmosphericPaint);
    }

    final veilPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.white.withValues(alpha: disabled ? 0.20 : 0.07),
          Colors.white.withValues(alpha: disabled ? 0.20 : 0.04),
          Colors.white.withValues(alpha: disabled ? 0.05 : 0.00),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, veilPaint);
  }

  Color _sampleFieldColor(
    double x,
    double y,
    double time, {
    required double motionScale,
    required double emphasis,
    required List<Color> paletteColors,
    required List<double> paletteStops,
  }) {
    final verticalFlow =
        math.sin(time + x * 2.35 + y * 3.60) * 0.042 +
        math.sin(time * 2 - x * 3.90 + y * 1.70) * 0.018 +
        math.cos(time + x * 0.80 - y * 5.40) * 0.024;
    final broadShear = math.sin(time * 2 + y * 4.00) * (x - 0.5) * 0.032;
    final sampledY = _clampUnit(y + (verticalFlow + broadShear) * motionScale);
    final base = _samplePalette(paletteColors, paletteStops, sampledY);
    final lightBreath =
        (math.sin(time * 2 + x * 5.0 - y * 2.0) + 1) *
        (0.012 + emphasis * 0.010) *
        motionScale;
    return Color.lerp(
      base,
      Colors.white,
      lightBreath.clamp(0.0, 0.055).toDouble(),
    )!;
  }

  Color _samplePalette(List<Color> colors, List<double> stops, double value) {
    final sampled = _clampUnit(value);
    for (var index = 0; index < stops.length - 1; index += 1) {
      final start = stops[index];
      final end = stops[index + 1];
      if (sampled <= end) {
        final localProgress = end == start
            ? 1.0
            : _smoothStep(_clampUnit((sampled - start) / (end - start)));
        return Color.lerp(colors[index], colors[index + 1], localProgress)!;
      }
    }
    return colors.last;
  }

  double _smoothStep(double value) {
    final t = _clampUnit(value);
    return t * t * (3 - 2 * t);
  }

  double _wave01(double time, double phase) {
    return (math.sin(time + phase) + 1) / 2;
  }

  List<double> _activePaletteStops(double time, double motionScale) {
    final pinkEnd = _clampUnit(
      0.27 + math.sin(time + 0.60) * 0.016 * motionScale,
    );
    final mintStart = math.max(
      pinkEnd + 0.105,
      _clampUnit(0.39 + math.sin(time * 2 + 1.40) * 0.020 * motionScale),
    );
    final mintEnd = math.max(
      mintStart + 0.145,
      _clampUnit(0.56 + math.cos(time + 2.20) * 0.020 * motionScale),
    );
    final blueStart = math.max(
      mintEnd + 0.115,
      _clampUnit(0.70 + math.sin(time * 2 + 3.10) * 0.014 * motionScale),
    );
    return <double>[
      0.0,
      pinkEnd,
      mintStart.clamp(0.0, 0.52).toDouble(),
      mintEnd.clamp(0.0, 0.66).toDouble(),
      blueStart.clamp(0.0, 0.80).toDouble(),
      1.0,
    ];
  }

  double _clampUnit(double value) {
    return value.clamp(0.0, 1.0).toDouble();
  }

  @override
  bool shouldRepaint(covariant _AiFlowBackgroundPainter oldDelegate) {
    return oldDelegate.mode != mode ||
        oldDelegate.motion != motion ||
        oldDelegate.progress != progress;
  }
}

class _AiTopBar extends StatelessWidget {
  const _AiTopBar({
    required this.onOpenHistory,
    required this.accountController,
    required this.showProviderStatus,
    required this.provider,
    required this.status,
    required this.onProviderChanged,
  });

  final VoidCallback onOpenHistory;
  final AccountController? accountController;
  final bool showProviderStatus;
  final _AiProvider provider;
  final _AiStatusPresentation status;
  final ValueChanged<_AiProvider> onProviderChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return SizedBox(
      height: 58,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 12,
            top: 8,
            child: _AiRoundButton(
              tooltip: strings.aiHistoryTooltip,
              icon: Icons.history_rounded,
              onPressed: onOpenHistory,
            ),
          ),
          if (showProviderStatus)
            Positioned(
              left: 66,
              right: 66,
              top: 8,
              child: Center(
                child: _AiProviderStatusRow(
                  provider: provider,
                  status: status,
                  compactStatus: true,
                  onProviderChanged: onProviderChanged,
                ),
              ),
            ),
          Positioned(
            right: 12,
            top: 8,
            child: _AiRoundButton(
              tooltip: strings.aiAccountTooltip,
              icon: Icons.manage_accounts_outlined,
              onPressed: () {
                if (accountController == null) {
                  FitLogNotifications.info(
                    context,
                    strings.aiAccountComingSoon,
                  );
                  return;
                }
                showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) {
                    return AnimatedBuilder(
                      animation: accountController!,
                      builder: (context, _) {
                        return _AiAccountStatusSheet(
                          accountController: accountController!,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AiRoundButton extends StatelessWidget {
  const _AiRoundButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = _AiThemePalette.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.70),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 20, color: palette.icon),
          ),
        ),
      ),
    );
  }
}

class _AiCenterStatus extends StatelessWidget {
  const _AiCenterStatus({required this.mode, required this.displayName});

  final AiShellMode mode;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final name = displayName?.trim();

    if (mode == AiShellMode.disabled) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            strings.aiSignInRequired,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF172018),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            strings.aiDisabledBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF647067),
              height: 1.4,
            ),
          ),
        ],
      );
    }

    final listening = strings.aiListening;
    final hasName = name != null && name.isNotEmpty;

    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: listening),
          if (hasName) TextSpan(text: strings.aiListeningNameSeparator),
          if (hasName)
            TextSpan(
              text: name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
        ],
      ),
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w500,
        color: const Color(0xFF111C16),
        letterSpacing: 0,
      ),
    );
  }
}

class _AiComposer extends StatelessWidget {
  const _AiComposer({
    required this.controller,
    required this.provider,
    required this.canSend,
    required this.sending,
    required this.attachedImages,
    required this.mode,
    required this.status,
    required this.hasConversation,
    required this.onProviderChanged,
    required this.onAttachPressed,
    required this.onRemoveAttachment,
    required this.onComposerChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final _AiProvider provider;
  final bool canSend;
  final bool sending;
  final List<PickedFoodImage> attachedImages;
  final AiShellMode mode;
  final _AiStatusPresentation status;
  final bool hasConversation;
  final ValueChanged<_AiProvider> onProviderChanged;
  final VoidCallback onAttachPressed;
  final ValueChanged<int> onRemoveAttachment;
  final ValueChanged<String> onComposerChanged;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final palette = _AiThemePalette.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!hasConversation) ...<Widget>[
          _AiProviderStatusRow(
            provider: provider,
            status: status,
            onProviderChanged: onProviderChanged,
          ),
          const SizedBox(height: 10),
        ],
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final canSubmit =
                canSend &&
                !sending &&
                (value.text.trim().isNotEmpty || attachedImages.isNotEmpty);
            final surfaceColor = Colors.white.withValues(alpha: 0.76);
            final borderColor = Colors.white.withValues(alpha: 0.82);
            return DecoratedBox(
              key: const ValueKey<String>('ai_composer_surface'),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: borderColor, width: 0.8),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF1E3324).withValues(alpha: 0.10),
                    blurRadius: 30,
                    spreadRadius: -4,
                    offset: const Offset(0, 14),
                  ),
                  BoxShadow(
                    color: const Color(0xFF172618).withValues(alpha: 0.035),
                    blurRadius: 1,
                    offset: const Offset(0, 0.5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (attachedImages.isNotEmpty) ...<Widget>[
                      _AiAttachedImagePreview(
                        images: attachedImages,
                        onRemove: onRemoveAttachment,
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Tooltip(
                          message: strings.aiAttachTooltip,
                          child: IconButton(
                            key: const ValueKey<String>(
                              'ai_attach_image_button',
                            ),
                            onPressed: canSend && !sending
                                ? onAttachPressed
                                : null,
                            icon: const Icon(Icons.add_rounded),
                            color: palette.icon,
                            disabledColor: const Color(0xFF9DA89F),
                          ),
                        ),
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 112),
                            child: TextField(
                              key: const ValueKey<String>('ai_composer_field'),
                              controller: controller,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: palette.historyText),
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.newline,
                              onChanged: onComposerChanged,
                              decoration: InputDecoration(
                                hintText: strings.aiComposerHint,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Tooltip(
                          message: strings.aiSendTooltip,
                          child: IconButton.filled(
                            key: const ValueKey<String>('ai_send_button'),
                            onPressed: canSubmit
                                ? () => onSend(value.text)
                                : null,
                            style: IconButton.styleFrom(
                              disabledBackgroundColor:
                                  palette.disabledActionBackground,
                              disabledForegroundColor:
                                  palette.disabledActionForeground,
                              backgroundColor: palette.action,
                              foregroundColor: palette.onAction,
                            ),
                            icon: sending
                                ? SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: palette.onAction,
                                    ),
                                  )
                                : const Icon(Icons.arrow_upward_rounded),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AiAttachedImagePreview extends StatelessWidget {
  const _AiAttachedImagePreview({required this.images, required this.onRemove});

  final List<PickedFoodImage> images;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Align(
      key: const ValueKey<String>('ai_attached_image_preview'),
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (var index = 0; index < images.length; index++)
            _AiAttachedImageThumb(
              image: images[index],
              onRemove: () => onRemove(index),
            ),
        ],
      ),
    );
  }
}

class _AiAttachedImageThumb extends StatelessWidget {
  const _AiAttachedImageThumb({required this.image, required this.onRemove});

  final PickedFoodImage image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(image.bytes, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            right: -6,
            top: -6,
            child: Tooltip(
              message: context.strings.removePhoto,
              child: Material(
                color: Colors.white.withValues(alpha: 0.92),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const SizedBox.square(
                    dimension: 24,
                    child: Icon(Icons.close_rounded, size: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiAccountStatusSheet extends StatelessWidget {
  const _AiAccountStatusSheet({required this.accountController});

  final AccountController accountController;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final auth = accountController.authSession;
    final subscription = accountController.subscriptionStatus;
    final isSignedIn = auth.isSignedIn;
    final localContextAllowed =
        accountController.localContextPermission?.allowed ?? false;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              strings.aiAccountTooltip,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _AiAccountLine(
              icon: Icons.person_outline_rounded,
              label: isSignedIn
                  ? auth.email ?? auth.accountId ?? strings.aiAvailableStatus
                  : strings.aiSignedOutStatus,
            ),
            const SizedBox(height: 8),
            _AiAccountLine(
              icon: Icons.verified_user_outlined,
              label: subscription.isActive
                  ? strings.subscriptionActive
                  : subscription.state == SubscriptionState.error
                  ? strings.subscriptionUnavailable
                  : strings.subscriptionInactive,
            ),
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
              key: const ValueKey<String>('ai_local_context_permission_switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(strings.aiLocalContextPermissionTitle),
              subtitle: Text(strings.aiLocalContextPermissionBody),
              value: localContextAllowed,
              onChanged: isSignedIn
                  ? (allowed) async {
                      try {
                        await accountController.setLocalContextAllowed(allowed);
                      } catch (_) {
                        if (!context.mounted) {
                          return;
                        }
                        FitLogNotifications.error(
                          context,
                          strings.phase2ErrorMessage(
                            'local_context_save_failed',
                          ),
                        );
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            if (!accountController.backendConfigured)
              Text(
                strings.phase2BackendNotConfigured,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF8A6A20),
                  height: 1.35,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              accountController.aiAvailability.canSend
                  ? strings.aiGatewayConnected
                  : strings.aiGatewayPending,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF687568)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiAccountLine extends StatelessWidget {
  const _AiAccountLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: const Color(0xFF4F6250)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _AiProviderStatusRow extends StatelessWidget {
  const _AiProviderStatusRow({
    required this.provider,
    required this.status,
    required this.onProviderChanged,
    this.compactStatus = false,
  });

  final _AiProvider provider;
  final _AiStatusPresentation status;
  final ValueChanged<_AiProvider> onProviderChanged;
  final bool compactStatus;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _AiProviderSelector(provider: provider, onChanged: onProviderChanged),
        const SizedBox(width: 8),
        _AiStatusPill(status: status, compact: compactStatus),
      ],
    );
  }
}

class _AiProviderSelector extends StatelessWidget {
  const _AiProviderSelector({required this.provider, required this.onChanged});

  final _AiProvider provider;
  final ValueChanged<_AiProvider> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final palette = _AiThemePalette.of(context);
    return FitLogSlidingSegmentedControl<_AiProvider>(
      key: const ValueKey<String>('ai_provider_selector'),
      indicatorKey: const ValueKey<String>('ai_provider_indicator'),
      segments: <FitLogSlidingSegment<_AiProvider>>[
        FitLogSlidingSegment<_AiProvider>(
          value: _AiProvider.chatGpt,
          label: strings.aiProviderChatGpt,
          key: const ValueKey<String>('ai_provider_chatgpt'),
        ),
        FitLogSlidingSegment<_AiProvider>(
          value: _AiProvider.qwen,
          label: strings.aiProviderQwen,
          key: const ValueKey<String>('ai_provider_qwen'),
        ),
      ],
      selected: provider,
      onChanged: onChanged,
      backgroundColor: Colors.white.withValues(alpha: 0.54),
      borderColor: Colors.white.withValues(alpha: 0.72),
      indicatorColor: Colors.white.withValues(alpha: 0.86),
      selectedTextColor: palette.providerSelectedText,
      unselectedTextColor: palette.providerText,
    );
  }
}

class _AiStatusPill extends StatelessWidget {
  const _AiStatusPill({required this.status, this.compact = false});

  final _AiStatusPresentation status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = _AiThemePalette.of(context);
    final indicatorColor = switch (status.tone) {
      _AiStatusTone.available => palette.statusAvailableIndicator,
      _AiStatusTone.blocked => const Color(0xFFD58B33),
      _AiStatusTone.unavailable => palette.statusUnavailableIndicator,
    };
    final textColor = switch (status.tone) {
      _AiStatusTone.available => palette.statusAvailableText,
      _AiStatusTone.blocked => const Color(0xFF86551F),
      _AiStatusTone.unavailable => palette.statusUnavailableText,
    };

    return Tooltip(
      message: status.label,
      child: Semantics(
        label: compact ? status.label : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
          ),
          child: Padding(
            padding: compact
                ? const EdgeInsets.all(8)
                : const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  key: const ValueKey<String>('ai_status_indicator'),
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!compact) ...<Widget>[
                  const SizedBox(width: 6),
                  Text(
                    status.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiMessageList extends StatelessWidget {
  const _AiMessageList({
    required this.controller,
    required this.scrollController,
    required this.latestUserKey,
    required this.topPadding,
    required this.bottomPadding,
    required this.sendAnchorBottomPadding,
    required this.scrollingDisabled,
    required this.onOpenFoodDraft,
    required this.onOpenWorkoutDraft,
  });

  final AiChatController controller;
  final ScrollController scrollController;
  final GlobalKey latestUserKey;
  final double topPadding;
  final double bottomPadding;
  final double sendAnchorBottomPadding;
  final bool scrollingDisabled;
  final void Function(AiFoodDraft draft, String? modelProvider) onOpenFoodDraft;
  final ValueChanged<AiWorkoutDraft> onOpenWorkoutDraft;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    bool? previousWasUser;
    final hasPendingUser =
        (controller.pendingUserText ?? '').isNotEmpty ||
        controller.pendingUserAttachments.isNotEmpty;
    final pendingUserKey = hasPendingUser && controller.sending
        ? latestUserKey
        : null;

    void addMessage(Widget child, {required bool isUser}) {
      if (items.isNotEmpty) {
        final startsNextTurn = previousWasUser == false && isUser;
        items.add(SizedBox(height: startsNextTurn ? 14 : 6));
      }
      items.add(child);
      previousWasUser = isUser;
    }

    for (final message in controller.messages) {
      addMessage(
        _AiMessageBubble(
          message: message,
          attachments: controller.runtimeAttachmentsFor(message),
          foodDraft: controller.foodDraftArtifactFor(message),
          workoutDraft: controller.workoutDraftArtifactFor(message),
          evidence: message.gatewayEvidence,
          onOpenFoodDraft: (draft) =>
              onOpenFoodDraft(draft, message.modelProvider),
          onOpenWorkoutDraft: onOpenWorkoutDraft,
        ),
        isUser: message.isUser,
      );
    }
    if (hasPendingUser) {
      final pendingBubble = _AiPendingMessageBubble(
        text: controller.pendingUserText ?? '',
        attachments: controller.pendingUserAttachments,
      );
      addMessage(
        pendingUserKey == null
            ? pendingBubble
            : KeyedSubtree(key: pendingUserKey, child: pendingBubble),
        isUser: true,
      );
    }
    if (controller.sending) {
      addMessage(
        _AiAssistantLoadingBubble(
          hasText: (controller.pendingUserText ?? '').trim().isNotEmpty,
          hasAttachments: controller.pendingUserAttachments.isNotEmpty,
        ),
        isUser: false,
      );
    }
    if (controller.loadingMessages) {
      if (items.isNotEmpty) {
        items.add(const SizedBox(height: 12));
      }
      items.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (sendAnchorBottomPadding > 0) {
      items.add(
        SizedBox(
          key: const ValueKey<String>('ai_send_anchor_fill'),
          height: sendAnchorBottomPadding,
        ),
      );
    }
    if (controller.sending && pendingUserKey != null) {
      _scheduleSendAnchorScroll(
        scrollController,
        pendingUserKey,
        readableTopPadding: topPadding,
      );
    }

    return ListView(
      key: const ValueKey<String>('ai_message_list'),
      controller: scrollController,
      physics: controller.sending || scrollingDisabled
          ? const NeverScrollableScrollPhysics()
          : const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(2, topPadding, 2, bottomPadding),
      children: items,
    );
  }
}

class _AiMessageViewport extends StatelessWidget {
  const _AiMessageViewport({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      key: const ValueKey<String>('ai_message_soft_edges'),
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final height = bounds.height;
        if (height <= 0) {
          return const LinearGradient(
            colors: <Color>[Colors.black, Colors.black],
          ).createShader(bounds);
        }
        final bottomStop = (_aiMessageBottomSoftEdgeHeight / height)
            .clamp(0.0, 0.12)
            .toDouble();
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const <Color>[Colors.black, Colors.black, Colors.transparent],
          stops: <double>[0.0, 1 - bottomStop, 1.0],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}

String _languageForMessage(String messageText, AppStrings strings) {
  final characters = messageText.runes.toList(growable: false);
  final cjkCount = characters.where((code) {
    return (code >= 0x4e00 && code <= 0x9fff) ||
        (code >= 0x3400 && code <= 0x4dbf);
  }).length;
  final asciiLetterCount = characters.where((code) {
    return (code >= 0x41 && code <= 0x5a) || (code >= 0x61 && code <= 0x7a);
  }).length;
  if (cjkCount > 0 && cjkCount >= asciiLetterCount * 0.2) {
    return 'zh';
  }
  if (asciiLetterCount > 0) {
    return 'en';
  }
  return strings.isChinese ? 'zh' : 'en';
}

void _scheduleSendAnchorScroll(
  ScrollController scrollController,
  GlobalKey? pendingUserKey, {
  required double readableTopPadding,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_alignSendAnchorToReadableTop(
      scrollController,
      pendingUserKey,
      readableTopPadding: readableTopPadding,
    )) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _alignSendAnchorToReadableTop(
        scrollController,
        pendingUserKey,
        readableTopPadding: readableTopPadding,
      );
    });
  });
}

bool _alignSendAnchorToReadableTop(
  ScrollController scrollController,
  GlobalKey? pendingUserKey, {
  required double readableTopPadding,
}) {
  final targetContext = pendingUserKey?.currentContext;
  if (targetContext == null || !scrollController.hasClients) {
    return false;
  }
  final targetRenderObject = targetContext.findRenderObject();
  final scrollable = Scrollable.maybeOf(targetContext);
  final viewportRenderObject = scrollable?.context.findRenderObject();
  if (targetRenderObject is! RenderBox ||
      viewportRenderObject is! RenderBox ||
      !targetRenderObject.attached ||
      !viewportRenderObject.attached) {
    return false;
  }
  final position = scrollController.position;
  final targetTop = targetRenderObject.localToGlobal(Offset.zero).dy;
  final viewportTop = viewportRenderObject.localToGlobal(Offset.zero).dy;
  final desiredTop = viewportTop + readableTopPadding;
  final nextOffset = (position.pixels + targetTop - desiredTop)
      .clamp(position.minScrollExtent, position.maxScrollExtent)
      .toDouble();
  if ((nextOffset - position.pixels).abs() > 0.5) {
    scrollController.jumpTo(nextOffset);
  }
  return true;
}

class _AiMessageBubble extends StatelessWidget {
  const _AiMessageBubble({
    required this.message,
    required this.attachments,
    required this.foodDraft,
    required this.workoutDraft,
    required this.evidence,
    required this.onOpenFoodDraft,
    required this.onOpenWorkoutDraft,
  });

  final AiChatMessage message;
  final List<AiGatewayImageAttachment> attachments;
  final AiFoodDraftArtifact? foodDraft;
  final AiWorkoutDraftArtifact? workoutDraft;
  final AiGatewayEvidence? evidence;
  final ValueChanged<AiFoodDraft> onOpenFoodDraft;
  final ValueChanged<AiWorkoutDraft> onOpenWorkoutDraft;

  @override
  Widget build(BuildContext context) {
    return _AiBubbleSurface(
      text: message.contentText,
      isUser: message.isUser,
      pending: false,
      attachments: attachments,
      foodDraft: foodDraft,
      workoutDraft: workoutDraft,
      evidence: evidence,
      onOpenFoodDraft: onOpenFoodDraft,
      onOpenWorkoutDraft: onOpenWorkoutDraft,
    );
  }
}

class _AiPendingMessageBubble extends StatelessWidget {
  const _AiPendingMessageBubble({
    required this.text,
    required this.attachments,
  });

  final String text;
  final List<AiGatewayImageAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    return _AiBubbleSurface(
      text: text,
      isUser: true,
      pending: true,
      attachments: attachments,
    );
  }
}

class _AiBubbleSurface extends StatelessWidget {
  const _AiBubbleSurface({
    required this.text,
    required this.isUser,
    required this.pending,
    this.attachments = const <AiGatewayImageAttachment>[],
    this.foodDraft,
    this.workoutDraft,
    this.evidence,
    this.onOpenFoodDraft,
    this.onOpenWorkoutDraft,
  });

  final String text;
  final bool isUser;
  final bool pending;
  final List<AiGatewayImageAttachment> attachments;
  final AiFoodDraftArtifact? foodDraft;
  final AiWorkoutDraftArtifact? workoutDraft;
  final AiGatewayEvidence? evidence;
  final ValueChanged<AiFoodDraft>? onOpenFoodDraft;
  final ValueChanged<AiWorkoutDraft>? onOpenWorkoutDraft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _AiThemePalette.of(context);
    if (isUser) {
      return _AiUserMessageCluster(
        text: text,
        pending: pending,
        attachments: attachments,
        textColor: palette.onUserBubble,
        bubbleColor: palette.userBubble,
      );
    }
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _AiMarkdownText(
          text: text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: palette.assistantText,
            height: 1.42,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (foodDraft != null) ...[
          const SizedBox(height: 12),
          _AiFoodDraftArtifactCard(
            draft: foodDraft!,
            onPressed: foodDraft!.draft == null || onOpenFoodDraft == null
                ? null
                : () => onOpenFoodDraft!(foodDraft!.draft!),
          ),
        ],
        if (workoutDraft != null) ...[
          const SizedBox(height: 12),
          _AiWorkoutDraftArtifactCard(
            draft: workoutDraft!,
            onPressed: workoutDraft!.draft == null || onOpenWorkoutDraft == null
                ? null
                : () => onOpenWorkoutDraft!(workoutDraft!.draft!),
          ),
        ],
        if (_aiEvidenceHasDisplayableContent(evidence)) ...[
          const SizedBox(height: 10),
          _AiEvidencePanel(evidence: evidence!),
        ],
      ],
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _AiEvidencePanel extends StatelessWidget {
  const _AiEvidencePanel({required this.evidence});

  final AiGatewayEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final palette = _AiThemePalette.of(context);
    final sources = evidence.documentSources.take(4).toList(growable: false);
    final contextObjects = evidence.contextObjects
        .where((item) => item != 'document_context')
        .map((item) => _aiEvidenceDimensionLabel(strings, item))
        .take(5)
        .toList(growable: false);
    final missing = evidence.missingDimensions
        .where(
          (item) =>
              item != 'document_context' ||
              _aiEvidenceShouldShowMissingDocument(evidence, sources.isEmpty),
        )
        .map((item) => _aiEvidenceMissingLabel(strings, item))
        .take(4)
        .toList(growable: false);
    final safety = evidence.safetyFlags
        .map((item) => _aiEvidenceSafetyLabel(strings, item))
        .take(3)
        .toList(growable: false);
    if (sources.isEmpty &&
        contextObjects.isEmpty &&
        missing.isEmpty &&
        safety.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const ValueKey<String>('ai_phase5_evidence'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Divider(height: 1, color: palette.artifactBorder),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.manage_search_rounded,
              size: 16,
              color: palette.markdownAuxText,
            ),
            const SizedBox(width: 6),
            Text(
              strings.aiEvidenceTitle,
              style: theme.textTheme.labelMedium?.copyWith(
                color: palette.markdownAuxText,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ],
        ),
        if (sources.isNotEmpty) ...[
          const SizedBox(height: 7),
          _AiEvidenceLabel(text: strings.aiEvidenceSourcesTitle),
          const SizedBox(height: 5),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: sources
                .map(
                  (source) => _AiEvidenceChip(
                    label: strings.aiEvidenceSourceLabel(
                      _aiEvidenceDocFileName(source.docPath),
                      source.heading,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
        if (contextObjects.isNotEmpty) ...[
          const SizedBox(height: 7),
          _AiEvidenceLabel(text: strings.aiEvidenceContextTitle),
          const SizedBox(height: 5),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: contextObjects
                .map((item) => _AiEvidenceChip(label: item))
                .toList(growable: false),
          ),
        ],
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 7),
          _AiEvidenceLabel(text: strings.aiEvidenceMissingTitle),
          const SizedBox(height: 5),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: missing
                .map((item) => _AiEvidenceChip(label: item))
                .toList(growable: false),
          ),
        ],
        if (safety.isNotEmpty) ...[
          const SizedBox(height: 7),
          _AiEvidenceLabel(text: strings.aiEvidenceSafetyTitle),
          const SizedBox(height: 5),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: safety
                .map((item) => _AiEvidenceChip(label: item))
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}

bool _aiEvidenceHasDisplayableContent(AiGatewayEvidence? evidence) {
  if (evidence == null) {
    return false;
  }
  if (evidence.documentSources.isNotEmpty ||
      evidence.contextObjects.any((item) => item != 'document_context') ||
      evidence.safetyFlags.isNotEmpty) {
    return true;
  }
  return evidence.missingDimensions.any(
    (item) =>
        item != 'document_context' ||
        _aiEvidenceShouldShowMissingDocument(evidence, true),
  );
}

bool _aiEvidenceShouldShowMissingDocument(
  AiGatewayEvidence evidence,
  bool sourcesEmpty,
) {
  return sourcesEmpty && evidence.workflow == 'app_logic_answer';
}

String _aiEvidenceDocFileName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final fileName = normalized.split('/').last.trim();
  if (fileName.toLowerCase().endsWith('.md')) {
    return fileName.substring(0, fileName.length - 3);
  }
  return fileName.isEmpty ? path : fileName;
}

String _aiEvidenceDimensionLabel(AppStrings strings, String key) {
  switch (key) {
    case 'profile_context':
      return strings.isChinese ? '个人档案' : 'Profile';
    case 'selected_day_summary':
      return strings.isChinese ? '当日饮食汇总' : 'Selected-day summary';
    case 'strategy_context':
      return strings.isChinese ? '饮食策略设置' : 'Diet strategy';
    case 'recent_food_summary':
      return strings.isChinese ? '近期饮食摘要' : 'Recent food summary';
    case 'recent_workout_summary':
      return strings.isChinese ? '近期训练摘要' : 'Recent workout summary';
    case 'body_metric_summary':
      return strings.isChinese ? '身体数据摘要' : 'Body-metric summary';
    case 'weight_trend_summary':
      return strings.isChinese ? '体重趋势' : 'Weight trend';
    case 'document_context':
      return strings.isChinese ? '文档来源' : 'Document sources';
    default:
      return _humanizeEvidenceKey(key);
  }
}

String _aiEvidenceMissingLabel(AppStrings strings, String key) {
  switch (key) {
    case 'document_context':
      return strings.isChinese ? '未找到相关文档来源' : 'No matching document source';
    case 'profile_context':
      return strings.isChinese ? '缺少个人档案' : 'Profile unavailable';
    case 'selected_day_summary':
      return strings.isChinese
          ? '缺少当日饮食汇总'
          : 'Selected-day summary unavailable';
    case 'strategy_context':
      return strings.isChinese ? '缺少饮食策略设置' : 'Diet strategy unavailable';
    case 'recent_food_summary':
      return strings.isChinese ? '缺少近期饮食摘要' : 'Recent food summary unavailable';
    case 'recent_workout_summary':
      return strings.isChinese
          ? '缺少近期训练摘要'
          : 'Recent workout summary unavailable';
    case 'body_metric_summary':
      return strings.isChinese ? '缺少身体数据摘要' : 'Body-metric summary unavailable';
    case 'weight_trend_summary':
      return strings.isChinese ? '缺少体重趋势' : 'Weight trend unavailable';
    case 'artifact_review':
      return strings.isChinese ? '缺少草稿复核' : 'Artifact review unavailable';
    default:
      return _humanizeEvidenceKey(key);
  }
}

String _aiEvidenceSafetyLabel(AppStrings strings, String key) {
  switch (key) {
    case 'record_summary_context_not_allowed':
      return strings.isChinese ? '记录摘要未授权' : 'Record-summary permission off';
    case 'strategy_write_requested':
      return strings.isChinese
          ? '策略修改需手动确认'
          : 'Strategy changes need confirmation';
    case 'food_write_requested':
      return strings.isChinese ? '饮食写入需手动确认' : 'Food writes need confirmation';
    case 'workout_write_requested':
      return strings.isChinese
          ? '训练写入需手动确认'
          : 'Workout writes need confirmation';
    case 'profile_write_requested':
      return strings.isChinese
          ? '档案修改需手动确认'
          : 'Profile changes need confirmation';
    case 'provider_claimed_write_blocked':
      return strings.isChinese ? '已拦截模型写入声明' : 'Provider write claim blocked';
    default:
      return _humanizeEvidenceKey(key);
  }
}

String _humanizeEvidenceKey(String key) {
  return key
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _AiEvidenceLabel extends StatelessWidget {
  const _AiEvidenceLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = _AiThemePalette.of(context);
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: palette.markdownAuxText,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
    );
  }
}

class _AiEvidenceChip extends StatelessWidget {
  const _AiEvidenceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = _AiThemePalette.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.markdownCodeBlockBackground.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.artifactBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.markdownAuxText,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _AiUserMessageCluster extends StatelessWidget {
  const _AiUserMessageCluster({
    required this.text,
    required this.pending,
    required this.attachments,
    required this.textColor,
    required this.bubbleColor,
  });

  final String text;
  final bool pending;
  final List<AiGatewayImageAttachment> attachments;
  final Color textColor;
  final Color bubbleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = text.trim();
    final textWidget = trimmed.isEmpty
        ? null
        : SelectableText(
            trimmed,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
              height: 1.42,
              fontWeight: FontWeight.w700,
            ),
          );
    final segments = <Widget>[
      if (attachments.isNotEmpty)
        _AiUserMediaSegment(
          key: const ValueKey<String>('ai_user_attachment_media'),
          attachments: attachments,
        ),
      if (textWidget != null)
        _AiUserBubbleSegment(
          key: const ValueKey<String>('ai_user_text_bubble'),
          color: bubbleColor,
          child: textWidget,
        ),
    ];

    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }

    final child = segments.length == 1
        ? segments.single
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (var index = 0; index < segments.length; index++) ...[
                if (index > 0) const SizedBox(height: 6),
                segments[index],
              ],
            ],
          );

    return Align(
      key: pending ? const ValueKey<String>('ai_pending_user_bubble') : null,
      alignment: Alignment.centerRight,
      child: child,
    );
  }
}

class _AiUserMediaSegment extends StatelessWidget {
  const _AiUserMediaSegment({super.key, required this.attachments});

  final List<AiGatewayImageAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: _AiMessageImageStrip(attachments: attachments),
    );
  }
}

class _AiUserBubbleSegment extends StatelessWidget {
  const _AiUserBubbleSegment({
    super.key,
    required this.color,
    required this.child,
  });

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: child,
        ),
      ),
    );
  }
}

class _AiFoodDraftArtifactCard extends StatelessWidget {
  const _AiFoodDraftArtifactCard({
    required this.draft,
    required this.onPressed,
  });

  final AiFoodDraftArtifact draft;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.strings;
    final palette = _AiThemePalette.of(context);
    final calories = draft.caloriesKcal?.round().toString() ?? '--';
    final enabled = onPressed != null;
    return DecoratedBox(
      key: const ValueKey<String>('ai_food_draft_artifact_card'),
      decoration: BoxDecoration(
        color: enabled
            ? palette.artifactSurface
            : palette.artifactDisabledSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled
              ? palette.artifactBorder
              : palette.artifactDisabledBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              strings.aiFoodDraftCardTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                color: palette.artifactTitle,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              strings.aiFoodDraftCardSummary(draft.mealName, calories),
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.artifactBody,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (draft.date != null) ...[
              const SizedBox(height: 6),
              _AiDraftDateRow(date: draft.date!, color: palette.artifactBody),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: enabled
                      ? palette.action
                      : palette.artifactButtonDisabledBackground,
                  foregroundColor: enabled
                      ? palette.onAction
                      : palette.artifactButtonDisabledForeground,
                  textStyle: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                child: Text(
                  enabled
                      ? strings.aiFoodDraftCardAction
                      : strings.aiFoodDraftCardUnavailable,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiWorkoutDraftArtifactCard extends StatelessWidget {
  const _AiWorkoutDraftArtifactCard({
    required this.draft,
    required this.onPressed,
  });

  final AiWorkoutDraftArtifact draft;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.strings;
    final palette = _AiThemePalette.of(context);
    final enabled = onPressed != null;
    return DecoratedBox(
      key: const ValueKey<String>('ai_workout_draft_artifact_card'),
      decoration: BoxDecoration(
        color: enabled
            ? palette.artifactSurface
            : palette.artifactDisabledSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled
              ? palette.artifactBorder
              : palette.artifactDisabledBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              strings.aiWorkoutDraftCardTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                color: palette.artifactTitle,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              strings.aiWorkoutDraftCardSummary(
                draft.recordName,
                draft.exerciseCount,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.artifactBody,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (draft.date != null) ...[
              const SizedBox(height: 6),
              _AiDraftDateRow(date: draft.date!, color: palette.artifactBody),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: enabled
                      ? palette.action
                      : palette.artifactButtonDisabledBackground,
                  foregroundColor: enabled
                      ? palette.onAction
                      : palette.artifactButtonDisabledForeground,
                  textStyle: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                child: Text(
                  enabled
                      ? strings.aiWorkoutDraftCardAction
                      : strings.aiWorkoutDraftCardUnavailable,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiDraftDateRow extends StatelessWidget {
  const _AiDraftDateRow({required this.date, required this.color});

  final String date;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: ValueKey<String>('ai_draft_date_$date'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.calendar_today_outlined, size: 15, color: color),
        const SizedBox(width: 6),
        Text(
          DateUtilsX.formatReadable(date),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AiMessageImageStrip extends StatelessWidget {
  const _AiMessageImageStrip({required this.attachments});

  final List<AiGatewayImageAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: <Widget>[
        for (var index = 0; index < attachments.length; index++)
          _AiMessageImageThumbnail(
            key: ValueKey<String>(
              'ai_message_image_thumbnail_state_${attachments[index].name}_${attachments[index].byteLength}_$index',
            ),
            attachment: attachments[index],
          ),
      ],
    );
  }
}

class _AiMessageImageThumbnail extends StatefulWidget {
  const _AiMessageImageThumbnail({super.key, required this.attachment});

  final AiGatewayImageAttachment attachment;

  @override
  State<_AiMessageImageThumbnail> createState() =>
      _AiMessageImageThumbnailState();
}

class _AiMessageImageThumbnailState extends State<_AiMessageImageThumbnail> {
  Uint8List? _bytes;
  String? _base64Data;

  @override
  void initState() {
    super.initState();
    _decodeIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _AiMessageImageThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.base64Data != widget.attachment.base64Data) {
      _decodeIfNeeded();
    }
  }

  void _decodeIfNeeded() {
    final base64Data = widget.attachment.base64Data;
    if (_base64Data == base64Data) {
      return;
    }
    _base64Data = base64Data;
    try {
      _bytes = base64Decode(base64Data);
    } catch (_) {
      _bytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      key: const ValueKey<String>('ai_message_image_thumbnail'),
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(14),
        ),
        child: SizedBox(
          width: 112,
          height: 112,
          child: _bytes == null
              ? const Icon(Icons.image_not_supported_rounded)
              : Image.memory(
                  _bytes!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.image_not_supported_rounded),
                ),
        ),
      ),
    );
  }
}

class _AiAssistantLoadingBubble extends StatefulWidget {
  const _AiAssistantLoadingBubble({
    required this.hasText,
    required this.hasAttachments,
  });

  final bool hasText;
  final bool hasAttachments;

  @override
  State<_AiAssistantLoadingBubble> createState() =>
      _AiAssistantLoadingBubbleState();
}

class _AiAssistantLoadingBubbleState extends State<_AiAssistantLoadingBubble> {
  _AiLoadingProgressStage _stage = _AiLoadingProgressStage.sending;
  final List<Timer> _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    _scheduleStageTimers();
  }

  @override
  void didUpdateWidget(covariant _AiAssistantLoadingBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasText != widget.hasText ||
        oldWidget.hasAttachments != widget.hasAttachments) {
      _stage = _AiLoadingProgressStage.sending;
      _scheduleStageTimers();
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  void _scheduleStageTimers() {
    _cancelTimers();
    _timers
      ..add(
        Timer(
          const Duration(milliseconds: 1500),
          () => _setStage(_AiLoadingProgressStage.waiting),
        ),
      )
      ..add(
        Timer(
          const Duration(seconds: 6),
          () => _setStage(_AiLoadingProgressStage.stillWaiting),
        ),
      )
      ..add(
        Timer(
          const Duration(seconds: 12),
          () => _setStage(_AiLoadingProgressStage.slow),
        ),
      );
  }

  void _cancelTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  void _setStage(_AiLoadingProgressStage stage) {
    if (!mounted || _stage == stage) {
      return;
    }
    setState(() => _stage = stage);
  }

  String _label(BuildContext context) {
    final strings = context.strings;
    switch (_stage) {
      case _AiLoadingProgressStage.sending:
        if (widget.hasAttachments && widget.hasText) {
          return strings.aiProgressSendingImagesAndText;
        }
        if (widget.hasAttachments) {
          return strings.aiProgressSendingImageRequest;
        }
        return strings.aiProgressSendingText;
      case _AiLoadingProgressStage.waiting:
        if (widget.hasAttachments) {
          return strings.aiProgressImageMayTakeLonger;
        }
        return strings.aiProgressWaitingForReply;
      case _AiLoadingProgressStage.stillWaiting:
        return strings.aiProgressStillWaiting;
      case _AiLoadingProgressStage.slow:
        return strings.aiProgressSlowResponse;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _AiThemePalette.of(context);
    final label = _label(context);
    return Align(
      key: const ValueKey<String>('ai_assistant_loading_bubble'),
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.action,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    key: const ValueKey<String>('ai_assistant_loading_label'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.icon,
                      fontWeight: FontWeight.w700,
                    ),
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiMarkdownText extends StatelessWidget {
  const _AiMarkdownText({required this.text, required this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? Theme.of(context).textTheme.bodyMedium;
    final palette = _AiThemePalette.of(context);
    return MarkdownBody(
      data: text,
      selectable: true,
      softLineBreak: true,
      onTapLink: (_, _, _) {},
      imageBuilder: (_, _, alt) {
        final label = alt?.trim() ?? '';
        if (label.isEmpty) {
          return const SizedBox.shrink();
        }
        return SelectableText(
          label,
          style: baseStyle?.copyWith(
            color: palette.markdownAuxText,
            fontStyle: FontStyle.italic,
          ),
        );
      },
      styleSheet: _aiMarkdownStyleSheet(context, baseStyle),
    );
  }
}

MarkdownStyleSheet _aiMarkdownStyleSheet(
  BuildContext context,
  TextStyle? baseStyle,
) {
  final theme = Theme.of(context);
  final palette = _AiThemePalette.of(context);
  final base = baseStyle ?? theme.textTheme.bodyMedium ?? const TextStyle();
  final heading = base.copyWith(fontWeight: FontWeight.w800, height: 1.34);
  final code = base.copyWith(
    fontFamily: 'monospace',
    color: palette.markdownCodeText,
    backgroundColor: palette.markdownCodeBackground,
  );
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: base,
    pPadding: EdgeInsets.zero,
    blockSpacing: 8,
    h1: heading.copyWith(fontSize: (base.fontSize ?? 16) * 1.18),
    h1Padding: EdgeInsets.zero,
    h2: heading.copyWith(fontSize: (base.fontSize ?? 16) * 1.12),
    h2Padding: EdgeInsets.zero,
    h3: heading.copyWith(fontSize: (base.fontSize ?? 16) * 1.08),
    h3Padding: EdgeInsets.zero,
    h4: heading.copyWith(fontSize: (base.fontSize ?? 16) * 1.04),
    h4Padding: EdgeInsets.zero,
    h5: heading,
    h5Padding: EdgeInsets.zero,
    h6: heading,
    h6Padding: EdgeInsets.zero,
    strong: base.copyWith(fontWeight: FontWeight.w800),
    em: base.copyWith(fontStyle: FontStyle.italic),
    a: base.copyWith(
      color: palette.artifactTitle,
      decoration: TextDecoration.underline,
    ),
    blockquote: base.copyWith(color: palette.artifactBody),
    blockquotePadding: const EdgeInsets.only(left: 10),
    blockquoteDecoration: BoxDecoration(
      border: Border(left: BorderSide(color: palette.artifactBorder, width: 3)),
    ),
    code: code,
    codeblockPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    codeblockDecoration: BoxDecoration(
      color: palette.markdownCodeBlockBackground,
      borderRadius: BorderRadius.circular(8),
    ),
    listBullet: base.copyWith(fontWeight: FontWeight.w700),
    listIndent: 22,
    tableHead: base.copyWith(fontWeight: FontWeight.w800),
    tableBody: base,
    tableBorder: TableBorder.all(color: palette.markdownTableBorder),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    img: base.copyWith(
      color: palette.markdownAuxText,
      fontStyle: FontStyle.italic,
    ),
  );
}

class _AiHistoryPanel extends StatelessWidget {
  const _AiHistoryPanel({required this.controller, required this.onClose});

  final AiChatController? controller;

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final panelWidth = math.min(MediaQuery.sizeOf(context).width * 0.78, 320.0);

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.10)),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              key: const ValueKey<String>('ai_history_panel'),
              width: panelWidth,
              height: math.max(320.0, MediaQuery.sizeOf(context).height - 140),
              margin: const EdgeInsets.fromLTRB(12, 12, 0, 96),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.90),
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(24),
                  left: Radius.circular(18),
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            strings.aiHistoryTitle,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: _AiThemePalette.of(
                                    context,
                                  ).historyText,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        IconButton(
                          onPressed: onClose,
                          tooltip: strings.close,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (controller == null ||
                        (controller?.accountId ?? '').isEmpty)
                      Text(
                        strings.aiHistorySignedOut,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _AiThemePalette.of(context).mutedText,
                          height: 1.4,
                        ),
                      )
                    else ...<Widget>[
                      Row(
                        children: <Widget>[
                          OutlinedButton.icon(
                            key: const ValueKey<String>('ai_new_chat_button'),
                            onPressed: () {
                              controller!.startNewSession();
                              onClose();
                            },
                            icon: const Icon(Icons.add_rounded),
                            label: Text(strings.aiNewChat),
                          ),
                          const Spacer(),
                          if (controller!.loadingSessions)
                            const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (controller!.sessions.isEmpty)
                        Text(
                          strings.aiHistoryEmpty,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: _AiThemePalette.of(context).mutedText,
                                height: 1.4,
                              ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            itemCount: controller!.sessions.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final session = controller!.sessions[index];
                              final selected =
                                  session.id == controller!.selectedSessionId;
                              return _AiHistoryTile(
                                key: ValueKey<String>(
                                  'ai_history_tile_${session.id}',
                                ),
                                title: session.title.trim().isEmpty
                                    ? strings.aiUntitledChat
                                    : session.title,
                                selected: selected,
                                deleting: controller!.isDeletingSession(
                                  session.id,
                                ),
                                operationsDisabled: controller!.deletingSession,
                                onTap: () {
                                  unawaited(
                                    controller!.selectSession(session.id),
                                  );
                                  onClose();
                                },
                                onRename: (title) => controller!.renameSession(
                                  session.id,
                                  title,
                                ),
                                onDelete: () => _confirmDeleteSession(
                                  context,
                                  controller!,
                                  session.id,
                                  session.title.trim().isEmpty
                                      ? strings.aiUntitledChat
                                      : session.title,
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteSession(
    BuildContext context,
    AiChatController controller,
    String sessionId,
    String title,
  ) async {
    if (controller.deletingSession) {
      return;
    }
    final strings = context.stringsRead;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(strings.aiDeleteChatConfirmTitle),
          content: Text(strings.aiDeleteChatConfirmBody(title)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              key: const ValueKey<String>('ai_confirm_delete_chat_button'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD45D4C),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(strings.delete),
            ),
          ],
        );
      },
    );
    if (confirmed == true && !controller.deletingSession) {
      await controller.deleteSession(sessionId);
    }
  }
}

class _AiHistoryTile extends StatefulWidget {
  const _AiHistoryTile({
    super.key,
    required this.title,
    required this.selected,
    required this.deleting,
    required this.operationsDisabled,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final String title;
  final bool selected;
  final bool deleting;
  final bool operationsDisabled;
  final VoidCallback onTap;
  final Future<bool> Function(String title) onRename;
  final VoidCallback onDelete;

  @override
  State<_AiHistoryTile> createState() => _AiHistoryTileState();
}

class _AiHistoryTileState extends State<_AiHistoryTile> {
  late final TextEditingController _renameController;
  late final FocusNode _renameFocusNode;
  bool _renaming = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _renameController = TextEditingController(text: widget.title);
    _renameFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _AiHistoryTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_renaming && oldWidget.title != widget.title) {
      _renameController.text = widget.title;
    }
  }

  @override
  void dispose() {
    _renameController.dispose();
    _renameFocusNode.dispose();
    super.dispose();
  }

  void _startRename() {
    setState(() {
      _renaming = true;
      _renameController.text = widget.title;
      _renameController.selection = TextSelection.collapsed(
        offset: _renameController.text.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _renameFocusNode.requestFocus();
      }
    });
  }

  void _cancelRename() {
    setState(() {
      _renaming = false;
      _saving = false;
      _renameController.text = widget.title;
    });
  }

  Future<void> _submitRename() async {
    final strings = context.stringsRead;
    final nextTitle = _renameController.text.trim();
    if (nextTitle.isEmpty) {
      FitLogNotifications.error(context, strings.aiRenameChatEmpty);
      return;
    }
    if (nextTitle == widget.title.trim()) {
      _cancelRename();
      return;
    }
    setState(() => _saving = true);
    final success = await widget.onRename(nextTitle);
    if (!mounted) {
      return;
    }
    if (success) {
      setState(() {
        _renaming = false;
        _saving = false;
      });
    } else {
      setState(() => _saving = false);
      FitLogNotifications.error(context, strings.aiRenameChatFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _AiThemePalette.of(context);
    final textColor = widget.selected
        ? palette.historySelectedText
        : palette.historyText;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.selected
            ? palette.historySelectedSurface
            : palette.historySurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _renaming || widget.operationsDisabled ? null : widget.onTap,
          child: SizedBox(
            height: 64,
            child: Row(
              children: <Widget>[
                const SizedBox(width: 12),
                Expanded(child: _buildTitle(context, textColor)),
                IconButton(
                  key: const ValueKey<String>('ai_rename_chat_button'),
                  tooltip: context.strings.aiRenameChat,
                  onPressed: _saving || widget.operationsDisabled
                      ? null
                      : _renaming
                      ? _submitRename
                      : _startRename,
                  icon: Icon(
                    _renaming ? Icons.check_rounded : Icons.edit_outlined,
                    size: 18,
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('ai_delete_chat_button'),
                  tooltip: _renaming
                      ? context.strings.cancel
                      : context.strings.aiDeleteChat,
                  onPressed: _saving || widget.operationsDisabled
                      ? null
                      : _renaming
                      ? _cancelRename
                      : widget.onDelete,
                  icon: widget.deleting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _renaming
                              ? Icons.close_rounded
                              : Icons.delete_outline_rounded,
                          size: 18,
                        ),
                ),
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context, Color textColor) {
    final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: textColor,
      fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w600,
      height: 1.2,
    );
    if (_renaming) {
      return TextField(
        key: const ValueKey<String>('ai_rename_chat_field'),
        controller: _renameController,
        focusNode: _renameFocusNode,
        enabled: !_saving,
        textInputAction: TextInputAction.done,
        maxLength: 80,
        minLines: 1,
        maxLines: 2,
        style: titleStyle,
        cursorColor: _AiThemePalette.of(context).action,
        onSubmitted: (_) => _submitRename(),
        decoration: const InputDecoration(
          counterText: '',
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      );
    }

    return Text(
      widget.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: titleStyle,
    );
  }
}
