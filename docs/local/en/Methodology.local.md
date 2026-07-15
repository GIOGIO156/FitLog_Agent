# Methodology

## Purpose

This document explains why FitLog Local uses its current diet, carb strategy, and exercise calorie methods. It is written for users who want to understand the reasoning behind the app before trusting the numbers.

FitLog is a tracking and estimation tool. It does not provide medical advice, diagnose conditions, prescribe diets, or replace a qualified professional.

Reference markers such as [REF-ALG-01](References.local.md) point to entries in [References](References.local.md), where the full source and evidence boundary are recorded.

## The Core Idea

FitLog separates three things that are often mixed together:

1. Goal phase: whether the user is cutting or bulking.
2. Base calculation method: whether daily targets are kcal-primary or macro-primary.
3. Strategy layer: whether carbs are redistributed or reviewed after the base target is calculated.

This separation matters because different users trust and act on different targets. Some users think in kcal first. Others think in protein/carbs/fat grams first. Mixing both systems into one formula would make the app harder to reason about and easier to misread.

## `energy_ratio`: Kcal-first Planning

`energy_ratio` is for users who want daily kcal target, intake, and remaining kcal to be the primary signal.

It works like this:

```text
BMR estimate
-> default no-exercise baseline from shared training frequency
-> cutting deficit or bulking surplus
-> add logged net exercise calories
-> split the final kcal target into protein/carbs/fat by percentage
```

Why this method exists:

- Many diet plans start with energy balance: eat below maintenance for cutting or above maintenance for bulking [REF-ALG-07](References.local.md).
- Macro percentages are easy to understand when the main target is kcal, and percentage-of-energy framing is a common nutrition planning frame [REF-ALG-04](References.local.md).
- Logged exercise can be added back as extra available intake because the baseline is intentionally a no-exercise daily baseline.

What users should know:

- `diet_goal_phase = cutting` means `daily_energy_goal_kcal` is treated as a deficit.
- `diet_goal_phase = bulking` means `daily_energy_goal_kcal` is treated as a surplus.
- In this mode, kcal target/intake/remaining is the main counter.
- Macro grams are derived from the kcal target and macro percentages.
- BMR and default lifestyle factors are estimates, not exact measurements [REF-ALG-01](References.local.md), [REF-ALG-02](References.local.md).
- The shared training-frequency setting is the user-facing default input for both diet modes, but local calibration can still override the `energy_ratio` default factor after enough history exists.

Main evidence context:

- BMR/RMR estimate: [REF-ALG-01](References.local.md), [REF-ALG-02](References.local.md).
- Macro energy conversion: [REF-ALG-03](References.local.md).
- Percentage-of-energy macro framing: [REF-ALG-04](References.local.md).

See [References](References.local.md) for source details and boundaries.

## `gram_per_kg`: Macro-first Planning

`gram_per_kg` is for users who want protein, carbs, and fat grams to be the primary target.

It works like this:

```text
bodyweight
-> goal phase
-> sex option
-> coarse training-frequency tier
-> protein/carbs/fat g/kg table
-> macro gram targets
```

Why this method exists:

- Many training-oriented users think of protein, carbs, and fat in grams per kg of bodyweight [REF-ALG-05](References.local.md), [REF-ALG-06](References.local.md).
- Protein and carbohydrate needs often scale more naturally with body size and training context than with a single kcal number [REF-ALG-06](References.local.md), [REF-ALG-15](References.local.md).
- A macro-first display can be easier to act on when the user cares about hitting protein/carbs/fat targets directly.

What users should know:

- `gram_per_kg` does not use BMR, activity level, daily deficit/surplus, logged exercise calories, or macro percentages.
- `training_frequency_per_week` is only a coarse lookup tier: 2, 3, 4, or 5 days per week.
- That tier is not a claim about intensity, training age, total volume, or performance demand.
- `prefer_not_to_say` uses the same-tier male/female average.
- In this mode, macro grams are primary.
- Kcal is auxiliary because `protein*4 + carbs*4 + fat*9` is only the energy equivalent of the macro targets. It is not the counter that drives the plan [REF-ALG-03](References.local.md).

Why kcal is auxiliary here:

If FitLog used g/kg macros and then forced those macros back through an independent kcal target, the two systems could fight each other. A user might see macro targets saying one thing and the kcal counter saying another. FitLog avoids that confusion by making macro grams the source of truth in `gram_per_kg`.

Main evidence context:

- Macro energy conversion: [REF-ALG-03](References.local.md).
- Protein g/kg range and sports nutrition context: [REF-ALG-05](References.local.md), [REF-ALG-06](References.local.md).
- Diet and body-composition framing: [REF-ALG-07](References.local.md).

## Why The Two Diet Modes Must Not Be Mixed

The two modes answer different questions.

`energy_ratio` asks:

```text
Given my kcal target, how many grams of protein/carbs/fat should I eat?
```

`gram_per_kg` asks:

```text
Given my bodyweight and training context, what protein/carbs/fat gram targets should I aim for?
```

Both can be useful, but they should not control the same target at the same time. FitLog keeps them separate so the user always knows which number is primary.

