# FitLog_Agent

## 中文

### 概览

FitLog_Agent V1 是从 FitLog Local 升级而来的云端 AI 辅助饮食与训练记录 App。它保留 Local 版已经实现的饮食记录、训练记录、确定性饮食/训练算法和本地导出能力，并在登录后把正式身体、饮食、训练记录统一到云端，再新增由云端 AI Gateway 支撑的订阅制 AI Chat 页面。

V1 的核心不是把整个 App 改成自动 AI Coach，也不是把本机 SQLite 变成完整历史镜像。V1 的目标是先建立登录前置的云端正式记录和本地 partial cache 边界，再让用户通过底部导航正中间的 AI 页面主动发起请求，完成拍照饮食估算、用餐决策、周复盘和 App 规则问答；AI 输出在用户确认前只作为草稿、建议、复盘或解释。

注意：当前源码已完成 Phase 3 Cloud Records Foundation 及主要 hardening 链路：在 Phase 2 账号与 Cloud Profile 基础上，新增 root auth gate、单 active device、Cloud Records migration、body/food/workout cloud-first 写入、本地 v15 partial cache metadata、cloud-backed repository、登录冷启动后台账号恢复、Home selected-day daily summary confirmed cache、stale-while-revalidate 后台重算、`daily_summaries` 云端 upsert/恢复、30 天低优先级 summary warm cache、confirmed cache 淘汰，以及基于云端正式 records 的导出完整性。底部导航包含居中的 AI tab，并使用主题化浮动 pill，不在 pill 外绘制整行底色；非 AI 页面使用实体主题 pill 和导航等宽、页面背景色的底部遮挡层遮住滚动内容，AI 页面使用无此遮挡层的更透明玻璃 pill 让彩色背景露出；root shell 不再缩短页面或绘制导航整条底色，可滚动页面在自身内容底部预留导航阅读空间，Home 首屏盒子会扣除浮动导航占位，AI 页面背景继续延伸到导航后方。AI 页面有不可用状态、模型选择器、运行期输入草稿、账号/订阅状态入口和用户记录摘要授权开关；AI 背景在可用状态下保持更清晰的彩色慢流动，键盘打开时暂停背景动画以降低输入卡顿；Profile 页面未登录时显示纯色背景、居中的无星 FitLog logo base asset、基于 SVG 曲线并贴近 logo 右上角的饱和圆润 AI 四角星群错峰呼吸闪烁动画，星群位置经过轻微左下微调且最小态保持更饱满，顶部后端配置提示、登录 FitLog 入口、邮箱密码登录、注册账号入口、注册验证码和密码确认，并统一使用 app 主题字体 `NotoSansSC` 与中等/半粗登录文字层级；键盘关闭时静态未登录页不可上下滑动，输入框聚焦时切换为紧凑可滚动的键盘避让布局。登录后以 Cloud Profile 为正式资料来源，昵称等 Profile 信息保存到云端，不要求注册 username；登录态会保存在本机并在启动时恢复，除非用户主动退出或登录态无法恢复；Profile 页面修改先进入本地草稿，卡片显示已修改状态，昵称和当前身体资料不提供卡片内保存键，并通过底部“保存更改”一次性写入 Cloud Profile；Profile 顶部“订阅”入口打开紧凑模糊浮层，可刷新 AI 订阅状态，并支持输入开发期内部兑换码开启当前账号的 AI entitlement；Profile 底部账号卡片提供明确退出登录入口，退出账号会清空 auth session 和本地账号缓存但不删除云端正式记录。当前仍不能发送 AI 消息；AI Gateway、App 内 LLM、RAG、云端 Chat history 和 Food Draft 写入闭环属于后续阶段。真实登录测试需要通过 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY` 配置 Supabase；配置版客户端会使用本机 `SharedPreferences` 保存注册验证码所需的 PKCE verifier 和 Supabase auth session。

登录和注册失败会保留当前表单，并通过统一系统通知显示可读原因；系统通知会按语义区分顶部轻量成功提示、明显错误/校验提示和保留 action 的提示，并避开底部导航与键盘。订阅状态加载失败不会把 Cloud Profile 资料页整体打断；只要 Cloud Profile 加载成功，Profile 仍可进入，AI 发送仍按订阅可用性关闭。内部兑换码只用于 Phase 2 测试和内部 entitlement 管理，不代表生产支付或应用商店订阅流程已经完成。

AI 页面中心文案优先使用已保存的 Cloud Profile 昵称；Profile 页只有在本地缓存元数据匹配当前登录账号时，才会在云端 Profile 刷新期间先显示缓存资料。订阅入口使用明确的状态徽标表示已开启、未开启、加载中或异常，不使用容易误解为未读提醒的独立绿点。

Profile 的身体资料区包含年龄、身高、体重、性别、体脂和腰围；身体资料卡提供日历/新增身体记录入口，日历默认显示当天，允许选择当天返回当前资料视图，但只有过去日期会进入历史身体记录编辑态。选择过去日期后，日历下方显示具体日期，只有体重、体脂和腰围三项高亮可编辑，身体资料里的年龄、身高、性别以及页面其它区域和底部导航都会用更强的柔和淡化状态锁定，不额外叠加分块遮罩；已有历史记录会在日期条左侧显示红色删除键，删除前必须确认，确认弹窗使用红色危险操作而不是绿色填充按钮，删除后刷新身体趋势和相关 summary cache；没有历史记录的过去日期会显示三个空位，不用当前身体资料预填。身体资料内联输入框与所在卡片同色，并使用固定数值槽位，聚焦前后不会改变数据框大小；键盘弹出时，历史身体记录输入框会把当前编辑区滚到键盘上方。身体趋势卡片只读展示体重、体脂或腰围的 7/14/21/28 天折线，不承担记录入口；真实记录点按所选周期内的日期间隔从左向右延伸，记录不足等提示直接显示在图表区域内。Profile 还提供本地主题偏好，默认 Green，可切换为 Black/黑橙；主题只保存在本机 `SharedPreferences`，不进入 SQLite 或 Cloud Profile。当前身体资料没有卡片内保存键，会随底部“保存更改”写入 Cloud Profile；历史身体指标记录保留独立保存并进入云端 `body_metric_logs`，本地只保留 partial cache。

### V1 范围

FitLog_Agent V1 设计包含：

- 云端账号、订阅和云端 Profile
- 登录后的 Cloud Records：`body_metric_logs`、food/workout records 和 `daily_summaries`
- 服务端统一管理的大模型 API key
- AI Gateway、远程 LLM / 多模态模型调用和 schema validation
- 底部导航正中间的沉浸式 AI Chat 页面
- 全屏彩色 AI 背景动效，以及未登录/未联网/未订阅时的灰色不可用状态
- 左侧可折叠云端 Chat history
- 拍照饮食估算、用餐建议、周复盘和 App 规则解释
- 基于云端 summary/context builder 的 Structured RAG，以及面向 App 文档的 Document RAG
- Chat 内 Food Draft / 推荐 / 复盘 / 规则解释卡片
- 用户确认后才写入正式记录的草稿优先机制

V1 不默认提供：

- 一次性下发完整原始历史到本地 SQLite
- 把本地 SQLite cache 当作 AI 或产品权威来源
- 离线正式写入、复杂冲突合并或旧本机历史自动迁移
- 用户业务数据向量库、长期 embedding、semantic memory 或 GraphRAG
- 强 Agent、多 Agent 或长期 AI Coach
- AI 自动修改目标、Profile、carb cycling、carb taper 或删除记录
- 医疗诊断、治疗建议或儿童青少年治疗指导

### AI Chat

AI 页面位于底部导航正中间，当前导航结构为：

```text
Home | Food | AI | Workout | Profile
```

AI 页面是一个简单 Chat，而不是 quick chips 工作台。Phase 2 已实现全屏浅色背景、中心状态文案、底部输入框、ChatGPT/千问模型选择器、右上账号/订阅入口、左侧历史入口占位和用户记录摘要授权开关。Phase 3 先统一云端正式记录源；当前发送按钮保持禁用，不会调用 AI Gateway、远程模型或 RAG，直到 Phase 4 Gateway 接入。

未发送的 AI 输入框内容是当前运行期内的设备级本地草稿。只要用户没有自行删除或成功发送，切换页面、离线或订阅状态变化都不应自动清空；退出登录或切换账号时应清空，避免上一账号上下文残留。

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
- AI 使用云端 Profile 与必要的云端 selected-day summary。
- 推荐不等于正式记录；用户选择方案后才可生成 Food Draft。

周复盘：

- AI 可基于云端 7 / 14 天摘要总结行为模式、数据缺口、主要问题和少量行动建议。
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

Phase 3 的目标是让登录后的 body / food / workout 正式记录和 daily summaries 以云端为 source of truth，本地 SQLite 只做 partial cache、草稿和运行期加速。完整的云端/本地权威、cache-first 读取、warm cache、写入成功条件、异常、冲突和修复规则统一维护在 [docs/zh/CloudLocalDataBoundary.md](docs/zh/CloudLocalDataBoundary.md) / [docs/en/CloudLocalDataBoundary.md](docs/en/CloudLocalDataBoundary.md)；README 只保留入口摘要。

V1 采用单 active device，last login wins；新设备登录会接管账号，旧设备下一次云端交互时停止正式写入并回到登录/接管路径。

旧本机历史迁移、离线正式写入和复杂端云冲突合并不阻塞 Phase 3；它们属于 Post-V1 增强，需要单独确认迁移、冲突 UI、导出和隐私规则。

### 技术栈

- Flutter + Dart
- SQLite via `sqflite`
- `provider` 用于应用服务和 UI 状态
- `shared_preferences` 保存语言偏好和轻量本地状态
- `excel` 用于 XLSX 导出
- `csv` 和 `archive` 用于 CSV ZIP 导出
- `supabase` Dart client 用于 Phase 2 Auth、订阅状态和 Cloud Profile 访问
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
flutter build apk --debug --split-per-abi
```

