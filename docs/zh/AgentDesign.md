# Agent 设计

## 目标

本文定义 FitLog_Agent V1 的 AI 与 Agent 边界。

FitLog_Agent 从 FitLog Local 复制而来。当前代码仍然保留本地确定性饮食记录、训练记录、Profile 设置、饮食算法、SQLite 存储和导出能力。Phase 1 已新增居中的 AI tab 和不可用 AI shell；云端 AI 辅助层仍属于后续阶段。Agent V1 不是自动 AI Coach，也不是完整云同步平台。

长期规则是：

```text
AI 可以生成草稿、解释规则、检索上下文、追问缺失信息。
AI 不能静默写入正式记录、修改目标、修改策略或删除数据。
```

## 当前实现基线

当前源码还没有 App 内部 LLM 执行能力。Phase 1 只实现 AI 导航入口和不可用 Chat shell。

当前代码未实现：

- 账号登录
- 云端 Profile
- 订阅校验
- AI Gateway
- 服务端统一管理的大模型 API key
- 远程 LLM 或多模态模型调用
- embeddings
- 向量数据库
- App 内部 RAG
- tool calling
- Agent loop
- AI 对话记忆
- Agent action/debug log

现有 AI 相关能力是用户中介流程，不是 App 内部 AI：

| 功能 | 当前行为 | App 内部 AI？ | 主要代码 |
| --- | --- | --- | --- |
| Prompt 复制 | App 提供提示词，用户复制到外部模型。 | 否 | `PromptTemplates`, `AddFoodPage._copyPrompt` |
| 外部 AI JSON 粘贴 | 用户手动粘贴外部模型生成的 JSON，FitLog 本地解析。 | 否 | `PasteAiResultPage`, `NutritionCalculator.parseAiFoodJson` |
| `source = ai_paste` | 保存后的饮食记录可标记来源是 AI 粘贴流程。 | 否 | `AppConstants.sourceAiPaste`, `FoodRecord.source` |
| Photo AI Analysis | Add Food 中可见的占位入口。 | 否 | `AddFoodPage` |
| AI Chat shell | 居中的 AI tab，包含不可用背景、可编辑输入框、模型选择器占位、历史入口占位和账号/订阅入口占位；当前不能发送。 | 否 | `AiPage`, `FitLogBottomNavBar` |

## V1 Agent 定位

Agent V1 是弱 Agent workflow 层，不是自主多步 Agent。

V1 新增：

- 云端账号和订阅状态
- 登录账号绑定的 Cloud Profile
- 服务端统一管理模型 API key
- AI Gateway
- 远程 LLM 和多模态模型调用
- AI Chat 内可由用户选择 ChatGPT/OpenAI 或千问/Qwen provider
- 位于底部导航正中间的全屏 AI Chat
- 云端 chat history
- 基于最小必要摘要的 Structured RAG
- 面向 FitLog 文档的 Document RAG
- schema-validated AI 输出
- Chat 内联草稿预览卡片
- 正式写入前的用户确认

V1 不新增：

- 用户自填模型 API key
- 开放式自主 Agent loop
- 多 Agent 系统
- 静默执行饮食计划
- 静默修改目标
- 静默修改 `carb_cycling` 或 `carb_tapering`
- 默认完整云同步 food/workout/weight 历史
- 用户业务数据向量库
- 基于业务记录的长期 semantic memory
- GraphRAG
- 医疗诊断或治疗建议

## 入口

Agent 主入口是底部导航正中间的新 AI tab：

```text
Home | Food | AI | Workout | Profile
```

AI 页面是一个简单的全屏 Chat。它不是 quick chips 工作台。除了 Add Food 的拍照识别路径，其它 Agent workflow 默认都从 AI 页面发起。

允许的入口：

| 入口 | 用途 | 边界 |
| --- | --- | --- |
| AI Chat tab | 饮食估算、用餐建议、周复盘、App 规则问答的主入口。 | 发送消息需要登录、联网和有效订阅。 |
| Add Food 拍照识别 | Food 流程内的食物图片识别快捷入口。 | 仍然只生成草稿，保存前必须确认。 |
| 现有外部 JSON 粘贴 | 兼容本地工作流。 | 用户中介的外部 AI，不是 Agent V1。 |

