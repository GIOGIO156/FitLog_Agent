# 产品设计

## 目标

FitLog_Agent V1 是一个基于 FitLog Local 升级而来的云端 AI 辅助饮食与训练记录 App。

它的价值不是“让 AI 取代记录”。它的价值是保留确定性的饮食、训练、目标、策略和导出工作流，同时通过订阅制 AI Chat 帮助用户估算复杂饮食、决定下一餐、复盘近期行为，并理解 App 规则。

产品承诺：

```text
登录后用云端正式记录和确定性规则记录。
用户需要帮助时主动调用云端 AI。
只有用户确认后才写入正式数据。
```

## 产品原则

- 除非 Agent V1 明确要求改变，否则保留 Local 行为。
- Agent 版正式记录功能登录前置。
- Phase 3 Cloud Records Foundation 已把登录后的 body/food/workout 正式记录接到云端 source of truth。
- 本地 SQLite 只做 partial cache、草稿和运行期加速，不做完整历史镜像。
- 具体云端/本地读写、cache、刷新、冲突和修复规则由 `CloudLocalDataBoundary.md` 维护。
- 登录态冷启动进入主界面时，应先用恢复出的 auth 账号绑定本地记录 cache，再等待 active-device 刷新，让当前日 Home/Food/Workout 可以先从匹配账号 cache 渲染。
- V1 采用单 active device，last login wins；不承诺实时多设备同步。
- 云端服务用于账号、订阅、Cloud Profile、Cloud Records、daily summaries、AI Gateway、chat history 和 AI 审计需求。
- 登录后 Cloud Profile 是跟账号绑定的用户信息。
- 不要求用户填写自己的模型 API key。
- `energy_ratio` 和 `gram_per_kg` 必须保持分离。
- `diet_goal_phase` 是 cutting/bulking 的来源。
- `diet_plan_strategy` 是确定性的策略设置，不是 AI 动作。
- AI 页面是 Agent 主入口。
- 不做静默写入：AI 生成草稿、解释、追问；用户确认后才保存。
- App 级临时反馈必须通过统一系统通知层，不再由各页面散落手写 snackbar。

## 系统通知

系统通知是 App 级临时反馈，不承载业务逻辑。

- 保存、删除、复制、导出、退出登录、验证码已发送等成功消息使用顶部轻量提示，不打断当前任务流，也不遮挡底部导航、输入框或主要操作按钮。
- 错误和校验失败提示更明显，并保留必要诊断信息，但会浮在底部导航或键盘上方，不遮挡当前输入焦点。
- 需要用户操作的提示必须通过统一 action 通知保留按钮和回调，不能降级成无 action 的被动提示。
- 通知颜色和文本样式来自当前 FitLog 主题，Green 和 Black/黑橙都保持一致的 surface、强调色和 `NotoSansSC` 字体。
- Android 还会把当前包含任意已选动作的未保存训练编辑草稿镜像成系统“训练进行中”通知。它不是后台训练任务，也不会创建新的训练记录。如果存在下一组力量训练组，通知标题是当前动作，正文是下一组未完成组并使用草稿里最新的重量/次数；如果当前草稿还没有可显示的下一组，则正文使用短的返回继续训练提示。右侧图片来自训练编辑页同一个动作的动作缩略图或身体部位 fallback。通知焦点会优先跟随最近一次勾选完成组所属动作；如果该动作还有未完成组，就继续显示该动作，否则回到训练顺序中第一个未完成力量动作。点击通知会恢复同一条本地 active draft。保存、舍弃或删除所有动作会取消通知。Android 状态栏 small icon 可能被系统渲染成单色，这是平台限制。

## 产品模块

