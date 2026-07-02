# Database Design

## Purpose

This document defines FitLog_Agent V1 schema, migrations, tables, fields, and storage concepts. Cloud/local authority, cache-first reads, write-success rules, refresh, failures, conflicts, and repair rules are defined in `CloudLocalDataBoundary.md`.

The copied source uses the FitLog Local SQLite schema for business records. Phase 2 adds Supabase-backed account, subscription-status, and Cloud Profile foundations. Phase 3 Cloud Records Foundation has landed the root auth gate, single active device, Cloud Records tables, active-device write guards for body/food/workout cloud writes, account-bound local cache metadata, cloud-backed body/food/workout repositories, selected-day daily-summary local cache for Home stale-while-revalidate, app-side `daily_summaries` cloud upsert/recovery, bounded recent-summary warm cache, and confirmed-cache eviction. Phase 4 Step 1 adds the Supabase AI chat-history/request-log/debug-summary tables and Flutter AI Gateway contract models. Phase 4 Steps 2-4 add the `ai-chat-route` Gateway, service-owned chat-turn/session RPCs, OpenAI/Qwen text provider metadata, AI-page sending, and cloud history UI. After login, official records are cloud-authoritative; local SQLite is reduced to partial cache, draft storage, and runtime acceleration. Later RAG and Food Draft workflows should use cloud official records or summary builders rather than complete local SQLite.

## Storage Overview

| Storage | Purpose | Current status |
| --- | --- | --- |
| SQLite / `sqflite` | Local profile/cache, calibration, strategy review, custom exercises, workout drafts, account-bound confirmed read models, selected-day `daily_summary_cache`, and partial cache. | Implemented from Local baseline; Phase 3 schema v15 carries cloud/cache metadata and selected-day summary cache. |
| Supabase Cloud Records | `body_metric_logs`, `food_records`/`food_items`, `workout_sessions`/`workout_sets`, `daily_summaries`. | Phase 3 migration added; body/food/workout reads and writes plus daily-summary upsert/recovery are wired through cloud-backed repositories. |
| SharedPreferences | UI language preference, local theme preference, lightweight app preferences, per-account user-record summary permission, Cloud Profile display cache, Supabase registration-code PKCE verifier state, and a tiny pending AI food analysis picker-recovery marker. | Implemented from Local baseline and Phase 2 account work; auth verifier, theme key, and picker recovery are local runtime/display state, not business record sync. |
| Local files | XLSX and CSV ZIP exports in the app documents directory. | Implemented from Local baseline. |
| Cloud database | Supabase Auth account identity, subscription entitlement rows, Cloud Profile, AI chat sessions/messages, AI request logs, and compact debug summaries. | Phase 2 migration adds `subscriptions` and `cloud_profiles`; Phase 4 Step 1 adds protected AI chat/log/debug tables; Phase 4 Steps 2-4 add the Gateway Edge Function, server-owned chat-turn/session RPCs, real text provider metadata, and app-side cloud history reads. |
| AI document index | Searchable app documentation chunks for Document RAG. | Planned for Agent V1. |
| In-memory providers | Selected date, refresh version, app services, language state, runtime summaries. | Implemented from Local baseline. |

Current local database name: `fitlog_local.db`.

Current local SQLite schema version: `15`.

Foreign keys are enabled with:

```sql
PRAGMA foreign_keys = ON
```

## Migration Policy

Local migrations must remain additive and compatible.

