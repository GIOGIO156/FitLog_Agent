# FitLog_Agent RAG 基础工程整改详细落地计划

> 状态：待实施（Execution Plan Ready）
>
> 制定日期：2026-07-13
>
> 当前执行范围：[`RAG_FOUNDATION_REMEDIATION_SCOPE.md`](RAG_FOUNDATION_REMEDIATION_SCOPE.md)
>
> 历史参考：[`docs/history/phase5/PHASE5_ENGINEERING_PLAN.md`](docs/history/phase5/PHASE5_ENGINEERING_PLAN.md)
>
> 所属 Roadmap：Phase 5 closure / hardening；本计划同时落地后续 Phase 6 可直接复用的完整评测基础，以及与 Planner/Provider/Output 共用基础设施的 AI Capability/Food Vision 发布阻断；不得用“留到 Phase 6 评测”或“另做图片功能”代替本计划已经确认的能力。

## 0. 文件职责与执行规则

本文件负责说明“按照什么顺序、修改哪些文件、采用什么合同、如何测试、部署、回滚和验收”。它必须与范围清单配套使用：

1. 范围清单锁定“必须解决什么”，本计划锁定“如何完整解决”。
2. 后续 Codex 开始实施前必须完整读取两份文件，不能只读本计划摘要或只处理触发案例。
3. `RAG-S00-01` 至 `RAG-S22`、`AI-S01` 至 `AI-S06`、`RAG-D01` 至 `RAG-D09`、`AI-D01` 至 `AI-D02` 都必须在本计划的追踪矩阵中有实施步骤、具体文件、自动化和验收证据。
4. 施工可以分批，但不能把 text embedding、hybrid retrieval、中文分词、reranker、检索工具、一次 Agentic retry、前置 Task/Context Planning、动作 Context 或全面评测降级成可选项。
5. 发现代码与本计划基线不同，先把差异、影响和建议写入“实施偏差记录”，再调整步骤；不得静默改变终态。
6. 每个施工包只能在对应自动化测试、生成物检查和人工/云端验收完成后标为完成。
7. 计划中的“候选文件”允许因实际代码组织做最小调整，但同一能力、合同、测试和验收不得消失。
8. 本轮实施不授权用户业务数据向量库、长期 semantic memory、GraphRAG、任意 SQL、开放式 Agent loop 或未确认正式写入。
9. 每个 Scope ID 开工前必须把实际文件补入第 20 节；完成时必须能从 Scope ID 追到施工包、代码/文档文件、测试、Gate 和部署证据。不能以“修改 Provider”“更新 Prompt”等泛化描述代替文件级落点。

### 0.1 后续 Codex 的开始顺序

```text
读取 AGENTS.md
  -> 读取 RAG_FOUNDATION_REMEDIATION_SCOPE.md
  -> 读取本计划全文
  -> 查看 git status，保护用户已有修改
  -> 执行 W0 基线冻结
  -> 按 W1-W11 顺序施工
  -> 每个 Gate 失败就停在当前施工包修复
  -> 所有终验通过后才更新 Roadmap/CHANGELOG 并归档
```

### 0.2 状态标记

施工时只使用以下状态：

- `NOT_STARTED`：尚未开始。
- `IN_PROGRESS`：代码或文档正在修改，尚未通过 Gate。
- `BLOCKED`：存在明确外部阻断；必须记录原因、已尝试方案和解除条件。
- `IMPLEMENTED_NOT_DEPLOYED`：本地自动化已通过，云端 migration/seed/Edge 尚未完成。
- `CANARY`：目标 Supabase 和测试账号正在灰度验收。
- `COMPLETE`：本地、云端、人工、文档和追踪矩阵全部闭合。

不得用“代码已写”“大体完成”“后续观察”代替以上状态。

### 0.3 稳定设计文档更新原则

本计划是状态/步骤导向的工程计划，可以记录 Gate、偏差、部署和日期；稳定设计文档不是施工日记。所有 stable docs 更新必须遵守 `AGENTS.md` 的 Formal Document Charters 和 Value-Preserving Refinement Workflow：

1. 修改前盘点 owning 文档相关 heading，将内容分类为 canonical fact、rationale/invariant、用户行为、实现机制、兼容/迁移、failure/edge case、历史事故、rollout task、evidence 或 duplicate。
2. Durable current behavior 写回拥有该事实的现有 capability-oriented section，并使用 present tense；不得在稳定文档末尾追加“2026-xx 更新”“本轮修改”“Phase closure”或其他时间戳式补丁块。
3. `Product` 维护产品承诺，`AppGuide` 维护入口/用户终态，`AgentDesign` 维护 capability/permission/provider boundary，`AIOutputContract` 维护输出/校验/纠错，`RAGDesign` 只维护 Context/retrieval/evidence，`Database` 维护持久化字段/数据流，`API_CONTRACT_DRAFT` 维护实际 wire contract。
4. 中英文 stable pair 在同一施工包同步 outline、事实、约束和链接；不能只改中文或只改英文。
5. 历史事故和已发布修复写入 `CHANGELOG.md`；施工顺序、Gate、canary、rollback 和未完成状态保留在本计划/Roadmap；不要把计划 checklist 复制进 stable docs。
6. 删除或移动文本前先确定新归属，保留公式、字段语义、source-of-truth、权限、failure、隐私、迁移和 non-goal 的最强陈述；不确定时保留并记录 ownership 问题。
7. 全部预定 stable docs 完成 ownership/bilingual/link/stale-wording 检查后，才重新生成 Document RAG chunks/seed/embedding；禁止边改一份边上传新 corpus。

## 1. 目标、成功定义与非目标

### 1.1 最终目标

本轮要把当前受控但能力不足的 RAG 管线升级为以下终态：

- 稳定文档 corpus 完整、双语、保真、可版本化和可校验；
- App 官方词、内部枚举、中文/英文同义表达可归一到相同概念；
- Document RAG 同时使用 exact/phrase、中文 token、全文、trigram、术语扩展和 text embedding；
- hybrid candidates 经受控、可解释的二阶段 rerank 后进入 Prompt；
- 模型可发出严格合同的文档检索工具调用，但服务端控制 corpus、参数、权限和次数；
- 首次证据不足时最多允许一次 query rewrite + retrieval，第二次仍不足必须停止；
- Task/Context Planning 发生在 Context Builder 之前，Context 不再由早期关键词路由单独决定；
- 内置动作、自定义动作和动作级历史可以作为最小、typed、authorized Structured Context；
- Workout Draft 按稳定动作引用确定性绑定，不再把未知动作静默当成 `total_load + total_reps`；
- FitLog 专属结论必须逐段绑定 Document/Structured/Deterministic evidence；
- 所有 AI Surface 通过 provider-independent Capability Core 调用 OpenAI/Qwen，Provider Adapter 不再拥有产品业务规则；
- 专用图片分析和 AI Chat 的 Food Draft 共享事实优先级、语言 policy、字段语义、semantic validator、纠错和 Preview Gate；
- 专用图片分析拥有独立 ChatGPT/千问 Provider preference，并接入 OpenAI image-capable adapter；
- 全面评测覆盖所有产品文档主题、Structured Context、路由、输出、安全、失败和性能，而不是只覆盖 workout 示例。

### 1.2 触发案例必须得到的正确行为

用户询问：

```text
像保加利亚分腿蹲的每侧次数，如果填 12，是否等于一组共做 24 次？
训练量怎么算？
```

终态必须做到：

1. 术语归一化把“每侧次数 / 单侧次数 / 单边次数 / per-side reps”映射为 `per_side_reps`。
2. 动作实体解析把“保加利亚分腿蹲”绑定为 `bulgarian_split_squat`。
3. `exercise_definition_context` 证明该动作的 `reps_input_mode = per_side_reps`。
4. Document RAG 命中稳定 `Algorithm.md` 中的计算规则，而不是依赖模型常识。
5. 回答明确区分：界面原始输入/展示仍为每侧 12；用于训练量和力量消耗启发式的 `calculation_reps = 12 * 2 = 24`。
6. 训练量使用保存的标准化字段，例如 `effectiveCalculationLoadKg * calculationReps`，不能错误声称只按单侧 12 计算。
7. Answer Basis 同时显示算法文档和动作定义；若任一维度缺失，明确说明缺什么。

### 1.3 自定义动作必须得到的正确行为

- 用户在当前问题中明确提到一个本地自定义动作时，Flutter 只发送该次命中的最小 `exercise_reference`，不能上传整个本地动作库。
- AI 问答可解释该引用携带的重量/次数/组统计属性。
- 用户要求“记录这个动作 3 组……”时，可以生成 Workout Draft，但仍必须进入现有训练编辑器并由用户保存。
- 查询该动作历史时，只有在记录摘要权限开启后，服务端才按账号和稳定动作 key 从云端正式 workout records 构建 `exercise_history_context`。
- 自定义动作库本身不因此变成全量云同步表；当前本地定义与历史 session snapshot 冲突时必须分别标明，不得互相覆盖。

### 1.4 明确非目标

- 不为 food/workout/body records、自定义动作历史或聊天历史建立 embedding/vector memory。
- 不把本地 `custom_exercises` 全表上传云端。
- 不允许模型生成或执行 SQL。
- 不允许无限检索、无限反思或 autonomous action loop。
- 不允许 AI 在用户确认前写入、删除或修改正式 food/workout/profile 数据。
- 不改变 `gram_per_kg`、`energy_ratio`、`diet_goal_phase` 等既有算法权威边界。
- 不因为新增 RAG 而提升 SQLite `dbVersion`；除非实施中确实新增本地持久化字段，届时必须另行按迁移规则审查。

## 2. 已验证的当前基线与根因

下表不是推测，而是本计划制定时对仓库现状的核对结果。实施 W0 必须重新验证，防止后续代码已经变化。

| 编号 | 当前事实 | 代码/文档证据 | 用户影响 | 对应范围 |
| --- | --- | --- | --- | --- |
| B-01 | `CloudLocalDataBoundary.md` 不在手写 chunk source list 中。 | `tool/phase5_document_rag/build_document_chunks.mjs` 的 `sourcePaths` | 云端/本地权威、cache、冲突和失败规则无法被 Document RAG 找到。 | S01, S03 |
| B-02 | chunk generator 的 Markdown 处理会破坏链接、URL、扩展名和代码路径。 | `stripMarkdown()` 与当前 generated seed 中的 `. dart`、`. sql`、`developers. openai. com` | 检索内容不等于源文档，代码引用和事实可能被破坏。 | S04, S18 |
| B-03 | 检索只有一次同语言 Postgres lexical RPC。 | `document_rag.ts` -> `search_document_chunks` | 官方中文词、同义词、长句和语义改写容易零命中。 | S05-S10 |
| B-04 | PostgreSQL `simple` tokenization 无法充分处理连续中文长句。 | `202607090002_phase5_document_rag_query_terms.sql` | “每侧次数”可能作为长字符串的一部分，term overlap 不稳定。 | S05, S07 |
| B-05 | 当前顺序为 route -> Context Builder -> output selection。 | `ai-chat-route/index.ts` 当前 125-139 行附近 | 后期识别出 Workout/Food Draft 时，无法反向申请动作或记录 Context。 | S11 |
| B-06 | 早期 route 主要依赖硬编码关键词与客户端 hint。 | `workflow_router.ts` | 图片+文字、隐式记录、动作+规则组合问题可能选错 Context。 | S11, S20 |
| B-07 | 服务端 Context 没有动作定义和动作级历史。 | `phase5_types.ts`、`context_builders.ts` | 内置/自定义动作属性无法成为受控证据。 | S12, S13 |
| B-08 | 内置动作真实属性只存在于 Dart catalog；官方中文名另在 AppStrings。 | `exercise_catalog.dart`、`app_strings.dart` | 服务端无法确定性识别“保加利亚分腿蹲 = per_side_reps”。 | S02, S12 |
| B-09 | 自定义动作库只在手机 SQLite。 | `custom_exercise_repository.dart` | 服务端不能主动读取；需要 request-scoped 最小引用，而不是误设全量同步。 | S12, S16 |
| B-10 | Workout Draft 绑定失败会生成 ad-hoc key 并默认 total load/total reps。 | `ai_workout_draft.dart` | 用户自定义或未知动作可能被错误解释并进入编辑器。 | S14 |
| B-11 | 稳定 Agent 文档没有完整迁移 Local 中已实现的输入口径规则。 | `docs/local/*` 有“每侧次数”等说明，当前 stable docs 缺失 | 即使检索成功也可能没有正确 corpus 事实。 | S01, S02 |
| B-12 | App 官方中文确实使用“每侧次数”，不是用户临时同义词。 | `app_strings.dart`、`add_workout_page.dart` | 零命中首先是 corpus/检索缺陷，其次才是一般同义词问题。 | S02, S05 |
| B-13 | API 实际解析 `allow_record_summary_context`，公开请求示例未完整展示该字段。 | `contracts.ts` 与 `API_CONTRACT_DRAFT.md` | 客户端、服务端、隐私文档合同不完全一致。 | S16 |
| B-14 | Prompt 只通过文字要求“没来源就别猜”，没有强制 claim-evidence 结构。 | `prompt_builder.ts`、`index.ts` | 模型仍可能在 `document_sources=[]` 时给出确定的 FitLog 专属结论。 | S15 |
| B-15 | 原 Roadmap 规划了 eval，但仓库没有完整可运行的 RAG eval corpus/report harness。 | 当前 `test/` 与 Edge tests | 召回、faithfulness、retry、性能和隐私缺陷无法系统阻断发布。 | S18-S22 |
| B-16 | Flutter 专用食物页正确发送中文 `language`，但专用 Food prompt 只有简短中文 system 句，任务说明、JSON 示例和 correction 主要是英文，且无输出语言 validator。 | `photo_food_analysis_page.dart`、`ai-food-photo-analyze/contracts.ts`、`_shared/ai_output_contract.ts` | 中文输入可以返回全英文或中英混合 meal/item/notes，并被结构校验放行。 | AI-S03, AI-S04 |
| B-17 | Food Draft validator 只验证字段、范围、日期并用 item sum 归一化 meal totals，不比对原始用户事实、notes/数字或营养语义。 | `_shared/ai_output_contract.ts` 的 `validateFoodDraft()`/`foodTotals()` | “说明承认 20g 蛋白质，但 `protein_g=8.5`”可以成为可审查草稿。 | AI-S02 至 AI-S04 |
| B-18 | 专用 Food correction 只在 `OutputContractError` 时发生；错误语言和事实矛盾是合法 string/number，不会触发 correction。 | `ai-food-photo-analyze/index.ts` 的 first-pass parse/correction | 单次模型语义错误被当成成功，而不是可恢复 issue。 | AI-S04 |
| B-19 | 专用请求合同和 Flutter 页面固定 Qwen；AI Chat OpenAI adapter 当前遇到图片直接拒绝。 | `ai-food-photo-analyze/contracts.ts`、`photo_food_analysis_page.dart`、`openai_provider.ts` | 图片分析无法独立选择 ChatGPT；未来接入容易复制第二套 Food 规则。 | AI-S01, AI-S05, AI-S06 |
| B-20 | 专用图片页面不是 Chat；`needs_clarification` 只被拼成错误通知，不能形成同会话问答。 | `photo_food_analysis_page.dart` 的 draft-null 分支 | 把 Chat clarification 规则照搬到该 Surface 会产生无法完成的 UX/状态合同。 | AI-S03, AI-S05 |
| B-21 | AI Chat 和专用 Food endpoint 分别构造 provider/system/user prompt，专用端点还在 index/contracts 中直接实现 Qwen Vision transport。 | `ai-chat-route/openai_provider.ts`、`qwen_provider.ts`、`ai-food-photo-analyze/contracts.ts`/`index.ts` | 语言、事实优先级、估算、error 和新 provider 支持会继续跨入口漂移。 | AI-S01, AI-S03, AI-S06 |

## 3. 不得破坏的既有边界

### 3.1 输出与写入

- 保留 provider-independent JSON envelope、严格 schema/domain validation 和最多一次 output correction。
- Retrieval retry 与 output correction 是两个不同机制：前者最多一次额外搜索，后者最多一次修复无效 JSON/合同输出；任何一个都不能演变成循环。
- Food Draft / Workout Draft 仍然只是 artifact；正式写入只发生在既有确认编辑页。
- `text`、`food_draft`、`workout_draft`、`clarification` 的公开响应关系继续严格校验。
- Provider adapter 只映射 provider 协议，不能改变 capability、字段语义、目标语言、权限、semantic validator、correction 上限或用户确认边界。
- 用户明确事实是 Food Draft 的最高优先级输入；图片/OCR/模型估算只能补充，不得覆盖。
- 专用图片页不创建 Chat session/clarification loop；分析失败或信息不足时保留输入并返回原表单修正。

### 3.2 数据与权限

- Auth、subscription、active-device 检查先于任何用户 Context builder。
- 记录摘要权限关闭时，`selected_day_summary`、recent summaries、`exercise_history_context` 不得读取。
- 内置动作 catalog 属于产品定义，不需要记录摘要权限。
- 当前请求明确命中的本地自定义动作引用视为 request-scoped 用户输入；无需记录摘要权限，但不得持久化完整定义到日志或长期服务端动作库。
- 客户端仍不能提交任意 `context_objects`、RAG result、tool result、SQL、server task plan、official write 或 provider key。

### 3.3 算法权威

- `per_side_reps` 的保存/计算规则由确定性 Dart 逻辑和稳定 Algorithm 文档共同说明；模型不自行发明公式。
- `exercise_definition_context` 只能说明动作定义，不能覆盖已保存 workout session/set snapshot。
- 历史趋势只能来自云端正式记录的 bounded summary，不从聊天文本猜测。

## 4. 目标架构与请求顺序

### 4.1 正常请求顺序

```text
Flutter request
  -> request schema / auth / subscription / active-device
  -> deterministic safety and fixed-entry rules
  -> pre-context Task Planner
       - deterministic high-confidence plan, or
       - bounded model plan after deterministic abstention
  -> server Context Policy validation and data minimization
  -> entity resolution
       - built-in exercise snapshot
       - request-scoped custom exercise references
  -> approved Structured Context builders
  -> search_fitlog_docs tool execution when requested
       - normalization + Chinese segmentation
       - exact/phrase + token + FTS + trigram + term expansion + vector
       - fusion + deterministic reranker
       - evidence coverage check
       - at most one model rewrite/tool retry
  -> bounded Prompt assembly
  -> final provider call using unified output contract
  -> schema/domain/grounding/write guards
  -> optional one output correction
  -> public response + Answer Basis + privacy-safe telemetry
```

### 4.2 为什么不再使用旧顺序

旧顺序先决定 Context，再让最终模型决定输出类型。它能处理早期已写死的 App Logic/Meal/Weekly 路由，但不能处理后加入的隐式 Food Draft、Workout Draft 和动作组合问题。新顺序先得到一个受限 Task Plan，服务器再根据 plan 组装 Context；模型可以申请信息，但服务器拥有最终裁剪权。

### 4.3 模型调用上限

| 路径 | Planner | Retrieval rewrite | Final answer | Output correction | 最大模型调用 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 高置信确定性、无需 retry、输出有效 | 0 | 0 | 1 | 0 | 1 |
| 模糊任务、无需 retrieval retry | 1 | 0 | 1 | 0 | 2 |
| 确定任务、检索不足后 retry | 0 | 1 | 1 | 0 | 2 |
| 最坏允许路径 | 1 | 1 | 1 | 1 | 4 |

硬限制：

- Document search 最大执行 2 次：首次 + 1 次 retry。
- Query rewrite 最大 1 次。
- Output correction 最大 1 次。
- 任何 timeout、预算不足或第二次证据仍不足都必须停止。
- Planner/retry 只返回结构化决策，不保存或暴露 chain-of-thought。

Food Capability 使用独立预算；专用 Food Surface 不经过 Chat Task Planner 或 Document RAG：

| Food 路径 | Food understanding | Draft generation | Semantic/output correction | 最大调用 |
| --- | ---: | ---: | ---: | ---: |
| 专用页面，first pass 有效 | 1 | 1 | 0 | 2 |
| 专用页面，允许一次纠错 | 1 | 1 | 1 | 3 |
| AI Chat 已高置信确定 Food Draft | 1 | 1 | 0/1 | 2/3 |
| AI Chat 需 Task Planner 后确定 Food Draft | Planner 之外 1 | 1 | 0/1 | 总计 3/4 |

Food understanding 与 Draft generation 分开是为了先把用户明确事实、包装/OCR、图片观察、估算需求和冲突编译成稳定中间结构，再生成草稿；不得为了降低一次调用而重新把事实提取、视觉估算、字段填充和一致性检查塞回一个不可验证的自由生成步骤。W9 必须分别报告这两步的延迟、token、cost 和失败率；若 canary 证明某 provider 支持在一次严格响应中同时返回完整 evidence ledger + draft，只有通过同一事实忠实度 Gate 且获得用户批准后才可合并，不能实施者自行删减。

### 4.4 所有 AI 能力的分层

