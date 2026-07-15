# FitLog_Agent V1 API Contract

## Purpose

This document owns the public Flutter-to-service transport shapes and compatibility boundaries for FitLog_Agent V1. It defines request/response envelopes, field constraints, authentication expectations, stable error categories, and retention-visible payloads.

本文只维护 Flutter 与服务端之间实际跨越网络边界的 contract。它不是运行时存储或云端数据库；账号、Profile、records、chat 和 logs 由代码写入 Supabase/Postgres，不会写入本 Markdown 文件。文件名暂时保留历史上的 `DRAFT`，但正文按当前 wire contract 维护，不能再作为阶段 checklist 使用。

Stable model-output governance lives in `docs/en/AIOutputContract.md` / `docs/zh/AIOutputContract.md`. Stable context/RAG governance lives in `docs/en/RAGDesign.md` / `docs/zh/RAGDesign.md`. Provider prompts, validator internals, retrieval ranking, rollout steps, and implementation status must not be duplicated here.

## Contract Invariants

- Supabase provides Auth, Postgres, and Edge Function boundaries; the App never receives service-role or model-provider secrets.
- Email/password sign-in and registration email code are the V1 account transport.
- Subscription entitlement is server-owned. Internal redemption is a development contract, not a production payment provider.
- The current release calls Qwen through the AI Gateway. OpenAI/ChatGPT transport adapters remain implemented and tested but are not called unless a future release has legal server configuration and explicitly enables the client surface.
- Signed-in Cloud Profile and body/food/workout records are cloud-authoritative. Local SQLite is partial cache, draft storage, and runtime acceleration.
- AI requests use only workflow-required context. Complete raw history is not a default request payload.
- Add Food and AI Chat send text plus zero to three compressed JPEG/PNG/WebP images inline through Qwen in the current release. Selecting unconfigured ChatGPT is blocked before transport with a transient unavailable error, preserved input, and an automatic animated return to the Qwen UI selection. Neither path retains original images by default.
- Food Draft and Workout Draft cross the boundary as typed, versioned data and remain drafts until normal editor confirmation.
- AI cannot silently write official records, change Profile/targets/strategies, apply carb tapering, or delete data.
- Document RAG accepts no client-supplied chunks or context objects. User business data does not enter long-term vector memory, semantic memory, or GraphRAG.

## Architectural Rationale

Supabase keeps account identity, relational Profile/records/summaries/chat/log data, and Edge Function Gateway execution in one bounded backend while retaining a future migration or self-hosting path. Postgres matches the relational data model more directly than an unstructured document store. Development entitlement validates gating without pretending a production payment/IAP decision has been made. Server-managed provider secrets keep Flutter independent from model vendors and exact model aliases.

## Backend Boundary

服务端负责：

- Auth/session
- subscription entitlement
- Cloud Profile
- Cloud Records
- daily summaries
- AI Gateway routing
- model API key management
- prompt/schema/model versioning
- schema validation
- safety guard
- chat sessions/messages
- Document RAG retrieval
- request metadata
- compact debug summaries

服务端在 V1 不提供默认无限原始历史读取：

- full raw food history in AI context
- full raw workout history in AI context
- full raw body metric history in AI context
- local export archives
- local SQLite migrations

客户端对需要账号的请求使用 provider 颁发的 session token。具体 token 格式和刷新方式由后端方案决定，但 App 不保存模型供应商 key 或后端 secret。

Locked backend mapping:

| Concern | Current contract |
| --- | --- |
| Auth/session | Supabase Auth, email OTP only for V1 start |
| Cloud database | Supabase Postgres |
| Cloud Profile | `cloud_profiles` table in Supabase Postgres |
| Cloud Records | `body_metric_logs`, `food_records`, `food_items`, `workout_sessions`, `workout_sets`; a separate `workout_records` parent can be added later if the workout UI needs a record header distinct from sessions |
| Daily summaries | `daily_summaries` table or equivalent service-maintained summary view |
| Subscription state | Internal `subscriptions` / entitlement table for development |
| AI Gateway | Supabase Edge Functions |
| Model secrets | Supabase Edge Function Qwen secret for the current release; optional OpenAI secret only when that provider is legally configured and enabled |
| Food analysis transport | Current Add Food workflow sends a text description and zero to three compressed JPEG/PNG/WebP images inline to `ai-food-photo-analyze`; no default Storage persistence |
| Document RAG index | Supabase Postgres document chunks with active-build hybrid lexical/vector retrieval; Qwen `text-embedding-v4`, 1536 dimensions, and no user-data vectors |

