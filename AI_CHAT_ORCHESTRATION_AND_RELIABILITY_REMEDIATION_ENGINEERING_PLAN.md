# FitLog AI Chat Orchestration And Reliability Remediation Engineering Plan

## 0. 状态、定位与文件职责

状态：`IMPLEMENTED / FINAL RELEASE GATES OPEN`。代码、迁移、云端部署、自动化 Gate、受控 soak、回滚演练和 legacy 退场已经落地；真实设备 journey 与最新稳定文档 corpus 的外部 embedding/激活仍未完成，因此本计划尚不能标记 `COMPLETE`。

制定日期：2026-07-18。

最近基线复核：2026-07-19，`d7b4f22`。该提交完成了训练草稿有序持久化/进程重建恢复、Food 图片 picker 单一 owner/single-flight 恢复、本地数据清空边界和本地 Document RAG corpus 再生成；这些机制是本计划必须复用的既有产品基础，不是可以被 Chat 整改替换的临时实现。

本计划是在当前 Phase 5 `rag_foundation_v1` 之上的 Chat 编排与可靠性整改，不回退到 Phase 4，也不重做已经落地的 Document RAG、Structured RAG、Food Capability、Exercise Binding、Provider Adapter 或 Output Validator。Phase 4 只作为已确认用户行为和回归知识的历史来源。

本文件取代尚未进入 Git 的 `AI_CHAT_CLARIFICATION_AND_EVIDENCE_REMEDIATION_ENGINEERING_PLAN.md`。旧文件按单个截图命名，容易再次把系统性问题拆成局部补丁；其中已核实的 evidence、write guard、clarification 和多模态结论已完整并入本计划，因此不再保留第二个并行施工入口。

本计划负责：风险、顺序、Gate、上线、回滚和完成证据。它不取代稳定设计文档。落地后的产品事实必须同步到对应的中英文 owning docs。

实施以 `d7b4f22` 为审计基线完成。Flutter、Edge、公开 additive contract、云端 clarification schema/RPC、评测、稳定文档与部署均已修改；当前真实状态与未关闭 Gate 见第 9 节 landing summary。

### 0.1 本计划最终目的

本计划的目的不是修好两个截图中的循环，也不是单纯提高 intent 分类命中率。目标是在不降级 Phase 5 Document RAG、Structured RAG、keyword/term normalization、vector retrieval、hybrid fusion、reranker、coverage/retry、Food/Workout validators 和现有记录机制的前提下，得到一个符合 FitLog 产品需求的 V1 Chat：它能理解自然中英文本和当前图片，选择正确能力，使用受权威约束的 Context，持续推进有状态多轮任务，生成可编辑且受校验的草稿，在失败时给出真实终态，并始终把正式写入留给用户确认。

同等重要的工程目标，是把“重大架构替换不得静默丢弃旧能力”从文字承诺变成 behavior parity、真实 production-path eval、shadow diff、发布 Gate、soak 和可验证 rollback。任何局部修复如果破坏这个终态，即使解决了当前截图，也不属于本计划的完成。

## 1. 执行摘要

两次故障不是两个独立 bug，而是同一条 Chat 生产链在不同位置失去控制：

| 核心问题 | 两次故障中的表现 | 应如何修改 | 为什么有效 |
| --- | --- | --- | --- |
| 决策职责分散 | `workflow_router`、`task_planner`、legacy `expected_output` 和 prompt 各自判断 intent/output；Phase 5 active path 绕过旧 resolver | 建立唯一的 `chat_decision.v2`，一次决定 capability、allowed output、Context、clarification 和附件策略 | 一个用户意图只被一个版本化合同解释，旧能力迁移可以逐项比较，不再出现“旧测试通过但生产没走它” |
| 用枚举规则承担开放语义 | “排骨藕汤，喝了三碗”不在少量食物词+`g/ml` 规则内，带图即在模型前返回歧义 | 确定性代码只负责权限、fixed entry、显式选项和高置信结构；开放食物/训练/问题语义交给有界 planner，必要时看当前图片 | 不再靠无穷扩充词表；清晰请求能到达模型，模型能力真正参与 |
| clarification 只有文案、没有状态 | 用户回复“回答问题”或“食物草稿”被当作新问题，再次生成同一句 | 增加可持久化、可验证、可幂等消费的 clarification 状态机和 typed option reply | 回复先确定性消费上一轮选项，不再重新猜 intent；每个澄清都有终止条件 |
| 临时图片与多轮流程冲突 | 首轮图片未被消费就澄清；第二轮没有像素可用 | 清晰图片同轮消费；确需跨轮时，客户端把 runtime attachment 绑定 clarification 并显式重发；重启后要求重新选择图片 | 保持“不长期存图片”的隐私边界，同时使多轮任务真实可完成 |
| 安全 guard 只看单词 | `is saved/persisted in` 被当成“AI 已替用户写入”，数据库答案被固定拒绝文案覆盖 | `write_claim_guard.v2` 判断“执行主体+完成动作+用户数据对象”，区分被动存储说明、否定能力和真实写入声明 | 保持写入 fail-closed，但不再把只读架构说明误杀 |
| RAG 原文直接当 UI 标签 | Database 技术标题中的 Markdown 反引号显示在 evidence chip | 原始 heading 保持不变；Flutter 单独生成 presentation label，只解析成对 inline-code delimiter | 不破坏 corpus/hash/精确标识符，又让 UI 符合人类阅读习惯 |
| 失败分类不诚实 | 用户歧义、planner timeout、invalid JSON、provider failure 都显示同一三选一 | 分离 `user_clarification`、`missing_business_fields`、`planner_unavailable`、`provider_failure`、`validation_failure`、`attachment_unavailable` | 用户知道该补充信息还是重试；日志能定位真实故障，不再形成伪循环 |
| 验收假绿 | fixture runner 只计数 JSON；canary 用 fixed workflow 绕过 AI 页面 auto，并把任意 clarification 算成功 | 先建设会执行 production decision path 的 journey runner；hard oracle 必须断言任务完成和状态转移 | 报告证明真实行为而非文件存在、HTTP 200 或非空文本 |
| 架构替换没有行为等价门 | Phase 5 新入口替换旧入口时，旧 explicit Food Draft 行为没有进入 active contract | 建立行为兼容清单、shadow diff 和“旧能力逐项去向”Gate；重大替换前先提交计划与 failing tests | 后续重构可以改变实现，但不能静默删除已经确认的产品能力 |

