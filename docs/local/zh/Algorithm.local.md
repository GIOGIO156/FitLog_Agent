# 算法设计

## 来源输入

| 输入 | 含义 | 使用位置 |
| --- | --- | --- |
| `age` | BMR 估算和未成年人保护。 | BMR、安全规则 |
| `height_cm` | 身高，单位厘米。 | BMR |
| `weight_kg` | 体重，单位千克。 | BMR、g/kg 宏量、运动消耗 |
| `sex_for_formula` | `male`、`female` 或 `prefer_not_to_say`。 | BMR、g/kg 表 |
| `activity_level` | 保存时由共享训练频率派生出的兼容活动档位。 | `energy_ratio` 兼容/导出元数据 |
| `diet_goal_phase` | `cutting` 或 `bulking`；阶段来源。 | 目标语义 |
| `diet_calculation_mode` | `energy_ratio` 或 `gram_per_kg`。 | 基础目标选择 |
| `daily_energy_goal_kcal` | 根据阶段表示每日赤字或盈余。 | `energy_ratio` |
| `protein_ratio_percent`, `carbs_ratio_percent`, `fat_ratio_percent` | 宏量热量百分比。 | `energy_ratio` |
| `training_frequency_per_week` | 共享的 2/3/4/5 训练频率设置。 | g/kg 查表、`energy_ratio` 默认基线回退、自检 |
| `diet_plan_strategy` | `none`、`carb_cycling` 或 `carb_tapering`。 | 策略层 |
| 饮食记录 | 每日 kcal/蛋白质/碳水/脂肪摄入。 | 每日汇总 |
| 训练 session/set | 已保存运动消耗和力量训练量输入。 | 运动消耗、每日汇总 |
| 体重日志 | 每日体重历史。 | 动态热量校准和 taper review |

`training_frequency_per_week` 现在是面向用户的共享设置。在 `gram_per_kg` 中，它仍然只是粗略查表档位；在 `energy_ratio` 中，只有在本地校准尚未学到更合适结果时，它才用于选择默认非运动系数。无论在哪个模式里，它都不代表训练强度、训练年限、训练容量或运动表现需求。

## 饮食架构

饮食计算分两步：

1. 基础目标层：应用 `diet_goal_phase x diet_calculation_mode`。
2. 策略层：在基础目标已存在后应用 `diet_plan_strategy`。

基础层是阶段和模式的来源。策略层可以调整最终展示的宏量/目标上下文，但不得合并两个基础计算模式。

## BMR 与基线

FitLog 使用 Mifflin-St Jeor 风格的 BMR 估算：

```text
male = 10 * weightKg + 6.25 * heightCm - 5 * age + 5
female = 10 * weightKg + 6.25 * heightCm - 5 * age - 161
prefer_not_to_say = average(male, female)
```

非运动基线：

```text
baselineNoExerciseTdee = bmr * lifestyleFactorUsed
```

`lifestyleFactorUsed` 优先使用有效动态校准结果；否则使用共享训练频率对应的默认值：

| `training_frequency_per_week` | 默认非运动系数 | 兼容 `activity_level` |
| --- | ---: |
| 2 | 1.20 | `sedentary` |
| 3 | 1.30 | `lightly_active` |
| 4 | 1.425 | `moderately_active` |
| 5 | 1.60 | `very_active` |

## `energy_ratio`

`energy_ratio` 是 kcal 主导模式。

```text
if diet_goal_phase == cutting:
  noExerciseTarget = baselineNoExerciseTdee - dailyEnergyGoalKcal

if diet_goal_phase == bulking:
  noExerciseTarget = baselineNoExerciseTdee + dailyEnergyGoalKcal

targetIntake = noExerciseTarget + loggedNetExerciseKcal
remainingCalories = targetIntake - caloriesInToday
```

宏量目标由目标 kcal 按归一化百分比换算：

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

如果计算时比例无效，calculator fallback 为 30/40/30。Profile 保存时要求可见比例字段合计为 100。

## `gram_per_kg`

`gram_per_kg` 是宏量主导模式。

```text
targetProteinG = weightKg * proteinCoeff
targetCarbsG = weightKg * carbsCoeff
targetFatG = weightKg * fatCoeff
macroEnergyEquivalentKcal = protein*4 + carbs*4 + fat*9
targetIntake = 0
remainingCalories = 0
```

边界：