## Common API Rules

Recommended headers:

```text
Authorization: Bearer <session_token>
X-FitLog-App-Version: <version>
X-FitLog-Platform: android|ios|web|desktop
X-FitLog-Language: zh|en
X-FitLog-Timezone: Asia/Shanghai
Idempotency-Key: <uuid>  # write-like requests
```

Common response envelope:

```json
{
  "ok": true,
  "data": {},
  "error": null,
  "request_id": "req_..."
}
```

Common error envelope:

```json
{
  "ok": false,
  "data": null,
  "error": {
    "code": "subscription_inactive",
    "user_message_key": "ai.error.subscriptionInactive",
    "retryable": false,
    "details": {}
  },
  "request_id": "req_..."
}
```

Stable error code families:

```text
auth_required
auth_expired
device_replaced
subscription_inactive
network_unavailable
profile_not_found
profile_conflict
payload_too_large
image_upload_failed
unsupported_attachment
gateway_timeout
provider_failure
request_schema_mismatch
provider_output_invalid
provider_refusal
provider_incomplete
record_schema_mismatch  # compatibility with older record/database paths
rag_no_result
write_confirmation_required
write_not_allowed
rate_limited
unknown
```

## Endpoint Shape

Recommended endpoints:

```text
POST /auth/*
POST /account/active-device/claim
POST /account/active-device/release
GET  /subscription/status
GET  /profile
PUT  /profile
GET  /ai/chats
POST /ai/chats
GET  /ai/chats/{chat_id}/messages
DELETE /ai/chats/{chat_id}
POST /ai/chat/route
POST /ai/food-photo/analyze
POST /ai/food-estimate
POST /ai/meal-decision
POST /ai/weekly-review
POST /ai/app-docs-answer
```

`/ai/chat/route` is the product-level chat entry for text and explicitly selected OpenAI/Qwen multimodal requests with up to three images. Dedicated workflow endpoints are implementation surfaces used by the router or by narrowly scoped UI flows. The current Add Food AI food analysis workflow is implemented by the Supabase Edge Function `ai-food-photo-analyze`; it accepts text-only requests or text plus up to three optional images. Chat image requests use the same draft-confirmation boundary and do not store original image bytes.

## Subscription Contract

`GET /subscription/status` returns:

```json
{
  "account_id": "acct_...",
  "status": "active",
  "plan_id": "fitlog_ai_monthly",
  "current_period_end": "2026-07-17T00:00:00Z",
  "provider": "internal_dev_entitlement",
  "checked_at": "2026-06-17T00:00:00Z"
}
```

Rules:

- App UI only shows whether AI is usable.
- V1 does not show user-visible remaining quota.
- Every AI Gateway request must be checked server-side.
- Backend may log request counts, cost metadata, model, latency, image count and subscription tier for operations and billing audit.
- Development uses at least two seeded accounts and at least one internal redeem code: one active subscription account, one inactive subscription account, and one inactive-to-active redeem path for gating regression tests.
- Production payment integration is deferred until a later release-hardening or commercialization decision; it must still write the same server-side entitlement contract.

## Cloud Profile Contract

Cloud Profile is created after login/onboarding and is authoritative after login.

Recommended fields:

```json
{
  "account_id": "acct_...",
  "display_name": "RINKO",
  "age": 28,
  "height_cm": 170.0,
  "weight_kg": 68.0,
  "sex_for_formula": "female",
  "diet_goal_phase": "cutting",
  "diet_calculation_mode": "energy_ratio",
  "daily_energy_goal_kcal": 1800,
  "protein_ratio_percent": 30,
  "carbs_ratio_percent": 40,
  "fat_ratio_percent": 30,
  "training_frequency_per_week": 4,
  "diet_plan_strategy": "carb_cycling",
  "carb_cycle_pattern_json": "{}",
  "carb_cycle_high_multiplier": 1.15,
  "carb_cycle_medium_multiplier": 1.0,
  "carb_cycle_low_multiplier": 0.85,
  "carb_taper_review_period_days": 14,
  "carb_taper_target_loss_pct_per_week": 0.5,
  "carb_taper_step_g": 20,
  "carb_taper_current_delta_g": 0,
  "language_code": "zh",
  "profile_version": "profile_42",
  "created_at": "2026-06-17T00:00:00Z",
  "updated_at": "2026-06-17T00:00:00Z"
}
```

