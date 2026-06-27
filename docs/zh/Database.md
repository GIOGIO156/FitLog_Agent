# 数据库设计

## 目标

本文定义 FitLog_Agent V1 的 schema、migration、表、字段和存储概念。云端/本地权威、cache-first 读取、写入成功标准、刷新、异常、冲突和修复规则统一定义在 `CloudLocalDataBoundary.md`。

当前复制来的源码使用 FitLog Local 的 SQLite schema 保存业务记录。Phase 2 新增基于 Supabase 的账号、订阅状态和 Cloud Profile 基础。Phase 3 Cloud Records Foundation 已落地 root auth gate、单 active device、Cloud Records 表、body/food/workout 云端写入守卫、账号绑定的本地 cache 元数据、cloud-backed body/food/workout repository、Home stale-while-revalidate 所需的选中日期 daily summary 本地 cache、App 侧 `daily_summaries` 云端 upsert/恢复、受控的近期 summary warm cache，以及 confirmed cache 淘汰。登录后正式记录以云端为权威；本地 SQLite 降级为 partial cache、草稿和运行期加速层。后续 AI Gateway、RAG 和 Food Draft 都应基于云端正式记录或 summary builder，而不是本地完整 SQLite。

## 存储总览

| 存储 | 用途 | 当前状态 |
| --- | --- | --- |
| SQLite / `sqflite` | 本地 profile/cache、校准、策略复盘、自定义动作、训练草稿、账号绑定 confirmed read model、选中日期 `daily_summary_cache` 和 partial cache。 | Local 基线已实现；Phase 3 schema v15 承载 cloud/cache 元数据和选中日期 summary cache。 |
| Supabase Cloud Records | `body_metric_logs`、`food_records`/`food_items`、`workout_sessions`/`workout_sets`、`daily_summaries`。 | Phase 3 migration 已新增；body/food/workout 读写和 daily summary upsert/恢复已接入 cloud-backed repository。 |
| SharedPreferences | UI 语言偏好、本地主题偏好、轻量 app 偏好、按账号保存的用户记录摘要授权、Cloud Profile 展示缓存，以及 Supabase 注册验证码所需的 PKCE verifier 状态。 | Local 基线和 Phase 2 账号基础已实现；auth verifier 和 theme key 是本机运行期/展示状态，不是业务记录同步。 |
| 本地文件 | App documents directory 中的 XLSX 和 CSV ZIP 导出。 | Local 基线已实现。 |
| 云端数据库 | Supabase Auth 账号身份、订阅 entitlement rows、Cloud Profile，以及后续 AI chats/request logs/最终回答/debug summaries。 | Phase 2 migration 已新增 `subscriptions` 和 `cloud_profiles`；后续 AI 表仍是计划。 |
| AI 文档索引 | 面向 Document RAG 的可检索 App 文档块。 | Agent V1 计划。 |
| In-memory providers | 选中日期、刷新版本、App services、语言状态、运行时摘要。 | Local 基线已实现。 |

当前本地数据库名：`fitlog_local.db`。

当前本地 SQLite schema version：`15`。

Foreign keys 启用方式：

```sql
PRAGMA foreign_keys = ON
```

## 迁移策略

本地迁移必须保持加法和兼容。

| Version | Change |
| ---: | --- |
| 1 | 初始 profile、food、workout、set 表。 |
| 2 | 新增 `workout_sessions.plan_id`。 |
| 3 | 新增 profile macro ratio 字段：`protein_ratio_percent`、`carbs_ratio_percent`、`fat_ratio_percent`。 |
| 4 | 新增 `user_weight_logs` 和 `calorie_calibration_state`。 |
| 5 | 新增 `diet_calculation_mode`、`training_frequency_per_week` 和 macro self-check 字段。 |
| 6 | 新增 `user_profile.diet_goal_phase TEXT NOT NULL DEFAULT 'cutting'`。 |
| 7 | 新增饮食策略 profile 字段和 `diet_adjustment_reviews`。 |
| 8 | 新增 `workout_sessions.record_name`。 |
| 9 | 新增本地 `user_profile.nickname`。 |
| 10 | 新增 `workout_record_drafts`。 |
| 11 | 新增 `custom_exercises`、动作快照、有氧强度 metadata、workout set 原始值与计算值字段。 |
| 12 | 在 `user_profile` 新增体脂和腰围字段，并在 `user_weight_logs` 新增账号作用域和身体指标字段。 |
| 13 | 为 food/workout/body 本地 cache 增加 `account_id`、`cloud_id`、`record_version`、`cloud_updated_at`、`deleted_at`、`cache_confirmed`、`cached_at` 等云端 confirmed read model 元数据，并新增 `daily_summary_cache`。 |
| 14 | 重新运行幂等的 Phase 3 cache 补列迁移，让安装过中间 v13 测试包的设备无需清除本地数据也能补齐 cloud/cache 字段。 |
| 15 | 新增幂等的 `daily_summary_cache` 修复迁移，用于给安装过中间 v14 测试包的设备补齐选中日期 summary JSON cache 字段、唯一索引，并确保 cache 写入失败不阻断首页实时 summary。 |