| Version | Change |
| ---: | --- |
| 1 | Initial profile, food, workout, and set tables. |
| 2 | Added `workout_sessions.plan_id`. |
| 3 | Added profile macro ratio fields: `protein_ratio_percent`, `carbs_ratio_percent`, `fat_ratio_percent`. |
| 4 | Added `user_weight_logs` and `calorie_calibration_state`. |
| 5 | Added `diet_calculation_mode`, `training_frequency_per_week`, and macro self-check fields. |
| 6 | Added `user_profile.diet_goal_phase TEXT NOT NULL DEFAULT 'cutting'`. |
| 7 | Added diet strategy profile fields and `diet_adjustment_reviews`. |
| 8 | Added `workout_sessions.record_name`. |
| 9 | Added local-only `user_profile.nickname`. |
| 10 | Added `workout_record_drafts`. |
| 11 | Added `custom_exercises`, exercise snapshots, cardio-intensity metadata, and raw-vs-calculation workout-set fields. |
| 12 | Added body fat and waist fields to `user_profile`, and account-scoped body metric fields to `user_weight_logs`. |
| 13 | Added cloud confirmed-read-model metadata to local food/workout/body caches: `account_id`, `cloud_id`, `record_version`, `cloud_updated_at`, `deleted_at`, `cache_confirmed`, `cached_at`, plus `daily_summary_cache`. |
| 14 | Re-runs the idempotent Phase 3 cache-column migration so devices that installed an intermediate v13 build still receive the cloud/cache columns without clearing local data. |
| 15 | Adds an idempotent `daily_summary_cache` repair for devices that installed an intermediate v14 build before the selected-day summary JSON cache columns, unique index, and cache-write downgrade were complete. |

Compatibility rules:

- Do not rewrite old migrations just because current schema changed.
- Prefer additive columns and tables.
- Preserve existing user data.
- Keep `daily_energy_goal_type` for compatibility.
- Treat `diet_goal_phase` as the cutting/bulking source of truth.
- Do not merge `energy_ratio` and `gram_per_kg` storage semantics.

## Local Tables

### `user_profile`

Purpose: singleton Local profile, diet settings, strategy settings, and self-check settings. Current repository uses `id = 1`.

Important fields:

| Field | Meaning |
| --- | --- |
| `id` | Singleton profile id. |
| `nickname` | Local-only UI nickname in the copied Local implementation. In Agent V1, account display name belongs to Cloud Profile. |
| `age` | BMR and under-18 protection. |
| `height_cm` | BMR input. |
| `weight_kg` | BMR, g/kg macro, workout calorie, and weight-log source. |
| `body_fat_percent` | Optional current body-fat percentage. Stored in Cloud Profile after login. |
| `waist_cm` | Optional current waist circumference. Stored in Cloud Profile after login. |
| `sex_for_formula` | `male`, `female`, or `prefer_not_to_say`. |
| `activity_level` | Compatibility/export tier derived from `training_frequency_per_week`. |
| `daily_energy_goal_type` | Compatibility field: `maintenance`, `deficit`, or `surplus`. |
| `daily_energy_goal_kcal` | Deficit or surplus amount depending on phase. |
| `protein_ratio_percent` | `energy_ratio` protein percentage. |
| `carbs_ratio_percent` | `energy_ratio` carb percentage. |
| `fat_ratio_percent` | `energy_ratio` fat percentage. |
| `diet_goal_phase` | `cutting` or `bulking`; phase source of truth. |
| `diet_calculation_mode` | `energy_ratio` or `gram_per_kg`. |
| `diet_plan_strategy` | `none`, `carb_cycling`, or `carb_tapering`. |
| `carb_cycle_pattern_json` | Weekly high/medium/low day mapping. |
| `carb_cycle_high_multiplier` | High-day carb multiplier. |
| `carb_cycle_medium_multiplier` | Medium-day carb multiplier. |
| `carb_cycle_low_multiplier` | Low-day carb multiplier. |
| `carb_taper_review_period_days` | 7/14/21/28 style review period. |
| `carb_taper_target_loss_pct_per_week` | Target weekly loss rate for taper review. |
| `carb_taper_step_g` | Carb adjustment step. |
| `carb_taper_current_delta_g` | Cumulative carb offset relative to base carbs. |
| `last_carb_taper_review_at` | Last review date/timestamp. |
| `training_frequency_per_week` | Shared 2/3/4/5 setting for g/kg tables, `energy_ratio` fallback, and self-check. |
| `macro_self_check_period_days` | 7/14/21/28 self-check window. |
| `macro_self_check_enabled` | Boolean stored as 0/1. |
| `last_macro_self_check_at` | Self-check cooldown timestamp/date. |
| `created_at`, `updated_at` | ISO timestamps. |

Agent V1 note: after login, Cloud Profile becomes authoritative. The local `user_profile` table may remain as compatibility/cache/migration surface, but formal account-bound profile changes should be saved to cloud.

### `food_records`