Rules:

- `diet_goal_phase` remains the source of cutting/bulking phase.
- `diet_calculation_mode` must keep `energy_ratio` and `gram_per_kg` separate.
- In `gram_per_kg`, macro grams are primary and kcal is auxiliary.
- In `energy_ratio`, kcal target/intake/remaining is primary.
- Offline saves are disabled. No pending profile merge is introduced in V1.
- Account deletion deletes Cloud Profile and account-bound identifiable AI conversation data.

## Active Device Contract

V1 uses one active device per account. A newer login takes over the account (`last login wins`). This avoids realtime multi-device sync and prevents older devices from continuing official writes while their old access token may still be temporarily valid.

Client behavior:

- Each app install creates and locally stores a stable `device_id`.
- After sign-in succeeds, the app calls `claim_active_device`.
- If a later cloud read, official write, subscription refresh, or AI request returns `device_replaced`, the app clears local auth/session state and shows a specific account-replaced message instead of a generic upload failure.
- Older devices do not need realtime push logout; they become inactive on their next cloud interaction.

Recommended RPCs/endpoints:

```text
POST /account/active-device/claim
POST /account/active-device/release
```

`claim_active_device` request:

```json
{
  "device_id": "dev_...",
  "allow_record_summary_context": false,
  "exercise_references": [
    {
      "key": "custom_split_squat",
      "name": "我的单侧蹲",
      "definition_hash": "8f31a220",
      "exercise_type": "strength",
      "body_part": "Legs",
      "strength_structure": "compound",
      "strength_profile": "lower_body_compound",
      "load_input_mode": "total_load",
      "reps_input_mode": "per_side_reps",
      "set_metric_type": "reps"
    }
  ],
  "session_id": "sess_...",
  "platform": "android",
  "app_version": "1.0.0"
}
```

Rules:

- The server derives `account_id` from auth context.
- The newest successful claim overwrites the previous active device.
- Official body/food/workout writes, Cloud Profile saves, and AI Gateway requests must call an active-device guard such as `assert_active_device`.
- `device_replaced` is stable and non-retryable with the old session. Re-login may claim the account again.
- Supabase single-session behavior may assist session cleanup, but correctness must not rely on immediate old-session revocation.

## Cloud Records Contract

Cloud Records are introduced before AI Gateway workflows depend on user history. They are the official source of truth for signed-in body metrics, food records, workout records, and daily summaries. Local SQLite may cache subsets for performance, but cache completeness must not be required for AI context or export correctness. Detailed cache-first, warm-cache, eviction, failure, conflict, and repair policy lives in `docs/en/CloudLocalDataBoundary.md` / `docs/zh/CloudLocalDataBoundary.md`.

Core tables:

```text
body_metric_logs
food_records
food_items
workout_records
workout_sessions
workout_sets
daily_summaries
```

Common record fields:

```json
{
  "id": "rec_...",
  "account_id": "acct_...",
  "date": "2026-06-17",
  "source": "manual",
  "record_version": 3,
  "created_at": "2026-06-17T00:00:00Z",
  "updated_at": "2026-06-17T00:00:00Z",
  "deleted_at": null
}
```

Rules:

- All record reads and writes are scoped to the authenticated account.
- Official writes must pass active-device verification; older devices receive `device_replaced` and must not create local official records.
- `body_metric_logs` stores historical measurements only: weight, body-fat percentage, and waist circumference.
- The current Profile body fields remain in Cloud Profile; historical body logs do not include age, height, or sex.
- `body_metric_logs` should be unique per `account_id + date`.
- Food and workout writes are immediate record-level writes, not page-wide Profile-style drafts.
- Deletes are soft deletes by default and must update summaries.
- Date-range reads are required; full-history reads are not a UI or AI default.
- Export may page through cloud records, but ordinary UI and AI context must use summaries/ranges.

