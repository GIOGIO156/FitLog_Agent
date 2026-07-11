# 数据库设计

## 目标

本文定义 FitLog_Agent V1 的 schema、migration、表、字段和存储概念。云端/本地权威、cache-first 读取、写入成功标准、刷新、异常、冲突和修复规则统一定义在 `CloudLocalDataBoundary.md`。

FitLog 使用本地 SQLite 保存兼容状态、确定性本地服务数据、草稿和 partial confirmed read model；Supabase 负责登录账号数据、正式记录、AI history/operations 和文档索引。登录后正式记录以云端为权威。RAG、export 和 AI draft workflow 使用云端正式 records、`daily_summaries` 或受控 summary builder，不假设本地 SQLite 保存完整历史。

## 存储总览

| 存储 | 用途 | 权威与生命周期 |
| --- | --- | --- |
| SQLite / `sqflite` | 本地兼容 profile/cache、校准、策略复盘、自定义动作、训练草稿、账号绑定 confirmed read model 和选中日期 `daily_summary_cache`。 | Schema v15。登录后正式记录在这里不具权威；confirmed cache 可重建且有界。 |
| Supabase Cloud Records | `body_metric_logs`、`food_records`/`food_items`、`workout_sessions`/`workout_sets` 和 `daily_summaries`。 | 登录后正式记录的权威来源；cloud-backed repository 协调写入和本地 read-model 更新。 |
| SharedPreferences | 语言/主题和轻量 UI preference、每账号记录摘要权限、Cloud Profile/subscription display cache、注册 PKCE verifier 和小型 picker-recovery marker。 | 设备本地运行期/显示状态，不是业务记录同步。 |
| 本地文件 | App documents directory 中的 XLSX 和 CSV ZIP 导出。 | 用户控制的派生文件，不是 cloud source of truth。 |
| 云端账号与 AI 存储 | Supabase Auth identity、subscription entitlement、Cloud Profile、AI chat sessions/messages、request logs、compact debug summaries、evidence/artifact snapshots 和 document chunks。 | 账号绑定或 service-owned cloud data，由 RLS/RPC/service boundary 保护。 |
| AI 文档索引 | 面向 Document RAG 的稳定文档 chunks。 | Supabase Postgres keyword/full-text/trigram retrieval，只允许 service-role 写入。 |
| In-memory providers | 选中日期、刷新版本、App services、语言状态和运行时摘要。 | 只用于短暂运行期协调。 |

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
| 14 | 重新运行幂等 cloud-cache 补列迁移，让安装过中间 v13 测试包的设备无需清除本地数据也能补齐缺失字段。 |
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
| `total_weight_g` | 总估算重量。对于包含 item 行的已确认 AI Food Draft，预览/保存路径会从 item 重量求和得到该值。 |
| `calories_kcal` | 餐级 kcal。 |
| `protein_g` | 蛋白质克数。 |
| `carbs_g` | 碳水克数。 |
| `fat_g` | 脂肪克数。 |
| `confidence` | 可用时的估算置信度。 |
| `estimation_notes` | 估算或用户备注。 |
| `source` | `manual`、`ai_paste`，以及从 Add Food AI 食物分析草稿确认保存而来的 `ai_photo`。 |
| `created_at`, `updated_at` | ISO 时间戳。 |

V1 边界：正式行只有用户确认后才写入。Add Food AI 食物分析会从文字和可选图片创建草稿并进入 Food Preview，只有用户保存才写正式行。

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
- 草稿里的力量组条目可以在 `payload_json` 内携带 draft-only 的 `completed_at` 时间戳，用于 Android 训练进行中通知判断最近一次勾选完成组。这不改变 `workout_sets` SQLite schema，也不需要提升正式本地 schema version。

### `user_weight_logs`

用途：每日身体指标历史的本地兼容/cache。云端 `body_metric_logs` 是登录账号的权威来源；登录后新增正式记录归属云端账号。

字段：

- `id`
- `account_id`
- `date`
- `weight_kg`
- `body_fat_percent`
- `waist_cm`
- `source`
- `deleted_at`
- `created_at`
- `updated_at`

