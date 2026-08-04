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
    expect(PromptTemplates.aiFoodPromptZh, contains('最高优先级输出与核算规则'));
    expect(PromptTemplates.aiFoodPromptZh, contains('先确定最终 items'));
    expect(PromptTemplates.aiFoodPromptZh, contains('唯一计算来源'));
    expect(PromptTemplates.aiFoodPromptZh, contains('用户当前消息的主要语言'));
    expect(PromptTemplates.aiFoodPromptZh, isNot(contains('自然语言值使用中文')));
    expect(PromptTemplates.aiFoodPromptZh, contains('静默复核'));
    expect(PromptTemplates.aiFoodPromptZh, contains('通常应为 ""'));
    expect(PromptTemplates.aiFoodPromptZh, contains('并列、互补的证据'));
    expect(PromptTemplates.aiFoodPromptZh, contains('对应食物和对应字段'));
    expect(PromptTemplates.aiFoodPromptZh, contains('文字未提到就忽略图片中其他'));
    expect(PromptTemplates.aiFoodPromptEn, contains('standing instructions'));
    expect(PromptTemplates.aiFoodPromptEn, contains('complete JSON'));
    expect(
      PromptTemplates.aiFoodPromptEn,
      contains('Highest-priority output and reconciliation rules'),
    );
    expect(PromptTemplates.aiFoodPromptEn, contains('final items first'));
    expect(PromptTemplates.aiFoodPromptEn, contains('sole source of truth'));
    expect(
      PromptTemplates.aiFoodPromptEn,
      contains("primary language of the user's current message"),
    );
    expect(
      PromptTemplates.aiFoodPromptEn,
      isNot(contains('natural-language values in English')),
    );
    expect(PromptTemplates.aiFoodPromptEn, contains('silently validate'));
    expect(PromptTemplates.aiFoodPromptEn, contains('Normally set it to ""'));
    expect(
      PromptTemplates.aiFoodPromptEn,
      contains('parallel, complementary evidence'),
    );
    expect(
      PromptTemplates.aiFoodPromptEn,
      contains('only for that food and field'),
    );
    expect(
      PromptTemplates.aiFoodPromptEn,
      contains('text did not mention them'),
    );

    expect(
      PromptTemplates.aiFoodPromptZh.indexOf('最终回复只能是一个严格'),
      lessThan(PromptTemplates.aiFoodPromptZh.indexOf('任务与对话状态')),
    );
    expect(
      PromptTemplates.aiFoodPromptZh.indexOf('先确定最终 items'),
      lessThan(PromptTemplates.aiFoodPromptZh.indexOf('total_weight_g 必须')),
    );
    expect(
      PromptTemplates.aiFoodPromptEn.indexOf(
        'final reply must contain exactly',
      ),
      lessThan(
        PromptTemplates.aiFoodPromptEn.indexOf('Task and conversation state'),
      ),
    );
    expect(
      PromptTemplates.aiFoodPromptEn.indexOf('final items first'),
      lessThan(PromptTemplates.aiFoodPromptEn.indexOf('total_weight_g must')),
    );
  });
}
