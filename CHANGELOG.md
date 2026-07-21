# Changelog

## 2026-07-22 Idempotent Workout Save Recovery

### Added

- Added a stable workout-save mutation contract, local SQLite v18 commit metadata/ledger, and an account-scoped Supabase workout commit ledger with guarded commit/status/abandon RPCs.
- Added recovery coverage for payload-hash stability, pending-draft serialization, editor auto-resume/notification suppression, lifecycle background races, and local/cloud migration contracts.

### Changed

- Workout plan create and replacement now commit all sessions and sets atomically with an idempotency key. App resume reconciles an unknown save outcome by mutation id, and retry reuses the original target plan, payload, calculation weight, and timestamp.
- A new-workout draft enters a locked save-confirmation state before the official write. Lifecycle autosave, automatic editor restoration, draft deletion, and the Android workout-in-progress notification remain disabled until the original mutation is confirmed or definitively rejected.
- A surviving process performs read-only save confirmation. A new process atomically confirms or abandons the old mutation without automatically resubmitting workout data; abandonment unlocks the ordinary draft and prevents a late old request from creating an official record.
- The Android workout-in-progress notification now appears only outside the foreground and is canceled before a notification tap restores exactly one editor route.

### Fixed

- Prevented backgrounding or process loss during Save Workout Record from leaving both a cloud-confirmed official record and a stale editable draft, including the response-loss window after the server or local SQLite transaction has already committed.
- Prevented notification-tap and automatic process restoration from stacking two workout editors, and replaced raw workout-save repository exceptions with the existing readable cloud error mapping.

### Validation

- `flutter analyze` reported no issues and all 278 Flutter tests passed. Twelve documentation/corpus/embedding/migration checks passed, including 625/625 local `text-embedding-v4` parity for build `8981d9a2f7b1923324f42c93`.
- Supabase migration `202607220001` was applied to the linked project; a PostgREST probe confirmed the new RPC schema-cache entry and authenticated-only boundary. Remote lint reported no issue in the new functions but still reports the pre-existing `redeem_internal_subscription_code` missing-`crypt` error.
- The configured split debug APK build completed for `armeabi-v7a`, `arm64-v8a`, and `x86_64`. The regenerated document corpus remains local and was not uploaded or activated.

## 2026-07-21 Camera Picker Recovery And Photo Food Save Landing

### Fixed

- Moved Android Camera lost-data recovery out of the root startup gate so returning from Camera no longer shows a full-screen Home or root loading interstitial before AI Chat or AI Food Analysis is restored.
- Restored recovered AI Food Analysis photos from inside the target page preview, preserving the note, selected image slot, and already-added images before merging the Android lost camera result.
- Deferred the first root Flutter frame only until lightweight picker-route recovery has pushed the target page, avoiding the brief default Home flash without waiting for image byte restoration.
- Restored recovered AI Food Analysis flows onto the Food tab and selected record date, and routed successful photo-analysis saves back to the Food log destination after the reviewed draft is written.
- Replaced the Android light startup/window background with the FitLog dark launch surface to avoid a white native frame when Camera returns through an Activity rebuild.

### Validation

- `flutter analyze` reported no issues. `flutter test` passed 266/266, including focused photo-analysis and picker-recovery coverage. The configured split debug APK build completed for `armeabi-v7a`, `arm64-v8a`, and `x86_64`.

## 2026-07-20 Food Description Focus And Image Source Sheet

### Changed

- Unified AI Chat and AI Food Analysis image-source selection around the same side-by-side Photo and Gallery card sheet, while preserving each route's title and selected-image count.

### Fixed

- Kept the lifted AI Food Analysis description editor as the foreground hit target while the keyboard is open. The rest of the page now dims progressively and blocks background actions, so cursor or selection adjustment cannot accidentally open the image picker; tapping or dragging the dimmed area dismisses the keyboard.

### Validation

- `flutter analyze` reported no issues and all 261 Flutter tests passed. Documentation checks passed 4/4, corpus and embedding checks passed 10/10, and build `4ebf00df876ce7cc62738c02` generated 17 missing plus 2 stale vectors while reusing 596 current vectors and pruning 15 obsolete local records. The 21-source/615-chunk build was atomically activated with 615 cloud rows and zero mismatch; identical Edge artifacts were redeployed as Chat v66 and Food photo v35 after type checks and 63/63 deterministic tests passed. Three completed production canaries each passed 30/33: retrieval held 13/13 source recall, 37/39 reviewed precision, 5/5 critical top-1, zero embedding fallback, and latest Edge retrieval p50/p95 968/1236 ms, while a repeated Qwen `provider_incomplete` on typed-clarification answer consumption left consumption, replay idempotency, and resolved-once gates open.

## 2026-07-20 Phase 5 AI/RAG Documentation Consolidation

### Added

- Added one non-executable consolidated Phase 5 final engineering record covering the original controlled RAG, Output Contract, RAG Foundation, Chat orchestration lineage, confirmed Scope IDs, migration/deployment map, preserved capability matrix, rejected approaches, rollback evidence, acceptance snapshots, and open release gates.

### Changed

- Retired the original Phase 5 plan, RAG scope/plan/audit, Output Contract plan, and Chat reliability plan after consolidating their durable evidence into the final record. The remaining valid-device journey gate is owned only by the Roadmap; neither the repository root nor `docs/history/phase5/` presents an obsolete checklist as a current execution authority. The deleted source plans remain recoverable from Git `dc6d9e86bcf62cf9509a3c7919107729c16856c3` for forensic review.
- Generated only the 118 missing/stale Qwen embeddings needed by local build `bbdd397f3d144e4ccea082e8`, reused 495 current vectors, pruned 79 obsolete local records, synchronized 613 chunks, and atomically activated the build with 613/613 cloud parity. Redeployed the current Edge source as ACTIVE `ai-chat-route` v65 and `ai-food-photo-analyze` v34; all 28 migrations were already aligned and were not reapplied.
- Updated the Roadmap to mark Phase 5 complete and archived, Phase 6 substantially implemented with final evidence gates open, and Phase 7 current. Keyword/term normalization, vector retrieval, hybrid fusion, reranking, coverage/retry, validators, and existing record/draft/recovery owners remain explicit non-regression requirements.

### Fixed

- Corrected the `cm01_se` classification from an Android test device to the user's PC water-cooling controller. The unsuccessful ADB installation attempt remains historical evidence only; it does not satisfy device acceptance and no longer creates an impossible device-specific release gate.
- Removed stale `active remediation` wording from the embedded bilingual RAG and output-contract documents and added corpus tests that reject history or engineering-plan sources.

### Validation

- Regenerated 613 chunks from the same 21 allowlisted stable sources as build `bbdd397f3d144e4ccea082e8`. Documentation/outline/link checks passed 4/4, corpus/chunker checks passed 4/4, embedding contract/sync unit checks passed 6/6, required Edge tests passed 63/63, and the full Edge suite passed 278/278 with two declared external fixtures ignored. The first activation canary passed 32/33 with the sole failure being a 1519 ms retrieval p95 against the unchanged 1500 ms gate; an identical recheck passed 33/33 with Edge retrieval p50/p95 926/1244 ms, 13/13 source recall, 37/39 reviewed precision, 5/5 critical top-1, zero embedding fallback, and zero transport retry.

## 2026-07-19 AI Chat Orchestration And Reliability

### Added

- Added the provider-neutral `chat_decision.v2` production path, behavior-parity fixtures with real executors, privacy-safe shadow comparison, and an `auto` workflow cloud canary that asserts completed answers/drafts rather than accepting arbitrary clarification.
- Added server-owned `ai_chat_clarification.v2` state with typed options, account/session-bound claims, stable request-ID replay, bounded no-progress/expiry handling, runtime-only attachment leases, history restoration, and Flutter option/error UI.
- Restored the six Phase 4 plans under `docs/history/phase4/` as `HISTORICAL / DO NOT EXECUTE` parity evidence without adding them to Document RAG.

### Changed

- Made one Chat decision own capability, output family, authorized Context, clarification, and attachment policy. Typed replies now restore the originating task's required Context, while existing Structured RAG, keyword/vector hybrid retrieval, reranking, coverage/retry, Food/Workout validators, and confirmed draft handoff/recovery authority remain unchanged.
- Current images reach the bounded planner when capability truly depends on them and reach the selected provider in the same turn. A clear consumed-food statement can produce a Food Draft even when an attached image is unclear; uncertainty stays in the draft instead of reopening intent selection.
- Narrowed write-claim blocking to completed AI/user-record mutations and normalized only balanced Markdown inline-code delimiters in evidence presentation labels, preserving the raw evidence payload and technical identifiers.

### Fixed

- Fixed the repeated three-option loop after replies such as `回答问题` or `食物草稿`, the clear soup-image request being rejected before model use, passive database storage explanations being mistaken for completed AI writes, and planner/provider failures being displayed as user ambiguity.
- Fixed clarification insertion on Supabase by explicitly resolving `pgcrypto.digest` from the `extensions` schema, and preserved both assistant message and debug-summary IDs in a successful clarification replay.

### Validation

- Applied additive migrations `202607190001` through `202607190003` and kept `rag_foundation_v1`, Document RAG retry, vector retrieval, hybrid fusion, reranking, coverage, and retry enabled. A legacy rollback rehearsal kept Edge/RAG/data available while intentionally failing 8 v2 behavior gates; the final deployed code then retired the legacy branch and its two runtime secrets. The post-retirement real-Qwen `auto` cloud gate passed 33/33 checks, including both reported failures, typed create/consume/replay with `resolved` and `attempt_count = 1`, Food image completion, 13/13 source recall, 37/39 source precision, 5/5 critical top-1, production Edge embeddings with no issue codes, and the unchanged 1500 ms Edge retrieval p95 gate.
- `flutter analyze` reported no issues; all 259 Flutter tests, 63 required Edge tests, 278 full Edge tests, 21 documentation/corpus/migration tests, and 108 local release fixtures passed. Configured split debug APKs were built and hashed. The ADB-exposed `cm01_se` target was later identified by the user as a PC water-cooling controller rather than an authorized test phone: the unsuccessful PackageInstaller session and temporary APK files were removed, no package was installed, and the attempt is not device-acceptance evidence. Manual journeys therefore remain open for a user-confirmed Android test device. The final 21-source/613-chunk local documentation build was not sent to the external embedding provider; cloud remains on the separately verified 586-chunk active build pending explicit data-externalization approval.

## 2026-07-19 Photo Picker And Workout Draft Recovery

### Changed

- Restored an active new-workout editor after an Android process rebuild when its authoritative SQLite draft was updated within 30 minutes. Surviving processes keep the existing route, older drafts remain manual through the Workout resume bar, and explicit back, discard, or successful save clears the lightweight route hint without adding a background timer or keepalive.
- Kept draft persistence ordered and critical while making workout notification rendering best effort. Rapid field edits now receive one trailing notification update, semantic actions and backgrounding sync immediately, and Android reuses the current decoded notification bitmap.

### Fixed

- Gave a mounted AI Food Analysis page exclusive ownership of its camera/gallery result and made root lost-data recovery single-flight only when that page is absent. Returning from Camera can no longer stack a second incomplete analysis page, expose the original page after Save, or enable a duplicate save sequence.
- Prevented a pending workout-notification update from reappearing after the draft was saved, discarded, or emptied.

### Validation

- `flutter analyze` reported no issues and all 251 Flutter tests passed. Focused recovery/notification tests also passed, including live-page picker ownership, single-flight lost-data recovery, recent-versus-expired workout route restoration, explicit-exit clearing, cancellation ordering, and a 320-update notification pressure case that rendered only the latest state once.
- Regenerated 595 chunks from 21 stable bilingual sources as local corpus build `0529595f175827fc3255df44`; all 10 deterministic corpus and embedding-sync checks passed. No cloud upload or corpus activation was performed.
- Rebuilt the configured split debug APKs: `arm64-v8a` SHA-256 `0125195648ed57ed755e464503678dec0a98d543ef28838e138a50e3faa9a4f8`, `armeabi-v7a` `a1df4dac9f755d02838c85130695a4761050e3f3338a62c2f0787469cc2f3002`, and `x86_64` `de5f9fcfc8abf3973aa84bd0da30877ae405660b301eb7e08336e824c6b0d7d9`.

## 2026-07-19 Paste JSON Editor And Modal Surfaces

### Added

- Added a top-right expand action to Paste AI Result. Its neutral four-corner expand/collapse controls stay visually quiet, and it waits for an open keyboard to close before presenting a root modal containing only a larger JSON editor, preserving text and selection and writing edits back on close.

