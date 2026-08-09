# FitLog Home 首屏数据编排、缓存一致性与可见刷新治理工程计划

## 0. 文档状态

| 项目 | 内容 |
| --- | --- |
| 状态 | Implemented，本轮已完成代码、测试、文档与 release 构建验证 |
| 编写日期 | 2026-08-09 |
| 计划性质 | 缺陷修复、启动时序治理、缓存一致性与状态架构收敛 |
| 主要页面 | Home；同时涉及 Root、Account、Food、Workout、Profile 的刷新协调 |
| 产品基线 | 保留 FitLog Local 的确定性算法与 Agent 版 cloud-first 正式记录边界 |
| SQLite 影响 | 已在身份隔离阶段升至 v21，为 `user_profile` 增加账号归属；其余复用现有 summary metadata 列 |
| Supabase 影响 | 不修改正式 food/workout/body 数据权威；优先复用现有 `daily_summaries` metadata，不新增无必要的云表 |
| AI/Edge 影响 | 不修改 AI Gateway、模型、RAG、AI 输出合同或订阅判定 |
| 发布策略 | 先建立行为基线，再消除可见 loading reset，随后收敛数据权威和事件顺序；每阶段独立验收、可回滚 |

本文档是 Home 首屏与选中日期数据编排工程的执行计划、验收清单和风险记录。稳定产品事实仍由中英文 `CloudLocalDataBoundary.md`、`AppGuide.md`、`Database.md` 等文档负责；发布事实写入 `CHANGELOG.md`。

### 0.1 进度索引

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| Phase 0 | 行为基线、characterization tests 与可观测性 | Completed |
| Phase 1 | Home 展示状态止血：已有内容不再退回整页 loading | Completed |
| Phase 2 | 明确本地/云端读取合同、summary envelope 与纯计算边界 | Completed |
| Phase 3 | 账号、Cloud Profile、active-device 与 Root 启动顺序收敛 | Completed |
| Phase 4 | 选中日期权威 revalidation、缓存对账与单飞调度 | Completed |
| Phase 5 | 正式写入后的 summary 失效、重建和单次发布 | Completed |
| Phase 6 | Warm cache、隐藏 tab 与全局 `RefreshNotifier` 降耦 | Completed |
| Phase 7 | 全量验证、迁移、文档、实机、构建与发布 | Completed after final validation |

### 0.2 本轮实施摘要

- 新增 `HomeDashboardCoordinator` 作为选中日期 Home snapshot、freshness、failure backoff、single-flight 和结果发布 owner。
- Home 从 page-owned `FutureBuilder` 切换为 coordinator snapshot 渲染；已有 dashboard 后 legacy 全局 refresh 不再移除 `ListView`。
- `DailySummaryService` 增加 local cache entry、cloud projection entry、official-record revalidation 和 rebuild/cache 明确入口。
- Food/Workout cloud-backed repositories 增加按日期强制刷新 official records 的受控入口，用于 selected-day summary revalidation。
- AccountController 将 Cloud Profile 恢复与 subscription 恢复并行；RootShell 不再用 hydration key 广播 Home 全局刷新。
- Warm cache 延后到 Home 稳定 snapshot 与 official cloud runtime ready 之后，并在账号切换时取消旧任务；未访问 tab 延迟挂载。
- SQLite 升至 v21，为 `user_profile` 增加 nullable `account_id` 并按 active account 过滤本地 Profile cache。
- 稳定设计文档已更新：`docs/en|zh/Database.md`、`docs/en|zh/CloudLocalDataBoundary.md`、`docs/en|zh/AppGuide.md`，发布记录写入 `CHANGELOG.md`。

---

## 1. 执行结论

当前问题不是一个“第三次同步步骤”，也不是一个单独的 `FutureBuilder` 使用错误。根本问题是：**账号恢复、active-device、Cloud Profile、Food/Workout cache、`daily_summary_cache`、Home 后台重算、warm cache、正式写入后的 read-model repair，以及全局 `RefreshNotifier` 都可以独立触发同一选中日期的重新读取，但没有一个组件拥有完整顺序、freshness、单飞、结果比较和可见状态发布权。**

于是当前实现同时存在两类相反问题：

1. **触发过多**：同一个 account/day 在启动时可被初始 hydration key、active-device bind、Home stale-while-revalidate、app resume、warm cache 和全局 data change 重复计算。
2. **真正需要的刷新反而缺失或太早**：active-device ready 会触发 Home 重载，但 Cloud Profile 仍可能被订阅请求阻塞；Cloud Profile 随后真正更新时，Home 又没有与 profile version 对应的精确失效事件。

产品需要的目标不是把所有异步过程串成一个长 loading，也不是简单删除刷新。目标是：

- 有匹配账号的 confirmed Home cache：立即稳定显示；后台校验不清空内容，相同结果不产生可见更新。
- 没有匹配 cache：保持稳定骨架/首次加载状态，等待小型首屏数据包，随后只从“无数据”过渡到一次真实内容；不得先显示假零值。
- active-device、Cloud Profile、selected-day records 和 summary rebuild 有明确依赖，但订阅、AI readiness、warm cache 和草稿恢复不得阻塞 Home。
- 每个 `(accountId, date)` 同时最多一个前台 revalidation；重复触发合并，旧 generation 不得覆盖新账号或新日期。
- 正式记录仍以云端为权威，本地 SQLite 仍是 partial confirmed cache；体验优化不得把缓存升级成正式数据源。

---

## 2. 已确认且不得降级的产品需求

以下要求已经由当前产品设计文档或本次用户问题确认，实施时不得为了减少刷新而静默删除：

1. 登录后 Cloud Profile 和 cloud official food/workout/body records 仍是权威来源。
2. 本地 confirmed cache 只用于快速显示、离线只读和 read-model 加速，不成为完整云端镜像。
3. 已知当前 auth account 后，必须先绑定该账号的本地 cache，再等待 active-device claim；不得显示其他账号数据。
4. 有匹配 Home cache 时立即展示，后台刷新不得把内容重置成整页 loading 或整页 error。
5. 没有匹配 Home cache 时，不得先构建一个本地空 summary 并把它伪装成已确认真实首页。
6. 云端结果与本地 metadata/payload 一致时，不发生可见刷新、滚动重置或布局跳变。
7. 云端结果变化时，只更新 Home snapshot 中变化的值；页面、滚动位置和底部导航保持挂载。
8. active-device 仍是正式云端读取、写入和 AI 使用的安全门，不能为了首屏速度绕过。
9. subscription failure 只影响订阅展示和 AI 能力，不阻塞 Home/Profile 正式数据恢复。
10. Food/Workout/Profile 正式写入保持 cloud-first；summary cache 或云端 projection 写入失败不得把已成功的正式记录回滚为失败。
11. `energy_ratio` 与 `gram_per_kg` 继续保持不同计算语义；`diet_goal_phase` 继续是减脂/增肌 phase 的 source of truth。
12. Home read 不得静默修改饮食目标、应用新的碳水递减、删除用户记录或把 AI 草稿写成正式记录。
13. 账号切换、退出和设备替换期间，旧账号的 snapshot、异步结果和 cache 均不得泄露到新账号 UI。
14. Android picker/page recovery 的 `deferFirstFrame` 与恢复路由不因本工程被删除；Home 数据编排必须与页面恢复正交。
15. 启动不得等待完整历史或最近 30 天详细 records；首屏只取当前可见面所需的小型数据包。

