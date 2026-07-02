# Phase 4 Step 2 Engineering Plan: Gateway Skeleton With Mock Provider

This document is the execution plan for Step 2 of
`PHASE4_GATEWAY_HANDOFF.md`. It is a working engineering and acceptance plan,
not a stable product source of truth. Stable product claims should remain in
`README.md`, `docs/en`, and `docs/zh` only after the implemented state is ready
to be documented.

## 1. Handoff Review

Step 1 has already created and manually accepted the Phase 4 data and contract
foundation:

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
- Contract tests in `test/ai_gateway_contract_test.dart`.

Step 2 should build the first real server path, but still with a mock provider.
The point is to validate the Gateway boundary before real model providers are
introduced.

Step 2 is not Phase 4 completion. After Step 2:

- The AI page should still not be wired for user-visible sending.
- No real OpenAI/ChatGPT or Qwen call should exist.
- No RAG, image upload, Food Draft, or official business write should exist.
- Cloud chat persistence should be proven through the server endpoint and
  database checks, not through the app UI yet.

## 2. Step 2 Goal

Build the server AI Gateway skeleton with a fixed mock assistant response.

Step 2 is successful when:

- A Supabase Edge Function or equivalent server endpoint exists for the Phase 4
  chat route.
- The endpoint verifies the Supabase user token server-side.
- The endpoint verifies subscription entitlement server-side.
- The endpoint verifies the active-device guard server-side.
- A valid request creates or reuses a cloud chat session.
- A valid request persists one user message and one mock assistant message.
- Request metadata is written to `ai_request_logs`.
- A compact sanitized debug summary is written to `ai_debug_summaries`.
- The response matches the Step 1 `AiGatewayResponse` JSON contract.
- Stable error codes are returned for auth, subscription, active-device,
  timeout/provider/schema failures, and network/client mapping where relevant.
- Request logs and debug summaries do not store secrets, auth tokens, raw
  provider traces, stack traces, chain-of-thought, unrestricted raw context, or
  full local SQLite payloads.
- Any Flutter client code remains low-level and unwired from `AiPage`.
- `dart format lib test`, `flutter analyze`, and `flutter test` pass.
- Backend formatting/linting/tests run where the local Deno/Supabase tooling is
  available, or the blocker is documented.

Implemented artifacts for this Step 2 pass:

- Supabase function config:
  `supabase/config.toml`.
- Supabase mock Gateway migration/RPC:
  `supabase/migrations/202606290002_phase4_step2_gateway_mock.sql`.
- Supabase service-role grant patch:
  `supabase/migrations/202606290003_phase4_step2_service_role_grants.sql`.
- Supabase subscription service-role write grant patch:
  `supabase/migrations/202606290004_phase4_step2_subscription_service_role_write.sql`.
- Supabase Edge Function:
  `supabase/functions/ai-chat-route/index.ts`.
- Supabase Edge Function helpers:
  `supabase/functions/ai-chat-route/contracts.ts` and
  `supabase/functions/ai-chat-route/mock_provider.ts`.
- Backend helper tests:
  `supabase/functions/ai-chat-route/index_test.ts`.
- Dashboard manual deployment copy:
  `supabase/functions/ai-chat-route/index.dashboard.ts`.

## 3. Assumptions, Decisions, And Open Risks

### 3.1 Selected Runtime

Use Supabase Edge Functions for Step 2 unless implementation discovers a
project constraint that makes this impossible.

Recommended function name:

```text
ai-chat-route
```

The deployed route is expected to be:

```text
https://<PROJECT_REF>.supabase.co/functions/v1/ai-chat-route
```

The local Supabase CLI route is expected to be:

```text
http://127.0.0.1:54321/functions/v1/ai-chat-route
```

This maps to the product-level `POST /ai/chat/route` contract from
`docs/API_CONTRACT_DRAFT.md`, while using the Supabase Functions URL shape.

### 3.2 Server Secrets

Required Edge Function environment values:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

Rules:

- `SUPABASE_SERVICE_ROLE_KEY` must exist only in Supabase Function secrets or a
  local uncommitted env file.
- The service-role key must never enter Flutter code, committed config,
  request logs, debug summaries, test fixtures, or manual acceptance notes.
- Flutter continues to use only `SUPABASE_URL` and `SUPABASE_ANON_KEY`.

### 3.3 Auth Verification

The endpoint must not trust a raw decoded JWT by itself.

Recommended flow:

1. Require `Authorization: Bearer <access_token>`.
2. Create a user-scoped Supabase client with `SUPABASE_ANON_KEY` and the
   incoming authorization header.
3. Call `auth.getUser()` or equivalent to verify the token.
4. Use the verified user id as `account_id`.
5. Use a service-role Supabase client only after auth succeeds.

### 3.4 Active-Device Session ID

Current Phase 3 active-device RPC requires both:

- `input_device_id`
- `input_session_id`

Current Step 1 `AiGatewayRequest` contains `device_id`, and the Flutter auth
repository already extracts `session_id`, `sid`, or `jti` from the Supabase
access-token payload for local runtime context.

Preferred Step 2 decision:

- Recover the current session id server-side from the verified access token
  claim using the same fallback order: `session_id`, then `sid`, then `jti`.
- Call `assert_active_device(input_device_id, input_session_id)` through the
  user-scoped Supabase client.

Required verification before implementation closes:

- A real Supabase test token used in manual acceptance must expose one of those
  session-id claims.
- The recovered value must match `account_active_devices.active_session_id` for
  the same account after sign-in or manual setup.

Fallback if that verification fails:

- Make the smallest possible request-contract addition for `session_id`.
- Update `AiGatewayRequest`, `test/ai_gateway_contract_test.dart`, and this
  plan's manual acceptance commands.
- Keep `session_id` scoped to active-device verification only.
- Do not expose provider secrets or add UI send wiring as part of that fallback.

### 3.5 Subscription Rule

Step 2 should preserve the current app behavior: only `subscriptions.status =
'active'` is accepted as AI-entitled.

Do not rely on the client's visible subscription state. The Edge Function must
query the current account's entitlement server-side.

### 3.6 Persistence Atomicity

Step 2 writes a request log, a debug summary, a user message, an assistant
message, and a session update. These writes should not produce duplicate
message sequences or partial successful turns.

Preferred implementation:

- Add a narrowly scoped Postgres RPC in a Step 2 Supabase migration for the
  successful mock chat turn.
- Call that RPC from the Edge Function using the service-role client after auth,
  subscription, active-device, and request validation pass.
- Lock the target session row inside the RPC before assigning message
  sequences.
- Insert both messages with adjacent sequences in the same database
  transaction.

Acceptable alternative:

- Direct service-role table writes from the Edge Function, but only if the
  implementation proves deterministic sequence behavior and no partial writes
  under concurrent sends to the same session.

If neither is proven, Step 2 must not pass.

### 3.7 UI Boundary

Step 2 may add a low-level Flutter client only if useful for tests or Step 3
handoff. It must not wire `AiPage` send behavior yet.

Allowed:

- Pure contract/client tests.
- A low-level `AiGatewayClient` that is not provided to the UI tree.
- Error mapping that reuses `AiGatewayError`.

Not allowed:

- Enabling the send button.
- Adding chat-history UI.
- Showing mock replies in the app UI.
- Long-term local chat storage.

## 4. Deliverables

Backend/Supabase:

- Add `supabase/functions/ai-chat-route/index.ts`.
- Add helper modules under `supabase/functions/ai-chat-route/` if they reduce
  complexity.
- Add Deno tests for pure helpers where practical.
- Add an optional Step 2 migration for an atomic Gateway persistence RPC if the
  implementation follows the preferred persistence plan.

Flutter:

- Prefer no Flutter production changes unless a low-level client is useful.
- If added, keep the client unwired from `AiPage`.
- If request/response contract changes are unavoidable, update the domain model
  and contract tests surgically.

Documentation:

- This plan file only.
- Do not update stable docs until Step 2 code has actually landed and passed
  automatic plus manual acceptance.

Not delivered in Step 2:

- No real provider adapter.
- No real model names.
- No provider API keys in Flutter.
- No AI page send enablement.
- No chat-history panel.
- No RAG.
- No image upload.
- No Food Draft.
- No official food/workout/body/Profile writes.
- No local SQLite chat-history storage.
- No `AppDatabase.dbVersion` bump.

## 5. Backend Architecture Plan

### 5.1 Recommended Function Layout

Suggested files:

```text
supabase/functions/ai-chat-route/index.ts
supabase/functions/ai-chat-route/contracts.ts
supabase/functions/ai-chat-route/errors.ts
supabase/functions/ai-chat-route/mock_provider.ts
supabase/functions/ai-chat-route/persistence.ts
supabase/functions/ai-chat-route/auth.ts
supabase/functions/ai-chat-route/index_test.ts
```

