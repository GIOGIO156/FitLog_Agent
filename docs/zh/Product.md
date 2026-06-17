# 产品设计

## 目标

FitLog_Agent V1 是一个基于 FitLog Local 升级而来的云端 AI 辅助饮食与训练记录 App。

它的价值不是“让 AI 取代记录”。它的价值是保留确定性的饮食、训练、目标、策略和导出工作流，同时通过订阅制 AI Chat 帮助用户估算复杂饮食、决定下一餐、复盘近期行为，并理解 App 规则。

产品承诺：

```text
用确定性规则进行本地记录。
用户需要帮助时主动调用云端 AI。
只有用户确认后才写入正式数据。
```

## 产品原则

- 除非 Agent V1 明确要求改变，否则保留 Local 行为。
- V1 默认保持 food/workout/weight 记录本地存储。
- 云端服务用于账号、订阅、Cloud Profile、AI Gateway、chat history 和 AI 审计需求。
- 登录后 Cloud Profile 是跟账号绑定的用户信息。
- 不要求用户填写自己的模型 API key。
- `energy_ratio` 和 `gram_per_kg` 必须保持分离。
- `diet_goal_phase` 是 cutting/bulking 的来源。
- `diet_plan_strategy` 是确定性的策略设置，不是 AI 动作。
- AI 页面是 Agent 主入口。
- 不做静默写入：AI 生成草稿、解释、追问；用户确认后才保存。

## 产品模块

| 模块 | V1 角色 | 已实现基线 | V1 计划新增 |
| --- | --- | --- | --- |
| Home | 选中日期仪表盘。 | 本地日汇总、饮食上下文、宏量/kcal 展示、紧凑饮食/训练卡。 | 可出现低打扰 AI 入口提示，但应路由到 AI 页面。 |
| Food Log | 正式饮食记录管理。 | 手动饮食录入、外部 AI JSON 粘贴、复制到日期、编辑、删除。 | 接收 AI Chat 或 Add Food 拍照识别确认后的 Food Draft。 |
| Add Food | 饮食创建流程。 | 手动录入、prompt 复制、JSON 粘贴、Photo AI 占位。 | 拍照识别快捷入口可调用 AI Gateway 并生成 Food Draft。 |
| AI | Agent 主入口。 | Phase 1 已实现居中 tab、不可用状态 AI shell、浅色流动背景、可编辑输入框、模型选择器占位、历史入口占位和账号/订阅入口占位；当前不能发送。 | 真实 auth gating、AI Gateway 调用、云端 chat history、饮食草稿、用餐决策、周复盘和 App 规则问答。 |
| Workout | 正式训练记录管理。 | 本地训练记录、自定义动作、训练草稿编辑器、热量启发式计算。 | V1 AI 可解释或复盘训练上下文，但不静默修改训练记录。 |
| Profile | 账号/Profile/饮食设置。 | 本地 Profile 和确定性饮食设置。 | 登录后的 Cloud Profile、订阅状态入口、离线禁止保存。 |
| Export | 用户主动导出数据。 | XLSX 和 CSV ZIP 导出。 | V1 不用云端备份替代本地导出。 |

## AI Chat 体验

AI 页面是简单的全屏 Chat，不是快捷按钮工作台。

导航结构：

```text
Home | Food | AI | Workout | Profile
```

必备 UI：

- AI tab 位于底部导航正中间。
- 底部导航是浮动白色 pill；导航组件本身不在 pill 外绘制整行底色。
- AI 页启用 `extendBody`，pill 两侧透出 AI 背景；普通页暂不启用，继续露出既有浅色页面背景，避免内容被导航栏遮住。
- 全屏 AI 动效背景。
- 中心文案使用用户昵称。
- 底部输入框。
- 输入区附近提供紧凑模型选择器，可选 `ChatGPT` 和 `千问`。
- 左侧可折叠 chat history。
- 右上角账号/订阅状态入口。
- 没有 quick chips。
- 小型隐私/状态提示。

当前 Phase 1 行为：

- Root navigation 是 `Home | Food | AI | Workout | Profile`。
- AI shell 默认显示未登录不可用状态。
- 输入框可编辑，但发送按钮禁用。
- 模型选择器显示 `ChatGPT` 和 `千问`，仅作为 UI 占位。
- 历史入口和账号/订阅入口是占位。
- AI 页面不触发 auth、网络、AI Gateway、LLM、RAG、chat-history 持久化或正式数据写入。