- 只使用体重、性别选项、目标阶段和 `training_frequency_per_week`。
- 不使用 BMR、`activity_level`、`daily_energy_goal_kcal`、已记录运动热量或宏量百分比。
- `macroEnergyEquivalentKcal` 是辅助分析/导出数据，不是 kcal 目标计数器。
- `prefer_not_to_say` 使用同频率档位的男女平均值。

减脂表，蛋白质/碳水/脂肪 g/kg：

| 性别 | 2 天 | 3 天 | 4 天 | 5 天 |
| --- | --- | --- | --- | --- |
| male | 1.4 / 1.5 / 0.8 | 1.6 / 1.8 / 0.8 | 1.7 / 2.0 / 0.9 | 1.8 / 2.2 / 1.0 |
| female | 1.4 / 1.4 / 1.0 | 1.6 / 1.6 / 1.0 | 1.7 / 1.7 / 1.1 | 1.8 / 1.9 / 1.2 |

增肌表，蛋白质/碳水/脂肪 g/kg：

| 性别 | 2 天 | 3 天 | 4 天 | 5 天 |
| --- | --- | --- | --- | --- |
| male | 1.6 / 3.0 / 0.8 | 1.7 / 3.4 / 0.9 | 1.8 / 3.8 / 0.9 | 2.0 / 4.2 / 1.0 |
| female | 1.6 / 2.8 / 0.9 | 1.7 / 3.1 / 1.0 | 1.8 / 3.4 / 1.0 | 2.0 / 3.8 / 1.1 |

## 饮食策略层

可用策略：

- `none`：最终目标等于基础目标。
- `carb_cycling`：仅减脂、仅成人，每周碳水重新分配。
- `carb_tapering`：仅减脂、仅成人，提供 review 建议流程。

未成年人不能启用减脂碳水策略。

### `carb_cycling`

该策略在 high/medium/low 日之间重新分配碳水，同时保持归一化后的每周平均值。

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

如果最终碳水低于下限，FitLog 会 clamp 碳水并添加 `carb_floor_applied`。

### `carb_tapering`

该策略复盘滚动体重趋势、饮食记录覆盖和训练稳定性。它永远不会自动应用。

Review 窗口：默认 14 天，也支持 21/28/7 天。

趋势公式：

```text
startAvgWeight = first 7-day average in window
endAvgWeight = last 7-day average in window
weightChangeKg = endAvgWeight - startAvgWeight
lossRatePctPerWeek = (-weightChangeKg / startAvgWeight) * 100 * 7 / windowDays
```

数据下限：

- 窗口内至少 7 条体重日志
- 饮食记录覆盖率至少 0.70
- 早期和后期窗口段都需要体重数据

决策行为：

- 慢于目标减去容忍值：`decrease_carbs`
- 在目标区间内：`keep`
- 快于目标加上容忍值：`pause_taper`
- 数据不足：`no_data`
- 训练明显下降：优先 `keep`
- 预计碳水低于安全下限：`blocked_by_safety_floor`

用户确认后的应用公式：

```text
taperedCarbsG = max(baseCarbsG + carb_taper_current_delta_g, minCarbsG)
```

`carb_taper_current_delta_g` 是相对基础碳水的累计偏移。

## 饮食摄入汇总

每日摄入从选中日期的已保存饮食记录计算：

```text
caloriesIn = sum(food_records.calories_kcal)
proteinG = sum(food_records.protein_g)
carbsG = sum(food_records.carbs_g)
fatG = sum(food_records.fat_g)
```

`DailySummary` 是运行时聚合数据，不作为数据库表长期存储。

## 运动消耗

运动消耗在创建或编辑训练记录时计算，并保存到 `workout_sessions.estimated_calories`。

有氧使用净 MET，避免重复计算静息基线：

```text
netMet = max(0, MET - 1)
netCardioKcal = netMet * 3.5 * bodyWeightKg / 200 * durationMinutes
```

当计算器只收到动作名时，以下旧固定 MET 表仍作为兼容 fallback：

| 动作 | MET |
| --- | ---: |
| Walking | 4.3 |
| Running | 8 |
| Cycling | 6 |
| Rowing Machine | 7 |
| Stair Climber | 8 |

保存后的内置和自定义有氧 session 也可以携带 `cardio_intensity_basis`、`cardio_met` 和可选 `cardio_active_minutes`。用户侧强度依据询问同一速度/节奏大概能连续维持多久：60 分钟以上、30-60 分钟、10-30 分钟、3-10 分钟，或小于 3 分钟且需要休息。选择小于 3 分钟的间歇选项时，FitLog 使用实际运动分钟数，而不是整段训练经过时间。