Keep the layout small. If one or two helper files are enough, do not split into
more modules.

### 5.2 Request Shape

The endpoint should accept the Step 1 request contract:

```json
{
  "session_id": "optional-existing-session-uuid",
  "message": {
    "text": "What can I eat for dinner?"
  },
  "language": "en",
  "model_choice": "chatgpt",
  "workflow_hint": "auto",
  "selected_date": "2026-06-29",
  "profile_version": "profile_1",
  "device_id": "device-a",
  "client": {
    "app_version": "1.0.35+36",
    "platform": "android",
    "timezone": "Asia/Shanghai"
  }
}
```

Text-only constraints:

- `message.text` is required after trimming.
- `message.text` should have a conservative maximum length. Suggested maximum:
  4000 characters for Step 2.
- `language` is required and must not be blank. Suggested accepted values for
  Step 2: `zh`, `en`.
- `model_choice` must be `chatgpt` or `qwen`.
- `workflow_hint` must be one of:
  - `auto`
  - `food_logging`
  - `meal_decision`
  - `weekly_review`
  - `app_logic_answer`
- `device_id` is required and must not be blank.
- `attachments`, `context_objects`, `draft`, `official_record_write`, and
  similar future-phase fields must be rejected in Step 2.

For rejected shape or unsupported future fields, return
`record_schema_mismatch` unless the implementation deliberately extends the
stable error enum and updates Dart tests.

### 5.3 Response Shape

Use the Step 1 `AiGatewayResponse` contract directly. Do not wrap it in a new
`ok/data/error` envelope in Step 2 unless the Dart contract is updated and
tested.

Successful response:

```json
{
  "session_id": "00000000-0000-4000-8000-000000000001",
  "assistant_message_id": "00000000-0000-4000-8000-000000000003",
  "model_choice": "chatgpt",
  "model_provider": "mock",
  "message": {
    "text": "This is a FitLog AI mock reply. Your text message was received.",
    "language": "en"
  },
  "workflow": "auto",
  "needs_clarification": false,
  "clarification_questions": [],
  "draft": null,
  "error": null,
  "debug_summary_id": "00000000-0000-4000-8000-000000000004"
}
```

Error response:

```json
{
  "session_id": null,
  "assistant_message_id": null,
  "model_choice": "chatgpt",
  "model_provider": "mock",
  "message": {
    "language": "en"
  },
  "workflow": "auto",
  "needs_clarification": false,
  "clarification_questions": [],
  "draft": null,
  "error": {
    "code": "subscription_required",
    "message": "AI subscription is required."
  },
  "debug_summary_id": null
}
```

Error messages should be short and user-readable, but not provider-shaped and
not raw stack traces.

### 5.4 HTTP Status Mapping

Recommended status codes:

| Case | HTTP status | Stable error code |
| --- | ---: | --- |
| Missing/invalid auth token | 401 | `auth_required` |
| Missing/inactive subscription | 403 | `subscription_required` |
| Active-device mismatch | 409 | `device_replaced` |
| Invalid request shape or unsupported future field | 422 | `record_schema_mismatch` |
| Mock provider timeout simulation, if tested | 504 | `gateway_timeout` |
| Mock provider forced failure, if tested | 502 | `provider_failure` |
| Success | 200 | none |

The response body should still be parseable by `AiGatewayResponse.fromJson`.

### 5.5 Server Flow

Recommended request flow:

1. Start timer.
2. Parse headers.
3. Require `Authorization: Bearer <token>`.
4. Verify user through a user-scoped Supabase client.
5. Parse and validate request JSON.
6. Recover the session id from the verified access token claims.
7. Check subscription with service-role or user-scoped database access.
8. Call `assert_active_device(input_device_id, input_session_id)` with a
   user-scoped Supabase client.
9. Reject unsupported future-scope request fields.
10. Call the mock provider.
11. Persist the successful turn through the atomic persistence path.
12. Return the response contract.

Blocked requests:

- `auth_required`: no account id is known, so no account-bound request log is
  required.
- `subscription_required`: account id is known; write a blocked request log and
  safe debug summary when practical.
- `device_replaced`: account id is known; write a blocked request log and safe
  debug summary when practical.
- `record_schema_mismatch`: account id is known after auth; write an error
  request log and safe debug summary when practical.

Blocked logs must not create chat sessions or chat messages.

### 5.6 Mock Provider

The mock provider should be deterministic and boring on purpose.

Recommended fixed assistant text:

```text
This is a FitLog AI mock reply. Your text message was received.
```

Rules:

- `model_provider` is `mock`.
- `model` in `ai_request_logs` is `mock-provider-v1` or similarly stable.
- The mock reply must not pretend to calculate macros, inspect food images, use
  RAG, or write business records.
- The mock provider should be injectable in tests so timeout/failure mapping can
  be tested without real remote calls.

### 5.7 Persistence Plan

Preferred successful-turn persistence RPC:

```text
public.record_ai_mock_chat_turn(...)
```

The exact function name can change, but it should be specific enough that later
provider work can either reuse it or replace it deliberately.

The RPC should:

- Require `input_account_id`.
- Accept nullable `input_session_id`.
- Validate that an existing session belongs to `input_account_id`.
- Reject deleted sessions.
- Lock the session row before assigning message sequences.
- Create a new session when `input_session_id` is null.
- Insert one `ai_request_logs` row with:
  - `status = 'ok'`
  - `error_code = null`
  - `model_provider = 'mock'`
  - `model = 'mock-provider-v1'`
  - `image_count = 0`
- Insert the user message.
- Insert the assistant message.
- Insert one `ai_debug_summaries` row with compact safe metadata.
- Update `ai_chat_sessions.last_message_at` and `updated_at`.
- Set an initial session title only if the title is currently blank.
- Return:
  - `session_id`
  - `assistant_message_id`
  - `debug_summary_id`
  - `request_id`
  - user and assistant `message_sequence` values, if useful for tests.

Suggested sequence rule:

- New session:
  - user message sequence `1`
  - assistant message sequence `2`
- Existing session:
  - user message sequence `max(message_sequence) + 1`
  - assistant message sequence `max(message_sequence) + 2`

The RPC should not grant execution to `anon` or `authenticated` clients if it is
designed for service-role Gateway use only.

### 5.8 Blocked/Error Logging

Blocked/error logging can be direct service-role writes from the Edge Function
because no message sequence is involved.

Recommended `ai_request_logs` values:

| Case | `status` | `error_code` | `session_id` |
| --- | --- | --- | --- |
| Subscription missing/inactive | `blocked` | `subscription_required` | null unless a verified own session was supplied |
| Device replaced | `blocked` | `device_replaced` | null unless a verified own session was supplied |
| Invalid request shape | `error` | `record_schema_mismatch` | null unless a verified own session was supplied |
| Mock timeout | `timeout` | `gateway_timeout` | null or verified own session |
| Mock forced failure | `error` | `provider_failure` | null or verified own session |

Recommended `ai_debug_summaries` values:

- `intent`: workflow hint if known, otherwise `ai_chat`.
- `intent_confidence`: null for mock/error cases.
- `called_tools_json`: `["mock_provider"]` on success, `[]` on blocked cases.
- `retrieved_dimensions_json`: `[]`.
- `missing_dimensions_json`: `[]`.
- `safety_flags_json`: short stable flags only, for example
  `["subscription_required"]`.
- `schema_validation_status`: `passed`, `blocked`, or `failed`.
- `user_final_action`: `read_only`, `blocked`, or `none`.

Do not store raw request body. Do not store raw authorization headers.

## 6. Flutter Plan

### 6.1 Preferred Step 2 Flutter Scope

Prefer no app UI changes in Step 2.

The app can continue to show:

- Editable composer.
- Provider selector.
- Account/subscription sheet.
- User-record summary permission toggle.
- Gateway-pending send state.

The AI page send button should remain disabled or otherwise unable to submit.

### 6.2 Optional Low-Level Client

If implementation adds a low-level client, suggested file:

```text
lib/data/remote/ai_gateway_client.dart
```

Constraints:

- It must not be provided to `AiPage`.
- It must not enable send behavior.
- It must not store chat history locally.
- It must not introduce a provider key or service-role key.
- It should reuse `AiGatewayRequest`, `AiGatewayResponse`, and
  `AiGatewayError`.
- It should map network failures to `AiGatewayErrorCode.networkFailure`.

Before adding a new HTTP dependency, check whether the existing `supabase` Dart
package can invoke Edge Functions in the current dependency version. If not,
defer the Flutter client to Step 3 unless a new dependency is clearly needed
and covered by tests.