结论：主要问题不是 Qwen 能力不足，也不是“Edge Function 里有确定性规则”本身错误。首个食物图片请求在 provider 调用前已经退出；数据库问题则是在 provider 正确回答后被过宽 guard 覆盖。确定性代码应保留在权限、schema、安全、确认和数值边界，不能代替开放世界语义理解。

## 2. 产品需求冻结

实施期间不得缩减以下已确认终态：

1. AI 页面是 Agent 主入口，接受自然中英文本和最多三张当前请求图片；用户不需要学习关键词模板。
2. Chat 能回答普通问题、基于 Document RAG 回答 App Logic、生成可编辑 Food/Workout Draft、进行授权后的 meal decision/review，并诚实报告证据不足。
3. Document RAG 只提供稳定设计证据；Structured RAG 只提供授权、最小化、类型化的用户摘要；same-chat 只负责连续性，不能伪装成权威证据。
4. AI 不能静默写入、删除或修改正式 food/workout/profile/goal/strategy；只有用户在正常 UI 审核确认后才写入。
5. Food/Workout Draft 必须通过既有严格/domain validator；不确定值应留空、标注或澄清，不能伪造精度。
6. clarification 必须有界、可选择、可恢复、可终止；Workout 缺字段最多追问一轮，随后 best-effort draft 或稳定失败。
7. OpenAI/Qwen adapter 可替换，但 capability、Context、output、安全、确认和状态机不能随 provider 漂移。
8. 不增加用户数据 vector DB、长期图片存储、semantic memory、GraphRAG、开放自主 Agent loop 或用户自带 API key。
9. 不改变 Cloud/Local source of truth、SQLite 算法语义、`energy_ratio`、`gram_per_kg`、`diet_goal_phase` 或正式记录写入流程。
10. Phase 5 已落地能力必须保留；本计划只替换有缺陷的 Chat orchestration 和验收层。
11. 手动/AI 新建训练的未保存草稿继续以现有 SQLite `workout_record_drafts` 为本地权威；SharedPreferences 只允许保存轻量 route/picker recovery hint，不能成为第二份业务草稿或正式记录来源。
12. 草稿/clarification 等关键状态 mutation 必须有序且可恢复；通知、动画、route restoration 和 picker recovery 属于 best-effort Surface，不得阻塞、覆盖或复活已经确认完成/清理的权威状态。
13. 本地数据清空、退出登录和切换账号必须遵守当前边界：云端正式记录和 AI history 不因本地 SQLite 清理被删除，本地独有草稿不可伪装成可恢复，任何 runtime attachment/recovery lease 必须按 account/session/lifecycle 失效。

任何实施偏差若删除、延期、降级或重新解释上述能力，必须先列出差异并获得用户确认。不得把已确认实现范围移到“后续评测”来缩减当前终态。

## 3. 已核实的故障链与历史根因

### 3.1 故障链 A：Database 问答、错误安全拦截与循环

1. “Where is the workout exercise snapshot persisted?”本应进入 App Logic / Document RAG。
2. RAG 已返回 Database 证据，但 provider 正文中的 `saved` 被 `providerClaimedWrite` 宽泛命中。
3. Gateway 丢弃正文，改为固定“不能写入记录”声明；这不是 RAG 没检索到，也不是模型拒答。
4. evidence chip 直接渲染原始 Markdown heading，所以技术标识符外的反引号可见。Database 有大量表级 code headings，因此最容易暴露；Algorithm/Methodology 的少量 code headings 也会出现，其他设计文件通常没有。
5. 中文追问落入通用 intent clarification；响应只有普通文本和 questions，没有 clarification ID/options/pending state。
6. 用户回复“回答问题”时，系统无法证明这是上一轮 option，只能重新进入 planner；同一固定文案可以无限重复。

### 3.2 故障链 B：清晰食物图片仍循环

1. 当前请求包含图片和“一锅武汉排骨藕汤，喝了三碗”，已足以选择 Food Draft，并允许模型估算不确定营养。
2. active `task_planner` 的 implicit Food 规则只覆盖少数食物名并要求 `g/ml`；该句不匹配。
3. 代码只要看到未匹配图片就立即返回 `image_intent_ambiguous`，model planner 和最终多模态 provider 都没有看到图片。
4. 用户回复“食物草稿”后，active Phase 5 路径没有复用 legacy `expected_output.ts` 已存在的 explicit Food Draft 规则。
5. 上一轮图片只在 Flutter runtime display map 中，conversation context 和服务端 history 没有像素；第二轮即使选对 output，也无法生成原图草稿。
6. planner 主动澄清、planner timeout、provider error 和 invalid plan 都被压成同一句，因此截图无法从 UI 分辨第二轮的具体失败类。

### 3.3 为什么有完整计划仍丢能力

Git 与当前仓库显示的是流程缺口，不是“没有写计划”：

- 2026-07-05 的 `578e5f5` 直接删除六份 Phase 4 工程计划和 handoff，共 7,102 行；Git 可恢复，但当前仓库失去了就地可检索的行为决策历史。
- 2026-07-16 的 `0ab9871` 同一提交同时加入 RAG 整改计划、生产架构和大量报告/生成资产；没有一个可审阅的“计划与 failing baseline 已先冻结”的 Git 检查点。
- 新 `taskPlan.expected_output` 成为 production source 后会绕过旧 `resolveOutputSelection`；旧 resolver 和测试仍然常绿，却不再证明生产行为。
- 随后的 workout routing 修复继续补单点，没有“所有既有 capability 在新入口中的去向”清单，因此形成逐洞修补。

