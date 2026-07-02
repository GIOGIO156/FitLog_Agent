# Phase 4 Steps 3 And 4 Engineering Plan: Flutter Chat Integration And Real Providers

This document is the execution plan for the combined Step 3 and Step 4 work in
`PHASE4_GATEWAY_HANDOFF.md`. It is a working engineering and acceptance plan,
not a stable product source of truth. Stable product claims should remain in
`README.md`, `docs/en`, and `docs/zh` only after the implemented state is ready
to be documented.

Steps 3 and 4 are intentionally planned together here. The implementation can
still use internal checkpoints, but the combined work is not complete until the
Flutter AI page can send text messages, cloud chat history works in the app,
and both server-side real provider adapters pass automatic and manual
acceptance.

## 1. Handoff Review

Step 1 and Step 2 have already created the Phase 4 base:

- Supabase AI chat tables:
  - `ai_chat_sessions`
  - `ai_chat_messages`
  - `ai_request_logs`
  - `ai_debug_summaries`
- Flutter contract models:
  - `AiChatSession`
  - `AiChatMessage`
  - `AiGatewayRequest`
  - `AiGatewayResponse`
  - `AiGatewayError`
- Mock Gateway server path:
  - `supabase/functions/ai-chat-route/index.ts`
  - `supabase/functions/ai-chat-route/contracts.ts`
  - `supabase/functions/ai-chat-route/mock_provider.ts`
  - `record_ai_mock_chat_turn`
- Step 2 checks already prove server-side auth, subscription, active-device,
  mock persistence, request logs, and compact debug summaries at the API layer.

The current Flutter AI page is still a shell:

- The composer is editable.
- The provider selector is visual.
- The history button opens a placeholder panel.
- `AccountController.aiAvailability.canSend` still returns `false` even when
  account, subscription, and Cloud Profile are ready.
- The send button callback is not wired to a Gateway client.

The combined Step 3 and Step 4 work should close Phase 4, but must not leak
future phases into the implementation.

## 2. Combined Goal

Ship text-only AI Chat through the server Gateway with cloud chat history and
server-side OpenAI/ChatGPT plus Qwen provider adapters.

The combined work is successful when:

- A signed-in, subscribed, active-device account can send a text message from
  the Flutter AI page.
- The Flutter UI shows a runtime pending user message immediately.
- The server stores canonical user and assistant messages in cloud chat history.
- The app refreshes the selected session from cloud after successful send.
- The history panel lists cloud sessions for the current account.
- The user can start a new session, switch sessions, archive a session, and
  soft-delete a session.
- Restarting the app and reopening AI history loads the cloud session and
  messages.
- The ChatGPT selector value routes to a server-side OpenAI/ChatGPT adapter.
- The Qwen selector value routes to a server-side Qwen adapter.
- Provider keys and exact model names are server-side secrets/config only.
- Provider responses are normalized into the existing `AiGatewayResponse`
  contract.
- Provider timeouts, invalid responses, and provider failures map to stable
  `AiGatewayError` codes.
- Request logs and debug summaries remain compact and sanitized.
- Subscription and active-device checks are still enforced by the server.
- No RAG, image upload, Food Draft, official business write, user-supplied
  provider key, local long-term chat storage, or `AppDatabase.dbVersion` bump is
  introduced.
- README, CHANGELOG, and bilingual stable docs are updated only after code and
  manual acceptance pass.
- `dart format lib test`, `flutter analyze`, `flutter test`, backend
  formatting/lint/tests, and the configured debug split APK build pass or have
  a documented environment/config blocker.

## 3. Assumptions, Decisions, And Risks

### 3.1 Combined Step Strategy

The work should be implemented as one combined delivery, with two internal
checkpoints:

1. Flutter integration against the existing Step 2 mock Gateway.
2. Real provider adapters and Phase 4 closure.

Do not update stable docs to say Phase 4 is shipped after checkpoint 1. The
combined plan only exits after checkpoint 2 and final manual acceptance pass.

### 3.2 Provider Details

Exact provider endpoints, request shapes, model IDs, and console setup are
time-sensitive. During implementation, verify the current official OpenAI and
Qwen provider documentation/consoles before choosing exact model values or
adapter payloads.

This plan deliberately defines only FitLog-owned stable choices:

- Flutter sends `model_choice = chatgpt` or `model_choice = qwen`.
- The server maps those choices to provider adapters.
- The server records normalized provider IDs such as `openai` and `qwen`.
- Exact model names are read from server-side environment/secrets.

### 3.3 Secrets

Required existing Supabase Function secrets:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

Recommended new server-side secret/config names:

- `FITLOG_OPENAI_API_KEY`
- `FITLOG_OPENAI_MODEL`
- `FITLOG_QWEN_API_KEY`
- `FITLOG_QWEN_MODEL`
- `FITLOG_QWEN_BASE_URL`, only if the selected Qwen SDK/API path needs it
- Optional provider timeout config, for example `FITLOG_AI_PROVIDER_TIMEOUT_MS`

Rules:

- Provider API keys must never enter Flutter code.
- Provider API keys must never enter committed config, request logs, debug
  summaries, test fixtures, manual acceptance notes, or user UI.
- If a deployed Step 4 function lacks required provider secrets, it should
  return a stable provider error. It must not silently fall back to the mock
  provider for real users.
- Mock provider code may remain for automated tests and local manual debugging,
  but production routing for `chatgpt` and `qwen` must use real adapters once
  Step 4 is accepted.

