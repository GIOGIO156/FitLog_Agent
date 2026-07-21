# 产品设计

## 目标

FitLog_Agent V1 是一款以确定性计划规则为基础、由用户控制 AI 层的云辅助饮食与训练记录产品。

它的价值不是“让 AI 取代记录”。它的价值是保留确定性的饮食、训练、目标、策略和导出工作流，同时通过订阅制 AI Chat 帮助用户估算复杂饮食、决定下一餐、复盘近期行为，并理解 App 规则。

产品承诺：

```text
登录后用云端正式记录和确定性规则记录。
用户需要帮助时主动调用云端 AI。
只有用户确认后才写入正式数据。
```

## 产品原则

- 除非 Agent 需求明确改变，否则保留已经验证的记录、计划和导出行为。
- Agent 版正式记录功能登录前置。
- 登录后的 body、food 和 workout 正式记录使用云端 source of truth。
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
- 错误和校验失败提示更明显，并保留必要诊断信息，但会浮在底部导航或键盘上方，不遮挡当前输入焦点。AI composer 错误复用同一个共享组件，并根据已测量的 composer 高度放在输入区上方，不再维护页面私有错误胶囊。
- 需要用户操作的提示必须通过统一 action 通知保留按钮和回调，不能降级成无 action 的被动提示。
- 被动临时通知保持紧凑样式，不显示关闭图标，并会自动过期；它与相关 surface 绑定，切换 tab、离开页面或 App 生命周期变化时不能把过期反馈带到无关模块。确认保存并关闭编辑页时，保存流程会在导航前捕获 root 通知 surface，并在目标页面只发送一条新的成功通知，继续使用同一有界计时器。
- App 短暂切到后台不会取消进行中的 AI 请求；返回页面后继续显示同一 pending 状态。只有真实的传输超时、网络中断或 Gateway 失败才转成错误，失败输入仍保留供重试。
- 通知颜色和文本样式来自当前 FitLog 主题，Green 和 Black/黑橙都保持一致的 surface、强调色和 `NotoSansSC` 字体。
- App 离开前台后，Android 会把包含任意已选动作的未保存新建训练草稿镜像成系统“训练进行中”通知。它只是 draft-resume surface，不是后台任务或新正式记录。编辑已有正式训练只使用页面内状态，不创建这类保留草稿或通知。
  - 有下一组力量训练时，title 是当前动作，body 是使用当前重量/次数的下一组未完成 set；否则显示简短返回继续提示。
  - 右侧图片复用训练 editor 的动作/身体部位 asset；small status-bar icon 可能被平台渲染成单色。
  - 通知焦点在当前动作未完成时跟随最近勾选 set，完成后回到训练顺序中第一个未完成力量动作。
  - 点击时先取消通知，再只恢复同一个本地 draft 的一个编辑页；回到前台、保存、舍弃或删除全部动作也会取消通知。

## 产品模块