这说明真正缺少的是**架构替换的行为兼容门**：计划记录了要建设什么，却没有强制证明新入口没有丢掉旧入口已经确认的行为。

### 3.4 为什么现有评测没有发现

当前 `tool/evals/run_rag_eval.mjs` 会校验 fixture schema、ID、数量和报告 hash，但不会逐条执行 fixture 的输入与 oracle；部分结果直接以 `true` 表示“已有其他测试覆盖”。因此“11 suites / 102 cases”主要是库存统计，不等于 102 条行为通过。

Cloud canary 也存在覆盖盲区：

- Food diagnostic 使用 fixed `workflow_hint=food_logging`，绕过 AI 页面真实的 `auto` 决策；
- Food 检查接受 `draft != null OR needs_clarification=true`，所以清晰请求被错误澄清也能通过；
- App Logic 主要检查 provider/HTTP/非空文本，没有断言正文真正回答问题且未被 write guard 替换；
- retrieval recall/precision 能证明证据检索，不证明 Chat routing、clarification 状态或 draft completion。

### 3.5 Phase 5 与 RAG 计划的准确状态

`RAG_FOUNDATION_REMEDIATION_ENGINEERING_PLAN.md` 顶部“待实施”与末尾 W0-W11 complete/部署证据冲突，主要是封口 metadata 没同步，不代表应该跳回 Phase 4。复核后的准确结论是：

- W0-W5、W7-W8 的主要工程能力和 W10 部署/corpus 工作真实存在，应保留；
- W6 的前置规划框架存在，但没有完整落实图片输入、allowed outputs、typed clarification 和 same-chat continuation；
- W9/W10 的报告真实记录了检索与 provider canary，但评测方式没有证明 W6 用户旅程；
- W11 需要把顶部状态改成“主体已落地、发现后续 Chat orchestration/eval 缺口”，并链接本计划，而不是把 Phase 5 整体重新标为未完成。

## 4. 目标架构：一个有状态、受约束的 Chat Orchestrator

### 4.1 唯一生产顺序

```text
request + current attachments + session
  -> restore/consume pending clarification
  -> authenticate, authorize and apply fixed-entry constraints
  -> chat_decision.v2
       capability + allowed output + Context plan + attachment policy
  -> build only authorized Context / retrieve RAG when required
  -> selected provider generates one allowed output family
  -> strict/domain/grounding/write-claim validation
  -> persist turn, evidence and clarification transition
  -> Flutter renders text, typed clarification or editable draft
  -> user confirmation remains the only official write boundary
```

RAG 是 evidence/context layer，不再被当作 Chat 总控制器。Output Contract 负责允许模型返回什么，Orchestrator 负责当前任务应该调用什么能力以及如何推进状态。

### 4.2 `chat_decision.v2` 单一合同

输入至少包含：

- fixed workflow/output hint 和 Surface；
- 当前 user text、language、图片数量以及必要时的当前图片；
- pending clarification snapshot/reply；
- same-chat typed summary；
- 可用 Context 类型和授权状态；
- provider capability flags，但不包含 provider-specific prompt 规则。

输出至少包含：

- `decision_version`、`capability`、`planned_workflow`；
- `allowed_output_families` 与最终 `selected_output_family`；
- `requested_context`、`approved_context`、`rejected_context`；
- `requires_clarification`、`clarification_kind`、`missing_dimensions`；
- `attachment_policy`；
- `source=clarification_reply|fixed_entry|deterministic|model`、confidence 和 compact reason codes。

决策优先级固定为：

1. 合法 pending clarification reply：只消费 allowlisted option，不重新做开放 intent inference。
2. fixed entry/explicit workflow hint：输出族固定，缺 Context 只能澄清或降级，不能改成普通文本。
3. 高置信结构化表达：使用小而对称的确定性规则，例如明确“回答这个问题”“生成食物草稿”；这些规则必须有中英/mixed tests。
4. 其余开放语义：调用有界 planner；对图片确有助于区分 capability 的请求，planner 接收当前图片而不是只有 `image_count`。
5. planner 失败：返回可重试系统错误，绝不冒充用户歧义。

同一 production flag 下只允许一个 active decision implementation。`workflow_router.ts`、`task_planner.ts`、`expected_output.ts` 的可复用规则迁移到 v2 后，旧实现只能作为 shadow/rollback，不能永久并行决定结果。

### 4.3 多模态决策原则

- 文本已经高置信表达“喝了三碗/吃了这些，生成记录”时，直接选择 Food Draft，最终 provider 在同一 turn 看图；不额外调用视觉 planner。
- 图片-only、`这个怎么样` 等确实依赖视觉内容才能判断 capability 时，允许一次低预算多模态 planning；它只选择能力，不生成正式 artifact。
- 图片不能成为“默认歧义”的充分条件。
- 当前图片/base64 不写入数据库、不写日志、不进入 RAG corpus。

### 4.4 Clarification 是状态机，不是文案

公开响应 additive 增加：

```json
{
  "clarification": {
    "schema_version": "ai_chat_clarification.v2",
    "clarification_id": "opaque-id",
    "kind": "intent_selection",
    "question": "你希望我如何处理这条消息？",
    "options": [
      {"id": "answer", "label": "回答问题", "resulting_output": "text"},
      {"id": "food_draft", "label": "生成食物草稿", "resulting_output": "food_draft"},
      {"id": "workout_draft", "label": "生成训练草稿", "resulting_output": "workout_draft"}
    ],
    "missing_dimensions": [],
    "attachment_policy": "runtime_rebind_available",
    "attempt": 1
  }
}
```

请求 additive 增加：

```json
{
  "clarification_reply": {
    "clarification_id": "opaque-id",
    "option_id": "food_draft"
  }
}
```

服务端新增云端 `ai_chat_clarifications` 状态表，而不是把控制状态只塞进普通消息文本：