兼容规则：

- 不因为当前 schema 改变就重写旧迁移。
- 优先新增字段和表。
- 保留已有用户数据。
- `daily_energy_goal_type` 为兼容字段继续保留。
- `diet_goal_phase` 是 cutting/bulking 的来源。
- 不合并 `energy_ratio` 和 `gram_per_kg` 的存储语义。

## 本地表

### `user_profile`

用途：Local singleton profile、饮食设置、策略设置和 self-check 设置。当前 repository 使用 `id = 1`。

重要字段：

| Field | Meaning |
| --- | --- |
| `id` | Singleton profile id。 |
| `nickname` | 复制来的 Local 实现中的本地 UI 昵称。Agent V1 中账号展示名属于 Cloud Profile。 |
| `age` | BMR 和未成年人保护。 |
| `height_cm` | BMR 输入。 |
| `weight_kg` | BMR、g/kg macro、训练热量和体重记录来源。 |
| `body_fat_percent` | 可选当前体脂百分比。登录后保存到 Cloud Profile。 |
| `waist_cm` | 可选当前腰围。登录后保存到 Cloud Profile。 |
| `sex_for_formula` | `male`、`female` 或 `prefer_not_to_say`。 |
| `activity_level` | 由 `training_frequency_per_week` 派生的兼容/导出 tier。 |
| `daily_energy_goal_type` | 兼容字段：`maintenance`、`deficit` 或 `surplus`。 |
| `daily_energy_goal_kcal` | 根据阶段解释为 deficit 或 surplus。 |
| `protein_ratio_percent` | `energy_ratio` protein 百分比。 |
| `carbs_ratio_percent` | `energy_ratio` carbs 百分比。 |
| `fat_ratio_percent` | `energy_ratio` fat 百分比。 |
| `diet_goal_phase` | `cutting` 或 `bulking`；阶段来源。 |
| `diet_calculation_mode` | `energy_ratio` 或 `gram_per_kg`。 |
| `diet_plan_strategy` | `none`、`carb_cycling` 或 `carb_tapering`。 |
| `carb_cycle_pattern_json` | 每周 high/medium/low day 映射。 |
| `carb_cycle_high_multiplier` | High day 碳水 multiplier。 |
| `carb_cycle_medium_multiplier` | Medium day 碳水 multiplier。 |
| `carb_cycle_low_multiplier` | Low day 碳水 multiplier。 |
| `carb_taper_review_period_days` | 7/14/21/28 复盘窗口。 |
| `carb_taper_target_loss_pct_per_week` | taper review 的目标周减重率。 |
| `carb_taper_step_g` | 碳水调整步长。 |
| `carb_taper_current_delta_g` | 相对 base carbs 的累计碳水偏移。 |
| `last_carb_taper_review_at` | 最近复盘日期/时间。 |
| `training_frequency_per_week` | 共享 2/3/4/5 设置，用于 g/kg 表、`energy_ratio` fallback 和 self-check。 |
| `macro_self_check_period_days` | 7/14/21/28 self-check 窗口。 |
| `macro_self_check_enabled` | 0/1 boolean。 |
| `last_macro_self_check_at` | self-check 冷却日期/时间。 |
| `created_at`, `updated_at` | ISO 时间戳。 |