### 6.3 Contract Change Rules

Do not change the Step 1 contract unless Step 2 proves that the active-device
session id cannot be derived server-side from the verified access token.

If a contract change is unavoidable:

- Add the smallest field needed.
- Update `AiGatewayRequest.toJson`.
- Update `test/ai_gateway_contract_test.dart`.
- Keep old fields and stable error codes compatible.
- Do not add RAG/image/Food Draft fields.

## 7. Test Plan

### 7.1 Backend Unit Tests

Add Deno tests for pure helpers where practical.

Recommended tests:

- Parses valid text-only request.
- Rejects empty `message.text`.
- Rejects unsupported `model_choice`.
- Rejects unsupported `workflow_hint`.
- Rejects unsupported future fields such as `attachments` and
  `context_objects`.
- Extracts session id from JWT payload claims in the same fallback order used by
  Flutter.
- Maps missing auth to `auth_required`.
- Maps inactive subscription to `subscription_required`.
- Maps active-device RPC false result to `device_replaced`.
- Maps mock provider timeout to `gateway_timeout`.
- Maps mock provider thrown error to `provider_failure`.
- Produces a successful mock response that `AiGatewayResponse.fromJson` can
  parse.
- Sanitizes error responses so they do not include stack traces, auth tokens, or
  service-role secrets.

### 7.2 Persistence Tests

If a SQL RPC is added, there are two acceptable validation levels:

- Manual SQL acceptance only, if no local Supabase test harness exists.
- Local Supabase integration test, if Supabase CLI and database reset are
  already available for this repo.

Required behavior to prove somewhere:

- New request creates a session and two messages.
- Existing session request appends two messages with deterministic sequences.
- Two requests to the same session cannot create duplicate
  `message_sequence` values.
- Cross-account `session_id` is rejected even though the Edge Function uses
  service-role writes.
- Deleted sessions are rejected.

### 7.3 Flutter Tests

Always keep existing Step 1 tests passing.

If no Flutter code changes:

- Do not add unnecessary Flutter tests.
- Still run `flutter analyze` and `flutter test` at the end of Step 2.

If a low-level client is added:

- Add tests for successful response parsing.
- Add tests for HTTP error body parsing.
- Add tests for network failure mapping to `network_failure`.
- Add tests proving the client does not expose raw provider errors directly.

If a request-contract field is added:

- Update `test/ai_gateway_contract_test.dart`.

## 8. Automatic Validation

Run from the repo root after implementation:

```bash
dart format lib test
flutter analyze
flutter test
```

Backend validation, when Deno and Supabase CLI are available:

```bash
deno fmt supabase/functions/ai-chat-route
deno lint supabase/functions/ai-chat-route
deno test supabase/functions/ai-chat-route
```

If a Step 2 SQL migration is added, review it and apply it to the configured
development Supabase project before manual acceptance:

```bash
supabase db push
```

If local Edge Function serving is used:

```bash
supabase functions serve ai-chat-route --env-file supabase/.env.local
```

If the local machine lacks Deno, Supabase CLI, Docker, or the local env file,
document exactly which backend command was skipped and continue with deployed
function acceptance instead. Do not skip `flutter analyze` or `flutter test`
after code changes.

## 9. Implementation Sequence

1. Review Step 1 outputs and current Phase 4 handoff.
   - Verify: Step 2 does not contradict the accepted Step 1 schema and
     contract.

2. Decide active-device session-id source.
   - Verify: a real test token exposes `session_id`, `sid`, or `jti`, and it
     matches `account_active_devices.active_session_id`.

3. Add the Edge Function skeleton and pure request/error helpers.
   - Verify: helper tests pass or manual parser checks are documented.

4. Add the mock provider.
   - Verify: it returns deterministic text and can simulate timeout/failure in
     tests without external network calls.

5. Add the persistence path.
   - Verify: successful turns create/reuse sessions, write two messages, write
     request logs, and write debug summaries.

6. Add blocked/error logging.
   - Verify: blocked account/device/schema cases do not create messages.

7. Optionally add a low-level Flutter client.
   - Verify: `AiPage` and send behavior remain unwired.

8. Run automatic validation.
   - Verify: Dart, Flutter, and available backend checks pass.

9. Run manual Supabase/Edge Function acceptance.
   - Verify: every check in Section 10 passes before Step 3 starts.

10. Prepare Step 2 handoff summary.
    - Verify: include changed files, validation results, manual acceptance
      results, known risks, and whether Step 3 may start.

## 10. Manual Acceptance Plan

Manual acceptance is required because Step 2 includes server auth,
subscription, active-device enforcement, service-role persistence, and deployed
or locally served Edge Function behavior that Flutter unit tests cannot prove.

Use a staging or development Supabase project. Do not run the first acceptance
pass against production.

### 10.0 Migration-Applied Verification Runbook

Use this quick runbook once the Step 2 SQL migration has already been applied
in Supabase. It is written for Windows PowerShell and `curl.exe`; for bash/zsh,
replace `$env:NAME` variables with shell variables and PowerShell backticks with
backslashes.

If the project was already migrated before
`202606290003_phase4_step2_service_role_grants.sql` or
`202606290004_phase4_step2_subscription_service_role_write.sql` existed, apply
those patch SQL files in Supabase SQL Editor before running Edge Function
acceptance. Without `003`, the deployed Gateway cannot read `subscriptions`
through the service role. Without `004`, the automated acceptance setup cannot
upsert A active / B inactive subscription rows. Both failures surface as
database permission errors instead of the stable Gateway contract.

The Supabase SQL Editor saved-query list is not the source of truth. The
source of truth is the repository migration files under `supabase/migrations/`.
After a patch query succeeds, it may be renamed for operator convenience, for
example `08_phase4_step2_service_role_grants_patch` and
`09_phase4_step2_subscription_service_role_write_patch`, or deleted from the
SQL Editor list to reduce clutter. Do not delete the repository migration files
and do not merge `003`/`004` back into `002` after they have been applied to a
project; preserving the separate files records the real migration order and
avoids future `db push` history confusion.

Do not paste real JWTs, anon keys, or service-role keys into public websites,
issue trackers, committed files, screenshots, or chat logs. The service-role
key should only be entered as a Supabase Function secret or in an uncommitted
local env file.

#### 10.0.1 Set Local Review Variables

In a local terminal, set only the public/test values needed for client-style
requests:

```powershell
$env:SUPABASE_URL = "https://<PROJECT_REF>.supabase.co"
$env:SUPABASE_ANON_KEY = "<SUPABASE_ANON_KEY>"
$env:FUNCTION_URL = "$env:SUPABASE_URL/functions/v1/ai-chat-route"

$env:USER_A_EMAIL = "<USER_A_EMAIL>"
$env:USER_A_PASSWORD = "<USER_A_PASSWORD>"
$env:USER_B_EMAIL = "<USER_B_EMAIL>"
$env:USER_B_PASSWORD = "<USER_B_PASSWORD>"

$env:DEVICE_A_ID = "phase4-step2-device-a"
$env:DEVICE_B_ID = "phase4-step2-device-b"
```

Expected result:

- `FUNCTION_URL` points to `.../functions/v1/ai-chat-route`.
- The service-role key is not stored in these variables unless you are using an
  uncommitted local function env file.

#### 10.0.2 Deploy Or Refresh The Edge Function

Dashboard option, for reviewers without a working Supabase CLI:

1. Open Supabase Dashboard.
2. Go to `Edge Functions`.
3. Create or open function `ai-chat-route`.
4. In Function settings, disable JWT verification for this function. This is
   required so unauthenticated requests reach the function and return the Step
   2 contract-shaped `401/auth_required` body.
5. Go to Function secrets and add:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
6. Put the contents of
   `supabase/functions/ai-chat-route/index.dashboard.ts` into the Dashboard
   function `index.ts`.
7. Deploy the function.

Dashboard pass criteria:

- Function name is exactly `ai-chat-route`.
- JWT verification is disabled for this function.
- All three secrets exist in Function secrets.
- No secret value is pasted into Flutter config, committed files, screenshots,
  or chat logs.
- Deployment succeeds without TypeScript/runtime startup errors.

If using the deployed Supabase project, configure Function secrets and deploy
from the repository root:

```powershell
supabase secrets set SUPABASE_URL="$env:SUPABASE_URL"
supabase secrets set SUPABASE_ANON_KEY="$env:SUPABASE_ANON_KEY"
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="<SERVICE_ROLE_KEY>"
supabase functions deploy ai-chat-route
```

If your Supabase CLI version does not read `supabase/config.toml` during
deploy, deploy with the explicit no-platform-JWT flag instead:

```powershell
supabase functions deploy ai-chat-route --no-verify-jwt
```