Recommended endpoints:

```text
GET    /records/body-metrics?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD
PUT    /records/body-metrics/{date}
DELETE /records/body-metrics/{date}

GET    /records/food?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD
POST   /records/food
PUT    /records/food/{id}
DELETE /records/food/{id}

GET    /records/workouts?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD
POST   /records/workouts
PUT    /records/workouts/{id}
DELETE /records/workouts/{id}

GET    /summaries/daily?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD
```

Local cache contract:

- Local cache is a performance and read-model layer, not the official source.
- Cache entries should track enough account, freshness, pending, and source-version metadata to enforce the boundary rules.
- Eviction deletes local cache only; cloud records remain authoritative and can be fetched again.
- Detailed cache-first, warm-cache, pinning, eviction, account-switch, failure, and repair rules live in `docs/en/CloudLocalDataBoundary.md` / `docs/zh/CloudLocalDataBoundary.md`.

## AI Gateway Request

`POST /ai/chat/route` request:

```json
{
  "session_id": "chat_...",
  "message": {
    "text": "今天还能吃什么？"
  },
  "attachments": [
    {
      "kind": "image",
      "mime_type": "image/jpeg",
      "base64_data": "...",
      "byte_length": 512000,
      "name": "meal.jpg"
    }
  ],
  "language": "zh",
  "model_choice": "qwen",
  "workflow_hint": "auto",
  "selected_date": "2026-06-17",
  "profile_version": "profile_42",
  "device_id": "dev_...",
  "conversation_context": {
    "messages": [
      {
        "role": "assistant",
        "text": "已生成饮食草稿，确认后才会保存。"
      }
    ],
    "artifacts": [
      {
        "type": "food_draft",
        "title": "鸡腿饭",
        "summary": "约 610 kcal"
      }
    ]
  },
  "client": {
    "app_version": "1.0.0",
    "platform": "android",
    "timezone": "Asia/Shanghai",
    "draft_schema_version": "v3"
  }
}
```

Rules:

- `model_choice` can be `chatgpt` or `qwen`. UI labels can be `ChatGPT` and `千问`; backend provider ids should remain stable as `openai` and `qwen`.
- Wire compatibility retains both enum values, but the current client sends only `qwen`. Selecting unconfigured ChatGPT produces no HTTP request; the selector automatically returns to Qwen, but that UI recovery does not submit or transform the attempted ChatGPT request.
- `workflow_hint` can be `auto`, `food_logging`, `workout_logging`, `meal_decision`, `weekly_review`, or `app_logic_answer`. `general_chat` and `safety_boundary` are server-planned response workflows, not accepted client hints.
- `attachments` is optional. The current Chat route accepts up to three image attachments for either explicitly selected image-capable `chatgpt` or `qwen` routing and never silently changes the provider.
- Supported attachment MIME types are `image/jpeg`, `image/png`, and `image/webp`; compressed payloads above 4 MB are rejected.
- `conversation_context` is optional and limited to compact same-chat text turns plus Food Draft / Workout Draft artifact summaries. It must not contain raw SQL rows, raw images, base64 payloads, provider secrets, or full business history.
- `allow_record_summary_context` defaults to `false`. When false, selected-day, recent-record, body-trend, and exercise-history builders are rejected with named missing dimensions; it does not disable safe stable-document or exact exercise-definition context.
- `exercise_references` is optional and contains at most four active local custom definitions whose exact name matched this request. Each entry uses the strict fields shown above. It is request-scoped, is never a full custom library upload, and does not authorize history or writes. Duplicate names remain candidates and require clarification.
- For Chinese questions, Document RAG targets Chinese docs. For English questions, it targets English docs.
- AI Gateway must reject unsupported writes unless user confirmation and schema validation have already happened.
- The AI Gateway calls the selected configured provider through server-side adapters. Each provider has one server-configured multimodal generation model ID used for text, image and structured-output requests; Flutter never supplies or hard-codes it. Document RAG uses the separate `FITLOG_DOCUMENT_EMBEDDING_MODEL=text-embedding-v4` and a Qwen embedding endpoint derived from `FITLOG_QWEN_BASE_URL`, while reusing `FITLOG_QWEN_API_KEY`.
- Chat may return a schema-validated Food Draft or Workout Draft. The app should show a readable assistant summary plus a native artifact-review button; tapping the button rebuilds the corresponding draft/editor surface from the stored snapshot before any official write.
- Every Chat provider reply uses the internal versioned machine-readable envelope; user-facing Markdown remains inside `message.text`, and Flutter still receives the public response shape below. Exact schemas, provider mapping, validation, correction, and failure rules are owned by `docs/en/AIOutputContract.md` / `docs/zh/AIOutputContract.md`.
- The public `output_type` is `text`, `food_draft`, `workout_draft`, or `clarification`. It is selected by a fixed product workflow, the high-confidence Chat resolver, or bounded model selection after resolver abstention, then validated against the payload before exposure.
- The public `workflow` can additionally expose server-planned `workout_logging`, `general_chat`, or `safety_boundary`; persistence constraints accept these values additively while legacy workflow values remain readable.
- `client.draft_schema_version` is `v3` for the current client. The Gateway can downgrade a validated Workout Draft for v1/v2 clients; omission means legacy v1 response compatibility and never weakens provider validation.
- Draft output resolves a supported explicit date in `message.text` against `selected_date`; otherwise `selected_date` is the default. Ambiguous date language returns clarification. The accepted draft date must equal the server-resolved target date.
- The dedicated Add Food AI food-analysis workflow uses a narrower internal `food_analysis_envelope.v1` without chat-style explanation text while sharing the canonical `food_draft.v2` validator.
- Task plans, normalized retrieval requests/results, tool calls, approved Context objects, evidence registries, corpus/build selection, account IDs used by internal RPCs, SQL, and provider API keys are server-owned. Client requests containing `draft`, `official_record_write`, tool calls, RAG context, or `context_objects` are rejected.