### 3.4 Persistence Generalization

The Step 2 RPC `record_ai_mock_chat_turn` hard-codes mock provider metadata.
Step 4 should not keep using it for real provider success writes.

Preferred additive migration:

- Add `record_ai_chat_turn` for real provider and shared successful-turn
  persistence.
- Keep `record_ai_mock_chat_turn` for Step 2 compatibility and backend tests.
- Add narrowly scoped session operation RPCs for archive/delete instead of
  granting broad direct client updates.

The new successful-turn RPC should accept provider metadata as inputs and store
only safe values:

- `input_model_provider`
- `input_model`
- `input_prompt_version`
- `input_schema_version`
- `input_assistant_text`

It must still:

- Verify an existing session belongs to `input_account_id`.
- Reject deleted sessions.
- Lock the session row before assigning sequences.
- Insert exactly one user message and one assistant message per success.
- Keep `message_type = text`.
- Keep `attachments_metadata = []`.
- Keep `final_answer_json = null`.
- Return at least:
  - `session_id`
  - `request_id`
  - `user_message_id`
  - `assistant_message_id`
  - `debug_summary_id`
  - user and assistant message sequences

### 3.5 Session Archive/Delete

Step 1 only grants authenticated clients `select` on chat sessions/messages.
Archive/delete should therefore be implemented with explicit RPCs or equivalent
server functions:

- `archive_ai_chat_session(input_session_id uuid, input_archived boolean)`
- `soft_delete_ai_chat_session(input_session_id uuid)`

Rules:

- The RPCs must use the authenticated account identity, not a client-supplied
  account id.
- Cross-account session ids must not update rows.
- Archive sets or clears `archived_at`; delete sets `deleted_at`.
- Delete is soft-delete only.
- Messages remain stored but hidden through existing RLS/default app queries.
- Do not add hard delete from the app in this phase.

### 3.6 Retry And Duplicate Sends

Do not introduce automatic retry that can duplicate persisted messages.

Default Step 3 behavior:

- On send, show a runtime-only pending user message.
- On success, clear pending state and reload canonical session messages from
  cloud.
- On network/ambiguous failure, refresh the selected session before showing a
  retry action.
- Only offer retry if the canonical history does not already show the sent
  turn.
- If the ambiguity cannot be resolved, keep the draft and show a safe error;
  the user may resend manually after reviewing history.

Do not add an idempotency-key schema unless implementation proves this default
flow cannot meet acceptance. If an idempotency key becomes necessary, add it as
an explicit migration and tests, not as an undocumented request field.

### 3.7 Local Storage Boundary

Chat history is cloud-backed after login.

Allowed local state:

- Runtime text draft in the current AI page/controller.
- Runtime pending message state.
- Runtime selected session id.
- In-memory session/message lists.

Not allowed:

- Local SQLite chat-history tables.
- Local long-term chat message cache.
- `AppDatabase.dbVersion` bump for chat.
- Uploading full local history into AI context.

### 3.8 AI Capability Boundary

The combined Step 3 and 4 work is still text-only chat.

Not implemented:

- Structured RAG.
- Document RAG.
- Context object upload from business records.
- Image attachments.
- Food Draft.
- Official food/workout/body/Profile writes.
- Agent loops or autonomous tools.
- User-managed provider API keys.

The attachment button should remain disabled.

## 4. Deliverables

Backend/Supabase:

- Add one additive migration for:
  - generalized `record_ai_chat_turn`
  - archive session RPC
  - soft-delete session RPC
  - grants for those RPCs only
- Refactor `supabase/functions/ai-chat-route` into small provider-aware helper
  modules.
- Add OpenAI/ChatGPT provider adapter.
- Add Qwen provider adapter.
- Add provider routing by stable `model_choice`.
- Add provider timeout and invalid-response handling.
- Update backend Deno tests with mocked provider HTTP calls.
- Keep mock helper for tests; do not silently use it for real production
  traffic.

Flutter:

- Add `lib/data/remote/ai_gateway_client.dart`.
- Add `lib/data/repositories/ai_chat_repository.dart`.
- Add `lib/features/ai/ai_chat_controller.dart`.
- Update `lib/features/ai/ai_page.dart` to use the controller and real history.
- Add focused AI widgets only if they keep `ai_page.dart` simpler, for example:
  - `lib/features/ai/widgets/ai_chat_message_bubble.dart`
  - `lib/features/ai/widgets/ai_history_panel.dart`
- Update app dependency injection in `lib/app.dart`.
- Update `AccountController.aiAvailability` and AI strings so configured,
  ready accounts can send.
- Update `lib/core/localization/app_strings.dart` for concise user-visible AI
  send/history/error text.

Tests:

- Add `test/ai_gateway_client_test.dart`, if the client can be tested with an
  injected transport.
- Add `test/ai_chat_controller_test.dart`.
- Update `test/ai_page_test.dart`.
- Update `test/ai_gateway_contract_test.dart` only when the stable contract
  changes.
- Update backend tests under `supabase/functions/ai-chat-route`.

Docs after implementation and acceptance:

- `README.md`
- `CHANGELOG.md`
- `docs/en/Product.md` and `docs/zh/Product.md`
- `docs/en/AppGuide.md` and `docs/zh/AppGuide.md`
- `docs/en/AgentDesign.md` and `docs/zh/AgentDesign.md`
- `docs/en/Database.md` and `docs/zh/Database.md`

Do not update stable docs before the code and manual acceptance are complete.

## 5. Backend Engineering Plan

