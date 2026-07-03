# Agent Design

## Purpose

This document defines the AI and Agent boundary for FitLog_Agent V1.

FitLog_Agent starts from the copied FitLog Local implementation. The current codebase still provides deterministic food logging, workout logging, profile settings, diet algorithms, local cache, and export. The implemented Agent baseline includes the centered AI tab, account state, subscription status, Cloud Profile foundation, signed-in body/food/workout official records connected to the cloud source of truth, AI Chat through server-side OpenAI/Qwen providers, Qwen multimodal chat with up to three images, cloud chat history, inline Chat Food Draft and Workout Draft artifact cards, a compact same-chat context builder, and Add Food AI Food Analysis that creates an editable Food Draft from a text description and up to three optional images. It also adds Home selected-day summary cache with stale-while-revalidate, first-render account-bound cache binding after signed-in recovery, upserts rebuildable `daily_summaries` to the cloud, warms recent summaries after first render, exports from cloud official records, and writes compact AI request/debug summaries. RAG, more than three Chat images, long-term image storage, and autonomous actions are later phases. Agent V1 does not turn the app into an autonomous coach or a platform where the model can freely read and write the database.

The durable rule is:

```text
AI may draft, explain, retrieve context, and ask follow-up questions.
AI must not silently write official records, change goals, change strategies, or delete data.
```

## Current Implementation Baseline

The current source has no on-device model execution. Remote AI calls go through Supabase Edge Functions with server-managed provider keys. The implemented Agent shell/account baseline includes the AI navigation entry, availability-gated chat page, account/subscription status surface, Profile login gate, Cloud Profile mapper/repository path, and user-record summary permission. Cloud Records source-of-truth paths for signed-in body, food, and workout records plus daily-summary cache/cloud projection hardening are also implemented. Phase 4 Step 1 adds Supabase tables for AI chat sessions/messages, request logs, and compact debug summaries, plus Flutter contract models for AI Gateway request/response/error mapping. Phase 4 Steps 2-4 add the `ai-chat-route` Supabase Edge Function, server-owned chat-turn RPCs, AI-page Gateway client, cloud chat-history repository/controller, and server-side OpenAI/ChatGPT plus Qwen text provider routing. Phase 4 Step 5 adds local provider preference persistence, readiness-only status, inline chat rename/delete confirmation, and Add Food AI food analysis through `ai-food-photo-analyze`. Phase 4 Step 6 adds AI Chat attachments with up to three images through Qwen multimodal routing, parsed Food Draft responses, Chat artifact cards that rebuild Food Preview after a user tap, smoother AI-page background motion, and stable rename/loading transitions. The current Add Food analysis path accepts text-only food descriptions or up to three optional images, and it stores a tiny local picker-recovery marker before launching camera/gallery so Android activity restarts can restore the draft. The current chat path also supports typed Workout Draft artifacts that rebuild the existing workout editor draft after a user tap, and it sends a compact same-chat context made from recent text and draft summaries. The implemented chat path does not run RAG, upload full record history, store image bytes long-term, or write official business records automatically.

Not implemented in the current code:

- embeddings
- vector database
- app-internal RAG
- more than three Chat image attachments
- record-summary/context retrieval for AI answers beyond compact same-chat text and draft summaries
- tool calling
- Agent loop
- long-term semantic AI conversation memory
- Agent action/debug workflows beyond compact request summaries
- production payment provider or subscription management

Existing AI-adjacent features are user-mediated, not app-internal AI:

| Feature | Current behavior | App-internal AI? | Main code |
| --- | --- | --- | --- |
| Prompt template text | The app keeps external-model guidance text for fallback copy/paste wording, but Add Food no longer exposes prompt copy as the primary flow. | No | `PromptTemplates`, `AppStrings` |
| External AI JSON paste | The user manually pastes JSON produced outside the app. FitLog parses it locally. | No | `PasteAiResultPage`, `NutritionCalculator.parseAiFoodJson` |
| `source = ai_paste` | Saved food records can mark that the source was an AI paste workflow. | No | `AppConstants.sourceAiPaste`, `FoodRecord.source` |
| AI Food Analysis | Add Food first entry. The user can submit a text-only food description or add up to three optional camera/gallery images, tap thumbnails to switch the enlarged preview or remove a single image, and keep a local recovery marker while the system picker is open; `ai-food-photo-analyze` calls Qwen and returns a schema-validated Food Draft that opens Food Preview. | Server-mediated draft only | `AddFoodPage`, `PhotoFoodAnalysisPage`, `AiFoodPhotoAnalysisClient`, `ai-food-photo-analyze` |
| AI Chat page | Centered AI tab with availability-gated background, editable composer, up to three image attachments, provider selector, cloud history sidebar, and account/subscription status entry. It can send text through OpenAI/Qwen and up to three images through Qwen only after login, subscription, active-device, and provider-configuration checks pass. Food Draft and Workout Draft responses render Chat artifact cards; tapping review rebuilds Food Preview or the existing workout editor draft and still requires user save confirmation before any official write. | Server-mediated text or draft only | `AiPage`, `AiChatController`, `SupabaseAiChatRepository`, `SupabaseAiGatewayClient`, `ai-chat-route` |
| Phase 4 chat data/contract foundation | Supabase schema for AI chat sessions/messages, request logs, compact debug summaries, and Flutter request/response/error contract models. It does not send messages or call providers. | No | `202606290001_phase4_ai_chat_foundation.sql`, `AiGatewayRequest`, `AiGatewayResponse` |
| Phase 4 Gateway and providers | Supabase Edge Function verifies auth, subscription, and active-device state, calls the selected server-side text or Qwen multimodal provider, accepts compact same-chat `conversation_context`, validates typed Food Draft or Workout Draft payloads, then persists the user/assistant text turn plus request log and compact debug summary through service-owned RPCs. | Server-mediated text or draft only | `ai-chat-route`, `record_ai_chat_turn`, `openai_provider.ts`, `qwen_provider.ts` |
| Account/Profile foundation | Supabase-configured email-password sign-in, persisted auth-session recovery, registration email-code flow with local PKCE verifier storage, subscription status lookup, Cloud Profile load/save path, Profile sign-in gate, and cache display fallback. | No | `AccountController`, `AuthRepository`, `SubscriptionRepository`, `CloudProfileRepository`, `ProfilePage` |
| User record summary permission | Per-account local setting that controls whether future AI answers may use user record summaries. The current text chat stores the permission only and does not upload full business history or record summaries; later summary-based AI workflows should use cloud summary/context builders. | No | `AiLocalContextPermissionRepository`, `AiPage` |

## V1 Agent Positioning

Agent V1 is a weak-Agent workflow layer, not an autonomous multi-step agent.

V1 adds:

- cloud account and subscription status
- Cloud Profile attached to the logged-in account
- Cloud Records and daily summaries as the official record source
- server-managed model API keys
- AI Gateway
- remote LLM and multimodal model calls
- user-selectable ChatGPT/OpenAI and Qwen provider routing inside AI Chat
- a centered full-screen AI Chat tab
- cloud chat history
- scoped Structured RAG over minimal summaries
- Document RAG over FitLog design/help documents
- schema-validated AI outputs
- inline Food Draft and Workout Draft preview cards in chat
- user confirmation before official writes

V1 does not add:

- user-supplied model API keys
- open-ended autonomous Agent loops
- multi-Agent systems
- silent meal-plan execution
- silent goal updates
- silent `carb_cycling` or `carb_tapering` changes
- one-shot full-history download into local SQLite
- treating local cache as the authoritative AI or product source
- user-data vector databases
- long-term semantic memory over business records
- GraphRAG
- medical diagnosis or treatment guidance

## Entry Points

The primary Agent entry is the new AI tab in the center of the bottom navigation:

```text
Home | Food | AI | Workout | Profile
```

The AI page is a simple full-screen chat surface. It is not a quick-chip workbench. Apart from the Add Food AI food analysis path, other Agent workflows should start from the AI page.

Allowed entry points:

| Entry | Purpose | Boundary |
| --- | --- | --- |
| AI Chat tab | Main Agent entry for food estimation, meal advice, weekly review, and app logic Q&A. | Requires login, network, and active subscription to send. |
| Add Food AI food analysis | Shortcut for text or image-based food estimation inside the Food flow. | Still produces a draft; user confirms before save. |
| Existing external JSON paste | Local compatibility workflow. | User-mediated external AI, not Agent V1. |

## AI Page Behavior

The AI page uses a full-screen programmatic liquid-gradient background and a minimal chat layout.

Chat interaction accents are theme-aware while the background keeps its own AI identity: user bubbles, send/review buttons, draft artifact borders, Markdown accents, and selected history rows use the active FitLog theme accent. Green stays green; Black Orange uses soft but clear orange. Readiness indicators remain semantic green for the ready state instead of becoming brand orange. The liquid-gradient background remains the AI page's pink/mint/blue color field instead of turning into a dark page background.

Required elements:

- full-screen animated background
- center status copy using the saved Cloud Profile nickname when available, such as "I'm listening, RINKO"
- bottom composer
- compact model selector for ChatGPT and Qwen near the composer
- right-top account/subscription status icon
- left collapsible cloud chat-history sidebar
- no quick chips
- compact privacy/status hint when needed

Animation states stay simple and should not compete with reading:

| State | Visual behavior | Product meaning |
| --- | --- | --- |
| Empty landing | Pink and blue fields feel visually balanced on portrait phones, the mint band wraps the center status text, and the whole field has visible motion. | The AI page is available or present and waiting for input. |
| Pre-conversation input | Keeps the visible landing motion, even while the keyboard is open. | The user is typing before sending the first message; the page is still in the landing input state. |
| Sent, history, waiting, or reading | Quiet, low-amplitude color-field flow. | The first message has been sent, an existing history conversation is open, a reply is pending, or the user is reading messages; chat content owns attention. |
| Disabled | Gray, low-motion color-field background that still flows. | User is offline, logged out, or not subscribed. Composer remains editable, but send is disabled. |

When messages grow into a scrollable list, the animated background remains one full-screen color field behind the whole AI page. It moves quietly and should be dimmed and desaturated behind the message layer for readability, but it should not be split into separate moving top/bottom strips, implemented as a translated static image, or built from obvious localized moving blobs. The color transitions should keep enough minimum width and sampling smoothness that pink/blue compression does not turn the mint band into visible blocky strips. The background should never stop entirely, including while the keyboard is open.

Waiting for a provider response should be shown by chat UI, not by faster background motion. The composer clears immediately, the user message appears as a pending bubble, and after that bubble has a real layout position the message list anchors it to the readable top boundary below the top actions. This send anchor is distinct from the message viewport's physical top and from the top fade-out region. A small active-turn trailing fill may be used only to make the pending user bubble plus assistant loading bubble anchor cleanly; it must not behave like a large scrollable blank region, and user drag should not be able to scroll the pending/loading pair completely out of view. The assistant loading bubble remains visible until the final assistant message is reloaded from cloud history. The assistant reply should not trigger another forced scroll after it appears.

The bottom navigation should be a theme-aware floating pill. The navigation component itself must not paint a full-width background strip outside the pill; whatever appears outside the pill should come from the current page or root shell background. Non-AI tabs use an opaque theme-surface pill so page text does not show through the navigation, while the AI tab uses a glass pill so the animated background remains visible. The root shell must not shrink page bodies to create navigation space. Scrollable pages own their bottom reading padding so the final content can scroll above the floating navigation, fixed bottom CTAs use navigation clearance, and Home first-viewport layout keeps only a small nav-adjacent gap so dashboard content keeps its intended size.

