# Changelog

## 2026-06-27 Guide Sheet Navigation Fix

### Fixed

- Unified the Home strategy guide and Profile current-plan method guide on a shared root modal guide sheet, removing the Profile page-local overlay/early-return path that left the root bottom navigation highlighted, clickable, and visually mixed with an extra full-width overlay.

### Changed

- Added shared guide-sheet geometry for explanation sheets: modal scrim over root navigation, 12 px clearance above the nav pill footprint, at least 64 px of top focus space, and internal body scrolling for long guide copy.
- Updated bilingual Product and AppGuide docs with the guide sheet and bottom-navigation interaction rules.

### Validation

- Ran `dart format lib\core\widgets\fitlog_guide_sheet.dart lib\features\home\home_page.dart lib\features\profile\profile_page.dart test\home_page_test.dart test\phase2_account_controller_test.dart`.
- Ran targeted `flutter test test\home_page_test.dart test\phase2_account_controller_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Ran `flutter build apk --debug`.
- Ran `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`.

## 2026-06-27 Phase 3 Hardening Completion

### Added

- Added app-side cloud `daily_summaries` upsert/recovery so Home and later AI/export builders can use a rebuildable cloud projection instead of trusting complete local SQLite.
- Added a low-priority 30-day summary warm-cache coordinator that runs after the signed-in shell renders, plus confirmed-cache eviction for old rebuildable local record/summary cache.
- Added export hardening: CSV/XLSX export now refreshes cloud-backed food, workout, and body metric records before building tables, and includes a Body Metrics table.

### Changed

- Successful food, workout, and Profile writes now schedule affected-date summary cache/cloud projection refresh without blocking the foreground write result.
- Updated bilingual design docs and roadmap to mark the Phase 3 main cloud/local hardening chain as landed, while keeping AI Gateway, chat history, RAG, and Food Draft writeback in later phases.

### Validation

- Ran `dart format lib test`.
- Ran `flutter analyze`.
- Added `test/daily_summary_cloud_cache_test.dart` for summary cloud fallback/upsert behavior.

## 2026-06-27 Phase 3 Home Summary Cache Migration Repair

### Fixed

- Bumped the local SQLite schema to v15 and added an idempotent `daily_summary_cache` repair so devices that installed an intermediate v14 build receive the `summary_json` cache column and account/date unique index without clearing local data.
- Kept selected-day summary cache writes off the Home critical path: if the optional local cache write fails, Home still displays the freshly built summary.

### Validation

- Ran `dart format lib\data\db\app_database.dart lib\domain\services\daily_summary_service.dart test\daily_summary_cache_test.dart`.
- Ran targeted `flutter test test\daily_summary_cache_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Confirmed the required documentation tree and searched for replacement characters.
- Rebuilt debug split APKs with `config/supabase.local.json`.

## 2026-06-27 Phase 3 Cache-First Hardening

### Added

- Added selected-day `daily_summary_cache` support for Home, including `DailySummary` JSON round-trip serialization for dashboard totals and compact food/workout records.
- Added Home stale-while-revalidate behavior: matching confirmed summary cache renders first, then the selected day is rebuilt in the background and the local confirmed summary cache is refreshed.
- Added a non-blocking signed-in startup path so persisted sessions can enter the tab shell before active-device claim, subscription refresh, and Cloud Profile refresh finish.

### Changed

- Kept matching cached Cloud Profile data visible while background account refresh runs, avoiding a downgrade back to Profile loading/error states during normal recovery.
- Updated bilingual design docs and roadmap to distinguish the implemented selected-day cache/SWR hardening from the remaining cloud daily-summary upsert coordinator, broader warm-cache scheduler, repair UI, and export hardening.

### Validation

- Ran `dart format lib test`.
- Ran `flutter analyze`.
- Ran targeted `flutter test test\daily_summary_cache_test.dart` and `flutter test test\phase2_account_controller_test.dart`.
- Ran `flutter test`.
- Rebuilt debug split APKs with `config/supabase.local.json`.

## 2026-06-27 Phase 3 Local Cache Migration Repair

### Fixed

- Bumped the local SQLite schema to v14 and re-ran the idempotent Phase 3 cache-column migration for devices that installed an intermediate v13 build without all cloud/cache columns.
- Fixed body, food, and workout cloud writes failing during local confirmed-cache updates with missing `cloud_id` or `cloud_updated_at` SQLite columns.