| 模块 | 产品角色 | 当前行为 | 长期边界 |
| --- | --- | --- | --- |
| Home | 选中日期 dashboard。 | 展示确定性 daily summary 和符合当前模式的 kcal 或 macro 信号；后台刷新前可以先显示匹配的 confirmed cache。 | 保持 dashboard，不变成 AI 工作台。 |
| Food Log | 正式 food record 管理。 | 支持手动录入、外部 AI JSON 粘贴、复制日期、编辑、删除和用户确认后的 AI 辅助记录。 | 登录后正式写入 cloud-first；所有 AI 结果在确认保存前都是草稿。 |
| Add Food | 食物创建 workflow。 | AI 食物分析作为第一入口，接受纯文字或最多三张可选图片，并提供与 AI Chat 独立的 ChatGPT/千问选择；当前请求使用 Qwen，未配置 ChatGPT 只报告不可用而不发送。手动录入和外部 AI JSON 粘贴继续保留；可复用外部对话 Prompt 的唯一入口位于 Paste AI Result。 | Provider 状态不改变共享 Food policy、语义 Preview Gate、隐私或确认边界。 |
| AI | Agent 主入口。 | 提供 gated Qwen 文字与图片对话、保留但未配置的 ChatGPT 选择反馈、云端 history、最多三张图片、校验后的 Food/Workout Draft 卡片、受限只读 RAG 和“回答依据”面板。 | Provider credentials 留在服务端；AI 不能静默写记录或设置。 |
| Workout | 正式训练记录管理。 | 支持训练记录、自定义动作、手动/AI 新建记录保留草稿、确定性热量估算和草稿恢复通知。 | 已保存历史的编辑状态仅存在于当前页面；AI 可以起草或复盘，但不能静默修改正式记录。 |
| Profile | 账号、身体资料、饮食和显示设置。 | 未登录显示 auth；登录后编辑一份 Cloud Profile draft 和独立历史身体记录。 | Cloud Profile 是权威来源；正式饮食设置只能通过 Profile 确认修改。 |
| Export | 用户主动导出数据。 | 支持从权威记录集合生成 XLSX 和 CSV ZIP。 | 本地 cache 可以加速，但不是完整性前提，也不等于备份。 |

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
- 说明类 guide sheet，包括 Home 策略说明和 Profile 当前计划计算方法说明，都使用 root modal sheet。固定强度的雾化 scrim 覆盖并禁用底部导航，sheet 底部停在 nav pill footprint 上方 12 px，顶部至少保留 64 px 焦点留白，长说明内容在 sheet body 内部滚动，不通过缩小文字或覆盖导航解决高度问题。黑橙主题下 modal guide panel 使用实体 elevated surface，防止页面内容穿透；普通玻璃卡继续保留既有透明度。
- Root shell 不缩短页面主体，也不绘制与导航同高的整条底色。浮动导航 geometry 区分屏幕坐标 footprint 与 SafeArea 内容避让：前者是 pill 高度加 `max(设备底部安全区, 12)`，后者减去已经被 `SafeArea` 消耗的安全区。
- Home 首屏盒子使用 SafeArea 内容高度减去导航避让。g/kg macro strip 和 energy-ratio 卡片保持在盒子内，不把导航预留当成内容内部间距。`energy_ratio` 模式下，热量卡保留自然圆环、字号、padding 和顶部位置，macro 卡保留底部自然高度，中间空间弹性伸缩。
- 可滚动阅读 padding 与固定底部 controls 使用独立 geometry。Food 和 Workout 添加 CTA 是有自身滚动避让的透明 overlay；它们和 AI composer 一样用屏幕坐标锚定到导航顶部，并共享同一视觉间距。专用 AI 食物分析按钮同样保持悬浮，但只从按钮中线到屏幕物理底部绘制与按钮等宽的页面背景遮挡，防止内容透出而不重新形成整行 footer plate。它的按钮、遮挡层和列表底部留白使用稳定的底部 `viewPadding`，在整个键盘运动期间保持键盘关闭时的屏幕 geometry。键盘只覆盖和揭示按钮，不再驱动按钮动画；键盘完全关闭前按钮输入保持禁用。
- 键盘 inset 动画期间，底部导航保持稳定的 `viewPadding`，字段或 AI composer 移动时 nav pill 不下探。
- 需要避让键盘的 surface 以实时系统 inset 作为纵向位移的唯一 owner，不缓存设备级键盘高度。焦点 editor 在整个 inset 过渡中必须保持挂载，不能替换成另一棵仅供键盘状态使用的 subtree。固定形状 editor 作为一个刚体跟随 inset，不改变宽度或高度；可滚动表单保持同一个字段并由既有 scroll owner 跟随 active field；明确的多字段流程只执行一次受限焦点切换。禁止延迟第二次 reveal、键盘稳定计时器或竞争性补偿滚动再次移动同一个字段。
- AI message list 把 composer 当成真实遮挡物，但不使用全宽 footer plate。Viewport 从顶部 action row 下方开始、hard clip 旧消息，并在键盘开合两种状态下复用相同的 10 px 区域间隔、14 px 列表底部留白和短 bottom fade，因此最后气泡与 composer 保持一致的 24 px 视觉距离。键盘打开时 composer 在键盘上方保留 12 px 间距，继续使用普通玻璃 surface，不叠加主题色 veil；列表禁止手动滚动，第一次点击 composer 外部或开始竖向拖动只负责收起键盘，不会触发被遮挡的页面内容。键盘关闭后恢复正常滚动和完整阅读区域；composer 运动仍限制在键盘避让位置与导航上方静止位置之间。
- 全屏程序化液态渐变 AI 背景；空白首页让顶部粉色和从中下部进入底部的蓝色在视觉上更均衡，中间保留略小但足以包裹中心状态文案的绿色色带，并通过全屏流场采样、过渡最小宽度和适度采样密度让颜色持续变形，而不是移动局部圆形色块或出现压缩后的块状条纹。发出第一条消息前，键盘输入仍保持可见的首页动效；第一条消息发出后、打开历史会话或发送等待期间，同一全屏色场才切换为更低幅度的安静流动，让页面不会完全静止，也不抢夺聊天阅读注意力。
- 中心文案优先使用已保存的 Cloud Profile 昵称。
- 底部输入框。
- 输入区附近提供紧凑模型选择器，可选 `ChatGPT` 和 `千问`。
- 左侧可折叠 chat history。
- 右上角账号/订阅状态入口。
- 没有 quick chips。
- 小型隐私/状态提示。