The AI page may keep a very light white gradient veil at the bottom. Its job is to soften the bottom light effect and system safe area, not to act as an opaque cover; future colorful animation should still remain visible beside the bottom navigation. The composer should be a floating bottom pill with the normal reading gap when the keyboard is closed. When the keyboard is open, it should attach to the keyboard top as a fully floating, solid input accessory; the message viewport should extend behind the composer to the keyboard top so no exterior composer background, half-height mask, or keyboard-above footer band surrounds the pill, while the message list's own bottom safe padding keeps the final bubble from colliding with the input pill. The chat list should use asymmetric soft alpha edges rather than hard rectangular clipping: the top fade can be longer to de-emphasize already-read content behind controls, while the bottom fade should be short so final bubbles do not look washed by the gradient.

AI Chat scroll geometry must handle obstruction consistently:

- The message list viewport may start at the top of the AI safe area and use internal top padding to place readable content below the history/account/provider controls.
- The message-list viewport should use a soft-edge mask near its top and bottom edges, not a visible background plate, to avoid hard card cutoffs.
- Send anchoring must target the same readable top padding used by normal message layout, not `Scrollable.ensureVisible(alignment: 0)`, so the pending bubble does not land inside the top fade.
- The message list needs enough bottom clearance for the measured composer height, bottom navigation, system safe area, bottom veil, and its own internal bottom safe padding.
- Send-time anchoring must target the real pending user bubble after layout. If a fallback scroll is needed to build that bubble, it should land near the active turn, not at the bottom of an oversized blank spacer.
- At the end of the list, the last message should rest above the composer surface instead of being covered by the input or navigation bar; in the keyboard-open state that safety distance comes from the message list's internal padding, not from clipping the viewport at the composer top or adding a surrounding composer background.
- The composer and message list must not calculate bottom spacing independently; they should share measured composer, keyboard, bottom-navigation, system safe-area, veil, and keyboard-closed reading-gap geometry.
- When the keyboard opens, the composer should attach to the keyboard top and the message-list viewport should extend behind the floating composer to the keyboard top, leaving only the list's internal bubble-safe padding to stop the final bubble above the input.
- The gap between the navigation bar and the physical screen bottom should reveal only the AI background and veil, not message text sliding underneath.

The center status text and composer hint should not say the same thing. The empty state may keep a center status such as "I'm listening, RINKO", using the saved Cloud Profile nickname before auth display name. The composer hint should give a lightweight input cue, such as "Ask away with FitLog." Keyboard focus by itself should not make the center status suddenly disappear or visibly jump; only a real conversation state should make the message list become the primary surface.

Assistant messages should render through a maintained GitHub-flavored Markdown renderer with app styling instead of a hand-written Markdown parser. Assistant text is selectable, user messages stay selectable plain text, and copying should use the system text-selection menu rather than a separate per-message copy button. Markdown rendering must not load remote images or execute link actions. Saveable business drafts may only come from validated Gateway draft payloads and must still go through user confirmation. When Chat returns a Food Draft or Workout Draft, the assistant message stores a lightweight artifact snapshot in `final_answer_json` and shows a native review button; tapping it rebuilds Food Preview or the existing workout editor draft locally from that snapshot instead of keeping a background draft page alive. If a stored snapshot can no longer rebuild the editor safely, the card remains visible as a disabled summary rather than disappearing.

AI Chat draft responses should not rely on raw provider prose plus pasted JSON. The provider-facing contract should be one machine-readable envelope: `message.text` contains the friendly user-facing explanation, estimate rationale, uncertainty, and review instruction, while `draft` contains the validated Food Draft or Workout Draft. The Gateway may recover a valid draft object from provider prose for robustness, but the user-facing UI should show the parsed `message.text` and native artifact card, not raw JSON. The dedicated Add Food AI food-analysis endpoint remains a pure structured Food Draft JSON workflow and does not need chat-style explanation.

Unsent composer text is a current-runtime device-local draft. It should survive tab switches and disabled availability states until the user deletes it or sends it. The composer clears immediately on send and the text moves into a pending user bubble; if sending fails, the draft should be restored for retry. Logout or account switching should clear the draft so previous account context does not linger; drafts must not be promoted into cloud chat history until a successful send.

## Supported V1 Workflows

### Food Draft Workflow

Inputs:

- text description
- optional food photos
- optional user corrections
- cloud profile
- selected date if relevant
- minimal cloud day summary if relevant

