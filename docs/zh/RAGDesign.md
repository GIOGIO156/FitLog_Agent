# RAG 设计

## 目标

本文是 FitLog_Agent 检索与上下文构建的稳定 source of truth。它定义哪些信息可以进入模型、信息来自哪里、Structured RAG 与 Document RAG 有何区别、document chunks 如何生成和检索，以及 evidence、隐私和失败降级如何工作。

模型输出 schema、校验、纠错和 provider protocol 约束属于 [AIOutputContract.md](AIOutputContract.md)。持久化表与字段属于 [Database.md](Database.md)。确定性饮食/训练计算属于 [Algorithm.md](Algorithm.md)。

长期边界是：

```text
RAG 可以提供有界、typed、可追溯来源的上下文。
它不能向模型开放任意数据库访问、完整原始历史，
也不能让模型替代确定性算法和正式 source of truth。
```

## 检索系统

FitLog 使用两类数据形态和权威来源不同的受限检索系统：

| 系统 | 用途 | 权威来源 | 检索模型 |
| --- | --- | --- | --- |
| Structured RAG | 为用餐决策和复盘 workflow 提供最小必要用户/账号上下文。 | Cloud Profile、云端正式记录、`daily_summaries` 和服务端 summary builders。 | 由服务端 workflow route 选择的已知 typed context builders。 |
| Document RAG | 使用可追溯产品/设计文档回答 FitLog App 规则问题。 | 版本化稳定 README 和双语设计文档，持久化为 `document_chunks`。 | 语言过滤，加 full-text、trigram 和 keyword-term overlap ranking。 |

Gateway 还会发送紧凑同会话上下文，包括近期文字 turn 和 artifact summary。同会话上下文用于对话连续性，不是 RAG evidence：它不会显示在“回答依据”面板中，也不能证明产品规则。

