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
| Document RAG | 使用可追溯产品/设计文档回答 FitLog App 规则问题。 | 版本化稳定 README 和双语设计文档，持久化为 active-build `document_chunks`。 | 版本化 query normalization、受控 lexical/vector branches、显式 fusion/rerank、coverage 和最多一次有界 retry。 |

Gateway 还会发送紧凑同会话上下文，包括近期文字 turn 和 artifact summary。同会话上下文用于对话连续性，不是 RAG evidence：它不会显示在“回答依据”面板中，也不能证明产品规则。

Stable-document embedding 只用于公开产品/帮助/设计 corpus。用户记录 embedding、semantic long-term memory、GraphRAG、模型生成 SQL、开放式检索循环和文档到云端的自动同步仍不在设计范围内。完整边界见[非目标](#非目标)。

Document RAG 的 corpus vector 与 query vector 都使用新加坡 Model Studio workspace 中的 Qwen `text-embedding-v4`，dense dimension 固定为 1536。Embedding model 独立于 Qwen 多模态生成模型，但两者复用服务端管理的 `FITLOG_QWEN_API_KEY`；embedding endpoint 从 `FITLOG_QWEN_BASE_URL` 推导，`FITLOG_DOCUMENT_EMBEDDING_MODEL` 标识检索模型。OpenAI 不是当前发布的 embedding 或 RAG 依赖。

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
- `docs/en/Product.md`、`AppGuide.md`、`Methodology.md`、`Algorithm.md`、`Database.md`、`CloudLocalDataBoundary.md`、`AgentDesign.md`、`AIOutputContract.md`、`RAGDesign.md` 和 `References.md`
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

RAG 是 evidence/Context layer，不是 Chat controller。任何 retrieval 或 Context Builder 运行前，active `chat_decision.v2` 先选择唯一 capability、output family、requested Context、clarification 状态和附件策略；服务端再派生兼容 Task Plan 并执行 Context Policy。旧 router/expected-output 规则只在 v2 明确复用的确定性 helper 或历史行为等价 oracle 中保留，不再存在可单独激活的 legacy 生产决策。

服务端 router 选择有界 workflow 和 required dimensions：

| Workflow | 检索行为 |
| --- | --- |
| `food_logging` | 使用本次 request 的文字/图片和 draft 规则；不做宽泛记录历史 RAG。 |
| `meal_decision` | 用户启用记录摘要权限时，使用已保存 Profile 和选中日期上下文。 |
| `weekly_review` | 用户启用权限时，使用有界近期 summaries 和可用趋势/coverage dimensions。 |
| `app_logic_answer` | 检索同语言稳定文档并返回 source-aware evidence。 |
| read-only safety boundary | Router 可以确定性阻止不支持写入/隐私请求时，不调用 provider。 |

Client workflow hint 只是 hint，不是权威。第一层路由会在任何模型 planner 之前应用确定性 safety 和 intent 规则，其 Workout 意图优先级为：明确同时要求记录训练和提问时返回 clarification；明确 Workout 记录请求进入草稿 workflow；直接询问 FitLog 行为或计算规则时进入 `app_logic_answer`；隐式 Workout 记录必须同时具有结构化动作/组数证据且不能是疑问句。既有确定性 Food 选择保持不变。只有仍无法确定的 request 才进入有界模型 planner。同会话 Workout 延续只有在上下文中真实存在 `workout_draft` artifact，且新消息含编辑或继续操作时才能确定性命中；仅仅在上一条消息中提到训练不够。随后由 Context Policy 在任何 context builder 或 query embedding 运行前裁剪 Task Plan。服务端 route 和 safety flags 决定实际 workflow 与 allowed actions。

Workflow routing 与 output selection 是不同决策。Routing 决定要构建哪些授权 context、是否检索文档以及允许哪些动作；它不把所有未识别请求默认为 `text`。明确产品入口固定自己的 output family。普通 AI Chat 的高置信度 resolver 可以直接指定 text 或 draft；resolver 主动放弃时，模型结合当前请求、图片和已授权 context 选择受限 `output_type`。模型选择结果不会扩大 RAG 权限或写权限。

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

1. 用版本化 canonical manifest 校验 `README.md` 和中英文目录内的全部稳定 Markdown；缺少双语配对或出现未授权 source 时生成立即失败。
2. 只在 fenced code 之外解析 headings，并保留完整 `heading_path` 和精确 Markdown 原文。
3. 长 section 只在 Markdown block 或安全句子边界拆分。链接、URL、code、表格、路径、扩展名、enum、数字、版本、日期和 reference ID 必须逐字节保真；必要时让单一受保护 token 形成超长 chunk，也不能破坏内容。
4. 保留有意义的短 section，使 non-goal、source-of-truth 和 mode 语义仍可检索。
5. 确定性生成 `section_id`、`chunk_index`、`chunk_count`、tags、status 和 `context_prefix`，不依赖时间、绝对路径或随机数。
6. 在可审查 corpus-build artifact 中保存 source、chunk、manifest、generator 和术语版本。
7. 由该 artifact 生成 `supabase/seed_phase5_document_chunks.sql`。
8. 完整 staging corpus build，校验 source/chunk 数量后原子切换 active build；查询不会混用未完成的新 build 与上一 active build。

确定性 context prefix 包含 source path、heading path、tags、status 和 chunk position。它提供最小 heading context，不改写或重复 source。可选 `context_note` 保留给经过审查的离线 notes；不能根据用户记录生成，也不能在 request time 生成。

## 文档状态

Document chunk 携带 evidence metadata status：

- `implemented`
- `planned`
- `non_goal`
- `local_baseline`
- `evidence`

Provider 不得把 `planned` 或 `non_goal` 内容说成已上线行为。Ingestion tool 只根据带状态语义的 heading 或章节开头显式 label 推断这些状态；正文偶然提到 future work、不支持动作或 non-goal，不能让整节被重新分类。推断仍只是工程辅助，不能代替清晰源文档。

## 检索

Document retrieval：

- ingestion 与 query 使用同一版本化 NFKC/lowercase 中英数字分词规则；chunk 持久化有界 `search_tokens`，同时完整保留受保护 enum、path、unit 和 exercise key；
- chunking、lexical tokenization 与 embedding 保持为三个独立阶段：heading-aware lossless chunking 定义可检索单元，分词结果进入 exact/term/full-text branches，embedding 则针对同一 chunk content 与确定性 context prefix 增加 semantic vector candidates；
- 把中文、英文和混合 query 规范化为受保护 terms、canonical concepts/internal enums、reviewed aliases、exercise keys 和有界 variants，且不合并近邻概念；
- 只查询 active stable-document corpus build，并强制 language、authority 和 status filter；
- 持久化 generated `search_tsv` 并建立 GIN index；其他 branches 继续使用既有 token、trigram 与 HNSW indexes；
- 并发启动有界 indexed lexical-candidate 收集与 Qwen query embedding；embedding failure 会显式记录，lexical candidates 仍可使用；
- 把 lexical candidate IDs 与可选兼容 1536 维 vector 交给 `search_document_chunks_hybrid_v3`，由 PostgreSQL 计算原有全局 scores/ranks、融合最多 30 个最终 candidates，并返回 branch scores、ranks、matched fields 和 matched terms；
- Edge 对有界 candidates 去重后应用版本化 feature reranker，优先 exact official concept、stable key、current authority、请求语言、source diversity，以及产品承诺、权限、持久化、公式、证据和检索问题等经过审查的 owning-document cues；
- 根据 Task Plan required dimensions 把 coverage 分类为 complete、partial、insufficient 或 conflicting；
- Coverage 不完整时允许严格 parse、服务端重新 normalize 的 `search_fitlog_docs` 单次 retry，因此 search 最多两次。

Chat orchestration rollout 不替换或弱化上述 retrieval branches。Exact keyword/term normalization、lexical/vector candidate generation、hybrid fusion、feature reranker、coverage classification 与单次 agentic retrieval retry 在 `rag_foundation_v1` 下继续 active；decision implementation 只能决定已授权 workflow 是否请求 Document RAG。

中文问题先排列中文 docs，再使用跨语言 fallback；英文问题同理先排列英文 docs。混合 query 可以检索两种语言，跨语言结果为次级且不改变回答语言。Owning-document prior 只用于细化原本合理的 candidates，不能绕过 corpus authority/status filter。Embedding failure 携带 issue 并降级到 lexical branches；reranker failure 使用 fused order。任何降级都不能伪造 source 或把不完整 coverage 包装成 FitLog claim。

首次 retrieval coverage complete 或 conflicting 时不调用 retry model。未知 exact technical identifier，以及 normalize 后没有变化的 rewrite，也会在第二次 search 前停止。只有真正缺少 evidence 且 rewrite 发生实质变化时才允许一次服务端 normalize 后的 retry；第二次仍不足则以 limitation/general-knowledge boundary 停止。Retrieval retry 与 output correction 使用独立 counter，不能扩大 Context 或权限。

## Prompt Assembly

Prompt assembly 保持以下层次分离：

1. system safety、output contract 和固定/可选择的 output family
2. workflow、language 和权限 instruction
3. typed Structured RAG objects
4. Document RAG source objects
5. same-chat continuity
6. current user request

Retrieved text 是不可信 evidence。文档内部的指令不得覆盖 system/output rules、授予 tools、索取 secrets 或授权写入。Source path、heading path、status 和 excerpt boundary 应对 prompt builder 可见。Provider prompt 紧凑序列化受控 context，省略重复的 Document RAG summary，只保留 grounding 与 evidence 所需的 source metadata。

## Evidence

Gateway 返回紧凑 evidence：

- routed workflow
- 使用的 context object types
- document sources
- missing dimensions
- safety flags
- read-only、artifact returned 或 blocked 等 final action

App 将其显示为“回答依据”面板，使用人类可读标签展示参考文档、使用数据、缺少信息和受限操作。同会话上下文不作为权威 evidence 显示。

Evidence 保留 grounding 使用的精确 source path、raw Markdown heading、identifier、status、excerpt 和 hashes。Flutter 只派生 presentation label，并仅移除技术标识符外成对的 inline-code delimiter；它不修改 raw evidence/corpus。因此 Database 表标题以及其他设计文件中的相同语法都能保持精确检索，同时 UI 不显示多余反引号。

Evidence 只包含 source metadata 和有界 excerpt，不包含完整文档、数据库行、图片、secret 或内部 reasoning。Debug summary 保存紧凑 dimensions，不保存 raw context payload。

## 失败与降级

- 缺少 optional context 时，如果 workflow 能明确说明限制，可以继续安全回答。
- 缺少 required context 时必须说明，provider 不得推断。
- App-logic question 没有匹配文档时，应说明未找到匹配 FitLog 文档，而不是编造规则。
- Structured context source failure 记录为 missing dimension。
- Safety-blocked workflow 返回确定性边界响应。
- Context 缺失不得把已经固定的 draft request 静默降级成普通 prose；需要时返回 contract-valid clarification 或稳定失败。
- 模型在 `auto` 中选择 output type 时，只能使用当前请求、图片和已授权 context，不能把缺失 evidence 编造成选择依据。
- RAG failure 永远不能扩大数据访问或写权限。

## 文档更新生命周期

稳定文档修改不会自动更新云端 rows。

Indexed stable document 变化后：

1. 事实变化时同时更新中英文 source documents；
2. 运行 `node tool/phase5_document_rag/build_document_chunks.mjs`；
3. 检查 manifest/source pairing、chunk count、hashes、status/authority、protected-token scans 和 generated corpus-build artifact；
4. 使用 `FITLOG_QWEN_API_KEY`、`FITLOG_QWEN_BASE_URL` 和 `FITLOG_DOCUMENT_EMBEDDING_MODEL` 构建 missing/stale Qwen `text-embedding-v4` vectors，把 generated seed 应用到 staging，按 matching chunk/input hashes 同步 vectors，并仅在 source/chunk/vector parity 后 activate；
5. 验证 cloud parity，并运行版本化 retrieval/evidence eval suites 和 provider canaries。

Docs-only corpus refresh 不需要 Flutter rebuild 或 Edge Function redeploy。只有 routing、context builders、retrieval、prompt assembly、response/evidence schema 或 safety code 变化时才重新部署 Edge Function。Activation/rollback 使用 corpus build ID，不做 destructive table reset。

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

有用指标包括：reviewed question set 的 source recall、top-result relevance、no-result rate、missing-dimension correctness、evidence/source agreement、latency 和 serialized context size。检索质量 claim 必须基于版本化评测集，不能只靠个别示例。发布 Gate 要求 recall@3 >= 0.97、reviewed precision@3 >= 0.85、critical top-1 >= 0.95、正常 Edge retrieval p95 <= 1,500 ms、单次 retry increment <= 3,500 ms。生产计时分别覆盖 query normalization、并发 lexical-candidate/query-embedding、最终 hybrid RPC、本地 rerank、可选 rewrite planner 和第二次 retrieval；Gateway 另行测量 planning、Context 构建、Provider 生成/校验/纠错和持久化。未申请 Document RAG 的路径把 embedding 记录为 `not_requested`，因此无需保存用户原文或向量即可直接审计实际 routing。

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

## 代码引用

- Router：`supabase/functions/ai-chat-route/workflow_router.ts`
- Context builders：`supabase/functions/ai-chat-route/context_builders.ts`
- Document retrieval：`supabase/functions/ai-chat-route/document_rag.ts`
- Prompt assembly：`supabase/functions/ai-chat-route/prompt_builder.ts`
- Gateway evidence：`supabase/functions/ai-chat-route/index.ts`、`supabase/functions/ai-chat-route/phase5_types.ts`
- Document schema/RPC：`supabase/migrations/202607080001_phase5_document_rag_index.sql`
- Foundation corpus 与 hybrid RPC：`supabase/migrations/202607130001_rag_foundation_document_hybrid.sql`
- Indexed candidate retrieval：`supabase/migrations/202607150003_rag_hybrid_indexed_candidates.sql`、`supabase/migrations/202607150004_rag_parallel_candidate_fusion.sql`
- Service-role grants：`supabase/migrations/202607090001_phase5_structured_rag_service_role_grants.sql`
- Ingestion tool：`tool/phase5_document_rag/build_document_chunks.mjs`
- Generated seed：`supabase/seed_phase5_document_chunks.sql`
- Reliability evaluation：`tool/evals/run_rag_foundation_cloud_eval.mjs`、`docs/reports/RAG_RELIABILITY_OPTIMIZATION_REPORT.md`；自动生成的原始证据继续保存在 `test/evals/reports/`
- Flutter evidence model/UI：`lib/domain/models/ai_gateway_evidence.dart`、`lib/features/ai/ai_page.dart`