Purpose: meal-level official food records.

Important fields:

| Field | Meaning |
| --- | --- |
| `id` | Local record id. |
| `date` | `yyyy-MM-dd`. |
| `meal_name` | Meal label. |
| `total_weight_g` | Total estimated weight. |
| `calories_kcal` | Meal kcal. |
| `protein_g` | Protein grams. |
| `carbs_g` | Carbohydrate grams. |
| `fat_g` | Fat grams. |
| `confidence` | Estimate confidence when available. |
| `estimation_notes` | Estimate or user notes. |
| `source` | `manual`, `ai_paste`, and `ai_photo` for user-confirmed records that started as an Add Food AI food analysis draft. |
| `created_at`, `updated_at` | ISO timestamps. |

V1 boundary: official rows are written only after user confirmation. Add Food AI food analysis creates a draft from text and optional images and opens Food Preview; only the user's save writes the official row.

### `food_items`

Purpose: item rows inside a meal.

Important fields:

| Field | Meaning |
| --- | --- |
| `id` | Item id. |
| `food_record_id` | Parent `food_records.id`, cascade delete. |
| `name` | Food item name. |
| `estimated_weight_g` | Estimated item weight. |
| `calories_kcal` | Item kcal. |
| `protein_g` | Protein grams. |
| `carbs_g` | Carb grams. |
| `fat_g` | Fat grams. |
| `notes` | Optional item notes. |

### `workout_sessions`

Purpose: saved exercise sessions. A multi-exercise workout record is represented by multiple rows sharing `plan_id`.

Important fields:

| Field | Meaning |
| --- | --- |
| `id` | Session id. |
| `plan_id` | Group id for a workout record. |
| `record_name` | User-facing workout record name. |
| `date` | `yyyy-MM-dd`. |
| `body_part`, `secondary_body_part` | Exercise category metadata. |
| `exercise_name`, `exercise_key`, `exercise_source` | Saved exercise identity. |
| `exercise_type` | `strength` or `cardio`. |
| `duration_minutes` | Per-exercise duration. |
| `intensity` | Legacy compatibility intensity field. |
| `strength_profile` | Saved strength calorie profile. |
| `load_input_mode`, `reps_input_mode`, `set_metric_type` | Saved strength input semantics. |
| `cardio_met`, `cardio_intensity_basis`, `cardio_active_minutes` | Saved cardio calculation metadata. |
| `body_weight_kg_at_calculation` | Bodyweight used for calorie calculation. |
| `exercise_snapshot_json` | Snapshot of exercise metadata at save time. |
| `estimated_calories` | Saved net exercise kcal. |
| `notes` | User notes. |
| `created_at`, `updated_at` | ISO timestamps. |

Rules:

- `plan_id` is the grouping key.
- There is no separate parent workout-record table in the current schema.
- Editing a saved record replaces the full `plan_id` group transactionally.
- Home and summaries use persisted sessions and sets, not unsaved drafts.

### `workout_sets`

Purpose: strength set rows.

Important fields:

| Field | Meaning |
| --- | --- |
| `id` | Set id. |
| `workout_session_id` | Parent `workout_sessions.id`, cascade delete. |
| `set_number` | Saved set order. |
| `weight_kg`, `reps` | Compatibility normalized calculation fields. |
| `input_weight_kg`, `input_reps`, `input_duration_seconds` | Raw user input. |
| `calculation_load_kg`, `calculation_reps` | Normalized values used by calorie and volume logic. |
| `load_input_mode`, `reps_input_mode`, `set_metric_type` | Per-set input semantics. |
| `is_completed`, `completed_at` | Completion state. |

Rules:

- Completed strength sets are persisted.
- Unchecked sets are discarded before save.
- Saved sets are renumbered from `1..n`.
- Raw and normalized values are both stored to keep historical records explainable.

### `custom_exercises`

Purpose: reusable local exercise definitions.

Important fields:

