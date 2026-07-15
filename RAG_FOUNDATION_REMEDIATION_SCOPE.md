# FitLog_Agent RAG 基础工程整改范围清单

> 状态：已确认范围（Confirmed Scope）
>
> 用途：锁定本轮 RAG、Context Planning、动作上下文、Provider-independent AI Capability、Food Draft/Food Vision 可靠性和完整验收必须解决的问题。
>
> 本文件不是当前已实现行为的 source of truth，也不是施工步骤、部署手册或完成状态记录。后续详细工程计划必须逐项映射本文件的 Scope ID，不得静默删除、降级、延期或替换任何已确认项。

## 1. 背景与目标

本轮问题由“保加利亚分腿蹲的每侧/单侧次数如何记录和计算”触发，但根因不是一个动作或一个同义词，而是多个基础层同时存在缺口：稳定文档迁移不完整、Document RAG allowlist 漏文件、chunk 生成不保真、中文检索和同义词处理不足、当前模型意图选择发生在 Context Builder 之后、动作定义和动作级历史没有进入授权 Context、无可靠来源时仍生成 FitLog 专属结论，以及原计划中的检索评测没有完整落地。

后续真实使用又确认了同一 AI 基础层的相邻发布阻断：专用食物分析虽然收到中文 `language`，仍可返回英文或中英混合 Food Draft；用户明确说明“奶昔含 20g 蛋白质”时，模型说明文字承认 20g，但结构化 `protein_g` 可以写成 8.5；当前校验只保证 JSON、数值范围、日期和 item totals 等有限不变量，不能证明草稿忠于用户明确事实；专用图片页面不是对话界面，却沿用了 clarification 语义；图片分析固定 Qwen，且专用端点与 AI Chat 各自维护部分食物 Prompt/Provider 规则。它们不是 Document RAG 检索缺陷，但与本轮正在整改的 Planner、Provider、Output Contract、Draft、评测和发布 Gate 共用基础设施，必须在同一执行计划中闭环，不能另留一套未定义的后续补丁。

本轮目标不是做最小补丁，而是一次性完成以下已确认终态：

- 完整、双语、可追溯、可验证的稳定文档 corpus；
- 中文分词、术语归一化、text embedding、hybrid retrieval 和 reranker；
- 模型可调用但权限受控的检索工具；
- 最多一次额外检索机会的受控 Agentic retry；
- 在 Context Builder 前完成的 Task/Context Planning；
- 内置动作、自定义动作和动作级历史的最小必要 Structured Context；
- 统一 JSON output contract、evidence、权限和确认边界继续成立；
- Surface、Capability Core、Provider Adapter 与 Shared Validation 职责分离，所有 AI 能力遵循 provider-independent 产品语义；
- 专用图片分析与 AI Chat 在进入 Food Draft 能力后共用事实优先级、语言、估算、语义校验和确认边界；
- 图片分析拥有独立于 AI Chat 的 ChatGPT/千问选择，并补齐 OpenAI Vision adapter；
- 覆盖 ingestion、retrieval、routing、context、output、security、failure 和 performance 的完整自动化评测与人工验收。

Phase 5 与 Phase 6 在后续计划中只能表示施工顺序和验收层次，不能用于把本清单中的任何基础工程降级为可选或推迟到未定义的未来阶段。

## 2. 锁定的架构边界

- [ ] `RAG-S00-01` 保留现有 provider-independent 统一 JSON envelope、严格 schema、领域校验、最多一次 output correction 和用户确认边界。
- [ ] `RAG-S00-02` 保留服务端认证、订阅、active-device、记录摘要授权和 write safety 的最终决定权；模型只能申请 Context，不能扩大权限。
- [ ] `RAG-S00-03` Document embedding 只用于稳定产品/设计文档，不为用户 food/workout/body 业务数据建立向量库、用户 embedding 或长期 semantic memory。
- [ ] `RAG-S00-04` Structured RAG 继续通过 typed、bounded、minimum-necessary builders 读取权威数据，不开放任意 SQL、完整原始历史或开放式 autonomous Agent loop。
- [ ] `RAG-S00-05` Agentic retrieval 最多允许一次额外 query rewrite + retrieval；不得无限循环，不得绕过 no-write、privacy 或 corpus scope。
- [ ] `RAG-S00-06` 分阶段实施只能调整顺序，不能缩小本文件锁定的最终范围；每个 Scope ID 都必须在详细计划、测试和验收中有落点。
- [ ] `RAG-S00-07` Provider 选择不得改变 capability、业务字段语义、语言要求、权限、写入边界或失败终态；Provider adapter 只负责 API/transport、provider-native schema/tool 映射、结果提取和 provider error/refusal/incomplete 归一化。

