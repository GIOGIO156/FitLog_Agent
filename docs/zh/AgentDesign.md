# Agent 设计

## 目标

本文定义 FitLog_Agent V1 的 AI 与 Agent 边界。

FitLog_Agent 从 FitLog Local 复制而来。当前代码仍然保留确定性饮食记录、训练记录、Profile 设置、饮食算法、本地 cache 和导出能力。已实现的 Agent 基线包含居中的 AI tab、账号状态、订阅状态、Cloud Profile 基础、登录后的 body/food/workout 正式记录云端 source of truth、通过服务端 OpenAI/Qwen provider 的 AI Chat、最多三张图片的千问多模态 Chat、云端 chat history、Chat 内联 Food Draft 和 Workout Draft artifact 卡片、紧凑同会话 context builder，以及可以用文字描述和最多三张可选图片创建可编辑 Food Draft 的 Add Food AI 食物分析。当前也已新增 Home 选中日期 summary cache 与 stale-while-revalidate、登录态恢复后的首屏账号 cache 绑定，把可重建 `daily_summaries` upsert 到云端，首屏后预热近期 summaries，从云端正式 records 导出，并写入紧凑 AI request/debug summaries。RAG、超过三张 Chat 图片、长期图片存储和 autonomous actions 属于后续阶段。Agent V1 不是自动 AI Coach，也不是让模型自由读写数据库的平台。

长期规则是：

```text
AI 可以生成草稿、解释规则、检索上下文、追问缺失信息。
AI 不能静默写入正式记录、修改目标、修改策略或删除数据。
```

## 当前实现基线

当前源码没有端上模型执行能力。远程 AI 调用通过 Supabase Edge Functions 执行，provider key 由服务端管理。已实现的 Agent shell/账号基线包含 AI 导航入口、可用性 gating 的 Chat 页面、账号/订阅状态入口、Profile 登录 gate、Cloud Profile mapper/repository 路径和用户记录摘要授权。登录态 body、food、workout 正式记录的 Cloud Records source-of-truth 路径，以及 daily-summary cache/云端 projection hardening 也已实现。Phase 4 Step 1 新增 AI chat sessions/messages、request logs、compact debug summaries 的 Supabase 表，以及 AI Gateway request/response/error mapping 的 Flutter contract models。Phase 4 Steps 2-4 新增 `ai-chat-route` Supabase Edge Function、服务端 chat-turn RPC、AI 页面 Gateway client、云端 chat-history repository/controller，以及服务端 OpenAI/ChatGPT 与 Qwen text provider 路由。Phase 4 Step 5 新增本机模型选择持久化、只表达可用性的状态 pill、chat inline 重命名/删除确认，以及通过 `ai-food-photo-analyze` 的 Add Food AI 食物分析。Phase 4 Step 6 新增最多三张图片的 AI Chat 千问附件、多模态 Food Draft 响应解析、用户点击后重建 Food Preview 的 Chat artifact 卡片、AI 页背景性能优化，以及稳定的重命名/loading 切换。当前 Add Food 分析路径支持纯文字食物描述，也支持最多三张可选图片，并会在打开相机/相册前保存很小的本地 picker 恢复标记，让 Android activity 重启后可恢复草稿。当前 chat 路径也支持 typed Workout Draft artifact，用户点击后才重建现有训练编辑草稿，并会发送由近期文本和草稿摘要组成的紧凑同会话 context。当前 chat 路径不执行 RAG、不上传完整记录历史、不长期保存图片 bytes，也不自动写入正式业务记录。

当前代码未实现：

- embeddings
- 向量数据库
- App 内部 RAG
- 超过三张的 Chat 图片附件
- 超出紧凑同会话文本和草稿摘要之外的 records summary/context 检索
- tool calling
- Agent loop
- 长期语义 AI 对话记忆
- compact request summaries 之外的 Agent action/debug workflow
- 生产支付 provider 或订阅管理

现有 AI 相关能力是用户中介流程，不是 App 内部 AI：