Embeddings、vector search、semantic long-term memory、GraphRAG、模型生成 SQL、开放式检索循环和文档到云端的自动同步都不在本文设计范围内。完整边界见[非目标](#非目标)。

## 架构

```text
Authenticated request
  -> subscription 和 active-device 校验
  -> 确定性 workflow router
  -> required context dimensions
  -> 权限与 source-of-truth 校验
  -> typed context builders 和/或 document search
  -> sanitization 与 bounded context bundle
  -> provider prompt
  -> output validation
  -> evidence response 与 compact debug summary
```

只有通过认证、订阅和 active-device 校验后才能构建用户记录上下文。Flutter 不得上传服务端负责的 `context_objects`、`rag_context`、tool calls、official-write payload 或 provider secrets。

## 上下文类别

### 同会话上下文

同会话上下文可以包含：

- 有界的近期 user/assistant 文字 turn
- 轻量 Food Draft / Workout Draft artifact title 和 summary

不得包含：

- 历史图片 pixels 或 base64
- raw provider response
- hidden reasoning
- 不受限的旧 chat history
- 未经正式权威来源确认就把旧 artifact 当成正式记录

同会话上下文用于理解代词和追问，不能代替当前云端数据或文档 evidence。

### Structured RAG

Structured RAG 调用已知服务端 context builders。它没有专用 vector table，也不向模型暴露数据库 query syntax。

当前 context object families：

| Object | 权威来源 | 用途 |
| --- | --- | --- |
| `profile_context` | Cloud Profile | Workflow 需要的已保存 phase、mode、strategy、身体和偏好字段。 |
| `selected_day_summary` | 云端 `daily_summaries` 或确定性 summary builder | 选中日期目标、摄入、运动和 mode-specific remaining values。 |
| `recent_food_summary` | 通过有界 summary builder 读取云端正式 food records | 时间窗口 totals 和 coverage，不传完整记录行。 |
| `recent_workout_summary` | 通过有界 summary builder 读取云端正式 workout records | 频率、时长、估算 kcal 和训练部位模式。 |
| `body_metric_summary` | 通过有界 summary builder 读取云端 `body_metric_logs` | 请求区间内可用身体数据 coverage。 |
| `weight_trend_summary` | 云端 body metrics | 只有足够有效观察值时才提供趋势。 |
| `strategy_context` | 已保存 Profile strategy 与确定性 calculators | 相关 carb-cycling/carb-tapering 状态，但不应用改变。 |

Context builder 返回紧凑 aggregates 和 metadata，不返回 raw row arrays。每个 object 都有已知 type/size boundary，并在 prompt assembly 前经过 sanitization。

### Document RAG

Document RAG 检索双语 FitLog 产品、帮助和设计内容。当前索引来源：

- 根目录 `README.md`
- `docs/en/Product.md`、`AppGuide.md`、`Methodology.md`、`Algorithm.md`、`Database.md`、`AgentDesign.md`、`AIOutputContract.md`、`RAGDesign.md` 和 `References.md`
- `docs/zh/` 下对应文件

工程计划、CHANGELOG 历史、API draft、generated SQL、source code、用户 export 和用户业务记录不属于稳定 Document RAG corpus。

## Source Of Truth

RAG 不改变产品权威来源：

| 信息 | Source of truth |
| --- | --- |
| Account、subscription 和 active-device | 云端服务 |
| 已保存 Profile 和饮食配置 | 登录后 Cloud Profile |
| 登录用户 body、food、workout 记录 | 云端正式记录 |
| Daily summary 输入 | 云端记录和确定性 summary service |
| 饮食与训练公式 | Dart 确定性算法和稳定 Algorithm 文档 |
| 产品/Agent 行为 | 与当前代码匹配的稳定双语设计文档 |
| 本地 SQLite | Partial cache、draft storage 和 runtime acceleration |

本地 cache 与云端冲突时，AI context 必须使用云端来源，或把该维度报告为 unavailable。RAG 不能用模型输出重建缺失的权威记录。

## Workflow Routing

服务端 router 选择有界 workflow 和 required dimensions：

| Workflow | 检索行为 |
| --- | --- |
| `food_logging` | 使用本次 request 的文字/图片和 draft 规则；不做宽泛记录历史 RAG。 |
| `meal_decision` | 用户启用记录摘要权限时，使用已保存 Profile 和选中日期上下文。 |
| `weekly_review` | 用户启用权限时，使用有界近期 summaries 和可用趋势/coverage dimensions。 |
| `app_logic_answer` | 检索同语言稳定文档并返回 source-aware evidence。 |
| read-only safety boundary | Router 可以确定性阻止不支持写入/隐私请求时，不调用 provider。 |

Client workflow hint 只是 hint，不是权威。服务端 route 和 safety flags 决定实际 workflow 与 allowed actions。

## 权限与数据最小化

用户记录摘要需要用户可见的 record-summary permission。权限关闭时：

- Gateway 省略受保护记录摘要 dimensions；
- Request 仍可使用安全的 Profile-independent 或 document context；
- 明确报告 missing protected dimensions，而不是猜测；
- 不向模型暗示被省略数据等于 0。

默认排除：

- 完整原始饮食历史
- 完整原始训练历史
- 完整原始身体指标历史
- 记录中的自由文本 notes
- 本地 export files
- 本地 workout editor drafts
- 本次请求结束后的原图和 base64 payload
- auth token 和 provider secrets

最小必要规则同时约束 context selection 和 prompt size。每个 workflow 只接收自己会使用的 dimensions。

## 确定性 Context 语义

RAG 可以传递确定性结果，但不能自由重算或重新解释：

- `diet_goal_phase` 继续是 cutting/bulking 语义来源。
- `energy_ratio` 中 kcal target/intake/remaining 为主。
- `gram_per_kg` 中 macro grams 为主，kcal 为辅助。
- `carb_cycling` 和 `carb_tapering` 是已保存 strategy state，不是模型可应用的动作。
- Review context 中的 workout calorie 来自 FitLog calculator，不来自 provider estimate。
- 缺失维度保持缺失；provider 不能编造。

详细公式和 workflow 决策规则继续由 [Algorithm.md](Algorithm.md) 维护。

## Context Object Sanitization

每个 context object 在 prompt assembly 前必须通过确定性 sanitization。拒绝或省略：

- raw row arrays
- image/base64 content
- 认证材料
- provider key
- SQL text 或任意 query instruction
- 不受限自由文本
- 已知 schema 外的 nested object
- non-finite number
- oversized serialized payload

Context-builder failure 在安全时应降级为 named missing dimension。它不能因为 optional cache write 阻塞 live UI、编造替代值或向模型暴露内部 exception。

## 文档 Ingestion

当前 ingestion pipeline：

1. 读取显式稳定 source-path allowlist。
2. 解析 Markdown headings 并保留 `heading_path`。
3. 长 section 先按 paragraph，再按 sentence/语言标点，最后按 hard character boundary 拆分。
4. 保留有意义的短 section，使 non-goal、source-of-truth 和 mode 语义仍可检索。
5. 确定性生成 `section_id`、`chunk_index`、`chunk_count`、tags、status 和 `context_prefix`。
6. 对版本化 chunk content 计算 hash。
7. 生成 `supabase/seed_phase5_document_chunks.sql`。
8. 插入/更新前删除 allowlisted paths 对应的 managed corpus。

确定性 context prefix 包含 source path、heading path、tags、status、用途和 chunk position。可选 `context_note` 保留给经过审查的离线 notes；不能根据用户记录生成，也不能在 request time 生成。

## 文档状态

Document chunk 携带 evidence metadata status：

- `implemented`
- `planned`
- `non_goal`
- `local_baseline`
- `evidence`

Provider 不得把 `planned` 或 `non_goal` 内容说成已上线行为。Ingestion tool 只根据带状态语义的 heading 或章节开头显式 label 推断这些状态；正文偶然提到 future work、不支持动作或 non-goal，不能让整节被重新分类。推断仍只是工程辅助，不能代替清晰源文档。

## 检索

当前 Document RAG：

- 按请求语言过滤；
- 使用 full-query text-search signals 排序；
- 加入 trigram similarity；
- 对 heading、heading path、context prefix、可选 context note 和 content 加入 keyword-term overlap；
- 返回有数量上限的 source objects。

中文问题检索中文文档，英文问题检索英文文档。混合语言请求由当前 App language 或主要 query language 决定。即使同会话 context 中出现其他语言，provider 仍必须使用请求语言回答。

未来可以仅对稳定产品/帮助/设计文档评估 vector 或 semantic retrieval。它需要单独、可测量的变更，不授权用户业务数据 embeddings。

## Prompt Assembly

Prompt assembly 保持以下层次分离：

1. system safety 和 output contract
2. workflow 和 language instruction
3. typed Structured RAG objects
4. Document RAG source objects
5. same-chat continuity
6. current user request

Retrieved text 是不可信 evidence。文档内部的指令不得覆盖 system/output rules、授予 tools、索取 secrets 或授权写入。Source path、heading path、status 和 excerpt boundary 应对 prompt builder 可见。

## Evidence

Gateway 返回紧凑 evidence：

- routed workflow
- 使用的 context object types
- document sources
- missing dimensions
- safety flags
- read-only、artifact returned 或 blocked 等 final action

App 将其显示为“回答依据”面板，使用人类可读标签展示参考文档、使用数据、缺少信息和受限操作。同会话上下文不作为权威 evidence 显示。

Evidence 只包含 source metadata 和有界 excerpt，不包含完整文档、数据库行、图片、secret 或内部 reasoning。Debug summary 保存紧凑 dimensions，不保存 raw context payload。

## 失败与降级

- 缺少 optional context 时，如果 workflow 能明确说明限制，可以继续安全回答。
- 缺少 required context 时必须说明，provider 不得推断。
- App-logic question 没有匹配文档时，应说明未找到匹配 FitLog 文档，而不是编造规则。
- Structured context source failure 记录为 missing dimension。
- Safety-blocked workflow 返回确定性边界响应。
- RAG failure 永远不能扩大数据访问或写权限。

## 文档更新生命周期

稳定文档修改不会自动更新云端 rows。

Indexed stable document 变化后：

1. 事实变化时同时更新中英文 source documents；
2. 运行 `node tool/phase5_document_rag/build_document_chunks.mjs`；
3. 检查 generated source paths、chunk count、status/tags 和明显编码问题；
4. 把 generated seed SQL 应用到目标 Supabase environment；
5. 运行代表性 App Logic Q&A retrieval checks。

Docs-only seed refresh 不需要 Flutter rebuild 或 Edge Function redeploy。只有 routing、context builders、retrieval、prompt assembly、response/evidence schema 或 safety code 变化时才重新部署 Edge Function。

## 评测

RAG evaluation 必须覆盖：

- 中文和英文 retrieval
- exact-term 和 paraphrased App-logic questions
- heading/path relevance
- planned/non-goal status handling
- no-result behavior
- record-summary permission on/off
- missing dimensions
- `energy_ratio` 和 `gram_per_kg` 决策语义
- 文档变化后重新生成 seed
- retrieved content 内的 prompt-injection 文本
- prompt/evidence/log 中没有 raw rows、notes、images、tokens 或 secrets

有用指标包括：reviewed question set 的 source recall、top-result relevance、no-result rate、missing-dimension correctness、evidence/source agreement、latency 和 serialized context size。检索质量 claim 必须基于版本化评测集，不能只靠个别示例。

## 非目标

- 为 AI 把完整云端历史同步到本地 SQLite
- 用户记录向量数据库
- 业务数据长期 semantic memory
- GraphRAG
- 任意数据库探索
- 因为缺少 context builder 就发送完整原始历史
- 让 provider-generated targets 替代确定性计算
- 把 retrieved documents 当作可执行指令
- autonomous retrieval/action loop

## 相关文档

- [AgentDesign.md](AgentDesign.md)：Agent 权限、workflow、确认和隐私边界
- [AIOutputContract.md](AIOutputContract.md)：output schema、provider constraints、validation 和 correction
- [Algorithm.md](Algorithm.md)：确定性公式和 workflow 语义
- [Database.md](Database.md)：`document_chunks`、logs、cloud records 和持久化
- [CloudLocalDataBoundary.md](CloudLocalDataBoundary.md)：云端/本地权威与 cache 行为
- [References.md](References.md)：RAG、安全、隐私和 evidence sources
- [../../PHASE5_ENGINEERING_PLAN.md](../../PHASE5_ENGINEERING_PLAN.md)：RAG 实施、部署与验收历史

## 代码引用

- Router：`supabase/functions/ai-chat-route/workflow_router.ts`
- Context builders：`supabase/functions/ai-chat-route/context_builders.ts`
- Document retrieval：`supabase/functions/ai-chat-route/document_rag.ts`
- Prompt assembly：`supabase/functions/ai-chat-route/prompt_builder.ts`
- Gateway evidence：`supabase/functions/ai-chat-route/index.ts`、`supabase/functions/ai-chat-route/phase5_types.ts`
- Document schema/RPC：`supabase/migrations/202607080001_phase5_document_rag_index.sql`
- Service-role grants：`supabase/migrations/202607090001_phase5_structured_rag_service_role_grants.sql`
- Ingestion tool：`tool/phase5_document_rag/build_document_chunks.mjs`
- Generated seed：`supabase/seed_phase5_document_chunks.sql`
- Flutter evidence model/UI：`lib/domain/models/ai_gateway_evidence.dart`、`lib/features/ai/ai_page.dart`
