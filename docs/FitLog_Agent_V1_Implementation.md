# 《FitLog_Agent V1 产品与实现设计书》

## 0. V1 锁定结论

FitLog_Agent V1 是在 FitLog Local 既有饮食、训练、Profile、算法和 SQLite 工作流基础上，新增一个由云端 AI Gateway 支撑的订阅制 AI Chat 页面。

V1 的核心不是把整个 App 变成 AI Coach，也不是让模型自由读写用户数据。Phase 2 收口后，V1 的工程顺序改为先把正式记录源统一到云端，再接 AI Gateway 和 RAG。V1 的核心是：

```text
FitLog_Agent V1
= 登录前置的云端正式记录源
+ 本地 partial cache / 草稿 / 运行期加速层
+ 现有 FitLog 确定性算法
+ 云端账号 / 订阅 / Profile
+ 云端 AI Gateway
+ 居中的全屏 AI Chat 页面
+ 受控的 Vision / Structured RAG / Document RAG workflow
+ Chat 内草稿预览与用户确认
```

一句话定位：

> FitLog_Agent V1 是一个云端 AI 辅助的饮食与训练记录 App。用户登录后拥有云端 Profile，并通过底部导航正中间的 AI Chat 页面主动发起 AI 请求。AI 可以生成饮食草稿、用餐建议、周复盘和 App 规则解释，但不能静默修改目标、策略或正式记录；所有正式写入都必须由用户确认。

V1 已锁定的关键取舍：

- AI 页面是一个简单沉浸式 Chat，不是 quick chips 工作台。
- AI tab 位于底部导航正中间。
- 所有 Agent workflow 默认从 AI Chat 发起。
- `Add Food` 的拍照识别是唯一业务页例外。
- AI 页面使用全屏彩色流动背景。
- 未登录或未联网时，AI 页面背景变灰，不能发送消息。
- 底部导航统一改成浮动白色 pill，pill 外不绘制整行背景。
- Profile 跟账号走，云端 Profile 是主版本。
- 未登录前没有正式 Profile。
- 离线时 Profile 可查看缓存，但禁止保存修改。
- Chat history 登录后云端保存，左侧可折叠历史栏展示，本地不长期保存。
- V1 采用订阅制，不做用户可见的按次额度 UI。
- V1 采用单 active device，last login wins；旧设备收到 `device_replaced` 后不能继续正式写入或 AI 发送。
- AI 使用远程 LLM；模型 API key 由服务端统一管理，不让用户在 App 内填写。
- V1 支持 Structured RAG 和 Document RAG 设计，但不把用户业务数据做长期 embedding / semantic memory。
- Phase 3 Cloud Records Foundation 后，body/food/workout 正式记录以云端为 source of truth；本地 SQLite 只做 partial cache，不做完整历史镜像。

---

# 1. 项目定位

## 1.1 项目名称

**FitLog_Agent V1**

## 1.2 产品类型

- AI-assisted food and workout logging app
- Cloud-assisted AI fitness logging app
- Subscription-based AI Chat experience
- Weak Agent / Agentic Workflow Hub
- Vision Workflow + Structured RAG + Document RAG 的受控组合

这里的 “Agent” 不表示强 Agent。V1 不允许模型自由多步行动、任意查库、任意写库、长期记忆用户偏好或自动修改目标。V1 的 Agent 性来自统一 Chat 入口里的 intent routing 和 workflow dispatch。

## 1.3 V1 要验证的问题

V1 只验证这些闭环：

1. **AI 是否能降低复杂饮食录入成本**
   - 食堂、外卖、混合菜、部分食用、去皮、少油、汤没喝等场景难以手动估算。
   - AI 应把图片/描述转成可编辑 Food Draft。

2. **AI 是否能基于 Profile 和当天记录帮助用户做下一餐决策**
   - 例如“今天还能吃什么”“这个外卖能点吗”“冰箱里这些怎么搭配”。
   - AI 不重新计算目标，只引用已有 Profile、目标、记录和摘要。

3. **AI 是否能基于 7 / 14 天记录生成可执行周复盘**
   - 不是自动调参。
   - 不是自动改 strategy。
   - 只总结行为模式、数据缺口、主要问题和少量行动建议。

4. **统一 AI Chat 是否能稳定调度不同 workflow**
   - 用户不需要先理解自己该点哪个功能。
   - Chat 根据用户输入、图片、当前语言、登录状态和上下文判断 workflow。

5. **云端正式记录 + 本地 partial cache 的边界是否足够清晰**
   - Profile 跟账号走。
   - body/food/workout 正式记录跟账号走。
   - 本地 SQLite cache 不是权威数据源。
   - AI 请求只读取最小必要云端摘要。

---

# 2. V1 与 FitLog Local 的关系

## 2.1 Local 版是产品和算法基准

FitLog_Agent 从 FitLog Local 复制而来。Local 版已经实现的饮食、训练、算法、Profile、导出和本地 SQLite 工作流仍是 V1 的基础。

必须继承的 Local 能力：

| 模块 | V1 继续继承 |
|---|---|
| Food | 手动饮食记录、外部 AI JSON 粘贴解析、Food Preview、编辑、复制、删除 |
| Workout | 本地训练记录、动作库、自定义动作、训练草稿、训练消耗估算 |
| Home | 选中日期摘要、摄入、运动、目标、剩余宏量/热量展示 |
| Profile | 饮食阶段、计算模式、策略设置、训练频率、自检、导出、清空本地数据 |
| Algorithm | BMR、TDEE、`energy_ratio`、`gram_per_kg`、训练消耗、校准、自检 |
| Strategy | `carb_cycling`、`carb_tapering` 本地确定性逻辑和用户确认机制 |
| Database | Phase 3 前沿用 SQLite additive migrations；Phase 3 后云端 records + 本地 partial cache |
| Export | XLSX / CSV ZIP 本地导出 |

不能改变的算法红线：

- `diet_goal_phase` 是 cutting / bulking 的来源。
- `diet_calculation_mode` 决定基础计算模式。
- `diet_plan_strategy` 只在基础目标之后应用。
- `energy_ratio` 下 kcal target / intake / remaining 是主信号。
- `gram_per_kg` 下宏量克数是主目标，kcal 只是辅助信息。
- `carb_cycling` 不能被解释成 AI 自动配餐。
- `carb_tapering` 不能被解释成 AI 自动减碳。
- 训练消耗仍由本地确定性规则计算。
- AI 不得静默覆盖 Local 计算结果。

## 2.2 Agent V1 是云端 AI 辅助层

Agent V1 负责：

- 接收用户自然语言、图片和追问。
- 判断用户意图。
- 判断用户是否登录、是否在线、是否订阅。
- 判断需要哪个 workflow。
- 读取云端 Profile。
- 调用云端 summary/context builder 获取必要摘要。
- 调用后端 AI Gateway。
- 调用远程 LLM / 多模态模型。
- 验证模型输出 schema。
- 在 Chat 中展示草稿、建议、复盘或解释。
- 对不确定信息进行追问。
- 等待用户确认后再调用本地保存逻辑。

Agent V1 不负责：

- 自动修改饮食目标。
- 自动修改 Profile。
- 自动修改 `diet_plan_strategy`。
- 自动修改 carb cycling day pattern / multipliers。
- 自动应用 carb taper。
- 自动删除记录。
- 自动生成长期饮食计划。
- 自动生成长期训练计划。
- 做医疗诊断或治疗建议。
- 让模型读取完整原始 food / workout / body 历史。
- 把本地 SQLite cache 当成 AI 或产品权威数据源。
- 把用户业务数据做长期 embedding / semantic memory。