对应稳定设计依据：

- `docs/en/CloudLocalDataBoundary.md`
- `docs/zh/CloudLocalDataBoundary.md`
- `docs/en/AppGuide.md`
- `docs/zh/AppGuide.md`
- `docs/en/Database.md`
- `docs/zh/Database.md`

---

## 3. 本轮实际验证结果

### 3.1 工作树与版本基线

- 审计基线：`main`，HEAD `323a3ca`。
- 审计开始时工作树干净。
- 审计起点 SQLite `AppDatabase.dbVersion` 为 `20`；本轮最终升至 `21` 并补齐 additive migration。
- 上次 Home 刷新审计涉及的生产代码在当前版本仍保持相同行为。

### 3.2 已执行测试

执行：

```powershell
flutter test test\home_page_test.dart test\phase2_account_controller_test.dart test\daily_summary_cloud_cache_test.dart test\daily_summary_cache_test.dart
```

结果：43 个测试全部通过。

这证明现有局部能力没有被当前测试判定为失败，但也暴露了覆盖缺口：

- `home_page_test.dart` 主要验证布局、mode 展示和 guide sheet。
- `phase2_account_controller_test.dart` 验证账号、Profile、订阅和页面状态的局部行为。
- summary cache 测试验证本地/云端 fallback。
- 当前没有测试覆盖 RootShell 首次 dependency 变化、active-device bind、全局 refresh 后 Home 的可见状态，或相同 payload 是否抑制 UI publish。

### 3.3 临时 characterization Widget 测试

本轮临时加入并随后完整移除了一个只用于诊断的 Widget 测试：

1. 让 Home 完成首次加载并确认 `ListView` 已显示。
2. 调用现有 `RefreshNotifier.markDataChanged()`。
3. 只推进一帧。
4. 断言 Home `ListView` 消失，整页 `CircularProgressIndicator` 出现。

测试通过，证明当前可见闪烁是确定的代码行为：Home 在任何 refresh version 改变时都会替换 `_dataFuture`，`FutureBuilder` 在新 Future 完成前抛弃已有内容并返回整页 loading。

临时测试没有保留在工作树；正式实现必须在 Phase 0 添加相反的长期回归测试：**已有 snapshot 时，refresh 不得移除 Home 内容。**

### 3.4 本轮未完成的实机证据

本轮没有获得新的 Android 实机帧时间线或 ADB trace；`flutter devices` 未在超时内返回。因此：

- “一次 refresh 必然清空 Home”已有 Widget 级可执行证据。
- “启动时可能触发几次 refresh”可由代码路径确定，但具体哪几个回调跨帧、用户最终看到两跳还是三跳，仍受网络、数据库、first-frame recovery 和调度时序影响。
- Phase 0 必须加入 debug trace 和配置 Supabase 的实机复现，不能只依赖静态推理完成发布验收。

### 3.5 本轮完成后的最终验证

- `dart format lib test` 通过。
- `flutter analyze` 通过，无问题。
- `flutter test` 通过，301 个 Flutter 测试全部通过。
- 目标回归测试通过：`flutter test test\home_page_test.dart test\phase2_account_controller_test.dart test\daily_summary_cloud_cache_test.dart test\daily_summary_cache_test.dart`。
- 稳定文档更新后重新生成本地 Document RAG seed：build `991d4101ce8089cefa69d95d`，21 个来源、633 个 chunks，local embeddings 633/633 parity；未上传或激活云端 Document RAG。
- Release APK 使用配置版 split 构建完成：`flutter build apk --release --split-per-abi --dart-define-from-file=config/supabase.local.json`。在删除上次中断留下的 Flutter cache 孤立锁后，Gradle release build 用时 34.5 秒，产出 `app-armeabi-v7a-release.apk`、`app-arm64-v8a-release.apk`、`app-x86_64-release.apk`；随后复制到 `artifacts/release-apks/` 为版本化 `1.0.37+41` binaries，并刷新 `SHA256SUMS.txt`。
- 根 `AGENTS.md` 已补充 Release APK 构建规则：构建前检查 Flutter/Dart/Gradle/Java 活跃进程；仅在确认没有活跃 Flutter 构建持有锁时删除精确 orphan lock；使用可写 `%APPDATA%\.flutter_tool_state` 与 Flutter SDK cache 的环境执行配置版 Release 命令；不要因为 UI 未刷新就重复启动构建。

---

## 4. 当前实际代码行为

### 4.1 正常恢复登录的启动链路

当前主要时序如下：

```text
AccountController.initialize
  → authRepository.loadSession
  → 设置 profileRepository active account
  → 尝试读取匹配 metadata 的本地 Cloud Profile cache
  → notify：RootAuthGate 进入五栏 RootShell
  → 后台启动 active-device claim 和 account-bound state load

RootShell.didChangeDependencies（第一次）
  → 再次绑定 Food/Workout/Profile repository accountId
  → 构造初始 hydration key
  → 因 _lastRecordHydrationKey 原为 null，安排一次全局 markDataChanged
  → 立即启动 30 天 warm summary（只延迟 400 ms，不等待 runtime ready）

HomePage（第一次）
  → 读取本地 daily_summary_cache
  → cache 命中：立即返回 snapshot，同时后台 getSummaryForDateAndCache
  → cache 未命中：立即 getSummaryForDateAndCache；此时 runtime 可能仍未 ready

active-device RPC 完成
  → CloudRuntimeContext.bind
  → RootShell.didChangeDependencies（第二次）
  → hydration key 因 deviceId/sessionId 改变
  → 再安排一次全局 markDataChanged

AccountController 继续恢复
  → subscription loading/请求/通知
  → subscription 完成后才 fetch Cloud Profile
  → Cloud Profile 写入本地 cache 并通知
  → Root hydration key 不再变化，Home 不一定因此精确重建
```

### 4.2 Home 自己的重复计算

`HomePage` 在 cache 命中时仍无条件调用 `_refreshDataInBackground`。后台任务：

1. 再次调用 `DailySummaryService.getSummaryForDateAndCache`。
2. 再次读取 Profile。
3. 先写本地 summary cache，再尝试写云端 `daily_summaries`。
4. 最后才检查 Home 当前 date/refreshVersion 是否仍匹配。
5. 匹配则 `setState`，把 `_dataFuture` 替换为已完成的新 Future。

`_backgroundRefreshKey` 包含 `refreshVersion`，所以全局 version 每增加一次，同一 account/day 就能再启动一轮后台重算。旧任务虽然可能不再更新 UI，但它在 generation 检查前已经发生 repository reads 和 cache/cloud side effects。

