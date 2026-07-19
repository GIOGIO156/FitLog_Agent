# Product Design

## Purpose

FitLog_Agent V1 is a cloud-assisted food and workout logging product with deterministic planning rules and a user-controlled AI layer.

Its value is not "AI replaces logging." Its value is that deterministic food, workout, diet-target, strategy, and export workflows remain stable, while a subscription-based AI Chat helps users estimate complex food, decide what to eat next, review recent behavior, and understand app rules.

The product promise:

```text
Record after sign-in with cloud official records and deterministic rules.
Use cloud AI when the user asks for help.
Write official data only after the user confirms.
```

## Product Principles

- Preserve proven logging, planning, and export behavior unless an explicit Agent requirement changes it.
- Require sign-in before official record features in the Agent version.
- Signed-in body, food, and workout official records use the cloud source of truth.
- Local SQLite is partial cache, draft storage, and runtime acceleration; it is not a full-history mirror.
- Detailed cloud/local read, write, cache, refresh, conflict, and repair rules live in `CloudLocalDataBoundary.md`.
- Signed-in startup should bind local record caches to the recovered auth account before active-device refresh finishes, so current-day Home/Food/Workout data can render from matching local cache.
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
- Error and validation messages remain more visible and keep readable diagnostic detail, but float above the bottom navigation or keyboard instead of covering the current input focus. AI composer errors use the same shared component and are offset above the measured composer rather than introducing a page-local error pill.
- Notifications that need user action must keep their action button and callback through the shared action notification API; they must not be downgraded to passive notices.
- Passive transient notices keep a compact shape, have no close icon, expire automatically, and stay scoped to the relevant surface; tab, route, or app-lifecycle changes cannot carry stale feedback into an unrelated module. A confirmed save that closes its editor captures the root notification surface before navigation and emits one fresh success notice on the destination page, where the same bounded timer applies.
- A short app-background transition does not cancel an in-flight AI request. The pending state resumes with the page; only a real transport timeout, network interruption, or Gateway failure becomes an error, and failed-send input remains available for retry.
- Notification colors and text styles come from the active FitLog theme, so Green and Black Orange keep consistent surfaces, accents, and `NotoSansSC` typography.
- Android mirrors an active unsaved new-workout draft with any selected exercise as a system "workout in progress" notification. This is a draft-resume surface, not a background task or new official record. Editing an existing official workout is page-local and never creates this retained draft or notification.
  - With a next strength set, the title is the current exercise and the body is the next incomplete set using current weight/reps values; otherwise it shows a short return-to-continue prompt.
  - The right-side image reuses the workout editor exercise/body-part asset. The platform may tint the small status-bar icon monochrome.
  - Focus follows the most recently checked set while that exercise remains unfinished, then returns to the first unfinished strength exercise in workout order.
  - Tapping resumes the same local draft. Save, discard, or deleting every exercise cancels the notification.

## Product Modules