交互与运行期行为：

- Root navigation 是 `Home | Food | AI | Workout | Profile`。
- AI shell 默认显示未登录不可用状态。
- 输入框可编辑；只有登录、联网、订阅可用、active device 有效且 Supabase Gateway provider 已配置时，发送才可用。
- 模型选择器显示 `ChatGPT` 和 `千问`。当前发布已配置 Qwen；选择未配置 ChatGPT 时显示正常生命周期的“当前模型不可用”错误，选中指示器先响应点击再以与底部导航相同的 240 ms `easeOutCubic` 滑动语义自动回到千问，同时保留当前输入且不发送 request。自动弹回只恢复 UI 选中态，不会把这次 ChatGPT 点击转换成千问 request。具体模型名和 API key 只在服务端配置。
- 账号/订阅入口打开当前状态 sheet，展示账号与订阅状态、后端状态和用户记录摘要授权开关；退出登录保留在 Profile，不放在这个临时 AI sheet 中。该授权控制 routed 用餐决策和复盘 workflow 是否可以使用云端记录摘要；关闭时 Gateway 仍可使用同会话、Cloud Profile 和文档上下文，但会把记录摘要维度报告为缺失。中心状态文案优先读取已保存的 Cloud Profile 昵称，再回退到 auth display name。
- 配置 Supabase URL 和 anon key 后，Supabase Auth、订阅状态和 Cloud Profile 访问已接入。
- 历史入口打开云端 chat-history 侧栏，支持新建 chat、切换 session、通过服务端 RPC inline 重命名，以及二次确认后软删除 session。重命名状态由侧栏层持有；键盘改变可用高度时，字段只使用 scrollable 的正常焦点 reveal，不追加延迟补偿，因此较低 session 不会丢失 editor 或编辑状态。由于当前没有归档列表/恢复 UI，归档入口不再暴露。
- AI 页面调用 `ai-chat-route` Edge Function 发送 Qwen 文本 turn 和最多三张图片的多模态 turn；请求语言按当前用户消息推断，并通过服务端 RPC 持久化通过校验的 user/assistant 文本消息。当前发布客户端不会调用保留的 OpenAI adapter。
- 可用的 Qwen 选择保存在本机 `SharedPreferences`，不同步到云端；不可用 ChatGPT 不会持久化为 active provider，并在短暂点击反馈后自动恢复 Qwen。状态与 provider availability 解耦，只表达账号订阅、Profile、设备、网络和 Gateway readiness：空对话 composer 上方显示带标签的状态 pill，进入对话后的固定顶部栏使用同排紧凑状态灯，避免窄屏换行；发送中的状态只由发送按钮 spinner 和 assistant loading 气泡表达。
- AI Chat 的交互强调色跟随当前本机 FitLog 主题：用户气泡、发送/确认按钮、草稿 artifact 卡片边框、Markdown 强调色和 history 选中态在 Green 主题保持绿色，在 Black/黑橙主题切换为柔和但明确的橙色。可用状态灯保持语义绿色，因为它表达账号订阅、设备和 Gateway readiness，而不是具体 provider 或品牌强调。AI 页液态背景保留自己的粉绿蓝色场，不因为黑橙主题而整页变成深色表面。
- 发送时输入框立即清空，用户消息先显示为 pending 气泡并从可见区域内单向定位到顶部可读边界，不允许先越过边界再回弹或整条消失；最终边界与顶部控件保持约 10 px 间距。旧消息在顶部直接裁切，不做顶部 soft fade；输入框上方保留底部 soft fade；等待期间显示 assistant loading 气泡；如果发送失败，会恢复刚才尝试发送的草稿。loading 气泡只根据请求类型和等待时长显示保守的客户端进度文案，例如正在发送、正在等待、图片请求可能更慢、服务端或模型响应较慢；它不展示模型真实思考链，也不会在缺少证据时声称已经完成图片识别、营养计算、RAG 检索或摘要读取。
- 当同一条用户 turn 同时包含图片附件和文字时，消息列表把图片附件渲染为右对齐裸圆角 media，并把文字渲染为独立用户气泡；请求、pending 状态、重试和云端 history 仍然保持为同一条 turn。悬浮输入框使用很轻的 hairline 和分层阴影，让它在 AI 背景上保持清晰的悬浮感，并且键盘收起运动只在键盘顶部和导航上方静止位置之间发生。
- assistant 消息通过维护中的 GitHub-flavored Markdown 渲染器按 App 样式展示，文本可选择，不加载远程图片，也不执行链接动作。用户消息保持可选择的普通文本。复制通过系统文字选择菜单完成，不再提供每条消息独立复制按钮。
- AI 页面可以通过已配置的 Qwen adapter 发送最多三张 JPEG/PNG/WebP 图片。附件操作打开与 AI 食物分析相同的横向拍照/相册双卡片，并使用 Chat 专属标题和已选数量摘要。打开系统相机/相册前会保存很小的本地恢复标记，让 Android activity 重建后可以恢复输入文字和取回的图片附件。Food Draft 响应会在用户点击确认后打开 Food Preview，Workout Draft 响应会在用户点击确认后打开现有训练编辑草稿；二者都携带通过校验的目标日期，在 review 前展示，并通过正常、跟随主题的日历控件提供修改，仍需用户在编辑页保存后才写正式记录。
- 服务端路由的只读 Structured RAG 和 Document RAG 支持用餐决策、周复盘和 App 规则回答。AI 页面不做长期图片存储，不自动修改目标，也不自动写入正式业务记录。
- 未发送的输入框内容是当前运行期内的设备级本地草稿。切换页面和不可用状态不应自动清空；用户删除、开始发送、退出登录或切换账号时清空，发送失败时恢复刚才尝试发送的草稿。

