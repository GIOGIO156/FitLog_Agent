# App Guide

## Purpose

This guide explains what each app area is for, how its main workflow behaves, and where deeper design rules are maintained. It is a navigation document, not a second copy of every formula, schema, or implementation plan.

| Question | Owning document |
| --- | --- |
| What should the product do, and why? | [Product.md](Product.md) |
| How are targets, summaries, and calorie estimates calculated? | [Algorithm.md](Algorithm.md) |
| What is stored, and in which fields? | [Database.md](Database.md) |
| Which copy is authoritative, cached, refreshed, or repaired? | [CloudLocalDataBoundary.md](CloudLocalDataBoundary.md) |
| What may AI read, propose, or write? | [AgentDesign.md](AgentDesign.md) |
| What output shapes must providers satisfy? | [AIOutputContract.md](AIOutputContract.md) |
| How are context, retrieval, and evidence constructed? | [RAGDesign.md](RAGDesign.md) |

## App Navigation

The root navigation is:

```text
Home | Food | AI | Workout | Profile
```

The centered AI tab is the primary Agent entry. Add Food AI analysis is the deliberate exception because it belongs inside the food-record creation flow.

Navigation follows these durable interaction rules:

- The bottom navigation is a theme-aware floating pill, not a full-width footer.
- Non-AI pages use an opaque theme surface and page-owned lower shielding so scrolling content does not show through the pill. The AI page uses a glass pill so its animated background remains continuous.
- The root shell does not shrink page bodies. Each page owns its reading padding or fixed-action clearance, while shared geometry keeps Home, Food, Workout, and the AI composer aligned to the same navigation footprint.
- Keyboard changes move keyboard-aware controls without making the navigation pill bounce toward the physical screen bottom.
- Explanation guides are root modal reading layers. Their scrim disables navigation, their body scrolls when necessary, and they retain visible space above the navigation footprint.

Exact layout geometry and the rationale behind these choices are maintained in [Product.md](Product.md).

## System Notifications

Pages use `FitLogNotifications` for app-level transient feedback:

- Food and Workout save, delete, and copy success use lightweight top notices. Validation and cloud/local write failures use bottom error notices that remain above navigation and the keyboard.
- Profile success events such as body metric save, Profile save, export ready, sign-out, data clear, redemption success, and registration code sent use top notices. Auth, subscription, export, redemption, validation, and Cloud Profile failures use readable bottom errors.
- AI uses informational notices for neutral unavailable states and the same shared, no-close error notice for failed sends, attachment validation, history operations, or preference saves. Composer-related errors are positioned above the measured composer so they do not cover retry input.
- A notification that offers retry, undo, open-file, or another action must use the shared action-notification API so its callback remains available.
- App-level transient notices keep the compact passive shape used by the app and have no close icon. They expire automatically; a new notice replaces the old one. Switching root tabs, leaving the originating page, or moving the app out of the foreground dismisses stale notices. When a confirmed Food or Workout save closes its editor, one fresh success notice is deliberately shown on the destination page and then follows the same bounded auto-dismiss lifecycle.

On Android, an active unsaved new-workout draft with at least one selected exercise is also mirrored by a system workout-in-progress notification. It represents local draft state, not a background workout or official record. Saved-history editing never creates this notification:

- It points to the next incomplete strength set, follows the most recently completed set while that exercise remains active, then falls back to the first unfinished strength exercise.
- After all strength sets are complete it enters a return-to-save state. Cardio-only or setless drafts use a short return-to-continue message.
- Tapping resumes the same draft; save, discard, or removing every exercise cancels it.
- Android 13+ requests permission when the notification is first needed, and denial does not affect the draft itself.

## Home

Home is the selected-day dashboard. It brings together the selected date, current diet phase/mode/strategy, food summary, workout summary, and compact links to the corresponding record areas.

The primary signal depends on the saved calculation mode:

- In `energy_ratio`, kcal target, intake, and remaining values are primary.
- In `gram_per_kg`, macro gram targets are primary and kcal is auxiliary.

