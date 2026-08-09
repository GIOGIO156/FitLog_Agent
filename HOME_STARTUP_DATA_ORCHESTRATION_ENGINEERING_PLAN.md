# FitLog Home 启动/恢复刷新恢复工程计划

## 0. 当前状态

| 项目 | 内容 |
| --- | --- |
| 状态 | Recovery implementation in progress |
| 更新日期 | 2026-08-10 |
| 计划性质 | 撤回上一轮过宽 Home 编排重写，前滚恢复稳定基线，并保留必要的窄修复 |
| 主要页面 | Home；AI Chat routing；相关文档与 Release APK 构建规则 |
| 产品基线 | 保留上一个可靠 AI delivery 版本的正常功能；不得为了减少 Home 刷新牺牲 AI、正式记录、账号、订阅或 Local 确定性算法 |
| SQLite 影响 | 保留 v21 和 nullable `user_profile.account_id` 作为已安装中间构建的 additive compatibility；当前运行时不继续依赖该列作为 Cloud Profile source of truth |
| Supabase/Edge 影响 | 修正 AI Chat planning/routing；不修改正式 food/workout/body 数据权威，不新增云表 |

本文替代上一版 “HomeDashboardCoordinator 已落地” 的工程计划。上一版协调器实现造成 Home 首屏卡在 spinner，并伴随 AI 训练前饮食/当天安排建议被误判为 FitLog app-logic grounding 而出现 `provider_output_invalid`。因此本轮采用前滚恢复：保留坏 APK 已经可能写入的 schema 兼容点，撤回过宽的数据编排重写，在稳定旧路径上做最小可验证修复。

稳定产品事实仍由 `docs/en|zh/CloudLocalDataBoundary.md`、`docs/en|zh/AgentDesign.md`、`docs/en|zh/RAGDesign.md`、`docs/en|zh/Database.md`、`docs/API_CONTRACT_DRAFT.md` 和 `CHANGELOG.md` 维护。

## 1. 问题验证结论

### 1.1 Home 多次刷新/卡 spinner

旧版本的多次刷新并不只发生在冷启动。只要 App 从后台恢复，`RootShell.didChangeAppLifecycleState(resumed)` 会调度选中日期 hydration refresh，并通过 `RefreshNotifier.markDataChanged()` 推动 Home 重新读取。

旧 Home 的代码行为是：`RefreshNotifier.version` 改变后创建新的 `_dataFuture`；只要新 Future 未完成，`FutureBuilder` 就返回整页 `CircularProgressIndicator`。因此即使已有 dashboard 已成功显示，后台恢复或短暂切出再回来也会被可见地替换成 loading。上一轮的大型 coordinator 重写试图一次性处理账号、Cloud Profile、active-device、summary、warm cache 和隐藏 tab，但实际破坏了 Home 首屏稳定性。

本轮判断：不要继续在该 1000+ 行改动上补丁；应恢复到上一个正常基线，然后只实现“有已成功 selected-day snapshot 时，refresh pending/failure 继续显示旧 dashboard”的窄修复。

### 1.2 AI “返回结果未通过校验”

通过近期 `ai_request_logs`/`ai_debug_summaries` 复核，截图对应失败为：

- `status = error`
- `error_code = provider_output_invalid`
- `expected_output = text`
- `workflow_type = app_logic_answer`
- `decision_reason = workout_rule_question`
- `validation_issue_codes_json` 包含 `grounding_fitlog_claim_without_approved_evidence`

该请求是“今天没吃饭、稍后腿部力量训练、问怎么安排”一类训练前饮食/当天安排建议。它不应被分类为 FitLog app 规则问答。真正的 FitLog 规则问答应是“每侧次数怎么算”“训练量/总训练重量怎么算”“FitLog 如何记录/计算某个值”等。

本轮判断：保留严格 grounding 校验，但修正路由边界。普通训练前饮食安排进入 `meal_decision`（在授权 context 可用时），或普通只读回答；FitLog 计算/记录规则仍进入 `app_logic_answer` 并请求 Document RAG / exercise definition。

## 2. 本轮工程原则

