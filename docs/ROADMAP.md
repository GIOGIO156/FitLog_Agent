# FitLog_Agent V1 Roadmap

## 1. Roadmap 目标

本文定义从当前 FitLog Local 源码基线落地到 FitLog_Agent V1 的工程阶段计划。

Roadmap 的核心目的不是把功能列完，而是保证每个阶段都能独立实现、独立安装审查、独立定位问题，并且不会把风险一次性堆到最后。

最终执行时应遵守：

```text
先保住 Local 基线
-> 再搭 AI 页面外壳
-> 再接账号 / 订阅 / Cloud Profile
-> 再接 AI Gateway 和 Chat History
-> 再接只读 RAG workflows
-> 最后接 Food Draft 写入闭环
-> 发布前整体加固
```

本文件只写中文，因为它是项目内部工程施工计划。稳定产品事实仍维护在 `docs/en/*` 和 `docs/zh/*`；V1 目标设计源文档仍是 `docs/FitLog_Agent_V1_Implementation.md`。

## 2. 当前源码基线

当前代码仍主要是复制来的 FitLog Local。

当前已存在：

- Flutter + Dart App shell。
- `Home`、`Food`、`AI`、`Workout`、`Profile` 五个主要 tab。
- Phase 1 AI shell：居中 AI tab、不可用 AI 页面、可编辑输入框、ChatGPT/千问模型选择器占位、history 入口占位、账号/订阅入口占位。
- 浮动白色 bottom navigation pill，pill 外不绘制整行背景色。
- SQLite 本地数据库。
- 本地饮食记录、饮食 item、训练记录、训练 set、体重记录。
- 手动饮食录入。
- 外部 AI JSON 粘贴和本地解析。
- prompt copy。
- 本地训练记录、训练草稿、自定义动作、训练热量估算。
- `energy_ratio`。
- `gram_per_kg`。
- `carb_cycling`。
- `carb_tapering`。
- 动态热量校准。
- training-frequency self-check。
- XLSX / CSV ZIP 本地导出。
- 中英文 UI 字符串和中文字体 fallback。

当前尚未存在：

- App 内 LLM 调用。
- AI Gateway。
- 账号登录。
- 订阅校验。
- Cloud Profile。
- 云端 Chat History。
- AI request logs。
- Structured RAG。
- Document RAG。
- 图片识别。
- Chat 内 Food Draft。
- AI 确认后写入正式 food record。

## 3. V1 完整落地定义

V1 完整落地是指：

1. 用户可以安装 App，并保留现有 Local 饮食、训练、Profile、导出能力。
2. 底部导航变成 `Home | Food | AI | Workout | Profile`。
3. AI 页面位于底部导航正中间。
4. 底部导航是浮动白色 pill，导航组件本身不在 pill 外绘制整行底色；pill 外显示当前页面或 root shell 背景。
5. AI 页面是全屏 Chat，有彩色动效背景。
6. 未登录、离线或未订阅时 AI 页面变灰，用户可编辑输入但不能发送。
7. 用户登录后有 Cloud Profile。
8. Cloud Profile 是登录后的权威 Profile。
9. 离线时 Profile 可展示缓存但禁止保存。
10. 用户订阅状态由云端控制。
11. 模型 API key 由服务端统一管理，用户不能在 App 内填写。
12. AI Chat 可发送消息并接收远程 LLM 回复。
13. Chat sessions/messages 登录后云端保存。
14. 左侧可折叠 history 可读取云端会话。
15. AI request metadata 和 compact debug summaries 可用于运维与排错。
16. Document RAG 可以回答 App 规则问题。
17. 中文问题检索中文文档，英文问题检索英文文档。
18. Structured RAG 可以基于最小必要本地摘要回答用餐决策和 Weekly Review。
19. AI 不上传完整 food/workout/weight 历史作为 V1 默认行为。
20. AI 不创建用户业务数据向量库，不做长期 semantic memory。
21. Add Food 拍照识别和 AI Chat 图片输入可以生成 Food Draft。
22. AI 不确定食材、肉类、分量、吃完比例或烹饪方式时会追问。
23. Food Draft 在 Chat 内展示为与记录页风格一致的预览卡。
24. 用户可以在 Chat 内轻量编辑 Food Draft。
25. 用户可以保存、丢弃或打开完整编辑页。
26. 正式 food record 只有用户确认后才写入。
27. AI 不静默修改 Profile、目标、策略、carb cycling、carb taper 或删除记录。
28. 发布前完成错误处理、隐私删除、弱网、性能和回归验证。

## 4. 总体阶段原则

阶段拆分原则：

- 每个阶段结束都必须能安装审查，Phase 0 除外。
- 每个阶段都必须保留上一阶段能力。
- 每个阶段只引入一类主要风险。
- 不把 UI、账号、Gateway、RAG、Food Draft 写入混在同一阶段。
- 先只读，再草稿，再确认写入。
- AI 写入能力必须晚于账号、Gateway、只读 RAG。
- 每阶段都要有明确阻断条件；阻断未解决不能进入下一阶段。
- 每阶段完成后再更新文档和 changelog。

测试原则：

- 代码阶段默认运行 `flutter analyze` 和 `flutter test`。
- 涉及 App 安装审查的阶段需要构建 Android debug APK。
- 文档-only 阶段不需要 Flutter 测试，除非同时改代码。
- 单元测试覆盖服务、模型、mapper、repository。
- Widget 测试覆盖页面状态和关键 UI gating。
- 后端/API 阶段必须有 contract test 或等价验证。
- 人工安装审查必须有 checklist。

数据原则：

- V1 默认不完整云同步 food/workout/weight 历史。
- AI 请求只上传当前任务最小必要上下文。
- 用户业务数据不做长期 embedding、semantic memory 或 GraphRAG。
- Cloud Profile 跟账号走。
- Chat history 登录后云端保存，本地不长期保存。
- 删除账号时删除 Cloud Profile 和可识别 chat history。

AI 行为原则：

- AI 可以解释、总结、建议、追问、生成草稿。
- AI 不能静默写入正式业务数据。
- AI 不能静默修改目标或策略。
- AI 不确定时必须追问。
- 数据不足时必须说明缺什么。
- 医疗相关请求只给一般信息并建议咨询专业人士。

## 5. 阶段总览

| 阶段 | 是否需要安装审查 | 核心目标 | 主要风险 |
| --- | --- | --- | --- |
| Phase 0 | 否 | 技术选型、API contract、工程边界锁定。 | 后续边做边改方向。 |
| Phase 1 | 是 | App Shell 与 AI 页面空壳。 | 导航和 UI 破坏现有 Local 体验。 |
| Phase 2 | 是 | 账号、订阅、Cloud Profile 基础。 | 登录状态和 Profile 权威来源混乱。 |
| Phase 3 | 是 | AI Gateway 与云端 Chat History。 | 网络、订阅 gating、会话持久化出错。 |
| Phase 4 | 是 | Structured RAG / Document RAG 与只读 workflows。 | 上下文上传过多、回答越权、文档语言检索错误。 |
| Phase 5 | 是 | Food Vision 与 Food Draft 写入闭环。 | AI 草稿写入错误或绕过用户确认。 |
| Phase 6 | 是 | V1 Release Hardening。 | 弱网、删除、隐私、性能、边界遗漏。 |

## 6. Phase 0: 技术选型与工程边界锁定

### 目标

在写任何 Agent 代码前，锁定 V1 的后端、账号、订阅、AI Gateway、Cloud Profile、RAG、图片处理和日志边界。

这个阶段不需要安装 App 审查，因为它不改运行时功能。

### 为什么现在做