## 2.3 “不是 local-first 主叙事”：云端正式记录与本地 partial cache

Agent 版不再把 “local-first” 作为主卖点，因为 V1 明确包含：

- 账号系统；
- 云端 Profile；
- 订阅制；
- 云端 AI Gateway；
- 远程 LLM；
- 云端 Chat history；
- 云端 AI request / response 记录。

因此 Phase 3 必须先完成 Cloud Records Foundation。更准确的表述是：

> V1 使用云端服务承载账号、订阅、Profile、正式 body/food/workout 记录、daily summaries 和 AI 能力；本地 SQLite 降级为 partial cache、草稿和运行期加速层，不再作为正式业务记录 source of truth。

---

# 3. 为什么是 Weak Agent

## 3.1 单个 workflow 只是 AI workflow

例如 Photo Food Logging：

```text
用户上传食物图片
-> AI 识别食物和分量
-> 返回结构化 FoodEstimate
-> App 展示 Food Draft
-> 用户编辑和确认
-> App 写入 food_records / food_items
```

这本身不是强 Agent。它是固定输入、固定 schema、固定确认路径的 AI workflow。

## 3.2 统一 AI Chat 带来 Agent 性

当用户只说：

```text
帮我看看这个
这个能吃吗
今天还剩多少
为什么最近没瘦
g/kg 为什么没有剩余 kcal
```

系统需要判断：

- 用户是在记录食物，还是只是估算？
- 图片是已吃食物、外卖菜单、冰箱图、营养标签，还是非食物？
- 是否需要当前 Profile？
- 是否需要今日记录？
- 是否需要 7 / 14 天记录？
- 是否需要文档检索？
- 是否要追问？
- 是否涉及正式写入？
- 是否必须展示草稿预览？

这个统一调度层就是 Weak Agent / Agentic Workflow Hub。

## 3.3 V1 不是强 Agent 的原因

V1 不允许模型自由行动。所有能力都由工程侧限制：

```text
固定 intent taxonomy
固定 workflow 类型
固定 Context Builder
固定 Read Tool
固定 Draft Tool
固定 Write Tool 权限
固定 output schema
固定 safety rules
固定 user confirmation
固定 fallback
```

AI 不能：

- 自己决定任意 SQL 查询。
- 自己决定任意写数据库。
- 自己更新 Profile。
- 自己改目标。
- 自己应用策略。
- 自己删除数据。
- 自己长期记忆用户偏好。
- 自己多轮调用工具直到完成开放目标。

---

# 4. V1 功能范围总览

## 4.1 V1 必做功能

| 功能 | 类型 | V1 状态 |
|---|---|---|
| 云端账号 | 基础设施 | 核心 |
| 订阅制 | 商业化基础 | 核心 |
| 云端 Profile | 账号级用户信息 | 核心 |
| AI Gateway | 模型调用后端 | 核心 |
| 底部导航 AI tab | 主入口 | 核心 |
| 沉浸式 AI Chat 页面 | 主要体验 | 核心 |
| 左侧可折叠 Chat history | 云端会话回看 | 核心 |
| 右上角账号/订阅入口 | 状态入口 | 核心 |
| 全屏彩色/灰色动效背景 | AI 页面视觉 | 核心 |
| Intent Router | workflow 调度 | 核心 |
| Photo Food Logging | Vision Workflow | 核心 |
| Meal Decision | Structured RAG | 核心 |
| Weekly Review | Structured RAG | 核心 |
| App Logic Q&A | Document RAG | 核心 |
| Context Builder | 上下文构建 | 核心 |
| Chat 内草稿预览 | 写入前确认 | 核心 |
| schema validation | 输出安全 | 核心 |
| request / response logging | 调试和历史 | 核心 |
| failure / clarification flow | 可恢复状态 | 核心 |

## 4.2 V1 明确不做

- 强 Agent。
- 多 Agent。
- AI Coach 陪伴式长期对话。
- 一次性全量历史下发、本地完整历史镜像或旧本机历史自动迁移。
- 用户业务数据向量库。
- 用户长期 embedding storage。
- semantic memory。
- GraphRAG。
- 自动修改目标。
- 自动修改 Profile。
- 自动修改 carb cycling pattern / multipliers。
- 自动应用 carb taper。
- 自动删除记录。
- 外卖平台官方 API。
- Apple Health / Google Fit。
- 睡眠、心率、压力数据接入。
- 完整自然语言训练记录正式落地。
- 医疗诊断。
- 儿童青少年治疗建议。

---

# 5. 总体架构

## 5.1 架构一句话

> 云端负责账号、订阅、Profile、正式 body/food/workout 记录、daily summaries、AI Gateway、Chat history 和模型调用；App 端保留确定性算法、本地 partial cache、草稿和运行期加速层；AI 根据云端 Profile 与必要云端摘要生成草稿、建议、复盘或解释；用户确认后才通过记录 API 写入正式云端记录。

## 5.2 总体数据流

```text
用户打开 AI tab
        ↓
检查登录 / 网络 / 订阅状态
        ↓
可用：彩色动效 Chat
不可用：灰色不可发送状态
        ↓
用户输入文字 / 上传图片
        ↓
Intent Router
        ↓
选择 workflow
        ↓
读取云端 Profile
        ↓
按需调用云端 Summary / Context Builder
        ↓
发送最小必要 context 到 AI Gateway
        ↓
远程 LLM / Multimodal Model
        ↓
Schema Validation / Safety Guard
        ↓
返回 Answer / Draft / Recommendation / Review
        ↓
Chat 内展示卡片或弹窗
        ↓
用户轻量编辑 / 追问 / 放弃 / 打开 full editor / 确认保存
        ↓
如确认保存：调用 Cloud Records API / Repository
        ↓
云端正式记录更新
        ↓
本地 partial cache 与 Home / Food Log 等页面刷新
```

## 5.3 数据分层

| 层 | 数据 | V1 保存位置 | 说明 |
|---|---|---|---|
| 账号层 | user id、登录、订阅 | 云端 | AI 使用权限与身份 |
| Profile 层 | nickname、当前身体数据、饮食目标、策略设置 | 云端主版本 + 本地缓存 | 跟账号走 |
| AI 服务层 | chat sessions、messages、final answers、request logs | 云端 | 登录后可回看 |
| 正式记录层 | body metric logs、food、workout、daily summaries | 云端主版本 + 本地 partial cache | Phase 3 统一 source of truth |
| 本地运行时聚合 | strategy result、临时 UI state | App 运行时 | 不作为权威表长期保存 |
| 导出文件 | XLSX / CSV ZIP | 本地文件 | 由用户触发 |

---

# 6. AI 页面设计

## 6.1 页面定位

AI 页面是一个简单、沉浸式 Chat 页面。

它不是：

- quick chips 工作台；
- 多入口功能页；
- 营销 landing page；
- 复杂 dashboard；
- 功能卡片列表。

它是：

- 全屏动态背景；
- 中心状态文案；
- 真实聊天输入；
- 云端会话历史；
- Chat 内结果卡片；
- 用户确认入口。

## 6.2 底部导航位置

底部导航建议为：

```text
Home | Food | AI | Workout | Profile
```

AI 位于正中间。它是 V1 Agent 能力的主入口。

## 6.3 底部导航视觉

现有导航条外层整行背景应移除。

最终设计：