| 模块 | V1 角色 | 已实现基线 | V1 计划新增 |
| --- | --- | --- | --- |
| Home | 选中日期仪表盘。 | 本地日汇总、饮食上下文、宏量/kcal 展示、紧凑饮食/训练卡。 | 通过 cloud-backed records repository 构建日汇总，把选中日期 confirmed summary 写入本地 cache，用 stale-while-revalidate 刷新 Home，并把可重建的 `daily_summaries` upsert 到云端。 |
| Food Log | 正式饮食记录管理。 | 手动饮食录入、外部 AI JSON 粘贴、复制到日期、编辑、删除，以及 Add Food AI 食物分析确认保存后的 `ai_photo` 记录。 | 登录后正式记录 cloud-first 写入；后续 Chat 草稿流程也必须保留同样的用户确认边界。 |
| Add Food | 饮食创建流程。 | AI 食物分析是第一入口；它可以只输入文字描述，也可以添加最多三张可选图片；手动录入和外部 AI JSON 粘贴仍保留。 | 未来如加入超过三张 Chat 图片或更完整的编辑页内草稿调整，必须先有明确隐私和确认设计。 |
| AI | Agent 主入口。 | 当前 AI 页面已实现居中 tab、可用性 gating 的 Chat 页面、可编辑输入框、可选择的消息文本、最多三张千问图片附件、本机持久化模型选择器、只表达可用性的状态 pill、账号/订阅状态 sheet、订阅/Profile 可用性 gating、用户记录摘要授权开关、紧凑同会话 context、Gateway client、服务端 OpenAI/Qwen provider 路由、Chat Food Draft 和 Workout Draft artifact 卡片，以及支持新建/切换/inline 重命名/确认删除的云端 chat history。 | 基于 RAG 的用餐决策、周复盘、App 规则问答和更完整的草稿编辑。 |
| Workout | 正式训练记录管理。 | 训练记录、自定义动作、训练草稿编辑器、热量启发式计算。 | 登录后正式记录 cloud-first 写入；V1 AI 可解释或复盘训练上下文，但不静默修改训练记录。 |
| Profile | 账号/Profile/饮食设置。 | 本地 Profile 逻辑作为兼容基线保留；未登录时显示登录入口，登录后正式 Profile 通过 Cloud Profile 保存。 | 账号删除、生产订阅管理和后续 AI 个性化 workflow。 |
| Export | 用户主动导出数据。 | XLSX 和 CSV ZIP 导出。 | Phase 3 hardening 后，导出会先读取云端正式 food、workout 和 body metric records 再生成文件；本地 cache 可以加速但不是完整性前提。 |

## AI Chat 体验

AI 页面是简单的全屏 Chat，不是快捷按钮工作台。

导航结构：

```text
Home | Food | AI | Workout | Profile
```

必备 UI：

- AI tab 位于底部导航正中间。
- 底部导航是主题化浮动 pill；导航组件本身不在 pill 外绘制整行底色。
- 非 AI 页面使用实体主题色导航 pill，并在 pill 中线以下保留与导航等宽、使用页面背景色的底部遮挡层，以遮住滚动内容但不形成整屏宽底色；AI 页面使用无此遮挡层的玻璃态导航 pill，让动效背景仍然可见。
- 说明类 guide sheet，包括 Home 策略说明和 Profile 当前计划计算方法说明，都使用 root modal sheet。遮罩覆盖并禁用底部导航，sheet 底部停在 nav pill footprint 上方 12 px，顶部至少保留 64 px 焦点留白，长说明内容在 sheet body 内部滚动，不通过缩小文字或覆盖导航解决高度问题。
- Root shell 不缩短页面主体，也不绘制与导航同高的整条底色；浮动导航几何区分两个坐标系：屏幕坐标里的导航占用是 pill 高度加 `max(设备底部安全区, 12)`，SafeArea 内容区里的导航避让是该占用减去已被 SafeArea 消耗的底部安全区。Home 首屏盒子使用 SafeArea 内容高度减去导航避让；g/kg macro strip 和 energy-ratio 卡片保持在盒子内，不把导航预留当成内容内部间距。energy-ratio 模式下，热量卡片保留自然圆环、字号、padding 并贴近顶部，宏量卡片保留自身自然内部高度并贴近底部，中间空白弹性伸缩。可滚动页面底部阅读留白和固定底部控件分别使用独立 helper。饮食和训练添加 CTA 是透明 overlay，列表自己预留滚动空间；它们和 AI 输入框一样使用屏幕坐标锚定到 nav pill 顶部，并共享同一段固定视觉间距，AI 页背景延伸到导航后方。底部导航本身在键盘 inset 动画期间保持稳定的底部 `viewPadding`，避免输入框或页面字段跟随键盘移动时 nav pill 短暂下探到屏幕底边再回弹。AI 消息列表把输入框当成真实遮挡物，但不依赖整条 footer 底色遮盖内容，并使用不对称 soft scroll-layer 边缘替代硬矩形聊天 viewport：顶部在控件下方使用更长退场，底部保持短退场以保证最后气泡干净。键盘未弹起时，AI 输入框保留正常外部阅读间距，viewport 截止在输入框上方；键盘弹起时，输入框贴住键盘顶部并成为完整悬浮且实心的 accessory，viewport 延伸到输入框后方并截止在键盘顶部，最后一条气泡和输入框之间的安全距离交给消息列表自己的底部 padding，而不是额外底部背景带。键盘弹起/收起过渡中，输入框 bottom 取键盘 inset 和未弹起时导航上方静止避让值中的较大者，避免跟随正在收起的键盘下探到正常静止位置以下。
- 全屏程序化液态渐变 AI 背景；空白首页让顶部粉色和从中下部进入底部的蓝色在视觉上更均衡，中间保留略小但足以包裹中心状态文案的绿色色带，并通过全屏流场采样、过渡最小宽度和适度采样密度让颜色持续变形，而不是移动局部圆形色块或出现压缩后的块状条纹。发出第一条消息前，键盘输入仍保持可见的首页动效；第一条消息发出后、打开历史会话或发送等待期间，同一全屏色场才切换为更低幅度的安静流动，让页面不会完全静止，也不抢夺聊天阅读注意力。
- 中心文案优先使用已保存的 Cloud Profile 昵称。
- 底部输入框。
- 输入区附近提供紧凑模型选择器，可选 `ChatGPT` 和 `千问`。
- 左侧可折叠 chat history。
- 右上角账号/订阅状态入口。
- 没有 quick chips。
- 小型隐私/状态提示。