| 功能 | 当前行为 | App 内部 AI？ | 主要代码 |
| --- | --- | --- | --- |
| Prompt 模板文案 | App 保留外部模型 fallback 说明文案，但 Add Food 不再把复制 prompt 作为主流程。 | 否 | `PromptTemplates`, `AppStrings` |
| 外部 AI JSON 粘贴 | 用户手动粘贴外部模型生成的 JSON，FitLog 本地解析。 | 否 | `PasteAiResultPage`, `NutritionCalculator.parseAiFoodJson` |
| `source = ai_paste` | 保存后的饮食记录可标记来源是 AI 粘贴流程。 | 否 | `AppConstants.sourceAiPaste`, `FoodRecord.source` |
| AI Food Analysis | Add Food 第一入口。用户可以提交纯文字食物描述，也可以添加最多三张可选拍照/相册图片，点击缩略图切换放大预览或删除单张图片，并在系统 picker 打开期间保留本地恢复标记；`ai-food-photo-analyze` 调用千问并返回 schema 校验后的 Food Draft，然后打开 Food Preview。 | 服务端中介草稿 | `AddFoodPage`, `PhotoFoodAnalysisPage`, `AiFoodPhotoAnalysisClient`, `ai-food-photo-analyze` |
| AI Chat 页面 | 居中的 AI tab，包含可用性 gating 背景、可编辑输入框、最多三张图片附件、模型选择器、云端 history 侧栏和账号/订阅状态入口；只有登录、订阅、active-device 和 provider 配置校验通过后，才能通过 OpenAI/Qwen 发送文本、通过 Qwen 发送最多三张图片。Food Draft 和 Workout Draft 响应会渲染 Chat artifact 卡片；用户点击确认按钮后才重建 Food Preview 或现有训练编辑草稿，并且仍需用户确认保存后才写正式记录。 | 服务端中介文本或草稿 | `AiPage`, `AiChatController`, `SupabaseAiChatRepository`, `SupabaseAiGatewayClient`, `ai-chat-route` |
| Phase 4 chat data/contract foundation | AI chat sessions/messages、request logs、compact debug summaries 的 Supabase schema，以及 Flutter request/response/error contract models；不发送消息，也不调用 provider。 | 否 | `202606290001_phase4_ai_chat_foundation.sql`, `AiGatewayRequest`, `AiGatewayResponse` |
| Phase 4 Gateway 和 providers | Supabase Edge Function 校验 auth、subscription 和 active-device 状态，调用用户选择的服务端文本 provider 或 Qwen 多模态 provider，接收紧凑同会话 `conversation_context`，校验 typed Food Draft 或 Workout Draft payload，然后通过服务端 RPC 持久化 user/assistant 文本 turn、request log 和 compact debug summary。 | 服务端中介文本或草稿 | `ai-chat-route`, `record_ai_chat_turn`, `openai_provider.ts`, `qwen_provider.ts` |
| 账号/Profile 基础 | 配置 Supabase 后的邮箱密码登录、登录态本机持久化恢复、带本机 PKCE verifier 的注册邮箱验证码流程、订阅状态查询、Cloud Profile 读取/保存路径、Profile 登录 gate 和缓存展示 fallback。 | 否 | `AccountController`, `AuthRepository`, `SubscriptionRepository`, `CloudProfileRepository`, `ProfilePage` |
| 用户记录摘要授权 | 每账号本地设置，控制未来 AI 回答是否可使用用户记录摘要。当前文本 chat 只保存授权，不上传完整业务历史或 records summary；后续基于摘要的 AI workflow 应使用云端 summary/context builder。 | 否 | `AiLocalContextPermissionRepository`, `AiPage` |

## V1 Agent 定位

Agent V1 是弱 Agent workflow 层，不是自主多步 Agent。

V1 新增：

- 云端账号和订阅状态
- 登录账号绑定的 Cloud Profile
- Cloud Records 和 daily summaries 作为正式记录来源
- 服务端统一管理模型 API key
- AI Gateway
- 远程 LLM 和多模态模型调用
- AI Chat 内可由用户选择 ChatGPT/OpenAI 或千问/Qwen provider
- 位于底部导航正中间的全屏 AI Chat
- 云端 chat history
- 基于最小必要摘要的 Structured RAG
- 面向 FitLog 文档的 Document RAG
- schema-validated AI 输出
- Chat 内联 Food Draft 和 Workout Draft 预览卡片
- 正式写入前的用户确认