If using local Supabase CLI instead:

```powershell
supabase functions serve ai-chat-route --env-file supabase/.env.local
```

Expected result:

- Deploy/serve completes without startup errors.
- `SUPABASE_SERVICE_ROLE_KEY` is available only to the function runtime.
- The route is reachable at `$env:FUNCTION_URL`.
- Requests without `Authorization` reach the function and return the Step 2
  JSON body with `error.code = auth_required`. If Supabase returns a
  platform-shaped JWT error instead, redeploy with `verify_jwt = false` /
  `--no-verify-jwt`.

#### 10.0.3 Verify The Applied RPC Permission

Run this in Supabase SQL Editor:

```sql
select
  routine_schema,
  routine_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name = 'record_ai_mock_chat_turn'
order by grantee, privilege_type;
```

Expected result:

- The function exists.
- `postgres` may appear because it is the owner/admin role.
- `service_role` has `EXECUTE`.
- `anon` and ordinary `authenticated` do not have `EXECUTE`.

#### 10.0.4 Get User Tokens And Account IDs

Create or choose two Auth users:

- User A: should be AI-entitled with an active subscription.
- User B: should remain inactive for the subscription rejection check.

Then get password-grant access tokens:

```powershell
$accountAResponse = curl.exe -s -X POST "$env:SUPABASE_URL/auth/v1/token?grant_type=password" `
  -H "apikey: $env:SUPABASE_ANON_KEY" `
  -H "Content-Type: application/json" `
  -d "{`"email`":`"$env:USER_A_EMAIL`",`"password`":`"$env:USER_A_PASSWORD`"}"

$accountA = $accountAResponse | ConvertFrom-Json
$env:ACCOUNT_A_TOKEN = $accountA.access_token
$env:ACCOUNT_A_UUID = $accountA.user.id

$accountBResponse = curl.exe -s -X POST "$env:SUPABASE_URL/auth/v1/token?grant_type=password" `
  -H "apikey: $env:SUPABASE_ANON_KEY" `
  -H "Content-Type: application/json" `
  -d "{`"email`":`"$env:USER_B_EMAIL`",`"password`":`"$env:USER_B_PASSWORD`"}"

$accountB = $accountBResponse | ConvertFrom-Json
$env:ACCOUNT_B_TOKEN = $accountB.access_token
$env:ACCOUNT_B_UUID = $accountB.user.id
```

Decode the token payload locally and copy the session id claim:

```powershell
node -e "const t=process.env.ACCOUNT_A_TOKEN; const b=t.split('.')[1].replace(/-/g,'+').replace(/_/g,'/'); const p=JSON.parse(Buffer.from(b,'base64').toString('utf8')); console.log(JSON.stringify({sub:p.sub, session_id:p.session_id, sid:p.sid, jti:p.jti}, null, 2));"
node -e "const t=process.env.ACCOUNT_B_TOKEN; const b=t.split('.')[1].replace(/-/g,'+').replace(/_/g,'/'); const p=JSON.parse(Buffer.from(b,'base64').toString('utf8')); console.log(JSON.stringify({sub:p.sub, session_id:p.session_id, sid:p.sid, jti:p.jti}, null, 2));"
```

Set the session variables from the first non-empty value in this order:
`session_id`, then `sid`, then `jti`.

```powershell
$env:SESSION_A_ID = "<ACCOUNT_A_SESSION_ID_OR_SID_OR_JTI>"
$env:SESSION_B_ID = "<ACCOUNT_B_SESSION_ID_OR_SID_OR_JTI>"
```

Expected result:

- `$env:ACCOUNT_A_UUID` equals token A's `sub`.
- `$env:ACCOUNT_B_UUID` equals token B's `sub`.
- Each token has at least one of `session_id`, `sid`, or `jti`.

#### 10.0.5 Prepare Entitlement And Active Device Rows

Run this in Supabase SQL Editor, replacing placeholders with the PowerShell
values above:

```sql
insert into public.subscriptions (account_id, status, plan_id, provider)
values
  ('<ACCOUNT_A_UUID>', 'active', 'fitlog_ai_dev', 'internal_dev_entitlement'),
  ('<ACCOUNT_B_UUID>', 'inactive', 'fitlog_ai_dev', 'internal_dev_entitlement')
on conflict (account_id) do update
set status = excluded.status,
    plan_id = excluded.plan_id,
    provider = excluded.provider,
    updated_at = timezone('utc', now());

insert into public.cloud_profiles (
  account_id,
  display_name,
  diet_goal_phase,
  diet_calculation_mode,
  profile_version
)
values (
  '<ACCOUNT_A_UUID>',
  'Step2 User A',
  'cutting',
  'energy_ratio',
  1
)
on conflict (account_id) do nothing;

insert into public.account_active_devices (
  account_id,
  active_device_id,
  active_session_id,
  platform,
  app_version,
  claimed_at,
  last_seen_at,
  replaced_at,
  replaced_reason
)
values (
  '<ACCOUNT_A_UUID>',
  '<DEVICE_A_ID>',
  '<SESSION_A_ID>',
  'manual_acceptance',
  'phase4_step2',
  timezone('utc', now()),
  timezone('utc', now()),
  null,
  null
)
on conflict (account_id) do update
set active_device_id = excluded.active_device_id,
    active_session_id = excluded.active_session_id,
    platform = excluded.platform,
    app_version = excluded.app_version,
    claimed_at = excluded.claimed_at,
    last_seen_at = excluded.last_seen_at,
    replaced_at = null,
    replaced_reason = null;
```

Expected result:

- User A has `subscriptions.status = 'active'`.
- User B has `subscriptions.status = 'inactive'`.
- User A has an active-device row matching the token session claim.

#### 10.0.6 Run The Required Edge Function Curl Checks

The checks below validate the full Step 2 server path:

```text
HTTP request -> ai-chat-route -> Supabase auth check
             -> subscription check
             -> assert_active_device
             -> mock provider
             -> record_ai_mock_chat_turn
             -> ai_chat_sessions/messages/logs/debug summaries
```

Run these after:

- the Step 2 SQL migration is applied,
- the Edge Function is deployed or served,
- user A and user B tokens are available,
- user A has `subscriptions.status = 'active'`,
- user B has `subscriptions.status = 'inactive'`,
- user A has an `account_active_devices` row matching `<DEVICE_A_ID>` and
  `<SESSION_A_ID>`.

Unauthenticated request:

```powershell
curl.exe -i -X POST "$env:FUNCTION_URL" `
  -H "apikey: $env:SUPABASE_ANON_KEY" `
  -H "Content-Type: application/json" `
  -d "{`"message`":{`"text`":`"hello`"},`"language`":`"en`",`"model_choice`":`"chatgpt`",`"workflow_hint`":`"auto`",`"device_id`":`"$env:DEVICE_A_ID`"}"
```

Pass:

- HTTP `401`.
- JSON `error.code` is `auth_required`.
- No chat session/message is created.

Inactive subscription:

```powershell
curl.exe -i -X POST "$env:FUNCTION_URL" `
  -H "apikey: $env:SUPABASE_ANON_KEY" `
  -H "Authorization: Bearer $env:ACCOUNT_B_TOKEN" `
  -H "Content-Type: application/json" `
  -d "{`"message`":{`"text`":`"hello`"},`"language`":`"en`",`"model_choice`":`"chatgpt`",`"workflow_hint`":`"auto`",`"device_id`":`"$env:DEVICE_B_ID`"}"
```

Pass:

- HTTP `403`.
- JSON `error.code` is `subscription_required`.
- User B has no chat messages.

Simulate replaced device for user A:

```sql
update public.account_active_devices
set active_device_id = 'replacement-device',
    active_session_id = '<SESSION_A_ID>',
    replaced_at = timezone('utc', now()),
    replaced_reason = 'manual_acceptance_replacement'
where account_id = '<ACCOUNT_A_UUID>';
```

Then call with the old device id:

```powershell
curl.exe -i -X POST "$env:FUNCTION_URL" `
  -H "apikey: $env:SUPABASE_ANON_KEY" `
  -H "Authorization: Bearer $env:ACCOUNT_A_TOKEN" `
  -H "Content-Type: application/json" `
  -d "{`"message`":{`"text`":`"hello`"},`"language`":`"en`",`"model_choice`":`"chatgpt`",`"workflow_hint`":`"auto`",`"device_id`":`"$env:DEVICE_A_ID`"}"
```

Pass:

- HTTP `409`.
- JSON `error.code` is `device_replaced`.
- No chat message is created.

Restore user A's active device:

```sql
update public.account_active_devices
set active_device_id = '<DEVICE_A_ID>',
    active_session_id = '<SESSION_A_ID>',
    replaced_at = null,
    replaced_reason = null,
    last_seen_at = timezone('utc', now())
