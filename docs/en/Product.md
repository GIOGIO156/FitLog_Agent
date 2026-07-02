# Product Design

## Purpose

FitLog_Agent V1 is a cloud-assisted AI food and workout logging app built from the FitLog Local baseline.

Its value is not "AI replaces logging." Its value is that deterministic food, workout, diet-target, strategy, and export workflows remain stable, while a subscription-based AI Chat helps users estimate complex food, decide what to eat next, review recent behavior, and understand app rules.

The product promise:

```text
Record after sign-in with cloud official records and deterministic rules.
Use cloud AI when the user asks for help.
Write official data only after the user confirms.
```

## Product Principles

- Preserve Local behavior unless an Agent V1 requirement explicitly changes it.
- Require sign-in before official record features in the Agent version.
- Phase 3 Cloud Records Foundation connects signed-in body/food/workout official records to the cloud source of truth.
- Local SQLite is partial cache, draft storage, and runtime acceleration; it is not a full-history mirror.
- Detailed cloud/local read, write, cache, refresh, conflict, and repair rules live in `CloudLocalDataBoundary.md`.
- V1 uses one active device per account with last-login-wins behavior; it does not promise realtime multi-device sync.
- Use cloud services for account, subscription, Cloud Profile, Cloud Records, daily summaries, AI Gateway, chat history, and AI audit needs.
- Treat the Cloud Profile as account-bound user information after login.
- Do not require users to bring their own model API key.
- Keep `energy_ratio` and `gram_per_kg` separate.
- Keep `diet_goal_phase` as the source of truth for cutting/bulking.
- Treat `diet_plan_strategy` as a deterministic strategy setting, not an AI action.
- Make the AI page the primary Agent entry.
- Avoid silent writes: AI drafts, explains, and asks; users confirm.
- Route app-level transient feedback through the shared system notification layer instead of page-local snackbars.

## System Notifications

System notifications are app-level transient feedback, not business logic.

- Success messages such as saved, deleted, copied, exported, signed out, or code sent use lightweight top notices so they do not interrupt the task flow or cover bottom navigation, composers, or primary action buttons.
- Error and validation messages remain more visible and keep readable diagnostic detail, but float above the bottom navigation or keyboard instead of covering the current input focus.
- Notifications that need user action must keep their action button and callback through the shared action notification API; they must not be downgraded to passive notices.
- Notification colors and text styles come from the active FitLog theme, so Green and Black Orange keep consistent surfaces, accents, and `NotoSansSC` typography.

## Product Modules

| Module | V1 role | Implemented baseline | V1 planned additions |
| --- | --- | --- | --- |
| Home | Selected-day dashboard. | Local daily summary, diet context, macro/kcal display, compact food/workout cards. | Builds daily summaries through cloud-backed record repositories, stores selected-day confirmed summary cache locally, refreshes Home with stale-while-revalidate, and upserts rebuildable `daily_summaries` to the cloud. |
| Food Log | Official food-record management. | Manual food entry, external AI JSON paste, copy-to-date, edit, delete, and confirmed `ai_photo` records from Add Food Photo AI Analysis. | After sign-in, official records write cloud-first; later Chat draft workflows must keep the same user-confirmation boundary. |
| Add Food | Food creation workflow. | Photo AI Analysis is the first entry; manual entry and external AI JSON paste remain available. | Future refinements may add more than three Chat images or richer editor-side draft refinement only with an explicit privacy and confirmation design. |
| AI | Primary Agent entry. | The current AI page implements the centered tab, availability-gated chat page, editable composer, selectable/copyable message bubbles, up to three Qwen image attachments, locally persisted provider selector, readiness-only status pill, account/subscription status sheet, subscription/Profile availability gating, user-record summary permission, compact same-chat context, Gateway client, server-side OpenAI/Qwen provider routing, Chat Food Draft and Workout Draft artifact cards, and cloud chat history with new/switch/inline rename/delete-with-confirmation. | RAG-backed meal decisions, weekly review, app logic Q&A, and richer draft editing. |
| Workout | Official workout-record management. | Workout records, custom exercises, draft editor, calorie heuristics. | After sign-in, official records write cloud-first; V1 AI may explain or review workout context but should not silently modify records. |
| Profile | Account/profile/diet settings. | Local profile logic remains the compatibility baseline; signed-out users see the sign-in entry, and signed-in formal profile changes save through Cloud Profile. | Account deletion, production subscription management, and later AI personalization flows. |
| Export | User-controlled data export. | XLSX and CSV ZIP export. | After Phase 3 hardening, export loads cloud official food, workout, and body metric records before building files; local cache may accelerate but is not required for completeness. |

