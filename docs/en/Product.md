# Product Design

## Purpose

FitLog_Agent V1 is a cloud-assisted AI food and workout logging app built from the FitLog Local baseline.

Its value is not "AI replaces logging." Its value is that deterministic food, workout, diet-target, strategy, and export workflows remain stable, while a subscription-based AI Chat helps users estimate complex food, decide what to eat next, review recent behavior, and understand app rules.

The product promise:

```text
Record locally with deterministic rules.
Use cloud AI when the user asks for help.
Write official data only after the user confirms.
```

## Product Principles

- Preserve Local behavior unless an Agent V1 requirement explicitly changes it.
- Keep food/workout/weight records local by default in V1.
- Treat local food/workout/weight history as a device dataset before any explicit Phase 7 cloud-sync migration.
- Use cloud services for account, subscription, Cloud Profile, AI Gateway, chat history, and AI audit needs.
- Treat the Cloud Profile as account-bound user information after login.
- Do not require users to bring their own model API key.
- Keep `energy_ratio` and `gram_per_kg` separate.
- Keep `diet_goal_phase` as the source of truth for cutting/bulking.
- Treat `diet_plan_strategy` as a deterministic strategy setting, not an AI action.
- Make the AI page the primary Agent entry.
- Avoid silent writes: AI drafts, explains, and asks; users confirm.

## Product Modules

| Module | V1 role | Implemented baseline | V1 planned additions |
| --- | --- | --- | --- |
| Home | Selected-day dashboard. | Local daily summary, diet context, macro/kcal display, compact food/workout cards. | May surface non-intrusive AI entry hints only if routed to AI page. |
| Food Log | Official food-record management. | Manual food entry, external AI JSON paste, copy-to-date, edit, delete. | Receives confirmed Food Drafts from AI Chat or Add Food photo recognition. |
| Add Food | Food creation workflow. | Manual entry, prompt copy, JSON paste, Photo AI placeholder. | Photo recognition shortcut may call AI Gateway and create Food Draft. |
| AI | Primary Agent entry. | Phase 2 implements the centered tab, disabled AI shell, editable composer, provider selector, account/subscription status sheet, subscription/Profile availability gating, and local-record context permission. Sending is disabled until AI Gateway is added. | AI Gateway calls, cloud chat history, food drafts, meal decisions, weekly review, and app logic Q&A. |
| Workout | Official workout-record management. | Local workout records, custom exercises, draft editor, calorie heuristics. | V1 AI may explain or review workout context but should not silently modify records. |
| Profile | Account/profile/diet settings. | Local profile logic remains the compatibility baseline; Phase 2 shows sign-in before login and saves formal profile changes through Cloud Profile when signed in. | Account deletion, production subscription management, and later AI personalization flows. |
| Export | User-controlled data export. | XLSX and CSV ZIP export. | No default cloud backup/export replacement in V1. |

## AI Chat Experience

The AI page is a simple full-screen chat, not a dashboard of shortcuts.

Navigation:

```text
Home | Food | AI | Workout | Profile
```

Required UI:

- AI tab centered in bottom navigation.
- Theme-aware floating bottom-navigation pill; the navigation component itself does not paint a full-width strip outside the pill.
- Non-AI pages use an opaque theme-surface nav pill to cover scrolling content. The AI page uses a glass nav pill so the animated background remains visible.
- The root shell does not shrink page bodies or paint a navigation-height strip. Floating-navigation geometry separates two coordinate systems: the screen-space footprint is the pill height plus `max(device bottom safe area, 12)`, while the SafeArea content-space clearance subtracts the bottom safe area already consumed by SafeArea. Home's first-viewport box uses SafeArea content height minus the nav clearance; the g/kg macro strip and energy-ratio cards stay inside that box instead of using nav reserve as internal spacing. In energy-ratio mode, the calorie card keeps its natural ring, typography, padding, and top placement; the macro card keeps its natural internal height at the bottom, and the middle space flexes. Scrollable bottom reading padding and fixed bottom controls use separate helpers. Food and Workout add CTAs are transparent overlays with their own scroll clearance; like the AI composer, they are anchored in screen coordinates to the nav pill top with the same fixed visual gap, and the AI page background extends behind navigation.
- Full-screen animated AI background; available states use a clearer colorful slow flow, and keyboard-open input pauses background animation to reduce typing jank.
- Center status line using the saved Cloud Profile nickname when available.
- Bottom composer.
- Compact model selector near the composer for `ChatGPT` and `Qwen`.
- Left collapsible chat-history sidebar.
- Top-right account/subscription icon.
- No quick chips.
- Compact privacy/status hint.

