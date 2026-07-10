# 方法论

## 目标

本文解释 FitLog_Agent V1 为什么使用当前饮食、训练和 AI 辅助方法。它面向想在相信数字或 AI workflow 前理解背后逻辑的用户和维护者。

FitLog_Agent 是记录、估算和决策辅助工具。它不提供医疗诊断、治疗，也不能替代合格专业人士建议。

文中的 [REF-ALG-01](References.md) 等标记指向 [References](References.md)，那里记录了来源和证据边界。

## 核心思路

FitLog 把四件事分开：

1. 目标阶段：用户是在 cutting 还是 bulking。
2. 基础计算方法：每日目标是 kcal-first 还是 macro-first。
3. 策略层：基础目标存在后，是否重分配或复盘碳水。
4. AI 辅助：用户是否主动请求云端 AI 生成草稿、解释、复盘或检索上下文。

这种分离很重要，因为用户需要知道哪个数字或设置是正式的。AI 可以帮助解释情况，但正式目标和已保存记录仍由确定性 App 逻辑和用户确认控制。

## V1 为什么需要 AI

Local App 已经能处理确定性记录和计算。许多用户真正困难的不是公式，而是把复杂现实转成可用记录和决策。

AI 帮助：

- 从文字或图片估算混合餐
- 食物信息不完整时追问
- 把不确定餐食信息变成可编辑草稿
- 解释今天剩余目标意味着什么
- 总结近期模式
- 回答 App 如何工作

AI 不替代：

- 正式饮食目标
- 已保存饮食记录
- 已保存训练记录
- Profile 设置
- 碳水策略设置
- 破坏性操作

原因很简单：AI 适合解释和辅助，但正式数据应可审计、由用户控制。

## 为什么需要 RAG

有些用户问题不能只靠 prompt 回答好。

例子：

- “为什么最近没瘦？”
- “今天下一餐能吃什么？”
- “为什么这个模式下 kcal 不是主目标？”
- “这个 App 里的 carb tapering 是什么？”

这些问题需要上下文：

- 近期摄入
- 训练模式
- 体重趋势
- 当前 Profile
- 当前饮食模式
- 当前策略
- 相关 App 文档

FitLog_Agent 使用两种受控检索：

- Structured RAG：已知 function 从云端正式记录、daily summaries 或受控 summary builder 构建紧凑摘要。
- Document RAG：检索相关 FitLog 文档片段。

当前 Document RAG 使用关键词、全文、trigram 和 term-overlap 检索。未来可以只对 App 文档评估 vector/semantic retrieval，但这不授权用户 food/workout/weight 数据向量库。基于业务记录的长期 semantic memory 不在 V1 范围内。工程细节见 `RAGDesign.md`。

## 为什么 AI 要追问

饮食估算经常不明确。照片或短描述可能看不出：

- 肉类类型
- 分量
- 油/酱汁用量
- 生重还是熟重
- 用户是否全部吃完
- 食材是否去掉或替换

当缺失信息会明显影响估算时，AI 应该追问。这比假装精确更能保护用户信任。

## `energy_ratio`：kcal-first planning

`energy_ratio` 适合希望 kcal target、intake 和 remaining kcal 成为主信号的用户。

它的流程：

```text
BMR estimate
-> default no-exercise baseline or calibrated baseline
-> cutting deficit or bulking surplus
-> add logged net exercise calories
-> split final kcal target into protein/carbs/fat by percentage
```

为什么存在：

- 很多饮食计划从能量平衡出发：cutting 低于维持，bulking 高于维持 [REF-ALG-07](References.md)。
- 当 kcal 是主目标时，宏量百分比容易理解 [REF-ALG-04](References.md)。
- 因为基线是无运动日基线，logged exercise 可以作为额外可摄入量加回。

用户需要知道：

- `diet_goal_phase = cutting` 时，`daily_energy_goal_kcal` 被解释为 deficit。
- `diet_goal_phase = bulking` 时，`daily_energy_goal_kcal` 被解释为 surplus。
- kcal target/intake/remaining 是主计数器。
- 宏量克数由 kcal target 和宏量百分比推导。
- BMR 和 lifestyle factor 是估算，不是精确测量 [REF-ALG-01](References.md), [REF-ALG-02](References.md)。

## `gram_per_kg`：macro-first planning

`gram_per_kg` 适合希望 protein、carbs、fat 克数成为主目标的用户。

它的流程：

```text
bodyweight
-> goal phase
-> sex option
-> coarse training-frequency tier
-> protein/carbs/fat g/kg table
-> macro gram targets
```

为什么存在：

- 训练导向用户经常用每公斤体重克数理解宏量 [REF-ALG-05](References.md), [REF-ALG-06](References.md)。
- 蛋白和碳水需求往往更自然地随体型和训练上下文变化 [REF-ALG-06](References.md), [REF-ALG-15](References.md)。
- 当用户关心直接打中克数时，macro-first 更容易执行。

用户需要知道：