Phase 2 账号/Profile 测试需要提供 Supabase 配置：

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
| [docs/FitLog_Agent_V1_Implementation.md](docs/FitLog_Agent_V1_Implementation.md) | Agent V1 产品与实现设计源文档。 |
| [docs/ROADMAP.md](docs/ROADMAP.md) | 从当前 Local 源码落地到 Agent V1 的中文工程阶段计划、执行步骤、验证方式和人工审查清单。 |
| [docs/API_CONTRACT_DRAFT.md](docs/API_CONTRACT_DRAFT.md) | Phase 0 API contract 草案，记录接口形状、数据边界和已锁定的技术选择。 |
| [CHANGELOG.md](CHANGELOG.md) | 英文记录 dated changes，说明改了什么、为什么改、解决什么问题和如何验证。 |
| [docs/en/Product.md](docs/en/Product.md) / [docs/zh/Product.md](docs/zh/Product.md) | 产品范围、原则、模块、workflow、边界和代码引用。 |
| [docs/en/AppGuide.md](docs/en/AppGuide.md) / [docs/zh/AppGuide.md](docs/zh/AppGuide.md) | 各 App 页面如何工作，尤其是 AI Chat、Profile、Food、Workout 和 Export。 |
| [docs/en/Methodology.md](docs/en/Methodology.md) / [docs/zh/Methodology.md](docs/zh/Methodology.md) | 面向用户解释算法、AI 辅助、确认机制和建议边界。 |
| [docs/en/Algorithm.md](docs/en/Algorithm.md) / [docs/zh/Algorithm.md](docs/zh/Algorithm.md) | 公式、确定性算法、Context Builder、AI 输出校验和算法边界。 |
| [docs/en/Database.md](docs/en/Database.md) / [docs/zh/Database.md](docs/zh/Database.md) | 本地 SQLite、Cloud Profile、Cloud Records、AI Chat、AI logs 和 Document RAG index 的 schema、migration、表和字段。 |
| [docs/en/CloudLocalDataBoundary.md](docs/en/CloudLocalDataBoundary.md) / [docs/zh/CloudLocalDataBoundary.md](docs/zh/CloudLocalDataBoundary.md) | Phase 3 云端/本地权威、cache-first、warm cache、写入成功标准、异常、冲突和修复规则。 |
| [docs/en/AgentDesign.md](docs/en/AgentDesign.md) / [docs/zh/AgentDesign.md](docs/zh/AgentDesign.md) | Agent V1 架构、权限、RAG、AI Gateway、草稿确认和隐私边界。 |
| [docs/en/References.md](docs/en/References.md) / [docs/zh/References.md](docs/zh/References.md) | 算法、工程、AI/RAG、隐私引用和证据边界。 |

