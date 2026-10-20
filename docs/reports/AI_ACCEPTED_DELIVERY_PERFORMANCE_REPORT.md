# AI Accepted Delivery Performance Report

Supersession note: this report records the 2026-08-09 implementation evidence. The current product boundary is stricter for Add Food photo analysis: AI Chat still recovers accepted requests across process death, but Add Food photo analysis only recovers while the original analysis page remains alive. If that page or process is killed, the app restores no images, text, result, status card, or retry UI. Current source-of-truth behavior lives in `docs/en/AgentDesign.md`, `docs/zh/AgentDesign.md`, `docs/API_CONTRACT_DRAFT.md`, and the Database/CloudLocalDataBoundary docs.

## 2026-08-14 Production Diagnosis

This section supersedes the older statement that production latency had not been measured. It records a bounded investigation, not a general provider benchmark: one generated meal image was converted to a 1,448 x 1,086 JPEG of 446,757 bytes, close to the 459,242 and 463,502 byte historical Chat images. Provider probes used the configured production Qwen model. Add Food canaries used the deployed asynchronous Edge route, an acceptance account, the private temporary bucket, the real worker path, and the same immediate-then-three-second polling cadence as Flutter. Canary delivery/log rows were deleted after measurement.

### Root-Cause Conclusions

| Question | Evidence | Conclusion |
| --- | --- | --- |
| Is `planner_unavailable` a Qwen outage? | At the production 8 second deadline, text Planner succeeded 5/5 at 1.94-3.68 seconds while image Planner succeeded 1/5; four calls were aborted locally at 8.01 seconds. With a diagnostic 20 second deadline, image Planner succeeded 5/5 at 8.24-12.17 seconds. | No. The confirmed direct cause is FitLog's 8 second client deadline around a normally slower multimodal Planner. The former top-level error erased that distinction. |
| Did the Phase 5.11 food prompt nearly double generation time? | Interleaved same-image probes: previous policy averaged 18.60 seconds; current policy averaged 20.55 seconds. | No. The observed increment was about 1.95 seconds or 10.5 percent. It matters, but it cannot explain a near doubling by itself. |
| Did accepted delivery add latency? | Production canaries measured temporary upload, claim, worker reload, Provider, validation, and polling separately. | Yes. Storage and polling add real fixed cost, but Provider generation remains dominant. |
| Is durable Worker recovery completely deployed? | Production booleans for both database settings read `false`; Edge secret and database GUC are separate stores. The cron job also failed 1,440/1,440 times in the latest 24 hours because direct `storage.objects` deletion is rejected by `protect_delete()`. | No. `waitUntil` handles the normal path, but cron exits during purge before it can invoke a Worker. Cleanup must use the Storage API and Worker credentials must move to a deployable database-side secret path. |

The Git history also changes the chronology interpretation: the 8 second `chat_decision.v2` Planner dates to 2026-07-19. Accepted delivery did not create that deadline, but its new failure/history/recovery state machine made the existing fault more visible and more disruptive. The later generic-image direct route avoids the Planner but is not a valid final product rule because image presence alone does not identify user intent.

The failed cleanup has a small but real current footprint: five expired delivery rows and six temporary objects totaling about 2.51 MB. Four objects are referenced by expired rows and two are unreferenced. This is not the cause of Provider latency, but it proves that the claimed expiry/cleanup boundary is not operating and must be repaired before reliable delivery can be called complete.

### Planner Measurements

| Probe | Samples | Success | Average | Range |
| --- | ---: | ---: | ---: | ---: |
| Text Planner, 8 second deadline | 5 | 5/5 | 3,005 ms | 1,938-3,684 ms |
| Image Planner, 8 second deadline | 5 | 1/5 | 7,950 ms including local aborts | 7,717-8,012 ms |
| Text Planner, 20 second diagnostic deadline | 5 | 5/5 | 3,139 ms | 3,041-3,282 ms |
| Image Planner, 20 second diagnostic deadline | 5 | 5/5 | 9,608 ms | 8,240-12,170 ms |

The 20 second run is diagnostic evidence only. Increasing the production deadline would turn an image turn into roughly ten seconds of visual planning followed by another visual generation call, so the engineering plan removes pixels from the Planner instead of normalizing that latency.

