# App Guide

## Purpose

This guide explains what each app area does and where to read deeper design details. It is navigational. Algorithm formulas belong in `Algorithm.md`; storage details belong in `Database.md`; AI boundaries belong in `AgentDesign.md`.

FitLog_Agent V1 keeps the existing FitLog Local app areas and adds one primary AI area.

## App Navigation

Recommended bottom navigation:

```text
Home | Food | AI | Workout | Profile
```

The AI tab sits in the center because it is the primary Agent entry. The bottom navigation component should be a floating white pill and should not paint a full-width background strip outside the pill.

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
- center status text, personalized with the user's display name
- bottom composer
- left collapsible chat history
- top-right account/subscription icon
- compact privacy/status hint
- no quick chips

Availability:

- logged in, online, subscribed: send enabled
- logged out: gray disabled state
- offline: gray disabled state
- not subscribed: disabled state with account/subscription explanation

Disabled-state rule:

- The user may continue editing an unfinished prompt.
- Send remains disabled until login, network, and subscription requirements are met.

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
- body profile
- diet phase
- calculation mode
- strategy
- training frequency
- self-check settings
- export
- clear local data

Agent V1 profile model:

- Before login, there is no formal profile.
- After login, Cloud Profile is authoritative.
- The device may cache profile values for display.
- Offline profile saving is disabled.
- AI uses Cloud Profile as the default context.
- Account deletion deletes Cloud Profile.

Profile remains the place where official diet settings change. AI can explain or suggest, but settings changes should happen through Profile UI.

Read more:

- Profile source of truth: `AgentDesign.md`
- Profile fields and cloud/local boundary: `Database.md`
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
- Planned Agent V1 behavior: documented target, not necessarily shipped yet.

Do not describe AI Gateway, account login, subscriptions, Cloud Profile, chat history, or RAG as implemented until code exists.