### Validation

- Ran `dart format lib test`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Rebuilt debug split APKs with `config/supabase.local.json`.

## 2026-06-26 Phase 3 Cloud Records Foundation

### Added

- Added the Phase 3 Supabase migration for active-device RPCs, Cloud Records tables, RLS, soft delete, record versions, timestamps, and `daily_summaries`.
- Added Flutter active-device runtime state and repository support for `claim_active_device`, `assert_active_device`, `release_active_device`, and `device_replaced`.
- Added cloud-backed body, food, and workout repositories that write to Supabase first and update local confirmed cache only after cloud success.
- Added local SQLite schema v13 cloud/cache metadata for account-bound partial cache and confirmed read models.

### Changed

- Moved the app root behind an auth gate so signed-out users do not see the five-tab official-record shell.
- Kept subscription failures scoped to AI availability while non-AI record pages depend on auth/Cloud Records instead.
- Updated design docs and roadmap to reflect the implemented Phase 3 foundation and remaining hardening for daily-summary upsert, warm-cache scheduling, repair UI, and export completeness.

### Validation

- Ran `dart format lib test`.
- Ran `flutter analyze`.
- Ran `flutter test`.

## 2026-06-26 Cloud Local Boundary Source Split

### Changed

- Reintroduced bilingual `CloudLocalDataBoundary.md` as the Phase 3 target source for cloud/local authority, cache-first reads, warm cache, write-success rules, failures, conflicts, and repair.
- Trimmed duplicated cloud/local cache and authority rules from README, Product, AppGuide, Database, AgentDesign, Methodology, API contract, roadmap, and implementation planning docs so they summarize and link to the boundary doc.
- Added Phase 3 guardrails for auth independence, state-slice isolation, user-action feedback, bounded refresh traffic, visual stability, daily-summary rebuild strategy, and landing-order regression tests.
- Added the Phase 3 single-active-device policy, active-device schema/RPC contract, `device_replaced` behavior, and last-login-wins UX so older devices cannot keep writing official records.
- Marked the CloudLocal implementation map and acceptance criteria as Phase 3 target behavior, not current Phase 2.5 implementation.

### Validation

- Documentation-only change; Flutter analysis/tests were not run.
- Confirmed required documentation tree exists and searched docs for replacement characters, stale design-doc paths, date-appended stable-doc headings, and CloudLocal references.

## 2026-06-25 Cloud Records Foundation Planning

### Changed

- Moved Cloud Records Foundation ahead of AI Gateway work in the roadmap so signed-in body, food, workout, and daily summary records have one cloud source of truth before AI workflows depend on history.
- Documented the Phase 3 cloud records tables, record API boundaries, soft delete/version/source fields, partial-cache rules, and wrapper context contracts.
- Clarified that Body Profile owns the calendar/add body-record entry, Body Trends is read-only, record actions save immediately, and Profile edits remain one multi-field draft save.
- Updated bilingual stable docs to use cloud summaries/context builders for AI record context instead of treating local SQLite cache as authoritative.

### Validation

- Documentation-only change; Flutter analysis/tests were not run.
- Confirmed required design documentation tree and searched docs for superseded phase, cloud-record, cache-authority, and replacement-character markers.

## 2026-06-25 Floating Navigation Bottom Shield

### Changed

- Changed solid bottom navigation to keep a same-width page-background lower shield from the pill midline to the screen bottom, covering scroll-through content without restoring a full-width footer strip.
- Kept the AI tab's glass navigation unchanged so the animated AI background remains visible around and below the pill.
- Documented the solid-only navigation shield behavior in the stable bilingual design docs and README.

### Validation