### Add Food Production Canaries

Three same-method samples with complete client-visible timing produced the following results:

| Metric | Sample 1 | Sample 2 | Sample 3 | Average |
| --- | ---: | ---: | ---: | ---: |
| Client send to accepted response | 1,849 ms | 1,402 ms | 1,525 ms | 1,592 ms |
| Pre-accept Storage upload inside Edge | 659 ms | 690 ms | 832 ms | 727 ms |
| Worker claim | 93 ms | 99 ms | 96 ms | 96 ms |
| Worker Storage reload | 1,120 ms | 965 ms | 1,310 ms | 1,132 ms |
| Provider first pass | 13,849 ms | 15,653 ms | 13,748 ms | 14,417 ms |
| First validation | 1 ms | 1 ms | 1 ms | 1 ms |
| Server accepted to completed | 15,474 ms | 17,113 ms | 15,564 ms | 16,050 ms |
| Client send to App-observed terminal result | 17,367 ms | 20,196 ms | 17,044 ms | 18,202 ms |
| App terminal poll number | 6 | 7 | 6 | 6.3 |

One earlier instrumentation canary also succeeded and measured 716 ms upload, 1,120 ms reload, 17,011 ms Provider time, and 18,838 ms accepted-to-completed time; it is excluded from the client-visible average because the first report did not yet emit one same-clock end-to-end field.

The current polling architecture has a deterministic completion-to-visibility upper bound of approximately 3 seconds plus one database query while the page is foregrounded. Background polling is intentionally paused and resume triggers an immediate query. The remediation plan keeps that lifecycle boundary but targets a bounded one-second foreground cadence and a warm normal worker path that reuses the already parsed image instead of immediately downloading the just-uploaded object.

### Prompt Accuracy And Latency Signal

The controlled image contained four edible items totaling 420 g plus two non-food scale references. Three baseline-policy drafts reported item counts of 5, 5, and 4 with total weights of 750, 750, and 420 g. Three current-policy drafts reported item counts of 4, 5, and 4 with total weights of 480, 785, and 530 g. The current policy improved exact item-count frequency from 1/3 to 2/3 and reduced mean absolute total-weight error from 220 g to about 178 g, but this sample is far too small and variable for an accuracy claim.

The correct decision is therefore to preserve explicit-quantity priority, scale references, item-first estimation, item-derived totals, and meal-level sanity checks while building a labeled accuracy/latency evaluation set. Prompt rollback based only on perceived speed would trade away the product's primary accuracy requirement without addressing the confirmed Planner, Storage-reload, polling, or Worker-configuration causes.

### Observability Added

- Chat decision planning now has bounded internal failure reasons such as `client_timeout`, Provider timeout/limit/auth/HTTP categories, response JSON failure, Planner JSON failure, and decision-contract failure. The public error family remains stable and raw Provider material is not logged.
- Add Food writes `photo_latency_breakdown.v1` into the existing `ai_request_logs.latency_breakdown_json`, covering pre-accept upload, claim, asset load, first Provider pass, first validation, optional correction, correction validation, and Worker/sync total.
- Diagnostic probes log only duration, bounded status, contract validity, item count, total weight, and response character count. They do not print prompts, images, raw model output, tokens, secrets, account IDs, or session IDs.

The active implementation and acceptance plan is maintained under `docs/ROADMAP.md` in “当前阻断工作包：AI Chat 正确路由与图片交付时效”.

## Scope

Date: 2026-08-09

Historical feature scope: reliable accepted delivery for AI Chat and Add Food photo analysis as implemented on 2026-08-09. Current behavior keeps the AI Chat cross-process recovery requirement, while Add Food photo analysis is limited to the still-mounted-page background/return case described in the supersession note above.

This report covers the local implementation and validation state. It does not claim production latency, production provider success rate, or deployed Supabase behavior because the migration and Edge functions were not applied to a remote project during this pass.

## 中文摘要

本报告记录 2026-08-09 的“可靠接受后交付”实现证据。当前产品边界已调整为：AI Chat 继续支持 accepted 后跨进程恢复；Add Food 拍照分析只解决原页面仍存活时切后台再回来查看结果的问题，进程或页面死亡后不恢复图片、文字或结果。