1. 恢复已知正常功能优先。撤回上一轮 HomeDashboardCoordinator、强制 selected-day official refresh、Profile account-id runtime 过滤等过宽改动。
2. 保留数据库前向兼容。已安装过上一 APK 的设备可能已有 v21 schema，因此不能把 `AppDatabase.dbVersion` 降回 v20。
3. Home 体验修复只动可见状态发布，不改 daily summary 公式、food/workout/profile 读写语义或 AI delivery。
4. AI 修复只改 intent/routing 边界，不放松 provider output schema、date、artifact、grounding 或 write-permission validation。
5. 稳定文档写当前真实架构，不保留“已实现 coordinator”这类误导性状态。
6. Release APK 必须按 `AGENTS.md` 的配置版 split Release 规则构建，并在构建前检查活跃进程和孤立 Flutter lock。

## 3. 实施顺序

### Phase A — 前滚恢复代码基线

- 将上一轮 Home/Root/summary/cache/repository/account/test 大改恢复到可靠 AI delivery 之后的稳定基线。
- 删除撤回的 `daily_summary_entry.dart` 与 `home_dashboard_coordinator.dart`。
- 保留 `AppDatabase.dbVersion = 21`、`user_profile.account_id` 建表字段、open-time/upgrade-time additive repair。

验收：

- `rg "HomeDashboardCoordinator|homeDashboardCoordinator|daily_summary_entry"` 在生产代码和稳定设计文档中无误导性残留；本恢复计划和 changelog 可以保留撤回说明。
- `test/daily_summary_cache_test.dart` 断言 schema version 为 21。

### Phase B — Home 可见刷新窄修复

- 在 `HomePage` 保留 `_lastSuccessfulData` 和 `_lastSuccessfulDate`。
- 新 Future pending 时，如果上一份成功 snapshot 属于当前选中日期，继续渲染该 snapshot。
- 新 Future 失败时，如果上一份成功 snapshot 属于当前选中日期，继续渲染该 snapshot；只有没有任何可用数据时才显示 loading/error/empty。
- 后台 refresh 成功后更新 `_dataFuture` 的同时更新 last-successful snapshot。

验收：

- 新增 widget 回归：已显示 Home dashboard 后触发 `RefreshNotifier.markDataChanged()`，下一次 summary read 被阻塞时，`ListView` 和既有 dashboard 文案仍保留。
- 保留既有 Home layout、g/kg、energy-ratio、strategy guide 和账号恢复测试。

### Phase C — AI routing 边界修复

- 保留既有 Workout 规则问答保护：含训练/动作/组数/次数/重量/容量等 subject 且是问句时，仍可进入 `app_logic_answer` 并请求 Document RAG / exercise definition。
- 不整体放松 grounding，也不把所有训练建议改成 `meal_decision`；本轮只新增窄例外。
- “今天没吃饭 + 稍后训练 + 怎么安排”在宽泛 Workout 规则问答之前确定性进入 `meal_decision`。
- 模型 planner system prompt 同步该边界，防止 planner 再把训练前饮食/当天安排建议推入 Document RAG grounding。

验收：

- planner tests 覆盖 pre-workout meal advice -> `meal_decision`。
- 原有 reps-per-side / training volume 规则问答仍 -> `app_logic_answer`，并保留 exercise definition context。
- AGENTS 指定 Edge `deno check` 与 deterministic tests 通过。

### Phase D — 文档和构建规则

- `CHANGELOG.md` 记录本轮恢复、Home 刷新修复、AI routing 修复和验证结果。
- `docs/en|zh/Database.md` 把 v21 描述为 additive compatibility，不再声称当前 runtime 依赖 `user_profile.account_id` 作为 Cloud Profile 权威机制。
- `docs/en|zh/CloudLocalDataBoundary.md` 保留“已显示 Home 不得被后台 refresh 打回整页 loading”的不变量，移除撤回的 dashboard coordinator 实现承诺。
- `docs/en|zh/AgentDesign.md`、`docs/en|zh/RAGDesign.md` 和 `docs/API_CONTRACT_DRAFT.md` 记录 app-logic grounding 与普通训练前饮食建议的边界。
- `AGENTS.md` 保留 Release APK 快速构建规则。

验收：

- 必需双语稳定文档树存在。
- 无撤回 coordinator 名称或误导性表述残留。
- 无 replacement character。
- 稳定文档变化后重新生成本地 Document RAG seed；不上传、不激活云端 corpus。

### Phase E — Release APK

- 构建前检查活跃 `flutter`、`dart`、`gradle`、相关 `java` 进程。
- 检查 `C:\src\flutter\bin\cache\lockfile` 与 `C:\src\flutter\bin\cache\flutter.bat.lock`。只有确认没有活跃 Flutter 构建持有锁时才删除精确孤立锁。
- 使用配置版 split Release：

