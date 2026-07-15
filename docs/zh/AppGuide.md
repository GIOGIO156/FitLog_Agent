# App Guide

## 目标

本文说明每个 App 区域解决什么问题、主要流程如何工作，以及更深层设计规则由哪份文档维护。它是导航型文档，不重复保存全部公式、schema 或实施计划。

| 问题 | 负责文档 |
| --- | --- |
| 产品应该做什么，为什么这样设计？ | [Product.md](Product.md) |
| 目标、摘要和热量估算如何计算？ | [Algorithm.md](Algorithm.md) |
| 哪些数据保存在哪里、字段是什么？ | [Database.md](Database.md) |
| 哪一份数据权威，如何 cache、刷新和修复？ | [CloudLocalDataBoundary.md](CloudLocalDataBoundary.md) |
| AI 可以读取、建议或写入什么？ | [AgentDesign.md](AgentDesign.md) |
| Provider 输出必须满足什么结构？ | [AIOutputContract.md](AIOutputContract.md) |
| Context、retrieval 和 evidence 如何构建？ | [RAGDesign.md](RAGDesign.md) |

## App 导航

根导航固定为：

```text
Home | Food | AI | Workout | Profile
```

中间的 AI tab 是主要 Agent 入口。Add Food AI 分析是刻意保留的例外，因为它属于食物记录创建流程。

导航遵循以下长期交互规则：

- 底部导航是跟随主题的悬浮 pill，不是全宽 footer。
- 非 AI 页面使用实体主题 surface 和页面负责的下方遮挡，避免滚动内容透过导航；AI 页面使用玻璃 pill，使动画背景保持连续。
- Root shell 不通过缩小页面 body 为导航留位。各页面负责自己的阅读 padding 或固定动作避让，共享 geometry 让 Home、Food、Workout 和 AI composer 对齐同一个导航 footprint。
- 键盘变化可以移动需要避让的控件，但不能让导航 pill 向屏幕物理底部弹跳。
- 说明型 guide 使用 root modal 阅读层；scrim 禁用底部导航，正文在需要时独立滚动，并在导航 footprint 上方保留可读空间。

精确布局 geometry 及其设计理由由 [Product.md](Product.md) 维护。

## 系统通知

页面使用 `FitLogNotifications` 提供 App 级临时反馈：

- Food 和 Workout 的保存、删除、复制成功使用顶部轻量通知；校验和云端/本地写入失败使用始终位于导航和键盘上方的底部错误通知。
- 身体记录、Profile、导出、退出、清理数据、兑换和注册验证码等成功事件使用顶部通知；auth、subscription、export、兑换、校验和 Cloud Profile 失败使用可读的底部错误提示。
- AI 用信息通知表示中性的暂不可用状态；发送、附件校验、历史操作或偏好保存失败统一使用不带关闭图标的共享错误通知。与 composer 相关的错误按实测 composer 高度放在输入区上方，不遮挡重试输入。
- Retry、undo、打开文件等带动作通知必须使用共享 action-notification API，保证按钮和 callback 不丢失。
- App 级临时通知保持原有紧凑的被动样式，不显示关闭图标，并在有界时间后自动消失；新通知替换旧通知。切换底部 tab、离开发起通知的页面或 App 进入后台时，过期通知立即清除。确认保存 Food 或 Workout 并关闭编辑页时，目标页面会有意显示一条新的成功通知，随后仍按同一有界生命周期自动消失。

Android 还会用系统“训练进行中”通知镜像包含至少一个已选动作的未保存新建训练草稿。它代表本地草稿状态，不是后台训练或正式记录；编辑已保存历史不会创建该通知：

- 有下一组力量训练时指向下一组未完成 set；当前动作仍未完成时跟随最近完成的 set，之后回到训练顺序中第一个未完成力量动作。
- 全部力量组完成后进入返回保存状态；只有有氧或没有 set 时显示简短返回继续提示。
- 点击恢复同一草稿；保存、放弃或删除全部动作后取消通知。
- Android 13+ 第一次需要显示时请求权限，拒绝权限不影响草稿本身。

