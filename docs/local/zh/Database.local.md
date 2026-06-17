# 数据库设计

## 存储概览

FitLog Local 将业务数据保存在本地。

| 存储 | 用途 | 远程同步 |
| --- | --- | --- |
| SQLite / `sqflite` | Profile、food records、food items、workout sessions、workout sets、custom exercises、workout record drafts、weight logs、calibration state、diet adjustment reviews。 | No |
| SharedPreferences | UI 语言偏好，目前是 `language_code`。 | No |
| Local files | App documents directory 中的 XLSX 和 CSV ZIP 导出文件。 | No |
| In-memory providers | App services、refresh version、selected date、language state。 | No |

数据库名：`fitlog_local.db`。

当前 SQLite schema 版本：`11`。

通过 `PRAGMA foreign_keys = ON` 启用外键。

## 迁移策略

迁移必须保持加法式，并保留现有本地数据。

| 版本 | 变更 |
| ---: | --- |
| 1 | 初始 profile、food、workout 和 set 表。 |
| 2 | 添加 `workout_sessions.plan_id`。 |
| 3 | 添加 profile 宏量比例字段：`protein_ratio_percent`、`carbs_ratio_percent`、`fat_ratio_percent`。 |
| 4 | 添加 `user_weight_logs` 和 `calorie_calibration_state`。 |
| 5 | 添加 `diet_calculation_mode`、`training_frequency_per_week` 和宏量自检字段。 |
| 6 | 添加 `user_profile.diet_goal_phase TEXT NOT NULL DEFAULT 'cutting'`。 |
| 7 | 添加饮食策略 profile 字段和 `diet_adjustment_reviews`。 |
| 8 | 添加 `workout_sessions.record_name`。 |
| 9 | 添加本地 UI 昵称字段 `user_profile.nickname`。 |
| 10 | 添加 `workout_record_drafts`，用于保存一条活动中的未保存训练编辑状态。 |
| 11 | 添加可复用 `custom_exercises`、训练 session 动作快照、有氧强度元数据，以及训练组的原始输入值/计算值字段。 |

兼容规则：

- 不因为当前 schema 变化就重写旧迁移。
- 优先用加字段、加表，而不是破坏式重建。
- 现有用户使用安全兼容默认值，例如 `cutting`、`energy_ratio`、`none`。
- `daily_energy_goal_type` 继续保留用于兼容，但 `diet_goal_phase` 是阶段语义的来源。

## 数据表

### `user_profile`