## AI Chat Experience

The AI page is a simple full-screen chat, not a dashboard of shortcuts.

Navigation:

```text
Home | Food | AI | Workout | Profile
```

Required UI:

- AI tab centered in bottom navigation.
- Theme-aware floating bottom-navigation pill; the navigation component itself does not paint a full-width strip outside the pill.
- Non-AI pages use an opaque theme-surface nav pill with a same-width page-background lower shield from the pill midline to the screen bottom, so scrolling content is covered without adding a full-width strip. The AI page uses a glass nav pill without that shield so the animated background remains visible.
- Explanation guide sheets, including the Home strategy guide and Profile current-plan method guide, open as root modal sheets. Their scrim covers and disables the bottom navigation, the sheet bottom stops 12 px above the nav pill footprint, the top keeps at least 64 px of focus space, and long guide text scrolls inside the sheet body instead of shrinking text or covering navigation.
- The root shell does not shrink page bodies or paint a navigation-height strip. Floating-navigation geometry separates two coordinate systems: the screen-space footprint is the pill height plus `max(device bottom safe area, 12)`, while the SafeArea content-space clearance subtracts the bottom safe area already consumed by SafeArea. Home's first-viewport box uses SafeArea content height minus the nav clearance; the g/kg macro strip and energy-ratio cards stay inside that box instead of using nav reserve as internal spacing. In energy-ratio mode, the calorie card keeps its natural ring, typography, padding, and top placement; the macro card keeps its natural internal height at the bottom, and the middle space flexes. Scrollable bottom reading padding and fixed bottom controls use separate helpers. Food and Workout add CTAs are transparent overlays with their own scroll clearance; like the AI composer, they are anchored in screen coordinates to the nav pill top with the same fixed visual gap, and the AI page background extends behind navigation.
- Full-screen animated AI background; the empty landing state uses visible colorful flow, while typing, waiting, and reading states use extremely slow low-amplitude motion so the page never freezes and the background does not compete with text.
- Center status line using the saved Cloud Profile nickname when available.
- Bottom composer.
- Compact model selector near the composer for `ChatGPT` and `Qwen`.
- Left collapsible chat-history sidebar.
- Top-right account/subscription icon.
- No quick chips.
- Compact privacy/status hint.

Current AI page behavior:

- The root navigation is `Home | Food | AI | Workout | Profile`.
- The AI shell defaults to signed-out disabled state.
- The composer is editable; send is enabled only when the user is logged in, online, subscribed, on the active device, and the Supabase Gateway provider is configured.
- The model selector displays `ChatGPT` and `Qwen` and routes the selected provider to the server Gateway; exact model names and API keys are server-side configuration.
- The account/subscription entry opens the current status sheet with sign-out and user-record summary permission. The center status text reads the saved Cloud Profile nickname before falling back to auth display name.
- Supabase Auth, subscription status, and Cloud Profile access are wired when the build is configured with Supabase URL and anon key.
- The history entry opens the cloud chat-history sidebar, supports creating a new chat, switching sessions, inline renaming through a server RPC, and soft-deleting sessions only after confirmation. The archive entry is not exposed because there is no archived-session recovery UI.
- The AI page calls the `ai-chat-route` Edge Function for text turns and Qwen multimodal turns with up to three images, then persists accepted user/assistant message text through server-owned RPCs.
- The model selector is stored locally on the device with `SharedPreferences`, so the last selected ChatGPT/Qwen choice survives app restart without syncing to cloud. The status pill shows readiness only with compact labels: `Ready` when sending is available and `Off` when any account, subscription, Profile, gateway, offline, or active-device gate blocks sending. In-progress sending is shown by the send-button spinner and assistant loading bubble, not by the readiness pill.
- Sending clears the composer immediately, shows the user message as a pending bubble, shows an assistant loading bubble while waiting, and restores the draft if the send fails.
- Assistant messages render through a maintained GitHub-flavored Markdown renderer with app styling, selectable text, no remote image loading, and no link actions. User messages remain selectable plain text. Each text message bubble also exposes a copy action that copies the original message text.
- The AI page can send up to three JPEG/PNG/WebP images through Qwen. Food Draft responses open Food Preview after user review, and Workout Draft responses open the existing workout editor draft after user review; both still require the user to save before any official record is written.
- No RAG, long-term image storage, automatic goal change, or automatic official business-record write occurs from the AI page.
- Unsent composer text is a current-runtime device-local draft. Page switches and disabled states should not clear it automatically; user deletion, send start, logout, or account switch clears it, and a failed send restores the attempted draft.

