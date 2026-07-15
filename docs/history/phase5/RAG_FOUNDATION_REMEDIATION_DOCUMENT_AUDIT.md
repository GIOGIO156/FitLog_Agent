# RAG Foundation Remediation Document Audit

## Responsibility

This audit records the W1 before/after inventory for the confirmed RAG foundation remediation. It is historical engineering evidence, not a current product source of truth and not part of the user-facing Document RAG corpus. Current behavior remains owned by README, the bilingual stable design tree, and `docs/API_CONTRACT_DRAFT.md` as defined in `AGENTS.md`.

## Repository Markdown Inventory

The W1 scan found 47 Markdown files. Every file is assigned one responsibility; no file is silently treated as current product evidence merely because it contains relevant words.

| Classification | Files | Count | Corpus authority | W1 action |
| --- | --- | ---: | --- | --- |
| User-facing stable current source of truth | `README.md`, `docs/en/*.md`, `docs/zh/*.md` in the required ten-file bilingual tree | 21 | `current_product`; eligible for the canonical user corpus | Preserve document charters and bilingual meaning; integrate workout input semantics into owning sections. |
| Current public wire contract | `docs/API_CONTRACT_DRAFT.md` | 1 | Current contract, excluded from user corpus | Preserve as the wire owner; W6-W8 update actual planner, exercise, retrieval, evidence, Food, and provider fields. |
| Historical implementation context | `docs/FitLog_Agent_V1_Implementation.md` | 1 | Historical, excluded | Keep rationale and provenance; current stable docs/code override early planned wording. |
| Shipped history | `CHANGELOG.md` | 1 | Historical, excluded | Do not add remediation claims until deployed facts exist. |
| Contributor/roadmap/active plans | `AGENTS.md`, `AI_OUTPUT_CONTRACT_ENGINEERING_PLAN.md`, `docs/ROADMAP.md`, `RAG_FOUNDATION_REMEDIATION_SCOPE.md`, `RAG_FOUNDATION_REMEDIATION_ENGINEERING_PLAN.md` | 5 | Maintenance/planned, excluded | Keep Scope and Gate status here; do not copy checklists into stable docs. |
| Archived engineering plan | `docs/history/phase5/PHASE5_ENGINEERING_PLAN.md` | 1 | Historical, excluded | Retain as original Phase 5 evidence; it cannot override the confirmed remediation Scope. |
| Frozen FitLog Local baseline | `docs/local/README.local.md`, `docs/local/CHANGELOG.local.md`, and fourteen `docs/local/en|zh/*.local.md` files | 16 | `local_baseline`, excluded | Preserve Local facts and history; repair links after relocation and never present Local-only behavior as Agent current behavior. |
| Asset note | `ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md` | 1 | Asset maintenance, excluded | No product-design ownership. |

Total: 47 files.

## Stable Owning-Document Block Inventory

The table classifies each meaningful stable-document block by concern. Existing headings remain capability-oriented; remediation facts are integrated into these owners rather than appended as dated updates.