| Field | Meaning |
| --- | --- |
| `exercise_key` | Stable local key. |
| `name` | User-facing name. |
| `exercise_type` | `strength` or `cardio`. |
| `body_part`, `secondary_body_part` | Category metadata. |
| `strength_structure`, `strength_profile` | Strength calculation metadata. |
| `load_input_mode`, `reps_input_mode`, `set_metric_type` | Default strength input semantics. |
| `default_cardio_intensity` | Default cardio intensity basis. |
| `is_hidden` | Hidden custom exercises remain valid for history/export but leave the active picker. |
| `created_at`, `updated_at` | ISO timestamps. |

### `workout_record_drafts`

Purpose: one active unsaved workout editor state.

Important fields:

| Field | Meaning |
| --- | --- |
| `id` | Fixed active draft id. |
| `kind` | `new_record` or `edit_record`. |
| `source_plan_id`, `source_session_id` | Saved-record origin when editing. |
| `date`, `record_name`, `notes` | Draft-visible metadata. |
| `payload_json` | Serialized editor snapshot. |
| `created_at`, `updated_at` | ISO timestamps. |

Rules:

- Drafts do not feed Home totals.
- Drafts are not official workout history.
- Explicit save validates editor state before writing official workout tables.

### `user_weight_logs`

Purpose: current local daily body metric history. After Phase 3, cloud `body_metric_logs` is the official source and local `user_weight_logs` should be compatibility/cache only; new official signed-in records belong to the cloud account.

Fields:

- `id`
- `account_id`
- `date`
- `weight_kg`
- `body_fat_percent`
- `waist_cm`
- `source`
- `deleted_at`
- `created_at`
- `updated_at`

Used by:

- dynamic calorie calibration
- carb-taper review
- weekly review summaries when available

Soft-deleted rows are excluded from normal reads. When a cloud `body_metric_logs` row is deleted, the matching `user_weight_logs` cache mirror is soft-deleted too so calibration and review services no longer consume that historical weight row.

### `calorie_calibration_state`

Purpose: singleton dynamic calorie calibration state.

Fields:

- `id`
- `lifestyle_factor`
- `confidence`
- `window_days`
- `valid_days`
- `last_calibrated_date`
- `created_at`
- `updated_at`

### `diet_adjustment_reviews`

Purpose: local carb-taper review history and user decision record.

Important fields:

- review date
- phase/mode/strategy at review time
- weight trend inputs
- food-log coverage
- training stability
- suggested action
- user decision
- before/after carb delta when applied

AI boundary: Weekly Review may explain these records, but it must not silently create or apply a diet adjustment review.

## Runtime Aggregates

`DailySummary` is not a table. It is assembled at runtime from:

- profile
- food records/items
- workout sessions/sets
- calibration state
- training-frequency self-check
- strategy calculations

Agent V1 should reuse cloud daily summaries or service-built summaries for Structured RAG instead of uploading raw table rows by default, and it should not treat local SQLite cache as authoritative context.

## Cloud Tables And Planned Tables

The following are service-side storage concepts for Agent V1. Phase 2 implements the Supabase `subscriptions` and `cloud_profiles` tables in `supabase/migrations/202606190001_phase2_account_profile.sql`, existing-project Cloud Profile compatibility in `supabase/migrations/202606230002_cloud_profile_schema_compat.sql`, body metric Cloud Profile compatibility in `supabase/migrations/202606230003_cloud_profile_body_metrics.sql`, and internal development redeem-code support in `supabase/migrations/202606230001_internal_subscription_codes.sql`. Phase 3 adds active-device RPCs, Cloud Records tables, RLS, soft delete, version/timestamp triggers, and the `daily_summaries` table in `supabase/migrations/202606260001_phase3_cloud_records.sql`. Phase 4 Step 1 adds AI chat/log/debug tables; Phase 4 Step 2 adds mock Gateway foundations; Phase 4 Steps 3/4 add `record_ai_chat_turn`, `archive_ai_chat_session`, `soft_delete_ai_chat_session`, service-role persistence for real text provider turns, and app-side cloud history reads.

### `accounts`

Purpose: authenticated user identity.

Phase 2 uses Supabase Auth for this layer rather than a custom public `accounts` table. Email and password credentials, sessions, and email verification state belong to Supabase Auth. FitLog does not store passwords in `cloud_profiles`, and it does not require a username for registration.

Fields:

- `id`
- auth provider id
- email or phone when available
- display name if present in auth metadata; FitLog nickname/display name is authoritative in Cloud Profile
- locale
- created/updated timestamps
- deletion status