### Fixed

- Smoothed the JSON editor's keyboard-motion handoff and made the state-preserving setup card fade progressively with the opening keyboard instead of disappearing in one frame. The fixed Parse control remains input-gated and naturally covered, while the live inset stays the sole editor-motion owner.
- Added a fixed blurred modal backdrop and opaque elevated guide surface so Profile method information and other shared guide sheets no longer reveal page content through the Black Orange panel.

### Validation

- `flutter analyze` reported no issues and all 244 Flutter tests passed, including continuous 40/52/64 px JSON-editor handoff coverage, progressive Prompt opacity at 40/80/180 px, low-emphasis Black Orange resize controls, keyboard-close-before-modal sequencing, expanded-editor value/selection return, and the Black Orange Profile guide surface.
- Regenerated 588 chunks from 21 stable bilingual sources as local corpus build `9e6ff8f97b77ffccadd68444`; all 10 deterministic corpus and embedding-sync checks passed.
- Rebuilt the configured split debug APKs: `arm64-v8a` SHA-256 `dab467b8971ba7b2cce925fc56ec4e2e056c5bb3ed905b3161081c895b4eb08a`, `armeabi-v7a` `c4c20ef9e9c385dcaff0b801be317320898c6912a1abc060d136680890517f3b`, and `x86_64` `de2fb0df24fab5b15e7827d2c6d4d135e0234ac291f60d8548ecbbb42fdfa6b1`.

## 2026-07-19 AI Food Analysis Keyboard Dismissal

### Fixed

- Kept the floating AI Food Analysis action, its lower shield, and matching list clearance at their closed-keyboard screen geometry throughout keyboard travel. The system keyboard now covers and reveals the action without an inset-driven fade or safe-area return jump, while input remains gated until the keyboard is fully closed.

### Validation

- `flutter analyze` reported no issues and all 243 Flutter tests passed, including regression coverage that holds the analysis-action rectangle constant at 0, 80, 180, and 336 px keyboard insets while checking keyboard-time input gating.
- Regenerated 586 chunks from 21 stable bilingual sources as local corpus build `dae128f72cc9711943d88d66`; all 10 deterministic corpus and embedding-sync checks passed.
- Rebuilt the configured split debug APKs: `arm64-v8a` SHA-256 `dda5289feac440f2a1d154b7ceccca64a270c99ab2272e8aed214fc08e28ec5a`, `armeabi-v7a` `f5eb13075e31de6bba3cdf10a491dcb0472f98b5afd663833a7a25b417c2df2f`, and `x86_64` `b08704cdc977896451b1dbdd9abaf89d6b8c932bff236de9c6273be4f7766395`.

## 2026-07-18 Profile Body Precision

### Fixed

- Canonicalized current Profile height, weight, body-fat, and waist drafts to one decimal before both Cloud Profile and same-day body-metric persistence, then synchronized the saved snapshot and editor baseline to the same values. A two-decimal input now saves once at the displayed precision without reopening the unsaved-changes prompt.

### Validation

- `flutter analyze` reported no issues and all 243 Flutter tests passed, including new coverage for one-time two-decimal normalization and legacy two-decimal cloud values that must load without a false dirty state.
- Regenerated and validated 586 chunks from 21 stable bilingual sources as corpus build `a33cf90c1adf71ec7d08113d`; all 10 deterministic chunking and embedding-sync tests passed. After human approval review was enabled, generated the eight missing Qwen vectors, reached 586/586 local parity, atomically activated the build in Supabase, and independently verified 586 cloud rows with zero metadata mismatches.
- Rebuilt the configured split debug APKs: `arm64-v8a` SHA-256 `bbd109a6ccd8be52e17f286a1ab01d846758a2fb71f145d641a0aa8faa631197`, `armeabi-v7a` `34566cd0bc7eec1b9955e7f1d3b7c2d41c7e76f3582088825e8e4ad5e563366b`, and `x86_64` `832512b52ff9a26cc6bc2a2d58e523eaeb19484248bbaf0a2f1781a6983831a0`.

## 2026-07-18 Food Input Keyboard Motion

### Fixed

- Simplified AI Food Analysis keyboard avoidance so the live system inset rigidly translates the fixed-size food-description editor, while the mounted analysis action uses paint-only opacity and input gating instead of per-frame field reveal or layout changes.
- Simplified Paste AI Result keyboard avoidance so the fixed-size JSON editor follows the live inset as one rigid surface, while the setup card and Parse action retain stable layout footprints and use paint-only opacity instead of collapsing supporting content or resizing the editor.
- Kept the live inset as the sole vertical-motion owner on both pages without caching a device-level keyboard height, delayed correction, or a second close animation.

### Validation

- `flutter analyze` reported no issues and all 241 Flutter tests passed, including fixed editor geometry, monotonic keyboard travel, repeated reopen/close cycles, stable supporting-content footprints, drag dismissal, and short-viewport coverage.
- Regenerated 586 chunks from 21 stable bilingual sources as corpus build `ce16bcf95848684f0f8a372d`; all 10 deterministic corpus/embedding tests passed. Reused 575 compatible vectors, generated only 11 Qwen vectors through a short-lived service-role-and-nonce-protected relay after the local Qwen TLS route reset, reached 586/586 local parity, atomically activated the build in Supabase, and independently verified 586 cloud rows with zero metadata mismatches. The relay function, nonce secret, and local helper files were removed after verification.
- Rebuilt the configured split debug APKs: `arm64-v8a` SHA-256 `00ce7c59ef7b36253f7c54792e98ce156691a9ba903fcf4945b9f206704f3a24`, `armeabi-v7a` `aee248eb7264623feb8b707d4934b99e6cccb69d84b7cf073d83ed9e27800971`, and `x86_64` `ca2411b78909dde4fb800eafd5c0bf6b40d8d72321ccb858880a6afddd8c2b56`.

## 2026-07-17 Auth Keyboard And Food Photo Picker

### Changed

- Replaced the permanent Photo/Gallery controls in AI Food Analysis with one clickable large preview and a bottom source sheet. The empty preview explains how to add images; a selected preview retains only a small lower-right `+`.
- Moved the model selector directly below the AI Food Analysis heading, removed the redundant subtitle and selector card, tightened the fixed preview/thumbnail rail, and replaced the full footer area with a floating analysis action plus a same-width lower-half content shield.
- Kept the AI Food Analysis preview and fixed thumbnail rail as one compact visual group, with a larger 16 px boundary before the food description.
- Enabled Android Photo Picker selection limits, requested only the remaining capacity, and changed a full three-image set to replace the selected image on the next pick.

### Fixed

- Reworked sign-in and registration keyboard handling around one stable layout tree and one inset owner. Keyboard Next follows the full login/registration field chain; each focus change owns one short transition and same-height IME updates no longer start a delayed second correction. The closed-keyboard canvas returns to a locked zero offset without logo or layout swapping.
- Kept the AI Food Analysis list, food-description field, focus node, floating action, and shield mounted throughout keyboard travel. The action now fades without changing layout, list clearance stays constant, and only a rising inset can request the minimum positive reveal needed for the editor; keyboard close performs no corrective scroll or padding switch.
- Removed the Paste AI Result page's independent 180 ms controller, direction detector, and automatic Scaffold resize. The native keyboard inset now directly owns the editor boundary and supporting-content fraction in both directions, preventing a lagging second resize or upper-edge snap on close.
- Removed delayed keyboard-reveal timers from Profile inline editors and AI history rename, while adding drag-to-dismiss behavior to ordinary scrollable Food, Workout, and Profile forms.
- Rejected picker results that exceed the requested image capacity instead of silently accepting only the first three.

### Validation

- `flutter analyze` reported no issues and all 239 Flutter tests passed, including mounted-but-faded Food Analysis actions during keyboard travel, rising-only food-description reveal, direct-inset Paste editor geometry, repeated keyboard reopen, floating-action shielding, source-sheet add/replace behavior, remaining-slot limits, overflow rejection, stable auth focus chaining, and lower-history rename retention.
- Regenerated 583 chunks from 21 stable bilingual sources as corpus build `b4400ad8b82742b465ffd6d7`; all 4 chunking and 6 embedding-sync deterministic tests passed. After explicit document-egress and service-role authorization, generated the 30 missing and 7 stale Qwen embeddings, pruned 26 obsolete vectors, reached 583/583 local parity, uploaded and atomically activated the build in Supabase, and independently verified 583 cloud rows with zero metadata mismatches.
- Regenerated the 583-chunk corpus as build `867f7969fd4608ecc0f6f576` after the auth-keyboard documentation correction; all 10 deterministic corpus/embedding tests passed. After explicit post-risk document-egress authorization, generated only the 6 missing Qwen vectors, pruned 6 obsolete vectors, reached 583/583 local parity, atomically activated the build in Supabase, and independently verified 583 cloud rows with zero metadata mismatches.
- Two post-activation canaries both confirmed the new active build, all five Qwen provider checks, retrieval hit 13/13, reviewed precision@3 92.31%, critical top-1 5/5, zero embedding fallbacks, and all access-control probes. The only remaining failed Gate is production Edge retrieval p95: 1,909 ms on the first six-sample run and 1,712 ms on the independent recheck, above the 1,500 ms threshold; the active corpus was retained and the local evaluation records 9 passes, 1 failure, and 0 blocked checks.
- Regenerated 584 chunks from 21 stable bilingual sources as corpus build `24d565c6b709bde3811a92ae`; all 10 deterministic corpus/embedding tests passed. After explicit authorization, generated only the 10 missing Qwen vectors, pruned 9 obsolete records, reached 584/584 local parity, atomically activated the build in Supabase, and independently verified the active state, 584 cloud rows, and zero metadata mismatches. The one-time JWT-protected activation function and all local helper code were deleted after verification.
- Rebuilt the configured debug split APKs: `arm64-v8a` SHA-256 `14c6db68e489a1284b11440766297accb2348921bda81d7cde703ab8ec7c0b1b`, `armeabi-v7a` `fd72003dd2e33fbb2f0862f3d1085c78900ad3852f39a645f05e7f58dac85b1a`, and `x86_64` `d0e9d15e63703163365d7d92fc40fb47e99273f0eaed572176348ca6bf6776f5`.
- `flutter analyze` reported no issues and all 239 Flutter tests passed after the unified keyboard-owner change, including repeated Paste editor reopen, keyboard-only Food description layout, auth focus retention/Next chaining, Profile inline editing, and lower-history rename coverage.
- Regenerated 583 chunks as build `e5dcd22e8989d3ae0914d3cd`; all 10 deterministic chunking/embedding tests passed. Generated the 23 missing and 1 stale Qwen vectors, pruned 24 obsolete local records, reached 583/583 local parity, atomically activated the build in Supabase, and independently verified 583 cloud rows with zero mismatches. The temporary service-role-only embedding relay used to bypass a local TLS route reset was deleted immediately after use.
- The final vector-enabled canary used the new active build, passed all five Qwen provider probes, retrieval hit 13/13, reviewed precision@3 92.31%, critical top-1 5/5, and recorded zero embedding fallbacks. Its only failed Gate was Edge retrieval p95 at 1,576 ms versus 1,500 ms; an independent same-build recheck measured 1,364 ms, so the activated vector corpus was retained without downgrading retrieval.
- Rebuilt the configured split debug APKs: `arm64-v8a` SHA-256 `0f4bfe225e44084199fd044a4d928eb41b1f1f7d242dc17f61a557b65a4a4a58`, `armeabi-v7a` `d49a69e2f1d0e447bc8e0b3f6ae9a3f1413e716dc85d9d1508fdaefddef20e04`, and `x86_64` `caef853ee35968a42cc2346997313ff1a9ad84a940c7752d35db32f96556524f`.
- `flutter analyze --no-pub` reported no issues and all 239 Flutter tests passed, including stable Food description focus/input connection during inset changes and frame-synchronized Paste supporting-content movement in both keyboard directions.
- Regenerated 584 chunks from 21 stable bilingual sources as corpus build `5fc91991637d6621a0f56e8f`; all 10 deterministic chunking/embedding tests passed. When the Codex host could not establish external TLS, the previously proven temporary cloud-relay path reused 572 compatible vectors, generated only 12 Qwen vectors, atomically activated the build, and independently verified 21 sources, 584 cloud rows, 584 valid `text-embedding-v4` 1536-dimensional vectors, and zero metadata mismatches. The activation response was Base64-wrapped before local import so four Chinese section IDs could not be lost to terminal encoding; final local parity is 584/584 with no missing, stale, or extra records. The JWT-and-one-time-nonce function, nonce secret, temporary `pg_net` extension, and all local helper files were removed after verification.
- The post-activation canary confirmed the new build in production, passed all five Qwen provider probes, and measured Edge retrieval p50/p95 at 924/1,313 ms with completed query embeddings and no Edge issue codes. The aggregate result was 26/28 only because the local direct runner inherited the Codex host TLS failure and recorded 14 local embedding fallbacks, causing its two retrieval-quality Gates to miss; production Edge remained vector-enabled and within the 1,500 ms latency Gate.
- Rebuilt the configured split debug APKs: `arm64-v8a` SHA-256 `89d00bc5d23c0de79aea5ce0173d26b13b79ae4348b3362ba113ef0bf00839ca`, `armeabi-v7a` `a2dfe760c3e8f661d66cfb222f53497f0f4a9d75a599ae09a599520632c1f695`, and `x86_64` `f1ee2753030587b07908925dbbbb9de808424c550f287a453672090620f784cc`.
- Regenerated 586 chunks from 21 stable bilingual sources as corpus build `bcb0dc993a76fd71a9aa7528`; all 10 deterministic chunking/embedding tests passed. After renewed explicit document-egress authorization, the JWT-and-one-time-token cloud relay reused 576 compatible vectors, generated only 10 Qwen vectors, pruned 7 obsolete local records, reached 586/586 local parity, atomically activated the build in Supabase, and independently verified 21 sources, 586 cloud rows, valid 1536-dimensional `text-embedding-v4` vectors, and zero metadata mismatches. The temporary function, token secret, `pg_net` extension, and local helper files were removed afterward.
- The post-activation canary confirmed the new build and all five Qwen Provider probes; all three production Document requests completed query embedding without fallback. The aggregate result was 24/27 because five direct-runner embeddings inherited the Codex host route instability, reducing one fixture's recall/top-1 result, while one six-sample Edge request raised retrieval p95 to 1,982 ms. An independent recheck could not start because the same host received a Supabase TLS handshake EOF, so the correctly activated vector corpus was retained without changing retrieval policy.
- Rebuilt the final configured split debug APKs: `arm64-v8a` SHA-256 `835408a0902a2666875adad71f893c10f66df07539252f3613ca5fff369e41fa`, `armeabi-v7a` `79b1d0e520a10d84bafacea648652cb62b7e0e67f9b359dafe8c76578fdc504f`, and `x86_64` `53c2034d7cbcec199ffa5f1b7c254489afdc7f56eebe7a6aba3356ad15442e46`.

