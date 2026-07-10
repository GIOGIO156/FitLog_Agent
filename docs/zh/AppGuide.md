# App Guide

## 目标

本文说明每个 App 区域做什么，以及应该去哪个设计文件读细节。它是导航型文档。算法公式属于 `Algorithm.md`；schema 和字段属于 `Database.md`；云端/本地读写、cache、刷新、冲突和修复规则属于 `CloudLocalDataBoundary.md`；AI 边界属于 `AgentDesign.md`。

FitLog_Agent V1 保留现有 FitLog Local 的 App 区域，并新增一个主要 AI 区域。

## App 导航

推荐底部导航：

```text
Home | Food | AI | Workout | Profile
```

AI tab 位于正中间，因为它是 Agent 主入口。底部导航组件应是主题化浮动 pill，不应在 pill 外绘制整行背景色。非 AI tab 使用实体主题色 pill，并从 pill 中线到底部屏幕保留与导航等宽、页面背景色的底部遮挡层，避免滚动文字从导航和底部安全区透出；该遮挡层不能延伸到 pill 与屏幕两侧之间的空隙。AI tab 使用没有这层遮挡的更透明玻璃态 pill，保留动效背景可见性。Root shell 不缩短页面主体；导航 helper 必须区分屏幕坐标里的 pill 占用和页面 SafeArea 内容区里仍需避让的重叠高度。导航 pill 在键盘 inset 变化期间保持稳定的底部 `viewPadding`，不应在键盘感知控件移动时自己下弹。Home 首屏盒子扣除导航重叠高度，g/kg 和 energy-ratio 仪表盘只在盒子内部调整区块之间的空白，不缩小卡片内部结构；可滚动 tab 在自身内容底部预留阅读空间；饮食和训练固定底部操作按钮是透明 overlay，并与 AI 输入框一样使用屏幕坐标里的固定导航相对间距，不再形成整条 footer 底色。

说明类 guide sheet 是临时阅读层，不是页面内容。Home 策略说明和 Profile 当前计划计算方法说明必须使用共享 root modal guide sheet：modal 遮罩覆盖并禁用底部导航，说明内容停在 nav pill footprint 上方 12 px，顶部至少保留 64 px 焦点留白，长内容在 sheet body 内部滚动。

## 系统通知

页面应使用 `FitLogNotifications` 处理 App 级临时反馈。

- Food 和 Workout 的保存、删除、复制完成等成功事件使用顶部轻量提示。Food/Workout 的校验失败和云端/本地写入失败使用底部错误提示，并避开底部导航和键盘。
- Android 上，包含任意已选动作的未保存训练编辑草稿会同步为系统“训练进行中”通知。它只是本地草稿镜像，不是后台训练任务。如果存在下一组力量训练组，通知标题是当前动作，正文是下一组未完成组，例如 `第 2 组，共 8 组 - 60 kg x 8 次`，右侧图片使用同一个动作缩略图或身体部位 fallback，不能使用 App 图标；如果还没有可显示的下一组，则正文使用短的返回继续训练提示。焦点会在最近一次勾选完成组所属动作还有未完成组时跟随该动作，否则回到训练顺序中第一个未完成力量动作。所有力量组都勾选但尚未保存时，通知进入完成态并提示返回保存。保存、舍弃或删除所有动作会取消通知。Android 13+ 会在第一次需要显示这条通知时请求通知权限；拒绝权限不影响训练草稿。
- Profile 的身体记录保存、Profile 保存、导出完成、退出登录、清空本地数据、兑换成功、验证码已发送等成功事件使用顶部轻量提示。Profile 的校验、登录注册、订阅、导出、兑换和 Cloud Profile 失败使用底部错误提示，并保留可读映射文案或诊断信息。
- AI 的中性不可用占位使用 info 提示，偏好保存失败使用错误提示。
- 未来任何带操作的通知，例如重试、撤销或打开文件，都必须使用统一 action 通知 API，保留按钮和回调。

## Home

Home 是选中日期仪表盘。

它展示：