## 3. 稳定文档与术语整改

### `RAG-S01` 全量文档事实审计

- [ ] 对仓库全部 Markdown 建立清单，区分 stable source of truth、当前 wire contract、historical implementation、roadmap/plan、Local baseline 和资产说明。
- [ ] 对比 FitLog Local 基线、Agent V1 初始计划、当前稳定文档和当前 Flutter/SQLite/Supabase/Edge 实现。
- [ ] 核对公式、字段语义、source-of-truth、用户流程、权限、失败行为、non-goal、代码引用和当前实现状态。
- [ ] 修复 `docs/local/` 中影响历史基线可读性的失效链接，或增加明确冻结/路径说明；Local 内容不得被误当 Agent 当前事实。
- [ ] 输出 before/after 内容盘点，说明保留、重写、移动、删除和未决项。

### `RAG-S02` 官方双语术语与内部概念统一

- [ ] 在 owning stable docs 中恢复并解释总重量、每侧重量、自重加重、辅助重量、总次数、每侧次数和单组时长。
- [ ] 保持 App 官方中文、官方英文、内部枚举和计算字段一致。
- [ ] 建立版本化双语领域术语表，至少覆盖：
  - `每侧次数`、`单侧次数`、`单边次数`、`每边次数`、`per-side reps`、`reps per side`、`unilateral reps` -> `per_side_reps`；
  - `总次数`、`整组次数`、`total reps` -> `total_reps`；
  - 每侧/单边重量、总重量/器械标称重量、自重加重、辅助重量及对应内部枚举；
  - 动作中文名、英文名、稳定 key 和经过审核的 aliases。
- [ ] 术语表用于文档写作、query normalization、测试 fixture 和动作实体识别，不能只存在于 prompt 文本中。
- [ ] 同步 `Product.md`、`AppGuide.md`、`Methodology.md`、`Algorithm.md`、`Database.md`、`AgentDesign.md`、`RAGDesign.md` 和必要 API contract；中英文含义与边界一致。

## 4. Document RAG corpus 与 ingestion

### `RAG-S03` Canonical corpus manifest

- [ ] 用户侧 Document RAG corpus 固定为根目录 `README.md` 加 `docs/en/`、`docs/zh/` 中全部稳定设计文档。
- [ ] corpus 必须包含双语 `CloudLocalDataBoundary.md`。
- [ ] `docs/local/*`、CHANGELOG、Roadmap、历史实施书、工程计划、generated SQL、source code 和用户业务记录不得进入用户侧 corpus。
- [ ] 如后续需要内部工程问答，必须使用独立 engineering corpus，并显式标记 `current_contract`、`historical`、`planned` 或 `non_goal`；不得与用户侧 current-product evidence 混排。
- [ ] 用 canonical manifest 代替容易遗漏的散落手写列表，并自动断言 required stable tree、generator source list、seed source paths 和部署 corpus 完全一致。

### `RAG-S04` Lossless Markdown-aware chunking

- [ ] 重写 chunker，保护 Markdown link、URL、inline code、code block、表格、文件路径、扩展名、内部枚举、小数、版本号和引用 ID。
- [ ] 禁止再次生成 `CHANGELOG. md`、`. dart`、`. ts`、`. sql`、`developers. openai. com` 等被改写内容。
- [ ] 保留 doc path、heading、heading path、language、authority/status、section ID、chunk position、content hash、generator version 和 source version。
- [ ] Chunk context prefix 必须确定性、可审查且不能改变原文事实。
- [ ] 增加 chunk round-trip/保真 fixture、禁止模式扫描、重复/遗漏检测和稳定 ID 回归测试。
- [ ] 重新生成 seed 前完成双语、链接、路径、状态和内容审查；之后再更新云端 corpus。

## 5. 检索基础工程

### `RAG-S05` 中文分词与双语 query normalization