- 底部只保留白色浮动 pill。
- pill 外侧不绘制整行绿色背景。
- AI 页背景动效延伸到屏幕底部和 pill 两侧。
- 普通页面背景也自然延伸到 pill 两侧。
- 不出现不同页面之间“有绿色底 / 没绿色底”的跳变。

推荐 pill 样式：

```text
background: white 92%-97% opacity
optional subtle blur
light border
soft shadow
rounded pill
icon + label inside
outside area fully transparent
```

不建议 pill 完全透明。它可以有轻微玻璃态，但图标和文字必须清晰。

## 6.4 AI 页面结构

```text
AIPage
├── AnimatedAiBackground
│   ├── colorful state
│   └── grayscale disabled state
├── TopBar
│   ├── ChatHistoryButton
│   └── AccountSubscriptionButton
├── ChatHistorySidebar
├── CenterListeningText
├── MessageList
│   ├── UserMessage
│   ├── AssistantMessage
│   ├── ClarificationCard
│   ├── FoodDraftPreview
│   ├── MealRecommendationCard
│   ├── WeeklyReviewCard
│   └── AppLogicAnswerCard
└── Composer
    ├── model selector
    ├── image attach
    ├── text input
    └── send button
```

## 6.5 中心文案

中心文案根据登录、网络和昵称状态变化。

| 状态 | 文案 |
|---|---|
| 已登录且有昵称 | `我在听，{nickname}` |
| 已登录但无昵称 | `我在听` |
| 未登录 | `登录后开始使用 FitLog AI` |
| 离线 | `当前离线，AI 暂不可用` |
| 未订阅 | `订阅后开始使用 FitLog AI` |

当消息列表为空时，文案居中显示。  
当消息变多时，文案弱化或让位给消息列表。

## 6.6 顶部右侧账号 / 订阅入口

右上角显示一个小标识。

点击后展示：

- 当前账号；
- 订阅状态；
- AI 是否可用；
- 登录 / 登出；
- 订阅入口；Profile 页面提供“订阅”卡片，可刷新状态并输入开发期内部兑换码；
- 隐私说明入口。

V1 不显示“剩余额度”，因为 V1 采用订阅制而非按次额度 UI。

## 6.7 左侧 Chat history

Chat history 采用左侧可折叠侧栏。

手机端表现：

- 默认收起；
- 点击左上按钮或边缘按钮打开；
- 从左侧滑出；
- 背后页面轻微遮罩或模糊；
- 侧栏使用 FitLog 风格白色/玻璃态面板；
- 右侧圆角、轻阴影；
- 不使用厚重的系统默认 drawer 视觉。

桌面 / 平板可扩展为：

- 常驻窄侧栏；
- 或半展开侧栏；
- 但 V1 移动端优先。

历史规则：

- 未登录：不显示历史，只显示登录提示。
- 登录后：从云端加载历史会话。
- 支持打开旧会话。
- 支持删除会话。
- 不做文件夹、收藏、长期记忆。
- 旧会话只用于回看，不默认影响未来回答。

## 6.8 Composer

底部输入框支持：

- 在 `ChatGPT` 和 `千问` 之间选择本次对话使用的模型 provider；
- 输入文字；
- 上传图片；
- 删除待上传图片；
- 发送；
- 离线时继续编辑未发送 prompt；
- 未登录、未订阅、离线时禁用发送。

未发送 prompt 的保留规则：

- 未发送文本是设备级本地草稿，不是云端 chat message；
- 当前运行期内，切换页面、离线或订阅状态变化都不自动清空；
- 只有用户主动删除或发送成功后才清空；
- 退出登录或切换账号时清空，避免上一账号上下文残留。

输入框视觉：

- 位于底部导航上方；
- 半透明或白色玻璃态；
- 模型选择器靠近输入区，使用紧凑 segmented control 或 menu，不做大卡片；
- 文字可读性优先；
- 上传图片后显示缩略图；
- 发送按钮状态明确。

---

# 7. AI 背景动效

## 7.1 设计目标

背景应像参考图一样：

- 全屏铺满；
- 柔和；
- 浅色；
- 彩色渐变；
- 持续缓慢流动；
- 不抢阅读；
- 不造成焦虑。

## 7.2 V1 简化状态

V1 不需要复杂情绪状态，只保留四种：

| 状态 | 动效 |
|---|---|
| 正常可用 | 彩色背景缓慢流动 |
| AI 正在处理 | 背景略微加速，亮度和层次轻微增强 |
| AI 需要补充信息 | 回到缓慢流动，追问卡片或输入区更突出 |
| 未登录 / 未联网 / 未订阅 | 背景变灰，动效停止或极慢 |

## 7.3 灰色不可用状态

未登录、未联网或未订阅时：

- 背景从彩色变为灰色；
- 动效停止或极慢；
- 中心文案说明原因；
- 输入框可以保留；
- 用户正在输入的 prompt 不丢失；
- 发送按钮禁用；
- 不进入 AI thinking 状态。

## 7.4 消息列表与背景

当消息列表出现后：

- 背景继续存在；
- 消息区域后方降低饱和度和亮度；
- 消息气泡、草稿卡片、输入框保持高对比；
- 结果卡片可以使用半透明白色或玻璃态，但字段必须清楚。

## 7.5 Accessibility

- 支持系统 reduce motion。
- reduce motion 开启时，背景改为静态渐变或极低速动画。
- 不使用闪烁或快速脉冲。
- 不依赖颜色表达唯一状态，必须有文字提示。

---

# 8. 登录、Profile 与账号

## 8.1 登录前状态

未登录前：

- 没有正式 Profile。
- AI 页面是灰色不可用状态。
- Chat history 不显示历史。
- Profile 页面显示登录入口或账号创建引导；当前 Phase 2 UI 使用主题纯色背景、无星 FitLog logo base asset、AI 星光 overlay 动画、邮箱密码登录、注册验证码、密码确认和绿色主按钮。
- 用户不能使用个性化 AI workflow。

## 8.2 登录后 Profile

登录后：

- 云端 Profile 是主版本。
- 本地保存当前账号的 Profile 缓存。
- App UI 使用本地缓存快速展示。
- 进入 AI 页或 Profile 页时可静默刷新云端 Profile。

## 8.3 Profile 修改

Profile 修改规则：

- 必须在线。
- 保存时写云端。
- 云端保存成功后更新本地缓存。
- 离线时禁用保存按钮。
- 不做 pending sync。

离线时 Profile 页面：

- 可查看本地缓存。
- 不允许提交修改。
- 提示“联网后可修改资料”。

## 8.4 Profile 字段

云端 Profile 建议保存：

```text
user_id
nickname
age
height_cm
weight_kg
sex_for_formula
diet_goal_phase
diet_calculation_mode
daily_energy_goal_kcal
protein_ratio_percent
carbs_ratio_percent
fat_ratio_percent
training_frequency_per_week
diet_plan_strategy
carb_cycle_pattern_json
carb_cycle_high_multiplier
carb_cycle_medium_multiplier
carb_cycle_low_multiplier
carb_taper_review_period_days
carb_taper_target_loss_pct_per_week
carb_taper_step_g
carb_taper_current_delta_g
language_code
profile_version
created_at
updated_at
```

说明：

- `weight_kg` 是当前 Profile 体重。
- 历史体重、体脂和腰围属于 `body_metric_logs`，在 Phase 3 Cloud Records Foundation 后以云端为正式 source of truth。
- `profile_version` 用于 AI context 和缓存一致性。

## 8.5 删除账号