V1 不新增：

- 用户自填模型 API key
- 开放式自主 Agent loop
- 多 Agent 系统
- 静默执行饮食计划
- 静默修改目标
- 静默修改 `carb_cycling` 或 `carb_tapering`
- 完整历史一次性下放到本地 SQLite
- 把本地 cache 当作 AI 或产品权威来源
- 用户业务数据向量库
- 基于业务记录的长期 semantic memory
- GraphRAG
- 医疗诊断或治疗建议

## 入口

Agent 主入口是底部导航正中间的新 AI tab：

```text
Home | Food | AI | Workout | Profile
```

AI 页面是一个简单的全屏 Chat。它不是 quick chips 工作台。除了 Add Food 的 AI 食物分析路径，其它 Agent workflow 默认都从 AI 页面发起。

允许的入口：

| 入口 | 用途 | 边界 |
| --- | --- | --- |
| AI Chat tab | 饮食估算、用餐建议、周复盘、App 规则问答的主入口。 | 发送消息需要登录、联网和有效订阅。 |
| Add Food AI 食物分析 | Food 流程内的文字或图片食物估算快捷入口。 | 仍然只生成草稿，保存前必须确认。 |
| 现有外部 JSON 粘贴 | 兼容本地工作流。 | 用户中介的外部 AI，不是 Agent V1。 |

## AI 页面行为

AI 页面使用全屏程序化液态渐变背景和极简 Chat 布局。

Chat 交互强调色跟随主题，但背景保留自己的 AI 视觉身份：用户气泡、发送/确认按钮、草稿 artifact 边框、Markdown 强调色和 history 选中态使用当前 FitLog 主题强调色。Green 保持绿色，Black/黑橙使用柔和但明确的橙色。可用状态仍使用语义绿色表示 ready，而不是变成品牌橙色。液态渐变背景仍是 AI 页自己的粉绿蓝色场，不切成整页深色背景。

必备元素：

- 全屏动态背景
- 中心状态文案，优先使用已保存的 Cloud Profile 昵称，例如“我在听，RINKO”
- 底部输入框
- 输入区附近的紧凑模型选择器，可选 ChatGPT 和千问
- 右上角账号/订阅状态入口
- 左侧可折叠的云端历史会话栏
- 不使用 quick chips
- 必要时显示小型隐私/状态提示

动效状态保持简单，并且不应抢夺阅读注意力：

| 状态 | 视觉行为 | 产品含义 |
| --- | --- | --- |
| 空闲首页 | 竖屏手机上粉色和蓝色色场视觉均衡，绿色色带包裹中心状态文案，整体色场有可见流动。 | AI 页面可用或已进入，等待用户输入。 |
| 首条消息前输入 | 即使键盘打开，也保持可见的首页动效。 | 用户还未发出第一条消息，页面仍处于 landing 输入状态。 |
| 已发送、历史会话、等待或阅读 | 安静、低幅度色场流动。 | 首条消息已发出、打开了已有历史会话、正在等待回复或阅读消息，聊天内容拥有注意力。 |
| Disabled | 灰色、低动态但仍持续流动的色场背景。 | 用户离线、未登录或未订阅。输入框仍可编辑，但不能发送。 |

当消息列表变长并可滚动时，背景动效始终是 AI 页面背后的单个全屏色场。它在消息层后方安静流动并降低亮度、饱和度，保证可读性，但不应被拆成只有顶部/底部在动的分段遮罩，也不应实现成一张静态图的整体平移或明显的局部圆形色块移动。颜色过渡需要保留足够的最小宽度和采样平滑度，避免粉色/蓝色同时挤压时把绿色色带压成明显块状条纹。背景不应完全停止，包括键盘打开时。

