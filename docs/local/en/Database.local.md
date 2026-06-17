# Database Design

## Storage Overview

FitLog Local stores business data locally.

| Storage | Purpose | Remote sync |
| --- | --- | --- |
| SQLite / `sqflite` | Profile, food records, food items, workout sessions, workout sets, custom exercises, workout record drafts, weight logs, calibration state, diet adjustment reviews. | No |
| SharedPreferences | UI language preference, currently `language_code`. | No |
| Local files | XLSX and CSV ZIP exports in the app documents directory. | No |
| In-memory providers | App services, refresh version, selected date, language state. | No |

Database name: `fitlog_local.db`.

Current SQLite schema version: `11`.

Foreign keys are enabled with `PRAGMA foreign_keys = ON`.

## Migration Policy

Migrations are additive and must preserve existing local data.

| Version | Change |
| ---: | --- |
| 1 | Initial profile, food, workout, and set tables. |
| 2 | Added `workout_sessions.plan_id`. |
| 3 | Added profile macro ratio fields: `protein_ratio_percent`, `carbs_ratio_percent`, `fat_ratio_percent`. |
| 4 | Added `user_weight_logs` and `calorie_calibration_state`. |
| 5 | Added `diet_calculation_mode`, `training_frequency_per_week`, macro self-check fields. |
| 6 | Added `user_profile.diet_goal_phase TEXT NOT NULL DEFAULT 'cutting'`. |
| 7 | Added diet strategy profile fields and `diet_adjustment_reviews`. |
| 8 | Added `workout_sessions.record_name`. |
| 9 | Added local-only `user_profile.nickname`. |
| 10 | Added `workout_record_drafts` for one active unsaved workout editor state. |
| 11 | Added reusable `custom_exercises`, workout-session exercise snapshots, cardio-intensity metadata, and raw-vs-calculation workout-set fields. |

Compatibility rules:

- Never merge or rewrite old migrations just because current schema changed.
- Prefer additive columns/tables over destructive rebuilds.
- Existing users default to safe compatibility values such as `cutting`, `energy_ratio`, and `none`.
- `daily_energy_goal_type` remains stored for compatibility, but `diet_goal_phase` is the phase source of truth.

## Tables

### `user_profile`

Purpose: singleton user profile, diet settings, strategy settings, and self-check settings. Repository uses `id = 1`.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | INTEGER PRIMARY KEY | Singleton profile id. |
| `nickname` | TEXT | Local-only UI nickname used by Home greeting; not an account field. |
| `age` | INTEGER NOT NULL | BMR and under-18 protection. |
| `height_cm` | REAL NOT NULL | BMR. |
| `weight_kg` | REAL NOT NULL | BMR, g/kg macros, workout calories. |
| `sex_for_formula` | TEXT NOT NULL | `male`, `female`, `prefer_not_to_say`. |
| `activity_level` | TEXT NOT NULL | Compatibility/export activity tier derived from `training_frequency_per_week` on profile save. |
| `daily_energy_goal_type` | TEXT NOT NULL | Compatibility field: `maintenance`, `deficit`, `surplus`. |
| `daily_energy_goal_kcal` | REAL NOT NULL | Deficit or surplus amount depending on `diet_goal_phase`. |
| `protein_ratio_percent` | REAL NOT NULL | `energy_ratio` macro percentage. |
| `carbs_ratio_percent` | REAL NOT NULL | `energy_ratio` macro percentage. |
| `fat_ratio_percent` | REAL NOT NULL | `energy_ratio` macro percentage. |
| `diet_goal_phase` | TEXT NOT NULL DEFAULT `cutting` | `cutting` or `bulking`; phase source of truth. |
| `diet_calculation_mode` | TEXT NOT NULL DEFAULT `energy_ratio` | `energy_ratio` or `gram_per_kg`. |
| `diet_plan_strategy` | TEXT NOT NULL DEFAULT `none` | `none`, `carb_cycling`, `carb_tapering`. |
| `carb_cycle_pattern_json` | TEXT | Weekday to high/medium/low mapping. |
| `carb_cycle_high_multiplier` | REAL NOT NULL DEFAULT 1.20 | High day multiplier. |
| `carb_cycle_medium_multiplier` | REAL NOT NULL DEFAULT 1.00 | Medium day multiplier. |
| `carb_cycle_low_multiplier` | REAL NOT NULL DEFAULT 0.80 | Low day multiplier. |
| `carb_taper_review_period_days` | INTEGER NOT NULL DEFAULT 14 | 14/21/28/7. |
| `carb_taper_target_loss_pct_per_week` | REAL NOT NULL DEFAULT 0.50 | Clamped by app constants. |
| `carb_taper_step_g` | REAL NOT NULL DEFAULT 10.0 | 5/10/15/20 style taper step. |
| `carb_taper_current_delta_g` | REAL NOT NULL DEFAULT 0.0 | Cumulative carb offset. |
| `last_carb_taper_review_at` | TEXT | Last taper review timestamp/date. |
| `training_frequency_per_week` | INTEGER NOT NULL DEFAULT 3 | Shared 2/3/4/5 training-frequency setting; used by g/kg tables, `energy_ratio` default-factor fallback, and self-check. |
| `macro_self_check_period_days` | INTEGER NOT NULL DEFAULT 14 | 7/14/21/28. |
| `macro_self_check_enabled` | INTEGER NOT NULL DEFAULT 1 | Boolean stored as 0/1. |
| `last_macro_self_check_at` | TEXT | Shared training-frequency self-check cooldown timestamp/date. |
| `created_at` | TEXT NOT NULL | ISO datetime. |
| `updated_at` | TEXT NOT NULL | ISO datetime. |