The current AI page can send text turns and up to three Qwen image attachments when all runtime gates are satisfied. It includes compact same-chat text and draft-artifact summaries in requests so the model can follow the active conversation. Cloud official records and daily summaries are already the signed-in source for later AI context, but the implemented chat path does not yet retrieve record summaries or run RAG.

Availability states:

| State | UI behavior |
| --- | --- |
| Logged in, online, subscribed | Colorful AI background; send enabled; status indicator is green. |
| Waiting for assistant | Background uses quiet low-amplitude motion; assistant loading bubble indicates work in progress. |
| Needs clarification | Background stays quiet; missing-info prompt or draft field is emphasized. |
| Logged out | Gray disabled AI page; send disabled; prompt can be typed but not sent. |
| Offline | Gray disabled AI page; send disabled; profile editing is also disabled. |
| Not subscribed | Gray or locked AI page; send disabled; top-right status explains subscription state. |

## AI Workflows

### Food Estimation

Add Food now exposes Photo AI Analysis as the first entry. The user can take photos or choose up to three images from the gallery, tap thumbnails to switch the enlarged preview, add an optional note, and send the images to the dedicated `ai-food-photo-analyze` Gateway path. The server calls Qwen multimodal capability and returns a schema-validated Food Draft, not an official record. The draft opens in the existing Food Preview editor; only the user's Save action writes `food_records` / `food_items` with source `ai_photo`.

The draft should include:

- meal name
- candidate food items
- amount or serving estimate
- kcal/protein/carbs/fat
- confidence or uncertainty notes
- missing questions when needed
- source marker such as AI draft

If the AI cannot identify an ingredient or portion, it should ask. For example, if meat type is unclear, it should ask what meat it is rather than guessing.

The current implemented draft surfaces are Food Preview after Add Food photo analysis, Chat Food Draft artifact cards that rebuild Food Preview after the user taps review, and Chat Workout Draft artifact cards that rebuild the existing workout editor draft after the user taps review. Future richer draft surfaces should stay consistent with the corresponding record editor and support:

- save
- discard
- open full editor

Official records are created only after save confirmation.

### Workout Drafts

AI Chat can return a schema-validated Workout Draft when the user asks to turn a described workout into a record. The assistant shows a readable summary plus a native artifact card. Tapping review rebuilds the existing workout editor draft from the stored snapshot, asks before replacing any unsaved workout draft, and still requires the user to save in the workout editor before any official workout record is written.

For Workout Drafts, AI may ask at most one clarification turn. That one turn should list all missing fields that materially affect the draft. If the user reply is still incomplete or says they do not know, AI should return a best-effort editable Workout Draft with missing numeric fields left empty and uncertainty recorded in notes instead of continuing to ask more questions.

### Meal Decision

The user can ask what to eat next, whether an order fits today, or why the day feels hard to manage.

The answer should use:

- Cloud Profile
- selected-day cloud food summary
- selected-day cloud workout summary
- current diet phase
- current calculation mode
- current strategy
- remaining targets or macro targets

The AI should explain the reasoning in practical terms. It must not recalculate the user's official plan or silently change targets.

### Weekly Review

The user can ask for a weekly or recent review.

The review should use recent cloud summaries rather than uploading full raw history by default. It should cover:

- food-log coverage
- average intake pattern
- protein/carbs/fat consistency
- workout consistency
- weight trend when available
- likely blockers
- small next actions

Weekly Review must distinguish advice from official settings. It may discuss `carb_cycling` and `carb_tapering`, but it must not apply either strategy or modify its settings.

### App Logic Q&A

The user can ask how FitLog works.

Examples:

- What is `gram_per_kg`?
- Why is kcal not primary in this mode?
- How does workout calorie estimation work?
- What does carb tapering do?
- What data is saved in cloud?

The app should retrieve English docs for English questions and Chinese docs for Chinese questions.

## Profile And Account Model

Before login, there is no formal profile and the Profile page should show only a login/onboarding entry. After login, profile behaves like account-bound user information.

V1 profile rules:

- Cloud Profile is authoritative.
- Local device may cache it for display, but cached values may be shown during cloud refresh only when the cache metadata matches the current signed-in account.
- Supabase auth sessions persist on the device and are recovered on startup until the user explicitly signs out or the session cannot be recovered.
- A newer device login takes over the account; the older device should show "account signed in on another device" on its next cloud interaction and return to sign-in/re-takeover flow.
- Profile page edits are local drafts until the user taps the bottom Save Changes bar; nickname and current body fields do not have card-level save buttons, modified sections are visibly marked in the page, and saving uploads one complete Cloud Profile snapshot.
- Auth failures keep the active sign-in or registration form visible and show readable shared system notification feedback.
- Subscription-status loading failures do not replace a successfully loaded Cloud Profile editor with a Profile error screen; AI sending remains gated by subscription availability.
- The Profile header uses a compact Subscription entry with an explicit active/inactive/loading/error status badge. It opens a small blurred overlay, keeping the current plan as the first main card.
- The Profile page provides a bottom Account card for explicit sign-out. Signing out clears the auth session, runtime drafts, and local caches without deleting cloud official records.
- Offline profile saving is disabled.
- AI uses Cloud Profile by default.
- Requests can include `profile_version`.
- Account deletion deletes Cloud Profile.

Profile should include the existing profile information needed by FitLog's diet and personalization logic, such as:

- display name or nickname
- age
- height
- weight
- body-fat percentage
- waist circumference
- sex option for formulas
- diet phase
- diet calculation mode
- diet-plan strategy
- energy-ratio settings
- gram-per-kg relevant settings
- training frequency
- self-check settings
- carb-cycling settings
- carb-tapering settings
- language preference when account-bound

After Phase 3 Cloud Records Foundation, workout, food, and body metric records use the cloud as the official source, and local SQLite is only cache, draft storage, and runtime acceleration. AI reads cloud records/summary/context builders for record context instead of treating local cache as authoritative. Cache-first reads, prefetch, eviction, export correctness, and repair rules live in `CloudLocalDataBoundary.md`.

The Profile body section shows the current Profile's six fields: age, height, weight, sex, body-fat percentage, and waist circumference. Current body fields are ordinary Profile draft fields and have no card-level save button; they persist only through the bottom Save Changes action. The Body Profile card provides the calendar/add body-record entry. The picker opens on today, selecting today returns to the current body profile view without showing a date badge, and only past dates enter the in-page historical body-record edit state. In that state, the exact date appears under the calendar action, with Chinese labels using a two-digit year and English labels using a four-digit year. Only weight, body-fat percentage, and waist circumference are highlighted and editable, while age, height, sex, the rest of the page, and bottom navigation are locked with stronger soft fading instead of extra block scrims. Existing historical records show a red delete control beside the date; deletion requires confirmation, uses a red destructive action instead of a green filled confirmation button, soft-deletes the cloud record and local cache mirror, refreshes Body Trends, and can affect future calibration/review results that use weight history. Past dates without a historical record leave the three editable metrics empty instead of copying current Profile values. Inline body-profile editors share the tile surface instead of painting separate filled input blocks, use a stable value slot so focusing a field does not resize the tile, and keyboard focus scrolls the active body-record editor above the keyboard instead of compressing the Profile card. Backfilling a past date does not silently modify the current Cloud Profile; setting a historical record as current body data requires explicit confirmation. The Body Trends card below is read-only and plots weight, body-fat, or waist records over 7/14/21/28-day windows. Trend controls stay at the bottom of the card, summary text stays above the chart, real record points extend from left to right by their real day spacing within the current window, insufficient-record messages appear inside the chart area, and tapping a real record dot shows that point's value inline.

The Profile theme card is a low-frequency setting placed before language settings. Current options are Green and Black, shown as independent tappable options rather than a two-part segmented control so future themes can be added without changing the interaction pattern. Green remains the default. Black uses the Black Orange palette with a dark page background, dark cards, and orange accent color. Orange is reserved for buttons, selected states, icon emphasis, and progress emphasis, not large card fills. The theme preference is stored only in local `SharedPreferences`, not SQLite or Cloud Profile.

## Data And Privacy Model

V1 cloud data:

- account
- subscription
- Cloud Profile
- body metric logs
- food records / food items
- workout records / workout sessions / workout sets
- daily summaries
- AI request metadata
- AI sessions
- AI chat messages
- final AI answers
- compact debug/action summaries

V1 local data:

- account-bound records/read-model cache
- local workout drafts
- pending drafts
- exports

AI requests should upload the minimum necessary context. For user-data context, prefer cloud summaries over raw rows. Cache cleanup, eviction, and account-switch rules live in `CloudLocalDataBoundary.md`.

## User Confirmation Model