Agent V1 说明：登录后 Cloud Profile 成为权威版本。Local `user_profile` 可以作为兼容、缓存或迁移表保留，但正式账号绑定 Profile 修改应保存到云端。

### `food_records`

用途：餐级正式饮食记录。

重要字段：

| Field | Meaning |
| --- | --- |
| `id` | 本地记录 id。 |
| `date` | `yyyy-MM-dd`。 |
| `meal_name` | 餐名。 |
| `total_weight_g` | 总估算重量。 |
| `calories_kcal` | 餐级 kcal。 |
| `protein_g` | 蛋白质克数。 |
| `carbs_g` | 碳水克数。 |
| `fat_g` | 脂肪克数。 |
| `confidence` | 可用时的估算置信度。 |
| `estimation_notes` | 估算或用户备注。 |
| `source` | `manual`、`ai_paste` 以及未来确认后的 AI draft 来源值。 |
| `created_at`, `updated_at` | ISO 时间戳。 |

V1 边界：正式行只有用户确认后才写入。AI Chat 先创建草稿。

### `food_items`

用途：一餐中的 item 行。

重要字段：

| Field | Meaning |
| --- | --- |
| `id` | Item id。 |
| `food_record_id` | 父级 `food_records.id`，级联删除。 |
| `name` | 食物名称。 |
| `estimated_weight_g` | 估算重量。 |
| `calories_kcal` | item kcal。 |
| `protein_g` | protein 克数。 |
| `carbs_g` | carbs 克数。 |
| `fat_g` | fat 克数。 |
| `notes` | 可选备注。 |

### `workout_sessions`

用途：已保存的单个动作 session。多动作训练记录通过多行共享 `plan_id` 表示。

重要字段：

| Field | Meaning |
| --- | --- |
| `id` | Session id。 |
| `plan_id` | 训练记录 group id。 |
| `record_name` | 用户可见训练记录名称。 |
| `date` | `yyyy-MM-dd`。 |
| `body_part`, `secondary_body_part` | 动作分类 metadata。 |
| `exercise_name`, `exercise_key`, `exercise_source` | 保存时的动作身份。 |
| `exercise_type` | `strength` 或 `cardio`。 |
| `duration_minutes` | 单动作时长。 |
| `intensity` | 旧版兼容强度字段。 |
| `strength_profile` | 保存时的力量热量 profile。 |
| `load_input_mode`, `reps_input_mode`, `set_metric_type` | 保存时的力量输入语义。 |
| `cardio_met`, `cardio_intensity_basis`, `cardio_active_minutes` | 保存时的有氧计算 metadata。 |
| `body_weight_kg_at_calculation` | 计算训练热量时使用的体重。 |
| `exercise_snapshot_json` | 保存时动作 metadata 快照。 |
| `estimated_calories` | 保存的净运动 kcal。 |
| `notes` | 用户备注。 |
| `created_at`, `updated_at` | ISO 时间戳。 |

规则：

- `plan_id` 是分组 key。
- 当前 schema 没有单独 parent workout-record 表。
- 编辑已保存记录时，事务性替换整个 `plan_id` group。
- Home 和摘要使用已保存 sessions/sets，不使用未保存草稿。

### `workout_sets`

用途：力量训练 set 行。

重要字段：

| Field | Meaning |
| --- | --- |
| `id` | Set id。 |
| `workout_session_id` | 父级 `workout_sessions.id`，级联删除。 |
| `set_number` | 保存后的 set 顺序。 |
| `weight_kg`, `reps` | 兼容用的标准化计算字段。 |
| `input_weight_kg`, `input_reps`, `input_duration_seconds` | 用户原始输入。 |
| `calculation_load_kg`, `calculation_reps` | 热量和容量计算使用的标准化值。 |
| `load_input_mode`, `reps_input_mode`, `set_metric_type` | 每组输入语义。 |
| `is_completed`, `completed_at` | 完成状态。 |

规则：

- 只持久化已完成力量组。
- 未勾选 set 保存前丢弃。
- 保存后的 set 从 `1..n` 重新编号。
- 同时保存原始值和标准化值，使历史记录可以解释。

### `custom_exercises`

用途：用户创建的可复用本地动作定义。

重要字段：