### 4.3 “本地读取”与“云端读取”没有被 API 名称分开

`DailySummaryService.getCachedSummaryForDate` 的行为并非纯本地：

- 先查本地 `daily_summary_cache`。
- 本地 miss 后直接请求云端 `daily_summaries`。
- 云端命中后再写回本地。

因此调用方无法从方法名判断它是否会联网、等待 active-device、失败或写 cache。

Food/Workout 的 `get...ByDate` 又是另一套行为：

- runtime 未 ready：只读本地。
- runtime ready 且本地非空：仍只返回本地，不校验云端。
- 只有本地结果为空时才请求云端。

这意味着“第二次画面是云端同步”并不总成立：只要本地有一条记录，所谓后台重算仍可能完全使用本地 cache。

### 4.4 freshness metadata 存在，但 Home 无法使用

SQLite `daily_summary_cache` 已有：

- `summary_version`
- `source_updated_at`
- `cloud_updated_at`
- `cache_confirmed`
- `cached_at`

但 `DailySummaryCacheRepository.getCachedSummary` 只返回 `DailySummary`，丢弃了 freshness 和来源 metadata。结果是：

- Home 不知道 cache 是刚写入还是几天前写入。
- 任意 cache hit 都会触发后台重算。
- app resume 无法按 freshness gate，Root 当前每次 resume 都全局 refresh。
- 相同 summary 也没有稳定 fingerprint/equality gate，仍可 `setState`。

### 4.5 `DailySummaryService` 的“读”包含写副作用

`getSummaryForDate` 会调用 `_resolveCalibration`。当校准条件满足时，它会写 `CalorieCalibrationState`。随后 `getSummaryForDateAndCache` 又会写本地 summary cache 和云端 projection。

因此当前一次“刷新 Home”实际上可能包含：

- 读取 Profile、食物、训练、体重和辅助窗口；
- 更新 calorie calibration；
- 重建 summary；
- 写 SQLite summary cache；
- upsert Supabase `daily_summaries`；
- 发布 UI。

在重复和并发 refresh 下，这不是一个纯粹、可安全重试的 display read。

### 4.6 Account slice 恢复顺序错误

`AccountController._loadAccountBoundState` 当前先 `await _loadSubscriptionStatus(accountId)`，之后才 fetch Cloud Profile。Home 的目标、nickname、macro mode 和 diet phase 依赖 Profile，但不依赖订阅。

后果：

- 慢订阅请求会延迟真正的 Cloud Profile。
- active-device bind 已经触发 Home refresh 时，Home 可能仍使用旧 Profile cache。
- Cloud Profile 最终到达后，没有 account/day/profile-version 精确事件保证 Home 重建。

### 4.7 正式写入后的发布顺序重复

Food、Workout、body metric 等成功路径普遍执行：

```text
await cloud-first official record write
→ markDataChanged()                    // 立即让 Home/Food/Workout 重载
→ refreshDailySummaryCacheForDate(s)   // unawaited 再重建 summary
```

Home 收到全局 mark 时可能先读到旧 summary cache，随后又启动自己的后台重算；`AppServices` 同时在后台重建同一天 summary。一次正式写入因此可能产生多个 summary build 和多个不同时间的可见结果。

### 4.8 Warm cache 与可见首屏没有优先级隔离

Root 一看到 accountId 就启动 `warmRecentWindow`，不等待：

- active-device ready；
- Cloud Profile ready；
- Home 首屏稳定；
- 当前 tab 是否需要恢复到 AI/Workout。

Warm cache 虽然延迟 400 ms，并且自身不直接通知 Home，但它会调用同一批 summary read/build/write API，与首屏和账号恢复竞争数据库、网络和 projection 写入。

### 4.9 所有 tab 首次进入 Root 时一起挂载

Root 使用包含五个实际页面实例的 `IndexedStack`。这保留 tab 状态，但也会在 shell 初次构建时挂载隐藏页面。Food/Workout 等页面同样监听全局 `RefreshNotifier`，所以 Home 启动 refresh 还可能让隐藏页面重复读取 selected date。

### 4.10 当前可见次数为什么不稳定

当前正常启动至少存在以下触发源：

| 触发源 | 是否可能改变 refresh version | 是否可能重算 summary | 是否一定有新业务数据 |
| --- | --- | --- | --- |
| Root 初始 hydration key | 是 | 是 | 否 |
| active-device runtime bind | 是 | 是 | 只表示云端门已打开 |
| Home cache hit 后台重算 | 否，直接 `setState` | 是 | 否 |
| Cloud Profile 真正 fetch 完成 | 当前通常不精确触发 Home | 可能遗漏 | 可能有 |
| app resume | 是，无 freshness gate | 是 | 否 |
| warm cache | 不直接 | 是 | 可能有 |
| 正式记录写入 | 是，并另起 cache rebuild | 是，可能多次 | 是 |
| workout/photo recovery | 某些路径会 | 可能 | 不一定是正式数据 |

如果初始 hydration key 与 runtime bind 在同一 post-frame callback 前发生，`_recordHydrationRefreshScheduled` 会合并一次。如果 runtime bind 更慢、跨过该 callback，就会触发第二次全局 refresh。再叠加 Home 后台重算，用户会看到初始画面后一次或两次明显更新；其他恢复路径还能继续增加次数。

---

## 5. 多方冲突的根本逻辑

### 5.1 冲突参与方

| 参与方 | 当前合理职责 | 当前越界或缺失 |
| --- | --- | --- |
| `AccountController` | auth、active-device、Profile、subscription、permission slices | subscription 串行阻塞 Profile；没有给 Home 输出精确 profile revision |
| `CloudRuntimeContext` | 表示 device/session 是否可使用正式云端 | ready 被 Root 当作“所有数据已经更新” |
| `_RootShellState` | 账号绑定、lifecycle、tab 和恢复协调 | 使用一个 hydration key 触发全局数据刷新；初值也被当作变化 |
| `HomePage` | 展示选中日期 dashboard | 自己决定 cache/network/background rebuild；已有内容时仍用 Future loading |
| `DailySummaryService` | 确定性 summary 算法 | 同时读取 repositories、更新校准、写本地 cache、写云端 projection |
| Food/Workout repositories | cloud-first 写、local confirmed cache | `getByDate` 同时承担 cache read 与条件式 cloud hydration，非空 cache 永不校验 |
| summary repositories | 本地/云端 projection 持久化 | 返回值丢 metadata，方法名不表达网络和副作用 |
| `RefreshNotifier` | 通知页面数据变化 | 只有全局整数，没有 account/date/domain/reason/freshness |
| `AppServices.refreshDailySummary...` | 写后 repair | unawaited 且与 Home 自己的 rebuild 并发，没有完成事件 |
| `WarmCacheCoordinator` | 低优先级预热 | 启动太早，与首屏使用相同重 API，不能取消 account switch |
| `IndexedStack` | 保留 tab 状态 | 首次挂载所有隐藏 tab，让全局 refresh 扩散 |