AI 页面在所有运行期 gate 满足时可以通过 Qwen 发送文本消息和最多三张图片附件。请求携带紧凑同会话文本和 draft artifact 摘要，使模型理解当前会话。服务端只在 auth、subscription 和 active-device 校验后构建上下文：routed read-only workflow 可以使用 Cloud Profile 和 App 文档片段；记录摘要必须先得到本机用户记录摘要授权。Assistant 消息可以显示“回答依据”面板，把参考文档、使用数据、缺少信息和受限操作分组为人类可读标签；参考文档只显示文件名级 chips，不显示完整内部路径，同会话历史也不作为回答依据展示。

所有 AI Chat provider 回复都使用统一经过校验的 envelope：`output_type` 表示 text、Food Draft、Workout Draft 或 clarification，`message.text` 承载友好解释和确认提示，`draft` 承载结构化 artifact。普通 Chat 先使用高置信度确定性判断，无法确定时才由模型选择受限类型；明确的 Add Food 入口直接固定 Food Draft，不重复猜测意图。OpenAI 使用 strict Structured Outputs，Qwen 使用 JSON Mode；Gateway 再执行共享精确校验、语义一致性检查与最多一次受限纠错。只有最终校验通过后 App 才展示解释/artifact，文字不能声称生成了实际不存在的草稿，也绝不把 raw provider JSON 当作 assistant Markdown。Food Draft item totals 会在审查前归一化。

每个 turn 只由一个 provider-neutral Chat decision 决定 capability、output family、授权 context、clarification 和当前附件策略。Clarification 是可持久化、typed、有限次数的状态，而不是反复出现的一句话：App 显示 allowlisted options，以稳定 request ID 精确消费一次回复，并推进原任务或返回真实系统错误。清晰的图片加文字请求在同一 turn 消费当前图片；只有后续确实仍需像素时，图片才保留在 account/session scoped 的运行期 lease 中。重新加载历史、进程重启、清空本地数据、退出或切换账号后必须重新附图。Planner、Provider、validation、attachment 和 clarification conflict 不能伪装成用户歧义。