## 2026-07-16 Food Prompt, AI Chat, And Intent Routing

### Changed

- Removed the duplicate reusable-Prompt action from Add Food. Paste AI Result now owns a one-time setup card with a single labeled copy button, explains the photo/description-to-JSON return flow before recommending `FitLog 中文助手` and `FitLog Estimator`, and continues to copy the Chinese or English standing prompt according to the app language.
- Made the fixed conversation header use a compact same-row readiness light so the provider selector cannot push status onto a second line. The empty-chat composer retains the labeled readiness pill.
- Reused the closed-keyboard message/composer separation while the keyboard is open: the same 10 px region gap, 14 px list-bottom padding, and short bottom fade preserve a 24 px bubble-to-composer visual distance. The composer keeps its normal glass surface instead of switching to a theme-colored solid surface and oversized veil.
- Reworked the Paste AI Result setup card into a compact two-step inset panel for usage and recommended GPTs, removed the redundant leading icon and setup badge, and retained the labeled copy action and language-matched standing Prompt.
- Made first-layer Workout intent precedence explicit: direct FitLog rule questions stay read-only answers, explicit structured logging requests still produce drafts, mixed Workout write-and-question requests produce clarification, and same-chat Workout continuation requires a real draft artifact plus an edit operation. Existing Food selection is unchanged.

### Fixed

- Added vertical-drag keyboard dismissal while preserving the first outside tap as a dismiss-only action and keeping message scrolling locked until the keyboard closes.
- Prevented clarification responses from appending a normal answer or draft-like essay by bounding visible clarification text to 320 characters and one or two questions.
- Restored readable black-theme colors for the Chat history heading and actual composer input without changing the muted empty-field hint, and increased animated background sampling density to remove visible horizontal banding at the blue-field peak.
- Made Paste AI Result temporarily scrollable only while its JSON editor and keyboard are active, eliminating fixed-column overflow without changing the resting layout. Profile sign-in and registration now reveal every focused email/code/password field above the keyboard, retain keyboard-time manual scrolling, and reset to a locked zero offset after keyboard dismissal.

### Validation

- `flutter analyze` reported no issues and all 233 Flutter tests passed, including the standing Prompt contract, Paste AI Result keyboard-only scrolling, Profile login/registration field reveal, Add Food, compact status, AI keyboard geometry, outside-tap, and vertical-drag coverage. All 78 Edge contract/router/provider tests and all 10 corpus/document deterministic tests passed.
- Regenerated 577 chunks from 21 stable bilingual sources as build `d555656c39225eb8bcf1a289`, generated only the 24 missing/stale Qwen embeddings, pruned 21 obsolete records, reached 577/577 local parity, atomically activated the build in Supabase, and verified 577 cloud rows with zero mismatches.
- The post-activation live canary passed 28/28 checks with retrieval hit 13/13, reviewed precision@3 97.44%, critical top-1 5/5, zero embedding fallbacks, and Edge retrieval p50/p95 1,119/1,435 ms. Rebuilt the configured `armeabi-v7a`, `arm64-v8a`, and `x86_64` debug split APKs.
- After explicit document-egress authorization, regenerated 579 chunks as build `942de22e58135187a7550327`, generated the 25 missing Qwen embeddings, pruned 23 obsolete local vectors, reached 579/579 local and cloud parity, and atomically activated the build in Supabase with zero mismatches. The independent post-activation canary passed 28/28 checks, used the new build, reached retrieval hit 13/13, reviewed precision@3 92.31%, critical top-1 5/5, zero embedding fallbacks, and production Edge retrieval p50/p95 of 1,109/1,422 ms. The local evaluation report now explicitly consumes this canary and passes 10/10 checks without blocked items.

## 2026-07-15 RAG Foundation Remediation Canary And Stage Diagnostics

### Added

- Added the Qwen `text-embedding-v4` document-embedding pipeline, versioned bilingual corpus manifest, cloud parity checks, controlled hybrid retrieval, owning-document reranking, bounded one-retry retrieval tool, task/context planning, action-history context, deterministic Workout Draft binding, and provider-independent grounding and Food Capability contracts.
- Added seven additive Supabase migrations for hybrid document retrieval, exercise history context, AI observability, latency breakdown, workflow persistence, indexed candidates, and parallel candidate fusion, then applied them to project `dyacqajcinjwrkbngeif`.
- Added deterministic and live evaluation runners with sanitized machine-readable and Markdown reports covering ingestion, retrieval, routing, context, grounding, privacy, provider behavior, failure injection, access control, and per-stage latency. Production diagnostics separate planning, query normalization, embedding, hybrid RPC, reranking, retry rewrite/search, generation, validation/correction, persistence, and external round-trip time without retaining prompts, vectors, excerpts, or provider output.
- Kept OpenAI adapters and contract tests without making OpenAI a release or RAG dependency. When OpenAI is not legally configured, selecting ChatGPT in AI Chat or dedicated food analysis shows the bounded `当前模型不可用` notice, preserves input, sends no request, and automatically slides the UI selection back to Qwen without converting the attempted selection into a hidden Qwen request.

### Changed

- Restored prompt copy as a secondary Add Food action and replaced the Paste AI Result recommendation card with the same reusable external-chat prompt. The standing prompt is sent once per new external chat, keeps every reply in the established complete flat JSON schema, reconciles meal totals from item values, and reserves trailing `estimation_notes` for necessary non-duplicative supplemental information. Copy language follows the app's Chinese or English mode.
- Removed sign-out from the transient AI account/subscription sheet; Profile remains the explicit account sign-out surface.
- Changed only the AI Chat keyboard interaction: the composer now keeps a 12 px gap above the keyboard, a bounded blurred gradient veil conceals the lower reading edge, message scrolling is locked while typing, and the first tap outside the composer dismisses the keyboard before page content can be activated. Other input screens retain their existing behavior.
- Unified ingestion and query normalization around bounded overlapping Chinese 2-4 grams, bilingual canonical terms, language-first ordering, and stable owning-document cues. Indexed term/FTS/trigram candidates now run concurrently with Qwen query embedding, while PostgreSQL v3 preserves global branch ranking and returns only 30 final candidates for Edge reranking. Document embeddings use Qwen `text-embedding-v4` at 1536 dimensions; generation remains on the configured Qwen text/vision model.
- Unified the AI Chat and Food analysis model pickers around the bottom navigation's 240 ms sliding-indicator motion. The readiness status remains tied to account, subscription, device, network, and Gateway gates rather than the temporarily selected provider.
- Regenerated and activated 569 chunks from 21 stable sources as corpus build `b209353e25df637256a1825f`, with zero missing, stale, extra, or cloud-mismatched vectors.
- Kept `rag_foundation_v1` and the bounded Document RAG retry enabled throughout diagnosis and optimization; performance results never triggered an unapproved runtime rollback. Retry now stops on complete/conflicting coverage, unknown exact identifiers, and unchanged rewrites, while retaining one useful missing-evidence retry. Additive migrations persist the bounded stage breakdown and align `record_ai_chat_turn` with the already-supported `workout_logging`, `general_chat`, and `safety_boundary` workflows.
- Reduced first-pass output ambiguity by giving Qwen only the selected output-family contract and a final family reminder, narrowing OpenAI strict schemas equivalently, compacting controlled prompt context, and setting capability-specific output budgets without accepting truncated artifacts.
- Promoted the curated RAG reliability/performance report into `docs/reports`, expanded it with measurement provenance, before/after speed and reliability results, causal analysis, rejected alternatives, residual risks, deployment evidence, and a reproducible raw-evidence index; generated snapshots remain under `test/evals/reports` with their own reading guide.

### Fixed

- Prevented stale local embedding records from surviving corpus regeneration, Chinese boundary phrases from being lost by non-overlapping tokenization, vector-only unrelated queries from fabricating document evidence, and canonical Chinese product claims from failing grounding only because internal enum spelling was absent.
- Prevented model-planner clarification turns from using the invalid pseudo-provider `planner`, and preserved full retrieval/retry metadata on failed requests so error-path latency evidence is not silently lost.
- Preserved Workout Draft routing for explicit workout-record requests and prevented complete, conflicting, unknown-identifier, or unchanged-query retrievals from paying for a no-gain model rewrite and second search.
- Preserved strict no-write, account-scope, source-authority, output-validation, and user-confirmation boundaries across normal, degraded, retry, and provider-failure paths.

### Validation

- Added widget and parser coverage for both reusable-prompt entry points, Chinese/English copied prompt content, standing prompt constraints, the unchanged `estimation_notes` JSON schema, and the AI sheet sign-out boundary. `flutter analyze` reported no issues and all 230 Flutter tests passed. Regenerated 577 chunks from 21 bilingual sources as build `99d908c576c844fd3c39d853`, completed 577/577 local embedding parity, uploaded and atomically activated the build, and independently verified 577 cloud rows with zero hash/vector metadata mismatches.
- Added AI page widget coverage for the keyboard gap, blur veil, scroll lock, outside-tap dismissal, close transition, and existing send-anchor behavior; `flutter analyze` reported no issues and all 224 Flutter tests passed. The required Edge checks passed, the full Edge suite passed all 130 tests, and the Node corpus/document suite passed all 20 tests. Regenerated the pending local Document RAG corpus as 577 chunks from 21 bilingual sources (build `941ac5b833f33e3c693e3443`); the four deterministic corpus tests passed, and no cloud upload or activation was performed.
- Live Qwen canary passed Chat 3/3 and Food text/image 2/2. Retrieval recall@3 was 100%, reviewed source precision@3 was 97.44%, critical top-1 was 100%, and all cross-account/access probes passed.
- The unchanged normal-latency and quality Gates now pass. The final release canary completed 28/28 checks with recall@3 100%, reviewed precision@3 97.44%, critical top-1 100%, and normal Edge retrieval p50/p95 1,061/1,250 ms. The repeated text-budget canary kept retrieval p95 at 1,299 ms; Chinese, English, and unknown-identifier paths were each 3/3 first-pass valid with zero correction and zero retrieval retry. An eight-concept stress probe remained first-retrieval complete but measured p95 1,566 ms; because no current canary produced a genuine useful retry, the conditional retry-increment p95 is recorded as unsampled rather than claimed as passed.
- Built configured split debug APKs for `armeabi-v7a`, `arm64-v8a`, and `x86_64`; recorded their sizes and SHA-256 hashes in the remediation engineering plan.
- After explicit document-egress authorization, sent only the stable repository-document embedding inputs to Qwen, pruned stale/extra local vectors, and activated the resulting 577-chunk build in Supabase. The first refresh canary passed 25/26 with one transient retrieval-latency miss; the independent recheck passed 26/26, used the new build in every Edge retrieval sample, had zero embedding fallbacks, and measured Edge retrieval p50/p95 at 1,217/1,438 ms.

