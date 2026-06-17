# FitLog_Agent

## 中文

### 概览

FitLog_Agent V1 是从 FitLog Local 升级而来的云端 AI 辅助饮食与训练记录 App。它保留 Local 版已经实现的饮食记录、训练记录、SQLite 数据、确定性饮食/训练算法和本地导出能力，并新增一个由云端 AI Gateway 支撑的订阅制 AI Chat 页面。

V1 的核心不是把整个 App 改成自动 AI Coach，也不是立即把所有业务数据迁移到云端。V1 的目标是让用户通过底部导航正中间的 AI 页面主动发起请求，完成拍照饮食估算、用餐决策、周复盘和 App 规则问答；AI 输出在用户确认前只作为草稿、建议、复盘或解释。

注意：当前源码已完成 Phase 1 App Shell：底部导航包含居中的 AI tab，AI 页面有不可用状态、浅色流动背景、模型选择器占位和可编辑输入框，但还不能发送消息。账号、订阅、Cloud Profile、AI Gateway、App 内 LLM、RAG、云端 Chat history 和 Food Draft 写入闭环仍属于后续工程阶段。

### V1 范围

FitLog_Agent V1 设计包含：

- 云端账号、订阅和云端 Profile
- 服务端统一管理的大模型 API key
- AI Gateway、远程 LLM / 多模态模型调用和 schema validation
- 底部导航正中间的沉浸式 AI Chat 页面
- 全屏彩色 AI 背景动效，以及未登录/未联网/未订阅时的灰色不可用状态
- 左侧可折叠云端 Chat history
- 拍照饮食估算、用餐建议、周复盘和 App 规则解释
- 基于本地摘要的 Structured RAG，以及面向 App 文档的 Document RAG
- Chat 内 Food Draft / 推荐 / 复盘 / 规则解释卡片
- 用户确认后才写入正式记录的草稿优先机制

V1 不默认提供：

- 完整 food / workout / weight 云同步
- 用户业务数据向量库、长期 embedding、semantic memory 或 GraphRAG
- 强 Agent、多 Agent 或长期 AI Coach
- AI 自动修改目标、Profile、carb cycling、carb taper 或删除记录
- 医疗诊断、治疗建议或儿童青少年治疗指导

### AI Chat

AI 页面位于底部导航正中间，当前导航结构为：

```text
Home | Food | AI | Workout | Profile
```

AI 页面是一个简单 Chat，而不是 quick chips 工作台。Phase 1 已实现全屏浅色背景、中心不可用状态文案、底部输入框、ChatGPT/千问模型选择器占位、右上账号/订阅占位和左侧历史入口占位。当前默认是未登录不可用状态；用户可以编辑 prompt，但发送按钮保持禁用，不会触发网络或模型调用。

除 Add Food 的拍照识别入口外，其他 Agent workflow 均从 AI Chat 发起。

### 核心功能

饮食记录：

- 继续支持手动录入、外部 AI JSON 粘贴、预览编辑、复制到指定日期和删除。
- 新增目标：AI Chat 或 Add Food 拍照入口可生成 Food Draft。
- AI 不确定肉类、分量、是否已吃完或烹饪方式时，应先追问。
- Food Draft 在 Chat 内预览，可轻量编辑，也可打开完整记录页。
- 用户确认保存后才写入 `food_records` / `food_items`。

用餐决策：

- 用户可在 AI Chat 中询问“今天还能吃什么”“这个外卖能点吗”“冰箱里这些怎么搭配”。
- AI 使用云端 Profile 与必要的本地 selected-day summary。
- 推荐不等于正式记录；用户选择方案后才可生成 Food Draft。

周复盘：

- AI 可基于 7 / 14 天记录总结行为模式、数据缺口、主要问题和少量行动建议。
- Weekly Review 不能自动修改目标、训练频率、`diet_plan_strategy`、carb cycling 设置或 carb taper 状态。

App 规则问答：

- 用户可询问 BMR、TDEE、`gram_per_kg`、`energy_ratio`、carb cycling、carb taper、运动消耗等规则。
- 中文问题检索中文文档，英文问题检索英文文档，并返回来源 section。