## Home

Home 是选中日期的 dashboard，集中展示日期、当前饮食 phase/mode/strategy、饮食摘要、训练摘要和前往对应记录区域的紧凑入口。

主要信号取决于已保存的计算模式：

- `energy_ratio` 以 kcal 目标、摄入和剩余为主。
- `gram_per_kg` 以宏量营养克数目标为主，kcal 只是辅助。

账号恢复后，Home 可以在 active-device refresh 完成前先展示与当前账号匹配的 confirmed cache；它不得展示其他账号 cache，也不应要求用户切换日期才能恢复当天内容。英文紧凑 strategy 卡在窄屏上将 strategy 名称与带连字符的细节分行显示。

Home 继续是 dashboard，不变成 AI 工作台。除非未来明确批准 Home 专用 workflow，AI 问题都进入 AI tab。

延伸阅读：[Product.md](Product.md)、[Algorithm.md](Algorithm.md)、[Database.md](Database.md) 和 [CloudLocalDataBoundary.md](CloudLocalDataBoundary.md)。

## Food

Food 保存选中日期的正式食物记录。用户通过正常确认流程查看、新建、复制、编辑和删除记录；手动录入和外部 AI JSON 粘贴兼容路径继续保留。

### AI 辅助食物流程

Add Food 把 AI 食物分析放在第一入口。用户可以只输入文字描述，也可以同时添加最多三张相机/相册图片，并使用与 AI Chat 相互独立的 ChatGPT/千问选择器。当前发布已配置 Qwen；选择 ChatGPT 时显示正常生命周期的“当前模型不可用”错误，选择器短暂响应后自动滑回千问，保留文字和图片，不发送 request，也不改变 AI Chat 选择。小型本地 picker-recovery marker 允许 Android activity 重建后恢复分析内容，而不是返回空页面。

兼容流程还会在 Add Food 和 Paste AI Result 顶部提供“复制长期对话 Prompt”。用户只需在新的外部 ChatGPT、Gemini 或同类网页对话开头发送一次，之后在同一个对话中只发送食物图片、说明和食物数据修正。外部模型每次仍只返回一个使用既有 schema 的完整扁平 JSON 对象；最后的 `estimation_notes` 通常为空，只允许放置餐食字段或具体 item note 无法表达的必要补充，不能重复基础餐食总结。复制内容会跟随 App 当前的中文或英文模式。

分析成功只创建可编辑 Food Draft：

- Draft 打开到现有 Food Preview editor。
- 字段和视觉语言与普通食物记录保持一致。
- 有 items 时，整餐重量和营养 totals 从 item sum 派生。
- 不确定性保持可见，必要时可以要求 clarification。
- 只有用户确认 Save 才创建正式记录。
- 成功终态必须包含 Food Draft 并进入 Preview；普通解释文字不能冒充分析成功。
- 结构合法的输出仍需通过目标语言、用户明确事实、营养一致性和共享 Food policy 校验。非法输出保留当前文字/图片，并在原表单要求修正输入；专用页面不会启动 Chat 式 clarification loop。

AI Chat 图片选择另有小型 recovery marker，用于 composer 文本、provider、恢复后的 attachments 和首页背景连续性。恢复过程永远不能绕过账号、订阅、active device、网络或 Gateway readiness 校验。

延伸阅读：[AgentDesign.md](AgentDesign.md)、[AIOutputContract.md](AIOutputContract.md)、[Algorithm.md](Algorithm.md) 和 [Database.md](Database.md)。

## AI

AI 是主要 Agent surface：一个全屏对话，而不是快捷入口网格。

### 界面与交互

