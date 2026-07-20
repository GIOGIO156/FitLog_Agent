# FitLog_Agent Phase 5 AI/RAG Final Engineering Record

> 状态：`CONSOLIDATED AS-BUILT / SOURCE PLANS RETIRED / VALID-DEVICE GATE OPEN`
>
> 审计基线：2026-07-20，Git `dc6d9e86bcf62cf9509a3c7919107729c16856c3`。
>
> 本文件是历史工程综合记录，不是当前产品设计、wire contract、活动施工计划或 Document RAG source。当前事实以双语稳定设计文档和代码为准；阶段状态和剩余操作 Gate 以 `docs/ROADMAP.md` 为准。

## 1. 最终产品目标

FitLog_Agent 需要的不是一个能够偶尔搜到文档的问答接口，而是一条受约束、可追溯、可恢复的 AI Chat 产品链：它理解自然中英文和当前图片，选择唯一 capability 与 output family，只构建被授权的最小 Context，使用 Structured RAG 或 Document RAG 提供 evidence，在确实缺少信息时通过有状态 clarification 推进原任务，生成严格校验且可编辑的 Food/Workout Draft，并始终把正式写入留给用户确认。

这个终态同时要求重大替换不能静默丢弃旧能力。Keyword/term normalization、vector retrieval、hybrid fusion、reranker、coverage/retry、Food/Workout validators、记录权威、草稿持久化和恢复机制都必须有行为等价与回归证据。

## 2. 为什么形成多份计划

| 阶段 | 当时解决的问题 | 后来确认的局限 | 最终去向 |
| --- | --- | --- | --- |
| 原始 Phase 5 | 增加只读 Structured RAG、lexical Document RAG、evidence 和基础 workflow routing。 | Corpus allowlist/chunk 保真、中文检索、embedding/hybrid/rerank、动作 Context 和系统性评测不足。 | 保留为原始历史；由 Foundation remediation 补齐。 |
| AI Output Contract | 统一 provider envelope、strict schema、draft validation、correction、error taxonomy 和观测。 | Output contract 只能约束“模型可以返回什么”，不能单独决定当前任务、Context 和多轮状态。 | 当前 Qwen 发布合同已落地；OpenAI live 启用前 Gate 保留。 |
| RAG Foundation remediation | 补齐稳定 corpus、术语、embedding、hybrid/rerank、retrieval tool/retry、Context Planning、动作绑定、grounding 和全面评测。 | Production Chat 仍存在分散决策、无状态 clarification、当前图片提前退出和过宽 write guard；部分评测没有执行真实 auto journey。 | Foundation 保持启用；Chat 缺口由后续计划整改。 |
| Chat orchestration remediation | 建立唯一 `chat_decision.v2`、typed/persisted clarification、附件 lease、准确 failure taxonomy、行为等价、真实 production-path eval、soak 和 legacy retirement。 | 代码/云端/自动化已落地；文档整理时有效测试设备和最新 corpus parity 尚待外部验收，后者已于 2026-07-20 关闭。 | Source plan 退场；剩余有效真机 Gate 转交 Roadmap Phase 7。 |

这些文件不是三个互相竞争的 RAG 设计。它们分别约束 retrieval/context、model output 和 Chat orchestration，共同构成最终 AI Chat。

## 3. 最终架构与 owning documents