如果不先锁定这些边界，后面会出现几类危险：

- App 先按一种 auth 状态写，后端又换成另一种 session 语义。
- Cloud Profile 字段反复变化，导致 Profile 页面和 AI context builder 反复返工。
- AI Gateway contract 不稳定，Chat、RAG、Food Draft 都被迫跟着改。
- 订阅 gating 放在 App 端还是服务端不清楚，导致绕过风险。
- 图片保存多久、是否保存原图、失败如何追问没有定论。

### 本阶段实现

本阶段只产出设计与 contract，不写正式功能代码。

需要锁定：

- 后端方案。
- 登录方式。
- 订阅方案。
- AI provider 和模型调用方式。
- 服务端模型 API key 管理方式。
- AI Gateway endpoint 设计。
- Chat Session / Message 数据模型。
- AI request log / debug summary 数据模型。
- Cloud Profile 字段。
- Cloud Profile 与本地 profile cache 的关系。
- 离线 Profile 行为。
- 图片上传、压缩、暂存和删除策略。
- Document RAG 初版检索策略。
- Structured RAG context object 列表。
- 错误码和用户可见错误文案分类。
- V1 不做的范围。

当前锁定结论：

- 后端方案：Supabase。
  - Auth 使用 Supabase Auth。
  - 云端数据库使用 Supabase Postgres。
  - 临时图片对象使用 Supabase Storage 私有临时 bucket。
  - AI Gateway 使用 Supabase Edge Functions。
- 登录方式：FitLog 自有邮箱验证码 / OTP 注册登录。
  - 任意可接收验证码的邮箱都可创建账号。
  - 未登录前没有正式 Profile。
  - V1 首版不做游客正式 Profile、Apple 登录、Google 登录或手机号登录。
- 订阅方案：开发期内部 entitlement。
  - 服务端维护订阅状态。
  - 至少准备两个调试账号：一个 subscribed，一个 unsubscribed。
  - App 只显示 AI 是否可用，不显示用户可见额度。
  - 生产支付 provider 以后再定，但必须写入同一套服务端 entitlement contract。
- AI providers：OpenAI / ChatGPT 与千问 / Qwen。
  - 用户在 AI Chat 输入区选择 `ChatGPT` 或 `千问`。
  - 工程 provider id 使用 `openai` 和 `qwen`。
  - 模型 API key 只在服务端 secret 中保存。
  - Flutter App 不保存模型 key。
  - 具体文本、vision 和 structured output 模型名由服务端环境配置控制。
  - API key 创建位置和具体模型名到 Phase 3 接 AI Gateway 时再按官方后台说明填写。
- 图片策略：App 压缩后上传 Supabase Storage 私有临时 bucket，再把 attachment reference 传给 AI Gateway。
  - 每次 AI 请求最多 2 张图片。
  - 单张目标压缩到 1.5 MB 以内。
  - 压缩后仍超过 5 MB 则拒绝。
  - 推荐最长边 1600 px。
  - 临时图片默认 24 小时过期；丢弃 draft、删除会话或删除账号时删除关联图片。

### 本阶段不实现

- 不新增 AI tab。
- 不新增登录 UI。
- 不接 AI Gateway。
- 不接 RAG。
- 不改 food/workout/profile 行为。
- 不改数据库 schema。

### 代码改动区域

通常不改代码。允许的改动：

- `docs/ROADMAP.md`
- `docs/FitLog_Agent_V1_Implementation.md`
- 必要时新增 `docs/API_CONTRACT_DRAFT.md`
- 必要时更新 `README.md`
- 必要时更新 `CHANGELOG.md`

### 执行步骤

1. 确认后端选型。
   - 已锁定 Supabase。
   - Phase 2 使用 Supabase Auth + Postgres 实现账号、Cloud Profile 和开发 entitlement。
   - Phase 3 使用 Supabase Edge Functions 承载 AI Gateway。
   - Phase 5 使用 Supabase Storage 私有临时 bucket 承载短期图片对象。

2. 确认登录方式。
   - 已锁定 FitLog 自有邮箱验证码 / OTP。
   - 任意可收验证码的邮箱可注册/登录。
   - 不做游客正式 Profile。
   - 未登录前没有正式 Profile。

3. 确认订阅方案。
   - 已锁定开发期内部 entitlement。
   - 先准备 subscribed / unsubscribed 两类调试账号。
   - 服务端记录请求次数和成本。
   - App 只显示订阅是否有效。
   - 生产支付 provider 是发布前商业化决策，但不得改变服务端 gating contract。

4. 定义 Cloud Profile。
   - 映射现有 `user_profile` 字段。
   - 明确 `profile_version`。
   - 明确 `updated_at`。
   - 明确账号删除时删除 Cloud Profile。

5. 定义 AI Gateway request。
   - `session_id`
   - `message`
   - `language`
   - `attachments`
   - `workflow_hint`
   - `profile_version`
   - `context_objects`
   - client app version

6. 定义 AI Gateway response。
   - `message`
   - `workflow`
   - `assistant_message_id`
   - `needs_clarification`
   - `draft`
   - `error`
   - `debug_summary_id`

7. 定义 Food Draft schema。
   - meal name
   - items
   - estimated weight
   - kcal/protein/carbs/fat
   - confidence
   - uncertainty notes
   - clarification questions

8. 定义 Document RAG 文档源。
   - `docs/zh/*`
   - `docs/en/*`
   - 是否需要生成 help chunks。
   - 检索语言如何判断。

9. 定义 Structured RAG context objects。
   - `profile_context`
   - `selected_day_summary`
   - `recent_food_summary`
   - `recent_workout_summary`
   - `weight_trend_summary`
   - `strategy_context`

10. 定义日志与隐私。
    - request metadata 保存什么。
    - debug summary 保存什么。
    - production 不保存什么。
    - 删除账号删除什么。

11. 更新文档。
    - Roadmap 写入最终 Phase。
    - Implementation 文档如有冲突则同步。
    - API contract 草案记录接口形状和未决技术选择。
    - README 添加 Roadmap 说明。

### 自动化验证

文档阶段验证：

- 确认 `docs/ROADMAP.md` 存在。
- 搜索占位词、旧文件名、替换字符。
- 确认 README 指向 Roadmap。
- 不运行 Flutter 测试，除非本阶段改了代码。

### 人工审查

人工审查问题：

- 是否认可 6 个安装审查阶段。
- 是否认可 V1 不做完整业务数据云同步。
- 是否认可先只读、再草稿、再确认写入。
- 是否认可 AI Gateway contract 的字段方向。
- 是否认可 Cloud Profile 字段归属。
- 是否认可订阅 gating 而不是用户可见额度 UI。
- 是否认可 Supabase + 邮箱 OTP + 开发 entitlement + OpenAI/ChatGPT 与 Qwen 双 provider + Supabase Storage 临时图片策略。

### 阻断条件

以下问题不解决，不能进入 Phase 1。当前这些问题已由 `docs/API_CONTRACT_DRAFT.md` 和 `docs/FitLog_Agent_V1_Implementation.md` 锁定：

- 后端方案未定。
- 登录方式未定。
- 订阅校验位置未定。
- Cloud Profile 是否权威未定。
- AI Gateway request/response contract 不清楚。
- Food Draft schema 不清楚。
- RAG 范围不清楚。
- 图片保存策略不清楚。

### 文档更新

- `docs/ROADMAP.md`
- `docs/FitLog_Agent_V1_Implementation.md`
- `docs/API_CONTRACT_DRAFT.md`
- `README.md`
- `CHANGELOG.md`

## 7. Phase 1: App Shell 与 AI 页面空壳

### 目标

