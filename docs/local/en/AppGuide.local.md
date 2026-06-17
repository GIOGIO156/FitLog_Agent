# App Guide

## Purpose

This guide explains what each FitLog Local app area does, how it works at a high level, and where to read the design details. It is a user and maintainer map, not a replacement for Product, Methodology, Algorithm, Database, AgentDesign, or References.

## App-wide Rules

- FitLog Local is local-first: business data is stored in SQLite unless the user exports it.
- Home, Food Log, and Workout Log share the selected date.
- The app has no internal LLM/API/Agent loop.
- External AI can help create food estimates before data enters the app, but FitLog stores and calculates locally.
- `diet_goal_phase` controls cutting/bulking semantics.
- `energy_ratio` and `gram_per_kg` stay separate.

Read more:

- Product scope: [Product](Product.md)
- Method reasoning: [Methodology](Methodology.md)
- AI boundary: [AgentDesign](AgentDesign.md)

## Home

Home is the selected-day dashboard.

What users see:

- local-time greeting using the locally saved nickname when present, with long nicknames moved to a dedicated second line when needed
- selected date
- primary calorie overview in `energy_ratio`
- dedicated macro-progress hero in `gram_per_kg`
- compact macro progress for protein/carbs/fat in equal-size cards when the page is in `energy_ratio`
- current `diet_goal_phase`, `diet_calculation_mode`, and `diet_plan_strategy`
- compact selected-day food/workout summaries with navigation to detail pages

How it works:

- `DailySummaryService` reads Profile, Food, Workout, calibration, self-check, and strategy data.
- Food totals come from saved `food_records`.
- Exercise totals come from saved `workout_sessions.estimated_calories`.
- `energy_ratio` uses kcal target/intake/remaining as primary, so Home keeps the calorie ring and kcal summary metrics at the top.
- In `energy_ratio`, the opening viewport is treated as a dedicated two-card box: only the calorie hero and macro cards live inside it, their gap stays controlled, and a short protective tail below the macro card separates the strategy card without creating a large empty band.
- `gram_per_kg` uses macro grams as primary and treats kcal as auxiliary, so Home replaces the calorie-ring hero with a dedicated macro dashboard built around the clipped arc, a lowest-completion macro focus hint, and the remaining grams.
- In `gram_per_kg`, kcal intake and workout burn move into the macro dashboard as compact tappable summaries instead of a separate Today's Records card, so the first viewport stays macro-first without losing navigation.
- In `gram_per_kg`, the clipped arc is intentionally oversized relative to the title so the first viewport reads as one continuous dashboard instead of a stack of smaller sections.
- In `gram_per_kg`, the bottom detail list stays vertical and denser, without a visible divider line, so the arc, focus state, and macro rows still read as one surface.
- In `gram_per_kg`, the first viewport still relies on a large dashboard container rather than measured spacer math: the macro dashboard owns the opening screen and the strategy card is placed after that container.
- Strategy fields show final target context after `none`, `carb_cycling`, or `carb_tapering` is applied.
- When carb cycling or carb tapering is active, the Home strategy card opens a structured explainer sheet with methodology-oriented guidance for non-expert users.
- In `gram_per_kg`, the strategy card stays below the initial macro viewport and only appears after scrolling, keeping the opening screen focused on execution rather than explanation.
- Detailed BMR/TDEE/calibration numbers are intentionally left out of the Home surface and remain available in Profile-oriented views.

Read more:

- Daily behavior: [Product](Product.md#daily-dashboard-behavior)
- Calculation reasoning: [Methodology](Methodology.md)
- Formulas: [Algorithm](Algorithm.md)
- Runtime aggregate fields: [Database](Database.md#runtime-aggregates)

## Food Log

Food Log is the selected-day food record list.

What users can do:

- view saved meals for the selected date
- open and edit a record
- copy a record to a chosen date
- delete a record after confirmation
- start Add Food
- read the estimation notice after scrolling past the selected-day meal list

How it works:

- A meal is stored as one `FoodRecord`.
- Optional item rows are stored as `FoodItem`.
- `source` records whether the meal came from manual entry or external AI paste.
- Copying creates a new local record with new ids/timestamps.
- Deleting a food record cascades to its item rows.

Read more:

- Food workflow: [Product](Product.md#food-workflow)
- Tables: [Database](Database.md#food_records), [Database](Database.md#food_items)
- AI-adjacent boundary: [AgentDesign](AgentDesign.md)

## Add Food

Add Food is the food entry gateway.

Entry options:

- `Paste AI Result`: paste JSON produced outside the app.
- `Manual Entry`: type food data directly.
- `Photo AI Analysis`: visible placeholder only; app-internal image recognition is not implemented.
- Prompt copy: copy a Chinese or English prompt for use with an external model.

How it works:

- Prompt copy is static text, not an AI call.
- Pasted JSON is parsed locally by `NutritionCalculator`.
- The preview page lets users correct parsed values before saving.
- Food Detail, AI preview, and Manual Entry all show user-facing field labels instead of raw snake_case keys, and numeric units stay in the field suffix so JSON keys and storage fields can remain unchanged.
- Manual Entry uses the same compact grid as the Food Detail main section: meal name full width, weight and calories on one row, protein/carbs/fat on one row, and notes full width.
- Manual entry writes a local record without item rows unless later edited.

Read more:

- Product behavior: [Product](Product.md#food-workflow)
- AI boundary: [AgentDesign](AgentDesign.md)
- Parser and summary formulas: [Algorithm](Algorithm.md#food-intake-summary)

## Workout Log

Workout Log is the selected-day workout record list.

The page title leads directly into the shared date strip, without a separate subtitle block above the calendar.

What users can do:

- view saved workout records for the selected date
- open a saved record
- delete a saved record
- start Add/Edit Workout Record
- resume one unsaved workout draft from the two-line floating draft bar above `Add Workout`
- discard that draft from the floating bar after confirmation

How it works:

- A user-facing `Workout Record` can contain multiple exercises.
- Internally, one multi-exercise record is multiple `workout_sessions` sharing the same `plan_id`.
- Each session in the same record also stores the same `record_name`.
- One active unsaved workout draft can also exist outside the saved-record list; it is persisted separately, does not count as a saved workout record, and appears as a title/subtitle draft bar that uses short body-part labels and caps direct body-part display at three names before `+n`.
- Record-level summaries are derived from persisted sessions and sets.
- Exercise thumbnails now prefer dedicated transparent PNG assets for matched movements, while unmatched exercises still fall back to the shared body-part SVG set.

Read more:

- Workout workflow: [Product](Product.md#workout-workflow)
- Workout tables: [Database](Database.md#workout_sessions), [Database](Database.md#workout_sets)

## Add/Edit Workout Record

Add/Edit Workout Record is where users create or revise a named workout record.

What users can do:

- name the workout record
- choose one or more exercises from the current chest, back, legs, glutes, shoulders, arms, core, full-body, cardio, and reusable custom library
- add a temporary custom strength or cardio exercise to the current record
- swipe a saved reusable custom exercise inside the `Custom exercises` filter and confirm deletion from future selection
- keep selected exercises in user-chosen order
- enter per-exercise duration
- choose cardio session intensity from a maintainable-duration basis
- enter strength sets with weight, reps or single-set duration, and completed state
- add notes
- leave the editor and come back later through the Workout Log draft bar
- discard a new draft or discard edits from inside the editor with the red danger action
- save completed strength sets

How it works:

- Exercise selection supports body-part filtering, search, and multi-select order.
- Reusable custom exercises appear under their own `Custom exercises` filter instead of the built-in body-part filters.
- Temporary custom exercises can be saved to the reusable local custom library when the user saves the workout record.
- When the user is inside that dedicated custom filter, reusable custom exercises can be hidden from future selection through inline swipe-to-delete with confirmation.
- The temporary custom-exercise page is no longer a plain vertical dropdown form; it reuses the Add Workout title scale, starts with a compact slider-style strength/cardio mode switch, keeps the name in its own identity card, groups strength metadata into tappable bento tiles, gives long rules a full-width row, uses short tile labels, falls back to one column only on very narrow screens, aligns section headers to the shared workout card-title scale, tightens typography to match the real mobile app surfaces, and uses a fixed bottom add action.
- Cardio exercises use duration and session intensity, and have no set checklist.
- The cardio duration explanation sits above the duration field, and the cardio intensity question sits above the intensity picker, which keeps the dropdown readable on small screens.
- The interval/very-high cardio option asks for active movement time so rest time is not overestimated.
- Strength exercises use set rows and store the input mode used for that session.
- Built-in and custom strength exercises can use total load, per-side load, added bodyweight load, assistance load, total reps, per-side reps, or single-set duration.
- Assisted bodyweight exercises store assistance load in the weight field, and calorie estimation treats actual load as `bodyweight - assistance`.
- Draft persistence happens while editing; saved-record persistence only happens after explicit save and successful validation.
- Back/gesture exit keeps the draft instead of opening a save/discard modal.
- Only completed strength sets are saved; unchecked sets are discarded.
- Editing a saved record replaces the full `plan_id` group transactionally.

Read more:

- Product workflow: [Product](Product.md#workout-workflow)
- Workout calorie reasoning: [Methodology](Methodology.md#why-exercise-calories-are-net-calories), [Methodology](Methodology.md#why-strength-training-is-not-just-minutes)
- Formulas: [Algorithm](Algorithm.md#workout-calories)
- Storage model: [Database](Database.md#workout_sessions)

## Workout Record Detail

Workout Record Detail explains a saved workout after persistence.

What users see:

- record name
- date and start time
- total duration
- total volume
- total sets
- estimated calories
- exercises in the record
- saved strength set detail
- saved strength input labels, such as per-side load, per-side reps, assistance load, or single-set duration
- saved cardio intensity basis and active movement time when present

How it works:

- Summary metrics are derived from saved sessions and saved sets.
- Total volume is based on normalized calculation values saved on strength sets.
- Set count is the number of saved strength sets.
- Saved strength detail is read-only for completion state in the current record flow.
- Detail views preserve what the user entered and the calculation mode used at save time, so later custom-exercise edits do not reinterpret old records.

Read more:

- Product behavior: [Product](Product.md#workout-workflow)
- Data model: [Database](Database.md#workout_sessions), [Database](Database.md#workout_sets)

## Profile

Profile is a summary-first control surface for personal data, diet behavior, language, export, and local data actions.

What users can set:

- nickname for local-only UI display, shown under the visible `User Settings` header as a compact one-line identity row with a trailing pen trigger and inline edit on demand
- a current-plan summary and macro target strip below the top identity row
- body-profile summary grid
- age, height, weight, and sex option inside a display-first 2x2 body-profile grid
- language
- `diet_goal_phase`
- `diet_calculation_mode`
- shared training-frequency setting and self-check settings for both diet modes
- `energy_ratio` daily energy goal and macro percentages
- `gram_per_kg` table context and macro-first preview
- `diet_plan_strategy`
- carb cycling pattern and multipliers
- carb taper review period, target loss rate, step size, and current offset

How it works:

- Profile saves to singleton `user_profile`.
- `nickname` is local-only profile data and is not an account identifier.
- Saving Profile also upserts the current day's weight log.
- The opening viewport is intentionally not a dense edit form; current plan, body profile, plan matrix, and training-frequency setup appear before the lower reference/export cards.
- Inline text and numeric cards default to display mode and use card-local save actions only after edits; unchanged inline editors can collapse when the user taps elsewhere. Direct chips and switches save immediately.
- Body Profile now enters one shared edit state: tapping any of the four tiles opens the whole 2x2 body-profile grid for cross-field editing, and one save action persists age, height, weight, and sex together.
- The English compact profile copy keeps short strategy and self-check labels, including `N/A` for no diet strategy and concise current/suggested training-frequency actions.
- The current-plan hero keeps an information trigger that opens a Home-style bottom sheet rather than a full-screen page; the sheet swaps between a `gram_per_kg` coefficient table and an `energy_ratio` default setup guide based on the selected diet mode.
- In `energy_ratio` mode, the energy-ratio settings card sits directly under the plan matrix and above the shared training-frequency/self-check card so the mode selector and numeric inputs stay adjacent.
- The `g/kg` setup card no longer repeats the self-check summary row or the long explanatory note; the full training-frequency self-check card stays below it as a separate section, and the note moves into the information sheet.
- Under-18 protection blocks adult-style cutting deficit behavior and cutting carb strategies.
- Training-frequency self-check can recommend the shared training-frequency setting from recent valid training days in either diet mode.
- Carb taper review can suggest a local action, but user confirmation is required.

Read more:

- Product behavior: [Product](Product.md#diet-setup-ux)
- User-facing method explanation: [Methodology](Methodology.md)
- Algorithm details: [Algorithm](Algorithm.md)
- Profile table: [Database](Database.md#user_profile)

## Export

Export creates local files for the user's records.

What exports include:

- food records
- food items
- workout records
- workout sets
- daily summary
- user profile
- diet adjustment review history
- strategy, calibration, self-check, and local-only nickname fields where relevant

How it works:

- XLSX and CSV ZIP exports are written to the app documents directory.
- Daily summary export is generated at export time from repositories and `DailySummaryService`.
- Export does not upload data.

Read more:

- Export coverage: [Database](Database.md#export-coverage)
- Product boundary: [Product](Product.md#implemented-boundaries)

## Language

Language preference controls UI copy and prompt copy.

How it works:

- The current language is stored in SharedPreferences as `language_code`.
- Prompt copy follows the current language.
- Language state is app-local.

Read more:

- Storage overview: [Database](Database.md#storage-overview)

## Privacy And Local-first Boundary

FitLog Local does not currently have accounts, backend sync, remote database, or app-internal AI calls.

What stays local:

- profile data
- food records
- workout records
- weight logs
- calibration state
- diet adjustment reviews
- exports
- language preference

Read more:

- Database storage: [Database](Database.md)
- AI boundary: [AgentDesign](AgentDesign.md)
- Evidence and safety boundaries: [References](References.md)
