# FitLog_Agent V1 API Contract Draft

本文是 Phase 0 的工程 contract 草案，用于把 Agent V1 的接口形状、数据边界和技术选择集中到一个文件。它不是 App 运行时存储，也不是云端数据库；手机 App 安装运行后不会把用户数据写入这个 Markdown 文件。真正的账号、Profile、chat、日志和图片会由后续代码写入 Supabase/Postgres/Storage。这个文件只作为开发蓝图、接口约定和验收依据。它也不表示运行时代码已经实现；当前 App 仍是复制来的 FitLog Local 基线。

## Phase 0 Status

已经锁定：

- Local food、workout、weight、Profile、SQLite、算法和导出行为继续作为业务基线。
- 后端选型为 Supabase：Auth + Postgres + Storage + Edge Functions。
- 首版登录方式为 FitLog 自有邮箱密码登录 + 注册邮箱验证码；任意可接收验证码的邮箱都可用于账号创建。
- 订阅方案为开发期内部 entitlement：种子账号和内部兑换码区分 subscribed / unsubscribed，不接真实支付 provider。
- AI providers 锁定为 OpenAI/ChatGPT 和千问/Qwen 两种，由服务端 AI Gateway 调用；用户可在 AI Chat 输入区选择使用哪一种。
- 图片先上传到 Supabase Storage 私有临时 bucket，再把 attachment reference 传给 AI Gateway。
- Agent V1 使用云端账号、订阅、Cloud Profile、Cloud Records、daily summaries、AI Gateway、chat history、request metadata 和 compact debug summaries。
- 模型 API key 只能由服务端管理，App 内不提供用户自填 key。
- Phase 3 Cloud Records Foundation 后，body/food/workout 正式记录以云端为 source of truth，本地 SQLite 只做 partial cache。
- AI 请求只读取当前 workflow 所需的最小必要云端摘要。
- Cloud Profile 是登录后的权威 Profile，本地 profile cache 只用于展示/缓存。
- 离线时 Profile 可展示缓存，但不能保存。
- AI 不能静默写正式记录、修改目标、修改策略、应用 carb taper 或删除数据。
- Food Draft 必须先进入草稿/预览/编辑/确认路径，确认后才写入正式 food records。
- Document RAG 只检索 App 文档和稳定帮助片段；用户业务数据不进入长期向量库、semantic memory 或 GraphRAG。

Phase 0 选型说明：

- 选择 Supabase 是为了用一套较轻的 BaaS 覆盖邮箱密码认证、注册验证码、关系型 Cloud Profile / records / summary / chat / log 表、临时图片对象和 Edge Function AI Gateway，避免 Phase 2-4 同时自建 auth、数据库、storage 和 API runtime。
- 相比 Firebase，Supabase 的 Postgres 表结构更贴合 Cloud Profile、records、daily summaries、chat messages、request logs、debug summaries 和 document chunks 这些关系型数据。
- 相比自建后端，Supabase 能更快落地 Phase 2-3，同时保留以后迁移或自托管的可能。
- 开发期订阅只用于验证 gating 和调试账号，不代表生产支付方案已经完成；生产支付/IAP provider 是发布前商业化决策。
- OpenAI 和 Qwen 的 API keys 只进入服务端 secrets；App 不保存模型 key，也不直接调用模型 provider。

结论：Phase 0 的产品边界、技术选型和 API 形状已经收敛，可进入 Phase 1。生产支付 provider、OpenAI/Qwen API key 创建、最终模型名和部署区域仍可在后续阶段按供应商限制调整，但不能改变 V1 的 server-managed key、subscription gating、草稿确认、用户可选模型和最小上下文边界。

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

| Concern | Phase 0 decision |
| --- | --- |
| Auth/session | Supabase Auth, email OTP only for V1 start |
| Cloud database | Supabase Postgres |
| Cloud Profile | `cloud_profiles` table in Supabase Postgres |
| Cloud Records | `body_metric_logs`, `food_records`, `food_items`, `workout_sessions`, `workout_sets`; a separate `workout_records` parent can be added later if the workout UI needs a record header distinct from sessions |
| Daily summaries | `daily_summaries` table or equivalent service-maintained summary view |
| Subscription state | Internal `subscriptions` / entitlement table for development |
| AI Gateway | Supabase Edge Functions |
| Model secrets | Supabase Edge Function secrets for OpenAI and Qwen |
| Temporary images | Supabase Storage private temp bucket |
| Document RAG index | Supabase Postgres document chunks; vector search optional only for docs |

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
invalid_model_output
schema_validation_failed
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
POST /ai/food-estimate
POST /ai/meal-decision
POST /ai/weekly-review
POST /ai/app-docs-answer
POST /ai/attachments
DELETE /ai/attachments/{attachment_id}
```

`/ai/chat/route` is the product-level chat entry. Dedicated workflow endpoints are implementation surfaces used by the router or by narrowly scoped UI flows such as Add Food photo recognition.

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
  "language": "zh",
  "model_choice": "chatgpt",
  "workflow_hint": "auto",
  "selected_date": "2026-06-17",
  "profile_version": "profile_42",
  "device_id": "dev_...",
  "attachments": [
    {
      "attachment_id": "att_...",
      "kind": "image",
      "mime_type": "image/jpeg",
      "size_bytes": 512000,
      "sha256": "hex...",
      "upload_ref": "supabase-storage://ai-temp-attachments/acct_.../chat_.../att_....jpg"
    }
  ],
  "context_objects": [
    {
      "type": "selected_day_summary",
      "version": "v1",
      "payload": {}
    }
  ],
  "client": {
    "app_version": "1.0.0",
    "platform": "android",
    "timezone": "Asia/Shanghai"
  }
}
```