For a recovered signed-in account, Home may render matching account-bound confirmed cache before active-device refresh completes. It must not show another account's cache or require a date switch to recover current-day content. Compact English strategy cards keep the strategy name and hyphen-prefixed detail on separate lines when space is narrow.

Home remains a dashboard rather than an AI workbench. AI questions route to the AI tab unless a future product decision explicitly introduces a Home-specific workflow.

Read more: [Product.md](Product.md), [Algorithm.md](Algorithm.md), [Database.md](Database.md), and [CloudLocalDataBoundary.md](CloudLocalDataBoundary.md).

## Food

Food contains official records for the selected date. Users can view, create, copy, edit, and delete records through the normal confirmed record flow. Manual entry and the compatibility path for externally produced AI JSON remain available.

### AI-Assisted Food Flow

Add Food presents AI Food Analysis as its first entry. The user may provide a text-only description or a description with up to three camera/gallery images. A small local picker-recovery marker allows Android activity recreation to restore the in-progress analysis instead of returning to an empty screen.

A successful analysis creates an editable Food Draft:

- The draft opens in the existing Food Preview editor.
- Fields and visual language remain consistent with normal food records.
- When items exist, meal weight and nutrition totals are derived from the item sum.
- Uncertainty remains visible and may produce a clarification question.
- Only the user's confirmed Save action creates an official record.
- A successful terminal result contains a Food Draft and opens Preview; ordinary explanation text cannot impersonate analysis success.

AI Chat image picking has its own small recovery marker for composer text, selected provider, recovered attachments, and landing-background continuity. Recovery never bypasses account, subscription, active-device, network, or Gateway readiness checks.

Read more: [AgentDesign.md](AgentDesign.md), [AIOutputContract.md](AIOutputContract.md), [Algorithm.md](Algorithm.md), and [Database.md](Database.md).

## AI

AI is the main Agent surface: a full-screen conversation, not a shortcut grid.

### Surface And Interaction

- A continuous programmatic pink/mint/blue liquid-gradient field extends behind the page and the glass navigation pill. The empty landing state has visible whole-field motion; sent, historical, waiting, and reading states use quieter low-amplitude motion so chat content owns attention. The background never becomes a translated static image or a set of obvious moving blobs.
- The landing status uses the saved Cloud Profile nickname when available. The page also provides a bottom composer, compact ChatGPT/Qwen selector, left chat-history entry, top-right account/subscription entry, and compact privacy/readiness hint. It does not use quick chips.
- The composer accepts text and up to three JPEG, PNG, or WebP images. Gallery selection may fill the remaining image limit in one operation. Text routes through the selected server provider; image turns require Qwen multimodal routing. Exact model names and provider keys remain server-side.
- Sending clears the composer immediately and adds a pending user turn. The real pending bubble anchors below the top controls without overshoot or bounce; the assistant loading bubble remains until the accepted response is persisted and reloaded. A failed send restores the attempted draft. The final response does not force a second scroll.
- The message viewport hard-clips older content below the top controls and keeps only a short bottom fade above the composer. Shared measured geometry protects the last message from the composer, navigation, keyboard, and system safe area. The floating composer attaches to the keyboard without acquiring a full-width footer background and never dips below its normal closed position during keyboard transitions.
- Assistant text uses app-styled GitHub-flavored Markdown and selectable text. User messages remain selectable plain text. Remote Markdown images and link actions are disabled. A mixed image-and-text turn displays rounded media above a separate text bubble while remaining one request, retry lifecycle, and history turn.
- Provider choice is device-local and survives restart. Unsent composer text survives tab changes and temporary disabled states during the current runtime; send start, explicit deletion, logout, or account switch clears it, while failure restores it.
- Send errors use the shared passive notice without a close icon and expire after a bounded interval. Editing, retrying, switching sessions, leaving the AI tab, or backgrounding the app clears stale feedback without deleting restored text or images. A normal short background transition does not cancel the request itself; a real timeout, network interruption, or Gateway error is shown after the app is foregrounded.
- Chat history permits only one delete operation at a time. While deletion is pending, the active row shows progress and history-row actions are temporarily disabled, preventing rapid taps across one or several sessions from issuing conflicting requests.