等待 provider 回复时，应由 chat UI 表达活跃状态，而不是让背景加速。发送后 composer 立即清空，用户消息进入 pending 气泡；等这个气泡有了真实布局位置后，消息列表把它锚到顶部操作区下方的可读边界。这个发送锚点不同于消息 viewport 的物理顶端，也不同于顶部渐变退场区。为了让 pending 用户气泡和 assistant loading 气泡稳定靠上，可以保留很小的活动轮次尾部填充，但它不能表现成一大段可滚动空白，用户手势也不能把 pending/loading 这一组完全滑出视野。assistant loading 气泡显示到最终 assistant 消息从云端 history 重新加载完成。assistant 回复出现后不再强制二次滚动。

底部导航应是主题化浮动 pill。导航组件本身不能在 pill 外绘制整行背景色；pill 外看到什么，应由当前页面或 root shell 背景决定。非 AI tab 使用实体主题色 pill，避免页面文字从导航下方透出；AI tab 使用玻璃态 pill，让动效背景仍然可见。Root shell 不能为了导航栏缩短页面主体。可滚动页面自己负责在内容底部预留阅读空间，使最后一段内容能滚到浮动导航上方；固定底部操作按钮使用导航避让；Home 首屏只保留小的导航邻近间距，避免仪表盘被压缩。

AI 页面底部可以保留一层很淡的白色渐变 veil。它的作用是柔化底部光效和系统安全区，不是不透明遮罩；未来彩色动效仍应能在 bottom navigation 两侧被看见。键盘未弹起时，输入框应保持带正常阅读间距的底部悬浮 pill；键盘弹起时，输入框应贴住键盘顶部，切换为完整悬浮且实心的 input accessory 状态，消息列表 viewport 延伸到输入框底部/键盘顶部，让输入框只以 pill 本体浮在内容上方，不再在输入框外侧留下额外 gap、半高遮罩或键盘上方底部背景带；最后一条气泡和输入框之间的安全距离由消息列表自己的底部 padding 提供。聊天列表靠近边缘时应使用不对称轻柔 alpha 渐隐，而不是硬矩形裁切：顶部可使用更长退场弱化已读内容和顶部控件的混杂，底部应保持短退场，避免最后气泡像被渐变侵蚀。

AI Chat 滚动几何必须统一处理遮挡：

- 消息列表 viewport 可以从 AI SafeArea 顶部开始，并通过内部 top padding 把默认可读内容放到 history/account/provider 控件下方。
- 消息列表 viewport 的上下边缘应使用 soft-edge mask，而不是可见背景板或硬裁切，避免卡片边缘出现被切断的感觉。
- 发送锚点必须指向普通消息布局使用的同一条顶部可读 padding，而不是 `Scrollable.ensureVisible(alignment: 0)`，避免 pending 气泡落进顶部渐变区。
- 消息列表底部需要预留足够空间，覆盖实测 composer 高度、bottom navigation、系统安全区、底部 veil，以及消息列表自己的底部安全 padding。
- 发送中的锚点必须指向已经完成布局的 pending 用户气泡。如果需要 fallback scroll 来让这个气泡进入布局范围，落点应在活动轮次附近，不能跳到超大空白 spacer 的底部。
- 用户滚到最后一条消息时，最后一条消息应停在 composer 表面上方，不能被输入框或导航栏遮住；键盘弹起时，这段安全距离来自消息列表内部 padding，而不是把 viewport 裁在输入框顶边或添加输入框外侧背景。
- composer 和消息列表不能各自独立计算底部间距；它们应共用实测 composer、键盘、bottom navigation、系统安全区、veil，以及键盘未弹起时外部阅读间距这些几何信息。
- 键盘弹起时，composer 需要贴住键盘顶部，消息列表 viewport 需要延伸到悬浮 composer 后方并截止在键盘顶部，只用列表内部的气泡安全 padding 让最后一条气泡停在输入框上方。
- 导航栏与屏幕底边之间的缝隙只应该露出 AI 背景和 veil，不应该让消息正文从这个缝隙下穿过去。

