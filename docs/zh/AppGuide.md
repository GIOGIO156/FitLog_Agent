# App Guide

## 目标

本文说明每个 App 区域做什么，以及应该去哪个设计文件读细节。它是导航型文档。算法公式属于 `Algorithm.md`；存储细节属于 `Database.md`；AI 边界属于 `AgentDesign.md`。

FitLog_Agent V1 保留现有 FitLog Local 的 App 区域，并新增一个主要 AI 区域。

## App 导航

推荐底部导航：

```text
Home | Food | AI | Workout | Profile
```

AI tab 位于正中间，因为它是 Agent 主入口。底部导航组件应是浮动白色 pill，不应在 pill 外绘制整行背景色。

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
- 中心状态文案，使用用户昵称
- 底部输入框
- 输入区附近的紧凑模型选择器，可选 ChatGPT 和千问
- 左侧可折叠 chat history
- 右上角账号/订阅图标
- 小型隐私/状态提示
- 没有 quick chips

当前 Phase 1 实现：

- AI tab 已经位于底部导航正中间。
- 页面默认是未登录不可用 shell。
- 输入框可以输入文字，但发送按钮禁用。
- ChatGPT/千问选择只是本地 UI 占位，不会调用 provider。
- 历史入口和账号/订阅入口是占位。
- 尚未实现 AI Gateway、auth session、订阅校验、Cloud Profile、云端 chat history、RAG 或 LLM 调用。

可用状态：

- 已登录、联网、已订阅：允许发送
- 未登录：灰色不可用状态
- 离线：灰色不可用状态
- 未订阅：不可用状态，并解释账号/订阅情况

不可用状态规则：

- 用户可以继续编辑未完成 prompt。
- 只有登录、联网和订阅条件全部满足时，才允许发送。

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
- 身体资料
- 饮食阶段
- 计算模式
- 策略
- 训练频率
- self-check 设置
- 导出
- 清空本地数据

Agent V1 profile 模型：

- 未登录前没有正式 Profile。
- 登录后 Cloud Profile 是权威版本。
- 设备可以缓存 Profile 用于显示。
- 离线时禁止保存 Profile。
- AI 默认使用 Cloud Profile 作为上下文。
- 删除账号时删除 Cloud Profile。

Profile 仍是正式饮食设置变更的位置。AI 可以解释或建议，但设置变更应通过 Profile UI 完成。

阅读更多：

- Profile 权威来源：`AgentDesign.md`
- Profile 字段与云端/本地边界：`Database.md`
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
- 已实现 Agent shell 行为：居中的 AI tab、不可用 AI 页面、可编辑输入框、模型选择器占位，以及五 tab 浮动底部导航。
- 计划中的 Agent V1 行为：目标设计，不一定已经上线。

在代码实现前，不要把 AI Gateway、账号登录、订阅、Cloud Profile、chat history 或 RAG 写成已实现。
