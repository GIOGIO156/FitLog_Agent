# Changelog

## 2026-06-18 Phase 1 Visual Cleanup

### Fixed

- Adjusted the AI composer keyboard spacing so the input pill sits just above the virtual keyboard instead of being pushed far upward by duplicated inset handling.
- Limited `extendBody` to the AI tab so normal Home/Food/Workout/Profile content no longer scrolls underneath the floating bottom navigation.
- Disabled Scaffold keyboard resizing on the AI tab and positioned the composer from the keyboard inset directly for more reliable on-device behavior.
- Moved the AI center status upward based on keyboard height so the provider/status pills and input composer no longer overlap the sign-in message.
- Restored the normal root shell scaffold background for non-AI tabs so their bottom-navigation slot matches the existing pale page background instead of turning white.
- Reworded the AI composer hint to the shorter branded prompt `Ask away with FitLog` / `快问问 FitLog`.

### Changed

- Folded the durable Phase 1 plan details into `docs/ROADMAP.md` and removed the standalone `docs/PHASE_1_ENGINEERING_PLAN.md` file to avoid duplicate source-of-truth drift.
- Documented the AI-only `extendBody`, bottom veil, keyboard, and future scroll-padding rules in the durable design docs.
- Clarified that future AI message lists must share bottom-obstruction geometry with the composer so keyboard focus does not leave chat content behind the input.
- Replaced the default Android launcher icon with the FitLog Agent mark in all mipmap densities.
- Bumped the debug build version to `1.0.6+7` so Android installs this visual cleanup as a clear app update.

### Validation

- Ran `dart format lib test`.
- Ran `flutter analyze`: no issues found.
- Ran `flutter test`: all tests passed.
- Ran `flutter build apk --debug`: built `build\app\outputs\flutter-apk\app-debug.apk`.

## 2026-06-18 Phase 1 AI Shell

### Added

- Added the centered `AI` root tab and a Phase 1 AI chat shell with a soft flowing disabled background, editable composer, ChatGPT/Qwen provider selector placeholder, history placeholder, and account/subscription placeholder.
- Added `RootTabIndex` constants and a reusable `FitLogBottomNavBar` so the five-tab shell keeps Home/Food/AI/Workout/Profile ordering explicit.
- Added widget coverage for the disabled AI composer, provider selector shell behavior, small-phone AI layout, bottom navigation item order, and centered AI index.

### Changed

- Updated Home record/dashboard shortcuts to route Food through index `1` and Workout through index `3` after inserting the AI tab at index `2`.
- Updated README, roadmap, and bilingual Product/AppGuide/AgentDesign docs to distinguish the implemented AI shell from still-planned auth, subscription, Cloud Profile, AI Gateway, LLM, RAG, cloud chat history, and Food Draft writeback.

### Validation

- Ran `dart format lib test`.
- Ran `flutter analyze`: no issues found.
- Ran `flutter test`: all tests passed.
- Ran `flutter build apk --debug`: built `build\app\outputs\flutter-apk\app-debug.apk`.

## 2026-06-18 Home Record Copy Cleanup

### Fixed

- Shortened the Home `Today's Records` food summary in English from `x meals logged` to `x meal(s)` so it no longer wraps awkwardly on small screens.
- Shortened the Chinese workout summary from `已记录 x 次训练` to `已记录 x 次` to avoid repeating the row title.

### Validation

- Ran `dart format lib\core\localization\app_strings.dart`.
- Ran `flutter analyze`: no issues found.
- Ran `flutter test`: all tests passed.
- Ran `flutter build apk --debug`: built `build\app\outputs\flutter-apk\app-debug.apk`.

## 2026-06-18 Android Agent Install Identity

### Changed

- Changed the Android `applicationId`, namespace, and `MainActivity` package from the copied Local identity to `com.fitlog.agent.fitlog_agent` so Agent debug builds can install beside the existing FitLog Local app instead of overwriting it.
- Changed the Android launcher label and Flutter app title to `FitLog Agent` so the test app is clearly distinguishable on-device.
- Documented the Local naming residue audit in the roadmap, keeping Dart package imports, the local SQLite database name, export filenames, and platform names outside Android unchanged for now to avoid unnecessary refactor risk.

### Validation

- Ran `dart format lib\core\localization\app_strings.dart`.
- Ran `flutter analyze`: no issues found.
- Ran `flutter test`: all tests passed.
- Ran `flutter build apk --debug`: built `build\app\outputs\flutter-apk\app-debug.apk`.
- Confirmed the generated debug manifests use package `com.fitlog.agent.fitlog_agent`, label `FitLog Agent`, and activity `com.fitlog.agent.fitlog_agent.MainActivity`.

