import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/prompt_templates.dart';
import '../../core/localization/localization_extensions.dart';
import '../../core/theme/fitlog_theme.dart';
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

class _PasteAiResultPageState extends State<PasteAiResultPage> {
  final TextEditingController _jsonController = TextEditingController();
  final FocusNode _jsonFocusNode = FocusNode();
  final GlobalKey _jsonEditorKey = GlobalKey();
  bool _isParsing = false;

  @override
  void dispose() {
    _jsonController.dispose();
    _jsonFocusNode.dispose();
    super.dispose();
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
              child: _KeyboardSupportingContent(
                key: const ValueKey<String>('paste_prompt_supporting_slot'),
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
                child: GlassPanel(
                  key: _jsonEditorKey,
                  padding: const EdgeInsets.all(12),
                  child: TextField(
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
                    ),
                  ),
                ),
              ),
            ),
            LayoutId(
              id: _PasteKeyboardLayoutChild.action,
              child: _KeyboardSupportingContent(
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

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final translation = (keyboardInset - _actionExtent).clamp(
      0.0,
      double.infinity,
    );
    return Transform.translate(offset: Offset(0, -translation), child: child);
  }
}

class _KeyboardSupportingContent extends StatelessWidget {
  const _KeyboardSupportingContent({super.key, required this.child});

  static const _fadeTravel = 96.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final opacity = (1 - keyboardInset / _fadeTravel)
        .clamp(0.0, 1.0)
        .toDouble();
    final hidden = opacity <= 0.01;
    final keyboardActive = keyboardInset > 0.5;
    return ExcludeSemantics(
      excluding: hidden,
      child: IgnorePointer(
        ignoring: keyboardActive,
        child: Opacity(opacity: opacity, child: child),
      ),
    );
  }
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