在不接后端、不接 LLM 的情况下，先让 App 有完整的 AI 入口和目标视觉结构。

用户安装后应看到：

- 底部导航变成 `Home | Food | AI | Workout | Profile`。
- AI tab 在正中间。
- 底部导航是浮动白色 pill。
- AI 页面是全屏 Chat 空壳。
- AI 页面具备流动背景能力；Phase 1 默认未登录不可用，因此显示灰色 disabled 设计。
- 输入框可以编辑，但不能发送真实消息。

### 为什么现在做

这个阶段只引入 UI shell 风险，不引入账号、网络、AI、RAG 或写库风险。这样可以先确认最核心的产品入口、动效、导航和跨页面体验是对的。

如果 AI 页面视觉和导航不先确认，后面接入账号和 AI 后再改，会同时影响状态管理、chat history 和消息流，排错成本更高。

### 当前完成状态

Phase 1 已完成并进入 Phase 2 前待人工复查状态。

已落地：

- Android 安装身份已经与 FitLog Local 分离，App label 为 `FitLog Agent`。
- Root navigation 已变为 `Home | Food | AI | Workout | Profile`。
- AI tab 是 index `2`，位于底部导航正中间。
- Home 中 Food/Workout 快捷入口已使用 `RootTabIndex`，避免 Workout 误跳 AI。
- 底部导航已抽为 `FitLogBottomNavBar`，只绘制浮动白色 pill 和选中 indicator。
- AI 页面已新增 `AiPage`，默认是未登录 disabled shell。
- AI 页面包含灰色低动态背景、中心状态文案、可编辑 composer、禁用 send、ChatGPT/千问选择器占位、history 占位和账号/订阅占位。
- AI composer 在虚拟键盘弹起时贴近键盘上沿，不再重复叠加 `viewInsets` 间距。
- AI 页面在键盘弹起时会按键盘高度上移中心状态文案，避免状态文案与模型选择、登录状态和输入框重叠。
- `extendBody` 只在 AI tab 生效，普通页面内容不再滑到 bottom navigation 后方。
- 普通页面继续露出既有浅色页面背景，避免为了透明效果改坏 Home/Food/Workout/Profile 的滚动底部；AI tab 因为启用 `extendBody`，pill 外区域露出 AI 页面背景。
- 未新增 Supabase、HTTP、LLM、图片上传、数据库迁移或客户端模型 API key。
- README、CHANGELOG、双语 Product/AppGuide/AgentDesign 已同步 Phase 1 已实现范围。
- 独立 Phase 1 工程计划书的长期信息已合并到本节，后续不再单独维护。

仍未实现：

- 账号登录、订阅校验、Cloud Profile、AI Gateway、LLM 调用、RAG、云端 chat history、图片上传、Food Draft 和确认写入闭环。

### 本阶段实现

- 新增 `lib/features/ai/`。
- 新增 AI page。
- 新增 AI background 动效组件。
- 新增 AI composer 组件。
- 新增 AI provider selector 占位，显示 `ChatGPT` / `千问`，但本阶段不真实调用模型。
- 新增 AI status/header 组件。
- 新增 history sidebar placeholder。
- 新增 top-right account/subscription placeholder。
- 修改 root shell pages。
- 修改 bottom navigation 为 5 tabs。
- 修改 bottom navigation 为 floating pill。
- 去掉 pill 外整行背景色。
- 新增 AI tab localizations。
- 新增 AI disabled state mock。
- 保持 Home/Food/Workout/Profile 原功能不变。

### 本阶段不实现

- 不实现登录。
- 不实现订阅。
- 不实现 Cloud Profile。
- 不实现 AI Gateway。
- 不创建或填写 OpenAI / Qwen API key。
- 不实现 chat history 保存。
- 不实现 RAG。
- 不实现图片上传。
- 不实现 Food Draft。
- 不改 SQLite schema。

### 代码改动区域

核心改动：

- `lib/app.dart`
- `lib/features/ai/ai_page.dart`
- `lib/core/localization/app_strings.dart`
- `lib/core/widgets/fitlog_bottom_nav_bar.dart`
- `lib/features/home/home_page.dart`
- `test/ai_page_test.dart`
- `test/root_navigation_test.dart`

### 执行步骤

1. 建立 AI feature 目录。
   - 新增 `ai_page.dart`。
   - 新增 widgets 目录。
   - 页面先不依赖后端 service。

2. 修改 root shell。
   - `_pages` 从 4 个变 5 个。
   - AI page 放在 index 2。
   - nav items 顺序固定为 Home, Food, AI, Workout, Profile。

3. 抽出或改造底部导航。
   - 保持 floating pill。
   - pill 外部不要绘制整行绿色或白色背景。
   - 保持 SafeArea。
   - 保持移动端宽度和页面卡片视觉协调。

4. 实现 AI 背景动效基础版本。
   - Ready：彩色柔和缓慢流动。
   - Processing mock：稍快。
   - Needs clarification mock：放慢并突出输入区域。
   - Disabled：灰色低动态。
   - 先不要做过多状态，避免动画过度设计。

5. 实现 AI 页面布局。
   - 中心文案。
   - 底部输入框。
   - 输入区附近提供紧凑模型选择器，可选 `ChatGPT` / `千问`。
   - 右上角状态入口。
   - 左侧 history placeholder。
   - 消息列表可为空。

6. 实现 disabled mock。
   - 在本阶段可用 hardcoded state 或 local controller。
   - 输入框可输入。
   - send button disabled。

7. 更新本地化字符串。
   - 中文和英文都补齐。
   - 避免终端乱码误判，中文文件按 UTF-8 读取。

8. 更新测试。
   - 确认 root shell 有 5 个 tab。
   - 确认 AI tab label 存在。
   - 确认 AI disabled 状态 send 不可用。

9. 手动视觉检查。
   - 普通页面导航不突兀。
   - AI 页面底部没有绿色底色带。
   - 横向/窄屏不溢出。

### 自动化验证

必须运行：

```bash
flutter analyze
flutter test
flutter build apk --debug
```

建议新增测试：

- AI page renders.
- Root shell has five tabs.
- AI tab is center index.
- Disabled AI composer cannot send.
- Existing Home/Food/Workout/Profile tests still pass.

### 人工安装审查

安装 APK 后检查：

- App 能正常启动。
- Home/Food/Workout/Profile 原流程没有明显变化。
- 底部导航为 5 个 tab。
- AI tab 正中间。
- 底部 pill 之外没有整行绿色背景。
- 切换到 AI 页面后灰色 disabled 背景铺满屏幕。
- AI 页面中心文案位置正确。
- 未打开键盘时输入框在底部导航上方；打开键盘后输入框贴近键盘上沿。
- 右上角状态入口存在。
- 左侧 history placeholder 可展开/收起或至少有目标位置。
- disabled 状态为灰色。
- disabled 状态可以编辑 prompt 但不能发送。
- 小屏幕上文字不挤压、按钮不溢出。

### 阻断条件

以下问题不解决不能进入 Phase 2：

- 任何 Local 既有核心功能损坏。
- 5 tab 导航状态错乱。
- AI tab 不是正中间。
- 底部 pill 外仍有整行背景色。
- AI 页面在常见手机尺寸布局溢出。
- disabled 状态仍能发送。
- `flutter analyze` 或 `flutter test` 失败。

### 文档更新

完成后更新：

- `docs/en/AppGuide.md`
- `docs/zh/AppGuide.md`
- `docs/en/Product.md`
- `docs/zh/Product.md`
- `README.md`
- `CHANGELOG.md`

## 8. Phase 2: 账号、订阅、Cloud Profile 基础