用途：

- 动态热量校准
- carb-taper review
- 数据足够时用于 weekly review 摘要

正常读取会排除 soft-deleted rows。云端 `body_metric_logs` 删除后，匹配的 `user_weight_logs` cache 镜像也会 soft delete，校准和 review 服务不再消费这条历史体重记录。

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

## 云端表与存储边界

以下服务端存储概念支撑 Agent V1 的账号、订阅、Cloud Profile、Cloud Records、AI Chat、日志和 Document RAG 行为。当前 schema 由账号/Profile 基础、内部 entitlement 测试、Cloud Records 与 active-device guard、AI chat/log/debug 表、chat 操作 RPC 和 Document RAG index 相关 Supabase migrations 定义。本节描述稳定的表职责，而不是实现顺序。

### `accounts`

用途：认证用户身份。

Supabase Auth 承载账号 identity，不自建 public `accounts` 表。邮箱/密码凭证、session 和邮箱验证状态归 Supabase Auth；FitLog 不把密码存入 `cloud_profiles`，注册也不要求 username。

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

该 Supabase Postgres 表以 `account_id = auth.uid()` 为 key。客户端可通过 RLS 读取自己的 row，但不能 insert/update；开发 entitlement 和服务端验收设置由 seed 或 service-role 工具维护。

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

Supabase 只保存兑换码 hash。客户端不能读取或更新该表。登录客户端调用 `redeem_internal_subscription_code(input_code text)` RPC，由服务端校验 hash、过期时间和兑换次数，记录每个账号/兑换码的唯一兑换，并 upsert 当前账号的 `subscriptions` row。Entitlement 写入留在服务端，App 不保存 service-role 凭证。

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

登录成功后客户端调用 `claim_active_device`，把账号 active device/session 绑定为当前设备。正式 body/food/workout writes、Cloud Profile 保存和 AI Gateway 请求在服务端或 RPC 边界调用 `assert_active_device`；旧设备请求返回稳定 `device_replaced` code。

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

该 Supabase Postgres 表具备 own-row select/insert/update RLS 和保持算法语义的字段约束。

如果项目已用早期 SQL shape 创建 `cloud_profiles`，还必须运行 `202606230002_cloud_profile_schema_compat.sql`；`create table if not exists` 不会给已存在表自动补列。只缺当前身体指标字段的项目可以运行更窄的 `202606230003_cloud_profile_body_metrics.sql`。

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
- Profile 当前身体指标保存到 Cloud Profile。历史体重、体脂和腰围使用云端 `body_metric_logs`；本地历史表只作为 cache/兼容层。
- V1 离线禁止保存 Profile。
- 删除账号时删除 Cloud Profile。
- mapper 必须保留 `diet_goal_phase`、`diet_calculation_mode` 和 `diet_plan_strategy` 这些用户控制的算法字段，不能在 `energy_ratio` 和 `gram_per_kg` 之间互相换算。

### `body_metric_logs`

用途：账号级历史身体指标正式记录。

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
- 删除通过 `deleted_at` soft delete；正常 app 读取、Body Trends、summary、校准和 review 都会排除已删除记录。

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

- `DailySummaryService` 按需从 cloud-backed record repository 构建 deterministic summary，可从云端 `daily_summaries` 恢复缺失的本地 summary cache、upsert 重建 summary，并把选中日期 confirmed summary 写入本地 `daily_summary_cache` 供 Home stale-while-revalidate 使用。AI 和 export 不能依赖本地完整 SQLite。
- AI wrapper 优先读 summaries 或 summary builder，而不是扫原始记录全量。

### `ai_chat_sessions`

用途：云端 chat history 侧栏。

字段：

- `id`
- `account_id`
- `title`
- `language`
- `last_message_at`
- `archived_at`
- `deleted_at`
- `created_at`
- `updated_at`

规则：