- 只保存 account/session/origin message IDs、kind、allowlisted options、missing dimensions、attachment policy、attempt、expiry 和状态；不保存图片像素，也不复制完整用户文本；
- 状态为 `pending -> resolving -> resolved`，或 `superseded/cancelled/expired`；
- 同一 session 最多一个 active clarification；
- compare-and-transition RPC/transaction 验证 account/session/id/option，并提供 request-id 幂等；失败可安全恢复 pending；
- response 的 `final_answer_json` 仍保留 clarification snapshot，供历史 UI 展示，但数据库状态才是控制 source of truth；
- 不改本地 SQLite schema/version。

自然语言“回答问题/食物草稿/第一个”等 alias 只能在存在 pending clarification 时映射到当前 options；全局短词匹配被禁止。

进度不变量：每一轮必须完成任务、减少 `missing_dimensions`、等待一个可消费输入，或进入稳定错误。相同 `decision signature + missing dimensions + options` 不得连续返回；intent selection 最多一次，业务缺字段最多一次。

### 4.5 临时附件生命周期

- 首轮清晰请求必须尽量同轮消费图片。
- 若必须澄清，Flutter 将 runtime attachment IDs 绑定 clarification ID；用户点击 option 时显式重发相同图片。
- 页面仍存活但图片已被系统回收时显示 `attachment_unavailable` 并要求重新选择，不能静默只发文字。
- App 重启、history reload 或换设备后，历史中只显示 metadata；clarification 标记 `resend_required`，绝不假装仍可访问原图。
- attachment rebind 必须遵守最多三张、大小/MIME 校验和现有隐私日志规则。
- 复用现有 picker recovery 的“当前页面是唯一 owner、Root 只在 owner 消失时 single-flight 恢复”原则；同一 clarification/image selection 不得打开第二个页面、重发第二个 request 或生成第二份 draft。
- 现有 `AiChatImageRecoveryStore` / `PhotoFoodAnalysisRecoveryStore` 只解决系统 picker 返回期间的 Activity 重建：marker 可保存文字、provider、日期等最小 metadata，并通过系统 lost-data API 取回实际图片；它们不能证明已发送 turn 的像素在任意重启后仍可访问，也不能替代 clarification 状态机。
- clarification attachment lease 只存在于当前 Flutter runtime，并同时绑定 account、session、clarification ID 和 origin turn。退出登录、切换账号、切换到不匹配 session、图片释放或 lease 被消费后立即失效；不得把本地路径/base64 长期写入 SharedPreferences、SQLite、云端 message 或日志。
- App 重建时可以恢复云端 pending clarification；只有系统 picker recovery 当次确实返回可用图片时才能重建 attachment lease，否则必须为 `resend_required`。SharedPreferences marker 的存在本身不能跳过图片可用性校验。

### 4.6 草稿交接与记录权威

- Chat Food/Workout artifact 在用户确认前仍是 AI draft；它们不能因 clarification resolved、provider success、history persistence 或页面恢复而成为正式记录。
- Workout Draft 确认后只通过现有 handoff 打开 Add Workout，并写入同一份权威 SQLite `workout_record_drafts`；不得新增 `ai_chat_workout_drafts`、SharedPreferences 完整草稿或第二个 active draft slot。
- SQLite draft mutation 保持关键且有序：正式云端保存开始后冻结新的 lifecycle autosave，云端成功后把最终草稿删除排在旧写入之后；失败则保留同一草稿供重试。Chat 整改不得绕过这条 ordering。
- `WorkoutEditorResumeStore` 只保存轻量 active-route hint，并以最近 30 分钟的权威 SQLite draft 判断是否自动恢复；通知渲染、route push 和 Android 图片缓存都是 best effort，不能影响草稿写入、清理或正式保存结果。
- Food Draft 继续进入现有 Food Preview，Workout Draft 继续进入现有训练 editor；Orchestrator 只生成/恢复经过校验的 artifact，不另建记录编辑器或自动保存路径。
- Profile“清空本地数据”可以删除 SQLite 中本地独有草稿但不删除云端 clarification/history；清理后若恢复到 pending clarification，客户端必须按真实可用性要求重新附图或重新建立目标 editor，不能依据残留 SharedPreferences marker 复活已清空草稿。

### 4.7 Evidence、write guard 与失败语义

Evidence：服务端继续返回原始 `doc_path/heading/heading_path/section_id/excerpt`。Flutter 的 `presentationLabel` 只去除成对 inline-code delimiter，保留内部文本、下划线、斜杠和顺序；畸形 Markdown fail-soft 显示原文。

Write guard：新增 `write_claim_guard.v2`，用版本化确定性句法/语义模式识别“执行主体+完成时态/结果+受限用户对象”，并返回 compact reason/span category。至少满足：

- block：`I saved your workout`、`Your workout has been saved`、`我已替你保存记录`；
- allow：`is saved in workout_sessions`、`这些数据保存在...`；
- allow：`I cannot save`、`不会自动删除`；
- 对无法确认但明确声称本次用户数据已变更的文本继续 fail-closed。

失败类型至少分为：`user_clarification`、`missing_business_fields`、`planner_unavailable`、`planner_invalid`、`provider_unavailable`、`provider_timeout`、`output_invalid`、`grounding_failed`、`attachment_unavailable`。只有前两类允许显示 clarification UI。

## 5. 工作包与强制 Gate

### W0 - 开发记忆与行为基线修复

任务：

