# Phase 4 Step 1 Engineering Plan: Data And Contract Foundation

This document is the execution plan for Step 1 of `PHASE4_GATEWAY_HANDOFF.md`.
It is a working engineering and acceptance plan, not a stable product source of
truth. Stable product claims should remain in `README.md`, `docs/en`, and
`docs/zh` only after the implemented state is ready to be documented.

## 1. Handoff Review

`PHASE4_GATEWAY_HANDOFF.md` is complete enough as a Phase 4 handoff plan:

- It defines the Phase 4 boundary.
- It splits the work into four reviewable steps.
- It gives every step an objective, scope, suggested files, automatic
  validation, manual acceptance, and blocking conditions.
- It has a final Phase 4 acceptance checklist.

Finishing the four steps only equals Phase 4 completion if every step passes
its automatic validation, manual acceptance, and "Do Not Proceed" gates, and
the final Phase 4 checklist passes. Mechanically creating the listed files is
not enough.

Step 1 by itself does not complete Phase 4. Step 1 only creates the cloud data
model and Flutter contract layer. The app must still be unable to send AI
messages after Step 1.

## 2. Step 1 Goal

Create the backend data model and Flutter contract layer for AI chat history
and AI Gateway payloads without enabling real chat sending.

Step 1 is successful when:

- Supabase has the four AI tables required for cloud chat history, request
  metadata, and compact debug summaries.
- Account isolation is represented in schema, indexes, and RLS.
- Client-readable chat history rows are protected by own-account RLS.
- Request logs and debug summaries are not exposed through client policies.
- Flutter has stable domain models and JSON mappers for Phase 4 text chat.
- Contract tests cover serialization, response parsing, and stable error
  mapping.
- No Flutter UI send behavior is enabled.
- `dart format lib test`, `flutter analyze`, and `flutter test` pass.

Implemented artifacts for this Step 1 pass:

- Supabase migration:
  `supabase/migrations/202606290001_phase4_ai_chat_foundation.sql`.
- Flutter contract models:
  `lib/domain/models/ai_chat_session.dart`,
  `lib/domain/models/ai_chat_message.dart`,
  `lib/domain/models/ai_gateway_request.dart`,
  `lib/domain/models/ai_gateway_response.dart`, and
  `lib/domain/models/ai_gateway_error.dart`.
- Contract tests:
  `test/ai_gateway_contract_test.dart`.

## 3. Assumptions And Decisions

- Supabase `auth.users(id)` remains the account identity source.
- Database IDs should be UUIDs in Postgres. Flutter can keep them as `String`
  values to avoid UI coupling to database types.
- `account_id` must exist on all four tables and must reference
  `auth.users(id)`.
- `ai_chat_sessions` and `ai_chat_messages` are client-readable for the signed
  in account, subject to RLS.
- Chat writes are server-owned. Step 1 should not grant direct authenticated
  insert/update/delete access for messages because later send must pass the
  Gateway, subscription, and active-device checks.
- Session archive/delete semantics are soft-state fields. Archiving hides a
  session from the default active history list. Deleting marks the session as
  deleted without deleting unrelated rows or other accounts.
- Request logs and debug summaries are server-side operational records. Step 1
  should enable RLS but should not add authenticated client read policies for
  these tables.
- Message retrieval needs deterministic ordering. Use an explicit
  `message_sequence` field per session, and still keep `created_at` and `id` as
  stable secondary sort fields.
- Step 1 must not add local SQLite chat-history storage and must not bump
  `AppDatabase.dbVersion`.
- Step 1 must not add RAG context, image upload, Food Draft generation,
  official food/workout/body/Profile writes, user-supplied model API keys, or
  provider API keys in Flutter.
- Step 1 must not choose exact OpenAI/Qwen model names. Provider details are
  Step 4 work and should be verified from official provider docs/consoles then.

## 4. Deliverables

Backend/Supabase:

- Add one migration, likely
  `supabase/migrations/*_phase4_ai_chat.sql`.
- Create `ai_chat_sessions`.
- Create `ai_chat_messages`.
- Create `ai_request_logs`.
- Create `ai_debug_summaries`.
- Add indexes, constraints, RLS, and grants consistent with the access model.

Flutter:

- Add `lib/domain/models/ai_chat_session.dart`.
- Add `lib/domain/models/ai_chat_message.dart`.
- Add `lib/domain/models/ai_gateway_request.dart`.
- Add `lib/domain/models/ai_gateway_response.dart`.
- Add an `AiGatewayError` model or equivalent stable error enum/value object.
- Add `test/ai_gateway_contract_test.dart`.

Not delivered in Step 1:

- No `AiGatewayClient`.
- No Supabase Edge Function.
- No mock provider.
- No real provider adapter.
- No `AiPage` send enablement.
- No chat-history panel wiring.
- No local SQLite chat history.

## 5. Backend Schema Plan

### 5.1 Migration Style

Follow existing migration style:

- Keep migration SQL idempotent where practical.
- Use `create extension if not exists pgcrypto`.
- Use `gen_random_uuid()` for UUID primary keys.
- Use `timezone('utc', now())` for timestamps.
- Use explicit indexes.
- Use `alter table ... enable row level security`.
- Drop and recreate named policies before creating them.
- Keep grants narrow.

### 5.2 `ai_chat_sessions`

Purpose: one cloud chat session owned by one account.

Recommended columns:

| Column | Type | Rule |
| --- | --- | --- |
| `id` | `uuid` | Primary key, default `gen_random_uuid()` |
| `account_id` | `uuid` | Not null, default `auth.uid()`, references `auth.users(id)` |
| `title` | `text` | Not null, default `''` |
| `language` | `text` | Not null, default `zh` |
| `last_message_at` | `timestamptz` | Nullable |
| `archived_at` | `timestamptz` | Nullable soft archive marker |
| `deleted_at` | `timestamptz` | Nullable soft delete marker |
| `created_at` | `timestamptz` | Not null UTC default |
| `updated_at` | `timestamptz` | Not null UTC default |

Recommended constraints and indexes:

- `unique(id, account_id)` so child rows can enforce session/account match.
- Index `(account_id, updated_at desc)`.
- Index `(account_id, archived_at, deleted_at, updated_at desc)`.
- Do not hard-delete sessions in normal app workflows.

### 5.3 `ai_chat_messages`

Purpose: one persisted user or assistant text message in a session.

Recommended columns:

| Column | Type | Rule |
| --- | --- | --- |
| `id` | `uuid` | Primary key, default `gen_random_uuid()` |
| `session_id` | `uuid` | Not null, references `ai_chat_sessions(id)` |
| `account_id` | `uuid` | Not null, default `auth.uid()`, references `auth.users(id)` |
| `message_sequence` | `integer` | Not null, unique per session |
| `role` | `text` | Not null, check `user` or `assistant` |
| `content_text` | `text` | Not null |
| `message_type` | `text` | Not null, default `text`; Phase 4 accepts text only |
| `workflow_type` | `text` | Not null, default `auto` |
| `model_choice` | `text` | Nullable stable client choice, for example `chatgpt` or `qwen` |
| `model_provider` | `text` | Nullable server provider id, for example `openai` or `qwen` |
| `request_id` | `uuid` | Nullable link to `ai_request_logs(request_id)` |
| `final_answer_json` | `jsonb` | Nullable; must stay null for plain text Step 1 tests |
| `attachments_metadata` | `jsonb` | Not null default `[]`; must remain an empty array in Phase 4 text chat |
| `created_at` | `timestamptz` | Not null UTC default |
| `deleted_at` | `timestamptz` | Nullable soft delete marker |

Recommended constraints and indexes:

- Composite foreign key `(session_id, account_id)` references
  `ai_chat_sessions(id, account_id)`.
- `unique(session_id, message_sequence)`.
- Check `role in ('user', 'assistant')`.
- Check `message_type = 'text'` for Step 1 and Phase 4.
- Check `jsonb_typeof(attachments_metadata) = 'array'`.
- Index `(account_id, session_id, message_sequence)`.
- Index `(account_id, session_id, created_at, message_sequence, id)`.

### 5.4 `ai_request_logs`

Purpose: compact operational metadata for a Gateway request. This table is not
user-visible chat content.

Recommended columns:

| Column | Type | Rule |
| --- | --- | --- |
| `request_id` | `uuid` | Primary key, default `gen_random_uuid()` |
| `account_id` | `uuid` | Not null, references `auth.users(id)` |
| `session_id` | `uuid` | Nullable, references `ai_chat_sessions(id)` |
| `workflow_type` | `text` | Not null, default `auto` |
| `model_choice` | `text` | Nullable stable client choice |
| `model_provider` | `text` | Nullable server provider id |
| `model` | `text` | Nullable server model config value, never an API key |
| `prompt_version` | `text` | Nullable |
| `schema_version` | `text` | Nullable |
| `profile_version` | `text` | Nullable |
| `status` | `text` | Not null, for example `ok`, `error`, `blocked`, `timeout` |
| `error_code` | `text` | Nullable stable error code |
| `latency_ms` | `integer` | Nullable, non-negative |
| `token_estimate` | `integer` | Nullable, non-negative |
| `image_count` | `integer` | Not null default `0`; Step 1/Phase 4 text chat should keep it `0` |
| `created_at` | `timestamptz` | Not null UTC default |

Do not add columns that store provider secrets, auth tokens, raw provider
payloads, stack traces, chain-of-thought, unrestricted context dumps, original
images, or full local SQLite payloads.

Recommended indexes:

- `(account_id, created_at desc)`.
- `(session_id, created_at desc)`.
- `(status, error_code, created_at desc)`.

### 5.5 `ai_debug_summaries`

Purpose: sanitized compact debug summary linked to a request log.

Recommended columns:

| Column | Type | Rule |
| --- | --- | --- |
| `id` | `uuid` | Primary key, default `gen_random_uuid()` |
| `request_id` | `uuid` | Not null unique, references `ai_request_logs(request_id)` |
| `account_id` | `uuid` | Not null, references `auth.users(id)` |
| `session_id` | `uuid` | Nullable, references `ai_chat_sessions(id)` |
| `intent` | `text` | Nullable |
| `intent_confidence` | `numeric` | Nullable, ideally 0 to 1 |
| `called_tools_json` | `jsonb` | Not null default `[]` |
| `retrieved_dimensions_json` | `jsonb` | Not null default `[]` |
| `missing_dimensions_json` | `jsonb` | Not null default `[]` |
| `safety_flags_json` | `jsonb` | Not null default `[]` |
| `schema_validation_status` | `text` | Nullable |
| `user_final_action` | `text` | Nullable, for example `read_only` |
| `created_at` | `timestamptz` | Not null UTC default |

Recommended constraints and indexes:

- Check JSON columns are arrays.
- Check `intent_confidence` is null or between 0 and 1.
- Index `(account_id, created_at desc)`.
- Index `(request_id)`.

## 6. RLS And Grant Plan

All four tables must have RLS enabled.

Recommended client access:

| Table | Authenticated client access in Step 1 |
| --- | --- |
| `ai_chat_sessions` | `select` own non-deleted rows |
| `ai_chat_messages` | `select` own non-deleted rows whose session is not deleted |
| `ai_request_logs` | none |
| `ai_debug_summaries` | none |

Recommended policies:

- `ai_chat_sessions_select_own`: `auth.uid() = account_id` and
  `deleted_at is null`.
- `ai_chat_messages_select_own`: `auth.uid() = account_id`,
  `deleted_at is null`, and the parent session belongs to the same account and
  is not deleted.

Recommended grants:

- Grant `select` on `ai_chat_sessions` and `ai_chat_messages` to
  `authenticated`.
- Do not grant authenticated client privileges on `ai_request_logs` or
  `ai_debug_summaries`.
- Do not grant authenticated direct insert/update/delete privileges for chat
  messages in Step 1.

If Step 2 chooses an Edge Function with service-role database access, the
Gateway can write all four tables after it performs auth, subscription, and
active-device checks. If Step 2 chooses user-token database writes instead, it
must add narrowly scoped RPCs or policies then; do not open those writes in
Step 1.

## 7. Flutter Contract Plan

### 7.1 `AiChatSession`

Fields:

- `id`
- `accountId`
- `title`
- `language`
- `lastMessageAt`
- `archivedAt`
- `deletedAt`
- `createdAt`
- `updatedAt`

Mapper expectations:

- `fromMap` reads Supabase row shape.
- `toMap` writes only contract fields needed by tests.
- Date parsing tolerates nullable values.
- Deleted sessions can be represented, but normal list queries should filter
  them outside the model.

### 7.2 `AiChatMessage`

Fields:

- `id`
- `sessionId`
- `accountId`
- `messageSequence`
- `role`
- `contentText`
- `messageType`
- `workflowType`
- `modelChoice`
- `modelProvider`
- `requestId`
- `finalAnswerJson`
- `attachmentsMetadata`
- `createdAt`
- `deletedAt`

Mapper expectations:

- Role is represented with stable values `user` and `assistant`.
- Unknown role or message type maps to a safe contract error in tests rather
  than being silently treated as valid UI content.
- `attachmentsMetadata` defaults to an empty list and Step 1 tests keep it
  empty.
- `finalAnswerJson` remains nullable and Step 1 tests do not create Food Draft
  behavior.

### 7.3 `AiGatewayRequest`

Phase 4 Step 1 request contract should be text-only:

- `sessionId` nullable.
- `messageText` required and non-empty after trimming at the caller boundary.
- `language`, likely `zh` or `en`.
- `modelChoice`, stable values `chatgpt` or `qwen`.
- `workflowHint`, default `auto`.
- `selectedDate` optional.
- `profileVersion` optional.
- `deviceId` required once the real Gateway client exists.
- `client` metadata map with app version, platform, and timezone when
  available.

Do not require or populate attachments, RAG context objects, Food Draft fields,
or business-write commands in Step 1.

### 7.4 `AiGatewayResponse`

Fields:

- `sessionId`
- `assistantMessageId`
- `modelChoice`
- `modelProvider`
- `messageText`
- `messageLanguage`
- `workflow`
- `needsClarification`
- `clarificationQuestions`
- `debugSummaryId`
- `error`

Step 1 should parse a text response and stable error envelope only. If a
response contains a non-null draft or unsupported structured write payload,
tests should prove it is not exposed as a saveable official record.

### 7.5 `AiGatewayError`

Stable error codes to support now:

- `auth_required`
- `subscription_required`
- `device_replaced`
- `gateway_timeout`
- `provider_failure`
- `record_schema_mismatch`
- `network_failure`
- `unknown`

Mapper expectations:

- Unknown server codes map to `unknown` while preserving the raw code for
  logs/tests if useful.
- User-facing text is not provider-shaped and does not expose raw stack traces.
- `device_replaced` remains distinct from network and save failures.

## 8. Test Plan

Add `test/ai_gateway_contract_test.dart`.

Required tests:

- `AiChatSession.fromMap` parses a complete Supabase row.
- `AiChatSession.toMap` preserves archive/delete timestamp fields.
- `AiChatMessage.fromMap` parses user and assistant messages.
- `AiChatMessage` ordering helper, if added, sorts by
  `messageSequence`, then `createdAt`, then `id`.
- `AiGatewayRequest.toJson` emits a minimal text-only payload.
- `AiGatewayRequest.toJson` does not emit attachments, RAG context objects, or
  Food Draft commands in Step 1.
- `AiGatewayResponse.fromJson` parses a successful assistant text response.
- `AiGatewayResponse.fromJson` parses clarification questions without creating
  a Food Draft.
- `AiGatewayResponse.fromJson` parses stable error codes.
- Unknown error codes map to `unknown`.
- A non-null unsupported draft payload is not exposed as a saveable official
  record.

Optional SQL review tests can be added later if the project introduces a local
Supabase test harness. For Step 1, SQL must be manually accepted against the
configured Supabase project.

## 9. Implementation Sequence

1. Review current Phase 4 docs and existing migration style.
   - Verify: schema choices do not contradict `PHASE4_GATEWAY_HANDOFF.md`.

2. Write the Supabase migration.
   - Verify: SQL creates four tables, indexes, constraints, RLS, and grants.

3. Add Flutter domain models and mappers.
   - Verify: no UI or repository send path is introduced.

4. Add contract tests.
   - Verify: targeted `flutter test test/ai_gateway_contract_test.dart` passes
     during the inner loop.

5. Run full automatic validation.
   - Verify: `dart format lib test`, `flutter analyze`, and `flutter test`
     pass.

6. Prepare manual acceptance package.
   - Verify: include migration name, changed files, SQL checks, test accounts,
     and pass/fail notes.

7. Run manual Supabase acceptance.
   - Verify: all checks in Section 10 pass before Step 2 starts.

## 10. Manual Acceptance Plan

Manual acceptance is required because Step 1 includes Supabase schema and RLS
behavior that Flutter unit tests cannot prove.

Use a staging or development Supabase project. Do not run the first acceptance
pass against production.