| Field | Meaning |
| --- | --- |
| `exercise_key` | 稳定本地 key。 |
| `name` | 用户可见名称。 |
| `exercise_type` | `strength` 或 `cardio`。 |
| `body_part`, `secondary_body_part` | 分类 metadata。 |
| `strength_structure`, `strength_profile` | 力量计算 metadata。 |
| `load_input_mode`, `reps_input_mode`, `set_metric_type` | 默认力量输入语义。 |
| `default_cardio_intensity` | 默认有氧强度 basis。 |
| `is_hidden` | 隐藏动作保留历史/导出兼容，但不出现在 active picker。 |
| `created_at`, `updated_at` | ISO 时间戳。 |

### `workout_record_drafts`

用途：一个当前未保存训练编辑器状态。

重要字段：

| Field | Meaning |
| --- | --- |
| `id` | 固定 active draft id。 |
| `kind` | `new_record` 或 `edit_record`。 |
| `source_plan_id`, `source_session_id` | 编辑已保存记录时的来源。 |
| `date`, `record_name`, `notes` | 草稿可见 metadata。 |
| `payload_json` | 序列化编辑器快照。 |
| `created_at`, `updated_at` | ISO 时间戳。 |

规则：

- 草稿不进入 Home totals。
- 草稿不是正式训练历史。
- 显式保存会先验证编辑器状态，再写入正式训练表。

### `user_weight_logs`

用途：当前本地每日身体指标历史。Phase 3 后，云端 `body_metric_logs` 是正式来源，本地 `user_weight_logs` 只应作为兼容/cache 表；登录后新增正式记录应归属云端账号。

字段：

- `id`
- `account_id`
- `date`
- `weight_kg`
- `body_fat_percent`
- `waist_cm`
- `source`
- `created_at`
- `updated_at`

用途：

- 动态热量校准
- carb-taper review
- 数据足够时用于 weekly review 摘要

### `calorie_calibration_state`

用途：singleton 动态热量校准状态。

字段：

- `id`
- `lifestyle_factor`
- `confidence`
- `window_days`
- `valid_days`
- `last_calibrated_date`
- `created_at`
- `updated_at`

### `diet_adjustment_reviews`

用途：本地 carb-taper review 历史和用户决策记录。

重要字段：

- review date
- 复盘时的 phase/mode/strategy
- weight trend inputs
- food-log coverage
- training stability
- suggested action
- user decision
- 应用时的 before/after carb delta

AI 边界：Weekly Review 可以解释这些记录，但不能静默创建或应用 diet adjustment review。

## 运行时聚合

`DailySummary` 不是数据库表。它运行时从以下数据组装：

- profile
- food records/items
- workout sessions/sets
- calibration state
- training-frequency self-check
- strategy calculations

Agent V1 应复用云端 daily summaries 或 service-built summaries 做 Structured RAG，而不是默认上传原始表行，也不应把本地 SQLite cache 当作权威上下文。

## 云端表与计划中的表

以下是 Agent V1 的服务端存储概念。Phase 2 已在 `supabase/migrations/202606190001_phase2_account_profile.sql` 实现 Supabase `subscriptions` 和 `cloud_profiles` 表，在 `supabase/migrations/202606230002_cloud_profile_schema_compat.sql` 为已建项目补齐 Cloud Profile schema，在 `supabase/migrations/202606230003_cloud_profile_body_metrics.sql` 提供身体指标 Cloud Profile 补列，并在 `supabase/migrations/202606230001_internal_subscription_codes.sql` 实现开发期内部兑换码支持。Phase 3 已在 `supabase/migrations/202606260001_phase3_cloud_records.sql` 新增 active-device RPC、Cloud Records 表、RLS、soft delete、version/timestamp 触发器和 `daily_summaries` 表；AI 表在对应阶段落地前仍是设计概念。

### `accounts`

用途：认证用户身份。

Phase 2 使用 Supabase Auth 承载这一层，不自建 public `accounts` 表。邮箱、密码凭证、session 和邮箱验证状态归 Supabase Auth；FitLog 不把密码存入 `cloud_profiles`，注册也不要求 username。

字段：

- `id`
- auth provider id
- 可用时的 email 或 phone
- auth metadata 中可用时的 display name；FitLog 昵称/display name 以 Cloud Profile 为权威版本
- locale
- created/updated timestamps
- deletion status

### `subscriptions`