用户删除账号时：

- 删除云端账号；
- 删除云端 Profile；
- 删除云端 Chat history；
- 删除可识别 AI request / response 数据；
- 删除云端正式 body/food/workout 记录或按账号删除策略处理；
- 清理本地缓存；
- 本地 partial cache 可直接清理；旧本机历史导入/保留属于 Post-V1 迁移决策。

---

# 9. 云端与本地数据边界

## 9.1 云端保存

V1 云端保存：

```text
accounts
subscriptions
cloud_profile
body_metric_logs
food_records
food_items
workout_records
workout_sessions
workout_sets
daily_summaries
ai_chat_sessions
ai_chat_messages
ai_final_answers
ai_request_logs
ai_debug_summaries
model / prompt / schema versions
request status / error code
```

## 9.2 本地保存

V1 本地保存：

```text
account-bound records/read-model cache
draft records
custom exercise cache
workout_record_drafts
local export files
cached profile
cached selected date / UI state
```

## 9.3 本地 partial cache 边界

本地 SQLite 在 Phase 3 后不是正式业务 source of truth，而是 partial cache、草稿和运行期加速层。cache-first 读取、warm cache、容量、淘汰、账号切换、失败和修复规则以 `docs/zh/CloudLocalDataBoundary.md` / `docs/en/CloudLocalDataBoundary.md` 为准。

本阶段仍不做完整历史 SQLite 镜像；清理 cache 不删除云端正式记录。

## 9.3.1 单 active device 与旧设备替换

Phase 3 应先落账号级 active-device 边界，再开放 Cloud Records 写入。登录成功后当前设备调用 `claim_active_device` 接管账号；正式 body/food/workout records、Cloud Profile 保存和后续 AI Gateway 请求都必须通过 active-device guard。

新设备登录采用 last login wins。旧设备不需要实时收到推送下线，但下一次 session refresh、云端读取、正式写入、订阅刷新或 AI 请求返回 `device_replaced` 时，App 必须显示“账号已在另一台设备登录”，清本地登录态并回到登录/重新接管路径。`device_replaced` 不能显示成普通上传失败，也不能允许旧设备继续重试同一 session。

## 9.4 旧本机历史与迁移

当前 Agent 版没有真实用户饮食/训练历史，可以登录前置并从云端正式记录开始。若未来要承接旧 Local 本机历史，必须提供显式迁移确认，不能静默归属到当前账号。

旧本机历史迁移需要单独解决：

- 导入到当前账号；
- 保留为本机旧数据；
- 导出后清空；
- 迁移冲突；
- 删除账号后的本机残留策略。

## 9.5 AI 请求时的摘要上传

当 AI 需要分析用户记录时，AI Gateway 调用受限 wrapper / context builder 生成最小必要摘要，而不是上传完整数据库或完整原始历史。

示例：

```text
最近 7 天 food coverage
最近 7 天 kcal / P / C / F 汇总
最近训练天数
当前 selected date summary
体重趋势是否足够
缺失数据 flags
```

---

# 10. AI Gateway 与后端

## 10.1 后端职责

后端负责：

- Auth；
- Subscription；
- Cloud Profile；
- AI Gateway；
- Model API key 管理；
- Prompt Registry；
- Schema Validation；
- Safety Guard；
- Request Logging；
- Chat History；
- Document Retrieval；
- Debug Summary。

后端不提供 V1 默认无限原始历史读取：

- 模型不能直接读取用户完整 food 数据库；
- 模型不能直接读取用户完整 workout 数据库；
- 模型不能直接读取完整 body metric history；
- 本地导出文件；
- 本地 SQLite migration；
- 无生命周期的 raw context 存储。

## 10.2 Phase 0 技术选型锁定

Phase 0 锁定以下工程选型：

| 事项 | V1 决策 |
|---|---|
| 后端方案 | Supabase |
| Auth | Supabase Auth，首版只做 FitLog 自有邮箱密码登录 + 注册邮箱验证码 |
| 云端数据库 | Supabase Postgres |
| 临时图片对象 | Supabase Storage 私有临时 bucket |
| AI Gateway | Supabase Edge Functions |
| 订阅状态 | 开发期内部 entitlement 表，种子账号和内部兑换码区分 subscribed / unsubscribed |
| AI providers | OpenAI / ChatGPT 与千问 / Qwen，用户在 AI Chat 输入区选择，服务端 adapter 调用 |

选择 Supabase 的原因：

- V1 需要账号、Cloud Profile、chat history、request logs、debug summaries、document chunks 和临时图片对象，Supabase 的 Auth、Postgres、Storage 和 Edge Functions 能覆盖这些需求。
- 相比 Firebase，Postgres 表结构更适合 Profile、chat、log 和文档索引这类关系型数据，也更容易做 contract test 和 SQL 层审计。
- 相比自建后端，Supabase 能减少 Phase 2-3 的基础设施工作量，让工程先验证账号、订阅 gating、Cloud Profile 和 AI Gateway 状态机。
- 如果后续因为生产支付、部署区域、合规或延迟需要迁移，App 仍应通过 `docs/API_CONTRACT_DRAFT.md` 中的接口 contract 访问后端，避免把业务 UI 绑定到供应商细节。

首版登录方式：

- 用户使用任意可接收验证码的邮箱注册或登录。
- 未登录前没有正式 Profile。
- V1 不做游客正式 Profile。
- Apple、Google、手机号等登录方式不进入首版，避免扩大账号状态矩阵。

订阅方案：

- 开发期先做服务端内部 entitlement，不接真实支付。
- 至少准备两个调试账号：一个 subscribed，一个 unsubscribed。
- Profile 页面可通过内部兑换码 RPC 为当前账号开启开发期 AI entitlement；兑换码只用于内部测试，不代表生产支付流程。
- App 只显示 AI 是否可用，不显示剩余额度。
- AI Gateway 每次请求仍必须服务端校验 entitlement，不能只相信客户端状态。
- 生产支付 provider 以后再定，但必须写入同一套服务端 entitlement contract。

AI providers：

- V1 支持 OpenAI / ChatGPT 和千问 / Qwen 两种 provider。
- 用户可在 AI Chat 输入区选择 `ChatGPT` 或 `千问`。
- 工程 contract 使用稳定 provider id：`openai` 和 `qwen`。
- OpenAI 和 Qwen API keys 只放在 Supabase Edge Function secrets 或等价服务端 secret 中。
- Flutter App 不保存、展示或传输模型 key。
- 文本、vision 和 structured output 的具体模型名通过服务端环境配置控制，不写死到 App。
- 具体 API key 创建位置、模型名和服务端环境变量到 Phase 4 实现 AI Gateway 时再按当时官方后台核验并填写。
- 如果后续更换或增加 provider，必须保持 AI Gateway request / response contract 不变。

图片策略：

- App 端先压缩图片，再上传到 Supabase Storage 私有临时 bucket。
- AI Gateway 接收 attachment reference，而不是长期公开 URL。
- 每次 AI 请求最多 3 张图片。
- 压缩目标为单张不超过 1.5 MB；压缩后仍超过 5 MB 则拒绝并提示用户换图或裁剪。
- 推荐最长边 1600 px，默认使用 JPEG，除非图片确实需要透明通道。
- 原图默认不长期保存；临时图片默认 24 小时过期。
- 用户丢弃 draft、删除会话或删除账号时，应删除可关联的临时图片。

## 10.3 API key 策略

V1 不做用户自带 API key。

规则：