用途：单例用户资料、饮食设置、策略设置和自检设置。Repository 使用 `id = 1`。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | INTEGER PRIMARY KEY | 单例 profile id。 |
| `nickname` | TEXT | 仅用于本地 UI 的昵称，例如 Home 问候语；不是账号字段。 |
| `age` | INTEGER NOT NULL | BMR 与未成年人保护。 |
| `height_cm` | REAL NOT NULL | BMR。 |
| `weight_kg` | REAL NOT NULL | BMR、g/kg 宏量、运动消耗。 |
| `sex_for_formula` | TEXT NOT NULL | `male`、`female`、`prefer_not_to_say`。 |
| `activity_level` | TEXT NOT NULL | 保存 Profile 时根据 `training_frequency_per_week` 派生出的兼容/导出活动档位。 |
| `daily_energy_goal_type` | TEXT NOT NULL | 兼容字段：`maintenance`、`deficit`、`surplus`。 |
| `daily_energy_goal_kcal` | REAL NOT NULL | 根据 `diet_goal_phase` 表示赤字或盈余。 |
| `protein_ratio_percent` | REAL NOT NULL | `energy_ratio` 宏量比例。 |
| `carbs_ratio_percent` | REAL NOT NULL | `energy_ratio` 宏量比例。 |
| `fat_ratio_percent` | REAL NOT NULL | `energy_ratio` 宏量比例。 |
| `diet_goal_phase` | TEXT NOT NULL DEFAULT `cutting` | `cutting` 或 `bulking`；阶段语义来源。 |
| `diet_calculation_mode` | TEXT NOT NULL DEFAULT `energy_ratio` | `energy_ratio` 或 `gram_per_kg`。 |
| `diet_plan_strategy` | TEXT NOT NULL DEFAULT `none` | `none`、`carb_cycling`、`carb_tapering`。 |
| `carb_cycle_pattern_json` | TEXT | weekday 到 high/medium/low 的映射。 |
| `carb_cycle_high_multiplier` | REAL NOT NULL DEFAULT 1.20 | 高碳日倍率。 |
| `carb_cycle_medium_multiplier` | REAL NOT NULL DEFAULT 1.00 | 中碳日倍率。 |
| `carb_cycle_low_multiplier` | REAL NOT NULL DEFAULT 0.80 | 低碳日倍率。 |
| `carb_taper_review_period_days` | INTEGER NOT NULL DEFAULT 14 | 14/21/28/7。 |
| `carb_taper_target_loss_pct_per_week` | REAL NOT NULL DEFAULT 0.50 | 由 app constants clamp。 |
| `carb_taper_step_g` | REAL NOT NULL DEFAULT 10.0 | 5/10/15/20 风格步长。 |
| `carb_taper_current_delta_g` | REAL NOT NULL DEFAULT 0.0 | 累计碳水偏移。 |
| `last_carb_taper_review_at` | TEXT | 上次 taper review 时间/日期。 |
| `training_frequency_per_week` | INTEGER NOT NULL DEFAULT 3 | 共享 2/3/4/5 训练频率设置；用于 g/kg 查表、`energy_ratio` 默认系数回退和自检。 |
| `macro_self_check_period_days` | INTEGER NOT NULL DEFAULT 14 | 7/14/21/28。 |
| `macro_self_check_enabled` | INTEGER NOT NULL DEFAULT 1 | bool 以 0/1 存储。 |
| `last_macro_self_check_at` | TEXT | 共享训练频率自检的冷却时间/日期。 |
| `created_at` | TEXT NOT NULL | ISO datetime。 |
| `updated_at` | TEXT NOT NULL | ISO datetime。 |

### `food_records`

用途：餐级饮食记录。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | record id。 |
| `date` | TEXT NOT NULL | `yyyy-MM-dd`。 |
| `meal_name` | TEXT NOT NULL | 餐名。 |
| `total_weight_g` | REAL NOT NULL | 总估算重量。 |
| `calories_kcal` | REAL NOT NULL | 餐级 kcal。 |
| `protein_g` | REAL NOT NULL | 蛋白质克数。 |
| `carbs_g` | REAL NOT NULL | 碳水克数。 |
| `fat_g` | REAL NOT NULL | 脂肪克数。 |
| `confidence` | REAL | 外部估算置信度；手动记录通常为空。 |
| `estimation_notes` | TEXT | 外部估算或用户备注。 |
| `source` | TEXT NOT NULL | `ai_paste` 或 `manual`。 |
| `created_at` | TEXT NOT NULL | ISO datetime。 |
| `updated_at` | TEXT NOT NULL | ISO datetime。 |

### `food_items`

用途：餐内 item 行。随父 food record 级联删除。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | item id。 |
| `food_record_id` | INTEGER NOT NULL | FK 到 `food_records.id`，ON DELETE CASCADE。 |
| `name` | TEXT NOT NULL | 食物 item 名称。 |
| `estimated_weight_g` | REAL NOT NULL | 估算重量。 |
| `calories_kcal` | REAL NOT NULL | kcal。 |
| `protein_g` | REAL NOT NULL | 蛋白质克数。 |
| `carbs_g` | REAL NOT NULL | 碳水克数。 |
| `fat_g` | REAL NOT NULL | 脂肪克数。 |
| `notes` | TEXT | 可选备注。 |

### `workout_sessions`

