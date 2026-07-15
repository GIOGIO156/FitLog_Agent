# FitLog Local

## 中文

### 概览

FitLog Local 是一款 local-first 的 Flutter 个人饮食与训练记录 App。它的职责不是在 App 内运行 AI，而是把食物估算、训练记录、饮食目标、剩余宏量和复盘信号整理成一个可长期维护的本地工作流。

它解决的实际问题有三类：

1. 真实饮食很难估算，因为外卖、食堂、混合菜、部分食用、剩饭和非包装食物很难直接对应营养标签。
2. 外部 AI 的食物估算如果只停留在聊天记录里，就很难沉淀成长期结构化记录。
3. 当摄入、运动、饮食阶段、计算模式和策略上下文被放在一起展示时，每日 kcal 和宏量目标更容易转化为行动判断。

推荐使用流程是：

1. 用任意外部多模态模型，或项目提供的 GPT 链接，根据照片或描述估算一餐。
2. 需要时复制 FitLog 内置 Prompt，让外部模型输出结构化 JSON。
3. 把 JSON 粘贴进 FitLog Local，预览、修正，并保存到本地 SQLite。
4. 在本地记录训练，包括有氧时长和力量训练组。
5. 查看选中日期的摄入、运动、目标、剩余宏量和策略上下文。
6. 需要时导出本地 XLSX 或 CSV ZIP 数据。

### 当前范围

FitLog Local 当前提供：

- 本地饮食记录、手动录入、外部 AI JSON 粘贴、预览编辑、复制到指定日期和删除
- 本地训练记录，支持命名的多动作训练记录、内置和可复用自定义动作、独立的自定义动作分组与组内左滑删除、有氧时长与强度、力量组输入口径、仅保存已完成组、保存后摘要和记录编辑
- 每日看板，展示摄入、运动消耗、BMR、非运动 TDEE 参考、目标、剩余 kcal/宏量和选中日期记录
- Profile 设置，管理身体数据、语言、饮食阶段、饮食计算模式、饮食策略、共享训练频率自检、导出和清空本地数据
- 本地确定性饮食策略：`carb_cycling` 和 `carb_tapering`
- XLSX 导出和 CSV ZIP 导出

FitLog Local 当前不提供：

- 后端、云同步、账号系统、远程数据库或多设备同步
- App 内 OpenAI/Gemini/LLM API 调用
- 向量数据库、RAG、tool calling、语义记忆或 Agent loop
- 自动配餐、自动修改目标或 AI Coach
- 医疗建议或儿童青少年治疗指导
- App 内图片识别；`Photo AI Analysis` 仍只是占位入口

### 核心功能

饮食记录：

- `Paste AI Result` 把外部模型 JSON 解析为本地 `FoodRecord` 和 `FoodItem` 数据。
- `Manual Entry` 记录餐名、日期、重量、kcal、蛋白质、碳水、脂肪和备注。
- 内置 Prompt 可按中文或英文复制，并用于任意外部模型。
- 已有饮食记录可以打开、编辑、复制到指定日期或删除。

训练记录：

- 保存后的训练使用面向用户的名称 `Workout Record`。
- 一条保存记录可以包含多个动作，内部仍通过共享 `plan_id` 分组。
- 同一记录内的每条 session 都保存相同 `record_name`，以保持加法式 schema 兼容。
- 创建和编辑时保留用户的动作选择顺序。
- 力量动作使用包含重量、次数或单组时长、完成状态和当次输入口径快照的组行。
- 内置和自定义力量动作区分总重量、每侧重量、自重加重、辅助重量、总次数和每侧次数。
- 力量训练保存时只持久化已完成组；未勾选组会被丢弃，保存后的组号重新编号。
- 有氧动作使用每个动作自己的时长和本次强度，不使用组清单。
- 间歇或极高强度有氧使用实际运动时长，避免把休息时间按极高强度计算。
- 已保存的可复用自定义动作显示在单独的动作库分组里，并可在该分组内通过左滑删除和确认从未来选择中隐藏。
- 保存后的记录展示摘要：总时长、总训练量、总组数和估算消耗。