草稿日期解析与意图/output selection 是两件独立的事。Chat 中受支持的明确日期由服务端解析；没有日期表达时使用当前选中日期；无法确定的日期语言进入 clarification。最终通过校验的 draft date 同时驱动 assistant 确认文字、artifact 和 editor，用户仍可在正式保存前通过日历修改。

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

Add Food 把“AI 食物分析”作为第一入口。页面主体删除重复的解释副标题，并按“标题、独立模型选择器、大预览、紧贴的固定缩略图栏、食物描述、悬浮分析按钮”排列。用户可以单独输入食物文字描述，也可以通过大预览框添加最多三张可选的拍照/相册图片。空预览提示点击添加食物图片；选图后显示当前图片，并只在右下角保留小型 `+` 作为继续添加或替换入口。底部来源弹窗把拍照和相册并排显示。预览下方固定预留三个同尺寸缩略位，点击缩略图切换上方放大预览，图片数量变化不会改变缩略图大小或页面高度；预览与缩略图保持紧凑的组内间距，缩略图栏与食物描述之间使用更大的分组间距。相册只请求剩余名额；三张已满时下一次选择替换当前图片，超过上限的 picker 结果会被拒绝而不是静默丢弃。模型选择器不再嵌套额外卡片。分析按钮是 body overlay，不使用 `bottomNavigationBar`；列表内容在其上方结束，而与按钮等宽的实体遮挡只覆盖按钮下半部至屏幕底部。键盘运动期间，分析按钮、遮挡层、正常 scroll tree、恒定按钮避让、焦点食物描述 editor 和 FocusNode 全部保持挂载。实时键盘 inset 只把固定尺寸的描述框作为一个刚体平移以保持键盘间距，不执行逐帧 reveal、补偿滚动、动态底部 padding 或 subtree 替换。描述框上移时，标题、provider selector 和图片区域随 inset 渐进变暗并停止接收输入；描述框保持前景命中层，继续支持光标和选区调整。点击或竖向拖动灰色背景只收起键盘，不会打开图片来源弹窗。分析按钮、遮挡层和列表避让通过稳定的底部 `viewPadding` 保持键盘关闭时的 geometry；系统键盘只覆盖和揭示按钮，不改变其透明度或位置，且键盘完全关闭前继续禁止按钮输入。

Paste AI Result 兼容路径始终挂载同一个固定尺寸 JSON editor，并由实时 inset 将其作为刚体平移。静止“解析”操作边界附近使用短小的连续交接区，消除硬速度变化，同时不增加计时器、键盘高度缓存或独立 animation controller。设置卡片跟随实时键盘展开 inset 逐步淡出，同时保留 layout footprint 和状态，避免单帧消失，也不会移动或重建 editor；固定的“解析”操作保持挂载、input gating 并由键盘自然覆盖。Editor 右上角的放大操作使用中性、低强调的四角框图标，先进入 pending 状态并清除焦点，在观测到 inset 归零前不打开弹窗；缩小操作使用同一套视觉样式。随后显示的 root modal 使用固定背景雾化和实体 elevated JSON panel，不自动聚焦，也不复制 Prompt 或“解析”操作。临时 controller 接收完整 `TextEditingValue`，不可点击 barrier 关闭的弹窗退出时把编辑后的文字和选区写回原页面。

Qwen 把输入发送到专用 `ai-food-photo-analyze` Gateway 路径；选择未配置 ChatGPT 时显示相同的短暂不可用错误，选择器自动滑回千问，保留文字和图片且不发送。打开系统相机或相册前，App 会保存一个很小的恢复标记，避免 Android activity 被系统重建后把用户丢回空白 Home，而是尽量恢复分析草稿。仍挂载的分析页面独占 picker 结果；只有该 owner 不存在时 Root 才执行 single-flight 恢复，因此从相机返回不会叠加第二层分析页，保存后也不会露出旧页面。已配置的 image-capable 服务端 adapter 共享同一 Food 事实优先级、目标语言 policy、semantic validator、纠错上限和 no-write 边界。成功终态必须有通过校验的 Food Draft，不能用普通解释文字冒充成功；非法输出保留表单输入供用户修正。草稿进入现有 Food Preview 编辑页，只有用户点击保存后才以 `ai_photo` 来源写入正式记录。

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

