# Algorithm Design

## Purpose

This document defines FitLog_Agent V1 algorithm boundaries.

The copied Local implementation already contains deterministic Dart algorithms for diet targets, food summaries, workout calories, dynamic calibration, training-frequency self-check, carb cycling, and carb taper review. Agent V1 may use these outputs as context, but the LLM must not replace them as the source of truth.

## Source-Of-Truth Inputs

| Input | Meaning | Used by |
| --- | --- | --- |
| `age` | BMR estimate and under-18 protection. | BMR, safety rules |
| `height_cm` | Height in centimeters. | BMR |
| `weight_kg` | Bodyweight in kilograms. | BMR, g/kg macros, workout calories |
| `sex_for_formula` | `male`, `female`, or `prefer_not_to_say`. | BMR, g/kg tables |
| `training_frequency_per_week` | Shared 2/3/4/5 setting. | g/kg tables, `energy_ratio` fallback, self-check |
| `diet_goal_phase` | `cutting` or `bulking`. | Target semantics |
| `diet_calculation_mode` | `energy_ratio` or `gram_per_kg`. | Base target selection |
| `daily_energy_goal_kcal` | Deficit or surplus amount depending on phase. | `energy_ratio` |
| `protein_ratio_percent`, `carbs_ratio_percent`, `fat_ratio_percent` | Macro energy percentages. | `energy_ratio` |
| `diet_plan_strategy` | `none`, `carb_cycling`, or `carb_tapering`. | Strategy layer |
| Food records | Daily intake; signed-in official records come from cloud storage. | Daily summary, AI context summaries |
| Workout sessions/sets | Saved exercise calories and volume inputs; signed-in official records come from cloud storage. | Workout calories, daily summary, AI context summaries |
| Body metric logs | Historical weight, body-fat, and waist records; signed-in official history comes from cloud `body_metric_logs`. | Calibration, taper review, weekly review context |
| Cloud Profile | Account-bound profile in Agent V1. | AI personalization and context |

Agent V1 rule: AI should receive compact summaries built from Cloud Profile, Cloud Records, daily summaries, or controlled summary builders. It should not directly invent official targets or override deterministic calculations; local SQLite cache must not become the authoritative AI or product source.

## Diet Architecture

Diet computation has two stages:

1. Base target layer: `diet_goal_phase x diet_calculation_mode`.
2. Strategy layer: `diet_plan_strategy` applied after base targets exist.

Hard boundaries:

- `diet_goal_phase` is the source of truth for cutting/bulking.
- `diet_calculation_mode` decides whether the app is kcal-primary or macro-primary.
- `diet_plan_strategy` modifies context after base targets, but does not merge modes.
- AI may explain these layers, but must not silently change them.

## BMR And Non-Exercise Baseline

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

`lifestyleFactorUsed` comes from dynamic calibration when available and valid. Otherwise it falls back to the shared training-frequency default:

| `training_frequency_per_week` | Default non-exercise factor | Compatibility `activity_level` |
| --- | ---: | --- |
| 2 | 1.20 | `sedentary` |
| 3 | 1.30 | `lightly_active` |
| 4 | 1.425 | `moderately_active` |
| 5 | 1.60 | `very_active` |

## `energy_ratio`

`energy_ratio` is kcal-primary.

```text
if diet_goal_phase == cutting:
  noExerciseTarget = baselineNoExerciseTdee - dailyEnergyGoalKcal

if diet_goal_phase == bulking:
  noExerciseTarget = baselineNoExerciseTdee + dailyEnergyGoalKcal

targetIntake = noExerciseTarget + loggedNetExerciseKcal
remainingCalories = targetIntake - caloriesInToday
```

Macro targets are derived from target kcal and normalized percentages:

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

If ratios are invalid during calculation, the calculator falls back to 30/40/30. Profile save validation should require visible ratio fields to sum to 100.

AI boundary:

- Meal advice may use remaining kcal/macros.
- AI must not silently edit ratio fields or daily energy goal.

## `gram_per_kg`

`gram_per_kg` is macro-primary.