## 2026-07-12 Workout Draft Retention Boundary

### Changed

- Limited retained workout drafts, the Workout resume bar, and Android workout-in-progress notifications to manually created or AI-generated new workout records.
- Kept saved-history edits page-local: leaving without a successful save now discards pending changes instead of creating a resumable draft.
- Advanced local SQLite to schema v16 with an idempotent cleanup of legacy `edit_record` draft rows while preserving the existing table and new-record payload compatibility.

### Fixed

- Prevented merely opening a saved workout through the edit action from copying the official record into the active draft slot and showing a misleading draft bar on return.
- Added a repository boundary that rejects non-`new_record` active-draft writes and filters legacy edit drafts from active reads.

### Validation

- Added regression coverage for legacy edit-draft classification, repository write rejection, and the v16 schema boundary.
- `flutter analyze`: no issues; `flutter test`: all 214 tests passed.
- Regenerated the bilingual Document RAG seed with 510 generator-v3 chunks after the stable Product, AppGuide, Database, and Cloud/Local boundary updates.
- Built configured split debug APKs for `armeabi-v7a`, `arm64-v8a`, and `x86_64` with `config/supabase.local.json`.

## 2026-07-12 Notification And AI Request Lifecycle

### Fixed

- Prevented save-success notifications from becoming unmanaged permanent overlays when a save and route pop occur in the same frame.
- Food Preview, manual food entry, food editing, and workout saving now capture the root Overlay before navigation and show their confirmation after the destination page is visible, preserving the normal bounded auto-dismiss lifecycle.
- Notification cleanup now distinguishes the pre-mount state from a genuinely removed Overlay entry, so route animation cannot cancel the timer while page disposal still releases it.
- Removed the AI page's private close-button error pill and routed send, attachment, and history failures through the shared bounded notification layer, with composer-aware positioning and foreground-only presentation.
- Serialized chat-history deletion globally so rapid taps on one or several sessions cannot issue overlapping delete operations or surface a misleading generic AI failure.
- Kept in-flight AI requests alive across normal app background/foreground transitions; true transport or Gateway failures still restore the attempted input for retry.
- Preserved repository network-error classification during chat-history refresh so a background transport interruption no longer degrades into the generic AI-request message.

### Validation

- Added regression coverage for success auto-dismiss, same-frame route-pop cleanup, post-navigation save notices, page-disposal timer cleanup, duplicate history deletion, shared AI errors, and background request continuity.
- `flutter analyze` reported no issues and all 213 Flutter tests passed.
- All 18 local migrations matched the linked remote migration history; no schema push was required.
- Deployed `ai-chat-route` version 21 and `ai-food-photo-analyze` version 14 after all 57 deterministic Edge tests passed.
- Uploaded and verified the bilingual stable-document corpus with 508 generator-v3 chunks across 19 source paths and two languages; English and Chinese notification-lifecycle retrieval both returned the owning Product/AppGuide sections.

## 2026-07-11 AI Intent Selection And Error-Lifecycle Hardening

### Added

- Added `provider_gateway_envelope.v2` with explicit `output_type` values for text, Food Draft, Workout Draft, and clarification, plus typed Flutter reconstruction and public API documentation.
- Added privacy-safe request telemetry for intent-resolution source, validated output type, and validation issue categories, together with service-role update grants that allow successful request/debug rows to be finalized after the initial RPC insert.
- Added Phase 6 regression coverage requirements for resolver abstention, model output selection, explicit workflow behavior, false draft success, error classification, and notification lifecycle.
- Added deterministic draft-date resolution, strict date agreement validation, and date-aware confirmation text for Food and Workout drafts.

### Changed

- Split ordinary AI Chat output selection into a high-confidence deterministic resolver and bounded model selection after `auto` abstention. Explicit Add Food analysis keeps a fixed Food Draft family and bypasses Chat intent inference.
- Separated workflow/context routing from result shape so authorized read-only context can support an editable draft without granting an official record write.
- Removed internal phase wording from provider-visible controlled context and prepended optional ingredient-photo or delivery-screenshot guidance to meal-decision answers without request images.
- Rebuilt and uploaded the bilingual stable-document corpus with 506 generator v3 chunks across 19 source paths.
- Upgraded current Food/Workout drafts and persisted Chat artifacts to v2 date-bearing shapes while preserving mixed-deployment and stored-v1 readability. Draft review now shows the accepted date and uses the normal themed calendar control before save.

### Fixed

- Fixed natural Workout Draft requests such as bench press plus weight/reps being accepted as ordinary prose instead of producing a validated draft or clarification.
- Rejected structurally valid text that claims a draft was created when no matching artifact exists, and enforced cross-field output-type, clarification, and draft-family consistency.
- Stopped misclassifying response decoding and unknown SDK/provider failures as network outages; only recognizable socket/timeout failures use the network category.
- Restored compact passive app notices without close icons; notices remain bounded and replacement-based, and clear on root-tab, originating-route, or app-background transitions while retry input remains preserved where applicable.
- Prevented lifecycle autosave from recreating a workout draft after a cloud-confirmed official save by freezing new autosaves and ordering the final draft deletion behind older queued writes.
- Restored successful output/debug telemetry finalization by granting the Edge Function service role the missing table-update permissions.

### Validation

- Deno type checks passed for both Edge Function entry points; all 57 deterministic Edge tests passed.
- `flutter analyze` reported no issues and all 208 Flutter tests passed.
- Built all three configured split debug APKs under `build/app/outputs/flutter-apk`.
- Applied remote migrations `202607110001` and `202607110002`; deployed `ai-chat-route` version 20 and `ai-food-photo-analyze` version 13.
- Verified 506 cloud chunks, 19 source paths, two languages, generator v3, and bilingual retrieval of the new intent-resolution, draft-date, and notification-lifecycle rules.
- A real UTF-8 Qwen Workout Draft canary resolved “yesterday” to `2026-07-10` and returned `workout_draft.v2`; a real dedicated Add Food text canary returned `food_draft.v2` with the exact selected date `2026-07-09`. Neither wrote an official record.
- A synthetic 1x1 image was rejected before provider completion as `provider_failure`; a user-approved real food-image device canary remains operational acceptance work and no private screenshot was exported during this landing.

## 2026-07-10 AI Output Contract Engineering Landing And RAG Documentation

### Added

- Added bilingual `AIOutputContract.md` as the stable source for provider envelopes, draft schemas, validation/normalization, failure semantics, bounded correction, logging, versioning, evaluation, and user-confirmed write boundaries.
- Added bilingual `RAGDesign.md` as the stable source for same-chat context, Structured RAG, Document RAG, source-of-truth rules, permissions, ingestion, retrieval, evidence, downgrade behavior, and evaluation.
- Added `AI_OUTPUT_CONTRACT_ENGINEERING_PLAN.md` with staged contract, provider, error, correction, observability, canary, and rollback work.
- Added one canonical provider-facing schema/validator module shared by AI Chat and Add Food, plus a server-owned expected-output resolver and strict contract fixtures.
- Added the additive `ai_request_logs` output-observability migration for expected output, validator version, first/final validation status, bounded correction count, and provider completion category.

### Changed

- Reduced duplicate Output/RAG detail in AgentDesign, Algorithm, Database, AppGuide, Methodology, and the API contract draft, replacing it with responsibility-specific summaries and links to the new source documents.
- Added the new bilingual stable documents to the Document RAG ingestion allowlist and refreshed the generated seed.
- Clarified that the V1 implementation book and phase plans preserve implementation history while stable current design lives in the bilingual design tree.
- Switched OpenAI Chat to strict Responses API Structured Outputs and all Qwen Chat paths to non-thinking JSON Mode using the same versioned envelope.
- Replaced permissive provider prose/fence extraction and numeric coercion with exact types, unknown-field rejection, bounded strings/arrays, real-date checks, Food total normalization, and one in-deadline correction attempt without image retransmission.
- Separated provider refusal, incomplete generation, invalid provider output, and request-schema errors across Edge Functions, Flutter models, and bilingual user messages while preserving the older compatibility code.
- Expanded `AGENTS.md` with formal reader/question/ownership charters for every stable and planning document, plus a value-preserving refinement workflow that requires classifying, moving, and auditing useful content before deletion instead of creating another duplicated mega-document.
- Refactored the bilingual AppGuide, Product, AgentDesign, Database, CloudLocalDataBoundary, AIOutputContract, and RAGDesign sources from phase/status-led development notes into durable product, capability, storage, and engineering contracts. Preserved interaction rationale, failure states, compatibility rules, workflow detail, and code references while moving duplicate ownership to concise summaries and links.
- Reframed the legacy-named `API_CONTRACT_DRAFT.md` as the current Flutter-to-service wire contract and removed its completed Phase 0 checklist; phase plans and the V1 implementation book now explicitly defer to the stable bilingual documents and current API contract.
- Tightened Document RAG status inference so only status-bearing headings or explicit leading labels mark a section as planned/non-goal. Incidental words inside current design text no longer misclassify whole Home, provider-validation, ingestion, or evidence sections.

### Validation

- Confirmed the required bilingual documentation tree and new cross-document links.
- Regenerated `supabase/seed_phase5_document_chunks.sql` with 495 value-preserving, less-duplicated chunks from the updated stable-document allowlist using generator v3 status semantics.
- Checked stable documents for stale paths, replacement characters, duplicate ownership wording, and obvious English/Chinese heading drift.
- Ran Deno type checks for both Edge Function entry points and 46 deterministic Edge contract tests; all passed.
- `flutter analyze`: no issues.
- `flutter test`: all 200 tests passed.
- Built configured split debug APKs with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing all three ABI APKs under `build/app/outputs/flutter-apk`.
- SQLite schema and `AppDatabase.dbVersion` were unchanged; output observability is an additive Supabase migration.
- Applied and registered remote migrations `202607080001`, `202607090001`, `202607090002`, and `202607100001` on linked project `dyacqajcinjwrkbngeif`; the first three reconciled existing idempotent RAG objects and the last added six output-observability columns.
- Deployed `ai-chat-route` version 16 and `ai-food-photo-analyze` version 11, uploaded all 495 generator v3 document chunks across 19 source paths, and verified bilingual search-RPC results. Real-provider canary prompts remain a separate operational acceptance step.

## 2026-07-10 AI Chat Send Anchor Stability

### Fixed

- Positioned the message list at the existing conversation's real end before adding send-time active-turn fill, and removed the later blind jump to the filled maximum scroll extent. This prevents the pending user bubble from briefly moving above the top controls or disappearing before settling.
- Added frame-by-frame keyboard-open and keyboard-closed widget coverage that requires the pending bubble to remain at or below the readable boundary, settle on the next layout frame, and stay fixed afterward.

### Changed

- Tightened the settled pending-bubble clearance below the top controls from 16 px to 10 px while preserving hard clipping above the message viewport.
- Updated bilingual Product and AppGuide documents with the stable send-anchor and top-clearance behavior.

### Validation