- 连续的程序化粉/绿/蓝液态渐变延伸到整页和玻璃导航 pill 后方。空闲首页保持明显的全屏色场运动；发送后、历史会话、等待和阅读状态改用安静低幅度运动，让聊天内容获得注意力。背景不能退化成平移静态图或明显局部移动色块。
- 首页状态文案优先使用 Cloud Profile nickname。页面还包含底部 composer、紧凑 ChatGPT/Qwen selector、左侧聊天历史入口、右上账号/订阅入口，以及紧凑 privacy/readiness hint；不使用 quick chips。
- Composer 接受文字和最多三张 JPEG、PNG 或 WebP 图片；相册可以一次填满剩余名额。当前文字和图片 turn 通过 Qwen 路由。选择未配置 ChatGPT 时显示相同的短暂错误，选择器使用与底部导航一致的滑动动画自动回到千问，保留 composer 和附件且不发送 request。状态灯仍保持订阅/设备/Gateway readiness 的真实状态；自动回到千问只是 UI 恢复，不会暗中发送请求。具体模型名和 provider key 只保留在服务端。
- 发送时立即清空 composer 并加入 pending 用户 turn。真实 pending bubble 锚定在顶部 controls 下方，不越界、不回弹；assistant loading bubble 保持到合法回复完成持久化并重新加载。失败会恢复本次输入，最终回复不会再次强制滚动。
- Message viewport 在顶部 controls 下方 hard clip 旧内容，只在 composer 上方保留短 bottom fade。共享 measured geometry 保护最后一条消息不被 composer、导航、键盘或系统 safe area 遮挡。键盘打开时，浮动 composer 在键盘上方保留 12 px 呼吸间距，局部模糊渐变 veil 避免聊天内容从 composer 与键盘之间透出；消息滚动在键盘关闭前锁定，点击 composer 以外的页面区域会先收起键盘，再恢复完整阅读空间和正常滚动。其他 App 输入页面继续保留原有键盘交互。
- Assistant 文字使用 App 风格的 GitHub-flavored Markdown 和可选择文本；用户消息保持可选择 plain text。禁用远程 Markdown 图片和 link action。图片加文字的同一 turn 把圆角 media 放在独立文字 bubble 上方，但仍保持一个 request、retry 生命周期和 history turn。
- Provider 选择保存在设备本地并跨重启恢复。未发送 composer 文本在当前运行期跨 tab 和暂时禁用状态保留；开始发送、用户主动删除、退出或切换账号会清除，发送失败则恢复。
- 发送错误使用不带关闭图标的共享被动通知，并在限定时间后自动消失；用户编辑输入、重试、切换 session、离开 AI tab 或让 App 进入后台时清除旧提示，但不删除已恢复的文字或图片。正常短暂切后台不会取消请求本身；真实超时、网络中断或 Gateway 错误在 App 回到前台后显示。
- Chat history 同一时间只允许一个删除操作。删除进行中时，当前行显示进度，全部历史行操作暂时禁用，避免快速点击同一条或连续点击多条 session 发出互相冲突的请求。

详细视觉 geometry、动画理由、主题行为和 Profile auth 呈现由 [Product.md](Product.md) 维护。

### 可用性与账号状态

Status pill 只表达 readiness；请求进行状态由发送按钮和 assistant loading bubble 表达。

| 状态 | 用户可见行为 |
| --- | --- |
| 已登录、在线、订阅有效、active device、Gateway 已配置 | 显示 `Ready`，允许发送。 |
| 发送或等待中 | Readiness 保持稳定，由发送控件和 assistant bubble 表达进行中。 |
| 未登录或离线 | 灰色禁用；用户仍可编辑未完成 prompt。 |
| 订阅或 Cloud Profile 不可用 | Gated 状态并解释账号/Profile 原因。 |
| Gateway、provider 或 active-device 校验未完成 | 准备中或不可用，发送保持禁用。 |

账号 sheet 展示账号/订阅状态、后端配置提示和用户记录摘要权限，不重复 Profile 中正式的退出登录操作。聊天历史 sidebar 支持新建、切换 session、行内重命名和确认后删除。在没有恢复体验前不暴露 archive。

### 回复、草稿与依据

所有可接受 provider reply 都必须跨过 [AIOutputContract.md](AIOutputContract.md) 定义的校验边界。用户可见解释与结构化 draft data 分离；raw provider JSON 永远不作为 assistant answer 渲染。