| 层 | 当前责任 | 稳定 owner |
| --- | --- | --- |
| Surface | AI Chat、Add Food、Food Preview、Workout editor 的入口、显示、用户确认和失败恢复。 | [Product](../../zh/Product.md)、[AppGuide](../../zh/AppGuide.md) |
| Chat decision | 一次决定 capability、output family、requested Context、clarification 和 attachment policy；旧 legacy branch 不可激活。 | [AgentDesign](../../zh/AgentDesign.md) |
| Context/RAG | Same-chat、Structured RAG、Document RAG、server Context Policy、evidence 和 failure downgrade。 | [RAGDesign](../../zh/RAGDesign.md) |
| Retrieval | Exact/term、中文 token、FTS、trigram、Qwen vector、PostgreSQL fusion、Edge reranker、coverage 与最多一次受控 retry。 | [RAGDesign](../../zh/RAGDesign.md) |
| Output governance | Provider-independent output families、strict schema、semantic validation、grounding、一次 correction 与 failure taxonomy。 | [AIOutputContract](../../zh/AIOutputContract.md) |
| Persistent state | Chat/history、clarification state/RPC、logs、document builds/vectors、cloud records 与本地草稿。 | [Database](../../zh/Database.md) |
| Cloud/local authority | Cloud official records、本地 partial cache、runtime attachment lease、clear/logout/account-switch 生命周期。 | [CloudLocalDataBoundary](../../zh/CloudLocalDataBoundary.md) |
| Wire boundary | Request/response、typed clarification reply、attachments、artifacts、errors 和 additive compatibility。 | [API contract](../../API_CONTRACT_DRAFT.md) |

Stable docs 只描述当前行为；本文件只保留为何演进到该行为以及验收发生在什么时点。

## 4. 不得降级的能力保留矩阵

| 能力 | 当前结论 | 主要生产落点 | 主要证据 |
| --- | --- | --- | --- |
| 双语 canonical corpus | 21 个 README/中英文稳定来源由 allowlist 管理；history/plans/reports 排除。 | `tool/phase5_document_rag/*` | manifest、lossless chunk、source parity tests |
| 中文与官方术语 | 中英混合 normalization、stable terms、exact official identifiers 和 do-not-merge 约束保留。 | `assets/rag/*`、`rag/query_normalizer.ts` | term/normalizer/retrieval fixtures |
| Vector/hybrid/rerank | Qwen `text-embedding-v4` 1536 维、indexed lexical/vector candidates、PostgreSQL global fusion、Edge feature reranker active。 | hybrid migrations、`rag/retrieval_pipeline.ts`、`retrieval_reranker.ts` | retrieval reports、cloud canaries |
| Coverage/retry | Coverage 明确 complete/partial/conflicting；最多一次 query rewrite/retrieval，no-gain/unchanged/unknown identifier 停止。 | `retrieval_coverage.ts`、`retrieval_retry.ts` | retry bounds/gain/failure tests |
| Structured RAG | Profile、day/recent summaries、strategy、exercise definition/history 使用 typed、bounded、authorized Context。 | `context_builders.ts`、`context_policy.ts`、RPCs | permission/cross-account/no-raw-history tests |
| Task/Context planning | 决策发生在 Context Builder 前；服务端 policy 不能被 Flutter 扩权。 | `chat_decision.ts`、planning modules | deterministic/model planner、policy tests |
| Evidence/grounding | FitLog 专属结论必须映射 evidence；UI presentation 不改 raw identifiers/hash。 | `grounding/*`、Flutter evidence models | claim/evidence/write-guard tests |
| Output contract | Text、Food Draft、Workout Draft、clarification 使用 provider-neutral strict contract 和共享 validator。 | `_shared/ai_output_contract.ts`、provider adapters | Edge contract/validator/provider fixtures |
| Clarification | Cloud `ai_chat_clarifications` 是控制 source of truth；typed reply 幂等消费，no-progress/expiry/conflict 有终止状态。 | clarification contracts、RPC migrations、Flutter controller | create/claim/resolve/replay/RLS/journey tests |
| Current images | 清晰请求同轮使用当前图片；跨轮只允许 account/session runtime lease，重启/清理/换号后要求重附。 | Flutter attachment lease、Chat request contracts | same-turn/rebind/resend/lifecycle tests |
| Draft/write boundary | AI 只生成 artifact；Food Preview/Workout editor 与现有权威草稿继续负责编辑和用户确认。 | existing draft repositories/editors | no-write、handoff、save/discard tests |
| 记录与恢复基础 | Cloud official records、本地 partial cache、`workout_record_drafts`、ordered mutation、30 分钟 resume hint 和 best-effort notification 未被 Chat 状态替代。 | existing repositories/recovery owners | behavior parity manifest、Flutter recovery tests |

