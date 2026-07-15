# Database Design

## Purpose

This document defines FitLog_Agent V1 schema, migrations, tables, fields, and storage concepts. Cloud/local authority, cache-first reads, write-success rules, refresh, failures, conflicts, and repair rules are defined in `CloudLocalDataBoundary.md`.

FitLog uses local SQLite for compatibility state, deterministic local services, drafts, and partial confirmed read models; Supabase owns signed-in account data, official records, AI history/operations, and the document index. After login, official records are cloud-authoritative. RAG, export, and AI draft workflows use cloud official records, `daily_summaries`, or controlled summary builders rather than assuming local SQLite contains complete history.

## Storage Overview

| Storage | Purpose | Authority and lifecycle |
| --- | --- | --- |
| SQLite / `sqflite` | Local compatibility profile/cache, calibration, strategy review, custom exercises, workout drafts, account-bound confirmed read models, and selected-day `daily_summary_cache`. | Schema v16. Signed-in official records are not authoritative here; confirmed cache is rebuildable and bounded. |
| Supabase Cloud Records | `body_metric_logs`, `food_records`/`food_items`, `workout_sessions`/`workout_sets`, and `daily_summaries`. | Authoritative for signed-in official records; cloud-backed repositories coordinate writes and local read-model updates. |
| SharedPreferences | Language/theme and lightweight UI preferences, per-account record-summary permission, Cloud Profile/subscription display cache, registration PKCE verifier state, and tiny picker-recovery markers. | Device-local runtime/display state, not business-record synchronization. |
| Local files | XLSX and CSV ZIP exports in the app documents directory. | User-controlled derived files; not a cloud source of truth. |
| Cloud account and AI storage | Supabase Auth identity, subscription entitlement, Cloud Profile, AI chat sessions/messages, request logs, compact debug summaries, evidence/artifact snapshots, and document chunks. | Account-bound or service-owned cloud data protected by RLS/RPC/service boundaries. |
| AI document index | Versioned active-build stable documentation chunks and embeddings for Document RAG. | Supabase Postgres lexical/vector candidate retrieval with service-role-only staging, activation, search, and rollback. |
| In-memory providers | Selected date, refresh version, app services, language state, and runtime summaries. | Ephemeral runtime coordination only. |

Current local database name: `fitlog_local.db`.

Current local SQLite schema version: `16`.

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
| 14 | Re-runs the idempotent cloud-cache column migration so devices that installed an intermediate v13 build receive the missing columns without clearing local data. |
| 15 | Adds an idempotent `daily_summary_cache` repair for devices that installed an intermediate v14 build before the selected-day summary JSON cache columns, unique index, and cache-write downgrade were complete. |
| 16 | Deletes legacy `edit_record` workout drafts so only manually or AI-created new workout records remain resumable. |

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
| `total_weight_g` | Total estimated weight. For confirmed AI Food Drafts with item rows, the preview/save path derives this value from the item-weight sum. |
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
- `total_load` keeps `input_weight_kg` as the calculation load; `per_side_load` stores `calculation_load_kg = input_weight_kg * 2`.
- `bodyweight_added` and `assistance_load` preserve the entered external/assistance value; the calorie service combines it with the saved bodyweight snapshot instead of overwriting the raw field.
- `total_reps` keeps `input_reps` as the calculation count; `per_side_reps` stores `calculation_reps = input_reps * 2`.
- `duration_seconds` preserves `input_duration_seconds`; its bounded calculation equivalent is stored separately and does not change the displayed duration.

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

Purpose: one active unsaved new-workout editor state created manually or handed off from AI.

Important fields:

| Field | Meaning |
| --- | --- |
| `id` | Fixed active draft id. |
| `kind` | Current writes use `new_record`; legacy `edit_record` rows are removed by the v16 migration. |
| `source_plan_id`, `source_session_id` | Legacy nullable compatibility fields; current new-record drafts leave them empty. |
| `date`, `record_name`, `notes` | Draft-visible metadata. |
| `payload_json` | Serialized editor snapshot. |
| `created_at`, `updated_at` | ISO timestamps. |