### 5.1 Migration Plan

Add a new migration, likely:

```text
supabase/migrations/*_phase4_step3_4_chat_ops_real_providers.sql
```

The migration should be additive and idempotent where practical.

Add `record_ai_chat_turn`:

- `security definer`
- `set search_path = public`
- revoke public execute
- grant execute only to the role used by the Edge Function service-role path
- validate `input_account_id`
- validate `input_session_id` ownership when present
- reject deleted sessions
- lock the session row before assigning message sequences
- insert request log, user message, assistant message, and debug summary in one
  transaction
- update `ai_chat_sessions.last_message_at`, `title` when blank, and
  `updated_at`

Add session operation RPCs:

- `archive_ai_chat_session(input_session_id uuid, input_archived boolean)`
- `soft_delete_ai_chat_session(input_session_id uuid)`

Session operation RPC rules:

- Use `auth.uid()` for account identity.
- Return a compact JSON object or boolean result.
- Update only rows where `account_id = auth.uid()` and `deleted_at is null`.
- Do not accept `input_account_id` from the client.
- Grant execute to `authenticated`.
- Do not grant direct authenticated `update` or `delete` on chat tables.

### 5.2 Provider-Aware Function Layout

Recommended small layout:

```text
supabase/functions/ai-chat-route/index.ts
supabase/functions/ai-chat-route/contracts.ts
supabase/functions/ai-chat-route/providers.ts
supabase/functions/ai-chat-route/openai_provider.ts
supabase/functions/ai-chat-route/qwen_provider.ts
supabase/functions/ai-chat-route/mock_provider.ts
supabase/functions/ai-chat-route/index_test.ts
```

Keep modules small. If two provider modules plus `contracts.ts` are enough, do
not split further.

### 5.3 Provider Adapter Contract

Use one internal provider adapter interface:

```ts
interface ProviderAdapter {
  readonly providerId: "openai" | "qwen" | "mock";
  readonly model: string;
  generateText(request: GatewayRequest): Promise<string>;
}
```

Adapter requirements:

- Accept only the Step 4 text-only `GatewayRequest`.
- Add a short server-side instruction that FitLog AI is text-only in Phase 4.
- Do not include RAG context, full user history, food records, workout records,
  profile dumps, or debug summaries in the provider prompt.
- Enforce a server-side timeout.
- Return a non-empty assistant text string.
- Reject unsupported/empty provider output as a stable provider failure.
- Never return raw provider payloads to user UI.
- Never write provider raw payloads to `ai_request_logs` or
  `ai_debug_summaries`.

### 5.4 Gateway Flow

The server request flow should remain:

1. Handle CORS preflight.
2. Require POST.
3. Read required environment values.
4. Verify `Authorization: Bearer <access_token>` with Supabase Auth.
5. Recover the current session id from the verified token claim.
6. Parse and validate the text-only request.
7. Check subscription server-side.
8. Assert active device server-side.
9. Route `model_choice` to the real provider adapter.
10. Call provider with timeout.
11. Persist success through `record_ai_chat_turn`.
12. Return `AiGatewayResponse` JSON.

Blocked/error requests:

- `auth_required` should not require an account-bound log.
- `subscription_required`, `device_replaced`, `record_schema_mismatch`,
  `gateway_timeout`, and `provider_failure` should write compact logs when an
  account id is known and it is safe to do so.
- Blocked/error logs must not create sessions or messages.

### 5.5 HTTP And Error Mapping

Keep Step 2 stable status mapping unless a tested product need appears:

| Case | HTTP status | Stable error code |
| --- | ---: | --- |
| Missing/invalid auth token | 401 | `auth_required` |
| Missing/inactive subscription | 403 | `subscription_required` |
| Active-device mismatch | 409 | `device_replaced` |
| Invalid request shape or future field | 422 | `record_schema_mismatch` |
| Provider timeout | 504 | `gateway_timeout` |
| Provider auth/rate/invalid response/failure | 502 | `provider_failure` |
| Success | 200 | none |

Do not add provider-shaped user-visible codes unless the Dart enum and tests
are updated deliberately.

### 5.6 Log And Debug Safety

Success logs should store:

- account id
- session id
- workflow type
- stable model choice
- provider id
- configured model name
- prompt version
- schema version
- profile version if supplied
- status
- stable error code when applicable
- latency
- compact token estimate if available
- `image_count = 0`

Logs/debug summaries must not store:

- provider API keys
- service-role keys
- Supabase JWTs
- raw provider request/response payloads
- stack traces
- chain-of-thought
- full local SQLite payloads
- raw food/workout/body/Profile histories
- unrestricted context dumps
- original images

## 6. Flutter Engineering Plan

### 6.1 `AiGatewayClient`

Add a low-level client:

```text
lib/data/remote/ai_gateway_client.dart
```

Responsibilities:

- Build the Supabase Edge Function URL or use the Supabase Functions client
  from the existing `supabase` package.
- Require an active Supabase auth session and access token.
- Send `AiGatewayRequest.toJson()`.
- Parse `AiGatewayResponse.fromJson`.
- Map network exceptions to `AiGatewayErrorCode.networkFailure`.
- Preserve server stable error codes.
- Never know provider API keys.
- Never write chat history locally.

Before adding a new dependency, verify whether the current `supabase` Dart
package can invoke Edge Functions cleanly. Prefer existing dependency support.

### 6.2 `AiChatRepository`

Add a repository:

```text
lib/data/repositories/ai_chat_repository.dart
```