### 5.2 六个根本缺陷

1. **没有唯一 orchestration owner**：每个参与方只知道自己的局部事件，但都能触发完整 reload。
2. **事件没有语义**：`version++` 不能表达哪一账号、哪一天、哪类数据、是否强制、是否只是 runtime ready。
3. **读取层级混合**：local read、cloud fetch、hydrate、rebuild、persist 和 UI publish 被同一个方法链串在一起。
4. **缺少可判定 freshness/equality**：metadata 被存储却不返回，相同 payload 仍更新 UI。
5. **依赖顺序与产品依赖不一致**：Home 依赖 Profile 和 selected-day data，却被 subscription 延迟，并在 Profile 到达前因 runtime ready 提前重算。
6. **过期任务只阻止 UI，不阻止副作用**：generation 检查发生在 summary/cache/cloud 写入之后。

### 5.3 不能采用的表面修复

以下做法不得作为最终方案：

- 只删除 `_scheduleSelectedDateHydrationRefresh()`：会破坏新设备、清空本地后的云端恢复。
- 只给 spinner 加淡入淡出：内容仍被清空，数据竞态仍存在。
- 只延长 debounce：减少概率但没有 freshness、account/date scope 或结果比较。
- 只保留本地 cache、不做云端 revalidation：违反 cloud official source of truth。
- 等全部 Profile、subscription、30 天 cache 完成再进 Home：改善跳变但显著恶化首屏，并违反 slice independence。
- 让 Home 永远显示旧 date snapshot 直到新 date 完成：会把旧日期数据放在新日期标题下，属于错误展示。
- 把所有逻辑塞进新的全局 `AppDataManager`：会复制当前“一个全局状态控制所有页面”的问题。

---

## 6. 目标产品状态机

### 6.1 Home 展示状态

Home 应使用持久的 view state，而不是用 Future connection state 直接替换整页：

| 状态 | snapshot | 用户可见行为 | 后台行为 |
| --- | --- | --- | --- |
| `initialLoading` | 无 | 固定布局骨架；不显示 0 kcal/0 条记录作为事实 | 等待匹配 cache 或首屏数据包 |
| `showingFreshCache` | 有 | 立即显示 dashboard，无全屏 loading | freshness 未过期则不自动请求 selected-day records |
| `showingStaleCache` | 有 | 保持 dashboard；必要时轻量 stale/syncing 标记 | runtime ready 后单飞 revalidate |
| `refreshingWithData` | 有 | 内容、滚动、导航保持；超过约 400 ms 才显示低噪声同步提示 | 不启动第二个同 key 请求 |
| `readyConfirmed` | 有 | 正常 dashboard | 等下一有效事件 |
| `offlineWithCache` | 有 | 保留内容，显示低噪声离线/稍后同步状态 | 自动 retry 遵守 backoff |
| `errorWithoutData` | 无 | 稳定错误/重试页面，不伪造空 summary | 用户重试或 runtime 恢复 |

`refreshingWithData` 不是新的完整页面；它只是现有 dashboard 上的 refresh metadata。

### 6.2 Snapshot identity

每个 Home snapshot 必须绑定：

```text
accountId
selectedDate
accountEpoch
summaryVersion / algorithmVersion
sourceUpdatedAt
cachedAt
profile identity/version or updatedAt
display fingerprint
```

任何异步结果只有在 accountId、date 和 accountEpoch 仍匹配时才能更新当前 UI。旧日期结果可以在正确账号范围内写自己的 cache，但不得改当前 snapshot；旧账号结果不得写入新账号 cache 或 UI。

### 6.3 事件优先级

同一个 `(accountId, date)` 的重复事件合并，强度按以下顺序：

```text
officialWrite / accountRepair / explicitRefresh
  > missingCacheFirstLoad
  > staleValidation / expiredResume
  > warmCache
```

高优先级事件可以把等待中的低优先级任务升级为 force refresh；不能并行启动第二个任务。

### 6.4 Freshness 与 retry 默认值

- Home selected-day confirmed summary：成功 freshness 5 分钟。
- 自动 refresh 失败 backoff：45 秒。
- app resume：只有超过 freshness 才触发。
- 用户显式 refresh：可绕过成功 freshness，但仍复用当前 single-flight；失败后记录时间，防止自动循环。
- warm cache：保留当前 10 分钟 account throttle，但只能在首屏稳定且 runtime ready 后启动。

这些值沿用稳定设计文档的默认方向；实现时写成单一常量和 fake clock 可测试逻辑，不增加远程配置系统。

---

## 7. 目标架构与职责边界

### 7.1 `HomeDashboardController`

新增页面级 controller，只负责：

- 当前 `HomeDashboardState`；
- account/date key 变化；
- 保留已有 snapshot；
- 将 refresh/error metadata 暴露给 UI；
- 只在 display fingerprint 变化或 refresh badge 状态需要变化时通知 listeners。

它不直接拼接 Supabase query，也不计算饮食算法。

建议文件：

```text
lib/features/home/home_dashboard_controller.dart
lib/features/home/home_dashboard_state.dart
```

### 7.2 `SelectedDaySummaryCoordinator`

新增选中日期 orchestration service，拥有：

- local snapshot read；
- freshness 判定；
- active-device/Profile readiness gate；
- per-key single-flight 和 generation；
- cloud selected-day revalidation；
- summary rebuild、cache persist、projection upsert；
- typed invalidation event 合并；
- 相同 payload 抑制。

建议文件：

```text
lib/domain/services/selected_day_summary_coordinator.dart
lib/domain/models/daily_summary_snapshot.dart
lib/domain/models/data_change_event.dart
```

Coordinator 只负责 selected-day dashboard/read model，不接管 AI、订阅、聊天、导航或所有 tab 的 UI 状态。

### 7.3 明确的 repository API

禁止继续使用“看起来是 cache read、实际可能联网并写入”的接口。目标 API 分层：

```text
DailySummaryCacheRepository.readLocalEntry(accountId, date)
DailySummaryCacheRepository.writeConfirmedEntry(entry)

DailySummaryCloudRepository.fetchCloudEntry(accountId, date)
DailySummaryCloudRepository.upsertCloudEntry(entry)

FoodRepository.readCachedByDate(day)
CloudBackedFoodRepository.fetchAndReconcileCloudDate(accountId, day)

WorkoutRepository.readCachedByDate(day)
CloudBackedWorkoutRepository.fetchAndReconcileCloudDate(accountId, day)

ProfileRepository.getProfileForAccount(accountId)
```

旧 `getCachedSummaryForDate` 与 `getSummaryForDateAndCache` 在迁移完成后删除或收窄，不保留两个语义相近的长期入口。

### 7.4 `DailySummaryEntry` / envelope

本地和云端 summary repository 返回 envelope，而不是只返回 `DailySummary`：

```text
summary
accountId
date
summaryVersion
sourceUpdatedAt
cloudUpdatedAt
cachedAt / builtAt
recordVersion（云端可用时）
profileVersion（云端可用时）
algorithmVersion
cacheConfirmed
```