## 2026-06-17 Dual Provider Selection

### Changed

- Updated the Agent V1 AI provider decision from Qwen-only to user-selectable ChatGPT/OpenAI and Qwen routing from the AI Chat composer.
- Added `model_choice` to the AI Gateway contract so Flutter sends the user's provider selection while model names and API keys remain server-side configuration.
- Clarified the AI Chat UI requirement for a compact ChatGPT/Qwen selector in the implementation source, roadmap, and bilingual Product/AppGuide/AgentDesign docs.
- Kept exact API key creation steps and concrete model names as Phase 3 implementation tasks to be filled from official provider consoles when the AI Gateway is built.

### Validation

- Documentation-only change; no runtime code, database schema, Flutter dependencies, or backend resources were changed.
- Flutter analysis and tests were not run because this only updates design and contract documents.

## 2026-06-17 Phase 0 Technical Decisions

### Changed

- Locked the Phase 0 backend choice to Supabase Auth, Postgres, Storage, and Edge Functions so account, Cloud Profile, chat history, request logs, document chunks, temporary attachments, and AI Gateway can share one backend boundary.
- Locked the first login method to FitLog-owned email OTP accounts and kept guest profiles, Apple login, Google login, and phone login out of the V1 starting scope.
- Locked development subscription gating to server-side internal entitlements with seeded subscribed and unsubscribed debug accounts, while deferring the production payment provider decision.
- Locked the initial AI provider direction to OpenAI/ChatGPT and Qwen server-side adapters, with model names and keys kept out of Flutter.
- Locked image handling to compressed uploads into a private Supabase Storage temporary bucket, with attachment references passed to AI Gateway and original images not stored long-term by default.

### Validation

- Documentation-only change; no runtime code, database schema, Flutter dependencies, or backend resources were changed.
- Flutter analysis and tests were not run because this only updates Phase 0 design and contract documents.

## 2026-06-17 Phase 0 Contract Audit

### Added

- Added `docs/API_CONTRACT_DRAFT.md` as the Phase 0 API contract draft for endpoint shape, common envelopes, Cloud Profile fields, AI Gateway request/response shape, Food Draft schema, context objects, chat history models, request logs, debug summaries, attachment policy, and Document RAG scope.

### Changed

- Linked the Phase 0 contract draft from README and the Roadmap so implementation work can distinguish locked boundaries from unresolved provider choices.
- Clarified that Phase 0 is not yet complete because backend provider, first login method, subscription provider, AI provider/model calling, and image transport/retention details still require explicit product/engineering decisions.

### Validation

- Documentation-only change; no runtime code, database schema, or Flutter dependencies were changed.
- Flutter analysis and tests were not run because Phase 0 did not touch code.

## 2026-06-17 Agent V1 Design Baseline

### Added

- Added the Agent V1 design baseline across README and the bilingual design document set.
- Added the `docs/FitLog_Agent_V1_Implementation.md` design source as the basis for the target Agent version.
- Added `docs/ROADMAP.md` as a Chinese engineering roadmap from the copied Local source to Agent V1, with staged implementation steps, validation methods, and manual review gates.

### Changed

- Reframed the project from the copied FitLog Local baseline into a cloud-assisted Agent V1 target while preserving Local deterministic food, workout, diet, strategy, and export behavior.
- Clarified that Agent V1 may use cloud accounts, subscription, Cloud Profile, AI Gateway, remote LLM calls, scoped Structured RAG, and Document RAG because those are explicit Agent-version goals.
- Kept food/workout/weight history out of default full cloud sync for V1 to avoid turning the first Agent version into a full cloud data platform.
- Defined the documentation set responsibilities so durable product, app, method, algorithm, database, Agent, and reference facts are stored in the right files instead of drifting into running notes.
- Linked the implementation design source and roadmap from README so future work can distinguish the V1 target design from the staged engineering execution plan.

### Validation

- Confirmed the target documentation tree exists under `docs/en` and `docs/zh`.
- Confirmed the Local design baseline remains available under `docs/local`.
- Confirmed current source code still reflects the copied Local implementation: no AI Gateway, account system, subscription UI, app-internal LLM, RAG, or Agent loop is implemented yet.
- Documentation-only change; `flutter analyze` and `flutter test` were not run.
