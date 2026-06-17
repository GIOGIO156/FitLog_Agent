# Methodology

## Purpose

This document explains why FitLog_Agent V1 uses its current diet, exercise, and AI-assistance methods. It is written for users and maintainers who want to understand the reasoning behind the app before trusting the numbers or the AI workflow.

FitLog_Agent is a logging, estimation, and decision-support tool. It does not provide medical diagnosis, treatment, or a replacement for qualified professional advice.

Reference markers such as [REF-ALG-01](References.md) point to entries in [References](References.md), where the source and evidence boundary are recorded.

## Core Idea

FitLog keeps four concerns separate:

1. Goal phase: whether the user is cutting or bulking.
2. Base calculation method: whether daily targets are kcal-primary or macro-primary.
3. Strategy layer: whether carbs are redistributed or reviewed after base targets exist.
4. AI assistance: whether the user asks cloud AI to draft, explain, review, or retrieve context.

This separation matters because users need to know which number or setting is official. AI can help interpret the situation, but official targets and saved records remain controlled by deterministic app logic and user confirmation.

## Why AI Exists In V1

The Local app already handles deterministic logging and calculations. The hard part for many users is not the formula; it is translating messy real life into usable records and decisions.

AI helps with:

- estimating mixed meals from text or images
- asking follow-up questions when food information is incomplete
- turning uncertain meal information into editable drafts
- explaining what a remaining target means today
- summarizing recent patterns
- answering how the app works

AI does not replace:

- official diet targets
- saved food records
- saved workout records
- profile settings
- carb strategy settings
- destructive actions

The reason is simple: AI is useful for interpretation, but official data should remain auditable and user-controlled.

## Why RAG Is Needed

Some user questions cannot be answered well from the prompt alone.

Examples:

- "Why have I not lost weight recently?"
- "What can I eat next today?"
- "Why is kcal not primary in this mode?"
- "What does carb tapering mean in this app?"

For these questions, the model needs context:

- recent intake
- workout pattern
- weight trend
- current profile
- current diet mode
- current strategy
- relevant app documentation

FitLog_Agent uses two scoped retrieval patterns:

- Structured RAG: known functions build compact summaries from user data.
- Document RAG: the app retrieves relevant FitLog documentation snippets.

Document RAG may use keyword, full-text, vector, semantic, or hybrid retrieval. However, vector search over app documents does not mean user food/workout/weight records become a user-data vector database. Long-term semantic memory over business records is out of scope for V1.

## Why AI Asks Questions

Food estimation is often ambiguous. A photo or short description may not reveal:

- meat type
- portion size
- oil/sauce amount
- cooked vs raw weight
- whether the user ate all of it
- whether ingredients were removed or substituted

When the missing detail could materially change the estimate, the AI should ask. This protects user trust better than pretending precision.

## `energy_ratio`: Kcal-First Planning

`energy_ratio` is for users who want kcal target, intake, and remaining kcal to be the primary signal.

It works like this:

```text
BMR estimate
-> default no-exercise baseline or calibrated baseline
-> cutting deficit or bulking surplus
-> add logged net exercise calories
-> split final kcal target into protein/carbs/fat by percentage
```

Why this method exists:

- Many diet plans start from energy balance: eat below maintenance for cutting or above maintenance for bulking [REF-ALG-07](References.md).
- Macro percentages are easy to understand when kcal is the main target [REF-ALG-04](References.md).
- Logged exercise can be added back because the baseline is intentionally a no-exercise baseline.

What users should know:

- `diet_goal_phase = cutting` treats `daily_energy_goal_kcal` as a deficit.
- `diet_goal_phase = bulking` treats `daily_energy_goal_kcal` as a surplus.
- kcal target/intake/remaining is the main counter.
- Macro grams are derived from kcal target and macro percentages.
- BMR and lifestyle factors are estimates, not exact measurements [REF-ALG-01](References.md), [REF-ALG-02](References.md).

## `gram_per_kg`: Macro-First Planning

`gram_per_kg` is for users who want protein, carbs, and fat grams to be the primary targets.

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