### 饮食与训练模型

Agent V1 必须继承 Local 版确定性算法：

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
- `carb_cycling` 是本地策略层，不是 AI 自动配餐。
- `carb_tapering` 是本地 review + 用户确认流程，不是 AI 自动减碳。
- 训练消耗仍由本地确定性规则计算。

### 云端与本地数据边界

云端保存：

- 账号、订阅、云端 Profile
- AI Chat sessions / messages / final answers
- AI request metadata、debug summary、prompt/schema/model version

本地保存：

- food records / food items
- workout sessions / workout sets
- custom exercises / workout drafts
- weight logs / calorie calibration state / diet adjustment reviews
- 本地导出文件和当前账号 Profile 缓存

V1 不默认把 food / workout / weight 历史完整云同步。AI 需要分析个人记录时，App 只上传最小必要摘要。

### 技术栈

- Flutter + Dart
- SQLite via `sqflite`
- `provider` 用于应用服务和 UI 状态
- `shared_preferences` 保存语言偏好和轻量本地状态
- `excel` 用于 XLSX 导出
- `csv` 和 `archive` 用于 CSV ZIP 导出
- Agent V1 后端选型锁定为 Supabase Auth、Postgres、Storage 和 Edge Functions
- Agent V1 AI providers 为 OpenAI / ChatGPT 与千问 / Qwen，模型 key 由服务端统一管理
- Agent V1 订阅开发期使用服务端内部 entitlement 调试账号

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
| [docs/FitLog_Agent_V1_Implementation.md](docs/FitLog_Agent_V1_Implementation.md) | Agent V1 产品与实现设计源文档。 |
| [docs/ROADMAP.md](docs/ROADMAP.md) | 从当前 Local 源码落地到 Agent V1 的中文工程阶段计划、执行步骤、验证方式和人工审查清单。 |
| [docs/API_CONTRACT_DRAFT.md](docs/API_CONTRACT_DRAFT.md) | Phase 0 API contract 草案，记录接口形状、数据边界和已锁定的技术选择。 |
| [CHANGELOG.md](CHANGELOG.md) | 英文记录 dated changes，说明改了什么、为什么改、解决什么问题和如何验证。 |
| [docs/en/Product.md](docs/en/Product.md) / [docs/zh/Product.md](docs/zh/Product.md) | 产品范围、原则、模块、workflow、边界和代码引用。 |
| [docs/en/AppGuide.md](docs/en/AppGuide.md) / [docs/zh/AppGuide.md](docs/zh/AppGuide.md) | 各 App 页面如何工作，尤其是 AI Chat、Profile、Food、Workout 和 Export。 |
| [docs/en/Methodology.md](docs/en/Methodology.md) / [docs/zh/Methodology.md](docs/zh/Methodology.md) | 面向用户解释算法、AI 辅助、确认机制和建议边界。 |
| [docs/en/Algorithm.md](docs/en/Algorithm.md) / [docs/zh/Algorithm.md](docs/zh/Algorithm.md) | 公式、确定性算法、Context Builder、AI 输出校验和算法边界。 |
| [docs/en/Database.md](docs/en/Database.md) / [docs/zh/Database.md](docs/zh/Database.md) | 本地 SQLite、云端 Profile、AI Chat、AI logs、Document RAG index 和数据边界。 |
| [docs/en/AgentDesign.md](docs/en/AgentDesign.md) / [docs/zh/AgentDesign.md](docs/zh/AgentDesign.md) | Agent V1 架构、权限、RAG、AI Gateway、草稿确认和隐私边界。 |
| [docs/en/References.md](docs/en/References.md) / [docs/zh/References.md](docs/zh/References.md) | 算法、工程、AI/RAG、隐私引用和证据边界。 |

Local 版历史基准保留在 `docs/local/` 下。

### 隐私与安全