### 10.1 Required Inputs

The reviewer needs:

- A Supabase project with the previous Phase 2 and Phase 3 migrations applied.
- Two real test users in Supabase Auth.
- Account UUID for user A: `<ACCOUNT_A_UUID>`.
- Account UUID for user B: `<ACCOUNT_B_UUID>`.
- The Step 1 migration applied to the project.
- Supabase SQL Editor access, or Supabase CLI access linked to the project.

### 10.2 Apply Migration

Preferred operation:

```bash
supabase db push
```

Acceptable alternative:

- Open Supabase Dashboard.
- Go to SQL Editor.
- Paste the Step 1 migration SQL.
- Run it once.
- Run it a second time if the migration is expected to be idempotent.

Pass criteria:

- Migration succeeds.
- A repeated run does not create duplicate policies or indexes.
- Existing Phase 2/Phase 3 tables and functions remain available.

### 10.3 Schema Presence Check

Run:

```sql
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'ai_chat_sessions',
    'ai_chat_messages',
    'ai_request_logs',
    'ai_debug_summaries'
  )
order by table_name;
```

Pass criteria:

- Exactly these four AI tables appear.

Run:

```sql
select table_name, column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name in (
    'ai_chat_sessions',
    'ai_chat_messages',
    'ai_request_logs',
    'ai_debug_summaries'
  )
order by table_name, ordinal_position;
```

Pass criteria:

- Every table has `account_id`.
- Sessions and messages have soft-delete fields.
- Messages have `role`, `content_text`, `message_type`, `message_sequence`,
  `created_at`, and `deleted_at`.
- Logs/debug tables do not contain columns for API keys, auth tokens, raw
  provider payloads, stack traces, chain-of-thought, original images, or full
  local SQLite dumps.

### 10.4 RLS And Policy Check

Run:

```sql
select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in (
    'ai_chat_sessions',
    'ai_chat_messages',
    'ai_request_logs',
    'ai_debug_summaries'
  )
order by tablename;
```

Pass criteria:

- `rowsecurity` is `true` for all four tables.

Run:

```sql
select tablename, policyname, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in (
    'ai_chat_sessions',
    'ai_chat_messages',
    'ai_request_logs',
    'ai_debug_summaries'
  )
order by tablename, policyname;
```

Pass criteria:

- Sessions have an own-account select policy.
- Messages have an own-account select policy and do not read messages from
  deleted parent sessions.
- Request logs and debug summaries have no authenticated client read policy.
- There is no broad `using (true)` policy.

### 10.5 Seed Test Rows

Run as an owner/service SQL context, replacing placeholders:

```sql
insert into public.ai_chat_sessions (
  id,
  account_id,
  title,
  language,
  created_at,
  updated_at
) values
  (
    '00000000-0000-4000-8000-0000000000a1',
    '<ACCOUNT_A_UUID>',
    'A dinner question',
    'zh',
    '2026-06-17T00:00:00Z',
    '2026-06-17T00:00:00Z'
  ),
  (
    '00000000-0000-4000-8000-0000000000b1',
    '<ACCOUNT_B_UUID>',
    'B training question',
    'zh',
    '2026-06-17T00:00:00Z',
    '2026-06-17T00:00:00Z'
  );

insert into public.ai_chat_messages (
  id,
  session_id,
  account_id,
  message_sequence,
  role,
  content_text,
  message_type,
  workflow_type,
  created_at
) values
  (
    '00000000-0000-4000-8000-0000000000a2',
    '00000000-0000-4000-8000-0000000000a1',
    '<ACCOUNT_A_UUID>',
    1,
    'user',
    '今天晚饭还能吃什么？',
    'text',
    'auto',
    '2026-06-17T00:00:01Z'
  ),
  (
    '00000000-0000-4000-8000-0000000000a3',
    '00000000-0000-4000-8000-0000000000a1',
    '<ACCOUNT_A_UUID>',
    2,
    'assistant',
    '可以优先选择瘦肉、鱼虾和蔬菜。',
    'text',
    'auto',
    '2026-06-17T00:00:01Z'
  ),
  (
    '00000000-0000-4000-8000-0000000000b2',
    '00000000-0000-4000-8000-0000000000b1',
    '<ACCOUNT_B_UUID>',
    1,
    'user',
    '今天练背可以吗？',
    'text',
    'auto',
    '2026-06-17T00:00:01Z'
  );
```

