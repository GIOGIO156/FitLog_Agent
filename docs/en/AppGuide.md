# App Guide

## Purpose

This guide explains what each app area does and where to read deeper design details. It is navigational. Algorithm formulas belong in `Algorithm.md`; schema and fields belong in `Database.md`; cloud/local reads, writes, cache, refresh, conflict, and repair rules belong in `CloudLocalDataBoundary.md`; AI boundaries belong in `AgentDesign.md`.

FitLog_Agent V1 keeps the existing FitLog Local app areas and adds one primary AI area.

## App Navigation

Recommended bottom navigation:

```text
Home | Food | AI | Workout | Profile
```

The AI tab sits in the center because it is the primary Agent entry. The bottom navigation component should be a theme-aware floating pill and should not paint a full-width background strip outside the pill. Non-AI tabs use an opaque theme-surface pill plus a same-width page-background lower shield from the pill midline to the screen bottom so scrolling text does not show through the navigation or bottom safe area; the shield must not extend into the pill-to-screen side gaps. The AI tab uses a more transparent glass pill without that shield to keep the animated background visible. The root shell does not shrink page bodies; navigation helpers must distinguish the pill footprint in screen coordinates from the remaining overlap inside a page's SafeArea content. Home's first-viewport box subtracts that nav overlap, while its g/kg and energy-ratio dashboards adapt only the space between sections inside the box without shrinking card internals. Scrollable tabs keep their own bottom reading padding, and Food/Workout fixed bottom CTAs are transparent overlays anchored in the same screen-space nav-relative gap as the AI composer instead of using full-width footer bands.

Explanation guide sheets are temporary reading layers, not page content. Home strategy help and Profile current-plan method help must use the shared root modal guide sheet: the modal scrim covers and disables the bottom navigation, the guide content stops 12 px above the nav pill footprint, the top keeps at least 64 px of focus space, and long content scrolls inside the sheet body.

## System Notifications

Pages should use `FitLogNotifications` for app-level transient feedback.

- Food and Workout success events, including save, delete, and copy completion, use top lightweight notices. Food/Workout validation and cloud/local write failures use bottom error notices that stay above navigation and the keyboard.
- Profile success events, including body metric save, Profile save, export ready, sign-out, data clear, redeem success, and registration code sent, use top lightweight notices. Profile validation, auth, subscription, export, redeem, and Cloud Profile failures use bottom error notices with the readable mapped message or diagnostic detail.
- AI uses info notices for neutral unavailable placeholders and error notices for failed preference saves.
- Any future notification with an action, such as retry, undo, or open file, must use the shared action notification API so the button and callback remain visible.

## Home

Home is the selected-day dashboard.

It shows:

- greeting and selected date
- current diet phase, calculation mode, and strategy context
- daily food summary
- daily workout summary
- calorie or macro target summary depending on mode
- compact links into Food and Workout detail areas

Behavior:

- In `energy_ratio`, kcal target/intake/remaining is the primary signal.
- In `gram_per_kg`, macro gram targets are primary and kcal is auxiliary.
- In English, compact strategy cards render the strategy name on the first line and the hyphen-prefixed detail on the second line, so `Carb cycle` and `Carb Taper` details do not wrap awkwardly on narrow screens.
- Home should not become an AI workbench.
- Any AI-related prompt should route to the AI tab unless the product later explicitly adds a Home-specific AI workflow.

Read more:

- Product behavior: `Product.md`
- Diet logic: `Algorithm.md`
- Current storage: `Database.md`

## Food

Food contains official food records for the selected date.

Existing Local capabilities:

- view food records by date
- add manual food record
- copy records to another date
- edit saved records
- delete saved records
- paste JSON produced by an external AI tool
- locally parse food JSON into preview data

Agent V1 additions:

- confirmed Food Drafts from AI Chat can become official records
- Add Food photo recognition can create a Food Draft
- uncertain AI estimates should ask follow-up questions before saving

Food Draft UI rules:

- Show the draft inside AI Chat as a compact preview card.
- Match the record-page UI style closely enough that users recognize the fields.
- Allow light editing in chat.
- Provide save, discard, and open-full-editor actions.
- Save only after confirmation.

Read more:

- AI draft boundary: `AgentDesign.md`
- Food record storage: `Database.md`
- Food parsing and summaries: `Algorithm.md`

## AI

AI is the main Agent page.

The AI page is a full-screen chat with animated background, not a shortcut grid.

Required layout:

- full-screen background animation
- center status text, personalized with the saved Cloud Profile nickname when available
- bottom composer
- compact model selector for ChatGPT and Qwen near the composer
- left collapsible chat history
- top-right account/subscription icon
- compact privacy/status hint
- no quick chips

