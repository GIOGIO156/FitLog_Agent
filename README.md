# FitLog_Agent

## 中文

### 项目目标

FitLog_Agent 是一个 AI 辅助的饮食与训练记录 App。它面向想控制饮食、训练和体重变化，但又不想把大量精力花在查食物成分、估重量、算热量和反复手动录入上的用户。

传统饮食记录的难点是：用户需要理解食物组成、热量和宏量营养；最好在吃之前记录，否则吃完后很难判断实际分量；如果记录流程太慢，长期坚持会很困难。FitLog_Agent 的目标是把这些摩擦降下来：AI 可以根据文字或图片生成草稿、回答下一餐怎么吃、复盘最近记录、解释 App 规则；确定性算法仍负责目标、宏量、训练热量和策略边界；正式记录和目标变更仍由用户确认。

FitLog_Agent 继承 FitLog Local 的确定性记录和算法基础，但产品目标不是“Local 的云端变体说明书”。它是一个登录后以云端正式记录为权威、以 AI Chat 为主动辅助入口的 Agent V1 产品。

### 产品承诺

```text
降低记录成本。
保留确定性饮食和训练规则。
AI 只生成草稿、建议、复盘和解释。
正式写入、删除和目标修改必须由用户确认。
```

### 核心能力

- 饮食记录：手动录入、AI 食物分析、Food Draft 预览编辑、复制到日期和删除。
- 训练记录：训练草稿、正式训练记录、自定义动作、力量和有氧热量估算。
- Profile 与目标：Cloud Profile、饮食阶段、`energy_ratio`、`gram_per_kg`、carb cycling、carb tapering 和身体指标记录。
- AI Chat：底部导航正中间的 AI 页面，支持文本、最多三张图片、ChatGPT/OpenAI 和千问/Qwen 服务端 provider。
- 用餐决策：用户主动询问“今天还能吃什么”“这个外卖能点吗”等问题时，AI 使用必要的 Profile、summary 和上下文给建议。
- 周复盘：AI 可以总结近期饮食、训练、体重趋势和数据缺口，但不能自动修改目标或策略。
- App 规则问答：Document RAG 用于解释 FitLog 的算法、字段、隐私和 Agent 边界。
- 导出：用户主动导出 XLSX 或 CSV ZIP。

### AI 与数据边界

- 模型 API key 由服务端管理，用户不需要也不应该填写自己的模型 key。
- OpenAI 与千问输出由服务端统一约束和严格校验；未通过最终校验的结果不会生成可审查/保存的 artifact。
- AI 输出在确认前只是草稿、建议、复盘或解释。
- AI 不会静默写入正式饮食、训练、Profile 或目标数据。
- AI 不会自动应用 carb tapering、删除记录或修改饮食目标。
- 图片请求最多三张；默认不长期保存原图或 base64。
- V1 不做用户业务数据向量库、长期 embedding、semantic memory 或 GraphRAG。
- V1 不是医疗诊断、治疗建议或儿童青少年治疗指导工具。

### 饮食与训练规则

FitLog_Agent 保留确定性算法作为正式目标和摘要的来源。

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

- `diet_goal_phase` 是 cutting / bulking 语义来源。
- `energy_ratio` 下 kcal target / intake / remaining 是主信号。
- `gram_per_kg` 下宏量克数是主目标，kcal 是辅助信息。
- `carb_cycling` 是用户配置的策略层，不是 AI 自动配餐。
- `carb_tapering` 是复盘和用户确认流程，不是 AI 自动减碳。
- 训练消耗仍由确定性规则计算。

### 云端与本地数据

登录后，正式 Profile、身体指标、饮食、训练和 daily summaries 以云端为权威来源。本地 SQLite 保留为 partial cache、草稿存储和运行期加速层。FitLog_Agent 使用单 active device 策略；新设备登录会接管账号，旧设备下一次云端交互时停止正式写入。

完整的云端/本地权威、cache-first 读取、warm cache、写入成功条件、异常、冲突和修复规则见 [docs/zh/CloudLocalDataBoundary.md](docs/zh/CloudLocalDataBoundary.md) / [docs/en/CloudLocalDataBoundary.md](docs/en/CloudLocalDataBoundary.md)。

### 技术栈

- Flutter + Dart
- SQLite via `sqflite`
- `provider` 用于应用服务和 UI 状态
- `shared_preferences` 保存语言、主题和轻量本地状态
- `image_picker` 用于相机/相册图片选择
- `excel`、`csv`、`archive` 用于导出
- Supabase Auth、Postgres、Storage、Edge Functions
- OpenAI / ChatGPT 与千问 / Qwen 服务端 provider