Responsibilities:

- List active sessions for current account:
  - select from `ai_chat_sessions`
  - `deleted_at is null`
  - default active list filters `archived_at is null`
  - order by `updated_at desc`
- Load messages for a selected session:
  - select from `ai_chat_messages`
  - filter by `session_id`
  - order by `message_sequence`, `created_at`, `id`
- Send text through `AiGatewayClient`.
- Archive/unarchive through the session RPC.
- Soft-delete through the session RPC.

Rules:

- Do not insert messages directly from Flutter.
- Do not update `ai_chat_messages` from Flutter.
- Do not use local SQLite for chat history.
- Treat RLS as a security boundary and still keep repository queries scoped to
  the selected/current account where practical.

### 6.3 `AiChatController`

Add a controller:

```text
lib/features/ai/ai_chat_controller.dart
```

State:

- account boundary key
- selected session id
- session list
- message list for selected session
- loading state
- sending state
- runtime pending user text
- runtime error
- last sent draft for safe retry

Behavior:

- Load sessions when account becomes AI-ready.
- Clear runtime state on sign-out or account switch.
- Clear selected session if it is archived/deleted.
- Load messages when switching sessions.
- Create a new session by setting selected session id to null before sending.
- Send only non-empty trimmed text.
- Show pending user message immediately.
- On success:
  - update selected session id from response
  - clear draft/pending error
  - reload sessions
  - reload canonical messages for the selected session
- On error:
  - keep draft text
  - clear sending state
  - refresh selected session if the failure might be ambiguous
  - expose a stable user-visible error
- On `device_replaced`:
  - mark the cloud runtime context as replaced or trigger existing account
    refresh/sign-out handling.

### 6.4 AI Page UI

Update `lib/features/ai/ai_page.dart` surgically.

Required UI behavior:

- Empty ready state can keep the current centered "I'm listening" visual.
- Once a session has messages or a pending message, show a scrollable message
  list above the composer.
- User and assistant text bubbles use app theme text styles and `NotoSansSC`.
- The composer stays above the keyboard and bottom nav pill.
- The send button is enabled only when:
  - the trimmed composer text is non-empty
  - the controller is not sending
  - `AccountController.aiAvailability.canSend` is true
- During sending, show a sending/progress state without locking the whole app.
- The attachment button remains disabled.
- Provider selector sends `chatgpt` or `qwen`.
- History panel shows real cloud sessions.
- New session, session switch, archive, and delete are available.
- Do not show raw debug summary IDs, stack traces, provider payloads, or
  internal logs in the user UI.

Keep the existing background/keyboard behavior unless a specific layout bug is
found.

### 6.5 Availability Gating

Update AI availability so the UI can actually send in Step 3.

Recommended model:

- Add `AiAvailabilityStatus.ready`, or rename the current
  `gatewayPending` path carefully.
- `canSend = true` only when all are true:
  - backend is configured
  - signed in
  - online
  - subscription active
  - Cloud Profile ready
  - active-device runtime context is usable
  - device has not been replaced
- Keep signed-out, offline, inactive subscription, missing profile, and
  backend-not-ready states disabled.

Server checks remain authoritative. Flutter gating is only UX.

### 6.6 Localization

Add concise strings for:

- sending
- retry
- new chat
- archive chat
- delete chat
- empty history
- no messages yet
- gateway/network error
- provider timeout
- provider failure
- subscription required
- device replaced

New text must use the existing app-level localization style in
`app_strings.dart`.

## 7. Automatic Test Plan

### 7.1 Flutter Unit And Controller Tests

Add focused tests for:

- `AiGatewayClient` parses a successful response.
- `AiGatewayClient` maps server error envelopes to `AiGatewayError`.
- `AiGatewayClient` maps thrown network failures to `network_failure`.
- `AiChatController` loads sessions.
- `AiChatController` switches sessions and loads ordered messages.
- `AiChatController` shows pending user text while sending.
- Successful send reloads canonical cloud messages.
- Failed send keeps the draft.
- Ambiguous failure refreshes messages before safe retry.
- Empty trimmed text is not sent.
- Account switch/sign-out clears runtime state.
- `device_replaced` is handled distinctly.
- Archive removes a session from the active list.
- Soft-delete removes a session and does not touch other sessions.
- Provider choice maps to `AiGatewayModelChoice.chatgpt` or
  `AiGatewayModelChoice.qwen`.

Use fakes for controller tests. Do not require live Supabase for Flutter unit
tests.

### 7.2 Flutter Widget Tests

Update/add widget tests for:

- disabled AI page keeps composer editable but send disabled.
- ready AI page enables send only with non-empty text.
- sending shows pending user bubble.
- assistant response appears after success.
- error state is user-readable and does not show raw internals.
- history panel lists sessions and can switch.
- new chat clears selected messages but keeps no long-term local storage.
- archive/delete updates the panel.
- small phone viewport has no text or composer/nav overlap.
- keyboard-visible layout remains stable.
- provider selector still works.

### 7.3 Backend Deno Tests

Add backend tests for:

- Provider router maps `chatgpt` to the OpenAI adapter.
- Provider router maps `qwen` to the Qwen adapter.
- Provider adapters parse valid mocked provider responses.
- Empty/invalid provider responses map to `provider_failure`.
- Provider timeout maps to `gateway_timeout`.
- Provider raw error bodies are not copied into the Gateway response.
- `gatewayResponse` no longer hard-codes `model_provider = mock` for real
  provider success.