- [ ] Ingestion 和 query 两端使用一致、可版本化的中文分词/关键词提取策略。
- [ ] 保留英文 token、内部枚举、动作 key、数字、单位和混合语言表达。
- [ ] 同时生成原始查询、官方术语查询、内部枚举查询、动作标准 key 查询和经过审核的同义词查询。
- [ ] 支持中文、英文、中英混合、长问题、短问题、口语、词序变化和常见同义表达。
- [ ] 规范化不能把相近但不同的概念错误合并，例如 `total_reps` 与 `per_side_reps`。

### `RAG-S06` Stable-document text embedding

- [ ] 为稳定 Document RAG chunks 增加 text embedding、向量索引和受控 search path。
- [ ] 当前发布使用新加坡区 Qwen `text-embedding-v4`、1536 维 dense vector；corpus 与 query 必须使用同一模型、维度、区域和 input contract，并复用服务端管理的 Qwen credential，不增加客户端 key 或第二套 embedding secret。
- [ ] 版本化 embedding model、input format、dimension、normalization、generated-at 和 source content hash。
- [ ] 文档变更、chunker 变更或 embedding model 变更时能够检测 stale vectors 并幂等重建。
- [ ] Query embedding 使用与 corpus 兼容的模型和版本。
- [ ] Embedding provider secret 保持服务端管理；日志不保存不必要的完整用户问题或敏感原始 Context。
- [ ] 不为用户业务记录、用户自定义动作历史或长期对话建立 embedding/vector memory。

### `RAG-S07` Controlled hybrid retrieval

- [ ] 每次 Document RAG 同时执行 exact/phrase、中文分词关键词、full-text/BM25、trigram、术语/枚举扩展和 vector semantic search。
- [ ] 合并、去重并保留各 retriever 的原始分数、命中字段、命中词和 source metadata。
- [ ] 使用明确、可测试的 score normalization/fusion，防止低质量 semantic match 覆盖精确产品术语命中。
- [ ] 按 language、corpus、authority/status 和允许的 source scope 过滤。
- [ ] 设置 candidate 上限、最终 top-k、最低分、最大 context token 和冲突处理规则。

### `RAG-S08` Reranker

- [ ] 对 hybrid candidates 执行受控 rerank。
- [ ] Reranker 输入包含原始问题、规范化术语、heading、context prefix、authority/status 和 chunk content。
- [ ] 保留 rerank 前后分数、最终排序和淘汰原因，便于评测和 debug。
- [ ] 防止 planned、historical、Local-only 或语义相近但规则不同的来源排在 current stable exact evidence 前面。
- [ ] 为 reranker failure 定义可见、可记录且不伪造 evidence 的降级路径。

## 6. 检索工具与受控 Agentic retry

### `RAG-S09` Model-callable retrieval tool

- [ ] 提供模型可调用但 corpus、权限、次数和参数受服务端控制的检索工具。
- [ ] 工具底层使用 `RAG-S05` 至 `RAG-S08` 的完整 hybrid + rerank pipeline，不是单纯关键词搜索。
- [ ] 工具返回 query used、normalized terms、retriever types、total hits、candidate/final scores、matched terms、source paths/headings、authority/status、corpus/model/version、coverage 和 missing dimensions。
- [ ] 工具不得接受任意 SQL、任意表名、任意用户数据范围或客户端伪造的 server-owned context objects。

### `RAG-S10` One bounded Agentic retry

- [ ] 第一次 hybrid retrieval + rerank 后执行可测试的 evidence coverage 检查。
- [ ] 以下情况允许一次受限 query rewrite：无结果、最高分过低、只覆盖问题一部分、缺少动作定义、缺少算法规则、来源冲突或命中状态不可靠。
- [ ] Query rewrite 只能产生有限检索变体、标准术语、内部枚举、翻译或问题拆分，不能申请未授权数据或生成 SQL。
- [ ] 第二次仍不足时必须停止，并返回明确 missing-source/insufficient-evidence 结果；不得无限搜索或用模型常识伪装 FitLog 事实。
- [ ] 记录 privacy-safe retry reason、query variant category、候选变化、最终 coverage、额外延迟和成本，不记录 chain-of-thought。

## 7. 前置 Task/Context Planning

### `RAG-S11` 在 Context Builder 前完成任务规划