## AI Gateway Response

`POST /ai/chat/route` response:

```json
{
  "session_id": "chat_...",
  "assistant_message_id": "msg_...",
  "model_choice": "chatgpt",
  "model_provider": "openai",
  "message": {
    "text": "今天蛋白质还差一些，晚饭可以优先选择瘦肉或鱼虾。",
    "language": "zh"
  },
  "workflow": "meal_decision",
  "output_type": "food_draft",
  "needs_clarification": false,
  "clarification_questions": [],
  "draft": {
    "schema_version": "food_draft.v2",
    "date": "2026-06-17",
    "meal_name": "鸡腿饭",
    "total_weight_g": 420.0,
    "calories_kcal": 610.0,
    "protein_g": 38.0,
    "carbs_g": 72.0,
    "fat_g": 18.0,
    "confidence": 0.72,
    "estimation_notes": "基于单张图片估算，保存前请确认分量。",
    "items": []
  },
  "error": null,
  "debug_summary_id": "dbg_..."
}
```

If clarification is needed:

```json
{
  "workflow": "food_logging",
  "output_type": "clarification",
  "needs_clarification": true,
  "clarification_questions": [
    "这张图里的肉看不清，你知道是鸡肉、牛肉还是猪肉吗？"
  ],
  "draft": null
}
```

`output_type` and the payload must agree: text has no draft, each draft type carries the matching versioned object and resolved date, and clarification has `needs_clarification = true`, non-empty questions, and no draft. A response that claims a draft was created without the matching artifact is invalid rather than a successful text response. The public `message.text` for a draft is generated from the validated artifact date so it cannot confirm a different date. Older successful responses without `output_type` remain readable through client inference during compatibility rollout.

If the request or final provider result fails, no draft/action is returned and `error.code` is one of:

- `request_schema_mismatch`: invalid Flutter-to-Gateway request
- `provider_output_invalid`: strict output validation still failed after zero or one eligible correction attempt
- `provider_refusal`: the provider explicitly refused
- `provider_incomplete`: generation ended before a complete contract result
- `provider_failure`: provider/service failure without a valid result
- `gateway_timeout`: the total request/provider deadline expired
- `record_schema_mismatch`: compatibility code for older record/database paths

## AI Food Analysis Contract

The current Add Food AI food analysis workflow is a dedicated Gateway surface, implemented by the Supabase Edge Function `ai-food-photo-analyze`.

