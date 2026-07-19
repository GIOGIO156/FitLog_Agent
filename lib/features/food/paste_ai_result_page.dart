import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/prompt_templates.dart';
import '../../core/localization/localization_extensions.dart';
import '../../core/theme/fitlog_theme.dart';
import '../../core/widgets/fitlog_modal_backdrop.dart';
import '../../core/widgets/fitlog_notifications.dart';
import '../../core/widgets/glass_panel.dart';
import '../../domain/services/nutrition_calculator.dart';
import 'food_preview_page.dart';

class PasteAiResultPage extends StatefulWidget {
  const PasteAiResultPage({super.key, this.initialDate});

  final String? initialDate;

  @override
  State<PasteAiResultPage> createState() => _PasteAiResultPageState();
}

class _PasteAiResultPageState extends State<PasteAiResultPage>
    with WidgetsBindingObserver {
  final TextEditingController _jsonController = TextEditingController();
  final FocusNode _jsonFocusNode = FocusNode();
  final GlobalKey _jsonEditorKey = GlobalKey();
  bool _isParsing = false;
  bool _openingExpandedEditor = false;
  bool _expandAfterKeyboardCloses = false;
  bool _expandedEditorScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _jsonController.dispose();
    _jsonFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!_expandAfterKeyboardCloses || !mounted) {
      return;
    }
    if (_currentKeyboardInset() > 0.5) {
      return;
    }
    _expandAfterKeyboardCloses = false;
    _scheduleExpandedEditor();
  }

  double _currentKeyboardInset() {
    final view = View.of(context);
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  void _requestExpandedEditor() {
    if (_openingExpandedEditor) {
      return;
    }
    setState(() => _openingExpandedEditor = true);
    _jsonFocusNode.unfocus();
    if (_currentKeyboardInset() > 0.5) {
      _expandAfterKeyboardCloses = true;
      return;
    }
    _scheduleExpandedEditor();
  }

  void _scheduleExpandedEditor() {
    if (_expandedEditorScheduled) {
      return;
    }
    _expandedEditorScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _expandedEditorScheduled = false;
      if (!mounted || !_openingExpandedEditor) {
        return;
      }
      final value = await _showExpandedJsonEditor();
      if (!mounted) {
        return;
      }
      if (value != null) {
        _jsonController.value = value.copyWith(composing: TextRange.empty);
      }
      setState(() => _openingExpandedEditor = false);
    });
  }

  Future<TextEditingValue?> _showExpandedJsonEditor() {
    final strings = context.stringsRead;
    return showGeneralDialog<TextEditingValue>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierLabel: strings.collapseJsonEditor,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _ExpandedPasteJsonEditor(
          initialValue: _jsonController.value,
          title: strings.jsonEditorTitle,
          closeTooltip: strings.collapseJsonEditor,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _copyPrompt() async {
    final language = context.languageController.language;
    await Clipboard.setData(
      ClipboardData(text: PromptTemplates.promptForLanguage(language)),
    );
    if (mounted) {
      FitLogNotifications.success(context, context.stringsRead.promptCopied);
    }
  }

  Future<void> _parseAndPreview() async {
    final strings = context.stringsRead;
    final input = _jsonController.text.trim();

    if (input.isEmpty) {
      FitLogNotifications.error(context, strings.pleasePasteJson);
      return;
    }

    setState(() => _isParsing = true);
    try {
      final parsed = NutritionCalculator.parseAiFoodJson(input);
      final prepared = parsed.copyWith(date: widget.initialDate ?? parsed.date);
      if (!mounted) {
        return;
      }

      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => FoodPreviewPage(initialRecord: prepared),
        ),
      );

      if (saved == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } on FormatException catch (e) {
      if (!mounted) {
        return;
      }
      FitLogNotifications.error(context, strings.parseError(e.message));
    } catch (_) {
      if (!mounted) {
        return;
      }
      FitLogNotifications.error(context, strings.parseErrorGeneric);
    } finally {
      if (mounted) {
        setState(() => _isParsing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: Text(strings.pasteAiResult)),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final strings = context.strings;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRect(
        child: CustomMultiChildLayout(
          delegate: _PasteKeyboardLayoutDelegate(),
          children: <Widget>[
            LayoutId(
              id: _PasteKeyboardLayoutChild.prompt,
              child: _KeyboardGatedContent(
                key: const ValueKey<String>('paste_prompt_supporting_slot'),
                hideWhenKeyboardActive: true,
                child: RepaintBoundary(
                  child: _ReusablePromptSetupCard(
                    title: strings.copyAiFoodPrompt,
                    usageLabel: strings.copyPromptUsageLabel,
                    usageBody: strings.copyPromptUsageBody,
                    recommendationLabel: strings.copyPromptRecommendationLabel,
                    recommendationBody: strings.copyPromptRecommendationBody,
                    actionLabel: strings.copyPromptAction,
                    onCopy: _copyPrompt,
                  ),
                ),
              ),
            ),
            LayoutId(
              id: _PasteKeyboardLayoutChild.editor,
              child: _KeyboardRigidEditor(
                child: RepaintBoundary(
                  child: GlassPanel(
                    key: _jsonEditorKey,
                    padding: const EdgeInsets.all(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        TextField(
                          key: const ValueKey<String>('paste_json_editor'),
                          controller: _jsonController,
                          focusNode: _jsonFocusNode,
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          expands: true,
                          scrollPadding: const EdgeInsets.only(bottom: 12),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                          decoration: const InputDecoration(
                            hintText: '{ "meal_name": "..." }',
                            alignLabelWithHint: true,
                            contentPadding: EdgeInsets.fromLTRB(12, 16, 52, 16),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton(
                            key: const ValueKey<String>(
                              'paste_expand_json_editor',
                            ),
                            tooltip: strings.expandJsonEditor,
                            iconSize: 21,
                            style: _subtleEditorResizeButtonStyle(context),
                            onPressed: _openingExpandedEditor
                                ? null
                                : _requestExpandedEditor,
                            icon: const Icon(Icons.fullscreen_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            LayoutId(
              id: _PasteKeyboardLayoutChild.action,
              child: _KeyboardGatedContent(
                key: const ValueKey<String>('paste_parse_supporting_slot'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FilledButton.icon(
                    key: const ValueKey<String>('paste_ai_parse_button'),
                    onPressed: _isParsing ? null : _parseAndPreview,
                    icon: _isParsing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_fix_high_outlined),
                    label: Text(_isParsing ? strings.parsing : strings.parse),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
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

class _KeyboardRigidEditor extends StatelessWidget {
  const _KeyboardRigidEditor({required this.child});

  static const _actionExtent = 52.0;
  static const _handoffHalfRange = 12.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final translation = _translationForInset(keyboardInset);
    return Transform.translate(offset: Offset(0, -translation), child: child);
  }

  static double _translationForInset(double keyboardInset) {
    final lowerBound = _actionExtent - _handoffHalfRange;
    final upperBound = _actionExtent + _handoffHalfRange;
    if (keyboardInset <= lowerBound) {
      return 0;
    }
    if (keyboardInset >= upperBound) {
      return keyboardInset - _actionExtent;
    }
    final progress = (keyboardInset - lowerBound) / (upperBound - lowerBound);
    return _handoffHalfRange * progress * progress;
  }
}

class _KeyboardGatedContent extends StatelessWidget {
  const _KeyboardGatedContent({
    super.key,
    required this.child,
    this.hideWhenKeyboardActive = false,
  });

  final Widget child;
  final bool hideWhenKeyboardActive;

  static const _promptFadeExtent = 180.0;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardActive = keyboardInset > 0.5;
    final gatedChild = ExcludeSemantics(
      excluding: keyboardActive,
      child: IgnorePointer(
        key: ValueKey<String>(
          hideWhenKeyboardActive
              ? 'paste_prompt_keyboard_guard'
              : 'paste_action_keyboard_guard',
        ),
        ignoring: keyboardActive,
        child: child,
      ),
    );
    if (!hideWhenKeyboardActive) {
      return gatedChild;
    }
    final fadeProgress = (keyboardInset / _promptFadeExtent)
        .clamp(0.0, 1.0)
        .toDouble();
    final opacity = 1 - Curves.easeInOutCubic.transform(fadeProgress);
    return Opacity(
      key: const ValueKey<String>('paste_prompt_keyboard_fade'),
      opacity: opacity,
      child: gatedChild,
    );
  }
}

class _ExpandedPasteJsonEditor extends StatefulWidget {
  const _ExpandedPasteJsonEditor({
    required this.initialValue,
    required this.title,
    required this.closeTooltip,
  });

  final TextEditingValue initialValue;
  final String title;
  final String closeTooltip;

  @override
  State<_ExpandedPasteJsonEditor> createState() =>
      _ExpandedPasteJsonEditorState();
}

class _ExpandedPasteJsonEditorState extends State<_ExpandedPasteJsonEditor> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController.fromValue(widget.initialValue);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).pop(_controller.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope<TextEditingValue>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _close();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: FitLogModalBackdrop(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: GlassPanel(
                    key: const ValueKey<String>('paste_expanded_json_modal'),
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    opaque: true,
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                widget.title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              key: const ValueKey<String>(
                                'paste_collapse_json_editor',
                              ),
                              tooltip: widget.closeTooltip,
                              iconSize: 21,
                              style: _subtleEditorResizeButtonStyle(context),
                              onPressed: _close,
                              icon: const Icon(Icons.fullscreen_exit_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: TextField(
                            key: const ValueKey<String>(
                              'paste_expanded_json_field',
                            ),
                            controller: _controller,
                            focusNode: _focusNode,
                            autofocus: false,
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            expands: true,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              hintText: '{ "meal_name": "..." }',
                              alignLabelWithHint: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

ButtonStyle _subtleEditorResizeButtonStyle(BuildContext context) {
  final fitTheme = context.fitLogTheme;
  return IconButton.styleFrom(
    foregroundColor: fitTheme.textSecondary,
    backgroundColor: fitTheme.surfaceVariant.withValues(
      alpha: fitTheme.isDark ? 0.56 : 0.72,
    ),
    disabledForegroundColor: fitTheme.disabledText,
    disabledBackgroundColor: fitTheme.surfaceVariant.withValues(alpha: 0.36),
    minimumSize: const Size.square(40),
    maximumSize: const Size.square(40),
    padding: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

enum _PasteKeyboardLayoutChild { prompt, editor, action }

class _PasteKeyboardLayoutDelegate extends MultiChildLayoutDelegate {
  static const _minimumEditorHeight = 72.0;

  @override
  void performLayout(Size size) {
    final childConstraints = BoxConstraints(
      minWidth: size.width,
      maxWidth: size.width,
      maxHeight: double.infinity,
    );
    final promptSize = layoutChild(
      _PasteKeyboardLayoutChild.prompt,
      childConstraints,
    );
    final actionSize = layoutChild(
      _PasteKeyboardLayoutChild.action,
      childConstraints,
    );
    final promptExtent = promptSize.height.clamp(
      0.0,
      (size.height - actionSize.height - _minimumEditorHeight).clamp(
        0.0,
        double.infinity,
      ),
    );
    final editorHeight = (size.height - promptExtent - actionSize.height).clamp(
      0.0,
      double.infinity,
    );
    layoutChild(
      _PasteKeyboardLayoutChild.editor,
      BoxConstraints.tightFor(width: size.width, height: editorHeight),
    );

    positionChild(_PasteKeyboardLayoutChild.prompt, Offset.zero);
    positionChild(_PasteKeyboardLayoutChild.editor, Offset(0, promptExtent));
    positionChild(
      _PasteKeyboardLayoutChild.action,
      Offset(0, size.height - actionSize.height),
    );
  }

  @override
  bool shouldRelayout(covariant _PasteKeyboardLayoutDelegate oldDelegate) {
    return false;
  }
}

class _ReusablePromptSetupCard extends StatelessWidget {
  const _ReusablePromptSetupCard({
    required this.title,
    required this.usageLabel,
    required this.usageBody,
    required this.recommendationLabel,
    required this.recommendationBody,
    required this.actionLabel,
    required this.onCopy,
  });

  final String title;
  final String usageLabel;
  final String usageBody;
  final String recommendationLabel;
  final String recommendationBody;
  final String actionLabel;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          DecoratedBox(
            key: const ValueKey<String>('paste_prompt_instruction_panel'),
            decoration: BoxDecoration(
              color: fitTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: fitTheme.outlineSubtle),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _PromptInstructionSection(
                    step: '1',
                    label: usageLabel,
                    body: usageBody,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: fitTheme.outlineSubtle),
                  ),
                  _PromptInstructionSection(
                    step: '2',
                    label: recommendationLabel,
                    body: recommendationBody,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              key: const ValueKey<String>('paste_copy_food_prompt_action'),
              onPressed: onCopy,
              icon: const Icon(Icons.content_copy_rounded),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptInstructionSection extends StatelessWidget {
  const _PromptInstructionSection({
    required this.step,
    required this.label,
    required this.body,
  });

  final String step;
  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 22,
          child: Text(
            step,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: fitTheme.primaryDeep,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: fitTheme.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
