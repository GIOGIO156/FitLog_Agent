# Algorithm Design

## Source-of-truth Inputs

| Input | Meaning | Used by |
| --- | --- | --- |
| `age` | BMR estimate and under-18 protection. | BMR, safety rules |
| `height_cm` | Height in centimeters. | BMR |
| `weight_kg` | Bodyweight in kilograms. | BMR, g/kg macros, workout calories |
| `sex_for_formula` | `male`, `female`, or `prefer_not_to_say`. | BMR, g/kg tables |
| `activity_level` | Compatibility activity tier derived from the shared training-frequency setting on save. | `energy_ratio` compatibility/export metadata |
| `diet_goal_phase` | `cutting` or `bulking`; phase source of truth. | Target semantics |
| `diet_calculation_mode` | `energy_ratio` or `gram_per_kg`. | Base target selection |
| `daily_energy_goal_kcal` | Daily deficit or surplus amount depending on phase. | `energy_ratio` |
| `protein_ratio_percent`, `carbs_ratio_percent`, `fat_ratio_percent` | Macro energy percentages. | `energy_ratio` |
| `training_frequency_per_week` | Shared 2/3/4/5 training-frequency setting. | g/kg table lookup, `energy_ratio` default baseline fallback, self-check |
| `diet_plan_strategy` | `none`, `carb_cycling`, or `carb_tapering`. | Strategy layer |
| Food records | Daily kcal/protein/carbs/fat intake. | Daily summary |
| Workout sessions/sets | Saved exercise calories and strength volume inputs. | Workout calories, daily summary |
| Weight logs | Daily bodyweight history. | Dynamic calorie calibration and taper review |

`training_frequency_per_week` is the user-facing shared setting. In `gram_per_kg` it stays a coarse table lookup tier; in `energy_ratio` it selects the default no-exercise factor only when local calibration has not already learned a better factor. It is still not a measure of intensity, training age, training volume, or performance demand.

## Diet Architecture

Diet computation has two stages:

1. Base target layer: applies `diet_goal_phase x diet_calculation_mode`.
2. Strategy layer: applies `diet_plan_strategy` after base targets exist.

The base layer is the source of truth for phase and mode. The strategy layer may adjust final displayed macros/target context, but it must not merge the two base calculation modes.

## BMR And Baseline

FitLog uses Mifflin-St Jeor style BMR estimates:

```text
male = 10 * weightKg + 6.25 * heightCm - 5 * age + 5
female = 10 * weightKg + 6.25 * heightCm - 5 * age - 161
prefer_not_to_say = average(male, female)
```

Non-exercise baseline:

```text
baselineNoExerciseTdee = bmr * lifestyleFactorUsed
```

`lifestyleFactorUsed` comes from dynamic calibration when available and valid; otherwise it falls back to the shared training-frequency default:

| `training_frequency_per_week` | Default non-exercise factor | Compatibility `activity_level` |
| --- | ---: |
| 2 | 1.20 | `sedentary` |
| 3 | 1.30 | `lightly_active` |
| 4 | 1.425 | `moderately_active` |
| 5 | 1.60 | `very_active` |

## `energy_ratio`

`energy_ratio` is the kcal-primary mode.

```text
if diet_goal_phase == cutting:
  noExerciseTarget = baselineNoExerciseTdee - dailyEnergyGoalKcal

if diet_goal_phase == bulking:
  noExerciseTarget = baselineNoExerciseTdee + dailyEnergyGoalKcal

targetIntake = noExerciseTarget + loggedNetExerciseKcal
remainingCalories = targetIntake - caloriesInToday
```

Macro targets are converted from target kcal by normalized macro percentages:

```text
ratioTotal = proteinRatioPercent + carbsRatioPercent + fatRatioPercent
proteinRatio = proteinRatioPercent / ratioTotal
carbsRatio = carbsRatioPercent / ratioTotal
fatRatio = fatRatioPercent / ratioTotal

targetProteinG = targetIntakeKcal * proteinRatio / 4
targetCarbsG = targetIntakeKcal * carbsRatio / 4
targetFatG = targetIntakeKcal * fatRatio / 9
macroEnergyEquivalentKcal = protein*4 + carbs*4 + fat*9
```

If ratios are invalid at calculation time, the calculator falls back to 30/40/30. Profile save validation requires the visible ratio fields to sum to 100.

## `gram_per_kg`

`gram_per_kg` is the macro-primary mode.

```text
targetProteinG = weightKg * proteinCoeff
targetCarbsG = weightKg * carbsCoeff
targetFatG = weightKg * fatCoeff
macroEnergyEquivalentKcal = protein*4 + carbs*4 + fat*9
targetIntake = 0
remainingCalories = 0
```

Boundaries:

- It uses only bodyweight, sex option, goal phase, and `training_frequency_per_week`.
- It does not use BMR, `activity_level`, `daily_energy_goal_kcal`, logged exercise calories, or macro ratio percentages.
- `macroEnergyEquivalentKcal` is auxiliary analysis/export data, not the kcal target counter.
- For `prefer_not_to_say`, use the same-frequency male/female average.