- 问候语和选中日期
- 当前饮食阶段、计算模式和策略上下文
- 当日饮食摘要
- 当日训练摘要
- 根据模式展示 kcal 或宏量目标摘要
- 进入 Food 和 Workout 详情区的紧凑入口

行为：

- `energy_ratio` 中，kcal target/intake/remaining 是主信号。
- `gram_per_kg` 中，宏量克数目标是主信号，kcal 是辅助信息。
- 登录态冷启动后，Home 当前日应先渲染匹配账号的本地 cache，再等待 active-device 刷新；不应需要用户切换日期才恢复可见数据。
- 英文界面的紧凑策略卡把策略名放在第一行，把带连字符的细节放在第二行，避免 `Carb cycle` 和 `Carb Taper` 的说明在窄屏上断得不自然。
- Home 不应变成 AI 工作台。
- 任何 AI 相关提示应路由到 AI tab，除非未来产品明确增加 Home 专属 AI workflow。

阅读更多：

- 产品行为：`Product.md`
- 饮食逻辑：`Algorithm.md`
- 当前存储：`Database.md`

## Food

Food 包含选中日期的正式饮食记录。

现有 Local 能力：

- 按日期查看饮食记录
- 添加手动饮食记录
- 复制记录到其它日期
- 编辑已保存记录
- 删除已保存记录
- 粘贴外部 AI 工具生成的 JSON
- 本地解析 food JSON 为预览数据

Agent V1 新增：

- Add Food 把 AI 食物分析放在第一入口；它可以基于纯文字食物描述创建 Food Draft，也可以使用最多三张可选拍照/相册图片和描述创建 Food Draft
- 打开相机/相册前会保存很小的本地恢复标记，让 Android activity 重启后能尽量回到分析草稿，而不是把用户丢回空白 Home
- AI Chat 图片附件启动也会保留一个小的本地恢复标记，用于在 Android 相机/系统 picker 重建 activity 后恢复输入文字、provider、取回的图片附件和 ready 彩色背景连续性；发送仍等待真实账号和 Gateway readiness，恢复期间可以保持灰色禁用
- AI 食物分析或后续 Chat 草稿流程中由用户确认的 Food Draft 可以变成正式记录
- AI 估算不确定时应先追问，再进入保存

Food Draft UI 规则：

- 当前已实现的 Add Food AI 食物分析路径会把草稿打开到现有 Food Preview 编辑页。
- 视觉上尽量接近记录页 UI，让用户能识别字段。
- 保存前允许编辑。
- 当草稿包含 items 时，餐品级重量、热量、蛋白质、碳水和脂肪由 items 求和得到。
- 只有确认后才保存。

阅读更多：

- AI 草稿边界：`AgentDesign.md`
- 饮食记录存储：`Database.md`
- 饮食解析与摘要：`Algorithm.md`

## AI

AI 是主要 Agent 页面。

AI 页面是带动效背景的全屏 Chat，不是快捷入口网格。

必备布局：

- 全屏背景动效
- 中心状态文案，优先使用已保存的 Cloud Profile 昵称
- 底部输入框
- 输入区附近的紧凑模型选择器，可选 ChatGPT 和千问
- 左侧可折叠 chat history
- 右上角账号/订阅图标
- 小型隐私/状态提示
- 没有 quick chips

当前 AI 页面实现：