当前 AI 页面行为：

- Root navigation 是 `Home | Food | AI | Workout | Profile`。
- AI shell 默认显示未登录不可用状态。
- 输入框可编辑；只有登录、联网、订阅可用、active device 有效且 Supabase Gateway provider 已配置时，发送才可用。
- 模型选择器显示 `ChatGPT` 和 `千问`，并把用户选择路由到服务端 Gateway；具体模型名和 API key 只在服务端配置。
- 账号/订阅入口打开当前状态 sheet，包含退出登录和用户记录摘要授权开关。中心状态文案优先读取已保存的 Cloud Profile 昵称，再回退到 auth display name。
- 配置 Supabase URL 和 anon key 后，Supabase Auth、订阅状态和 Cloud Profile 访问已接入。
- 历史入口打开云端 chat-history 侧栏，支持新建 chat、切换 session、通过服务端 RPC inline 重命名，以及二次确认后软删除 session。由于当前没有归档列表/恢复 UI，归档入口不再暴露。
- AI 页面调用 `ai-chat-route` Edge Function 发送文本 turn 和最多三张图片的千问多模态 turn，并通过服务端 RPC 持久化通过校验的 user/assistant 文本消息。
- 模型选择保存在本机 `SharedPreferences`，用户上次选择的 ChatGPT/千问会在 App 重启后恢复，不同步到云端。状态 pill 只表达 readiness：满足发送条件时显示紧凑的 `可用`，账号/Profile/订阅/后端 gate、离线或 active-device 阻止发送时显示紧凑的 `不可用`；发送中的状态只由发送按钮 spinner 和 assistant loading 气泡表达。
- AI Chat 的交互强调色跟随当前本机 FitLog 主题：用户气泡、发送/确认按钮、草稿 artifact 卡片边框、Markdown 强调色和 history 选中态在 Green 主题保持绿色，在 Black/黑橙主题切换为柔和但明确的橙色。可用状态灯保持语义绿色，因为它表达 provider 当前可用，而不是品牌强调。AI 页液态背景保留自己的粉绿蓝色场，不因为黑橙主题而整页变成深色表面。
- 发送时输入框立即清空，用户消息先显示为 pending 气泡，并锚到顶部可读边界而不是 viewport 的渐变退场边缘；等待期间显示 assistant loading 气泡；如果发送失败，会恢复刚才尝试发送的草稿。loading 气泡只根据请求类型和等待时长显示保守的客户端进度文案，例如正在发送、正在等待、图片请求可能更慢、服务端或模型响应较慢；它不展示模型真实思考链，也不会在缺少证据时声称已经完成图片识别、营养计算、RAG 检索或摘要读取。
- 当同一条用户 turn 同时包含图片附件和文字时，消息列表把图片附件渲染为右对齐裸圆角 media，并把文字渲染为独立用户气泡；请求、pending 状态、重试和云端 history 仍然保持为同一条 turn。悬浮输入框使用很轻的 hairline 和分层阴影，让它在 AI 背景上保持清晰的悬浮感，并且键盘收起运动只在键盘顶部和导航上方静止位置之间发生。
- assistant 消息通过维护中的 GitHub-flavored Markdown 渲染器按 App 样式展示，文本可选择，不加载远程图片，也不执行链接动作。用户消息保持可选择的普通文本。复制通过系统文字选择菜单完成，不再提供每条消息独立复制按钮。
- AI 页面可以通过千问发送最多三张 JPEG/PNG/WebP 图片。Chat 图片附件打开系统相机/相册前会保存很小的本地恢复标记，让 Android activity 重建后可以恢复输入文字和取回的图片附件。Food Draft 响应会在用户点击确认后打开 Food Preview，Workout Draft 响应会在用户点击确认后打开现有训练编辑草稿；二者都仍需用户在编辑页保存后才写正式记录。
- AI 页面不触发 RAG、长期图片存储、自动修改目标或正式业务记录自动写入。
- 未发送的输入框内容是当前运行期内的设备级本地草稿。切换页面和不可用状态不应自动清空；用户删除、开始发送、退出登录或切换账号时清空，发送失败时恢复刚才尝试发送的草稿。