- Ran `dart format lib\core\widgets\fitlog_bottom_nav_bar.dart test\root_navigation_test.dart`.
- Ran `flutter test test\root_navigation_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Confirmed the required documentation tree exists and searched stable docs for replacement characters and date-appended headings.
- Ran `flutter clean`.
- Ran `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`.

## 2026-06-24 Black Theme And Floating Navigation

### Added

- Added the Black theme option in Profile, backed by local `SharedPreferences`, while keeping Green as the default theme.
- Added an ignored local Supabase dart-define file template so configured debug builds can read `SUPABASE_URL` and `SUPABASE_ANON_KEY` from a stable local file instead of relying on command history.

### Changed

- Mapped app-level surface, text, selected, button, snackbar, dialog, bottom-sheet, and bottom-navigation colors through shared theme tokens so the Black theme uses dark surfaces with orange accents without changing nutrition semantic colors.
- Changed the root bottom navigation to a theme-aware floating pill without a full-width strip outside the pill; non-AI tabs use an opaque theme surface pill, the AI tab uses a glass pill, and scrollable pages keep their own bottom reading padding.
- Split floating-navigation geometry into screen-space footprint, SafeArea content overlap, scroll reading padding, and floating-control gap helpers so Home, scrollable pages, and bottom actions no longer reuse one ambiguous nav height.
- Changed Food and Workout add actions into transparent floating CTA overlays with explicit CTA height and scroll clearance helpers, sharing the AI composer fixed nav-relative gap without painting a full-width footer band.
- Replaced the AI composer hard-coded bottom offset with the shared floating-control helper so CTA and composer spacing track the floating nav geometry across device safe areas with a fixed gap to the nav pill top.
- Changed the Profile Body Trends chart to place real record points from left to right by real day spacing inside the selected window, and kept the chart area taller for readability.
- Changed the Profile theme selector from a two-part segmented control to independent tap options placed before language settings.
- Documented local theme preference, Black theme boundaries, per-tab floating-pill navigation behavior, and date-spaced trend plotting in the stable design docs.

### Fixed

- Fixed Profile guide overlays so they reserve the floating navigation height instead of overflowing behind the nav pill.
- Fixed remaining hard-coded Profile self-check text colors so Black theme labels and emphasis use readable theme tokens.
- Fixed Home first-viewport sizing so the dashboard box ends above the floating nav pill instead of counting the pill area as usable dashboard height.
- Fixed the Home first-viewport dashboard so it no longer keeps an extra nav-adjacent blank gap above the floating nav pill.
- Fixed the gram/kg Home dashboard macro strip spacing so the bottom macro information sits closer to the floating nav while staying inside the first-viewport box.
- Fixed the energy-ratio Home dashboard on compact first viewports by keeping the macro card's natural internal height at the bottom of the first-viewport box and flexing the space between the calorie and macro cards.
- Fixed the energy-ratio Home calorie card so compact first viewports keep the Local-sized ring, typography, padding, and card internals instead of shrinking the card to avoid overflow.
- Fixed Food and Workout add CTAs to use the same screen-space nav-relative anchor as the AI composer, avoiding SafeArea-coordinate drift on devices with bottom safe areas.
- Fixed Food and Workout log bottom add buttons so they sit just above the floating nav pill instead of being pushed upward by duplicated nav padding.
- Fixed Food and Workout add buttons so only the pill is painted; the area around the pill remains transparent instead of showing a solid footer background.
- Tuned the light-theme AI glass nav alpha so the animated AI background remains visible while non-AI tabs keep an opaque nav pill.

### Validation

- Ran `dart format lib\core\widgets\fitlog_bottom_nav_bar.dart lib\features\ai\ai_page.dart lib\features\food\food_log_page.dart lib\features\workout\workout_log_page.dart lib\features\home\home_page.dart test\root_navigation_test.dart test\home_page_test.dart`.
- Ran `flutter test test\root_navigation_test.dart test\home_page_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Cleared `build` and `.dart_tool\flutter_build` before rebuilding.
- Ran `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`.

## 2026-06-23 Profile Body Metrics And Trends

### Added

- Added current body-fat percentage and waist circumference to Profile, Cloud Profile mapping, Supabase Cloud Profile schema, and the local profile cache.
- Added local account-scoped body metric history fields so saved Profile body metrics can feed a Body Trends card without treating historical body records as full cloud sync.
- Added a Profile Body Trends card below Body Profile with weight, body-fat, and waist charts; 7/14/21/28-day ranges; inline insufficient-record messages; and tappable record dots with an inline value readout.

### Changed

- Upgraded the local SQLite schema to version 12 for body metric profile fields and account-scoped body metric logs.
- Increased the Profile Body Trends chart area so trend lines and inline empty states have more room.
- Bumped the debug build version to `1.0.32+33` for this corrected split APK.

### Fixed

- Kept the currently loaded Profile visible when a Cloud Profile save fails, so a missing Supabase body-metric column shows save feedback without replacing the whole Profile page with an error state.

### Validation

