# Cloud and Local Data Boundary

## Purpose

This document is the source of truth for how FitLog_Agent relates cloud data, local SQLite, local caches, UI read models, writes, reads, background refresh, failures, conflicts, and repair.

`Database.md` owns schema, migrations, tables, and fields. `AgentDesign.md` owns how AI may use data. `Product.md` and `AppGuide.md` own user-facing behavior summaries. When those files need cloud/local rules, they should summarize and point here instead of duplicating the full policy.

## Scope

These rules apply to every signed-in Agent build. They cover the root auth gate, active-device claim/assert, cloud-first body/food/workout writes, account-bound confirmed-cache metadata, cloud-backed repositories, non-blocking startup recovery, first-render account binding, selected-day summary cache, stale-while-revalidate rebuilds, cloud `daily_summaries`, bounded warm cache, cache eviction, and export completeness.

Pre-login compatibility behavior remains local. Offline official-write queues, complete two-way sync, automatic old-device-history migration, and complex cross-device merge UI are outside this boundary. Richer repair presentation may evolve, but it must continue to obey the state, authority, and failure rules below.

## Core Principles

- Cloud records are the authority for signed-in official body, food, and workout data.
- Local SQLite is partial cache, draft storage, runtime acceleration, and confirmed UI read model.
- Local cache is not a complete cloud mirror and must not be required for AI, export, repair, or cross-device correctness.
- Pages with confirmed account-bound cache should open from local data without waiting for active-device recovery or cloud refresh once the signed-in auth account is known.
- Official data must not be lost because local cache is evicted.
- AI may draft, explain, and review, but official data changes still require user confirmation and cloud success.

## Runtime Account State Machine

| State | Entry condition | UI behavior | Cloud behavior |
| --- | --- | --- | --- |
| `signed_out` | No valid session, user signed out, or the session is proven unrecoverable | Root auth gate; bottom navigation is not visible | No official-record reads or writes |
| `recovering_cached` | A signed-in account and matching confirmed cache exist, but Supabase session, Cloud Profile, or subscription is still recovering | Render cached Home/Profile/Body Trends immediately; no full-page loading or error | Recover the session and refresh Cloud Profile, subscription, and visible windows in the background |
| `online_confirmed` | Session, Cloud Profile, and visible-window refresh succeed | Normal interaction; writes remain cloud-first | Normal reads/writes; successful writes update local read models |
| `offline_readonly` | Background refresh has a network failure, timeout, or temporary service failure while confirmed cache exists | Keep confirmed cache visible; block official writes or keep drafts; a lightweight sync-failed state may be shown | Stop the current forced refresh and retry with backoff |
| `stale_cached` | Cache exceeds the freshness window or background refresh fails without becoming a crisis | Keep cache visible; update only affected local UI, not the whole page | Validate again after freshness expiry, resume, or explicit user refresh |
| `device_replaced` | Server confirms the current device/session was replaced by a newer login for the same account | Block official writes and AI send, show "account signed in on another device", clear local auth session, then return to root auth gate or offer re-login takeover | This device/session is no longer allowed to write official records |
| `repair_required` | Metadata conflict, account-boundary mismatch, version regression, or unmergeable payload difference | Block affected writes and show a repair/refresh path | Repair from cloud records or rebuildable projections |

Transition rules:

- `recovering_cached` must render confirmed cache first instead of switching to `loading` while waiting for cloud.
- `auth_required`, network failure, or subscription failure during background refresh may downgrade `online_confirmed` to `stale_cached`/`offline_readonly`, but must not replace confirmed UI.
- A signed-in runtime returns to `signed_out` only when session recovery proves the persisted session is unrecoverable.
- Server `device_replaced` responses must not be treated as ordinary upload failures; the app must enter `device_replaced`, stop official writes, and clear local sign-in state.
- Explicit user writes never bypass cloud success merely because local cache exists.

## Auth Boundary