1. 把 Git 中删除的六份 Phase 4 计划恢复到 `docs/history/phase4/`，加 `HISTORICAL / DO NOT EXECUTE` 索引；它们不进入当前 stable docs 或 Document RAG manifest。
2. 修正 `RAG_FOUNDATION_REMEDIATION_ENGINEERING_PLAN.md` 顶部状态为 `CLOSED_WITH_FOLLOW_UP_GAPS`，保留原 W0-W11 landing evidence，并链接本计划。
3. 建立 `test/evals/fixtures/ai_chat_behavior_parity.v2.json`：每个已确认 capability 必须记录 owning product requirement、历史来源、current route、expected workflow/output/context/confirmation 和 executable oracle。
4. 以 `d7b4f22` 为代码/文档基线，记录当前 production flags、Edge versions、migration/corpus hashes、Flutter 251-test 基线及现有 deterministic test 基线。`0529595f175827fc3255df44` 只是 595-chunk 本地 build，提交记录明确没有 cloud upload/activation；W0 必须独立回读真实 active cloud build，不能把 local generated 状态当成 production 状态。
5. 盘点并冻结现有记录/恢复组件的职责：`workout_record_drafts`、draft mutation queue、`WorkoutEditorResumeStore`、notification scheduler、`AiChatImageRecoveryStore`、`PhotoFoodAnalysisRecoveryCoordinator/Store`、Root lost-data recovery 和本地数据清空路径。新实现必须标明复用点，不能创建平行权威状态。
6. 先加入本节两条故障链的 failing tests，不改生产代码。

Gate W0：

- 每个旧 capability 都明确标为 `preserved / intentionally changed with approval / obsolete with evidence`；不得无去向。
- 当前两条故障链在 active production path 测试中稳定失败，证明测试能复现而不是手写结论。
- local generated corpus、active cloud corpus、Edge version、migration state 和 APK 必须分别记录；任何一项都不能由另一项推断。
- 训练/图片恢复组件的 source-of-truth、owner、清理条件和 best-effort 边界全部进入 parity manifest；Chat 改造不得新增第二个 active draft 或 recovery owner。
- 本计划、行为清单和 failing baseline 先形成独立 Git checkpoint，再开始切换生产入口。

### W1 - 把评测从“库存统计”改为“执行证明”

任务：

1. 为每个 fixture suite 注册真实 executor；runner 调用 production decision/context/output functions 并比较 hard oracle。
2. 没有 executor 的 suite 标为 `inventory_only`，不得进入 pass rate；release gate 中出现 inventory-only suite 直接失败。
3. 报告输出 `declared/executed/passed/failed/skipped`，并验证 executed case IDs 与 fixture IDs 完全一致。
4. 新增 multi-turn journey executor，可携带 session、pending clarification、附件可用状态和 simulated planner/provider failure。
5. 改 cloud canary：使用 AI 页面真实 `workflow_hint=auto`；只有预期为 clarification 的 case 才允许 clarification；Food/App Logic 必须断言具体 output、正文语义、evidence 和 guard action。
6. RAG retrieval 指标继续保留，但与 orchestration/task-completion 指标分开报告。
7. 冻结当前 Document RAG 的 keyword/domain-term normalization、lexical/vector hybrid retrieval、fusion/reranker、coverage/retry 配置和发布阈值。若实现确需调整，必须提供同一 eval set 的前后对比并获得用户批准；不能为让 Chat journey 通过而关闭 vector、缩减 rerank、降低 recall/precision/top-1 或把失败改记为 fallback success。

Gate W1：旧 runner 的硬编码 `true` 和“有 draft 或有 clarification 都算成功”不再存在；当前两次故障的 journey 在修复前红、修复后绿；现有 retrieval/grounding/reranker/coverage/retry suites 继续逐条执行并满足原阈值，不得以 orchestration 修复替代或降级 RAG 质量 Gate。

### W2 - `chat_decision.v2` 与唯一 active path

任务：

1. 定义 provider-neutral decision schema/validator 和明确的 precedence。
2. 把 fixed entry、explicit selection、language symmetry、context policy、allowed output 和 attachment policy 收敛到一个实现。
3. 模型 planner prompt 对 Food/Workout/App Logic/meal decision/普通问答对称，输入包含必要的当前图片，输出严格受 schema 限制。
4. planner unavailable/timeout/invalid 进入真实错误，不生成三选一。
5. 增加 `AI_CHAT_ORCHESTRATOR_VERSION=legacy|chat_decision_v2`；shadow 只比较决策，不重复调用最终 provider、不扩大 Context。
6. 逐项迁移 legacy resolver 的已确认行为；shadow mismatch 必须分类解决，不能以“新模型应该更聪明”直接忽略。

Gate W2：behavior parity fixture 100% executed/passed；`task_planner`、`expected_output`、`workflow_router` 不再有两个同时生效的 output decision；清晰图片文字能到达正确 capability。

### W3 - Clarification、持久状态与附件重绑

任务：

1. 增加 additive API contract、Edge validator、云端 migration/RPC/RLS 和状态转换测试。
2. Flutter 解析 typed options，渲染可点击选项并发送 typed reply；自由文本回复在本地不猜全局 intent，由服务端按 pending allowlist 消费。
3. 历史/重启恢复 typed clarification；expired/resolved 状态不可再次提交。
4. runtime attachment 与 account/session/clarification/origin turn 共同绑定，使用单一 owner、single-flight rebind；消费后不可再次重发，无法证明像素可用时明确要求重新选择。
5. 复用现有 Android picker lost-data recovery，但不把 picker marker 扩大成跨 turn 图片存储；Activity 重建、history reload、退出登录、切换账号、本地数据清空分别实现确定终态。
6. Workout Draft handoff 复用现有 SQLite active draft、mutation queue、30 分钟 route hint 和 best-effort notification；不得从 Chat clarification 创建第二份本地草稿或绕过现有清理 ordering。
7. 记录 attempt/progress signature；阻止相同 clarification 连续返回。

Gate W3：同一 option 幂等、跨账号/session/replay/伪造 option 被拒；“回答问题”“食物草稿”“生成训练草稿”都只消费一次；图片任务在 runtime、Activity 重建、App 重启/history reload、账号/session 变化、附件丢失和本地数据清空情况下都有确定终态；任何 recovery journey 都不会重复 push、重复 request、重复 artifact 或重复 active draft。

### W4 - Safety、Evidence Presentation 与诚实错误

任务：