```text
Surface Orchestration
  - AI Chat / 专用图片分析 / 未来明确入口
  - 决定 surface、目标语言来源、fixed/auto task、允许 Context、独立 Provider 选择和 UI 终态
  -> provider-independent Capability Request
Capability Core
  - task_plan / retrieval_query / text_answer / food_draft / workout_draft
  - 定义业务 policy、字段语义、权限、evidence、失败和确认边界
  -> Provider-neutral generation request + schema
Provider Adapter
  - OpenAI / Qwen / mock
  - 只做 API URL、auth、text/image/tool/schema 编码、completion/refusal/incomplete 提取
  -> Provider-neutral completion
Shared Validation
  - structure / domain / language / fact faithfulness / grounding / safety / compatibility
  -> public response or stable failure
```

禁止把 Surface-specific 决策塞进 Provider Adapter，也禁止为了“统一”而强迫所有 Surface 使用一段相同 Prompt。统一的是 normalized request、Capability policy、合同、validator 和 Gate；Surface instruction 与 provider encoding 可以不同，但不能改变业务语义。

### 4.5 Food Capability 跨入口顺序

专用图片页面：

```text
App language + 独立 food provider preference + selected date + text/images
  -> fixed capability=food_draft（无 Chat intent、无 Document RAG）
  -> food_understanding.v1
  -> server precedence/conflict normalization
  -> food_draft.v2 generation
  -> structural + language + semantic + safety validation
  -> valid draft -> Food Preview
     or input_revision_required -> 保留原表单输入，用户修改后重新提交
```

AI Chat Food Draft：

```text
Chat Task Planner/output family approval
  -> capability=food_draft + approved same-chat/current-image Context
  -> 与专用页面相同的 Food Capability Core/Provider Adapter/Shared Validation
  -> Chat artifact/clarification UX
```

两个 Surface 不共享模型 preference，也不共享 Chat 状态；它们只共享 Food Capability 的产品语义和执行组件。

## 5. 已锁定的技术选择

### 5.1 Canonical corpus

用户侧 corpus 固定为：

- 根目录 `README.md`；
- `docs/en/` 下 required stable tree 全部文档；
- `docs/zh/` 下对应 required stable tree 全部文档；
- 明确包含双语 `CloudLocalDataBoundary.md`。

不包含：`docs/local/`、`CHANGELOG.md`、`docs/ROADMAP.md`、`docs/history/`、根目录工程计划、`API_CONTRACT_DRAFT.md`、generated SQL、源码和用户记录。

Corpus 不再由 generator 内部手写数组维护，改用版本化 manifest；生成器、测试、seed 和云端 build metadata 都读取同一 manifest。

### 5.2 中文分词与术语归一化

采用“Unicode 规范化 + 领域词典最长匹配 + `Intl.Segmenter` 中文 word segmentation + 英文/枚举/数字/单位保留”的受控策略：

- NFKC、空白和大小写归一化；
- 领域词典先保护 `每侧次数`、`gram_per_kg`、动作 key 等完整 term；
- 其余中文由 `Intl.Segmenter` 分词；
- 英文连字符、下划线、数字和单位保留规范化变体；
- 输出 raw query、canonical concepts、tokens、phrases、translations、exercise keys 和 reviewed aliases；
- ingestion 与 runtime 使用同一词表版本，并通过 golden fixture 验证输出等价。

不允许用模型临时生成的同义词直接写回词典。新 alias 必须进入版本化文件、经过评测并可回滚。

### 5.3 Text embedding