- Sign-in, registration, sign-out, and session recovery are account-layer capabilities; they must not depend on Cloud Records cache, daily summaries, warm cache, or successful subscription refresh.
- The signed-out page must not start official-record reads, records warm cache, or daily-summary warm cache.
- If backend configuration is missing, sign-in and registration buttons must show a readable configuration error; they must not appear to do nothing.
- When the user taps sign in, register, refresh subscription, or sign out, UI must enter a visible processing, success, or failure state; silent no-op is not allowed.
- After sign-in succeeds, the app may enter first-load without cache or `recovering_cached`; it must not wait for subscription status, Cloud Records warm cache, or 30-day warming before entering the five-tab shell.
- If persisted session recovery is slow, pages with matching account-bound cache may render first; if there is no account or the session is proven unrecoverable, the app must return to the root auth gate.

## State Slice Rules

- Runtime state must be split into independent slices: auth/session, Cloud Profile, subscription, visible records/read models, daily summaries, warm cache, and AI Gateway availability.
- A failed slice may affect only its own UI or capability. Subscription failure affects AI send and subscription display; it must not block non-AI Home/Food/Workout/Profile data pages.
- Cloud Profile refresh failure must not wipe a matching displayed Profile cache; records refresh failure must not wipe an already displayed records read model.
- Warm cache affects next-open and history-navigation speed only. It must not control page visibility, button enabled state, or official write permission.
- Cloud Records readiness must not let the AI send button bypass Gateway, active-device, provider, or server entitlement checks.
- Each slice needs its own freshness, loading, error, stale, and retry state; a single global loading/error must not cover the whole tab shell.

## Single Active Device Policy

- Agent V1 uses one active device per account with `last login wins`. After a newer device signs in successfully, that device takes over the account; older devices may no longer perform official writes or AI send.
- V1 does not implement real-time multi-device sync and does not rely on detecting whether another device is online. Mobile online presence is unreliable, so replacement is based on the server-side active device/session record.
- Each app install creates a local `device_id`. After sign-in succeeds, the app calls `claim_active_device` so the server records the current account's active device/session as this device.
- Supabase single-session can be an additional helper, but it is not the only protection. An old access token may remain briefly valid before expiry, so official write paths must also verify active device/session.
- The older device does not need a realtime push logout. It enters replacement state the next time session refresh, cloud read, official write, AI send, or account refresh returns `device_replaced`.
- `device_replaced` is an account safety and conflict-boundary state, not an ordinary network error. The app should show "This account signed in on another device. Sign in again to take over.", then clear local auth session, runtime drafts, and account-bound display cache.
- Device replacement does not delete cloud official records or rebuildable local cache. Local cache must not remain visible as active-account data unless the user signs in again and claims the active device.

## Subscription State Rules

- Subscription authority lives in the cloud; local storage keeps only the last confirmed display/status cache.
- On startup, a matching account subscription cache may render the last active/inactive state before the background refresh completes.
- A successful subscription refresh updates the local display cache.
- If subscription refresh fails while a previous confirmed state exists, keep that state and mark it stale with an error reason; do not make the Profile subscription card or AI page repeatedly flicker into unavailable/loading.
- If no subscription cache exists and refresh fails, AI stays unsendable/pending; non-AI product data pages remain usable.
- Real AI send and quota deduction must still be checked by the server/Gateway entitlement path. Local active cache is only display state and startup latency reduction.

## Data Classes