## AI 页面行为

AI 页面使用全屏动效背景和极简 Chat 布局。

必备元素：

- 全屏动态背景
- 中心状态文案，带用户昵称，例如“我在听，RINKO”
- 底部输入框
- 输入区附近的紧凑模型选择器，可选 ChatGPT 和千问
- 右上角账号/订阅状态入口
- 左侧可折叠的云端历史会话栏
- 不使用 quick chips
- 必要时显示小型隐私/状态提示

动效状态保持简单：

| 状态 | 视觉行为 | 产品含义 |
| --- | --- | --- |
| Ready | 彩色柔和、缓慢流动。 | AI 可用，等待输入。 |
| Processing | 稍微加速或层次增加。 | 正在路由、检索上下文或生成。 |
| Needs clarification | 动效放慢，同时突出输入区或草稿卡。 | AI 需要用户补充缺失信息。 |
| Disabled | 灰色、低动态背景。 | 用户离线、未登录或未订阅。输入框仍可编辑，但不能发送。 |

当消息列表变长并可滚动时，背景动效始终保留，但消息层后方应降低亮度和饱和度，保证可读性。

底部导航应是浮动白色 pill。导航组件本身不能在 pill 外绘制整行背景色；pill 外看到什么，应由当前页面或 root shell 背景决定。Phase 1 只在 AI tab 启用 `extendBody`，让 AI 动效背景铺到导航栏后方，pill 两侧和底部安全区缝隙都能透出 AI 背景。Home、Food、Workout 和 Profile 暂不启用 `extendBody`，以免现有滚动内容滑到导航栏下方；这些页面可以继续露出既有浅色页面背景。

AI 页面底部可以保留一层很淡的白色渐变 veil。它的作用是柔化底部光效和系统安全区，不是不透明遮罩；未来彩色动效仍应能在 bottom navigation 两侧被看见。

当 AI Chat 进入真实消息列表阶段时，必须先解决滚动遮挡：

- 消息列表底部需要预留足够空间，覆盖 composer、模型选择器、bottom navigation、系统安全区和底部 veil。
- 用户滚到最后一条消息时，最后一条消息应停在 composer 上方的正常阅读距离，不能被输入框或导航栏遮住。
- composer 和消息列表不能各自独立计算底部间距；它们应共用同一个底部遮挡高度，包括键盘、composer、模型选择器、bottom navigation、系统安全区和 veil。
- 键盘弹起时，消息列表需要和 composer 同步更新 bottom inset，使当前输入上下文和最新消息停在输入框上方。
- 导航栏与屏幕底边之间的缝隙只应该露出 AI 背景和 veil，不应该让消息正文从这个缝隙下穿过去。

中心状态文案和 composer hint 不能表达同一句话。空状态可以保留中心状态，例如“我在听，RINKO”；composer hint 应提供轻量输入提示，例如“快问问 FitLog”。键盘聚焦本身不应让中心状态突然消失或明显跳动；只有进入真实对话状态后，消息列表才自然成为主体。

## V1 支持的 Workflow

### Food Draft Workflow

输入：

- 文字描述
- 食物照片
- 用户补充信息
- 云端 Profile
- 相关时的选中日期
- 相关时的本地当日摘要

行为：

1. AI 提取候选食物、分量、烹饪方式和不确定点。
2. 如果食物类型、肉类类型、分量、实际食用比例或烹饪方式不清楚，AI 先追问，不强行自信估算。
3. AI 返回经过 schema 校验的草稿数据。
4. App 在 Chat 内展示 Food Draft 卡片，视觉上与记录页 UI 保持一致。
5. 用户可以在 Chat 内做轻量编辑。
6. 用户可以保存、丢弃或打开完整饮食编辑页。
7. 只有用户确认后才写入正式饮食记录。