- 模型 API key 由服务端统一管理。
- App 不保存 OpenAI / Qwen / Gemini / 其他模型 key。
- 用户通过账号和订阅获得 AI 使用权限。
- 后端可根据成本、模型能力和安全策略切换模型。

## 10.4 推荐接口

V1 可以保留专用 endpoint，避免一开始做自由 tool calling。

```text
POST /auth/*
GET  /subscription/status
GET  /profile
PUT  /profile
GET  /ai/chats
POST /ai/chats
GET  /ai/chats/{chat_id}/messages
DELETE /ai/chats/{chat_id}
POST /ai/chat/route
POST /ai/food-estimate
POST /ai/meal-decision
POST /ai/weekly-review
POST /ai/app-docs-answer
POST /ai/attachments
DELETE /ai/attachments/{attachment_id}
```

统一 Chat 是产品入口；专用 endpoint 是工程实现方式。Router 可以把用户请求分发到专用 endpoint。

---

# 11. 订阅制

## 11.1 V1 不做用户可见额度

V1 采用订阅制，不做“本月剩余 AI 次数”UI。

AI 页右上角只显示：

- 登录状态；
- 订阅状态；
- AI 是否可用。

## 11.2 订阅状态

| 状态 | AI 页面 |
|---|---|
| 未登录 | 灰色，提示登录 |
| 已登录未订阅 | 灰色或订阅引导，不能发送 |
| 已订阅在线 | 彩色，可发送 |
| 已订阅离线 | 灰色，可编辑输入但不能发送 |

## 11.3 后端仍需记录成本

虽然不显示额度，后端仍应记录：

- request count；
- feature_type；
- model；
- latency；
- token estimate；
- image count；
- error rate；
- subscription tier。

用途：

- 成本分析；
- 风控；
- debug；
- 未来定价；
- 模型优化。

---

# 12. RAG 与上下文设计

## 12.1 V1 不是“不做 RAG”

V1 不是禁用 RAG。V1 的重点是：

- 可以做 Structured RAG；
- 可以做 Document RAG；
- 不在 V1 默认做用户业务数据向量库；
- 不做 semantic memory；
- 不做 GraphRAG；
- 不做开放式 Agent 自由检索循环。

## 12.2 Structured RAG

Structured RAG 用于用户个人数据问题。

典型问题：

```text
为什么最近没瘦？
今天还能吃什么？
这个外卖适合我吗？
这周哪里做得不好？
蛋白质是不是不够？
训练日碳水是不是太低？
```

检索方式：

- 固定 function；
- repository 查询；
- service 聚合；
- Context Builder 摘要；
- 不让 LLM 自由查 SQL；
- 不把用户业务数据长期 embedding 化。

可能使用的数据：

```text
cloud profile
selected date
DailySummary
food record count
food macro summary
workout summary
weight trend availability
food log coverage
training frequency
diet strategy context
missing data flags
```

## 12.3 Document RAG

Document RAG 用于 App 规则解释。

典型问题：

```text
BMR 是怎么算的？
为什么 g/kg 模式没有剩余 kcal？
为什么运动消耗要减去 1 MET？
carb cycling 是什么？
carb taper 为什么不能自动应用？
为什么数据不足时不能下结论？
```

检索对象：

```text
README
Product
AppGuide
Methodology
Algorithm
Database
AgentDesign
References
```

语言规则：

- 中文问题检索 `docs/zh/*`；
- 英文问题检索 `docs/en/*`；
- 中英混合优先当前 App 语言或主要语言；
- 回答应标明 source section。

检索实现可选：

- 关键词；
- section metadata；
- SQLite FTS；
- 文档向量；
- hybrid retrieval。

如果 V1 使用向量检索，应优先索引 App 文档，不索引用户 food / workout / weight 业务数据。

## 12.4 Vision Workflow 不是 RAG

Photo Food Logging 主要是：

```text
Multimodal image understanding
Food estimation
Structured output
Draft preview
```

它不是依赖检索增强的 RAG workflow。

## 12.5 Context Metadata

每次 AI 请求保存摘要级 metadata：

```text
request_id
user_id
chat_id
workflow_type
selected_date
period_days
profile_version
food_record_count
workout_record_count
weight_log_count
missing_data_flags
context_builder_version
prompt_version
schema_version
model
status
error_code
```

默认不长期保存完整 context JSON。失败请求或 debug 模式可短期保存必要 payload。

---

# 13. Intent Router

## 13.1 Router 输入

```json
{
  "message": "为什么最近没瘦？",
  "locale": "zh",
  "app_language": "zh",
  "chat_id": "optional",
  "attachments": [],
  "selected_date": "2026-06-17",
  "is_logged_in": true,
  "subscription_active": true,
  "network_available": true,
  "profile_version": "profile_42"
}
```

## 13.2 Intent taxonomy

```text
food_logging
food_estimation_only
meal_decision
weekly_review
app_logic_question
profile_question
unsupported_medical
unsupported_goal_change
unsupported_training_plan
smalltalk
unclear
```

## 13.3 Workflow taxonomy

```text
photo_food_logging
manual_food_draft_from_text
meal_decision
weekly_review
app_logic_answer
clarification
refusal
general_chat
```

## 13.4 Router 输出

```json
{
  "intent": "weekly_review",
  "workflow": "weekly_review",
  "confidence": 0.86,
  "needs_clarification": false,
  "required_context": [
    "cloud_profile",
    "recent_food_summary",
    "recent_workout_summary",
    "weight_trend_availability"
  ],
  "requires_write_confirmation": false,
  "safety_flags": [],
  "reason": "用户询问近期体重变化原因，需要最近记录摘要。"
}
```

## 13.5 低置信度规则

Router 低置信度时，不应猜测执行。

应追问：

- “你是想把这顿饭记录下来，还是只是估算一下？”
- “这张图是已经吃过的饭，还是外卖菜单？”
- “你想看 7 天还是 14 天复盘？”
- “你想让我解释 App 规则，还是根据你的记录做建议？”

---

# 14. Tool / Function / Wrapper

## 14.1 Tool 分层

| 工具类型 | 用途 | V1 是否允许 | 是否需要确认 |
|---|---|---:|---:|
| Read Tool | 读取云端摘要 | 是 | 否 |
| Profile Tool | 读取云端 Profile | 是 | 否 |
| Vision Tool | 图片识别 / 估算 | 是 | 否 |
| Document Search Tool | 检索 App 文档 | 是 | 否 |
| Draft Tool | 创建草稿 | 是 | 部分场景 |
| Write Tool | 保存正式记录 | 是 | 必须确认 |
| Dangerous Tool | 删除 / 改目标 / 应用策略 | V1 不开放 | 不适用 |

## 14.2 Read Tools

```text
get_cloud_profile()
get_today_summary(date)
get_today_food_records_summary(date)
get_today_workout_summary(date)
get_recent_food_summary(days)
get_recent_workout_summary(days)
get_body_metric_summary(days)
get_weight_trend_availability(days)
get_diet_strategy_context()
get_training_frequency_context(days)
```

Read Tool 只能返回摘要，不直接把完整 SQL rows 塞给模型。Read Tool 读取云端 source of truth 或云端 summary builder；本地 SQLite cache 不能作为 AI 权威来源。

## 14.3 Draft Tools

```text
create_food_draft()
create_meal_recommendation_draft()
create_weekly_review_card()
create_app_logic_answer()
```

Draft 不等于正式记录。

## 14.4 Write Tools

V1 允许：