```powershell
flutter build apk --release --split-per-abi --dart-define-from-file=config/supabase.local.json
```

- 复制产物到 `artifacts/release-apks/` 并刷新 SHA256。

验收：

- `app-armeabi-v7a-release.apk`
- `app-arm64-v8a-release.apk`
- `app-x86_64-release.apk`

## 4. 必须保护的不变量

- `energy_ratio` 与 `gram_per_kg` 计算语义不合并。
- `diet_goal_phase` 继续是减脂/增肌 source of truth。
- AI 不得静默修改目标、应用 carb tapering、删除记录或写正式 food/workout/profile 数据。
- 可靠 AI delivery 的 `202 accepted` 生命周期不因 Home 修复被削弱。
- Add Food 图片分析、Chat history、typed clarification、Food/Workout Draft review/save 确认路径必须保持。
- App resume 后可以触发必要刷新，但不得把已有 Home dashboard 清空成整页 spinner。
- 训练前饮食/当天安排建议不得要求 Document RAG grounding；FitLog 自身规则说明必须继续 grounded 或明确说明没有匹配文档。

## 5. 当前验证记录

本轮最终验证结果：

- `dart format lib test`：通过，实际格式化 `lib/features/home/home_page.dart`、`test/daily_summary_cache_test.dart`、`test/home_page_test.dart`。
- `npm.cmd exec --yes deno -- fmt ...`：通过，格式化/检查本轮触及的 AI routing/planning TypeScript 文件。
- Targeted Flutter：`flutter test test\home_page_test.dart test\daily_summary_cache_test.dart test\phase2_account_controller_test.dart`，42/42 通过。
- Targeted AI planner：`npm.cmd exec --yes deno -- test supabase/functions/ai-chat-route/planning/chat_decision_test.ts supabase/functions/ai-chat-route/planning/task_planner_test.ts`，26/26 通过。
- `flutter analyze`：通过，无问题。
- AGENTS Edge check：`npm.cmd exec --yes deno -- check supabase/functions/ai-chat-route/index.ts supabase/functions/ai-food-photo-analyze/index.ts`，通过。
- AGENTS Edge deterministic tests：`npm.cmd exec --yes deno -- test supabase/functions/_shared/ai_output_contract_test.ts supabase/functions/ai-chat-route/expected_output_test.ts supabase/functions/ai-chat-route/index_test.ts supabase/functions/ai-food-photo-analyze/index_test.ts`，65/65 通过；routing-boundary audit 后又连同两个 planner tests 复跑，91/91 通过。
- 全量 Flutter：`flutter test`，301/301 通过。
- 文档检查：必需稳定文档树存在；稳定 docs 未发现撤回 coordinator 表述、date-style heading 或 replacement character。
- Document RAG local seed：`node --env-file=supabase/.env.local tool/phase5_document_rag/sync_document_embeddings.mjs --build-local`，build `991d4101ce8089cefa69d95d`，633 chunks，matching 633，missing/stale/extra 均为 0；未上传或激活云端 corpus。
- Release APK：构建前检查 active `flutter`/`dart`/`gradle` 为空，仅发现一个非 Gradle 名称的长期 Java 进程；确认两个 Flutter SDK 空 lock 文件为孤立锁并仅删除 `C:\src\flutter\bin\cache\lockfile`、`C:\src\flutter\bin\cache\flutter.bat.lock`。
- Release build：`flutter build apk --release --split-per-abi --dart-define-from-file=config/supabase.local.json`，Gradle `assembleRelease` 30.9 秒完成。
- Versioned APK copies:
  - `artifacts/release-apks/fitlog-agent-v1.0.37-build41-armeabi-v7a-release.apk`
  - `artifacts/release-apks/fitlog-agent-v1.0.37-build41-arm64-v8a-release.apk`
  - `artifacts/release-apks/fitlog-agent-v1.0.37-build41-x86_64-release.apk`
- `artifacts/release-apks/SHA256SUMS.txt` 已刷新。
- Edge deployment：`supabase functions deploy ai-chat-route` 成功部署到 Supabase project `dyacqajcinjwrkbngeif`；routing-boundary audit 后重新部署，`supabase functions list` 确认 `ai-chat-route` 为 `ACTIVE` version 74。`ai-food-photo-analyze` 未 redeploy，因为本轮未修改该函数。