Local 版历史基准保留在 `docs/local/` 下。

### 隐私与安全

- AI 请求可能会将用户文字、图片、云端 Profile 字段和必要云端记录摘要发送到 FitLog AI Gateway。
- 原始图片默认不长期保存。
- Chat history 登录后云端保存，本地不长期保存。
- 删除账号时，应删除 Cloud Profile、云端正式记录和可识别 AI 会话数据。
- AI 输出是估算、草稿、建议或解释，不是医疗建议。
- AI 不得自动修改目标、策略、Profile 或正式记录。

## English

### Overview

FitLog_Agent V1 upgrades FitLog Local into a cloud-assisted AI food and workout logging app. It preserves the Local version's food logging, workout logging, deterministic diet/workout algorithms, and local export workflows, moves signed-in official body, food, and workout records to the cloud, and then adds a subscription-based AI Chat page powered by a cloud AI Gateway.

V1 does not turn the whole app into an autonomous AI coach, and it does not turn local SQLite into a complete history mirror. Its goal is to first establish login-gated cloud official records plus local partial-cache boundaries, then let users proactively use the centered AI tab for photo food estimation, meal decisions, weekly review, and app-rule Q&A. AI outputs remain drafts, recommendations, reviews, or explanations until the user confirms an action.

Note: the current source has completed the Phase 3 Cloud Records Foundation and its main hardening chain: on top of the Phase 2 account and Cloud Profile foundation, it adds the root auth gate, single active device, Cloud Records migration, body/food/workout cloud-first writes, local v15 partial-cache metadata, cloud-backed repositories, non-blocking signed-in startup account recovery, Home selected-day daily-summary confirmed cache, stale-while-revalidate background rebuilds, `daily_summaries` cloud upsert/recovery, low-priority 30-day summary warm cache, confirmed-cache eviction, and export completeness from cloud official records. Bottom navigation includes the centered AI tab and uses a theme-aware floating pill without a full-width strip outside the pill; non-AI pages use an opaque theme-surface pill plus a same-width page-background lower shield to cover scrolling content, the AI page uses a more transparent glass pill without that shield so the colorful background remains visible, the root shell no longer shrinks pages or paints a navigation-height strip, scrollable pages keep their own bottom reading padding, the Home first viewport subtracts the floating navigation obstruction, and the AI page background still extends behind navigation. The AI page has a disabled state, provider selector, runtime composer draft, account/subscription status entry, and user-record summary permission toggle; the AI background keeps a clearer colorful slow flow in available states and pauses background animation while the keyboard is open to reduce input jank; the Profile page shows a solid-background auth screen with the no-star FitLog logo base asset, saturated SVG-derived fixed rounded AI four-point sparkle cluster anchored to the logo's upper-right with a slight lower-left placement adjustment, fuller resting scale, staggered breathing pulses, top backend-configuration notice, a sign-in landing action, email-password sign-in, registration-only email code, password confirmation, and app theme `NotoSansSC` typography with moderate sign-in text weights. The signed-out screen stays locked when the keyboard is closed and switches to compact keyboard-aware scrolling while auth fields are focused. After login, Cloud Profile is the formal profile, including nickname/display name, and registration does not require a username; the auth session is persisted locally and recovered on startup until explicit sign-out or unrecoverable session failure; Profile edits first become a local page draft with modified section markers, nickname and current body fields do not have card-level save buttons, and the bottom Save Changes bar writes the full Cloud Profile in one save; the Profile header Subscription entry opens a compact blurred overlay that can refresh AI entitlement and redeem a development internal code for the current account; the bottom Profile Account card provides explicit sign-out, clearing the auth session and local account cache without deleting cloud official records. It still cannot send AI messages; AI Gateway, app-internal LLM calls, RAG, cloud Chat history, and Food Draft writeback remain later phases. Real login testing requires `SUPABASE_URL` and `SUPABASE_ANON_KEY` Supabase configuration; configured clients use local `SharedPreferences` storage for the registration code PKCE verifier state and Supabase auth session.