完整 Scope ID 的收口关系见第 10 节；本表是最终能力索引，不复制已经完成的逐步施工 checklist。

## 5. 关键整改结论

1. RAG 是 evidence/Context layer，不是 Chat controller。检索质量不能证明 intent、output 或多轮状态正确。
2. Output Contract 负责“允许返回什么”；Chat decision 负责“本轮应该调用什么以及如何继续”。二者不能互相替代。
3. 确定性规则适合权限、fixed entry、schema、安全、日期和数值边界；开放食物、训练和自然语言问题不能依赖不断扩充的关键词硬编码。
4. Clarification 必须是有 ID、状态、选项、attempt、expiry 和幂等消费的协议，不能只是 assistant 文案。
5. 当前图片不进入长期存储。需要跨轮时只能由当前 runtime 显式重绑；不可恢复时要求重附。
6. Write guard 必须识别执行主体、完成动作和用户业务对象；数据库“保存在哪里”的被动说明不是 AI 已替用户写入。
7. 评测必须执行真实 production decision path，并断言任务终态；HTTP 200、非空文本或任意 clarification 都不能算成功。

## 6. 被拒绝或退场的方案

- 原始一次性 lexical-only retrieval：召回与中文/同义表达能力不足。
- 用少量食物词和 `g/ml` 规则承担开放语义：清晰图片请求可能在模型调用前被误判。
- Workflow router、task planner、expected output 和 prompt 分别决定意图：生产入口替换时会静默丢行为。
- Free-text clarification 文案：用户选择上一轮选项时会重新猜 intent 并重复同一句。
- 过宽关键词 write guard：会误杀数据库存储说明。
- 简化 parallel fusion 与 24-candidate 配置：评测显示 recall/precision/top-1 下降，因此拒绝质量换速度。
- 可运行的 legacy decision branch：回滚演练证明它会重新暴露 8 个 v2 行为失败，随后从生产代码和 secrets 中删除。

## 7. 验收快照

### Foundation 收口快照

- `rag_foundation_v1` 与 Document RAG retry 保持启用。
- Foundation active build `99d908c576c844fd3c39d853`：21 sources、577/577 vectors、cloud mismatch 0。
- Release retrieval 28/28；recall@3 100%、reviewed precision@3 97.44%、critical top-1 100%、正常 Edge retrieval p95 1.250 秒。
- Foundation 时点 Edge 为 Chat v44、Food photo v21；完整细节见 [RAG reliability report](../../reports/RAG_RELIABILITY_OPTIMIZATION_REPORT.md)。

### Chat orchestration 收口快照

- `chat_decision.v2`、`ai_chat_clarification.v2`、`write_claim_guard.v2` 和三项 clarification migrations 已部署。
- Chat orchestration 收口时为 Chat Edge v64、Food photo v33；2026-07-20 重新部署当前源码后为 ACTIVE v65/v34。Legacy decision branch 与两个 runtime secrets 已删除。
- Post-retirement real-Qwen `auto` cloud gate 33/33；两条用户故障链、typed create/consume/replay、Food image completion、13/13 source recall、37/39 precision、5/5 critical top-1 通过。
- Corpus build `bbdd397f3d144e4ccea082e8` 已以 21 sources / 613 embedded chunks 激活并回读 0 mismatch；activation recheck 33/33，Edge retrieval p50/p95 926/1244 ms。
- 当时自动化证据为 `flutter analyze` 无问题、Flutter 259/259、required Edge 63/63、full Edge 278 passed、Node docs/corpus/migration 21/21。
- 这些数字是对应 landing 时点证据，不替代当前分支重新运行的验证。

## 8. 当前 Release Gates 与准确边界