### 目标

让 App 具备真实账号状态、订阅状态和 Cloud Profile 基础，但仍不接 AI Gateway。

用户安装后应看到：

- 可以登录/登出。
- 登录后 Profile 从云端加载。
- 未登录前没有正式 Profile。
- AI 页面根据登录、联网、订阅状态决定能否发送。
- 离线时 Profile 可查看缓存但不能保存。
- 右上角状态入口可查看账号/订阅状态。

### 为什么现在做

AI Chat、RAG 和 Food Draft 都需要用户身份和 Cloud Profile。先接账号和 Profile，可以避免后面 AI context 依赖一个临时本地 profile，导致之后大面积重构。

### 本阶段实现

- Auth/session 状态层。
- 登录 UI。
- 登出行为。
- 订阅状态读取。
- Cloud Profile model。
- Cloud Profile repository/API client。
- Profile 页面适配 Cloud Profile。
- 本地 profile cache。
- 离线 profile save disabled。
- AI 页面 gating 使用真实状态。
- 右上角状态入口展示账号和订阅。
- 基础网络状态 detection。

### 本阶段不实现

- 不接 AI Gateway。
- 不发送 AI 消息。
- 不保存 Chat History。
- 不做 RAG。
- 不做 Food Draft。
- 不完整云同步 food/workout/weight。
- 不做用户可见额度 UI。

### 代码改动区域

预计新增：

- `lib/features/auth/*`
- `lib/features/account/*` 或 `lib/features/profile/account_status_*`
- `lib/data/remote/*`
- `lib/data/repositories/cloud_profile_repository.dart`
- `lib/domain/models/cloud_profile.dart`
- `lib/domain/models/subscription_status.dart`
- `lib/domain/models/auth_session.dart`
- `lib/core/network/*`
- `lib/core/config/*`

预计修改：

- `lib/app.dart`
- `lib/features/profile/profile_page.dart`
- `lib/features/ai/ai_page.dart`
- `lib/core/localization/app_strings.dart`
- `pubspec.yaml`，按后端方案加入必要依赖

### 执行步骤

1. 加入后端所需依赖。
   - Auth SDK 或 HTTP client。
   - 安全 token 存储，如需要。
   - 网络状态检测，如需要。

2. 建立配置层。
   - 区分 dev/staging/prod endpoint。
   - 不把模型 API key 放进 App。
   - 不把敏感后端 secret 放进客户端。

3. 建立 session model。
   - `signedOut`
   - `signedIn`
   - `loading`
   - `error`
   - token refresh state

4. 建立 subscription model。
   - `active`
   - `inactive`
   - `unknown`
   - `loading`
   - provider metadata

5. 建立 Cloud Profile model。
   - 映射现有 profile 字段。
   - 增加 `profile_version`。
   - 增加 `updated_at`。
   - 明确 nullable/default。

6. 实现 Auth controller。
   - load session。
   - sign in。
   - sign out。
   - refresh session。
   - expose state to UI。

7. 实现 Cloud Profile repository。
   - fetch。
   - save。
   - cache。
   - clear on sign out if policy requires。

8. 改造 Profile 页面。
   - 未登录时显示登录入口，不展示正式 editable profile。
   - 登录后加载 Cloud Profile。
   - saving 时显示状态。
   - 离线时禁止保存。
   - 保存成功更新 cache 和 `profile_version`。

9. 改造 AI 页面 gating。
   - 未登录：disabled gray。
   - 离线：disabled gray。
   - 未订阅：disabled gray。
   - 三者都满足：本阶段仍不发送，但 UI 可进入 ready mock。

10. 改造右上角状态入口。
    - 显示登录状态。
    - 显示订阅状态。
    - 提供登录/管理订阅入口占位。

11. 保持 Local food/workout/weight。
    - 不迁移历史记录。
    - 不让 Cloud Profile 保存触发 food/workout/weight 上传。

12. 写测试。
    - session state。
    - profile mapping。
    - offline save disabled。
    - AI gating。

### 自动化验证

必须运行：

```bash
flutter analyze
flutter test
flutter build apk --debug
```

建议新增测试：

- signed-out Profile 不允许保存。
- signed-in Profile fetch 后展示字段。
- offline Profile save disabled。
- Cloud Profile mapper 保留 `diet_goal_phase`。
- Cloud Profile mapper 不合并 `energy_ratio` 和 `gram_per_kg`。
- AI page gating: signed out/offline/unsubscribed disables send。
- sign out 后不显示上一个用户的正式 profile。

后端/API 验证：

- Auth happy path。
- Auth failure。
- Subscription active/inactive。
- Cloud Profile fetch/save。
- Profile version conflict 的 V1 行为：提示刷新或重试，不做复杂 merge。

### 人工安装审查

安装 APK 后检查：

- 未登录启动 App，Home/Food/Workout 基本可用。
- 未登录进入 Profile，不出现正式 editable profile。
- 登录后 Profile 加载云端信息。
- 修改 Profile 并保存，重启后仍能看到云端值。
- 断网后 Profile 显示缓存但保存按钮 disabled。
- 断网后 AI 页面变灰，输入框可编辑但不能发送。
- 未订阅账号 AI 页面 disabled。
- 订阅有效账号 AI 页面进入 ready 状态，但本阶段不需要真实发送。
- 登出后 AI 页面 disabled。
- 登出后 Profile 不显示上一账号正式信息。
- Food/Workout 本地历史没有被云端逻辑破坏。

### 阻断条件

以下问题不解决不能进入 Phase 3：

- 登录状态不稳定或重启后丢失。
- Profile 云端保存和读取不一致。
- 离线仍可保存 Profile。
- 未登录仍能编辑正式 Profile。
- AI gating 与登录/订阅/联网状态不一致。
- 登出后泄露上一账号 Profile。
- Local food/workout/weight 被误上传或误清空。
- `flutter analyze` 或 `flutter test` 失败。

### 文档更新

完成后更新：

- `docs/en/Product.md`
- `docs/zh/Product.md`
- `docs/en/AppGuide.md`
- `docs/zh/AppGuide.md`
- `docs/en/Database.md`
- `docs/zh/Database.md`
- `docs/en/AgentDesign.md`
- `docs/zh/AgentDesign.md`
- `README.md`
- `CHANGELOG.md`

## 9. Phase 3: AI Gateway 与云端 Chat History

### 目标

让 AI Chat 能真实发送消息、接收远程 LLM 回复，并把会话历史保存到云端。

本阶段仍然不引入 RAG、不读取本地 food/workout/weight 摘要、不生成 Food Draft、不写正式业务数据。

### 为什么现在做

AI Gateway 和 Chat History 是所有后续 AI workflow 的基础。先验证最小 chat 闭环，可以把网络、订阅 gating、会话顺序、云端历史和错误处理问题独立暴露出来。

### 本阶段实现

- AI Gateway endpoint。
- 服务端统一管理模型 API key。
- AI Gateway 根据用户选择路由到 OpenAI 或 Qwen provider adapter。
- App AI Gateway client。
- Chat Session model。
- Chat Message model。
- 云端 chat sessions。
- 云端 chat messages。
- 左侧 history 读取真实 sessions。
- 新建会话。
- 切换会话。
- 删除或归档会话。
- request metadata。
- compact debug summary。
- 订阅状态由服务端二次校验。
- AI 页面发送/接收基础消息。
- 基础错误 UI。

### 本阶段不实现

- 不接 Structured RAG。
- 不接 Document RAG。
- 不读取本地业务记录摘要。
- 不支持图片。
- 不生成 Food Draft。
- 不写 food/workout/profile。
- 不做流式输出，除非 Phase 0 已确定且实现成本低。
- 不做复杂多 Agent。