- 账号级 RLS 保护客户端读取。
- 服务端 Gateway 只有通过 auth、subscription 和 active-device 校验后才能创建或复用 session。
- service-role grants 只用于服务端 Gateway、entitlement 维护和验收；普通 authenticated client 仍不获得直接写入权限。
- 客户端读取排除 soft-deleted sessions。
- 不开放客户端直接写入；Gateway 写入由 Edge Function 和 `record_ai_chat_turn` RPC 在服务端完成。
- Inline 重命名使用 `rename_ai_chat_session`，该 RPC 检查 `auth.uid()`、trim 并限制 title 长度，只更新当前账号未删除 session。删除使用 `soft_delete_ai_chat_session` 写 `deleted_at`，不应删除无关消息或其它账号数据。归档状态仍保留在 schema/RPC 中，但当前 UI 不暴露归档入口，因为没有归档恢复列表。

### `ai_chat_messages`

用途：用户和 assistant 消息。

字段：

- `id`
- `session_id`
- `account_id`
- `message_sequence`
- `role`
- `content_text`
- `message_type`
- `workflow_type`
- `model_choice`
- `model_provider`
- `request_id`
- `final_answer_json`
- `attachments_metadata`
- `created_at`
- `deleted_at`

规则：

- 账号级 RLS 保护客户端读取。
- Gateway 每个通过校验的 turn 写一条 user message 和一条 assistant message。图片 Chat 仍以文本消息持久化，最多三张图片只在本次 Gateway request 中转发。
- `final_answer_json` 可以保存轻量 `ai_chat_artifacts.v2` snapshot，例如合法 `food_draft.v2` 或 `workout_draft.v2`，同时保存解析后的 `target_date`、日期解析来源、`ai_chat_evidence.v1` 或概括 retrieved context 的 `evidence` object。Artifact snapshot 只在 review 后重建 Preview；evidence 只用于只读显示/debug context。两者都不是正式记录或后台草稿队列。History reader 继续兼容 v1 artifact：legacy draft 没有自身日期时使用其中保存的 selected date。
- `role` 限定为 `user` 和 `assistant`；持久化的 chat history 仍为 text message。`ai_chat_messages` 不保存图片 bytes 或 base64。
- 消息顺序以 `message_sequence` 为确定性主顺序，timestamp 和 id 作为稳定辅助字段。
- message 的 `account_id` 必须与父 session 匹配。
- 默认不在本地长期保存。
- 不暴露内部 chain-of-thought 或 raw debug traces。

### `ai_request_logs`

用途：审计、可靠性、订阅校验、成本追踪和滥用防护。

字段：

- `request_id`
- `account_id`
- `session_id`
- `workflow_type`
- `model_choice`
- `model_provider`
- 服务端配置的 `model`
- `prompt_version`
- `schema_version`
- `profile_version`
- `status`
- `error_code`
- `latency_ms`
- `token_estimate`
- `image_count`
- `expected_output`
- `intent_resolution_source`
- `selected_output_type`
- `validation_issue_codes_json`
- `validator_version`
- `first_pass_validation_status`
- `correction_attempt_count`
- `final_validation_status`
- `provider_completion_status`
- `created_at`

该表是服务端 operational record：

- Additive migration `202607100001_ai_output_contract_observability.sql` 幂等增加 expected output、validator、first-pass/final validation、correction count 和 provider completion category 字段，不改变 SQLite `AppDatabase.dbVersion`。
- Additive migration `202607110001_ai_intent_output_observability.sql` 允许 `expected_output = auto`，并增加 `fixed_workflow` / `deterministic` / `model` 解析来源、最终通过校验的 output type 和不含用户内容的 issue-code array。它同样不改变 SQLite schema version。
- Migration `202607110002_ai_observability_update_grants.sql` 允许 Edge Function service role 在初始 RPC insert 后 finalize `ai_request_logs` 和 `ai_debug_summaries`；authenticated client 仍没有直接读写 policy。
- Chat 使用 `prompt_version = phase5_rag_readonly_v1` 与 `schema_version = ai_chat_response.v2`；Add Food 使用 `workflow_type = food_logging` 与 `schema_version = food_draft.v2`。
- 文字/图片路径只保存紧凑 output-contract 状态，不保存 raw provider output、correction payload、图片 bytes/base64、provider secret 或不受限 notes。
- `selected_output_type` 只在 provider 结果通过 contract validation 后写入；issue codes 是固定分类，不保存 field value、用户 prompt 或 provider 原文。
- Authenticated client 没有直接 table read policy。