### 快速开始

环境要求：

- Flutter 3.x
- Dart 3.x
- Android Studio 或 VS Code
- Android 模拟器或真机

常用命令：

```bash
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --debug --split-per-abi
```

账号、Cloud Profile、Cloud Records 和真实 AI Gateway 测试需要 Supabase 配置：

```bash
flutter run --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

也可以复制 `config/supabase.local.json.example` 为本机未提交的 `config/supabase.local.json`，填入 Supabase URL 和 anon key 后运行：

```bash
flutter run --dart-define-from-file=config/supabase.local.json
flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json
```

### 设计文档

| 文件 | 用途 |
| --- | --- |
| [CHANGELOG.md](CHANGELOG.md) | 英文 dated changes，说明改了什么、为什么改、解决什么问题和如何验证。 |
| [docs/en/Product.md](docs/en/Product.md) / [docs/zh/Product.md](docs/zh/Product.md) | 产品目的、原则、模块、工作流、边界和代码引用。 |
| [docs/en/AppGuide.md](docs/en/AppGuide.md) / [docs/zh/AppGuide.md](docs/zh/AppGuide.md) | App 各区域如何工作，以及应该阅读哪些设计文件。 |
| [docs/en/Methodology.md](docs/en/Methodology.md) / [docs/zh/Methodology.md](docs/zh/Methodology.md) | 面向用户解释为什么这样设计饮食、训练、AI 和确认流程。 |
| [docs/en/Algorithm.md](docs/en/Algorithm.md) / [docs/zh/Algorithm.md](docs/zh/Algorithm.md) | 公式、确定性算法、workflow 算法和算法边界。 |
| [docs/en/Database.md](docs/en/Database.md) / [docs/zh/Database.md](docs/zh/Database.md) | SQLite、Cloud Profile、Cloud Records、AI Chat、日志和 Document RAG index 的 schema 与数据流。 |
| [docs/en/AgentDesign.md](docs/en/AgentDesign.md) / [docs/zh/AgentDesign.md](docs/zh/AgentDesign.md) | Agent 定位、AI workflow、权限、草稿确认、请求留存和隐私边界。 |
| [docs/en/AIOutputContract.md](docs/en/AIOutputContract.md) / [docs/zh/AIOutputContract.md](docs/zh/AIOutputContract.md) | Provider output envelope、draft schema、校验、归一化、失败、纠错、日志和确认边界。 |
| [docs/en/RAGDesign.md](docs/en/RAGDesign.md) / [docs/zh/RAGDesign.md](docs/zh/RAGDesign.md) | 同会话 context、Structured RAG、Document RAG、source of truth、ingestion、retrieval、evidence 和评测。 |
| [docs/en/References.md](docs/en/References.md) / [docs/zh/References.md](docs/zh/References.md) | 算法、工程、AI/RAG、隐私引用和证据边界。 |
| [docs/en/CloudLocalDataBoundary.md](docs/en/CloudLocalDataBoundary.md) / [docs/zh/CloudLocalDataBoundary.md](docs/zh/CloudLocalDataBoundary.md) | 云端/本地权威、cache、写入、读取、异常、冲突和修复规则。 |
| [docs/API_CONTRACT_DRAFT.md](docs/API_CONTRACT_DRAFT.md) | 当前 Flutter-to-service wire contract、字段约束、稳定错误和兼容边界；文件名保留历史 `DRAFT`。 |
| [docs/FitLog_Agent_V1_Implementation.md](docs/FitLog_Agent_V1_Implementation.md) | V1 架构决策、实施背景和仍有维护价值的历史上下文。 |
| [docs/ROADMAP.md](docs/ROADMAP.md) | 工程阶段计划、执行步骤、验证方式和人工审查清单。 |
| [PHASE5_ENGINEERING_PLAN.md](PHASE5_ENGINEERING_PLAN.md) | Phase 5 工程计划、部署和验收说明。 |
| [AI_OUTPUT_CONTRACT_ENGINEERING_PLAN.md](AI_OUTPUT_CONTRACT_ENGINEERING_PLAN.md) | AI Output Contract 的分阶段实施、验证、灰度和回滚计划。 |

Local 版本基线保留在 `docs/local/`。

### 隐私与安全

- AI 请求可能包含用户输入、图片、Cloud Profile 字段和必要的云端摘要上下文。
- 用户记录摘要上下文需要用户在 App 内授权。
- 原图默认不长期保存。
- 登录后的云端 chat history 会保存文本 turn、轻量 artifact/evidence snapshot 和摘要。
- AI 输出不是医疗建议。
- AI 不能自动修改目标、策略、Profile 或正式记录。

## English

### Purpose

FitLog_Agent is an AI-assisted food and workout logging app. It is for users who want to manage diet, training, and body-weight changes without spending excessive effort looking up food composition, estimating portions, calculating calories/macros, and repeatedly entering records by hand.

Traditional food logging is hard because users need to understand ingredients, calories, and macros; recording is easiest before eating, while portions become harder to estimate after the meal; and a slow workflow is difficult to keep long term. FitLog_Agent reduces that friction: AI can turn text or images into drafts, help decide what to eat next, review recent behavior, and explain app rules. Deterministic algorithms still own targets, macros, workout calories, and strategy boundaries. Official records and goal changes still require user confirmation.

FitLog_Agent inherits deterministic logging and algorithm foundations from FitLog Local, but this README describes FitLog_Agent as its own Agent V1 product: signed-in cloud official records plus an AI Chat entry for user-initiated assistance.

### Product Promise

```text
Make logging easier.
Keep deterministic diet and workout rules.
Use AI only for drafts, suggestions, reviews, and explanations.
Require user confirmation for official writes, deletes, and goal changes.
```

### Core Capabilities

- Food logging: manual entry, AI Food Analysis, Food Draft preview/edit, copy-to-date, and delete.
- Workout logging: workout drafts, official workout records, custom exercises, and strength/cardio calorie estimates.
- Profile and targets: Cloud Profile, diet phase, `energy_ratio`, `gram_per_kg`, carb cycling, carb tapering, and body metrics.
- AI Chat: centered AI page with text, up to three images, and server-side ChatGPT/OpenAI plus Qwen providers.
- Meal decisions: when users ask what to eat next, AI uses the minimum needed Profile, summary, and context.
- Weekly review: AI can summarize recent food, training, weight trends, and data gaps, but cannot automatically change goals or strategies.
- App logic Q&A: Document RAG explains FitLog algorithms, fields, privacy, and Agent boundaries.
- Export: user-controlled XLSX or CSV ZIP export.

### AI And Data Boundaries

- Model API keys are server-managed; users do not provide model keys.
- OpenAI and Qwen outputs use one server-owned strict contract; results that fail final validation never create a review/save artifact.
- AI outputs are drafts, suggestions, reviews, or explanations until confirmed.
- AI does not silently write official food, workout, Profile, or goal data.
- AI does not automatically apply carb tapering, delete records, or change diet goals.
- Image requests are limited to three images; original images or base64 payloads are not stored long term by default.
- V1 does not create user-business-data vector databases, long-term embeddings, semantic memory, or GraphRAG.
- V1 is not medical diagnosis, treatment advice, or pediatric treatment guidance.

### Diet And Workout Rules

FitLog_Agent preserves deterministic algorithms as the source for official targets and summaries.

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

Key boundaries:

- `diet_goal_phase` is the source of cutting / bulking semantics.
- In `energy_ratio`, kcal target / intake / remaining is primary.
- In `gram_per_kg`, macro grams are primary and kcal is auxiliary.
- `carb_cycling` is a user-configured strategy layer, not AI meal automation.
- `carb_tapering` is a review plus user-confirmation flow, not AI automatic carb reduction.
- Workout calories remain deterministic calculations.

### Cloud And Local Data

After sign-in, official Profile, body metrics, food, workout, and daily summaries use the cloud as the source of truth. Local SQLite remains partial cache, draft storage, and runtime acceleration. FitLog_Agent uses a single-active-device policy; a newer login takes over the account, and the older device stops official writes on the next cloud interaction.

The full cloud/local authority, cache-first reads, warm cache, write-success rules, failures, conflicts, and repair policy live in [docs/en/CloudLocalDataBoundary.md](docs/en/CloudLocalDataBoundary.md) / [docs/zh/CloudLocalDataBoundary.md](docs/zh/CloudLocalDataBoundary.md).

### Tech Stack

- Flutter + Dart
- SQLite via `sqflite`
- `provider` for app services and UI state
- `shared_preferences` for language, theme, and lightweight local state
- `image_picker` for camera/gallery image selection
- `excel`, `csv`, and `archive` for export
- Supabase Auth, Postgres, Storage, and Edge Functions
- OpenAI / ChatGPT and Qwen server-side providers

### Quick Start

Requirements:

- Flutter 3.x
- Dart 3.x
- Android Studio or VS Code
- Android emulator or physical device

Common commands:

```bash
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --debug --split-per-abi
```

Account, Cloud Profile, Cloud Records, and real AI Gateway testing need Supabase configuration:

```bash
flutter run --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