用途：单个已保存动作 session。一个多动作 `Workout Record` 在存储层是多条共享 `plan_id` 的 session。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | session id。 |
| `plan_id` | TEXT | 同一训练记录分组键。 |
| `record_name` | TEXT | 面向用户的训练记录名称，在同组内重复保存。 |
| `date` | TEXT NOT NULL | `yyyy-MM-dd`。 |
| `body_part` | TEXT NOT NULL | Body-part bucket。 |
| `secondary_body_part` | TEXT | 力量动作 metadata 中可选的副锻炼部位。 |
| `exercise_name` | TEXT NOT NULL | 动作展示名。 |
| `exercise_key` | TEXT | 保存当时的内置、自定义或临时动作定义 key。 |
| `exercise_source` | TEXT | `builtin`、`custom` 或 `ad_hoc`。 |
| `exercise_type` | TEXT NOT NULL | `strength` 或 `cardio`。 |
| `duration_minutes` | INTEGER NOT NULL | 用户记录时长。 |
| `intensity` | TEXT NOT NULL | 兼容旧记录的强度字段。 |
| `strength_profile` | TEXT | 本次保存使用的内部力量消耗 profile。 |
| `load_input_mode` | TEXT | 保存当时的重量录入口径，例如 `total_load`、`per_side_load`、`bodyweight_added` 或 `assistance_load`。 |
| `reps_input_mode` | TEXT | 保存当时的次数录入口径，例如 `total_reps` 或 `per_side_reps`。 |
| `set_metric_type` | TEXT | 保存当时的力量组记录指标，目前为 `reps` 或 `duration_seconds`。 |
| `cardio_met` | REAL | 本次有氧计算使用的 MET。 |
| `cardio_intensity_basis` | TEXT | 本次有氧强度依据，例如 `moderate_30_to_60` 或 `interval_under_3`。 |
| `cardio_active_minutes` | INTEGER | 间歇类有氧中实际运动分钟数，可小于经过时长。 |
| `body_weight_kg_at_calculation` | REAL | 本次运动消耗计算使用的体重。 |
| `exercise_snapshot_json` | TEXT | 保存当时可解释/复盘动作定义所需 metadata 的 JSON 快照。 |
| `estimated_calories` | REAL NOT NULL | 本地确定性估算结果。 |
| `notes` | TEXT | 可选备注。 |
| `created_at` | TEXT NOT NULL | ISO datetime。 |
| `updated_at` | TEXT NOT NULL | ISO datetime。 |

### `workout_sets`

用途：力量训练组行。跟随父 session 级联删除。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | set id。 |
| `workout_session_id` | INTEGER NOT NULL | FK 到 `workout_sessions.id`。 |
| `set_number` | INTEGER NOT NULL | 保存后的组号。 |
| `weight_kg` | REAL NOT NULL | 兼容用计算负重；新记录中与计算器使用的标准化负重一致。 |
| `reps` | INTEGER NOT NULL | 兼容用计算次数；按时长记录的力量组会保存标准化后的计算次数。 |
| `input_weight_kg` | REAL | 用户原始输入的重量，尚未按每侧、自重或辅助重量解释。 |
| `input_reps` | INTEGER | 用户原始输入的次数，尚未按每侧次数解释。 |
| `input_duration_seconds` | INTEGER | 平板支撑等按时长记录的力量组的单组时长。 |
| `calculation_load_kg` | REAL | 力量消耗和训练量计算实际使用的标准化负重。 |
| `calculation_reps` | INTEGER | 力量消耗和训练量计算实际使用的标准化次数。 |
| `load_input_mode` | TEXT | 本组保存的重量录入口径副本。 |
| `reps_input_mode` | TEXT | 本组保存的次数录入口径副本。 |
| `set_metric_type` | TEXT | 本组保存的组记录指标副本。 |
| `is_completed` | INTEGER NOT NULL | bool 以 0/1 存储。 |
| `completed_at` | TEXT | 完成时间，可为空。 |

当前保存行为：

- 只持久化已完成的力量组。
- 未勾选的组会在插入/更新前丢弃。
- 剩余组会重新编号为 `1..n`。
- `is_completed` 继续保存用于兼容，但已保存的力量组预期都是已完成组。
- 新记录同时保存用户看到的原始输入值和算法使用的标准化计算值，因此每侧哑铃/绳索重量、每侧次数、辅助自重、自重加重和按时长记录的力量组在保存后仍然可解释。

### `custom_exercises`