| Owner | Meaningful block classes | Canonical material preserved | W1 disposition |
| --- | --- | --- | --- |
| `README.md` | Product promise, capability summary, setup, privacy boundary, document map | Chinese-first/English-second parity, Local provenance, server-managed provider keys, scoped RAG/no-write boundary | Preserve the user's active-plan navigation edits. Final current-capability wording waits for W10 deployment alignment. |
| `Product.md` | Product principles, modules, workflows, user confirmation, capabilities, non-goals | Separate diet modes, AI primary entry, cloud official records/local cache, draft confirmation | Add the durable user-visible strength input semantics; provider/RAG end state waits for implementation. |
| `AppGuide.md` | Navigation, visible flows, failures, confirmation, area links | Add Food entry, AI artifact review, workout draft retention, saved-record editing behavior | Add total/per-side/bodyweight/assistance/duration entry behavior and Bulgarian example. |
| `Methodology.md` | User-facing rationale and evidence limits | Diet-mode separation, carb strategies, net calories, confirmation | Restore why raw strength entries and normalized calculation values are separate. |
| `Algorithm.md` | Deterministic inputs, formulas, strategy separation, workout calories, boundaries | Exact `energy_ratio`/`gram_per_kg` separation, saved snapshot rules, strength heuristic | Preserve existing normalization formulas and add a worked `bulgarian_split_squat` example plus independent load/reps normalization invariant. |
| `Database.md` | SQLite/cloud schema, persisted semantics, migrations, aggregates, export, non-goals | SQLite v16 compatibility, cloud authority, workout input/calculation fields | Expand current field semantics for all load/reps/duration modes; no SQLite version bump because no local schema changed. |
| `CloudLocalDataBoundary.md` | Authority, cache lifecycle, offline downgrade, conflicts, repair, privacy | Cloud official record authority, bounded cache, account binding, optional cache failure | Preserve. W7/W10 add request-scoped custom exercise reference and history authority only after code lands. |
| `AgentDesign.md` | Agent capabilities, entry points, context/privacy/write permissions | Server authority, summary permission, no silent writes, scoped RAG | Preserve. W6-W8 integrate planner, action context, capability/provider boundary after implementation. |
| `AIOutputContract.md` | Envelopes, families, schemas, validation, correction, errors, confirmation | Provider-independent envelope, strict validation, one correction, draft-only semantics | Preserve. W7-W8 add workout v3 and Food semantic/grounding contracts after tests pass. |
| `RAGDesign.md` | Context categories, corpus, ingestion, retrieval, evidence, failure, evaluation | Same-chat/Structured/Document separation, no user vector memory, data minimization | Preserve the user's active-scope links. W2-W8 replace lexical-only current architecture only when production code is implemented. |
| `References.md` | Stable reference IDs and narrow evidence boundaries | Internal decisions are not falsely attributed to external literature | Preserve; no new external factual claim was needed for W1 terminology. |

The English and Chinese files retain matching heading outlines. Translations need not be literal, but every W1 rule above appears in both languages.

## Local Baseline Review And Link Repair

The Local baseline contains the strongest pre-Agent statements for strength entry semantics:

- `Product.local.md` lists total load, per-side load, added bodyweight load, assistance load, total reps, per-side reps, and duration sets.
- `AppGuide.local.md` explains visible labels and assisted-bodyweight behavior.
- `Methodology.local.md` explains raw display values versus normalized calculation values.
- `Algorithm.local.md` defines per-side load/reps multiplication and assisted-bodyweight load.
- `Database.local.md` defines input modes and raw/calculation fields.

These facts match current Dart models, `ExerciseCatalog`, `WorkoutCalorieCalculator`, and SQLite v16 fields, so the current Agent stable owners now preserve them. Local files remain frozen provenance rather than Agent authority.

Relocation had left Local sibling links such as `References.md` and `Product.md` broken after filenames gained `.local.md`, while `README.local.md` still used repository-root-relative paths. W1 changed link targets only:

- Local English/Chinese sibling links now target `*.local.md`.
- `README.local.md` links to current root/stable files now resolve from `docs/local/`.
- A deterministic relative-link scan reports zero broken links under `docs/local/`.

No Local formulas, claims, dates, or historical entries were rewritten.

## Code And Contract Comparison

