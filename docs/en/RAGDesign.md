# RAG Design

## Purpose

This document is the stable source of truth for retrieval and context construction in FitLog_Agent. It defines what information may enter the model, where that information comes from, how Structured RAG and Document RAG differ, how document chunks are generated and retrieved, and how evidence, privacy, and failure downgrade work.

Model-output schemas, validation, correction, and provider protocol constraints belong to [AIOutputContract.md](AIOutputContract.md). Persisted tables and fields belong to [Database.md](Database.md). Deterministic nutrition/workout calculations belong to [Algorithm.md](Algorithm.md).

The durable boundary is:

```text
RAG may provide bounded, typed, source-aware context.
It must not give the model unrestricted database access, full raw history,
or authority to replace deterministic calculations and official sources of truth.
```

## Retrieval Systems

FitLog uses two scoped retrieval systems with different data shapes and authority:

| System | Purpose | Authoritative source | Retrieval model |
| --- | --- | --- | --- |
| Structured RAG | Give meal-decision and review workflows minimum necessary user/account context. | Cloud Profile, cloud official records, `daily_summaries`, and server-side summary builders. | Known typed context builders selected by the server workflow route. |
| Document RAG | Answer FitLog app-logic questions with traceable product/design documentation. | Versioned stable README and bilingual design documents stored as active-build `document_chunks`. | Versioned query normalization plus controlled lexical/vector branches, explicit fusion/reranking, coverage, and at most one bounded retry. |

The Gateway also sends compact same-chat context containing recent text turns and artifact summaries. Same-chat context is conversation continuity, not RAG evidence: it is not shown in the Answer basis panel and it does not prove a product rule.