首页：

- Home、Food Log 和 Workout Log 共享选中日期。
- `energy_ratio` 模式下，kcal 目标/摄入/剩余是主计数器。
- `gram_per_kg` 模式下，宏量克数是主计数器，kcal 只作为辅助摄入信息。
- 看板展示当前饮食阶段、计算模式、策略上下文、饮食记录和训练记录。

Profile：

- 保存年龄、身高、体重、性别选项、共享训练频率设置、饮食阶段、计算模式、宏量比例、自检设置、兼容活动元数据和策略设置。
- `diet_goal_phase` 是 cutting/bulking 语义的唯一来源。
- 未成年人保护会阻止成人式减脂赤字行为和减脂碳水策略。
- 导出和清空本地数据都只作用于本地。

### 饮食模型

饮食设置分为三层：

```text
diet_goal_phase:
  - cutting
  - bulking

diet_calculation_mode:
  - energy_ratio
  - gram_per_kg

diet_plan_strategy:
  - none
  - carb_cycling
  - carb_tapering
```

关键边界：

- `diet_goal_phase` 决定 `daily_energy_goal_kcal` 表示赤字还是盈余。
- `energy_ratio` 使用 BMR、基于训练频率的默认非运动系数、`daily_energy_goal_kcal`、已记录净运动消耗和宏量百分比。
- `gram_per_kg` 使用体重、性别选项和 `training_frequency_per_week` 查表。
- `gram_per_kg` 不使用 BMR、活动水平、每日热量目标、已记录运动热量或宏量百分比。
- 训练频率自检会在两种饮食模式下复盘近期训练记录，并对共享的 `training_frequency_per_week` 设置给出建议。
- 在 `gram_per_kg` 模式下，`macro_energy_equivalent_kcal = protein*4 + carbs*4 + fat*9` 只是辅助分析/导出数据，不是 kcal 目标计数器。
- `carb_cycling` 和 `carb_tapering` 是本地确定性策略层，只在基础目标算出后应用。
- `carb_tapering` 可以提出复盘建议，但不会在没有用户确认的情况下自动应用。

### 为什么这样计算

FitLog 保持方法分离，是为了让用户清楚知道哪个数字才是来源。`energy_ratio` 是 kcal 优先：它从估算的基础能量开始，应用减脂赤字或增肌盈余，加上已记录净运动消耗，再把结果换算成宏量克数。在这个模式里，默认非运动系数现在来自共享训练频率设置；如果本地校准已经根据历史学到更合适的系数，则仍以校准值优先。`gram_per_kg` 是宏量优先：它用体重和粗略训练频率档位设定蛋白质、碳水和脂肪，所以 kcal 是辅助信息，不是主计数器。

碳水策略也被有意限制。`carb_cycling` 只是在 high/medium/low 日之间重新分配一周碳水；它不是神奇燃脂规则。`carb_tapering` 会复盘滚动体重趋势、饮食记录覆盖率和训练稳定性，然后等待用户确认，才会应用任何碳水下调。

运动消耗使用额外净消耗。每日基线已经包含静息能量消耗，所以有氧会减去运动时间里的静息部分（`MET - 1`），避免把同一份静息热量算两次。有氧强度使用“保持这次速度/节奏还能连续维持多久”的具体选择，而不是只靠主观轻中高。力量训练以训练量为主，而不是单纯按分钟计算，因为休息时间、负荷、次数、输入口径和动作类型都比时长本身更重要。

面向用户的完整解释见 [Methodology](../zh/Methodology.md)。实现公式见 [Algorithm](../zh/Algorithm.md)。证据来源和边界见 [References](../zh/References.md)。

### 技术栈

- Flutter + Dart
- SQLite via `sqflite`
- `provider` 用于应用服务和 UI 状态
- `shared_preferences` 保存语言偏好
- `excel` 用于 XLSX 导出
- `csv` 和 `archive` 用于 CSV ZIP 导出

### 快速开始