### `subscriptions`

Purpose: user AI entitlement.

Phase 2 implements this as a Supabase Postgres table keyed by `account_id = auth.uid()`. Clients may read their own row through RLS. Client inserts/updates are denied; development entitlements and server-side acceptance setup are seeded or maintained with service-role tooling.

Fields:

- `id`
- `account_id`
- plan id
- status
- current period start/end
- provider customer/subscription ids
- created/updated timestamps

User-visible V1 product rule: subscription gating only, no visible per-message quota UI.

### `internal_subscription_codes`

Purpose: development-only internal redeem codes that activate AI entitlement for the currently signed-in account.

Phase 2 stores only hashed codes in Supabase. Clients cannot read or update this table. A signed-in client calls the `redeem_internal_subscription_code(input_code text)` RPC, which validates the hash, expiry and redemption count, records one redemption per account/code pair, and upserts the account's `subscriptions` row. This keeps entitlement writes server-side without placing Supabase service-role credentials in the app.

Fields:

- `id`
- label
- hashed code
- status
- plan id
- duration days
- max and used redemption counts
- optional expiry
- created/updated timestamps

### `internal_subscription_redemptions`

Purpose: audit which account redeemed which internal code.

Fields:

- `id`
- `code_id`
- `account_id`
- redeemed timestamp

### `account_active_devices`

Purpose: V1 single-active-device boundary. It records which app install/device/session has taken over the account so older devices cannot continue official writes. It is not a realtime online-presence table and is not a multi-device sync system.

Phase 3 implementation: after sign-in succeeds, the client calls the `claim_active_device` RPC to update the account's active device/session to the current device. Official body/food/workout records, Cloud Profile saves, and later AI Gateway requests call `assert_active_device` at the server/RPC boundary. Requests from older devices return the stable `device_replaced` error code.

Recommended fields:

- `account_id`
- `active_device_id`
- `active_session_id`
- platform
- app version
- claimed timestamp
- last seen timestamp
- replaced timestamp or diagnostic reason

Recommended RPCs:

- `claim_active_device(device_id text, session_id text, platform text, app_version text)`
- `assert_active_device(device_id text, session_id text)`
- optional `release_active_device(device_id text, session_id text)`

Rules:

- `account_id` must come from `auth.uid()` and must not trust a client-supplied account id.
- A newer login overwrites the older active device: last login wins.
- The older physical session may not disappear immediately from Supabase Auth tables; product correctness relies on the active-device write guard, not immediate deletion of the old session.
- `device_replaced` is not a network failure or ordinary upload failure; the client should clear local sign-in state and enter the re-login/takeover path.

### `cloud_profiles`

Purpose: authoritative account-bound profile.

Phase 2 implements this as a Supabase Postgres table with own-row select/insert/update RLS and algorithm-preserving field checks.

Projects that already created `cloud_profiles` from an earlier Phase 2 SQL file must also run `202606230002_cloud_profile_schema_compat.sql`; `create table if not exists` does not add columns to an existing table. Existing projects that only need the current body metric columns can run `202606230003_cloud_profile_body_metrics.sql` as a narrow patch.

Recommended fields mirror current profile concepts:

- `account_id`
- display name/nickname
- age
- height
- current weight
- current body-fat percentage
- current waist circumference
- sex option for formulas
- diet goal phase
- diet calculation mode
- daily energy goal kcal
- macro ratio percentages
- training frequency
- diet plan strategy
- carb-cycling pattern and multipliers
- carb-taper review settings and current delta
- self-check settings
- language preference if account-bound
- `profile_version`
- created/updated timestamps

Rules:

- Exists only after login/onboarding.
- Cloud Profile is authoritative.
- Device cache is display/cache only.
- Profile page edits are local drafts until Save Changes succeeds; cloud writes upsert one complete `cloud_profiles` snapshot and increment `profile_version`.
- Current body metrics in Profile are saved in Cloud Profile. Historical weight, body-fat, and waist records move to cloud `body_metric_logs` after Phase 3; the local history table is cache/compatibility only.
- Offline profile saves are disabled in V1.
- Account deletion deletes Cloud Profile.
- The mapper must preserve `diet_goal_phase`, `diet_calculation_mode`, and `diet_plan_strategy` as user-controlled algorithm fields; it must not convert between `energy_ratio` and `gram_per_kg`.