- Ran `dart format lib/features/ai/ai_page.dart test/ai_page_test.dart`.
- Ran `flutter test test/ai_page_test.dart`; all 37 AI page tests passed, including frame-by-frame keyboard-open and keyboard-closed send anchoring.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test`; all 198 tests passed.
- Ran `git diff --check`; only existing LF/CRLF working-copy warnings were reported.
- Built the configured split debug APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing all three ABI APKs under `build/app/outputs/flutter-apk`.
- Ran `node tool/phase5_document_rag/build_document_chunks.mjs` and `node --check tool/phase5_document_rag/build_document_chunks.mjs`; regenerated 462 document chunks after the stable design-doc updates.
- Applied `supabase/seed_phase5_document_chunks.sql` to the linked Supabase project. No migration was required because this change did not alter the Document RAG schema or RPC.
- Verified the cloud corpus contains 462 chunks across 15 document paths and 2 languages; a Chinese send-anchor query retrieves the updated Product guidance.

## 2026-07-09 Phase 5 Structured RAG Acceptance Fix

### Fixed

- Added service-role grants for Phase 5 Structured RAG source tables and `ai_debug_summaries` updates, fixing the case where Document RAG worked but Cloud Profile, daily summary, and record-summary context silently appeared missing.
- Made `ai-chat-route` log Structured RAG table-fetch and debug-summary patch failures, and preserved both provider id and Phase 5 context tools in `called_tools_json`.
- Changed AI Chat evidence chips into an Answer basis panel that separates reference docs, used data, missing info, and limited actions, uses file-name source chips instead of full paths, and suppresses irrelevant missing-document chips for structured meal answers.
- Fixed Document RAG long-question retrieval by adding keyword-term overlap and title-phrase weighting to `search_document_chunks`, so natural app-logic questions no longer require exact full-sentence matches.

### Changed

- AI Chat now enforces the request language in provider prompts so English questions can receive English answers even when same-chat history or retrieved docs contain Chinese.
- Meal-decision prompts now make `gram_per_kg` macro gaps primary and kcal auxiliary, while `energy_ratio` keeps kcal remaining primary.
- The AI message viewport now starts below the top action row and hard-clips older messages there, while keeping only the bottom soft fade above the composer.

### Validation

- Ran `dart format lib/features/ai/ai_page.dart lib/core/localization/app_strings.dart test/ai_page_test.dart`.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test test/ai_page_test.dart`; all AI page tests passed.
- Ran `flutter test`; all tests passed.
- Ran `node tool\phase5_document_rag\build_document_chunks.mjs`; regenerated 462 document chunks.
- Ran `node --check tool\phase5_document_rag\build_document_chunks.mjs`.
- Deployed `ai-chat-route` with `supabase functions deploy ai-chat-route --project-ref dyacqajcinjwrkbngeif`.
- Applied `supabase/migrations/202607090001_phase5_structured_rag_service_role_grants.sql` with `supabase db query --linked --file ...`.
- Applied `supabase/migrations/202607090002_phase5_document_rag_query_terms.sql` with `supabase db query --linked --file ...`.
- Applied regenerated `supabase/seed_phase5_document_chunks.sql` with `supabase db query --linked --file ...`.
- Verified `document_chunks` contains 462 rows across 15 document paths and 2 languages; English long-question retrieval returns `docs/en/Algorithm.md` / `carb_tapering` and `docs/en/Methodology.md` / `Carb Tapering`; Chinese `gram_per_kg` retrieval returns `docs/zh/Algorithm.md`.
- Attempted `flutter clean`; the command shell stalled without a live Flutter/Dart child process in this environment, so generated build directories were removed with a path-guarded workspace cleanup before rebuilding.
- Built the configured split debug APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing `build/app/outputs/flutter-apk/app-armeabi-v7a-debug.apk`, `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`, and `build/app/outputs/flutter-apk/app-x86_64-debug.apk`.
- Could not run Edge Function Deno tests because `deno` is not installed in this environment.

## 2026-07-09 Phase 5 RAG Engineering Landing

### Changed

- Implemented the Phase 5 Document RAG ingestion upgrade with canonical Node seed generation, Markdown heading paths, recursive splitting, preserved short sections, deterministic context prefixes, chunk position metadata, and managed-corpus cleanup before reseeding.
- Extended `document_chunks`, `search_document_chunks`, document retrieval, prompt context, and evidence payloads to carry contextual chunk metadata instead of only bare excerpts; the migration recreates the RPC so deployed old return schemas can upgrade cleanly.
- Updated bilingual AgentDesign, Database, and the Phase 5 engineering plan to describe the implemented ingestion design, deployment boundary, verification SQL, and single seed-generation entry point.

### Validation

- Ran `node tool\phase5_document_rag\build_document_chunks.mjs`; regenerated 463 document chunks.
- Ran `node --check tool\phase5_document_rag\build_document_chunks.mjs`.
- Ran `dart format lib test`; no files changed.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test`; all tests passed.
- Built the configured split debug APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing `build/app/outputs/flutter-apk/app-armeabi-v7a-debug.apk`, `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`, and `build/app/outputs/flutter-apk/app-x86_64-debug.apk`.
- Could not run `deno fmt` or Edge Function Deno tests because `deno` is not installed in this environment.

## 2026-07-09 Documentation Structure And RAG Ingestion Design

### Changed

- Rewrote README as a product-led project entry that explains FitLog_Agent's problem, purpose, capabilities, boundaries, setup, and design-doc map instead of leading with implementation status history.
- Updated AgentDesign and Database docs to distinguish implemented Document RAG behavior from the next ingestion refinement boundary: heading-aware structure, recursive splitting, short-rule preservation, and reviewed contextual metadata.
- Documented the maintenance rule for applying regenerated document seed SQL after stable README/docs changes.
- Added narrow AI/RAG reference entries for document chunking patterns and contextual retrieval guidance.
- Tightened AGENTS.md documentation rules for README purpose, changelog scope, stable-doc structure, and phase-plan separation.
- Renamed status-led AppGuide, Database, and CloudLocalDataBoundary sections to capability, boundary, responsibility, and regression-coverage sections.

### Validation

- Ran `node tool\phase5_document_rag\build_document_chunks.mjs`; regenerated 433 document chunks after the README/docs cleanup.
- Confirmed the required README, changelog, and bilingual design documentation tree exists.
- Ran documentation text searches for replacement characters, date-style stable-doc headings, root-level design-doc links, stale paths, and chunking terminology.
- Ran `git diff --check`; only existing LF/CRLF line-ending warnings were reported.

## 2026-07-08 Phase 5 Controlled RAG Workflows

### Added

- Added the Phase 5 Document RAG schema, `search_document_chunks` RPC, document-chunk seed generation tooling, and generated Supabase seed SQL for FitLog app/design documents.
- Added `ai-chat-route` workflow routing, server-built Structured RAG context, Document RAG retrieval, read-only safety blocking, Phase 5 prompt context, evidence snapshots, and compact debug-summary context patching.
- Added Flutter Gateway evidence models and AI Chat evidence rendering for retrieved document sources, context dimensions, missing dimensions, and safety flags.

### Changed

- Gated user record-summary context behind the existing per-account user-record summary permission; when disabled, Phase 5 omits record-summary table reads and reports the dimensions as missing evidence.
- Updated OpenAI/Qwen provider prompts to use only server-provided Phase 5 controlled context, current user input, and current request images, while preserving user-confirmed Food Draft and Workout Draft boundaries.
- Updated README and bilingual Product, AppGuide, AgentDesign, and Database docs for the implemented Phase 5 read-only RAG and evidence boundary.

### Validation

- Ran `node tool\phase5_document_rag\build_document_chunks.mjs`; generated 447 document chunks.
- Ran `dart format lib test tool`.
- Ran documentation tree, stale Phase 5/RAG wording, replacement-character, date-heading, stale-path, and `git diff --check` searches; only existing Git line-ending warnings were reported.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test`; all tests passed.
- Built the configured split debug APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing `build/app/outputs/flutter-apk/app-armeabi-v7a-debug.apk`, `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`, and `build/app/outputs/flutter-apk/app-x86_64-debug.apk`.
- Could not run `deno fmt` or `deno test supabase\functions\ai-chat-route\index_test.ts` because `deno` is not installed in this environment.

## 2026-07-08 Bottom Navigation Keyboard Stability

### Fixed

- Kept the floating bottom navigation pill on stable bottom `viewPadding` during keyboard open/close transitions, preventing the nav from dipping down and bouncing back while the AI composer follows the keyboard.
- Added root navigation widget coverage for the Android-style keyboard state where `padding.bottom` drops to zero while `viewPadding.bottom` still contains the system gesture safe area.
- Updated bilingual Product, AppGuide, and AgentDesign docs to record that the root bottom navigation stays fixed during keyboard inset animation.

### Validation

- Ran `dart format lib\core\widgets\fitlog_bottom_nav_bar.dart test\root_navigation_test.dart`.
- Ran `flutter test test\root_navigation_test.dart`; all root navigation tests passed.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test`; all tests passed.
- Built the configured split debug APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing `build/app/outputs/flutter-apk/app-armeabi-v7a-debug.apk`, `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`, and `build/app/outputs/flutter-apk/app-x86_64-debug.apk`.

## 2026-07-08 AI Chat Composer Motion Clamp

### Fixed

- Clamped the AI Chat composer bottom offset to the larger of the keyboard inset and the closed navigation-resting clearance, preventing the composer from following a closing keyboard to the physical screen bottom before bouncing back above the navigation pill.
- Kept the message viewport and composer on the same keyboard-attached geometry so the final chat bubble remains clear in open, closed, and intermediate keyboard states.
- Added a widget regression test for keyboard open, partial-close, and fully closed insets.
- Updated bilingual Product, AppGuide, and AgentDesign docs to record the composer motion range.

### Validation

- Ran `dart format lib\features\ai\ai_page.dart test\ai_page_test.dart`.
- Ran `flutter test test\ai_page_test.dart`; all AI page tests passed.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test`; all tests passed.
- Built the configured split debug APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing `build/app/outputs/flutter-apk/app-armeabi-v7a-debug.apk`, `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`, and `build/app/outputs/flutter-apk/app-x86_64-debug.apk`.

## 2026-07-08 AI Chat Bare Image Media

### Changed

- Changed mixed image-plus-text user turns so image attachments render as bare rounded right-aligned media above the text bubble instead of being wrapped in a green user bubble, while still staying one Gateway request, pending lifecycle, retry unit, and cloud-history turn.
- Cached decoded message thumbnail bytes in widget state, added stable thumbnail state keys, and enabled gapless image playback so keyboard inset rebuilds do not briefly expose a theme-colored placeholder before the image redraws.
- Updated bilingual Product, AppGuide, and AgentDesign docs to record the bare media layout and keyboard-stable image thumbnail boundary.

### Validation

- Ran `dart format lib\features\ai\ai_page.dart test\ai_page_test.dart`.
- Ran `flutter test test\ai_page_test.dart`; all AI page tests passed.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test`; all tests passed.
- Built the configured split debug APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing `build/app/outputs/flutter-apk/app-armeabi-v7a-debug.apk`, `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`, and `build/app/outputs/flutter-apk/app-x86_64-debug.apk`.

## 2026-07-08 AI Chat Conservative Progress Labels

### Changed

- Changed the AI Chat assistant loading bubble from a generic thinking label to conservative client-side progress labels driven only by request type and elapsed time.
- Added text/image waiting states for sending, normal wait, longer image wait, continued server wait, and slow network/model response without exposing model chain-of-thought or claiming unverified image, nutrition, RAG, or context milestones.
- Updated bilingual Product, AppGuide, and AgentDesign docs for the current Phase 4 client-only progress boundary, and updated the roadmap so future Phase 5-7 work requires progress claims to match Gateway/RAG/context evidence.

### Validation

- Ran `dart format lib\features\ai\ai_page.dart lib\core\localization\app_strings.dart test\ai_page_test.dart`.
- Ran `flutter test test\ai_page_test.dart`; all AI page tests passed.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test`; all tests passed.
- Built the configured split debug APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing `build/app/outputs/flutter-apk/app-armeabi-v7a-debug.apk`, `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`, and `build/app/outputs/flutter-apk/app-x86_64-debug.apk`.

## 2026-07-08 AI Chat Mixed Attachment Layout

### Changed

- Changed AI Chat user-turn rendering so a message that includes both image attachments and text displays as separate adjacent media and text surfaces while staying one Gateway request, pending lifecycle, retry unit, and cloud-history turn.
- Refined the floating AI composer with a subtle hairline border and layered low-opacity shadow so it reads as a floating input surface over the animated AI background without becoming a heavy card.
- Updated bilingual Product, AppGuide, and AgentDesign docs to record the mixed attachment/text bubble layout and composer surface boundary.

### Validation