- [ ] 保留现有统一 JSON output contract，但将真正影响 Context 的 task planning 移到 Context Builder 之前。
- [ ] 明确区分 `workflow/context planning` 与 `output-family selection`，不再都使用含糊的 “intent routing” 名称。
- [ ] 前置 planner 输出 workflow、expected/allowed output family、entities、requested context、retrieval needs、clarification needs 和 confidence/source。
- [ ] 明确请求优先由高置信度确定性规则处理；规则主动放弃时，受限模型 planner 处理文字、当前图片和紧凑同会话 Context。
- [ ] 模型 planner 只能申请 Context；服务器必须结合 auth、permission、workflow policy 和 data minimization 重新验证并裁剪。
- [ ] 解决以下当前缺口：
  - 只有图片和食物补充、未出现“记录”时仍能在 Context 前区分 Food Draft、Meal Decision 或普通分析；
  - Workout Draft 在 Context 前识别动作实体和动作定义需求；
  - App 规则问题与动作实体组合时同时请求 document 和 exercise definition；
  - 模糊 Meal Decision 在需要时读取授权 selected-day summary；
  - 同会话 clarification 继承正确 workflow、output family 和 Context needs。
- [ ] 最终 provider call 使用已经批准的 Context，继续返回统一 JSON，并通过 schema/domain/evidence/write validation。

## 8. 动作 Structured Context 与确定性绑定

### `RAG-S12` Exercise definition context

- [ ] 新增 typed、bounded `exercise_definition_context`，用于动作属性问答、Workout Draft 和动作规则解释。
- [ ] 内置动作从 `exercise_catalog.dart` 的 canonical definition 生成版本化服务端结构化快照，避免手工把整套动作复制进 Markdown。
- [ ] Context 至少包含稳定 key、官方中英文名/aliases、exercise type、body part、strength structure/profile、load input mode、reps input mode、set metric type 和必要 cardio defaults。
- [ ] 自定义动作继续遵守 V1 非全量云同步边界：客户端只发送本次命中的、严格 schema 校验的最小 `exercise_reference`，不上传整个动作库或任意 Context。
- [ ] API contract 必须定义 `exercise_reference` 的字段、长度、enum、来源、权限、冲突和拒绝规则。
- [ ] 同名、未知或歧义动作必须请求用户确认，不能静默假定。

### `RAG-S13` Exercise history context

- [ ] 新增 permissioned、scoped `exercise_history_context`，用于回答某动作最近组数、重量、次数、训练量和趋势。
- [ ] 使用云端正式 workout source of truth 或受控 summary builder，按稳定 exercise key/name、账号、时间范围和行数上限查询。
- [ ] 不上传完整 workout history、完整 set rows 或无关动作。
- [ ] 记录摘要权限关闭、定义无法绑定或历史不足时返回 named missing dimension。

### `RAG-S14` Workout Draft deterministic binding

- [ ] Workout Draft schema/handoff 必须保留稳定 exercise reference，并与已批准的 definition context 一致。
- [ ] Flutter review/handoff 按 key 重新绑定内置或本地自定义动作，而不是只依赖有限名称 aliases。
- [ ] load/reps/set metric 从真实动作定义取得；未知动作不得静默退化为 `total_load + total_reps`。
- [ ] 中文动作名、英文动作名、稳定 key、自定义 key 和历史 snapshot 都有明确解析/兼容测试。
- [ ] Draft 仍只进入现有 workout editor；用户保存前不写正式 workout record。

## 9. Evidence、回答与合同一致性

### `RAG-S15` Evidence-grounded answer guard

- [ ] FitLog 专属规则必须由 Document RAG source、Structured Context 或确定性规则支持。
- [ ] Evidence 为空或 coverage 不足时不得使用“FitLog 的规则是/系统会”之类确定陈述。
- [ ] 一般知识可以回答，但必须明确标注未核实 FitLog 产品规则，且不得伪造 source。
- [ ] 最终校验 `claims <= evidence`，并核对 source、excerpt、context object、missing dimensions 和用户可见 Answer Basis 一致。
- [ ] planned、historical、Local-only、non-goal 或错误语言来源不得被呈现为当前 implemented behavior。

### `RAG-S16` API、权限、隐私与日志合同

- [ ] `API_CONTRACT_DRAFT.md` 补充实际使用的 `allow_record_summary_context`、默认值、隐私意义和服务端行为。
- [ ] 新增并锁定 `exercise_reference`、task plan、retrieval request/result 和 evidence metadata 的边界。
- [ ] 客户端继续禁止提交任意 `context_objects`、RAG result、SQL、tool calls、official write、provider API key 或 server-owned decisions。
- [ ] 明确哪些 Context 需要记录摘要授权，以及关闭权限后的 named missing dimensions。
- [ ] 日志只保存 privacy-safe workflow、context types、query category/normalized terms（按隐私规则）、retriever/rerank score metadata、retry reason、latency、token/cost 和 issue codes；不保存原图、base64、完整原始历史、raw failed provider output 或 chain-of-thought。