1. 实现 `write_claim_guard.v2` 和中英/mixed positive/negative corpus。
2. 实现 evidence `presentationLabel`，不改原始 payload/corpus。
3. 扩展 public error mapping、Flutter retry/reattach UI 和 compact observability。
4. observability 记录 decision version/source/reason、selected capability/output、clarification ID/state/attempt、attachment policy、failure class、write-guard reason；不记录原始图片或完整 provider output。

Gate W4：数据库被动存储说明不再被拦截，真实写入声明仍 100% block；所有稳定文档技术 heading 的 UI label 通过，原始 evidence hash 不变；系统故障不再显示用户澄清文案。

### W5 - 端到端集成与设备验收

至少执行以下 hard journeys：

| 场景 | 必须结果 |
| --- | --- |
| English Database persistence question | `app_logic/text`；回答位置；有 Database evidence；无 write false block；chip 无 delimiter |
| 中文/中英混合等价问题 | 与英文 capability/output/Context 对称 |
| 通用 intent clarification -> “回答问题” | typed option 只消费一次，恢复原问题并回答 |
| 图片 + “一锅武汉排骨藕汤，喝了三碗” | 当前 turn 产生可编辑 Food Draft 或只因真实缺失字段做一次业务澄清；不得 intent 三选一 |
| 通用 intent clarification -> “食物草稿” | 恢复 Food Draft；runtime 图片显式重发 |
| 图片不可恢复 | 明确要求重新选择图片，不循环、不假装看过 |
| Android picker Activity 重建，原页面仍存活 | 原页面保持唯一 owner；Root 不重复 push，不产生第二个 request/draft |
| Android picker Activity 重建，原页面已丢失 | Root single-flight 恢复一次；只有实际取回图片才重建 attachment lease |
| App 重启/history reload 后仍有云端 pending clarification | 恢复 typed options；像素不可证明时 `resend_required`，不得依据 marker 假装可用 |
| clarification attachment option 连续点击或网络重试 | request ID 幂等；同一 lease 只消费一次，不重复 provider/draft |
| “生成训练草稿”及缺字段回复 | 恢复 Workout Draft；最多一轮缺字段 |
| Chat Workout Draft 确认与 Android 进程重建 | 只交接一个权威 SQLite active draft；30 分钟内按现有 route hint 恢复，旧草稿只手动恢复 |
| Workout 正式保存/失败/放弃 | 成功按 mutation ordering 清理且不复活；失败保留同一草稿；通知失败不影响结果 |
| 清空本地数据后恢复云端 Chat history | 云端 clarification/history 保留；已清空本地 draft/不可用图片不复活，UI 要求重新建立输入 |
| 退出登录/切换账号时有 pending clarification/attachment | runtime lease 清除；旧账号状态不可在新账号/session 消费 |
| meal decision/review | 只使用授权 summary；关闭授权时报告缺失而不改成别的 workflow |
| planner timeout/invalid | 可重试错误；保留输入；不是 clarification |
| provider invalid output | 一次 bounded correction 后合法结果或稳定错误 |
| “I saved your record” | block |
| “record is saved in table X” | allow |
| 未确认 draft | 永不产生正式记录写入 |

Gate W5：所有 hard journeys 100% 通过；报告显示每个 case 确实 executed；同一 clarification signature 连续重复率为 0；fixed workflow、auto workflow 和同会话 continuation 都有覆盖；恢复压力测试证明单一 owner/single-flight/ordered mutation，不出现重复页面、请求、artifact、draft、正式记录或清理后复活。

### W6 - 稳定文档、部署与 legacy 退场

实现后同步：

- `docs/en|zh/Product.md`、`AppGuide.md`：可观察 Chat/clarification/attachment/error 行为；
- `docs/en|zh/AgentDesign.md`：orchestration、权限和图片生命周期；
- `docs/en|zh/AIOutputContract.md`：decision/clarification additive contract 和 failure taxonomy；
- `docs/en|zh/RAGDesign.md`：RAG 与 Orchestrator 的职责边界；
- `docs/en|zh/Database.md`：新增 cloud clarification state；
- `API_CONTRACT_DRAFT.md`、`CHANGELOG.md` 和本计划状态。

Stable docs 全批次完成 ownership、双语、链接、UTF-8 和 stale wording 检查后，才重新生成 Document RAG chunks。`d7b4f22` 已产生的本地 build `0529595f175827fc3255df44` 没有上传/激活，而且本计划实施还会继续修改稳定文档，因此它只作为 W0 baseline，不作为最终发布候选；不得提前上传后再为本计划重复生成。若需要把文档文本发送给外部 embedding API，仍需单独明确授权；不能把本次代码/计划授权推定为数据外发授权。

发布顺序：

1. 部署 additive migration/API，保持旧客户端兼容。
2. 部署 v2 behind flag，运行 deterministic + shadow decision diff。
3. 运行真实 `auto` Qwen text/image cloud canary；OpenAI 无生产 secret 时只做 adapter/contract tests，不伪报 live parity。
4. 构建 configured split APK，完成真实设备两条原始故障链和附件重启场景。
5. 激活 `chat_decision_v2`，观察至少一个约定 soak window 的 completion、clarification、failure 和 guard 指标。
6. soak 通过后删除 legacy active decision；历史计划、parity fixture 和 rollback tag 保留。

Gate W6：云端 flag/Edge/migration/corpus/APK hashes、设备证据、监控窗口和回滚演练全部写入 landing summary；不能仅凭部署成功标 COMPLETE。

## 6. 测试与验证命令

### 6.1 Targeted deterministic

- decision contract/planner/clarification state/write guard/failure matrix Edge tests；
- expected output legacy-to-v2 parity tests；
- Flutter gateway response/message/history/controller/page/evidence label/attachment rebind tests；
- migration static/contract/RLS/idempotency tests；
- executable eval runner 和 multi-turn journey runner。

### 6.2 Required repository gates

```powershell
npm.cmd exec --yes deno -- check supabase/functions/ai-chat-route/index.ts supabase/functions/ai-food-photo-analyze/index.ts
npm.cmd exec --yes deno -- test supabase/functions/_shared/ai_output_contract_test.ts supabase/functions/ai-chat-route/expected_output_test.ts supabase/functions/ai-chat-route/index_test.ts supabase/functions/ai-food-photo-analyze/index_test.ts
flutter analyze
flutter test
```