where account_id = '<ACCOUNT_A_UUID>';
```

Successful new session:

```powershell
$successBody = curl.exe -s -X POST "$env:FUNCTION_URL" `
  -H "apikey: $env:SUPABASE_ANON_KEY" `
  -H "Authorization: Bearer $env:ACCOUNT_A_TOKEN" `
  -H "Content-Type: application/json" `
  -d "{`"message`":{`"text`":`"What can I eat for dinner?`"},`"language`":`"en`",`"model_choice`":`"chatgpt`",`"workflow_hint`":`"auto`",`"selected_date`":`"2026-06-29`",`"profile_version`":`"profile_1`",`"device_id`":`"$env:DEVICE_A_ID`",`"client`":{`"app_version`":`"1.0.35+36`",`"platform`":`"android`",`"timezone`":`"Asia/Shanghai`"}}"

$success = $successBody | ConvertFrom-Json
$success | ConvertTo-Json -Depth 20
$env:NEW_SESSION_ID = $success.session_id
$env:DEBUG_SUMMARY_ID = $success.debug_summary_id
```

Pass:

- Response has no `error`.
- `model_provider` is `mock`.
- `message.text` is
  `This is a FitLog AI mock reply. Your text message was received.`
- `session_id`, `assistant_message_id`, and `debug_summary_id` are UUIDs.

Existing session reuse:

```powershell
$reuseBody = curl.exe -s -X POST "$env:FUNCTION_URL" `
  -H "apikey: $env:SUPABASE_ANON_KEY" `
  -H "Authorization: Bearer $env:ACCOUNT_A_TOKEN" `
  -H "Content-Type: application/json" `
  -d "{`"session_id`":`"$env:NEW_SESSION_ID`",`"message`":{`"text`":`"Add one more mock turn.`"},`"language`":`"en`",`"model_choice`":`"qwen`",`"workflow_hint`":`"meal_decision`",`"device_id`":`"$env:DEVICE_A_ID`"}"

$reuse = $reuseBody | ConvertFrom-Json
$reuse | ConvertTo-Json -Depth 20
```

Pass:

- Response `session_id` equals `$env:NEW_SESSION_ID`.
- `model_choice` is `qwen`.
- `model_provider` is still `mock`.
- The session has four messages with sequences `1`, `2`, `3`, `4`.

Future-scope rejection:

```powershell
curl.exe -i -X POST "$env:FUNCTION_URL" `
  -H "apikey: $env:SUPABASE_ANON_KEY" `
  -H "Authorization: Bearer $env:ACCOUNT_A_TOKEN" `
  -H "Content-Type: application/json" `
  -d "{`"message`":{`"text`":`"Please inspect this image.`"},`"language`":`"en`",`"model_choice`":`"chatgpt`",`"workflow_hint`":`"food_logging`",`"device_id`":`"$env:DEVICE_A_ID`",`"attachments`":[{`"kind`":`"image`",`"attachment_id`":`"future`"}],`"context_objects`":[{`"type`":`"selected_day_summary`",`"payload`":{}}],`"draft`":{`"schema_version`":`"food_draft.v1`"},`"official_record_write`":{`"kind`":`"food`"}}"
```

Pass:

- HTTP `422`.
- JSON `error.code` is `record_schema_mismatch`.
- No Food Draft or official food/workout/body/Profile record is written.

#### 10.0.7 Run Database Verification After Curl Checks

Run in Supabase SQL Editor:

```sql
select id, account_id, title, language, last_message_at, archived_at, deleted_at
from public.ai_chat_sessions
where id = '<NEW_SESSION_ID>';

select
  message_sequence,
  role,
  content_text,
  message_type,
  workflow_type,
  model_choice,
  model_provider,
  request_id,
  final_answer_json,
  attachments_metadata
from public.ai_chat_messages
where session_id = '<NEW_SESSION_ID>'
order by message_sequence, created_at, id;

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
where logs.session_id = '<NEW_SESSION_ID>'
order by logs.created_at, debug.created_at;

select count(*) as user_b_message_count
from public.ai_chat_messages
where account_id = '<ACCOUNT_B_UUID>';
```

Pass:

- Session row belongs to user A and is not deleted.
- After the two success calls, exactly four messages exist.
- Message sequences are `1`, `2`, `3`, `4`.
- User and assistant rows alternate in order.
- Assistant rows use `model_provider = 'mock'`.
- Logs use `model_provider = 'mock'`, `model = 'mock-provider-v1'`,
  `status = 'ok'`, `image_count = 0`, and no success `error_code`.
- User B message count is `0` unless user B was deliberately activated for a
  later cross-account check.

#### 10.0.8 Cross-Account Session Protection

Temporarily activate user B and set a matching active-device row:

```sql
update public.subscriptions
set status = 'active',
    updated_at = timezone('utc', now())
where account_id = '<ACCOUNT_B_UUID>';

insert into public.account_active_devices (
  account_id,
  active_device_id,
  active_session_id,
  platform,
  app_version,
  claimed_at,
  last_seen_at,
  replaced_at,
  replaced_reason
)
values (
  '<ACCOUNT_B_UUID>',
  '<DEVICE_B_ID>',
  '<SESSION_B_ID>',
  'manual_acceptance',
  'phase4_step2',
  timezone('utc', now()),
  timezone('utc', now()),
  null,
  null
)
on conflict (account_id) do update
set active_device_id = excluded.active_device_id,
    active_session_id = excluded.active_session_id,
    platform = excluded.platform,
    app_version = excluded.app_version,
    claimed_at = excluded.claimed_at,
    last_seen_at = excluded.last_seen_at,
    replaced_at = null,
    replaced_reason = null;
```

Invoke as B against A's session:

```powershell
curl.exe -i -X POST "$env:FUNCTION_URL" `
  -H "apikey: $env:SUPABASE_ANON_KEY" `
  -H "Authorization: Bearer $env:ACCOUNT_B_TOKEN" `
  -H "Content-Type: application/json" `
  -d "{`"session_id`":`"$env:NEW_SESSION_ID`",`"message`":{`"text`":`"This must not enter user A session.`"},`"language`":`"en`",`"model_choice`":`"chatgpt`",`"workflow_hint`":`"auto`",`"device_id`":`"$env:DEVICE_B_ID`"}"
```

Then restore B to inactive:

```sql
update public.subscriptions
set status = 'inactive',
    updated_at = timezone('utc', now())
where account_id = '<ACCOUNT_B_UUID>';
```

Pass:

- Request is rejected, preferably with `record_schema_mismatch`.
- User A's session does not receive a new message from user B.
- No row exists with `account_id = '<ACCOUNT_B_UUID>'` and
  `session_id = '<NEW_SESSION_ID>'`.

#### 10.0.9 Log/Debug Safety And Client Access

Run in Supabase SQL Editor:

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

select
  request_id,
  account_id,
  session_id,
  workflow_type,
  model_choice,
  model_provider,
  model,
  status,
  error_code,
  latency_ms,
  token_estimate,
  image_count,
  created_at
from public.ai_request_logs
order by created_at desc
limit 20;
```

Pass:

- Sensitive-column search returns zero rows.
- Reviewed log rows do not contain JWTs, service-role keys, provider keys, raw
  payloads, provider traces, stack traces, chain-of-thought, or unrestricted
  context dumps.
- `token_estimate` is allowed because it is a usage estimate, not an auth token.

Check that an authenticated client cannot read logs/debug tables directly:

```powershell
curl.exe -i "$env:SUPABASE_URL/rest/v1/ai_request_logs?select=*&limit=1" `
  -H "apikey: $env:SUPABASE_ANON_KEY" `
  -H "Authorization: Bearer $env:ACCOUNT_A_TOKEN"

curl.exe -i "$env:SUPABASE_URL/rest/v1/ai_debug_summaries?select=*&limit=1" `
  -H "apikey: $env:SUPABASE_ANON_KEY" `
  -H "Authorization: Bearer $env:ACCOUNT_A_TOKEN"