Sign-in and registration failures keep the current form mounted and show readable feedback through the shared system notification layer; notifications distinguish lightweight top success notices, more visible error/validation notices, and action-preserving notices while avoiding bottom navigation and the keyboard. Subscription-status loading failures do not block the whole Cloud Profile page; when Cloud Profile loads successfully, Profile still opens, while AI sending remains gated by subscription availability. Internal redeem codes are only for Phase 2 testing and internal entitlement management; they do not represent production payment or app-store subscription flows.

The AI page center status reads the saved Cloud Profile nickname first. The Profile page may show cached profile values during cloud refresh only when the cache metadata matches the current signed-in account. The Subscription entry uses explicit status badges for active, inactive, loading, and error states instead of a standalone dot that could read as an unread notification.

The Profile body section includes age, height, weight, sex, body-fat percentage, and waist circumference. The Body Profile card provides the calendar/add body-record entry: the picker opens on today, selecting today returns to the current body profile view, and only past dates enter the historical body-record edit state. For a past date, the exact date appears under the calendar action, only weight, body-fat percentage, and waist circumference are highlighted and editable, while age, height, sex, the rest of the page, and bottom navigation are locked with stronger soft fading instead of extra block scrims. Existing historical records show a red delete button beside the date; deletion requires confirmation, uses a red destructive action instead of a green filled button, and refreshes Body Trends plus the affected summary cache. Past dates without a historical record show empty slots for the three editable metrics instead of current Profile values. Inline body-profile inputs share the metric tile surface and use a fixed value slot so focusing a field does not change tile size. When the keyboard opens, historical body-record inputs scroll the active edit area above the keyboard. The Body Trends card is read-only and shows 7/14/21/28-day charts for weight, body fat, or waist without serving as the record entry; real record points extend from left to right by real day spacing inside the selected range, and insufficient-record copy stays inside the chart area. Profile also provides a local theme preference: Green remains the default, and Black uses the Black Orange palette; the preference is stored in local `SharedPreferences`, not SQLite or Cloud Profile. Current body fields have no card-level save button and are saved with the bottom Save Changes Cloud Profile action, while historical body metric logs keep their own save action and use cloud `body_metric_logs` with local partial cache only.