- Ran `dart format lib\domain\models\user_profile.dart lib\domain\models\weight_log.dart lib\data\db\app_database.dart lib\data\repositories\profile_repository.dart lib\features\account\account_controller.dart lib\domain\services\cloud_profile_mapper.dart lib\features\profile\profile_page.dart lib\core\localization\app_strings.dart test\cloud_profile_mapper_test.dart test\user_profile_test.dart test\phase2_account_controller_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test --reporter compact`.
- Ran `flutter build apk --debug --split-per-abi --no-pub --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.

## 2026-06-23 Profile Cache And Subscription Status Polish

### Changed

- Changed the AI center status to read the saved Cloud Profile nickname before falling back to auth display name, so the AI page greeting follows the Profile nickname.
- Replaced the Profile header subscription entry's notification-like dot with a compact semantic status badge for active, inactive, loading, and error states.
- Changed the signed-in Profile page to use the authoritative Cloud Profile directly when it is ready, and to show only account-matched cached Profile data while the cloud refresh is still loading.
- Bumped the debug build version to `1.0.30+31` for this corrected split APK.

### Fixed

- Reduced unnecessary "Loading cloud profile..." exposure after app restart when a current-account Profile cache is already available.

### Validation

- Ran `dart format lib\features\account\account_controller.dart lib\features\ai\ai_page.dart lib\features\profile\profile_page.dart test\phase2_account_controller_test.dart`.
- Ran `flutter test test\phase2_account_controller_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Ran `flutter build apk --debug --split-per-abi --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.

## 2026-06-23 AI And Subscription Overlay Polish

### Changed

- Reworked the signed-in Profile subscription details from a large bottom sheet into a compact blurred overlay, keeping the main Profile plan card visible as the first primary card.
- Strengthened the AI page background colors and motion while pausing the background animation during keyboard input to reduce typing jank.
- Kept the AI account sheet subscribed to account-controller updates so the local-record context permission switch reflects state changes immediately.
- Bumped the debug build version to `1.0.29+30` for this corrected split APK.

### Fixed

- Added readable feedback for local-record context permission save failures.
- Added widget coverage for toggling the AI local-context permission and for keeping the subscription overlay compact.

### Validation

- Ran `dart format lib\features\ai\ai_page.dart lib\features\profile\profile_page.dart lib\core\localization\app_strings.dart test\phase2_account_controller_test.dart`.
- Ran `flutter test test\phase2_account_controller_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Ran `flutter build apk --debug --split-per-abi --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.

## 2026-06-23 Profile Auth Keyboard Focus Fix

### Fixed

- Kept the signed-out Profile auth panel mounted when keyboard insets appear, so focusing an email/password field no longer rebuilds the field, drops focus, and immediately dismisses the keyboard.
- Added widget coverage that simulates the keyboard inset appearing while the login email field is focused and verifies the field can still receive input.
- Bumped the debug build version to `1.0.28+29` for this corrected split APK.

### Validation

- Ran `dart format lib\features\profile\profile_page.dart test\phase2_account_controller_test.dart`.
- Ran `flutter test test\phase2_account_controller_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Ran `flutter build apk --debug --split-per-abi --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.

## 2026-06-23 Profile Session And Account Controls

### Added

- Added a bottom Profile Account card for explicit sign-out. Sign-out clears the Supabase auth session, runtime Profile draft state, account-bound Cloud Profile cache metadata, and local singleton Profile cache without deleting local food/workout/weight records.
- Added persisted Supabase auth-session recovery so users remain signed in after closing and reopening the app until they explicitly sign out or the session cannot be recovered.

### Changed

- Moved the signed-in Profile subscription status from an inline card into a compact header entry and bottom sheet, keeping Current Plan as the first main Profile card.
- Refined the Profile draft UI so modified markers are more visible, the Save Changes bar stays anchored near the bottom of the Profile body, and expanded details grow upward.
- Changed the signed-out Profile auth screen to keep the no-keyboard landing state locked while switching to a compact keyboard-aware scroll layout when login or registration fields are focused.
- Bumped the debug build version to `1.0.27+28` for this corrected split APK.

### Validation

- Ran `dart format lib\app.dart lib\core\config\supabase_pkce_storage.dart lib\data\repositories\auth_repository.dart lib\features\account\account_controller.dart lib\features\profile\profile_page.dart lib\core\localization\app_strings.dart test\phase2_account_controller_test.dart`.
- Ran `flutter test test\phase2_account_controller_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Ran `flutter build apk --debug --split-per-abi --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.

## 2026-06-23 Cloud Profile Failure Diagnostics

### Fixed

- Mapped Cloud Profile Supabase failures into stable diagnostic codes for missing table, incomplete schema, field type mismatch, RLS denial, expired auth, constraint failure, network failure, and generic fetch/save failure.
- Added the Cloud Profile diagnostic code to the Profile error gate so field testing can distinguish Supabase schema, policy, session, and network problems from screenshots.
- Changed Cloud Profile local display caching to best-effort behavior so a successful cloud load or save is not blocked by a local SQLite/cache write failure.
- Bumped the debug build version to `1.0.26+27` for this diagnostic split APK.

### Validation

- Ran `dart format lib\data\repositories\cloud_profile_repository.dart lib\features\account\account_controller.dart lib\core\localization\app_strings.dart lib\features\profile\profile_page.dart test\phase2_account_controller_test.dart`.
- Ran `flutter test test\phase2_account_controller_test.dart test\cloud_profile_mapper_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Ran `flutter build apk --debug --split-per-abi --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.

## 2026-06-23 Cloud Profile Schema Compatibility

### Fixed

- Added a Supabase compatibility migration for existing `cloud_profiles` tables so projects created from an earlier Phase 2 schema receive the latest Cloud Profile columns, constraints, and own-row RLS policies.
- Changed Cloud Profile mapper writes for `daily_energy_goal_kcal` and macro ratio percentage columns to send integers, matching the Supabase schema and avoiding PostgREST integer-cast failures during default Cloud Profile creation.
- Added mapper coverage to ensure Cloud Profile integer fields are serialized as Dart `int` values.
- Bumped the debug build version to `1.0.25+26` for this corrected split APK.

### Validation

- Ran `dart format lib\domain\services\cloud_profile_mapper.dart test\cloud_profile_mapper_test.dart`.
- Ran `flutter test test\cloud_profile_mapper_test.dart test\phase2_account_controller_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Ran `flutter build apk --debug --split-per-abi --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.

## 2026-06-23 Phase 2 Subscription Redeem Management

### Added

- Added Supabase internal subscription code tables, redemption audit storage, and `redeem_internal_subscription_code` RPC so development entitlement can be granted without putting service-role credentials in the app.
- Added a signed-in Profile `Subscription` card with short status fields, refresh, and redeem-code entry for internal Phase 2 testing.
- Added repository/controller support and widget coverage for successful, invalid, and already-redeemed code flows.
- Documented that internal redeem codes are for development entitlement testing only and do not represent production payment or app-store subscription flows.
- Bumped the debug build version to `1.0.24+25` for this split APK.

### Validation

- Ran `dart format lib\domain\models\subscription_status.dart lib\data\repositories\subscription_repository.dart lib\features\account\account_controller.dart lib\features\profile\profile_page.dart lib\core\localization\app_strings.dart test\phase2_account_controller_test.dart`.
- Ran `flutter test test\phase2_account_controller_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Ran `flutter build apk --debug --split-per-abi --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.

## 2026-06-23 Phase 2 Auth Error Boundaries

### Fixed

- Mapped common Supabase auth failures to stable FitLog error codes and user-readable snackbars, so invalid login credentials, registered emails, expired codes, rate limits, and network failures no longer surface raw package exceptions.
- Kept the current sign-in or registration form mounted after auth failures instead of replacing it with a global loading/error gate.
- Decoupled subscription status loading from Cloud Profile loading so a subscription lookup failure does not block the Profile editor when the Cloud Profile loads successfully.
- Added widget/controller coverage for invalid login feedback, registered-email registration feedback, and subscription-load failure isolation.
- Bumped the debug build version to `1.0.23+24` for this corrected split APK.

### Validation

- Ran `dart format lib\data\repositories\auth_repository.dart lib\features\account\account_controller.dart lib\features\profile\profile_page.dart lib\features\ai\ai_page.dart lib\core\localization\app_strings.dart test\phase2_account_controller_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Ran `flutter build apk --debug --split-per-abi --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.

## 2026-06-23 Profile Draft Save Boundary

### Changed

- Changed signed-in Profile editing to stage local page drafts with modified section markers and a bottom Save Changes bar instead of immediately saving each tap or card edit.
- Renamed the Body Profile card action from a save action to a local Done action, keeping cloud persistence centralized in the bottom draft bar.
- Documented that Cloud Profile remains the authoritative account profile, while unsaved Profile drafts do not become official AI or app context until saved.
- Bumped the debug build version to `1.0.22+23` for this corrected split APK.

### Validation

- Ran `dart format lib\features\profile\profile_page.dart lib\core\localization\app_strings.dart test\phase2_account_controller_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Ran `flutter build apk --debug --split-per-abi --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.

## 2026-06-23 Default Cloud Profile Initialization

### Fixed

- Changed Cloud Profile fetching to use a limited row query so a new account with no `cloud_profiles` row is treated as empty state rather than a load failure.
- Automatically creates and caches a default Cloud Profile for newly registered or newly signed-in accounts when no cloud row exists, so Profile opens with the default editable data instead of a `profile_load_failed` screen.
- Added controller coverage for default Cloud Profile creation on new accounts.
- Bumped the debug build version to `1.0.21+22` for this corrected split APK.

### Validation

- Ran `dart format lib\data\repositories\cloud_profile_repository.dart lib\features\account\account_controller.dart test\phase2_account_controller_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Ran `flutter build apk --debug --split-per-abi`.