```

Pass:

- Direct client reads are rejected by missing grants/RLS, or return no readable
  rows. They must not expose request logs or debug summaries to the client.

#### 10.0.10 UI Non-Wiring Smoke Check

Run a configured app build if available:

```powershell
flutter run --dart-define-from-file=config/supabase.local.json
```

Manual UI operations:

1. Sign in as user A.
2. Open the AI tab.
3. Type text into the composer.
4. Try any visible send affordance.
5. Return to Supabase SQL Editor and check whether new chat rows appeared.

Pass:

- The App UI still does not send to `ai-chat-route` in Step 2.
- No mock assistant reply appears in the AI page.
- Opening the page or typing a draft does not create a chat session/message.
- Provider selection remains UI-only until Step 3.

Useful code checks:

```powershell
rg -n "ai-chat-route|functions.invoke|AiGatewayClient|sendMessage|canSend|onSend" lib/features/ai lib/data lib/app.dart
rg -n "CREATE TABLE.*ai_chat|AppDatabase.dbVersion|ai_chat" lib/data/db lib
```

Pass:

- No `AiPage` send wiring exists yet.
- No local SQLite chat-history table exists.
- `AppDatabase.dbVersion` is unchanged unless a separate SQLite change was
  explicitly approved.

After this quick runbook passes, continue through Sections 10.8-10.19 for a
full acceptance record, especially the deleted-session rejection in Section
10.14. Do not start Step 3 until all required manual checks in Section 10 and
automatic checks in Section 10.19 have passed or have an explicitly documented
tooling blocker.

### 10.1 Required Inputs

The reviewer needs:

- A Supabase project with Phase 2, Phase 3, and Phase 4 Step 1 migrations
  applied.
- The Step 2 Edge Function deployed or served locally.
- If Step 2 adds a database RPC, the Step 2 migration applied.
- Supabase project URL: `<SUPABASE_URL>`.
- Supabase anon key: `<SUPABASE_ANON_KEY>`.
- Supabase service-role key available only to the function runtime, not to
  Flutter.
- Two Supabase Auth test users:
  - subscribed user A
  - unsubscribed user B
- Optional third subscribed user C for cross-account session checks, or
  temporarily activate user B for that one check.
- Account UUID for user A: `<ACCOUNT_A_UUID>`.
- Account UUID for user B: `<ACCOUNT_B_UUID>`.
- Account UUID for user C if used: `<ACCOUNT_C_UUID>`.
- Access token for user A: `<ACCOUNT_A_TOKEN>`.
- Access token for user B: `<ACCOUNT_B_TOKEN>`.
- Active device id for user A: `<DEVICE_A_ID>`.
- Current session id claim for user A: `<SESSION_A_ID>`.

Function URL:

```text
<FUNCTION_URL>
```

Use one of:

```text
http://127.0.0.1:54321/functions/v1/ai-chat-route
https://<PROJECT_REF>.supabase.co/functions/v1/ai-chat-route
```

### 10.2 Secret Hygiene Check

Before invoking the function, inspect the workspace:

```bash
rg -n "SERVICE_ROLE|service_role|SUPABASE_SERVICE_ROLE_KEY|OPENAI|QWEN|DASHSCOPE|api_key|secret" lib test supabase README.md docs
```

Pass criteria:

- No service-role key value is committed.
- No provider API key is committed.
- No Flutter file contains a provider key or service-role key.
- References to env variable names are acceptable.

If this check finds a real secret value, Step 2 fails until the secret is
rotated and removed from git history as appropriate.

### 10.3 Apply Step 2 Migration If Present

If Step 2 adds a migration, apply it:

```bash
supabase db push
```

Acceptable dashboard alternative:

- Open Supabase Dashboard.
- Go to SQL Editor.
- Paste the Step 2 migration SQL.
- Run it once.
- Re-run only if the migration is intentionally idempotent.

Pass criteria:

- Migration succeeds.
- Existing Step 1 tables remain available.
- No new authenticated client insert/update/delete policies are opened on
  `ai_chat_messages` to bypass the Gateway.
- Any new RPC intended only for the Gateway is not executable by `anon` or
  ordinary `authenticated` clients.

Suggested RPC permission check if a function is added:

```sql
select
  routine_schema,
  routine_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name like '%ai%chat%turn%'
order by routine_name, grantee;
```

Pass criteria:

- The Gateway persistence RPC is not broadly granted to `anon`.
- If it is not meant for direct client use, it is not granted to
  `authenticated`.

### 10.4 Deploy Or Serve The Edge Function

Local serve option:

```bash
supabase functions serve ai-chat-route --env-file supabase/.env.local
```

Deployed option:

```bash
supabase secrets set SUPABASE_URL=<SUPABASE_URL>
supabase secrets set SUPABASE_ANON_KEY=<SUPABASE_ANON_KEY>
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<SERVICE_ROLE_KEY>
supabase functions deploy ai-chat-route
```

Pass criteria:

- The function starts or deploys without syntax/runtime startup errors.
- The service-role key is supplied by function secrets or an uncommitted local
  env file.
- The function can be reached at `<FUNCTION_URL>`.

### 10.5 Prepare Test Users And Entitlements

Run as a service/owner SQL context, replacing placeholders:

```sql
insert into public.subscriptions (account_id, status, plan_id, provider)
values
  ('<ACCOUNT_A_UUID>', 'active', 'fitlog_ai_dev', 'internal_dev_entitlement'),
  ('<ACCOUNT_B_UUID>', 'inactive', 'fitlog_ai_dev', 'internal_dev_entitlement')
on conflict (account_id) do update
set status = excluded.status,
    plan_id = excluded.plan_id,
    provider = excluded.provider,
    updated_at = timezone('utc', now());

insert into public.cloud_profiles (
  account_id,
  display_name,
  diet_goal_phase,
  diet_calculation_mode,
  profile_version
)
values (
  '<ACCOUNT_A_UUID>',
  'Step2 User A',
  'cutting',
  'energy_ratio',
  1
)
on conflict (account_id) do nothing;
```

Pass criteria:

- User A has `subscriptions.status = 'active'`.
- User B has `subscriptions.status = 'inactive'`.
- User A has a Cloud Profile row if the function or later smoke flow expects
  one.

### 10.6 Obtain Test Access Tokens

One acceptable way is Supabase Auth password grant with test credentials:

```bash
curl -s -X POST "<SUPABASE_URL>/auth/v1/token?grant_type=password" \
  -H "apikey: <SUPABASE_ANON_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"email":"<USER_A_EMAIL>","password":"<USER_A_PASSWORD>"}'
```

Store the returned `access_token` as `<ACCOUNT_A_TOKEN>`.

Repeat for user B and store the returned `access_token` as
`<ACCOUNT_B_TOKEN>`.

Pass criteria:

- Both tokens are current access tokens for the intended test users.
- The decoded token `sub` claim matches the expected account UUID.
- The decoded token exposes `session_id`, `sid`, or `jti`.

Suggested local token claim check:

```bash
node -e "const p=JSON.parse(Buffer.from(process.argv[1].split('.')[1], 'base64url').toString('utf8')); console.log(JSON.stringify({sub:p.sub, session_id:p.session_id, sid:p.sid, jti:p.jti}, null, 2))" "<ACCOUNT_A_TOKEN>"
```

Pass criteria:

- `sub` equals `<ACCOUNT_A_UUID>`.
- One of `session_id`, `sid`, or `jti` is present.
- The function implementation uses the same claim source for
  `assert_active_device`.

If Node is unavailable, decode the JWT payload with any trusted local tool. Do
not paste real tokens into public websites.

### 10.7 Prepare Active Device State

Set a known active device for user A. Use the session id claim from the token.

Run as service/owner SQL context:

```sql
insert into public.account_active_devices (
  account_id,
  active_device_id,
  active_session_id,
  platform,
  app_version,
  claimed_at,
  last_seen_at,
  replaced_at,
  replaced_reason
)
values (
  '<ACCOUNT_A_UUID>',
  '<DEVICE_A_ID>',
  '<SESSION_A_ID>',
  'manual_acceptance',
  'phase4_step2',
  timezone('utc', now()),
  timezone('utc', now()),
  null,
  null
)
on conflict (account_id) do update
set active_device_id = excluded.active_device_id,
    active_session_id = excluded.active_session_id,
    platform = excluded.platform,
    app_version = excluded.app_version,
    claimed_at = excluded.claimed_at,
    last_seen_at = excluded.last_seen_at,
    replaced_at = null,
    replaced_reason = null;
```

Pass criteria:

- The active-device row for user A matches `<DEVICE_A_ID>` and
  `<SESSION_A_ID>`.
- A request using the same token and device id should pass the active-device
  guard.

### 10.8 Unauthenticated Request Rejection

Invoke without `Authorization`:

```bash
curl -i -X POST "<FUNCTION_URL>" \
  -H "apikey: <SUPABASE_ANON_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"message":{"text":"hello"},"language":"en","model_choice":"chatgpt","workflow_hint":"auto","device_id":"<DEVICE_A_ID>"}'
