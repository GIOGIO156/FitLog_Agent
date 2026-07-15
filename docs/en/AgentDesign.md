# Agent Design

## Purpose

This document defines the product-level AI and Agent boundary for FitLog_Agent V1: which capabilities exist, where they may be entered, what data they may use, what they may return, and which actions always remain under user control.

Detailed model-output schemas, validation, correction, and failure semantics belong to [AIOutputContract.md](AIOutputContract.md). Context objects, retrieval, ingestion, evidence, and RAG safety belong to [RAGDesign.md](RAGDesign.md). Exact product interaction and visual rationale belong to [Product.md](Product.md).

The durable rule is:

```text
AI may draft, explain, retrieve bounded context, and ask follow-up questions.
AI must not silently write official records, change goals or strategies, or delete data.
```

FitLog's deterministic logging, diet, workout, summary, and export systems remain authoritative. The Agent layer wraps those systems with account-gated remote AI, typed drafts, scoped retrieval, and user-visible evidence; it does not make the model a database operator or autonomous coach.

## Operating Model

FitLog does not execute a model on-device. Remote calls pass through Supabase Edge Functions with server-managed provider credentials.

```text
User request
  -> authentication, subscription, and active-device checks
  -> fixed-entry and deterministic safety rules
  -> approved Task Plan and server Context Policy
  -> allowed same-chat / exercise / Structured RAG / Document RAG context
  -> configured provider call (Qwen in the current release)
  -> shared output validation and normalization
  -> accepted answer, optional typed draft, and evidence
  -> user review before any official write
```

Each AI path separates four responsibilities. Surface orchestration owns entry, target language, local provider preference, approved terminal states, and UI confirmation. A versioned Capability Core owns task, Food/Workout semantics, fact priority, and context needs. OpenAI/Qwen adapters encode that capability into provider-specific text, image, schema, and tool protocols without redefining product rules. Shared validation enforces structure, domain semantics, language, grounding, safety, and confirmation. A provider change cannot broaden context, alter fact priority, bypass validation, or write official data.

The operating layer includes:

- cloud account, subscription state, Cloud Profile, Cloud Records, and daily summaries;
- a centered full-screen AI Chat entry;
- current-release Qwen text/image routing without user-supplied API keys, plus retained OpenAI adapters for a future legally configured release;
- Qwen AI Chat multimodal requests and dedicated Add Food Qwen image requests with up to three images;
- cloud chat history and bounded same-chat continuity;
- Structured RAG over minimum-necessary summaries;
- Document RAG over stable bilingual FitLog documents;
- schema-validated Food Draft and Workout Draft artifacts;
- explicit user review and normal editor save before official writes.

The operating layer excludes:

- user-supplied provider keys;
- open-ended tool calling or Agent loops;
- multi-Agent systems;
- unrestricted database access or model-generated SQL;
- complete-history upload as a substitute for a context builder;
- user-business-data embeddings, vector databases, GraphRAG, or long-term semantic memory;
- silent goal, strategy, record, or deletion actions;
- medical diagnosis or treatment guidance.

## Capability Classification

AI-adjacent compatibility features and Agent workflows must remain distinguishable:

| Capability | Behavior | Classification |
| --- | --- | --- |
| Prompt template copy | Establishes a reusable external food-estimation chat contract: send once per new external chat, then submit photos, descriptions, and corrections. Replies retain the existing complete flat JSON schema; trailing `estimation_notes` is normally empty and is limited to necessary non-duplicative supplemental information. The copied language follows the app language. | User-mediated external AI, not app-internal AI or an Edge prompt. |
| External AI JSON paste | User pastes externally generated food JSON and FitLog parses it locally using the established food-estimate schema. | User-mediated external AI, not app-internal AI. |
| `source = ai_paste` | Marks the origin of a confirmed compatibility-flow food record. | Provenance only, not proof of an internal model call. |
| Add Food AI analysis | Sends text and zero to three optional images to `ai-food-photo-analyze`; the entry fixes the Food Draft family, validates it, and opens Food Preview. | Deterministic server-mediated draft workflow, without Chat intent inference. |
| AI Chat | Sends text and up to three images through Qwen after all gates pass. Selecting unconfigured ChatGPT produces a transient unavailable error and no request; the Gateway handles high-confidence intent first and otherwise lets the configured model select from bounded output types. | Server-mediated answer or draft generation. |
| Structured RAG | Builds typed, minimum-necessary server-side context for routed read-only workflows. | Server-mediated read-only context. |
| Document RAG | Searches the stable bilingual design corpus for app-logic questions. | Server-mediated read-only evidence. |
| User-record-summary permission | Controls whether protected record summaries may enter routed AI context. | Permission control, not AI output. |

