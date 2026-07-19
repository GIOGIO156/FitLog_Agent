# Phase 4 Gateway Handoff

This file is a handoff checklist for future implementation chats. It is not the stable product source of truth. Stable scope and architecture still live in `docs/ROADMAP.md`, `docs/API_CONTRACT_DRAFT.md`, and the bilingual docs under `docs/en` and `docs/zh`.

Phase 4 should be implemented in four reviewable steps. Each step should end with automatic validation plus a manual acceptance pass before the next step starts.

## Phase 4 Boundary

Phase 4 goal:

- AI Chat can send text messages.
- The server calls the selected remote provider.
- Cloud chat sessions and messages persist after login.
- Request metadata and compact debug summaries are stored server-side.
- Subscription and active-device checks are enforced by the server.

Phase 4 must not implement:

- Structured RAG.
- Document RAG.
- Food image attachment upload.
- Food Draft generation.
- Any official food/workout/body/Profile write from AI output.
- Business-record summary context upload.
- Local long-term chat history storage.
- User-supplied model API keys.
- Open-ended Agent loops or multi-agent orchestration.

The app may keep the current editable composer and provider selector, but send must only become enabled when the Gateway path is actually wired and server checks are in place.

## Shared Rules For All Steps

- Preserve current Local and Agent behavior unless the step explicitly changes it.
- Keep server-managed model keys only on the backend.
- Keep Cloud Records as the signed-in source of truth.
- Keep local SQLite as partial cache, drafts, and runtime acceleration only.
- Do not bump local `AppDatabase.dbVersion` unless local SQLite schema or persisted local semantics change.
- Do not add RAG, images, Food Drafts, or business writes as "small extras".
- Do not expose provider raw errors, stack traces, or debug summaries to user UI.
- Do not store chain-of-thought.
- Do not rely on client-side subscription state for authorization; server must enforce entitlement again.
- Keep `device_replaced` distinct from generic network or save failures.
- Use stable error codes and user-readable mapped messages.
- For OpenAI/Qwen details during implementation, verify current official provider docs/consoles before choosing exact model names or environment variable names.

## Step 1: Data And Contract Foundation

### Objective

Create the backend data model and Flutter contract layer for AI chat history and Gateway payloads, without enabling real chat sending in the app.

### Scope

Backend/Supabase:

- Add a Supabase migration for `ai_chat_sessions`.
- Add a Supabase migration for `ai_chat_messages`.
- Add a Supabase migration for `ai_request_logs`.
- Add a Supabase migration for `ai_debug_summaries`.
- Add account isolation with `account_id`.
- Add RLS policies for own-row access where client reads are allowed.
- Add archive/delete semantics for sessions.
- Add ordered message retrieval fields.
- Add timestamps and indexes.

Flutter:

- Add domain models:
  - `AiChatSession`
  - `AiChatMessage`
  - `AiGatewayRequest`
  - `AiGatewayResponse`
  - `AiGatewayError` or equivalent stable error model
- Add mappers for request/response JSON.
- Add contract tests for model serialization and error mapping.

### Suggested Files

Likely additions:

- `supabase/migrations/*_phase4_ai_chat.sql`
- `lib/domain/models/ai_chat_session.dart`
- `lib/domain/models/ai_chat_message.dart`
- `lib/domain/models/ai_gateway_request.dart`
- `lib/domain/models/ai_gateway_response.dart`
- `test/ai_gateway_contract_test.dart`

Do not wire `AiPage` send behavior yet, except for test-only model coverage if needed.

### Automatic Validation

Run:

```bash
dart format lib test
flutter analyze
flutter test
```

If only SQL and model tests are changed, targeted tests are acceptable during the inner loop, but the step should finish with full `flutter analyze` and `flutter test`.

### Manual Acceptance

The user should run the migration against the configured Supabase project and check:

- Tables exist.
- RLS is enabled where expected.
- One account cannot read another account's chat rows.
- Message order is stable by `created_at` plus a deterministic tiebreaker.
- Session archive/delete does not remove unrelated messages or accounts.
- Request log/debug summary tables do not expose sensitive internals through client policies.

### Do Not Proceed If

- RLS is ambiguous or missing.
- Chat rows can cross accounts.
- The schema cannot represent both user and assistant messages.
- The contract still assumes RAG context, images, or Food Draft output.
- Flutter tests or analysis fail.

## Step 2: Gateway Skeleton With Mock Provider

### Objective