- 它不使用 BMR、activity level、daily deficit/surplus、logged exercise calories 或 macro percentages。
- `training_frequency_per_week` 是粗略查表 tier，不是精确强度或训练年限指标。
- `prefer_not_to_say` 使用同 tier male/female 平均值。
- 宏量克数是主目标。
- kcal 是辅助信息，因为它只是宏量目标的能量等价值 [REF-ALG-03](References.md)。

## 为什么两种饮食模式不能混合

两种模式回答的问题不同。

`energy_ratio` 问：

```text
Given my kcal target, how many grams of protein/carbs/fat should I eat?
```

`gram_per_kg` 问：

```text
Given my bodyweight and training context, what protein/carbs/fat gram targets should I aim for?
```

两者都可以有用，但同一时间只能有一个主目标。如果 App 让两套系统同时控制同一个目标，用户会看到互相冲突的信号。

## Carb Cycling

`carb_cycling` 是 cutting 的策略层。它在基础目标计算后，对一周内碳水做重新分配。

流程：

```text
base carbs
-> choose high / medium / low days
-> normalize the 7-day multipliers
-> raise carbs on some days and lower them on others
-> keep weekly average carbs controlled
```

为什么存在：

- 有些用户希望高强度训练日吃更多碳水，轻松日吃更少。
- 碳水需求会随训练需求变化 [REF-ALG-15](References.md)。
- 周平均标准化可以避免隐形超吃或过度限制。

用户需要知道：

- Carb cycling 不是神奇减脂方法。
- 如果周摄入和执行很差，它不能补偿。
- 蛋白和脂肪保持稳定，移动的是碳水。
- FitLog 有 carb floor：`max(weightKg * 1.2, 100)`。
- AI 可以解释当天 day type，但不能改计划。

## Carb Tapering

`carb_tapering` 是 cutting 的复盘策略。它不会自动替用户节食。

流程：

```text
review recent weight trend
-> check food-log coverage
-> check training stability
-> compare current loss rate with target range
-> suggest keep, decrease carbs, pause taper, or no action
-> wait for user confirmation
```

为什么存在：

- Cutting 往往需要随时间小幅调整。
- 静态体重变化规则有明显限制 [REF-ALG-11](References.md), [REF-ALG-19](References.md)。
- 体重会受水分、食物体积、钠、消化和训练压力影响 [REF-ALG-20](References.md)。
- 用户确认可以防止 App 或 AI 静默把计划收紧。

用户需要知道：

- FitLog 使用滚动趋势，不看单次称重。
- 饮食记录覆盖率很重要。
- 训练稳定性很重要。
- 数据弱时应返回 `no_data`，而不是假装确定。
- 如果掉重太快，FitLog 可能建议 `pause_taper`。
- 如果 carbs 低于安全下限，App 会阻止继续降低。
- AI 可以在 Weekly Review 中讨论 taper 状态，但正式应用仍需要用户确认。

## 为什么训练热量是净热量

FitLog 尽量避免重复计算静息消耗。

有氧会减去 1 MET：

```text
netMet = max(0, MET - 1)
```

这是基于 MET 惯例的本地产品选择 [REF-ALG-08](References.md), [REF-ALG-09](References.md)。它让 logged exercise 成为无运动基线之外的额外消耗，而不是重复计算静息能量。

力量训练使用项目启发式：标准化容量、动作 profile、体重参与程度和有边界的 recovery modifiers。它是估算，不是实验室测量。

## 为什么使用 Cloud Profile

Agent V1 需要账号绑定的 AI 个性化：

- AI 页面需要登录和订阅
- chat history 跟账号走
- AI Gateway 需要稳定 profile context
- 订阅和滥用控制在服务端

因此，登录后 Cloud Profile 是权威版本。设备可以缓存用于展示。V1 禁止离线保存 Profile，所以不会产生 profile merge conflict。

对于登录账号，body、food 和 workout 正式记录以云端为权威来源。本地 SQLite 只做 partial cache、草稿和运行期加速，不做完整历史镜像。当 AI 需要近期上下文时，FitLog 发送受控云端 builder 生成的紧凑摘要，而不是完整原始历史。工程规则见 `CloudLocalDataBoundary.md`。

## 为什么需要用户确认

AI 估算可以有用，也可能出错。用户确认保护：

- 数据质量
- 隐私预期
- 饮食安全
- 意外写入
- 意外策略修改
- 用户自主权

App 应把 AI 输出视为：

- 回答
- 解释
- 草稿
- 复盘
- 建议

只有确认后的草稿或正常 UI 确认动作才变成正式数据。

## 限制

- 营养标签和食物估算都只是近似。
- BMR、TDEE、MET 和 g/kg 范围都是估算。
- 力量热量计算是实用启发式。
- 体重趋势有噪声。
- AI 输出可能错误或不完整。
- 重要信息缺失时，AI 应追问。
- App 不是医疗建议。

## 阅读更多

- 稳定产品行为：`Product.md`
- App 导航和页面职责：`AppGuide.md`
- 算法公式：`Algorithm.md`
- 存储边界：`Database.md`
- AI 与 Agent 边界：`AgentDesign.md`
- AI output contract 与校验：`AIOutputContract.md`
- Context、retrieval 与 evidence：`RAGDesign.md`
- 证据边界：`References.md`