- AI tab 已经位于底部导航正中间。
- AI 页的背景作为单个连续的程序化液态渐变层延伸到整个页面和 bottom navigation 后方，底部只保留轻微白色渐变 veil。空闲首页让粉色和蓝色在竖屏手机上视觉更均衡，蓝色从输入框上方的中下部提前进入，中间绿色色带略小但包裹中心状态文案；动效来自带过渡宽度保护的全屏流场采样下的颜色持续变形，而不是局部圆形色块移动或压缩后的块状条纹。发出第一条消息前，键盘输入仍保持可见的首页动效；第一条消息发出后、打开已有历史会话或发送等待期间，同一色场才持续安静低幅度流动，既不会像静态图，也不会抢夺聊天阅读注意力。AI tab 使用玻璃态导航 pill；其它可滚动页面使用实体主题色导航 pill，并在自身内容底部预留阅读空间，不依赖 root 层整条导航底色。
- 页面默认是未登录不可用 shell。
- 输入框可以输入文字和最多三张 JPEG/PNG/WebP 图片附件；从相册选择时可以一次选入多张，最多补齐剩余额度。只有登录、联网、订阅可用、active device 有效，且已配置的 Supabase Gateway 能调用所选 provider 时，发送才可用。
- ChatGPT/千问选择会把文本请求路由到服务端 Gateway；图片附件必须使用千问多模态路由。模型名和 provider API key 只保存在服务端。
- ChatGPT/千问选择会保存在本机并在 App 重启后恢复；模型名和 provider API key 只保存在服务端。
- 模型/状态 pill 只表示 readiness，并使用紧凑文案：满足发送条件时显示 `可用`，账号/Profile/订阅/网关 gate、离线或 active-device 阻止发送时显示 `不可用`。请求进行中只由发送按钮和 assistant loading 气泡表达。
- AI Chat 的交互强调色会跟随主题：用户气泡、发送按钮、artifact 确认按钮、草稿卡片边框、Markdown 强调色和 history 选中态在 Green 主题保持绿色，在 Black/黑橙主题切换为柔和但明确的橙色。可用状态灯和文字保持语义绿色，继续表达 ready 状态。AI 液态背景仍是独立的粉绿蓝色场。
- 发送 prompt 后，输入框立即清空，消息列表先以现有会话的真实末尾作为发送定位起点，再显示 pending 用户气泡；等气泡有真实布局位置后，列表把它锚到 history/account/provider 控件下方约 10 px 的可读边界。首个可见位置只能从边界下方向上收敛，不能针对已经加入活动轮次填充的最大滚动距离盲跳，因此不会先冲到控件后方或整条消失再回弹。服务端回复持久化和重新加载前显示 assistant loading 气泡；发送中的活动轮次填充不能暴露成可滚动空白，最终 assistant 回复出现后不再强制二次滚动。
- 消息 viewport 从顶部操作区下方开始，并在这里硬裁切旧消息，所以滚动内容不能穿到状态灯和 provider 控件后方。只有输入框上方保留短底部 soft fade。实测 composer 几何确保键盘弹起和未弹起时手动滚动都不会让最后一条消息被输入框盖住。键盘未弹起时，输入框保持带正常阅读间距的底部悬浮 pill，viewport 截止在输入框上方；键盘弹起时，输入框贴住键盘顶部，作为完整悬浮且实心的 input accessory，消息列表 viewport 延伸到输入框后方并截止在键盘顶部，不再被额外外部 gap、半高遮罩或 footer 背景带包围，最后一条气泡只依赖列表内部底部安全 padding 避开输入框。键盘收起时，输入框会停在正常导航上方静止避让位置，不跟随键盘落到屏幕物理底部后再弹回。
- assistant 消息通过维护中的 GitHub-flavored Markdown 渲染器按 App 样式展示，文本可选择。用户消息仍按可选择的普通文本显示，复制通过系统文字选择菜单完成，不再提供气泡级复制按钮。当前 Markdown 渲染不加载远程图片，也不执行链接动作。
- 当 Chat 回复包含 Food Draft 或 Workout Draft 时，assistant 消息会显示原生 artifact 卡片和确认按钮。按钮用已保存的 snapshot 重建 Food Preview 或现有训练编辑草稿；后台不会保持一个待命草稿页面，用户在编辑页保存前也不会写正式记录。
- Chat 草稿回复应把面向用户的解释放在 `message.text`，把结构化草稿数据放在 `draft`。服务端校验后，App 展示解释文字和原生 artifact 卡片；provider 原始 JSON 不应作为普通 assistant Markdown 出现在聊天中。Add Food AI 食物分析快捷入口仍保持专用的 `ai-food-photo-analyze` 纯 JSON contract。
- Food Draft 和 Workout Draft 卡片使用同一套简短确认按钮文案 `查看并确认`，草稿类型由卡片标题说明。
- 训练草稿最多只追问一轮；如果用户仍没有提供完整信息，Chat 应返回可编辑的不完整草稿，而不是继续追问。
- 账号/订阅入口在账号服务可用时打开当前账号 sheet。中心状态文案优先读取已保存的 Cloud Profile 昵称，再回退到 auth display name。
- Sheet 展示账号/订阅状态、退出登录、后端配置提示和用户记录摘要授权开关；当前 chat 路径从客户端只发送紧凑同会话文本和草稿 artifact 摘要。Phase 5 的记录摘要上下文只在 routed read-only workflow 中由服务端构建，并且必须先开启用户记录摘要授权；它仍不上传完整业务历史。
- 配置 Supabase 后，Supabase Auth、订阅状态和 Cloud Profile 访问已接入。
- 历史入口打开云端 chat history，支持新建 chat、切换 session、inline 重命名和二次确认删除；当前 UI 不暴露归档入口。
- Phase 4 已新增 AI 页面发送接入、OpenAI/ChatGPT 与千问/Qwen 服务端 provider 路由、最多三张图片的千问多模态 Chat、紧凑同会话 context、云端消息持久化、request logs、compact debug summaries、Chat Food Draft 和 Workout Draft artifact 卡片，以及专用 Add Food AI 食物分析草稿流程。Phase 5 新增服务端 workflow routing、只读 Structured RAG/Document RAG、evidence snapshot 和 assistant evidence 面板。
- 同时包含图片和文字的用户 turn 会在聊天 UI 中把图片附件显示为裸圆角 media，并把文字显示为独立气泡，但仍然是一条请求和一条云端 history turn。
- 等待回复时，assistant loading 气泡只根据请求类型和等待时长显示保守的客户端进度文案；它不展示模型真实思考链，也不会在信号不存在时声称 RAG、context 或图片分析阶段已经完成。
- Phase 5 RAG 是只读且带 evidence 的；它可以辅助用餐决策、周复盘和 App 规则回答，但 AI 页面不做长期图片存储、不自动修改目标，也不自动写入正式业务记录。Chat Food Draft 和 Workout Draft artifact 卡片只有在用户点击确认后才打开对应编辑页，用户保存前仍是草稿。