还必须运行新增 decision/clarification/eval suites、现有 Document RAG/embedding/migration checks，以及：

```powershell
flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json
```

### 6.3 评测通过标准

- hard deterministic journeys：100%；
- fixture `declared == executed + explicitly_non_release_inventory`，release suites 中 inventory 为 0；
- clarification task completion：所有可满足输入完成，重复 signature 为 0；
- write guard positive/negative hard corpus：100%；
- evidence presentation cases：100%，raw payload parity 100%；
- 既有 RAG retrieval/grounding、Food/Workout strict validation和正式写入确认 tests 无回归；
- live canary 不允许用 fixed workflow 代替 auto，也不允许把非预期 clarification 计为成功。

## 7. 风险与回滚

| 风险 | 控制 |
| --- | --- |
| v2 决策改变已有 workflow | behavior parity manifest、shadow diff、flagged activation |
| clarification migration 影响旧客户端 | additive response/request；旧字段保留；服务端兼容无 typed reply |
| 状态 race/replay | server-owned table、transactional compare-and-transition、request ID 幂等 |
| 图片跨轮增加隐私风险 | 只由当前 Flutter runtime 重发；服务端不持久化像素；日志只存 metadata |
| 复用 picker recovery 时产生双 owner/双页面/双请求 | mounted Surface 独占结果；Root 只在 owner 消失时 single-flight；attachment lease 一次性消费 |
| SharedPreferences marker 被误当成可恢复业务状态 | marker 仅提示 route/picker recovery；恢复前必须回读权威 SQLite/cloud state并验证实际图片；账号/session/lifecycle 不匹配即清除 |
| Chat 创建第二份 Workout/Food 草稿权威 | 只交接现有 Food Preview、Add Workout 和 SQLite `workout_record_drafts`；禁止平行 draft table/slot/editor |
| 本地清理后残留 marker 复活已删除草稿 | server clarification 与本地 artifact/attachment 分别校验；本地数据不存在时要求重建输入，不从 marker 合成草稿 |
| local corpus 被误认为 active cloud corpus | W0/W6 分别记录 local build、active cloud build、Edge config/hash；只在完整 stable-doc batch 后一次性生成、授权、激活 |
| planner 多模态增加延迟/成本 | 文本高置信时不做视觉 planning；只在 capability 真依赖图片时调用；分别观测 |
| guard 放宽导致虚假成功声明 | narrow semantic detector + hard corpus + structured final-action invariant；不以模型分类替代安全门 |
| 新评测 runner 与生产逻辑分叉 | 直接导入/调用 production functions；报告记录 code/config hash |

2026-07-19 的 retirement 前回滚演练只切换 `AI_CHAT_ORCHESTRATOR_VERSION=legacy`，没有回滚 `rag_foundation_v1`、Document RAG corpus、Food Capability 或正式数据 schema；报告证明旧路径仍可服务，但会重新失败 8 个 v2 行为 Gate。恢复 v2 并通过最终 canary 后，legacy 生产分支和两个 runtime secrets 已删除。retirement 后若必须紧急回退，只能重新部署保留在 Supabase 历史中的 Edge v63/基线源代码，并继续保留 additive clarification 表和历史消息；不得通过不存在的 flag 假装完成回滚，也不得回滚正式数据 schema。

## 8. 完成定义

只有同时满足以下条件，本计划才能标记 COMPLETE：

1. 两次用户提供的原始故障链在 active production path、cloud canary 和真实设备上都通过。
2. `chat_decision.v2` 是唯一 active workflow/output/context/clarification source；legacy 只在已记录 rollback window 内存在，随后删除 active code。
3. Clarification 是服务端有状态、客户端可恢复、typed option 可幂等消费的协议；不存在相同 clarification 无限重复。
4. 清晰图片请求在同轮到达正确 capability；跨轮图片有显式 rebind/resend/reattach 终态且不长期存储。
5. Database/App Logic 被动存储说明不再被 write guard 误杀，真正的未授权写入声明仍被拦截。
6. Evidence UI 不显示 Markdown delimiter，原始 RAG evidence/corpus/hash 未因 presentation 修复改变。
7. planner/provider/validation/attachment failures 与用户歧义在 API、UI、日志中可区分。
8. 评测逐条执行 fixture 和 multi-turn journey；不存在硬编码 pass、允许任意 clarification 或 fixed workflow 绕过真实入口。
9. 所有旧产品能力在 parity manifest 中有明确去向，所有 confirmed requirements 均未静默删除或降级。
10. 现有 keyword/vector/hybrid/reranker/coverage/retry 配置和质量 Gate 未被静默关闭、缩减或降阈值；如有经批准调整，前后 eval 与理由已完整记录。
11. Clarification/附件恢复复用单一 owner、single-flight 和 account/session lease；Activity/App 重建、重试、本地清理、退出/换号均不会产生重复页面、请求、artifact、draft 或正式写入。
12. Chat Food/Workout handoff 只使用现有编辑器与权威草稿机制；训练草稿 mutation ordering、30 分钟 route restoration 和 best-effort notification 边界保持成立。
13. Required Edge/Flutter/migration/eval/build/cloud/device gates 通过，稳定中英文文档、API、CHANGELOG、RAG plan status 和 landing summary 已同步；最终 corpus 与 active cloud state 分别验证。

## 9. 当前实施状态

- [ ] W0 开发记忆、RAG plan 状态与行为基线修复：交付物已完成；事前独立 Git checkpoint 无法事后补造
- [x] W1 可执行评测与真实 canary
- [x] W2 `chat_decision.v2` 唯一 active path
- [x] W3 Clarification 状态机与附件重绑
- [x] W4 Safety、Evidence 和 failure taxonomy
- [ ] W5 端到端 journey、云端与设备验收：自动化与 cloud journey 已完成；真实设备安装/人工 journey 阻塞
- [ ] W6 稳定文档、部署、soak、rollback rehearsal 与 legacy 退场：除真实设备 Gate 和 final corpus 外部 embedding/激活外均完成