```

Pass criteria:

- HTTP status is `401`.
- Response body parses as the Step 1 response contract.
- `error.code` is `auth_required`.
- No chat session is created.
- No chat message is created.
- No log row with a fake or null account is created.
- Response does not expose stack traces, JWT parsing internals, or service-role
  secrets.

### 10.9 Subscription Rejection

Invoke as inactive user B:

```bash
curl -i -X POST "<FUNCTION_URL>" \
  -H "apikey: <SUPABASE_ANON_KEY>" \
  -H "Authorization: Bearer <ACCOUNT_B_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"message":{"text":"hello"},"language":"en","model_choice":"chatgpt","workflow_hint":"auto","device_id":"device-b"}'
```

Pass criteria:

- HTTP status is `403`.
- `error.code` is `subscription_required`.
- No `ai_chat_sessions` row is created for user B.
- No `ai_chat_messages` row is created for user B.
- A blocked `ai_request_logs` row for user B may exist with:
  - `status = 'blocked'`
  - `error_code = 'subscription_required'`
  - no secret or raw request payload.
- A compact debug summary may exist and must be safe.

Database check:

```sql
select status, error_code, model_provider, image_count, created_at
from public.ai_request_logs
where account_id = '<ACCOUNT_B_UUID>'
order by created_at desc
limit 5;

select count(*) as message_count
from public.ai_chat_messages
where account_id = '<ACCOUNT_B_UUID>';
```

### 10.10 Active-Device Rejection

First, simulate replacement for user A:

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
curl -i -X POST "<FUNCTION_URL>" \
  -H "apikey: <SUPABASE_ANON_KEY>" \
  -H "Authorization: Bearer <ACCOUNT_A_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"message":{"text":"hello"},"language":"en","model_choice":"chatgpt","workflow_hint":"auto","device_id":"<DEVICE_A_ID>"}'
```

Pass criteria:

- HTTP status is `409`.
- `error.code` is `device_replaced`.
- No new session is created.
- No new message is created.
- A blocked `ai_request_logs` row for user A may exist with
  `error_code = 'device_replaced'`.
- The error is distinct from generic network/provider failure.

Restore active state before success tests:

```sql
update public.account_active_devices
set active_device_id = '<DEVICE_A_ID>',
    active_session_id = '<SESSION_A_ID>',
    replaced_at = null,
    replaced_reason = null,
    last_seen_at = timezone('utc', now())
where account_id = '<ACCOUNT_A_UUID>';
```

### 10.11 Successful New Session Request

Invoke as subscribed active user A with no `session_id`:

```bash
curl -i -X POST "<FUNCTION_URL>" \
  -H "apikey: <SUPABASE_ANON_KEY>" \
  -H "Authorization: Bearer <ACCOUNT_A_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"message":{"text":"What can I eat for dinner?"},"language":"en","model_choice":"chatgpt","workflow_hint":"auto","selected_date":"2026-06-29","profile_version":"profile_1","device_id":"<DEVICE_A_ID>","client":{"app_version":"1.0.35+36","platform":"android","timezone":"Asia/Shanghai"}}'
```

Capture from the response:

- `<NEW_SESSION_ID>` from `session_id`.
- `<ASSISTANT_MESSAGE_ID>` from `assistant_message_id`.
- `<DEBUG_SUMMARY_ID>` from `debug_summary_id`.

Response pass criteria:

- HTTP status is `200`.
- `error` is null.
- `session_id` is a UUID.
- `assistant_message_id` is a UUID.
- `model_choice` is `chatgpt`.
- `model_provider` is `mock`.
- `message.text` equals the agreed mock provider text.
- `message.language` is `en`.
- `workflow` is `auto`.
- `draft` is null.
- `debug_summary_id` is a UUID.

Database session check:

```sql
select id, account_id, title, language, last_message_at, archived_at, deleted_at
from public.ai_chat_sessions
where id = '<NEW_SESSION_ID>';
```

Pass criteria:

- Exactly one row exists.
- `account_id` equals `<ACCOUNT_A_UUID>`.
- `language` is `en`.
- `deleted_at` is null.
- `last_message_at` is not null.

Database message check:

```sql
select
  id,
  message_sequence,
  role,
  content_text,
  message_type,
  workflow_type,
  model_choice,
  model_provider,
  request_id,
  final_answer_json,
  attachments_metadata
from public.ai_chat_messages
where session_id = '<NEW_SESSION_ID>'
order by message_sequence, created_at, id;
```

Pass criteria:

- Exactly two rows exist.
- Sequence `1` is role `user`.
- Sequence `2` is role `assistant`.
- User content equals the request text.
- Assistant content equals the fixed mock reply.
- `message_type` is `text` for both rows.
- `workflow_type` is `auto` for both rows.
- `model_choice` is `chatgpt` for both rows or at least for the assistant row,
  depending on final implementation.
- `model_provider` is `mock` for the assistant row.
- `final_answer_json` is null.
- `attachments_metadata` is `[]`.

Database log/debug check:

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
where debug.id = '<DEBUG_SUMMARY_ID>';
```

Pass criteria:

- Exactly one joined row exists.
- `logs.account_id` equals `<ACCOUNT_A_UUID>`.
- `logs.session_id` equals `<NEW_SESSION_ID>`.
- `logs.model_provider` is `mock`.
- `logs.model` is a stable mock identifier, for example `mock-provider-v1`.
- `logs.status` is `ok`.
- `logs.error_code` is null.
- `logs.image_count` is `0`.
- `logs.latency_ms` is non-negative or null only if deliberately not recorded.
- Debug JSON fields are arrays.
- Debug summary is compact and does not contain raw request body, auth token, or
  provider trace.

### 10.12 Existing Session Reuse

Invoke again with `<NEW_SESSION_ID>`:

```bash
curl -i -X POST "<FUNCTION_URL>" \
  -H "apikey: <SUPABASE_ANON_KEY>" \
  -H "Authorization: Bearer <ACCOUNT_A_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"session_id":"<NEW_SESSION_ID>","message":{"text":"Add one more mock turn."},"language":"en","model_choice":"qwen","workflow_hint":"meal_decision","device_id":"<DEVICE_A_ID>"}'
```

Pass criteria:

- HTTP status is `200`.
- Response `session_id` equals `<NEW_SESSION_ID>`.
- Response `model_choice` is `qwen`.
- Response `model_provider` is still `mock`.
- No second session is created for this request.

Database check:

```sql
select message_sequence, role, content_text, model_choice, model_provider
from public.ai_chat_messages
where session_id = '<NEW_SESSION_ID>'
order by message_sequence, created_at, id;
```

Pass criteria:

- Exactly four rows exist after two successful requests.
- Sequences are `1`, `2`, `3`, `4`.
- Rows `3` and `4` are the second user/assistant pair.
- There are no duplicate `message_sequence` values.

### 10.13 Cross-Account Session Rejection

Use a second subscribed active account if available. If only user B exists,
temporarily activate user B for this check and set an active-device row matching
user B's token session claim.

Temporary activation for user B:

```sql
update public.subscriptions
set status = 'active',
    updated_at = timezone('utc', now())
where account_id = '<ACCOUNT_B_UUID>';
```

Set user B active device with token session claim `<SESSION_B_ID>`:

```sql
insert into public.account_active_devices (
  account_id,
  active_device_id,
  active_session_id,
  platform,
  app_version,
  claimed_at,
  last_seen_at,
  replaced_at,
  replaced_reason
)
values (
  '<ACCOUNT_B_UUID>',
  'device-b-active',
  '<SESSION_B_ID>',
  'manual_acceptance',
  'phase4_step2',
  timezone('utc', now()),
  timezone('utc', now()),
  null,
  null
)
on conflict (account_id) do update
set active_device_id = excluded.active_device_id,
    active_session_id = excluded.active_session_id,
    platform = excluded.platform,
    app_version = excluded.app_version,
    claimed_at = excluded.claimed_at,
    last_seen_at = excluded.last_seen_at,
    replaced_at = null,
    replaced_reason = null;
```

Invoke as user B against user A's session:

```bash
curl -i -X POST "<FUNCTION_URL>" \
  -H "apikey: <SUPABASE_ANON_KEY>" \
  -H "Authorization: Bearer <ACCOUNT_B_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"session_id":"<NEW_SESSION_ID>","message":{"text":"This must not enter user A session."},"language":"en","model_choice":"chatgpt","workflow_hint":"auto","device_id":"device-b-active"}'
```

Pass criteria:

- HTTP status is `422`, `403`, or `404` depending on final implementation, but
  the stable error code must not be `provider_failure`.
- Preferred `error.code` is `record_schema_mismatch` unless a more precise
  stable code was added and tested.
- No message is appended to user A's session.
- No message row exists with `account_id = '<ACCOUNT_B_UUID>'` and
  `session_id = '<NEW_SESSION_ID>'`.
- Service-role persistence did not bypass account ownership.

Restore user B inactive after the check if user B is the inactive-subscription
test account:

```sql
update public.subscriptions
set status = 'inactive',
    updated_at = timezone('utc', now())