### Meal Decision Workflow

输入：

- 云端 Profile
- 当前饮食阶段、计算模式和策略
- 选中日期饮食摘要
- 选中日期训练摘要
- 剩余 kcal/macros 或宏量目标
- 用户问题

行为：

- 回答“下一餐吃什么”“这个外卖能点吗”“为什么今天饿”等问题。
- 尊重 `energy_ratio` 和 `gram_per_kg` 的不同语义。
- 解释建议基于蛋白缺口、碳水剩余、脂肪控制、训练日上下文还是记录不确定性。
- 不修改目标或策略。

### Weekly Review Workflow

输入：

- 云端 Profile
- 7/14 天本地摘要
- 饮食记录覆盖率
- 训练稳定性
- 可用时的体重趋势
- 当前 `diet_plan_strategy`

行为：

- 总结行为模式和数据缺口。
- 解释进展停滞的可能原因。
- 区分行为建议和正式策略修改。
- 把 `carb_cycling` 和 `carb_tapering` 作为当前配置策略解释，而不是 AI 可静默执行的动作。
- 可以提出行动建议，但任何正式修改都要回到用户确认的 UI 流程。

### App Logic Q&A Workflow

输入：

- 用户语言
- 同语言文档检索结果
- 相关时的当前 App 上下文

行为：

- 回答 FitLog 如何工作。
- 解释字段、饮食模式、训练热量规则、carb cycling、carb tapering、导出和隐私边界。
- 用户用中文提问时检索中文文档；用户用英文提问时检索英文文档。
- 不把计划中的功能说成已经上线。

## Context 与 RAG

V1 使用受控检索，因为许多有用回答都需要上下文。例如用户问“为什么最近没瘦”，模型需要近期摄入、训练、体重和 Profile 上下文才能回答。

### Structured RAG

Structured RAG 指 App 或后端调用已知 context-builder function，把紧凑结构化摘要发送给 AI Gateway。

例子：

- `daily_summary`
- `recent_food_summary`
- `recent_workout_summary`
- `weight_trend_summary`
- `profile_context`
- `strategy_context`
- `selected_day_context`

规则：

- 只上传当前请求需要的最小上下文。
- 优先上传摘要，不上传原始记录。
- 确定性本地计算仍是目标和摘要的来源。
- V1 默认不上传完整 food/workout/weight 历史。

### Document RAG

Document RAG 指检索 FitLog 文档片段来回答 App 规则问题。

允许的检索方式：

- 关键词检索
- 全文检索
- 向量/语义检索
- 混合检索

向量检索允许用于产品、帮助、设计文档。这不等于批准建立用户业务数据向量库，也不等于批准对 food/workout/weight 记录做长期 semantic memory。

文档索引范围：

- 英文问题使用 `docs/en/*`
- 中文问题使用 `docs/zh/*`
- 可由这些设计文档派生稳定帮助片段

### 明确不做

- 用户业务数据 embeddings
- 长期用户 semantic memory
- GraphRAG
- 让模型任意探索数据库
- 开放式 tool execution loop

## 云端数据边界

V1 云端存储用于账号绑定的 AI 体验，不用于完整业务数据迁移。

V1 云端保存：

- 账号身份
- 订阅状态
- Cloud Profile
- AI chat sessions
- AI chat messages
- AI 最终回答
- AI request/response metadata
- 用于运维和排错的紧凑 debug/action summaries

V1 默认不云同步：

- 完整饮食历史
- 完整训练历史
- 完整体重历史
- 本地导出文件
- 本地训练草稿

当用户请求需要时，本地记录可以被汇总后临时发送给 AI Gateway。

## Cloud Profile

Profile 跟账号走。未登录前，用户没有正式 Profile。

规则：

- 登录后 Cloud Profile 是权威版本。
- 设备可以缓存 Profile 用于显示。
- 离线时禁止修改 Profile。
- 离线时 Profile 页面可以显示缓存值，但不能保存修改。
- AI 默认使用 Cloud Profile 作为权威上下文。
- 请求可携带 `profile_version` 检测上下文是否过期。
- 删除账号时删除 Cloud Profile。