## Carb Cycling

`carb_cycling` is a strategy layer for cutting. It redistributes carbs across the week after the base target is calculated.

It works like this:

```text
base carbs
-> choose high / medium / low days
-> normalize the 7-day multipliers
-> raise carbs on some days and lower them on others
-> keep weekly average carbs controlled
```

Why this method exists:

- Some users prefer more carbs on harder training days and fewer carbs on easier or rest days.
- Carb needs can vary with training demands [REF-ALG-15](References.local.md).
- Weekly normalization helps avoid accidentally turning cycling into hidden overeating or excessive restriction.

How to assign high, medium, and low days:

- High-carb days are usually the best fit for the hardest sessions of the week: the longest training day, the most demanding lower-body session, or a day where performance matters most [REF-ALG-15](References.local.md), [REF-ALG-21](References.local.md).
- Medium-carb days fit ordinary training days that still need support, but are not the most demanding session of the week.
- Low-carb days fit rest days, technique days, or clearly lighter activity days.
- This is a practical planning rule, not a claim that one exact pattern is scientifically superior for everyone. FitLog keeps it simple so users can map carb availability to training demand without changing the base diet mode.

What users should know:

- Carb cycling is not a magic fat-loss algorithm; evidence around periodized carbohydrate restriction should not be overstated [REF-ALG-14](References.local.md).
- It does not create better results by itself if weekly intake and adherence are poor.
- It keeps protein and fat stable while adjusting carbs.
- It applies a safety floor: carbs should not drop below `max(weightKg * 1.2, 100)`.
- If the floor is hit, FitLog clamps the target and records a local reason code.
- The current multipliers are a local FitLog setting layer. They move carbs up or down from the base target, then normalize the week so the average does not drift too far.
- A good starting pattern is:
  High on the hardest session days, medium on normal training days, low on rest or easy days.
- If recovery or adherence gets worse, change the day labels before making the multipliers more aggressive.

Main evidence context:

- Periodized carbohydrate availability: [REF-ALG-13](References.local.md).
- Limits of periodized carb restriction evidence: [REF-ALG-14](References.local.md).
- Carbohydrate needs vary with training demands: [REF-ALG-15](References.local.md).
- Practical daily carbohydrate ranges and g/kg framing: [REF-ALG-21](References.local.md).

## Carb Tapering

`carb_tapering` is a local review strategy for cutting. It does not auto-diet for the user.

It works like this:

```text
review recent weight trend
-> check food-log coverage
-> check training stability
-> compare current loss rate with target range
-> suggest keep, decrease carbs, pause taper, or no action
-> wait for user confirmation
```

Why this method exists:

- Cutting often needs small adjustments over time, but static weight-change rules have meaningful limits [REF-ALG-11](References.local.md), [REF-ALG-19](References.local.md).
- Weight can fluctuate from water, food volume, sodium, digestion, and training stress.
- A rolling review is safer than reacting to a single day because it reduces the influence of short-term noise [REF-ALG-19](References.local.md).
- User confirmation prevents the app from silently tightening the plan.

How to set target loss rate and taper step:

- A conservative default target is about `0.5%` bodyweight loss per week, which lines up with common physique-sport guidance for preserving lean mass during a cut [REF-ALG-17](References.local.md).
- Pushing toward `1.0%/week` is more aggressive and should be reserved for cases where logging quality, recovery, and training stability are all good [REF-ALG-17](References.local.md).
- Going slower than `0.5%/week` can be reasonable when the user is already lean, highly sensitive to recovery disruption, or simply prefers a steadier cut. FitLog allows this, but treats it as a user choice rather than a universal best setting.
- Taper step size is a FitLog local product rule, not a literature-derived prescription. The app uses small gram changes because body weight is noisy and because the trend signal should be respected before making another cut [REF-ALG-19](References.local.md), [REF-ALG-20](References.local.md).
- In practice, smaller steps such as `5-10 g/day` are the safer starting point when carbs are already low or logging is inconsistent. Larger steps such as `15-20 g/day` make more sense only when the trend is clearly too slow and the data quality is strong.

How to choose the review period:

- Longer windows such as `14-28 days` are steadier when day-to-day body weight swings are large [REF-ALG-20](References.local.md).
- A `7-day` review is faster, but easier to misread unless weighing and food logging are both very consistent.
- FitLog therefore treats the review window as a stability control, not as a claim that one exact period is clinically correct for everyone.

What users should know:

- FitLog uses a rolling trend, not one weigh-in.
- Food log coverage matters because poor logging makes the trend harder to interpret.
- Training stability matters because a drop in training can make an aggressive carb cut less appropriate.
- Suggested carb changes are small steps, not automatic punishment.
- If the data is weak, the app should say `no_data` instead of pretending to know.
- If loss is too fast, the app can suggest `pause_taper`, matching the app's conservative loss-rate framing [REF-ALG-17](References.local.md).
- If carbs would fall below the safety floor, the app blocks the decrease.
- The taper delta is cumulative. The current carb target is roughly:
  `base carbs + current taper delta`