- Ran `dart format lib\features\ai\ai_page.dart test\ai_page_test.dart`.
- Ran `flutter test test\ai_page_test.dart`; all AI page tests passed.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test`; all tests passed.
- Built the configured split debug APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing `build/app/outputs/flutter-apk/app-armeabi-v7a-debug.apk`, `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`, and `build/app/outputs/flutter-apk/app-x86_64-debug.apk`.

## 2026-07-05 Phase 5-7 Roadmap And Evaluation Lab Plan

### Changed

- Reworked the remaining Agent V1 roadmap so Phase 5 focuses on RAG and read-only AI workflows, Phase 6 becomes a dedicated Reliability Evaluation Lab, and Phase 7 becomes evidence-driven release hardening.
- Expanded the Phase 6 evaluation design around FitLog-owned system reliability rather than generic model intelligence, covering eval case schema, RAG retrieval checks, structured-context checks, answer faithfulness, safety red-team cases, draft-confirmation regression, thresholds, and report requirements.
- Updated the cross-phase test matrix and final V1 completion criteria to require reliable eval evidence before release hardening and V1 completion.

### Validation

- Documentation-only change; Flutter analysis and tests were not run.
- Confirmed the required documentation tree exists and searched the roadmap for stale old Phase 6 Food Vision stage wording after the update.

## 2026-07-05 AI Chat Camera Visual Recovery

### Changed

- Changed AI Chat image-picker recovery to preserve the ready colorful AI background when Android camera/system picker recreates the activity after the user entered from a ready AI page.
- Kept send availability tied to real AccountController, subscription, Cloud Profile, active-device, and Gateway readiness; recovered content is not queued or auto-sent while state is restoring, and the send control may remain disabled/gray.
- Updated bilingual AgentDesign, AppGuide, and Database docs to record the Android camera lifecycle recovery boundary and the difference between visual continuity and send permission.

### Fixed

- Fixed the brief disabled gray AI background flash after confirming a camera photo during AI Chat attachment recovery.

### Validation

- Ran `dart format` on changed Dart files with SDK telemetry redirected to the repo-local `.dart_tool` appdata path.
- Ran `flutter clean`.
- Ran `flutter pub get`.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test test\ai_page_test.dart`; all AI Chat tests passed, including ready-background recovery with disabled send.
- Ran `flutter test`; all tests passed.
- Built the configured split debug APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing `build/app/outputs/flutter-apk/app-armeabi-v7a-debug.apk`, `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`, and `build/app/outputs/flutter-apk/app-x86_64-debug.apk`. Gradle reported the existing Kotlin daemon incremental-cache issue for Android plugins, then continued and produced the APKs successfully.
- No Supabase Edge Function deploy was required for this client-only AI Chat recovery change.

## 2026-07-05 AI Chat Camera Recovery And Food Draft Totals

### Added

- Added AI Chat image-picker recovery so Android activity restarts after camera/gallery selection can restore composer text, selected provider, and recovered image attachments instead of returning the user to Home.
- Added regression coverage for AI Chat image recovery and Food Draft total normalization from item sums.

### Changed

- Changed Food Draft parsing, Gateway validation, Food Preview save behavior, and provider prompts so meal-level weight, calories, protein, carbs, and fat are derived from item totals whenever `items` is non-empty.
- Updated README, API contract draft, and bilingual Product/AppGuide/AgentDesign/Database docs to document AI Chat image recovery and item-sum Food Draft totals.

### Fixed

- Fixed mismatched AI food-analysis totals where the meal total could diverge from the sum of visible item rows.
- Fixed AI Chat camera attachment loss after Android picker activity recreation by sharing the existing lost-image recovery path with Chat attachments.

### Validation

- Ran `dart format` on changed Dart files; the SDK telemetry write was redirected to the repo-local `.dart_tool` appdata path after the default user-profile telemetry path was sandbox-blocked.
- Ran `flutter clean`.
- Ran `flutter pub get`.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test test/ai_gateway_contract_test.dart`; all tests passed.
- Ran `flutter test`; all tests passed.
- Built the configured split debug APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing `build/app/outputs/flutter-apk/app-armeabi-v7a-debug.apk`, `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`, and `build/app/outputs/flutter-apk/app-x86_64-debug.apk`. Gradle reported the existing Kotlin daemon incremental-cache issue for Android plugins, then continued and produced the APKs successfully.
- Deno formatting/tests could not be run because `deno` is not installed in this environment.
- Supabase Edge Function deployment could not be run because the Supabase CLI is not installed and no `SUPABASE_ACCESS_TOKEN` or cached Supabase login is available; target project ref detected from local config is `dyacqajcinjwrkbngeif`.

## 2026-07-03 Keyboard Animation Performance

### Changed

- Changed AI Chat keyboard handling so `viewInsets` changes rebuild only the keyboard-responsive composer/message layer, while the animated liquid background stays outside that keyboard layout path.
- Paused AI Chat background animation only while Android keyboard metrics are actively transitioning, then resumed the existing landing/chat background motion after the keyboard settles.
- Changed Profile keyboard reveal for auth and inline body fields to use a single focus-aware reveal path: keyboard inset is owned by a small scroll spacer, TextField scroll padding is no longer inset-amplified, and focused fields scroll only by the amount needed to clear the keyboard.

### Fixed

- Fixed Profile body-field keyboard reveal overshooting and settling back by replacing forced `ensureVisible` alignment with screen-coordinate overlap correction.

### Validation

- Added widget coverage for Profile body-field reveal staying above the keyboard.
- Ran `flutter test test\ai_page_test.dart`; all AI Chat keyboard, background, and composer tests passed.
- Ran `flutter test test\phase2_account_controller_test.dart`; all Profile and account tests passed.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test`; all tests passed.
- Built the configured split debug APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing armeabi-v7a, arm64-v8a, and x86_64 debug APKs.

## 2026-07-03 Android Workout Draft Progress Notification

### Added

- Added an Android workout-in-progress system notification for active unsaved workout editor drafts with any selected exercise. The notification mirrors local draft state, shows the current exercise, next incomplete set when one exists, a short return-to-continue prompt when no set is available yet, and the matching exercise/body-part image, and opens the existing active draft editor when tapped.
- Added Android 13+ notification permission requesting for the workout draft notification; denying the permission leaves workout draft editing unchanged.
- Added draft-only `completed_at` timestamps to workout draft set payloads so notification focus can follow the most recently checked set without changing the official SQLite workout-set schema.
- Added focus and sync tests covering first-set focus, same-exercise next-set focus, multi-exercise recent-completion focus, fallback after an exercise is complete, unchecking, weight/reps edits, deleted current exercise fallback, complete state, save/discard cancellation, and duplicate-open prevention.

### Changed

- Updated Product, AppGuide, and Database docs in English and Chinese to describe the local-draft notification boundary, Android small-icon limitation, right-side exercise image rule, focus rules, tap-to-resume behavior, and draft-only completion timestamp.
- Changed workout draft persistence during editing so any meaningful editor content is saved as the active draft, allowing the notification tap to recover the same editor state even when the user has just selected an exercise.

### Fixed

- Fixed Android light-theme system status bars in the Agent app so status bar time and icons use dark foregrounds over FitLog's light page background, including when Android selects night resources.
- Fixed the workout draft notification's right-side image so it uses the current exercise/body-part PNG asset instead of the app icon; chest press variants without dedicated PNG assets fall back to the chest body-part image instead of borrowing the barbell flat bench press image.
- Removed the duplicate generic Bench Press entry from the built-in exercise library so users choose Barbell Flat Bench Press for that movement.

### Validation

- Ran `dart format lib test`.
- Confirmed the required documentation tree exists and searched stable docs for date-appended headings, stale local design-doc paths, and replacement characters.
- Ran `git diff --check`; only existing Windows line-ending warnings were reported.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test test\workout_draft_notification_test.dart`; all notification focus, sync, and tap-coordinator tests passed.
- Ran `flutter test`; all tests passed.
- Built the configured split debug APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing armeabi-v7a, arm64-v8a, and x86_64 debug APKs.

## 2026-07-03 AI Background Smoothing, Composer Bounds, And Chat Draft Contract

### Changed

- Changed pending AI Chat user bubbles to use the same green surface as persisted user bubbles so sending state no longer looks faded or disabled.
- Smoothed the AI page liquid background by protecting the mint transition width and modestly increasing field sampling, reducing blocky bands when the pink and blue fields compress toward the center without adding real-time noise.
- Changed the AI chat message viewport to use separate readable and floating-overlay bounds, keeping messages clear of the input while allowing keyboard-open content to continue behind the composer.
- Changed the AI chat message layer into a near-full-screen scroll layer with asymmetric soft alpha edges, avoiding rectangular-looking card cutoffs near the top controls and composer.
- Tuned the AI chat scroll-layer soft edges to be asymmetric, with a longer top fade for hierarchy behind controls and a shorter bottom fade so final bubbles remain clean.
- Fixed send-time anchoring so the pending user bubble aligns to the readable top boundary in both keyboard-open and keyboard-closed states instead of landing inside the top fade-out region.
- Changed the keyboard-open AI composer into a solid input-accessory position attached to the keyboard top, removing the extra keyboard-above footer band and lower-half veil while preserving the floating pill when the keyboard is closed.
- Changed keyboard-open message spacing so the viewport extends to the composer bottom / keyboard top with no exterior composer background, while the final bubble still gets its safety distance from the message list's own bottom padding.
- Changed AI Chat interaction accents to read the active FitLog theme, so Black Orange uses orange user bubbles, send/review buttons, draft-card accents, Markdown accents, and selected history rows while the AI liquid background keeps its independent pink/mint/blue identity.
- Refined the Black Orange AI Chat palette so user bubbles use a softer bright orange, draft review buttons keep the stronger action orange, draft-card surfaces use a warm low-glare orange system, and the ready indicator returns to semantic green for availability.
- Changed Qwen text Chat draft prompting so user-friendly explanation belongs in `message.text` and structured Food Draft / Workout Draft data belongs in `draft`, while Add Food AI food analysis remains on its dedicated pure-JSON contract.
- Hardened AI Gateway provider parsing to prefer Gateway-shaped JSON objects, preventing incidental provider prose objects from hiding a later valid draft payload.
- Updated README, Product, AppGuide, AgentDesign, and API contract docs to describe the smoothed background sampling, soft-edge message scroll layer, floating-composer scroll geometry, keyboard accessory composer mode, theme-aware AI Chat accents with semantic readiness green, and stable Chat draft envelope.

### Validation

- Ran `dart format lib test`; formatter reported 0 changed files on the final pass.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test test\ai_page_test.dart`; all AI page tests passed, including pending user-bubble green, Black Orange warm orange bubbles and draft action, semantic green readiness, keyboard-open solid floating-composer overlay, readable-top send anchoring, soft-edge message layer, and final-bubble safe-padding coverage.
- Ran `flutter test`; all tests passed.
- Added Edge Function contract regression tests for friendly prose plus Food Draft JSON and Gateway-shaped JSON preference; local Deno CLI was unavailable in this environment, so these tests were not executed here.
- Ran `git diff --check`; no whitespace errors were reported.
- Confirmed the required README, changelog, and English/Chinese design documentation tree exists.
- Built the configured split debug APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing armeabi-v7a, arm64-v8a, and x86_64 debug APKs.

## 2026-07-02 AI Background Fluid Gradient

### Changed

- Changed the AI page background from whole-layer translation plus a fixed wash path to a full-screen programmatic liquid-gradient color field with a stronger pink field from the top, a smaller mint center band that wraps the center status text, and an earlier blue transition so visible pink and blue areas feel more balanced on portrait phones.
- Changed the background animation to use seamless whole-field warped color sampling instead of localized moving blobs, with a faster landing loop, a quieter 9-second chat/history loop after the first message is sent, and pre-conversation keyboard input kept on the visible landing motion.
- Removed per-message copy buttons from AI Chat bubbles; message text remains selectable and copying uses the system text-selection menu.
- Updated README, Product, AppGuide, and AgentDesign docs in English and Chinese to describe the AI page background as a continuous liquid-gradient color field rather than a translated static image or localized moving blob layer.

### Validation

- Ran `dart format lib test`; formatter reported 0 changed files on the final pass.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test`; all tests passed.
- Built the configured split debug APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing armeabi-v7a, arm64-v8a, and x86_64 debug APKs.

## 2026-07-02 Startup Cache And AI Food Analysis Recovery

### Added

- Added Add Food AI Food Analysis support for text-only food descriptions while keeping up to three optional camera/gallery images and the existing Food Preview confirmation boundary.
- Added a small local picker-recovery marker and lost-data recovery path so Android camera/gallery activity restarts can reopen the AI food analysis draft instead of dropping the user back to Home.

### Changed

- Changed signed-in startup hydration so Home, Food, and Workout bind local record repositories to the recovered auth-session account before active-device runtime refresh, allowing current-day local cache reads to render without a manual date switch.
- Changed the `ai-food-photo-analyze` contract, Qwen prompt, request logging, and debug metadata to support text-only requests with `image_count = 0` while still avoiding raw image/base64/full-note retention.

### Validation

- Ran `dart format lib test`; formatter reported 0 changed files on the final pass.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test test\photo_food_analysis_page_test.dart test\add_food_page_test.dart test\ai_gateway_contract_test.dart`; targeted AI food analysis tests passed.
- Ran `flutter test`; all tests passed.
- Built the configured split debug APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing armeabi-v7a, arm64-v8a, and x86_64 debug APKs.
- Deployed the updated `ai-food-photo-analyze` Supabase Edge Function to project `dyacqajcinjwrkbngeif` so text-only requests reach the new server contract.
- Local Supabase Edge Function Deno tests could not run because `deno` is not installed on this machine.