1. **有效真机 journey**：尚未在用户明确确认的 Android 测试设备上执行两条原始故障链和 picker Activity/App restart journey。`cm01_se` 是主机水冷控制器，不是授权测试手机；此前因其暴露 Android ADB 而被错误分类。只发生了只读查询、临时 APK 推送和未成功的 PackageInstaller 尝试；session 已撤销、临时文件已删除、应用未安装，也没有重启、清除用户数据或修改系统设置。这次操作不能作为设备验收证据。
2. **Corpus Gate 已关闭**：build `bbdd397f3d144e4ccea082e8` 已获得明确外发授权，613/613 local/cloud metadata parity、0 missing/stale/extra/mismatch，并已原子激活。首次 canary 唯一失败为 Edge retrieval p95 1519 ms，相对固定 1500 ms Gate 超出 19 ms；同配置 recheck 为 1244 ms 并以 33/33 关闭 Gate，阈值没有降低。
3. **OpenAI 未来启用 Gate**：当前发布只配置 Qwen。OpenAI adapter/contract tests 保留；若未来合法配置并启用 OpenAI，必须先完成对应 text/image live canary、监控和 adapter rollback，不得把 adapter 存在等同于已发布可用。
4. **事前 checkpoint 偏差**：Chat replacement 前未形成计划要求的独立 Git checkpoint，无法事后补造。该事实保留为流程偏差和后续变更规则，不是一个可以无限阻塞当前发布的伪 Gate。

## 9. 文档与状态归属

- Stable current behavior：`README.md`、`docs/en/*.md`、`docs/zh/*.md`。
- Public wire shape：`docs/API_CONTRACT_DRAFT.md`。
- Current phase/open Gates：`docs/ROADMAP.md`。
- Shipped history：`CHANGELOG.md`。
- Phase 5 evolution and evidence：本文件。
- Raw/versioned eval evidence：`test/evals/reports/`；专业汇总在 `docs/reports/`。

本文件不进入 Document RAG corpus。Stable-doc corpus 只允许 README 与十对双语 owning documents；工程历史可以解释开发过程，但不能成为模型回答当前产品行为的依据。

## 10. 确认范围与最终收口

以下矩阵承接已经删除的 Scope/Plan 中仍需长期防回归的范围。这里记录最终能力和证据归属，不恢复已完成的任务勾选表。

| 原 Scope | 锁定要求 | 最终收口与证据 |
| --- | --- | --- |
| `RAG-S00-01` 至 `RAG-S00-07` | 保留统一 output contract、服务端权限、稳定文档专用 embedding、typed Structured RAG、最多一次 retrieval retry、完整范围和 provider-independent 语义。 | 第 3-5 节能力矩阵；当前合同由双语 Agent/RAG/Output 文档和 API contract 维护。 |
| `RAG-S01` 至 `RAG-S04` | 全量文档审计、双语术语、canonical manifest、lossless Markdown chunking。 | 21-source allowlist、generator v4、受保护 token/路径/链接测试和双语 owning docs 已落地；history/plans/reports 明确排除。 |
| `RAG-S05` 至 `RAG-S10` | 中文/双语 query normalization、Qwen embedding、controlled hybrid retrieval、reranker、模型检索工具和一次有界 retry。 | `assets/rag/*`、`rag/query_normalizer.ts`、`retrieval_pipeline.ts`、`retrieval_reranker.ts`、`retrieval_tool.ts`、`retrieval_retry.ts`；第 7、12 节记录质量与失败实验。 |
| `RAG-S11` 至 `RAG-S14` | Context Builder 前规划、动作定义/历史 Context、Workout Draft 稳定绑定。 | `chat_decision.v2`、server context policy、57 项 catalog snapshot、account-scoped history RPC、`workout_draft.v3` 与 Flutter hash revalidation。 |
| `RAG-S15` 至 `RAG-S17` | Evidence-grounded claims、API/权限/隐私合同、完整 failure/downgrade matrix。 | Grounding/write guards、server-owned Context rejection、privacy-safe observability、named missing dimensions 和细分稳定错误已落地。 |
| `RAG-S18` 至 `RAG-S22` | Corpus、retrieval、routing、faithfulness、安全、retry/failure/performance 全面评测。 | Versioned fixtures/runners、`test/evals/reports/`、第 7 和第 12 节验收快照；评测执行真实 pipeline，不以 HTTP 200 或任意 clarification 代替成功。 |
| `AI-S01` 至 `AI-S06` | Surface/Capability/Adapter/Validation 分层，共享 Food policy/validator，语言与事实一致性，图片页独立 provider 选择和跨 provider parity。 | AI Chat 与 Add Food 共用 provider-neutral Food contract；当前 Qwen text/image canary 已完成，未配置 OpenAI 的 UI unavailable/no-request/no-hidden-fallback 行为已验证。 |
| `RAG-D01` 至 `RAG-D09`、`AI-D01` 至 `AI-D02` | 实现、文档、corpus/vector、检索、Context、guard、测试、部署/回滚和归档交付。 | 代码、migrations、稳定文档、报告、corpus activation 和部署记录均已落地；第 8 节只剩有效真机 Gate。 |