Current Phase 2 behavior:

- The root navigation is `Home | Food | AI | Workout | Profile`.
- The AI shell defaults to signed-out disabled state.
- The composer is editable, but send is disabled until Phase 3 AI Gateway.
- The model selector displays `ChatGPT` and `Qwen` as UI only.
- The account/subscription entry opens a Phase 2 status sheet with sign-out and local-record context permission. The center status text reads the saved Cloud Profile nickname before falling back to auth display name.
- Supabase Auth, subscription status, and Cloud Profile access are wired when the build is configured with Supabase URL and anon key.
- The history entry remains a placeholder.
- No AI Gateway, LLM, RAG, chat-history persistence, or official data write occurs from the AI page.
- Unsent composer text is a current-runtime device-local draft. Page switches and disabled states should not clear it automatically; user deletion, successful send, logout, or account switch clears it.

Phase 2 may show a visually ready account/subscription/Profile state, but message sending remains locked until the Phase 3 Gateway and chat-history contract exist.

Availability states:

| State | UI behavior |
| --- | --- |
| Logged in, online, subscribed | Colorful AI background; send enabled. |
| Processing | Background becomes slightly more active; composer indicates work in progress. |
| Needs clarification | Background slows; missing-info prompt or draft field is emphasized. |
| Logged out | Gray disabled AI page; send disabled; prompt can be typed but not sent. |
| Offline | Gray disabled AI page; send disabled; profile editing is also disabled. |
| Not subscribed | Gray or locked AI page; send disabled; top-right status explains subscription state. |

## AI Workflows

### Food Estimation

The user can describe a meal or attach an image. AI produces a Food Draft, not an official record.

The draft should include:

- meal name
- candidate food items
- amount or serving estimate
- kcal/protein/carbs/fat
- confidence or uncertainty notes
- missing questions when needed
- source marker such as AI draft

If the AI cannot identify an ingredient or portion, it should ask. For example, if meat type is unclear, it should ask what meat it is rather than guessing.

The Food Draft appears inside chat as a compact preview card with UI consistent with the food-record page. It supports light editing and actions:

- save
- discard
- open full editor

Official records are created only after save confirmation.

### Meal Decision

The user can ask what to eat next, whether an order fits today, or why the day feels hard to manage.

The answer should use:

- Cloud Profile
- selected-day food summary
- selected-day workout summary
- current diet phase
- current calculation mode
- current strategy
- remaining targets or macro targets

The AI should explain the reasoning in practical terms. It must not recalculate the user's official plan or silently change targets.

### Weekly Review

The user can ask for a weekly or recent review.

The review should use recent summaries rather than uploading full raw history by default. It should cover:

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
- Profile page edits are local drafts until the user taps the bottom Save Changes bar; modified sections are visibly marked in the page, and saving uploads one complete Cloud Profile snapshot.
- Auth failures keep the active sign-in or registration form visible and show readable snackbar feedback.
- Subscription-status loading failures do not replace a successfully loaded Cloud Profile editor with a Profile error screen; AI sending remains gated by subscription availability.
- The Profile header uses a compact Subscription entry with an explicit active/inactive/loading/error status badge. It opens a small blurred overlay, keeping the current plan as the first main card.
- The Profile page provides a bottom Account card for explicit sign-out. Signing out clears the auth session and local singleton Profile cache without deleting local food/workout/weight records.
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