- AI 请求可能会将用户文字、图片、云端 Profile 字段和必要本地摘要发送到 FitLog AI Gateway。
- 原始图片默认不长期保存。
- Chat history 登录后云端保存，本地不长期保存。
- 删除账号时，应删除云端 Profile 和可识别 AI 会话数据。
- AI 输出是估算、草稿、建议或解释，不是医疗建议。
- AI 不得自动修改目标、策略、Profile 或正式记录。

## English

### Overview

FitLog_Agent V1 upgrades FitLog Local into a cloud-assisted AI food and workout logging app. It preserves the Local version's food records, workout records, SQLite data, deterministic diet/workout algorithms, and local export workflows, while adding a subscription-based AI Chat page powered by a cloud AI Gateway.

V1 does not turn the whole app into an autonomous AI coach, and it does not immediately migrate all business data to the cloud. Its goal is to let users proactively use the centered AI tab for photo food estimation, meal decisions, weekly review, and app-rule Q&A. AI outputs remain drafts, recommendations, reviews, or explanations until the user confirms an action.

Note: the current source has completed the Phase 1 App Shell: bottom navigation includes the centered AI tab, and the AI page has a disabled state, soft flowing background, provider selector placeholder, and editable composer. It cannot send messages yet. Account login, subscription, Cloud Profile, AI Gateway, app-internal LLM calls, RAG, cloud Chat history, and Food Draft writeback remain later engineering phases.

### V1 Scope

FitLog_Agent V1 is designed to include:

- cloud account, subscription, and Cloud Profile
- server-managed model API keys
- AI Gateway, remote LLM / multimodal calls, and schema validation
- a centered, immersive AI Chat page in bottom navigation
- full-screen animated AI background and grayscale disabled states for signed-out/offline/unsubscribed users
- left collapsible cloud Chat history
- photo food logging, meal decision, weekly review, and app logic Q&A
- Structured RAG over local summaries and Document RAG over app documents
- inline Food Draft, recommendation, review, and rule-answer cards in Chat
- draft-first confirmation before official writes

V1 does not provide by default:

- full food / workout / weight cloud sync
- user-data vector database, long-term embeddings, semantic memory, or GraphRAG
- strong Agent, multi-Agent, or long-term AI coach behavior
- automatic target, Profile, carb cycling, carb taper, or record deletion changes
- medical diagnosis, treatment advice, or pediatric treatment guidance

### AI Chat

The AI page sits in the center of bottom navigation:

```text
Home | Food | AI | Workout | Profile
```

The AI page is a simple Chat surface, not a quick-chip workspace. Phase 1 implements the full-screen soft background, disabled center status, bottom composer, ChatGPT/Qwen provider selector placeholder, top-right account/subscription placeholder, and left history placeholder. The current app defaults to signed-out disabled state: a half-written prompt remains editable, but sending stays disabled and no network or model call is made.

Except for the Add Food photo-recognition shortcut, Agent workflows start from AI Chat.

### Core Features

Food logging:

- Existing manual entry, external AI JSON paste, preview/edit, copy-to-date, and delete flows remain.
- New target behavior: AI Chat or Add Food photo entry can create a Food Draft.
- AI should ask follow-up questions when meat type, portion, completion, or cooking method is uncertain.
- Food Drafts are previewed in Chat, can be lightly edited, and can open the full food editor.
- Official `food_records` / `food_items` are written only after user confirmation.

Meal decision:

- Users can ask "What can I still eat today?", "Can I order this?", or "How should I combine these foods?"
- AI uses Cloud Profile plus the minimum necessary local selected-day summary.
- A recommendation is not a record; choosing a plan can create a Food Draft.

Weekly review:

- AI can summarize 7 / 14 day behavior patterns, data gaps, main issues, and a small number of action suggestions.
- Weekly Review cannot automatically change goals, training frequency, `diet_plan_strategy`, carb cycling settings, or carb taper state.

App logic Q&A:

- Users can ask about BMR, TDEE, `gram_per_kg`, `energy_ratio`, carb cycling, carb tapering, and exercise-calorie rules.
- Chinese queries retrieve Chinese docs; English queries retrieve English docs; answers return source sections.

### Diet And Workout Model