力量使用训练量驱动的净消耗：

1. 优先使用已完成且有有效计算次数的组；如果没有，则使用所有有效输入组。
2. 保存用户原始输入字段，并为热量启发式计算标准化字段。
3. 每侧重量会转换为 `calculation_load_kg = input_weight_kg * 2`。
4. 每侧次数会转换为 `calculation_reps = input_reps * 2`。
5. 平板支撑等按时长记录的力量组保存 `input_duration_seconds`，并用有上限的 time-under-tension 等价值生成 `calculation_reps`。
6. 自重动作使用 `bodyWeightKg * bodyweightShare + externalLoadKg` 作为有效负荷。
7. 辅助类自重动作把输入重量视为辅助重量，并用 `max(0, bodyWeightKg - assistanceKg)` 作为有效负荷。
8. 非自重动作使用标准化后的外部负荷。
9. 计算 `totalVolumeKg = sum(effectiveLoadKg * calculationReps)`。
10. 从已保存 session 快照或当前动作定义中选择内部动作 profile 系数。
11. 时长只进入有上限的恢复密度修正，不线性累加热量。

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

动作 profile 系数：

| Profile | strengthCoefficient | postTrainingRecoveryRate | muscleRepairAdaptationRate |
| --- | ---: | ---: | ---: |
| `upper_body_compound` | 0.013 | 0.28 | 0.12 |
| `lower_body_compound` | 0.019 | 0.34 | 0.16 |
| `isolation` | 0.0085 | 0.12 | 0.06 |
| `full_body_power_or_high_density` | 0.024 | 0.45 | 0.20 |

附加修正：

```text
bodyFactor = clamp(sqrt(bodyWeightKg / 80), 0.85, 1.15)
recoveryDensityModifier = clamp(1 + (densityRatio - 1) * 0.28, 0.85, 1.35)
```

运动消耗会加入 `energy_ratio` 的目标摄入，不会直接改变 g/kg 宏量目标。

## 动态热量校准

动态校准使用本地历史更新非运动生活方式系数。

规则：

- 候选窗口：28 / 21 / 14 / 7 天
- 每 7 天最多校准一次
- 使用起点/终点 7 日滚动平均体重
- 要求足够的饮食日志和体重日志
- 使用 7700 kcal/kg 作为粗略历史近似
- 使用 EWMA 平滑更新
- 限制单次更新幅度并 clamp 全局系数

```text
observedTotalTdee = avgDailyIntake - weightChangeKg * 7700 / windowDays
observedNoExerciseTdee = observedTotalTdee - avgDailyExercise
observedLifestyleFactor = observedNoExerciseTdee / avgBmr
newFactor = oldFactor * 0.8 + observedLifestyleFactor * 0.2
```

边界：

- 单次更新上限：+/-0.03
- 全局系数范围：1.10 到 1.70
- 最低置信度：0.35

校准与训练频率自检相互独立。

## 共享训练频率自检

自检同时适用于 `energy_ratio` 和 `gram_per_kg`。

有效训练日规则：按不同日期计数，不按 session 数计数。满足任一条件即为有效日：

1. 至少一个力量 session
2. 有氧总时长至少 20 分钟
3. 当日总估算运动消耗至少 80 kcal

推荐值：

```text
averageWeekly = activeTrainingDays / periodDays * 7
recommended = clamp(round(averageWeekly), 2, 5)
```

周期：7 / 14 / 21 / 28 天。

冷却：通过 `last_macro_self_check_at` 控制，展示/应用反馈不应频繁于每 7 天一次。

用户确认建议时，自检只会更新共享的 `training_frequency_per_week` 设置。它不会直接更新已校准的 `lifestyle_factor_non_exercise`，不使用体重变化公式，也不使用 observed TDEE EWMA。

## 算法边界

- 当前目标、汇总、运动消耗、校准、策略和自检计算均由本地确定性 Dart 代码完成。
- 外部 AI Prompt 复制和 JSON 粘贴不构成 App 内 AI 推理。
- 当前没有算法使用 RAG、向量搜索、语义记忆、tool calling 或 Agent loop。
- FitLog 估算仅用于个人记录，不是医疗建议。

## 代码引用

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