You can also copy `config/supabase.local.json.example` to the uncommitted local file `config/supabase.local.json`, fill in the Supabase URL and anon key, then run:

```bash
flutter run --dart-define-from-file=config/supabase.local.json
flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json
```

### Design Documents

| File | Purpose |
| --- | --- |
| [CHANGELOG.md](CHANGELOG.md) | English dated changes: what changed, why, what problem it solved, and validation. |
| [docs/en/Product.md](docs/en/Product.md) / [docs/zh/Product.md](docs/zh/Product.md) | Product purpose, principles, modules, workflows, boundaries, and code references. |
| [docs/en/AppGuide.md](docs/en/AppGuide.md) / [docs/zh/AppGuide.md](docs/zh/AppGuide.md) | How each app area works and which design files to read. |
| [docs/en/Methodology.md](docs/en/Methodology.md) / [docs/zh/Methodology.md](docs/zh/Methodology.md) | User-facing explanation of diet, workout, AI, and confirmation choices. |
| [docs/en/Algorithm.md](docs/en/Algorithm.md) / [docs/zh/Algorithm.md](docs/zh/Algorithm.md) | Formulas, deterministic algorithms, workflow algorithms, and boundaries. |
| [docs/en/Database.md](docs/en/Database.md) / [docs/zh/Database.md](docs/zh/Database.md) | SQLite, Cloud Profile, Cloud Records, AI Chat, logs, and Document RAG index schema and data flow. |
| [docs/en/AgentDesign.md](docs/en/AgentDesign.md) / [docs/zh/AgentDesign.md](docs/zh/AgentDesign.md) | Agent positioning, AI workflows, permissions, draft confirmation, request retention, and privacy boundaries. |
| [docs/en/AIOutputContract.md](docs/en/AIOutputContract.md) / [docs/zh/AIOutputContract.md](docs/zh/AIOutputContract.md) | Provider output envelopes, draft schemas, validation, normalization, failures, correction, logging, and confirmation boundaries. |
| [docs/en/RAGDesign.md](docs/en/RAGDesign.md) / [docs/zh/RAGDesign.md](docs/zh/RAGDesign.md) | Same-chat context, Structured RAG, Document RAG, sources of truth, ingestion, retrieval, evidence, and evaluation. |
| [docs/en/References.md](docs/en/References.md) / [docs/zh/References.md](docs/zh/References.md) | Algorithm, engineering, AI/RAG, privacy references, and evidence boundaries. |
| [docs/en/CloudLocalDataBoundary.md](docs/en/CloudLocalDataBoundary.md) / [docs/zh/CloudLocalDataBoundary.md](docs/zh/CloudLocalDataBoundary.md) | Cloud/local authority, cache, writes, reads, failures, conflicts, and repair rules. |
| [docs/API_CONTRACT_DRAFT.md](docs/API_CONTRACT_DRAFT.md) | Current Flutter-to-service wire contract, field constraints, stable errors, and compatibility boundaries; the legacy filename retains `DRAFT`. |
| [docs/FitLog_Agent_V1_Implementation.md](docs/FitLog_Agent_V1_Implementation.md) | V1 architecture decisions, implementation background, and historical context that remains useful to maintainers. |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Engineering phase plan, execution steps, validation, and manual review checklist. |
| [PHASE5_ENGINEERING_PLAN.md](PHASE5_ENGINEERING_PLAN.md) | Phase 5 engineering plan, deployment, and acceptance notes. |
| [AI_OUTPUT_CONTRACT_ENGINEERING_PLAN.md](AI_OUTPUT_CONTRACT_ENGINEERING_PLAN.md) | Staged AI Output Contract implementation, validation, canary, and rollback plan. |

The Local version baseline remains under `docs/local/`.

### Privacy And Safety

- AI requests may include user text, images, Cloud Profile fields, and necessary cloud summary context.
- User-record summary context requires in-app user permission.
- Original images are not stored long term by default.
- Signed-in cloud chat history stores text turns plus lightweight artifact/evidence snapshots and summaries.
- AI outputs are not medical advice.
- AI must not automatically modify goals, strategies, Profile, or official records.