Chat persistence, request logs, debug summaries, Gateway transport models, and evidence snapshots are supporting infrastructure. Their presence does not grant the model additional read or write authority.

## Entry Points

The primary Agent entry is the centered AI tab:

```text
Home | Food | AI | Workout | Profile
```

The AI page is a full-screen conversation, not a quick-chip workbench. Apart from Add Food AI analysis, Agent workflows start from this page.

| Entry | Purpose | Boundary |
| --- | --- | --- |
| AI Chat | Food/workout drafting, meal decisions, weekly review, and app-logic Q&A. | Sending requires login, network, active subscription, active device, Cloud Profile, and configured Gateway/provider. |
| Add Food AI analysis | Text or image-based food estimation inside the Food creation flow. | Produces an editable Food Draft; saving requires confirmation. |
| External JSON paste | Compatibility path for externally generated food JSON. | Local parsing under user control; not an Agent call. |

## AI Surface Contract

The AI page must make capability and authority visible without exposing provider internals:

- The composer remains editable while sending is unavailable, but the send action stays disabled until every runtime gate passes.
- The usable Qwen selection is device-local. Exact models and provider credentials remain server-side. An unavailable ChatGPT selection enters the current UI only for brief tap feedback, then the selector automatically slides back to Qwen; it is not persisted as an active provider.
- Up to three JPEG, PNG, or WebP attachments are supported. Current requests route through Qwen. Selecting unconfigured ChatGPT in AI Chat or Add Food AI analysis shows the normal transient `current model unavailable` error, preserves input, sends no provider request, and restores the Qwen selection through the shared sliding control. This UI recovery is not provider fallback and never converts the original tap into a Qwen request; the status pill continues to reflect subscription, device, and Gateway readiness only.
- Small local picker-recovery markers may restore composer text, selected provider, attachments, or Add Food analysis after Android activity recreation. Recovery never queues or sends content and never bypasses real account/Gateway readiness.
- Unsent composer text survives tab switches and temporary disabled states during the current runtime. Send start clears it into a pending turn; failure restores it. Logout or account switch clears it.
- Cloud history supports new chat, session switching, inline rename, and delete with confirmation. Archive is not exposed without a recovery UI.
- Assistant text uses maintained Markdown rendering with selectable text, no remote image loading, and no link execution.
- Food Draft and Workout Draft data render as native artifact cards, never as raw JSON inside the assistant message.
- Explicit workflows fix their result family. Model output selection in ordinary Chat controls response shape only and grants no write, delete, or settings authority.
- The Answer basis panel separates reference documents, used data, missing dimensions, and limited actions. Same-chat continuity is not presented as authoritative evidence.

Readiness is distinct from request activity:

| State | Send behavior |
| --- | --- |
| Logged in, online, subscribed, active device, Profile and Gateway ready | Enabled. |
| Logged out, offline, inactive subscription, missing Profile, replaced device, or unconfigured provider | Disabled with a readable reason. |
| Request pending | Readiness remains stable; the send control and assistant loading bubble show activity. |

Visual layout, animation, scroll anchoring, keyboard geometry, navigation treatment, theme accents, and auth-screen presentation are maintained in [Product.md](Product.md) and summarized by app area in [AppGuide.md](AppGuide.md).

## Supported Workflows

### Food Draft Workflow

Add Food AI analysis is an explicit workflow: it bypasses ordinary Chat intent selection, and a successful terminal result must contain an editable Food Draft. Ordinary AI Chat can return a Food Draft through either high-confidence deterministic selection or bounded model selection; both paths use the same canonical schema and confirmation boundary.

Inputs may include a text description, up to three current-request images, selected date, and user corrections. If Chat contains an explicit supported date, the Gateway resolves it against the selected request date; otherwise the selected date remains the default.

1. AI extracts candidate foods, portions, cooking method, nutrition, and uncertainty.
2. Material ambiguity produces a bounded clarification rather than a confident guess.
3. The Gateway validates the versioned Food Draft, requires its date to match the resolved target date, and normalizes meal totals from item totals.
4. Add Food opens Food Preview directly after validation; Chat shows the accepted date and an artifact card, then opens Preview only after review.
5. The user may change the date through the themed calendar control and edit the remaining draft fields.
6. Only the normal confirmed save path writes official food records.