```text
targetProteinG = weightKg * proteinCoeff
targetCarbsG = weightKg * carbsCoeff
targetFatG = weightKg * fatCoeff
macroEnergyEquivalentKcal = protein*4 + carbs*4 + fat*9
targetIntake = 0
remainingCalories = 0
```

Boundaries:

- Uses bodyweight, sex option, goal phase, and `training_frequency_per_week`.
- Does not use BMR, `activity_level`, `daily_energy_goal_kcal`, logged exercise calories, or macro ratio percentages.
- `macroEnergyEquivalentKcal` is auxiliary information, not the kcal target counter.
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

AI boundary:

- Meal advice should treat macro grams as primary in this mode.
- AI should not describe remaining kcal as the main target.

## Strategy Layer

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

If final carbs would fall below the floor, FitLog clamps carbs and marks the floor condition.

AI boundary:

- AI may explain the current day type and macro context.
- AI must not silently change the weekly pattern or multipliers.

### `carb_tapering`

The strategy reviews rolling weight trend, food-log coverage, and training stability. It never auto-applies.

Review windows: 7/14/21/28 days, with 14 as the default.

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

AI boundary:

- Weekly Review may discuss taper status.
- AI must not apply taper changes.
- Official application remains a user-confirmed local review flow.

## Food Intake Summary

Daily intake is computed from saved food records for the selected date:

```text
caloriesIn = sum(food_records.calories_kcal)
proteinG = sum(food_records.protein_g)
carbsG = sum(food_records.carbs_g)
fatG = sum(food_records.fat_g)
```

`DailySummary` is runtime aggregate data, not a stored table.

Agent V1 context builders should expose selected-day or recent-window summaries, not raw food history by default.

## Food Draft Estimation

Agent V1 food estimation is an AI workflow, but official persistence still follows deterministic validation and user confirmation.

Food Draft output should be schema-validated and include:

- meal name
- item list
- estimated weights
- kcal/protein/carbs/fat
- confidence or uncertainty notes
- missing information questions when needed
- source metadata

Rules:

- Ask follow-up questions when food type, meat type, portion size, eaten amount, or cooking method is unclear.
- Treat AI nutrition as an estimate, not exact truth.
- Let the user lightly edit draft values in chat.
- Save only after user confirmation.
- Official save writes normal `food_records` and `food_items`.

## Workout Calories

Workout calories are calculated when workout records are created or edited and then saved on `workout_sessions.estimated_calories`.

### Cardio

Cardio uses net MET to avoid double-counting resting baseline:

```text
netMet = max(0, MET - 1)
netCardioKcal = netMet * 3.5 * bodyWeightKg / 200 * durationMinutes
```

Legacy fixed MET fallback:

| Exercise | MET |
| --- | ---: |
| Walking | 4.3 |
| Running | 8 |
| Cycling | 6 |
| Rowing Machine | 7 |
| Stair Climber | 8 |

Saved cardio sessions may also store:

- `cardio_intensity_basis`
- `cardio_met`
- `cardio_active_minutes`

For under-3-minute interval style cardio, active movement minutes should be used instead of full elapsed rest-inclusive duration.

### Strength

Strength uses volume-driven net calories:

1. Prefer completed sets with valid calculation reps; if none exist, use all valid entered sets.
2. Preserve user input fields and calculate normalized fields.
3. Per-side load becomes `calculation_load_kg = input_weight_kg * 2`.
4. Per-side reps become `calculation_reps = input_reps * 2`.
5. Duration-based strength sets store `input_duration_seconds` and use bounded time-under-tension equivalents.
6. Bodyweight movements use `bodyWeightKg * bodyweightShare + externalLoadKg`.
7. Assisted bodyweight movements use `max(0, bodyWeightKg - assistanceKg)`.
8. Non-bodyweight movements use normalized external load.
9. Compute `totalVolumeKg = sum(effectiveLoadKg * calculationReps)`.
10. Select internal movement profile coefficients from the saved snapshot or definition.
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

Workout calories are added to `energy_ratio` target intake. They do not directly change g/kg macro targets.

## Dynamic Calorie Calibration