本地验证结果是绿色的：Edge 类型检查通过，Edge 确定性测试 65/65 通过，`flutter analyze` 通过，Flutter 测试 300/300 通过。Release split APK 在清理遗留 Flutter 锁并确认构建环境可写后完成，Gradle `assembleRelease` 用时 35.3 秒，三个 ABI 包大小分别约 32.77 MB、34.73 MB、36.16 MB。

需要明确的性能边界是：本报告只证明本地实现、契约、UI 恢复和构建健康状态，不代表线上 Supabase 项目的真实模型延迟或成功率。线上完整可靠性还需要应用 migration、部署 Edge Functions、配置定时 worker 调用和临时资产清理任务，并在真实设备上完成切后台/杀进程恢复 canary。

## Executive Summary

- The feature removes the old foreground-only reliability gap: accepted AI work is now represented by `ai_delivery_requests`, not by an in-memory Flutter callback.
- The accepted boundary avoids fake success. `202 accepted` means only that auth, subscription, active-device, request validation, idempotency, delivery-row persistence, and required temporary image persistence succeeded.
- Chat and photo analysis keep separate business landings. Chat success writes canonical chat messages. Current photo-analysis success remains a temporary Food Draft result that is consumed only by the original still-mounted Add Food page; the older AI-page completed-card behavior in this historical report is no longer the source of truth.
- The main performance tradeoff is intentional: accepted async image requests pay a small pre-acceptance Storage write so background worker recovery can survive app death.
- Local validation is green: Edge type check passed, Edge deterministic tests passed 65/65, Flutter analyze passed, Flutter tests passed 300/300, and split Release APK build completed in 35.3 seconds after clearing stale Flutter locks.

## Performance Targets And Results

| Area | Target | Current result |
| --- | --- | --- |
| App process loss after acceptance | Request must not disappear. | Delivery row is cloud-authoritative; Flutter polls and reloads delivery rows on resume. |
| Accepted response behavior | Return before provider completion. | Async routes return `ai_delivery_transport.v1` after persistence, then continue via `waitUntil` and worker actions. |
| Foreground polling | Avoid tight loops. | One request poll every 3 seconds, capped at 40 ticks, about 120 seconds. Resume/load paths repair after polling stops. |
| Worker lease | Prevent double active workers while permitting recovery. | Edge workers request a 120 second lease; SQL clamps leases between 30 and 300 seconds and can reclaim expired `running` rows. |
| Retry bound | Avoid unbounded provider loops. | `max_attempts` defaults to 3 and SQL constrains it to 1 through 5. |
| Retention bound | Avoid long-lived temporary assets. | Delivery rows default to 72 hour expiry; temporary assets are private and scoped to retry/recovery. |
| Worker batch size | Avoid large catch-up spikes. | `process_pending` defaults to 3 rows and caps requested limit at 10. |
| Image payload size | Bound upload and provider cost. | Client and Edge reject images above 4 MB each; max images is 3; temp bucket limit is 12 MB per object policy. |
| Release build health | Avoid previous lock/permission stall. | Stale Flutter locks were removed after process checks; split Release build completed in 35.3 seconds. |

## Local Measurements

### Build

Command:

```bash
flutter build apk --release --split-per-abi --no-pub --dart-define-from-file=config/supabase.local.json
```

Observed result:

- Gradle task `assembleRelease`: 35.3 seconds.
- `MaterialIcons-Regular.otf` tree-shaken from 1,645,184 bytes to 15,464 bytes, a 99.1 percent reduction.
- Build environment issue reproduced and resolved: sandboxed Gradle/Flutter checks hit wrapper or tool-state permission limits; the final build ran in an elevated environment after confirming no active Flutter/Dart build process and clearing two stale Flutter cache locks.

APK outputs:

| APK | Size | SHA-256 |
| --- | ---: | --- |
| `app-armeabi-v7a-release.apk` | 32.77 MB | `F65887F4B68998C9733DB746A9B6562475C986F8847E9DD24AF7F779B297A8BB` |
| `app-arm64-v8a-release.apk` | 34.73 MB | `1D3987B6D91377CAC24222673D5442B791E462D6B20D260ED181772298AAE4DE` |
| `app-x86_64-release.apk` | 36.16 MB | `F688462D5CEBD5A19C6A9037FD7FB491FACC2B736A6867AB1958E5955928B542` |

### Validation Runtime

Local observed checks:

- `npm.cmd exec --yes deno -- check supabase/functions/ai-chat-route/index.ts supabase/functions/ai-food-photo-analyze/index.ts`: passed.
- Edge deterministic tests for shared output contract, Chat route, expected output, and photo analysis: 65 passed, 0 failed.
- `flutter analyze`: no issues found.
- `flutter test`: 300 passed.

These checks validate contract compatibility, parser behavior, UI controller recovery, retry calls, accepted transport parsing, photo-analysis accepted transport, and existing product workflows. They do not measure production network latency or provider latency.

## Runtime Performance Profile

### Accepted Path

For async Chat and photo analysis, the pre-acceptance path performs:

1. Auth/session validation.
2. Subscription and active-device checks.
3. Request schema and attachment validation.
4. Idempotency lookup by `(account_id, kind, client_request_id)`.
5. Temporary private Storage writes for image payloads.
6. `ai_delivery_requests` insert or duplicate replay.
7. `202 accepted` transport response.

Provider execution starts after acceptance through `EdgeRuntime.waitUntil` when available. Worker-only `process_one` and `process_pending` actions provide recovery if the immediate waitUntil execution is interrupted.

Performance implication: ordinary accepted responses are no longer blocked by model generation, RAG, or output validation. Image requests still wait for temporary asset persistence before acceptance because that persistence is what makes recovery true.

### Worker And Database

The delivery table is shaped for cheap recovery and claim scans:

- Unique idempotency: `(account_id, kind, client_request_id)`.
- Owner display scan: `(account_id, status, updated_at desc)`.
- Claim scan: `(kind, status, lease_expires_at, accepted_at)` for queued/running rows.
- RLS permits authenticated users to select only their own delivery rows.
- Service-owned RPCs perform accept, claim, finish, and retry mutations.

At-least-once execution is expected. Business writes stay idempotent:

- Chat worker records with `record_ai_chat_turn_v3` and request/client ids.
- Photo worker stores an existing Food Draft response envelope in the delivery row only.
- Official food records are written only through Food Preview Save.

### Flutter UI

Foreground delivery polling is deliberately light:

- One active polling timer per controller.
- Poll interval: 3 seconds.
- Poll cap: 40 ticks, about 120 seconds.
- Terminal delivery reloads sessions and messages.
- Resume refresh and session reload repair state after polling stops or app process loss.

The UI avoids unbounded spinners by rendering explicit delivery states:

- Chat processing bubble for queued/running rows.
- Chat failed bubble with Retry for terminal retryable failure.
- Photo processing card on the AI page.
- Photo draft-ready card that opens Food Preview only on tap.
- Photo failed card with Retry.

## Feature Additions Confirmed In Design Docs

| Current behavior | Owning docs updated |
| --- | --- |
| `202 accepted` means server-owned delivery lifecycle, not model success. | `AgentDesign.md`, `CloudLocalDataBoundary.md`, `AIOutputContract.md`, `API_CONTRACT_DRAFT.md`, `README.md` |
| `ai_delivery_requests` stores accepted lifecycle, attempts, lease, retryability, result/error, assets, and expiry. | `Database.md`, `CloudLocalDataBoundary.md`, `API_CONTRACT_DRAFT.md` |
| Private temporary `fitlog-ai-temp-assets` bucket stores accepted async images for recovery/retry only. | `Database.md`, `AgentDesign.md`, `API_CONTRACT_DRAFT.md`, `README.md` |
| AI Chat success remains canonical chat history. | `AgentDesign.md`, `Database.md`, `CloudLocalDataBoundary.md` |
| Add Food photo success remains a temporary draft card until Food Preview Save. | `Product.md`, `AppGuide.md`, `AgentDesign.md`, `AIOutputContract.md`, `API_CONTRACT_DRAFT.md` |
| Client polls and reloads delivery rows; retry requeues the same request. | `AppGuide.md`, `CloudLocalDataBoundary.md`, `API_CONTRACT_DRAFT.md` |
| Accepted transport schema is `ai_delivery_transport.v1`. | `AIOutputContract.md`, `API_CONTRACT_DRAFT.md` |