```text
save_food_draft_as_record()
save_edited_food_record()
save_weekly_review_report_if_enabled()
```

调用条件：

- 用户已明确确认；
- schema 已通过；
- 必填字段齐全；
- 数值通过范围校验；
- 不涉及危险字段。

## 14.5 禁止工具

```text
delete_food_record()
delete_workout_record()
batch_edit_records()
update_profile_from_ai()
update_diet_goal()
change_diet_plan_strategy()
change_carb_cycle_pattern()
apply_carb_taper()
clear_local_data()
```

这些操作 V1 不通过 AI 执行。

---

# 15. Context Builder

## 15.1 总原则

Context Builder 负责把云端正式数据和必要缓存结果变成最小必要上下文。权威输入来自 Cloud Profile、Cloud Records 和 daily summaries；本地 SQLite cache 只能作为展示/性能层，不能作为 AI 权威数据源。

原则：

- 不上传完整数据库。
- 不上传无关历史。
- 不把 SQL row 直接交给 LLM。
- 标明时间范围。
- 标明数据来源。
- 标明缺失字段。
- 标明不确定性。
- 标明 Local 已计算结果。
- 标明 AI 不得覆盖的字段。
- 控制 token。

## 15.2 MealDecisionContext

包含：

```text
cloud_profile:
  diet_goal_phase
  diet_calculation_mode
  diet_plan_strategy
  current weight
  training_frequency_per_week

selected_day_summary:
  calories_in
  exercise_calories
  target_intake
  remaining_calories
  protein target / intake / remaining
  carbs target / intake / remaining
  fat target / intake / remaining
  mode primary signal

food_context:
  meals eaten today
  food count
  uncertain estimates if known

workout_context:
  workout done today
  exercise calories

constraints:
  no medical advice
  do not recalculate target
  do not write without confirmation
```

## 15.3 WeeklyReviewContext

包含：

```text
period_days: 7 or 14
food_log_coverage
average calories
average protein / carbs / fat
high variance meals
late-day or dinner pattern if derivable
workout active days
weight trend availability
missing data flags
current strategy
current mode
under_18 flag
```

输出必须区分：

- 数据足够；
- 数据不足；
- 只能判断记录行为；
- 不能判断真实生理变化。

## 15.4 DocumentAnswerContext

包含：

```text
query_language
target_doc_language
retrieved_doc
retrieved_section
section_excerpt
source_path
source_heading
confidence
```

回答必须标注来源 section，不得假装 App 有未实现功能。

---

# 16. Workflow A：Photo Food Logging

## 16.1 目标

把食物照片或描述转成可编辑饮食草稿，降低复杂饮食录入成本。

## 16.2 入口

- AI Chat；
- Add Food -> AI Food Analysis。

Add Food 是唯一允许保留的业务页 AI 快捷入口，因为它直接对应饮食记录草稿。

## 16.3 用户流程

```text
用户输入食物描述 / 可选上传图片
        ↓
AI 判断图片类型
        ↓
如果不是食物：提示无法记录
如果不确定：追问
        ↓
AI 估算 meal + items
        ↓
返回 FoodEstimate schema
        ↓
Chat 内展示 Food Draft 预览
        ↓
用户轻量编辑 / 打开 full editor / 放弃
        ↓
用户确认保存
        ↓
写入 food_records / food_items
```

## 16.4 追问场景

必须追问：

- 看不出是什么肉；
- 看不出是否已吃完；
- 分量明显不确定；
- 图片是外卖菜单而不是已吃食物；
- 图片是冰箱食材而不是已吃食物；
- 用户只说“帮我看看”但没说明要记录还是估算。

示例：

```text
我不确定这块肉是牛肉、猪肉还是鸡肉。你能告诉我大概是什么肉吗？
```

```text
这张图更像外卖菜单，不像已经吃过的一餐。你是想让我帮你选择，还是要记录已经吃了的食物？
```

## 16.5 FoodEstimate 输出

```json
{
  "meal_name": "鸡腿饭",
  "date": "2026-06-17",
  "total_weight_g": 520,
  "calories_kcal": 720,
  "protein_g": 45,
  "carbs_g": 88,
  "fat_g": 20,
  "confidence": 0.72,
  "estimation_notes": "鸡腿按去皮估算，米饭按半份估算，烹饪油不确定。",
  "uncertain_fields": ["meat_type", "cooking_oil"],
  "items": [
    {
      "name": "去皮鸡腿",
      "estimated_weight_g": 180,
      "calories_kcal": 300,
      "protein_g": 38,
      "carbs_g": 0,
      "fat_g": 14,
      "notes": "肉类由用户确认，油量仍不确定。"
    }
  ]
}
```

## 16.6 Chat 内 Food Draft

Food Draft 预览应尽量复用现有记录页面字段风格。

展示：

- meal name；
- date；
- weight；
- kcal；
- P / C / F；
- item rows；
- confidence；
- estimation notes；
- uncertain fields；
- user note；
- source。

操作：

- 轻量编辑；
- 保存；
- 放弃；
- 重新估算；
- 打开完整编辑页面。

保存前不写正式 `food_records`。

---

# 17. Workflow B：Meal Decision

## 17.1 目标

帮助用户基于当前 Profile 和当天记录做下一餐选择。

典型问题：

```text
我今天还能吃什么？
晚饭怎么吃？
这个外卖能点吗？
冰箱里这些怎么搭配？
蛋白质还差多少？
```

## 17.2 入口

只从 AI Chat 触发。

Home / Food Log / Profile 不另设入口。

## 17.3 用户流程

```text
用户输入问题 / 上传外卖截图 / 上传冰箱图
        ↓
Router 判断 meal_decision
        ↓
Context Builder 获取 cloud profile + selected day summary
        ↓
必要时追问剩几餐、偏好、是否训练日
        ↓
AI 生成 2-3 个建议
        ↓
Chat 内展示 Meal Recommendation Card
        ↓
用户选择方案
        ↓
可转成 Food Draft
        ↓
用户确认保存
```

## 17.4 关键规则

- 外卖截图不是已吃食物。
- 冰箱图不是已吃食物。
- 推荐不等于记录。
- AI 不重新计算 Local 目标。
- `energy_ratio` 下优先解释 kcal / remaining kcal。
- `gram_per_kg` 下优先解释 protein / carbs / fat grams。
- 数据不足时说清楚缺什么。
- 未知食材或份量时追问。

## 17.5 输出示例

```json
{
  "summary": "今天蛋白质还差较多，脂肪剩余不多。晚饭更适合选择瘦肉或鱼虾，主食正常，少油。",
  "recommendations": [
    {
      "title": "牛肉饭少酱版",
      "why_suitable": "能补充蛋白质和碳水，脂肪相对可控。",
      "estimated_calories_kcal": 580,
      "estimated_protein_g": 38,
      "estimated_carbs_g": 72,
      "estimated_fat_g": 15,
      "suggested_modification": "备注少油少酱，米饭正常或略减。",
      "risk_note": "实际用油量不确定。"
    }
  ],
  "not_recommended": [
    {
      "title": "炸鸡拌饭",
      "reason": "脂肪不确定性高，容易超过今日剩余脂肪。"
    }
  ],
  "confirmation_questions": [
    "你晚饭还剩几餐要吃？",
    "你希望更饱一点还是更贴近目标？"
  ]
}
```

---

# 18. Workflow C：Weekly Review

## 18.1 目标

基于 7 / 14 天记录，生成可执行复盘。

不是：