### V1 Scope

FitLog_Agent V1 is designed to include:

- cloud account, subscription, and Cloud Profile
- signed-in Cloud Records: `body_metric_logs`, food/workout records, and `daily_summaries`
- server-managed model API keys
- AI Gateway, remote LLM / multimodal calls, and schema validation
- a centered, immersive AI Chat page in bottom navigation
- full-screen animated AI background and grayscale disabled states for signed-out/offline/unsubscribed users
- left collapsible cloud Chat history
- photo food logging, meal decision, weekly review, and app logic Q&A
- Structured RAG over cloud summary/context builders and Document RAG over app documents
- inline Food Draft, recommendation, review, and rule-answer cards in Chat
- draft-first confirmation before official writes

V1 does not provide by default:

- one-shot complete raw-history download into local SQLite
- treating local SQLite cache as the authoritative AI or product source
- offline official writes, complex conflict resolution, or automatic migration of old device history
- user-data vector database, long-term embeddings, semantic memory, or GraphRAG
- strong Agent, multi-Agent, or long-term AI coach behavior
- automatic target, Profile, carb cycling, carb taper, or record deletion changes
- medical diagnosis, treatment advice, or pediatric treatment guidance

### AI Chat

The AI page sits in the center of bottom navigation:

```text
Home | Food | AI | Workout | Profile
```

The AI page is a simple Chat surface, not a quick-chip workspace. Phase 2 implements the full-screen soft background, center status, bottom composer, ChatGPT/Qwen provider selector, top-right account/subscription entry, left history placeholder, and user-record summary permission toggle. Phase 3 first unifies the cloud official-record source; sending stays disabled and no AI Gateway, remote model, or RAG call is made until the Phase 4 Gateway lands.

Unsent AI composer text is a device-local draft for the current app runtime. Unless the user deletes it or successfully sends it, page switches, offline state, or subscription-state changes should not clear it automatically; logout or account switch should clear it so previous account context does not linger.

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
- AI uses Cloud Profile plus the minimum necessary cloud selected-day summary.
- A recommendation is not a record; choosing a plan can create a Food Draft.

Weekly review:

- AI can summarize behavior patterns, data gaps, main issues, and a small number of action suggestions from cloud 7 / 14 day summaries.
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