- Because of that, a `10 g` step is not a one-time opinion about today; it shifts the standing carb target until the user accepts a later review or changes settings.

Main evidence context:

- Protein preservation during training phases: [REF-ALG-16](References.local.md).
- Conservative loss-rate framing: [REF-ALG-17](References.local.md).
- Observed prep macro shifts: [REF-ALG-18](References.local.md).
- Dynamic weight-change limitations: [REF-ALG-19](References.local.md).
- Day-to-day body-mass variability: [REF-ALG-20](References.local.md).

## Why Exercise Calories Are Net Calories

FitLog adds logged exercise calories to `energy_ratio` intake targets. To avoid double counting, those exercise calories must be net additional exercise calories.

The reason is simple:

The daily baseline already includes the calories the body would have burned at rest during that time. If FitLog added total exercise calories without removing resting burn, it would count the same resting calories twice.

For cardio, FitLog uses:

```text
netMet = max(0, MET - 1)
netCardioKcal = netMet * 3.5 * bodyWeightKg / 200 * durationMinutes
```

For built-in and custom cardio, FitLog can store the intensity basis used for that session. The record page asks how long the user could maintain the same pace or rhythm, rather than only asking for a vague easy/moderate/hard label. The options map to local MET values:

- 60+ minutes: low intensity.
- 30-60 minutes: moderate intensity.
- 10-30 minutes: vigorous intensity.
- 3-10 minutes: high intensity.
- Under 3 minutes, needs rests: interval/extreme intensity.

The last option is treated carefully. Interval work often includes rest time, so FitLog asks for active movement minutes and uses that value for the MET calculation instead of assuming the whole elapsed duration was extreme intensity.

Why subtract 1 MET:

- 1 MET roughly represents resting energy cost [REF-ALG-09](References.local.md).
- The no-exercise baseline already includes resting metabolism.
- Subtracting 1 MET estimates only the extra cost of doing the activity instead of resting.

Example:

If an activity is 8 MET, FitLog treats the extra exercise cost as about 7 MET, not 8 MET, because the first 1 MET was already part of baseline daily burn.

Main evidence context:

- MET values and conversion: [REF-ALG-08](References.local.md), [REF-ALG-09](References.local.md).

## Why Strength Training Is Not Just Minutes

Strength training is not modeled as simple calories per minute.

Why:

- A 60-minute strength session may include heavy sets, light sets, warmups, and long rests.
- Two sessions with the same duration can have very different loads, reps, and total volume; training demands vary widely by context [REF-ALG-06](References.local.md).
- Counting every minute linearly would overvalue rest time and undervalue actual work.

FitLog uses training volume and movement type:

```text
effective load
-> reps
-> total volume
-> movement profile coefficients
-> active lifting cost
-> recovery and adaptation components
```

Strength exercises can have different entry conventions. Some dumbbell or dual-cable movements are entered as per-side weight, some single-arm or single-leg movements are entered as per-side reps, bodyweight movements may use added weight, and assisted movements use assistance load. FitLog keeps the user's original entry for display, then saves normalized calculation values for volume and calorie estimation. This avoids treating one dumbbell as total load or one-side reps as the whole set.

Custom strength exercises use the same idea. The user chooses understandable input modes such as total weight, per-side weight, bodyweight plus added load, assistance load, total reps, per-side reps, or single-set duration. The app maps those choices to existing local strength profiles; it does not ask the user to choose internal profile names.

For assisted pull-up or dip variants, the logged weight is assistance load, so FitLog estimates actual movement load from `bodyweight - assistance` before applying the normal strength heuristic.

Duration still matters, but only as a capped recovery-density modifier. It can create a small difference between denser and slower sessions, but it does not linearly add calories.

What users should know:

- Strength calorie estimates are a FitLog local heuristic.
- They are useful for consistency inside FitLog, not lab-grade measurement.
- The app prioritizes avoiding obvious double counting over pretending to know exact exercise burn.

## Why FitLog Uses Boundaries And Confirmation

FitLog intentionally uses local deterministic rules and user confirmation because the data is imperfect.

Important uncertainty sources:

- Meal estimates can be wrong.
- External AI estimates can be wrong.
- Weight changes can reflect water, food volume, sodium, or training stress; static weight-change models are limited [REF-ALG-11](References.local.md), [REF-ALG-19](References.local.md).
- Exercise calorie estimates are approximate [REF-ALG-08](References.local.md), [REF-ALG-09](References.local.md).
- BMR and activity factors are population estimates [REF-ALG-01](References.local.md), [REF-ALG-02](References.local.md).

FitLog's response to uncertainty:

- keep calculation modes separate
- use rolling windows instead of single days
- clamp unsafe or extreme values
- keep carb taper user-confirmed
- show strategy reason/context instead of hiding it
- avoid app-internal AI claims unless real AI is implemented

## Where To Read More

- Engineering formulas and implementation boundaries: [Algorithm](Algorithm.local.md)
- Evidence and source boundaries: [References](References.local.md)
- Product behavior and UX scope: [Product](Product.local.md)
- AI/Agent boundary: [AgentDesign](AgentDesign.local.md)