当前 AI 页面在所有运行期 gate 满足时可以发送文本消息和最多三张千问图片附件。请求会携带紧凑同会话文本和 draft artifact 摘要，使模型能理解当前会话。云端正式 records 和 daily summaries 已经作为登录后的后续 AI context 来源，但当前 chat 路径还不会检索 records summary 或执行 RAG。

AI Chat 生成草稿时，provider 回复应使用一个经过校验的 envelope：`message.text` 承载友好的解释、估算依据和确认提示，`draft` 承载结构化 Food Draft 或 Workout Draft。服务端校验通过后，App 展示解释文字和原生 artifact 卡片，不应把 provider 原始 JSON 当成普通 assistant Markdown 展示。Food Draft 包含 items 时，餐品级重量、热量和宏量会先按 items 求和归一化，再进入确认或保存。专用 Add Food AI 食物分析路径更严格：`ai-food-photo-analyze` 期望纯结构化 Food Draft JSON，校验后直接进入 Food Preview。

可用状态：

| 状态 | UI 行为 |
| --- | --- |
| 已登录、联网、已订阅 | 彩色 AI 背景；允许发送；状态指示使用语义绿色表示可用。 |
| 等待 assistant 回复 | 背景使用安静低幅度的色场流动；assistant loading 气泡显示处理状态。 |
| 需要补充信息 | 背景保持安静；突出缺失信息问题或草稿字段。 |
| 未登录 | 灰色不可用 AI 页面；禁止发送；仍可输入但不能发送。 |
| 离线 | 灰色不可用 AI 页面；禁止发送；Profile 修改也禁用。 |
| 未订阅 | 灰色或锁定 AI 页面；禁止发送；右上角状态解释订阅情况。 |

## AI Workflows

### 饮食估算

Add Food 现在把“AI 食物分析”作为第一入口。用户可以单独输入食物文字描述，也可以添加最多三张可选的拍照/相册图片，点击缩略图切换上方放大预览，并发送到专用 `ai-food-photo-analyze` Gateway 路径。打开系统相机或相册前，App 会保存一个很小的恢复标记，避免 Android activity 被系统重建后把用户丢回空白 Home，而是尽量恢复分析草稿。服务端会把文字和可选图片交给千问，并返回经过 schema 校验的 Food Draft，不直接写入正式记录。草稿会进入现有 Food Preview 编辑页；只有用户点击保存后，才以 `ai_photo` 来源写入 `food_records` / `food_items`。

草稿应包含：

- 餐名
- 候选食物项
- 分量或 serving 估计
- kcal/protein/carbs/fat
- 置信度或不确定说明
- 必要时的追问
- AI draft 来源标记

如果 AI 无法识别食材或分量，应先追问。例如肉类不明确时，应问用户是什么肉，而不是直接猜。