用途：用户 AI entitlement。

Phase 2 将它实现为 Supabase Postgres 表，`account_id = auth.uid()`。客户端可通过 RLS 读取自己的行。客户端 insert/update 被拒绝；开发 entitlement 由 seed 或 service-role 工具维护。

字段：

- `id`
- `account_id`
- plan id
- status
- current period start/end
- provider customer/subscription ids
- created/updated timestamps

用户可见 V1 产品规则：只做订阅 gating，不显示按次额度 UI。

### `internal_subscription_codes`

用途：开发期内部兑换码，用来为当前登录账号开启 AI entitlement。

Phase 2 只在 Supabase 存储兑换码 hash。客户端不能读取或更新这张表。登录客户端调用 `redeem_internal_subscription_code(input_code text)` RPC，由服务端校验 hash、过期时间和兑换次数，记录每个账号/兑换码的唯一兑换，并 upsert 当前账号的 `subscriptions` row。这样 entitlement 写入仍在服务端完成，App 内不会保存 Supabase service-role 凭证。

字段：

- `id`
- label
- hashed code
- status
- plan id
- duration days
- 最大兑换次数和已兑换次数
- optional expiry
- created/updated timestamps

### `internal_subscription_redemptions`

用途：审计哪个账号兑换过哪个内部码。

字段：

- `id`
- `code_id`
- `account_id`
- redeemed timestamp

### `account_active_devices`

用途：V1 单 active device 边界。它记录当前账号被哪一个 App 安装/device/session 接管，用于避免旧设备继续正式写入；它不是实时在线心跳表，也不用于多端同步。

Phase 3 实现：登录成功后客户端调用 `claim_active_device` RPC，把当前账号的 active device/session 更新为本设备。正式 body/food/workout records、Cloud Profile 保存和后续 AI Gateway 请求在服务端或 RPC 边界调用 `assert_active_device`。如果请求来自旧设备，返回稳定错误码 `device_replaced`。

推荐字段：

- `account_id`
- `active_device_id`
- `active_session_id`
- platform
- app version
- claimed timestamp
- last seen timestamp
- replaced timestamp 或 diagnostic reason

推荐 RPC：

- `claim_active_device(device_id text, session_id text, platform text, app_version text)`
- `assert_active_device(device_id text, session_id text)`
- 可选 `release_active_device(device_id text, session_id text)`

规则：

- `account_id` 必须来自 `auth.uid()`，不能信任客户端传入。
- 新登录设备覆盖旧 active device，采用 last login wins。
- 旧设备物理 session 可能不会立刻从 Supabase Auth 表删除；产品正确性依赖 active-device 写入守卫，而不是依赖旧 session 立即消失。
- `device_replaced` 不等同于网络失败或普通上传失败；客户端应清本地登录态并进入重新登录/接管路径。

### `cloud_profiles`

用途：账号绑定的权威 Profile。

Phase 2 将它实现为 Supabase Postgres 表，具备 own-row select/insert/update RLS 和保持算法语义的字段约束。

如果项目早期已经用旧版 Phase 2 SQL 创建过 `cloud_profiles`，还必须运行 `202606230002_cloud_profile_schema_compat.sql`；`create table if not exists` 不会给已存在的表自动补列。若既有项目只缺这次当前身体指标字段，也可以运行更窄的 `202606230003_cloud_profile_body_metrics.sql`。

推荐字段映射当前 profile 概念：

- `account_id`
- display name/nickname
- age
- height
- current weight
- current body-fat percentage
- current waist circumference
- sex option for formulas
- diet goal phase
- diet calculation mode
- daily energy goal kcal
- macro ratio percentages
- training frequency
- diet plan strategy
- carb-cycling pattern and multipliers
- carb-taper review settings and current delta
- self-check settings
- 账号绑定时的 language preference
- `profile_version`
- created/updated timestamps

规则：