### `food_records`

Purpose: meal-level food records.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | Record id. |
| `date` | TEXT NOT NULL | `yyyy-MM-dd`. |
| `meal_name` | TEXT NOT NULL | Meal label. |
| `total_weight_g` | REAL NOT NULL | Total estimated weight. |
| `calories_kcal` | REAL NOT NULL | Meal kcal. |
| `protein_g` | REAL NOT NULL | Protein grams. |
| `carbs_g` | REAL NOT NULL | Carbohydrate grams. |
| `fat_g` | REAL NOT NULL | Fat grams. |
| `confidence` | REAL | External estimate confidence; often null for manual records. |
| `estimation_notes` | TEXT | Notes from external estimate or user. |
| `source` | TEXT NOT NULL | `ai_paste` or `manual`. |
| `created_at` | TEXT NOT NULL | ISO datetime. |
| `updated_at` | TEXT NOT NULL | ISO datetime. |

### `food_items`

Purpose: item rows inside a meal. Deleted with parent food record.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | Item id. |
| `food_record_id` | INTEGER NOT NULL | FK to `food_records.id`, ON DELETE CASCADE. |
| `name` | TEXT NOT NULL | Food item name. |
| `estimated_weight_g` | REAL NOT NULL | Estimated item weight. |
| `calories_kcal` | REAL NOT NULL | Item kcal. |
| `protein_g` | REAL NOT NULL | Protein grams. |
| `carbs_g` | REAL NOT NULL | Carbohydrate grams. |
| `fat_g` | REAL NOT NULL | Fat grams. |
| `notes` | TEXT | Optional item notes. |

### `workout_sessions`