Behavior:

1. AI extracts candidate foods, portions, cooking method, and uncertainty.
2. If food type, meat type, portion, consumed amount, or cooking method is unclear, AI asks a follow-up question instead of forcing a confident estimate.
3. AI returns schema-validated draft data.
4. The dedicated Add Food AI food analysis path opens the existing Food Preview editor after a schema-validated response; the implemented Chat image draft path shows a Chat artifact card and opens Food Preview only after the user taps the review button.
5. The user may edit draft fields before saving.
6. The user may save, discard, or open the full food editor when the UI provides that path.
7. Official food records are written only after confirmation.

### Workout Draft Workflow

Inputs:

- text description
- optional image context when Qwen multimodal analysis is part of the current request
- optional user corrections
- selected date if relevant

Behavior:

1. AI extracts a candidate workout record name, date, exercises, sets, cardio duration, intensity, and uncertainty.
2. If exercise identity, load, reps, duration, or intensity is unclear, AI may ask at most one follow-up question that lists all material missing fields.
3. If the user reply is still incomplete or says they do not know, AI returns a best-effort schema-validated Workout Draft with missing values left empty and uncertainty recorded in notes instead of asking again.
4. AI returns schema-validated Workout Draft data.
5. The assistant message shows a Chat artifact card and opens the existing workout editor draft only after the user taps review.
6. If an unsaved workout editor draft already exists, the app asks before replacing that draft.
7. The user may edit the workout draft before saving.
8. Official workout records are written only by the normal workout editor save action.

### Meal Decision Workflow

Inputs:

- cloud profile
- current diet phase, calculation mode, and strategy
- selected-day food summary
- selected-day workout summary
- remaining kcal/macros or macro targets
- user request

Behavior:

- Answer questions such as "What can I eat next?", "Can I order this?", or "Why am I hungry today?"
- Respect `energy_ratio` and `gram_per_kg` semantics.
- Explain whether the recommendation is based on missing protein, remaining carbs, fat control, training day context, or food-log uncertainty.
- Do not change targets or strategies.

### Weekly Review Workflow

Inputs:

- cloud profile
- 7/14-day cloud summaries
- food-log coverage
- workout consistency
- weight trend when available
- current `diet_plan_strategy`

Behavior:

- Summarize patterns and data gaps.
- Explain likely causes of stalled progress.
- Distinguish behavior advice from official strategy changes.
- Discuss `carb_cycling` and `carb_tapering` as configured strategies, not as actions AI can silently apply.
- Suggest actions, but route any official change through normal user-confirmed UI.

### App Logic Q&A Workflow

Inputs:

- user language
- Document RAG results from the matching language document set
- current app context when relevant

Behavior:

- Answer how FitLog works.
- Explain fields, diet modes, workout calorie rules, carb cycling, carb tapering, export, and privacy boundaries.
- If the user asks in Chinese, retrieve Chinese documents. If the user asks in English, retrieve English documents.
- Do not claim planned features are already implemented.

## Context And RAG

V1 uses scoped retrieval because many useful answers require context. For example, when a user asks why weight loss has stalled, the model needs recent intake, training, weight, and profile context before answering.

The current AI Chat path implements only a compact same-chat context builder. It sends recent text turns plus Food Draft / Workout Draft artifact summaries so the model can understand the current conversation, but it does not send raw historical images, base64 payloads, full business history, or arbitrary database results. This same-chat context is not RAG.

### Structured RAG

Structured RAG means the backend or app calls known context-builder functions and sends compact structured summaries to the AI Gateway. After Phase 3, user-record context should come from cloud records, daily summaries, or summary builders rather than local SQLite cache.

Examples:

- `daily_summary`
- `recent_food_summary`
- `recent_workout_summary`
- `body_metric_summary`
- `weight_trend_summary`
- `profile_context`
- `strategy_context`
- `selected_day_context`

Rules:

- Upload the minimum necessary context for the current request.
- Prefer summaries over raw records.
- Preserve deterministic calculations as the source for targets and summaries.
- Do not upload full raw food/workout/body history.
- Do not give the model a free-form database query tool.