- Request parser still rejects future fields.
- Failure logs use compact safe fields.
- Missing provider config maps to a stable provider failure.

Use mocked `fetch` or injectable transport. Do not call real providers in
automated tests.

### 7.4 Required Automatic Validation

Run during implementation:

```bash
dart format lib test
flutter analyze
flutter test
```

Run backend checks where Deno tooling is available:

```bash
deno fmt supabase/functions/ai-chat-route
deno lint supabase/functions/ai-chat-route
deno test supabase/functions/ai-chat-route
```

Run configured Android debug split build after code is stable:

```bash
flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json
```

If `config/supabase.local.json` is unavailable in the workspace, document that
the configured APK build was skipped because local Supabase config was
unavailable. Do not replace it with an unconfigured build unless explicitly
requested.

## 8. Implementation Sequence

1. Review Step 1/2 artifacts and confirm Step 2 manual acceptance is complete.
   - Verify: mock Gateway can still pass its backend tests.

2. Add the Step 3/4 Supabase migration for generalized persistence and session
   operations.
   - Verify: SQL review shows no broad direct table grants and no local SQLite
     changes.

3. Refactor Gateway provider routing while keeping mock tests passing.
   - Verify: Deno tests still pass for request parsing and mock behavior.

4. Add real provider adapters with mocked backend tests.
   - Verify: provider timeout, invalid response, and sanitized error tests pass.

5. Add `AiGatewayClient`.
   - Verify: client tests cover success, stable server errors, and network
     failure.

6. Add `AiChatRepository`.
   - Verify: repository queries are cloud-backed only and do not write messages
     directly.

7. Add `AiChatController`.
   - Verify: controller tests cover send success, failure, account switch,
     history, archive/delete, and provider choice.

8. Wire the AI page to the controller.
   - Verify: widget tests cover send enablement, pending/success/error UI,
     history panel, and small-screen layout.

9. Update app dependency injection and availability gating.
   - Verify: unconfigured builds keep AI send disabled; configured ready
     accounts can send.

10. Run full automatic validation.
    - Verify: formatting, analysis, Flutter tests, backend checks, and
      configured APK build pass or documented config blockers are real.

11. Run manual Supabase/API/app acceptance.
    - Verify: every required manual item in Section 9 passes.

12. Update stable docs and CHANGELOG after manual acceptance.
    - Verify: docs mark AI Gateway and cloud chat history as implemented while
      keeping RAG, images, Food Draft, and business writes as later phases.

13. Run final automatic validation after docs/code settle.
    - Verify: at minimum `flutter analyze` and `flutter test` still pass after
      final edits.

## 9. Manual Acceptance Plan

Manual acceptance is required because this combined work depends on:

- Supabase project SQL/RPC changes.
- Supabase Edge Function deployment.
- Provider API keys and model configuration.
- Real test accounts and active-device rows.
- Real app login/session behavior.
- Real provider calls.

Everything else should be covered by automated tests.

### 9.1 Required Inputs

The reviewer needs:

- A staging/development Supabase project.
- Phase 2, Phase 3, Phase 4 Step 1, and Phase 4 Step 2 migrations already
  applied.
- The combined Step 3/4 migration applied.
- Deployed `ai-chat-route` Edge Function.
- Function secrets configured:
  - Supabase URL/anon/service-role values
  - OpenAI/ChatGPT provider key and model config
  - Qwen provider key and model config
- Configured Flutter file:
  - `config/supabase.local.json`
- At least two Supabase Auth test users:
  - user A: active subscription
  - user B: inactive subscription
- Prefer a third account or temporarily activated user B for cross-account
  checks.
- Account UUIDs:
  - `<ACCOUNT_A_UUID>`
  - `<ACCOUNT_B_UUID>`
- Access tokens:
  - `<ACCOUNT_A_TOKEN>`
  - `<ACCOUNT_B_TOKEN>`
- Active-device values:
  - `<DEVICE_A_ID>`
  - `<SESSION_A_ID>`
  - `<DEVICE_B_ID>`
  - `<SESSION_B_ID>`

### 9.2 Apply Migration And Deploy Function

Preferred migration operation:

```bash
supabase db push
```

Acceptable manual alternative:

- Open Supabase Dashboard.
- Go to SQL Editor.
- Paste the Step 3/4 migration SQL.
- Run it once.
- Re-run safe parts if the migration is designed to be idempotent.

Deploy function:

```bash
supabase functions deploy ai-chat-route
```

Configure secrets in Supabase Dashboard or CLI. Do not paste secret values into
this repository or acceptance notes.

Pass criteria:

- Migration succeeds.
- Function deploy succeeds.
- Step 1/2 tables still exist.
- Step 2 mock tests still pass locally.
- No secret values are committed.

### 9.3 SQL/RPC Acceptance

Check functions exist:

```sql
select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'record_ai_chat_turn',
    'archive_ai_chat_session',
    'soft_delete_ai_chat_session'
  )
order by routine_name;
```

Pass criteria:

- All expected functions exist.

Check grants:

```sql
select routine_name, grantee, privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name in (
    'record_ai_chat_turn',
    'archive_ai_chat_session',
    'soft_delete_ai_chat_session'
  )
order by routine_name, grantee;
```

Pass criteria:

- `archive_ai_chat_session` and `soft_delete_ai_chat_session` are executable by
  `authenticated`.
- General successful-turn persistence is not executable by ordinary
  authenticated clients if it is intended only for the Edge Function service
  path.