用途：用户创建的本地可复用动作定义。隐藏行会保留用于历史记录兼容，但不进入当前可选动作库。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | custom exercise row id。 |
| `exercise_key` | TEXT NOT NULL UNIQUE | 保存训练记录时使用的稳定本地 key。 |
| `name` | TEXT NOT NULL | 用户看到的自定义动作名。 |
| `exercise_type` | TEXT NOT NULL | `strength` 或 `cardio`。 |
| `body_part` | TEXT NOT NULL | 力量动作的主要部位；自定义有氧固定为 `Cardio`。 |
| `secondary_body_part` | TEXT | 可选副锻炼部位。 |
| `strength_structure` | TEXT | 面向用户的力量动作结构，会映射到内部 profile，例如 `compound`、`isolation` 或 `full_body_auto`。 |
| `strength_profile` | TEXT | 训练记录使用的内部力量消耗 profile。 |
| `load_input_mode` | TEXT | 默认力量重量录入口径。 |
| `reps_input_mode` | TEXT | 默认力量次数录入口径。 |
| `set_metric_type` | TEXT | 默认力量组记录指标。 |
| `default_cardio_intensity` | TEXT | 自定义有氧的默认强度依据。 |
| `is_hidden` | INTEGER NOT NULL DEFAULT 0 | bool 以 0/1 存储。 |
| `created_at` | TEXT NOT NULL | ISO datetime。 |
| `updated_at` | TEXT NOT NULL | ISO datetime。 |

### `workout_record_drafts`

用途：单独保存一条活动中的未保存训练编辑状态，与正式训练历史分离。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | TEXT PRIMARY KEY | 固定的活动草稿 id。 |
| `kind` | TEXT NOT NULL | `new_record` 或 `edit_record`。 |
| `source_plan_id` | TEXT | 当草稿来自已保存的分组训练记录时，对应原始 `plan_id`。 |
| `source_session_id` | INTEGER | 当草稿来自旧的单条非分组训练记录时，对应原始 session id。 |
| `date` | TEXT NOT NULL | 编辑页里显示的草稿日期。 |
| `record_name` | TEXT NOT NULL | 草稿训练记录名。 |
| `notes` | TEXT NOT NULL | 草稿备注。 |
| `payload_json` | TEXT NOT NULL | 序列化后的编辑器快照，包含草稿元数据、动作顺序、时长、组行、默认提示状态和完成标记。 |
| `created_at` | TEXT NOT NULL | 草稿创建时间。 |
| `updated_at` | TEXT NOT NULL | 最近一次自动保存时间。 |

草稿行为：

- 草稿表不属于正式训练历史，也不会出现在已保存训练列表里。
- 草稿表不会参与 Home 的训练汇总，也不进入导出覆盖。
- 用户显式保存时，会先校验当前编辑状态，再写入 `workout_sessions` 和 `workout_sets`，最后删除草稿行。

### `user_weight_logs`

用途：体重日志，用于趋势和校准。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | log id。 |
| `date` | TEXT NOT NULL UNIQUE | `yyyy-MM-dd`。 |
| `weight_kg` | REAL NOT NULL | 体重。 |
| `source` | TEXT NOT NULL | `manual` 或 `profile_save`。 |
| `created_at` | TEXT NOT NULL | ISO datetime。 |
| `updated_at` | TEXT NOT NULL | ISO datetime。 |

### `calorie_calibration_state`

用途：动态生活系数校准状态，主键固定为 `id = 1`。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | INTEGER PRIMARY KEY CHECK (id = 1) | 单例状态。 |
| `lifestyle_factor` | REAL NOT NULL | 校准后的非运动生活系数。 |
| `confidence` | REAL NOT NULL | 0..1。 |
| `window_days` | INTEGER NOT NULL | 校准窗口天数。 |
| `valid_days` | INTEGER NOT NULL | 窗口内有效天数。 |
| `last_calibrated_date` | TEXT | 上次校准日期。 |
| `created_at` | TEXT NOT NULL | ISO datetime。 |
| `updated_at` | TEXT NOT NULL | ISO datetime。 |

### `diet_adjustment_reviews`