中心状态文案和 composer hint 不能表达同一句话。空状态可以保留中心状态，例如“我在听，RINKO”，并优先使用已保存的 Cloud Profile 昵称，再回退到 auth display name；composer hint 应提供轻量输入提示，例如“快问问 FitLog”。键盘聚焦本身不应让中心状态突然消失或明显跳动；只有进入真实对话状态后，消息列表才自然成为主体。

assistant 消息应通过维护中的 GitHub-flavored Markdown 渲染器按 App 样式展示，而不是继续维护手写 Markdown parser。assistant 文本可选择，用户消息保持可选择的普通文本，复制应通过系统文字选择菜单完成，而不是提供每条消息独立复制按钮。Markdown 渲染不能加载远程图片或执行链接动作。可保存业务草稿只能来自经过 Gateway 校验的 draft payload，并且仍需用户确认。Chat 返回 Food Draft 或 Workout Draft 时，assistant message 会把轻量 artifact snapshot 存在 `final_answer_json`，并展示原生确认按钮；用户点击后，App 才用 snapshot 在本地重建 Food Preview 或现有训练编辑草稿，而不是在后台保留一个待命草稿页面。如果历史 snapshot 已无法安全重建编辑页，卡片仍保留摘要，但确认按钮会变成灰色不可用。

AI Chat 草稿回复不应依赖“provider 普通解释 + 裸 JSON 粘贴”的混合输出。面向 provider 的稳定 contract 应是一个机器可读 envelope：`message.text` 放友好的用户解释、估算依据、不确定点和确认提示，`draft` 放经过校验的 Food Draft 或 Workout Draft。Gateway 可以为了鲁棒性从 provider prose 中恢复合法 draft 对象，但用户界面应展示解析后的 `message.text` 和原生 artifact 卡片，而不是原始 JSON。专用 Add Food AI 食物分析 endpoint 仍是纯结构化 Food Draft JSON workflow，不需要聊天式解释。

未发送的输入框内容是当前运行期内的设备级本地草稿。它应在切换 tab 和可用状态变化时保留，直到用户删除或发送。发送时 composer 立即清空，文本进入 pending 用户气泡；如果发送失败，应恢复草稿以便重试。退出登录或切换账号时应清空，避免上一账号上下文残留；草稿只有发送成功后才能进入云端 chat history。

## V1 支持的 Workflow

### Food Draft Workflow

输入：

- 文字描述
- 可选食物照片
- 用户补充信息
- 云端 Profile
- 相关时的选中日期
- 相关时的云端当日摘要

行为：

1. AI 提取候选食物、分量、烹饪方式和不确定点。
2. 如果食物类型、肉类类型、分量、实际食用比例或烹饪方式不清楚，AI 先追问，不强行自信估算。
3. AI 返回经过 schema 校验的草稿数据。
4. 专用 Add Food AI 食物分析路径在 schema 校验通过后打开现有 Food Preview 编辑页；当前已实现的 Chat 图片草稿路径先展示 Chat artifact 卡片，只有用户点击确认按钮后才打开 Food Preview。
5. 用户可以在保存前编辑草稿字段。
6. UI 提供对应路径时，用户可以保存、丢弃或打开完整饮食编辑页。
7. 只有用户确认后才写入正式饮食记录。

### Workout Draft Workflow

输入：

- 文字描述
- 当前请求包含图片时的图片上下文
- 用户补充信息
- 相关时的选中日期

行为：

1. AI 提取候选训练记录名称、日期、动作、组数、有氧时长、强度和不确定点。
2. 如果动作、重量、次数、时长或强度不清楚，AI 最多追问一轮，并在这一轮中列出会明显影响草稿的缺失字段。
3. 如果用户回复仍不完整或表示不知道，AI 返回 best-effort 的 schema 校验 Workout Draft，把缺失值留空并把不确定点写入 notes，而不是继续追问。
4. AI 返回经过 schema 校验的 Workout Draft 数据。
5. assistant message 先显示 Chat artifact 卡片，只有用户点击确认按钮后才打开现有训练编辑草稿。
6. 如果本机已经有未保存训练编辑草稿，App 会先询问是否替换。
7. 用户可以在保存前编辑训练草稿。
8. 只有用户在训练编辑页保存后，才写入正式训练记录。

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
- 7/14 天云端摘要
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