### 9.1 Landing summary

| 项目 | 2026-07-19 landing evidence |
| --- | --- |
| 基线与开发记忆 | 基线 `d7b4f223870d915bfa0d008421e443438a8fd38f`；六份 Phase 4 计划恢复到 `docs/history/phase4/` 且明确 `HISTORICAL / DO NOT EXECUTE`；RAG plan 状态为 `CLOSED_WITH_FOLLOW_UP_GAPS`。现有 workout draft、mutation queue、30 分钟 resume hint、best-effort notification、AI/Add Food picker recovery 与本地清理 owner 已进入 parity manifest，未创建平行权威状态。 |
| 唯一编排入口 | `chat_decision.v2` 共同决定 capability、output、Context、clarification 和 attachment policy；legacy 生产 branch 已从 `index.ts` 删除，`AI_CHAT_ORCHESTRATOR_VERSION` 与 `AI_CHAT_ORCHESTRATOR_SHADOW_ENABLED` secrets 已删除。Legacy comparator/task rules只作为历史 oracle 或 v2 明确复用的 deterministic helper。 |
| Clarification | `ai_chat_clarification.v2`、云端 `ai_chat_clarifications`、RLS、claim/resolve/release RPC、request-ID replay、30 秒 stale claim、attempt/progress signature、typed/free-text scoped reply、Flutter history restore、account/session attachment lease 和 local clear invalidation 已落地。Migrations `202607190001`、`202607190002`、`202607190003` 本地/远端一致。 |
| Safety 与 evidence | `write_claim_guard.v2` 区分 AI 已完成写入与被动数据库说明；evidence UI 只移除平衡的 inline-code delimiter，不改 raw evidence；planner/provider/validation/attachment 与 clarification errors 分开映射并以 compact privacy-safe fields 记录。 |
| 自动化 | `flutter analyze` 无问题；`flutter test` 259/259；required Edge 63/63；全部 Edge 278 passed、0 failed、2 个声明为 external 的 provider fixtures ignored；Node docs/corpus/migration 21/21；local release report 8 pass、0 fail、1 blocked，110 declared / 108 executed+passed / 2 external skipped。 |
| Cloud final | Edge `ai-chat-route` ACTIVE v64，bundle SHA-256 `a27c21c15ea0d3fb99f42880a5cce1b5dea23cec5be7f45cc3cd9ab4fc5f3b11`；`ai-food-photo-analyze` ACTIVE v33。最终真实 Qwen `auto` 报告 `rag_foundation_cloud_chat-orchestrator-v2-legacy-retired.v1` 为 33/33：两条用户故障链、Food image draft、typed create/consume/replay、resolved once、RLS、13/13 source recall、37/39 precision、5/5 critical top-1、Edge vector embedding completed、reranker 保留且 Edge retrieval p95 1324 ms。 |
| Soak | `2026-07-19T13:48:28Z` 至 legacy rehearsal 开始前 `2026-07-19T14:28:23Z` 的受控 v2 窗口包含 7 个最终 hard turns：text/app-logic、image Food Draft、typed clarification pending -> resolved、idempotent replay；0 final failure、0 duplicate signature、0 write-guard false positive。随后 post-retirement 33/33 canary 再次验证唯一 v2。 |
| Rollback rehearsal | 临时 legacy 报告 `rag_foundation_cloud_chat-orchestrator-rollback-legacy-rehearsal.v1`：Edge/RAG/data 可用，13/13 recall、39/39 precision、5/5 top-1，但总计 25 pass / 8 fail，失败正是 permission/RAG boundary、image auto 与 typed clarification。随后恢复 v2、部署 v64、删除 legacy flags并以 33/33 final gate确认。 |
| APK | Configured split debug APK 构建成功。SHA-256：`armeabi-v7a` `16c6f7793a4f0b443fa63c2c1905bbcce09dbd014e8a6e370b90460b4f80f9cf`；`arm64-v8a` `0d892efcb577280cddc32b6b0bdd69ed38df4c34c93022dfb474c8dba8f9b678`；`x86_64` `262a0452e6b50850011d89c9f872f423e380923d6c29497393ad24775e2372bb`。 |
| Corpus | 最终稳定文档在全部双语/ownership 检查后生成 local build `0fc1fdfe9be09ac849bbb8a6`，21 sources / 613 chunks。生产仍使用已验证 active build `a33cf90c1adf71ec7d08113d`，21 sources / 586 embedded chunks；本任务没有把稳定文档发送给外部 embedding API。 |

### 9.2 尚未关闭的 Release Gate

1. 连接的定制 Android 11 `armeabi-v7a` 设备可以完整接收 100,910,902-byte APK，PackageInstaller session 也能写到 100%，但 commit 长期停在 90% 且未创建 package；同设备存在历史未终结 install sessions。临时 APK/session 已清理且未删除用户数据。需要设备维护/重启或另一台可安装设备后，执行两条原始截图 journey 与 picker Activity/App restart journey。
2. Final corpus 比 active cloud corpus 多 27 chunks。按照本计划和数据外发边界，生成 613 份外部 embeddings 并激活新 corpus 需要单独明确授权；在此之前 local eval 的 `active_chunks_embedding_freshness_parity` 正确保持 `blocked`，不能改成 pass。
3. W0 要求的“切换生产入口之前形成独立 Git checkpoint”无法在事后伪造；本次所有改动仍基于可审计的 `d7b4f22` diff，Phase 4 历史、parity manifest、pre-retirement Edge v63 和 rollback report 已保留。最终 landing 已形成正常 Git commit，但不能把它冒充为事前 checkpoint。

在以上 Gate 有真实证据前，状态保持 `IMPLEMENTED / FINAL RELEASE GATES OPEN`，不标记 `COMPLETE`。