| Data class | Examples | Authority | Local role |
| --- | --- | --- | --- |
| Account identity | Supabase auth user id, email session | Cloud | Auth session cache only |
| Active device | `device_id`, `active_session_id`, `claimed_at` | Cloud | Local device id and display/diagnostic state |
| Subscription | entitlement rows, quota state | Cloud | Display/status cache only |
| Cloud Profile | nickname, goals, phase, mode, current body snapshot | Cloud after login | Display cache and page-local draft |
| Body metric logs | dated weight, body-fat percentage, waist records | Cloud | Confirmed read model and partial cache |
| Food records | `food_records`, `food_items` | Cloud | Confirmed day read model and partial cache |
| Workout records | sessions, sets, workout records | Cloud | Confirmed day read model and partial cache |
| Daily summaries | selected-day totals and compact context | Rebuildable cloud projection | Confirmed summary cache |
| Local-only app data | theme, runtime UI state, unfinished prompts, local export files | Local | Local authority |
| Drafts | unsaved prompts, manual/AI new-workout drafts, unconfirmed AI food drafts | Local until confirmed | Draft storage only; saved-workout edits remain page-local |
| AI records | chat sessions, messages, final answers, request metadata | Cloud/service after their phases | Runtime display cache only |

## Source Of Truth Rules

- Signed-in body, food, and workout official records use Supabase Cloud Records as the source of truth.
- Local SQLite must not be treated as a complete history mirror.
- Local confirmed read models may render UI quickly, but they do not overrule cloud official records.
- A cloud success response updates local confirmed cache/read models with the returned row, version, and timestamps.
- Local cache eviction is not cloud deletion.
- Cloud deletion or soft deletion must go through the official cloud repository path.
- Local cache must be account-bound; cache with mismatched account metadata cannot be displayed as confirmed data for another user.

## Write Rules

- Official create, update, and delete operations for body, food, and workout records are cloud-first.
- Account-bound official operations such as body/food/workout writes, Cloud Profile saves, and AI send must pass active device/session verification first; old devices receiving `device_replaced` must not continue submitting.
- The app may keep editable drafts or pending UI state, but it cannot report an official write as successful before Supabase succeeds.
- Cloud success requires a valid account id, RLS acceptance, payload validation, and a returned cloud row or accepted delete marker.
- After cloud success, update the local confirmed read model and the affected `daily_summaries` projection/cache.
- If cloud write fails, preserve the previous official state and keep any user draft/edit in a retryable non-official state.
- AI cannot silently modify diet goals, apply carb tapering, delete records, or write official records; user confirmation and the official write path are required.
- There is no offline official-write queue. Offline user edits remain drafts until an explicit online save succeeds.
- Workout lifecycle autosave and official save are ordered mutations of one local draft. Starting an official save blocks new lifecycle autosaves; after cloud success, a final draft deletion runs behind any older queued draft write. This cloud-confirmed terminal mutation wins over backgrounding the app. Official-save failure does not run that deletion and keeps the draft retryable.

## User Action Feedback Rules

- Add, edit, delete, copy-to-date, save body record, and save Profile actions must have a visible result: `validating`, `saving`, `saved`, `error/retry`, or an explicit disabled reason.
- After the user taps an official write action, failure must not be silent. The app must preserve user input or a recoverable draft and show a readable error, retry entry, or re-login path.
- While a write is in progress, duplicate submit should be disabled or guarded by an idempotency/mutation key to avoid duplicate records.
- Delete may show a pending state, but if cloud delete fails, the app must restore the original record or show a clear not-deleted state; local UI must not look successful while the cloud record still exists.
- Foreground write failures such as `auth_required`, RLS denied, payload validation, schema mismatch, or network failure must map to user-readable states; raw backend exceptions should stay inside diagnostics.
- Foreground writes that receive `device_replaced` must show device-replacement messaging and sign out/re-login flow; they must not look like ordinary save failures or keep retrying with the old session.
- Background refresh errors may be low-noise; foreground user-action errors must be direct.

## Read Rules

- Cache-first UI surfaces:
  - Home selected-day summary/read model.
  - Food selected-date records.
  - Workout selected-date records.
  - Body Trends visible 7/14/21/28-day window.
  - Profile display cache when account metadata matches.
- Cloud/builder-first flows:
  - AI context.
  - Export correctness.
  - Account repair.
  - Cross-device restore and reconciliation.
  - Long-window history reconstruction.