当前已实现的草稿界面包括 Add Food AI 食物分析后的 Food Preview、用户点击确认后重建 Food Preview 的 Chat Food Draft artifact 卡片，以及用户点击确认后重建现有训练编辑草稿的 Chat Workout Draft artifact 卡片。未来更完整的草稿界面也应与对应记录编辑页 UI 保持一致，并支持：

- 保存
- 丢弃
- 打开完整编辑页

只有确认保存后才创建正式记录。

### 训练草稿

当用户要求把一段训练描述整理成记录时，AI Chat 可以返回经过 schema 校验的 Workout Draft。assistant 会先显示可读摘要和原生 artifact 卡片；用户点击确认后，App 才用已保存的 snapshot 重建现有训练编辑草稿。如果本机已经有未保存训练草稿，App 会先询问是否替换。只有用户在训练编辑页保存后，才创建正式训练记录。

训练草稿最多只追问一轮。追问时应一次列出会明显影响草稿的缺失字段；如果用户回复仍不完整或表示不知道，AI 应返回可编辑的不完整 Workout Draft，把缺失数值留空，并把不确定点写入 notes，而不是继续追问。

### 用餐决策

用户可以问下一餐吃什么、某个外卖是否适合今天、为什么今天很难控制等问题。

回答应使用：

- Cloud Profile
- 选中日期云端饮食摘要
- 选中日期云端训练摘要
- 当前饮食阶段
- 当前计算模式
- 当前策略
- 剩余目标或宏量目标

AI 应用实用语言解释理由。它不能重新计算用户的正式计划，也不能静默修改目标。

### 周复盘

用户可以请求一周或近期复盘。

复盘默认使用云端近期摘要，而不是上传完整原始历史。它应覆盖：

- 饮食记录覆盖率
- 平均摄入模式
- protein/carbs/fat 稳定性
- 训练稳定性
- 可用时的体重趋势
- 可能阻碍因素
- 少量下一步行动

Weekly Review 必须区分建议和正式设置。它可以讨论 `carb_cycling` 和 `carb_tapering`，但不能应用策略或修改策略设置。

### App 规则问答

用户可以询问 FitLog 如何工作。

例子：

- `gram_per_kg` 是什么？
- 为什么这个模式下 kcal 不是主目标？
- 训练热量是怎么估算的？
- carb tapering 是什么？
- 哪些数据会上云？

用户用中文提问时应检索中文文档；用户用英文提问时应检索英文文档。

## Profile 与账号模型

未登录前没有正式 Profile，Profile 页面只显示登录/onboarding 入口。登录后，Profile 像账号绑定的用户信息一样存在。

V1 Profile 规则：

- Cloud Profile 是权威版本。
- 本地设备可以缓存用于显示，但只有缓存元数据匹配当前登录账号时，才可在云端刷新期间先显示缓存值。
- Supabase 登录态会保存在本机并在启动时恢复，直到用户主动退出登录或登录态无法恢复。
- 新设备登录会接管账号；旧设备下一次云端交互时应显示“账号已在另一台设备登录”，并回到登录/重新接管路径。
- Profile 页面中的修改先作为本地草稿存在，昵称和当前身体资料没有卡片级保存键，用户点击底部“保存更改”后才一次性上传完整 Cloud Profile；页面会用更醒目的状态标记已修改的区块。
- 登录和注册失败会保留当前表单，并通过统一系统通知显示可读提示。
- 订阅状态加载失败不会替换已经成功加载的 Cloud Profile 编辑页；AI 发送仍受订阅可用性限制。
- Profile 页标题区域使用紧凑的“订阅”入口，并用明确的已开启/未开启/加载中/异常状态徽标替代容易误解为未读提醒的独立绿点；点开后显示小型模糊浮层，让“当前计划”继续作为第一个主要卡片。
- Profile 页面底部提供明确的账号卡片用于退出登录。退出登录会清空 auth session、运行期草稿和本地缓存，但不删除云端正式记录。
- 离线时禁止保存 Profile。
- AI 默认使用 Cloud Profile。
- 请求可以携带 `profile_version`。
- 删除账号时删除 Cloud Profile。

Profile 应包含现有饮食和个性化逻辑需要的信息，例如：