## Removed Or Explicitly Not Added Scope

| Old or rejected scope | Current documented state |
| --- | --- |
| Foreground-only AI request lifetime. | Replaced by accepted delivery rows after `202 accepted`; pre-accepted input remains local retry state. |
| Generic background operation engine or cloud-side draft queue outside the visible product surfaces. | Not added; delivery is narrow and product-specific. |
| Android WorkManager, foreground service, push notification, wake lock, or background keepalive for AI delivery. | Not added; worker recovery is server-side and client recovery is polling/resume. |
| Long-term original image storage or image bytes in chat history/logs. | Not added; accepted async images use short-lived private temporary Storage only. |
| AI silently writing official food records. | Not added; official writes still require Food Preview Save. |
| Prompt, RAG, validator schema, or provider output-family changes. | Not changed for this feature. |
| SQLite delivery queue table `ai_pending_operations`. | Retired compatibility cleanup remains documented as SQLite v20 behavior. |

## Documentation Audit Result

Checked stable documentation tree:

- `README.md`
- `CHANGELOG.md`
- `docs/API_CONTRACT_DRAFT.md`
- `docs/ROADMAP.md`
- `docs/en/*` and `docs/zh/*` for Product, AppGuide, Methodology, Algorithm, Database, CloudLocalDataBoundary, AgentDesign, AIOutputContract, RAGDesign, References

Results:

- Required bilingual stable-doc tree exists.
- English and Chinese stable-doc heading counts match for Product, AppGuide, Methodology, Algorithm, Database, CloudLocalDataBoundary, AgentDesign, AIOutputContract, RAGDesign, and References.
- Searches found no replacement characters, date-appended stable-doc headings, or stale root-level design-doc paths.
- Stale wording found and corrected during this audit:
  - Add Food was still described in AgentDesign as skipping the accepted status card in all cases.
  - Database still described image Chat without the temporary reloadable asset path now used by accepted async delivery.
  - Product's draft-surface summary did not mention the AI-page completed photo delivery card.
  - ROADMAP still described short-lived Storage image objects as future work instead of the current accepted async delivery boundary.
- Remaining `foreground service` wording is intentional Workout draft non-goal scope, not AI delivery behavior.

## Risks And Gaps

- No production latency measurement yet. The local report proves build/test health and documents expected performance characteristics, but accepted-response p50/p95, worker completion p50/p95, provider failure rate, and Storage upload latency still need a real Supabase canary.
- Supabase migration and Edge function deployment were not performed in this pass. Until deployed, production cannot use `ai_delivery_requests`, `fitlog-ai-temp-assets`, or worker actions.
- A scheduled worker trigger is still required for durable recovery when `waitUntil` is interrupted. The code exposes service-role protected `process_pending` and `process_one`, but no Supabase cron configuration was added here.
- Expiry fields and cleanup rules are documented, but a concrete scheduled cleanup worker for expired delivery rows and temporary Storage objects still needs deployment work.
- Runtime code size is high. The Edge implementation duplicates queue, asset, worker, and finish helpers across Chat and photo functions. It is verified, but a future shared module extraction would reduce maintenance risk.
- Release APK currently uses the existing project release signing behavior, which signs with the debug key. That is acceptable for local testing but not for store distribution.

## Recommended Follow-up Metrics

After deploying the migration and Edge functions, run a small canary matrix and record:

- Accepted response latency p50/p95 for text Chat, image Chat, text-only photo analysis, and 1/3-image photo analysis.
- Worker completion latency p50/p95 and timeout/error distribution.
- Temporary Storage upload latency and object cleanup success.
- Duplicate submit replay latency and duplicate provider-call count.
- Lease reclaim count for interrupted workers.
- Retry success rate by `error_code` and `failure_stage`.
- Client visible stale-processing count after app kill/resume.
- Official food write count from accepted photo analysis, proving only Food Preview Save creates records.