环境要求：

- Flutter 3.x
- Dart 3.x
- Android Studio 或 VS Code
- Android 模拟器或真机，当前以 Android 工作流优先

常用命令：

```bash
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --debug
```

### 设计文档

| 文件 | 用途 |
| --- | --- |
| [README.md](../../README.md) | 项目概览、当前范围、方法入口说明、快速开始和文档地图。 |
| [CHANGELOG.md](../../CHANGELOG.md) | 纯英文按日期记录用户可见行为、数据、算法和文档变更；复杂错误可记录排查线索和经验教训。 |
| [docs/en/Product.md](../en/Product.md) / [docs/zh/Product.md](../zh/Product.md) | 产品范围、模块、流程、UX 行为、已实现边界和非目标。 |
| [docs/en/AppGuide.md](../en/AppGuide.md) / [docs/zh/AppGuide.md](../zh/AppGuide.md) | 按 App 板块解释每个模块做什么、背后大致如何工作、以及去哪里继续阅读。 |
| [docs/en/Methodology.md](../en/Methodology.md) / [docs/zh/Methodology.md](../zh/Methodology.md) | 面向用户解释 FitLog 为什么使用这些饮食、碳水策略和运动消耗方法。 |
| [docs/en/Algorithm.md](../en/Algorithm.md) / [docs/zh/Algorithm.md](../zh/Algorithm.md) | 工程级公式、饮食模式、运动消耗逻辑、校准、自检和算法边界。 |
| [docs/en/Database.md](../en/Database.md) / [docs/zh/Database.md](../zh/Database.md) | SQLite schema、迁移、表、字段、运行时聚合、数据流和导出覆盖。 |
| [docs/en/AgentDesign.md](../en/AgentDesign.md) / [docs/zh/AgentDesign.md](../zh/AgentDesign.md) | 当前 AI/Agent 边界：外部 AI 辅助输入和 App 内本地确定性逻辑的区别。 |
| [docs/en/References.md](../en/References.md) / [docs/zh/References.md](../zh/References.md) | 外部证据、引用边界和每个来源支持的具体内容。 |

英文设计文档在 `docs/en/` 下保持同等内容。

### 隐私与安全

- 业务数据默认存储在本地 SQLite。
- 导出文件写入 App 文档目录下的本地文件。
- 营养与运动数值都是个人记录用途的估算值。
- 本 App 不提供医疗建议。
- 用户可以在 FitLog Local 外部使用外部 AI，但 App 本身不调用 AI API。

## English

### Overview

FitLog Local is a local-first Flutter app for personal food and workout logging. Its job is not to run AI inside the app. Its job is to turn food estimates, workout records, diet targets, remaining macros, and review signals into a durable local workflow.

The practical problem is threefold:

1. Real meals are hard to estimate because takeout, cafeteria food, mixed dishes, partial portions, leftovers, and non-packaged meals rarely map cleanly to nutrition labels.
2. External AI food estimates are easy to lose if they stay in chat history instead of becoming structured records.
3. Daily kcal and macro targets are easier to act on when intake, exercise, diet phase, calculation mode, and strategy context are shown together.

The intended workflow is:

1. Use any external multimodal model, or the provided GPT links, to estimate a meal from a photo or description.
2. Copy FitLog's prompt when useful and ask the external model for structured JSON.
3. Paste the JSON into FitLog Local, preview it, correct it, and save it to local SQLite.
4. Log workouts locally, including cardio duration and strength sets.
5. Review the selected day's intake, exercise, targets, remaining macros, and strategy context.
6. Export local data as XLSX or CSV ZIP when needed.

### Current Scope

FitLog Local currently provides:

- local food records, manual food entry, external AI JSON paste, preview/edit, copy-to-date, and delete
- local workout records with named multi-exercise records, built-in and reusable custom exercises, a dedicated custom-exercise picker group with inline swipe-to-delete for saved custom entries, cardio duration and intensity, strength set input modes, completed-set persistence, saved-record summaries, and record editing
- a daily dashboard for intake, exercise calories, BMR, no-exercise TDEE reference, targets, remaining kcal/macros, and selected-day records
- Profile settings for body data, language, diet phase, diet calculation mode, diet plan strategy, shared training-frequency self-check, export, and local data clearing
- local deterministic diet strategy support for `carb_cycling` and `carb_tapering`
- XLSX export and CSV ZIP export