Workout, food, and weight records remain local by default in V1. They may be summarized for AI only when needed. They are not silently attached to a newly signed-in account before a future explicit cloud-sync phase.

The Profile body section shows six fields: age, height, weight, sex, body-fat percentage, and waist circumference. The Body Trends card below it plots local account-scoped weight, body-fat, or waist records over 7/14/21/28-day windows. Trend controls stay at the bottom of the card, summary text stays above the chart, real record points extend from left to right by their real day spacing within the current window, insufficient-record messages appear inside the chart area, and tapping a real record dot shows that point's value inline.

The Profile theme card is a low-frequency setting placed before language settings. Current options are Green and Black, shown as independent tappable options rather than a two-part segmented control so future themes can be added without changing the interaction pattern. Green remains the default. Black uses the Black Orange palette with a dark page background, dark cards, and orange accent color. Orange is reserved for buttons, selected states, icon emphasis, and progress emphasis, not large card fills. The theme preference is stored only in local `SharedPreferences`, not SQLite or Cloud Profile.

## Data And Privacy Model

V1 cloud data:

- account
- subscription
- Cloud Profile
- AI request metadata
- AI sessions
- AI chat messages
- final AI answers
- compact debug/action summaries

V1 local default data:

- food records
- food items
- workout sessions
- workout sets
- weight and body metric logs
- local workout drafts
- exports

AI requests should upload the minimum necessary context. For user-data context, prefer summaries over raw rows.

## User Confirmation Model

AI output categories:

| Output | Official write? | Confirmation rule |
| --- | --- | --- |
| Explanation | No | No save action. |
| Meal suggestion | No | User decides outside AI. |
| Food Draft | Not yet | Save requires confirmation. |
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

## Implemented Agent Phase 1-2 Scope

The current Agent source now implements:

- Android install identity separated from FitLog Local.
- App label and Flutter app title `FitLog Agent`.
- Five-tab root navigation: `Home | Food | AI | Workout | Profile`.
- `RootTabIndex` constants so Home links continue routing Food to index `1` and Workout to index `3`.
- Theme-aware floating bottom-navigation pill extracted into `FitLogBottomNavBar`.
- Full-screen AI shell at `lib/features/ai/ai_page.dart`.
- Disabled AI state with editable prompt and disabled send button.
- ChatGPT/Qwen provider selector placeholder.
- History placeholder entry.
- Supabase configuration via `SUPABASE_URL` and `SUPABASE_ANON_KEY`, with local SharedPreferences-backed PKCE verifier storage for registration email codes.
- Phase 2 account controller and repository layer for Auth, subscription status, Cloud Profile, and local-record context permission.
- Profile auth screen with a solid theme background, no-star FitLog logo base asset, saturated SVG-derived fixed rounded AI four-point sparkle cluster anchored to the logo's upper-right with a slight lower-left placement adjustment, fuller resting scale, staggered breathing pulses, app theme `NotoSansSC` typography with moderate sign-in text weights, top backend-configuration notice, a non-scrolling static landing state when the keyboard is closed, keyboard-aware compact scrolling while auth fields are focused, email-password sign-in, registration email code, password confirmation, no username requirement, automatic default Cloud Profile creation for accounts without a cloud row, cloud save path, and cached display fallback.
- Persisted Supabase auth-session recovery, AI account/subscription status sheet, Profile header Subscription entry with compact blurred status refresh and internal redeem-code entitlement, local-record context permission toggle, explicit Profile sign-out account card, and logout/account-switch composer clearing.
- AI shell, root navigation, mapper, and account-controller tests.

## V1 Non-goals

- full cloud sync of food/workout/weight history by default
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