- 只对稳定 Document RAG chunks 建立向量。
- 当前发布模型固定为新加坡区 Qwen `text-embedding-v4`，dense dimension 固定为 1536；这是独立于 `FITLOG_QWEN_MODEL` 的检索模型，不是第二个生成/Vision 模型。
- Embedding input 固定为：language + authority/status + heading path + canonical terms + lossless content。
- 模型名、dimension、input format version、content hash 和 generated time 全部持久化。
- Runtime query embedding 使用同一模型/维度，向量只在请求内存中使用，不长期保存用户问题 embedding。
- 更换模型、dimension、chunker 或 embedding input version 必须全量重建，不允许新旧向量混搜。
- 复用服务端 `FITLOG_QWEN_API_KEY`，不新增 embedding secret；从现有 Singapore `FITLOG_QWEN_BASE_URL` 的 `/compatible-mode/v1` 根路径派生 `/embeddings`，不要求重复 endpoint 配置。离线 corpus 与 runtime query 请求均显式锁定 1536 dimension。
- Alibaba Cloud Model Studio [`text-embedding-v4` 文档](https://www.alibabacloud.com/help/en/model-studio/embedding)与 [Singapore 同步 Embedding API](https://www.alibabacloud.com/help/en/model-studio/text-embedding-synchronous-api)为实现依据；OpenAI-compatible 路径每批最多 10 条，response 必须校验 model/count/order/dimension/finite values。
- Embedding failure 可以降级到 lexical hybrid，但只有 vector 已实际部署、回填、通过 eval，才允许把本轮标为完成。

### 5.4 Hybrid retrieval 与 reranker

第一次检索并行生成以下分支：

1. exact canonical concept / enum / exercise key；
2. exact phrase 和 heading phrase；
3. 中文 tokens / reviewed aliases term overlap；
4. PostgreSQL full-text；
5. trigram；
6. vector cosine similarity。

数据库返回各分支原始分数和匹配 metadata，Edge 先做 Reciprocal Rank Fusion，再执行第二阶段确定性 feature reranker。Reranker 不是另一个自由回答模型；它使用固定版本公式综合：

- exact official term、enum、exercise key；
- normalized term coverage；
- heading/heading-path match；
- vector similarity；
- language、authority、status；
- source diversity 与问题所需维度；
- planned/historical/local/non-goal penalty；
- 同一 chunk 和相邻 chunk 去重/合并。

Reranker 所有 feature、权重、版本、入选/淘汰原因都可测试。未来若换成 learned reranker，必须通过同一 eval Gate，不能静默替换。

### 5.5 检索规模初始常量

这些值作为实现初始值，W9 可依据固定 eval 调整；任何调整必须写入报告而不是凭感觉：

| 参数 | 初始值 |
| --- | ---: |
| exact/phrase branch candidates | 20 |
| token/FTS branch candidates | 30 |
| trigram branch candidates | 20 |
| vector branch candidates | 30 |
| 去重后最大 candidates | 60 |
| rerank 输入上限 | 24 |
| 最终 source top-k | 6 |
| 单 chunk Prompt excerpt 上限 | 900 characters |
| Document Context 总字符软上限 | 6,000 characters |
| search executions | 1 + 最多 1 retry |
| retry query variants | 最多 3 |

### 5.6 模型可调用检索工具

工具名固定为 `search_fitlog_docs`。工具只接受：

- `query`；
- `language`；
- `required_dimensions`；
- 最多 3 个受限 query variants；
- 可选 canonical concepts / exercise keys。

服务端忽略或拒绝 corpus、表名、SQL、limit 越界、用户账号范围和任意 Context 请求。OpenAI/Qwen adapter 可使用 provider-native tool call；若 provider 当前不支持等价 native call，必须使用同一严格 JSON tool-request envelope，不能退化为让模型输出 SQL 或自由文本指令。

### 5.7 一次 Agentic retry

首次结果经过 deterministic coverage checker。只有以下 reason code 才能进入 retry：

- `no_results`；
- `score_below_threshold`；
- `partial_dimension_coverage`；
- `missing_algorithm_rule`；
- `missing_exercise_definition`；
- `source_conflict`；
- `unreliable_authority_or_status`。

Retry 模型只看到问题、首次 query/normalized terms、source metadata、bounded excerpts、coverage 和 missing dimensions；它可以返回 `stop` 或一次新的 `search_fitlog_docs` 调用。第二次后无论结果如何都停止。无证据时输出 `insufficient_evidence`，不能继续猜词或使用模型常识冒充 FitLog 规则。

### 5.8 前置 Task/Context Planning

新增 `task_plan.v1`。确定性高置信规则优先；规则主动 abstain 后，受限模型 planner 读取当前消息、当前图片、紧凑 same-chat Context 和 request-scoped exercise references。Planner 只能申请 Context，服务器按 policy 重新验证。

Workflow 至少区分：

- `general_chat`；
- `food_logging`；
- `workout_logging`；
- `meal_decision`；
- `weekly_review`；
- `app_logic_answer`；
- `safety_boundary`。

“workflow/context planning”与“final output family validation”使用不同术语和类型，避免再次把两层含糊地都叫 intent routing。

合同中必须拆开三种 enum，不能继续用一个 `WorkflowType` 同时承担全部含义：request `workflow_hint` 允许 `auto|food_logging|workout_logging|meal_decision|weekly_review|app_logic_answer`；内部 `PlannedWorkflow` 使用上面的完整七类；public response `workflow` 返回最终 approved workflow，包括 `general_chat` 和 `safety_boundary`。旧客户端把 workflow 当字符串/未知值走保守 UI，不能因此拒绝整个成功响应。

### 5.9 动作 Context 与自定义动作边界

- 内置动作：Dart `ExerciseCatalog` 仍是 canonical definition；构建工具生成版本化服务端 snapshot，CI 比较 count/key/hash 防止 drift。
- 官方中文动作名：从当前 App 显示映射提取到可复用 catalog localization，App UI 和 snapshot 共用，不在服务端手抄第二份。
- Reviewed aliases：放入版本化 bilingual alias 文件，由 client matcher、server resolver 和 eval 共用。
- 自定义动作：Flutter 仅在当前问题命中时发送最多 4 个最小 references；服务端严格校验并标记 `client_local_custom`。
- 动作历史：只从当前账号云端正式 workout sessions/sets 做 bounded summary，需要 record-summary permission。
- 不新增云端 `custom_exercises` 全量同步表。

### 5.10 Evidence-grounded output

仅靠 Prompt 文字提醒不足以证明 claim/evidence 一致。内部 provider envelope 升级为可验证的 answer segments：

- `fitlog_rule`：必须引用一个或多个有效 Document/Structured/Deterministic evidence ID；
- `general_knowledge`：不得伪装成 FitLog 当前规则；当用户问的是 FitLog 而证据不足时必须带 limitation；
- `limitation`：引用 missing dimension/retrieval issue；
- `user_action`：只描述可确认的 UI 步骤，不能声称已写入。

Gateway 从通过验证的 segments 组装公开 `message.text`。引用不存在、status 不允许、claim scope 不匹配或 FitLog claim 无引用都属于 output-invalid，可使用现有一次 correction；再次失败返回稳定错误/限制，不放行普通文本。

### 5.11 Rollout 开关

只新增两个必要开关：

- `AI_CONTEXT_PIPELINE_VERSION=phase5_legacy|rag_foundation_v1`：整体 planner/context/retrieval 回滚。
- `DOCUMENT_RAG_RETRY_ENABLED=true|false`：单独关闭额外检索，以便控制故障、费用或延迟。

Completion 时生产默认必须是 `rag_foundation_v1`。Legacy 路径只能在 canary/rollback 窗口保留，最终删除时间由 W11 记录。

新增两个与 Food 路径直接相关、可独立回滚的开关：

- `AI_CAPABILITY_PIPELINE_VERSION=legacy|capability_v1`：控制共享 Capability/Provider/Validation 分层；完成时默认 `capability_v1`。
- `OPENAI_FOOD_VISION_ENABLED=true|false`：只控制专用图片页/Chat 图片 Food Draft 是否允许选择 OpenAI，不得改变 Qwen 或 text-only Chat；OpenAI adapter、模型配置和 canary 未通过前默认 false。

### 5.12 Provider Adapter 边界

统一 adapter interface 至少暴露：provider id、model id、capability flags（text/image/strict-schema/json-mode/tools）、deadline、`generateStructured()`、completion status 和 usage metadata。Adapter 可以根据 provider 能力选择 native JSON Schema、JSON Mode、Responses/Chat Completions 或 tool encoding，但不得：

- 决定 workflow/output family/目标语言；
- 修改 Food/Workout 字段语义或事实优先级；
- 自行读取 RAG/Structured Context；
- 静默切换 provider/model；
- 放宽 shared validator；
- 生成正式写入或用户终态。

现有 `ai-chat-route/openai_provider.ts`、`qwen_provider.ts` 和专用 Food endpoint 的 Qwen transport 逐步收敛到共享 adapter contract；迁移期间允许薄 wrapper，但 wrapper 只能做类型/调用兼容，不能保留第二套业务 Prompt。

### 5.13 Food understanding 与事实优先级

Selected provider 的第一步严格返回 `food_understanding.v1`，内容只描述本次输入，不生成正式记录：

1. 保留用户明确陈述的食物、重量、份量、食用比例、营养值、烹饪方式和排除/修正；每条保留 normalized value/unit、target item、来源和 bounded source span/hash。
2. 包装/OCR 明确信息与图片视觉观察分开，不能把视觉猜测标成标签事实。
3. 模型假设、待估算字段、冲突和无法绑定的事实显式列出。
4. Server 按 `user_explicit > package_or_ocr > visual_observation > model_estimate` 生成 approved facts；高优先级冲突不由 adapter 或 Draft generator 擅自覆盖。
5. Draft generator 只估算 approved facts 仍缺失的字段，并把估算/假设写入目标语言 notes。

不为自然语言的每个可能句式写业务规则。模型负责语义解析；确定性代码负责 typed contract、unit/target binding、来源优先级、冲突和 draft 对齐。

### 5.14 Food language/semantic Gate

- Surface 明确传入 `response_language`；专用页面来自当前 App language，AI Chat 来自 Chat language policy。
- Shared policy 根据语言生成 capability instruction；专用 Surface 不复制 Chat intent/context 指令，Chat Surface 也不覆盖 fixed Food 规则。
- Validator 检查普通 user-facing string 的主语言；品牌/型号/专有名词允许原文，并通过 allow-reason 标记。
- 每个 approved `user_explicit` fact 必须绑定到 draft item/meal 字段或 unresolved issue；不能只出现在 notes。
- notes、item、meal、事实 ledger、日期、单位和 totals 必须一致。
- macro/kcal 使用版本化 plausibility tolerance；只产生 issue/review，不能覆盖明确包装标签。
- Semantic issues 与 schema issues 共享最多一次 correction budget，但 telemetry 必须区分 `structural`、`language`、`fact_conflict`、`nutrition_consistency`、`grounding`。

### 5.15 专用图片页独立 Provider 选择

- 使用独立 preference key，例如 `fitlog.food_analysis.selected_provider`；不得读取或写入 AI Chat 的 `fitlog.ai.selected_provider`。
- 默认值必须与当前已部署行为兼容：Qwen；只有用户主动选择才改为 ChatGPT。
- 切换 Provider 不清空当前图片/文字，不创建 Chat session，不改变日期或 Preview 流程。
- 当前 provider 不支持输入类型或 feature flag 关闭时，选项显示真实不可用状态；不得自动改选另一 provider。
- 新 UI 文本使用 App theme typography 和双语 strings；小屏、键盘、横向空间、loading/disabled/error 都有 widget test。

## 6. 新增/修改的核心合同

以下 shape 是计划级锁定合同。实施时可以补充严格 bounds，但不能删除其语义。

### 6.1 `document_corpus_manifest.v1`

候选文件：`tool/phase5_document_rag/document_corpus_manifest.v1.json`

```json
{
  "schema_version": "document_corpus_manifest.v1",
  "corpus_id": "fitlog_stable_docs_v1",
  "authority": "current_product",
  "include": [
    "README.md",
    "docs/en/*.md",
    "docs/zh/*.md"
  ],
  "required_bilingual_basenames": [
    "Product.md",
    "AppGuide.md",
    "Methodology.md",
    "Algorithm.md",
    "Database.md",
    "CloudLocalDataBoundary.md",
    "AgentDesign.md",
    "AIOutputContract.md",
    "RAGDesign.md",
    "References.md"
  ],
  "exclude": [
    "docs/local/**",
    "docs/history/**",
    "docs/ROADMAP.md",
    "docs/API_CONTRACT_DRAFT.md",
    "CHANGELOG.md",
    "**/*ENGINEERING_PLAN.md"
  ]
}
```

Manifest resolver 必须展开 glob 后输出排序后的实际文件列表和 manifest hash；不能因为文件缺失就静默 `continue`。

### 6.2 `domain_terms.v1`

候选文件：`assets/rag/domain_terms.v1.json`

每个 concept 至少包含：

```json
{
  "concept": "per_side_reps",
  "official": {
    "zh": "每侧次数",
    "en": "Per-side reps"
  },
  "aliases": {
    "zh": ["单侧次数", "单边次数", "每边次数"],
    "en": ["reps per side", "unilateral reps"]
  },
  "internal_values": ["per_side_reps"],
  "do_not_merge_with": ["total_reps"],
  "version": 1
}
```

至少覆盖：load/reps/set metric 全部枚举、饮食模式/阶段/策略、RAG/Agent 权限术语、动作官方中英文名和 reviewed aliases。

### 6.3 Document chunk/cloud schema

在现有 `document_chunks` 上 additive 增加：

- `corpus_id text not null`；
- `authority text not null`；
- `source_version text not null`；
- `manifest_hash text not null`；
- `term_dictionary_version text not null`；
- `search_tokens text[] not null`；
- `canonical_terms text[] not null`；
- `embedding vector(1536)`；
- `embedding_model text`；
- `embedding_dimension integer`；
- `embedding_input_hash text`；
- `embedding_generated_at timestamptz`。

新增 `document_corpus_builds` 记录 corpus build：build id、manifest/chunker/term/embedding version、source count、chunk count、embedded count、build status、generated/deployed time。该表只存文档构建 metadata，不存用户数据。

旧 RPC 保留到新 Edge canary 结束；新增 `search_document_chunks_hybrid`，返回每个 candidate 的分支分数、matched terms、source metadata 和 fusion score。

### 6.4 `task_plan.v1`

```json
{
  "schema_version": "task_plan.v1",
  "workflow": "workout_logging",
  "expected_output": "workout_draft",
  "allowed_output_families": ["workout_draft", "clarification"],
  "entities": {
    "exercise_mentions": [
      {
        "surface": "保加利亚分腿蹲",
        "candidate_keys": ["bulgarian_split_squat"],
        "resolution": "resolved"
      }
    ],
    "date_mentions": []
  },
  "requested_context": ["exercise_definition_context"],
  "retrieval_needs": ["workout_input_semantics"],
  "clarification_needs": [],
  "confidence": 0.96,
  "source": "deterministic"
}
```

Server policy validation 必须输出 approved/rejected Context 和 reason codes；模型请求本身不直接驱动数据库读取。

### 6.5 `exercise_reference.v1`

Flutter request 可选字段使用数组，最大 4 个：

```json
{
  "schema_version": "exercise_reference.v1",
  "key": "custom_...",
  "source": "custom",
  "official_name": "我的单腿蹲",
  "aliases": [],
  "exercise_type": "strength",
  "body_part": "Legs",
  "secondary_body_part": null,
  "strength_structure": "compound",
  "strength_profile": "lower_body_compound",
  "load_input_mode": "total_load",
  "reps_input_mode": "per_side_reps",
  "set_metric_type": "reps",
  "default_cardio_intensity": null,
  "definition_hash": "sha256:..."
}
```

约束：

- key/name/alias 长度、数组数量、enum、嵌套深度和序列化大小有硬上限；
- `source` 仅允许 `custom`；客户端不发送内置完整定义；
- 只接受当前 message 或 approved same-chat entity reference 命中的定义；
- 日志只保存是否提供、数量、source 和 hash 前缀，不保存完整本地动作名/定义；
- 该对象不能扩大账号、记录或工具权限。

### 6.6 `exercise_definition_context.v1`

```json
{
  "type": "exercise_definition_context",
  "version": "v1",
  "source": "builtin_catalog_snapshot",
  "data": {
    "matches": [
      {
        "key": "bulgarian_split_squat",
        "name_en": "Bulgarian Split Squat",
        "name_zh": "保加利亚分腿蹲",
        "source": "builtin",
        "exercise_type": "strength",
        "body_part": "Legs",
        "strength_structure": "compound",
        "strength_profile": "lower_body_compound",
        "load_input_mode": "total_load",
        "reps_input_mode": "per_side_reps",
        "set_metric_type": "reps",
        "definition_hash": "sha256:..."
      }
    ]
  },
  "missing": [],
  "privacy": {
    "contains_raw_records": false,
    "contains_images": false,
    "contains_user_free_text_notes": false
  }
}
```

同名、多候选或 key/name 冲突时 `matches` 不得自行选一个，必须产生 `ambiguous_exercise_reference` clarification。

### 6.7 `exercise_history_context.v1`

只包含 bounded aggregates：

- exercise key/name/source；
- requested date range、实际 coverage；
- session count、completed set count；
- 最近若干 session 的日期级 compact summary，上限由 policy 固定；
- input/calculation load/reps 的聚合或最近值；
- volume trend 和模式 snapshot；
- missing/permission/source-version metadata。

禁止包含完整 set rows、notes、无关动作、完整 workout history。

### 6.8 `retrieval_result.v1`

内部结果至少包含：

- request/retrieval id；
- search attempt `1|2`；
- raw/normalized query categories；
- language/corpus/authority；
- term/segment/embedding/reranker versions；
- branch hit counts；
- candidate scores；
- final sources 和 stable evidence IDs；
- matched terms；
- coverage dimensions；
- missing dimensions；
- retry eligible/reason；
- latency/token/cost metadata；
- failure/downgrade issues。

公开 evidence 只暴露安全子集；debug logs 也不得保存完整原始用户问题或 chain-of-thought。

### 6.9 内部 grounded answer envelope

候选内部版本：`ai_chat_response.v3`。

```json
{
  "schema_version": "ai_chat_response.v3",
  "output_type": "text",
  "answer_segments": [
    {
      "text": "保加利亚分腿蹲在 FitLog 中按每侧次数录入。",
      "claim_scope": "fitlog_rule",
      "evidence_refs": ["ctx:exercise:bulgarian_split_squat"]
    },
    {
      "text": "输入 12 时界面保留 12，但计算次数标准化为 24。",
      "claim_scope": "fitlog_rule",
      "evidence_refs": ["doc:algorithm:strength-volume", "ctx:exercise:bulgarian_split_squat"]
    }
  ],
  "draft": null,
  "needs_clarification": false,
  "clarification_questions": []
}
```

Gateway 拼接 segments；不直接把 evidence ID 插进用户 Markdown，Answer Basis 使用同一 verified evidence list。

### 6.10 Workout Draft `v3` 动作绑定

当前客户端升级为 `workout_draft.v3`，每个 exercise 增加受验证的 `exercise_reference`：

- stable key；
- source `builtin|custom`；
- canonical name；
- definition hash/version；
- input-mode snapshot；
- resolution status。

新客户端必须：

1. 按 key + source 查找内置/本地 custom definition；
2. 找到且 hash/关键枚举一致时绑定当前定义；
3. 本地 custom 已删除但 artifact 有已验证 snapshot 时，使用 snapshot 并提示用户确认；
4. key/name/mode 冲突时禁止静默 fallback，要求确认或重新选择动作；
5. 不再由 `_adHocKey()` 自动掩盖未解析动作；
6. review 后仍进入现有 workout editor，正式保存逻辑不变。

Legacy v2 只用于旧客户端过渡；服务端不得向 v2 客户端发送一个无法安全绑定但看似成功的 draft，应返回 clarification。兼容窗口结束后由 W11 决定删除 legacy fallback。

### 6.11 `ai_capability_request.v1`

内部 normalized request 由 Surface 构建、由 Capability Core 消费，不直接接受客户端伪造：

```json
{
  "schema_version": "ai_capability_request.v1",
  "surface": "food_photo_analysis",
  "capability": "food_draft",
  "response_language": "zh",
  "provider_choice": "qwen",
  "selected_date": "2026-07-13",
  "input_refs": {
    "has_user_text": true,
    "image_count": 1
  },
  "approved_context_types": [],
  "policy_version": "food_capability.v1"
}
```

约束：

- `surface`、`capability`、`response_language`、provider capability 和 approved Context 由服务端/可信 Flutter Surface contract 确认；Provider Adapter 不重新推断。
- Raw text/image 作为 request-scoped payload 单独传递，不复制进 telemetry object。
- 专用 Food Surface 的 `approved_context_types=[]`，不因 Provider 选择而开启 RAG/记录摘要。
- AI Chat Food path 只能携带 Task/Context Policy 已批准的 bounded types。

### 6.12 `food_understanding.v1`

候选内部合同：

```json
{
  "schema_version": "food_understanding.v1",
  "response_language": "zh",
  "items": [
    {
      "item_ref": "item:shake",
      "display_name": "高蛋白奶昔",
      "facts": [
        {
          "concept": "protein_g",
          "value": 20,
          "unit": "g",
          "source": "user_explicit",
          "source_ref": "user_text:span_hash",
          "confidence": 1.0,
          "status": "approved"
        }
      ],
      "observations": [],
      "estimation_needs": ["weight_g", "calories_kcal", "carbs_g", "fat_g"]
    }
  ],
  "unresolved_facts": [],
  "conflicts": []
}
```

`source` 固定为 `user_explicit|package_or_ocr|visual_observation|model_estimate`。`source_ref` 只保留 request-scoped bounded reference/hash；不进入长期 debug log。模型不得把同一事实同时标为 explicit 和 estimate。Server normalization 输出 approved/rejected/conflict reason codes，Draft generator 只接收 approved facts 和 estimation needs。

### 6.13 `food_semantic_validation.v1` 与 Surface 终态

内部 validator result：

```json
{
  "schema_version": "food_semantic_validation.v1",
  "status": "failed",
  "issues": [
    {
      "code": "user_fact_mismatch",
      "fact_ref": "item:shake/protein_g",
      "draft_path": "$.draft.items[2].protein_g"
    }
  ],
  "correction_eligible": true
}
```

公开终态保持 Surface-specific：

- AI Chat：现有 `food_draft|clarification|error` envelope 和 artifact UX；
- 专用页面：`draft` 或 `input_revision_required/error`。混合部署期间可以继续用 `needs_clarification=true` + `clarification_questions` wire shape，但 Flutter 必须把它解释为返回原表单修正，不能创建 Chat turn。

Issue codes 至少包括：`response_language_mismatch`、`user_fact_omitted`、`user_fact_mismatch`、`fact_source_precedence_violation`、`notes_field_conflict`、`item_meal_totals_mismatch`、`nutrition_consistency_unexplained`、`unresolved_food_conflict`。Issue 只描述可修正的输出问题，不包含 chain-of-thought 或完整用户文本。

## 7. 施工包总览与依赖

本计划使用 `W0-W11` 表示本轮施工包，避免与 Roadmap 的 Phase 1-7 混淆。

| 施工包 | 主题 | 主要依赖 | 完成后解锁 |
| --- | --- | --- | --- |
| W0 | 基线冻结、执行控制和失败复现 | 无 | 全部后续工作 |
| W1 | 全量 Markdown 事实审计与双语术语 | W0 | W2、W4、W7、W10 |
| W2 | Canonical manifest 与 lossless chunker | W0、W1 的术语初版 | W3、W4 |
| W3 | pgvector、embedding schema、回填与 parity | W2 | W4、W9 |
| W4 | 中文 normalization、hybrid、fusion、reranker | W1-W3 | W5、W9 |
| W5 | 检索工具、coverage 和一次 Agentic retry | W4 | W8、W9 |
| W6 | 前置 Task/Context Planner 与 policy | W0；可与 W2-W4 局部并行开发 | W7、W8 |
| W7 | 动作 catalog snapshot、custom reference、history、draft binding | W1、W6 | W8、W9 |
| W8 | Grounded output、Provider-independent Capability、Food semantic reliability、API/UI/observability | W4-W7；Food 子路径可在 W0/W6 contract 稳定后并行 | W9、W10 |
| W9 | 全面 deterministic/live eval 与阈值校准 | W1-W8 | W10 |
| W10 | 文档收口、云端部署、canary 和人工验收 | W9 | W11 |
| W11 | 兼容清理、状态同步、归档和最终移交 | W10 | COMPLETE |

禁止跳过规则：

- W3 未证明 vector freshness/parity，不得把 hybrid 标为完成。
- W4 未通过检索 eval，不得开始生产 canary。
- W6 未完成，不能仅在旧 route 上“顺手增加动作 builder”并宣布动作 Context 完成。
- W7 未完成确定性绑定，Workout Draft 仍视为存在发布阻断。
- W8 未实现 claim/evidence guard，不能只靠 Prompt 文案通过 faithfulness 验收。
- W8 未实现共享 Food Capability、语言/事实 semantic Gate 和双 Provider adapter，不得把专用图片分析或 AI Chat Food Draft 标为可靠。
- W9 不是可选 Phase 6 工作，而是本轮完成 Gate。

## 8. W0 - 基线冻结、执行控制与失败复现

### 8.1 目标

在修改任何业务逻辑前固定可重复基线、保护已有行为、建立追踪和 rollback 控制。

### 8.2 需要检查的文件

- `AGENTS.md`
- `RAG_FOUNDATION_REMEDIATION_SCOPE.md`
- 本计划
- `docs/history/phase5/PHASE5_ENGINEERING_PLAN.md`
- `docs/ROADMAP.md`
- 当前 Git status/diff
- 现有 Flutter、Edge、migration、seed 和目标 Supabase 部署状态

### 8.3 任务

1. 记录当前 commit、branch、dirty files；不得覆盖用户已有修改。
2. 运行现有基线：
   - `flutter analyze`
   - `flutter test`
   - Edge `deno check`
   - Edge deterministic tests
   - 当前 chunk generator
3. 保存当前 generated chunk count、source paths、generator version 和目标云端 `document_chunks` count/hash 分布。
4. 用 deterministic test/fixture 重现至少以下失败：
   - “每侧次数”无法命中正确 stable source；
   - `CloudLocalDataBoundary.md` 不在 seed sources；
   - generated content 含 `. dart` / `. sql` / spaced URL；
   - Workout Draft 识别发生在 Context Builder 后；
   - Bulgarian Split Squat 动作属性不在 server Context；
   - 自定义动作无法作为 request-scoped Context；
   - 未找到文档仍可能产生 FitLog 确定性回答；
   - `_adHocKey + total_load + total_reps` fallback。
   - 中文专用食物描述返回英文或中英混合 meal/item/notes，且当前 validator 仍通过；
   - 用户明确“奶昔含 20g 蛋白质”，notes 承认 20g 但 `protein_g=8.5` 仍进入 Preview；
   - 专用页面把 clarification 当错误通知，无法形成 Chat 式追问；
   - 专用页面固定 Qwen，OpenAI adapter 拒绝 image request；
   - Chat/专用端点对 Food 语言、事实、估算和 Provider 映射使用不同实现。
5. 在实现代码中加入但默认不开启：
   - `AI_CONTEXT_PIPELINE_VERSION`
   - `DOCUMENT_RAG_RETRY_ENABLED`
6. 建立本计划“实施偏差记录”和每个 W 的状态，不得预先勾选 Scope checklist。

### 8.4 建议新增测试/fixture

- `supabase/functions/ai-chat-route/rag_foundation_baseline_test.ts`
- `tool/phase5_document_rag/fixtures/chunk_fidelity_cases.json`
- `test/ai_workout_draft_binding_test.dart`
- `test/evals/fixtures/food_capability_regressions.v1.json`
- 扩展 `supabase/functions/ai-food-photo-analyze/index_test.ts` 与 `test/photo_food_analysis_page_test.dart`

基线失败测试可以先标为 expected failure 或放入独立 fixture runner，但不能污染主测试常绿；W2/W6/W7/W8 分别把它们转为正式回归测试。

### 8.5 Gate W0

- 现有测试基线结果已记录。
- 原八类 RAG/动作问题和新增五类 Food/Provider 问题都有可复现证据。
- 两个 rollout 开关有明确默认值和读取失败行为。
- 没有改动生产行为。
- Git diff 只包含基线 fixture/plan/必要 flag scaffolding。

### 8.6 回滚

W0 不改变生产行为；删除未接线 flag scaffolding 和临时 fixture 即可。不得删除已确认范围/计划文件。

## 9. W1 - 全量文档事实审计与双语术语

### 9.1 目标

先修复知识源，再优化检索。不能让更强检索更稳定地返回错误或不完整文档。

### 9.2 文档审计范围

对仓库全部 Markdown 分类：

- stable current source of truth；
- public/current wire contract；
- historical implementation context；
- roadmap/active plan；
- Local frozen baseline；
- changelog；
- asset/tool README；
- generated/third-party note。

必须比较：

1. `docs/local/` 的 Local 产品/算法/数据库事实；
2. `docs/FitLog_Agent_V1_Implementation.md` 的初始目标与历史决定；
3. 当前双语 stable docs；
4. 当前 Flutter/Dart 实现；
5. 当前 Supabase schema/Edge 实现；
6. 当前 API contract、Roadmap 和 Changelog。

### 9.3 审计分类字段

每个 meaningful block 记录：

- source path/heading；
- 类型：canonical fact、rationale、user behavior、implementation、migration、failure、historical、rollout、evidence、duplicate；
- 当前 owning document；
- Local/Agent/current/planned 状态；
- 是否双语一致；
- 是否与代码一致；
- 动作：保留、重写、移动、删除重复、待确认；
- 代码/测试证据；
- 对应 Scope ID。

完成时生成：`docs/history/phase5/RAG_FOUNDATION_REMEDIATION_DOCUMENT_AUDIT.md`。它记录 before/after 与未决项，不成为用户 Document RAG source。

### 9.4 术语任务

1. 创建 `assets/rag/domain_terms.v1.json`。
2. 为所有 concept 写官方 zh/en、aliases、internal values、do-not-merge。
3. 至少覆盖：
   - 总重量、每侧重量、自重加重、辅助重量；
   - 总次数、每侧次数、单组时长；
   - `total_load`、`per_side_load`、`bodyweight_added`、`assistance_load`；
   - `total_reps`、`per_side_reps`、`duration_seconds`；
   - `energy_ratio`、`gram_per_kg`、`diet_goal_phase`；
   - carb cycling/tapering；
   - account/subscription/profile/cloud/local/cache/source-of-truth；
   - output family、draft、confirmation、evidence、RAG；
   - 内置动作 key/官方中英文名与 reviewed aliases。
4. 把 `AppStrings.exerciseDisplayName` 中内置动作中文名迁移到可由 `ExerciseCatalog`、App UI 和 export tool 共用的 canonical localization map。
5. 测试 App 官方标签与术语表 official values 一致。
6. 测试 `per_side_reps` 不会和 `total_reps` 合并。

### 9.5 Stable docs 更新责任

本包先写准确内容，但正式“已实现 hybrid”措辞只在 W10 与部署同步。至少审查并同步：

- `docs/en|zh/Product.md`：用户可见动作录入口径和 Agent 边界摘要。
- `docs/en|zh/AppGuide.md`：自定义动作、每侧输入、AI Chat draft/review 行为。
- `docs/en|zh/Methodology.md`：为什么保留 raw input 并标准化计算值。
- `docs/en|zh/Algorithm.md`：`calculation_load_kg`、`calculation_reps`、volume 公式和示例。
- `docs/en|zh/Database.md`：现有字段语义、document embedding metadata（W3 落地后）。
- `docs/en|zh/CloudLocalDataBoundary.md`：自定义动作 request-scoped 引用、云端历史权威。
- `docs/en|zh/AgentDesign.md`：planner/tool/context/write/privacy 权限。
- `docs/en|zh/AIOutputContract.md`：grounded answer、draft v3、correction 边界。
- `docs/en|zh/RAGDesign.md`：最终检索架构、corpus、failure、eval。
- `docs/en|zh/References.md`：只补充真正支持的方法来源和窄 claim。
- `docs/API_CONTRACT_DRAFT.md`：当前 public wire fields。
- `README.md`：只保留产品级摘要和文档导航，不复制工程计划。

### 9.6 重点算法示例

Algorithm 双语文档和 tests 必须包含：

```text
Bulgarian Split Squat
input_reps = 12
reps_input_mode = per_side_reps
display/input value = 12 per side
calculation_reps = 24
totalVolumeKg += effectiveCalculationLoadKg * 24
```

同时说明如果重量本身又是 `per_side_load`，重量和次数各自按各自 mode 标准化；不得把所有单侧动作一概双乘重量和次数。

### 9.7 测试

- machine terminology JSON schema/duplicate/alias collision tests；
- AppStrings official label snapshot tests；
- bilingual heading/meaning checks；
- stable doc code-reference link checks；
- Local-only/planned/stale wording scan；
- formula field-name consistency scan。

### 9.8 Gate W1

- 全部 Markdown 有分类结果。
- 每个删除/移动都有 destination/reason。
- 双语 stable docs 的动作录入口径、公式和边界一致。
- “每侧次数”及其官方英文/内部枚举都在稳定 corpus 源和 machine terminology 中。
- App UI 官方词与 machine terminology 无 drift。
- 未把 Local 冻结文档当成 Agent 当前事实。

### 9.9 回滚

文档 refactor 按 owning file 独立回滚；不得回滚已经证实的当前事实。若某项权威仍不明确，保留原文并在 audit 标记 unresolved，不可静默删除。

## 10. W2 - Canonical manifest 与 lossless Markdown-aware chunker

### 10.1 目标

保证“源文档内容是什么，chunk 就保真携带什么”，并让 corpus 漏文件成为测试失败。

### 10.2 候选文件

- 修改 `tool/phase5_document_rag/build_document_chunks.mjs`
- 新增 `tool/phase5_document_rag/document_corpus_manifest.v1.json`
- 新增 `tool/phase5_document_rag/chunk_markdown.mjs`
- 新增 `tool/phase5_document_rag/validate_document_corpus.mjs`
- 新增 `tool/phase5_document_rag/build_document_chunks_test.mjs`
- 新增 `tool/phase5_document_rag/fixtures/*`
- 更新 `supabase/seed_phase5_document_chunks.sql`

文件可以更少，但 parser、manifest、validation 必须可单测，不能继续只靠运行一个大脚本后肉眼看 SQL。

### 10.3 Parser/chunker 要求

1. 以 Markdown block 为单位解析 heading、paragraph、list、blockquote、table、fenced code。
2. 不在以下 token 内切分或插入空格：
   - Markdown link label/target；
   - URL/email；
   - inline/fenced code；
   - 文件路径和扩展名；
   - internal enums；
   - 小数、版本号、日期、reference ID；
   - table cell。
3. 超长 section 先按 block，再按句子边界切分；hard split 只能发生在普通文本 safe range。
4. 相邻 chunks 带最小 reviewed overlap 或 heading context，不复制整个 section。
5. 稳定 ID 不依赖绝对路径、时间或随机数；相同 source+heading+content 生成相同 ID。
6. Heading 重名通过 heading path/ordinal/content hash 消歧。
7. README 双语 section 按 heading/内容决定语言；不能把中英文混成错误 language。
8. 每个 chunk 存 source hash、chunk hash、manifest hash、generator version 和 term version。
9. `status` 只能从明确 heading/leading marker 或 owning document authority 产生，不能因正文提到 future/non-goal 就误标整个 chunk。
10. Manifest required file 缺失、双语不配对或出现未授权 source 时立即非零退出。

### 10.4 Corpus replacement

当前 seed 只删除当次 source path，source 从 allowlist 移除时可能留下 stale row。新 seed 必须按 `corpus_id` 完整替换 managed corpus：

```text
begin
  mark corpus build staging
  delete/replace all rows for corpus_id + target build
  validate expected source/chunk count
  activate build atomically
commit
```

如采用同表 build id 双版本切换，查询只读 active build；不得在半写入状态暴露混合 corpus。

### 10.5 自动测试

Fixtures 至少包含：

- `[OpenAI](https://developers.openai.com/...)`；
- `CHANGELOG.md`、`app_database.dart`、`index.ts`、`.sql`；
- `gram_per_kg`、`per_side_reps`；
- `0.85`、`v1.2.3`、`2026-07-13`；
- 中文标点、英文句号、括号和表格；
- fenced JSON/SQL/Dart；
- 同名 headings；
- 单一超长 URL/code token；
- bilingual README；
- CloudLocalDataBoundary source coverage。

断言：

- source substring 可在按顺序拼接的 chunk contents 中恢复；
- protected token byte-for-byte 保真；
- 无 `. dart`、`. ts`、`. sql`、spaced hostname 禁止模式；
- 无重复 stable ID、无空 chunk、无漏 source；
- 同输入重复生成完全相同的 normalized output/hash；
- CloudLocal 双语 chunks > 0。

### 10.6 Gate W2

- Manifest 与 required stable tree 完全一致。
- 当前 510 chunks 数量允许变化，但变化有 report 和原因。
- 所有 fidelity fixtures 通过。
- generated seed 禁止模式为 0。
- generator source list 不再散落在代码中。
- 本地 seed source paths 与 manifest 一致。

### 10.7 回滚

旧 generator/seed 保留在 Git 历史。生产未切换 active build 前可直接回滚；生产切换后使用上一 active corpus build id，不执行破坏性 table reset。

## 11. W3 - pgvector、embedding pipeline 与 corpus parity

### 11.1 目标

为稳定文档提供可重建、可检测 stale、可回滚的向量检索基础。

### 11.2 Supabase migration

候选 migration：

- `supabase/migrations/202607130001_rag_foundation_document_hybrid.sql`

内容：

1. `create extension if not exists vector`。
2. additive 增加 6.3 所列 chunk metadata/embedding columns。
3. 新增 `document_corpus_builds`。
4. 为 active corpus、language、authority/status、tokens 建 indexes。
5. 为 `embedding vector(1536)` 建 cosine HNSW/合适索引；以目标 Supabase 支持情况验证具体 operator class。
6. 新增 service-role-only staging/upsert/activate/search RPC。
7. anon/authenticated 无 table/RPC 直接权限。
8. 旧 `search_document_chunks` 暂时保留供 legacy pipeline rollback。
9. migration 可重复检查、不中断已有 lexical rows。

### 11.3 Embedding 同步工具

候选文件：

- `tool/phase5_document_rag/sync_document_embeddings.mjs`
- `tool/phase5_document_rag/embedding_client.mjs`
- `tool/phase5_document_rag/embedding_sync_test.mjs`

命令模式：

```text
--dry-run        列出 missing/stale/extra，不调用外部 API、不写云端
--build-local    对本地 chunk artifact 批量生成 embedding artifact
--sync-cloud     只向已确认 Supabase project 写入匹配 content hash 的 vectors
--verify-cloud   比较 manifest/build/chunk/vector/hash parity
```

要求：

- 显式读取 server-managed `FITLOG_QWEN_API_KEY`；不得把 key 写入文件/日志，也不读取 `OPENAI_API_KEY`/`FITLOG_OPENAI_API_KEY` 作为 Document RAG 前置条件。
- 从 Qwen Singapore compatible base 派生 `/v1/embeddings`，每批最多 10 条，输入不含用户记录。
- retry 仅处理 transport/rate-limit，次数和 backoff 有上限。
- 每个 response 验证 model、数量、dimension=1536、finite values。
- upsert 前验证 chunk id + embedding input hash；不允许错位。
- dry-run 输出 counts，不输出完整 chunk content。
- 中断后可幂等继续。
- stale vectors 必须重建，不能只看 `embedding is not null`。

### 11.4 Runtime query embedding

在 Edge 新增 bounded embedding client：

- 空查询不调用；
- 只发送 normalized query/variants，不发送 Structured Context 或用户历史；
- 使用与 corpus 相同的 Qwen `text-embedding-v4`、Singapore endpoint、1536 dimension 和服务端 Qwen credential；
- timeout 独立于 final provider timeout；
- response dimension/finite values 严格验证；
- failure 形成 `embedding_unavailable` issue，走 lexical branches；
- query vector 不写 DB/log。

### 11.5 测试

- migration 静态检查：extension、RLS/grants、function search_path、bounds；
- mock embedding batch order/dimension/non-finite/error tests；
- stale detection：content、chunker、term、model、dimension 任一变化；
- idempotent sync；
- cloud parity query fixture；
- vector search same-language/current-authority filter；
- embedding failure lexical downgrade。

### 11.6 Gate W3

- 本地所有 active chunks 有 matching embedding artifact。
- 目标云端 active build source/chunk/embedded count 完全一致。
- stale/mismatched vectors = 0。
- vector RPC 返回正确中文/英文 smoke result。
- anon/authenticated 不能直接读/写 document tables 或调用内部 admin RPC。
- 只运行 lexical fallback 不算完成。

### 11.7 回滚

- Edge 可切回 `phase5_legacy` RPC。
- DB additive columns/table/index 保留，不做 destructive down migration。
- active corpus build 切回上一个 build id。
- 关闭 runtime vector branch 不删除 embeddings，以便排障后恢复。

## 12. W4 - Query normalization、controlled hybrid 与 reranker

### 12.1 目标

把“同义词靠模型碰运气”改为可版本化、可测量的查询理解和多路召回。

### 12.2 候选文件

- 修改 `supabase/functions/ai-chat-route/document_rag.ts`
- 新增 `supabase/functions/ai-chat-route/rag/query_normalizer.ts`
- 新增 `supabase/functions/ai-chat-route/rag/retrieval_pipeline.ts`
- 新增 `supabase/functions/ai-chat-route/rag/retrieval_reranker.ts`
- 新增 `supabase/functions/ai-chat-route/rag/retrieval_coverage.ts`
- 新增 `supabase/functions/ai-chat-route/rag/types.ts`
- 新增对应 `*_test.ts`
- 修改 W3 migration 中的 hybrid RPC，或新增后续 additive migration

### 12.3 Normalization 输出

```text
raw_query
normalized_query
language_profile (zh/en/mixed + confidence)
protected_phrases
tokens
canonical_concepts
internal_values
translations
exercise_mentions/keys
query_variants
term_dictionary_version
```

规则：

- “每侧次数”“单侧次数” -> `per_side_reps`，同时保留原词；
- “总次数” -> `total_reps`，不得出现在 `per_side_reps` concepts；
- mixed query 同时允许 zh/en sources 作为次级 branch，但 answer language 不变；
- 首选当前问题语言的 stable source；跨语言 fallback 必须标记并只在同语言 coverage 不足时使用；
- 动作名归一不自动决定动作属性，属性必须来自 definition context。

### 12.4 Hybrid SQL/Edge 分工

Postgres：

- 执行各 branch candidate retrieval；
- 强制 corpus/language/authority/active-build filter；
- 返回原始 score/rank/matched terms；
- 不在 SQL 中隐藏最终综合公式。

Edge：

- 验证 rows/schema；
- RRF/score normalization；
- candidate dedupe；
- feature rerank；
- source diversity/context budget；
- coverage classification；
- 生成 debug-safe score metadata。

### 12.5 Reranker 约束

- 权重常量集中并带 `reranker_version`。
- Exact official concept/key 不能被泛语义相似 chunk 轻易压过。
- `implemented/current_product` 优先于 planned/historical/local。
- `non_goal` 只有在用户问边界时才是正 evidence，否则降权。
- 同一 heading 的相邻 chunks 可合并，但 evidence ID 保留。
- Reranker exception/invalid candidate 时退回 fused order并记录 `reranker_degraded`；不能返回伪造分数或空 evidence 冒充成功。

### 12.6 测试案例

至少包括：

- 每侧次数 / 单侧次数 / 单边次数 / 每边次数；
- per-side reps / reps per side / unilateral reps；
- 长句“保加利亚分腿蹲的每侧次数怎么算训练量”；
- `per_side_reps` internal enum；
- mixed “保加利亚 split squat reps per side”；
- 错误近邻“总次数”；
- Cloud/local/cache/source-of-truth；
- `gram_per_kg` 与 `energy_ratio`；
- planned/non-goal questions；
- 无答案问题；
- prompt injection-like query；
- embedding/vector failure；
- reranker failure。

### 12.7 Gate W4

- 官方词和批准 aliases 在 expected source top-3 100% 命中。
- `per_side_reps`/`total_reps` confusion 为 0。
- Hybrid report 能展示各 branch、fusion、rerank 前后排序。
- Reranker 相对 fused baseline 的关键集 top-1 不下降，整体达到 W9 阈值。
- Failure downgrade 不伪造 source。

### 12.8 回滚

通过 pipeline version 切回 legacy retrieval；保留 query/eval fixtures。若单一 branch 故障，可在 hybrid pipeline 内禁用该 branch 并留下 issue，但 production completion 必须恢复全部 mandatory branches。

## 13. W5 - `search_fitlog_docs` 工具、coverage 与一次 Agentic retry

### 13.1 目标

让模型能够在证据不足时提出一次更好的检索，而不是无限猜同义词或完全无法判断首次搜索质量。

### 13.2 候选文件

- `supabase/functions/ai-chat-route/rag/retrieval_tool.ts`
- `supabase/functions/ai-chat-route/rag/retrieval_retry.ts`
- `supabase/functions/ai-chat-route/rag/retrieval_coverage.ts`
- `supabase/functions/ai-chat-route/providers.ts`
- `openai_provider.ts`
- `qwen_provider.ts`
- provider mock 与 tests

### 13.3 Tool contract 实现

1. 定义 provider-independent tool schema。
2. OpenAI/Qwen adapter 将 schema 映射到 provider-native tool/function call；不能改变服务端可接受参数。
3. Tool request 先严格 parse，再做 server normalization/policy；模型给出的 canonical term 只是建议。
4. Tool implementation 永远只调用 W4 pipeline。
5. Tool response 返回 bounded metadata/excerpts，不返回 DB internals、SQL 或完整 docs。
6. 工具调用次数存于 request-local state；第二次后拒绝 `retrieval_attempt_limit_reached`。

### 13.4 Coverage checker

Coverage 不是简单看 `results.length > 0`，必须根据 Task Plan 的 required dimensions 检查：

- source authority/status；
- algorithm/product/database/privacy 等 required topic；
- exercise definition 是否存在；
- canonical concept 是否被覆盖；
- 冲突来源是否解决；
- top score/term coverage 是否达到校准阈值；
- sources 是否足以支持拟回答的 FitLog claim 类型。

输出 `complete|partial|insufficient|conflicting` 和 named missing dimensions。

### 13.5 Retry 决策

- Deterministic coverage complete：不调用 retry model。
- Eligible：调用一次 rewrite planner。
- Rewrite planner 只能返回 `stop` 或单个 tool invocation；最多 3 variants。
- Gateway 重新 normalize/validate，不接受 SQL/corpus/limit/account 参数。
- 第二次 search 后 coverage 再评估；不得再调用 model/tool。
- 第二次不足：最终 Prompt 只允许 limitation/general-knowledge-with-disclaimer。

### 13.6 与 output correction 的隔离

- Retrieval retry counter 与 correction counter 分开记录。
- Retrieval retry 不能因 final JSON invalid 再运行。
- Output correction 不能重新调用 retrieval tool或扩大 Context。
- 总 deadline 在每次调用前检查，预算不足直接停止并记录 stable issue。

### 13.7 测试

- 首次命中 -> retry=0；
- 无结果 -> retry=1 -> 成功；
- partial algorithm/definition -> retry=1；
- 第二次失败 -> stop；
- model 请求第二次额外 retry -> 拒绝；
- model 请求 SQL/其他 corpus -> 拒绝；
- permission scope 在 retry 前后相同；
- tool/provider timeout；
- OpenAI/Qwen tool mapping parity；
- no chain-of-thought/raw context logs。

### 13.8 Gate W5

- 所有请求 search executions <= 2。
- 正常高质量命中不会产生额外模型调用。
- Retry gain 达到 W9 阈值。
- 第二次不足时 100% 停止并报告 limitation。
- Tool 无法访问用户记录、任意 SQL 或非 stable corpus。

### 13.9 回滚

设置 `DOCUMENT_RAG_RETRY_ENABLED=false` 后保留首次 hybrid retrieval。若 provider-native tool mapping 故障，不能退化为开放文本工具；可切回 server-orchestrated strict JSON tool envelope，仍遵守同一合同和次数。

## 14. W6 - 前置 Task/Context Planner 与服务端 Context Policy

### 14.1 目标

在构建 Context 前决定任务、允许的输出和所需信息，解决当前 route/context/output-selection 顺序错误。

### 14.2 候选文件

- 新增 `supabase/functions/ai-chat-route/planning/task_plan_contract.ts`
- 新增 `supabase/functions/ai-chat-route/planning/task_planner.ts`
- 新增 `supabase/functions/ai-chat-route/planning/context_policy.ts`
- 修改 `workflow_router.ts`：保留确定性 rules，但改为 planner 输入，不再独自决定全部 Context
- 修改/逐步移除 `expected_output.ts` 的后置职责
- 修改 `index.ts` orchestration
- 修改 `contracts.ts`、`phase5_types.ts`
- 修改 providers 和 mock planner
- 新增 planner/policy tests

### 14.3 Planner 输入边界

允许：

- 当前 message；
- 当前 request images；
- language/model/fixed entry；
- bounded same-chat messages/artifact summaries/entity refs；
- request-scoped custom exercise references；
- deterministic safety flags。

不允许：

- 尚未批准的 record summaries；
-完整历史；
- auth/provider secrets；
- raw DB rows；
- previous raw provider output；
- 任意 client context object。

### 14.4 决策层次

1. Request schema/safety hard block。
2. Fixed product entry，例如 dedicated food logging。
3. High-confidence deterministic rules：明确 draft、明确 App rule、明确 weekly review 等。
4. Deterministic abstention 时调用 model planner。
5. Parse `task_plan.v1`。
6. Server Context Policy 结合 auth/permission/workflow/output/limits 裁剪。
7. 如果任务/实体仍歧义，直接构造 clarification plan，不先读大量 Context。

### 14.5 Context Policy matrix

至少明确：

| Workflow | 可申请 Context | 额外条件 |
| --- | --- | --- |
| general_chat | same-chat only；必要时 document | 不读取 record summaries |
| food_logging | request images/text、必要 definition 无 | 正式写入为 0 |
| workout_logging | exercise_definition；必要时 same-chat | history 只有用户明确询问且 permission on |
| meal_decision | profile、selected_day、strategy、必要 document | record permission on 才读 summary |
| weekly_review | bounded recent summaries/trend/strategy | permission on；固定时间窗口 |
| app_logic_answer | document；动作组合时 exercise_definition | 不因规则问答读取用户历史 |
| safety_boundary | document 可选或 deterministic response | 不调用用户 data builder/正式写入 |

### 14.6 必测任务

- 只有食物图片+食物名，无“记录” -> Food Draft/Meal Decision ambiguity 正确处理；
- “鸡胸 200g 米饭 150g”隐式记录；
- “今天还能吃这个吗”+图片 -> Meal Decision；
- “保加利亚分腿蹲每侧次数怎么算” -> app_logic + document + exercise definition；
- “记录保加利亚分腿蹲 3 组，每侧 12” -> workout_logging + workout_draft + definition；
- 自定义动作明确名称 -> custom reference；
- “它再加一组” same-chat clarification -> 继承 workout workflow/entity；
- 普通聊天 -> no RAG/no record context；
- safety/write request -> block；
- permission off -> protected Context rejected with named missing dimension。

### 14.7 Index orchestration 改造

旧：

```text
routeGatewayWorkflow
buildPhase5Context
resolveOutputSelection
provider
```

新：

```text
resolveDeterministicSafetyAndFixedEntry
buildTaskPlan (deterministic or model)
validateContextPlan
resolveEntities
buildApprovedContext
runApprovedRetrieval
final provider using allowed output families
validate output/evidence
```

`request.workflowType` 不再在中途被含糊覆盖；保存 original hint、planned workflow、approved workflow 和 final public workflow，便于 debug。

### 14.8 Planner failure

- Fixed/high-confidence deterministic plan 可继续。
- Ambiguous draft intent 返回 clarification，不静默变 ordinary text。
- 不确定 app-rule 问题可以执行最小 Document RAG，因为它不读取用户 records；仍需 evidence guard。
- 不确定 record workflow 不得读取 protected summary。
- 记录 `planner_failure`/`planner_output_invalid`，不暴露 raw output。

### 14.9 Gate W6

- Context Builder 前已有 approved Task Plan。
- planner 请求不能扩大 policy/auth/permission。
- 图片/隐式记录/Workout Draft/组合问题/same-chat cases 全部通过。
- 旧固定入口、JSON output contract 和 no-write 回归通过。
- legacy pipeline flag 可恢复旧顺序。

### 14.10 回滚

切回 `phase5_legacy`；新 request 字段保持 optional，旧客户端不受 schema break。不得只回滚 planner 却保留要求 planner 才能安全调用的新动作/history Context。

## 15. W7 - 动作定义、动作历史与 Workout Draft 确定性绑定

### 15.1 目标

让服务端知道“用户说的是哪个动作、这个动作的输入口径是什么、历史数据从哪里来”，同时保持本地自定义动作和云端记录边界。

### 15.2 内置 catalog snapshot

候选文件：

- 修改 `lib/core/constants/exercise_definition.dart`
- 修改 `lib/core/constants/exercise_catalog.dart`
- 修改 `lib/core/localization/app_strings.dart`
- 新增 `tool/phase5_document_rag/export_exercise_catalog.dart`
- 新增 generated `supabase/functions/ai-chat-route/generated/exercise_catalog.v1.json`
- 新增 catalog parity tests

任务：

1. 把官方中文 display map 放到 catalog 可访问层；AppStrings 调用同一来源。
2. Exporter 读取 Dart canonical list，输出 stable sorted JSON。
3. Snapshot 包含 6.6 所列字段、aliases、version/hash。
4. CI 运行 exporter check mode；generated snapshot 与 Dart count/key/hash 不一致就失败。
5. 服务端只加载 generated snapshot，不手写另一套属性。

### 15.3 Flutter custom exercise matcher

候选文件：

- 新增 `lib/domain/services/ai_exercise_reference_builder.dart`
- 修改 `AiGatewayRequest`
- 修改 AI chat controller/page send path
- 使用 `CustomExerciseRepository`
- 更新 contract/client tests

步骤：

1. 仅在发送当前消息时读取 active custom definitions。
2. 用 normalized exact name/alias/current same-chat entity refs 匹配。
3. 只发送命中的最多 4 个 references；零命中不发送空库。
4. 同名多个 custom/builtin 发送候选并让 server clarification，不按列表顺序静默选。
5. 不把 references 放入通用 `client` map；使用正式顶层 contract field。
6. Request log 不保存完整 reference。

### 15.4 服务端 entity resolver/context builder

候选文件：

- `supabase/functions/ai-chat-route/exercise/exercise_reference.ts`
- `exercise/exercise_resolver.ts`
- `exercise/exercise_context_builder.ts`
- 修改 `context_builders.ts` 或拆分 typed builders

解析优先级：

1. 明确 stable key；
2. official exact zh/en name；
3. reviewed alias exact normalized match；
4. request-scoped custom exact match；
5. same-chat approved entity reference；
6. 多候选 -> clarification；
7. 无候选 -> named missing，不使用 fuzzy 猜动作属性。

Fuzzy/embedding 可以用于“候选提示”，不能自动确定 definition。

### 15.5 动作历史 builder

候选 migration：

- `supabase/migrations/202607130002_rag_foundation_exercise_history.sql`

候选 RPC：`build_exercise_history_summary(account_id, exercise_keys, start_date, end_date, session_limit)`。

约束：

- Edge 传入 verified account id，不接受 client account id；
- service role only；
- 只查该账号未删除正式 workout records/sessions/sets；
- 优先稳定 key，legacy name 只作为明确兼容分支并标记；
- date range、keys、sessions/rows 有硬上限；
- SQL 内聚合，返回 compact summaries；
- 不返回 notes/full set list；
- permission off 直接不调用 RPC；
- custom current definition 与 historical snapshot 不同，返回 conflict metadata。

### 15.6 Workout Draft v3

需要同步：

- `supabase/functions/_shared/ai_output_contract.ts`
- OpenAI/Qwen schemas/prompts/mock/tests
- `lib/domain/models/ai_workout_draft.dart`
- `lib/domain/models/ai_gateway_request.dart`
- workout editor handoff
- artifact persistence/read compatibility
- `docs/en|zh/AIOutputContract.md`
- `docs/API_CONTRACT_DRAFT.md`

Validation：

- provider 返回的 built-in key 必须存在于 approved definition Context；
- custom key/reference 必须存在于 request-approved custom refs；
- definition hash/modes 必须一致；
- unresolved/mismatch 不能生成 enabled review action；
- old v1/v2 artifacts 仍可读取，但新请求优先 v3；
- no `_adHocKey()` silent binding for new v3。

### 15.7 关键 tests

- Bulgarian Split Squat zh/en/key -> `per_side_reps`；
- Single-arm Dumbbell Row alias；
- built-in exact key but wrong name；
- custom exact name and modes；
- two custom exercises same name；
- hidden/deleted custom after artifact generation；
- custom definition changed before review；
- unknown action；
- history permission on/off；
- history no data；
- legacy session without key；
- history limited to target account/exercise/date；
- Workout Draft v3 round-trip/persist/reopen/editor；
- user save required；no official write before save。

### 15.8 Gate W7

- Server snapshot 与 Dart catalog parity 100%。
- 内置动作官方中英文和 aliases 可解析。
- 自定义动作只发送命中 references，未上传完整库。
- History builder 无 raw rows/notes/cross-account leakage。
- Workout Draft v3 未解析动作不能静默 fallback。
- Bulgarian 与至少一个 custom per-side case 端到端通过。

### 15.9 回滚

- 关闭新 pipeline 后旧客户端仍可走 legacy v2。
- Generated catalog 是构建资产，可回滚到上一 version/hash。
- Exercise history RPC additive 保留但停止调用。
- 不删除用户本地 custom definitions、drafts 或云端 workout records。

## 16. W8 - Grounded output、Provider-independent Capability、Food semantic reliability、API/UI 与 observability

### 16.1 目标

让“找到什么”“理解了什么”“依据什么生成”“最终输出什么”形成机器可验证闭环；统一所有 AI Surface 的 Capability/Provider 分层，修复 Food Draft 语言与用户事实忠实度，并让公开合同、UI、日志保持一致。

### 16.2 Grounded output validator

候选文件：

- 修改 `_shared/ai_output_contract.ts`
- 新增 `ai-chat-route/grounding/grounding_contract.ts`
- 新增 `grounding/faithfulness_guard.ts`
- 修改 `contracts.ts`、`prompt_builder.ts`、`index.ts`
- 修改 provider schemas/prompts/tests

规则：

1. 构建 approved evidence registry，ID 指向 document source、context object 或 deterministic rule。
2. Provider 只能引用 registry IDs。
3. `fitlog_rule` segment 至少一个允许的 evidence ref。
4. Document status/authority 与 claim 类型兼容。
5. `general_knowledge` 在 FitLog 证据不足时包含明确 limitation，不出现在 Answer Basis 的文档来源里。
6. `limitation` 对应 missing dimension/issue。
7. Segment 文本非空、有长度/数量上限；拼接后 public message 不重复/丢句。
8. Draft output 仍需 artifact schema；grounding 不能替代 draft validation。
9. Grounding failure 可进入现有一次 output correction；correction 只能使用已有 Context/evidence。
10. 第二次失败返回 `provider_output_invalid` 或 deterministic insufficient-evidence response，绝不放行未引用 FitLog claim。

### 16.3 API contract 修改

`docs/API_CONTRACT_DRAFT.md` 与 Flutter/Edge code 同步：

- 在 request 示例加入 `allow_record_summary_context` 及默认 false；
- 加入 bounded `exercise_references`；
- 描述 same-chat entity refs（若最终采用）；
- 拆分 request hint、internal planned workflow 与 public response workflow 三种 enum；request 增加 `workout_logging`，public 增加 `workout_logging|general_chat|safety_boundary`，并同步旧客户端未知值 compatibility；
- 明确 task plan/tool/retrieval result/context objects 是 server-owned；
- 公开 evidence 增加 retrieval attempt、coverage、source status、context/missing dimensions 的安全字段；
- Workout Draft v3 与旧客户端协商；
- stable error/issue codes；
- 隐私与日志字段。
- 专用 Food endpoint 的 `model_choice=chatgpt|qwen`、provider capability/error 行为和独立 Surface 语义；
- `food_understanding.v1`/semantic issue 的内部边界，以及公开 wire 不暴露内部事实 ledger；
- 专用页面 `input_revision_required` 的 additive wire 方案或 `needs_clarification` 兼容映射；
- 明确 AI Chat 与专用页面不共享模型 preference，只共享 Food Capability。

### 16.4 Observability migration

候选 migration：

- `supabase/migrations/202607130003_rag_foundation_observability.sql`

在 request logs/debug summaries additive 增加 compact fields：

- task plan version/source/confidence/workflow；
- requested/approved/rejected context type arrays；
- query language/category、canonical concept IDs（按隐私规则）；
- corpus/build/embedding/reranker version；
- branch hit counts/final hit count；
- coverage status/missing dimensions；
- retry reason/count/gain；
- embedding/reranker downgrade issue；
- retrieval/planner/final/correction latency；
- prompt context size、token/cost estimate；
- grounding validation status/issue codes；
- surface/capability/provider adapter/policy version；
- target response language 和 language validation status；
- food understanding/fact/conflict counts（只存数量/类别，不存 source span/value）；
- structural/semantic validation status、semantic issue code counts；
- food understanding/draft generation/semantic correction latency；
- final action/no-write。

不得存：

- raw images/base64；
-完整问题全文（除现有 chat message 的用户授权会话存储边界外，debug log 不重复保存）；
-完整 Context objects/history rows；
-完整 custom exercise definition/name；
- raw provider invalid output；
- chain-of-thought；
- auth/provider secrets；
- query embedding vector。

### 16.5 Flutter evidence/UI

候选文件：

- `lib/domain/models/ai_gateway_evidence.dart`
- `lib/domain/models/ai_gateway_response.dart`
- `lib/features/ai/ai_page.dart`
- AI controller/client/tests

Answer Basis 显示：

- 文档来源与 heading；
- 使用的动作定义（内置/当前请求自定义）；
- 使用的记录摘要类型；
- missing information；
- 是否执行额外检索（不展示内部 query/思维）；
- read-only/draft confirmation boundary。

UI 不显示：

- score 细节、raw Context、tool JSON、chain-of-thought；
- “已检索/已读取”但 evidence 不存在的 progress 文案；
- “已保存/已修改/已应用”除非正式 repository 确认写入。

### 16.6 Failure matrix

实现并测试以下分类：

| 层 | Issue | 是否可继续 final provider | 用户侧行为 |
| --- | --- | --- | --- |
| segmentation | `query_normalization_failed` | 可，使用保守 raw lexical | 如 evidence 足够正常回答，否则 limitation |
| query embedding | `embedding_unavailable` | 可，lexical hybrid | 不声称 semantic retrieval 完整 |
| vector RPC | `vector_search_failed` | 可，其他 branches | 同上 |
| lexical RPC | `lexical_search_failed` | 可，vector 可用且 coverage 足够 | 否则 limitation |
| reranker | `reranker_degraded` | 可，用 fused order | debug/eval 记录 |
| retry planner | `retrieval_retry_failed` | 可，使用首次 results | 不再 retry |
| document corpus | `document_context_missing` | 可回答 general knowledge + disclaimer | 不说 FitLog 官方规则 |
| exercise definition | `exercise_definition_missing/ambiguous` | 问答可 limitation；draft 要 clarification | 不默认 modes |
| exercise history | `exercise_history_permission_denied/unavailable` | 可 | 明确缺失，不当 0 |
| task planner | `task_planner_failed` | 仅安全 deterministic fallback | 模糊 draft clarification |
| final provider | existing provider errors | 否或稳定失败 | 现有 error mapping |
| grounding | `unsupported_fitlog_claim` | correction 后仍失败则否 | 不放行 claim |
| response language | `response_language_mismatch` | correction 一次后仍失败则否 | 不进入 Preview/错误语言回答 |
| food understanding | `food_understanding_invalid` | 否 | 保留输入并提示重新分析 |
| user fact | `user_fact_omitted/mismatch` | correction 一次后仍失败则否 | 专用页返回输入修正；Chat 返回稳定失败/clarification |
| food semantics | `notes_field_conflict/nutrition_consistency_unexplained` | correction 一次后仍失败则否 | 不进入 Preview |
| provider capability | `provider_capability_unavailable` | 否；不得静默换 provider | 保留输入并显示模型不可用 |
| logging/cache | `telemetry_write_failed` | 是 | live answer 不被 optional log 阻断 |

### 16.7 Provider-independent Capability/Adapter 重构

候选新增文件：

- `supabase/functions/_shared/ai_capabilities/capability_contract.ts`
- `supabase/functions/_shared/ai_capabilities/capability_registry.ts`
- `supabase/functions/_shared/ai_capabilities/food/food_contract.ts`
- `supabase/functions/_shared/ai_capabilities/food/food_policy.ts`
- `supabase/functions/_shared/ai_capabilities/food/food_orchestrator.ts`
- `supabase/functions/_shared/ai_capabilities/food/food_semantic_validator.ts`
- `supabase/functions/_shared/providers/provider_contract.ts`
- `supabase/functions/_shared/providers/openai_adapter.ts`
- `supabase/functions/_shared/providers/qwen_adapter.ts`
- `supabase/functions/_shared/providers/mock_adapter.ts`

候选修改文件：

- `supabase/functions/ai-chat-route/providers.ts`
- `supabase/functions/ai-chat-route/openai_provider.ts`
- `supabase/functions/ai-chat-route/qwen_provider.ts`
- `supabase/functions/ai-chat-route/mock_provider.ts`
- `supabase/functions/ai-chat-route/index.ts`
- `supabase/functions/ai-chat-route/prompt_builder.ts`
- `supabase/functions/ai-food-photo-analyze/contracts.ts`
- `supabase/functions/ai-food-photo-analyze/index.ts`
- `supabase/functions/_shared/ai_output_contract.ts`

实施顺序：

1. 从现有 providers 提取最小 `ProviderAdapter` 接口和 capability flags，不先重写业务行为。
2. 用 adapter wrapper 保持现有 AI Chat text 测试通过。
3. 建立 provider-independent `CapabilityRequest`/registry；Task Planner、retrieval、grounded answer、Food Draft 各自注册 policy/schema/validator。
4. 把 Food prompt/policy 从 Chat Qwen prompt 和专用 Food contracts 中抽到共享 Food Core；Surface 只提供 normalized inputs/instructions。
5. 把专用 endpoint 内联 Qwen transport 替换为 provider registry；保留相同 auth/subscription/device/deadline/logging 边界。
6. 接入 OpenAI image-capable adapter；OpenAI/Qwen 各自使用统一多模态生成模型，模型 capability 不满足 image/structured requirements 时显式失败。
7. 删除重复业务 Prompt 前先用 golden tests 证明两入口/两 provider 使用同一 policy version；不能先删旧逻辑再靠人工观察。

Provider adapter 单测必须证明：同一 normalized request 映射到不同 provider wire 后，capability、language、facts、schema 和 correction issue 不丢失；adapter 不读取 Context DB、不改变 output family、不触发正式写入。

### 16.8 Food understanding、Draft generation 与 semantic validation

候选测试/fixture：

- `supabase/functions/_shared/ai_capabilities/food/food_contract_test.ts`
- `supabase/functions/_shared/ai_capabilities/food/food_semantic_validator_test.ts`
- `supabase/functions/_shared/providers/provider_parity_test.ts`
- 扩展 `_shared/ai_output_contract_test.ts`
- `test/evals/fixtures/food_capability_regressions.v1.json`

实现步骤：

1. Food understanding call 使用 selected provider、当前 text/images、目标语言和 strict `food_understanding.v1` schema；不提供 RAG/历史/无关 Context。
2. Server 验证 fact source、unit、target item、bounds、source reference 和 conflict；应用统一 precedence，输出 approved facts/estimation needs。
3. Draft generation call 只看到 approved understanding、selected date、目标语言和 Food Draft policy；原图不在 correction 时重复发送，除非 provider contract 明确证明为解决视觉 conflict 必需且仍在同一 deadline/image retention 边界内。
4. Shared structural validator 后执行 language/fact/notes/totals/nutrition plausibility validator。
5. Semantic issue 进入同一个最多一次 correction；correction 输入包含 approved facts、issue codes 和 previous normalized draft，不包含 raw invalid provider response 的长期持久化。
6. 仍失败时生成 Surface-specific stable terminal state；任何失败草稿、partial draft 或 raw provider JSON 不返回 Preview action。
7. Flutter 解析层继续执行 client compatibility validation，不能因为 server passed 就用宽松数值字符串解析。

必须包含的 golden cases：

- 中文 App language + 中文描述 -> 普通字段中文；品牌/英文型号可保留；
- 英文 App/Chat language + 英文描述 -> 英文字段；
- 中英混合输入 -> 目标语言不漂移，专有名词保留；
- “奶昔含 20g 蛋白质” -> 绑定 item `protein_g=20`，不能只写 notes；
- “包装每份 24g 蛋白，我吃了半份” -> approved derived constraint 与估算分离；
- “米饭只吃一半” -> 食用比例作用于正确 item，无法绑定时不静默猜；
- notes 20g / field 8.5g -> `user_fact_mismatch`；
- macro/kcal 差异有标签/纤维说明 -> 允许；无解释且超容差 -> issue；
- item totals 与 meal totals 不一致 -> 现有 normalization/issue policy 明确且两 provider 相同；
- food understanding 遗漏用户明确 fact -> invalid，不继续生成可审查草稿。

### 16.9 专用图片 Surface 与独立 Provider 选择

候选 Flutter 文件：

- `lib/features/food/photo_food_analysis_page.dart`
- `lib/features/food/photo_food_analysis_recovery.dart`（只有恢复模型选择/输入确有产品需要时修改；不得与 Chat recovery 共用状态）
- `lib/domain/models/ai_food_photo_analysis.dart`
- `lib/domain/models/ai_gateway_request.dart`
- `lib/data/remote/ai_food_photo_analysis_client.dart`
- `lib/core/localization/app_strings.dart`
- `test/photo_food_analysis_page_test.dart`
- `test/ai_gateway_contract_test.dart`

UI/状态规则：

1. 增加与当前页面视觉系统一致的 ChatGPT/千问选择器，状态 key 使用 `fitlog.food_analysis.selected_provider`；AI Chat 继续使用 `fitlog.ai.selected_provider`。
2. 默认 Qwen 以保持升级兼容；选择保存到 SharedPreferences，不触发 SQLite `dbVersion`。
3. Provider 切换不清空 note/images/date；发送中的请求锁定本次 selected provider，切换不能改变 in-flight request。
4. `input_revision_required` 在原页显示可操作的双语反馈，保留 note/images，焦点返回描述区域；不创建 Chat bubble/session，不自动重发。
5. Draft 只有 server semantic validation passed 且 Flutter decode passed 才 push `FoodPreviewPage`。
6. Provider unavailable/refusal/incomplete/timeout/output-invalid 使用现有稳定错误体系扩展，保留输入；不自动换 provider。
7. Widget tests 验证 preference 隔离：修改图片页选择不改变 AI Chat key，反向亦然。

### 16.10 统一多模态生成模型与 OpenAI Food 图片接入

候选 Edge 文件：

- `supabase/functions/_shared/providers/openai_adapter.ts`
- `supabase/functions/ai-food-photo-analyze/contracts.ts`
- `supabase/functions/ai-food-photo-analyze/index.ts`
- `supabase/functions/ai-food-photo-analyze/index_test.ts`
- `supabase/functions/ai-chat-route/openai_provider.ts`
- `supabase/functions/ai-chat-route/contracts.ts`
- `supabase/functions/ai-chat-route/index_test.ts`

任务：

1. OpenAI 只读取 `FITLOG_OPENAI_MODEL`，Qwen 只读取 `FITLOG_QWEN_MODEL`；AI Chat 文字、AI Chat 图片和专用 Food 图片分析均使用所选 Provider 的同一个统一多模态生成模型 ID，不新增或保留 Text/Vision model config 分叉。Adapter tests 与 live canary 验证配置模型支持当前 image input 和 structured schema；不支持时明确失败。
2. 专用 request contract 接受 `chatgpt|qwen`；服务端按 provider capability 拒绝不支持组合。
3. OpenAI 图片编码、response schema、refusal/incomplete/usage 通过 adapter 映射为 provider-neutral completion。
4. AI Chat 图片当前只允许 Qwen 的限制只有在 OpenAI image adapter/canary/Flutter UI 全部就绪后再 additive 放开；不得先让客户端发送再由服务端失败。
5. `model_choice`、`model_provider`、实际 model 和日志一致；不得返回选择 ChatGPT 实际调用 Qwen。
6. Feature flag 关闭或 OpenAI 配置缺失时，Qwen 路径保持可用；UI 必须显示 ChatGPT 当前不可用并以共享滑动动画自动恢复 Qwen 选中态。恢复只改变 UI，不得把这次点击静默转换为 Qwen request。

### 16.11 Stable docs 与 contributor rule 落点

W8 代码合同稳定后准备以下 owning updates，W10 统一以 current behavior 落地：

- `AGENTS.md`：Provider adapter transport-only、Capability policy shared、不得复制业务规则的贡献者规则；
- `docs/en/AgentDesign.md` / `docs/zh/AgentDesign.md`：Surface/Capability/Provider/Validation 架构与权限；
- `docs/en/AIOutputContract.md` / `docs/zh/AIOutputContract.md`：Food understanding、语言/事实 semantic validation、correction/终态；
- `docs/API_CONTRACT_DRAFT.md`：专用双 provider wire、兼容字段和 errors；
- `docs/en/Product.md` / `docs/zh/Product.md`、`AppGuide.md`：独立 Provider 选择、原页输入修正、Preview Gate；
- `docs/en/Database.md` / `docs/zh/Database.md`：SharedPreferences 独立 preference、AI log 新字段；无 SQLite schema 变化时明确 `dbVersion` 不变；
- `docs/en/RAGDesign.md` / `docs/zh/RAGDesign.md`：只更新 Chat plan/Context 与 Capability 的交界，不复制 Food Vision/Provider 细节；
- `docs/ROADMAP.md`、`CHANGELOG.md`：分别维护状态/链接和部署后事实。

这些更新严格执行 0.3：不追加日期块，不把本节 checklist 复制到 stable docs，不在 `RAGDesign` 建第二份 Food contract。

### 16.12 Gate W8

- API docs/Flutter/Edge fields 一致。
- FitLog claim 无 evidence 100% 被 validation/correction/limitation 拦截。
- Answer Basis 与实际 registry 一致。
- 日志 redaction tests 通过。
- progress 文案不超过证据。
- 所有正式写入仍为 0，draft review/save 边界无回归。
- AI Chat/专用页面的 Food Capability policy/validator version 一致，Surface-specific 差异有显式 contract。
- 中文/英文/混合语言和专有名词 language Gate 通过；错误语言 Draft 进入 Preview 为 0。
- 用户明确 Food facts 被覆盖、遗漏或仅写进 notes 的 Draft 进入 Preview 为 0。
- 专用页面只有 Preview 或原页输入修正/稳定错误，不创建 Chat clarification loop。
- 图片页与 AI Chat provider preference 完全隔离。
- OpenAI/Qwen image adapters 通过同一 parity suite；OpenAI 未配置时真实 unavailable、自动滑回 Qwen、无 request、无 hidden provider fallback。

### 16.13 回滚

公开 response additive fields 必须允许旧客户端忽略。切 legacy pipeline 后仍使用现有 v2 envelope；新 DB observability columns 保留。若 grounded v3 provider mapping 故障，不得放宽 validator，应切回 legacy 整体 pipeline。OpenAI Food Vision 可单独关闭并隐藏/禁用选项；图片页 preference 保留但不可用状态真实显示。Food semantic validator 不得为了回滚 Provider 而关闭；若共享 Food pipeline 本身故障，只能通过 `AI_CAPABILITY_PIPELINE_VERSION=legacy` 整体回退，并将 legacy 的已知语言/事实风险视为发布阻断，不能标记 COMPLETE。

## 17. W9 - 全面评测集、报告与阈值校准

### 17.1 目标

建立可以重复运行、能够定位失败层的评测工程。本包覆盖整个 FitLog Agent，不以 workout 触发案例代替其他主题。

### 17.2 目录建议

```text
test/evals/
  README.md
  fixtures/
    document_retrieval.v1.json
    structured_context.v1.json
    task_planning.v1.json
    exercise_context.v1.json
    grounded_output.v1.json
    food_capability_regressions.v1.json
    provider_capability_parity.v1.json
    safety_privacy.v1.json
    failure_retry.v1.json
    provider_canary.v1.json
  expected/
  reports/
  failure_corpus/
tool/evals/
  run_rag_eval.mjs
  build_rag_report.mjs
supabase/functions/ai-chat-route/evals/
  deterministic_eval_test.ts
```

`reports/` 只提交无隐私、体积可控的基线/发布报告；真实 provider raw output 不入库。失败样本经过脱敏后进入 `failure_corpus`，修复后继续保留。

### 17.3 Eval case 公共 schema

每个 case 至少包含：

- stable `case_id`、suite、language、query/input kind；
- workflow hint、permission、same-chat Context、exercise refs；
- expected task plan/workflow/output families；
- expected/forbidden Context dimensions；
- expected canonical terms/entities；
- expected source paths/headings/top-k；
- allowed statuses/authority；
- expected retry behavior；
- surface、capability、provider choice/capability flags、target response language；
- user/package/visual/estimate facts、expected precedence/conflicts、semantic issues 和允许的 Surface terminal state；
- required/forbidden answer concepts；
- evidence and no-write assertions；
- failure injection；
- latency/token/context budgets；
- fixture version和 reason。

### 17.4 Document retrieval 主题覆盖

每个主要 stable owning doc 至少有一组 zh/en/mixed/paraphrase/no-answer cases：

| Owning doc | 必测主题 |
| --- | --- |
| Product | 产品承诺、模块、支持范围、non-goals |
| AppGuide | 页面入口、Add Food、AI Chat、训练记录、自定义动作、确认/失败行为 |
| Methodology | 两种饮食模式、策略、训练消耗方法、局限 |
| Algorithm | BMR/TDEE、宏量、phase/mode/strategy、per-side normalization、volume/calories |
| Database | SQLite/cloud schema、字段语义、迁移、export、记录 snapshot |
| CloudLocalDataBoundary | authority、cache、offline、conflict、repair、account switch |
| AgentDesign | Context 权限、工具、privacy、write boundary、retention |
| AIOutputContract | JSON envelope、draft schema、validation、correction、errors |
| RAGDesign | corpus、Structured/Document RAG、hybrid、retry、evidence、failure |
| References | evidence claim boundary、内部决定与外部依据 |

每个主题包含：

- 官方中文/英文；
- 2 个自然改写；
- 1 个口语/短查询；
- 1 个中英混合；
- 1 个近义但不同概念负例；
- 1 个 corpus 无答案问题。

### 17.5 术语专项

硬性 cases：

- 每侧次数、单侧次数、单边次数、每边次数；
- per-side reps、reps per side、unilateral reps；
- 总次数/total reps 负例；
- 每侧重量、单侧重量、每边重量、per-side load；
- 总重量/器械标称重量；
- 自重加重、辅助重量；
- 时长组；
- 词序变化、无空格长句、错别字小样本；
- 官方动作中文/英文/key/aliases。

### 17.6 Task/Context/Structured suites

- Meal Decision：两个 diet modes、permission on/off、selected day missing、image ambiguity。
- Weekly Review：7/14 天、稀疏数据、weight trend 足/不足、strategy read-only。
- Food Draft：明确/隐式文本、image-only、日期、用户明确重量/比例/营养、包装/OCR、事实冲突、目标语言、专有名词、专用页 input revision 与 Chat clarification 差异。
- Workout Draft：明确/隐式、内置/custom/unknown/ambiguous、same-chat follow-up。
- App Logic：纯规则、动作+规则、database+privacy、planned/non-goal。
- General chat：不应读取 record/document 的 cases。
- Safety：改目标、应用策略、删除、完整历史、prompt injection。
- Planner request vs server approved vs actual Context 三方一致。

### 17.7 动作专项

- 所有内置动作 snapshot parity 自动测试。
- 每种 load/reps/set mode 至少一个 builtin case。
- Bulgarian per-side reps 必测。
- Custom total/per-side/duration/cardio 各一例。
- 同名 builtin/custom、自定义同名、unknown、typo、语言 alias。
- Definition current vs historical snapshot conflict。
- History permission off、no data、bounded recent、legacy name fallback。
- Draft v3 review/save/no-write。

### 17.8 Output/faithfulness/safety suites

- 全部 output families；
- malformed JSON/schema mismatch/domain mismatch；
- 一次 correction 成功/失败；
- FitLog claim valid evidence；
- forged/unknown evidence ID；
- planned/historical/local source claim；
- general knowledge with limitation；
- Answer Basis/source agreement；
- prompt injection inside retrieved chunk；
- client forged exercise/context/tool/API key；
- provider refusal/incomplete/timeout；
- OpenAI/Qwen text；
- OpenAI/Qwen image Food Draft；同一 normalized capability contract、facts、language、errors 和 Preview Gate；
- 专用 Food/AI Chat 跨入口 policy parity；专用入口不调用 Document RAG/Chat clarification；
- 用户事实遗漏/覆盖、notes/数字矛盾、错误语言、nutrition plausibility、semantic correction 成功/失败；
- 图片页与 AI Chat provider preference 隔离；
- logs redaction/no raw history/no writes。

### 17.9 Failure injection

每个可失败层都需 deterministic injection：

- manifest/chunker；
- segmentation/normalization；
- embedding API/dimension；
- vector/lexical RPC；
- reranker；
- tool request parse；
- retry planner；
- task planner；
- every Structured builder；
- provider；
- output/grounding validator；
- capability registry/provider adapter；
- food understanding/precedence/semantic validator；
- Surface terminal-state mapping/provider preference；
- log/cache write。

报告必须将失败归因到 ingestion、retrieval、planning、context、provider、output、client 或 deployment，不只输出总 pass/fail。

### 17.10 固定发布阈值

阈值基于 versioned eval set；任何降低都需要用户明确批准。

| 指标 | Release Gate |
| --- | ---: |
| Required corpus source coverage | 100% |
| 双语 required file pairing | 100% |
| Protected Markdown token fidelity | 100% |
| Active chunks embedding freshness/parity | 100% |
| 官方术语/枚举 expected source top-3 | 100% |
| Document answerable set source recall@3 | >= 97% |
| Document answerable set precision@3 | >= 85% |
| Critical Product/Algorithm/Privacy cases top-1 | >= 95% |
| `per_side_reps` vs `total_reps` confusion | 0 |
| Wrong-language-only top-3 on monolingual query | 0 |
| planned/local/historical misreported current | 0 |
| No-answer cases fabricated source | 0 |
| Context permission violations | 0 |
| Context raw rows/notes/images leakage | 0 |
| Task plan/approved/actual Context mismatch | 0 on critical cases |
| FitLog claim without valid evidence | 0 |
| Draft before-confirmation official writes | 0 |
| Search executions > 2 | 0 |
| Retry on first-pass-complete cases | <= 2% |
| Retry success among eligible first misses | >= 60% |
| Retry permission expansion | 0 |
| Catalog snapshot parity | 100% |
| Unknown action silent total/total fallback in v3 | 0 |
| Food Draft wrong response language escape | 0 |
| Food user-explicit fact omitted/overridden in accepted draft | 0 |
| Food notes/field semantic contradiction escape | 0 |
| Invalid Food Draft reaches Preview/artifact action | 0 |
| Dedicated Food surface creates Chat clarification/session | 0 |
| Food page/AI Chat provider preference cross-write | 0 |
| Provider choice changes capability/permission/confirmation policy | 0 |
| OpenAI/Qwen normalized capability contract parity | 100% |

### 17.11 性能/费用预算

在固定本地/mock环境记录 deterministic time，在真实 provider canary 记录网络 p50/p95。初始 release budgets：

- normalization + fusion + rerank（不含网络 embedding/DB）：p95 <= 100 ms；
- embedding + hybrid DB + rerank 正常路径：p95 <= 1,500 ms；
- 额外 retrieval retry 增量：p95 <= 3,500 ms；
- final Document Context <= 6,000 characters / top-k <= 6；
- Structured Context 必须保持各 builder 既有/新合同上限；
- 默认路径模型调用 1；模糊或 retry 路径按 4.3 上限；
- Food understanding/draft/correction 按 4.3 独立预算，分别报告专用页和 AI Chat Food path 的 p50/p95、token/cost；
- retry rate 在完整 answerable eval 中 <= 20%；
- token/cost 报告分别列 planner、embedding、retry、final、correction。

如真实区域网络导致时间预算不合理，只能基于报告调整并保留明确上限；不得删除 timeout/预算 Gate。

### 17.12 Gate W9

- deterministic eval 一条命令可重跑并生成机器/人类可读报告。
- 所有固定阈值通过。
- 当前发布的 Qwen text 与 image Food canary 小样本通过，且不使用真实用户隐私 fixture；未配置 OpenAI 由 adapter/contract tests 与两处 UI unavailable/no-request/no-fallback tests 证明，不要求 live canary。
- 失败样本已进入 regression corpus。
- 报告能定位 branch/rerank/retry/planner/context/output 层。

### 17.13 回滚

Eval assets 永不因功能 rollback 删除；回滚后用同一套 eval 验证 legacy 行为和已知缺口，报告明确当前 pipeline version。

## 18. W10 - 稳定文档收口、部署、canary 与人工验收

### 18.1 目标

让仓库 stable docs、generated corpus、云端 active build、Edge、Flutter 和实际行为在同一发布点一致。

### 18.2 Stable docs 最终更新

在实现和 W9 通过后，把 W1 准备的准确文本更新为 present-tense current behavior。必须同步中英文：

- Product/AppGuide/Methodology/Algorithm/Database；
- CloudLocalDataBoundary/AgentDesign/AIOutputContract/RAGDesign/References；
- API contract；
- README 文档导航/产品级边界；
- 不在 stable docs 写施工 checklist、canary 日记或 Phase diary。

更新时必须逐项执行 0.3 和 `AGENTS.md` 文档 charter：先确定 owning file/heading，再将事实整合进现有 capability section；不得在文件尾增加日期标题、时间戳更新块或把 W8/W9 checklist 原样粘贴进去。Provider/Capability 架构归 `AgentDesign`，Food output/semantic validation 归 `AIOutputContract`，专用页选择/终态归 `Product`/`AppGuide`，wire 归 API contract，持久化 preference/log 归 `Database`，RAG 只保留 Context/retrieval 交界。

特别删除/改写当前已过时说法：

- “Embeddings/vector search 不在当前 RAG design”；
- Document corpus 漏 `CloudLocalDataBoundary.md`；
- 仅关键词/全文/trigram 的 current architecture；
- output selection 在 Context 之后的描述；
- Workout Draft 只依赖 name alias 的描述；
- API request 示例缺实际字段。
- 专用 Add Food 只支持 Qwen、且 AI Chat 图片只允许 Qwen 的 current 描述（仅在 OpenAI Vision canary 已通过后改为双 provider）；
- 专用 Food clarification 被描述成 Chat 追问的文字；
- Provider adapter 中存在 Food 业务规则、或两入口维护不同 Food policy 的旧描述；
- Food Draft 只声明结构校验而没有说明语言/用户事实/semantic Gate 的过时描述。

### 18.3 本地自动步骤

1. 全量 stable docs/link/bilingual/status scan。
2. 运行 manifest validator。
3. 生成 lossless chunks/seed。
4. 运行 chunk fidelity/forbidden-pattern/parity tests。
5. 生成/校验 catalog snapshot。
6. Embedding dry-run 和 local build。
7. 全部 Edge/Dart/eval tests。
8. `git diff --check` 和 planned/current stale wording scan。

### 18.4 人工确认目标 Supabase

在任何写入前记录：

- project ref/url；
- environment（local/staging/production）；
- 当前 migration version；
- 当前 Edge function version；
- 当前 active corpus build；
- 备份/rollback build id；
- 使用的 embedding model/dimension/version；
- canary account/device/subscription。

不得把历史计划里的 project ref 当成无需复核的当前目标。

### 18.5 部署顺序

```text
1. Apply additive document/vector migration
2. Apply exercise-history RPC migration
3. Apply observability migration
4. Verify tables/RLS/grants/RPC signatures
5. Stage new lossless chunk build
6. Sync embeddings for exact staged build
7. Verify source/chunk/vector/hash parity
8. Activate new corpus build atomically
9. Deploy Edge with AI_CONTEXT_PIPELINE_VERSION=phase5_legacy
10. Run legacy smoke
11. Enable rag_foundation_v1 for canary/test environment
12. Run deterministic cloud probes and manual scripts
13. Enable retry canary
14. Install configured split APK and run end-to-end review
15. Promote production default only after all gates pass
```

Edge 不得先切新 pipeline 再慢慢回填 vectors；未完成 build 不允许 active。

### 18.6 云端 SQL 验证

至少检查：

- migrations 已应用且顺序正确；
- active corpus 只有 manifest authorized paths；
- required zh/en source counts > 0；
- `CloudLocalDataBoundary.md` 双语存在；
- active chunk count = build metadata；
- embedding non-null count = active chunk count；
- embedding model/dimension/input hash 一致；
- stale/extra/duplicate chunks = 0；
- hybrid RPC 同语言/authority/status filter；
- anon/authenticated grants 不越权；
- history RPC 跨账号隔离；
- logs/debug fields 更新但无 raw context；
- read-only prompts official writes = 0。

### 18.7 人工验收脚本

#### A. 官方术语与 Bulgarian 触发案例

依次问：

1. “保加利亚分腿蹲每侧次数填 12 是一共 24 次吗？”
2. “单侧次数怎么算训练量？”
3. “每边 12 下总训练量怎么算？”
4. “Bulgarian split squat reps per side in FitLog?”
5. “总次数和每侧次数有什么区别？”

检查回答、动作 definition、Algorithm source、Answer Basis 和正确计算语义。

#### B. 文档广度

分别问 Product/AppGuide、两种饮食模式、BMR/TDEE、策略、Database、CloudLocal、privacy、output JSON、RAG non-goal。确认 expected owning source，不只命中 workout docs。

#### C. 自定义动作

1. 本地创建一个 `per_side_reps` 自定义动作。
2. 问它的录入方式。
3. 要求生成 3 组每侧 12 的 Workout Draft。
4. 检查 review editor 的 key/modes/输入。
5. 不保存并确认正式记录为 0。
6. 再保存一次并确认只由 editor 写入。
7. permission on/off 分别问历史。

#### D. Planner

- 纯食物图+简短补充；
- 隐式食物记录；
- 隐式 workout 记录；
- App 规则+动作组合；
- same-chat “再加一组”；
- general chat；
- 修改目标/删除/完整历史请求。

#### E. Retry/failure

- 首次 exact hit：无 retry；
- reviewed paraphrase 首次不足、retry 成功；
- corpus 无答案：retry 一次后停止；
- 临时模拟 embedding/reranker failure：词法降级且不伪造 source。

#### F. Provider paths

- ChatGPT 中文/英文 text；
- Qwen 中文/英文 text；
- ChatGPT/Qwen image Food/Meal paths；
- 两个 provider 的 draft/clarification/grounding。
- 专用图片页分别选择 ChatGPT/千问，重启后各自恢复；AI Chat provider preference 不受影响。
- 中文输入普通字段为中文、英文输入为英文、中英混合保留专有名词但说明语言正确。
- “奶昔含 20g 蛋白质”在两 provider/两入口都保留用户事实；notes/字段不矛盾。
- 专用页面信息不足时保留图片/文字并回到原表单修正，不创建 Chat turn。
- Provider unavailable/refusal/incomplete/timeout/output-invalid 均保留输入；未配置 ChatGPT 的 UI selection 自动滑回 Qwen，但不发送或转换请求。

### 18.8 APK 与回归

按 AGENTS 默认构建：

```powershell
flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json
```

确认：

- AI 页面 Answer Basis/错误文案/进度；
- Food Preview/Workout editor；
- Home/Food/Workout/Profile 既有功能；
- account switch、permission toggle、weak network；
- 无系统字体/布局回归；
- 自定义动作创建/删除和历史记录不受破坏。

### 18.9 Gate W10

- Stable docs、代码、cloud schema、active corpus/vectors、Edge 和 APK 一致。
- 全部 SQL probes/人工脚本通过。
- 生产 pipeline 默认 `rag_foundation_v1`。
- retry 开关状态与报告一致。
- 无 privacy/write/faithfulness release blocker。

### 18.10 回滚

按 20 节执行；rollback 后再次运行 critical smoke，不能只切开关不验证。

## 19. W11 - 兼容清理、状态同步与归档

### 19.1 目标

清理仅由本轮产生且已不再需要的兼容代码，准确记录完成状态，并保留完整追溯。

### 19.2 任务

1. 根据 canary 窗口决定 legacy route/RPC/v2 draft fallback 的保留期限。
2. 只删除本轮新架构明确替代且无旧客户端需要的代码；不顺手重构其他模块。
3. 更新 `CHANGELOG.md`：Added/Changed/Fixed/Validation，简洁记录已部署事实。
4. 更新 `docs/ROADMAP.md`：
   - 原 Phase 5 baseline 已完成；
   - 本轮 closure/hardening 的最终状态；
   - 关键验收指标/部署状态；
   - scope、实施计划、历史计划和最终报告链接。
5. 将本计划状态改为 COMPLETE，并填写 landing summary、migration、Edge、corpus build、eval report。
6. 将根目录 scope 与本计划移动到 `docs/history/phase5/`；更新所有链接。
7. 保留文件名区分：
   - 原始 `PHASE5_ENGINEERING_PLAN.md`；
   - `RAG_FOUNDATION_REMEDIATION_SCOPE.md`；
   - `RAG_FOUNDATION_REMEDIATION_ENGINEERING_PLAN.md`；
   - document audit/eval/landing summary。
8. 重新生成 Document RAG seed，因为 README/RAGDesign 链接会变化。
9. 最终 required tree、broken link、stale root ref、replacement char、generated seed、Git diff 检查。

### 19.3 Gate W11

- Scope matrix 全部 COMPLETE，有证据链接。
- 无根目录 stale plan refs。
- Roadmap 不复制完整计划，但能追溯全部文件。
- Changelog 只写已部署事实。
- Stable docs 无 phase diary/plan checklist。
- 最终 seed/parity 在归档链接变更后重新通过。

### 19.4 回滚

归档/链接属于文档操作，可独立回滚；不要回滚已经部署的数据 migration。若存在未完成 Scope ID，不执行 COMPLETE/归档，保持根目录 active plan 并显式记录状态。

## 20. 文件级修改索引

本节是施工文件导航，不替代各 W 的任务/测试/Gate。开工时必须以 `rg`/实际 imports 复核路径；如实际组织不同，只能做等价最小调整，并在实施偏差记录中更新“旧候选 -> 实际文件”。每个 Scope ID 必须至少映射一个 production file、一个 test/eval、一个 owning doc 或明确说明为什么该层不需要修改；不能完成代码后才猜测应该同步哪些文件。

### 20.0 Scope 到文件的使用方式

```text
Scope ID
  -> 第 25 节实施施工包/Gate
  -> 对应 W 的候选文件与任务
  -> 本节具体 production/test/tool/doc 文件
  -> 第 27 节实际 diff/validation/deployment evidence
```

### 20.1 Flutter/Dart

| 文件/区域 | 计划改动 |
| --- | --- |
| `lib/core/constants/exercise_definition.dart` | 必要的 canonical localization/snapshot 字段访问；保持现有 enums |
| `lib/core/constants/exercise_catalog.dart` | 官方中文名/alias 可导出、definition parity |
| `lib/core/localization/app_strings.dart` | 使用 catalog 官方中文名；官方术语测试 |
| `lib/domain/models/ai_gateway_request.dart` | `exercise_references`、workflow/schema capability |
| `lib/domain/models/ai_gateway_response.dart` | additive evidence/issue fields compatibility |
| `lib/domain/models/ai_gateway_evidence.dart` | action definition/retrieval coverage/retry evidence |
| `lib/domain/models/ai_workout_draft.dart` | v3 reference binding；移除新路径 silent ad-hoc defaults |
| `lib/domain/services/ai_exercise_reference_builder.dart` | 当前请求命中 custom references |
| `lib/features/ai/ai_chat_controller.dart`、`lib/features/ai/ai_page.dart`、`lib/data/remote/ai_gateway_client.dart` | 发送 refs、解析 v3、Answer Basis、progress truthfulness、共享 Food Capability 接线 |
| `lib/features/workout/add_workout_page.dart`、`lib/features/workout/workout_session_page.dart`、`lib/data/repositories/workout_draft_repository.dart` | key/source/hash/mode 验证与 clarification/editor handoff |
| `lib/domain/models/ai_food_photo_analysis.dart` | 双 provider request/response、input revision compatibility、严格 Food Draft decode |
| `lib/data/remote/ai_food_photo_analysis_client.dart` | 专用双 provider wire/error mapping，不实现 Food 业务规则 |
| `lib/features/food/photo_food_analysis_page.dart` | 独立 Provider 选择、in-flight provider 锁定、原页输入修正、Preview Gate |
| `lib/features/food/photo_food_analysis_recovery.dart` | 仅在需要时恢复专用输入/选择；不得读写 Chat preference/session |
| `lib/features/food/food_preview_page.dart` | 只接受通过 shared semantic/client validation 的 Draft；确认写入边界回归 |
| `lib/core/localization/app_strings.dart` | 图片页 Provider 选择、input revision/provider unavailable 双语文案 |
| `test/photo_food_analysis_page_test.dart`、`test/ai_gateway_contract_test.dart`、`test/ai_page_test.dart` | 专用 UX、preference 隔离、双 provider contract、Preview/no-write regression |
| `pubspec.yaml` | 注册 `assets/rag/*.json`（如 Flutter runtime 读取） |

### 20.2 Edge

| 文件/区域 | 计划改动 |
| --- | --- |
| `supabase/functions/ai-chat-route/contracts.ts` | public/internal request types、拒绝 server-owned fields |
| `supabase/functions/ai-chat-route/phase5_types.ts` | 拆分/升级 typed plan/context/evidence types |
| `supabase/functions/ai-chat-route/index.ts` | 新 orchestration 顺序、budgets、telemetry |
| `supabase/functions/ai-chat-route/workflow_router.ts` | deterministic planner rules/safety，不再单独决定 Context |
| `supabase/functions/ai-chat-route/expected_output.ts` | 职责并入 pre-context plan/allowed family；保留兼容 tests |
| `supabase/functions/ai-chat-route/context_builders.ts` | 接收 approved plan；增加 action definition/history |
| `supabase/functions/ai-chat-route/document_rag.ts` | 新 hybrid pipeline orchestration |
| `supabase/functions/ai-chat-route/prompt_builder.ts` | plan/context/tool/evidence layers；grounded output instructions |
| `supabase/functions/ai-chat-route/providers.ts`、`openai_provider.ts`、`qwen_provider.ts`、`mock_provider.ts` | planner、tool/retry、grounded envelope mapping；逐步变为共享 adapter 的薄兼容层 |
| `supabase/functions/_shared/ai_output_contract.ts` | grounded text、Workout Draft v3、Food structural/language/semantic compatibility |
| 新 `supabase/functions/ai-chat-route/planning/`、`rag/`、`exercise/`、`grounding/` | 隔离明确职责，避免继续堆入 `index.ts` |
| 新 `supabase/functions/_shared/providers/provider_contract.ts`、`openai_adapter.ts`、`qwen_adapter.ts`、`mock_adapter.ts` | Provider capability/transport-only interface、OpenAI Vision、Qwen parity |
| 新 `supabase/functions/_shared/ai_capabilities/capability_contract.ts`、`capability_registry.ts` | Surface -> capability normalized contract/registry |
| 新 `supabase/functions/_shared/ai_capabilities/food/food_contract.ts`、`food_policy.ts`、`food_orchestrator.ts`、`food_semantic_validator.ts` | Food understanding、precedence、共享 Prompt policy、Draft/semantic Gate |
| `supabase/functions/ai-food-photo-analyze/contracts.ts` | 双 provider public request、Surface-specific terminal compatibility、provider-neutral body |
| `supabase/functions/ai-food-photo-analyze/index.ts` | 调用共享 Food Capability/provider registry；保留 auth/deadline/logging，不内联业务规则 |
| `supabase/functions/ai-food-photo-analyze/index_test.ts` | zh/en/mixed、facts、semantic correction、双 provider、failure/redaction |
| `supabase/functions/ai-chat-route/index_test.ts`、`supabase/functions/_shared/ai_output_contract_test.ts`、新增 provider/food tests | cross-surface/cross-provider contract/validator parity |

### 20.3 Supabase

| Migration | 内容 |
| --- | --- |
| `supabase/migrations/202607130001_rag_foundation_document_hybrid.sql` | pgvector、chunk/build metadata、indexes、hybrid/admin RPC |
| `supabase/migrations/202607130002_rag_foundation_exercise_history.sql` | bounded account-scoped exercise history summary RPC |
| `supabase/migrations/202607130003_rag_foundation_observability.sql` | planner/retrieval/retry/grounding + surface/capability/provider/language/food semantic metadata |

此处日期数字仅是尚未创建 migration 的排序文件名；实际施工日期变化时可以调整该 migration 文件名中的时间戳，但职责和顺序不变。该规则不适用于 stable docs，稳定文档仍禁止时间戳式更新块；也不得修改已部署旧 migration 文件来伪装新 schema。

### 20.4 Tooling/assets/evals

- 重写 `tool/phase5_document_rag/build_document_chunks.mjs`。
- 增加 manifest、parser、validator、embedding sync、catalog export。
- 增加 `assets/rag/domain_terms.v1.json` 和 exercise aliases。
- 增加 `test/evals` 与报告 runner。
- 增加 `food_capability_regressions.v1.json`、`provider_capability_parity.v1.json` 和对应 runner/report dimensions。
- generated seed 继续由工具产生，禁止手改大段 SQL。

### 20.5 文档

- 全部 stable bilingual docs 按 W1/W10 同步。
- `docs/API_CONTRACT_DRAFT.md` 更新实际 wire contract。
- `README.md` 只更新产品摘要/导航。
- `AGENTS.md` 增加 Provider adapter transport-only、共享 Capability policy/validator 的 contributor rule。
- `docs/en|zh/AgentDesign.md` 维护 Surface/Capability/Provider/Validation 边界；`AIOutputContract.md` 维护 Food facts/language/semantic contract；`Product.md`/`AppGuide.md` 维护独立选择和专用页终态；`Database.md` 维护 SharedPreferences/log 语义；`RAGDesign.md` 只维护交界链接。
- `CHANGELOG.md` 只在部署完成后写事实。
- `docs/ROADMAP.md` 维护状态/链接/验收摘要。
- `docs/history/phase5` 保存原计划、本轮 scope/plan/audit/report。

所有 stable docs 行都执行 0.3：不追加时间戳更新块，不复制工程 checklist，双语同任务更新；上述 owning file 映射优先于“把所有信息都写进 RAGDesign”。

## 21. 自动化验证命令

实施时以实际脚本名为准，但必须形成以下一键层次。

### 21.1 Tool/ingestion

```powershell
node tool/phase5_document_rag/validate_document_corpus.mjs
node --test tool/phase5_document_rag/*_test.mjs
node tool/phase5_document_rag/build_document_chunks.mjs
node tool/phase5_document_rag/sync_document_embeddings.mjs --dry-run
```

### 21.2 Dart/Flutter

```powershell
dart format lib test tool
flutter analyze
flutter test
```

### 21.3 Edge

```powershell
npm.cmd exec --yes deno -- check supabase/functions/ai-chat-route/index.ts supabase/functions/ai-food-photo-analyze/index.ts
npm.cmd exec --yes deno -- test supabase/functions/_shared/ai_output_contract_test.ts supabase/functions/_shared/ai_capabilities supabase/functions/_shared/providers supabase/functions/ai-chat-route/expected_output_test.ts supabase/functions/ai-chat-route/index_test.ts supabase/functions/ai-food-photo-analyze/index_test.ts
```

新增 Edge tests 必须加入同一 test command 或运行目录级命令，不能只在个人终端单独跑遗漏 CI。

### 21.4 Eval

```powershell
node tool/evals/run_rag_eval.mjs --mode deterministic
node tool/evals/build_rag_report.mjs
```

Live canary 必须显式参数和 secrets，不作为默认无网络 test 的隐式依赖。

### 21.5 APK

```powershell
flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json
```

### 21.6 Docs/生成物检查

- required documentation tree；
- bilingual outlines/links；
- old root paths；
- replacement characters；
- stale “future vector only” wording；
- stable docs date/update headings、Phase diary/checklist residue、Provider/Food rule ownership duplication；
- generated seed forbidden patterns；
- manifest/seed/cloud parity；
- `git diff --check`。

## 22. 部署与人工操作清单

以下操作需要目标环境、密钥和外部状态，Codex 不得假装自动完成：

1. 确认 Supabase project/environment。
2. 备份/记录 current active corpus build 与 Edge version。
3. 应用本轮七份 additive migrations。
4. 设置/确认 server config：Qwen generation/embedding 共用服务端 Qwen secret，`FITLOG_DOCUMENT_EMBEDDING_MODEL=text-embedding-v4`；OpenAI generation 未合法配置时保持真实 unavailable，不是 RAG 或当前发布前置条件。
5. 运行 chunk staging + embedding sync。
6. 运行 parity SQL 后 activate build。
7. 部署 Edge function。
8. 配置 canary subscription/account/device/record permission。
9. 安装 configured split APK。
10. 完成人工脚本并保存不含隐私的结果。
11. 才能切生产 pipeline default。

每一步必须记录命令、环境、时间、结果、rollback point；secrets 不写入计划/日志。

## 23. Rollback 手册

### 23.1 触发条件

- critical retrieval/evidence regression；
- auth/permission/privacy 越界；
- official write boundary 回归；
- p95/费用严重超预算；
- vector/corpus parity 失败；
- provider tool/planner 广泛失败；
- current rules 被 planned/local evidence 覆盖；
- Workout Draft 错绑动作。
- 错误语言或用户明确事实冲突的 Food Draft 进入 Preview；
- 图片页/AI Chat preference 串写；
- 选择 ChatGPT 实际调用 Qwen、或 provider 不可用时 silent fallback；
- 共享 Capability/Provider 重构导致两个入口 policy/validator version 不一致。

### 23.2 顺序

```text
1. 仅 OpenAI Food Vision 故障：OPENAI_FOOD_VISION_ENABLED=false，Qwen 仍走 shared validator
2. Food Capability 整体故障：AI_CAPABILITY_PIPELINE_VERSION=legacy，并把已知语言/事实风险标为发布阻断
3. DOCUMENT_RAG_RETRY_ENABLED=false
4. 如 Context/RAG 仍不稳定，AI_CONTEXT_PIPELINE_VERSION=phase5_legacy
5. 回滚 Edge 到上一已验证 version
6. active corpus build 切回上一 build id
7. 保留 additive migrations/embeddings/logs/preferences，不做 destructive delete
8. 运行 auth/no-write/provider-preference/legacy critical smoke
9. 记录 issue 和 failure corpus
```

### 23.3 不允许的 rollback

- 不 `git reset --hard` 覆盖用户修改。
- 不清空用户 SQLite/云端 records。
- 不删除云端 workout history/custom local definitions。
- 不把 validator 放宽为接受无 evidence claim。
- 不把整个用户历史发送给模型作为临时替代。
- 不把 planned/local docs 加入 current corpus“救召回”。
- 不通过关闭 language/fact/semantic validator 来恢复 Provider 可用性。
- 不静默把用户选择的 ChatGPT 切换成 Qwen，或反向同步图片页/AI Chat preference。

## 24. 风险与预防

| 风险 | 预防/检测 | 回退 |
| --- | --- | --- |
| 中文词典过度扩展造成 false positive | do-not-merge、negative fixtures、term version | 回滚词典 version |
| Embedding 泛匹配压过官方词 | exact boost、authority/status、reranker、critical top-1 gate | 临时禁 vector branch，不算完成 |
| Chunk/parser 再次破坏 Markdown | round-trip/protected token/forbidden pattern tests | active build rollback |
| 模型 planner 申请过多 Context | server policy、bounds、approved/rejected telemetry | deterministic clarification |
| Retry 增加延迟/费用 | coverage gate、一次上限、kill switch、cost report | 关闭 retry |
| 自定义动作泄露 | request-scoped exact match、数量/字段/日志限制 | 不发送 ref，clarification |
| 动作同名错绑 | key/source/hash、ambiguity clarification | 禁止 draft review |
| History 跨账号 | server account id、RLS/service RPC tests | 停用 builder/RPC |
| Grounded segments 增加 provider invalid | strict schema、一次 correction、mock/live canary | legacy pipeline，不放宽 guard |
| 旧客户端不懂 v3 | capability/version negotiation、clarification | v2 safe compatibility |
| Stable docs 提前宣称部署 | W10 同步发布、Roadmap 状态 | 回滚措辞/不 activate |
| Corpus source 移除留下 stale rows | corpus build atomic replacement/parity | previous build |
| 两 Provider 各自复制业务 Prompt 再次漂移 | shared Capability policy/version、adapter boundary test、file ownership | 停止新 adapter，保留已验证 shared core |
| Food understanding 遗漏用户事实 | typed ledger、source precedence、omission/semantic eval、一次 correction | 不返回 Preview，原页修正 |
| 语言 validator 误伤品牌/专有名词 | 主语言 + protected proper-noun reason、zh/en/mixed fixtures | 保留原文专名，不放宽普通说明 Gate |
| macro/kcal 机械校验覆盖标签事实 | versioned tolerance、标签/纤维/糖醇 reason、只报 issue 不改 explicit fact | 保留 explicit label，要求说明/修正 |
| Food 两阶段调用增加延迟/费用 | 分步 telemetry、deadline、固定 W9 budget、无开放循环 | 关闭未通过 provider，不合并成不可验证单次生成 |
| 图片页模型 preference 污染 Chat | 独立 key/repository/widget tests | 清理错误 key 写入，不删用户业务数据 |
| OpenAI 未合法配置或模型能力不兼容 | adapter/contract tests、配置驱动 availability、两处 UI no-request 生命周期提示与自动滑回测试 | ChatGPT 选项保持真实 unavailable；选择器恢复 Qwen 但不触发 hidden provider fallback，Qwen 与 Document RAG 独立可用 |

## 25. Scope 双向追踪矩阵

### 25.1 `RAG-S00` 架构边界

| Scope | 施工包 | 主要 production/contract 文件 | 主要测试、文档与 Gate |
| --- | --- | --- | --- |
| RAG-S00-01 | W8 | `supabase/functions/_shared/ai_output_contract.ts`、`ai-chat-route/index.ts`、`lib/features/food/food_preview_page.dart`、Workout editor handoff | `_shared/ai_output_contract_test.ts`、`ai-chat-route/index_test.ts`、Flutter Preview/editor no-write tests；`docs/en|zh/AIOutputContract.md`；W8 |
| RAG-S00-02 | W6-W8 | `planning/context_policy.ts`、`context_builders.ts`、exercise history RPC、AI Gateway request/response/log paths | auth/subscription/device/record-permission/cross-account/no-write tests；`docs/en|zh/AgentDesign.md`、`CloudLocalDataBoundary.md`；W6-W8 |
| RAG-S00-03 | W3 | `202607130001_rag_foundation_document_hybrid.sql`、`sync_document_embeddings.mjs`、`embedding_client.mjs` | migration/schema/source scan 断言无 user embedding columns/data；`docs/en|zh/RAGDesign.md`、`Database.md`；W3 |
| RAG-S00-04 | W6/W7 | `planning/context_policy.ts`、`context_builders.ts`、`exercise/exercise_context_builder.ts`、exercise history RPC | typed builder bound、server-owned scope、no client SQL/raw history tests；`AgentDesign.md`/`CloudLocalDataBoundary.md`；W6/W7 |
| RAG-S00-05 | W5 | `rag/retrieval_retry.ts`、`retrieval_tool.ts`、`ai-chat-route/index.ts`、provider tool adapters | executions <= 2、retry count <= 1、second retry rejected；`docs/en|zh/RAGDesign.md`；W5/W9 |
| RAG-S00-06 | W0/W11 | 本 scope/plan、`docs/ROADMAP.md`、完成后的 `docs/history/phase5/*` | 第 25/27 节证据检查；未完成 Scope 不得归档或标 COMPLETE；W11 |
| RAG-S00-07 | W8 | `_shared/providers/*`、`_shared/ai_capabilities/*`、Chat/Food provider wrappers | adapter boundary、normalized request、policy/schema/error parity；`AgentDesign.md`/`AIOutputContract.md`；W8/W9 |

### 25.2 `RAG-S01` 至 `RAG-S10`

| Scope | 施工包 | 主要 production/contract 文件 | 主要测试、评测、owning doc | Gate |
| --- | --- | --- | --- | --- |
| RAG-S01 | W1 | `docs/en|zh/*.md`、`README.md`、`docs/API_CONTRACT_DRAFT.md`；代码/Local 仅作为审计证据 | 新 `docs/history/phase5/RAG_FOUNDATION_REMEDIATION_DOCUMENT_AUDIT.md`、bilingual/link/stale wording scans；各 stable doc 按 charter 归位 | W1 |
| RAG-S02 | W1/W4 | 新 `assets/rag/domain_terms.v1.json`、`exercise_catalog.dart`、`exercise_definition.dart`、`app_strings.dart`、`rag/query_normalizer.ts` | term schema/collision/do-not-merge、App label snapshot、双语 retrieval fixtures；`Algorithm.md`/`AppGuide.md`/`RAGDesign.md` | W1/W4/W9 |
| RAG-S03 | W2 | 新 `tool/phase5_document_rag/document_corpus_manifest.v1.json`、`validate_document_corpus.mjs`；`build_document_chunks.mjs`、`supabase/seed_phase5_document_chunks.sql` | `build_document_chunks_test.mjs`、manifest required/unauthorized/bilingual coverage、CloudLocal chunks > 0；`RAGDesign.md` | W2/W10 |
| RAG-S04 | W2 | 新 `chunk_markdown.mjs`；`build_document_chunks.mjs`、seed/artifact metadata | chunk fidelity/round-trip/protected-token/stable-ID tests 和 fixtures；`RAGDesign.md` | W2 |
| RAG-S05 | W1/W4 | `assets/rag/domain_terms.v1.json`、新 `rag/query_normalizer.ts`/`types.ts`、`document_rag.ts` | query normalizer tests、zh/en/mixed/long-query/negative retrieval eval；`RAGDesign.md` | W4/W9 |
| RAG-S06 | W3 | 新 `202607130001_rag_foundation_document_hybrid.sql`、provider-neutral `embedding_client.mjs`、`sync_document_embeddings.mjs`；Qwen Singapore endpoint derivation；`document_rag.ts`/`rag/retrieval_pipeline.ts` | Qwen batch <= 10、model/order/dimension/stale/idempotency/failure/cloud parity tests；`Database.md`/`RAGDesign.md` | W3/W10 |
| RAG-S07 | W4 | `document_rag.ts`、新 `rag/retrieval_pipeline.ts`/`types.ts`、hybrid RPC in W3 migration | branch/fusion/filter/dedupe/failure tests、retrieval eval；`RAGDesign.md` | W4/W9 |
| RAG-S08 | W4 | 新 `rag/retrieval_reranker.ts`、`retrieval_coverage.ts`、versioned weights/config | reranker ranking/authority/non-goal/degraded-order tests、top-1 eval；`RAGDesign.md` | W4/W9 |
| RAG-S09 | W5 | 新 `rag/retrieval_tool.ts`；`providers.ts`、OpenAI/Qwen adapter tool mapping | strict schema/bounds/injection/provider parity/no-user-data tests；`RAGDesign.md`/`API_CONTRACT_DRAFT.md`（仅公开字段变化时） | W5 |
| RAG-S10 | W5 | 新 `rag/retrieval_retry.ts`；`retrieval_coverage.ts`、`ai-chat-route/index.ts`、provider adapters | zero/one retry、second stop、budget/counter/tool timeout/retry gain tests；`RAGDesign.md` | W5/W9 |

### 25.3 `RAG-S11` 至 `RAG-S17`

| Scope | 施工包 | 主要 production/contract 文件 | 主要测试、评测、owning doc | Gate |
| --- | --- | --- | --- | --- |
| RAG-S11 | W6 | 新 `planning/task_plan_contract.ts`、`task_planner.ts`、`context_policy.ts`；`workflow_router.ts`、`expected_output.ts`、`index.ts`、`contracts.ts`、`phase5_types.ts` | planner/policy/fixed-entry/image/implicit-draft/clarification tests；`AgentDesign.md`/`RAGDesign.md`/`API_CONTRACT_DRAFT.md` | W6/W9 |
| RAG-S12 | W7 | `exercise_definition.dart`、`exercise_catalog.dart`、新 catalog exporter/snapshot；`ai_exercise_reference_builder.dart`、`exercise_reference.ts`、`exercise_resolver.ts`、`exercise_context_builder.ts` | catalog parity、builtin/custom exact/alias/ambiguity/permission tests；`Algorithm.md`/`Database.md`/`CloudLocalDataBoundary.md`/`AgentDesign.md` | W7 |
| RAG-S13 | W7 | 新 `202607130002_rag_foundation_exercise_history.sql`、`exercise_context_builder.ts`、`context_builders.ts` | account/exercise/date/row bounds、permission on/off、legacy/conflict/no-raw-row tests；`Database.md`/`CloudLocalDataBoundary.md`/`AgentDesign.md` | W7/W9 |
| RAG-S14 | W7 | `_shared/ai_output_contract.ts`、provider schemas/prompts、`ai_workout_draft.dart`、Gateway request、workout draft repository/editor handoff | Draft v3 binding/hash/mode/unresolved/no-ad-hoc fallback/persistence/editor/no-write tests；`AIOutputContract.md`/`API_CONTRACT_DRAFT.md` | W7/W10 |
| RAG-S15 | W8 | 新 `grounding/*`、`prompt_builder.ts`、`ai-chat-route/index.ts`、`ai_gateway_evidence.dart`/response/UI | evidence registry/claim coverage/unsupported claim/citation mapping/provider correction tests；`AIOutputContract.md`/`RAGDesign.md` | W8/W9 |
| RAG-S16 | W8 | `ai-chat-route/contracts.ts`/`index.ts`、Gateway request/response/error/client、`202607130003_rag_foundation_observability.sql` | public/server-owned/auth/redaction/old-client/error-code tests；`API_CONTRACT_DRAFT.md`/`Database.md`/`AgentDesign.md` | W8/W10 |
| RAG-S17 | W8/W9 | planner/RAG/provider/capability orchestration、timeouts/budgets/issues in `index.ts` 与 shared contracts | W9 failure injection、deadline/degraded/no-false-source/no-write tests；`RAGDesign.md`/`AIOutputContract.md`/`AgentDesign.md` | W8/W9 |

### 25.4 `RAG-S18` 至 `RAG-S22`

| Scope | 施工包 | 被评测的 production 文件 | 评测文件/报告与 owning doc | Gate |
| --- | --- | --- | --- | --- |
| RAG-S18 | W2/W3/W9 | manifest/chunker/seed、embedding tooling、hybrid migration/active build | `test/evals/fixtures/corpus_ingestion.v1.json`、tool tests、parity report；`RAGDesign.md`/`Database.md` | W9/W10 |
| RAG-S19 | W9 | W4/W5 的 normalizer/hybrid/reranker/tool/retry；此 Scope 不另建运行时代码 | `test/evals/fixtures/document_retrieval.v1.json`、`run_rag_eval.mjs`、`build_rag_report.mjs`；`RAGDesign.md` | W9 |
| RAG-S20 | W6/W7/W9 | planner/context policy、exercise definition/history、Workout Draft binding；此 Scope 不另建平行实现 | `structured_context.v1.json`、`routing_workflows.v1.json`、`actions_permissions.v1.json`；`AgentDesign.md`/`RAGDesign.md` | W9 |
| RAG-S21 | W8/W9 | grounding/output contract/API/UI/provider adapters；此 Scope 只增加 eval/必要 instrumentation | `output_faithfulness.v1.json`、`safety_privacy.v1.json`、provider parity fixtures/report；`AIOutputContract.md`/`AgentDesign.md` | W9/W10 |
| RAG-S22 | W5/W8/W9 | retrieval retry、failure/budget/telemetry paths；此 Scope 不复制生产逻辑 | `retry_failure_performance.v1.json`、failure-injection runner、latency/cost report；`RAGDesign.md`/`Database.md` | W9/W10 |

### 25.5 `AI-S01` 至 `AI-S06`

| Scope | 施工包 | 主要 production/contract 文件 | 主要测试、评测、owning doc | Gate |
| --- | --- | --- | --- | --- |
| AI-S01 | W8 | 新 `supabase/functions/_shared/ai_capabilities/*`、`_shared/providers/*`；Chat/Food provider wrappers | adapter boundary、normalized request、policy/schema/version parity；`AgentDesign.md`/`AIOutputContract.md` | W8/W9 |
| AI-S02 | W8 | 新 `_shared/ai_capabilities/food/food_contract.ts`、`food_policy.ts`、`food_orchestrator.ts` | food understanding/source precedence/fact omission fixtures；`AIOutputContract.md` | W8/W9 |
| AI-S03 | W6/W8 | Chat planner/index、`supabase/functions/ai-food-photo-analyze/*`、shared Food Core | cross-surface policy/validator parity、专用 no-RAG/no-Chat-loop；`AgentDesign.md`/`Product.md`/`AppGuide.md` | W8/W9 |
| AI-S04 | W8 | 新 `food_semantic_validator.ts`、`_shared/ai_output_contract.ts`、provider correction mapping | zh/en/mixed、20g vs 8.5、notes/field、nutrition tolerance、invalid escape=0；`AIOutputContract.md` | W8/W9 |
| AI-S05 | W8/W10 | `photo_food_analysis_page.dart`、共享 sliding selector、`ai_food_photo_analysis.dart`、client/localization/recovery/Preview | independent preference、input retention/revision、OpenAI unavailable notice/animated return/no-request、Preview/no-write、configured APK；`Product.md`/`AppGuide.md`/`Database.md` | W8/W10 |
| AI-S06 | W8-W10 | OpenAI/Qwen Chat/Food adapters、配置驱动 availability、Food/Chat contracts/index、observability migration | Qwen text/image live canary；OpenAI adapter contract tests 与两处 unavailable/animated-return/no-request/no-hidden-fallback UI tests；redaction；`AgentDesign.md`/`AIOutputContract.md`/`API_CONTRACT_DRAFT.md` | W9/W10 |

### 25.6 Deliverables `RAG-D01` 至 `RAG-D09`、`AI-D01` 至 `AI-D02`

| Deliverable | 计划落点 | 完成证据 |
| --- | --- | --- |
| RAG-D01 | 本节矩阵 + 实施状态/偏差记录 | 所有 Scope 有 code/test/report link |
| RAG-D02 | W1/W8/W10 | 双语 stable docs、terms、API/RAG/Agent/output contract diff |
| RAG-D03 | W2/W3 | manifest、chunker、seed、embedding、migration、active build parity |
| RAG-D04 | W4/W5 | segmentation、normalization、hybrid、reranker、tool、retry tests |
| RAG-D05 | W6/W7 | planner/policy、definition/history、draft v3 E2E |
| RAG-D06 | W8 | grounding guard、failure matrix、logs/error behavior |
| RAG-D07 | W9 | deterministic/live fixtures、reports、manual acceptance |
| RAG-D08 | W10/23 | deployment record、backfill、canary、rollback、compatibility |
| RAG-D09 | W11 | Roadmap/CHANGELOG/stable docs/归档链接 |
| AI-D01 | W8 | provider-independent layers、shared Food Core/validator、OpenAI/Qwen adapter code/tests |
| AI-D02 | W8-W11 | 独立图片 Provider UX、统一多模态生成模型、provider/semantic eval、stable docs、canary/rollback/归档证据 |

## 26. 最终完成定义

只有以下全部满足才可把本计划标为 COMPLETE：

1. 所有 W0-W11 Gate 通过，且 W8 的 AI Capability/Food 子 Gate 不得被 Grounding 子项替代。
2. 25 节所有 Scope/Deliverable 行都有实际证据，不是只改 checkbox。
3. 全部本地自动化、Edge checks、Flutter tests、eval 和 configured APK build 通过。
4. 本轮七份 additive migration、active corpus、embeddings 和 Edge 已部署到确认环境。
5. Corpus manifest/seed/cloud active build/parity 完全一致。
6. Stable docs、公开 API、代码、UI 与云端行为一致。
7. Bulgarian 官方触发案例、中文 aliases、英文/mixed cases 全部正确。
8. 内置/custom action definition、history、Draft v3 binding 全部正确。
9. 无 evidence 的 FitLog 专属确定性回答为 0。
10. 未确认 official food/workout/profile writes 为 0。
11. Search 最大 2 次，retry 最大 1 次，output correction 最大 1 次。
12. 权限、隐私、跨账号、raw history、prompt injection tests 全部通过。
13. W9 固定质量/性能/费用阈值通过并生成报告。
14. Roadmap/CHANGELOG/归档准确完成，旧计划没有被误当当前执行依据。
15. `AI-S01` 至 `AI-S06`、`AI-D01` 至 `AI-D02` 全部有 production file、test/eval、owning doc 和 canary/rollback 证据。
16. AI Chat/专用图片分析共享 Food Capability 后，wrong-language、user-fact mismatch、notes/field contradiction 和 invalid Preview escape 均为 0。
17. 图片分析 ChatGPT/千问 preference 与 AI Chat preference 隔离；Qwen text/image live parity 通过；OpenAI 未合法配置时两处 ChatGPT 选择均通过 unavailable/no-request/no-fallback tests，adapter 保留且不构成当前核心发布依赖。

## 27. 实施状态、偏差与证据记录模板

后续 Codex 在施工时更新本节，不要把运行日记散落到 stable docs。

### 27.1 施工状态

| Work package | Status | Code/Doc summary | Validation evidence | Deployment evidence |
| --- | --- | --- | --- | --- |
| W0 | COMPLETE | 冻结 commit `209c556a032f163339b2df93ac11bf9d41e28ed1`、`main` 与 dirty-file 基线；保留用户既有修改并建立 fail-closed flags、baseline fixtures 和 rollback 参照。 | 基线与最终 diff 均未清理用户修改；pipeline flag tests 纳入最终 Edge 全集。 | 部署前记录为 Edge chat v21/photo v14、旧 corpus/legacy pipeline；可作为行为回滚基线。 |
| W1 | COMPLETE | 审计 47 个 Markdown；修复 Local 冻结文档链接；建立版本化 domain/exercise 术语并把力量输入语义与 Bulgarian split squat 写回双语 owning docs。 | 文档、链接、双语、UTF-8、术语、57 项 catalog 与 Bulgarian 触发测试通过；审计见 `docs/history/phase5/RAG_FOUNDATION_REMEDIATION_DOCUMENT_AUDIT.md`。 | 无外部写入。 |
| W2 | COMPLETE_DEPLOYED | 21 个稳定文档由 canonical manifest 管理；lossless chunker 与 generator v4 保留 protected tokens；ingestion/query 统一有界重叠中文 2-4 gram，embedding timeout 时仍能 lexical failover。P7 owning-doc 与报告入口维护后已重建并发布 corpus。 | Node corpus/docs/terms/assets/migration tests 20/20；build `99d908c576c844fd3c39d853`、577 chunks、21 sources、manifest SHA-256 `e6f00671fa6a2f8b667b5f7171dc46c2c5a9f10e73a913cd4a55062c5c99e087`，corpus validation 通过。 | 用户明确授权稳定文档外发后，577-chunk build 已上传并原子激活；独立回读为 active。 |
| W3 | COMPLETE_DEPLOYED | Additive pgvector/build migration、service-role-only RPC、Qwen Singapore `text-embedding-v4`、1536 维、batch <= 10、stale/extra pruning 和 atomic artifact write 完成。 | Embedding tests 6/6；本地 parity 577 matching、0 missing、0 stale、0 extra；cloud 577 rows、0 mismatched。 | Migrations `202607130001`、`202607150003`、`202607150004` 已应用；active build `99d908c576c844fd3c39d853` 为 577/577。 |
| W4 | COMPLETE_DEPLOYED_ENABLED | zh/en/mixed normalization、exact/term/FTS/trigram/vector、indexed lexical-candidate 与 embedding 并发、v3 全局 SQL rank/fusion、30 final candidates、owning-document reranker v2、单语优先与 vector-only no-answer fail-closed 完成。 | 24-candidate A/B 虽过最低阈值但 precision 降至 89.74%，故保留 30；final recall@3 100%、reviewed precision@3 97.44%、critical top-1 100%、no-answer fabricated source 0，正常 Edge retrieval p95 1,250/1,299 ms。 | Migrations `202607150003`、`202607150004` 与 Edge chat v44 已部署；`AI_CONTEXT_PIPELINE_VERSION=rag_foundation_v1` 保持启用。 |
| W5 | COMPLETE_DEPLOYED_ENABLED | `search_fitlog_docs` 使用严格 provider-neutral schema；bounded rewrite 最多一次，server revalidation、coverage、gain 与独立 correction counter 完成。Complete/conflicting、unknown exact identifier、unchanged rewrite 均在第二次 search 前停止。 | Retrieval/retry tests 28/28；release canary 及 stress probe 均为首次 retrieval complete/确定性 stop，retry/no-gain 均为 0。Useful-retry path 有确定性 coverage-gain regression，但当前 production corpus 未产生 live useful-retry 样本，因此不伪报 conditional retry p95。 | `DOCUMENT_RAG_RETRY_ENABLED=true`；功能保留且无 silent disable。 |
| W6 | COMPLETE_DEPLOYED_ENABLED | `task_plan.v1` 在 Context Builder 前运行，确定性 resolver 优先，只有未决请求使用 model planner；server Context Policy 在任何 builder/embedding 前裁剪权限；planner clarification 使用实际 Provider id。 | Deterministic/model planner、permission clamp、Food/image/Workout/App Logic/same-chat/general-chat tests 通过；final all-workflow canary 的 model-planner path 首次通过。 | Edge chat v44；new pipeline 启用。 |
| W7 | COMPLETE_DEPLOYED_ENABLED | 57 项 catalog snapshot、request-scoped custom references、definition/history Context、permissioned history RPC、`workout_draft.v3` binding 与 Flutter hash revalidation 完成；chat-turn RPC 已与新 workflow table contract 对齐。 | Catalog/custom/builtin handoff、Bulgarian alias/key/ambiguity、Flutter 223/223 通过；`record_schema_mismatch` 根因已由 additive migration 修复。 | Migrations `202607130002`、`202607150002` 已应用；new pipeline 启用。 |
| W8 | COMPLETE_DEPLOYED_LOCAL_UI_REFINED | Grounding guard v2、failure matrix、observability、共享 Food Capability、事实/语言/semantic Gate、独立图片 Provider 选择、OpenAI/Qwen adapters 与未配置 OpenAI UI unavailable 行为完成；两处 selector 统一为底部导航 240 ms 滑动语义并自动恢复 Qwen。Qwen 只接收 selected family contract，controlled Context 去重并紧凑序列化，text/draft/Food budgets 为 384/1600/1200。 | Required Edge 61/61、full Edge 130/130、Flutter 223/223；`flutter analyze` 无问题；final canary 8/8 workflow first-pass valid、correction/final failure 0；Food text/image live 通过；两处 ChatGPT unavailable/no-request/input-preservation tests 通过。 | Migrations through `202607150004`，chat v44、photo v21 已部署；OpenAI 无 remote secret，不是当前核心依赖。 |
| W9 | COMPLETE_RELEASE_SET_CONDITIONAL_RETRY_UNSAMPLED | P0-P7 专项报告保留 baseline、失败实验、根因、修复与最终证据。失败的简化 parallel fusion 因质量下降被拒绝；production v3 保持全局 rank。 | Final release 28/28：recall/precision/top-1 100%/97.44%/100%，正常 Edge retrieval p50/p95 1,061/1,250 ms；重复 text-budget p95 1,299 ms。八概念 stress 首次 complete 3/3，但 p95 1,566 ms；conditional useful-retry 因当前 0 次触发而无 live p95，旧 no-gain retry 约 3,839 ms 且该触发已被禁止。 | 不降低阈值、不切 legacy、不关闭 retry。正常发布 Gate 通过；stress 与 retry 条件样本限制在专项报告中显式保留。 |
| W10 | COMPLETE_DEPLOYED_CANARY_ENABLED | 七项 RAG foundation/diagnostic migrations、active corpus/vectors、Edge 与 configured split APK 已部署；真实 canary 后保持用户确认的 foundation/retry 状态。 | Required/full Edge 61/61、130/130；Node 20/20；Flutter 223/223；final cloud 28/28；refresh recheck 26/26；migration history aligned；runtime config hashes verified。 | `AI_CONTEXT_PIPELINE_VERSION=rag_foundation_v1`、`DOCUMENT_RAG_RETRY_ENABLED=true`；chat v44/photo v21；stable-doc build `99d908c576c844fd3c39d853` active。 |
| W11 | COMPLETE | Bilingual stable docs、Roadmap、CHANGELOG、专项报告与本计划已整合到当前事实；legacy compatibility 作为显式 rollback point 保留。 | Corpus `99d908c576c844fd3c39d853`（577 chunks/21 sources）通过 generation、embedding、local/cloud parity、docs/link/UTF-8/stale wording checks；refresh recheck 26/26。 | 用户明确授权后，88 个 missing/stale inputs 已通过 Qwen 重建，72 extra 已清理，build 已同步、activate 并回读为 active；无剩余文档外发阻塞。 |

### 27.2 实施偏差记录

| Date | Planned assumption | Actual finding | Impacted Scope | Decision | User approval needed |
| --- | --- | --- | --- | --- | --- |
| 2026-07-14 | W0 从可识别的工作树基线开始。 | 工作树已有 `AGENTS.md`、README、Roadmap、双语 RAGDesign、seed 修改，旧 Phase 5 根计划已移动至 `docs/history/phase5/`，本 Scope/计划尚未跟踪。 | RAG-S00-06、RAG-S01、RAG-S03、RAG-D01、RAG-D09 | 全部视为用户既有修改并保留；后续在内容级 diff 基础上追加，不回滚或覆盖。 | 否 |
| 2026-07-14 | W0 记录目标 Supabase 的 active corpus/hash/Edge 基线。 | 本地配置仅含 URL/anon；当前环境未提供 service-role、OpenAI 或 Qwen secrets，不能安全读取管理面状态或运行 live probe。 | RAG-S18、RAG-D07、RAG-D08 | 本地工程继续；W0 保持 `IMPLEMENTED_NOT_DEPLOYED`，在 W10 获得明确目标与授权后补齐云端基线、部署和 canary 证据。 | 是（W10 外部操作前） |
| 2026-07-14 | AI capability 按计划拆入多个 `_shared/ai_capabilities/*` 与 `_shared/providers/*` 文件。 | 现有 provider adapters 已有稳定边界；为避免平行实现，统一 Food understanding/policy/validator 集中在版本化 `_shared/food_capability.ts`，现有 OpenAI/Qwen adapters 只消费 normalized capability request。 | AI-S01 至 AI-S04、AI-D01 | 保持同一四层职责和 parity Gate，不改变 Scope；记录等价、小型代码组织偏差。 | 否 |
| 2026-07-15 | 原中文切分可用不重叠短块覆盖 embedding failure。 | “FitLog 的产品承诺是什么”在一次 query embedding timeout 时跨 4 字边界，lexical branch 只返回英文候选。 | RAG-S05、RAG-S07、RAG-S17、RAG-S19 | Ingestion/query 同步升级为 generator v4 的有界重叠 2-4 gram，优先 4-gram；增加 vector-only no-answer fail-closed 与 60-candidate 计划上限。 | 否 |
| 2026-07-15 | Singapore Qwen embedding + hybrid DB 正常路径 p95 <= 1,500 ms，retry increment <= 3,500 ms。 | 逐段复测证明 embedding 通常不是主瓶颈：Edge initial embedding 常见 0.7-0.8 s，hybrid RPC 最高约 6.3 s；retry 的 rewrite planner 约 2.6 s、第二次 RPC 最高约 6.6 s，中文 document Context p95 16.6 s。另发现 Provider output correction 会扩大总耗时并仍可能失败。 | RAG-S17、RAG-S22、RAG-D07、RAG-D08、W9-W11 | 保留原阈值与完整报告；按用户确认维持 `rag_foundation_v1`/retry on，不再因 Gate 失败自行回退。后续优化 SQL 执行形态、retry 触发和 Provider contract reliability，未经批准不降低质量或切换 Provider。 | 否 |
| 2026-07-15 | Stable owning-doc refinement 后按 AGENTS.md 重新生成并同步 Document RAG。 | 逐段诊断文档整合后，本地已生成 572-chunk build `86820ab67bab9ba229f08530`；执行环境要求用户在知情后明确授权把稳定仓库文档 chunk 文本发送给外部 Qwen embedding API，既有广义部署授权不足以继续。 | RAG-S03、RAG-S06、RAG-D02、RAG-D08、W2/W3/W10/W11 | 不绕过审查；保留云端旧 active build 与当前 foundation runtime，等待明确授权后只重建 35 个变化/新增 embedding、清理 31 个 extra、同步并校验 parity。 | 是 |
| 2026-07-15 | 直接并行 lexical/vector 结果并在 Edge 简化融合可降低延迟且保持质量。 | 第一版 parallel retrieval 把 recall/precision/critical top-1 降至 84.62%/84.21%/80%；24 final candidates 虽通过最低阈值，precision 仍由 94.87% 降至 89.74%。 | RAG-S07、RAG-S08、RAG-S19、RAG-S22 | 拒绝质量降级方案。采用 v3：lexical candidate IDs 与 embedding 并发，PostgreSQL 继续计算原全局 scores/ranks，production 保留 30 final candidates。 | 否 |
| 2026-07-15 | 优化后应能对一个 live useful retry 直接计算 p95。 | 版本化中英/mixed、unknown identifier 与八概念 stress 均首次 retrieval complete 或确定性 stop，production canary 为 0 retry；因此没有 current useful-retry 分母。Stress retrieval p95 1,566 ms，超过正常门槛 66 ms，但非默认 release query set。 | RAG-S09、RAG-S22、RAG-D07、W5/W9 | 不制造 production retry、不把旧 no-gain retry 当成功样本；报告 normal-set pass、stress observation 与 conditional retry unsampled。保留 retry flag/功能及 deterministic coverage-gain test。 | 否 |

任何会删除、延期、降级或重新解释 Scope 的偏差都必须先获得用户确认；文件名变化或等价的小型代码组织调整可记录后继续。

### 27.3 Landing summary（完成时填写）

- Final commit/branch：未创建 commit；`main` dirty worktree 按 W0 保护。
- Supabase project/environment：`dyacqajcinjwrkbngeif`；用户确认目标环境。
- Applied migrations：`202607130001_rag_foundation_document_hybrid.sql`、`202607130002_rag_foundation_exercise_history.sql`、`202607130003_rag_foundation_observability.sql`、`202607150001_rag_latency_breakdown.sql`、`202607150002_ai_chat_turn_rag_workflows.sql`、`202607150003_rag_hybrid_indexed_candidates.sql`、`202607150004_rag_parallel_candidate_fusion.sql`。
- Edge version/model config：`ai-chat-route` v44、`ai-food-photo-analyze` v21；Qwen `qwen3.7-plus`；provider deadline 45,000 ms；当前 `rag_foundation_v1`/retry on。
- Capability/policy/validator versions：`task_plan.v1`、`rag_context_policy.v1`、`fitlog_document_reranker.v2`、`fitlog_grounding_guard.v2`、共享 Food/output validators。
- Food page provider preference key/default：独立本机 key，默认 Qwen；未配置 ChatGPT 显示 unavailable、使用共享动画自动滑回 Qwen 且不发送。
- OpenAI/Qwen text/image capability matrix：Qwen text、Food text/image live 通过；OpenAI adapter/contract tests 保留，UI unavailable/animated-return/no-request/no-hidden-fallback 通过，无 OpenAI live secret/canary。
- Active cloud corpus build/manifest hash：`99d908c576c844fd3c39d853` / `e6f00671fa6a2f8b667b5f7171dc46c2c5a9f10e73a913cd4a55062c5c99e087`；577 chunks / 21 sources；cloud mismatched 0。
- Embedding model/dimension/version：Qwen `text-embedding-v4` / 1536 / `document_embedding_input.v1`；local/cloud active 577/577，missing/stale/extra/mismatched 均为 0。
- Catalog snapshot version/hash：57 exercises / `7a04ae33188c7e5907c09c04076b15a0a3b1499b9bdfd62f1fe6b84d4a3a26f8`。
- Eval report：`docs/reports/RAG_RELIABILITY_OPTIMIZATION_REPORT.md`；raw final evidence 继续保存在 `test/evals/reports/`：`rag_foundation_cloud_p6_text_budget.v1.{json,md}`（27/27）、`rag_foundation_cloud_p6_release.v1.{json,md}`（28/28）、`rag_foundation_cloud_p6_useful_retry.v1.{json,md}`（stress/retry sampling evidence）。
- APK artifact：`build/app/outputs/flutter-apk/app-{armeabi-v7a,arm64-v8a,x86_64}-debug.apk`；arm64 `74EAF30E2F667B755AD557064B2AB6A4902032AAA3B6695830E80275FEC3C8E0`，armeabi-v7a `D71E3FFB9AA084B5DEC8B40CAF973F736553203B6B252E6352A040AF2F4E38B8`，x86_64 `16FEC2772865B8B344E0B7482F08BB4E9B170CCEF0EDBA082FDF20D030582C78`。
- Rollback point：部署前 Edge chat v21/photo v14 仍保留为历史参照；当前没有执行 runtime rollback，foundation/retry 均启用。
- Known blocker：stable-doc egress 授权与 corpus refresh 已收口；当前无部署阻塞。八概念 stress p95 1,566 ms 与 conditional useful-retry live p95 无样本仍保留在专项报告，不伪报或通过阈值降级消除。