## 11. 实现、迁移与部署谱系

### 11.1 Additive migrations

| 层 | 已应用 migrations | 责任 |
| --- | --- | --- |
| 原始 Phase 5 | `202607080001_phase5_document_rag_index.sql`、`202607090001_phase5_structured_rag_service_role_grants.sql`、`202607090002_phase5_document_rag_query_terms.sql` | Document index、Structured RAG service-role boundary、query terms。 |
| Output contract | `202607100001_ai_output_contract_observability.sql`、`202607110001_ai_intent_output_observability.sql`、`202607110002_ai_observability_update_grants.sql` | Output/intent observability 与 grants。 |
| RAG foundation | `202607130001_rag_foundation_document_hybrid.sql`、`202607130002_rag_foundation_exercise_history.sql`、`202607130003_rag_foundation_observability.sql`、`202607150001_rag_latency_breakdown.sql`、`202607150002_ai_chat_turn_rag_workflows.sql`、`202607150003_rag_hybrid_indexed_candidates.sql`、`202607150004_rag_parallel_candidate_fusion.sql` | pgvector/build metadata、exercise history、RAG logs、latency、workflow、indexed candidates 与 production v3 fusion。 |
| Chat orchestration | `202607190001_ai_chat_clarification_state.sql`、`202607190002_ai_chat_orchestration_observability.sql`、`202607190003_ai_chat_clarification_digest_search_path.sql` | Typed clarification state/RPC/RLS、decision observability 与安全 search path。 |

这些都是 additive migrations。回滚 runtime 或 Edge 不得删除正式数据表、历史消息、vectors 或 clarification rows；SQLite schema 未因本轮文档整理而变化。

### 11.2 生产落点

- Edge 主入口由 `supabase/functions/ai-chat-route/` 负责 decision、Context、RAG、provider、validation 和 clarification；专用图片入口由 `ai-food-photo-analyze/` 复用共享 Food contract。
- `_shared/ai_output_contract.ts` 及 provider adapters 负责 provider-neutral envelope、strict/domain validation、一次 bounded correction 和错误归一化。
- `tool/phase5_document_rag/` 负责 canonical corpus、lossless chunks、embedding freshness/parity 和 seed；`tool/evals/` 与 `test/evals/` 保存可重复评测。
- Flutter controller/repositories 负责历史恢复、typed reply、runtime attachment lease、Preview/editor handoff；既有 Food/Workout draft、mutation queue 和 official-record owner 没有被 Chat 状态替换。
- Foundation 收口时生产版本为 Chat v44/Food photo v21；Chat orchestration 收口为 v64/v33；2026-07-20 当前源码重新部署后为 ACTIVE v65/v34。版本号是发布证据，不是当前代码 source of truth。

## 12. 失败实验、回滚与不可伪造的限制