FitLog Local currently does not provide:

- backend, cloud sync, accounts, remote database, or multi-device sync
- app-internal OpenAI/Gemini/LLM API calls
- vector database, RAG, tool calling, semantic memory, or Agent loop
- automatic meal planning, automatic target changes, or an AI coach
- medical advice or pediatric treatment guidance
- app-internal photo recognition; `Photo AI Analysis` is still a placeholder entry point

### Core Features

Food Log:

- `Paste AI Result` parses external-model JSON into local `FoodRecord` and `FoodItem` data.
- `Manual Entry` records meal name, date, weight, kcal, protein, carbs, fat, and notes.
- Built-in prompts can be copied in Chinese or English and used with any external model.
- Existing food records can be opened, edited, copied to a chosen date, or deleted.

Workout Record:

- Saved workouts use the user-facing term `Workout Record`.
- A single saved record can contain multiple exercises grouped internally by shared `plan_id`.
- Each session in the same record stores the same `record_name` for additive schema compatibility.
- Creation/editing preserves the user's exercise selection order.
- Strength exercises use set rows with weight, reps or single-set duration, completed state, and saved input-mode snapshots.
- Built-in and custom strength exercises distinguish total weight, per-side weight, added bodyweight load, assistance load, total reps, and per-side reps.
- Strength saves persist completed sets only; unchecked sets are discarded and saved sets are renumbered.
- Cardio exercises use per-exercise duration, a session-intensity basis, and do not have set checklists.
- Interval or very-high-intensity cardio uses active movement time to avoid applying extreme intensity to rest time.
- Saved reusable custom exercises appear in their own picker group and can be hidden from future selection through inline swipe-to-delete inside that custom group.
- Saved records show summary metrics: duration, total volume, total sets, and estimated calories.

Home:

- The selected date is shared across Home, Food Log, and Workout Log.
- `energy_ratio` mode treats kcal target/intake/remaining as primary.
- `gram_per_kg` mode treats macro grams as primary and kcal as auxiliary intake information.
- The dashboard shows current diet phase, calculation mode, strategy context, food records, and workout records.

Profile:

- Stores age, height, weight, sex option, a shared training-frequency setting, diet phase, calculation mode, macro ratios, self-check settings, compatibility activity metadata, and strategy settings.
- `diet_goal_phase` is the source of truth for cutting/bulking semantics.
- Under-18 protection blocks adult-style cutting deficit behavior and cutting carb strategies.
- Export and clear-local-data actions stay local.

### Diet Model

Diet setup has three layers:

```text
diet_goal_phase:
  - cutting
  - bulking

diet_calculation_mode:
  - energy_ratio
  - gram_per_kg

diet_plan_strategy:
  - none
  - carb_cycling
  - carb_tapering
```

Important boundaries:

- `diet_goal_phase` controls whether `daily_energy_goal_kcal` means deficit or surplus.
- `energy_ratio` uses BMR, a training-frequency-based default non-exercise factor, `daily_energy_goal_kcal`, logged net exercise, and macro percentages.
- `gram_per_kg` uses bodyweight, sex option, and `training_frequency_per_week` table lookup.
- `gram_per_kg` does not use BMR, activity level, daily energy goal, logged exercise calories, or macro-ratio percentages.
- Training-frequency self-check can review recent workout history in both diet modes and suggest the shared `training_frequency_per_week` setting.
- In `gram_per_kg` mode, `macro_energy_equivalent_kcal = protein*4 + carbs*4 + fat*9` is auxiliary analysis/export data, not the kcal target counter.
- `carb_cycling` and `carb_tapering` are local deterministic strategy layers applied after the base target is calculated.
- `carb_tapering` can suggest a review action, but it never applies a change without user confirmation.