Purpose: one saved exercise session. A multi-exercise workout record is represented by multiple sessions sharing `plan_id`.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | Session id. |
| `plan_id` | TEXT | Shared id for a workout record group. |
| `record_name` | TEXT | User-facing workout record name, duplicated across the group. |
| `date` | TEXT NOT NULL | `yyyy-MM-dd`. |
| `body_part` | TEXT NOT NULL | Body part/category. |
| `secondary_body_part` | TEXT | Optional secondary body part for strength exercise metadata. |
| `exercise_name` | TEXT NOT NULL | Exercise display name. |
| `exercise_key` | TEXT | Built-in, custom, or ad-hoc exercise definition key at save time. |
| `exercise_source` | TEXT | `builtin`, `custom`, or `ad_hoc`. |
| `exercise_type` | TEXT NOT NULL | `strength` or `cardio`. |
| `duration_minutes` | INTEGER NOT NULL | Per-exercise duration. |
| `intensity` | TEXT NOT NULL | Legacy intensity field, kept for compatibility. |
| `strength_profile` | TEXT | Internal strength calorie profile used for this saved session. |
| `load_input_mode` | TEXT | Saved load-entry mode, such as `total_load`, `per_side_load`, `bodyweight_added`, or `assistance_load`. |
| `reps_input_mode` | TEXT | Saved repetition-entry mode, such as `total_reps` or `per_side_reps`. |
| `set_metric_type` | TEXT | Saved strength set metric, currently `reps` or `duration_seconds`. |
| `cardio_met` | REAL | Saved MET value used for cardio calorie calculation. |
| `cardio_intensity_basis` | TEXT | Saved cardio intensity basis, such as `moderate_30_to_60` or `interval_under_3`. |
| `cardio_active_minutes` | INTEGER | Active movement minutes for interval-style cardio when less than the elapsed duration. |
| `body_weight_kg_at_calculation` | REAL | Bodyweight used when workout calories were calculated. |
| `exercise_snapshot_json` | TEXT | JSON snapshot of exercise-definition metadata needed to explain/replay the saved record. |
| `estimated_calories` | REAL NOT NULL | Saved net exercise kcal estimate. |
| `notes` | TEXT | Optional notes. |
| `created_at` | TEXT NOT NULL | Timeline/start-time ordering. |
| `updated_at` | TEXT NOT NULL | ISO datetime. |

Workout record behavior:

- `plan_id` remains the grouping key.
- No separate parent workout-record table exists.
- Editing a saved record replaces the full `plan_id` group transactionally.
- Summary duration, calories, volume, and set count are derived from persisted sessions/sets.

### `workout_sets`

Purpose: strength set rows. Deleted with parent workout session.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | Set id. |
| `workout_session_id` | INTEGER NOT NULL | FK to `workout_sessions.id`, ON DELETE CASCADE. |
| `set_number` | INTEGER NOT NULL | Saved set order. |
| `weight_kg` | REAL NOT NULL | Compatibility calculation load; for new rows this mirrors the normalized load used by the calculator. |
| `reps` | INTEGER NOT NULL | Compatibility calculation repetitions; for duration-based strength sets this stores the normalized calculation count. |
| `input_weight_kg` | REAL | Raw load value entered by the user, before per-side/bodyweight/assistance interpretation. |
| `input_reps` | INTEGER | Raw repetition value entered by the user, before per-side interpretation. |
| `input_duration_seconds` | INTEGER | Raw single-set duration for duration-based strength sets such as plank. |
| `calculation_load_kg` | REAL | Normalized load used by strength calorie and volume calculations. |
| `calculation_reps` | INTEGER | Normalized repetitions used by strength calorie and volume calculations. |
| `load_input_mode` | TEXT | Per-set copy of the saved load-entry mode. |
| `reps_input_mode` | TEXT | Per-set copy of the saved repetition-entry mode. |
| `set_metric_type` | TEXT | Per-set copy of the saved set metric type. |
| `is_completed` | INTEGER NOT NULL | Boolean stored as 0/1. |
| `completed_at` | TEXT | ISO datetime when completed. |

Current save behavior:

- Completed strength sets are persisted.
- Unchecked sets are discarded before insert/update.
- Remaining sets are renumbered from `1..n`.
- `is_completed` remains stored for compatibility, but saved strength sets are expected to be completed sets.
- New rows keep both user-facing input values and normalized calculation values so per-side dumbbell/cable load, per-side reps, assisted bodyweight load, bodyweight plus added load, and duration-based sets remain explainable after save.

### `custom_exercises`