- If confirmed local cache exists, cache-first surfaces should render it immediately and refresh in the background only when stale or explicitly requested.
- If no confirmed local cache exists, a page-level loading, empty, or login state is acceptable.
- Stale cache may stay visible with a refresh status; it should not be cleared merely because refresh started.

## App Startup Rules

- Startup must not block first render on a full-history cloud pull.
- Startup must not force a complete 30-day refetch before rendering cache-backed pages.
- When the five-tab shell is entered for a recovered signed-in session, the app must bind Food, Workout, and Profile repositories to the auth-session account id before the active-device runtime context finishes claiming or refreshing. This lets Home, Food, and Workout read matching local account caches on the first current-date render instead of showing an empty day until the user changes dates.
- First-render data is not warm cache. If no matching confirmed Home cache exists, the first signed-in Home render may wait for a small first-render bundle: account/Cloud Profile basics, the selected-day Home summary/read model, and only the data required by the default visible surface. The app should not render an empty Home and then replace it with the real Home while the user is watching.
- If a matching confirmed Home cache exists, render it immediately and validate in the background. Matching cloud data should not visibly refresh Home; changed cloud data should update only the affected values without a full-page loading reset.
- Supabase session recovery, subscription refresh, Cloud Profile refresh, and visible-window Cloud Records refresh should run in the background when matching local cache exists.
- `auth_required` during background refresh is a recoverable sync/session state for cache-backed UI, not a reason to replace confirmed Home or Body Trends content with a full-page error.
- `auth_required` for an official foreground write blocks that write and should surface a clear retry/login path.
- If no signed-in account or no matching account-bound cache exists, cloud-backed official-record areas should show the login gate or first-load state.

## Warm Cache Rules

Warm cache runs after the first visible page has rendered stably. It improves the next app open, date switches, trend windows, and history navigation, but it is not a startup blocking condition.

Preferred warm order after first render:

1. Body Trends visible/default body-metric window; body metric logs are lightweight and high priority.
2. Food/Workout selected-date detailed records if they were not part of the first-render bundle.
3. Recent 30-day `daily_summaries`.
4. Recent 30-day `body_metric_logs`; fetching the full recent body-metric window is acceptable because it is small and covers 7/14/21/28-day trend switches.
5. Recent 30-day food/workout detailed records in throttled batches.

Rules:

- The recent 30-day window is a retention priority and warm target, not a requirement to download 30 days before showing Home.
- Warm cache should be account-bound, cancellable on sign-out/account switch, and throttled so it does not compete with visible interactions.
- Warm cache must not turn an already rendered page back into loading.
- If warm cache discovers data for the currently visible surface, update only the affected read model and only when metadata or payload differs.
- Detailed food/workout records are heavier than body metric logs and summaries, so they should be warmed after lightweight summaries and body metrics.

## Background Refresh Rules

- Refresh only the visible account, selected date, selected month, or selected trend window.
- Trigger refresh when:
  - cache freshness expires;
  - the user explicitly refreshes;
  - the selected date/window changes and cache is missing or stale;
  - a successful write requires summary/read-model rebuild;
  - app resume exceeds the freshness window;
  - account sign-in, sign-out, or account switch changes the cache boundary.
- Gate refresh by `account_id`, `cached_at`, `source_updated_at`, `record_version`, selected date/window, and explicit user action.
- If metadata and payload match, do not visibly reset or flash the UI.
- If data changed, apply the smallest local read-model update needed for the visible surface.
- Failed background refresh keeps the existing confirmed read model visible and records a refresh failure state.
- Refresh loops should be throttled/debounced so startup and resume do not repeatedly query unchanged visible data.
- Account-level Cloud Profile and subscription refresh must have freshness and failure backoff. A default implementation may use roughly 5 minutes of success freshness and roughly 45 seconds of failure backoff; explicit user refresh may bypass freshness but should still record failure time to avoid automatic loops.
- Background refresh must not reset `recovering_cached` pages into full-page loading. Matching results do not visibly refresh the page; changed results update only the affected fields or cards.