### Document RAG

Document RAG means retrieving FitLog documentation snippets to answer app-logic questions.

Allowed retrieval methods:

- keyword search
- full-text search
- vector or semantic search
- hybrid retrieval

Vector search is allowed for product/help/design documents. It is not approval to create a user-data vector database or long-term semantic memory over food/workout/weight records.

Document indexing scope:

- `docs/en/*` for English questions
- `docs/zh/*` for Chinese questions
- stable app help snippets derived from those documents

### Explicitly Out Of Scope

- user business-data embeddings
- long-term semantic user memory
- GraphRAG
- arbitrary database exploration by the model
- open-ended tool execution loops

## Cloud Data Boundary

V1 cloud/local data authority, cache, writes, reads, failures, and repair rules live in `CloudLocalDataBoundary.md`. AgentDesign only defines how AI uses that data.

AI context should prefer Cloud Profile, cloud records/daily_summaries, or compact summaries produced by controlled summary/context builders. AI Gateway should not treat local SQLite cache as authoritative context and should not upload complete raw history by default.

V1 uses one active device per account. AI context building and AI Gateway send must come from the current active device/session; an older device replaced by a newer login cannot keep using local cache to send AI requests.

By default, V1 does not provide the model with complete raw food history, complete raw workout history, complete raw body-metric history, local export archives, or local workout drafts. When record context is needed, the app should use user-visible permission or settings and send only the minimum necessary summary.

The implemented food analysis and image paths are narrow, not RAG. Add Food sends a text description and zero to three compressed JPEG/PNG/WebP images to `ai-food-photo-analyze`; AI Chat can send up to three JPEG/PNG/WebP images through `ai-chat-route` when Qwen is selected. The Edge Functions forward only the current request input to Qwen, validate structured Food Draft or Workout Draft payloads when present, and do not store original images or base64 payloads. Add Food and AI Chat request logs write the accepted `image_count` including `0` for text-only food analysis, while chat history persists text turns plus lightweight artifact snapshots and summaries for returned drafts.

## Cloud Profile

Profile belongs to the account. Before login, the user has no formal profile, and the Profile page should show a login/onboarding entry instead of the local profile editor. The current auth entry uses a solid theme background, the no-star FitLog logo base asset with a saturated SVG-derived fixed rounded AI four-point sparkle cluster anchored to the logo's upper-right, a slight lower-left placement adjustment, fuller resting scale, staggered breathing pulses, app theme `NotoSansSC` typography with moderate sign-in text weights, a top backend-configuration notice when needed, a static non-scrolling landing state when the keyboard is closed, keyboard-aware compact scrolling while auth fields are focused, email-password sign-in, and a registration form with email code plus password confirmation. Registration does not collect a username; nickname/display name remains a Cloud Profile field filled through Profile onboarding.

Rules:

- Cloud Profile is the authoritative profile after login.
- Supabase auth sessions persist on the device and are recovered on app startup. The session is cleared only on explicit sign-out, account change, or unrecoverable auth recovery failure.
- Accounts without an existing `cloud_profiles` row are initialized with a default Cloud Profile automatically, matching the Local first-run default profile experience.
- Sign-in and registration errors keep the active auth form mounted and show readable snackbar feedback. Raw Supabase exception text should stay inside repository diagnostics.
- Cloud Profile load/save failures should map to stable diagnostic codes for missing table, incomplete schema, field type mismatch, RLS denial, expired auth, constraint failure, network failure, and generic fetch/save failure.
- Subscription-status loading is separate from Cloud Profile loading. If subscription lookup fails but Cloud Profile loads, Profile remains usable while AI sending stays unavailable.
- The device may cache the profile for display, but a local cache write failure must not block the already loaded authoritative Cloud Profile. Cached Profile values may be shown during cloud refresh only when account-bound cache metadata matches the current signed-in account.
- Profile UI edits are staged as a page-local draft. Taps and inputs update the Profile preview immediately, changed sections show visible modified markers, nickname and current body fields do not have card-level save buttons, and the bottom Save Changes bar stays anchored near the bottom of the Profile body, expands upward for compact change details, and upserts one complete Cloud Profile snapshot.
- Current body metrics on the Profile page, including weight, body-fat percentage, and waist circumference, are part of the Cloud Profile snapshot after login and are saved only through the bottom Save Changes action during ordinary Profile editing. Historical weight, body-fat, and waist records belong to cloud `body_metric_logs`, while local `user_weight_logs` is only confirmed cache. The Body Profile card provides the past-date-only calendar/add record entry; its in-page historical body-record edit state keeps its own save action, saves only `body_metric_logs`, locks non-editable Profile areas with stronger soft fading instead of extra block scrims, keeps the active editor visible above the keyboard, and does not silently change the current Cloud Profile. Body Trends remains read-only.
- Until Save Changes succeeds, other app areas and AI context should continue using the last saved authoritative Cloud Profile rather than the unsaved draft.
- Offline profile editing is disabled.
- If the user is offline, the Profile page may show cached values but cannot save changes.
- AI uses Cloud Profile as the default authoritative context.
- Requests may include `profile_version` to detect stale context.
- Account deletion deletes Cloud Profile.
- The Profile page exposes explicit sign-out in a bottom Account card. Signing out or switching accounts clears the auth session, runtime Profile draft state, account-bound Cloud Profile cache metadata, and local caches; it must not delete cloud official records.

Cloud Profile mapping must preserve algorithm semantics. It may validate enum values, fill versioned defaults for missing fields, and convert storage types, but it must not infer a new `diet_goal_phase`, convert `gram_per_kg` into `energy_ratio`, treat auxiliary kcal values as primary in `gram_per_kg` mode, or overwrite the user's phase/mode/strategy from derived fields.

Because offline profile saving is disabled, V1 avoids pending-profile merge conflicts. If a future version allows offline edits, it must define a field-level merge policy before implementation.

## Subscription And Availability

V1 uses subscription gating rather than user-visible per-message credits.

The Profile header exposes a compact `Subscription` entry button with an explicit active/inactive/loading/error status badge, not a standalone notification-like dot. The entry opens a small blurred overlay. The overlay shows the current account entitlement, refreshes subscription status, and can redeem a development internal code through the Supabase RPC `redeem_internal_subscription_code`. Redeem codes are stored server-side as hashes and update the account's `subscriptions` row only through the RPC; clients never receive a service-role key and cannot directly insert or update entitlement rows. This is an internal development entitlement test path, not a production payment or app-store subscription implementation.

AI send is disabled when:

- user is not logged in
- device is offline
- current device has been replaced by a newer login for the same account
- subscription is inactive

The app may still let the user type or edit an unfinished prompt in disabled states. Sending requires login, network, active device, Cloud Profile, subscription, and Gateway server checks to pass.

Backend may log request counts and model cost internally, but V1 should not show a quota or remaining-credit UI unless that product decision changes.

## Request, Response, And Debug Retention

Default V1 recommendation:

- Save AI sessions and final chat messages in cloud so history works across devices after login.
- Save request/response metadata for reliability, billing audit, abuse prevention, and debugging.
- Store compact debug summaries instead of verbose raw chain-of-thought or unrestricted tool traces.
- For Add Food AI food analysis, store only compact metadata such as workflow, model, image count, optional input kind, mime type, compressed byte length, note presence, schema validation status, and safety/error flags; do not store the original image, base64 payload, or full free-text note by default.
- Avoid storing full retrieved local record payloads when a compact context summary is enough.
- Provide account deletion behavior that removes account-bound profile and chat history according to the deletion policy.

Debug logs should be environment-aware:

| Environment | Retention behavior |
| --- | --- |
| Development | More detailed gateway logs are acceptable for debugging. |
| Production | Store compact metadata and sanitized summaries only. |
| User-facing UI | Show final messages and relevant draft cards, not internal traces. |

## Tool And Write Permissions

AI can propose writes only through typed draft objects.