可用状态：

- 已登录、联网、已订阅：允许发送
- 未登录：灰色不可用状态
- 离线：灰色不可用状态
- 未订阅或 Cloud Profile 未完成：橙色 gate 状态，并解释账号/Profile 情况
- 账号、订阅和 Profile 已就绪但后端、provider 或 active-device 未完成校验：橙色准备中状态

当前说明：即使账号、订阅、Cloud Profile 和 Cloud Records gate 都已就绪，发送仍依赖已部署的 Supabase Edge Function、provider secrets 和 active-device 校验。

不可用状态规则：

- 用户可以继续编辑未完成 prompt。
- 只有登录、联网和订阅条件全部满足时，才允许发送。
- 未发送的输入框内容应在当前运行期内的切换 tab 和不可用状态下保留。用户发送时输入框立即清空；如果发送失败，草稿恢复以便重试。退出登录或账号变化时清空。

支持 workflow：

- 食物图片/文字估算
- 训练草稿生成
- 用餐决策建议
- 周复盘
- App 规则问答

语言行为：

- 中文问题检索中文文档。
- 英文问题检索英文文档。

阅读更多：

- Agent 边界：`AgentDesign.md`
- 产品范围：`Product.md`
- RAG 与云端存储：`Database.md`

## Workout

Workout 包含正式训练记录。

现有 Local 能力：

- 创建命名训练记录
- 添加一个或多个动作
- 使用内置动作
- 创建临时或可复用自定义动作
- 记录有氧时长和强度 basis
- 用支持的输入模式记录力量组
- 保存已完成力量组
- 确定性估算训练热量
- 编辑或删除已保存记录
- 当当前本地训练草稿包含任意已选动作时保持 Android 系统通知同步；点击通知会恢复已有草稿编辑页，不会创建新草稿或新记录

Agent V1 边界：