Current Phase 2 implementation:

- The AI tab exists as the center tab.
- The AI page background extends behind bottom navigation and keeps a subtle white bottom veil; available states use a clearer colorful slow flow, keyboard-open input pauses the background animation to reduce typing jank, and the AI tab uses a glass nav pill. Other scrollable pages use an opaque theme-surface nav pill and reserve bottom reading space inside their own content instead of relying on a root-level navigation strip.
- The page defaults to a signed-out disabled shell.
- The composer accepts text, but the send button is disabled until Phase 4 AI Gateway.
- ChatGPT/Qwen selection is a local UI placeholder and does not call a provider.
- The account/subscription entry opens the Phase 2 account sheet when account services are available. The center status text reads the saved Cloud Profile nickname before falling back to auth display name.
- The sheet shows account/subscription state, sign-out, backend configuration warnings, and user-record summary permission; Phase 2 does not upload history, and after Phase 3 summary sources should move to cloud summary/context builders.
- Supabase Auth, subscription status, and Cloud Profile access are wired when the app is built or run with Supabase configuration.
- The history entry is still a placeholder.
- No AI Gateway, cloud chat history, RAG, or LLM call is implemented yet.

Availability:

- logged in, online, subscribed: send enabled
- logged out: gray disabled state
- offline: gray disabled state
- not subscribed: disabled state with account/subscription explanation

Current note: even when account, subscription, Cloud Profile, and Cloud Records gates are ready, sending remains disabled until the Phase 4 Gateway exists.

Disabled-state rule:

- The user may continue editing an unfinished prompt.
- Send remains disabled until login, network, and subscription requirements are met.
- Unsent composer text should survive tab switches and disabled states within the current runtime. It clears when the user deletes it, a send succeeds, logout occurs, or the account changes.

Supported workflows:

- food image/text estimation
- meal decision advice
- weekly review
- app logic Q&A

Language behavior:

- Chinese questions retrieve Chinese documents.
- English questions retrieve English documents.

Read more:

- Agent boundary: `AgentDesign.md`
- Product scope: `Product.md`
- RAG and cloud storage: `Database.md`

## Workout

Workout contains official workout records.

Existing Local capabilities:

- create a named workout record
- add one or more exercises
- use built-in exercises
- create temporary or reusable custom exercises
- record cardio duration and intensity basis
- record strength sets with supported input modes
- save completed strength sets
- estimate workout calories deterministically
- edit or delete saved records

Agent V1 boundary:

- AI may explain recent workout patterns in Weekly Review.
- AI may use workout summaries for meal-decision context.
- AI should not silently create, edit, or delete workout records in V1.

Read more:

- Workout calories: `Algorithm.md`
- Workout tables: `Database.md`

## Profile

Profile contains account-bound user information and diet setup.

Local baseline:

- nickname
- body profile: age, height, weight, sex, body-fat percentage, and waist circumference
- Body Trends: reads the partial cache for cloud `body_metric_logs`; when no cache exists, the current window can be restored from cloud
- diet phase
- calculation mode
- strategy
- training frequency
- self-check settings
- export
- clear local data

Agent V1 profile model:

- Before login, there is no formal profile.
- Before login, Profile should show a login/onboarding entry instead of the local profile editor.
- The current signed-out screen uses a solid theme background, the no-star FitLog logo base asset with a saturated SVG-derived fixed rounded AI four-point sparkle cluster anchored to the logo's upper-right, a slight lower-left placement adjustment, fuller resting scale, staggered breathing pulses, app theme `NotoSansSC` typography with moderate sign-in text weights, a top backend-configuration notice when needed, a static non-scrolling no-keyboard landing action, keyboard-aware compact scrolling while fields are focused, email-password sign-in, and a registration form with email code plus password confirmation. Registration does not ask for username; nickname is edited later in Cloud Profile.
- Sign-in and registration errors keep the active form in place and use readable shared system notification messages instead of raw backend exception text.
- A successful sign-in persists the Supabase session on the device; the user remains signed in after app restart until they explicitly sign out.
- V1 uses one active device per account. A newer device login takes over the account. When an older device receives `device_replaced` during the next cloud read, save, subscription refresh, or AI request, it should show "account signed in on another device", clear local sign-in state, and return to sign-in/re-takeover flow instead of showing a generic upload failure.
- After login, Cloud Profile is authoritative.
- If a newly registered or newly signed-in account has no Cloud Profile row yet, the app creates a default Cloud Profile automatically and opens the normal Profile editor.
- Cloud Profile load/save failures should show a readable message plus a diagnostic error code such as schema mismatch, RLS denial, expired session, network failure, or missing table.
- A subscription-status loading failure should not block the Profile editor when the Cloud Profile loads successfully; AI sending remains disabled until subscription status is available and active.
- The Profile header has a compact Subscription entry with an explicit active/inactive/loading/error status badge. It opens a small blurred overlay showing account entitlement, refresh status, and a development internal-code redemption action. This is an internal Phase 2 testing path, not a production payment flow.
- Profile edits are staged as a local page draft. Nickname and current body fields do not have card-level save buttons; changed cards show a visible modified marker, the bottom bar stays anchored near the bottom of the Profile body, expands upward with the unsaved count and a compact field list, Discard restores the last saved Cloud Profile, and Save Changes writes one full profile snapshot.
- The Body Profile card provides the calendar/add body-record entry, and the picker only allows past dates. After the user selects a date, Profile stays in an in-page historical body-record edit state: the exact date appears under the calendar action, Chinese dates use a two-digit year, English dates use a four-digit year, only weight, body-fat percentage, and waist circumference are highlighted and editable, and age, height, sex, the rest of the page, and bottom navigation are locked with stronger soft fading instead of extra block scrims. Inline editors share the metric tile surface, keep the value area height stable while focused, and keyboard focus scrolls the active editor above the keyboard. Backfilling a past date must not silently update the current Cloud Profile; setting a historical row as current body profile requires explicit confirmation.
- The Body Trends card sits directly below Body Profile and is read-only; it does not provide a record entry. It supports weight, body-fat, and waist charts; 7/14/21/28-day ranges; real record points extending from left to right by real day spacing within the current window; inline insufficient-record states inside the chart; and tappable record dots with an inline value readout.
- The Theme card lives before language settings in the low-frequency Profile settings area and supports independent Green and Black tap options. Green remains the default; Black only changes color tokens and accents, not records, algorithms, or cloud boundaries.
- The device may cache profile values for display, but local cache failure should not block a successfully loaded Cloud Profile. During a cloud refresh, cached Profile values may be shown only when account-bound cache metadata matches the current signed-in account.
- Offline profile saving is disabled.
- AI uses Cloud Profile as the default context.
- Account deletion deletes Cloud Profile.
- After Phase 3, food, workout, and body metric official records use the cloud as the authoritative source; local SQLite is only cache, draft storage, and runtime acceleration. Read/write, cache-first, prefetch, eviction, failure, and repair rules live in `CloudLocalDataBoundary.md`.
- The bottom account card provides explicit sign-out. Signing out clears the auth session and runtime drafts; account-bound cache cleanup rules live in `CloudLocalDataBoundary.md`, and sign-out must not delete cloud official records.
- An older device replaced by a newer login cannot continue saving Profile, body, food, or workout records.

Profile remains the place where official diet settings change. AI can explain or suggest, but settings changes should happen through Profile UI.

Read more:

- Profile source of truth: `AgentDesign.md`
- Cloud/local boundary: `CloudLocalDataBoundary.md`
- Profile fields and schema: `Database.md`
- Diet setup logic: `Algorithm.md`

## Export

Export remains a user-controlled local workflow.

Existing export formats:

- XLSX
- CSV ZIP

Export covers raw records and useful runtime summaries from the Local baseline. V1 does not replace export with automatic cloud backup.

Read more:

- Export coverage: `Database.md`

## Privacy And Status Hints

The app should keep privacy messaging visible but small.

Recommended placement:

- AI page: compact hint near composer or account/subscription status.
- Profile: account/profile cloud storage explanation.
- Food Draft: brief note that AI estimates are drafts until confirmed.

Avoid large explanatory blocks in normal task flows.

## Implemented Vs Planned

When writing UI copy or documentation, keep these states separate:

- Implemented Local behavior: already present in the copied codebase.
- Implemented Agent Phase 1-2 behavior: the centered AI tab, disabled AI page, editable composer, provider selector, account/subscription status sheet, Cloud Profile Profile gate, user-record summary permission, and floating five-tab bottom navigation.
- Phase 3 has connected the Cloud Records Foundation and its main hardening chain, including `body_metric_logs`, cloud official food/workout records, the `daily_summaries` table, app-side summary cloud upsert/recovery, local partial cache, Home selected-day summary cache with stale-while-revalidate, bounded recent-summary warm cache, confirmed-cache eviction, and cloud-backed export completeness.
- Planned Agent V1 behavior: documented target, not necessarily shipped yet.

Do not describe AI Gateway, cloud chat history, RAG, Food Draft writeback, or LLM calls as implemented until code exists. Account login, subscription status, Cloud Profile, and Cloud Records require Supabase configuration to test against a real backend.