- 自动目标调整；
- 自动策略调整；
- 医疗判断；
- 体重变化诊断；
- AI Coach 长期计划。

## 18.2 用户流程

```text
用户在 AI Chat 请求复盘
        ↓
默认 7 天，用户可指定 14 天
        ↓
Context Builder 获取 food / workout / weight availability / profile / strategy
        ↓
AI 判断数据是否足够
        ↓
生成 Weekly Review Card
        ↓
用户可继续追问 / 复制 / 保存
```

## 18.3 与策略的边界

Weekly Review 可以：

- 说明当前 `diet_plan_strategy`；
- 解释 carb cycling 对当前目标的影响；
- 提醒 carb cycling pattern 可能和训练日不匹配；
- 提醒 carb taper review 需要足够体重和饮食记录；
- 建议用户去 Profile 查看策略设置；
- 总结行为模式。

Weekly Review 不能：

- 自动修改 `diet_plan_strategy`；
- 自动启用 / 关闭 carb cycling；
- 自动修改 carb cycling pattern；
- 自动修改 carb cycling multipliers；
- 自动应用 carb taper；
- 自动修改 `carb_taper_current_delta_g`；
- 替代本地 carb taper review；
- 自动修改 `training_frequency_per_week`；
- 自动修改目标 kcal 或 macro ratios。

## 18.4 输出结构

```json
{
  "period_days": 7,
  "data_quality": {
    "food_log_coverage": 0.86,
    "workout_days": 3,
    "weight_trend_available": false,
    "missing_data": ["weight_trend"]
  },
  "summary": "这周记录覆盖率较好，但没有足够体重趋势，因此不能判断真实体重变化。",
  "main_issue": "晚餐脂肪波动较大",
  "secondary_issue": "训练日碳水略低",
  "action_plan": [
    {
      "title": "晚餐先控制油脂不确定性",
      "detail": "下周外卖优先选择少油少酱的饭类或粉面类，蛋白质选瘦肉、鸡蛋或鱼虾。"
    }
  ],
  "strategy_note": "当前策略可以继续观察，不建议由 AI 自动调整 carb cycling 或 carb taper。",
  "not_doing": [
    "不建议本周直接大幅降低碳水",
    "不自动修改目标或策略"
  ]
}
```

---

# 19. Workflow D：App Logic Q&A

## 19.1 目标

回答 App 规则、算法和边界问题。

示例：

```text
BMR 是怎么算的？
TDEE 是怎么算的？
为什么 g/kg 没有剩余 kcal？
为什么有氧要减去 1 MET？
carb cycling 是什么？
carb taper 为什么不能自动应用？
为什么数据不足时不能下结论？
```

## 19.2 检索规则

- 中文问题检索中文文档。
- 英文问题检索英文文档。
- 返回 source section。
- 不回答成医学建议。
- 不声称未实现功能已经存在。

## 19.3 输出结构

```json
{
  "answer": "在 gram_per_kg 模式下，FitLog 把蛋白质、碳水和脂肪克数作为主目标，kcal 只是这些宏量的能量等价，所以不会像 energy_ratio 那样把剩余 kcal 作为主计数器。",
  "related_topics": ["gram_per_kg", "macro_energy_equivalent_kcal"],
  "source_sections": [
    {
      "doc": "Algorithm.md",
      "section": "gram_per_kg"
    }
  ],
  "limitations": "这解释的是 App 计算规则，不是个性化营养处方。"
}
```

---

# 20. Chat 内结果卡片

## 20.1 Food Draft Preview

用途：

- 展示 AI 估算饮食草稿；
- 支持轻量编辑；
- 允许跳 full editor；
- 用户确认后保存。

按钮：

- Save；
- Edit；
- Open full editor；
- Discard；
- Regenerate。

## 20.2 Meal Recommendation Card

用途：

- 展示建议方案；
- 解释为什么适合；
- 标出风险和不推荐选项；
- 用户选择后可转 Food Draft。

按钮：

- Choose this；
- Turn into food draft；
- Ask follow-up；
- Discard。

## 20.3 Weekly Review Card

用途：

- 展示周期、数据质量、主要问题、建议和不做事项。

按钮：

- Save review；
- Copy；
- Ask follow-up；
- Close。

## 20.4 App Logic Answer Card

用途：

- 回答规则；
- 标注来源文档 section；
- 支持继续追问。

按钮：

- Continue；
- Copy；
- View source section if available。

---

# 21. 失败与追问

## 21.1 设计原则

失败态优先转成：

- 追问；
- 可重试；
- 可手动修正；
- 清楚说明缺失信息。

不应：

- 假装知道；
- 编造数据；
- 自动猜测关键字段；
- 写入不完整记录；
- 让用户误以为已经保存。

## 21.2 场景矩阵

| 场景 | UI 行为 |
|---|---|
| 未登录 | AI 页面灰色，提示登录 |
| 未订阅 | AI 页面灰色或订阅引导，不能发送 |
| 离线 | AI 页面灰色，可编辑输入但不能发送 |
| 图片看不清 | 追问或要求重拍 |
| 不知道肉类 | 追问肉类 |
| 分量不确定 | 追问份量 |
| 图片是菜单 | 询问是要选择还是记录 |
| 数据不足 | 说明缺哪些数据 |
| schema fail | 不写库，允许重试 |
| 网络失败 | 保留输入，允许重试 |
| 保存失败 | 草稿保留，提示重试 |

---

# 22. 安全边界

## 22.1 AI 不得自动修改字段

AI 不得自动修改：

```text
diet_goal_phase
diet_calculation_mode
diet_plan_strategy
daily_energy_goal_kcal
protein_ratio_percent
carbs_ratio_percent
fat_ratio_percent
training_frequency_per_week
lifestyle_factor
carb_cycle_pattern_json
carb_cycle_high_multiplier
carb_cycle_medium_multiplier
carb_cycle_low_multiplier
carb_taper_current_delta_g
```

## 22.2 医疗边界

AI 不得输出：

- 疾病诊断；
- 治疗建议；
- 快速瘦身承诺；
- 极端节食方案；
- 过度训练建议；
- 羞辱体重或外貌的话术；
- 儿童青少年治疗建议。

必须保留：

- 营养估算仅供个人记录参考；
- 食物估算存在误差；
- 运动消耗是估算；
- 特殊健康情况咨询专业人士。

## 22.3 未成年人边界

如果 `age < 18`：

AI 不允许：

- 推荐减脂赤字；
- 推荐 carb cycling；
- 推荐 carb tapering；
- 推荐激进饮食；
- 承诺减重。

AI 允许：

- 普通饮食记录；
- 食物估算；
- 均衡饮食提醒；
- 温和保守建议；
- 建议咨询专业人士。

---

# 23. 隐私与数据保留

## 23.1 AI 页面轻量提示

AI 页面首次使用应显示轻量隐私提示。

中文建议：

```text
AI 请求可能会将你的文字、图片、Profile 字段和必要的云端记录摘要发送到 FitLog AI 网关处理。
```

英文建议：

```text
AI requests may send your message, selected images, profile fields, and necessary cloud record summaries to FitLog AI Gateway.
```

要求：

- 不大面积占屏；
- 可关闭；
- 设置页保留完整说明；
- 图片上传处提示原图默认不长期保存。

## 23.2 云端长期保存

```text
account
subscription
cloud_profile
ai_chat_sessions
ai_chat_messages
ai_final_answers
request metadata
debug summary
```

## 23.3 云端短期或可选保存

```text
raw model request
raw model response
context JSON
failed payload
```