## Traffic And Visible Refresh Control

Cloud source of truth does not mean continuous polling. FitLog uses stale-while-revalidate: render the local confirmed read model first, then validate the cloud under controlled conditions.

- Foreground records polling without bounds is not allowed. Automatic refresh may be triggered only by freshness expiry, app resume, date/window change, successful write, explicit refresh, or repair flow.
- Every refresh must be scoped to the account and visible range. The app does not pull full history by default and does not require detailed recent 30-day records before first render.
- Reads should use date ranges, month ranges, `updated_at`, `record_version`, summary version, or lightweight metadata to detect changes before downloading unchanged payloads.
- Warm cache must be low priority, cancellable, and throttled; it must not compete with active typing, saving, scrolling, or page switching.
- Failure backoff must be recorded per slice; network failure must not create automatic retry loops on startup, resume, or page switches.
- If cloud metadata/payload matches local data, do not trigger visible UI updates, loading flashes, or list rebuilds.
- If cloud data changed, update only the changed field, card, or record row; do not put the whole page back into loading, reset scroll position, steal input focus, or discard unsaved drafts.
- Visible sync hints should be low-noise, such as a small stale/syncing marker. Mature behavior should not show repeated full-page refreshes in front of the user.

## Cache Capacity And Eviction

- Pin the recent 30 days of records and summaries by default.
- Keep detailed records for at most 180 older user-visited day buckets per account.
- Keep rebuildable local summary/record cache bounded; the current implementation prunes cloud-confirmed cache older than the recent 30-day window and relies on cloud records/builders for older history reconstruction.
- Body calendar and Body Trends reuse the same cache policy; they do not require a separate larger cache.
- The recent 30-day window is not the only cache that may exist. When a day falls outside the recent window, it may remain as an older visited day bucket until older-bucket capacity or eviction rules require removal.
- Cache metadata should track account id, date/window, `cached_at`, source updated/version fields, pending/confirmed status, and last access when available.
- Eviction may delete only cloud-confirmed, rebuildable, local cache entries.
- Eviction must not delete pending drafts, current visible data, recent pinned-window data, unconfirmed edits, or cloud official data.
- Older history loads on demand by date, month, or trend window and can be cached after display.

## Daily Summaries

- `daily_summaries` is a persisted, rebuildable cloud projection generated from official records, Cloud Profile, and deterministic calculators.
- It may serve Home, history, export, review, and AI context.
- It is not user-authored official record data and does not replace raw official records.
- Home may display a local confirmed summary immediately.
- AI, export, repair, and cross-device correctness should use cloud summaries or controlled summary/context builders.
- If a summary is missing or stale, the builder may rebuild it from cloud official records and upsert the cloud projection.
- Summary rebuild must not silently modify official records.

## Daily Summary Cloud Strategy

- The current design uses an app/service-side deterministic builder that rebuilds summaries and upserts `daily_summaries` through the cloud repository; DB triggers or Edge Functions are not required for this summary strategy.
- The summary builder must reuse existing deterministic algorithm semantics. It must not merge `energy_ratio` with `gram_per_kg`, and it must not infer official targets from AI output.
- After a successful food/workout/body records write, the change coordinator should rebuild the affected date's summary and update local confirmed summary cache.
- When Home or export reads a missing, stale, or version-mismatched cloud summary, the app may rebuild it from cloud official records and upsert it.
- Summary rows should store enough input version or timestamp metadata, such as records `updated_at`/`record_version`, Profile version, algorithm/schema version, and `built_at`, so stale summaries can be detected.
- Summary rebuild must be idempotent; repeated rebuilds for the same account and date must not create multiple official summary rows.
- Summary rebuild failure must not delete official records; Home may keep the last confirmed summary visible and mark it stale/error.

## Failure And Crisis Decisions

Non-crisis states:

- Background refresh returns `auth_required` while confirmed cache is visible.
- Supabase session recovery is slow.
- Transient network failure or timeout occurs during background refresh.
- Cloud refresh fails while confirmed cache for the visible page exists.
- Optional Home helper windows such as calibration samples or training-frequency self-checks fail while the selected-day summary can still be built from local read models.

Warn but do not block existing confirmed UI:

- Visible cache is older than the freshness window.
- Current date/window refresh failed.
- `daily_summaries` is missing, stale, or rebuilding.
- Subscription refresh fails while non-AI product data is otherwise usable.

Block official writes:

- The user is not signed in.
- Supabase write fails.
- RLS denies the operation.
- `account_id` does not match the authenticated user.
- Cloud schema or required columns are missing.
- Payload validation fails.
- Returned cloud data fails mapper validation.
- Cloud version conflict requires refresh/retry.

Enter repair or reconciliation:

- Local confirmed metadata conflicts with cloud metadata.
- Cloud `record_version` regresses or cannot be ordered.
- The same official record has unmergeable local/cloud payload differences.
- Summary and official records remain inconsistent after rebuild attempts.
- Cache for one account appears under another account boundary.
- Local child rows are orphaned after cache update or eviction.
- A persisted auth session proves unrecoverable during background recovery and the app must return to the root auth gate.

## User-Initiated Local Data Clearing

- Profile's Clear All Local Data action deletes rows only from this device's SQLite business tables. It does not call a cloud-repository deletion path or delete the Supabase Auth session, SharedPreferences, exported files, or any cloud data.
- The action covers both rebuildable account-bound confirmed cache and local workout drafts, custom exercises, calibration, and review state that have no cloud copy. It is therefore not cache eviction and cannot promise that everything removed is recoverable.
- Cloud Profile, Cloud Records, cloud `daily_summaries`, AI chat history, and cloud AI logs remain unchanged. While signed in, page refreshes can rebuild local confirmed cache under the normal cloud-authoritative read rules.
- The action does not change the active account and is not sign-out, account switching, account deletion, or cloud official deletion. UI and documentation must state that cloud data can reappear while local-only data is permanently lost.
- [Database.md](Database.md) owns the exact SQLite table scope and code references.

## Conflict And Repair

- Cloud official records are the conflict authority.
- Local confirmed cache can be overwritten by cloud rebuild/refresh results.
- Offline official writes and automatic client/cloud merge are out of scope for V1.
- A version conflict should prompt refresh/retry rather than silently choosing the client payload.
- Repair flows must be explicit, explainable, and based on cloud official records or rebuildable projections.
- Local cache deletion and cloud official deletion must remain separate operations in code and UI.
- Account sign-out or account switch clears local auth/session display caches, runtime drafts, and local record caches without deleting cloud official data.

## Security And Privacy

- Store only the local cache needed for performance and visible workflows.
- Do not store user-supplied model API keys.
- Local cache is not long-term semantic memory.
- AI request logs, chat history, RAG inputs, and debug summaries follow `AgentDesign.md`.
- RLS must enforce own-row access for cloud official records.
- Export and account repair use cloud official records or summaries as the authority.
- Account deletion should delete Cloud Profile, cloud official records, identifiable chat history, and identifiable AI request/response data.

## Page Rules

Root auth gate:

- Signed-out or backend-unconfigured Agent builds must render the auth/onboarding screen before the tab shell.
- The bottom navigation is not visible or tappable until the account is signed in.
- A backend-unconfigured build may show the Supabase configuration notice, but it must not be treated as a valid Cloud Records test build.

Home:

- Render confirmed local selected-day summary/read model immediately when available.
- Do not turn cached Home into a full-page error because background refresh returned `auth_required`.
- Do not flash back to loading when cloud data is unchanged.

Food:

- Render confirmed selected-date local records immediately when available.
- Create, edit, copy, and delete official records through the cloud write path after sign-in.
- Update the selected-day read model after cloud success.