因为 V1 禁止离线保存 Profile 修改，所以不会产生 pending profile merge 冲突。如果未来版本允许离线修改，必须先定义字段级合并规则。

## 订阅与可用状态

V1 使用订阅制，而不是用户可见的按次额度。

以下状态禁用 AI 发送：

- 用户未登录
- 设备离线
- 订阅未生效

禁用状态下，App 仍可允许用户输入或编辑未完成 prompt。真正发送需要所有条件都满足。

后端可以内部记录请求次数和模型成本，但 V1 不显示额度或剩余次数 UI，除非产品决策改变。

## Request、Response 与 Debug 留存

V1 默认建议：

- 云端保存 AI sessions 和最终 chat messages，使登录后的历史记录可跨设备查看。
- 保存 request/response metadata，用于稳定性、订阅审计、滥用防护和排错。
- 保存紧凑 debug summaries，不保存冗长 chain-of-thought 或无限制 tool traces。
- 当紧凑上下文摘要足够时，不保存完整检索到的本地记录 payload。
- 删除账号时按删除策略移除账号绑定的 Profile 和 chat history。

Debug log 应区分环境：

| 环境 | 留存行为 |
| --- | --- |
| Development | 可保留更详细 gateway logs 以便调试。 |
| Production | 只保存紧凑 metadata 和脱敏摘要。 |
| User-facing UI | 只展示最终消息和相关草稿卡，不展示内部轨迹。 |

## Tool 与写入权限

AI 只能通过 typed draft object 提议写入。

| 动作 | AI 是否可以做 | 是否需要用户确认？ |
| --- | --- | --- |
| 创建饮食草稿 | 可以 | 保存需要确认 |
| 修改草稿字段 | 可以建议或预填 | 用户控制最终值 |
| 保存正式饮食记录 | 不能静默保存 | 需要 |
| 修改训练记录 | V1 只做草稿或解释 | 实现后仍需要 |
| 修改 Profile | V1 只解释 | 需要通过 Profile UI |
| 修改饮食阶段/模式/策略 | 只解释 | 需要通过 Profile UI |
| 应用 carb taper | 只解释或建议 | 需要通过现有 review flow |
| 删除记录 | 不可以 | 需要现有破坏性确认 |

## 安全与质量规则

- 模型不确定时必须追问。
- 数据不足时必须说明缺什么。
- 遇到医疗问题时，只提供一般营养/健身信息，并建议咨询专业人士。
- 不提供诊断或治疗。
- 不把 AI 估算当作精确营养事实。
- AI 草稿和正式写入之间必须有用户确认。
- 本地确定性算法仍是目标和摘要的权威来源。
- 文档和 UI 文案必须区分已实现行为与 V1 计划行为。

## 代码引用

当前 Local 基线：

- App shell: `lib/main.dart`, `lib/app.dart`
- AI shell: `lib/features/ai/ai_page.dart`
- Bottom navigation: `lib/core/widgets/fitlog_bottom_nav_bar.dart`
- 饮食录入和 AI-adjacent paste flow: `lib/features/food/*`
- Prompt templates: `lib/core/constants/prompt_templates.dart`
- JSON parser: `lib/domain/services/nutrition_calculator.dart`
- Daily summaries: `lib/domain/services/daily_summary_service.dart`
- Diet targets: `lib/domain/services/macro_target_calculator.dart`
- Strategies: `lib/domain/services/carb_cycling_calculator.dart`, `lib/domain/services/carb_taper_review_service.dart`, `lib/domain/services/diet_plan_strategy_service.dart`
- Workout calories: `lib/domain/services/workout_calorie_calculator.dart`
- Database: `lib/data/db/app_database.dart`
- Repositories: `lib/data/repositories/*`

计划中的 Agent V1 surface：

- cloud auth/session layer
- Cloud Profile repository
- AI Gateway client
- context-builder services
- chat-history repository
- draft-card UI components
