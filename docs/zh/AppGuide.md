# App Guide

## 目标

本文说明每个 App 区域做什么，以及应该去哪个设计文件读细节。它是导航型文档。算法公式属于 `Algorithm.md`；schema 和字段属于 `Database.md`；云端/本地读写、cache、刷新、冲突和修复规则属于 `CloudLocalDataBoundary.md`；AI 边界属于 `AgentDesign.md`。

FitLog_Agent V1 保留现有 FitLog Local 的 App 区域，并新增一个主要 AI 区域。

## App 导航

推荐底部导航：

```text
Home | Food | AI | Workout | Profile
```

AI tab 位于正中间，因为它是 Agent 主入口。底部导航组件应是主题化浮动 pill，不应在 pill 外绘制整行背景色。非 AI tab 使用实体主题色 pill，并从 pill 中线到底部屏幕保留与导航等宽、页面背景色的底部遮挡层，避免滚动文字从导航和底部安全区透出；该遮挡层不能延伸到 pill 与屏幕两侧之间的空隙。AI tab 使用没有这层遮挡的更透明玻璃态 pill，保留动效背景可见性。Root shell 不缩短页面主体；导航 helper 必须区分屏幕坐标里的 pill 占用和页面 SafeArea 内容区里仍需避让的重叠高度。Home 首屏盒子扣除导航重叠高度，g/kg 和 energy-ratio 仪表盘只在盒子内部调整区块之间的空白，不缩小卡片内部结构；可滚动 tab 在自身内容底部预留阅读空间；饮食和训练固定底部操作按钮是透明 overlay，并与 AI 输入框一样使用屏幕坐标里的固定导航相对间距，不再形成整条 footer 底色。

说明类 guide sheet 是临时阅读层，不是页面内容。Home 策略说明和 Profile 当前计划计算方法说明必须使用共享 root modal guide sheet：modal 遮罩覆盖并禁用底部导航，说明内容停在 nav pill footprint 上方 12 px，顶部至少保留 64 px 焦点留白，长内容在 sheet body 内部滚动。

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

- AI Chat 确认后的 Food Draft 可以变成正式记录
- Add Food 拍照识别可以创建 Food Draft
- AI 估算不确定时应先追问，再进入保存

Food Draft UI 规则：

- 在 AI Chat 内以紧凑预览卡展示草稿。
- 视觉上尽量接近记录页 UI，让用户能识别字段。
- 允许 Chat 内轻量编辑。
- 提供保存、丢弃、打开完整编辑页操作。
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

当前 Phase 2 实现：

- AI tab 已经位于底部导航正中间。
- AI 页的背景延伸到 bottom navigation 后方，底部保留轻微白色渐变 veil；可用状态使用更清晰的彩色慢流动，输入时键盘打开会暂停背景动画以降低输入卡顿，AI tab 使用玻璃态导航 pill；其它可滚动页面使用实体主题色导航 pill，并在自身内容底部预留阅读空间，不依赖 root 层整条导航底色。
- 页面默认是未登录不可用 shell。
- 输入框可以输入文字，但发送按钮在 Phase 4 AI Gateway 前禁用。
- ChatGPT/千问选择只是本地 UI 占位，不会调用 provider。
- 账号/订阅入口在账号服务可用时打开 Phase 2 账号 sheet。中心状态文案优先读取已保存的 Cloud Profile 昵称，再回退到 auth display name。
- Sheet 展示账号/订阅状态、退出登录、后端配置提示和用户记录摘要授权开关；Phase 2 不上传历史，Phase 3 后摘要来源应改为云端 summary/context builder。
- 配置 Supabase 后，Supabase Auth、订阅状态和 Cloud Profile 访问已接入。
- 历史入口仍是占位。
- 尚未实现 AI Gateway、云端 chat history、RAG 或 LLM 调用。

可用状态：

- 已登录、联网、已订阅：允许发送
- 未登录：灰色不可用状态
- 离线：灰色不可用状态
- 未订阅：不可用状态，并解释账号/订阅情况