### 代码改动区域

预计新增：

- `lib/features/ai/models/*`
- `lib/features/ai/widgets/chat_message_bubble.dart`
- `lib/features/ai/widgets/chat_history_panel.dart`
- `lib/data/remote/ai_gateway_client.dart`
- `lib/data/repositories/ai_chat_repository.dart`
- `lib/domain/models/ai_chat_session.dart`
- `lib/domain/models/ai_chat_message.dart`
- `lib/domain/models/ai_gateway_request.dart`
- `lib/domain/models/ai_gateway_response.dart`

预计后端新增：

- `/ai/chat`
- `/ai/sessions`
- `/ai/sessions/{id}/messages`
- `/ai/sessions/{id}/archive` 或 delete
- AI request logging
- subscription enforcement middleware

### 执行步骤

1. 后端实现 session/message 数据表。
   - sessions 归属 account。
   - messages 归属 session 和 account。
   - user 和 assistant role 分开。
   - 保存 created_at。

2. 后端实现 AI Gateway。
   - 验证 auth token。
   - 验证 subscription active。
   - 构建 provider request。
   - 根据 `model_choice` 选择 OpenAI 或 Qwen provider adapter。
   - 保存 request metadata。
   - 保存 compact debug summary。
   - 返回 assistant message。

3. App 实现 AI Gateway client。
   - send message。
   - create session if needed。
   - list sessions。
   - load messages。
   - archive/delete session。
   - map errors。

4. App 实现 Chat state controller。
   - selected session。
   - message list。
   - sending state。
   - error state。
   - retry state。
   - disabled gating。

5. AI 页面接入真实消息列表。
   - 用户消息立即显示 pending。
   - assistant 回复成功后加入列表。
   - 失败时显示可重试状态。

6. 左侧 history 接入真实云端 sessions。
   - 可折叠。
   - 新建会话。
   - 切换会话。
   - 删除/归档会话。

7. 保存与恢复。
   - 重启 App 后登录用户能看到云端 history。
   - 本地不长期保存 chat history。

8. 错误处理初版。
   - 未订阅。
   - 登录过期。
   - 网络失败。
   - Gateway timeout。
   - provider error。

9. 写测试。
   - client mapper。
   - repository。
   - chat state。
   - gating。
   - session/message ordering。

### 自动化验证

必须运行：

```bash
flutter analyze
flutter test
flutter build apk --debug
```

后端/API 验证：

- 未登录调用 AI Gateway 被拒绝。
- 未订阅调用 AI Gateway 被拒绝。
- 已订阅调用成功。
- session 创建成功。
- message 顺序正确。
- request metadata 生成。
- provider error 转换为稳定 error code。
- 不返回 internal debug trace 给用户。

App 测试：

- 发送消息 pending -> success。
- 发送消息 pending -> error。
- 切换 session 后消息正确。
- 删除/归档 session 后 history 更新。
- 登录失效后 AI 页面 disabled。

### 人工安装审查

安装 APK 后检查：

- 已订阅账号可以发送普通消息。
- assistant 能回复。
- 新建会话成功。
- 切换历史会话成功。
- 重启后 history 仍在。
- 未订阅账号不能发送。
- 断网时不能发送，已输入内容保留。
- Gateway 错误不会导致 App 崩溃。
- 删除/归档会话后 UI 更新正确。
- AI 回复不会创建 food/workout/profile 数据。
- Food/Workout/Profile 原有能力仍正常。

### 阻断条件

以下问题不解决不能进入 Phase 4：

- 服务端订阅校验可绕过。
- Chat messages 串账号或串 session。
- 重启后 history 丢失或错乱。
- 网络失败导致 App 崩溃。
- debug trace 暴露到用户 UI。
- AI 回复能触发业务写入。
- 本地长期保存 chat history。
- `flutter analyze` 或 `flutter test` 失败。

### 文档更新

完成后更新：

- `docs/en/AgentDesign.md`
- `docs/zh/AgentDesign.md`
- `docs/en/Database.md`
- `docs/zh/Database.md`
- `docs/en/AppGuide.md`
- `docs/zh/AppGuide.md`
- `README.md`
- `CHANGELOG.md`

## 10. Phase 4: Structured RAG / Document RAG 与只读 AI Workflows

### 目标

让 AI 能回答与 App 规则和用户近期状态有关的问题，但保持只读。

本阶段实现：

- App Logic Q&A。
- Meal Decision。
- Weekly Review。
- Structured RAG。
- Document RAG。

本阶段不写正式业务数据。

### 为什么现在做

只读 RAG 是 Food Draft 写入前的安全演练。它可以验证 workflow routing、上下文最小化、文档检索、语言检索和 AI 边界，而不会引入写库风险。

### 本阶段实现

- 本地 context builders。
- Structured RAG context object。
- Document RAG index。
- 中文/英文文档检索。
- Workflow routing。
- App Logic Q&A。
- Meal Decision。
- Weekly Review。
- 只读回答卡片。
- 数据不足提示。
- 不确定时说明缺什么。

### 本阶段不实现

- 不支持图片。
- 不生成 Food Draft。
- 不保存 food/workout/profile。
- 不修改目标。
- 不应用 carb taper。
- 不修改 carb cycling。
- 不上传完整原始历史。
- 不做用户业务数据 embedding。
- 不做 semantic memory。

### 代码改动区域

预计新增：

- `lib/domain/services/ai_context_builder.dart`
- `lib/domain/models/ai_context/*`
- `lib/domain/services/recent_food_summary_service.dart`
- `lib/domain/services/recent_workout_summary_service.dart`
- `lib/domain/services/weight_trend_summary_service.dart`
- `lib/data/repositories/document_repository.dart`，如文档检索在客户端
- 后端 document index ingest / query 模块

预计修改：

- `lib/data/remote/ai_gateway_client.dart`
- `lib/features/ai/ai_page.dart`
- `lib/features/ai/widgets/*`
- AI Gateway backend workflow routing

### 执行步骤

1. 定义 context object schema。
   - 与 `Database.md` 和 `AgentDesign.md` 对齐。
   - 每个 object 都有 `type`、`version`、`date_range`、`data`。

2. 实现 `selected_day_summary` builder。
   - 使用现有 `DailySummaryService`。
   - 输出 intake、workout、target context。
   - 根据模式区分 kcal-primary 和 macro-primary。

3. 实现 `recent_food_summary` builder。
   - 默认 7/14 天窗口。
   - 输出平均摄入、macro consistency、coverage、missing days。
   - 不上传所有 food rows。

4. 实现 `recent_workout_summary` builder。
   - 输出训练频率、估算 kcal、训练部位分布、稳定性。
   - 不上传所有 sets 原始行，除非明确需要且最小化。

5. 实现 `weight_trend_summary` builder。
   - 数据不足时输出 insufficient data。
   - 数据足够时输出 trend。
   - 避免伪精确。

6. 实现 `strategy_context` builder。
   - 当前 `diet_plan_strategy`。
   - `carb_cycling` day type。
   - `carb_tapering` state。
   - 明确 AI 不能应用策略。

7. 实现 Document RAG 初版。
   - 中文问题检索 `docs/zh`。
   - 英文问题检索 `docs/en`。
   - 初版可用关键词/全文检索。
   - 如果 Phase 0 已确定向量检索，索引仅限文档，不含用户业务数据。

8. 后端实现 workflow routing。
   - `app_logic_qa`
   - `meal_decision`
   - `weekly_review`
   - fallback chat
   - workflow 选择写入 debug summary。