Original images and base64 payloads are not retained after the request. Compact metadata may record image count, input kind, mime type, compressed length, validation result, and safety/error category.

### Workout Draft Workflow

Inputs may include a workout description, selected date, optional current-request image context, and user corrections. Date resolution follows the same explicit-date/default-date/clarification rules as Food Draft.

1. AI extracts a candidate record name, exercises, sets, cardio duration, intensity, uncertainty, and the server-resolved target date.
2. AI may ask one clarification turn listing all material missing fields.
3. If the reply remains incomplete, AI returns an editable best-effort draft with unknown values left empty, or a stable failure; it does not continue an open-ended question loop.
4. Chat shows the validated date and a native artifact card. Review rebuilds the existing workout editor draft, whose date remains changeable through the normal calendar control, and asks before replacing another unsaved draft.
5. Only the normal workout editor Save action writes an official workout record.

### Meal Decision Workflow

The routed read-only workflow may use Cloud Profile, selected-day summaries, saved phase/mode/strategy, remaining kcal or macro targets, and the user's request.

It may answer questions such as what to eat next or whether an order fits the day. It must respect `energy_ratio` versus `gram_per_kg`, explain its evidence and missing data, and never recalculate or change the official plan.

### Weekly Review Workflow

The routed read-only workflow may use bounded 7/14-day summaries, log coverage, workout consistency, weight trend when available, and saved strategy state.

It may summarize patterns, limitations, likely blockers, and small next actions. It may discuss `carb_cycling` or `carb_tapering`, but it cannot apply or modify either strategy.

### App Logic Q&A Workflow

Document RAG answers how FitLog works, including diet modes, workout calorie rules, strategies, storage, export, and privacy boundaries. Chinese questions retrieve Chinese documents; English questions retrieve English documents. A missing relevant source produces an explicit limitation rather than an invented product rule.

## Context And RAG Boundary

FitLog uses three distinct context categories:

- bounded same-chat text and artifact summaries for conversation continuity;
- Structured RAG objects built from known cloud sources and deterministic summaries;
- Document RAG sources retrieved from the stable bilingual design corpus.

Context is built on the server only after auth, subscription, and active-device checks. The client cannot submit server-owned context objects, arbitrary SQL, tool calls, official-write payloads, or provider credentials. Complete raw histories, historical images, unrestricted notes, export archives, and local workout drafts are excluded by default.

Before any Context Builder runs, a versioned `task_plan.v1` separates workflow/context planning from output-family selection. Fixed entries and high-confidence deterministic rules plan first; only an ambiguous request reaches a bounded model planner. The plan carries the server-planned workflow, allowed output family, bounded entities, requested Context, retrieval needs, clarification state, confidence, and source. Server policy then approves or rejects each Context type according to workflow, record-summary permission, and data minimization. Public workflow values may therefore include `workout_logging`, `general_chat`, and `safety_boundary`, while the client can only hint approved entry workflows.

Detailed object schemas, permissions, retrieval, ingestion, evidence, injection handling, evaluation, and update lifecycle are defined in [RAGDesign.md](RAGDesign.md).

## Cloud Data And Profile Boundary

AI context uses Cloud Profile, cloud official records, `daily_summaries`, or controlled summary builders. Local SQLite is partial cache, draft storage, and runtime acceleration; it is not authoritative AI context.

Cloud Profile rules:

- Before login there is no formal Profile.
- After login, Cloud Profile is authoritative. An account without a row receives a safe default Profile.
- Auth sessions persist on-device until explicit sign-out, account change, or unrecoverable recovery failure.
- One account has one active device. A replaced device cannot continue using cache to send AI requests or write protected cloud data.
- Profile loading and subscription loading are independent; a subscription error must not hide a valid Profile editor, but AI remains gated.
- Profile edits remain a page-local draft until one complete Save Changes operation succeeds. AI and other pages continue using the last saved Profile.
- Cached Profile display is allowed during refresh only when cache metadata matches the current account. Cache-write failure must not block a successful cloud read.
- Offline Profile saving is disabled; no pending-profile merge exists in V1.
- Mapping may validate enums and versioned defaults but must not infer a new phase, merge `gram_per_kg` with `energy_ratio`, or overwrite the saved strategy.
- Sign-out clears runtime drafts and account-bound caches without deleting cloud official records.