普通 AI Chat 的高置信度请求由 Gateway 直接固定 text 或 draft；无法确定时由模型结合自然语言、图片和同会话上下文选择受限结果类型。Add Food 等明确入口不参与这层判断。无论由哪一层选择，结构与语义不一致的 response 都不会显示为成功。

返回合法 Food Draft 或 Workout Draft 时，assistant 显示原生 artifact 卡和 `Review and confirm` / `查看并确认`：

- Artifact 卡显示通过校验的目标日期。Chat 请求中受支持的明确日期覆盖当前选中日期；没有日期表达时默认使用选中日期；无法确定的日期必须追问，不能猜测。
- Food review 重建 Food Preview。
- Workout review 重建现有训练 editor draft；已有未保存草稿时先确认替换。
- Food Preview 和训练 editor 通过各自正常、跟随主题的日历控件展示同一个 draft date。日期不作为普通文字输入框暴露，用户仍可在保存前修改。
- 后台不保持一个待命 editor 页面。
- 用户通过正常 editor 保存前，不写入正式记录。
- Workout Draft 最多追问一轮，之后返回可编辑 best-effort draft 或稳定失败。

客户端只发送有界同会话文字和 artifact summary 维持连续性。服务端可以为 routed read-only workflow 增加最小必要 Structured RAG 或 Document RAG context。记录摘要必须得到用户可见权限，不上传完整业务历史。“回答依据”面板区分参考文档、已用数据、缺少信息和受限动作；同会话连续性不作为权威 evidence 展示。

### 支持的 Workflow

- 食物图片/文字估算
- 训练草稿生成
- 用餐决策建议
- 周复盘
- App 逻辑问答

没有随请求上传图片的用餐决策回答会先提示：用户可以上传现有食材照片或外卖平台截图，以便结合图片给出推荐。该提示不改变授权 context、记录摘要权限或确认边界。

中文 App 逻辑问题检索中文稳定文档，英文问题检索英文稳定文档。即使同会话内容包含其他语言，回答仍跟随本次请求语言。

延伸阅读：[AgentDesign.md](AgentDesign.md)、[AIOutputContract.md](AIOutputContract.md)、[RAGDesign.md](RAGDesign.md)、[Product.md](Product.md) 和 [Database.md](Database.md)。

## Workout

Workout 保存正式训练记录和最多一条可恢复的新建记录草稿。用户可以创建命名记录、添加内置或自定义动作、记录有氧或力量训练、勾选支持的 sets、查看确定性热量估算，并编辑或删除已保存记录。

力量动作定义决定每组如何录入。总重量/器械标称重量已经是完整外部负重；每侧重量只在计算快照中乘 2；自重加重会在动作的有界体重参与量上加输入负重；辅助重量从体重中扣除。次数同样区分总次数和每侧次数，按时长动作则填写单组时长。编辑器继续显示原始数值和标签，保存后的 `calculation_load_kg` 与 `calculation_reps` 用于训练量和热量启发式。例如，保加利亚分腿蹲填写 12 表示每侧 12，计算次数为 24，界面不会把原始输入改成 24。

恢复条和 Android“训练进行中”通知只适用于手动创建或 AI 生成的新训练。已保存历史的编辑状态仅存在于当前页面：保存会提交修改，未保存就离开会放弃修改，不生成保留草稿。

AI 可以解释有界的近期训练模式，也可以返回 Workout Draft artifact；它不能静默创建、替换、编辑或删除正式训练记录。Clarification 最多一轮，不完整数值留在正常训练 editor 中供用户修改。

前述 Android 训练进行中通知恢复同一个未保存本地草稿，绝不创建第二份草稿或记录。

用户开始正式保存训练后，生命周期 autosave 停止。云端正式保存成功后，系统会等更早的草稿写入结束，再执行最终草稿清理，因此保存过程中切到其它 App 不会复活一份过期重复草稿；正式保存失败则保留可编辑草稿供重试。

延伸阅读：[Algorithm.md](Algorithm.md)、[Database.md](Database.md) 和 [AgentDesign.md](AgentDesign.md)。

## Profile

Profile 包含账号绑定的身份信息、身体资料、饮食设置、显示偏好、导出入口和账号控制。