- 只在登录/onboarding 后存在。
- Cloud Profile 是权威版本。
- 设备缓存仅用于显示和缓存。
- Profile 页面修改在“保存更改”成功前只是本地草稿；云端写入会 upsert 一份完整 `cloud_profiles` snapshot，并递增 `profile_version`。
- Profile 里的当前身体指标保存到 Cloud Profile。历史体重、体脂和腰围在 Phase 3 后进入云端 `body_metric_logs`；本地历史表只作为 cache/兼容层。
- V1 离线禁止保存 Profile。
- 删除账号时删除 Cloud Profile。
- mapper 必须保留 `diet_goal_phase`、`diet_calculation_mode` 和 `diet_plan_strategy` 这些用户控制的算法字段，不能在 `energy_ratio` 和 `gram_per_kg` 之间互相换算。

### `body_metric_logs`

用途：账号级历史身体指标记录，Phase 3 后作为正式来源。

字段：

- `id`
- `account_id`
- `date`
- `weight_kg`
- `body_fat_percent`
- `waist_cm`
- `source`
- `record_version`
- `created_at`
- `updated_at`
- `deleted_at`

规则：

- 每个账号每天最多一条，建议 `UNIQUE(account_id, date)`。
- 只记录体重、体脂和腰围，不记录年龄、身高或公式性别。
- 过去日期补记不静默修改当前 Cloud Profile。
- 身体资料卡提供记录入口，Body Trends 只读展示趋势。

### `food_records` / `food_items`

用途：账号级正式饮食记录。

规则：

- 新增、编辑和删除是记录级即时操作，不走 Profile 整页草稿保存。
- 删除默认写 `deleted_at`，summary builder 默认排除 soft-deleted rows。
- `food_items` 归属 `food_records`。

### `workout_records` / `workout_sessions` / `workout_sets`

用途：账号级正式训练记录。

规则：

- `workout_records` 表示一次训练记录容器。
- `workout_sessions` 和 `workout_sets` 归属对应 record。
- 保存时保留动作 metadata、输入口径和计算快照。
- 删除默认 soft delete，并更新 summaries。

### `daily_summaries`

用途：Home、AI context、复盘、导出和历史页的轻量汇总入口。

字段应覆盖：

- `account_id`
- `date`
- kcal/protein/carbs/fat totals
- workout estimated kcal
- body metric availability
- mode-primary target/remaining snapshot
- coverage flags
- `updated_at`

规则：

- Phase 3 已创建云端 `daily_summaries` 表。当前 App 侧 `DailySummaryService` 按需用 cloud-backed records repository 构建 deterministic summary，可从云端 `daily_summaries` 恢复缺失的本地 summary cache，把重建 summary upsert 到云端，并把选中日期 confirmed summary 写入本地 `daily_summary_cache` 供 Home stale-while-revalidate 使用；AI/export 不能依赖本地完整 SQLite。
- AI wrapper 优先读 summaries 或 summary builder，而不是扫原始记录全量。

### `ai_chat_sessions`

用途：云端 chat history 侧栏。

字段：

- `id`
- `account_id`
- title
- language
- created/updated timestamps
- archived/deleted state

### `ai_chat_messages`

用途：用户和 assistant 消息。

字段：

- `id`
- `session_id`
- `account_id`
- role
- content
- attachments metadata
- final answer text
- draft card references
- created timestamp

规则：

- 只为登录用户保存。
- 默认不在本地长期保存。
- 不暴露内部 chain-of-thought 或 raw debug traces。

### `ai_request_logs`

用途：审计、可靠性、订阅校验、成本追踪和滥用防护。

字段：

- `id`
- `account_id`
- `session_id`
- request type/workflow
- model/provider
- prompt/context size metadata
- response status
- latency
- token 或 cost metadata
- error code
- created timestamp

生产日志应优先保存 metadata 和脱敏摘要，而不是原始敏感 payload。

### `ai_debug_summaries`

用途：紧凑 operational trace。

字段：

- `request_id`
- selected workflow
- retrieval sources used
- schema validation result
- tool/context-builder calls
- final write intent
- failure reason when failed

规则：

- Development 可保留更多细节。
- Production 保存紧凑脱敏摘要。
- 用户 UI 只展示最终消息和草稿卡，不展示 debug traces。

### `document_chunks`

用途：面向 App 文档的 Document RAG。

字段：

- `id`
- language
- source file
- section path
- content chunk
- stable reference id
- keyword/full-text index fields
- 如果使用向量检索，可有 optional embedding vector
- updated timestamp

允许来源：

- `docs/en/*`
- `docs/zh/*`
- 从设计文档派生的稳定帮助片段