- AI 可以在 Weekly Review 中解释近期训练模式。
- AI 可以把训练摘要用于用餐决策上下文。
- AI Chat 可以生成 Workout Draft artifact，用户点击确认后打开现有训练编辑页。
- 训练草稿追问上限是一轮；不完整信息应进入可编辑草稿，而不是在 chat 中连续追问。
- V1 中 AI 不应静默创建、编辑或删除正式训练记录。

阅读更多：

- 训练热量：`Algorithm.md`
- 训练表结构：`Database.md`

## Profile

Profile 包含账号绑定的用户信息和饮食设置。

Local 基线：

- 昵称
- 身体资料：年龄、身高、体重、性别、体脂、腰围
- 身体趋势卡片：读云端 `body_metric_logs` 的本地 partial cache；没有 cache 时按当前窗口从云端恢复
- 饮食阶段
- 计算模式
- 策略
- 训练频率
- self-check 设置
- 导出
- 清空本地数据

Agent V1 profile 模型：

- 未登录前没有正式 Profile。
- 未登录前，Profile 页面应显示登录/onboarding 入口，而不是本地 Profile 编辑器。
- 当前未登录页使用当前主题纯色背景、无星 FitLog logo base asset 与基于 SVG 曲线并贴近 logo 右上角的饱和固定圆润 AI 四角星群错峰呼吸闪烁动画，星群经过轻微左下位置微调且最小态保持更饱满，并统一使用 app 主题字体 `NotoSansSC` 与中等/半粗登录文字层级；需要提示后端配置时，提示位于页面顶部；无键盘静态入口不可上下滑动，输入框聚焦后切换为可避让键盘的紧凑可滚动布局，包含邮箱密码登录，以及注册邮箱验证码和密码确认表单。注册不要求 username；昵称稍后在 Cloud Profile 中编辑。
- 登录和注册错误应保留当前表单，并通过统一系统通知显示可读提示，而不是展示后端原始异常。
- 登录成功后 Supabase session 会保存在设备上；除非用户主动退出账号，重启 App 后仍保持登录。
- V1 使用单 active device：新设备登录会接管账号。旧设备下一次云端读取、保存、订阅刷新或 AI 请求收到 `device_replaced` 时，应显示“账号已在另一台设备登录”，清本机登录态并回到登录/重新接管路径；不得显示成普通上传失败。
- 登录后 Cloud Profile 是权威版本。
- 新注册或新登录账号没有 Cloud Profile row 时，App 会自动创建默认 Cloud Profile，并进入正常 Profile 编辑页。
- Cloud Profile 加载/保存失败时，应显示可读提示和诊断错误码，例如 schema 不匹配、RLS 拦截、session 过期、网络失败或表缺失。
- 订阅状态加载失败不应阻塞 Cloud Profile 已成功加载的 Profile 编辑页；AI 发送仍要等订阅状态可用且生效后才开放。
- Profile 标题区右侧提供紧凑“订阅”入口，并用明确的已开启/未开启/加载中/异常状态徽标表达订阅状态；点开小型模糊浮层后显示当前账号 entitlement，可刷新状态，也可输入开发期内部兑换码为当前账号开启 AI 订阅。这只是内部开发 entitlement 测试路径，不是生产支付流程。
- Profile 修改会先进入本地页面草稿。昵称和当前身体资料没有卡片级保存键；已改卡片显示醒目的已修改标记，底部条贴近 Profile body 底部并向上展开，显示未保存数量和简洁字段列表；“放弃”恢复到上次保存的 Cloud Profile，“保存更改”一次性写入完整 profile snapshot。
- 身体资料卡提供日历/新增身体记录入口；日历默认打开当天，选择当天会回到当前身体资料视图且不显示日期条，选择过去日期才会让 Profile 留在页内历史身体记录编辑态。进入后，日历按钮下方显示具体日期，中文日期使用两位年份，英文日期使用四位年份；只有体重、体脂和腰围三项高亮可编辑，年龄、身高、性别、页面其它区域和底部导航都会用更强的柔和淡化状态锁定，不额外叠加分块遮罩。已有历史记录会在日期左侧显示红色删除控件；删除必须确认，确认动作使用红色危险操作而不是绿色填充确认按钮，会刷新身体趋势，并移除本地 cache 镜像，使校准/review 读取不到该行。没有历史记录的过去日期会让三项可编辑指标保持为空。内联编辑器与指标 tile 共用卡片底色，聚焦时保持数值区高度稳定，键盘聚焦时会把当前编辑区滚到键盘上方。过去日期补记不会静默修改当前 Cloud Profile；如需把某条历史记录设为当前身体资料，必须显式确认。
- 身体趋势卡片放在身体资料正下方，只读展示趋势，不承担记录入口。它支持体重、体脂、腰围三种折线，支持 7/14/21/28 天窗口；真实记录点按当前窗口内的真实日期间隔从左向右延伸；当前周期记录不足等状态直接写在折线图区内；点按真实记录点会在图内显示该点数值。
- 主题卡片放在 Profile 的低频设置区、语言设置前，使用 Green 和 Black/黑橙 两个独立点按选项。默认 Green；Black/黑橙只改变颜色 token 和强调色，不改变记录、算法或云端边界。
- 设备可以缓存 Profile 用于显示，但本地缓存失败不应阻塞已成功加载的 Cloud Profile。云端刷新期间，只有账号绑定的缓存元数据匹配当前登录账号时，才可先显示缓存 Profile。
- 离线时禁止保存 Profile。
- AI 默认使用 Cloud Profile 作为上下文。
- 删除账号时删除 Cloud Profile。
- Phase 3 Cloud Records Foundation 后，food、workout 和 body metric 正式记录以云端为权威来源；本地 SQLite 只作为 cache、草稿和运行期加速层。具体读写、cache-first、预取、淘汰、异常和修复规则见 `CloudLocalDataBoundary.md`。
- Profile 底部账号卡提供明确退出入口。退出账号会清除 auth session 和运行期草稿；账号绑定 cache 清理规则见 `CloudLocalDataBoundary.md`，不得删除云端正式记录。
- 被新设备替换的旧设备不能继续保存 Profile、身体记录、饮食记录或训练记录。