Workout:

- Render confirmed selected-date local sessions/sets/records immediately when available.
- Create, edit, and delete official records through the cloud write path after sign-in.
- Retain only manual/AI new-workout drafts; saved-record editing stays page-local and is discarded when the editor closes without a successful save.
- Update workout summaries and the selected-day read model after cloud success.

Profile:

- Cloud Profile is authoritative after login; matching local display cache may render first.
- Profile edits are page-local drafts until the user saves the full Cloud Profile snapshot.
- Body Profile provides the dated body-record entry; body records write through Cloud Records.
- Body Trends is read-only and should render the local confirmed visible window before background refresh.
- Body Trends must distinguish `partial_cache`, `confirmed_empty`, and `confirmed_ready`. A missing local row in an unconfirmed window is not proof that the cloud has no records.
- While a trend window is `partial_cache`, keep the chart area height stable and show existing confirmed points plus a lightweight syncing/refreshing state, or a fixed-height "syncing recent body records" state.
- Show final "no records" or "insufficient records" only after the cloud confirms the visible window as `confirmed_empty`.
- When body-metric warm cache completes while the user is viewing Body Trends, update only the chart area and controls needed for the new state; do not rebuild the full Profile page or shift layout.

AI:

- AI context must not trust local SQLite cache as the final authority.
- Use Cloud Profile plus cloud `daily_summaries` or controlled summary/context builders.
- Official writes from AI drafts require user confirmation and the normal cloud write path.

Export and repair:

- Use cloud official records, cloud summaries, or builders for correctness.
- Local cache may accelerate reads but must not be required for completeness.

## Implementation Map

The following components enforce this boundary:

- Supabase migration: `supabase/migrations/202606260001_phase3_cloud_records.sql`.
- Local SQLite schema: `lib/data/db/app_database.dart`.
- Cloud cache/read model: account-bound v15 metadata is carried by `FoodRepository`, `WorkoutRepository`, and `ProfileRepository`; `CacheMaintenanceService` prunes only cloud-confirmed rebuildable cache.
- Cloud record repositories: `CloudBackedFoodRepository`, `CloudBackedWorkoutRepository`, and `CloudBackedProfileRepository` live in `lib/data/repositories/food_repository.dart`, `workout_repository.dart`, and `profile_repository.dart`.
- Daily summaries: `lib/domain/services/daily_summary_service.dart` builds on demand from cloud-backed repositories, reads/writes the cloud `daily_summaries` projection through `lib/data/repositories/daily_summary_cloud_repository.dart`, and updates local selected-day confirmed cache through `lib/data/repositories/daily_summary_cache_repository.dart`; Home uses stale-while-revalidate for the selected date.
- Warm cache and eviction: `lib/domain/services/warm_cache_coordinator.dart` warms recent 30-day summaries after the five-tab shell renders; `lib/domain/services/cache_maintenance_service.dart` prunes old cloud-confirmed local cache without deleting cloud official records.
- Write/read-model coordination: cloud-backed repositories update the local confirmed cache after cloud success, pages refresh through `RefreshNotifier`, and successful food/workout/Profile writes schedule affected-date summary cache/cloud projection refresh.
- Export correctness: `lib/export/export_table_builder.dart` uses cloud-backed all-record loaders for food, workout, and body metric records before building CSV/XLSX tables, and includes a Body Metrics table.
- Root auth gate, first-render account binding, and cache-backed pages: `lib/app.dart`, `profile_page.dart`, `home_page.dart`, `food_log_page.dart`, `workout_log_page.dart`.
- Account state machine, Cloud Profile display cache, subscription display cache, background recovery, and refresh backoff: `lib/features/account/account_controller.dart`.
- Active device claim / guard: Supabase RPCs `claim_active_device`, `assert_active_device`, and `release_active_device`; Flutter repository lives at `lib/data/repositories/active_device_repository.dart`, with runtime state in `lib/domain/models/cloud_runtime_context.dart`.
- The Profile gate must treat `offline_readonly` and refresh errors with matching cache as renderable states, not full-page errors.
- The AI page may read subscription display cache for status presentation, while real send capability remains controlled by Gateway and server entitlement checks.