Rules:

- Drafts do not feed Home totals.
- Drafts are not official workout history.
- Editing a saved workout is page-local and never writes this table.
- Explicit save validates editor state before writing official workout tables.
- Draft strength-set entries may include draft-only `completed_at` timestamps inside `payload_json` so the Android workout-in-progress notification can identify the most recently checked set. This does not change the `workout_sets` SQLite schema or the official saved-record migration version.

### `user_weight_logs`

Purpose: local compatibility/cache for daily body metric history. Cloud `body_metric_logs` is authoritative for signed-in accounts; new official signed-in records belong to the cloud account.

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

## Cloud Tables And Storage Boundaries

The following service-side storage concepts support Agent V1 account, subscription, Cloud Profile, Cloud Records, AI Chat, logging, and Document RAG behavior. The current schema is defined by Supabase migrations for account/profile foundations, internal entitlement testing, Cloud Records and active-device guards, AI chat/log/debug tables, chat operation RPCs, and the Document RAG index. This section describes durable table responsibilities rather than implementation order.

### `accounts`

Purpose: authenticated user identity.

Supabase Auth provides account identity rather than a custom public `accounts` table. Email/password credentials, sessions, and email verification belong to Supabase Auth. FitLog does not store passwords in `cloud_profiles`, and registration does not require a username.

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

This Supabase Postgres table is keyed by `account_id = auth.uid()`. Clients may read their own row through RLS. Client inserts/updates are denied; development entitlements and server-side acceptance setup are seeded or maintained with service-role tooling.

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

Supabase stores only hashed redemption codes. Clients cannot read or update this table. A signed-in client calls the `redeem_internal_subscription_code(input_code text)` RPC, which validates the hash, expiry, and redemption count, records one redemption per account/code pair, and upserts the account's `subscriptions` row. Entitlement writes stay server-side without placing service-role credentials in the app.

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

After sign-in succeeds, the client calls `claim_active_device` to bind the account's active device/session to the current device. Official body/food/workout writes, Cloud Profile saves, and AI Gateway requests call `assert_active_device` at the server/RPC boundary. Requests from older devices return the stable `device_replaced` code.

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

This Supabase Postgres table uses own-row select/insert/update RLS and algorithm-preserving field checks.

Projects that created `cloud_profiles` from the earlier SQL shape must also run `202606230002_cloud_profile_schema_compat.sql`; `create table if not exists` does not add columns to an existing table. Projects that only lack current body metric columns can run `202606230003_cloud_profile_body_metrics.sql` as a narrow patch.

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
- Current body metrics in Profile are saved in Cloud Profile. Historical weight, body-fat, and waist records use cloud `body_metric_logs`; the local history table is cache/compatibility only.
- Offline profile saves are disabled in V1.
- Account deletion deletes Cloud Profile.
- The mapper must preserve `diet_goal_phase`, `diet_calculation_mode`, and `diet_plan_strategy` as user-controlled algorithm fields; it must not convert between `energy_ratio` and `gram_per_kg`.

### `body_metric_logs`

Purpose: authoritative account-level historical body metric records.

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

- `DailySummaryService` builds deterministic summaries on demand from cloud-backed record repositories, recovers missing local summary cache from cloud `daily_summaries`, upserts rebuilt summaries, and persists selected-day confirmed summaries into local `daily_summary_cache` for Home stale-while-revalidate. AI and export must not depend on complete local SQLite.
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

- Account-bound RLS protects client reads.
- The server-side Gateway may create or reuse sessions only after auth, subscription, and active-device checks.
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