## 10. Failure、降级与性能边界

### `RAG-S17` Retrieval and context failure matrix

- [ ] 覆盖 lexical search、query segmentation、embedding generation/query、vector index、reranker、Agentic retry、Document RAG、Structured builder、provider、logging 和 evidence assembly failure。
- [ ] 每种 failure 定义稳定分类、可用降级、用户可见限制、debug metadata 和是否允许继续最终 provider call。
- [ ] 降级不得把 missing data 当 0、不得伪造 source、不得把无来源模型常识包装成 FitLog 事实。
- [ ] Optional cache/log failure 不阻塞 live answer；权威 Context failure 必须形成 named missing dimension 或稳定失败。
- [ ] 设置正常路径和单次 retry 路径的 latency、token、candidate、top-k、context-size、model-call 和成本预算。

## 11. 全面评测与验收范围

### `RAG-S18` Corpus and ingestion evaluation

- [ ] Required stable source coverage、language pairing、authority/status、chunk count、stable ID、hash、embedding freshness 和 cloud/local corpus parity。
- [ ] Markdown/URL/code/path/number 保真、无重复遗漏、无 replacement character、无 stale path。

### `RAG-S19` Document retrieval evaluation

- [ ] 覆盖 Product/AppGuide、Methodology/Algorithm、Database/CloudLocalDataBoundary、AgentDesign、AIOutputContract、RAGDesign 和 References 的全部主要主题。
- [ ] 覆盖饮食模式、阶段、策略、BMR/TDEE、宏量、训练热量、输入模式、存储、缓存、导出、隐私、Agent 权限、JSON output、RAG 边界和 evidence。
- [ ] 每个主题覆盖官方词、自然改写、同义词、短/长问题、中文、英文、中英混合、口语和无答案问题。
- [ ] 记录 lexical/vector/fused/reranked top-k、expected source hit、no-result、false-positive 和跨语言错误。

### `RAG-S20` Structured Context and routing evaluation

- [ ] Meal Decision、Weekly Review、Profile、selected day、7/14 天 summary、权限关闭、数据稀疏和 builder failure。
- [ ] 明确/隐式 Food Draft、图片识别/记录/Meal Decision 歧义、Workout Draft、App Logic、动作组合问题、普通聊天、同会话 clarification 和 safety requests。
- [ ] Task planner 请求 Context、服务端裁剪和最终实际 Context 一致；模型选择不能扩大权限。
- [ ] 内置动作、自定义动作、aliases、同名歧义、definition/history context、load/reps/set mode 和 draft binding。

### `RAG-S21` Output, faithfulness, safety and privacy evaluation

- [ ] `text`、`food_draft`、`workout_draft`、`clarification`、malformed JSON、schema mismatch、一次 correction、日期、artifact 和 no-write confirmation。
- [ ] Source/evidence agreement、insufficient-evidence detection、planned/Local/historical 不误报、一般知识与 FitLog 事实边界。
- [ ] Prompt injection、完整历史请求、客户端伪造 Context/tool/API key、删除/改目标/应用策略、未成年人和医疗边界。
- [ ] OpenAI/Qwen、文字/图片路径、transport/provider/output-invalid 分类和日志 redaction。

### `RAG-S22` Agentic retry, failure and performance evaluation

- [ ] 首次命中无需 retry、低召回触发一次 retry、第二次成功、第二次仍失败、来源冲突和 coverage 仅部分满足。
- [ ] 验证最大额外检索次数为 1，正式写入为 0，权限范围不扩大，无法检索时正确停止。
- [ ] 覆盖 embedding/reranker/tool/provider failure 和受控降级。
- [ ] 衡量 source recall、precision、top-k hit、rerank gain、no-result rate、retry rate、retry gain、faithfulness、latency、token、context size 和成本。

## 12. Provider-independent AI Capability 与 Food Draft/Food Vision 可靠性

### `AI-S01` Surface、Capability Core、Provider Adapter 与 Shared Validation 分层