9. Prompt/system instruction 加边界。
   - 不写正式记录。
   - 不修改目标/策略/Profile。
   - 不把 planned feature 说成 implemented。
   - 数据不足就说明。

10. AI 页面展示只读回答。
    - 普通 answer。
    - Weekly review summary card。
    - Meal advice card。
    - App logic answer。
    - 不出现保存按钮。

11. 写测试。
    - context builder fixture。
    - language routing。
    - workflow routing。
    - no-write guard。
    - prompt boundary regression。

### 自动化验证

必须运行：

```bash
flutter analyze
flutter test
flutter build apk --debug
```

建议新增测试：

- `selected_day_summary` 在 `energy_ratio` 下包含 kcal remaining。
- `selected_day_summary` 在 `gram_per_kg` 下包含 macro gaps 且不把 kcal 当主目标。
- `recent_food_summary` 不输出完整 row list。
- `weight_trend_summary` 数据不足时返回 insufficient data。
- 中文问题选择中文 docs。
- 英文问题选择英文 docs。
- Weekly Review 不产生 write intent。
- Meal Decision 不修改 profile。
- App Logic Q&A 不把未实现 AI 功能说成已上线。

后端验证：

- RAG query 只返回同语言文档。
- Workflow routing 可解释。
- request log 只存 metadata 和摘要。
- no-write workflow 不调用写入 API。

### 人工安装审查

安装 APK 后检查这些问题：

- 中文问：“gram_per_kg 是什么？”
- 中文问：“为什么这个模式 kcal 不是主目标？”
- 中文问：“carb cycling 和 carb tapering 有什么区别？”
- 英文问：“How does carb tapering work?”
- 问：“今天还能吃什么？”
- 问：“为什么最近没瘦？”
- 问：“帮我把目标改成减脂更激进一点。”
- 问：“直接帮我应用 carb taper。”

审查标准：

- 中文问题用中文回答。
- 英文问题用英文回答。
- App 规则回答和文档一致。
- Meal Decision 会引用今日摘要。
- Weekly Review 会说明数据不足或模式。
- AI 不声称自己已经修改目标。
- AI 不静默改策略。
- AI 不写 food/workout/profile。
- 回答中不会暴露 debug trace。
- Food/Workout/Profile 原流程正常。

### 阻断条件

以下问题不解决不能进入 Phase 5：

- AI 上传完整业务历史作为默认上下文。
- Document RAG 检索错语言。
- AI 把计划功能说成已上线。
- AI 在只读阶段产生写库动作。
- AI 建议绕过用户确认。
- Weekly Review 自动应用 carb taper。
- Meal Decision 改目标或策略。
- context builder 破坏 Local 算法。
- `flutter analyze` 或 `flutter test` 失败。

### 文档更新

完成后更新：

- `docs/en/AgentDesign.md`
- `docs/zh/AgentDesign.md`
- `docs/en/Algorithm.md`
- `docs/zh/Algorithm.md`
- `docs/en/Methodology.md`
- `docs/zh/Methodology.md`
- `docs/en/Database.md`
- `docs/zh/Database.md`
- `README.md`
- `CHANGELOG.md`

## 11. Phase 5: Food Vision 与 Food Draft 写入闭环

### 目标

实现 V1 最核心的 AI 写入相关能力：食物图片/描述 -> AI 估算 -> Chat 内 Food Draft -> 用户编辑/确认 -> 写入正式本地 food records。

这是 V1 中第一个允许 AI workflow 触达正式业务写入的阶段，因此必须严格使用草稿和确认机制。

### 为什么现在做

前面阶段已经验证：

- AI 页面存在。
- 账号/订阅/Profile 存在。
- AI Gateway 可用。
- Chat history 可用。
- RAG 和只读 workflow 可控。

现在才加入 Food Draft 写入，可以把风险集中在 draft schema、UI preview、用户确认、repository write 和刷新逻辑上。

### 本阶段实现

- AI Chat 支持图片附件。
- Add Food 拍照识别入口接入 AI Gateway。
- 图片压缩/上传。
- Vision food estimation workflow。
- Food Draft schema validation。
- Clarification flow。
- Chat 内 Food Draft preview card。
- Chat 内轻量编辑。
- 保存 Food Draft。
- 丢弃 Food Draft。
- 打开完整编辑页。
- 保存后写入 `food_records` / `food_items`。
- 保存后刷新 Home/Food。
- 保存后记录 source。
- 失败时不写库。

### 本阶段不实现

- 不让 AI 写 workout record。
- 不让 AI 写 Profile。
- 不让 AI 修改 diet goal。
- 不让 AI 修改 carb cycling。
- 不让 AI 应用 carb taper。
- 不让 AI 删除记录。
- 不做完整食物数据库。
- 不做用户长期图片库。
- 不默认长期保存原始图片。

### 代码改动区域

预计新增：

- `lib/features/ai/widgets/food_draft_card.dart`
- `lib/domain/models/food_draft.dart`
- `lib/domain/models/food_draft_item.dart`
- `lib/domain/services/food_draft_mapper.dart`
- `lib/domain/services/food_draft_validator.dart`
- `lib/data/remote/image_upload_client.dart`，如需要
- `lib/features/ai/widgets/image_attachment_picker.dart`

预计修改：

- `lib/features/food/add_food_page.dart`
- `lib/features/food/manual_food_entry_page.dart`
- `lib/features/food/food_detail_page.dart`，如复用 editor
- `lib/data/repositories/food_repository.dart`
- `lib/features/ai/ai_page.dart`
- `lib/data/remote/ai_gateway_client.dart`
- `lib/core/localization/app_strings.dart`

后端预计新增：

- vision attachment handling。
- image temporary storage。
- food estimation schema validation。
- clarification response。
- Food Draft response type。

### 执行步骤

1. 定义 Food Draft domain model。
   - meal name。
   - total weight。
   - total kcal/protein/carbs/fat。
   - item list。
   - confidence。
   - estimation notes。
   - missing questions。
   - source metadata。

2. 定义 Food Draft schema。
   - 与 AI Gateway response 对齐。
   - 所有数值字段需要单位。
   - 缺失信息用明确字段表示。
   - invalid schema 不能进入保存流程。

3. 实现 Food Draft validator。
   - kcal 和 macro 不允许 NaN。
   - weight 不允许负数。
   - item name 不为空。
   - total 与 item 是否允许不完全一致要有规则。
   - confidence 可选。

4. 实现图片附件 UI。
   - AI Chat composer 可添加图片。
   - Add Food photo entry 可复用。
   - 附件可删除。
   - 离线/未登录/未订阅不能上传。

5. 实现图片上传/传输。
   - 根据 Phase 0 决策：直接 multipart 或先上传 storage 再传 URL。
   - 压缩大图。
   - 限制图片数量和大小。
   - 上传失败给用户可理解错误。

6. 后端实现 vision workflow。
   - 验证登录和订阅。
   - 调用多模态模型。
   - 返回 Food Draft 或 clarification questions。
   - 保存 request metadata。
   - 不默认长期保存原图。

7. 实现 clarification flow。
   - 如果肉类不清楚，问用户。
   - 如果分量不清楚，问用户。
   - 如果吃完比例不清楚，问用户。
   - 如果烹饪方式影响大，问用户。
   - 用户回答后继续同一个 draft workflow。

8. 实现 Chat 内 Food Draft card。
   - 视觉与记录页字段一致。
   - 支持轻量编辑。
   - 支持保存。
   - 支持丢弃。
   - 支持打开完整编辑页。
   - 显示 AI estimate/draft 状态。