当前说明：即使账号、订阅、Cloud Profile 和 Cloud Records gate 都已就绪，发送仍要等 Phase 4 Gateway 接入后才会开放。

不可用状态规则：

- 用户可以继续编辑未完成 prompt。
- 只有登录、联网和订阅条件全部满足时，才允许发送。
- 未发送的输入框内容应在当前运行期内的切换 tab 和不可用状态下保留。用户删除、发送成功、退出登录或账号变化时清空。

支持 workflow：

- 食物图片/文字估算
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

Agent V1 边界：

- AI 可以在 Weekly Review 中解释近期训练模式。
- AI 可以把训练摘要用于用餐决策上下文。
- V1 中 AI 不应静默创建、编辑或删除训练记录。

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
- 登录和注册错误应保留当前表单，并通过底部 snackbar 显示可读提示，而不是展示后端原始异常。
- 登录成功后 Supabase session 会保存在设备上；除非用户主动退出账号，重启 App 后仍保持登录。
- V1 使用单 active device：新设备登录会接管账号。旧设备下一次云端读取、保存、订阅刷新或 AI 请求收到 `device_replaced` 时，应显示“账号已在另一台设备登录”，清本机登录态并回到登录/重新接管路径；不得显示成普通上传失败。
- 登录后 Cloud Profile 是权威版本。
- 新注册或新登录账号没有 Cloud Profile row 时，App 会自动创建默认 Cloud Profile，并进入正常 Profile 编辑页。
- Cloud Profile 加载/保存失败时，应显示可读提示和诊断错误码，例如 schema 不匹配、RLS 拦截、session 过期、网络失败或表缺失。
- 订阅状态加载失败不应阻塞 Cloud Profile 已成功加载的 Profile 编辑页；AI 发送仍要等订阅状态可用且生效后才开放。
- Profile 标题区右侧提供紧凑“订阅”入口，并用明确的已开启/未开启/加载中/异常状态徽标表达订阅状态；点开小型模糊浮层后显示当前账号 entitlement，可刷新状态，也可输入开发期内部兑换码为当前账号开启 AI 订阅。这只是 Phase 2 内部测试路径，不是生产支付流程。
- Profile 修改会先进入本地页面草稿。已改卡片显示醒目的已修改标记，底部条贴近 Profile body 底部并向上展开，显示未保存数量和简洁字段列表；“放弃”恢复到上次保存的 Cloud Profile，“保存更改”一次性写入完整 profile snapshot。
- 身体资料卡提供日历/新增身体记录入口；用户选择日期后，身体记录 sheet 顶部只显示具体日期，sheet 只编辑体重、体脂和腰围三项。过去日期补记不会静默修改当前 Cloud Profile；如需把某条历史记录设为当前身体资料，必须显式确认。
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

## 已实现与计划中

UI 文案或文档必须区分：

- 已实现 Local 行为：复制来的代码中已经存在。
- 已实现 Agent Phase 1-2 行为：居中的 AI tab、不可用 AI 页面、可编辑输入框、模型选择器、账号/订阅状态 sheet、Cloud Profile 的 Profile gate、用户记录摘要授权开关，以及五 tab 浮动底部导航。
- Phase 3 已接入 Cloud Records Foundation 和主要 hardening 链路，包括 `body_metric_logs`、food/workout 云端正式记录、`daily_summaries` 表、App 侧 summary 云端 upsert/恢复、本地 partial cache、Home 选中日期 summary cache 与 stale-while-revalidate、受控的近期 summary warm cache、confirmed cache 淘汰，以及 cloud-backed 导出完整性。
- 计划中的 Agent V1 行为：目标设计，不一定已经上线。

在代码实现前，不要把 AI Gateway、云端 chat history、RAG、Food Draft 写回或 LLM 调用写成已实现。账号登录、订阅状态、Cloud Profile 和 Cloud Records 都需要配置 Supabase 后才能连接真实后端测试。