### `body_metric_logs`

Purpose: account-level historical body metric records and the official source after Phase 3.

Fields:

- `id`
- `account_id`
- `date`
- `weight_kg`
- `body_fat_percent`
- `waist_cm`
- `source`
- `record_version`
- `created_at`
- `updated_at`
- `deleted_at`

Rules:

- Each account should have at most one row per day, preferably `UNIQUE(account_id, date)`.
- Records include only weight, body-fat percentage, and waist circumference; they do not include age, height, or sex.
- Backfilling a past date must not silently update the current Cloud Profile.
- The Body Profile card provides the record entry; Body Trends is read-only.
- Deletes are soft deletes through `deleted_at`; normal app reads, Body Trends, summaries, calibration, and reviews exclude deleted rows.

### `food_records` / `food_items`

Purpose: account-level official food records.

Rules:

- Create, edit, and delete are immediate record-level actions, not Profile-style page drafts.
- Deletes set `deleted_at` by default, and summary builders exclude soft-deleted rows.
- `food_items` belong to `food_records`.

### `workout_records` / `workout_sessions` / `workout_sets`

Purpose: account-level official workout records.

Rules:

- `workout_records` represents one workout record container.
- `workout_sessions` and `workout_sets` belong to the parent record.
- Saved rows preserve exercise metadata, input modes, and calculation snapshots.
- Deletes are soft deletes by default and update summaries.

### `daily_summaries`

Purpose: lightweight summary entry for Home, AI context, review, export, and history views.

Fields should cover:

- `account_id`
- `date`
- kcal/protein/carbs/fat totals
- workout estimated kcal
- body metric availability
- mode-primary target/remaining snapshot
- coverage flags
- `updated_at`

Rules:

- Phase 3 creates the cloud `daily_summaries` table. The current app-side `DailySummaryService` builds deterministic summaries on demand from cloud-backed record repositories, recovers missing local summary cache from cloud `daily_summaries`, upserts rebuilt summaries to cloud, and persists selected-day confirmed summaries into local `daily_summary_cache` for Home stale-while-revalidate. AI/export must not depend on complete local SQLite.
- AI wrappers should prefer summaries or summary builders over scanning full raw records.

### `ai_chat_sessions`

Purpose: cloud chat history sidebar.

Fields:

- `id`
- `account_id`
- `title`
- `language`
- `last_message_at`
- `archived_at`
- `deleted_at`
- `created_at`
- `updated_at`

Rules:

- Phase 4 Step 1 creates the table with account-bound RLS for client reads.
- Phase 4 Steps 2-4 allow the server-side Gateway to create or reuse sessions only after auth, subscription, and active-device checks.
- The service-role grants are limited to server Gateway, entitlement maintenance, and acceptance use; ordinary authenticated clients still do not receive direct write access.
- Client reads exclude soft-deleted sessions.
- Direct client writes are not opened; Gateway writes are server-owned through the Edge Function and `record_ai_chat_turn` RPC.
- Inline rename uses `rename_ai_chat_session`, which checks `auth.uid()`, trims and length-limits the title, and only updates the current account's non-deleted session. Deleting uses `soft_delete_ai_chat_session` to mark `deleted_at` and should not remove unrelated messages or accounts. Archive state remains in the schema/RPC but is not exposed in the current UI because there is no recovery list.

### `ai_chat_messages`

Purpose: user and assistant messages.

Fields:

- `id`
- `session_id`
- `account_id`
- `message_sequence`
- `role`
- `content_text`
- `message_type`
- `workflow_type`
- `model_choice`
- `model_provider`
- `request_id`
- `final_answer_json`
- `attachments_metadata`
- `created_at`
- `deleted_at`

Rules:

- Phase 4 Step 1 creates the table with account-bound RLS for client reads.
- Phase 4 Steps 2-4 Gateway writes one user message and one assistant message per accepted text turn; Phase 4 Step 6 keeps accepted image chat persisted as text messages while up to three images are forwarded only through the Gateway request.
- `final_answer_json` may store a lightweight `ai_chat_artifacts.v1` snapshot for validated returned artifacts such as `food_draft.v1`. The snapshot is used to rebuild Preview pages after the user taps a review button; it is not an official record and is not a background draft queue.
- `role` is limited to `user` and `assistant`; `message_type` remains text-only for persisted chat history. Image bytes/base64 are not stored in `ai_chat_messages`.
- Message order is deterministic by `message_sequence`, with timestamps and ids available as stable secondary fields.
- A message must match its parent session's `account_id`.
- Messages are not stored long-term locally by default.
- Messages must not expose internal chain-of-thought or raw debug traces.

### `ai_request_logs`

Purpose: audit, reliability, subscription enforcement, cost tracking, and abuse prevention.

Fields:

- `request_id`
- `account_id`
- `session_id`
- `workflow_type`
- `model_choice`
- `model_provider`
- server-configured `model`
- `prompt_version`
- `schema_version`
- `profile_version`
- `status`
- `error_code`
- `latency_ms`
- `token_estimate`
- `image_count`
- `created_at`

Phase 4 Step 1 creates this table as a server-side operational record. Phase 4 chat writes Gateway success, blocked, timeout, provider failure, and error metadata from the server path, including sanitized provider/model metadata when available. Add Food AI food analysis writes `workflow_type = food_logging`, `model_choice = qwen`, `model_provider = qwen`, `schema_version = food_draft.v1`, and the accepted `image_count` for text-only requests (`0`) or up to three optional image requests. AI Chat image requests forward up to three images to Qwen through `ai-chat-route`, write the accepted `image_count`, and persist text plus validated artifact snapshots in chat history without storing original image bytes or base64 payloads. Authenticated clients do not receive direct table read policies. Production logs should prefer metadata and sanitized summaries over raw sensitive payloads.

### `ai_debug_summaries`

Purpose: compact operational trace.

Fields:

- `id`
- `request_id`
- `account_id`
- `session_id`
- `intent`
- `intent_confidence`
- `called_tools_json`
- `retrieved_dimensions_json`
- `missing_dimensions_json`
- `safety_flags_json`
- `schema_validation_status`
- `user_final_action`
- `created_at`

Rules:

- Phase 4 Step 1 creates this table as a server-side operational record. Chat writes compact Gateway summaries. Add Food AI food analysis writes compact `food_photo_analysis` summaries with input kind, selected date, note presence, image count, image mime type and compressed byte length when present, schema validation status, and safety/error flags only. Authenticated clients do not receive direct table read policies.
- JSON fields are compact arrays, not unrestricted traces.
- Production stores compact sanitized summaries.
- User-facing UI shows final messages and draft cards, not debug traces.

### `document_chunks`

Purpose: Document RAG over app docs.

Fields:

- `id`
- language
- source file
- section path
- content chunk
- stable reference id
- keyword/full-text index fields
- optional embedding vector if vector search is used
- updated timestamp

Allowed sources:

- `docs/en/*`
- `docs/zh/*`
- stable help snippets derived from design docs

This table/index is for documents, not user business data.

## Structured RAG Context Objects

Structured RAG should pass compact typed objects, not arbitrary database access.

Recommended context objects:

| Object | Source | Notes |
| --- | --- | --- |
| `profile_context` | Cloud Profile. | Authoritative profile comes from cloud after login. |
| `selected_day_summary` | Cloud `daily_summaries` or summary builder. | Food totals, workout totals, target context. |
| `recent_food_summary` | Cloud records summary builder. | Windowed totals and coverage, not full rows by default. |
| `recent_workout_summary` | Cloud records summary builder. | Frequency, duration, estimated kcal, major body-part pattern. |
| `body_metric_summary` | Cloud `body_metric_logs` summary builder. | Weight, body-fat, and waist availability. |
| `weight_trend_summary` | Cloud `body_metric_logs` summary builder. | Trend only when enough data exists. |
| `strategy_context` | Profile strategy settings and deterministic calculator output. | Includes `carb_cycling` or `carb_tapering` state when relevant. |

## Source Of Truth Summary