Cutting table, protein/carbs/fat g/kg:

| Sex | 2 days | 3 days | 4 days | 5 days |
| --- | --- | --- | --- | --- |
| male | 1.4 / 1.5 / 0.8 | 1.6 / 1.8 / 0.8 | 1.7 / 2.0 / 0.9 | 1.8 / 2.2 / 1.0 |
| female | 1.4 / 1.4 / 1.0 | 1.6 / 1.6 / 1.0 | 1.7 / 1.7 / 1.1 | 1.8 / 1.9 / 1.2 |

Bulking table, protein/carbs/fat g/kg:

| Sex | 2 days | 3 days | 4 days | 5 days |
| --- | --- | --- | --- | --- |
| male | 1.6 / 3.0 / 0.8 | 1.7 / 3.4 / 0.9 | 1.8 / 3.8 / 0.9 | 2.0 / 4.2 / 1.0 |
| female | 1.6 / 2.8 / 0.9 | 1.7 / 3.1 / 1.0 | 1.8 / 3.4 / 1.0 | 2.0 / 3.8 / 1.1 |

## Diet Plan Strategy Layer

Applicable strategies:

- `none`: final targets equal base targets.
- `carb_cycling`: cutting-only, adult-only weekly carb redistribution.
- `carb_tapering`: cutting-only, adult-only review suggestion flow.

Under-18 users cannot enable cutting carb strategies.

### `carb_cycling`

The strategy redistributes carbs across high/medium/low days while preserving the normalized weekly average.

```text
rawMultiplier(day) = high / medium / low
sumRaw = sum(rawMultiplier over 7 days)
normalizer = 7 / sumRaw
normalizedMultiplier(day) = rawMultiplier(day) * normalizer

finalCarbsG(day) = baseCarbsG * normalizedMultiplier(day)
finalProteinG(day) = baseProteinG
finalFatG(day) = baseFatG
finalMacroEnergyEquivalentKcal = P*4 + C*4 + F*9
```

Safety floor:

```text
minCarbsG = max(weightKg * 1.2, 100)
```

If final carbs would fall below the floor, FitLog clamps carbs and adds `carb_floor_applied`.

### `carb_tapering`

The strategy reviews rolling weight trend, food-log coverage, and training stability. It never auto-applies.

Review windows: default 14 days, with 21/28/7 options.

Trend formula:

```text
startAvgWeight = first 7-day average in window
endAvgWeight = last 7-day average in window
weightChangeKg = endAvgWeight - startAvgWeight
lossRatePctPerWeek = (-weightChangeKg / startAvgWeight) * 100 * 7 / windowDays
```

Data floor:

- at least 7 weight logs in the window
- food log coverage at least 0.70
- both early and late window segments need weight data

Decision behavior:

- slower than target minus tolerance: `decrease_carbs`
- within target band: `keep`
- faster than target plus tolerance: `pause_taper`
- insufficient data: `no_data`
- material training drop: prefer `keep`
- projected carbs below floor: `blocked_by_safety_floor`

Application formula after user confirmation:

```text
taperedCarbsG = max(baseCarbsG + carb_taper_current_delta_g, minCarbsG)
```

`carb_taper_current_delta_g` is cumulative relative to base carbs.

## Food Intake Summary

Daily intake is computed from saved food records for the selected date:

```text
caloriesIn = sum(food_records.calories_kcal)
proteinG = sum(food_records.protein_g)
carbsG = sum(food_records.carbs_g)
fatG = sum(food_records.fat_g)
```

`DailySummary` is runtime aggregate data. It is not stored as a database table.

## Workout Calories

Workout calories are calculated when workout records are created or edited and then saved on `workout_sessions.estimated_calories`.

Cardio uses net MET to avoid double counting resting baseline:

```text
netMet = max(0, MET - 1)
netCardioKcal = netMet * 3.5 * bodyWeightKg / 200 * durationMinutes
```

The legacy fixed MET map remains the fallback when the calculator is called with only an exercise name:

| Exercise | MET |
| --- | ---: |
| Walking | 4.3 |
| Running | 8 |
| Cycling | 6 |
| Rowing Machine | 7 |
| Stair Climber | 8 |

Saved built-in and custom cardio sessions can also carry `cardio_intensity_basis`, `cardio_met`, and optional `cardio_active_minutes`. The user-facing intensity basis asks how long the user could maintain the same pace: 60+ minutes, 30-60 minutes, 10-30 minutes, 3-10 minutes, or under 3 minutes with rests. For the under-3-minute interval option, FitLog uses active movement minutes when provided, not the whole elapsed session duration.

Strength uses volume-driven net calories:

1. Prefer completed sets with valid calculation reps; if none exist, use all valid entered sets.
2. Preserve user input fields and calculate normalized fields for the calorie heuristic.
3. Per-side load becomes `calculation_load_kg = input_weight_kg * 2`.
4. Per-side reps become `calculation_reps = input_reps * 2`.
5. Duration-based strength sets, such as plank, store `input_duration_seconds` and use a bounded time-under-tension equivalent for `calculation_reps`.
6. Bodyweight movements use `bodyWeightKg * bodyweightShare + externalLoadKg` as effective load.
7. Assisted bodyweight movements store assistance in the input weight field, and use `max(0, bodyWeightKg - assistanceKg)` as effective load.
8. Non-bodyweight movements use normalized external load.
9. Compute `totalVolumeKg = sum(effectiveLoadKg * calculationReps)`.
10. Select internal movement profile coefficients from the saved session snapshot or current exercise definition.
11. Use duration only in a capped recovery-density modifier, not as linear calorie accumulation.

```text
activeLiftingKcal =
  totalVolumeKg * strengthCoefficient * bodyFactor * intensityFactor

postTrainingRecoveryKcal =
  activeLiftingKcal * postTrainingRecoveryRate * recoveryDensityModifier

muscleRepairAdaptationKcal =
  activeLiftingKcal * muscleRepairAdaptationRate

netStrengthKcal =
  activeLiftingKcal + postTrainingRecoveryKcal + muscleRepairAdaptationKcal
```

Movement coefficients:

| Profile | strengthCoefficient | postTrainingRecoveryRate | muscleRepairAdaptationRate |
| --- | ---: | ---: | ---: |
| `upper_body_compound` | 0.013 | 0.28 | 0.12 |
| `lower_body_compound` | 0.019 | 0.34 | 0.16 |
| `isolation` | 0.0085 | 0.12 | 0.06 |
| `full_body_power_or_high_density` | 0.024 | 0.45 | 0.20 |

Additional modifiers:

```text
bodyFactor = clamp(sqrt(bodyWeightKg / 80), 0.85, 1.15)
recoveryDensityModifier = clamp(1 + (densityRatio - 1) * 0.28, 0.85, 1.35)
```

Workout calories are added to `energy_ratio` target intake. They do not directly change g/kg macro targets.

## Dynamic Calorie Calibration

Dynamic calibration updates the non-exercise lifestyle factor from local history.

Rules:

- candidate windows: 28 / 21 / 14 / 7 days
- at most one calibration every 7 days
- use 7-day start/end rolling average weight
- require sufficient food logs and weight logs
- use 7700 kcal/kg as a rough historical approximation
- smooth updates with EWMA
- cap each update and clamp the global factor

```text
observedTotalTdee = avgDailyIntake - weightChangeKg * 7700 / windowDays
observedNoExerciseTdee = observedTotalTdee - avgDailyExercise
observedLifestyleFactor = observedNoExerciseTdee / avgBmr
newFactor = oldFactor * 0.8 + observedLifestyleFactor * 0.2
```

Bounds:

- per-update step cap: +/-0.03
- global factor range: 1.10 to 1.70
- minimum confidence: 0.35

Calibration is independent from training-frequency self-check.

## Shared Training-frequency Self-check

Self-check applies in both `energy_ratio` and `gram_per_kg`.

Valid training day rule: count distinct dates, not sessions. A day is valid if any condition is true:

1. at least one strength session
2. cardio total duration is at least 20 minutes
3. daily total estimated exercise calories is at least 80 kcal

Recommendation:

```text
averageWeekly = activeTrainingDays / periodDays * 7
recommended = clamp(round(averageWeekly), 2, 5)
```

Periods: 7 / 14 / 21 / 28 days.

Cooldown: show/apply feedback no more frequently than every 7 days through `last_macro_self_check_at`.

Self-check updates only the shared `training_frequency_per_week` setting when the user accepts a suggestion. It does not directly update calibrated `lifestyle_factor_non_exercise`, does not use weight-change equations, and does not use observed TDEE EWMA.

## Algorithm Boundaries

- All current target, summary, workout calorie, calibration, strategy, and self-check calculations are local deterministic Dart code.
- External AI prompt copy and JSON paste do not constitute app-internal AI reasoning.
- No current algorithm uses RAG, vector search, semantic memory, tool calling, or an Agent loop.
- FitLog estimates are for personal tracking and are not medical advice.

## Code References

- `lib/domain/services/daily_summary_service.dart`
- `lib/domain/services/macro_target_calculator.dart`
- `lib/domain/services/workout_calorie_calculator.dart`
- `lib/core/constants/exercise_catalog.dart`
- `lib/core/constants/exercise_definition.dart`
- `lib/domain/models/workout_session.dart`
- `lib/domain/models/workout_set.dart`
- `lib/domain/services/training_frequency_self_check_service.dart`
- `lib/domain/services/diet_plan_strategy_service.dart`
- `lib/domain/services/carb_cycling_calculator.dart`
- `lib/domain/services/carb_taper_review_service.dart`
- `lib/domain/services/nutrition_calculator.dart`
- `lib/domain/models/daily_summary.dart`
- `lib/domain/models/user_profile.dart`
- `lib/domain/models/diet_adjustment_review.dart`
- `test/macro_target_calculator_test.dart`
- `test/workout_calorie_calculator_test.dart`
