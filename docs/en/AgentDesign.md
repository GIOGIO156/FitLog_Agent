# Agent Design

## Purpose

This document defines the AI and Agent boundary for FitLog_Agent V1.

FitLog_Agent starts from the copied FitLog Local implementation. The current codebase still provides deterministic local food logging, workout logging, profile settings, diet algorithms, SQLite storage, and export. Phase 1 now adds the centered AI tab and disabled AI shell, while the cloud-assisted AI layer remains planned for later phases. Agent V1 does not turn the app into an autonomous coach or a full cloud-sync platform.

The durable rule is:

```text
AI may draft, explain, retrieve context, and ask follow-up questions.
AI must not silently write official records, change goals, change strategies, or delete data.
```

## Current Implementation Baseline

The current source has no app-internal LLM execution. Phase 1 implements only the AI navigation entry and disabled chat shell.

Not implemented in the current code:

- account login
- cloud profile
- subscription enforcement
- AI Gateway
- server-managed model API keys
- remote LLM or multimodal model calls
- embeddings
- vector database
- app-internal RAG
- tool calling
- Agent loop
- AI conversation memory
- Agent action/debug logs

Existing AI-adjacent features are user-mediated, not app-internal AI:

| Feature | Current behavior | App-internal AI? | Main code |
| --- | --- | --- | --- |
| Prompt copy | The app provides prompt text that the user can copy into an external model. | No | `PromptTemplates`, `AddFoodPage._copyPrompt` |
| External AI JSON paste | The user manually pastes JSON produced outside the app. FitLog parses it locally. | No | `PasteAiResultPage`, `NutritionCalculator.parseAiFoodJson` |
| `source = ai_paste` | Saved food records can mark that the source was an AI paste workflow. | No | `AppConstants.sourceAiPaste`, `FoodRecord.source` |
| Photo AI Analysis | Visible placeholder entry point in Add Food. | No | `AddFoodPage` |
| AI Chat shell | Centered AI tab with disabled background, editable composer, provider selector placeholder, history placeholder, and account/subscription placeholder. It cannot send. | No | `AiPage`, `FitLogBottomNavBar` |

## V1 Agent Positioning

Agent V1 is a weak-Agent workflow layer, not an autonomous multi-step agent.

V1 adds:

- cloud account and subscription status
- Cloud Profile attached to the logged-in account
- server-managed model API keys
- AI Gateway
- remote LLM and multimodal model calls
- user-selectable ChatGPT/OpenAI and Qwen provider routing inside AI Chat
- a centered full-screen AI Chat tab
- cloud chat history
- scoped Structured RAG over minimal summaries
- Document RAG over FitLog design/help documents
- schema-validated AI outputs
- inline draft preview cards in chat
- user confirmation before official writes

V1 does not add:

- user-supplied model API keys
- open-ended autonomous Agent loops
- multi-Agent systems
- silent meal-plan execution
- silent goal updates
- silent `carb_cycling` or `carb_tapering` changes
- default full cloud sync for food/workout/weight history
- user-data vector databases
- long-term semantic memory over business records
- GraphRAG
- medical diagnosis or treatment guidance

## Entry Points

The primary Agent entry is the new AI tab in the center of the bottom navigation:

```text
Home | Food | AI | Workout | Profile
```

The AI page is a simple full-screen chat surface. It is not a quick-chip workbench. Apart from the Add Food photo-recognition path, other Agent workflows should start from the AI page.

Allowed entry points:

| Entry | Purpose | Boundary |
| --- | --- | --- |
| AI Chat tab | Main Agent entry for food estimation, meal advice, weekly review, and app logic Q&A. | Requires login, network, and active subscription to send. |
| Add Food photo recognition | Shortcut for food image analysis inside the Food flow. | Still produces a draft; user confirms before save. |
| Existing external JSON paste | Local compatibility workflow. | User-mediated external AI, not Agent V1. |

## AI Page Behavior

The AI page uses a full-screen animated background and a minimal chat layout.

Required elements:

- full-screen animated background
- center status copy using the user's display name, such as "I'm listening, RINKO"
- bottom composer
- compact model selector for ChatGPT and Qwen near the composer
- right-top account/subscription status icon
- left collapsible cloud chat-history sidebar
- no quick chips
- compact privacy/status hint when needed

Animation states stay simple:

| State | Visual behavior | Product meaning |
| --- | --- | --- |
| Ready | Soft colorful slow flow. | AI is available and waiting. |
| Processing | Slightly faster or more layered flow. | The request is routing, retrieving context, or generating. |
| Needs clarification | Slower flow with input or draft card emphasis. | AI needs user-supplied missing information. |
| Disabled | Gray, low-motion background. | User is offline, logged out, or not subscribed. Composer remains editable, but send is disabled. |