Profile 仍是正式饮食设置变更的位置。AI 可以解释或建议，但设置变更应通过 Profile UI 完成。

阅读更多：

- Profile 权威来源：`AgentDesign.md`
- 云端/本地边界：`CloudLocalDataBoundary.md`
- Profile 字段与 schema：`Database.md`
- 饮食设置逻辑：`Algorithm.md`

## Export

Export 仍是用户主动控制的本地流程。

现有导出格式：

- XLSX
- CSV ZIP

导出覆盖 Local 基线中的原始记录和有用运行时摘要。V1 不用自动云备份替代导出。

阅读更多：

- 导出覆盖范围：`Database.md`

## 隐私与状态提示

App 应保留隐私提示，但不应占据太多屏幕。

推荐位置：

- AI 页面：输入框或账号/订阅状态附近的小提示。
- Profile：说明账号/Profile 云端存储。
- Food Draft：简短说明 AI 估算在确认前只是草稿。

正常任务流里避免大段说明。

## 可用范围与边界

UI 文案或文档必须区分能力状态：

- 可用 App 行为：饮食记录、训练记录、Profile、导出、账号 gating 的 Cloud Profile/Cloud Records、AI Chat、云端 chat history、最多三张千问图片附件、Add Food AI 食物分析、Chat Food Draft / Workout Draft artifact 卡片，以及带 evidence 的 Phase 5 只读 RAG。
- 条件性行为：真实账号、Cloud Records、订阅、AI Gateway、provider routing、Document RAG seed 和模型调用需要 Supabase migrations/config、Edge Function 部署和 provider secrets。
- 边界行为：AI 可以生成草稿、复盘、推荐和解释；不能自动写正式记录、删除数据、修改目标、应用策略、长期存图或运行自主工具。
- 未来或需单独批准的行为：超过三张 Chat 图片、长期图片存储、用户数据向量记忆、AI 自动正式写入、autonomous Agent action、生产支付管理和账号删除流程。

不要在没有说明依赖条件的情况下，把条件性或未来行为写成普遍可用。依赖后端配置的功能应在 setup 或验收说明中写清楚，不要把 AppGuide 变成 release log。