AI output categories:

| Output | Official write? | Confirmation rule |
| --- | --- | --- |
| Explanation | No | No save action. |
| Meal suggestion | No | User decides outside AI. |
| Food Draft | Draft only | Save requires confirmation. |
| Workout Draft | Draft only | Save requires confirmation in the workout editor. |
| Weekly Review | No | Strategy changes must go through normal UI. |
| App logic answer | No | No write action. |
| Profile/diet setting suggestion | No | Change requires Profile UI confirmation. |

## Implemented Scope From Local

The copied Local baseline already implements:

- local food CRUD
- external AI JSON paste and local parsing
- prompt copy
- manual food entry
- selected-date Home/Food/Workout flow
- workout record creation/editing/deletion
- custom exercise library
- deterministic workout calorie estimation
- dynamic calorie calibration
- `energy_ratio`
- `gram_per_kg`
- `carb_cycling`
- `carb_tapering`
- local profile setup
- XLSX and CSV ZIP export
- local data clearing with confirmation
- language switching

## Implemented Agent Scope

The current Agent source now implements:

- Android install identity separated from FitLog Local.
- App label and Flutter app title `FitLog Agent`.
- Five-tab root navigation: `Home | Food | AI | Workout | Profile`.
- `RootTabIndex` constants so Home links continue routing Food to index `1` and Workout to index `3`.
- Theme-aware floating bottom-navigation pill extracted into `FitLogBottomNavBar`.
- Full-screen AI shell at `lib/features/ai/ai_page.dart`.
- Disabled AI state with editable prompt and disabled send button.
- ChatGPT/Qwen provider selector with server-side Gateway routing and server-managed model credentials.
- Cloud chat-history entry with new chat, session switching, inline rename, and delete confirmation; archive is not exposed in the current UI.
- Chat send path with up to three Qwen image attachments, compact same-chat context, pending user bubbles, assistant loading feedback, semantic status indicators, selectable/copyable message bubbles, maintained assistant Markdown rendering, Food Draft handoff to Food Preview, and Workout Draft handoff to the workout editor draft.
- Supabase configuration via `SUPABASE_URL` and `SUPABASE_ANON_KEY`, with local SharedPreferences-backed PKCE verifier storage for registration email codes.
- Account controller and repository layer for Auth, subscription status, Cloud Profile, and user-record summary permission.
- Profile auth screen with a solid theme background, no-star FitLog logo base asset, saturated SVG-derived fixed rounded AI four-point sparkle cluster anchored to the logo's upper-right with a slight lower-left placement adjustment, fuller resting scale, staggered breathing pulses, app theme `NotoSansSC` typography with moderate sign-in text weights, top backend-configuration notice, a non-scrolling static landing state when the keyboard is closed, keyboard-aware compact scrolling while auth fields are focused, email-password sign-in, registration email code, password confirmation, no username requirement, automatic default Cloud Profile creation for accounts without a cloud row, cloud save path, and cached display fallback.
- Persisted Supabase auth-session recovery, AI account/subscription status sheet, Profile header Subscription entry with compact blurred status refresh and internal redeem-code entitlement, user-record summary permission toggle, explicit Profile sign-out account card, and logout/account-switch composer clearing.
- AI shell, chat controller, Gateway contract/client, root navigation, mapper, and account-controller tests.

## V1 Non-goals

- full-history one-shot download into local SQLite
- treating local cache as the authoritative AI or product source
- user-data vector database
- long-term semantic memory
- autonomous multi-step AI coach
- automatic target updates
- automatic `carb_tapering` application
- automatic `carb_cycling` modification
- medical diagnosis or treatment advice
- replacing the deterministic algorithm layer with LLM reasoning

## Code References

- App bootstrap: `lib/main.dart`, `lib/app.dart`
- AI shell: `lib/features/ai/ai_page.dart`
- Bottom navigation: `lib/core/widgets/fitlog_bottom_nav_bar.dart`
- Home: `lib/features/home/home_page.dart`
- Food: `lib/features/food/*`
- Workout: `lib/features/workout/*`
- Profile: `lib/features/profile/profile_page.dart`
- Models: `lib/domain/models/*`
- Services: `lib/domain/services/*`
- Database: `lib/data/db/app_database.dart`
- Repositories: `lib/data/repositories/*`
- Export: `lib/export/*`
- Localization and prompts: `lib/core/localization/*`, `lib/core/constants/prompt_templates.dart`
- Agent V1 source design: `docs/FitLog_Agent_V1_Implementation.md`