- Training-oriented users often think in grams per kilogram of bodyweight [REF-ALG-05](References.md), [REF-ALG-06](References.md).
- Protein and carbohydrate needs often scale with body size and training context [REF-ALG-06](References.md), [REF-ALG-15](References.md).
- Macro-first planning can be easier to act on when the user cares about hitting grams directly.

What users should know:

- It does not use BMR, activity level, daily deficit/surplus, logged exercise calories, or macro percentages.
- `training_frequency_per_week` is a coarse lookup tier, not a precise measure of intensity or training age.
- `prefer_not_to_say` uses the same-tier male/female average.
- Macro grams are primary.
- Kcal is auxiliary because it is only the energy equivalent of the macro targets [REF-ALG-03](References.md).

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

Both can be useful, but only one should be primary at a time. If the app forced both systems to drive the same target, users could see conflicting signals.

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

- Some users prefer more carbs on harder training days and fewer carbs on easier days.
- Carbohydrate needs can vary with training demands [REF-ALG-15](References.md).
- Weekly normalization helps avoid hidden overeating or excessive restriction.

What users should know:

- Carb cycling is not a magic fat-loss method.
- It does not compensate for poor weekly intake control or poor adherence.
- Protein and fat stay stable while carbs move.
- FitLog applies a carb floor: `max(weightKg * 1.2, 100)`.
- AI can explain the current day type, but should not change the plan.

## Carb Tapering

`carb_tapering` is a review strategy for cutting. It does not auto-diet for the user.

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

- Cutting often needs small adjustments over time.
- Static weight-change rules have meaningful limits [REF-ALG-11](References.md), [REF-ALG-19](References.md).
- Body weight can fluctuate from water, food volume, sodium, digestion, and training stress [REF-ALG-20](References.md).
- User confirmation prevents the app or AI from silently tightening the plan.

What users should know:

- FitLog uses rolling trends, not one weigh-in.
- Food-log coverage matters.
- Training stability matters.
- Weak data should produce `no_data`, not fake certainty.
- If loss is too fast, FitLog may suggest `pause_taper`.
- If carbs would fall below the safety floor, the app blocks the decrease.
- AI may discuss taper status in Weekly Review, but official application remains user-confirmed.

## Why Exercise Calories Are Net Calories

FitLog tries to avoid double-counting resting energy.

For cardio, it subtracts 1 MET:

```text
netMet = max(0, MET - 1)
```

This is a local product choice built on MET conventions [REF-ALG-08](References.md), [REF-ALG-09](References.md). It makes logged exercise an add-on to a no-exercise baseline rather than counting resting energy twice.

For strength training, FitLog uses a project heuristic based on normalized volume, movement profile, bodyweight involvement, and bounded recovery modifiers. This is an estimate, not lab measurement.

## Why Cloud Profile Is Used

Agent V1 needs account-bound AI personalization:

- the AI page requires login and subscription
- chat history follows the account
- the AI Gateway needs a stable profile context
- subscription and abuse controls live on the server

Therefore, after login, Cloud Profile is the authoritative profile. The device may cache it for display. Offline profile saving is disabled in V1 so there is no profile merge conflict.

Food, workout, and weight history remain local by default in V1. When AI needs recent context, the app should send compact summaries instead of uploading everything.

## Why User Confirmation Is Required

AI estimates can be useful and still wrong. User confirmation protects:

- data quality
- privacy expectations
- diet safety
- accidental writes
- accidental strategy changes
- user agency

The app should treat AI outputs as one of these:

- answer
- explanation
- draft
- review
- suggestion

Only confirmed drafts or confirmed normal UI actions become official data.

## Limitations

- Nutrition labels and food estimates are approximate.
- BMR, TDEE, MET, and g/kg ranges are estimates.
- Strength calorie calculations are practical heuristics.
- Weight trends are noisy.
- AI output can be wrong or incomplete.
- AI should ask when the missing information matters.
- The app is not medical advice.

## Read More

- Stable product behavior: `Product.md`
- App navigation and page responsibilities: `AppGuide.md`
- Algorithm formulas: `Algorithm.md`
- Storage boundaries: `Database.md`
- AI and Agent boundary: `AgentDesign.md`
- Evidence boundaries: `References.md`