## 2026-07-02 AI Chat Markdown And Copy

### Added

- Added selectable AI Chat message text and per-message copy actions so users can copy original user or assistant message content from the chat surface.

### Changed

- Changed assistant message rendering from the local hand-written Markdown parser to the maintained `flutter_markdown_plus` renderer, preserving app styling while supporting GitHub-flavored headings such as `####` without per-marker patches.
- Kept the AI Chat Markdown boundary constrained by blocking remote Markdown image rendering and link actions.

### Validation

- Ran `dart format lib test`; formatter reported 0 changed files on the final pass.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test test\ai_page_test.dart`; all AI page tests passed.
- Ran `flutter test`; all tests passed.
- Built the configured split debug APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing armeabi-v7a, arm64-v8a, and x86_64 debug APKs.

## 2026-07-02 AI Photo Preview And Status Copy Polish

### Changed

- Changed Add Food Photo AI Analysis controls to use shorter Photo/Gallery labels, keep the camera action as an add-photo action instead of a retake state, let thumbnail taps switch the enlarged preview, and remove the duplicate bottom clear button in favor of per-thumbnail removal.
- Changed AI Chat artifact review buttons so Food Draft and Workout Draft cards share the compact `Review and confirm` action wording.
- Changed the AI top readiness pill to use compact `Ready`/`Off` English labels while preserving detailed gate reasons in status sheets and errors.
- Fixed Photo AI Analysis error handling so service-side schema/provider failures return structured gateway errors instead of being mislabeled as network failures, and made the Food Draft parser tolerate common JSON wrappers and non-critical confidence formatting.

### Validation

- Ran `dart format lib test`; formatter reported 0 changed files on the final pass.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test`; all tests passed.
- Built the configured split debug APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing armeabi-v7a, arm64-v8a, and x86_64 debug APKs.

## 2026-07-02 Workout Draft Clarification And Photo Multi-Image

### Changed

- Changed Qwen workout draft prompting to allow at most one clarification turn; if the user reply is still incomplete, AI Chat should return an editable `workout_draft.v1` with missing values left null and uncertainties in notes.
- Changed AI Gateway provider parsing to recover schema-validated Food Draft or Workout Draft JSON from provider prose or fenced JSON, preventing raw draft JSON from leaking as ordinary assistant text.
- Changed Add Food Photo AI Analysis to accept one to three compressed JPEG/PNG/WebP images in the dedicated `ai-food-photo-analyze` workflow, matching the AI Chat three-image boundary while still returning only a Food Draft.

### Validation

- Ran `dart format lib test`; formatter updated Dart formatting in `app_strings.dart`, `photo_food_analysis_page.dart`, and `photo_food_analysis_page_test.dart`.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test`; all tests passed.
- Built the configured split debug APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing armeabi-v7a, arm64-v8a, and x86_64 debug APKs.
- Local Supabase Edge Function tests could not run because `deno` is not installed on this machine.

## 2026-07-02 AI Chat Draft Context And Workout Draft Artifacts

### Added

- Added AI Chat Workout Draft artifacts that show a summary card, rebuild the existing workout editor draft only after the user taps review, ask before replacing an unsaved workout draft, and never write an official workout record until the editor save action.
- Added compact same-chat context for AI Chat requests, limited to recent text turns and Food Draft / Workout Draft artifact summaries so the provider can follow the current conversation without receiving raw images, base64 payloads, full business history, RAG context, or user API keys.
- Added a `workout_draft.v1` Gateway draft contract and Flutter domain mapper that converts validated AI workout draft payloads into the existing local workout editor draft format.

### Changed

- Changed AI Chat draft artifact handling so historical cards can keep their visible summary even when their stored snapshot can no longer safely rebuild an editor; unavailable review actions are shown disabled instead of silently removing the card.
- Updated README, API contract draft, roadmap, and bilingual Product/AppGuide/AgentDesign/Database docs to mark Food Draft and Workout Draft artifact cards, compact same-chat context, and the no-automatic-official-write boundary as current behavior.

### Validation

- Ran `dart format lib test`; formatter reported 0 changed files.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test`; all 160 tests passed.
- Built the configured debug split APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing armeabi-v7a, arm64-v8a, and x86_64 debug APKs.
- Local Deno tests for Supabase Edge Functions could not run because `deno` is not installed.

## 2026-07-01 Phase 4 Step 6 Multimodal Chat And AI Page Performance

### Added

- Added up-to-three-image AI Chat attachment support for Qwen multimodal requests, including camera/gallery selection, local image validation, request serialization, Gateway validation, Qwen `image_url` routing, and Food Draft response parsing.
- Added AI Chat Food Draft artifact cards that keep the assistant Markdown reply readable and open the existing Food Preview confirmation flow only after the user taps review; no official food record is written until the user saves.
- Added a Supabase `record_ai_chat_turn` RPC migration that persists validated Chat artifact snapshots in `ai_chat_messages.final_answer_json` and records accepted Chat image counts without storing image bytes or base64 payloads.

### Changed

- Changed the AI page background from full-screen per-frame repainting to a static painted layer animated by transform, keeping visible motion while reducing keyboard and chat interaction pressure.
- Changed chat send completion so pending/loading UI stays visible until cloud messages finish reloading, avoiding a temporary empty "listening" state before the answer appears.
- Changed conversation layout so the provider selector/status row moves to the top bar after chat content exists, while composer errors remain above the input area and empty-state errors appear above the provider/status row.
- Changed AI Chat image previews to show thumbnail-only attachments with per-image removal and no filename label, matching the Chat-style upload affordance; gallery selection can now add multiple images at once up to the remaining three-image limit.
- Changed Chat Food Draft handling so send completion no longer immediately navigates away from the AI page, avoiding the visible post-loading route flash and letting users reopen the draft from the assistant message.
- Changed AI Chat conversation geometry so the message list starts below the top history/account/provider controls, shares the measured composer obstruction with bottom navigation and safe-area spacing, and preserves more readable text space.
- Changed send-time scrolling so a newly sent user bubble anchors at the top of the readable chat area with the assistant loading bubble visible, while the final assistant reply does not force a second scroll.
- Changed send-time anchoring to use a bounded active-turn fill and lock user drag during provider waiting, so the pending user/loading pair stays visible without exposing a large scrollable blank area.
- Changed Add Food Photo AI Analysis errors to use the top notification layer and restyled the analyze action with the same floating pill plus lower shield geometry as the app navigation.
- Changed history inline rename to use the same typography and row footprint as the displayed title, with cancel handled by the row action instead of a suffix icon that narrows the text field.
- Updated README, API contract draft, roadmap, and bilingual Product/AppGuide/AgentDesign/Database docs for the AI Chat up-to-three-image Qwen boundary, artifact-snapshot draft confirmation rule, non-RAG scope, no long-term image storage, and chat-history persistence boundary.

### Fixed

- Fixed the AI page `+` attachment button still describing image attachment as unavailable after Qwen multimodal support.
- Fixed stale design text that described AI Chat as text-only or unable to inspect images.
- Fixed AI Chat image sends so the current runtime conversation shows the user's image thumbnail instead of text only, without storing raw images in cloud chat history.
- Fixed AI Chat network-failure feedback so it says the message was kept for retry and appears inside the composer layout instead of behind the attachment/input area.
- Fixed the max-image-limit notice so it uses the AI composer notice position instead of the global bottom notification, and fixed the top history/account actions so the provider/status row no longer pulls them away from the top corners.
- Fixed AI Chat manual scrolling so long assistant text cannot slide behind the composer, and fixed the quiet background painter so the whole page repaints as one continuous slow-moving layer instead of appearing active only in exposed top/bottom regions.
- Fixed AI Chat send-time fallback scrolling so it no longer jumps to a blank spacer page when the pending bubble has not been laid out yet.
- Fixed assistant Markdown rendering so `#`, `##`, and `###` headings render as headings instead of leaking raw hash markers into chat replies.
- Fixed Add Food photo-analysis network-failure copy so it says the current photo and note remain on the page, not that an app draft was saved.
- Fixed assistant/user message spacing so a new user turn has breathing room after the previous assistant reply while each user/assistant pair stays compact.

### Validation

- Ran `dart format lib test`; formatter reported 0 changed files on the final pass.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test`; all 156 tests passed.
- Built the configured debug split APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`, producing armeabi-v7a, arm64-v8a, and x86_64 debug APKs.
- Confirmed the required documentation tree exists, checked `git diff --check` for whitespace errors, and searched current stable docs/code for stale no-image, single-image Chat, saved-draft network copy, blank-spacer anchoring, raw Markdown-heading leakage, date-appended stable-doc headings, and replacement characters.
- Local Deno tests for Supabase Edge Functions could not run because `deno` is not installed. Supabase CLI is available as `2.108.0`, but Edge Function deploy and any remote SQL application were not performed from this environment.

## 2026-07-01 Phase 4 Step 5 AI UX And Photo Food Analysis

### Added

- Added local AI provider persistence so the ChatGPT/Qwen selection survives app restart without cloud sync.
- Added inline cloud chat-session rename through the `rename_ai_chat_session` RPC, plus delete confirmation in the history UI while hiding the archive entry.
- Added Add Food Photo AI Analysis as the first food-entry path, with camera/gallery selection, optional user note, loading overlay, a Qwen multimodal `ai-food-photo-analyze` Gateway client/function contract, and Food Draft conversion into the existing Food Preview confirmation flow.
- Added `ai_photo` as the confirmed-source marker for records that started from photo analysis and were saved by the user.

### Changed

- Changed the AI status pill to show readiness only; request activity now appears in the send-button spinner and assistant loading bubble.
- Increased the AI background's quiet-state visible motion and marked the painter as changing so the page no longer appears frozen during keyboard input, waiting, or reading.
- Changed Add Food so external AI JSON paste is a fallback and prompt-copy is no longer the primary food-entry flow.
- Updated README, API contract draft, roadmap, and bilingual Product/AppGuide/AgentDesign/Database docs for the implemented photo draft path, server-managed provider-key boundary, compact logging rules, and hidden chat archive UI.

### Fixed

- Fixed chat history deletion so it cannot soft-delete a session without user confirmation.
- Fixed the provider selector returning to the default option after app restart.
- Fixed stale docs that still described Add Food photo analysis as a placeholder or the active photo transport as Supabase Storage retention.

### Validation