当前 AI Chat 路径只实现紧凑同会话 context builder。它会发送近期文本 turn 以及 Food Draft / Workout Draft artifact 摘要，让模型理解当前会话，但不会发送历史原图、base64 payload、完整业务历史或任意数据库结果。这个同会话 context 不是 RAG。

### Structured RAG

Structured RAG 指后端或 App 调用已知 context-builder function，把紧凑结构化摘要发送给 AI Gateway。Phase 3 后，用户记录上下文应来自云端 records / daily summaries / summary builder，而不是本地 SQLite cache。

例子：

- `daily_summary`
- `recent_food_summary`
- `recent_workout_summary`
- `body_metric_summary`
- `weight_trend_summary`
- `profile_context`
- `strategy_context`
- `selected_day_context`

规则：

- 只上传当前请求需要的最小上下文。
- 优先上传摘要，不上传原始记录。
- 确定性计算仍是目标和摘要的来源。
- 不上传完整 food/workout/body 原始历史。
- 不给模型自由数据库查询工具。

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

V1 云端/本地数据权威、cache、写入、读取、异常和修复规则由 `CloudLocalDataBoundary.md` 维护。AgentDesign 只规定 AI 如何使用这些数据。

AI context 应优先使用 Cloud Profile、云端 records/daily_summaries 或受控 summary/context builder 生成的紧凑摘要。AI Gateway 不应把本地 SQLite cache 当权威上下文，也不应默认上传完整原始历史。

V1 采用单 active device。AI context 构建和 AI Gateway 发送都必须来自当前 active device/session；被新设备替换的旧设备不能继续使用本地 cache 发送 AI 请求。

V1 默认不提供给模型：完整原始饮食历史、完整原始训练历史、完整原始身体指标历史、本地导出文件或本地训练草稿。需要记录上下文时，应配合用户可见的授权或设置，并发送最小必要摘要。

已实现的食物分析和图片路径都是受限 workflow，不是 RAG。Add Food 会把文字描述和零到三张压缩后的 JPEG/PNG/WebP 图片发送到 `ai-food-photo-analyze`；AI Chat 在选择千问时可以通过 `ai-chat-route` 发送最多三张 JPEG/PNG/WebP 图片。Edge Functions 只把当前请求输入转发给千问，校验结构化 Food Draft 或 Workout Draft payload，并且不保存原图或 base64 payload。Add Food 和 AI Chat request logs 会写入通过校验的 `image_count`，纯文字食物分析为 `0`；chat history 持久化文本 turn，并为返回的 draft 保存轻量 artifact snapshot 和摘要。

## Cloud Profile

Profile 跟账号走。未登录前，用户没有正式 Profile，Profile 页面应显示登录/onboarding 入口，而不是本地 Profile 编辑器。当前认证入口使用当前主题纯色背景、无星 FitLog logo base asset 与基于 SVG 曲线并贴近 logo 右上角的饱和固定圆润 AI 四角星群错峰呼吸闪烁动画，星群经过轻微左下位置微调且最小态保持更饱满，并统一使用 app 主题字体 `NotoSansSC` 与中等/半粗登录文字层级，需要后端配置提示时提示位于页面顶部；键盘关闭时静态入口不可上下滑动，输入框聚焦并弹出键盘时切换为紧凑可滚动布局，包含邮箱密码登录，以及注册邮箱验证码和密码确认表单。注册不收集 username；昵称/display name 仍属于 Cloud Profile，并通过 Profile onboarding 填写。

规则：