## Verification Invariants

Automated tests and manual acceptance should preserve these invariants:

- When backend configuration or network is missing, sign-in/registration buttons do not silent no-op.
- First signed-in render without cache does not show an empty Home and then jump to real Home.
- Cold start with cache does not wait for session, subscription, Cloud Profile, and records refresh before displaying.
- Subscription refresh failure does not block non-AI data pages.
- Failed create, update, or delete cloud writes show errors and retry, and do not create official local records.
- Background `auth_required` does not replace cached Home, Food, Workout, or Body Trends with a full-page error.
- Matching refresh metadata does not trigger visible loading, list rebuild, or scroll reset.
- Account switch or sign-out does not show the previous account's cache.

## Build Configuration

- Real account, Cloud Profile, and Cloud Records testing requires a configured build.
- Local release/debug APKs should be built with `--dart-define-from-file=config/supabase.local.json` or equivalent `SUPABASE_URL` and `SUPABASE_ANON_KEY` defines.
- A build without these defines is an unconfigured auth-shell build; it cannot verify persisted Supabase sessions, cloud records, or cloud/local cache recovery.

## Runtime Acceptance Invariants

- Signed-out startup shows the root auth gate without the bottom navigation.
- Sign-in, registration, and sign-out entries do not depend on records cache, warm cache, daily summaries, or subscription refresh; taps must produce visible feedback.
- A newer login claims the active device; an older device that receives `device_replaced` during the next cloud interaction stops official writes and returns to sign-in/takeover flow.
- A configured build restores a valid persisted Supabase session unless the user signed out, Android app data was cleared, the package/signature changed in a way that forces reinstall, or the session is unrecoverable.
- Cold start with confirmed cache renders Home immediately.
- Cold start after process death binds current account caches before active-device refresh, so Home/Food/Workout do not show an empty current day that only repairs after a date switch.
- First signed-in Home render without cache waits for the selected-day summary/read model instead of rendering an empty Home that refreshes under the user's gaze.
- `auth_required` during background refresh does not replace cached Home with a full-page error.
- Optional calibration/self-check history failures do not replace the selected-day Home summary with a full-page error.
- Unrecoverable persisted-session recovery returns to the root auth gate instead of leaving the tab shell in a permanent `auth_required` state.
- With matching account Profile cache, Cloud Profile or subscription background refresh failure does not turn Profile into a full-page error or continuous auto-retry loop.
- If subscription refresh fails while a previous confirmed active/inactive cache exists, Profile keeps the previous display state marked stale instead of flickering into loading/error.
- Body Trends renders local confirmed records before cloud refresh and does not show final empty/insufficient states while the visible window is still `partial_cache`.
- Home selected-day stale-while-revalidate cache can refresh after first render without forcing full-page loading or visible layout jumps; current warm cache fills recent 30-day summaries under the same rule.
- A failed cloud write does not create or overwrite an official local record.
- Failed foreground create, update, or delete actions show a readable error and retry/recovery path instead of appearing to do nothing.
- An older device cannot create, update, delete, or send AI after `device_replaced`; the error must not be shown as an ordinary upload failure.
- A successful cloud write updates local read models and affected summaries.
- Backgrounding during a successful new-workout save cannot recreate the cleared local draft; a failed new-record save keeps that draft available.
- Matching background refresh results do not cause visible loading flashes.
- Background refresh is bounded by freshness, visible window, and failure backoff, with no continuous polling or repeated full-page refreshes in front of the user.
- Cache eviction never deletes cloud official data.
- AI and export correctness do not depend on local cache completeness.
- Account switch or sign-out does not show another account's cached records.