- [ ] 所有 AI 路径统一采用四层职责：Surface Orchestration 决定入口、目标语言来源、固定/自动任务、Context 和 UI 终态；Capability Core 定义 `text_answer`、`food_draft`、`workout_draft`、`task_plan`、`retrieval_query` 等产品语义；Provider Adapter 只做 OpenAI/Qwen 协议映射；Shared Validation 执行结构、领域、语言、事实忠实度、安全和确认边界。
- [ ] 不建立“一段所有页面照抄的万能 Prompt”。Surface 生成 provider-independent normalized capability request，Capability Core 生成统一 policy/contract，Provider Adapter 只按 provider 能力编码 system/input/schema/tool/image。
- [ ] OpenAI/Qwen 可以使用不同 API、Structured Outputs/JSON Mode、图片格式和 tool-call 机制，但不得各自维护食物事实优先级、营养字段含义、动作规则、权限、写入或用户终态。
- [ ] 共享规则必须存在于版本化代码/合同和测试中，不能只复制到多个 Prompt 字符串；Provider 新增或模型升级必须通过同一 capability parity Gate。
- [ ] 在 `AGENTS.md` 项目规则和稳定 `AgentDesign`/`AIOutputContract` 中写明 Provider adapter 的边界，防止后续功能再次漂移。

### `AI-S02` Food understanding、事实来源与通用优先级

- [ ] Food Draft 生成前建立 typed、bounded、provider-independent `food_understanding` 中间结构，区分用户明确事实、包装/OCR 明确信息、图片观察、模型假设、模型估算、缺失字段和未解决冲突。
- [ ] 优先级固定为：用户明确事实 > 包装/OCR 明确信息 > 图片观察 > 通用模型估算。低优先级信息只能填补缺失字段，不能覆盖高优先级事实。
- [ ] 用户自由文本仍由模型做通用语义理解，不为每个可能句式写业务正则；确定性层只验证统一结构、来源、单位、约束绑定和冲突，不维护无法穷举的自然语言表达清单。
- [ ] 每个用户明确的重量、份量、营养值、食用比例或排除/修正说明都必须被中间结构保留，或被显式标记为 unresolved；不能在生成草稿时静默丢失。
- [ ] 模型只能估算用户没有明确提供的字段；所有估算和假设必须在可编辑草稿说明中以目标语言简洁呈现。

### `AI-S03` Shared Food Capability 与跨入口一致性

- [ ] 专用 `ai-food-photo-analyze` 固定进入 Food Capability，不参加 AI Chat 的 task/output intent selection；AI Chat 只有在 approved plan/output family 为 Food Draft 后才进入同一 Food Capability。
- [ ] 两个入口共享 food-understanding contract、事实优先级、字段语义、语言 policy、估算边界、Food Draft schema、semantic validator、一次有界 correction 和 Preview 前 Gate。
- [ ] 两个入口保留各自 Surface 行为：AI Chat 可以有 same-chat Context/clarification；专用页面只接受本次文字、零至三张图片、选中日期和独立 Provider 选择，不调用 Document RAG，不形成对话循环。
- [ ] 同一 provider-independent Food Capability 不要求两个入口 Prompt 逐字相同；Surface-specific instruction 只能补充入口/UX/Context 差异，不能覆盖共享业务规则。
- [ ] 任何 structurally valid 但与用户明确事实、语言或共享 Food policy 冲突的结果都不得进入 Food Preview。

### `AI-S04` 输出语言与 Food semantic validation

- [ ] `response_language` 由 Surface 明确提供：AI Chat 按其语言策略决定，专用页面按当前 App language 决定；Provider 不自行从英文 JSON 示例或历史 Context 改写目标语言。
- [ ] 对 Food Draft 的 `meal_name`、普通 `item.name`、`estimation_notes`、输入修正提示和其他用户可见文字执行目标语言 Gate；品牌名、商标、型号和没有可靠翻译的专有名词可以保留原文，但不能导致普通说明整体漂移到错误语言。
- [ ] Semantic validator 至少检查：用户事实与绑定字段一致、food-understanding 与 draft 一致、notes 与数字不矛盾、item/meal totals 一致、日期一致、数值有限非负、营养/热量不存在超出容差且无解释的明显矛盾、估算/明确值来源没有倒置。
- [ ] 热量与宏量营养素检查使用版本化容差和 reason code，考虑纤维、糖醇、酒精、四舍五入和标签差异；不得用机械 `4P+4C+9F` 强行改写合法标签事实。
- [ ] Semantic issue 可以进入现有最多一次 output correction；correction 必须携带原始 normalized facts 和 issue codes，不能重新开放未授权 Context。第二次仍失败时返回稳定失败或输入修正状态，不放行草稿。