## 2026-06-23 Email Password Auth Split

### Changed

- Replaced the signed-out Profile OTP login with a clear landing/sign-in/register flow: email-password sign-in, registration-only email code, password confirmation, and no username field.
- Kept the animated FitLog logo on both sign-in and registration while using a smaller, higher logo placement for the longer registration form.
- Prevented the signed-out Profile auth screen from scrolling in the static no-keyboard state while still allowing keyboard avoidance when needed.
- Switched the Phase 2 auth repository/controller boundary to `signInWithPassword`, `sendRegistrationOtp`, and `completeRegistration`.
- Documented that credentials belong to Supabase Auth, while nickname/display name remains a Cloud Profile field filled after onboarding.
- Bumped the debug build version to `1.0.20+21` for this corrected split APK.

### Validation

- Ran `dart format lib\data\repositories\auth_repository.dart lib\features\account\account_controller.dart lib\features\profile\profile_page.dart lib\core\localization\app_strings.dart test\phase2_account_controller_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Ran `flutter build apk --debug --split-per-abi`.

## 2026-06-22 Supabase OTP PKCE Storage

### Fixed

- Added SharedPreferences-backed GoTrue async storage to the configured Supabase client so Email OTP sign-in can complete the default PKCE flow instead of failing with the `_asyncStorage != null` assertion.
- Added a focused storage test for setting, reading, and removing the PKCE verifier state.
- Bumped the debug build version to `1.0.19+20` for this corrected configured split APK.

### Validation

- Ran `dart format lib\app.dart lib\core\config\supabase_pkce_storage.dart test\supabase_pkce_storage_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Ran `flutter build apk --debug --split-per-abi` with Supabase dart defines for manual login validation.

