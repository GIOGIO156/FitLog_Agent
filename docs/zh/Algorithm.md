# 算法设计

## 目标

本文定义 FitLog_Agent V1 的算法边界。

复制来的 Local 实现已经包含饮食目标、饮食摘要、训练热量、动态校准、训练频率 self-check、carb cycling 和 carb taper review 的确定性 Dart 算法。Agent V1 可以把这些输出作为上下文，但 LLM 不能替代它们成为权威算法。

## 权威输入

| 输入 | 含义 | 用途 |
| --- | --- | --- |
| `age` | BMR 估算和未成年人保护。 | BMR、安全规则 |
| `height_cm` | 身高厘米。 | BMR |
| `weight_kg` | 体重公斤。 | BMR、g/kg macros、训练热量 |
| `sex_for_formula` | `male`、`female` 或 `prefer_not_to_say`。 | BMR、g/kg 表 |
| `training_frequency_per_week` | 共享 2/3/4/5 设置。 | g/kg 表、`energy_ratio` fallback、self-check |
| `diet_goal_phase` | `cutting` 或 `bulking`。 | 目标语义 |
| `diet_calculation_mode` | `energy_ratio` 或 `gram_per_kg`。 | 基础目标选择 |
| `daily_energy_goal_kcal` | 根据阶段解释为 deficit 或 surplus。 | `energy_ratio` |
| `protein_ratio_percent`, `carbs_ratio_percent`, `fat_ratio_percent` | 宏量能量百分比。 | `energy_ratio` |
| `diet_plan_strategy` | `none`、`carb_cycling` 或 `carb_tapering`。 | 策略层 |
| Food records | 每日摄入。 | Daily summary、AI context summaries |
| Workout sessions/sets | 已保存训练热量和容量输入。 | 训练热量、daily summary、AI context summaries |
| Weight logs | 体重历史。 | 校准、taper review、weekly review context |
| Cloud Profile | Agent V1 中账号绑定的 profile。 | AI 个性化和上下文 |

Agent V1 规则：AI 应接收由这些输入构建的紧凑摘要。它不能直接发明正式目标，也不能覆盖确定性计算。

## 饮食架构

饮食计算分两层：

1. 基础目标层：`diet_goal_phase x diet_calculation_mode`。
2. 策略层：在基础目标存在后应用 `diet_plan_strategy`。

硬边界：

- `diet_goal_phase` 是 cutting/bulking 的来源。
- `diet_calculation_mode` 决定 App 是 kcal-first 还是 macro-first。
- `diet_plan_strategy` 在基础目标后修改上下文，但不合并两种模式。
- AI 可以解释这些层，但不能静默修改。

## BMR 与非运动基线

FitLog 使用 Mifflin-St Jeor 风格 BMR 估算：

```text
male = 10 * weightKg + 6.25 * heightCm - 5 * age + 5
female = 10 * weightKg + 6.25 * heightCm - 5 * age - 161
prefer_not_to_say = average(male, female)
```

非运动基线：

```text
baselineNoExerciseTdee = bmr * lifestyleFactorUsed
```

`lifestyleFactorUsed` 优先使用有效的动态校准结果。否则回退到共享训练频率默认值：

| `training_frequency_per_week` | 默认 non-exercise factor | 兼容 `activity_level` |
| --- | ---: | --- |
| 2 | 1.20 | `sedentary` |
| 3 | 1.30 | `lightly_active` |
| 4 | 1.425 | `moderately_active` |
| 5 | 1.60 | `very_active` |

## `energy_ratio`

`energy_ratio` 是 kcal-first 模式。

```text
if diet_goal_phase == cutting:
  noExerciseTarget = baselineNoExerciseTdee - dailyEnergyGoalKcal

if diet_goal_phase == bulking:
  noExerciseTarget = baselineNoExerciseTdee + dailyEnergyGoalKcal

targetIntake = noExerciseTarget + loggedNetExerciseKcal
remainingCalories = targetIntake - caloriesInToday
```

宏量目标由 target kcal 和标准化百分比转换：

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

如果计算时 ratio 无效，calculator 回退到 30/40/30。Profile 保存校验应要求可见 ratio 字段合计 100。

AI 边界：

- 用餐建议可以使用 remaining kcal/macros。
- AI 不得静默编辑 ratio 字段或 daily energy goal。

## `gram_per_kg`

`gram_per_kg` 是 macro-first 模式。

```text
targetProteinG = weightKg * proteinCoeff
targetCarbsG = weightKg * carbsCoeff
targetFatG = weightKg * fatCoeff
macroEnergyEquivalentKcal = protein*4 + carbs*4 + fat*9
targetIntake = 0
remainingCalories = 0
```

边界：

- 使用体重、性别选项、目标阶段和 `training_frequency_per_week`。
- 不使用 BMR、`activity_level`、`daily_energy_goal_kcal`、logged exercise calories 或 macro ratio percentages。
- `macroEnergyEquivalentKcal` 是辅助信息，不是 kcal target counter。
- `prefer_not_to_say` 使用同频率 male/female 平均值。