| Module | Product role | Current behavior | Durable boundary |
| --- | --- | --- | --- |
| Home | Selected-day dashboard. | Shows deterministic daily summaries and mode-appropriate kcal or macro signals; matching confirmed cache may render before background refresh. | It remains a dashboard, not an AI workbench. |
| Food Log | Official food-record management. | Supports manual entry, external AI JSON paste, copy-to-date, edit, delete, and confirmed AI-assisted records. | Signed-in official writes are cloud-first; every AI result remains a draft until save confirmation. |
| Add Food | Food creation workflow. | AI Food Analysis is first, accepts a text-only description or up to three optional images, and has an independent ChatGPT/Qwen selector; current requests use Qwen, while unconfigured ChatGPT reports unavailable without sending. Manual entry and external AI JSON paste remain available; Paste AI Result is the sole entry for the reusable external-chat prompt. | The provider state does not change the shared Food policy, semantic Preview Gate, privacy, or confirmation boundary. |
| AI | Primary Agent entry. | Provides gated Qwen text and image chat, retained-but-unconfigured ChatGPT selection feedback, cloud history, up to three images, validated Food/Workout Draft cards, scoped read-only RAG, and an Answer basis panel. | Provider credentials stay server-side; AI cannot silently write records or settings. |
| Workout | Official workout-record management. | Supports workout records, custom exercises, retained manual/AI new-record drafts, deterministic calorie heuristics, and draft-resume notification. | Editing saved history is page-local; AI may draft or review but cannot silently change official records. |
| Profile | Account, body, diet, and presentation settings. | Signed-out users see authentication; signed-in users edit one Cloud Profile draft plus separate historical body records. | Cloud Profile is authoritative; official diet changes occur only through Profile confirmation. |
| Export | User-controlled data export. | Supports XLSX and CSV ZIP built from the authoritative record set. | Local cache may accelerate export but is not required for completeness or treated as backup. |

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
- Explanation guide sheets, including the Home strategy guide and Profile current-plan method guide, open as root modal sheets. Their fixed-strength blurred scrim covers and disables the bottom navigation, the sheet bottom stops 12 px above the nav pill footprint, the top keeps at least 64 px of focus space, and long guide text scrolls inside the sheet body instead of shrinking text or covering navigation. Modal guide panels use an opaque elevated surface in the Black Orange theme, preventing page content from showing through while ordinary glass panels retain their existing translucency.
- The root shell does not shrink page bodies or paint a navigation-height strip. Floating-navigation geometry separates screen-space footprint from SafeArea content-space clearance: the former is the pill height plus `max(device bottom safe area, 12)`, while the latter subtracts the safe area already consumed by `SafeArea`.
- Home's first-viewport box uses SafeArea content height minus navigation clearance. Its g/kg macro strip and energy-ratio cards stay inside that box instead of treating navigation reserve as internal spacing. In `energy_ratio`, the calorie card keeps its natural ring, typography, padding, and top placement; the macro card keeps its natural bottom height while the middle space flexes.
- Scrollable reading padding and fixed bottom controls use separate geometry. Food and Workout add CTAs are transparent overlays with their own scroll clearance; like the AI composer, they anchor to the navigation top in screen coordinates with the same visual gap. The dedicated AI Food Analysis action uses the same floating principle but owns a same-width page-background shield only from the action midline to the physical bottom edge, preventing content bleed without recreating a full-width footer plate. Its action, shield, and list clearance use stable bottom `viewPadding` and retain their closed-keyboard screen geometry throughout keyboard travel. The keyboard covers and reveals the action rather than animating it, and input stays gated until the keyboard is fully closed.
- Bottom navigation keeps stable bottom `viewPadding` during keyboard inset animation. The pill does not dip while fields or the AI composer move.
- Keyboard-aware surfaces use the live system inset as the sole owner of vertical movement; they do not cache a device-level keyboard height. A focused editor remains mounted throughout the inset transition instead of being replaced by a separate keyboard-only subtree. Fixed-shape editors follow the inset as one rigid surface without changing their width or height, scrollable forms keep the same field attached and follow the active field with their existing scroll owner, and explicit multi-field flows use one bounded focus transition. A delayed second reveal, keyboard-settle timer, or competing corrective scroll must not move the same field again.
- The AI message list treats the composer as a real obstruction without a full-width footer plate. With the keyboard open or closed, its viewport reuses the same 10 px region gap, 14 px list-bottom padding, and short bottom fade, keeping a consistent 24 px visual distance between the last bubble and composer. The open-keyboard composer keeps a 12 px keyboard gap and the normal glass surface without a theme-colored veil. Manual list scrolling stays locked while the keyboard is visible; the first outside tap or vertical-drag start dismisses the keyboard without activating obscured content. Closing the keyboard restores normal scrolling and the full reading area.
- Full-screen programmatic liquid-gradient AI background; the empty landing state balances visible pink at the top and blue from the lower-middle to the bottom, while a slightly smaller mint center band wraps the center status text. The field uses whole-field warped color sampling, minimum transition widths, and moderate sampling density instead of localized moving blobs or blocky compressed strips. Pre-conversation typing keeps the visible landing motion; after the first message is sent, when a historical conversation is opened, or while a send is pending, the same full-screen field switches to quieter low-amplitude motion so the page never freezes and the background does not compete with chat reading.
- Center status line using the saved Cloud Profile nickname when available.
- Bottom composer.
- Compact model selector near the composer for `ChatGPT` and `Qwen`.
- Left collapsible chat-history sidebar.
- Top-right account/subscription icon.
- No quick chips.
- Compact privacy/status hint.