Agent V1 must preserve the Local deterministic algorithms:

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
- `carb_cycling` is a local strategy layer, not AI meal automation.
- `carb_tapering` is a local review plus user-confirmation flow, not AI automatic carb reduction.
- Workout calories remain deterministic local calculations.

### Cloud And Local Data Boundary

Cloud stores:

- account, subscription, and Cloud Profile
- AI Chat sessions / messages / final answers
- AI request metadata, debug summaries, and prompt/schema/model versions

Local stores:

- food records / food items
- workout sessions / workout sets
- custom exercises / workout drafts
- weight logs / calorie calibration state / diet adjustment reviews
- local export files and the current account's cached Profile

V1 does not fully cloud-sync food / workout / weight history by default. When AI needs personal record context, the app uploads only the minimum necessary summary.

### Tech Stack

- Flutter + Dart
- SQLite via `sqflite`
- `provider` for app services and UI state
- `shared_preferences` for language preference and lightweight local state
- `excel` for XLSX export
- `csv` and `archive` for CSV ZIP export
- Agent V1 backend is locked to Supabase Auth, Postgres, Storage, and Edge Functions
- Agent V1 AI providers are OpenAI / ChatGPT and Qwen, with model keys managed server-side
- Agent V1 subscription development uses server-side internal entitlement debug accounts

### Quick Start

Requirements:

- Flutter 3.x
- Dart 3.x
- Android Studio or VS Code
- Android emulator or physical device; Android workflow is currently primary

Common commands:

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
| [docs/FitLog_Agent_V1_Implementation.md](docs/FitLog_Agent_V1_Implementation.md) | Source design for Agent V1 product and implementation behavior. |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Chinese engineering roadmap from the current Local source to Agent V1, including phases, execution steps, validation, and manual review checklists. |
| [docs/API_CONTRACT_DRAFT.md](docs/API_CONTRACT_DRAFT.md) | Phase 0 API contract draft covering endpoint shape, data boundaries, and locked technical choices. |
| [CHANGELOG.md](CHANGELOG.md) | English dated changes: what changed, why, what problem it solved, and validation. |
| [docs/en/Product.md](docs/en/Product.md) / [docs/zh/Product.md](docs/zh/Product.md) | Product scope, principles, modules, workflows, boundaries, and code references. |
| [docs/en/AppGuide.md](docs/en/AppGuide.md) / [docs/zh/AppGuide.md](docs/zh/AppGuide.md) | How each app area works, especially AI Chat, Profile, Food, Workout, and Export. |
| [docs/en/Methodology.md](docs/en/Methodology.md) / [docs/zh/Methodology.md](docs/zh/Methodology.md) | User-facing explanation of algorithms, AI assistance, confirmation, and advice boundaries. |
| [docs/en/Algorithm.md](docs/en/Algorithm.md) / [docs/zh/Algorithm.md](docs/zh/Algorithm.md) | Formulas, deterministic algorithms, Context Builder, AI validation, and algorithm boundaries. |
| [docs/en/Database.md](docs/en/Database.md) / [docs/zh/Database.md](docs/zh/Database.md) | Local SQLite, Cloud Profile, AI Chat, AI logs, Document RAG index, and data boundaries. |
| [docs/en/AgentDesign.md](docs/en/AgentDesign.md) / [docs/zh/AgentDesign.md](docs/zh/AgentDesign.md) | Agent V1 architecture, permissions, RAG, AI Gateway, draft confirmation, and privacy boundaries. |
| [docs/en/References.md](docs/en/References.md) / [docs/zh/References.md](docs/zh/References.md) | Algorithm, engineering, AI/RAG, privacy references, and evidence boundaries. |

The Local version baseline is retained under `docs/local/`.

### Privacy And Safety

- AI requests may send user text, images, Cloud Profile fields, and necessary local summaries to FitLog AI Gateway.
- Original images are not stored long-term by default.
- Chat history is stored in the cloud after sign-in and is not stored locally long-term.
- Account deletion should remove Cloud Profile and identifiable AI conversation data.
- AI outputs are estimates, drafts, recommendations, reviews, or explanations, not medical advice.
- AI must not automatically modify goals, strategies, Profile, or official records.