- 昵称或展示名
- 年龄
- 身高
- 体重
- 体脂
- 腰围
- 公式用性别选项
- 饮食阶段
- 饮食计算模式
- 饮食策略
- energy-ratio 设置
- gram-per-kg 相关设置
- 训练频率
- self-check 设置
- carb-cycling 设置
- carb-tapering 设置
- 账号绑定时的语言偏好

Phase 3 Cloud Records Foundation 后，训练、饮食和身体指标记录以云端为正式来源，本地 SQLite 只作为 cache、草稿和运行期加速层。AI 使用记录时读取云端 records/summary/context builder，不把本地 cache 当权威来源。具体 cache-first、预取、淘汰、导出正确性和修复规则见 `CloudLocalDataBoundary.md`。

Profile 的身体资料区显示当前 Profile 六项：年龄、身高、体重、性别、体脂和腰围。当前身体资料属于普通 Profile 草稿字段，没有卡片级保存键，只通过底部“保存更改”提交。身体资料卡提供日历/新增身体记录入口；日历默认显示当天，选择当天会回到当前身体资料视图且不显示日期条，只有过去日期才进入页内历史身体记录编辑态。进入后，日历按钮下方显示具体日期，中文日期使用两位年份，英文日期使用四位年份。只有体重、体脂和腰围三项高亮可编辑，年龄、身高、性别、页面其它区域和底部导航都会用更强的柔和淡化状态锁定，不额外叠加分块遮罩。已有历史记录会在日期左侧显示红色删除控件；删除必须确认，确认动作使用红色危险按钮语义而不是绿色填充确认按钮，会 soft-delete 云端记录和本地 cache 镜像，刷新身体趋势，并可能影响之后使用体重历史的校准/review 结果。没有历史记录的过去日期会让三项可编辑指标保持为空，而不是复制当前 Profile 数值。身体资料内联编辑器与所在 tile 共用卡片底色，不额外绘制独立填充输入框，并使用稳定数值槽位，聚焦字段不会改变数据框大小；键盘聚焦时会把当前身体记录编辑区滚到键盘上方，而不是压缩身体资料卡。过去日期补记不会静默修改当前 Cloud Profile；如需把某条历史记录设为当前身体资料，必须显式确认。身体趋势卡片位于身体资料下方，只读展示体重、体脂或腰围在 7/14/21/28 天窗口中的折线，不承担记录入口。指标和天数选择位于卡片底部，周期变化和记录数量位于折线图上方；真实记录点按当前窗口内的真实日期间隔从左向右延伸；当前周期记录不足等状态直接显示在折线图区内；点按真实记录点会在图内显示该点数值。

Profile 的主题卡片属于低频设置，位于语言设置前。当前支持 Green 和 Black/黑橙，并用独立点按选项呈现，而不是二分段胶囊控件，便于以后继续增加主题。默认仍是 Green。Black/黑橙使用深色背景、深色卡片和橙色强调色，橙色只用于按钮、选中态、图标强调和进度强调，不作为大面积卡片背景。主题偏好只保存在本机 `SharedPreferences`，不写入 SQLite 或 Cloud Profile。

## 数据与隐私模型

V1 云端数据：

- 账号
- 订阅
- Cloud Profile
- body metric logs
- food records / food items
- workout records / workout sessions / workout sets
- daily summaries
- AI request metadata
- AI sessions
- AI chat messages
- AI 最终回答
- 紧凑 debug/action summaries

V1 本地数据：

- account-bound records/read-model cache
- local workout drafts
- pending drafts
- exports

AI 请求只上传最小必要上下文。用户业务数据上下文应优先使用云端摘要，而不是原始行。cache 清理、淘汰和账号切换规则见 `CloudLocalDataBoundary.md`。

## 用户确认模型

AI 输出类别：

| 输出 | 是否正式写入？ | 确认规则 |
| --- | --- | --- |
| 解释 | 否 | 无保存动作。 |
| 用餐建议 | 否 | 用户自行决定。 |
| Food Draft | 仅草稿 | 保存需要确认。 |
| Workout Draft | 仅草稿 | 需要在训练编辑页确认保存。 |
| Weekly Review | 否 | 策略变化必须通过正常 UI。 |
| App 规则回答 | 否 | 无写入动作。 |
| Profile/饮食设置建议 | 否 | 需要通过 Profile UI 确认。 |

## Local 已实现范围

复制来的 Local 基线已经实现：