Request:

```json
{
  "images": [
    {
      "mime_type": "image/jpeg",
      "base64_data": "...",
      "byte_length": 512000
    }
  ],
  "language": "zh",
  "model_choice": "chatgpt",
  "device_id": "dev_...",
  "selected_date": "2026-06-17",
  "schema_version": "food_draft.v2",
  "user_note": "100g 三文鱼，米饭只吃了一半"
}
```

Response:

```json
{
  "model_choice": "chatgpt",
  "model_provider": "openai",
  "draft": {
    "schema_version": "food_draft.v2",
    "date": "2026-06-17",
    "meal_name": "鸡腿饭",
    "total_weight_g": 420.0,
    "calories_kcal": 610.0,
    "protein_g": 38.0,
    "carbs_g": 72.0,
    "fat_g": 18.0,
    "confidence": 0.68,
    "estimation_notes": "图片估算，米饭按用户说明减半。",
    "items": [
      {
        "name": "去皮鸡腿",
        "weight_g": 160.0,
        "calories_kcal": 260.0,
        "protein_g": 34.0,
        "carbs_g": 0.0,
        "fat_g": 12.0
      }
    ]
  },
  "needs_clarification": false,
  "clarification_questions": [],
  "debug_summary_id": "dbg_...",
  "error": null
}
```

Rules:

- Only authenticated, subscribed, active-device users may call the function.
- The current implementation accepts a non-empty text description with zero to three optional JPEG/PNG/WebP images and rejects any compressed payload above 4 MB.
- The server rejects an empty request that has neither images nor a text description, and it does not accept user-supplied provider API keys.
- `model_choice` is `chatgpt` or `qwen`. The page stores this preference under its own device-local key; it neither reads nor overwrites the AI Chat preference.
- In the current release, an unconfigured `chatgpt` selection is a UI-only unavailable state and is not transported or persisted as the active provider; Qwen remains the configured request path.
- The Edge Function forwards request-scoped text and optional images only to a configured, explicitly selected image-capable adapter through server-managed secrets. The current client transports Qwen only; unconfigured ChatGPT stops in Flutter, shows unavailable, and restores the Qwen selector without sending. A later user-initiated send while Qwen is visibly selected follows the normal Qwen path.
- A successful terminal result is a structurally and semantically validated Food Draft. A clarification-compatible response is mapped by the dedicated page to inline input-revision feedback while retaining the current text/images; it does not create a chat session or hidden conversation loop.
- `selected_date` is the exact required draft date for this explicit workflow. Current clients request `food_draft.v2`; the endpoint may downgrade a validated v2 draft to the legacy v1 response shape only when a legacy request explicitly asks for v1.
- A returned draft opens `FoodPreviewPage`; no official `food_records` row is written until the user explicitly saves there.
- Logs store compact metadata such as input kind, selected date, note presence, mime type, compressed byte length, image count, expected output, validator version, first-pass/final validation result, correction count, provider completion category, provider/model and latency. They must not store raw image bytes, base64 payloads, full free-text notes, provider raw responses or provider secrets.

## Food Draft Payload

Food Drafts are transportable, editable proposals, not official records. The public Gateway payload carries meal name, meal totals, optional confidence/notes, and item portion totals. Item values are for the whole estimated portion, and the Gateway normalizes meal totals from items when items are present.

The shared strict `food_draft.v2` contract is defined in `docs/en/AIOutputContract.md` / `docs/zh/AIOutputContract.md`. It includes the required real `date`. That document owns required fields, schema-version compatibility, exact types, bounds, unknown-field policy, normalization, provider mapping, and invalid-output handling. This API draft owns only where the draft appears in request/response/history transport.

An invalid Food Draft must not create a save/review action. Saving requires explicit confirmation in Food Preview; discarding writes nothing.

Allowed confirmed source markers for future official records:

```text
ai_photo
ai_chat
ai_meal_decision
```

Existing `ai_paste` remains the external JSON paste compatibility source.

## Workout Draft Payload