Stable-document embeddings are limited to the public product/help/design corpus. User-record embeddings, semantic long-term memory, GraphRAG, model-generated SQL, open-ended retrieval loops, and automatic document-to-cloud synchronization remain outside this design. The complete boundary is listed under [Non-goals](#non-goals).

Document RAG uses Qwen `text-embedding-v4` in the Singapore Model Studio workspace for both corpus and query vectors. Dense vectors are fixed at 1536 dimensions. The embedding model is independent from the Qwen multimodal generation model, but both reuse the server-managed `FITLOG_QWEN_API_KEY`; the embedding endpoint is derived from `FITLOG_QWEN_BASE_URL`, and `FITLOG_DOCUMENT_EMBEDDING_MODEL` identifies the retrieval model. OpenAI is not an embedding or RAG dependency for the current release.

## Architecture

```text
Authenticated request
  -> subscription and active-device checks
  -> deterministic workflow router
  -> required context dimensions
  -> permission and source-of-truth checks
  -> typed context builders and/or document search
  -> sanitization and bounded context bundle
  -> provider prompt
  -> output validation
  -> evidence response and compact debug summary
```

Authentication, subscription, and active-device checks happen before user-record context is built. Flutter must not upload server-owned `context_objects`, `rag_context`, tool calls, official-write payloads, or provider secrets.

## Context Categories

### Same-Chat Context

Same-chat context may include:

- bounded recent user and assistant text turns
- lightweight Food Draft / Workout Draft artifact titles and summaries

It must not include:

- historical image pixels or base64
- raw provider responses
- hidden reasoning
- unrestricted old chat history
- a previous artifact presented as an official record unless the official source confirms it

Same-chat context helps resolve pronouns and follow-up questions. It is not a substitute for current cloud data or document evidence.

### Structured RAG

Structured RAG calls known server-side context builders. It does not have a dedicated vector table and does not expose database query syntax to the model.

Current context object families:

| Object | Authoritative source | Purpose |
| --- | --- | --- |
| `profile_context` | Cloud Profile | Saved phase, mode, strategy, body and preference fields needed by the workflow. |
| `selected_day_summary` | Cloud `daily_summaries` or deterministic summary builder | Selected-day targets, intake, exercise and mode-specific remaining values. |
| `recent_food_summary` | Cloud official food records through a bounded summary builder | Window totals and coverage without full record rows. |
| `recent_workout_summary` | Cloud official workout records through a bounded summary builder | Frequency, duration, estimated kcal and body-part pattern. |
| `body_metric_summary` | Cloud `body_metric_logs` through a bounded summary builder | Available body metric coverage in the requested range. |
| `weight_trend_summary` | Cloud body metrics | Trend only when enough valid observations exist. |
| `strategy_context` | Saved Profile strategy plus deterministic calculators | Relevant carb-cycling or carb-tapering state without applying a change. |

Context builders return compact aggregates and metadata, not raw row arrays. Each object has a known type and size boundary and is sanitized before prompt assembly.

### Document RAG

Document RAG retrieves bilingual FitLog product/help/design text. Current indexed sources are:

- root `README.md`
- `docs/en/Product.md`, `AppGuide.md`, `Methodology.md`, `Algorithm.md`, `Database.md`, `CloudLocalDataBoundary.md`, `AgentDesign.md`, `AIOutputContract.md`, `RAGDesign.md`, and `References.md`
- matching files under `docs/zh/`

Engineering plans, changelog history, API drafts, generated SQL, source code, user exports, and user business records are not part of the stable Document RAG corpus.

## Source Of Truth

RAG does not change product authority:

| Information | Source of truth |
| --- | --- |
| Account, subscription, and active-device state | Cloud services |
| Saved Profile and diet configuration | Cloud Profile after sign-in |
| Signed-in body, food, and workout records | Cloud official records |
| Daily summary inputs | Cloud records and deterministic summary service |
| Diet and workout formulas | Dart deterministic algorithms and stable Algorithm documentation |
| Product/Agent behavior | Stable bilingual design documents matching current code |
| Local SQLite | Partial cache, draft storage, and runtime acceleration only |

If local cache conflicts with the cloud source, AI context must use the cloud source or report the dimension as unavailable. RAG must not use model output to reconstruct missing authoritative records.

## Workflow Routing

The server router selects a bounded workflow and its required dimensions:

| Workflow | Retrieval behavior |
| --- | --- |
| `food_logging` | Uses request-scoped text/images and draft rules; no broad record-history RAG. |
| `meal_decision` | Uses saved Profile and selected-day context when record-summary permission is enabled. |
| `weekly_review` | Uses bounded recent summaries and available trend/coverage dimensions when permission is enabled. |
| `app_logic_answer` | Searches same-language stable documents and returns source-aware evidence. |
| read-only safety boundary | Does not call the provider for unsupported write/privacy requests when the router can block deterministically. |

Client workflow hints are hints, not authority. The server first applies deterministic routing and safety rules; it calls the bounded model planner only when those rules cannot resolve the workflow. The resulting Task Plan is then clamped by Context Policy before any context builder or query embedding runs. The server route and safety flags decide the actual workflow and allowed actions.

Workflow routing and output selection are separate decisions. Routing chooses which authorized context to build, whether documents are retrieved, and which actions are allowed; it does not turn every unrecognized request into `text`. Explicit product entries fix their output family. In ordinary AI Chat, a high-confidence resolver may select text or a draft directly; after resolver abstention, the model uses the current request, images, and authorized context to select a bounded `output_type`. Model selection never expands RAG or write authority.

## Permission And Data Minimization

User-record summaries require the user-visible record-summary permission. When permission is off:

- the Gateway omits protected record-summary dimensions;
- the request may still receive safe Profile-independent or document-based context;
- missing protected dimensions are reported instead of guessed;
- the model is not told that omitted data is zero.

Default exclusions:

- complete raw food history
- complete raw workout history
- complete raw body-metric history
- free-form record notes
- local export files
- local workout editor drafts
- original images and base64 payloads after the request
- auth tokens and provider secrets

The minimum-necessary rule applies to both context selection and prompt size. A workflow receives only dimensions used by that workflow.

## Deterministic Context Semantics

RAG may transport deterministic results but may not recompute or reinterpret them freely.

- `diet_goal_phase` remains the source of cutting/bulking semantics.
- In `energy_ratio`, kcal target/intake/remaining is primary.
- In `gram_per_kg`, macro grams are primary and kcal is auxiliary.
- `carb_cycling` and `carb_tapering` are saved strategy states, not actions the model may apply.
- Workout calorie values come from FitLog calculators, not provider estimates in review context.
- Missing dimensions remain missing; the provider must not fabricate them.

Detailed formulas and workflow decision rules remain in [Algorithm.md](Algorithm.md).

## Context Object Sanitization

Every context object must pass deterministic sanitization before prompt assembly. Reject or omit:

- raw row arrays
- image/base64 content
- authentication material
- provider keys
- SQL text or arbitrary query instructions
- unbounded free text
- nested objects outside the known schema
- non-finite numbers
- oversized serialized payloads

Context-builder failure should degrade to a named missing dimension when safe. It must not block live UI with optional cache writes, fabricate substitute values, or expose internal exceptions to the model.

## Document Ingestion

The implemented ingestion pipeline:

1. Validates the versioned canonical manifest against `README.md` and every stable Markdown file in both language trees; a missing bilingual pair or an unauthorized source fails generation.
2. Parses headings outside fenced code and preserves the complete `heading_path` and exact Markdown source text.
3. Splits long sections at Markdown block or safe sentence boundaries. Links, URLs, code, tables, paths, extensions, enums, numbers, versions, dates, and reference IDs remain byte-for-byte intact; a protected token may form an oversized chunk rather than being corrupted.
4. Keeps meaningful short sections so non-goals, source-of-truth rules, and mode semantics remain retrievable.
5. Generates deterministic `section_id`, `chunk_index`, `chunk_count`, tags, status, and `context_prefix` without depending on time, absolute paths, or randomness.
6. Stores source, chunk, manifest, generator, and terminology versions in a reviewable corpus-build artifact.
7. Generates `supabase/seed_phase5_document_chunks.sql` from that artifact.
8. Stages a complete corpus build, validates source/chunk counts, and atomically switches the active build. Queries never combine a partial new build with the previous active build.

The deterministic context prefix includes source path, heading path, tags, status, and chunk position. It supplies minimal heading context without rewriting or duplicating the source. Optional `context_note` remains reserved for reviewed offline notes; it must not be generated from user records or at request time.

## Document Status

Document chunks carry a status used as evidence metadata:

- `implemented`
- `planned`
- `non_goal`
- `local_baseline`
- `evidence`

The provider must not present `planned` or `non_goal` content as shipped behavior. The ingestion tool infers these states only from a status-bearing heading or an explicit leading label; an incidental mention of future work, an unsupported action, or a non-goal must not reclassify the whole section. Inference remains an engineering aid, not a substitute for clear source writing.

## Retrieval

Document retrieval:

- applies the same versioned NFKC/lowercase Chinese-English-number tokenization at ingestion and query time; chunks persist bounded `search_tokens`, while protected enums, paths, units, and exercise keys remain intact;
- keeps chunking, lexical tokenization, and embeddings as separate stages: heading-aware lossless chunking defines retrievable units, tokenization feeds exact/term/full-text branches, and embeddings add semantic vector candidates over the same chunk content plus deterministic context prefix;
- normalizes Chinese, English, and mixed queries into protected terms, canonical concepts/internal enums, reviewed aliases, exercise keys, and bounded variants without merging nearby concepts;
- queries only the active stable-document corpus build and filters language, authority, and status;
- stores a generated `search_tsv` column with a GIN index, while the existing token, trigram, and HNSW indexes support the other branches;
- starts bounded indexed lexical-candidate collection and Qwen query embedding concurrently; embedding failure is explicit and lexical candidates remain usable;
- sends the lexical candidate IDs and optional compatible 1536-dimension vector to `search_document_chunks_hybrid_v3`, which computes the original global scores and ranks inside PostgreSQL, fuses at most 30 final candidates, and returns branch scores, ranks, matched fields, and matched terms;
- deduplicates those bounded candidates in Edge, then applies a versioned feature reranker that prioritizes exact official concepts, stable keys, current authority, requested language, source diversity, and reviewed owning-document cues such as product promise, permission, persistence, formula, evidence, and retrieval questions;
- classifies coverage as complete, partial, insufficient, or conflicting against the Task Plan's required dimensions;
- allows `search_fitlog_docs` one strictly parsed server-normalized retry when coverage is not complete, for a hard maximum of two searches.

Chinese questions place Chinese docs before cross-language fallback, and English questions do the same for English docs. Mixed queries may search both; cross-language results are secondary and do not change response language. Owning-document priors refine otherwise plausible candidates but never bypass corpus authority/status filters. Embedding failure degrades to lexical branches with an issue code. Reranker failure uses the fused order. Neither downgrade fabricates sources or turns incomplete coverage into a FitLog claim.

Coverage-complete or conflicting first retrieval does not call a retry model. An unknown exact technical identifier and a normalized rewrite that is unchanged also stop without a second search. Only a genuine missing-evidence case with a materially changed, server-normalized rewrite may retry once; a second insufficient result stops with a limitation/general-knowledge boundary. Retrieval retry and output correction use separate counters and never expand context or permission.

## Prompt Assembly

Prompt assembly keeps these layers distinct:

1. system safety, output contract, and fixed or selectable output family
2. workflow, language, and permission instructions
3. typed Structured RAG objects
4. Document RAG source objects
5. same-chat continuity
6. current user request

Retrieved text is untrusted evidence. Instructions contained inside retrieved documents must not override system/output rules, grant tools, request secrets, or authorize writes. Source path, heading path, status, and excerpt boundaries remain visible to the prompt builder. The provider prompt serializes controlled context compactly, omits a duplicate Document RAG summary, and keeps only the source metadata required for grounding and evidence.

## Evidence

The Gateway returns compact evidence describing:

- routed workflow
- context object types used
- document sources
- missing dimensions
- safety flags
- final action such as read-only, artifact returned, or blocked

The App presents this as an Answer basis panel. It uses human-readable labels for referenced documents, used data, missing information, and limited actions. Same-chat context is not displayed as authoritative evidence.

Evidence contains source metadata and bounded excerpts, not complete documents, database rows, images, secrets, or internal reasoning. Debug summaries store compact dimensions, not raw context payloads.

## Failure And Downgrade

- Missing optional context does not prevent a safe response if the workflow can answer with an explicit limitation.
- Missing required context must be stated; the provider must not infer it.
- Document retrieval returning no matching source for an app-logic question must produce a no-matching-document limitation rather than an invented FitLog rule.
- Structured context source failure is recorded as a missing dimension.
- A safety-blocked workflow returns a deterministic boundary response.
- Missing context cannot silently downgrade a fixed draft request into ordinary prose; the result must be a contract-valid clarification or a stable failure when necessary.
- When the model selects an output type under `auto`, it may use only the current request, images, and authorized context and cannot invent missing evidence as a selection basis.
- RAG failure never grants broader data access or write permission.

## Document Update Lifecycle

Stable document edits do not automatically update cloud rows.

When an indexed stable document changes:

1. update the English and Chinese source documents together when facts change;
2. run `node tool/phase5_document_rag/build_document_chunks.mjs`;
3. inspect manifest/source pairing, chunk count, hashes, status/authority, protected-token scans, and the generated corpus-build artifact;
4. build missing/stale Qwen `text-embedding-v4` vectors with `FITLOG_QWEN_API_KEY`, `FITLOG_QWEN_BASE_URL`, and `FITLOG_DOCUMENT_EMBEDDING_MODEL`, apply the generated seed to staging, synchronize vectors by matching chunk/input hashes, and activate only after source/chunk/vector parity;
5. verify cloud parity and run the versioned retrieval/evidence evaluation suites and provider canaries.

A docs-only corpus refresh does not require a Flutter rebuild or Edge Function redeploy. Redeploy the Edge Function only when routing, context builders, retrieval, prompt assembly, response/evidence schema, or safety code changes. Activation and rollback use corpus build IDs rather than destructive table reset.

## Evaluation

RAG evaluation must cover:

- Chinese and English retrieval
- exact-term and paraphrased app-logic questions
- heading/path relevance
- planned/non-goal status handling
- no-result behavior
- record-summary permission on/off
- missing dimensions
- `energy_ratio` and `gram_per_kg` decision semantics
- document changes followed by seed regeneration
- prompt-injection text inside retrieved content
- no raw rows, notes, images, tokens, or secrets in prompts/evidence/logs

Useful metrics include source recall on a reviewed question set, top-result relevance, no-result rate, missing-dimension correctness, evidence/source agreement, latency, and serialized context size. Retrieval quality claims require a versioned evaluation set rather than anecdotal examples. Release Gates require recall@3 >= 0.97, reviewed precision@3 >= 0.85, critical top-1 >= 0.95, normal Edge retrieval p95 <= 1,500 ms, and one-retry increment <= 3,500 ms. Production timing separates query normalization, concurrent lexical-candidate and query-embedding work, final hybrid RPC, local reranking, optional rewrite planning and the second retrieval; Gateway timing separately measures planning, context building, provider generation/validation/correction, and persistence. A path that does not request Document RAG records embedding as `not_requested`, which makes routing behavior directly auditable without retaining user text or vectors.

## Non-goals

- full cloud synchronization into local SQLite for AI
- user-record vector databases
- long-term semantic memory over business data
- GraphRAG
- unrestricted database exploration
- sending full raw history because a context builder is missing
- provider-generated targets replacing deterministic calculations
- treating retrieved documents as executable instructions
- autonomous retrieval/action loops

## Related Documents

- [AgentDesign.md](AgentDesign.md): Agent permissions, workflows, confirmation, and privacy boundary
- [AIOutputContract.md](AIOutputContract.md): output schemas, provider constraints, validation, and correction
- [Algorithm.md](Algorithm.md): deterministic formulas and workflow semantics
- [Database.md](Database.md): `document_chunks`, logs, cloud records, and persistence
- [CloudLocalDataBoundary.md](CloudLocalDataBoundary.md): cloud/local authority and cache behavior
- [References.md](References.md): RAG, security, privacy, and evidence sources
- [../../RAG_FOUNDATION_REMEDIATION_SCOPE.md](../../RAG_FOUNDATION_REMEDIATION_SCOPE.md): confirmed scope for the active RAG foundation remediation; it describes required future work, not current behavior
- [../../RAG_FOUNDATION_REMEDIATION_ENGINEERING_PLAN.md](../../RAG_FOUNDATION_REMEDIATION_ENGINEERING_PLAN.md): active implementation, validation, deployment, and rollback plan
- [../history/phase5/PHASE5_ENGINEERING_PLAN.md](../history/phase5/PHASE5_ENGINEERING_PLAN.md): historical original Phase 5 controlled-RAG implementation, deployment, and acceptance plan

## Code References

- Router: `supabase/functions/ai-chat-route/workflow_router.ts`
- Context builders: `supabase/functions/ai-chat-route/context_builders.ts`
- Document retrieval: `supabase/functions/ai-chat-route/document_rag.ts`
- Prompt assembly: `supabase/functions/ai-chat-route/prompt_builder.ts`
- Gateway evidence: `supabase/functions/ai-chat-route/index.ts`, `supabase/functions/ai-chat-route/phase5_types.ts`
- Document schema/RPC: `supabase/migrations/202607080001_phase5_document_rag_index.sql`
- Foundation corpus and hybrid RPC: `supabase/migrations/202607130001_rag_foundation_document_hybrid.sql`
- Indexed candidate retrieval: `supabase/migrations/202607150003_rag_hybrid_indexed_candidates.sql`, `supabase/migrations/202607150004_rag_parallel_candidate_fusion.sql`
- Service-role grants: `supabase/migrations/202607090001_phase5_structured_rag_service_role_grants.sql`
- Ingestion tool: `tool/phase5_document_rag/build_document_chunks.mjs`
- Generated seed: `supabase/seed_phase5_document_chunks.sql`
- Reliability evaluation: `tool/evals/run_rag_foundation_cloud_eval.mjs`, `docs/reports/RAG_RELIABILITY_OPTIMIZATION_REPORT.md`; generated raw evidence remains under `test/evals/reports/`
- Flutter evidence model/UI: `lib/domain/models/ai_gateway_evidence.dart`, `lib/features/ai/ai_page.dart`