9. 实现保存到本地 food repository。
   - 保存前再次 validate。
   - 写入 `food_records`。
   - 写入 `food_items`。
   - source 标记为 AI draft confirmed 或等价枚举。
   - 保存成功后刷新 Home/Food。

10. 实现打开完整编辑页。
    - 将 draft 映射到现有 manual/editor 页面。
    - 用户在完整编辑页保存后写入正式记录。
    - 返回后 Chat draft 状态更新。

11. 实现失败保护。
    - invalid schema 不展示保存按钮。
    - upload failed 不产生 draft。
    - save failed 不标记为 saved。
    - discard 不写数据库。

12. 写测试。
    - schema mapper。
    - validator。
    - draft -> food record mapping。
    - save confirmation。
    - discard no-write。
    - clarification state。

### 自动化验证

必须运行：

```bash
flutter analyze
flutter test
flutter build apk --debug
```

建议新增测试：

- Food Draft valid schema maps to domain model。
- Invalid schema returns error state。
- Draft save writes one `food_records` row。
- Draft save writes expected `food_items` rows。
- Draft discard writes nothing。
- Draft edit changes saved values。
- Save triggers refresh notifier。
- Add Food photo entry uses same draft workflow。
- Offline image upload disabled。
- Unsubscribed image upload disabled。

后端验证：

- 清晰食物图片返回 draft。
- 不清楚肉类返回 clarification。
- 不清楚分量返回 clarification。
- 图片过大返回稳定错误。
- provider vision error 返回稳定错误。
- request log 不保存不必要 raw payload。

### 人工安装审查

安装 APK 后检查：

1. AI Chat 文本描述食物。
   - 输入“我吃了一碗米饭和鸡胸肉”。
   - 应生成 Food Draft。
   - 保存前 Home/Food 不变化。
   - 保存后 Home/Food 更新。

2. AI Chat 上传清晰食物图。
   - 应生成 Food Draft。
   - 卡片字段可读。
   - 可轻量编辑。
   - 可保存。

3. 肉类不明确的图片。
   - AI 应追问肉类，而不是乱猜。

4. 分量不明确。
   - AI 应追问分量或提供明确不确定说明。

5. 用户编辑草稿。
   - 修改 kcal 或 item。
   - 保存后详情页显示修改后的值。

6. 打开完整编辑页。
   - 草稿字段带入完整编辑页。
   - 保存后写入正式记录。

7. 丢弃草稿。
   - 不写数据库。
   - Home/Food 不变。

8. Add Food 拍照识别入口。
   - 与 AI Chat 使用同一个草稿确认逻辑。

9. 断网状态。
   - 不能上传图片。
   - 输入内容保留。

10. 未订阅状态。
    - 不能调用识别。

### 阻断条件

以下问题不解决不能进入 Phase 6：

- Food Draft 可绕过确认直接写入。
- 丢弃后仍写入数据库。
- invalid schema 可保存。
- 图片识别失败导致 App 崩溃。
- AI 不确定时仍强行给确定估算。
- 保存后 Home/Food 不刷新。
- source 标记混乱。
- 打开完整编辑页丢字段。
- AI 可以修改 Profile 或 strategy。
- `flutter analyze` 或 `flutter test` 失败。

### 文档更新

完成后更新：

- `docs/en/Product.md`
- `docs/zh/Product.md`
- `docs/en/AppGuide.md`
- `docs/zh/AppGuide.md`
- `docs/en/AgentDesign.md`
- `docs/zh/AgentDesign.md`
- `docs/en/Algorithm.md`
- `docs/zh/Algorithm.md`
- `docs/en/Database.md`
- `docs/zh/Database.md`
- `README.md`
- `CHANGELOG.md`

## 12. Phase 6: V1 Release Hardening

### 目标

把 V1 从“功能完成”变成“可以发布、审查、维护”的版本。

这个阶段不应新增大功能，只做加固、回归、隐私、性能、文档和发布准备。

### 为什么现在做

前面阶段已经分别验证了 UI、账号、Gateway、RAG、Food Draft。最后需要把跨阶段边界统一检查一遍，因为很多问题只有完整链路连起来后才会出现。

### 本阶段实现

- 统一错误处理。
- 弱网和超时策略。
- 登录过期恢复。
- 订阅失效恢复。
- AI Gateway fallback。
- invalid schema 处理。
- 图片上传失败处理。
- RAG 无结果处理。
- 删除账号流程。
- Cloud Profile 删除。
- Chat history 删除或匿名化。
- Request log retention 明确化。
- Debug log 降噪。
- Production 不保存不必要 raw context。
- 医疗/高风险建议边界。
- AI 越权行为回归测试。
- 动效性能优化。
- 长 chat history 性能优化。
- 本地化完整性检查。
- 文档回填。
- Release candidate build。

### 本阶段不实现

- 不新增新的 Agent workflow。
- 不新增 workout AI 写入。
- 不新增完整云同步。
- 不新增用户可见额度系统。
- 不新增 semantic memory。
- 不重构已稳定 Local 算法。

### 代码改动区域

预计修改：

- `lib/core/network/*`
- `lib/core/errors/*`
- `lib/features/ai/*`
- `lib/features/profile/*`
- `lib/data/remote/*`
- `lib/data/repositories/*`
- `lib/core/localization/app_strings.dart`
- backend error middleware
- backend retention/deletion jobs
- tests

### 执行步骤

1. 统一 error model。
   - network unavailable。
   - auth expired。
   - subscription inactive。
   - gateway timeout。
   - provider failure。
   - invalid schema。
   - upload failed。
   - rag no result。
   - save failed。

2. 统一用户可见错误文案。
   - 中文和英文都补齐。
   - 不显示内部 stack trace。
   - 不显示 provider 原始敏感错误。

3. 弱网测试与处理。
   - timeout。
   - retry。
   - duplicate send 防护。
   - pending message 状态恢复。

4. 登录过期处理。
   - token refresh。
   - refresh 失败回到 signed out。
   - 清理敏感 account state。

5. 订阅失效处理。
   - 服务端拒绝。
   - App disabled。
   - 已输入 prompt 保留。

6. 删除账号。
   - 删除 Cloud Profile。
   - 删除或匿名化 chat history。
   - 删除 identifiable AI conversation data。
   - 明确 request log retention。
   - 本地 cache 清理。

7. 隐私与日志检查。
   - production 不存 chain-of-thought。
   - production 不存不必要 raw local context。
   - debug summary 足够排错但不暴露隐私。

8. AI safety regression。
   - 医疗诊断请求。
   - 要求直接改目标。
   - 要求直接应用 carb taper。
   - 要求删除记录。
   - 要求绕过订阅。

9. 性能检查。
   - AI 背景动效低端机帧率。
   - 长消息列表滚动。
   - history 很多时加载。
   - 大图压缩上传。

10. UI 细节检查。
    - 小屏幕。
    - 大屏幕。
    - 键盘弹出。
    - 横竖屏如支持。
    - 长中文昵称。
    - 长英文错误文案。

11. 全功能回归。
    - Food。
    - Workout。
    - Profile。
    - Export。
    - AI Chat。
    - RAG。
    - Food Draft。

12. 文档回填。
    - 把已实现范围从 planned 调整为 implemented。
    - 不再把已实现的 V1 能力写成未来目标。
    - CHANGELOG 写清楚变更、原因、解决的问题、验证。

13. Release candidate build。
    - Android debug APK。
    - 如发布需要，再做 release build 签名流程。

### 自动化验证

必须运行：

```bash
flutter analyze
flutter test
flutter build apk --debug
```

建议补充：

- AI boundary regression tests。
- Error mapper tests。
- Account deletion tests。
- Subscription gating tests。
- Chat history pagination tests。
- Food Draft end-to-end repository tests。
- Context builder no-raw-history tests。
- Localization missing key checks。