Purpose: reusable local exercise definitions created by the user. Hidden rows are kept for history compatibility but excluded from the active picker.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | Custom exercise row id. |
| `exercise_key` | TEXT NOT NULL UNIQUE | Stable local key used by saved workout sessions. |
| `name` | TEXT NOT NULL | User-facing custom exercise name. |
| `exercise_type` | TEXT NOT NULL | `strength` or `cardio`. |
| `body_part` | TEXT NOT NULL | Primary body part for strength; `Cardio` for custom cardio. |
| `secondary_body_part` | TEXT | Optional secondary strength body part. |
| `strength_structure` | TEXT | User-facing strength structure mapped to an internal profile, such as `compound`, `isolation`, or `full_body_auto`. |
| `strength_profile` | TEXT | Internal strength calorie profile used by saved records. |
| `load_input_mode` | TEXT | Default strength load-entry mode. |
| `reps_input_mode` | TEXT | Default strength repetition-entry mode. |
| `set_metric_type` | TEXT | Default strength set metric. |
| `default_cardio_intensity` | TEXT | Default cardio intensity basis for custom cardio. |
| `is_hidden` | INTEGER NOT NULL DEFAULT 0 | Boolean stored as 0/1; hidden custom exercises stay available for history/export, but are excluded from the active picker. |
| `created_at` | TEXT NOT NULL | ISO datetime. |
| `updated_at` | TEXT NOT NULL | ISO datetime. |

### `workout_record_drafts`

Purpose: one active unsaved workout editor state, stored separately from saved workout history.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | TEXT PRIMARY KEY | Fixed active draft id. |
| `kind` | TEXT NOT NULL | `new_record` or `edit_record`. |
| `source_plan_id` | TEXT | Saved-record `plan_id` when the draft started from an existing grouped workout record. |
| `source_session_id` | INTEGER | Saved single-session id when the draft started from an older non-grouped workout record. |
| `date` | TEXT NOT NULL | Draft date shown in the editor. |
| `record_name` | TEXT NOT NULL | Draft workout-record name. |
| `notes` | TEXT NOT NULL | Draft notes. |
| `payload_json` | TEXT NOT NULL | Serialized editor snapshot with draft metadata, exercise order, duration values, set rows, default-hint state, and completed flags. |
| `created_at` | TEXT NOT NULL | Draft creation timestamp. |
| `updated_at` | TEXT NOT NULL | Last draft autosave timestamp. |

Draft behavior:

- The draft table is not part of workout history and does not appear in saved workout lists.
- The draft table does not feed Home workout totals or export coverage.
- Explicit save validates current editor state first, then writes `workout_sessions` and `workout_sets`, then deletes the draft row.

### `user_weight_logs`

Purpose: daily bodyweight history for calibration and review.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | Weight log id. |
| `date` | TEXT NOT NULL UNIQUE | One entry per day. |
| `weight_kg` | REAL NOT NULL | Bodyweight. |
| `source` | TEXT NOT NULL | Currently written from profile save. |
| `created_at` | TEXT NOT NULL | ISO datetime. |
| `updated_at` | TEXT NOT NULL | ISO datetime. |

### `calorie_calibration_state`

Purpose: singleton dynamic calorie calibration state.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | INTEGER PRIMARY KEY CHECK (`id = 1`) | Singleton row. |
| `lifestyle_factor` | REAL NOT NULL | Calibrated non-exercise lifestyle factor. |
| `confidence` | REAL NOT NULL | 0 to 1 confidence. |
| `window_days` | INTEGER NOT NULL | 7/14/21/28. |
| `valid_days` | INTEGER NOT NULL | Food-log valid day count. |
| `last_calibrated_date` | TEXT | `yyyy-MM-dd`. |
| `created_at` | TEXT NOT NULL | ISO datetime. |
| `updated_at` | TEXT NOT NULL | ISO datetime. |

### `diet_adjustment_reviews`