Detailed visual geometry, animation rationale, theme behavior, and Profile auth presentation are maintained in [Product.md](Product.md).

### Availability And Account State

The status pill communicates readiness only. Request activity belongs to the send button and assistant loading bubble.

| State | User-visible behavior |
| --- | --- |
| Logged in, online, subscribed, active device, configured Gateway | `Ready`; sending is enabled. |
| Sending or waiting | Readiness stays stable; the send control and assistant bubble show activity. |
| Logged out or offline | Disabled gray state; the user may still edit an unfinished prompt. |
| Subscription or Cloud Profile unavailable | Gated state with an account/Profile explanation. |
| Gateway, provider, or active-device check incomplete | Preparing or unavailable state; sending remains disabled. |

The account sheet exposes account/subscription state, sign-out, backend configuration warnings, and the user-record-summary permission. The chat-history sidebar supports new chat, session switching, inline rename, and delete with confirmation. Archive is not exposed without a corresponding recovery experience.

### Responses, Drafts, And Evidence

Every accepted provider reply crosses the validated output boundary described in [AIOutputContract.md](AIOutputContract.md). User-facing explanation is separate from structured draft data; raw provider JSON is never rendered as an assistant answer.

Ordinary AI Chat fixes text or draft only for high-confidence requests; when the Gateway cannot decide, the model uses natural language, images, and same-chat context to select a bounded result type. Explicit entries such as Add Food do not participate in this inference. Regardless of selection source, a structurally or semantically inconsistent response is never shown as success.

When a valid Food Draft or Workout Draft is returned, the assistant shows a native artifact card with `Review and confirm` / `查看并确认`:

- The artifact card shows the validated target date. A supported date written in the Chat request overrides the currently selected date; no date expression defaults to the selected date, while an ambiguous date asks for clarification instead of guessing.
- Food review rebuilds Food Preview.
- Workout review rebuilds the existing workout editor draft and asks before replacing another unsaved draft.
- Food Preview and the workout editor show the same draft date through their normal themed calendar control. The date is not exposed as a raw text field and remains user-changeable before save.
- No editor page is kept alive in the background.
- No official record is written until the user saves through the normal editor flow.
- Workout Draft generation may ask at most one clarification turn, then returns an editable best-effort draft or a stable failure.

The client sends only bounded same-chat text and artifact summaries for continuity. The server may add minimum-necessary Structured RAG or Document RAG context for a routed read-only workflow. Record summaries require the user-visible permission; full business history is not uploaded. The Answer basis panel distinguishes reference documents, used data, missing information, and limited actions. Same-chat continuity is not presented as authoritative evidence.

### Supported Workflows

- food image/text estimation
- workout draft generation
- meal-decision advice
- weekly review
- app-logic Q&A

A meal-decision answer without a request image starts by telling the user that they can upload a photo of available ingredients or a delivery-app screenshot for an image-informed recommendation. This tip does not change authorized context, record-summary permission, or confirmation boundaries.

Chinese app-logic questions retrieve Chinese stable documents; English questions retrieve English stable documents. The answer follows the request language even when same-chat content contains another language.

Read more: [AgentDesign.md](AgentDesign.md), [AIOutputContract.md](AIOutputContract.md), [RAGDesign.md](RAGDesign.md), [Product.md](Product.md), and [Database.md](Database.md).

## Workout

Workout contains official workout records and at most one retained new-record draft. Users can create a named record, add built-in or custom exercises, record cardio or strength details, mark supported sets complete, review deterministic calorie estimates, and edit or delete saved records.

The resume bar and Android workout-in-progress notification apply only to a manually created or AI-generated new workout. Editing saved history is page-local: saving commits the update, while leaving without saving discards the pending changes and does not create a retained draft.

AI may explain bounded recent patterns and may return a Workout Draft artifact. It cannot silently create, replace, edit, or delete an official workout record. Clarification is capped at one turn; incomplete values remain editable in the normal workout editor.

The Android workout-in-progress notification described above resumes the same unsaved local draft and never creates a second draft or record.