这些应有保留期，不默认无限期保存。

## 23.4 默认不保存

```text
original image long-term
full local SQLite as source of truth
full raw food history in AI context
full raw workout history in AI context
full raw body metric history in AI context
user embedding storage
semantic memory
```

---

# 24. 数据库与存储规划

## 24.1 本地 SQLite 角色

Phase 3 后，本地 SQLite 不再是业务记录基础，而是 partial cache、草稿和运行期加速层。

可规划扩展：

- 记录 source 枚举增加：
  - `ai_photo`
  - `ai_chat`
  - `ai_meal_decision`

说明：

- `manual`：手动录入；
- `ai_paste`：外部 AI JSON 粘贴；
- `ai_photo`：App 内图片识别后保存；
- `ai_chat`：AI Chat 草稿保存；
- `ai_meal_decision`：Meal Decision 推荐方案保存。

具体 migration SQL 不在本文展开。

## 24.2 云端表规划

建议云端表：

```text
users
subscriptions
cloud_profiles
body_metric_logs
food_records
food_items
workout_records
workout_sessions
workout_sets
daily_summaries
ai_chat_sessions
ai_chat_messages
ai_request_logs
ai_debug_summaries
prompt_versions
document_sections
document_index
```

## 24.3 云端 Profile

`cloud_profiles` 是账号级主版本。

字段参考见第 8.4 节。

## 24.4 AI Chat

`ai_chat_sessions`：

```text
id
user_id
title
created_at
updated_at
deleted_at
```

`ai_chat_messages`：

```text
id
session_id
user_id
role
content_text
message_type
workflow_type
final_answer_json
created_at
deleted_at
```

不用于 semantic memory。

## 24.5 AI Request Logs

```text
request_id
user_id
session_id
workflow_type
model
prompt_version
schema_version
profile_version
status
error_code
latency_ms
token_estimate
image_count
created_at
```

## 24.6 Debug Summary

```text
request_id
intent
intent_confidence
called_tools_json
retrieved_dimensions_json
missing_dimensions_json
safety_flags_json
schema_validation_status
user_final_action
```

---

# 25. Document RAG 文档索引

## 25.1 文档源

```text
README.md
docs/en/Product.md
docs/en/AppGuide.md
docs/en/Methodology.md
docs/en/Algorithm.md
docs/en/Database.md
docs/en/AgentDesign.md
docs/en/References.md
docs/zh/Product.md
docs/zh/AppGuide.md
docs/zh/Methodology.md
docs/zh/Algorithm.md
docs/zh/Database.md
docs/zh/AgentDesign.md
docs/zh/References.md
```

## 25.2 Section metadata

每个 section 应有：

```text
doc_path
language
heading
heading_level
section_id
content
updated_at
tags
```

## 25.3 回答引用

App Logic Answer 必须能返回：

```text
doc
section
language
confidence
```

不要求用户看到复杂 citation UI，但内部结构要保留。

---

# 26. Debug 与质量控制

## 26.1 Router Debug

记录：

```text
user_query
attachment_type
predicted_intent
intent_confidence
alternative_intents
needs_clarification
final_workflow
user_correction
```

重点检查：

- 外卖截图是否误判为已吃食物；
- 只发图片是否过早记录；
- “这个怎么样”是否需要追问；
- 周复盘是否误入普通问答。

## 26.2 Context Debug

记录：

```text
called_context_builders
date_range
records_found
missing_fields
coverage
profile_version
context_builder_version
```

## 26.3 Vision Debug

记录：

```text
image_type
recognized_foods
uncertain_fields
confidence
user_modified_fields
before_after_diff
```

## 26.4 Safety Debug

记录：

```text
under_18_flag
medical_risk_flag
unsupported_action_flag
write_confirmation_required
write_confirmed
```

---

# 27. 测试与验收

## 27.1 UI 验收

- AI tab 位于底部导航正中间。
- 底部导航只显示浮动白色 pill，外层没有整行背景。
- AI 页面彩色背景铺满全屏。
- 未登录 / 离线 / 未订阅时背景变灰。
- 输入框未发送内容在当前运行期内切换页面、离线或订阅状态变化时不丢失；退出登录或切换账号时清空。
- Chat history 侧栏可打开、关闭。
- 消息列表变长时背景仍存在但不影响阅读。

## 27.2 Profile 验收

- 未登录无正式 Profile。
- 登录后从云端读取 Profile。
- 离线时 Profile 禁止保存。
- 保存 Profile 必须写云端成功后更新本地缓存。
- 删除账号后云端 Profile 和本地缓存被清理。

## 27.3 Workflow 验收

Photo Food Logging：

- 能上传图片。
- 不确定食物时追问。
- 能生成 Food Draft。
- Chat 内可轻量编辑。
- 可跳 full editor。
- 保存前不写正式记录。
- 保存后刷新 Food Log / Home。

Meal Decision：

- 能读取当天 summary。
- 能区分 `energy_ratio` 和 `gram_per_kg`。
- 不把推荐直接写成记录。
- 选择方案后才生成草稿。

Weekly Review：

- 支持 7 / 14 天。
- 能识别数据不足。
- 不自动改 strategy。
- 不自动应用 carb taper。
- 不自动改 carb cycling。

App Logic Q&A：

- 中文问题检索中文文档。
- 英文问题检索英文文档。
- 回答带 source section。
- 不声称未实现功能已实现。

## 27.4 Safety 验收

- AI 不能自动修改目标。
- AI 不能自动修改 Profile。
- AI 不能自动删除记录。
- AI 不能给医疗诊断。
- 未成年人不能收到成人式减脂建议。
- schema fail 不写库。

---

# 28. 风险与应对

| 风险 | 表现 | 应对 |
|---|---|---|
| AI 页视觉过重 | 动效影响阅读 | 降低饱和度、reduce motion、消息区加底 |
| 导航背景割裂 | AI 页彩色与绿色底冲突 | 统一浮动 pill，去掉整行背景 |
| Router 误判 | 菜单图被当记录 | 图片类型分类 + 追问 |
| Profile 冲突 | 本地和云端不一致 | 云端主版本，本地缓存，离线禁保存 |
| V1 范围膨胀 | 让模型读取无限原始历史或把 cache 当权威 | 云端 records 是权威，AI 只读最小 summary |
| AI 幻觉 | 假装有缺失数据 | Context Builder 标 missing fields |
| 用户过度信任 | 把估算当精确值 | confidence / notes / 追问 |
| 隐私疑虑 | 不清楚上传什么 | AI 首次轻量提示 + 设置页说明 |
| 策略越界 | Weekly Review 自动调参 | 明确只建议、不修改 |
| 成本失控 | 订阅制下请求过多 | 后端成本日志、模型路由、风控 |

---

# 29. 最终锁定范围

```text
V1 =
  Cloud account
+ Subscription
+ Cloud Profile
+ Server-managed model API key
+ AI Gateway
+ Center AI tab
+ Immersive AI Chat UI
+ Full-screen animated AI background
+ Grayscale disabled state
+ Cloud chat history sidebar
+ Photo Food Logging
+ Meal Decision
+ Weekly Review
+ App Logic Q&A
+ Structured RAG over cloud summaries
+ Document RAG over app docs
+ Chat inline draft preview
+ User confirmation before writes
+ Request / response / debug logging
+ Safety boundaries
```

V1 不再继续加大功能。后续新增能力必须明确属于 V1.1 / V2，并单独设计数据、隐私、UI 和测试边界。