Dynamic calibration updates the non-exercise lifestyle factor from local history.

Inputs:

- food intake coverage
- weight logs
- estimated exercise calories
- selected review window

Purpose:

- Improve the no-exercise baseline for `energy_ratio`.
- Avoid treating logged exercise as part of lifestyle baseline.
- Keep calibration independent from training-frequency self-check.

AI boundary:

- AI may explain calibration confidence.
- AI should not invent a new lifestyle factor.

## Training-Frequency Self-Check

Training-frequency self-check reviews workout history against the shared `training_frequency_per_week` setting.

It can suggest that the user review the setting when the saved workout pattern is inconsistent with the chosen frequency.

Rules:

- It is deterministic local logic.
- It does not directly change profile settings without user confirmation.
- Cooldown is controlled by `last_macro_self_check_at`.
- The shared setting is used by both diet modes, but with different effects.

## Agent Context Builders

Context builders expose deterministic calculation results and bounded summaries to the AI Gateway. After sign-in, user-record context comes from cloud official records, `daily_summaries`, or controlled summary builders rather than local SQLite cache completeness. This document owns the calculations and mode-specific interpretation of those values; [RAGDesign.md](RAGDesign.md) owns context object schemas, permissions, source selection, sanitization, document retrieval, evidence, and context-size boundaries.

The AI Gateway receives only the context necessary for the routed workflow. Missing dimensions remain missing and cannot be reconstructed by model reasoning.

## Workflow Algorithms

### Meal Decision

Algorithmic flow:

1. Identify user intent and selected date.
2. Build profile and selected-day context.
3. Determine whether mode is `energy_ratio` or `gram_per_kg`.
4. Summarize the primary decision signal for that mode: kcal target/intake/remaining in `energy_ratio`, or protein/carbs/fat gram gaps in `gram_per_kg`.
5. Consider workout context and strategy context.
6. Generate practical advice.
7. Avoid official writes.

In `gram_per_kg`, AI meal advice should lead with macro gram gaps and treat kcal remaining as auxiliary monitoring. In `energy_ratio`, AI meal advice should lead with kcal remaining and use macro structure as secondary guidance.

### Weekly Review

Algorithmic flow:

1. Determine review window.
2. Build recent food summary and coverage.
3. Build recent workout summary.
4. Build weight trend summary if data is sufficient.
5. Include strategy context.
6. Explain patterns, blockers, and data gaps.
7. Suggest next actions without changing official settings.

### App Logic Q&A

Algorithmic flow:

1. Detect language.
2. Retrieve same-language documents.
3. Answer in the detected user-message language from docs and current app context.
4. Distinguish current product behavior from explicitly marked future scope.

## Algorithm Boundaries

- Current target, summary, workout calorie, calibration, strategy, and self-check calculations are deterministic Dart code.
- AI can consume calculation outputs.
- AI cannot silently modify official profile, target, strategy, food, workout, or weight records.
- AI food estimation is a draft workflow until user confirmation.
- User-data RAG uses cloud structured summaries, not open-ended raw database access or complete raw history as default context.
- Current Document RAG uses keyword, full-text, trigram, and term-overlap retrieval over app documents; any future vector/semantic retrieval remains a separately evaluated document-only enhancement.
- User business-data vector databases are out of scope for V1.

## Code References

- Macro targets: `lib/domain/services/macro_target_calculator.dart`
- Daily summary: `lib/domain/services/daily_summary_service.dart`
- Workout calories: `lib/domain/services/workout_calorie_calculator.dart`
- Dynamic calibration: `lib/domain/services/daily_summary_service.dart`
- Training self-check: `lib/domain/services/training_frequency_self_check_service.dart`
- Diet strategy: `lib/domain/services/diet_plan_strategy_service.dart`
- Carb cycling: `lib/domain/services/carb_cycling_calculator.dart`
- Carb taper review: `lib/domain/services/carb_taper_review_service.dart`
- Food parser: `lib/domain/services/nutrition_calculator.dart`
- Models: `lib/domain/models/*`
- Tests: `test/macro_target_calculator_test.dart`, `test/workout_calorie_calculator_test.dart`