用途：本地 carb taper review 历史。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | review id。 |
| `review_date` | TEXT NOT NULL | review 参考日。 |
| `window_days` | INTEGER NOT NULL | review 窗口。 |
| `diet_goal_phase` | TEXT NOT NULL | review 时阶段。 |
| `diet_calculation_mode` | TEXT NOT NULL | review 时模式。 |
| `diet_plan_strategy` | TEXT NOT NULL | review 时策略。 |
| `start_avg_weight_kg` | REAL | 窗口起始平均体重。 |
| `end_avg_weight_kg` | REAL | 窗口结束平均体重。 |
| `weight_change_kg` | REAL | 体重变化。 |
| `loss_rate_pct_per_week` | REAL | 实际变化速度。 |
| `target_loss_pct_per_week` | REAL | 目标变化速度。 |
| `food_log_coverage` | REAL | 记录覆盖率。 |
| `active_training_days` | INTEGER | 有效训练天数。 |
| `suggested_action` | TEXT NOT NULL | `no_data`、`keep`、`decrease_carbs`、`pause_taper`、`increase_carbs_small` 或 `blocked_by_safety_floor`。 |
| `suggested_carb_delta_g` | REAL NOT NULL DEFAULT 0 | 建议变化量。 |
| `applied_delta_after_g` | REAL | 用户应用后的累计偏移。 |
| `confidence` | REAL NOT NULL DEFAULT 0 | 0..1。 |
| `reason_codes_json` | TEXT | reason code 列表。 |
| `user_decision` | TEXT | `pending`、`accepted`、`dismissed`、`expired`。 |
| `created_at` | TEXT NOT NULL | ISO datetime。 |
| `updated_at` | TEXT NOT NULL | ISO datetime。 |

## 运行时聚合

这些字段不单独持久化，而是在运行时由 `DailySummaryService` 聚合：

- `energy_ratio` 下的目标摄入和剩余 kcal
- base/final target calories 与 base/final protein/carbs/fat
- `carb_day_type`、`carb_adjustment_g`、`carb_taper_current_delta_g`
- 训练频率自检摘要字段
- calibration confidence、window、valid-day 摘要
- Home 和 Export 用到的 selected-day food/workout 汇总

## 数据流

Profile：

```text
ProfilePage
-> UserProfile
-> ProfileRepository.saveProfile
-> user_profile + user_weight_logs
-> DailySummaryService / ExportTableBuilder
-> Home / Profile display
```

Food：

```text
AddFoodPage / PasteAiResultPage / ManualFoodEntryPage
-> NutritionCalculator / form draft
-> FoodRepository
-> food_records + food_items
-> Home / Food display
```

Workout：

```text
AddWorkoutPage
-> built-in/custom/ad-hoc exercise definition
-> workout draft snapshot
-> workout_record_drafts
-> explicit save validation
-> WorkoutCalorieCalculator
-> WorkoutRepository
-> workout_sessions + workout_sets
-> Home / Workout display
```

Export：

```text
ProfilePage export action
-> XlsxExportService or CsvExportService
-> ExportTableBuilder
-> CustomExerciseRepository
-> local .xlsx or .zip file
```

## 导出覆盖

导出包含 food records、food items、workout records、workout sets、custom exercises、daily summary、user profile 和 diet adjustment review history。相关位置会包含策略字段、base/final target 字段、校准元数据、训练频率自检字段、本地 `nickname`、`record_name`、保存时的动作 metadata、有氧强度 metadata、自定义动作隐藏状态，以及 workout set 的原始输入值和标准化计算值。

## 未实现

- cloud sync
- accounts
- remote database
- data import
- vector database
- embedding storage
- AI conversation history
- Agent 行为日志
- semantic memory

## 代码引用

- Database：`lib/data/db/app_database.dart`
- Repositories：`lib/data/repositories/food_repository.dart`、`workout_repository.dart`、`profile_repository.dart`、`custom_exercise_repository.dart`
- Models：`lib/domain/models/*`
- Services：`lib/domain/services/*`
- Export：`lib/export/xlsx_export_service.dart`、`lib/export/csv_export_service.dart`
- App state：`lib/app.dart`、`lib/core/localization/language_controller.dart`