Cutting table，protein/carbs/fat g/kg：

| Sex | 2 days | 3 days | 4 days | 5 days |
| --- | --- | --- | --- | --- |
| male | 1.4 / 1.5 / 0.8 | 1.6 / 1.8 / 0.8 | 1.7 / 2.0 / 0.9 | 1.8 / 2.2 / 1.0 |
| female | 1.4 / 1.4 / 1.0 | 1.6 / 1.6 / 1.0 | 1.7 / 1.7 / 1.1 | 1.8 / 1.9 / 1.2 |

Bulking table，protein/carbs/fat g/kg：

| Sex | 2 days | 3 days | 4 days | 5 days |
| --- | --- | --- | --- | --- |
| male | 1.6 / 3.0 / 0.8 | 1.7 / 3.4 / 0.9 | 1.8 / 3.8 / 0.9 | 2.0 / 4.2 / 1.0 |
| female | 1.6 / 2.8 / 0.9 | 1.7 / 3.1 / 1.0 | 1.8 / 3.4 / 1.0 | 2.0 / 3.8 / 1.1 |

AI 边界：

- 这个模式下，用餐建议应把宏量克数作为主目标。
- AI 不应把 remaining kcal 说成主目标。

## 策略层

适用策略：

- `none`：最终目标等于基础目标。
- `carb_cycling`：cutting-only、adult-only 的每周碳水重分配。
- `carb_tapering`：cutting-only、adult-only 的复盘建议流程。

未成年人不能启用 cutting carb strategies。

### `carb_cycling`

该策略在 high/medium/low day 之间重分配碳水，同时保持标准化周平均不变。

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

安全下限：

```text
minCarbsG = max(weightKg * 1.2, 100)
```

如果 final carbs 低于下限，FitLog 会 clamp carbs 并标记 floor condition。

AI 边界：

- AI 可以解释当天 day type 和 macro context。
- AI 不得静默修改每周 pattern 或 multipliers。

### `carb_tapering`

该策略复盘滚动体重趋势、饮食记录覆盖率和训练稳定性。它永远不自动应用。

复盘窗口：7/14/21/28 天，默认 14 天。

趋势公式：

```text
startAvgWeight = first 7-day average in window
endAvgWeight = last 7-day average in window
weightChangeKg = endAvgWeight - startAvgWeight
lossRatePctPerWeek = (-weightChangeKg / startAvgWeight) * 100 * 7 / windowDays
```

数据下限：

- 窗口内至少 7 条体重记录
- food log coverage 至少 0.70
- early 和 late window segments 都需要体重数据

决策行为：

- 慢于 target minus tolerance：`decrease_carbs`
- 在 target band 内：`keep`
- 快于 target plus tolerance：`pause_taper`
- 数据不足：`no_data`
- 训练明显下降：倾向 `keep`
- 预计 carbs 低于安全下限：`blocked_by_safety_floor`

用户确认后的应用公式：

```text
taperedCarbsG = max(baseCarbsG + carb_taper_current_delta_g, minCarbsG)
```

`carb_taper_current_delta_g` 是相对 base carbs 的累计偏移。

AI 边界：

- Weekly Review 可以讨论 taper 状态。
- AI 不得应用 taper change。
- 正式应用仍是用户确认的本地 review flow。

## 饮食摄入摘要

每日摄入从选中日期的已保存饮食记录计算：

```text
caloriesIn = sum(food_records.calories_kcal)
proteinG = sum(food_records.protein_g)
carbsG = sum(food_records.carbs_g)
fatG = sum(food_records.fat_g)
```

`DailySummary` 是运行时聚合，不是存储表。

Agent V1 context builders 应暴露选中日期或近期窗口摘要，而不是默认上传原始饮食历史。

## Food Draft 估算

Agent V1 饮食估算是 AI workflow，但正式持久化仍遵循确定性校验和用户确认。

Food Draft 输出应通过 schema validation，并包含：

- 餐名
- item list
- estimated weights
- kcal/protein/carbs/fat
- confidence 或 uncertainty notes
- 必要时的缺失信息问题
- source metadata

规则：

- 食物类型、肉类类型、分量、实际食用比例或烹饪方式不清楚时，先追问。
- AI 营养结果是估算，不是精确事实。
- 允许用户在 Chat 内轻量编辑草稿。
- 用户确认后才保存。
- 正式保存写入普通 `food_records` 和 `food_items`。

## 训练热量

训练热量在创建或编辑训练记录时计算，然后保存在 `workout_sessions.estimated_calories`。

### 有氧

有氧使用 net MET，避免重复计算静息基线：

```text
netMet = max(0, MET - 1)
netCardioKcal = netMet * 3.5 * bodyWeightKg / 200 * durationMinutes
```

旧版固定 MET fallback：