- Account-bound RLS protects client reads.
- The Gateway writes one user message and one assistant message per accepted turn. Accepted image Chat persists as text messages while up to three images are forwarded only in the current Gateway request.
- `final_answer_json` may store a lightweight `ai_chat_artifacts.v2` snapshot for validated artifacts such as `food_draft.v2` or `workout_draft.v2`, plus the resolved `target_date`, date-resolution source, `ai_chat_evidence.v1`, or an `evidence` object that summarizes retrieved context. Artifact snapshots rebuild Preview after review; evidence is read-only display/debug context. Neither is an official record or a background draft queue. The history reader retains compatibility with v1 artifacts by using their stored selected date when the legacy draft lacks its own date.
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
- `expected_output`
- `intent_resolution_source`
- `selected_output_type`
- `validation_issue_codes_json`
- `validator_version`
- `first_pass_validation_status`
- `correction_attempt_count`
- `final_validation_status`
- `provider_completion_status`
- `latency_breakdown_json`
- `created_at`

This table is a server-side operational record:

- The additive `202607100001_ai_output_contract_observability.sql` migration idempotently adds output-family, validator, first-pass/final validation, correction-count, and provider completion-category fields. It does not change SQLite `AppDatabase.dbVersion`.
- The additive `202607110001_ai_intent_output_observability.sql` migration permits `expected_output = auto` and adds `fixed_workflow` / `deterministic` / `model` resolution source, the final validated output type, and a privacy-safe issue-code array. It likewise does not change the SQLite schema version.
- Migration `202607110002_ai_observability_update_grants.sql` allows the Edge Function service role to finalize `ai_request_logs` and `ai_debug_summaries` after the initial RPC insert. Authenticated clients still have no direct read or write policy.
- The additive `202607150001_rag_latency_breakdown.sql` migration adds a bounded `ai_latency_breakdown.v1` object. It separates Edge runtime age, environment/auth/request/device checks, planning, context building, query normalization, embedding, hybrid RPC, reranking, rewrite planning, provider generation/validation/correction, and persistence. Missing or inapplicable stages remain `null` or `not_requested`; the object never stores raw messages, vectors, document excerpts, images, provider output, secrets, business records, or chain-of-thought.
- The additive `202607150002_ai_chat_turn_rag_workflows.sql` migration aligns the `record_ai_chat_turn` RPC validation with the table contract for `workout_logging`, `general_chat`, and `safety_boundary`; existing workflow values and the service-role-only execution boundary remain intact.
- Chat uses `prompt_version = phase5_rag_readonly_v1` and `schema_version = ai_chat_response.v2`; Add Food uses `workflow_type = food_logging` and `schema_version = food_draft.v2`. Additive workflow constraints preserve legacy values and also accept server-planned `workout_logging`, `general_chat`, and `safety_boundary`.
- Text/image paths store compact output-contract states, never raw provider output, correction payloads, image bytes/base64, provider secrets, or unrestricted notes.
- `selected_output_type` is written only after provider output passes contract validation. Issue codes are fixed categories and contain no field values, user prompt, or provider text.
- Authenticated clients have no direct read policy.

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

- This server-side operational table stores compact Gateway summaries. Additive observability fields cover surface/capability/provider-policy versions, Task Plan source and approved/rejected context types, reviewed canonical concept IDs, corpus/build/embedding/reranker versions, branch counts, coverage/retry/issues, bounded latency/context-size metrics, grounding/language/Food semantic status, fact/conflict counts, and final action. Add Food also stores input kind, selected date, note presence, image count, and optional mime type/compressed byte length. Authenticated clients have no direct read policy.
- These fields never duplicate the complete question, custom-exercise names, raw Context/history rows, original images/base64, provider-invalid output, secrets, or chain-of-thought.
- JSON fields are compact arrays, not unrestricted traces.
- Production stores compact sanitized summaries.
- User-facing UI shows final messages and draft cards, not debug traces.

### `document_chunks`

Purpose: Document RAG over app docs.

Fields:

- `id`
- `language`
- `doc_path`
- `heading`
- `heading_level`
- `heading_path`
- `section_id`
- `chunk_index`
- `chunk_count`
- `content`
- `context_prefix`
- `context_note`
- `tags`
- `status`
- `authority`
- `corpus_id`
- `build_id`
- `source_hash`
- `chunk_hash`
- `content_hash`
- `manifest_hash`
- `generator_version`
- `term_version`
- `search_tokens`
- `search_tsv` (stored generated `tsvector`)
- `embedding`
- `embedding_model`
- `embedding_dimension`
- `embedding_input_hash`
- `embedding_normalization_version`
- `embedding_generated_at`
- `source_updated_at`
- `created_at`
- `updated_at`

Allowed sources:

- the explicit stable bilingual source allowlist maintained by the Document RAG ingestion tool
- root `README.md`

Rules:

- Migration `202607080001_phase5_document_rag_index.sql` creates the legacy-compatible base table; additive migration `202607130001_rag_foundation_document_hybrid.sql` adds versioned corpus-build and 1536-dimension embedding metadata without deleting lexical rows. Migration `202607150003_rag_hybrid_indexed_candidates.sql` adds generated `search_tsv`, its GIN index, and bounded indexed-candidate retrieval. Migration `202607150004_rag_parallel_candidate_fusion.sql` adds the lexical-candidate and final v3 fusion RPCs without replacing the compatibility functions.
- `document_corpus_builds` stores staging/active/superseded build state, expected source/chunk counts, manifest/generator/term versions, and optional embedding model/dimension. One partial build never becomes visible as a mixture with the previous active build.
- Legacy `search_document_chunks`, foundation `search_document_chunks_hybrid`, and bounded v2 remain available for compatibility and fail-closed rollback. Production uses service-role-only `search_document_chunk_lexical_candidates_v1` to obtain indexed term/FTS/trigram candidate IDs while query embedding runs, then `search_document_chunks_hybrid_v3` applies the active-corpus, language, authority and status filters, computes global lexical/vector ranks, and returns at most 30 fused candidates for Edge reranking. Staging and activation RPCs validate source/chunk parity; embedding-required activation also validates vector count.
- `supabase/seed_phase5_document_chunks.sql` and the reviewable corpus-build JSON are generated from the canonical manifest by `tool/phase5_document_rag/build_document_chunks.mjs`. Qwen `text-embedding-v4` build/sync/verify is idempotent, uses 1536 dimensions, and checks content, chunker, terms, model, dimension, and input hash before cloud activation.
- Authenticated clients do not read or write this table directly. It is for documents, not user business data.
- Only Document RAG requires a dedicated persistent index. Structured RAG reuses Cloud Profile, Cloud Records, and summary tables through `ai-chat-route` context builders.
- `build_exercise_history_summary` is a service-role-only bounded aggregate over official workout sessions/sets. It filters a verified account, at most four exercise keys, a bounded date range and session limit, and never returns notes or complete set rows.

The exact source allowlist, chunking, contextual metadata, status semantics, retrieval behavior, seed-refresh lifecycle, privacy boundary, and RAG evaluation rules live in [RAGDesign.md](RAGDesign.md). Database owns only the persisted schema and RPC data flow.

## Structured RAG Storage Boundary

Structured RAG has no separate `structured_rag` SQL table. It builds bounded runtime objects over Cloud Profile, Cloud Records, and `daily_summaries`; service-role grants provide required reads and compact debug-summary update access. Flutter cannot upload its own context-object payload. Object schemas, permission behavior, missing dimensions, sanitization, and evidence are defined in [RAGDesign.md](RAGDesign.md).

## Source Of Truth Summary

The complete authority boundary for Cloud Profile, Cloud Records, daily summaries, and local cache lives in `CloudLocalDataBoundary.md`. Database records where the data is stored and what each field means. Summary rules:

| Data | V1 source of truth |
| --- | --- |
| Account identity | Cloud |
| Active device | Cloud |
| Subscription | Cloud |
| Cloud Profile | Cloud |
| Body metric logs | Cloud; local SQLite cache only |
| Food records | Cloud; local SQLite cache only |
| Workout records | Cloud; local SQLite cache only |
| Daily summaries | Cloud summary table/service |
| AI chat history | Cloud after login |
| AI request logs | Cloud/service logs |
| Document RAG index | Cloud `document_chunks`; generated seed from stable docs |
| Export files | Local user-controlled files |

Cache capacity, eviction eligibility, cache-first reads, `auth_required` handling, and repair policy live in `CloudLocalDataBoundary.md`.

## Offline Rules

- AI page enters disabled gray state while offline.
- User may edit unfinished prompt text but cannot send.
- Profile page may display cached profile but cannot save.
- V1 does not allow pending offline profile edits.
- Official food/workout/body writes require cloud access; offline official-write queues are outside the current boundary, with handling defined in `CloudLocalDataBoundary.md`.

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

Export correctness comes from cloud official records, cloud summaries, or builders; local cache may accelerate reads but must not be required to be complete. The export builder fetches cloud-backed food, workout, and body metric records before building XLSX/CSV tables and includes a Body Metrics table. Details live in `CloudLocalDataBoundary.md`. Cloud AI chat history and request logs are not part of record export unless a separately designed account-data export adds them.

## Storage Non-goals

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
- AI chat and AI food analysis contract models: `lib/domain/models/ai_chat_session.dart`, `lib/domain/models/ai_chat_message.dart`, `lib/domain/models/ai_gateway_request.dart`, `lib/domain/models/ai_gateway_response.dart`, `lib/domain/models/ai_gateway_evidence.dart`, `lib/domain/models/ai_gateway_error.dart`, `lib/domain/models/ai_food_photo_analysis.dart`, `lib/domain/models/ai_workout_draft.dart`
- Supabase AI schema: `supabase/migrations/202606290001_phase4_ai_chat_foundation.sql`, `supabase/migrations/202606290002_phase4_step2_gateway_mock.sql`, `supabase/migrations/202606300001_phase4_step3_4_chat_ops_real_providers.sql`, `supabase/migrations/202607010001_phase4_step5_chat_session_rename.sql`, `supabase/migrations/202607080001_phase5_document_rag_index.sql`, `supabase/migrations/202607090001_phase5_structured_rag_service_role_grants.sql`, `supabase/migrations/202607100001_ai_output_contract_observability.sql`, `supabase/migrations/202607130001_rag_foundation_document_hybrid.sql`, `supabase/migrations/202607130002_rag_foundation_exercise_history.sql`, `supabase/migrations/202607130003_rag_foundation_observability.sql`, `supabase/migrations/202607150001_rag_latency_breakdown.sql`, `supabase/migrations/202607150002_ai_chat_turn_rag_workflows.sql`, `supabase/migrations/202607150003_rag_hybrid_indexed_candidates.sql`, `supabase/migrations/202607150004_rag_parallel_candidate_fusion.sql`
- Supabase AI Gateway: `supabase/functions/_shared/ai_output_contract.ts`, `supabase/functions/ai-chat-route/index.ts`, `supabase/functions/ai-chat-route/openai_provider.ts`, `supabase/functions/ai-chat-route/qwen_provider.ts`, `supabase/functions/ai-chat-route/workflow_router.ts`, `supabase/functions/ai-chat-route/context_builders.ts`, `supabase/functions/ai-chat-route/document_rag.ts`, `supabase/functions/ai-chat-route/prompt_builder.ts`, `supabase/functions/ai-food-photo-analyze/index.ts`
- Document RAG seed tooling: `tool/phase5_document_rag/build_document_chunks.mjs`, `supabase/seed_phase5_document_chunks.sql`
- AI chat and AI food analysis repository/client: `lib/data/repositories/ai_chat_repository.dart`, `lib/data/remote/ai_gateway_client.dart`, `lib/data/remote/ai_food_photo_analysis_client.dart`
- Export: `lib/export/xlsx_export_service.dart`, `lib/export/csv_export_service.dart`