- No broad table update/delete grant is added for authenticated clients.

Check chat table grants:

```sql
select table_name, grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in (
    'ai_chat_sessions',
    'ai_chat_messages',
    'ai_request_logs',
    'ai_debug_summaries'
  )
order by table_name, grantee, privilege_type;
```

Pass criteria:

- Authenticated clients can read own session/message rows.
- Authenticated clients do not receive broad insert/update/delete on chat
  messages.
- Authenticated clients do not receive direct reads of request logs or debug
  summaries.

Archive own session as simulated user A after a test session exists:

```sql
begin;
set local role authenticated;
set local request.jwt.claim.sub = '<ACCOUNT_A_UUID>';

select public.archive_ai_chat_session('<SESSION_ID_FROM_USER_A>'::uuid, true);

commit;
```

Pass criteria:

- User A's session gets `archived_at`.
- User B's sessions are unchanged.

Cross-account archive rejection:

```sql
begin;
set local role authenticated;
set local request.jwt.claim.sub = '<ACCOUNT_B_UUID>';

select public.archive_ai_chat_session('<SESSION_ID_FROM_USER_A>'::uuid, true);

commit;
```

Pass criteria:

- The RPC fails or returns a not-updated result.
- User A's session is not modified by user B.

Soft-delete own session:

```sql
begin;
set local role authenticated;
set local request.jwt.claim.sub = '<ACCOUNT_A_UUID>';

select public.soft_delete_ai_chat_session('<SESSION_ID_FROM_USER_A>'::uuid);

commit;
```

Pass criteria:

- `deleted_at` is set.
- The row is hidden from authenticated client session reads.
- Child messages are not hard-deleted.

### 9.4 API Acceptance

Set:

```bash
FUNCTION_URL="https://<PROJECT_REF>.supabase.co/functions/v1/ai-chat-route"
```

Unauthenticated rejection:

```bash
curl -i -X POST "$FUNCTION_URL" \
  -H "apikey: <SUPABASE_ANON_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"message":{"text":"hello"},"language":"en","model_choice":"chatgpt","workflow_hint":"auto","device_id":"device-a"}'
```

Pass criteria:

- HTTP status is `401`.
- `error.code` is `auth_required`.
- No chat session/message is created.

Inactive subscription rejection:

```bash
curl -i -X POST "$FUNCTION_URL" \
  -H "apikey: <SUPABASE_ANON_KEY>" \
  -H "Authorization: Bearer <ACCOUNT_B_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"message":{"text":"hello"},"language":"en","model_choice":"chatgpt","workflow_hint":"auto","device_id":"<DEVICE_B_ID>"}'
```

Pass criteria:

- HTTP status is `403`.
- `error.code` is `subscription_required`.
- No messages are created for user B.

Active-device rejection:

Temporarily replace user A's active device:

```sql
update public.account_active_devices
set active_device_id = 'replacement-device',
    active_session_id = '<SESSION_A_ID>',
    replaced_at = timezone('utc', now()),
    replaced_reason = 'manual_acceptance_replacement'
where account_id = '<ACCOUNT_A_UUID>';
```

Invoke with the old device id:

```bash
curl -i -X POST "$FUNCTION_URL" \
  -H "apikey: <SUPABASE_ANON_KEY>" \
  -H "Authorization: Bearer <ACCOUNT_A_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"message":{"text":"hello"},"language":"en","model_choice":"chatgpt","workflow_hint":"auto","device_id":"<DEVICE_A_ID>"}'
```

Pass criteria:

- HTTP status is `409`.
- `error.code` is `device_replaced`.
- No session/message is created.

Restore user A's active device before success tests:

```sql
update public.account_active_devices
set active_device_id = '<DEVICE_A_ID>',
    active_session_id = '<SESSION_A_ID>',
    replaced_at = null,
    replaced_reason = null,
    last_seen_at = timezone('utc', now())
where account_id = '<ACCOUNT_A_UUID>';
```

ChatGPT/OpenAI provider success:

```bash
curl -i -X POST "$FUNCTION_URL" \
  -H "apikey: <SUPABASE_ANON_KEY>" \
  -H "Authorization: Bearer <ACCOUNT_A_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"message":{"text":"Reply briefly: what is one high-protein dinner idea?"},"language":"en","model_choice":"chatgpt","workflow_hint":"auto","selected_date":"2026-06-30","profile_version":"profile_1","device_id":"<DEVICE_A_ID>","client":{"app_version":"phase4-step3-4","platform":"manual","timezone":"Asia/Shanghai"}}'
```

Pass criteria:

- HTTP status is `200`.
- `error` is null.
- `session_id` is a UUID.
- `assistant_message_id` is a UUID.
- `model_choice` is `chatgpt`.
- `model_provider` is the OpenAI provider id selected by implementation,
  expected `openai`.
- `message.text` is non-empty.
- `draft` is null.
- `debug_summary_id` is a UUID.

Capture `<OPENAI_SESSION_ID>` and `<OPENAI_DEBUG_SUMMARY_ID>`.

Qwen provider success:

```bash
curl -i -X POST "$FUNCTION_URL" \
  -H "apikey: <SUPABASE_ANON_KEY>" \
  -H "Authorization: Bearer <ACCOUNT_A_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"message":{"text":"用中文简短回复：训练后晚餐怎么安排？"},"language":"zh","model_choice":"qwen","workflow_hint":"auto","device_id":"<DEVICE_A_ID>"}'
```

Pass criteria:

- HTTP status is `200`.
- `error` is null.
- `model_choice` is `qwen`.
- `model_provider` is `qwen`.
- `message.text` is non-empty.
- `draft` is null.

Database message check:

```sql
select
  message_sequence,
  role,
  content_text,
  message_type,
  workflow_type,
  model_choice,
  model_provider,
  final_answer_json,
  attachments_metadata
from public.ai_chat_messages
where session_id = '<OPENAI_SESSION_ID>'
order by message_sequence, created_at, id;
```

Pass criteria:

- Exactly two rows exist after the first successful request in that session.
- Sequence `1` is `user`.
- Sequence `2` is `assistant`.
- Both rows are `message_type = text`.
- `attachments_metadata` is `[]`.
- `final_answer_json` is null.
- Assistant row has real provider metadata, not `mock`.

Existing session reuse:

```bash
curl -i -X POST "$FUNCTION_URL" \
  -H "apikey: <SUPABASE_ANON_KEY>" \
  -H "Authorization: Bearer <ACCOUNT_A_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"session_id":"<OPENAI_SESSION_ID>","message":{"text":"Add one more short answer."},"language":"en","model_choice":"chatgpt","workflow_hint":"auto","device_id":"<DEVICE_A_ID>"}'
```

Pass criteria:

- HTTP status is `200`.
- Response `session_id` equals `<OPENAI_SESSION_ID>`.
- No second session is created for this request.
- Message sequences become `1`, `2`, `3`, `4` with no duplicates.

Cross-account session rejection:

- Use subscribed active user B, or temporarily activate user B and set an active
  device row for the test.
- Invoke user B against `<OPENAI_SESSION_ID>`.

Pass criteria:

- Request is rejected.
- Preferred error code is `record_schema_mismatch`, unless implementation adds
  and tests a more precise stable code.
- No message is appended to user A's session.
- No row exists with `account_id = '<ACCOUNT_B_UUID>'` and
  `session_id = '<OPENAI_SESSION_ID>'`.

Future-scope rejection:

```bash
curl -i -X POST "$FUNCTION_URL" \
  -H "apikey: <SUPABASE_ANON_KEY>" \
  -H "Authorization: Bearer <ACCOUNT_A_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"message":{"text":"Please inspect this image."},"language":"en","model_choice":"chatgpt","workflow_hint":"food_logging","device_id":"<DEVICE_A_ID>","attachments":[{"kind":"image","attachment_id":"future"}],"context_objects":[{"type":"selected_day_summary","payload":{}}],"draft":{"schema_version":"food_draft.v1"},"official_record_write":{"kind":"food"}}'
```

Pass criteria:

- HTTP status is `422`.
- `error.code` is `record_schema_mismatch`.
- No session/message is created for this request.
- No Food Draft appears.
- No official business record is written.

Business no-write check:

```sql
select count(*) as ai_food_records
from public.food_records
where account_id = '<ACCOUNT_A_UUID>'
  and source in ('ai_chat', 'ai_photo', 'ai_meal_decision');

select count(*) as ai_workout_sessions
from public.workout_sessions
where account_id = '<ACCOUNT_A_UUID>'
  and exercise_source in ('ai_chat', 'ai_photo', 'ai_meal_decision');
```

Pass criteria:

- Counts do not increase during Phase 4 Step 3/4 manual tests.

Log/debug safety check:

```sql
select
  logs.request_id,
  logs.account_id,
  logs.session_id,
  logs.workflow_type,
  logs.model_choice,
  logs.model_provider,
  logs.model,
  logs.status,
  logs.error_code,
  logs.latency_ms,
  logs.token_estimate,
  logs.image_count,
  debug.id as debug_summary_id,
  debug.schema_validation_status,
  debug.user_final_action,
  debug.called_tools_json,
  debug.retrieved_dimensions_json,
  debug.missing_dimensions_json,
  debug.safety_flags_json
from public.ai_debug_summaries debug
join public.ai_request_logs logs
  on logs.request_id = debug.request_id
where logs.account_id = '<ACCOUNT_A_UUID>'
order by logs.created_at desc
limit 20;
```

Pass criteria:

- Success, blocked, timeout, and error statuses are distinguishable when
  present.
- Provider IDs and model names are visible as safe metadata.
- No provider key, service-role key, JWT, stack trace, raw provider payload,
  chain-of-thought, or unrestricted context dump appears.
- `image_count` remains `0`.

Sensitive column check:

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

- Query returns zero rows.
- `token_estimate` remains acceptable because it is a compact usage estimate,
  not an auth/provider token.

### 9.5 Flutter App Manual Acceptance

Build/install the configured debug split APK:

```bash
flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json
```

Manual app checks:

1. Signed-out state.
   - Open app signed out.
   - AI send is unavailable.
   - Composer remains editable.
   - No Gateway request is made.

2. Subscribed account send with ChatGPT.
   - Sign in as user A.
   - Ensure subscription active and Cloud Profile ready.
   - Open AI tab.
   - Select ChatGPT.
   - Send a short text message.
   - User message appears pending immediately.
   - Assistant response appears after success.
   - No raw provider/internal error appears.

3. Qwen send.
   - Select Qwen.
   - Send a Chinese text message.
   - Assistant response appears.
   - Database logs show `model_choice = qwen` and `model_provider = qwen`.

4. App restart history.
   - Kill/restart the app.
   - Sign-in session recovers.
   - Open AI history.
   - Cloud session appears.
   - Selecting it loads the correct messages.

