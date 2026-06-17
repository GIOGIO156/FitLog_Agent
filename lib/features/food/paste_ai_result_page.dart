import 'package:flutter/material.dart';

import '../../core/localization/localization_extensions.dart';
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

  Future<void> _parseAndPreview() async {
    final strings = context.stringsRead;
    final input = _jsonController.text.trim();

    if (input.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.pleasePasteJson)));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.parseError(e.message))));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.parseErrorGeneric)));
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
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    strings.pasteInstruction,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.45),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          strings.recommendedGpt,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(strings.recommendedGptHint),
                      ],
                    ),
                  ),
                ],
              ),
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
