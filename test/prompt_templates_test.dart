import 'package:fitlog_local/core/constants/prompt_templates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('food prompts establish a reusable JSON-only chat contract', () {
    for (final prompt in <String>[
      PromptTemplates.aiFoodPromptZh,
      PromptTemplates.aiFoodPromptEn,
    ]) {
      expect(prompt, contains('"estimation_notes": ""'));
      expect(prompt, isNot(contains('"comment"')));
      expect(prompt, contains('items'));
    }

    expect(PromptTemplates.aiFoodPromptZh, contains('长期规则'));
    expect(PromptTemplates.aiFoodPromptZh, contains('完整 JSON'));
    expect(PromptTemplates.aiFoodPromptZh, contains('静默复核'));
    expect(PromptTemplates.aiFoodPromptZh, contains('通常应为 ""'));
    expect(PromptTemplates.aiFoodPromptEn, contains('standing instructions'));
    expect(PromptTemplates.aiFoodPromptEn, contains('complete JSON'));
    expect(PromptTemplates.aiFoodPromptEn, contains('silently validate'));
    expect(PromptTemplates.aiFoodPromptEn, contains('Normally set it to ""'));
  });
}