### `AI-S05` 专用图片分析页面终态与独立 Provider 选择

- [ ] 专用页面不是 Chat。它只有两类终态：通过校验的可编辑 Food Draft；或保留现有图片/文字并要求用户在原表单修正后重新分析。不得显示成连续对话式追问，也不得创建隐藏 conversation state。
- [ ] 当前 `needs_clarification`/`clarification_questions` 如为兼容保留，专用页面必须把它映射为 `input_revision_required` 式的内联/页面反馈；AI Chat 可以继续按自己的 clarification contract 展示。
- [ ] 图片分析页面新增独立 ChatGPT/千问选择；使用独立本机 preference key，不读取、覆盖或同步 AI Chat 的模型选择。
- [ ] 独立选择只改变 Provider，不改变 Food Capability、请求图片/文字、语言、事实优先级、schema、semantic validator、Preview 或正式写入确认边界；它不在同一 Provider 内拆分文字模型与图片模型配置。
- [ ] Provider 未配置/不可用、模型不支持图片、超时、拒绝和 output-invalid 必须显示真实稳定错误并保留输入，不能静默把请求切换到另一 provider 或假装成功；当前发布未合法配置 OpenAI 时，AI Chat 和专用图片页切换到 ChatGPT 都触发生命周期式“当前模型不可用”提示，选择器以共享滑动动画自动恢复 Qwen 选中态，但不发送 provider request。该 UI 恢复不得被实现为隐藏 Qwen transport。

### `AI-S06` 统一多模态生成模型、跨 Provider parity、observability 与评测

- [ ] OpenAI 和 Qwen 各自只配置一个统一多模态生成模型 ID；AI Chat 文字、AI Chat 图片和专用 Food 图片分析均使用所选 Provider 的同一个模型。已配置并发布的模型必须通过 adapter tests 与 live canary 证明支持当前图片输入和结构化输出；未配置 OpenAI 时保留 adapter/contract tests，并证明两处 UI 的真实 unavailable、自动滑回 Qwen、no-request 和 no-hidden-provider-fallback 行为，不把 OpenAI live canary 作为当前 Qwen 核心发布阻断。不得用第二个 Vision 模型配置代替 capability 验证，也不能把未经验证的 text-only adapter 直接视为已支持图片。
- [ ] Document RAG Embedding 属于独立任务，使用独立于生成模型的 Qwen `text-embedding-v4` 与 embedding endpoint，但复用服务端 `FITLOG_QWEN_API_KEY`；不得把 embedding 与 Qwen 多模态生成模型合并，也不得要求用户提供模型 key。
- [ ] Qwen/OpenAI adapters 使用同一 normalized capability request、Food policy、内部合同、validator 和 error taxonomy；Provider-specific 差异只存在于请求编码、schema/tool/image 格式、completion 提取和 provider 状态映射。
- [ ] 日志记录 surface、capability、provider/model、policy/contract/validator version、目标语言、事实/冲突数量、structural/semantic validation status、correction count、latency/token/cost 和最终终态；不得记录原图/base64、完整用户自由文本、raw invalid output 或 chain-of-thought。
- [ ] 评测必须覆盖中文、英文、中英混合、品牌/专有名词、纯文字、单/多图、多食物、包装标签、用户明确重量/比例/营养值、notes/数字矛盾、错误语言、输入修正、provider refusal/incomplete/timeout 和双 provider parity。
- [ ] 将本轮实际失败转为脱敏回归样本：中文描述却返回英文/混合字段；说明承认“20g 蛋白质”但 `protein_g` 为 8.5；专用页面不能进行 Chat 式追问；图片页模型选择与 AI Chat preference 相互独立。
- [ ] Parity 不要求两种模型返回完全相同的估算数字，但要求相同输入事实不被覆盖、相同语言/权限/失败/确认边界成立，且任何 invalid draft escape 为 0。

## 13. 必需交付物