Interaction and runtime behavior:

- The root navigation is `Home | Food | AI | Workout | Profile`.
- The AI shell defaults to signed-out disabled state.
- The composer is editable; send is enabled only when the user is logged in, online, subscribed, on the active device, and the Supabase Gateway provider is configured.
- The model selector displays `ChatGPT` and `Qwen`. Qwen is configured in the current release. Selecting unconfigured ChatGPT shows a transient `The current model is unavailable.` error; the indicator acknowledges the tap and then slides back to Qwen with the bottom navigation's 240 ms `easeOutCubic` motion. Input is preserved and no request is sent. The automatic return restores UI selection only and never converts the attempted ChatGPT selection into a Qwen request. Exact model names and API keys remain server-side configuration.
- The account/subscription entry opens the current status sheet with account and subscription state, backend status, and user-record summary permission. Sign-out remains in Profile rather than this transient AI sheet. The permission controls whether routed meal-decision and review workflows may use cloud record summaries; when it is off, the Gateway can still use same-chat, Cloud Profile, and document context but reports record-summary dimensions as missing. The center status text reads the saved Cloud Profile nickname before falling back to auth display name.
- Supabase Auth, subscription status, and Cloud Profile access are wired when the build is configured with Supabase URL and anon key.
- The history entry opens the cloud chat-history sidebar, supports creating a new chat, switching sessions, inline renaming through a server RPC, and soft-deleting sessions only after confirmation. An active rename is held at panel scope while the keyboard changes the available height; the field uses the scrollable's normal focus reveal without a delayed corrective movement, so lower sessions do not lose their editor or edit state. The archive entry is not exposed because there is no archived-session recovery UI.
- The AI page calls the `ai-chat-route` Edge Function for Qwen text turns and up to three-image multimodal turns, sends the language inferred from the current user message, then persists accepted user/assistant message text through server-owned RPCs. The retained OpenAI adapter is not called by an unconfigured current-release client.
- The usable Qwen selection is stored locally on the device with `SharedPreferences` without cloud sync. An unavailable ChatGPT selection is not persisted as the active provider and automatically returns to Qwen after brief tap feedback. Readiness remains independent from provider availability and reflects only account, subscription, Profile, device, network, and Gateway gates: the empty-chat composer shows the labeled pill, while the fixed conversation header uses a compact same-row status light that cannot wrap below the provider selector. In-progress sending remains on the send-button spinner and assistant loading bubble.
- AI Chat interaction accents follow the current local FitLog theme: user bubbles, send/review buttons, draft artifact borders, Markdown accents, and selected history rows stay green in the Green theme and switch to soft but clear orange in the Black Orange theme. The ready indicator remains semantic green because it communicates account/subscription/device/Gateway readiness rather than provider choice or brand accent. The AI page liquid background keeps its own pink/mint/blue color field instead of becoming a dark full-page surface.
- Sending clears the composer immediately and shows the user message as a pending bubble that moves only upward from within the visible area to the readable top boundary; it must not overshoot above that boundary, bounce back, or disappear as a whole. The settled boundary keeps about 10 px of clearance below the top controls. Older messages are hard-clipped at the top without a soft fade, the bottom soft fade remains above the composer, an assistant loading bubble is shown while waiting, and a failed send restores the draft. The loading bubble uses conservative client-side progress labels based only on request type and elapsed time, such as sending, waiting, image requests taking longer, or slow server/model response; it does not show model chain-of-thought or claim image recognition, nutrition calculation, RAG retrieval, or summary reads before the app has evidence.
- When one user turn contains both image attachments and text, the message list renders the image attachments as bare rounded right-aligned media above a separate text bubble while keeping the request, pending state, retry, and cloud history as one turn. The floating composer uses a subtle hairline and layered shadow so it stays distinct from the AI background, and its keyboard-close motion stays within the range between the keyboard top and the normal navigation-resting position.
- Assistant messages render through a maintained GitHub-flavored Markdown renderer with app styling, selectable text, no remote image loading, and no link actions. User messages remain selectable plain text. Copying uses the system text-selection menu rather than a separate per-message copy button.
- The AI page can send up to three JPEG/PNG/WebP images through the configured Qwen adapter. Before opening the system camera/gallery picker for Chat image attachments, it stores a small local recovery marker so Android activity recreation can restore composer text and recovered attachments. Food Draft responses open Food Preview after user review, and Workout Draft responses open the existing workout editor draft after user review; both carry a validated target date, show it before review, expose it through the normal themed calendar control, and still require the user to save before any official record is written.
- Server-routed read-only Structured RAG and Document RAG support meal decisions, weekly review, and app-logic answers. They do not store images long-term, change goals automatically, or write official business records from the AI page.
- Unsent composer text is a current-runtime device-local draft. Page switches and disabled states should not clear it automatically; user deletion, send start, logout, or account switch clears it, and a failed send restores the attempted draft.

