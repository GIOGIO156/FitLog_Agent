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
  bool _isParsing = false;

  @override
  void dispose() {
    _jsonController.dispose();
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
      appBar: AppBar(title: Text(strings.pasteAiResult)),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ReusablePromptSetupCard(
              title: strings.copyAiFoodPrompt,
              badge: strings.copyPromptOneTimeBadge,
              body: strings.copyPromptSubtitle,
              actionLabel: strings.copyPromptAction,
              onCopy: _copyPrompt,
            ),
            Expanded(
              child: GlassPanel(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _jsonController,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: '{ "meal_name": "..." }',
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: FilledButton.icon(
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
          ],
        ),
      ),
    );
  }
}

class _ReusablePromptSetupCard extends StatelessWidget {
  const _ReusablePromptSetupCard({
    required this.title,
    required this.badge,
    required this.body,
    required this.actionLabel,
    required this.onCopy,
  });

  final String title;
  final String badge;
  final String body;
  final String actionLabel;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: fitTheme.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.forum_outlined, color: fitTheme.primaryDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: fitTheme.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    badge,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: fitTheme.primaryDeep,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
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