- 登录后 Cloud Profile 是权威版本。
- Supabase 登录态会保存在本机，并在 App 启动时恢复。只有主动退出登录、切换账号或登录态无法恢复时才清空。
- 如果账号还没有 `cloud_profiles` row，App 会自动初始化默认 Cloud Profile，体验应等同于 Local 首次打开时看到的默认 Profile。
- 登录和注册错误会保留当前认证表单，并通过底部 snackbar 显示可读提示。Supabase 原始异常文本只应保留在 repository 诊断边界内。
- Cloud Profile 加载/保存失败应映射到稳定诊断码，覆盖表缺失、schema 不完整、字段类型不匹配、RLS 拦截、auth 过期、约束失败、网络失败和通用读取/保存失败。
- 订阅状态加载与 Cloud Profile 加载相互独立。订阅查询失败但 Cloud Profile 加载成功时，Profile 仍可使用，AI 发送保持不可用。
- 设备可以缓存 Profile 用于显示，但本地缓存写入失败不能阻塞已经加载成功的权威 Cloud Profile。云端刷新期间，只有账号绑定的缓存元数据匹配当前登录账号时，才可先显示缓存 Profile。
- Profile UI 修改先进入页面本地草稿。点按和输入会立刻更新 Profile 页预览，已改区块显示更醒目的已修改标记，昵称和当前身体资料没有卡片级保存键，底部“保存更改”条贴近 Profile body 底部并向上展开紧凑改动摘要，然后一次性 upsert 完整 Cloud Profile snapshot。
- Profile 页面里的当前身体指标，包括体重、体脂和腰围，登录后属于 Cloud Profile snapshot，并且普通 Profile 编辑时只通过底部“保存更改”提交。历史体重、体脂和腰围属于云端 `body_metric_logs`，本地 `user_weight_logs` 只做 confirmed cache。身体资料卡提供仅限过去日期的日历/新增记录入口，进入页内历史身体记录编辑态后保留自己的保存动作，只保存 `body_metric_logs`，用更强的柔和淡化状态锁定不可编辑区域，不额外叠加分块遮罩，并在键盘弹出时保持当前编辑区可见，不静默改当前 Cloud Profile；Body Trends 只读展示趋势。
- 在“保存更改”成功前，其他 App 区域和 AI context 应继续使用上一次已保存的权威 Cloud Profile，而不是未保存草稿。
- 离线时禁止修改 Profile。
- 离线时 Profile 页面可以显示缓存值，但不能保存修改。
- AI 默认使用 Cloud Profile 作为权威上下文。
- 请求可携带 `profile_version` 检测上下文是否过期。
- 删除账号时删除 Cloud Profile。
- Profile 页面底部的账号卡片提供明确的退出登录入口。退出登录或切换账号会清空 auth session、运行期 Profile 草稿状态、账号绑定的 Cloud Profile 缓存元数据和本地 cache；不得删除云端正式记录。

Cloud Profile 映射必须保留算法语义。它可以校验枚举值、为缺失字段填入版本化默认值、转换存储类型，但不能推断新的 `diet_goal_phase`，不能把 `gram_per_kg` 换算成 `energy_ratio`，不能在 `gram_per_kg` 模式下把辅助 kcal 值当主目标，也不能根据派生字段覆盖用户原本的 phase/mode/strategy。

因为 V1 禁止离线保存 Profile 修改，所以不会产生 pending profile merge 冲突。如果未来版本允许离线修改，必须先定义字段级合并规则。

## 订阅与可用状态

V1 使用订阅制，而不是用户可见的按次额度。

Profile 页标题区域提供紧凑的“订阅”入口按钮，并用明确的已开启/未开启/加载中/异常状态徽标替代容易误解为未读提醒的独立绿点。入口打开小型模糊浮层展示订阅详情。浮层展示当前账号 entitlement，可刷新订阅状态，也可以通过 Supabase RPC `redeem_internal_subscription_code` 输入开发期内部兑换码。兑换码以 hash 形式保存在服务端，并且只能通过 RPC 更新当前账号的 `subscriptions` row；客户端不会拿到 service-role key，也不能直接 insert/update entitlement row。这只是内部开发 entitlement 测试路径，不是生产支付或应用商店订阅实现。

以下状态禁用 AI 发送：

- 用户未登录
- 设备离线
- 当前设备已被同账号新登录设备替换
- 订阅未生效