### `ai_debug_summaries`

用途：紧凑 operational trace。

字段：

- `id`
- `request_id`
- `account_id`
- `session_id`
- `intent`
- `intent_confidence`
- `called_tools_json`
- `retrieved_dimensions_json`
- `missing_dimensions_json`
- `safety_flags_json`
- `schema_validation_status`
- `user_final_action`
- `created_at`

规则：

- 该服务端 operational table 保存紧凑 Gateway summary。Chat debug rows 包含 routed intent confidence、called tools、retrieved dimensions、missing dimensions、safety flags、schema-validation status 和 final action。Add Food 保存紧凑 `food_photo_analysis` summary，只包含 input kind、selected date、note presence、image count、可用时的 mime type/compressed byte length、validation status 和 safety/error flags。Authenticated client 没有直接 read policy。
- JSON 字段是紧凑数组，不是无限制 traces。
- Production 保存紧凑脱敏摘要。
- 用户 UI 只展示最终消息和草稿卡，不展示 debug traces。

### `document_chunks`

用途：面向 App 文档的 Document RAG。

字段：

- `id`
- `language`
- `doc_path`
- `heading`
- `heading_level`
- `heading_path`
- `section_id`
- `chunk_index`
- `chunk_count`
- `content`
- `context_prefix`
- `context_note`
- `tags`
- `status`
- `content_hash`
- `generator_version`
- `source_updated_at`
- `created_at`
- `updated_at`

允许来源：

- Document RAG ingestion tool 维护的显式稳定双语 source allowlist
- 根目录 `README.md`

规则：

- Migration `202607080001_phase5_document_rag_index.sql` 创建该表。
- `search_document_chunks(input_language, input_query, input_limit)` 是 service-role RPC，会按语言过滤，并基于 heading、heading path、确定性 context prefix、可选人工审查 context note 和 chunk content 的整句全文检索、trigram signals 和关键词 term overlap 排序。term-overlap fallback 用于避免长自然语言问句因为整句无法精确匹配 chunk 而返回空结果。
- `supabase/seed_phase5_document_chunks.sql` 由 `tool/phase5_document_rag/build_document_chunks.mjs` 从稳定文档生成；migration 后需在 Supabase SQL editor 人工执行。
- Authenticated client 不直接读写该表。它用于文档，不用于用户业务数据。
- 只有 Document RAG 需要专用持久化 index。Structured RAG 通过 `ai-chat-route` context builders 复用 Cloud Profile、Cloud Records 和 summary tables。

完整 source allowlist、chunking、contextual metadata、status 语义、retrieval 行为、seed refresh 生命周期、隐私边界和 RAG 评测规则见 [RAGDesign.md](RAGDesign.md)。Database 只负责持久化 schema 和 RPC data flow。

## Structured RAG 存储边界

Structured RAG 没有单独的 `structured_rag` SQL 表。它基于 Cloud Profile、Cloud Records 和 `daily_summaries` 构建有界运行期 objects；service-role grants 提供所需读取和紧凑 debug-summary update 权限。Flutter 不能上传自己的 context-object payload。Object schemas、权限行为、missing dimensions、sanitization 和 evidence 见 [RAGDesign.md](RAGDesign.md)。

## 权威来源摘要

Cloud Profile、Cloud Records、daily summaries 和本地 cache 的完整权威边界由 `CloudLocalDataBoundary.md` 维护。Database 只记录这些数据落在哪些表以及字段含义。简要规则：

| Data | V1 source of truth |
| --- | --- |
| Account identity | Cloud |
| Active device | Cloud |
| Subscription | Cloud |
| Cloud Profile | Cloud |
| Body metric logs | Cloud；本地 SQLite 只做 cache |
| Food records | Cloud；本地 SQLite 只做 cache |
| Workout records | Cloud；本地 SQLite 只做 cache |
| Daily summaries | Cloud summary table/service |
| AI chat history | 登录后 Cloud |
| AI request logs | Cloud/service logs |
| Document RAG index | 云端 `document_chunks`；由稳定文档 seed 生成 |
| Export files | 用户主动控制的本地文件 |