When messages grow into a scrollable list, the animated background remains present but should be dimmed and desaturated behind the message layer for readability.

The bottom navigation should be a floating white pill. The component itself may use a soft glass or near-opaque surface, but it should not paint a full-width green strip behind the pill. This applies globally so switching between AI and non-AI pages does not create a sharp background-band change.

## Supported V1 Workflows

### Food Draft Workflow

Inputs:

- text description
- food photo
- optional user corrections
- cloud profile
- selected date if relevant
- minimal local day summary if relevant

Behavior:

1. AI extracts candidate foods, portions, cooking method, and uncertainty.
2. If food type, meat type, portion, consumed amount, or cooking method is unclear, AI asks a follow-up question instead of forcing a confident estimate.
3. AI returns schema-validated draft data.
4. The app shows an inline Food Draft card in chat, matching the record-page UI style.
5. The user may make light edits in chat.
6. The user may save, discard, or open the full food editor.
7. Official food records are written only after confirmation.

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
- 7/14-day local summaries
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

### Structured RAG

Structured RAG means the app or backend calls known context-builder functions and sends compact structured summaries to the AI Gateway.

Examples:

- `daily_summary`
- `recent_food_summary`
- `recent_workout_summary`
- `weight_trend_summary`
- `profile_context`
- `strategy_context`
- `selected_day_context`

Rules:

- Upload the minimum necessary context for the current request.
- Prefer summaries over raw records.
- Preserve deterministic local calculations as the source for targets and summaries.
- Do not upload full food/workout/weight history by default in V1.

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

V1 cloud storage is used for account-bound AI experience, not for complete business-data migration.

Cloud-stored in V1:

- account identity
- subscription status
- Cloud Profile
- AI chat sessions
- AI chat messages
- final AI answers
- AI request/response metadata
- compact debug/action summaries for operations and troubleshooting

Not cloud-synced by default in V1:

- full food history
- full workout history
- full weight history
- local export archives
- local workout drafts

Local records may be summarized and temporarily sent to the AI Gateway when needed for a user request.

## Cloud Profile

Profile belongs to the account. Before login, the user has no formal profile.

Rules:

- Cloud Profile is the authoritative profile after login.
- The device may cache the profile for display.
- Offline profile editing is disabled.
- If the user is offline, the Profile page may show cached values but cannot save changes.
- AI uses Cloud Profile as the default authoritative context.
- Requests may include `profile_version` to detect stale context.
- Account deletion deletes Cloud Profile.

Because offline profile saving is disabled, V1 avoids pending-profile merge conflicts. If a future version allows offline edits, it must define a field-level merge policy before implementation.

## Subscription And Availability

V1 uses subscription gating rather than user-visible per-message credits.

AI send is disabled when:

- user is not logged in
- device is offline
- subscription is inactive

The app may still let the user type or edit an unfinished prompt in disabled states. Sending requires all gates to pass.

Backend may log request counts and model cost internally, but V1 should not show a quota or remaining-credit UI unless that product decision changes.

## Request, Response, And Debug Retention

Default V1 recommendation:

- Save AI sessions and final chat messages in cloud so history works across devices after login.
- Save request/response metadata for reliability, billing audit, abuse prevention, and debugging.
- Store compact debug summaries instead of verbose raw chain-of-thought or unrestricted tool traces.
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
| Modify workout record | Draft or explanation only in V1 | Yes if implemented |
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

Current Local baseline:

- App shell: `lib/main.dart`, `lib/app.dart`
- AI shell: `lib/features/ai/ai_page.dart`
- Bottom navigation: `lib/core/widgets/fitlog_bottom_nav_bar.dart`
- Food entry and AI-adjacent paste flow: `lib/features/food/*`
- Prompt templates: `lib/core/constants/prompt_templates.dart`
- JSON parser: `lib/domain/services/nutrition_calculator.dart`
- Daily summaries: `lib/domain/services/daily_summary_service.dart`
- Diet targets: `lib/domain/services/macro_target_calculator.dart`
- Strategies: `lib/domain/services/carb_cycling_calculator.dart`, `lib/domain/services/carb_taper_review_service.dart`, `lib/domain/services/diet_plan_strategy_service.dart`
- Workout calories: `lib/domain/services/workout_calorie_calculator.dart`
- Database: `lib/data/db/app_database.dart`
- Repositories: `lib/data/repositories/*`

Planned Agent V1 surfaces:

- cloud auth/session layer
- Cloud Profile repository
- AI Gateway client
- context-builder services
- chat-history repository
- draft-card UI components