The AI page can send Qwen text turns and up to three image attachments when all runtime gates are satisfied. It includes compact same-chat text and draft-artifact summaries so the model can follow the active conversation. Server-built context is added only after auth, subscription, and active-device checks: Cloud Profile and app-document snippets may be used for routed read-only workflows, while record summaries require the local user-record summary permission. Assistant messages can show an Answer basis panel that separates reference docs, used data, missing info, and limited actions with human-readable labels. Reference documents use file-name chips rather than full internal paths, and same-chat history is not shown as answer evidence.

Every AI Chat provider reply uses one validated envelope: `output_type` identifies text, Food Draft, Workout Draft, or clarification; `message.text` carries the friendly explanation and review instruction; and `draft` carries the structured artifact. Ordinary Chat uses deterministic high-confidence selection first and bounded model selection only after abstention. The explicit Add Food entry fixes Food Draft without re-inferring intent. OpenAI uses strict Structured Outputs and Qwen uses JSON Mode; the Gateway then applies shared exact validation, semantic consistency checks, and at most one bounded correction. The app displays an explanation or artifact only after final validation, does not allow text to claim a nonexistent draft, and never renders raw provider JSON as assistant Markdown. Food Draft item totals are normalized before review.

One provider-neutral Chat decision owns capability, output family, authorized context, clarification, and current-attachment policy for each turn. A clarification is a persisted, typed, bounded state rather than a repeated sentence: the app renders its allowed options, consumes a reply exactly once with a stable request ID, and either advances the original task or returns a truthful system error. Clear image-and-text requests consume their current images in the same turn. If a follow-up truly needs those pixels, they remain only in an account/session-scoped runtime lease; history reload, restart, local-data clearing, logout, or account switch requires the user to attach them again. Planner, provider, validation, attachment, and clarification conflicts are not presented as user ambiguity.

Draft date resolution is separate from intent/output selection. Supported explicit dates in Chat are resolved by the server; otherwise the currently selected date is used. Ambiguous date language produces clarification. The accepted draft date drives the assistant confirmation, artifact, and editor, while the user can still change it with the calendar before official save.

Availability states:

| State | UI behavior |
| --- | --- |
| Logged in, online, subscribed | Colorful AI background; send enabled; status indicator is semantic green for availability. |
| Waiting for assistant | Background uses quiet low-amplitude color-field motion; assistant loading bubble indicates work in progress. |
| Needs clarification | Background stays quiet; missing-info prompt or draft field is emphasized. |
| Logged out | Gray disabled AI page; send disabled; prompt can be typed but not sent. |
| Offline | Gray disabled AI page; send disabled; profile editing is also disabled. |
| Not subscribed | Gray or locked AI page; send disabled; top-right status explains subscription state. |

## AI Workflows

### Food Estimation

Add Food exposes AI Food Analysis as the first entry. The body omits the redundant explanatory subtitle and orders its controls as heading, independent model selector, large preview, tightly spaced fixed thumbnail rail, food description, and floating analysis action. The user can type a description by itself or add up to three optional camera/gallery images through the preview. The empty preview explains that it adds food photos; after selection it shows the current image and retains only a small lower-right `+` as the add/replace affordance. A bottom source sheet presents Photo and Gallery side by side. Three fixed-size thumbnail slots keep the page height stable, and thumbnail taps switch the enlarged preview. The preview and thumbnail rail use compact internal spacing, while a larger group boundary separates the rail from the description. Gallery selection is limited to the remaining capacity; a full three-image set replaces the current image on the next pick, and over-limit results are rejected rather than silently discarded. The selector is not nested inside another card. The analysis action is a body overlay rather than a `bottomNavigationBar`; list clearance ends above it, while a same-width opaque shield covers only the control's lower half through the screen bottom. The action, shield, normal scroll tree, constant action clearance, focused food-description editor, and focus node all remain mounted during keyboard travel. The live keyboard inset translates only the fixed-size description editor as one rigid surface to maintain its keyboard gap, without a per-frame reveal, corrective scroll, dynamic bottom padding, or subtree replacement. The analysis action, shield, and list clearance keep their closed-keyboard geometry through stable bottom `viewPadding`; the system keyboard covers and reveals the action without changing its opacity or position, and input stays gated until the keyboard is fully closed.

The Paste AI Result compatibility path keeps one fixed-size JSON editor mounted while the live inset translates it as a rigid surface. A short continuous handoff around the resting Parse-action boundary removes the hard velocity change without adding a timer, cached keyboard height, or independent animation controller. The setup card uses the live opening inset to fade out gradually while retaining its layout footprint and state, avoiding a single-frame disappearance without moving or rebuilding the editor. The fixed Parse action remains mounted, input-gated, and naturally covered by the keyboard. The editor's top-right expand action uses a neutral, low-emphasis four-corner icon, enters a pending state, clears focus, and opens no modal until the observed inset reaches zero. The matching collapse action uses the same visual treatment. The root modal has fixed-strength background blur, an opaque elevated JSON panel, no autofocus, and no duplicate Prompt or Parse action. A temporary controller receives the complete `TextEditingValue` and returns edited text and selection to the page when the non-barrier-dismissible modal closes.

Qwen sends the input to the dedicated `ai-food-photo-analyze` Gateway path; selecting unconfigured ChatGPT shows the same transient unavailable error, slides the selector back to Qwen, retains text and images, and sends nothing. Before launching the system camera/gallery picker, the app stores a small recovery marker so an Android activity restart can reopen the analysis draft instead of dropping the user back to an empty Home state. A still-mounted analysis page exclusively owns the picker result, while root recovery runs only when that owner is absent and remains single-flight; returning from Camera therefore cannot stack a second analysis page or expose an older page after Save. The configured image-capable server adapter uses the same Food fact priority, target-language policy, semantic validator, correction limit, and no-write boundary. A successful terminal result must contain a validated Food Draft and cannot be replaced by ordinary explanation text; invalid output keeps the form input for revision. The draft opens in the existing Food Preview editor, and only the user's Save action writes `food_records` / `food_items` with source `ai_photo`.