Workout Drafts are transportable, editable proposals, not official records. The current public payload carries `workout_draft.v3`, a required resolved date, record name/notes, exercises, optional cardio metadata, and nullable set values. Every exercise also carries an approved stable `exercise_key`, `exercise_source`, `definition_hash`, and exact load/reps/set modes copied from server-approved definition Context. An unresolved or mismatched definition cannot create an enabled review action. Historical v1/v2 artifacts remain readable through their compatibility path.

The exact schema, best-effort null behavior, one-turn clarification cap, type/range checks, provider mapping, and invalid-output handling are owned by `docs/en/AIOutputContract.md` / `docs/zh/AIOutputContract.md`.

An invalid Workout Draft must not create an enabled review action. The official workout record is written only when the user confirms through the normal workout editor save path. Raw provider JSON is never rendered as ordinary assistant Markdown.

## Context Objects

Context objects are server-owned internal inputs, not fields Flutter may supply. The public request carries only the user-controlled record-summary permission; the Gateway route decides which typed objects are required and returns compact evidence/missing-dimension metadata.

Object families, authoritative sources, permissions, sanitization, context-size limits, deterministic mode semantics, Document RAG, evidence, and failure downgrade are owned by `docs/en/RAGDesign.md` / `docs/zh/RAGDesign.md`.

## Chat History Models

`ai_chat_sessions`:

```json
{
  "id": "chat_...",
  "account_id": "acct_...",
  "title": "今天晚饭",
  "language": "zh",
  "last_message_at": "2026-06-17T00:00:10Z",
  "archived_at": null,
  "deleted_at": null,
  "created_at": "2026-06-17T00:00:00Z",
  "updated_at": "2026-06-17T00:00:00Z"
}
```

`ai_chat_messages`:

```json
{
  "id": "msg_...",
  "session_id": "chat_...",
  "account_id": "acct_...",
  "message_sequence": 1,
  "role": "user",
  "content_text": "今天还能吃什么？",
  "message_type": "text",
  "workflow_type": "meal_decision",
  "model_choice": "chatgpt",
  "model_provider": "openai",
  "request_id": "req_...",
  "final_answer_json": {
    "schema_version": "ai_chat_artifacts.v2",
    "artifacts": [
      {
        "type": "food_draft",
        "schema_version": "food_draft.v2",
        "draft": {
          "schema_version": "food_draft.v2",
          "date": "2026-07-01",
          "meal_name": "鸡腿饭",
          "total_weight_g": 420.0,
          "calories_kcal": 610.0,
          "protein_g": 38.0,
          "carbs_g": 72.0,
          "fat_g": 18.0,
          "confidence": 0.72,
          "estimation_notes": "AI estimate; review before saving.",
          "items": []
        },
        "target_date": "2026-07-01",
        "date_resolution_source": "default",
        "model_choice": "qwen"
      }
    ]
  },
  "attachments_metadata": [],
  "created_at": "2026-06-17T00:00:00Z",
  "deleted_at": null
}
```

Rules:

- Chat tables, Flutter JSON models, the Gateway path, provider routing, authenticated send/history operations, and `rename_ai_chat_session` must satisfy the same session/message contract below.
- Chat history is cloud-stored after login once the Gateway path writes sessions and messages; the AI page reads the owning account's sessions/messages, supports inline rename through RPC, and requires confirmation before soft delete.
- `archived_at` remains in the schema for compatibility with the earlier RPC, but the current AI page does not expose an archive entry because there is no archived-list recovery UI.
- Messages are ordered by `message_sequence`, with `created_at` and `id` as deterministic secondary fields.
- `ai_chat_sessions` and `ai_chat_messages` are client-readable only for the owning account and exclude soft-deleted rows.
- Direct client writes should not bypass the Gateway subscription and active-device checks.
- `final_answer_json` may hold lightweight validated artifact snapshots for assistant messages. These snapshots are not official records or background draft queues; the app uses them only to rebuild preview/confirmation pages when the user taps a review action.
- It is not long-term semantic memory.
- Old sessions are for user review and do not automatically alter future answers unless explicitly selected or referenced.

## Request Logs And Debug Summaries

`ai_request_logs`:

```json
{
  "request_id": "req_...",
  "account_id": "acct_...",
  "session_id": "chat_...",
  "workflow_type": "meal_decision",
  "model_choice": "chatgpt",
  "model_provider": "openai",
  "model": "pending",
  "prompt_version": "prompt_v1",
  "schema_version": "meal_decision.v1",
  "profile_version": "profile_42",
  "status": "ok",
  "error_code": null,
  "latency_ms": 1200,
  "token_estimate": 1400,
  "image_count": 0,
  "expected_output": "text",
  "validator_version": "ai_output_validator.v1",
  "first_pass_validation_status": "passed",
  "correction_attempt_count": 0,
  "final_validation_status": "passed",
  "provider_completion_status": "completed",
  "created_at": "2026-06-17T00:00:00Z"
}
```

`ai_debug_summaries`:

```json
{
  "id": "dbg_...",
  "request_id": "req_...",
  "account_id": "acct_...",
  "session_id": "chat_...",
  "intent": "meal_decision",
  "intent_confidence": 0.86,
  "called_tools_json": ["get_cloud_profile", "get_today_summary"],
  "retrieved_dimensions_json": ["profile", "selected_day_summary"],
  "missing_dimensions_json": [],
  "safety_flags_json": [],
  "schema_validation_status": "passed",
  "user_final_action": "read_only",
  "created_at": "2026-06-17T00:00:00Z"
}
```

Production logs should store compact metadata and sanitized summaries. Authenticated clients should not receive direct table read policies for `ai_request_logs` or `ai_debug_summaries`. These tables should not store chain-of-thought, unrestricted tool traces, full local SQLite payloads, provider secrets, auth tokens, raw provider responses, image base64 payloads, or original images long-term by default.

For Add Food AI food analysis:

- `ai_request_logs.workflow_type = food_logging`
- `ai_request_logs.session_id = null`
- `ai_request_logs.image_count` equals the accepted image count, including `0` for text-only food analysis.
- `ai_request_logs.schema_version = food_draft.v2`
- `ai_debug_summaries.intent = food_photo_analysis`
- `ai_debug_summaries.retrieved_dimensions_json` may include compact request metadata such as mime type, byte length, selected date and whether a user note was supplied.

## Image Transport Policy

Current Add Food and AI Chat policy:

- Original images are not stored long-term by default.
- Images are compressed on device before analysis.
- Transport uses inline JSON payloads: text plus zero to three images in `ai-food-photo-analyze`, and up to three images in `ai-chat-route`.
- Supabase Storage is not used for the current Add Food analysis path.
- The Edge Function forwards only the current request-scoped text and optional images to the provider and must not write raw images, base64 payloads, or full free-text notes into logs, debug summaries, or chat history.
- Non-food, insufficient text, or unclear images should trigger a clarification or refusal, not a forced food record.

Limits for the current image paths:

- `ai-food-photo-analyze`: text description plus 0 to 3 optional images per request
- `ai-chat-route`: 1 to 3 images per explicitly selected OpenAI or Qwen multimodal request
- hard reject any compressed image > 4 MB
- supported MIME types: `image/jpeg`, `image/png`, `image/webp`
- recommended longest edge: 1600 px

Long-term original image libraries, Supabase Storage attachment retention, and more than three Chat images are out of scope until a separate privacy and retention design is approved.

## Document RAG Transport Boundary

The public Gateway does not accept client-supplied document chunks or RAG context. For app-logic questions, the server searches the stable same-language document corpus and returns bounded source/evidence metadata in the Gateway response.

The exact source allowlist, chunk schema, ingestion, retrieval ranking, language rules, status handling, evidence, update lifecycle, privacy boundary, and evaluation requirements are owned by `docs/en/RAGDesign.md` / `docs/zh/RAGDesign.md`. Persistent `document_chunks` fields remain documented in the bilingual Database design.

## Contract Maintenance

- A public field or error-code change must update this file, the corresponding Flutter/server models, contract fixtures, stable owning design documents, and `CHANGELOG.md` together.
- Additive compatibility is preferred. A breaking change requires a new schema/version boundary and an explicit stored-history migration or downgrade rule.
- Provider-specific protocol changes belong in `AIOutputContract.md` unless they alter the public Flutter/Gateway envelope.
- Context or evidence changes belong in `RAGDesign.md` unless they alter a public request/response field.
- Production payment, long-term image retention, larger image limits, and new autonomous actions require separate product/privacy approval; they cannot be inferred from existing optional fields.