| Fact checked | Local/stable statement | Current implementation evidence | Result/action |
| --- | --- | --- | --- |
| Official UI term for per-side repetitions | `每侧次数` / `Per-side reps` | `AppStrings.repsInputModeLabel`, workout editor labels | Confirmed; versioned as `per_side_reps`, with reviewed aliases kept distinct from `total_reps`. |
| Per-side load calculation | Multiply only the load dimension by two | `WorkoutSet.calculationLoadKg`, workout calorie service | Confirmed in Algorithm/Database; no blanket unilateral doubling. |
| Per-side reps calculation | Multiply calculation reps by two, preserve raw input | `WorkoutSet.calculationReps`, workout calorie service | Confirmed; Bulgarian input 12 remains display 12 and calculates as 24. |
| Assisted/bodyweight semantics | Assistance subtracts from bodyweight; added load adds external weight | `ExerciseLoadInputMode`, workout calorie service | Confirmed and documented separately; concepts are a do-not-merge pair. |
| Duration sets | Preserve seconds; use bounded equivalent | `ExerciseSetMetricType.durationSeconds`, set model/calorie service | Confirmed. |
| Built-in exercise truth | English definition in Dart; Chinese name previously private to UI | `ExerciseCatalog`, former `AppStrings.exerciseDisplayName` map | Chinese map moved to the catalog layer; UI now consumes it and every built-in has parity coverage. |
| Bulgarian definition | Per-side reps | `ExerciseCatalog` key `bulgarian_split_squat` | Confirmed and added to the generated bilingual exercise terminology. |
| Cloud/local authority | Cloud official records, local partial cache/drafts | cloud repositories, SQLite cache/read models, stable boundary docs | Confirmed; no user-record vector store or full custom-exercise cloud sync is authorized. |
| Request summary permission | Parsed by Gateway but incomplete in public example | `allowRecordSummaryContext` in Edge contracts | Confirmed gap; W6/W8 own the wire correction. |
| Current RAG retrieval | Single lexical RPC, handwritten source list | generator, `document_rag.ts`, migrations | Confirmed gap; stable docs are not changed to claim hybrid/vector until W2-W4 and deployment complete. |
| Current Food reliability | Strict shape, limited domain checks, Qwen-only dedicated surface | shared output validator, dedicated endpoint/page | Confirmed gap; W8 owns capability layering, language/fact semantics, and dual-provider support. |

## Versioned Terminology Deliverables

W1 establishes two machine-readable, jointly versioned assets:

- `assets/rag/domain_terms.v1.json` owns product concepts, official Chinese/English labels, reviewed aliases, internal values, categories, and explicit do-not-merge boundaries.
- `assets/rag/exercise_terms.v1.json` is generated from `ExerciseCatalog` and owns stable exercise keys, official bilingual names, reviewed aliases, and input/calculation modes without hand-copying the catalog into Markdown.

The core dictionary covers total/per-side/added-bodyweight/assistance load, total/per-side reps, duration sets, both diet modes, diet phase, carb cycling/tapering, cloud authority/local cache, draft families, Structured/Document RAG, evidence, and record-summary permission. `per_side_reps` and `total_reps`, `per_side_load` and `total_load`, `bodyweight_added` and `assistance_load`, and `energy_ratio` and `gram_per_kg` are explicit do-not-merge pairs.

## Before/After Preservation Record

| Area | Before W1 | After W1 | Deleted material |
| --- | --- | --- | --- |
| Markdown ownership | 47 files had implicit roles; current, historical, Local, plan, and asset material could be confused by naive allowlists | All 47 files are assigned an authority class; only the 21 current stable sources are eligible for the user corpus | None |
| Workout terminology | Official UI labels existed in code; stable docs incompletely exposed the full modes and aliases | Versioned bilingual product/exercise terminology plus app/catalog parity tests | None |
| Exercise localization | Chinese action map lived privately in `AppStrings` | Catalog layer owns the map; `AppStrings` delegates | The duplicated UI-private map was replaced only after its entries moved intact |
| Stable strength semantics | Algorithm had formulas, while Product/AppGuide/Methodology/Database lacked a complete cross-reader explanation | Each owning document now carries only its appropriate user behavior, rationale, formula example, or persisted-field meaning in both languages | None |
| Local baseline links | Relocation produced broken links | Zero broken Local relative links; content remains frozen | None |
| Active remediation links | README/Roadmap/RAGDesign already had user edits pointing to active Scope/plan and archived Phase 5 plan | Preserved unchanged as part of the protected dirty-tree baseline | None |

## Unresolved And Deferred Evidence

There is no unresolved product-design conflict in W1. The current process lacks service-role and provider credentials, so cloud active-corpus, Edge-version, embedding, and live-provider facts are not asserted here. Those are deployment evidence owned by W10. Stable docs will describe the hybrid/planner/provider/Food end state in present tense only after the corresponding local Gates and deployment/canary evidence exist.