cache 容量、淘汰资格、cache-first 读取、`auth_required` 处理和修复策略见 `CloudLocalDataBoundary.md`。

## 离线规则

- 离线时 AI 页面进入灰色不可用状态。
- 用户可以编辑未完成 prompt，但不能发送。
- Profile 页面可以展示缓存 profile，但不能保存。
- V1 不允许 pending offline profile edits。
- 正式 food/workout/body 写入需要云端；离线正式写入队列不在当前边界内，具体处理见 `CloudLocalDataBoundary.md`。

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

导出正确性以云端正式 records、云端 summaries 或 builders 为准；本地 cache 只可加速读取，不能要求完整。Export builder 在生成 XLSX/CSV 前读取 cloud-backed food、workout 和 body metric records，并包含 Body Metrics 表。详细规则见 `CloudLocalDataBoundary.md`。云端 AI chat history 和 AI request logs 不属于记录导出，除非另行设计账号数据导出能力。

## 存储非目标

- 长期图片 attachment storage
- 长期草稿队列或 Chat 草稿自动写入正式记录
- 超过三张的 Chat 图片或长期图片 attachment storage
- 用户业务数据向量库

## 代码引用

- Database: `lib/data/db/app_database.dart`
- Repositories: `lib/data/repositories/*`
- Profile: `lib/domain/models/user_profile.dart`, `lib/data/repositories/profile_repository.dart`
- Food: `lib/domain/models/food_record.dart`, `lib/data/repositories/food_repository.dart`
- Workout: `lib/domain/models/workout_session.dart`, `lib/domain/models/workout_set.dart`, `lib/data/repositories/workout_repository.dart`
- Custom exercises: `lib/data/repositories/custom_exercise_repository.dart`
- Daily summaries: `lib/domain/services/daily_summary_service.dart`
- AI chat 和 AI 食物分析 contract models: `lib/domain/models/ai_chat_session.dart`, `lib/domain/models/ai_chat_message.dart`, `lib/domain/models/ai_gateway_request.dart`, `lib/domain/models/ai_gateway_response.dart`, `lib/domain/models/ai_gateway_evidence.dart`, `lib/domain/models/ai_gateway_error.dart`, `lib/domain/models/ai_food_photo_analysis.dart`, `lib/domain/models/ai_workout_draft.dart`
- Supabase AI schema: `supabase/migrations/202606290001_phase4_ai_chat_foundation.sql`, `supabase/migrations/202606290002_phase4_step2_gateway_mock.sql`, `supabase/migrations/202606300001_phase4_step3_4_chat_ops_real_providers.sql`, `supabase/migrations/202607010001_phase4_step5_chat_session_rename.sql`, `supabase/migrations/202607080001_phase5_document_rag_index.sql`, `supabase/migrations/202607090001_phase5_structured_rag_service_role_grants.sql`, `supabase/migrations/202607100001_ai_output_contract_observability.sql`
- Supabase AI Gateway: `supabase/functions/_shared/ai_output_contract.ts`, `supabase/functions/ai-chat-route/index.ts`, `supabase/functions/ai-chat-route/openai_provider.ts`, `supabase/functions/ai-chat-route/qwen_provider.ts`, `supabase/functions/ai-chat-route/workflow_router.ts`, `supabase/functions/ai-chat-route/context_builders.ts`, `supabase/functions/ai-chat-route/document_rag.ts`, `supabase/functions/ai-chat-route/prompt_builder.ts`, `supabase/functions/ai-food-photo-analyze/index.ts`
- Document RAG seed tooling: `tool/phase5_document_rag/build_document_chunks.mjs`, `supabase/seed_phase5_document_chunks.sql`
- AI chat 和 AI 食物分析 repository/client: `lib/data/repositories/ai_chat_repository.dart`, `lib/data/remote/ai_gateway_client.dart`, `lib/data/remote/ai_food_photo_analysis_client.dart`
- Export: `lib/export/xlsx_export_service.dart`, `lib/export/csv_export_service.dart`