Build the server Gateway path and session/message APIs using a mock provider response. This validates auth, subscription, active device, persistence, logging, and error boundaries before involving real model providers.

### Scope

Backend:

- Add the AI Gateway endpoint or Supabase Edge Function entry.
- Verify Supabase auth token.
- Verify current account entitlement on the server.
- Verify active device/session on the server.
- Create a session when needed.
- Save the user message.
- Return a fixed mock assistant response.
- Save the assistant message.
- Save request metadata.
- Save a compact debug summary.
- Map stable error codes:
  - `auth_required`
  - `subscription_required`
  - `device_replaced`
  - `gateway_timeout`
  - `provider_failure`
  - `record_schema_mismatch` or schema-specific equivalent

Flutter:

- Add a low-level client if useful for integration tests, but do not replace the AI page's UI flow yet unless Step 3 begins.
- Keep the current send button behavior unchanged if the app is not ready to consume the endpoint.

### Suggested Files

Likely additions depend on the Supabase function layout selected by the implementer:

- `supabase/functions/ai-chat-route/*`
- backend helper modules for auth, subscription, active-device, provider mock, and logging
- optional `lib/data/remote/ai_gateway_client.dart`
- optional `test/ai_gateway_client_test.dart`

### Automatic Validation

Run:

```bash
dart format lib test
flutter analyze
flutter test
```

Backend checks may need Supabase CLI or a project dashboard. If local Edge Function execution is used, document the command and result in the step summary.

### Manual Acceptance

Using configured Supabase accounts:

- Unauthenticated request is rejected.
- Inactive subscription is rejected.
- Replaced device/session is rejected with `device_replaced`.
- Subscribed active account receives the mock assistant reply.
- `ai_chat_sessions` row is created or reused correctly.
- `ai_chat_messages` contains user and assistant messages in order.
- `ai_request_logs` contains metadata without raw secrets.
- `ai_debug_summaries` contains compact operational summary only.
- User UI does not show internal traces.

### Do Not Proceed If

- Client-side gating is the only subscription check.
- Active-device replacement can still send AI messages.
- Mock responses do not persist as cloud chat history.
- Logs contain provider keys, auth tokens, chain-of-thought, or unrestricted raw context.
- Error codes are unstable or provider-shaped.

## Step 3: Flutter AI Chat Integration

### Objective

Connect the Flutter AI page to the Gateway and cloud chat history, still using the mock provider from Step 2. This is the first step where the user can manually test chat send behavior in the app.

### Scope

Flutter:

- Add `AiGatewayClient`.
- Add `AiChatRepository`.
- Add chat state controller for:
  - selected session
  - message list
  - loading state
  - sending state
  - pending user message
  - assistant success
  - send failure
  - retry
  - session switching
  - session archive/delete
  - logout/account-switch cleanup
- Enable send only when:
  - logged in
  - online
  - active device
  - Cloud Profile ready
  - subscription active
  - Gateway is configured
- Keep text draft runtime-local until successful send.
- Keep chat history cloud-backed, not long-term local.
- Replace the history placeholder with real session list.
- Add new session, session switch, archive/delete.
- Keep AI reply as text only.
- Keep attachment button disabled.
- Keep RAG/Food Draft/business-write paths absent.

UI:

- Show pending user message immediately.
- Append assistant message on success.
- Show stable error state on failure.
- Allow retry where safe.
- Preserve keyboard and animated background behavior.
- Keep message content above composer and nav pill.

### Suggested Files

Likely additions/changes:

- `lib/data/remote/ai_gateway_client.dart`
- `lib/data/repositories/ai_chat_repository.dart`
- `lib/features/ai/ai_chat_controller.dart`
- `lib/features/ai/widgets/chat_message_bubble.dart`
- `lib/features/ai/widgets/chat_history_panel.dart`
- `lib/features/ai/ai_page.dart`
- `lib/core/localization/app_strings.dart`
- `test/ai_chat_controller_test.dart`
- `test/ai_page_test.dart`

### Automatic Validation

Run:

```bash
dart format lib test
flutter analyze
flutter test
```

If UI layout changes are substantial, add focused widget tests for narrow/mobile widths and composer/history behavior.

### Manual Acceptance

On a configured build with the Step 2 mock Gateway:

- Subscribed account can send a text message.
- User message appears pending immediately.
- Mock assistant reply appears after success.
- Restarting the app and reopening AI history shows the cloud session.
- Switching sessions loads the right messages.
- New session works.
- Archive/delete updates the history panel.
- Unsubscribed account cannot send.
- Signed-out user cannot send.
- Offline send fails gracefully and keeps the draft.
- Logout or account switch clears runtime draft/message state.
- AI reply does not create food/workout/body/Profile data.

### Do Not Proceed If

- Messages cross sessions or accounts.
- History disappears after restart.
- Failed send duplicates messages unexpectedly.
- Long-term local chat history is introduced.
- Business records are written by AI output.
- Composer or nav layout regresses.
- Tests or analysis fail.

## Step 4: Real Provider Adapters And Phase 4 Closure

### Objective

Replace the mock provider with server-side OpenAI/ChatGPT and Qwen provider adapters, then close Phase 4 documentation and validation.

### Scope

Backend:

- Add OpenAI provider adapter.
- Add Qwen provider adapter.
- Read provider API keys from server-side secrets only.
- Read model names from server-side environment/config.
- Keep Flutter using stable provider choices only.
- Normalize provider responses into the Phase 4 response contract.
- Map provider failures into stable error codes.
- Add timeouts.
- Add invalid-response handling.
- Ensure request logs do not store secrets, tokens, or chain-of-thought.

Flutter:

- Ensure provider selector sends stable model choice.
- Ensure provider errors show readable messages.
- Keep message retry behavior safe.
- Keep current no-RAG/no-Food-Draft boundary visible in code and tests.

Docs:

- Update `docs/en/AgentDesign.md` and `docs/zh/AgentDesign.md`.
- Update `docs/en/Database.md` and `docs/zh/Database.md`.
- Update `docs/en/AppGuide.md` and `docs/zh/AppGuide.md`.
- Update `README.md`.
- Update `CHANGELOG.md`.
- Mark AI Gateway and cloud chat history as implemented.
- Keep RAG, image attachments, Food Draft, and AI business writes as later phases.

### Suggested Files

Likely additions/changes:

- backend provider adapter modules under Supabase function code
- `lib/features/ai/ai_page.dart`
- `lib/data/remote/ai_gateway_client.dart`
- `lib/core/localization/app_strings.dart`
- README and bilingual docs listed above
- tests for provider choice, error mapping, and no-write boundaries

### Automatic Validation

Run:

```bash
dart format lib test
flutter analyze
flutter test
flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json
```

If `config/supabase.local.json` is not available in the workspace, document that the APK build was skipped because local Supabase config was unavailable.

### Manual Acceptance

With server secrets configured:

- ChatGPT/OpenAI provider returns a real assistant message.
- Qwen provider returns a real assistant message.
- Switching provider affects the server adapter used.
- Provider timeout maps to stable user-visible error.
- Provider invalid response maps to stable user-visible error.
- Provider raw error is not shown directly to users.
- Cloud history persists after app restart.
- Request logs/debug summaries are compact and safe.
- Unsubscribed account remains blocked by server.
- Replaced device remains blocked by server.
- AI replies do not create or modify food/workout/body/Profile records.
- RAG and Food Draft are still unavailable.

### Do Not Close Phase 4 If

- Model keys appear in Flutter code, local config committed to the repo, logs, or user UI.
- One provider can break the shared response contract.
- Error handling leaks raw provider traces.
- Chat history is stored long-term in local SQLite.
- RAG, image upload, Food Draft, or business writes slip into the phase.
- `flutter analyze`, `flutter test`, or the configured debug APK build fails.

## Final Phase 4 Acceptance Checklist

Phase 4 is complete only when all are true:

- Supabase AI chat tables are migrated and protected by RLS.
- Server Gateway enforces auth, subscription, and active-device checks.
- AI messages are persisted to cloud chat history.
- History list can create, load, switch, and archive/delete sessions.
- Flutter send path handles pending, success, error, and retry states.
- OpenAI/ChatGPT and Qwen provider choices work through server-side adapters.
- Server-managed model keys never enter Flutter.
- Request logs and compact debug summaries exist without sensitive internals.
- No RAG, images, Food Draft, or official business writes are implemented.
- README and bilingual docs reflect the exact implemented state.
- `flutter analyze` passes.
- `flutter test` passes.
- Configured debug split APK build passes or has a documented config blocker.

## Recommended Handoff Format After Each Step

Each implementation chat should end with:

- Files changed.
- What was intentionally not implemented.
- Automatic validation commands and results.
- Manual acceptance checklist for the user.
- Known risks or follow-up items.
- Whether it is safe to start the next step.