Once the user starts the official workout save, lifecycle autosave stops. The final cloud-confirmed save clears the local draft only after older queued draft writes have finished, so switching to another app during save cannot resurrect a stale duplicate draft. A failed official save keeps the editable draft for retry.

Read more: [Algorithm.md](Algorithm.md), [Database.md](Database.md), and [AgentDesign.md](AgentDesign.md).

## Profile

Profile contains account-bound identity, body information, diet setup, presentation preferences, export access, and account controls.

### Account And Profile State

- Before login there is no formal Profile; the page presents sign-in/registration rather than the editor.
- Email/password sessions persist across restart. Registration uses an email code and password confirmation; nickname is edited later in Cloud Profile.
- One account has one active device. A newer login replaces the older device, which receives a readable `device_replaced` flow on its next protected cloud interaction.
- After login, Cloud Profile is authoritative. Missing Profile rows are initialized with safe defaults. Cached display values may appear during refresh only when their account metadata matches the recovered account.
- Subscription loading is independent from Profile loading. A subscription failure keeps a successfully loaded editor usable but continues to gate AI sending.
- Profile edits form one page-local draft. Changed sections are marked; Discard restores the saved snapshot and Save Changes writes one complete Cloud Profile. Offline Profile saving is disabled.
- The bottom Account card provides explicit sign-out. Sign-out clears the auth session, runtime drafts, and account-bound local caches without deleting cloud official records.

### Body Profile And Trends

The current body profile includes age, height, weight, sex, body-fat percentage, and waist circumference. Current values save with the complete Cloud Profile; historical weight, body-fat, and waist records use the separate body-record flow.

The Body Profile calendar opens on today. Today returns to the current profile view; a past date opens the in-page historical editor. Only weight, body-fat percentage, and waist circumference are editable there. Missing past records start empty, deletion is confirmed and destructive, non-editable page areas remain visibly locked, and keyboard focus keeps the active editor readable. Saving a past record never silently replaces the current Profile; promoting historical values requires explicit confirmation.

Body Trends is read-only. It supports weight, body-fat, and waist views over 7/14/21/28-day windows, real date spacing, in-chart insufficient-data states, and tappable points with an inline value.

### Settings And Official Changes

The Theme card offers independent Green and Black options before language settings. Green is the default; Black uses the Black Orange palette. Theme preference is local presentation state in `SharedPreferences`, not SQLite or Cloud Profile.

Profile remains the only place where official diet phase, calculation mode, and strategy settings change. AI may explain or recommend, but it cannot apply those changes.

Read more: [Product.md](Product.md), [AgentDesign.md](AgentDesign.md), [CloudLocalDataBoundary.md](CloudLocalDataBoundary.md), [Database.md](Database.md), and [Algorithm.md](Algorithm.md).

## Export

Export is a user-controlled local workflow. XLSX and CSV ZIP remain supported. Export loads the authoritative record set needed for completeness; local cache may accelerate the operation but is not a substitute for cloud official records. Export is not replaced by automatic cloud backup.

Read more: [Database.md](Database.md) and [CloudLocalDataBoundary.md](CloudLocalDataBoundary.md).

## Privacy And Capability Communication

Privacy messages should be visible but compact:

- AI shows a short hint near the composer or account state.
- Profile explains account-bound cloud storage.
- Draft review explains that AI estimates remain drafts until confirmed.

Documentation and UI copy must distinguish:

- **Available behavior:** logging, Profile, export, configured account/cloud flows, AI Chat, chat history, up to three Qwen images, Food/Workout Draft review, and read-only evidence-backed RAG.
- **Conditional behavior:** account, Cloud Records, subscription, Gateway, providers, and Document RAG require the corresponding Supabase configuration, migrations, deployed functions, secrets, and seed data.
- **Boundary behavior:** AI drafts, retrieves, recommends, reviews, and explains; it does not silently write official records, delete data, change goals or strategies, retain original images, or run autonomous tools.
- **Separately approved future scope:** larger image limits, long-term image storage, user-data vector memory, automatic official writes, autonomous actions, production payment management, and account-deletion UI.

Conditional or future behavior must not be presented as generally available without naming its requirement or approval boundary.