这个表/索引用于文档，不用于用户业务数据。

## Structured RAG Context Objects

Structured RAG 应传递紧凑 typed objects，而不是任意数据库访问。

推荐 context objects：

| Object | Source | Notes |
| --- | --- | --- |
| `profile_context` | Cloud Profile。 | 登录后权威 profile 来自云端。 |
| `selected_day_summary` | 云端 `daily_summaries` 或 summary builder。 | 饮食 totals、训练 totals、目标上下文。 |
| `recent_food_summary` | 云端 records summary builder。 | 窗口 totals 和 coverage，默认不传完整行。 |
| `recent_workout_summary` | 云端 records summary builder。 | 频率、时长、估算 kcal、主要训练部位模式。 |
| `body_metric_summary` | 云端 `body_metric_logs` summary builder。 | 体重、体脂、腰围覆盖情况。 |
| `weight_trend_summary` | 云端 `body_metric_logs` summary builder。 | 数据足够时才给趋势。 |
| `strategy_context` | Profile strategy settings 和确定性 calculator 输出。 | 相关时包含 `carb_cycling` 或 `carb_tapering` 状态。 |

## 权威来源摘要

Cloud Profile、Cloud Records、daily summaries 和本地 cache 的完整权威边界由 `CloudLocalDataBoundary.md` 维护。Database 只记录这些数据落在哪些表以及字段含义。简要规则：

| Data | V1 source of truth |
| --- | --- |
| Account identity | Cloud |
| Active device | Cloud after Phase 3 |
| Subscription | Cloud |
| Cloud Profile | Cloud |
| Body metric logs | Cloud after Phase 3; local SQLite cache only |
| Food records | Cloud after Phase 3; local SQLite cache only |
| Workout records | Cloud after Phase 3; local SQLite cache only |
| Daily summaries | Cloud summary table/service after Phase 3 |
| AI chat history | 登录后 Cloud |
| AI request logs | Cloud/service logs |
| Document RAG index | Cloud 或 bundled service index |
| Export files | 用户主动控制的本地文件 |

cache 容量、淘汰资格、cache-first 读取、`auth_required` 处理和修复策略见 `CloudLocalDataBoundary.md`。

## 离线规则

- 离线时 AI 页面进入灰色不可用状态。
- 用户可以编辑未完成 prompt，但不能发送。
- Profile 页面可以展示缓存 profile，但不能保存。
- V1 不允许 pending offline profile edits。
- Phase 3 后正式 food/workout/body 写入需要云端；离线正式写入队列不属于 Cloud Records Foundation 默认范围，具体处理见 `CloudLocalDataBoundary.md`。

## 导出覆盖

导出应继续覆盖：

- food records
- food items
- workout sessions
- workout sets
- custom exercises
- daily summaries
- user profile fields
- strategy fields
- calibration metadata
- self-check fields
- diet adjustment review history

Phase 3 hardening 后，导出正确性以云端正式 records、云端 summaries 或 builders 为准；本地 cache 只可加速读取，不能要求完整。当前 export builder 会在生成 XLSX/CSV 前读取 cloud-backed food、workout 和 body metric records，并包含 Body Metrics 表。详细规则见 `CloudLocalDataBoundary.md`。云端 AI chat history 和 AI request logs 不属于当前记录导出，除非未来显式增加账号数据导出能力。

## 当前源码未实现

- AI chat 表
- AI request log 表
- Document RAG index
- AI Gateway / chat workflow backend sync
- 用户业务数据向量库

## 代码引用

- Database: `lib/data/db/app_database.dart`
- Repositories: `lib/data/repositories/*`
- Profile: `lib/domain/models/user_profile.dart`, `lib/data/repositories/profile_repository.dart`
- Food: `lib/domain/models/food_record.dart`, `lib/data/repositories/food_repository.dart`
- Workout: `lib/domain/models/workout_session.dart`, `lib/domain/models/workout_set.dart`, `lib/data/repositories/workout_repository.dart`
- Custom exercises: `lib/data/repositories/custom_exercise_repository.dart`
- Daily summaries: `lib/domain/services/daily_summary_service.dart`
- Export: `lib/export/xlsx_export_service.dart`, `lib/export/csv_export_service.dart`