后端验证：

- Auth expired。
- Subscription inactive。
- Gateway timeout。
- Invalid provider output。
- Account deletion。
- Request log retention。
- Production debug summary redaction。

### 人工安装审查

完整审查 checklist：

1. 基础启动。
   - 新装启动。
   - 升级安装。
   - 冷启动恢复。

2. Local 业务。
   - 新增饮食。
   - 编辑饮食。
   - 删除饮食。
   - 复制饮食。
   - 新增训练。
   - 编辑训练。
   - 删除训练。
   - 自定义动作。
   - Profile 设置。
   - Export。

3. 账号/Profile。
   - 未登录。
   - 登录。
   - 登出。
   - 重启恢复。
   - 离线查看缓存。
   - 离线不能保存。

4. AI Chat。
   - 普通消息。
   - 新建 session。
   - 切换 history。
   - 删除/归档 session。
   - 断网。
   - 未订阅。

5. RAG。
   - 中文 App 规则问答。
   - 英文 App 规则问答。
   - Meal Decision。
   - Weekly Review。
   - 数据不足提示。

6. Food Draft。
   - 文本食物估算。
   - 图片食物估算。
   - 追问。
   - 编辑。
   - 保存。
   - 丢弃。
   - 打开完整编辑页。

7. 安全边界。
   - AI 不静默写记录。
   - AI 不改目标。
   - AI 不改 strategy。
   - AI 不应用 carb taper。
   - AI 不删除记录。
   - 医疗问题不诊断。

8. 视觉。
   - AI 背景可读。
   - 消息列表后背景降亮度/饱和度。
   - 底部 nav pill 无整行背景。
   - 小屏无溢出。

### 阻断条件

以下问题不解决不能发布 V1：

- 账号间数据串扰。
- 未订阅可绕过服务端调用 AI。
- 删除账号不删除 Cloud Profile。
- AI 可静默写入或修改正式数据。
- Food Draft 保存错误或丢字段。
- RAG 默认上传完整历史。
- 生产日志保存不必要 raw context。
- 医疗/高风险输出越界。
- 断网/超时导致崩溃。
- Local 核心功能回归。
- `flutter analyze` 或 `flutter test` 失败。

### 文档更新

完成后更新：

- 所有 `docs/en/*`
- 所有 `docs/zh/*`
- `README.md`
- `CHANGELOG.md`
- 如有 API contract 文档，也同步更新

## 13. 跨阶段测试矩阵

| 测试项 | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 | Phase 6 |
| --- | --- | --- | --- | --- | --- | --- |
| `flutter analyze` | 必须 | 必须 | 必须 | 必须 | 必须 | 必须 |
| `flutter test` | 必须 | 必须 | 必须 | 必须 | 必须 | 必须 |
| Android debug build | 必须 | 必须 | 必须 | 必须 | 必须 | 必须 |
| Home 回归 | 必须 | 必须 | 必须 | 必须 | 必须 | 必须 |
| Food 回归 | 必须 | 必须 | 必须 | 必须 | 必须 | 必须 |
| Workout 回归 | 必须 | 必须 | 必须 | 必须 | 必须 | 必须 |
| Profile 回归 | 基础 | 必须 | 必须 | 必须 | 必须 | 必须 |
| Export 回归 | 抽查 | 抽查 | 抽查 | 抽查 | 抽查 | 必须 |
| AI 页面视觉 | 必须 | 必须 | 必须 | 必须 | 必须 | 必须 |
| 登录/订阅 | 不适用 | 必须 | 必须 | 必须 | 必须 | 必须 |
| Chat History | 不适用 | 不适用 | 必须 | 必须 | 必须 | 必须 |
| RAG | 不适用 | 不适用 | 不适用 | 必须 | 必须 | 必须 |
| Food Draft | 不适用 | 不适用 | 不适用 | 不适用 | 必须 | 必须 |
| 弱网/断网 | 基础 | 必须 | 必须 | 必须 | 必须 | 必须 |
| 安全边界 | 基础 | 基础 | 必须 | 必须 | 必须 | 必须 |
| 删除账号 | 不适用 | 基础 | 基础 | 基础 | 基础 | 必须 |

## 14. 每阶段人工安装审查模板

每次阶段完成并构建 APK 后，人工审查应记录：

```text
阶段：
构建版本：
构建日期：
测试设备：
Android 版本：
账号类型：
订阅状态：

1. 启动是否正常：
2. 现有 Local 功能是否正常：
3. 本阶段新增功能是否可见：
4. 本阶段新增功能是否符合设计：
5. 离线/弱网表现：
6. 错误提示是否可理解：
7. 是否出现 UI 溢出或遮挡：
8. 是否有隐私/安全边界问题：
9. 是否发现阻断问题：
10. 是否允许进入下一阶段：
```

建议结论格式：

```text
结论：通过 / 有条件通过 / 不通过
必须修复：
可后续优化：
备注：
```

## 15. 文档与 CHANGELOG 规则

每个阶段完成后都要判断是否需要更新：

- `README.md`
- `CHANGELOG.md`
- `docs/en/Product.md`
- `docs/zh/Product.md`
- `docs/en/AppGuide.md`
- `docs/zh/AppGuide.md`
- `docs/en/AgentDesign.md`
- `docs/zh/AgentDesign.md`
- `docs/en/Algorithm.md`
- `docs/zh/Algorithm.md`
- `docs/en/Database.md`
- `docs/zh/Database.md`
- `docs/en/Methodology.md`
- `docs/zh/Methodology.md`
- `docs/en/References.md`
- `docs/zh/References.md`
- `docs/FitLog_Agent_V1_Implementation.md`
- `docs/ROADMAP.md`

规则：

- 已经实现的能力不能继续写成 planned。
- 尚未实现的能力不能写成 shipped。
- 稳定设计事实进入 `docs/en/*` 和 `docs/zh/*`。
- 工程阶段计划进入 `docs/ROADMAP.md`。
- V1 总设计源进入 `docs/FitLog_Agent_V1_Implementation.md`。
- 历史变化进入 `CHANGELOG.md`。
- README 只做项目入口和文档索引。

## 16. Roadmap 调整规则

Roadmap 可以调整，但不能随意漂移。

允许调整的情况：

- Phase 0 技术选型导致 API contract 必须变化。
- 某阶段发现必须拆分才能安全验证。
- 某阶段发现两个步骤必须合并才能形成可安装版本。
- 后端/支付/平台限制导致顺序变化。

调整要求：

- 写清楚为什么改。
- 写清楚解决了什么风险。
- 写清楚影响哪些后续阶段。
- 更新 README 文档索引，如文件职责变化。
- 在 CHANGELOG 中记录简明变更。

不建议调整的情况：

- 为了赶进度把 RAG 和 Food Draft 写入合并。
- 为了赶进度跳过 Phase 2 账号/Profile。
- 为了赶进度让 AI 在无确认下写入正式记录。
- 为了赶进度把 debug log 暴露给用户。

## 17. 最终完成标准

V1 可以视为完成，必须同时满足：

- Phase 1-6 全部通过自动化验证。
- Phase 1-6 全部通过人工安装审查。
- 当前 Local 核心能力无回归。
- AI 页面、账号、订阅、Cloud Profile、AI Gateway、Chat History、RAG、Food Draft 均按设计工作。
- AI 不越权写入或修改正式数据。
- 删除账号和隐私边界明确可用。
- README 和设计文档反映真实已实现范围。
- CHANGELOG 记录完整但不膨胀。
- 没有阻断级 bug。