## 2026-06-22 Profile Sign-In Typography

### Changed

- Reduced Profile sign-in typography weight: Email/OTP fields now use medium text, and the OTP/send primary actions use semi-bold text instead of title-like heavy weights.
- Exposed the app theme builder and font constants so tests and root loading UI can use the same `NotoSansSC` typography as the running app.
- Updated the Profile sign-in Email/OTP fields and OTP/sign-in buttons to derive local text styles from the app theme instead of relying on raw local `TextStyle` overrides.
- Added widget-test assertions that the signed-out Profile login controls resolve to the app font family and the intended medium/semi-bold weights.
- Added an AGENTS.md engineering rule requiring new UI text to use app-level typography and avoid accidental platform/default font fallback.
- Bumped the debug build version to `1.0.18+19` for this corrected split APK.
- Updated README and bilingual Product/AppGuide/AgentDesign docs to document app-wide typography consistency and moderate sign-in text weight on the Profile sign-in entry.

### Validation

- Ran `dart format lib\app.dart lib\features\profile\profile_page.dart test\phase2_account_controller_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Ran `flutter build apk --debug --split-per-abi`.

## 2026-06-22 Profile Sign-In Sparkle Balance

### Changed

- Nudged the Profile sign-in sparkle cluster slightly left and down so it sits closer to the original FitLog app icon relationship.
- Increased the main sparkles' resting scale and opacity while keeping the approved peak size and 6-second staggered pulse animation unchanged.
- Tightened the green-to-cyan sparkle palette by reducing white mixing and soft glow so the brightest frame reads more saturated against the light background.
- Bumped the debug build version to `1.0.16+17` for this corrected split APK.
- Updated README and bilingual Product/AppGuide/AgentDesign docs to describe the refined sparkle placement, fuller resting state, and saturated SVG-derived palette.

### Validation

- Ran `dart format lib\features\profile\profile_page.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Ran `flutter build apk --debug --split-per-abi`.