5. New session.
   - Tap new chat.
   - Send a message.
   - A new cloud session appears in history.
   - Old session remains intact.

6. Session switch.
   - Switch between two sessions.
   - Messages do not cross sessions.
   - Composer draft behavior is clear and does not overwrite cloud history.

7. Archive session.
   - Archive a session from history.
   - It disappears from the active history list.
   - Database row has `archived_at`.
   - Messages are not hard-deleted.

8. Delete session.
   - Soft-delete a session.
   - It disappears from active history and normal client reads.
   - Database row has `deleted_at`.
   - Other sessions/messages remain unchanged.

9. Inactive subscription.
   - Sign in as user B.
   - AI send is unavailable.
   - If an API call is forced, server returns `subscription_required`.

10. Device replacement.
    - Simulate active-device replacement for user A.
    - Try to send.
    - App shows a distinct device/session message or signs out through existing
      device-replaced handling.
    - No chat message is created.

11. Offline/weak network.
    - Disable network before send.
    - Send fails gracefully.
    - Draft text is preserved.
    - No duplicate canonical messages appear after reconnect/retry.

12. Logout/account switch.
    - Type an unsent draft.
    - Sign out or switch account.
    - Runtime draft and selected messages clear.
    - New account does not see previous account history.

13. Layout.
    - Test a small phone viewport/device.
    - Open keyboard.
    - Message list, composer, and bottom nav do not overlap incoherently.
    - Long Chinese and English messages wrap cleanly.

14. Boundary.
    - Attachment button remains disabled.
    - No Food Draft card appears.
    - Home/Food/Workout/Profile data are not created or modified by AI reply.

### 9.6 Documentation Acceptance

After code and manual acceptance pass, update stable docs.

Pass criteria:

- README Chinese and English sections match in facts and commands.
- CHANGELOG records the combined Step 3/4 change concisely.
- `docs/en/*` and `docs/zh/*` pairs stay synchronized.
- AgentDesign marks app-side sending, cloud chat history UI, and real providers
  as implemented.
- Database docs describe current AI chat/session/log/debug storage and new RPCs.
- Product/AppGuide describe user-visible chat/history behavior.
- RAG, image attachments, Food Draft, and AI business writes remain documented
  as later phases.
- No date-appended stable-doc update section is added.

## 10. Exit Criteria

The combined Step 3/4 work is complete only when all are true:

- Flutter AI page can send text through the Gateway for a subscribed active
  account.
- ChatGPT/OpenAI provider returns a real assistant message.
- Qwen provider returns a real assistant message.
- Cloud chat sessions/messages persist and reload after app restart.
- History list can create, load, switch, archive, and soft-delete sessions.
- Failed sends do not duplicate messages unexpectedly.
- Signed-out, inactive subscription, offline, profile-missing, backend-missing,
  and device-replaced states are blocked in UI and enforced by server where
  applicable.
- Server logs/debug summaries are compact and sanitized.
- Provider secrets are only in Supabase/server-side secret storage.
- Flutter has no provider API keys or service-role keys.
- No local SQLite chat history or schema version bump exists.
- No RAG, image upload, Food Draft, or business write exists.
- `dart format lib test` has run.
- `flutter analyze` passes.
- `flutter test` passes.
- Backend Deno formatting/lint/tests pass where tooling is available.
- Configured debug split APK build passes, or missing local config is
  documented.
- Manual Supabase/API/app acceptance passes.
- README, CHANGELOG, and bilingual stable docs reflect the exact implemented
  state.

## 11. Do Not Close Phase 4 If

Do not close Phase 4 if:

- The app can send based only on Flutter subscription state without server
  entitlement enforcement.
- Active-device replacement can still send AI messages.
- Provider keys appear in Flutter, committed config, logs, debug summaries, or
  UI.
- The function silently returns mock responses for real Step 4 user traffic.
- One provider breaks the shared response contract.
- Provider raw errors, stack traces, raw payloads, or chain-of-thought leak to
  users or logs.
- Service-role writes can append to another account's session.
- Cross-account history appears in the app.
- Archive/delete can modify another account's session.
- Failed or blocked requests create chat messages.
- Message sequences duplicate under normal repeated sends.
- Chat history is stored long-term in local SQLite.
- RAG, image upload, Food Draft, or official business writes slip into this
  phase.
- Composer, keyboard, or bottom nav layout regresses.
- Stable docs claim unimplemented features are shipped.
- Flutter analysis/tests or required backend tests fail.

## 12. Combined Step 3/4 Handoff Summary Template

At the end of the implementation chat, report:

- Files changed.
- Migration/RPC names added.
- Edge Function route.
- Provider adapter files.
- Provider secret names configured, without secret values.
- Auth verification approach.
- Subscription check approach.
- Active-device check approach.
- Persistence approach and sequence-safety decision.
- Flutter client/repository/controller architecture.
- History archive/delete approach.
- Retry/duplicate-send decision.
- What was intentionally not implemented.
- Automatic validation commands and results.
- Configured APK build result or config blocker.
- Manual acceptance results for:
  - unauthenticated rejection
  - inactive subscription rejection
  - device replacement rejection
  - ChatGPT/OpenAI success
  - Qwen success
  - existing session reuse
  - cross-account session rejection
  - archive/delete
  - future-scope rejection
  - log/debug safety
  - app restart history
  - offline/weak-network behavior
  - no business writes
- Stable documentation updates.
- Known risks or follow-up items.
- Whether Phase 4 is closed.