- Ran `dart format lib test`; formatter reported 0 changed files.
- Ran `flutter analyze`; no issues found.
- Ran `flutter test`; all 145 tests passed.
- Built the configured debug split APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`; Gradle reported a Kotlin daemon incremental-cache fallback for `image_picker_android`, then successfully produced armeabi-v7a, arm64-v8a, and x86_64 debug APKs.
- Confirmed the required documentation tree exists and searched current docs for stale photo-placeholder, prompt-copy, Storage-retention, replacement-character, and date-appended stable-doc wording; remaining placeholder/no-image hits are historical roadmap/changelog phase notes.
- Local Deno tests for Supabase Edge Functions could not run because `deno` is not installed. Supabase CLI is available as `2.108.0`, but the SQL migration and Edge Function deploy were not applied to a remote project from this environment.

## 2026-06-30 Phase 4 Steps 3 And 4 AI Chat Send And Providers

### Added

- Added the app-side AI chat send path with a Gateway client, cloud chat repository, runtime chat controller, pending-message state, cloud history loading, session switching, new chat, archive, soft delete, and stable error mapping.
- Added the Step 3/4 Supabase migration for `record_ai_chat_turn`, `archive_ai_chat_session`, and `soft_delete_ai_chat_session`, keeping direct authenticated table writes closed while enabling service-owned text turn persistence.
- Added server-side OpenAI/ChatGPT and Qwen text provider adapters for `ai-chat-route`, with provider API keys and exact model names kept in Edge Function environment configuration.

### Changed

- Changed AI availability so subscribed active-device users can send only when the configured backend Gateway is present, while text chat remains outside RAG, image recognition, Food Draft writeback, and official business-record writes.
- Changed Qwen provider calls to explicitly disable thinking output for the product chat path.
- Changed the AI background motion into two readability-oriented profiles: visible colorful flow on the empty landing state, and extremely slow low-amplitude flow while typing, waiting, or reading chat messages.
- Changed the AI status pill to use semantic state indicators for available, waiting, gated, and unavailable states.
- Changed chat sending to clear the composer immediately, show a pending user bubble, show an assistant loading bubble while waiting, and restore the draft if the send fails.
- Added scoped assistant-message Markdown rendering for paragraphs, bold text, ordered/unordered lists, inline code, and code blocks while keeping user messages plain text.
- Updated README, roadmap, API contract draft, and bilingual Product/AppGuide/AgentDesign/Database docs to mark text sending, real provider routing, and cloud chat history as implemented while preserving the remaining Agent V1 boundaries; synchronized bilingual AppGuide/AgentDesign with the current chat UI behavior.

### Fixed

- Fixed AI page send taps that could fail in debug because the button callback listened to localization through Provider outside a build, and made account/device preflight failures show a local AI error instead of silently doing nothing.
- Fixed the AI animated background so it continuously repeats while the AI page is mounted, including while the keyboard is visible, without using fast processing motion during reading or waiting states.

### Validation

- Ran targeted AI chat controller/page tests, including keyboard-visible animation progression, quiet reading motion, status indicator, optimistic composer clearing, assistant loading, failure draft restore, and assistant Markdown coverage; then ran `flutter analyze` and `flutter test`.
- Built the configured debug split APK with `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`.
- Uploaded the Qwen provider Edge Function secrets, deployed `ai-chat-route`, confirmed unauthenticated function requests return the stable `auth_required` contract, and confirmed the configured Qwen `qwen3.7-plus` endpoint answers directly.
- Confirmed the required documentation tree and searched stable docs for replacement characters, date-appended headings, stale root design-doc paths, and stale Step 2 current-state wording.
- Local Deno formatting/tests for the Edge Function could not run because `deno` is not installed in this environment.

## 2026-06-29 Phase 4 Step 2 Mock Gateway Skeleton

### Added
- Added the Supabase `ai-chat-route` Edge Function skeleton with stable Step 1-compatible response envelopes, server-side auth verification, subscription enforcement, active-device checks, deterministic mock provider replies, and sanitized error mapping.
- Added `record_ai_mock_chat_turn` to persist accepted mock turns atomically, creating or reusing chat sessions, assigning deterministic user/assistant message sequences, and writing request logs plus compact debug summaries without opening direct client writes.
- Added a follow-up service-role grant migration so the deployed Gateway can read subscription entitlement, write sanitized request/debug logs, and support service-side acceptance checks without opening direct client writes.
- Added a narrow service-role subscription write grant so server-side entitlement setup and maintenance can upsert acceptance subscriptions without opening authenticated client writes.
- Added function-level Supabase config so unauthenticated requests can reach the function and return the stable `auth_required` Gateway contract instead of a platform-shaped error.
- Added Deno-side helper tests for request parsing, future-scope rejection, JWT session-claim extraction, response envelopes, and mock provider failure simulation.

### Changed
- Updated README, roadmap, API contract draft, and bilingual Product/AppGuide/AgentDesign/Database docs to mark the server-side mock Gateway as implemented while keeping AI-page sending, real providers, UI cloud history, RAG, and Food Draft writeback as later work.

### Validation
- Ran `dart format lib test`, `flutter analyze`, and `flutter test`; all completed successfully.
- Ran deployed Supabase Edge Function acceptance against the linked dev project: verified `401/auth_required`, `403/subscription_required`, `409/device_replaced`, active subscribed mock replies, session reuse with message sequences `1..4`, service-role request/debug records, future-field rejection, cross-account session rejection, and authenticated-client denial on logs/debug tables.
- Deno helper tests could not run locally because `deno` is not installed in this environment; the deployed-function acceptance covered the live server path.

## 2026-06-29 Phase 4 Step 1 AI Chat Foundation

### Added

- Added the Supabase Phase 4 Step 1 AI chat foundation migration with `ai_chat_sessions`, `ai_chat_messages`, `ai_request_logs`, and `ai_debug_summaries`, including account-bound constraints, deterministic message ordering, RLS-protected chat reads, and server-only log/debug table access.
- Added Flutter domain contract models for AI chat sessions/messages, Gateway request/response payloads, and stable Gateway error mapping without wiring AI message sending.
- Added contract tests for text-only Gateway payloads, assistant responses, clarification handling, unsupported draft boundaries, message ordering, and stable/unknown error codes.

### Changed

- Updated README and bilingual Product/AppGuide/AgentDesign/Database docs to mark the Phase 4 Step 1 data/contract foundation as implemented while keeping AI Gateway, provider calls, UI chat-history persistence, RAG, and Food Draft writeback as later work.
- Closed Phase 4 Step 1 after manual Supabase acceptance confirmed table creation, RLS, own-account chat reads, server-only log/debug access, cross-account message rejection, deterministic ordering, and soft-delete visibility.

### Validation

- Ran `dart format lib test`.
- Ran targeted `flutter test test\ai_gateway_contract_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Manually applied and accepted `202606290001_phase4_ai_chat_foundation.sql` in Supabase SQL Editor: verified the four AI tables exist, RLS is enabled on all four, only session/message tables expose authenticated `SELECT`, logs/debug tables reject authenticated reads, cross-account session/message binding fails, no sensitive log/debug columns are present, and soft-deleted sessions/messages are hidden from client reads.

## 2026-06-29 Current-State Wording Cleanup

### Changed

- Updated user-facing AI and account copy to avoid stale Phase 1/Phase 2 wording and to describe record-summary permission as future use of necessary cloud summaries, not local SQLite history upload.
- Updated README and bilingual Product/AppGuide/AgentDesign docs so current-state sections describe the implemented Agent shell/account/Cloud Records baseline without removing historical phase records from the roadmap or changelog.

### Validation

- Ran `dart format lib\core\localization\app_strings.dart`.
- Confirmed the required documentation tree exists and searched updated docs/code for stale Phase 1/Phase 2 user-facing wording, replacement characters, date-appended stable-doc headings, and stale phase-plan paths.
- Ran `git diff --check` with only line-ending warnings.
- Ran `flutter analyze`.
- Ran `flutter test`.

## 2026-06-28 Phase 3 Acceptance Closure

### Changed

- Renamed the AI availability ready-but-unsendable state from Phase 3 wording to Gateway pending wording, keeping the composer editable while send remains disabled until the AI Gateway exists.
- Updated the AI account sheet copy so it no longer says message sending starts in Phase 3.
- Closed Phase 3 documentation drift by marking daily summary cloud upsert/cache hardening as implemented and by keeping Phase 4 test scope aligned with the no-RAG Gateway/Chat History phase boundary.

### Validation

- Ran `dart format lib\domain\models\ai_availability.dart lib\features\account\account_controller.dart lib\features\ai\ai_page.dart lib\core\localization\app_strings.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.

## 2026-06-28 Body Metric Calendar Today And Delete

### Added

- Added a confirmed delete action for existing past body metric records from the Body Profile historical edit state.
- Added widget coverage for the body metric calendar defaulting to today and for deleting an existing past body metric record without saving Cloud Profile or refilling the deleted date from current Profile values.

### Changed

- Changed the Body Profile calendar to open on today and allow selecting today as the way back to the current body profile view; only past dates enter historical edit mode and show a date badge.
- Changed the historical body metric delete confirmation to use a red destructive action instead of a green filled confirmation button.
- Changed past body metric dates without an existing record to open with empty weight, body-fat, and waist fields instead of copying current Profile values.
- Synchronized historical body metric deletion across cloud `body_metric_logs` and the local `user_weight_logs` cache mirror through existing `deleted_at` soft-delete fields, avoiding any SQL or SQLite schema change.
- Updated README, Product, AppGuide, and Database docs with the today-return calendar behavior, delete confirmation, Body Trends refresh, and calibration/review cache implications.

### Validation

- Ran `dart format lib\features\profile\profile_page.dart lib\data\repositories\profile_repository.dart lib\core\localization\app_strings.dart test\phase2_account_controller_test.dart`.
- Ran targeted `flutter test test\phase2_account_controller_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Confirmed the required documentation tree exists and searched updated docs for stale body-record sheet wording, past-date-only calendar wording, replacement characters, and date-appended stable-doc headings.
- Ran `git diff --check` with only line-ending warnings.
- Ran `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`.

## 2026-06-27 Profile Draft Save Consolidation

### Added

- Added Profile widget coverage for nickname and current body edits, confirming both remain local drafts and do not save Cloud Profile until the bottom Save Changes bar is used.

### Changed

- Removed the remaining card-level Done/save controls from ordinary Profile nickname and current body editing, leaving the bottom Save Changes bar as the only ordinary Profile save entry.
- Kept the historical body-record editor's independent save action because it writes a dated `body_metric_logs` record rather than the current Cloud Profile snapshot.
- Updated bilingual README, Product, AppGuide, and AgentDesign docs to document the consolidated Profile save boundary.

### Validation

- Ran `dart format lib\features\profile\profile_page.dart test\phase2_account_controller_test.dart`.
- Ran targeted `flutter test test\phase2_account_controller_test.dart`.
- Confirmed the required documentation tree exists and searched docs/code for root-level design-doc links, date-appended stable-doc headings, stale local-doc references, and replacement characters.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Ran `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`.

## 2026-06-27 System Notifications Refactor

### Added

- Added `FitLogNotifications` as the shared app notification layer with semantic success, error, info, and action APIs.
- Added widget coverage for lightweight success notices, bottom-navigation-safe error notices, and action callback preservation.

### Changed

- Replaced page-local SnackBar calls across Food, Workout, Profile, and AI with shared notifications: success feedback now appears as lightweight top notices, while validation and failure feedback stays visible above bottom navigation or the keyboard.
- Preserved user-facing diagnostics for parse/save/export/auth/subscription failures and kept action notifications available through a dedicated API instead of passive toast behavior.
- Updated README, Product, and AppGuide docs with the system notification UX principles and per-module notification behavior.

### Validation

- Ran `dart format lib test`.
- Ran targeted `flutter test test\fitlog_notifications_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Confirmed the required documentation tree exists and searched updated docs/code for stale snackbar usage, replacement characters, and date-appended stable-doc headings.
- Ran `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`.

## 2026-06-27 Past Body Metrics Calendar Edit

### Added

- Added an in-page Profile body-record edit state for past dates: the Body Profile calendar only allows past dates, highlights weight/body-fat/waist for editing, and dims/disables the rest of the Profile page plus root bottom navigation while the edit is active.
- Added focused widget coverage confirming past body edits write only `body_metric_logs` through `upsertWeightLog`, do not save Cloud Profile, are blocked while an unsaved Profile draft exists, show full-year English dates, and keep English strategy-card details on a hyphen-prefixed second line.

### Changed

- Kept historical body metric saves separate from the full Cloud Profile save path so backfilled records do not silently change current body data.
- Changed the English historical body-record date badge from a shortened year to a full four-digit year.
- Updated bilingual README, Product, AppGuide, and AgentDesign docs to replace the old body-record sheet design with the in-page edit state and document the stronger soft-fade lock state plus keyboard-aware focus behavior.
- Added stable same-surface body-profile editor details to the bilingual README, Product, and AppGuide docs.

### Fixed

- Strengthened locked Profile areas and root bottom navigation with soft opacity dimming, avoiding block scrims or visible rectangular seams while making non-editable content read as disabled.
- Added focus-aware keyboard reveal for Profile auth fields and inline body editors so active inputs are scrolled above the keyboard without compressing the cards.
- Kept Body Profile inline editors visually merged with their metric tiles and gave the value area a stable height so focusing a field no longer paints a separate input block or changes tile size.
- Split English Home strategy-card titles into a strategy line and a hyphen-prefixed detail line to avoid awkward narrow-screen wrapping.

### Validation

- Ran `dart format lib test`.
- Ran targeted `flutter test test\home_page_test.dart`.
- Ran targeted `flutter test test\phase2_account_controller_test.dart`.
- Ran `flutter analyze`.
- Ran `flutter test`.
- Confirmed the required documentation tree exists and searched docs for stale body-record sheet wording, replacement characters, stale local-doc links, and date-appended stable-doc headings.
- Ran `flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json`.

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