Rules:

- `model_choice` can be `chatgpt` or `qwen`. UI labels can be `ChatGPT` and `千问`; backend provider ids should remain stable as `openai` and `qwen`.
- `workflow_hint` can be `auto`, `food_logging`, `meal_decision`, `weekly_review`, or `app_logic_answer`.
- `context_objects` must be typed summaries, not raw SQL rows by default.
- For Chinese questions, Document RAG targets Chinese docs. For English questions, it targets English docs.
- AI Gateway must reject unsupported writes unless user confirmation and schema validation have already happened.
- The AI Gateway calls the selected provider through server-side adapters. Text, vision and structured-output model names must be environment-configured, not hard-coded in Flutter.

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
  "needs_clarification": false,
  "clarification_questions": [],
  "draft": null,
  "error": null,
  "debug_summary_id": "dbg_..."
}
```

If clarification is needed:

```json
{
  "workflow": "food_logging",
  "needs_clarification": true,
  "clarification_questions": [
    "这张图里的肉看不清，你知道是鸡肉、牛肉还是猪肉吗？"
  ],
  "draft": null
}
```

## Food Draft Schema

Food Drafts are not official records.

```json
{
  "schema_version": "food_draft.v1",
  "draft_id": "draft_...",
  "source": "ai_chat",
  "meal_name": "鸡腿饭",
  "date": "2026-06-17",
  "total_weight_g": 520.0,
  "calories_kcal": 720.0,
  "protein_g": 45.0,
  "carbs_g": 88.0,
  "fat_g": 20.0,
  "confidence": 0.72,
  "estimation_notes": "鸡腿按去皮估算，烹饪油不确定。",
  "uncertain_fields": ["cooking_oil"],
  "clarification_questions": [],
  "items": [
    {
      "name": "去皮鸡腿",
      "estimated_weight_g": 180.0,
      "calories_kcal": 300.0,
      "protein_g": 38.0,
      "carbs_g": 0.0,
      "fat_g": 14.0,
      "notes": "肉类由用户确认，油量仍不确定。"
    }
  ]
}
```

Validation rules:

- Required numeric nutrition fields must be finite and non-negative.
- Item names cannot be empty.
- Missing key food facts should produce `clarification_questions` instead of a saveable draft.
- Invalid schema must not show a save action.
- Saving a draft requires explicit user confirmation.
- Discarding a draft writes nothing.

Allowed confirmed source markers for future official records:

```text
ai_photo
ai_chat
ai_meal_decision
```

Existing `ai_paste` remains the external JSON paste compatibility source.

## Context Objects

Allowed Structured RAG context objects:

| Object | Source | Notes |
| --- | --- | --- |
| `profile_context` | Cloud Profile | Authoritative after login. |
| `selected_day_summary` | Cloud `daily_summaries` / summary builder | Targets, intake, exercise and mode-specific remaining values. |
| `recent_food_summary` | Cloud records summary builder | Windowed totals and coverage, not full rows by default. |
| `recent_workout_summary` | Cloud records summary builder | Frequency, duration, estimated kcal and major body-part pattern. |
| `body_metric_summary` | Cloud `body_metric_logs` summary builder | Weight, body-fat and waist availability by range. |
| `weight_trend_summary` | Cloud `body_metric_logs` summary builder | Only when enough data exists. |
| `strategy_context` | Profile strategy settings and deterministic calculators | Includes carb cycling/tapering state when relevant. |

Context builders must preserve deterministic calculations. LLM output cannot replace target or summary calculations. The model must not receive a generic SQL tool or direct database access; it only receives typed context objects generated by known builders. Local SQLite cache can accelerate UI but must not be treated as authoritative context.

## Chat History Models

`ai_chat_sessions`:

```json
{
  "id": "chat_...",
  "account_id": "acct_...",
  "title": "今天晚饭",
  "language": "zh",
  "created_at": "2026-06-17T00:00:00Z",
  "updated_at": "2026-06-17T00:00:00Z",
  "deleted_at": null
}
```

`ai_chat_messages`:

```json
{
  "id": "msg_...",
  "session_id": "chat_...",
  "account_id": "acct_...",
  "role": "user",
  "content_text": "今天还能吃什么？",
  "message_type": "text",
  "workflow_type": "meal_decision",
  "final_answer_json": null,
  "attachments_metadata": [],
  "created_at": "2026-06-17T00:00:00Z",
  "deleted_at": null
}
```

Rules:

- Chat history is cloud-stored after login.
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
  "created_at": "2026-06-17T00:00:00Z"
}
```