| Action | AI may do | Requires user confirmation? |
| --- | --- | --- |
| Create food draft | Yes | Save requires confirmation |
| Edit draft fields | Suggest or prefill | User controls final value |
| Save official food record | No direct silent save | Yes |
| Create workout draft | Yes | Save requires confirmation through the workout editor |
| Modify workout record | No direct silent edit | Yes through the workout editor |
| Change profile | Explain only in V1 | Yes through Profile UI |
| Change diet phase/mode/strategy | Explain only | Yes through Profile UI |
| Apply carb taper | Explain/recommend only | Yes through existing review flow |
| Delete records | No | Yes through existing destructive confirmation |

## Safety And Quality Rules

- If the model is uncertain, ask a question.
- If data is insufficient, explain what is missing.
- If a request is medical, redirect to general nutrition/fitness information and encourage professional advice.
- Do not provide diagnosis or treatment.
- Do not use AI estimates as exact nutritional truth.
- Always keep user confirmation between AI drafts and official writes.
- Keep local deterministic algorithms authoritative for targets and summaries.
- Keep implemented behavior separate from planned V1 behavior in documentation and UI copy.

## Code References

Current Local and Agent baseline:

- App shell: `lib/main.dart`, `lib/app.dart`
- AI page: `lib/features/ai/ai_page.dart`, `lib/features/ai/ai_chat_controller.dart`
- Bottom navigation: `lib/core/widgets/fitlog_bottom_nav_bar.dart`
- Food entry and AI-adjacent paste flow: `lib/features/food/*`
- Workout editor draft handoff: `lib/features/workout/add_workout_page.dart`, `lib/domain/models/ai_workout_draft.dart`, `lib/domain/models/workout_record_draft.dart`
- Prompt templates: `lib/core/constants/prompt_templates.dart`
- JSON parser: `lib/domain/services/nutrition_calculator.dart`
- Daily summaries: `lib/domain/services/daily_summary_service.dart`
- Diet targets: `lib/domain/services/macro_target_calculator.dart`
- Strategies: `lib/domain/services/carb_cycling_calculator.dart`, `lib/domain/services/carb_taper_review_service.dart`, `lib/domain/services/diet_plan_strategy_service.dart`
- Workout calories: `lib/domain/services/workout_calorie_calculator.dart`
- Database: `lib/data/db/app_database.dart`
- Repositories: `lib/data/repositories/*`
- Account/Profile state: `lib/features/account/account_controller.dart`
- Cloud Profile mapping: `lib/domain/services/cloud_profile_mapper.dart`
- Supabase schema: `supabase/migrations/202606190001_phase2_account_profile.sql`, `supabase/migrations/202606260001_phase3_cloud_records.sql`, `supabase/migrations/202606290001_phase4_ai_chat_foundation.sql`, `supabase/migrations/202606290002_phase4_step2_gateway_mock.sql`, `supabase/migrations/202606300001_phase4_step3_4_chat_ops_real_providers.sql`
- Supabase chat/session rename schema: `supabase/migrations/202607010001_phase4_step5_chat_session_rename.sql`
- Supabase Edge Functions: `supabase/functions/ai-chat-route/index.ts`, `supabase/functions/ai-chat-route/openai_provider.ts`, `supabase/functions/ai-chat-route/qwen_provider.ts`, `supabase/functions/ai-food-photo-analyze/index.ts`
- AI chat and AI food analysis data path: `lib/data/remote/ai_gateway_client.dart`, `lib/data/remote/ai_food_photo_analysis_client.dart`, `lib/data/repositories/ai_chat_repository.dart`
- AI Gateway contract models: `lib/domain/models/ai_chat_session.dart`, `lib/domain/models/ai_chat_message.dart`, `lib/domain/models/ai_gateway_request.dart`, `lib/domain/models/ai_gateway_response.dart`, `lib/domain/models/ai_gateway_error.dart`, `lib/domain/models/ai_food_photo_analysis.dart`, `lib/domain/models/ai_workout_draft.dart`

Planned later Agent V1 surfaces:

- record-summary context-builder services
- richer inline draft editing