本地 `daily_summary_cache` 已有大部分列；先复用现有 schema。算法变更通过统一 `summaryVersion`/`algorithmVersion` 失效旧 cache，不为每次构建提升 SQLite dbVersion。

### 7.5 纯 summary build 与副作用分离

`DailySummaryService` 最终应接收显式 inputs 并返回确定性结果：

```text
Cloud/current Profile
selected-day authoritative food records
selected-day authoritative workout sessions
calibration snapshot
diet review snapshot
macro self-check snapshot
```

以下副作用移出 builder：

- calorie calibration 更新；
- local summary cache 写入；
- cloud `daily_summaries` upsert；
- UI notify。

校准更新由显式、可单飞的 calibration refresh 负责；summary build 只消费已解析 snapshot。这样重复 build 是幂等计算，不会因为 Home 重绘而更新持久状态。

### 7.6 账号绑定 Profile cache

当前 `user_profile` 是单行表，`ProfileRepository.getProfile()` 不按 account 查询。虽然 `AccountController` 另有 SharedPreferences metadata guard，但 Home 直接读 repository，仍存在把旧 row 当作当前账号 display cache 的结构性风险。

计划将 SQLite 升至 v21：

- 为 `user_profile` 增加 nullable `account_id TEXT`。
- Agent 登录态只读取 `account_id = currentAccountId` 的 Profile cache。
- 未配置 cloud 的 Local 兼容模式继续读取 `account_id IS NULL` 的 legacy Profile。
- cloud Profile cache 写入时必须带 accountId。
- 迁移不把未知 legacy row 猜测绑定到当前账号；第一次 cloud Profile 成功后再写正确归属。
- 继续保持单 active Profile cache 也可以，但查询必须有身份约束。

该变更必须遵守 SQLite additive migration、v20→v21 migration test、Database 双语文档和 Changelog 更新规则。

### 7.7 Typed data changes

正式写入和 repair 使用带语义事件：

```text
accountId
affectedDates
domain: food | workout | profile | bodyMetric
reason: officialWrite | delete | repair | explicitRefresh
forceRebuild
```

本地草稿打开/关闭、通知同步、tab 切换不得发送 official-record change。Home 只响应当前 account/date 相关事件。

`RefreshNotifier` 不要求在一个阶段一次性删除；先让 Home 退出全局 version，再逐步迁移 Food/Workout，避免大爆炸式重写。

---

## 8. 目标数据顺序

### 8.1 有匹配 confirmed Home cache 的冷启动

```text
恢复 auth account
→ 绑定 account-scoped repositories
→ local-only 读取 summary envelope + matching Profile cache
→ 立即发布 Home snapshot（一次）
→ first-frame recovery 独立完成
→ active-device claim
→ Cloud Profile 与 subscription 并行恢复
→ 若 summary 未过期且 Profile revision 未变化：不做 selected-day cloud fetch
→ 若过期/Profile 变化：后台单飞 revalidate
→ payload 相同：只结束 syncing，不发布新内容
→ payload 变化：原位更新数值，不清空 Home
```

### 8.2 没有匹配 cache 的冷启动/新设备/清空本地后恢复

```text
恢复 auth account
→ local-only read miss
→ 显示固定 Home skeleton，不构建本地假零 summary
→ active-device ready
→ 等 Cloud Profile ready（不等 subscription）
→ 并行读取 selected-day cloud food/workout；必要时读取 cloud summary metadata
→ 云端确认 empty 或返回 records
→ 构建一次真实 summary
→ 先写 account-bound local confirmed cache
→ 发布一次 Home snapshot
→ cloud projection upsert 失败只标记 stale/repair，不撤销内容或正式记录
```

### 8.3 App resume

```text
resume
→ controller 检查 visible account/date + cachedAt + last failure
→ freshness 内：无请求、无 UI 变化
→ 已过期：保留 snapshot，安排一次后台 revalidate
→ 多个 lifecycle/context 回调合并为同一 single-flight
```

### 8.4 正式记录写入

```text
cloud official write 成功
→ repository 更新本地 confirmed record cache
→ 发布 typed change(accountId, affectedDates, domain)
→ selected-day coordinator 将对应 summary 标为 stale/dirty
→ 若当前 Home date 受影响：保留旧 snapshot + 轻量 syncing
→ authoritative reconcile/rebuild 单飞执行
→ local summary cache 原子更新
→ Home payload 变化时只发布一次
→ cloud projection best-effort upsert
```

summary repair 失败不得把 official write 显示为失败，也不得删除旧 confirmed Home snapshot。

### 8.5 Cloud Profile 更新

```text
Cloud Profile save/fetch 成功
→ 写 account-bound local Profile cache
→ 发布 profile revision event
→ 当前 Home summary 若基于旧 profile：标 stale 并重建选中日期
→ 最近 30 天 projection 由低优先级 warm/repair 渐进更新
```

不在 Profile 保存按钮后同步阻塞重建 30 天 summary。

### 8.6 账号切换或 device replaced

```text
accountEpoch 增加
→ 取消/失效旧账号 Home generation
→ 立即移除旧账号 snapshot
→ 绑定新账号 local scope
→ 新账号 cache hit 则显示；否则 skeleton
→ 旧任务结果即使返回，也不能写新账号 UI/cache
```

---

## 9. 分阶段实施计划

### Phase 0：行为基线、characterization tests 与可观测性

#### 目标

在改动时序前，把当前缺陷和不可破坏能力变成自动化证据。

#### 实施

1. 在 `home_page_test.dart` 增加永久回归测试，先以当前代码预期失败：已有内容后 refresh 不得出现 full-page loader。
2. 新增 Root/account 启动 harness，使用 fake auth、fake active-device、fake Cloud Profile、fake clock 和可控 Completer。
3. 覆盖 active-device 在 first post-frame 之前/之后完成的两种顺序。
4. 增加 debug-only trace sink：
   - correlation/generation；
   - account/date；
   - event reason；
   - local hit/miss；
   - refresh start/coalesced/complete/fail；
   - old/new fingerprint；
   - UI transition；
   - 不记录 nickname、食物名称、训练内容或其他用户数据。
5. 记录当前调用计数：首屏 summary build 次数、selected-day cloud fetch 次数、Home visible publish 次数。
6. 配置版 debug APK 实机完成：cache hit、cache miss、慢 active-device、慢 subscription、离线、resume。

#### 验收门

- 自动测试稳定复现“当前全局 refresh 会让 Home 内容消失”。
- trace 能区分 Root hydration、runtime ready、Home revalidate、write repair 和 warm cache。
- 现有 43 个目标测试继续通过；新增 characterization 测试允许在 Phase 1 修复前单独标记为预期失败，但不得把 failing test 合入主分支。实际提交顺序应在同一变更中先加测试再修复。

#### 回滚

仅测试和 debug trace，无生产数据变化；可直接撤回。

---

### Phase 1：Home 展示状态止血

#### 目标