可恢复的训练草稿只属于用户手动新建或 AI 交接的新记录。打开或修改一条已保存历史记录时只使用页面内编辑状态；未保存就离开会放弃这些修改，不生成恢复条或“训练进行中”通知。

Android 在新建训练编辑期间重建进程时，App 使用轻量本地活动标记和权威 SQLite 草稿判断恢复；仅当草稿在最近 30 分钟内更新，才自动回到 Add Workout。进程仍存活时保持原 route，不重复 push；超过 30 分钟的草稿只通过 Workout 页既有恢复条手动继续。明确返回、丢弃和成功保存都会清除自动恢复标记；该机制不使用 timer、alarm、前台服务、wake lock 或后台保活。草稿持久化保持关键且有序；best-effort “训练进行中”通知只在 App 离开前台后镜像最新草稿，回到 App 或点击通知时会先取消通知，再只恢复一个编辑 route。

正式训练保存会先持久化稳定的 mutation id、目标 plan、payload hash、计算体重、时间戳和 `committing` 状态，再冻结生命周期 autosave 与编辑。云端在同一 transaction 中写入训练 sessions/sets 并记录 mutation 结果，因此同一 mutation 的重试不会创建第二条正式记录；云端确认后再按顺序执行最终草稿删除。

如果 App 切到后台、进程终止或连接中断导致结果不确定，保留项会显示为锁定的保存确认状态，而不是可编辑训练草稿。原进程仍存活时只查询同一 mutation，用户手动重试也复用同一 payload 和 mutation id。新进程启动时，FitLog 会原子确认或放弃该 mutation，但不会自动重发训练：已提交则清理本地项，已放弃则解锁为普通草稿，状态服务不可用则继续锁定。服务端会先记录放弃结果，阻止旧请求的延迟副本随后写入正式记录。等待确认期间不显示 Android“训练进行中”通知，也不自动恢复编辑器。

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
- Profile 的“清空本地数据”是独立的设备级 SQLite 清理，不是退出登录、删除账号或删除云端数据。用户确认后，它删除本地业务表中的 confirmed cache、训练草稿、自定义动作、校准和复盘状态以及兼容 Profile 数据；保留 Supabase 登录态、SharedPreferences 偏好、已导出文件和全部云端正式记录。登录后，仍存在的云端正式记录会在页面刷新时重新写入本地 cache；被清除的本地独有数据不能从云端恢复。
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

对于登录账号，训练、饮食和身体指标记录以云端为正式来源，本地 SQLite 只作为 cache、草稿和运行期加速层。AI 使用记录时读取云端 records 或受控 summary/context builder，不把本地 cache 当权威来源。具体 cache-first、预取、淘汰、导出正确性和修复规则见 `CloudLocalDataBoundary.md`。

Profile 身体资料区显示年龄、身高、体重、性别、体脂和腰围。这些都是普通 Profile draft 字段，没有卡片级保存键，只随完整 Cloud Profile 通过底部“保存更改”提交。当前身高、体重、体脂和腰围统一使用一位小数的规范精度：“保存更改”会在持久化前只规范化一次，保存后的 snapshot、输入框文字和未保存判断都比较同一个数值，因此格式转换不会再次弹出保存提示。

Body Profile 日历是独立历史记录入口。它默认打开今天；选择今天会回到当前 Profile 且不显示日期条，选择过去日期才进入页内历史 editor。具体日期显示在日历 action 下方，中文使用两位年份，英文使用四位年份。只有体重、体脂和腰围高亮可编辑；年龄、身高、性别、页面其它区域和底部导航使用更强的柔和淡化保持锁定，不增加分块 scrim。

已有历史记录提供红色危险删除 action 并要求确认。删除会 soft-delete 云端 row 和本地 cache mirror、刷新 Body Trends，并可能影响使用体重历史的 calibration/review。没有 row 的过去日期保持三项空值，不复制当前 Profile。Inline editor 与 tile 共用 surface，聚焦时保持稳定数值槽位，并滚动到键盘上方而不压缩 card。补记历史不能静默修改当前 Cloud Profile；把历史数据设为当前值必须显式确认。