Pass criteria:

- All inserts succeed.
- A user and assistant message can exist in the same session.
- Equal `created_at` timestamps do not make ordering ambiguous because
  `message_sequence` exists.

### 10.6 Account Isolation Check

Run as simulated authenticated user A:

```sql
begin;
set local role authenticated;
set local request.jwt.claim.sub = '<ACCOUNT_A_UUID>';

select id, account_id, title
from public.ai_chat_sessions
order by updated_at desc, id;

select session_id, account_id, message_sequence, role, content_text
from public.ai_chat_messages
order by created_at, message_sequence, id;

commit;
```

Pass criteria:

- User A sees only A session rows.
- User A sees only A message rows.
- User A does not see B rows.

Run the same query as simulated user B:

```sql
begin;
set local role authenticated;
set local request.jwt.claim.sub = '<ACCOUNT_B_UUID>';

select id, account_id, title
from public.ai_chat_sessions
order by updated_at desc, id;

select session_id, account_id, message_sequence, role, content_text
from public.ai_chat_messages
order by created_at, message_sequence, id;

commit;
```

Pass criteria:

- User B sees only B session rows.
- User B sees only B message rows.
- User B does not see A rows.

If the SQL Editor cannot simulate `authenticated` role with JWT claims, use the
Supabase REST API with each user's JWT and the project anon key. The pass
criteria are the same.

### 10.7 Session/Message Account Mismatch Check

Run as owner/service SQL context:

```sql
insert into public.ai_chat_messages (
  session_id,
  account_id,
  message_sequence,
  role,
  content_text,
  message_type,
  workflow_type
) values (
  '00000000-0000-4000-8000-0000000000a1',
  '<ACCOUNT_B_UUID>',
  99,
  'user',
  'This row must not be accepted.',
  'text',
  'auto'
);
```

Pass criteria:

- Insert fails because a message cannot attach account B to account A's
  session.
- If this insert succeeds, Step 1 fails and the schema needs a composite
  session/account constraint.

### 10.8 Message Ordering Check

Run:

```sql
select role, content_text, message_sequence, created_at, id
from public.ai_chat_messages
where session_id = '00000000-0000-4000-8000-0000000000a1'
order by created_at, message_sequence, id;
```

Pass criteria:

- The user message with `message_sequence = 1` appears before the assistant
  message with `message_sequence = 2`.
- Re-running the query returns the same order.

### 10.9 Archive/Delete Semantics Check

Archive user A's session:

```sql
update public.ai_chat_sessions
set archived_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
where id = '00000000-0000-4000-8000-0000000000a1'
  and account_id = '<ACCOUNT_A_UUID>';

select count(*) as a_message_count
from public.ai_chat_messages
where session_id = '00000000-0000-4000-8000-0000000000a1';
```

Pass criteria:

- The session has `archived_at`.
- A's messages still exist.
- B's session and messages are unchanged.

Soft-delete user A's session:

```sql
update public.ai_chat_sessions
set deleted_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
where id = '00000000-0000-4000-8000-0000000000a1'
  and account_id = '<ACCOUNT_A_UUID>';
```

Then run as simulated user A:

```sql
begin;
set local role authenticated;
set local request.jwt.claim.sub = '<ACCOUNT_A_UUID>';

select id
from public.ai_chat_sessions
where id = '00000000-0000-4000-8000-0000000000a1';

select id
from public.ai_chat_messages
where session_id = '00000000-0000-4000-8000-0000000000a1';

commit;
```

Pass criteria:

- Deleted session is not visible through normal authenticated client reads.
- Messages under a deleted session are not visible through normal
  authenticated client reads.
- Rows are not hard-deleted from the database unless account deletion cascades.

### 10.10 Log And Debug Exposure Check

Create a safe request log and debug summary as owner/service SQL context:

```sql
insert into public.ai_request_logs (
  request_id,
  account_id,
  session_id,
  workflow_type,
  model_choice,
  model_provider,
  model,
  prompt_version,
  schema_version,
  profile_version,
  status,
  error_code,
  latency_ms,
  token_estimate,
  image_count
) values (
  '00000000-0000-4000-8000-0000000000d1',
  '<ACCOUNT_A_UUID>',
  '00000000-0000-4000-8000-0000000000a1',
  'auto',
  'chatgpt',
  'openai',
  'server-configured-model',
  'prompt_v1',
  'ai_chat_response.v1',
  'profile_1',
  'ok',
  null,
  1200,
  400,
  0
);

insert into public.ai_debug_summaries (
  request_id,
  account_id,
  session_id,
  intent,
  intent_confidence,
  called_tools_json,
  retrieved_dimensions_json,
  missing_dimensions_json,
  safety_flags_json,
  schema_validation_status,
  user_final_action
) values (
  '00000000-0000-4000-8000-0000000000d1',
  '<ACCOUNT_A_UUID>',
  '00000000-0000-4000-8000-0000000000a1',
  'ai_chat',
  0.8,
  '[]'::jsonb,
  '[]'::jsonb,
  '[]'::jsonb,
  '[]'::jsonb,
  'passed',
  'read_only'
);
```

Then run as simulated user A:

```sql
begin;
set local role authenticated;
set local request.jwt.claim.sub = '<ACCOUNT_A_UUID>';

select *
from public.ai_request_logs;

select *
from public.ai_debug_summaries;

commit;
```

Pass criteria:

- Authenticated client select is denied, or returns no rows because no client
  read policy exists.
- Logs/debug summaries are not available through ordinary client table reads.

Run:

```sql
select table_name, column_name
from information_schema.columns
where table_schema = 'public'
  and table_name in ('ai_request_logs', 'ai_debug_summaries')
  and (
    lower(column_name) like '%api_key%'
    or lower(column_name) like '%secret%'
    or lower(column_name) like '%auth_token%'
    or lower(column_name) like '%access_token%'
    or lower(column_name) like '%refresh_token%'
    or lower(column_name) like '%provider_token%'
    or lower(column_name) like '%raw%'
    or lower(column_name) like '%trace%'
    or lower(column_name) like '%stack%'
    or lower(column_name) like '%chain%'
    or lower(column_name) like '%cot%'
    or lower(column_name) like '%full_payload%'
  );
```

Pass criteria:

- Query returns zero rows. `token_estimate` is allowed because it is a compact
  usage estimate, not an auth/provider token.

### 10.11 Flutter Contract Acceptance

Run:

```bash
dart format lib test
flutter analyze
flutter test
```

Pass criteria:

- Formatting completes.
- Analysis reports no issues.
- All tests pass.
- `test/ai_gateway_contract_test.dart` covers success, error, and no-extra-scope
  cases.

Manual code review checks:

- `AiPage` send behavior is not wired to any Gateway path.
- No `AiGatewayClient` network client exists yet unless the Step 1 scope was
  explicitly changed.
- No provider API key or model secret appears in Flutter code or committed
  config.
- No local SQLite table or `AppDatabase.dbVersion` change was added for chat
  history.
- No tests or models expose Food Draft save behavior, image upload behavior, or
  RAG context as implemented.

Useful review searches:

```bash
rg -n "api_key|secret|OPENAI|QWEN|DASHSCOPE|provider trace|chain-of-thought" lib test supabase
rg -n "AiGatewayClient|ai/chat/route|canSend: true" lib/features/ai lib/data
rg -n "CREATE TABLE.*ai_chat|AppDatabase.dbVersion|ai_chat" lib/data/db lib
```

Pass criteria:

- No secrets are present.
- No AI send path is enabled from UI.
- No local SQLite chat-history table is introduced.

## 11. Step 1 Exit Criteria

Step 1 is complete only when all of these are true:

- The Supabase migration has been applied and manually accepted.
- RLS blocks cross-account chat reads.
- Request logs and debug summaries are not client-readable.
- A message cannot be attached to another account's session.
- Message ordering is deterministic.
- Archive/delete semantics preserve unrelated accounts and messages.
- Flutter contract tests cover request, response, message/session models, and
  stable errors.
- The app still cannot send AI messages.
- `dart format lib test` has run.
- `flutter analyze` passes.
- `flutter test` passes.

If any item fails, do not start Step 2.

## 12. Step 1 Handoff Summary Template

At the end of the Step 1 implementation chat, report:

- Files changed.
- Migration file name.
- Tables created.
- RLS/grant decisions.
- What was intentionally not implemented.
- Automatic validation commands and results.
- Manual Supabase acceptance results.
- Known risks or follow-up items.
- Whether Step 2 may start.