## 2026-06-21 Profile Sign-In Sparkle Placement

### Changed

- Replaced the hand-normalized rounded sparkle path with the supplied SVG curve coordinates so the Profile sign-in sparkle silhouette matches the Figma-exported reference.
- Repositioned the sparkle cluster to match the original logo relationship: one large main sparkle near the FitLog mark's upper-right edge, with two smaller companion sparkles to its upper-right and lower-right.
- Raised and enlarged the sparkle cluster so its resting layout reads closer to the original mark instead of sitting low and faint beside the logo.
- Kept the approved 6-second staggered scale/opacity pulse animation while tightening the cluster and reducing auxiliary sparkles to non-dominant flashes.
- Bumped the debug build version to `1.0.15+16` for this corrected split APK.
- Updated README and bilingual Product/AppGuide/AgentDesign docs to document the SVG-derived fixed rounded sparkle cluster.

### Validation

- Ran `dart format lib\features\profile\profile_page.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Ran `flutter build apk --debug --split-per-abi`.

## 2026-06-21 Profile Sign-In Sparkle Pulse Reference

### Changed

- Reworked the Profile sign-in sparkle overlay into a fixed rounded four-point star cluster based on the supplied reference shape and timing notes.
- Replaced rotation and visible travel with a 6-second staggered scale/opacity pulse loop, keeping the stars in a small fixed area instead of behaving like a loading spinner.
- Added two brief auxiliary sparkles around the three main stars so at least two main stars remain visible while short flashes add depth.
- Moved the missing-backend notice to the top of the signed-out Profile screen so the logo/form composition remains centered around the login experience.
- Bumped the debug build version to `1.0.13+14` for this corrected split APK.
- Updated README and bilingual Product/AppGuide/AgentDesign docs to document the fixed rounded sparkle cluster, staggered breathing pulses, and top notice placement.

### Validation

- Ran `dart format lib\features\profile\profile_page.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Ran `flutter build apk --debug --split-per-abi`.

## 2026-06-20 Profile Sign-In Sparkle Geometry

### Fixed

- Replaced the Profile sign-in sparkle overlay's rounded blob path with upright geometric four-point stars so the small companion stars return to clear vertical/horizontal axes.

### Changed

- Reworked the sparkle animation into a symmetric rotate, lift, scale, and return motion with no pre-rotated rest state.
- Shifted the signed-out Profile layout toward the requested reference: logo in the visual middle band and Email/OTP/sign-in controls lower on the screen, while leaving the temporary Supabase notice placement unchanged.
- Bumped the debug build version to `1.0.11+12` for this corrected split APK.
- Updated README and bilingual Product/AppGuide/AgentDesign docs to document the geometric four-point sparkle overlay and symmetric return motion.

### Validation