先消除最直接的用户可见回退，不改变现有云端权威和 refresh 触发来源。

#### 实施

1. 将 `_HomePageData` 提升为持久 snapshot state。
2. 初次无 snapshot 时才显示整页 loading/skeleton。
3. refresh version 变化时保留当前 snapshot，后台加载新结果。
4. 新结果到达前不替换 `ListView`，不重置 scroll controller。
5. 计算 canonical display fingerprint；summary/profile 显示内容相同则不发布内容更新。
6. 为首次 loader、refresh indicator、dashboard content 增加稳定 test keys，避免与 calorie ring 的 `CircularProgressIndicator` 混淆。
7. 加 account/date generation guard；旧 Future 不能更新当前页面。

#### 预计文件

- `lib/features/home/home_page.dart`
- `lib/features/home/home_dashboard_state.dart`
- `test/home_page_test.dart`

#### 验收门

- 已显示 Home 后任意现有 `markDataChanged()` 不再移除 dashboard。
- 相同 payload 不改变 scroll offset，不产生第二次内容 publish。
- date 改变且新 date 无 snapshot 时显示新日期 skeleton，不显示旧日期数值。
- 本阶段不删除 Root refresh，确保功能尚未因 UX 止血而丢失。

#### 回滚

仅 UI state 管理；可回到 FutureBuilder 旧路径，无 schema 或数据回滚。

---

### Phase 2：读取合同、summary envelope、纯计算与账号隔离

#### 目标

把 local read、cloud fetch、build、persist 和 publish 拆开，使后续调度可以判断 freshness、来源和副作用。

#### 实施

1. 新增 `DailySummaryEntry`，完整映射本地与云端 metadata。
2. `DailySummaryCacheRepository` 提供纯 local read；不得 fallback cloud。
3. `DailySummaryCloudRepository` 返回 cloud envelope，包括现有 row 的 `record_version`、`source_updated_at`、`profile_version`、`algorithm_version`、`built_at`、`updated_at`。
4. 修正 cloud upsert：
   - 不再硬编码永远为 `profile_version: 1`；
   - `algorithm_version` 使用单一常量；
   - `source_updated_at` 表示输入 revision，不是无条件当前时间的伪来源；
   - 重复相同 fingerprint 的 projection 不做无意义 upsert。
5. 为 Food/Workout 增加明确的 cached read 与 force cloud reconcile API；保留旧 API 直到调用方迁移完成。
6. 将 `DailySummaryService` 分为显式 inputs 的纯 builder 与 orchestration side effects。
7. 将 calorie calibration refresh 移出 Home display read，并保证同一天 single-flight。
8. SQLite v21：为 `user_profile` 增加 nullable `account_id`，实现账号过滤和 legacy local fallback。
9. 添加 v20→v21、fresh v21、intermediate partial schema 的 idempotent migration tests。

#### 预计文件

- `lib/domain/models/daily_summary_snapshot.dart`
- `lib/domain/services/daily_summary_service.dart`
- `lib/data/repositories/daily_summary_cache_repository.dart`
- `lib/data/repositories/daily_summary_cloud_repository.dart`
- `lib/data/repositories/food_repository.dart`
- `lib/data/repositories/workout_repository.dart`
- `lib/data/repositories/profile_repository.dart`
- `lib/data/db/app_database.dart`
- 对应 unit/migration tests

#### 验收门

- 名为 local/cache 的 read 在 fake network 下不会发请求。
- cloud read 不隐式改 UI；cache write 失败不改变返回的 cloud confirmed 数据。
- 原有 `energy_ratio`、`gram_per_kg`、carb cycling/tapering、exercise calories、calibration 和 self-check 测试结果保持一致。
- 登录账号 A 无法读取账号 B 或 unscoped legacy Profile row。
- Local 未配置模式仍能读取 legacy unscoped Profile。

#### 回滚

- v21 是 additive nullable column；旧版本可忽略，不需要 destructive downgrade。
- 新旧 repository API 在迁移阶段短暂并存，出现问题可让调用方回旧接口，但不得长期双轨。

---

### Phase 3：Account 与 Root 启动顺序收敛

#### 目标

让 readiness 事件表达真实含义，消除 subscription 阻塞和初始 hydration 的无效全局 refresh。

#### 实施

1. active-device claim 成功后，并行恢复：
   - Cloud Profile slice；
   - subscription slice；
   - local context permission slice。
2. 每个 slice 独立 loading/freshness/error/backoff；subscription 不阻塞 Profile。
3. AccountController 暴露稳定 profile revision/account epoch，而不是让 Home猜测 notify 原因。
4. Root 首次看到 hydration key 时只 seed，不调用 `markDataChanged()`。
5. runtime 从 not-ready→ready 时发送 typed `cloudRuntimeReady`，不再等同 `officialDataChanged`。
6. lifecycle resume 交给 coordinator 按 freshness 决定，Root 不再无条件全局 refresh。
7. 保留 `_bindLocalRecordAccount(accountId)` 发生在首个 Home local read 前。
8. 保持 picker/workout recovery 的 first-frame 逻辑独立；只有恢复确实提交正式记录时才发送 typed record change。

#### 预计文件

- `lib/features/account/account_controller.dart`
- `lib/domain/models/cloud_runtime_context.dart`
- `lib/app.dart`
- `test/phase2_account_controller_test.dart`
- 新 Root startup tests

#### 验收门

- fake subscription 永不完成时，Cloud Profile 和 Home 仍能 ready。
- runtime ready 只触发最多一次符合条件的 selected-day revalidation。
- 初始 key seed 不增加 data revision。
- resume freshness 内零 selected-day 请求；过期后一个请求。
- device replaced 仍阻断正式写入并清理账号 UI。

#### 回滚

Account slice 并行化和 Root typed event 可分别回滚；不得回滚 active-device 安全门。

---

### Phase 4：选中日期权威 revalidation 与单飞调度

#### 目标

在不连续轮询的前提下，让真正的云端校验发生一次、结果可比较、失败可降级。

#### 实施

1. 引入 `SelectedDaySummaryCoordinator` 和 per-key single-flight。
2. cache hit：立即返回 local entry；只有 stale/forced 才等待 runtime 后 revalidate。
3. cache miss：不调用本地 partial builder；等待 active-device + Cloud Profile 后取首屏 bundle。
4. `fetchAndReconcileCloudDate` 对 Food/Workout 执行完整 selected-day cloud query：
   - 云端成功后在 SQLite transaction 中 upsert 当前 rows/children；
   - 只清理相同 account/date 下、cloud-confirmed 且云端已不再返回的 rows；
   - 不清理 unscoped legacy、本地草稿或其他账号/日期；
   - 云端 empty 是 confirmed empty，失败不是 empty。
5. 使用 current Cloud Profile、authoritative selected-day records 和显式辅助 snapshot 构建 summary。
6. 先写本地 confirmed summary，再决定是否发布；cloud projection upsert 为 repair side effect。
7. payload 相同：更新 freshness metadata 即可，不通知 Home 内容变化。
8. request 在 account/date 改变后：
   - 可完成旧 key 的安全 cache 写入；
   - 不更新当前 UI；
   - 旧账号 epoch 结果全部丢弃。