Detailed reads, writes, cache-first behavior, conflicts, and repair are defined in [CloudLocalDataBoundary.md](CloudLocalDataBoundary.md).

## Subscription And Availability

V1 uses subscription gating rather than a user-visible per-message credit balance. AI send requires login, network, active device, Cloud Profile, active subscription, Gateway, and configured provider checks.

The Profile Subscription entry shows active/inactive/loading/error state and can expose the development internal-code redemption flow. Redemption is a server-owned entitlement RPC backed by hashed codes; clients never receive service-role credentials or direct entitlement-write access. This is not a production payment or app-store subscription implementation.

Backend request counts and model cost may be logged internally. The UI must not invent a quota or credit balance without a separate product decision.

## Output, Retention, And Privacy

All provider replies are untrusted until the Gateway validates the provider-independent envelope, output selection, domain rules, and write policy. The ordinary-Chat resolver may abstain with `auto`, allowing the model to select from bounded types; explicit product entries do not participate in that inference. OpenAI uses strict Structured Outputs; Qwen uses JSON Mode plus the same deterministic validator. Correctable structured failures receive at most one bounded correction attempt. Complete rules are in [AIOutputContract.md](AIOutputContract.md).

Cloud retention may include:

- AI sessions and accepted final chat messages;
- validated artifact/evidence snapshots needed for review and history;
- request metadata needed for reliability, billing audit, abuse prevention, and debugging;
- compact sanitized debug summaries.

It must not include raw provider responses, chain-of-thought, unrestricted tool traces, original images, base64 payloads, provider secrets, auth tokens, or complete retrieved record payloads when a compact summary is sufficient. Production logs are more restrictive than development diagnostics, and the user-facing UI shows accepted messages and artifacts rather than internal traces.

## Tool And Write Permissions

AI can propose writes only through typed drafts:

| Action | AI authority | Confirmation boundary |
| --- | --- | --- |
| Create Food Draft | May propose and prefill. | User reviews and saves in Food Preview. |
| Create Workout Draft | May propose and prefill. | User reviews, resolves replacement, and saves in the workout editor. |
| Edit or delete an official record | No direct authority. | Existing editor/destructive confirmation only. |
| Change Profile, phase, mode, or strategy | Explain or recommend only. | Profile UI confirmation. |
| Apply carb taper/cycling changes | Explain or recommend only. | Existing deterministic review/settings flow. |
| Read protected record summaries | Only when routed and permissioned. | User-record-summary permission plus server checks. |

## Safety And Quality Rules

- Ask one bounded question when missing information materially changes a draft; otherwise expose uncertainty.
- State missing context instead of treating it as zero or fabricating it.
- Keep deterministic targets, summaries, dates, and calorie calculations authoritative.
- Treat AI food estimates as editable estimates, not exact nutritional truth.
- Reject unsupported write or privacy requests before provider execution when possible.
- Do not provide medical diagnosis or treatment; keep guidance general and recommend professional help when appropriate.
- Preserve the user-confirmation boundary even after a valid structured response.

## Code References

- AI page/controller: `lib/features/ai/ai_page.dart`, `lib/features/ai/ai_chat_controller.dart`
- Add Food AI analysis: `lib/features/food/*`, `lib/data/remote/ai_food_photo_analysis_client.dart`
- Workout draft handoff: `lib/features/workout/add_workout_page.dart`, `lib/domain/models/ai_workout_draft.dart`
- Account/Profile state: `lib/features/account/account_controller.dart`, `lib/domain/services/cloud_profile_mapper.dart`
- AI repositories and contracts: `lib/data/repositories/ai_chat_repository.dart`, `lib/data/remote/ai_gateway_client.dart`, `lib/domain/models/ai_gateway_*.dart`
- Gateway and output contract: `supabase/functions/_shared/ai_output_contract.ts`, `supabase/functions/ai-chat-route/*`, `supabase/functions/ai-food-photo-analyze/*`
- Cloud schema: `supabase/migrations/*account_profile*`, `*cloud_records*`, `*ai_chat*`, `*document_rag*`, `*ai_output_contract*`
- Deterministic services: `lib/domain/services/daily_summary_service.dart`, `macro_target_calculator.dart`, `workout_calorie_calculator.dart`, `carb_cycling_calculator.dart`, `carb_taper_review_service.dart`