| Exercise | MET |
| --- | ---: |
| Walking | 4.3 |
| Running | 8 |
| Cycling | 6 |
| Rowing Machine | 7 |
| Stair Climber | 8 |

已保存有氧 session 也可以保存：

- `cardio_intensity_basis`
- `cardio_met`
- `cardio_active_minutes`

对于 under-3-minute interval 风格有氧，应使用 active movement minutes，而不是包含休息的总 elapsed duration。

### 力量

力量使用基于训练容量的净热量估算：

1. 优先使用有有效 calculation reps 的已完成 sets；如果没有，则使用所有有效输入 sets。
2. 保留用户原始输入，同时计算标准化字段。
3. Per-side load 转为 `calculation_load_kg = input_weight_kg * 2`。
4. Per-side reps 转为 `calculation_reps = input_reps * 2`。
5. Duration-based strength sets 保存 `input_duration_seconds`，并使用有边界的 time-under-tension 等价值。
6. Bodyweight movements 使用 `bodyWeightKg * bodyweightShare + externalLoadKg`。
7. Assisted bodyweight movements 使用 `max(0, bodyWeightKg - assistanceKg)`。
8. 非自重动作使用标准化外部负重。
9. 计算 `totalVolumeKg = sum(effectiveLoadKg * calculationReps)`。
10. 从保存时 snapshot 或动作定义选择内部 movement profile coefficients。
11. Duration 只用于有上限的 recovery-density modifier，不作为线性热量累加。

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

训练热量会加入 `energy_ratio` 的 target intake。它不直接改变 g/kg macro targets。

## 动态热量校准

动态校准根据本地历史更新 non-exercise lifestyle factor。

输入：

- food intake coverage
- weight logs
- estimated exercise calories
- selected review window

用途：

- 改善 `energy_ratio` 的 no-exercise baseline。
- 避免把 logged exercise 当成 lifestyle baseline。
- 与 training-frequency self-check 保持独立。

AI 边界：

- AI 可以解释 calibration confidence。
- AI 不应发明新的 lifestyle factor。

## Training-Frequency Self-Check

Training-frequency self-check 根据训练历史检查共享 `training_frequency_per_week` 设置是否一致。

当已保存训练模式与选择的训练频率不一致时，它可以提示用户检查设置。

规则：

- 它是确定性本地逻辑。
- 它不会在没有用户确认的情况下直接修改 profile settings。
- 冷却由 `last_macro_self_check_at` 控制。
- 共享设置被两个饮食模式使用，但作用不同。

## Agent Context Builders

Agent V1 使用 context builders，把紧凑摘要发送给 AI Gateway。

推荐 builder 输出：

| Context | Contents |
| --- | --- |
| `profile_context` | Cloud Profile、饮食阶段、模式、策略、训练频率、self-check 设置。 |
| `selected_day_summary` | 摄入、训练消耗、目标上下文、剩余值或宏量缺口。 |
| `recent_food_summary` | 窗口平均值、覆盖率、宏量稳定性、缺失日期。 |
| `recent_workout_summary` | 频率、估算热量、训练部位模式、稳定性。 |
| `weight_trend_summary` | 数据足够时的趋势、缺失数据状态、简单速率计算。 |
| `strategy_context` | 相关时的 carb cycling day type 或 taper review state。 |
| `document_context` | 用户语言对应的 App 文档检索片段。 |

AI Gateway 只应接收当前 workflow 需要的上下文。

## Workflow 算法

### 用餐决策

算法流程：

1. 识别用户 intent 和选中日期。
2. 构建 profile 和 selected-day context。
3. 判断当前模式是 `energy_ratio` 还是 `gram_per_kg`。
4. 总结 remaining kcal/macros 或 macro gaps。
5. 考虑训练上下文和策略上下文。
6. 生成实用建议。
7. 不做正式写入。

### Weekly Review

算法流程：

1. 确定 review window。
2. 构建 recent food summary 和 coverage。
3. 构建 recent workout summary。
4. 数据足够时构建 weight trend summary。
5. 加入 strategy context。
6. 解释模式、阻碍和数据缺口。
7. 提出下一步行动，但不修改正式设置。

### App 规则问答

算法流程：

1. 检测语言。
2. 检索同语言文档。
3. 根据文档和当前 App 上下文回答。
4. 区分已实现行为和计划中的 Agent V1 行为。

## 算法边界

- 当前目标、摘要、训练热量、校准、策略和 self-check 计算都是确定性 Dart 代码。
- AI 可以消费计算输出。
- AI 不能静默修改正式 profile、target、strategy、food、workout 或 weight records。
- AI 饮食估算在用户确认前只是草稿 workflow。
- 用户数据 RAG 应使用结构化摘要，不做开放式原始数据库访问。
- Document RAG 可以对 App 文档使用关键词、全文、向量或混合检索。
- 用户业务数据向量库不在 V1 范围内。

## 代码引用

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