where account_id = '<ACCOUNT_B_UUID>';
```

### 10.14 Deleted Session Rejection

Soft-delete the test session:

```sql
update public.ai_chat_sessions
set deleted_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
where id = '<NEW_SESSION_ID>'
  and account_id = '<ACCOUNT_A_UUID>';
```

Invoke as user A against the deleted session:

```bash
curl -i -X POST "<FUNCTION_URL>" \
  -H "apikey: <SUPABASE_ANON_KEY>" \
  -H "Authorization: Bearer <ACCOUNT_A_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"session_id":"<NEW_SESSION_ID>","message":{"text":"This must not append to a deleted session."},"language":"en","model_choice":"chatgpt","workflow_hint":"auto","device_id":"<DEVICE_A_ID>"}'
```

Pass criteria:

- Request is rejected.
- Preferred `error.code` is `record_schema_mismatch` unless a more precise
  stable code was added and tested.
- No new message is appended under the deleted session.
- Deleted session remains hidden from authenticated client reads.

If the session is needed for later manual checks, create a new successful
session after this test instead of clearing `deleted_at`.

### 10.15 Future-Scope Rejection

Invoke with unsupported Step 4+ fields:

```bash
curl -i -X POST "<FUNCTION_URL>" \
  -H "apikey: <SUPABASE_ANON_KEY>" \
  -H "Authorization: Bearer <ACCOUNT_A_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"message":{"text":"Please inspect this image."},"language":"en","model_choice":"chatgpt","workflow_hint":"food_logging","device_id":"<DEVICE_A_ID>","attachments":[{"kind":"image","attachment_id":"future"}],"context_objects":[{"type":"selected_day_summary","payload":{}}],"draft":{"schema_version":"food_draft.v1"},"official_record_write":{"kind":"food"}}'
```

Pass criteria:

- Request is rejected.
- Preferred HTTP status is `422`.
- Preferred `error.code` is `record_schema_mismatch`.
- No chat session or message is created for this request.
- No Food Draft is exposed as saveable output.
- No food/workout/body/Profile official table is written.
- Logs/debug summaries, if written, contain only compact safe metadata.

Business table safety check:

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

- Counts do not increase because Step 2 must not write official business
  records.

### 10.16 Log And Debug Safety Review

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

- Query returns zero rows.
- `token_estimate` remains acceptable because it is a compact usage estimate,
  not an auth/provider token.

Sample recent logs:

```sql
select
  request_id,
  account_id,
  session_id,
  workflow_type,
  model_choice,
  model_provider,
  model,
  status,
  error_code,
  latency_ms,
  token_estimate,
  image_count,
  created_at
from public.ai_request_logs
order by created_at desc
limit 20;
```

Pass criteria:

- No provider key, service-role key, JWT, stack trace, chain-of-thought, raw
  request body, or unrestricted context dump appears in any reviewed field.
- Success, blocked, and error statuses are distinguishable.
- `model_provider` is `mock` for Step 2 success.
- `image_count` remains `0`.

### 10.17 Authenticated Client Access Review

Run as simulated authenticated user A, or use the REST API with user A's JWT:

```sql
begin;
set local role authenticated;
set local request.jwt.claim.sub = '<ACCOUNT_A_UUID>';

select id, account_id, title, deleted_at
from public.ai_chat_sessions
order by updated_at desc;

select session_id, account_id, message_sequence, role, content_text
from public.ai_chat_messages
order by created_at, message_sequence, id;

select *
from public.ai_request_logs;

select *
from public.ai_debug_summaries;

commit;
```

Pass criteria:

- User A can read own non-deleted sessions/messages.
- User A cannot read user B sessions/messages.
- User A cannot directly read `ai_request_logs`.
- User A cannot directly read `ai_debug_summaries`.

If the SQL Editor cannot simulate `authenticated` role with JWT claims, use
Supabase REST API requests with user JWTs. The pass criteria are the same.

### 10.18 UI Non-Wiring Check

Run a configured app build or debug run if available:

```bash
flutter run --dart-define-from-file=config/supabase.local.json
```

Manual UI operations:

1. Sign in as subscribed user A.
2. Ensure Profile/Cloud Profile is ready.
3. Open the AI tab.
4. Type text into the composer.
5. Observe the send control and Gateway status.
6. Try to trigger send if any apparent send affordance is visible.

Pass criteria:

- The AI page still communicates that AI Gateway sending is not connected from
  the app UI yet, or otherwise prevents send.
- Typing a draft does not call the Edge Function.
- No chat row is created merely by opening the AI page or typing a draft.
- No mock assistant response appears in the app UI in Step 2.
- The provider selector remains a UI selection only until Step 3 wiring.
- There is no raw error, stack trace, or internal debug summary shown in the
  user UI.

Useful code review searches:

```bash
rg -n "ai-chat-route|functions.invoke|AiGatewayClient|sendMessage|canSend|onSend" lib/features/ai lib/data lib/app.dart
rg -n "CREATE TABLE.*ai_chat|AppDatabase.dbVersion|ai_chat" lib/data/db lib
```

Pass criteria:

- Any `AiGatewayClient` remains unwired from `AiPage`.
- No app-level dependency injection makes the AI page send.
- No local SQLite chat-history table is introduced.
- `AppDatabase.dbVersion` is unchanged unless a separate local SQLite change
  was explicitly approved.

### 10.19 Automatic Validation Acceptance

Run:

```bash
dart format lib test
flutter analyze
flutter test
```

Pass criteria:

- Formatting completes.
- Analysis reports no issues.
- All Flutter tests pass.

Run backend checks if tooling is available:

```bash
deno fmt supabase/functions/ai-chat-route
deno lint supabase/functions/ai-chat-route
deno test supabase/functions/ai-chat-route
```

Pass criteria:

- Formatting completes.
- Lint reports no issues.
- Backend tests pass.

If backend tooling is not available, the Step 2 handoff must explicitly say
which command could not run and why. Manual deployed-function acceptance still
must pass.

## 11. Step 2 Exit Criteria

Step 2 is complete only when all of these are true:

- The Edge Function or server endpoint exists.
- Auth is verified server-side.
- Subscription entitlement is verified server-side.
- Active-device status is verified server-side.
- Subscribed active user can receive the fixed mock response.
- New-session success creates one session, one user message, one assistant
  message, one request log, and one debug summary.
- Existing-session success appends messages with deterministic sequences.
- Inactive subscription is blocked and does not create messages.
- Replaced device is blocked with `device_replaced` and does not create
  messages.
- Cross-account session reuse is blocked even though the server uses
  service-role persistence.
- Unsupported future-scope fields are rejected.
- Logs/debug summaries are compact and sanitized.
- Authenticated clients still cannot read request logs or debug summaries.
- The app UI still cannot send AI messages.
- No real provider call exists.
- No provider key exists in Flutter or committed config.
- No RAG, image upload, Food Draft, or official business write exists.
- No local SQLite chat-history storage is introduced.
- `dart format lib test` has run.
- `flutter analyze` passes.
- `flutter test` passes.
- Backend formatting/lint/tests pass where local tooling is available, or the
  tooling blocker is documented.
- Manual acceptance in Section 10 passes.

If any item fails, do not start Step 3.

## 12. Do Not Proceed If

Do not proceed to Step 3 if:

- Subscription is enforced only by Flutter UI state.
- Active-device replacement can still send AI messages.
- Service-role writes can append to another account's session.
- Failed or blocked requests create chat messages.
- Message sequence assignment can duplicate under normal repeated sends.
- Logs contain provider keys, service-role keys, auth tokens, raw payloads,
  stack traces, chain-of-thought, or unrestricted context dumps.
- Error responses expose raw Deno/Supabase/provider internals to the user.
- Mock responses are shown through the AI page UI.
- AI page send is enabled.
- RAG, image upload, Food Draft, or business-write behavior slips into the
  step.
- Flutter tests or analysis fail.

## 13. Step 2 Handoff Summary Template

At the end of the Step 2 implementation chat, report:

- Files changed.
- Function name and route.
- Any migration/RPC name added.
- Auth verification approach.
- Subscription check approach.
- Active-device session-id source and verification result.
- Persistence approach and sequence-safety decision.
- What was intentionally not implemented.
- Automatic validation commands and results.
- Manual acceptance results for:
  - unauthenticated rejection
  - inactive subscription rejection
  - device replacement rejection
  - successful new session
  - existing session reuse
  - cross-account session rejection
  - future-scope rejection
  - log/debug safety
  - UI non-wiring
- Known risks or follow-up items.
- Whether Step 3 may start.