禁用状态下，App 仍可允许用户输入或编辑未完成 prompt。真正发送需要登录、联网、active device、Cloud Profile、订阅和 Gateway 服务端校验都通过。

后端可以内部记录请求次数和模型成本，但 V1 不显示额度或剩余次数 UI，除非产品决策改变。

## Request、Response 与 Debug 留存

V1 默认建议：

- 云端保存 AI sessions 和最终 chat messages，使登录后的历史记录可跨设备查看。
- 保存 request/response metadata，用于稳定性、订阅审计、滥用防护和排错。
- 保存紧凑 debug summaries，不保存冗长 chain-of-thought 或无限制 tool traces。
- 对 Add Food AI 食物分析，只保存 workflow、model、图片数量、可选输入类型、mime type、压缩字节数、是否有补充说明、schema 校验状态和 safety/error flags 等紧凑 metadata；默认不保存原图、base64 payload 或完整自由文本说明。
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
| 创建训练草稿 | 可以 | 通过训练编辑页保存前需要确认 |
| 修改训练记录 | 不能直接静默修改 | 通过训练编辑页确认 |
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

当前 Local 与 Agent 基线：

- App shell: `lib/main.dart`, `lib/app.dart`
- AI 页面: `lib/features/ai/ai_page.dart`, `lib/features/ai/ai_chat_controller.dart`
- Bottom navigation: `lib/core/widgets/fitlog_bottom_nav_bar.dart`
- 饮食录入和 AI-adjacent paste flow: `lib/features/food/*`
- 训练编辑草稿衔接: `lib/features/workout/add_workout_page.dart`, `lib/domain/models/ai_workout_draft.dart`, `lib/domain/models/workout_record_draft.dart`
- Prompt templates: `lib/core/constants/prompt_templates.dart`
- JSON parser: `lib/domain/services/nutrition_calculator.dart`
- Daily summaries: `lib/domain/services/daily_summary_service.dart`
- Diet targets: `lib/domain/services/macro_target_calculator.dart`
- Strategies: `lib/domain/services/carb_cycling_calculator.dart`, `lib/domain/services/carb_taper_review_service.dart`, `lib/domain/services/diet_plan_strategy_service.dart`
- Workout calories: `lib/domain/services/workout_calorie_calculator.dart`
- Database: `lib/data/db/app_database.dart`
- Repositories: `lib/data/repositories/*`
- Account/Profile state: `lib/features/account/account_controller.dart`
- Cloud Profile mapping: `lib/domain/services/cloud_profile_mapper.dart`
- Supabase schema: `supabase/migrations/202606190001_phase2_account_profile.sql`, `supabase/migrations/202606260001_phase3_cloud_records.sql`, `supabase/migrations/202606290001_phase4_ai_chat_foundation.sql`, `supabase/migrations/202606290002_phase4_step2_gateway_mock.sql`, `supabase/migrations/202606300001_phase4_step3_4_chat_ops_real_providers.sql`
- Supabase chat/session rename schema: `supabase/migrations/202607010001_phase4_step5_chat_session_rename.sql`
- Supabase Edge Functions: `supabase/functions/ai-chat-route/index.ts`, `supabase/functions/ai-chat-route/openai_provider.ts`, `supabase/functions/ai-chat-route/qwen_provider.ts`, `supabase/functions/ai-food-photo-analyze/index.ts`
- AI chat 和图片饮食分析 data path: `lib/data/remote/ai_gateway_client.dart`, `lib/data/remote/ai_food_photo_analysis_client.dart`, `lib/data/repositories/ai_chat_repository.dart`
- AI Gateway contract models: `lib/domain/models/ai_chat_session.dart`, `lib/domain/models/ai_chat_message.dart`, `lib/domain/models/ai_gateway_request.dart`, `lib/domain/models/ai_gateway_response.dart`, `lib/domain/models/ai_gateway_error.dart`, `lib/domain/models/ai_food_photo_analysis.dart`, `lib/domain/models/ai_workout_draft.dart`

后续计划中的 Agent V1 surface：

- records summary context-builder services
- 更完整的 Chat 内草稿编辑