可用状态：

| 状态 | UI 行为 |
| --- | --- |
| 已登录、联网、已订阅 | 彩色 AI 背景；允许发送。 |
| 处理中 | 背景稍微更活跃；输入区显示处理状态。 |
| 需要补充信息 | 背景放慢；突出缺失信息问题或草稿字段。 |
| 未登录 | 灰色不可用 AI 页面；禁止发送；仍可输入但不能发送。 |
| 离线 | 灰色不可用 AI 页面；禁止发送；Profile 修改也禁用。 |
| 未订阅 | 灰色或锁定 AI 页面；禁止发送；右上角状态解释订阅情况。 |

## AI Workflows

### 饮食估算

用户可以描述一餐或上传图片。AI 生成 Food Draft，不直接写入正式记录。

草稿应包含：

- 餐名
- 候选食物项
- 分量或 serving 估计
- kcal/protein/carbs/fat
- 置信度或不确定说明
- 必要时的追问
- AI draft 来源标记

如果 AI 无法识别食材或分量，应先追问。例如肉类不明确时，应问用户是什么肉，而不是直接猜。

Food Draft 在 Chat 内以紧凑预览卡出现，视觉与饮食记录页 UI 保持一致。它支持轻量编辑和操作：

- 保存
- 丢弃
- 打开完整编辑页

只有确认保存后才创建正式记录。

### 用餐决策

用户可以问下一餐吃什么、某个外卖是否适合今天、为什么今天很难控制等问题。

回答应使用：

- Cloud Profile
- 选中日期饮食摘要
- 选中日期训练摘要
- 当前饮食阶段
- 当前计算模式
- 当前策略
- 剩余目标或宏量目标

AI 应用实用语言解释理由。它不能重新计算用户的正式计划，也不能静默修改目标。

### 周复盘

用户可以请求一周或近期复盘。

复盘默认使用近期摘要，而不是上传完整原始历史。它应覆盖：

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

未登录前没有正式 Profile。登录后，Profile 像账号绑定的用户信息一样存在。

V1 Profile 规则：

- Cloud Profile 是权威版本。
- 本地设备可以缓存用于显示。
- 离线时禁止保存 Profile。
- AI 默认使用 Cloud Profile。
- 请求可以携带 `profile_version`。
- 删除账号时删除 Cloud Profile。

Profile 应包含现有饮食和个性化逻辑需要的信息，例如：

- 昵称或展示名
- 年龄
- 身高
- 体重
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

训练、饮食、体重记录 V1 默认仍在本地。只有用户请求需要时，才汇总后供 AI 使用。

## 数据与隐私模型

V1 云端数据：

- 账号
- 订阅
- Cloud Profile
- AI request metadata
- AI sessions
- AI chat messages
- AI 最终回答
- 紧凑 debug/action summaries

V1 默认本地数据：

- food records
- food items
- workout sessions
- workout sets
- weight logs
- local workout drafts
- exports

AI 请求只上传最小必要上下文。用户业务数据上下文应优先使用摘要，而不是原始行。

## 用户确认模型

AI 输出类别：

| 输出 | 是否正式写入？ | 确认规则 |
| --- | --- | --- |
| 解释 | 否 | 无保存动作。 |
| 用餐建议 | 否 | 用户自行决定。 |
| Food Draft | 暂不 | 保存需要确认。 |
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

## Agent Phase 1 已实现范围

当前 Agent shell 已实现：

- Android 安装身份与 FitLog Local 分离。
- App label 与 Flutter app title 为 `FitLog Agent`。
- 五个底部 tab：`Home | Food | AI | Workout | Profile`。
- `RootTabIndex` 常量，确保 Home 跳 Food 仍是 index `1`，跳 Workout 是 index `3`。
- 抽出的浮动白色底部导航组件 `FitLogBottomNavBar`。
- `lib/features/ai/ai_page.dart` 中的全屏 AI shell。
- 不可用 AI 状态：prompt 可编辑，发送按钮禁用。
- ChatGPT/千问模型选择器占位。
- 历史入口和账号/订阅入口占位。
- AI shell widget test 和 root navigation test。

## V1 不做

- 默认完整云同步 food/workout/weight 历史
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