| 实验/事件 | 结果 | 最终决策 |
| --- | --- | --- |
| Lexical-only 与手写 corpus list | 中文、同义表达、跨文档 Context 和漏文件问题无法稳定解决。 | Canonical manifest + bilingual normalization + embedding/hybrid/rerank。 |
| 简化 parallel fusion | Recall/precision/critical top-1 降至 84.62%/84.21%/80%；24 candidates 虽过最低线，precision 仍只有 89.74%。 | 拒绝以质量换速度；保留 PostgreSQL v3 全局 rank/fusion 和 30 final candidates。 |
| 旧 no-gain retry | 约 3.839 秒额外耗时且没有 coverage gain。 | 只有 coverage gain 才允许一次 retry；unknown identifier、unchanged rewrite 和 complete/conflicting coverage 停止。当前 useful-retry live p95 没有真实分母，不能伪报。 |
| Legacy Chat rollback rehearsal | RAG/data 仍可用且 recall 13/13、precision 39/39、top-1 5/5，但总计 25 pass / 8 fail；失败集中在 permission/RAG boundary、image auto 和 typed clarification。 | 恢复 v2 后通过 33/33；删除 legacy branch 与两个 runtime secrets。紧急回退只能重部署保留的 Edge v63/基线源，不能用不存在的 flag。 |
| Chat 替换前 checkpoint | 计划要求的独立事前 Git checkpoint 没有发生，无法事后伪造。 | 以 `d7b4f22`、parity manifest、Edge v63 和 rollback report 审计；以后重大替换必须先冻结基线、行为矩阵和 rollback point。 |

Corpus 回滚只切换上一 active build；Edge 回滚不得回滚 additive schema；评测资产和失败样本不能随 runtime 回滚删除。任何降级都必须继续满足 no-write、privacy、bounded Context 和不伪造 evidence。

## 13. 验证证据与复核入口

### 13.1 收口时自动化与云端证据

| 时点 | 证据 |
| --- | --- |
| Foundation | Required/full Edge 61/61、130/130；Flutter 223/223；Node 20/20；cloud release 28/28；21-source/577-vector build 完整 parity。 |
| Chat orchestration | `flutter analyze` 无问题；Flutter 259/259；required Edge 63/63；full Edge 278 passed、0 failed、2 external ignored；Node docs/corpus/migration 21/21；post-retirement Qwen gate 33/33。 |
| Soak | 2026-07-19 受控窗口包含 7 个最终 hard turns；0 final failure、0 duplicate signature、0 write-guard false positive。 |
| 2026-07-20 激活 | Build `bbdd397f3d144e4ccea082e8`，21 sources / 613 chunks；613/613 local/cloud parity、0 mismatch；Edge v65/v34 ACTIVE；required/full Edge 63/63、278/278；activation recheck 33/33、Edge retrieval p50/p95 926/1244 ms。 |

维护者复核应运行仓库当前要求的 `flutter analyze`、`flutter test`、Edge Deno check/test、Node corpus/docs/embedding tests，并按变更风险运行 eval/canary。历史数字只证明对应 landing 时点，不替代当前分支验证。

原始机器可读证据继续保存在 `test/evals/reports/`；RAG 延迟、质量、候选数 A/B、失败方案与最终结果由 [RAG reliability optimization report](../../reports/RAG_RELIABILITY_OPTIMIZATION_REPORT.md) 汇总。当前产品行为、API 和数据边界仍由第 3 节链接的 owning documents 维护。

## 14. 原计划退场与 Git 恢复

完成本综合记录后，以下六份 source plans/audit 从工作树删除：原始 Phase 5 plan、Output Contract plan、RAG remediation Scope、RAG Foundation plan、RAG document audit 和 Chat orchestration plan。删除原因不是它们“毫无价值”，而是其 durable scope、实现谱系、失败实验、部署/回滚证据和未关闭 Gate 已分别进入本文件、稳定 owning docs、Roadmap、CHANGELOG 与原始 eval reports；继续保留六份完整 checklist 只会制造状态冲突和错误施工入口。

需要法证级追溯时，可从审计基线 Git `dc6d9e86bcf62cf9509a3c7919107729c16856c3` 恢复当时的原始文件。四份计划位于该提交根目录，原始 Phase 5 plan 与 document audit 位于 `docs/history/phase5/`。恢复仅用于审计，不得重新把旧计划当作当前架构或施工入口。