The draft should include:

- meal name
- candidate food items
- amount or serving estimate
- kcal/protein/carbs/fat
- confidence or uncertainty notes
- missing questions when needed
- source marker such as AI draft

If the AI cannot identify an ingredient or portion, it should ask. For example, if meat type is unclear, it should ask what meat it is rather than guessing.

The current implemented draft surfaces are Food Preview after Add Food AI food analysis, Chat Food Draft artifact cards that rebuild Food Preview after the user taps review, and Chat Workout Draft artifact cards that rebuild the existing workout editor draft after the user taps review. Future richer draft surfaces should stay consistent with the corresponding record editor and support:

- save
- discard
- open full editor

Official records are created only after save confirmation.

### Workout Drafts

AI Chat can return a schema-validated Workout Draft when the user asks to turn a described workout into a record. The assistant shows a readable summary plus a native artifact card. Tapping review rebuilds the existing workout editor draft from the stored snapshot, asks before replacing any unsaved workout draft, and still requires the user to save in the workout editor before any official workout record is written.

Retained workout drafts belong only to new records created manually or handed off from AI. Opening or changing a saved history record uses a page-local edit state; leaving that editor without saving discards the pending changes and does not create a resume bar or workout-in-progress notification.

If Android rebuilds the process while a new-workout editor is active, a local activity hint and the authoritative SQLite draft restore Add Workout automatically only when the draft was updated within the previous 30 minutes. A surviving process keeps the existing route without another push. Older drafts open only through the existing Workout resume bar. Explicit back, discard, and successful save clear the automatic-resume hint; no timer, alarm, foreground service, wake lock, or background keepalive is used. Draft persistence remains critical and ordered, while system-notification rendering is best effort, coalesces rapid field edits, and updates immediately for semantic changes or backgrounding.

Starting the official workout save freezes lifecycle autosave. Cloud-confirmed completion is followed by a final ordered draft deletion, so backgrounding the app during save cannot leave a duplicate stale draft; a failed save preserves the editable draft.

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
- Profile's Clear All Local Data action is a separate device-level SQLite cleanup, not sign-out, account deletion, or cloud-data deletion. After confirmation, it deletes confirmed caches, workout drafts, custom exercises, calibration and review state, and compatibility Profile data from local business tables. It preserves the Supabase session, SharedPreferences preferences, exported files, and all cloud official records. While signed in, surviving cloud official records are written back into local cache as pages refresh; cleared local-only data cannot be restored from cloud.
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

For signed-in accounts, workout, food, and body metric records use the cloud as the official source, and local SQLite is only cache, draft storage, and runtime acceleration. AI reads cloud records or controlled summary/context builders instead of treating local cache as authoritative. Cache-first reads, prefetch, eviction, export correctness, and repair rules live in `CloudLocalDataBoundary.md`.

The Profile body section shows age, height, weight, sex, body-fat percentage, and waist circumference. These are ordinary Profile draft fields with no card-level save button; the bottom Save Changes action persists them with the complete Cloud Profile. Current height, weight, body-fat, and waist values use one-decimal canonical precision: Save Changes normalizes them once before persistence, and the saved snapshot, editor text, and dirty-state comparison all use that same value so formatting cannot reopen the save prompt.

The Body Profile calendar is a separate historical-record entry. It opens on today; choosing today returns to the current Profile without a date badge, while a past date enters the in-page historical editor. The exact date appears under the calendar action, using two-digit years in Chinese and four-digit years in English. Only weight, body-fat percentage, and waist circumference are highlighted and editable. Age, height, sex, the rest of the page, and bottom navigation remain locked with stronger soft fading rather than extra block scrims.