Body Trends 只读展示体重、体脂或腰围的 7/14/21/28 天窗口。Controls 位于卡片底部，summary 位于 chart 上方，真实 point 按真实日期间隔绘制，不足数据状态显示在 chart 内，点击 point 会行内显示数值。

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
- App 文档 chunks
- AI evidence snapshots
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

## 核心记录与计划能力

产品保留以下确定性能力：

- 本地饮食 CRUD
- 外部 AI JSON 粘贴与本地解析
- prompt 复制
- 手动饮食录入
- Home/Food/Workout 共享选中日期
- 训练记录创建、编辑、删除
- 自定义动作库
- 力量组支持总重量、每侧重量、自重加重、辅助重量、总次数、每侧次数和按时长记录；App 保留用户看到的原始输入，并使用标准化计算值
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

## AI 与账号能力

当前产品包含：

- Android 安装身份与 FitLog Local 分离。
- App label 与 Flutter app title 为 `FitLog Agent`。
- 五个底部 tab：`Home | Food | AI | Workout | Profile`。
- 稳定五 tab 路由和跟随主题的悬浮底部导航 pill。
- `lib/features/ai/ai_page.dart` 中的全屏 AI shell。
- 不可用 AI 状态：prompt 可编辑，发送按钮禁用。
- ChatGPT/千问模型选择器；当前 Qwen 通过服务端 Gateway 路由，未配置 ChatGPT 显示不可用且不发送，模型凭证由服务端管理。
- 云端 chat-history 入口，支持新建 chat、切换 session、inline 重命名和删除确认；当前 UI 不暴露归档入口。
- Chat 发送链路，包含最多三张千问图片附件、紧凑同会话 context、用户 pending 气泡、assistant loading 反馈、语义状态指示、可选择的消息文本、维护中的 assistant Markdown 渲染、Food Draft 进入 Food Preview 的确认路径，以及 Workout Draft 进入训练编辑草稿的确认路径。
- Gateway workflow routing、只读 Structured RAG/Document RAG、`document_chunks` seed/RPC 路径、Gateway evidence snapshot，以及在 AI Chat 中展示参考文档、使用数据、缺少信息和受限操作的“回答依据”面板。
- 通过 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY` 注入 Supabase 配置，并使用本机 SharedPreferences 保存注册邮箱验证码所需的 PKCE verifier 状态。
- Account controller 与 Auth、订阅状态、Cloud Profile、用户记录摘要授权 repository。
- Profile 认证页使用当前主题纯色背景、无星 FitLog logo base asset、基于 SVG 曲线并贴近 logo 右上角的饱和固定圆润 AI 四角星群错峰呼吸闪烁动画，星群经过轻微左下位置微调且最小态保持更饱满，并统一使用 app 主题字体 `NotoSansSC` 与中等/半粗登录文字层级。页面保留顶部后端配置提示；landing、登录和注册共用同一棵固定布局树，键盘关闭时锁定不可滚动，打开时由唯一 inset owner 增加临时滚动范围。焦点字段立即跟随键盘 inset；需要移动时停在键盘上方 14 px，不再为后续按键额外预留空间。明确的 Next 链依次推进登录和注册字段，只执行一次短促回弹的焦点切换定位，不缩放 logo，也不等待键盘完成后再启动第二段动画；键盘关闭后回到零偏移。认证流程提供邮箱密码登录、注册邮箱验证码、密码确认且不要求 username；没有云端 profile row 的账号会自动创建默认 Cloud Profile，并包含云端保存路径和缓存展示 fallback。
- 持久化 Supabase 登录态恢复、AI 账号/订阅状态 sheet、带紧凑模糊浮层状态刷新和内部兑换码 entitlement 的 Profile 顶部“订阅”入口、用户记录摘要授权开关、Profile 底部退出登录账号卡片，以及退出登录/切换账号时清空输入草稿。
- AI shell、chat controller、Gateway contract/client、evidence 解析与渲染、root navigation、mapper 和 account-controller 测试。

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
- V1 实施历史与决策理由：`docs/FitLog_Agent_V1_Implementation.md`