`ai_debug_summaries`:

```json
{
  "request_id": "req_...",
  "intent": "meal_decision",
  "intent_confidence": 0.86,
  "called_tools_json": ["get_cloud_profile", "get_today_summary"],
  "retrieved_dimensions_json": ["profile", "selected_day_summary"],
  "missing_dimensions_json": [],
  "safety_flags_json": [],
  "schema_validation_status": "passed",
  "user_final_action": "read_only"
}
```

Production logs should store compact metadata and sanitized summaries. They should not store chain-of-thought, unrestricted tool traces, full local SQLite payloads, or original images long-term by default.

## Attachment Policy

Locked policy:

- Original images are not stored long-term by default.
- Images are compressed on device before upload when possible.
- Upload transport uses Supabase Storage private temporary bucket, not direct long-term app storage.
- AI Gateway receives attachment references and resolves them server-side after auth and subscription checks.
- Attachment metadata can be stored with chat messages.
- Temporary images expire after 24 hours by default.
- Temporary images are deleted earlier when a draft is discarded, a session is deleted, or an account is deleted.
- Non-food or unclear images should trigger a clarification or refusal, not a forced food record.

Limits for V1:

- max 2 images per AI request
- target compressed image <= 1.5 MB
- hard reject any post-compression image > 5 MB
- preferred compressed format: JPEG unless transparency is needed
- recommended longest edge: 1600 px

The app stores only attachment metadata in chat history by default. Long-term original image libraries are out of scope for V1.

## Document RAG Contract

Document sources:

```text
README.md
docs/en/Product.md
docs/en/AppGuide.md
docs/en/Methodology.md
docs/en/Algorithm.md
docs/en/Database.md
docs/en/AgentDesign.md
docs/en/References.md
docs/zh/Product.md
docs/zh/AppGuide.md
docs/zh/Methodology.md
docs/zh/Algorithm.md
docs/zh/Database.md
docs/zh/AgentDesign.md
docs/zh/References.md
```

Document chunks should include:

```text
doc_path
language
heading
heading_level
section_id
content
updated_at
tags
```

Rules:

- Chinese query -> Chinese docs.
- English query -> English docs.
- Mixed language -> current App language or dominant query language.
- Answers return source document and section metadata.
- The answer must not claim planned V1 features are already implemented.

## Phase 0 Pass Checklist

| Requirement | Status |
| --- | --- |
| Backend scheme | Locked: Supabase Auth, Postgres, Storage, Edge Functions |
| Login method | Locked: FitLog email-password sign-in and registration email-code flow |
| Subscription scheme | Locked for development: internal entitlement table, seeded subscribed/unsubscribed accounts, and internal redeem codes |
| AI provider/model calling | Locked: user-selectable OpenAI/ChatGPT and Qwen through server-side AI Gateway adapters |
| Server-managed model API keys | Locked |
| AI Gateway endpoint shape | Drafted |
| Chat Session / Message model | Drafted |
| AI request log / debug summary model | Drafted |
| Cloud Profile fields | Drafted |
| Cloud Profile and local cache relationship | Locked |
| Cloud Records source of truth | Implemented foundation: active-device guard, Cloud Records migration, cloud-backed body/food/workout repositories, local SQLite partial cache |
| Records API shape | Implemented in Flutter repositories for body/food/workout; formal service API can still wrap the same contract |
| Daily summary API shape | Implemented in Phase 3 hardening: table created, app-side cloud upsert/recovery, confirmed local cache, warm cache, and eviction boundary landed |
| Cache eviction boundary | Locked: recent/current/pending pinned; older visited cache evictable |
| Offline Profile behavior | Locked |
| Image upload/compression/temporary retention | Locked: Supabase Storage temp bucket, 2 images/request, target <= 1.5 MB, hard reject > 5 MB, 24h TTL |
| Document RAG strategy | Locked |
| Structured RAG context objects | Locked |
| Error code categories | Drafted |
| V1 non-goals | Locked |

Phase 0 is complete for engineering entry into Phase 1. Production payment provider, API key creation steps, and exact OpenAI/Qwen model names remain later implementation choices, but they must preserve this contract.
