# AI Accepted Delivery Performance Report

## Scope

Date: 2026-08-09

Feature scope: reliable accepted delivery for AI Chat and Add Food photo analysis. Once an Edge Function returns `202 accepted`, the server owns the request lifecycle. The app must recover to processing, success, or stable failed-with-retry after foreground loss, backgrounding, or process death. Before acceptance, the client still owns local retry input.

This report covers the local implementation and validation state. It does not claim production latency, production provider success rate, or deployed Supabase behavior because the migration and Edge functions were not applied to a remote project during this pass.

## 中文摘要

本次“可靠接受后交付”把 AI Chat 与 Add Food 拍照分析从前台 HTTP 回调可靠性中解耦。服务器返回 `202 accepted` 后，请求生命周期由 `ai_delivery_requests` 云端行接管；App 即使切后台、被杀或轮询超时，重新进入后也能从云端恢复到处理中、成功结果或可重试失败状态。

本地验证结果是绿色的：Edge 类型检查通过，Edge 确定性测试 65/65 通过，`flutter analyze` 通过，Flutter 测试 300/300 通过。Release split APK 在清理遗留 Flutter 锁并确认构建环境可写后完成，Gradle `assembleRelease` 用时 35.3 秒，三个 ABI 包大小分别约 32.77 MB、34.73 MB、36.16 MB。

需要明确的性能边界是：本报告只证明本地实现、契约、UI 恢复和构建健康状态，不代表线上 Supabase 项目的真实模型延迟或成功率。线上完整可靠性还需要应用 migration、部署 Edge Functions、配置定时 worker 调用和临时资产清理任务，并在真实设备上完成切后台/杀进程恢复 canary。

## Executive Summary

- The feature removes the old foreground-only reliability gap: accepted AI work is now represented by `ai_delivery_requests`, not by an in-memory Flutter callback.
- The accepted boundary avoids fake success. `202 accepted` means only that auth, subscription, active-device, request validation, idempotency, delivery-row persistence, and required temporary image persistence succeeded.
- Chat and photo analysis keep separate business landings. Chat success writes canonical chat messages. Photo-analysis success remains a temporary Food Draft result and opens Food Preview only after the user taps the completed status card.
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