- Ran `dart format lib\features\profile\profile_page.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Ran `flutter build apk --debug --split-per-abi`.

## 2026-06-19 No-Star Logo Base And Richer AI Sparkles

### Added

- Added `assets/branding/fitlog_logo_base.png` as the Profile sign-in logo base without pre-rendered sparkle marks.

### Changed

- Updated the Profile sign-in logo to compose the no-star base asset with a separate animated AI sparkle overlay, avoiding duplicate sparkle artifacts.
- Reworked sparkle motion into a staggered bloom, rotate, glow, and settle sequence with a main star and two delayed companion stars.
- Bumped the debug build version to `1.0.10+11` for this corrected installable APK.
- Updated README and bilingual design docs to document the no-star base asset plus animated sparkle overlay.

### Validation

- Ran documentation-tree and stale-reference searches.
- Ran `dart format lib\features\profile\profile_page.dart test\phase2_account_controller_test.dart`.
- Ran `flutter analyze --no-pub`.
- Ran `flutter test --no-pub`.
- Ran `flutter build apk --debug --split-per-abi --no-pub`.

## 2026-06-19 Profile Sign-In Logo Restoration

### Fixed

- Replaced the hand-drawn sign-in logo reconstruction with the real FitLog Agent launcher asset so the blue brand mark matches the installed app icon.

### Changed

- Kept the AI sparkle motion as an overlay on top of the real logo asset instead of redrawing the whole mark.
- Bumped the debug build version to `1.0.9+10` for this corrected installable APK.
- Updated README and bilingual design docs to document that the sign-in screen uses the real logo asset plus animated sparkle overlay.

### Validation

- Ran documentation-tree and stale-reference searches.
- Ran `dart format lib\features\profile\profile_page.dart test\phase2_account_controller_test.dart`.
- Ran `flutter analyze --no-pub`.
- Ran `flutter test --no-pub`.
- Ran `flutter build apk --debug --split-per-abi --no-pub`.

## 2026-06-19 Profile Sign-In Visual Refresh

### Added

- Added a centered sign-in branding area with animated AI sparkle marks on the signed-out Profile screen.
- Added widget coverage for the signed-out Profile OTP login layout.

### Changed

- Reworked the signed-out Profile UI into a clean solid-background login screen with centered branding, Email/OTP inputs, and a green primary sign-in button matching the Add Food action color.
- Bumped the debug build version to `1.0.8+9` for this installable visual update.
- Updated README and bilingual Product/AppGuide/AgentDesign docs to document the current Profile sign-in behavior.

### Validation

- Ran documentation-tree and stale-reference searches.
- Ran `dart format lib\features\profile\profile_page.dart test\phase2_account_controller_test.dart`.
- Ran `flutter analyze --no-pub`.
- Ran `flutter test --no-pub`.
- Ran `flutter build apk --debug --split-per-abi --no-pub`.

## 2026-06-19 Phase 2 Account And Cloud Profile Foundation

### Added

- Added Supabase-backed Phase 2 configuration, Auth, subscription, Cloud Profile, and local-record context-permission repositories.
- Added `AccountController` state orchestration for signed-out, loading, subscribed/unsubscribed, missing-profile, ready, offline-readonly, and error states.
- Added Profile sign-in gating, Cloud Profile creation gating, cloud-save behavior after login, and local cache display fallback.
- Added AI account/subscription status sheet, local-record summary permission toggle, and account-change composer draft clearing.
- Added Supabase migration and seed notes for `subscriptions` and `cloud_profiles` with RLS and algorithm-preserving checks.
- Added mapper and controller tests for Phase 2 profile/account behavior.

### Changed

- Bumped the debug build version to `1.0.7+8` for the Phase 2 installable APK.
- Updated README, roadmap, and bilingual Product/AppGuide/AgentDesign/Database docs to distinguish implemented Phase 2 account/Profile foundation from later AI Gateway, chat history, RAG, and Food Draft work.

### Validation

- Ran documentation-tree and stale-reference searches.
- Ran `dart format lib test`.
- Ran `flutter analyze --no-pub`.
- Ran `flutter test --no-pub`.
- Ran `flutter build apk --debug --split-per-abi --no-pub`.

## 2026-06-19 Phase 7 Data Boundary Clarification

### Added

- Added a Phase 7 roadmap stage for full food/workout/weight cloud sync after the usable V1 release.
- Added an AI composer regression test so unfinished prompt text survives tab switches.

### Changed

- Clarified that Phase 2-6 local food/workout/weight history remains a device dataset and is not silently claimed by a newly signed-in account.
- Documented Cloud Profile mapper boundaries so storage conversion does not alter diet phase, calculation mode, or strategy semantics.
- Documented AI composer draft retention within the current runtime across tab switches and disabled states, with logout/account switch clearing the draft.
- Expanded the Phase 2 roadmap into a detailed engineering implementation plan covering Supabase schema/RLS, Flutter state models, cache boundaries, Profile gating, AI gating, local-record context permission, implementation slices, tests, and manual review.

### Validation

- Ran documentation-tree and stale-reference searches.
- Ran `dart format test\ai_page_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.

## 2026-06-19 Documentation Reference Fix

### Fixed

- Corrected the bilingual Algorithm docs to point dynamic calibration references at `DailySummaryService`, where the current source implements the logic.

### Validation

- Ran documentation-tree and stale-reference searches.

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