- [ ] `RAG-D01` 本文件所有 Scope ID 与后续详细工程计划步骤/验收项的双向追踪矩阵。
- [ ] `RAG-D02` 更新后的稳定双语文档、术语表、API contract 和 RAG/Agent/output contracts。
- [ ] `RAG-D03` Canonical corpus manifest、lossless chunker、seed、embedding pipeline 和 cloud index/migrations。
- [ ] `RAG-D04` 中文分词、query normalization、hybrid retrieval、reranker、检索工具和单次 Agentic retry。
- [ ] `RAG-D05` 前置 Task/Context Planner、server policy validation、exercise definition/history builders 和 deterministic draft binding。
- [ ] `RAG-D06` Evidence/claim guard、failure matrix、privacy-safe observability 和 stable error/downgrade behavior。
- [ ] `RAG-D07` Deterministic unit/integration tests、versioned eval fixtures、retrieval reports、provider canaries 和人工验收记录。
- [ ] `RAG-D08` 部署、数据回填、corpus/embedding refresh、canary、rollback 和旧版本兼容说明。
- [ ] `RAG-D09` Roadmap/CHANGELOG/stable docs 的完成状态同步，以及旧/新工程计划的归档和追溯链接。
- [ ] `AI-D01` Provider-independent capability contract/layers、共享 Food understanding/policy/validator、OpenAI/Qwen adapters 和跨入口接线。
- [ ] `AI-D02` 图片分析独立 Provider 选择、非对话式输入修正终态、Food semantic/provider parity eval、canary、文档和回归证据。

## 14. 计划与文档关系

- 本文件锁定“必须解决什么”和“最终必须达到什么结果”。
- [`RAG_FOUNDATION_REMEDIATION_ENGINEERING_PLAN.md`](RAG_FOUNDATION_REMEDIATION_ENGINEERING_PLAN.md) 负责“按什么顺序、修改哪些文件、如何迁移、测试、部署、回滚和验收”。
- 已归档的 `docs/history/phase5/PHASE5_ENGINEERING_PLAN.md` 记录原始受控 lexical RAG 的施工背景和验收设计，不能覆盖本文件新增或纠正的范围。
- `docs/ROADMAP.md` 只维护阶段状态、顺序、风险、完成摘要和到范围/详细计划/历史计划的链接，不复制两份计划的完整内容。
- 在新详细计划完成审查前，不删除、重写或把已归档的 `docs/history/phase5/PHASE5_ENGINEERING_PLAN.md` 标为新的执行依据。
- 实施全部完成后，Roadmap 才能把本轮 RAG closure/hardening 标记为完成；未完成的 Scope ID 必须保持显式状态，不能由总体“Phase 5 已完成”覆盖。
- 稳定设计文档必须按 `AGENTS.md` 的 Formal Document Charters 和 Value-Preserving Refinement Workflow 维护：把 durable fact 写回 owning section，保持 present-tense、双语含义和链接一致；不得在 `Product.md`、`AppGuide.md`、`AgentDesign.md`、`AIOutputContract.md`、`RAGDesign.md` 等稳定文档尾部追加“某日更新”“本轮新增”或时间戳式施工块。
- 历史事故和已发布修复进入 `CHANGELOG.md`，执行顺序/Gate/canary/rollback 留在工程计划，当前 API wire shape 进入 `API_CONTRACT_DRAFT.md`；不得为了省事把同一规则复制成多份相互漂移的 source of truth。

## 15. 完成定义

本轮只有在以下条件全部成立时才算完成：

- 所有 `RAG-S00` 至 `RAG-S22` 和 `AI-S01` 至 `AI-S06` 已实现并通过对应自动化与人工验收；
- 所有 `RAG-D01` 至 `RAG-D09` 和 `AI-D01` 至 `AI-D02` 已交付；
- 当前稳定文档、实际代码、部署 corpus、embedding index、retrieval behavior、evidence UI 和公开 API contract 一致；
- 中文、英文、混合语言、同义词、动作定义、自定义动作、动作历史和复杂组合问题达到工程计划锁定的阈值；
- 正常 hybrid 路径和单次 Agentic retry 路径均满足延迟、费用、隐私和停止条件；
- 无可靠来源时不再生成伪装成 FitLog 官方规则的确定回答；
- 用户确认前 food/workout/profile 正式写入保持为 0；
- AI Chat 与专用图片分析进入 Food Capability 后共享事实优先级、语言和 semantic validation，错误语言或用户事实冲突的 Draft 进入 Preview 数量为 0；
- 图片分析 ChatGPT/千问选择独立于 AI Chat preference，两个 provider 的 capability/权限/失败/确认边界 parity 通过；
- Roadmap、CHANGELOG、stable docs 和计划归档状态准确反映最终实现。