The complete authority boundary for Cloud Profile, Cloud Records, daily summaries, and local cache lives in `CloudLocalDataBoundary.md`. Database records where the data is stored and what each field means. Summary rules:

| Data | V1 source of truth |
| --- | --- |
| Account identity | Cloud |
| Active device | Cloud after Phase 3 |
| Subscription | Cloud |
| Cloud Profile | Cloud |
| Body metric logs | Cloud after Phase 3; local SQLite cache only |
| Food records | Cloud after Phase 3; local SQLite cache only |
| Workout records | Cloud after Phase 3; local SQLite cache only |
| Daily summaries | Cloud summary table/service after Phase 3 |
| AI chat history | Cloud after login |
| AI request logs | Cloud/service logs |
| Document RAG index | Cloud or bundled service index |
| Export files | Local user-controlled files |

Cache capacity, eviction eligibility, cache-first reads, `auth_required` handling, and repair policy live in `CloudLocalDataBoundary.md`.

## Offline Rules

- AI page enters disabled gray state while offline.
- User may edit unfinished prompt text but cannot send.
- Profile page may display cached profile but cannot save.
- V1 does not allow pending offline profile edits.
- After Phase 3, official food/workout/body writes require cloud access; offline official-write queues are outside the default Cloud Records Foundation scope, with handling defined in `CloudLocalDataBoundary.md`.

## Export Coverage

Export should continue to cover:

- food records
- food items
- workout sessions
- workout sets
- custom exercises
- daily summaries
- user profile fields
- strategy fields
- calibration metadata
- self-check fields
- diet adjustment review history

After Phase 3 hardening, export correctness comes from cloud official records, cloud summaries, or builders; local cache may accelerate reads but must not be required to be complete. The current export builder fetches cloud-backed food, workout, and body metric records before building XLSX/CSV tables and includes a Body Metrics table. Details live in `CloudLocalDataBoundary.md`. Cloud AI chat history and AI request logs are not part of the current record export unless a future privacy/export feature explicitly adds account-data export.

## Not Implemented In Current Source

- Document RAG index
- long-term image attachment storage
- long-lived draft queues or automatic Chat draft writeback to official records
- more than three Chat images or long-term image attachment storage
- user-data vector database

## Code References

- Database: `lib/data/db/app_database.dart`
- Repositories: `lib/data/repositories/*`
- Profile: `lib/domain/models/user_profile.dart`, `lib/data/repositories/profile_repository.dart`
- Food: `lib/domain/models/food_record.dart`, `lib/data/repositories/food_repository.dart`
- Workout: `lib/domain/models/workout_session.dart`, `lib/domain/models/workout_set.dart`, `lib/data/repositories/workout_repository.dart`
- Custom exercises: `lib/data/repositories/custom_exercise_repository.dart`
- Daily summaries: `lib/domain/services/daily_summary_service.dart`
- AI chat and AI food analysis contract models: `lib/domain/models/ai_chat_session.dart`, `lib/domain/models/ai_chat_message.dart`, `lib/domain/models/ai_gateway_request.dart`, `lib/domain/models/ai_gateway_response.dart`, `lib/domain/models/ai_gateway_error.dart`, `lib/domain/models/ai_food_photo_analysis.dart`, `lib/domain/models/ai_workout_draft.dart`
- Supabase AI schema: `supabase/migrations/202606290001_phase4_ai_chat_foundation.sql`, `supabase/migrations/202606290002_phase4_step2_gateway_mock.sql`, `supabase/migrations/202606300001_phase4_step3_4_chat_ops_real_providers.sql`, `supabase/migrations/202607010001_phase4_step5_chat_session_rename.sql`
- Supabase AI Gateway: `supabase/functions/ai-chat-route/index.ts`, `supabase/functions/ai-chat-route/openai_provider.ts`, `supabase/functions/ai-chat-route/qwen_provider.ts`, `supabase/functions/ai-food-photo-analyze/index.ts`
- AI chat and AI food analysis repository/client: `lib/data/repositories/ai_chat_repository.dart`, `lib/data/remote/ai_gateway_client.dart`, `lib/data/remote/ai_food_photo_analysis_client.dart`
- Export: `lib/export/xlsx_export_service.dart`, `lib/export/csv_export_service.dart`