### Why These Methods

FitLog keeps its methods separated so users can tell which number is the source of truth. `energy_ratio` is kcal-first: it starts from estimated baseline energy, applies a cutting deficit or bulking surplus, adds logged net exercise, and then converts the result into macro grams. In this mode, the default no-exercise factor now comes from the shared training-frequency setting unless local calibration has already learned a better factor from history. `gram_per_kg` is macro-first: it sets protein, carbs, and fat from bodyweight and a coarse training-frequency tier, so kcal is auxiliary instead of the main counter.

Carb strategies are also deliberately limited. `carb_cycling` redistributes weekly carbs across high/medium/low days; it is not a magic fat-loss rule. `carb_tapering` reviews rolling weight trend, food-log coverage, and training stability, then waits for user confirmation before applying any carb reduction.

Exercise calories use net additional burn. The daily baseline already includes resting energy use, so cardio subtracts the resting part of the activity window (`MET - 1`) to avoid counting the same resting calories twice. Cardio intensity is recorded as a concrete "how long could you keep this pace" choice rather than a bare subjective label. Strength training is volume-driven rather than minute-driven because rest time, load, reps, input mode, and movement type matter more than duration alone.

For the user-facing explanation, see [Methodology](../en/Methodology.md). For implementation formulas, see [Algorithm](../en/Algorithm.md). For source boundaries, see [References](../en/References.md).

### Tech Stack

- Flutter + Dart
- SQLite via `sqflite`
- `provider` for app services and UI state
- `shared_preferences` for language preference
- XLSX export via `excel`
- CSV ZIP export via `csv` and `archive`

### Quick Start

Requirements:

- Flutter 3.x
- Dart 3.x
- Android Studio or VS Code
- Android emulator or device for the Android-first workflow

Commands:

```bash
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --debug
```

### Design Documents

| File | Purpose |
| --- | --- |
| [README.md](../../README.md) | Project overview, current scope, method entry points, quick start, and documentation map. |
| [CHANGELOG.md](../../CHANGELOG.md) | English-only dated history of user-facing, data, algorithm, and documentation changes; complex bugs may include debugging clues and lessons learned. |
| [docs/en/Product.md](../en/Product.md) / [docs/zh/Product.md](../zh/Product.md) | Product scope, modules, workflows, UX behavior, implemented boundaries, and non-goals. |
| [docs/en/AppGuide.md](../en/AppGuide.md) / [docs/zh/AppGuide.md](../zh/AppGuide.md) | App-area guide explaining what each module does, how it works at a high level, and where to read more. |
| [docs/en/Methodology.md](../en/Methodology.md) / [docs/zh/Methodology.md](../zh/Methodology.md) | User-facing explanation of why FitLog uses these diet, carb strategy, and workout calorie methods. |
| [docs/en/Algorithm.md](../en/Algorithm.md) / [docs/zh/Algorithm.md](../zh/Algorithm.md) | Engineering-level formulas, diet modes, workout calorie logic, calibration, self-check, and algorithm boundaries. |
| [docs/en/Database.md](../en/Database.md) / [docs/zh/Database.md](../zh/Database.md) | SQLite schema, migrations, tables, fields, runtime aggregates, data flows, and export coverage. |
| [docs/en/AgentDesign.md](../en/AgentDesign.md) / [docs/zh/AgentDesign.md](../zh/AgentDesign.md) | Current AI/Agent boundary: external AI-assisted input versus app-internal deterministic logic. |
| [docs/en/References.md](../en/References.md) / [docs/zh/References.md](../zh/References.md) | External evidence, citation boundaries, and what each source supports. |

Chinese design documents mirror the same content under `docs/zh/`.

### Privacy And Safety

- Business data is stored locally by default in SQLite.
- Exports are written as local files in the app documents directory.
- Nutrition and exercise values are estimates for personal tracking.
- The app does not provide medical advice.
- External AI may be used by the user outside FitLog Local, but the app itself does not call an AI API.