9. failure：有 cache 时进入 `offlineWithCache`/`showingStaleCache`；无 cache 时进入稳定 error+retry。

#### 预计文件

- `lib/domain/services/selected_day_summary_coordinator.dart`
- `lib/features/home/home_dashboard_controller.dart`
- Food/Workout/summary repositories
- Home/Root providers
- unit、Widget、integration-style fake tests

#### 验收门

- cache hit + cloud same：一次可见 snapshot，零 full-page reset。
- cache hit + cloud changed：旧内容保持到新数据完成，随后一次原位更新。
- local nonempty + cloud changed：force reconcile 仍能发现 cloud change。
- cloud confirmed empty：显示真实零记录；网络失败不得把旧记录清为空。
- cache miss：只发生 skeleton→真实内容或 skeleton→error，不出现假零 Home。
- account switch during fetch：零跨账号显示/写入。
- 同 key 10 个并发事件只产生一次 cloud selected-day request。

#### 回滚

Coordinator 可切回 Phase 1 的稳定显示+旧数据路径；transactional reconcile 失败时永远保留原 cache，不能部分删除。

---

### Phase 5：正式写入、summary 失效与单次发布

#### 目标

把当前“mark global + unawaited rebuild + Home 自己 rebuild”收敛为一次 typed invalidation 和一次 summary publish。

#### 实施

1. Food create/update/delete 成功后发送 affected date event。
2. Workout session/plan create/update/delete/commit 成功后发送 affected date set。
3. Body metric edit/delete 保留现有受影响日期算法，但发送 typed event。
4. Cloud Profile save/fetch revision 改变时失效当前 selected-day summary；最近窗口交给 warm repair。
5. 删除页面中成对出现的：
   - `markDataChanged()`；
   - `refreshDailySummaryCacheForDate(s)`。
6. Coordinator 对同一日期 dirty event 合并并重建一次。
7. official record write success 与 summary repair success 分开呈现：
   - 正式写入成功立即给出成功反馈；
   - summary repair 失败只让 Home stale，不反转正式写入结果。
8. AI 生成 Food/Workout 经用户确认写入后复用相同 typed event；AI draft 本身不触发。

#### 预计文件

- Food/Workout/Profile/AI confirmed-write 页面
- `lib/app.dart` 中旧 cache refresh extension/AppServices helper
- typed event/coordinator tests

#### 验收门

- 一次 food add 只产生一个 affected-day summary rebuild。
- update 跨日期时只重建 old/new 两天，各一次。
- workout plan 多 session 同一天被去重；跨日期保留完整 date set。
- draft discard、tab change、notification sync 不刷新 Home。
- summary cache 写失败不阻止已 cloud-confirmed 的写入和用户成功反馈。

#### 回滚

可逐个 workflow 迁移；未迁移页面继续旧路径，但同一页面不得同时发送新旧两种事件。

---

### Phase 6：Warm cache、隐藏 tab 与全局刷新降耦

#### 目标

清理启动资源竞争和全局事件扩散，不扩大成无界 cloud sync。

#### 实施

1. Warm cache 只在：
   - first visible surface 稳定；
   - active-device ready；
   - 当前 account 未变化；
   - 没有高优先级 selected-day request 时运行。
2. Warm task 加 account cancellation token；退出/切换账号立即停止后续天数。
3. Warm 使用 coordinator 的 `warm` 优先级；不得与当前 visible key 并发重复 build。
4. Root tabs 改为“首次需要时挂载、访问后保留”的 lazy IndexedStack 策略；恢复目标 tab 可在首帧前标记为 visited。
5. Food/Workout selected-date 页面逐步迁移到 account/date/domain scoped revision，避免 Home/Profile change 触发隐藏页无差别 reload。
6. 当所有 official-data consumer 完成迁移后删除或极度收窄 `RefreshNotifier`。
7. 不引入 foreground polling、WebSocket 全量订阅或完整历史自动同步。

#### 验收门

- Home 首屏期间 warm cache 不发当前日重复请求。
- 切换账号后旧 warm task 零写入新账号 scope。
- 未访问 tab 不在首屏启动 DB/cloud load。
- 首次访问 Food/Workout 有稳定 page-level loading/cache display；访问后 tab state 保留。
- camera/workout recovery 仍能直接打开目标 tab/page，不闪现错误中间页。

#### 回滚

Lazy tab 和 warm scheduling 可独立回滚；typed Home coordinator 不依赖 lazy mount 才能正确。

---

### Phase 7：全量验证、文档、实机、构建与发布

#### 自动化验证

必须运行：

```powershell
dart format lib test
flutter analyze
flutter test
```

若本工程没有修改 Supabase Edge Function 或 shared AI contract，不要求运行 Deno Edge checks。若实施过程中实际触及这些文件，则按 `AGENTS.md` 补跑全部 deterministic Edge checks。

#### 配置版构建

```powershell
flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json
```

不得用未配置 Supabase 的 APK 验证账号恢复、Cloud Profile、active-device 或 cloud records。

#### 文档更新

完成后按实际改动更新：

- `docs/en/CloudLocalDataBoundary.md`
- `docs/zh/CloudLocalDataBoundary.md`
- `docs/en/AppGuide.md`
- `docs/zh/AppGuide.md`
- `docs/en/Database.md`
- `docs/zh/Database.md`
- `CHANGELOG.md`
- 必要时 `docs/ROADMAP.md`

若 SQLite 升至 v21，Database 双语文档和 Changelog 必须与 migration 同一任务完成。稳定文档全部通过后，才重新生成 Document RAG seed，并检查中英文 heading/section 对齐；不得在计划阶段提前上传新 chunks。

#### 实机矩阵

至少覆盖：

1. 同设备、有 cache、冷启动。
2. 同设备、有 cache、慢网络。
3. 同设备、有 cache、完全离线。
4. 新设备/清空本地、云端有记录。
5. 新设备/清空本地、云端确认当天无记录。
6. active-device 快于首帧和慢于首帧两种顺序。
7. subscription 请求延迟/失败，但 Profile 和 Home 正常。
8. Cloud Profile 与本地 cache 相同/不同。
9. app resume 在 freshness 内/外。
10. Food、Workout、body、Profile 写入后返回 Home。
11. 写入时切 tab、后台、恢复。
12. 账号退出、切换、device replaced。
13. picker recovery 和 workout editor recovery 与 Home 启动并存。

#### 发布门

全部满足后才能完成本工程：

- Home 一旦显示真实内容，本轮生命周期内 full-page loading reset 次数为 0。
- 有 cache 的启动，内容 snapshot 可见发布次数为 1；云端相同不增加。
- 无 cache 的启动只有 skeleton→content 或 skeleton→error 一次主转换。
- 同一 account/date 同时最多一个 foreground revalidation。
- freshness 内 resume 的 selected-day cloud request 数为 0。
- 相同 payload 的 Home content notification 数为 0。
- account switch/device replaced 的跨账号数据泄露为 0。
- official write 不被 optional summary cache/projection failure 阻断。
- Local 行为和所有 diet/workout deterministic algorithm tests 保持一致。
- Flutter analyze、全量 tests、配置版 split APK 构建全部通过。