Purpose: local carb taper review history and user decision record.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | Review id. |
| `review_date` | TEXT NOT NULL | Review date. |
| `window_days` | INTEGER NOT NULL | Review window. |
| `diet_goal_phase` | TEXT NOT NULL | Phase at review time. |
| `diet_calculation_mode` | TEXT NOT NULL | Mode at review time. |
| `diet_plan_strategy` | TEXT NOT NULL | Strategy at review time. |
| `start_avg_weight_kg` | REAL | Start average weight. |
| `end_avg_weight_kg` | REAL | End average weight. |
| `weight_change_kg` | REAL | End minus start. |
| `loss_rate_pct_per_week` | REAL | Rolling trend. |
| `target_loss_pct_per_week` | REAL | User target. |
| `food_log_coverage` | REAL | Coverage ratio. |
| `active_training_days` | INTEGER | Training stability input. |
| `suggested_action` | TEXT NOT NULL | `no_data`, `keep`, `decrease_carbs`, `pause_taper`, `increase_carbs_small`, or `blocked_by_safety_floor`. |
| `suggested_carb_delta_g` | REAL NOT NULL DEFAULT 0 | Suggested change. |
| `applied_delta_after_g` | REAL | Resulting cumulative delta if accepted. |
| `confidence` | REAL NOT NULL DEFAULT 0 | Review confidence. |
| `reason_codes_json` | TEXT | Internal reason codes. |
| `user_decision` | TEXT | `pending`, `accepted`, `dismissed`, or `expired`. |
| `created_at` | TEXT NOT NULL | ISO datetime. |
| `updated_at` | TEXT NOT NULL | ISO datetime. |

## Runtime Aggregates

`DailySummary` is not a table. It is assembled at runtime from profile data, food records, workout records, calibration state, self-check results, and strategy results.

Derived data includes:

- intake kcal/protein/carbs/fat
- exercise calories
- BMR and no-exercise TDEE reference
- target intake and remaining kcal for `energy_ratio`
- macro targets and remaining macros
- base and final strategy targets
- strategy reason codes and confidence
- calibration metadata
- self-check metadata
- selected-day food and workout record lists

## Data Flows

Profile:

```text
ProfilePage
-> UserProfile
-> ProfileRepository.saveProfile
-> user_profile + user_weight_logs
-> DailySummaryService
-> Home/Profile display
```

Food:

```text
AddFoodPage / PasteAiResultPage / ManualFoodEntryPage
-> FoodRecord + FoodItem
-> FoodRepository
-> food_records + food_items
-> DailySummaryService
-> Home/Food display
```

Workout:

```text
AddWorkoutPage
-> built-in/custom/ad-hoc exercise definition
-> workout draft snapshot
-> workout_record_drafts
-> explicit save validation
-> WorkoutCalorieCalculator
-> WorkoutSession + WorkoutSet
-> WorkoutRepository
-> workout_sessions + workout_sets
-> DailySummaryService
-> Home/Workout display
```

Export:

```text
ProfilePage export action
-> XlsxExportService or CsvExportService
-> repositories + CustomExerciseRepository + DailySummaryService
-> local .xlsx or .zip file
```

## Export Coverage

Exports include food records, food items, workout records, workout sets, custom exercises, daily summary, user profile, and diet adjustment review history. Strategy fields, base/final target fields, calibration metadata, training-frequency self-check fields, local-only `nickname`, `record_name`, saved exercise metadata, cardio-intensity metadata, custom-exercise hidden state, and workout-set raw/calculation values are included where relevant.

## Not Implemented

- cloud sync
- accounts
- remote database
- data import
- vector database
- embedding storage
- AI conversation history
- Agent action logs
- semantic memory

## Code References

- Database: `lib/data/db/app_database.dart`
- Repositories: `lib/data/repositories/food_repository.dart`, `workout_repository.dart`, `profile_repository.dart`, `custom_exercise_repository.dart`
- Models: `lib/domain/models/*`
- Services: `lib/domain/services/*`
- Export: `lib/export/xlsx_export_service.dart`, `lib/export/csv_export_service.dart`
- App state: `lib/app.dart`, `lib/core/localization/language_controller.dart`