- 本地饮食 CRUD
- 外部 AI JSON 粘贴与本地解析
- prompt 复制
- 手动饮食录入
- Home/Food/Workout 共享选中日期
- 训练记录创建、编辑、删除
- 自定义动作库
- 确定性训练热量估算
- 动态热量校准
- `energy_ratio`
- `gram_per_kg`
- `carb_cycling`
- `carb_tapering`
- 本地 Profile 设置
- XLSX 和 CSV ZIP 导出
- 本地数据清空确认
- 语言切换

## Agent 已实现范围

当前 Agent 源码已实现：

- Android 安装身份与 FitLog Local 分离。
- App label 与 Flutter app title 为 `FitLog Agent`。
- 五个底部 tab：`Home | Food | AI | Workout | Profile`。
- `RootTabIndex` 常量，确保 Home 跳 Food 仍是 index `1`，跳 Workout 是 index `3`。
- 抽出的主题化浮动 pill 底部导航组件 `FitLogBottomNavBar`。
- `lib/features/ai/ai_page.dart` 中的全屏 AI shell。
- 不可用 AI 状态：prompt 可编辑，发送按钮禁用。
- ChatGPT/千问模型选择器，并通过服务端 Gateway 路由，模型凭证由服务端管理。
- 云端 chat-history 入口，支持新建 chat、切换 session、inline 重命名和删除确认；当前 UI 不暴露归档入口。
- Chat 发送链路，包含最多三张千问图片附件、紧凑同会话 context、用户 pending 气泡、assistant loading 反馈、语义状态指示、可选择的消息文本、维护中的 assistant Markdown 渲染、Food Draft 进入 Food Preview 的确认路径，以及 Workout Draft 进入训练编辑草稿的确认路径。
- 通过 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY` 注入 Supabase 配置，并使用本机 SharedPreferences 保存注册邮箱验证码所需的 PKCE verifier 状态。
- Account controller 与 Auth、订阅状态、Cloud Profile、用户记录摘要授权 repository。
- Profile 认证页使用当前主题纯色背景、无星 FitLog logo base asset、基于 SVG 曲线并贴近 logo 右上角的饱和固定圆润 AI 四角星群错峰呼吸闪烁动画，星群经过轻微左下位置微调且最小态保持更饱满，并统一使用 app 主题字体 `NotoSansSC` 与中等/半粗登录文字层级，顶部后端配置提示、键盘关闭时静态不可滚动的登录入口、输入框聚焦时紧凑可滚动的键盘避让布局、邮箱密码登录、注册邮箱验证码、密码确认、不要求 username；没有云端 profile row 的账号会自动创建默认 Cloud Profile，并包含云端保存路径和缓存展示 fallback。
- 持久化 Supabase 登录态恢复、AI 账号/订阅状态 sheet、带紧凑模糊浮层状态刷新和内部兑换码 entitlement 的 Profile 顶部“订阅”入口、用户记录摘要授权开关、Profile 底部退出登录账号卡片，以及退出登录/切换账号时清空输入草稿。
- AI shell、chat controller、Gateway contract/client、root navigation、mapper 和 account-controller 测试。

## V1 不做

- 完整历史一次性下放到本地 SQLite
- 把本地 cache 当作 AI 或产品权威来源
- 用户业务数据向量库
- 长期 semantic memory
- 自主多步 AI Coach
- 自动更新目标
- 自动应用 `carb_tapering`
- 自动修改 `carb_cycling`
- 医疗诊断或治疗建议
- 用 LLM 推理替代确定性算法层

## 代码引用

- App bootstrap: `lib/main.dart`, `lib/app.dart`
- AI shell: `lib/features/ai/ai_page.dart`
- Bottom navigation: `lib/core/widgets/fitlog_bottom_nav_bar.dart`
- Home: `lib/features/home/home_page.dart`
- Food: `lib/features/food/*`
- Workout: `lib/features/workout/*`
- Profile: `lib/features/profile/profile_page.dart`
- Models: `lib/domain/models/*`
- Services: `lib/domain/services/*`
- Database: `lib/data/db/app_database.dart`
- Repositories: `lib/data/repositories/*`
- Export: `lib/export/*`
- Localization and prompts: `lib/core/localization/*`, `lib/core/constants/prompt_templates.dart`
- Agent V1 source design: `docs/FitLog_Agent_V1_Implementation.md`