Existing historical records expose a red destructive delete control with confirmation. Deletion soft-deletes the cloud row and local cache mirror, refreshes Body Trends, and may affect calibration or review that uses weight history. A past date without a row starts with empty editable metrics rather than copied current values. Inline editors share the tile surface, keep a stable value slot while focused, and scroll above the keyboard instead of compressing the card. Backfilling history never silently modifies the current Cloud Profile; promoting historical data to current values requires explicit confirmation.

Body Trends is read-only and plots weight, body-fat, or waist over 7/14/21/28-day windows. Controls remain at the bottom, summary text remains above the chart, real points use real date spacing, insufficient-record states appear inside the chart area, and tapping a point reveals its value inline.

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
- app-document chunks
- AI evidence snapshots
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

## Core Logging And Planning Capabilities

The product retains these deterministic capabilities:

- local food CRUD
- external AI JSON paste and local parsing
- prompt copy
- manual food entry
- selected-date Home/Food/Workout flow
- workout record creation/editing/deletion
- custom exercise library
- strength-set entry semantics for total load, per-side load, added bodyweight load, assistance load, total reps, per-side reps, and duration-based sets; the app preserves the visible entry while using normalized calculation values
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

## AI And Account Capabilities

The current product includes:

- Android install identity separated from FitLog Local.
- App label and Flutter app title `FitLog Agent`.
- Five-tab root navigation: `Home | Food | AI | Workout | Profile`.
- Stable five-tab routing and a theme-aware floating bottom-navigation pill.
- Full-screen AI shell at `lib/features/ai/ai_page.dart`.
- Disabled AI state with editable prompt and disabled send button.
- ChatGPT/Qwen provider selector with server-side Gateway routing and server-managed model credentials.
- Cloud chat-history entry with new chat, session switching, inline rename, and delete confirmation; archive is not exposed in the current UI.
- Qwen Chat send path with up to three image attachments, explicit unconfigured-ChatGPT feedback, compact same-chat context, pending user bubbles, assistant loading feedback, semantic status indicators, selectable message text, maintained assistant Markdown rendering, Food Draft handoff to Food Preview, and Workout Draft handoff to the workout editor draft.
- Gateway workflow routing, read-only Structured RAG/Document RAG, the `document_chunks` seed/RPC path, Gateway evidence snapshots, and an AI Chat Answer basis panel for reference docs, used data, missing info, and limited actions.
- Supabase configuration via `SUPABASE_URL` and `SUPABASE_ANON_KEY`, with local SharedPreferences-backed PKCE verifier storage for registration email codes.
- Account controller and repository layer for Auth, subscription status, Cloud Profile, and user-record summary permission.
- Profile auth screen with a solid theme background, no-star FitLog logo base asset, saturated SVG-derived fixed rounded AI four-point sparkle cluster anchored to the logo's upper-right with a slight lower-left placement adjustment, fuller resting scale, staggered breathing pulses, app theme `NotoSansSC` typography with moderate sign-in text weights, and a top backend-configuration notice. Landing, sign-in, and registration share one fixed layout tree: it is locked when the keyboard is closed and gains temporary scroll extent from one inset owner when open. The focused field follows keyboard inset changes immediately and, when movement is required, stops 14 px above the keyboard instead of reserving space for following actions. Explicit Next actions move through the login and registration field chains with one short elastic focus transition; the logo does not resize, and no second reveal waits for keyboard completion. Keyboard close returns the canvas to zero offset. The flow provides email-password sign-in, registration email code, password confirmation, no username requirement, automatic default Cloud Profile creation for accounts without a cloud row, cloud save path, and cached display fallback.
- Persisted Supabase auth-session recovery, AI account/subscription status sheet, Profile header Subscription entry with compact blurred status refresh and internal redeem-code entitlement, user-record summary permission toggle, explicit Profile sign-out account card, and logout/account-switch composer clearing.
- AI shell, chat controller, Gateway contract/client, evidence parsing/rendering, root navigation, mapper, and account-controller tests.

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
- V1 implementation history and rationale: `docs/FitLog_Agent_V1_Implementation.md`