### 账号与 Profile 状态

- 登录前没有正式 Profile，页面显示登录/注册而不是编辑器。
- Email/password session 跨重启保留；注册使用邮箱验证码和密码确认，nickname 之后在 Cloud Profile 编辑。
- 一个账号只有一个 active device；新设备登录会替换旧设备，旧设备在下一次受保护云端交互时进入可读的 `device_replaced` 流程。
- 登录后 Cloud Profile 是权威来源；缺失 Profile row 会用安全默认值初始化。刷新时只有账号 metadata 与当前恢复账号匹配的 cache 才能先展示。
- Subscription loading 与 Profile loading 相互独立；订阅失败不遮挡已经成功加载的 editor，但 AI 发送继续 gated。
- Profile edits 组成一份 page-local draft。修改 section 有标记；Discard 恢复已保存 snapshot，Save Changes 写入完整 Cloud Profile。离线禁止保存 Profile。
- 底部 Account card 提供明确退出。退出清除 auth session、运行期 drafts 和账号绑定本地 cache，但不删除云端正式记录。

### 身体资料与趋势

当前身体资料包括年龄、身高、体重、性别、体脂率和腰围。当前数值随完整 Cloud Profile 保存；历史体重、体脂和腰围使用独立身体记录流程。

Body Profile 日历默认打开今天。今天返回当前 Profile view；过去日期进入页内历史编辑态，其中只有体重、体脂率和腰围可编辑。不存在的过去记录保持空值；删除必须确认并使用危险操作；不可编辑区域保持清晰锁定状态，键盘聚焦保证当前 editor 可读。保存过去记录不能静默替换当前 Profile；把历史值设为当前值必须显式确认。

Body Trends 只读，支持体重、体脂和腰围，提供 7/14/21/28 天窗口、按真实日期间距绘制、chart 内不足数据状态，以及点击 point 后的行内数值。

### 设置与正式变更

Theme card 在语言设置前提供独立 Green 和 Black 选项。Green 是默认；Black 使用 Black Orange palette。Theme preference 是 `SharedPreferences` 中的本地显示状态，不属于 SQLite 或 Cloud Profile。

Profile 仍是正式修改 diet phase、calculation mode 和 strategy 的唯一位置。AI 可以解释或建议，但不能应用这些改变。

延伸阅读：[Product.md](Product.md)、[AgentDesign.md](AgentDesign.md)、[CloudLocalDataBoundary.md](CloudLocalDataBoundary.md)、[Database.md](Database.md) 和 [Algorithm.md](Algorithm.md)。

## Export

Export 是用户主动控制的本地流程，继续支持 XLSX 和 CSV ZIP。为了保证完整性，导出加载所需的权威记录；本地 cache 可以加速，但不能代替云端正式记录。Export 不会被自动云备份取代。

延伸阅读：[Database.md](Database.md) 和 [CloudLocalDataBoundary.md](CloudLocalDataBoundary.md)。

## 隐私与能力表达

隐私说明应该可见但紧凑：

- AI 在 composer 或账号状态附近显示短提示。
- Profile 解释账号绑定云存储。
- Draft review 说明 AI 估算在确认前仍是草稿。

文档和 UI copy 必须区分：

- **可用行为：**记录、Profile、导出、已配置账号/云端流程、Qwen AI Chat、聊天历史、最多三张 Qwen 图片、Food/Workout Draft review、未配置 ChatGPT 反馈和只读 evidence-backed RAG。
- **条件能力：**账号、Cloud Records、subscription、Gateway、providers 和 Document RAG 依赖相应 Supabase 配置、migrations、已部署 functions、secrets 和 seed data。
- **边界行为：**AI 可以起草、检索、建议、复盘和解释；不能静默写正式记录、删除数据、修改目标或 strategy、保留原图或运行 autonomous tools。
- **需要单独批准的未来范围：**更高图片上限、长期图片存储、用户数据 vector memory、自动正式写入、autonomous actions、生产支付管理和账号删除 UI。

不得把条件能力或未来范围描述为普遍可用；必须同时说明其依赖或批准边界。