Phase 3 connects signed-in body / food / workout official records to the cloud source of truth, while local SQLite becomes partial cache, draft storage, and runtime acceleration. The full cloud/local authority, cache-first reads, warm cache, write-success rules, failures, conflicts, and repair policy live in [docs/en/CloudLocalDataBoundary.md](docs/en/CloudLocalDataBoundary.md) / [docs/zh/CloudLocalDataBoundary.md](docs/zh/CloudLocalDataBoundary.md); the README keeps only this entry summary.

V1 uses one active device per account with last-login-wins behavior; a newer login takes over the account, and the older device stops official writes on its next cloud interaction and returns to sign-in/takeover flow.

Old device-history migration, offline official writes, and complex client/cloud conflict resolution do not block Phase 3. They are Post-V1 enhancements that need separate migration, conflict UI, export, and privacy rules.

### Tech Stack

- Flutter + Dart
- SQLite via `sqflite`
- `provider` for app services and UI state
- `shared_preferences` for language preference and lightweight local state
- `excel` for XLSX export
- `csv` and `archive` for CSV ZIP export
- `supabase` Dart client for Phase 2 Auth, subscription status, and Cloud Profile access
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
flutter build apk --debug --split-per-abi
```

Phase 2 account/Profile testing needs Supabase configuration:

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
| [docs/FitLog_Agent_V1_Implementation.md](docs/FitLog_Agent_V1_Implementation.md) | Source design for Agent V1 product and implementation behavior. |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Chinese engineering roadmap from the current Local source to Agent V1, including phases, execution steps, validation, and manual review checklists. |
| [docs/API_CONTRACT_DRAFT.md](docs/API_CONTRACT_DRAFT.md) | Phase 0 API contract draft covering endpoint shape, data boundaries, and locked technical choices. |
| [CHANGELOG.md](CHANGELOG.md) | English dated changes: what changed, why, what problem it solved, and validation. |
| [docs/en/Product.md](docs/en/Product.md) / [docs/zh/Product.md](docs/zh/Product.md) | Product scope, principles, modules, workflows, boundaries, and code references. |
| [docs/en/AppGuide.md](docs/en/AppGuide.md) / [docs/zh/AppGuide.md](docs/zh/AppGuide.md) | How each app area works, especially AI Chat, Profile, Food, Workout, and Export. |
| [docs/en/Methodology.md](docs/en/Methodology.md) / [docs/zh/Methodology.md](docs/zh/Methodology.md) | User-facing explanation of algorithms, AI assistance, confirmation, and advice boundaries. |
| [docs/en/Algorithm.md](docs/en/Algorithm.md) / [docs/zh/Algorithm.md](docs/zh/Algorithm.md) | Formulas, deterministic algorithms, Context Builder, AI validation, and algorithm boundaries. |
| [docs/en/Database.md](docs/en/Database.md) / [docs/zh/Database.md](docs/zh/Database.md) | Schema, migrations, tables, and fields for local SQLite, Cloud Profile, Cloud Records, AI Chat, AI logs, and Document RAG index. |
| [docs/en/CloudLocalDataBoundary.md](docs/en/CloudLocalDataBoundary.md) / [docs/zh/CloudLocalDataBoundary.md](docs/zh/CloudLocalDataBoundary.md) | Phase 3 cloud/local authority, cache-first reads, warm cache, write-success rules, failures, conflicts, and repair policy. |
| [docs/en/AgentDesign.md](docs/en/AgentDesign.md) / [docs/zh/AgentDesign.md](docs/zh/AgentDesign.md) | Agent V1 architecture, permissions, RAG, AI Gateway, draft confirmation, and privacy boundaries. |
| [docs/en/References.md](docs/en/References.md) / [docs/zh/References.md](docs/zh/References.md) | Algorithm, engineering, AI/RAG, privacy references, and evidence boundaries. |

The Local version baseline is retained under `docs/local/`.

### Privacy And Safety

- AI requests may send user text, images, Cloud Profile fields, and necessary cloud record summaries to FitLog AI Gateway.
- Original images are not stored long-term by default.
- Chat history is stored in the cloud after sign-in and is not stored locally long-term.
- Account deletion should remove Cloud Profile, cloud official records, and identifiable AI conversation data.
- AI outputs are estimates, drafts, recommendations, reviews, or explanations, not medical advice.
- AI must not automatically modify goals, strategies, Profile, or official records.
