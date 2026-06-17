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
| AI | Primary Agent entry. | Phase 1 implements the centered tab, disabled AI shell, soft flowing background, editable composer, provider selector placeholder, history placeholder, and account/subscription placeholder. Sending is disabled. | Real auth gating, AI Gateway calls, cloud chat history, food drafts, meal decisions, weekly review, and app logic Q&A. |
| Workout | Official workout-record management. | Local workout records, custom exercises, draft editor, calorie heuristics. | V1 AI may explain or review workout context but should not silently modify records. |
| Profile | Account/profile/diet settings. | Local profile and deterministic diet setup. | Login-gated Cloud Profile, subscription status access, offline save disabled. |
| Export | User-controlled data export. | XLSX and CSV ZIP export. | No default cloud backup/export replacement in V1. |

## AI Chat Experience

The AI page is a simple full-screen chat, not a dashboard of shortcuts.

Navigation:

```text
Home | Food | AI | Workout | Profile
```

Required UI:

- AI tab centered in bottom navigation.
- Floating white bottom-navigation pill; the navigation component itself does not paint a full-width strip outside the pill.
- The AI page enables `extendBody` so the AI background shows beside the pill; normal pages do not enable it yet and may show their existing pale page background to avoid content being hidden behind the navigation bar.
- Full-screen animated AI background.
- Center status line using the user's display name.
- Bottom composer.
- Compact model selector near the composer for `ChatGPT` and `Qwen`.
- Left collapsible chat-history sidebar.
- Top-right account/subscription icon.
- No quick chips.
- Compact privacy/status hint.

Current Phase 1 behavior:

- The root navigation is `Home | Food | AI | Workout | Profile`.
- The AI shell defaults to signed-out disabled state.
- The composer is editable, but send is disabled.
- The model selector displays `ChatGPT` and `Qwen` as UI only.
- The history and account/subscription entries are placeholders.
- No auth, network, AI Gateway, LLM, RAG, chat-history persistence, or official data write occurs from the AI page.

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

Before login, there is no formal profile. After login, profile behaves like account-bound user information.

V1 profile rules:

- Cloud Profile is authoritative.
- Local device may cache it for display.
- Offline profile saving is disabled.
- AI uses Cloud Profile by default.
- Requests can include `profile_version`.
- Account deletion deletes Cloud Profile.

Profile should include the existing profile information needed by FitLog's diet and personalization logic, such as:

- display name or nickname
- age
- height
- weight
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

Workout, food, and weight records remain local by default in V1. They may be summarized for AI only when needed.

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
- weight logs
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

## Implemented Agent Phase 1 Scope

The current Agent shell now implements:

- Android install identity separated from FitLog Local.
- App label and Flutter app title `FitLog Agent`.
- Five-tab root navigation: `Home | Food | AI | Workout | Profile`.
- `RootTabIndex` constants so Home links continue routing Food to index `1` and Workout to index `3`.
- Floating white bottom-navigation pill extracted into `FitLogBottomNavBar`.
- Full-screen AI shell at `lib/features/ai/ai_page.dart`.
- Disabled AI state with editable prompt and disabled send button.
- ChatGPT/Qwen provider selector placeholder.
- History and account/subscription placeholder entries.
- AI shell widget tests and root navigation tests.

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