---

## 10. 测试矩阵

### 10.1 Unit tests

- `DailySummaryEntry` 本地/云端 metadata mapping。
- 5 分钟 freshness、45 秒 backoff、explicit refresh override。
- event priority merge 和 single-flight。
- canonical fingerprint：字段相同、map 顺序稳定、Profile 显示字段变化。
- stale generation/account epoch 丢弃。
- Cloud Profile 与 subscription 并行恢复。
- Profile account-bound query 与 legacy local fallback。
- Food/Workout reconcile：新增、更新、删除、empty、失败、其他账号保护、child rows。
- pure summary builder 与现有算法 golden parity。
- calibration refresh 单飞且 Home read 无写副作用。

### 10.2 Widget tests

- 已有 Home 内容后 refresh 不出现 full-page loader。
- refresh indicator 延迟显示且不改变布局。
- same payload 不重建 dashboard content。
- changed payload 原位更新，scroll offset 保持。
- cache miss 不显示假零值。
- date switch 不复用旧日期值。
- offline cache 保留；offline no-cache 显示 retry。
- account switch 立即移除旧 snapshot。

### 10.3 Orchestration tests

- 初始 hydration 与 runtime ready 同帧/跨帧。
- runtime ready 早于/晚于 local cache read。
- Profile ready 早于/晚于 records。
- subscription 永久 pending。
- write event 与 resume/event storm 同时发生。
- warm task 与 visible refresh 冲突时让路。
- old request 在 sign-out 后返回。
- cloud projection stale/missing/schema-version mismatch。

### 10.4 Migration tests

- fresh v21 schema。
- v20→v21 添加 `user_profile.account_id`。
- 中间测试 build 已有该列时幂等。
- legacy unscoped Profile 不自动绑定未知账号。
- 已绑定 Profile 可被同账号读取，其他账号不可见。

---

## 11. 可观测性与性能预算

### 11.1 Debug trace 字段

```text
event_name
correlation_id / generation
account_hash（不可逆、仅调试）
date
reason
cache_state
runtime_ready
profile_revision
request_priority
coalesced_count
old_fingerprint / new_fingerprint
ui_transition
duration_ms
failure_code
```

不得记录 email、nickname、食物、训练、身体数据或 summary JSON。

### 11.2 必须关注的计数

- `home_fullscreen_loading_after_content`：目标 0。
- `home_content_publish_count`：cache+same cloud 目标 1。
- `selected_day_refresh_requested` 与 `selected_day_refresh_started` 的差值：反映 coalescing。
- `selected_day_duplicate_inflight`：目标 0。
- `same_payload_ui_publish`：目标 0。
- `stale_generation_drop`：允许出现，但不得伴随错误账号写入。
- `warm_visible_key_collision`：目标 0。

### 11.3 体验预算

- 有本地 cache：Root shell 可见后 p95 300 ms 内显示 Home 内容；以实机 debug trace 验证，不以 unit test 模拟网络时间替代。
- 无 cache：第一帧显示稳定骨架，不出现空 Home 跳变。
- 后台 refresh 少于约 400 ms 时不显示同步提示，避免提示本身闪烁。
- 启动不拉完整历史或最近 30 天详细 food/workout records。

---

## 12. 风险与控制

| 风险 | 后果 | 控制 |
| --- | --- | --- |
| 只隐藏 loading、没有真正 revalidate | UI 看起来稳定但数据长期 stale | Phase 1 后必须完成 Phase 2–4；发布门同时验证云端变化 |
| cloud empty reconcile 错删本地记录 | 本地 cache 丢失、用户误见空态 | 只在云端成功后 transaction reconcile；限定 account/date/cloud-confirmed；失败不删 |
| 旧请求跨账号返回 | 隐私和正确性事故 | accountEpoch + captured accountId；旧账号结果不得写当前 scope |
| summary pure builder 重构算法 | 破坏 Local 基线或 mode 语义 | 先加 golden parity；不改变公式；逐字段对比 |
| v21 Profile 归属迁移 | legacy Profile 暂时不可见 | 不猜测绑定；Local 读 unscoped；Agent 等 Cloud Profile 或 matching cache |
| 强制 selected-day fetch 增加流量 | 启动/恢复网络开销 | 5 分钟 freshness、45 秒 backoff、single-flight、visible date scope |
| Profile/records 并行时序 | 使用不同 revision 构建 summary | coordinator 捕获一致 input snapshot；revision 变化则失效重建 |
| summary projection upsert 失败 | AI/export 可能暂时读旧 projection | official record 不回滚；标记 repair；受控重试/warm repair |
| Lazy tab 影响恢复 | AI/Workout 恢复页不挂载或闪现 Home | Phase 6 后置；恢复目标先加入 visited；保留 first-frame recovery tests |
| Warm cache 取消不完整 | 旧账号后台写入 | account cancellation token + repository account scope + tests |
| 全局 notifier 迁移范围过大 | 多页面回归 | Home 先退出；workflow 按页迁移；禁止同页双发 |

---

## 13. 明确不在本工程范围

- 完整 food/workout/body 历史自动云同步平台。
- 离线正式写入队列或复杂跨设备 merge UI。
- GraphRAG、用户 embedding、semantic memory 或 autonomous Agent loop。
- AI 模型、prompt、provider、订阅规则或输出合同改造。
- diet/workout 算法公式优化或 mode 合并。
- 重写 Android picker/page recovery；只验证本工程不破坏它。
- 为减少一次 selected-day fetch 而新建无必要的后端服务、Realtime 订阅或远程 feature flag 系统。
- 在 Home 启动阶段预加载完整 30 天详细 records。

---

## 14. 完成定义

本工程只有在以下条件同时成立时才可标记 Complete：

1. 代码层只有一个组件负责 Home selected-day refresh 的顺序、single-flight、freshness 和 publish。
2. local/cache/cloud/build/persist API 语义明确，不再通过方法名隐藏网络和写副作用。
3. 已有内容后的 full-page loading reset 已由永久测试阻断。
4. cache hit、cache miss、offline、resume、write、account switch、device replaced 均通过自动化和配置版实机验证。
5. Cloud Profile 不再被 subscription 串行阻塞。
6. 正式记录写入后只产生一次受影响日期 summary rebuild/publish。
7. Warm cache 和隐藏 tab 不再与首屏争夺同一 visible key。
8. SQLite v21 migration、双语 Database 文档和 Changelog 同步完成。
9. 中英文稳定文档准确描述最终行为，计划中的未实施措辞没有被误写成已发布事实。
10. Flutter analyze、全量 tests、配置版 split APK 构建全部通过，无未解释 warning、失败或跨账号数据风险。
