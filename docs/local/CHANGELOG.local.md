# Changelog

## 2026-06-14 Profile And Food Form Editing Follow-up

### Changed

- Reworked Body Profile editing so tapping any age/height/weight/sex tile opens one shared edit state for all four fields, allowing users to move across the 2 x 2 grid and save once instead of saving one field at a time.
- Tightened agreed English UI copy on Profile, Home, and Add Workout, including the shorter training self-check title and period pills, shorter diet-mode and diet-strategy labels, compact current-plan training summary, shortened greetings, `Remaining`, `Exercise kcal`, `Calories Intake`, and the `Add` / `Custom` workout entry buttons.
- Followed up the English Profile copy with `Current: x times/week`, `Suggested: x times/week`, shorter `Apply` / `Keep Current` action buttons, and `N/A` for the no-strategy diet pill.
- Rebuilt Manual Entry to match the saved Food Detail main-section layout: meal name full width, weight and calories on one row, protein/carbs/fat on one row, and no confidence field.
- Switched Food Detail, AI preview, and Manual Entry field labels from raw storage keys to user-facing localized labels, while keeping the underlying JSON/database/export keys unchanged and moving units such as `g` and `kcal` into input suffixes.
- Updated bilingual Product and AppGuide docs so the body-profile shared edit state and the food-form presentation rules are recorded in the stable design docs.

### Validation

- `dart format` on modified Dart files: success.
- `flutter analyze`: success.
- `flutter test`: success.
- `flutter build apk --debug`: success; generated `build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter build apk --debug --split-per-abi --build-number 23`: success; generated `app-armeabi-v7a-debug.apk`, `app-arm64-v8a-debug.apk`, and `app-x86_64-debug.apk`.
- `flutter build apk --debug --split-per-abi --build-number 24`: success; regenerated `app-armeabi-v7a-debug.apk`, `app-arm64-v8a-debug.apk`, and `app-x86_64-debug.apk` with the latest compact Profile copy follow-up.

## 2026-06-13 Source Baseline Cleanup

### Changed

- Reduced repository write-path duplication by centralizing repeated child-row insertion helpers inside `FoodRepository` and `WorkoutRepository`, preserving existing timestamp, transaction, and persistence behavior.
- Added `NumberUtils.toNullableInt` for nullable database id parsing and replaced repeated sentinel-based id parsing in domain models with the shared helper.
- Removed the Profile page file-level `unnecessary_brace_in_string_interps` ignore by simplifying the only unnecessary interpolations while preserving visible text.

### Added

- Added focused `NumberUtils.toNullableInt` unit coverage for null, invalid, sentinel, and valid integer-like values.

### Fixed

- Rebuilt the ABI-specific debug APKs with `--build-number 22` so devices that previously installed a higher debug build, such as build 21, do not reject the current package as a version downgrade.

### Validation

- `dart format lib test`: success.
- `flutter analyze`: success.
- `flutter test`: success.
- `flutter build apk --debug`: success.
- `flutter build apk --debug --split-per-abi --build-number 22`: success; generated ABI-specific debug APKs including `app-arm64-v8a-debug.apk`.

## 2026-06-13 Documentation Baseline Rule Update

### Changed

- Reordered `README.md` so the Chinese section appears before the English section, matching the project's primary Chinese-user audience while preserving bilingual content parity.
- Updated `AGENTS.md` documentation rules so future documentation work keeps `README.md` Chinese-first and allows `CHANGELOG.md` to preserve complex bug/debugging lessons when they help future diagnosis.
- Aligned the `AGENTS.md` heading with the current file name instead of the older `CLAUDE.md` label.
- Corrected the Chinese README custom-exercise description so it matches the current inline swipe-to-delete behavior instead of the removed separate management-entry wording.
- Synchronized detailed design docs after review: fixed the English AppGuide's `AgentDesign` naming, aligned Add/Edit Workout custom-exercise deletion wording, added the missing Chinese Product cardio-helper behavior, and completed Chinese Database export/code-reference coverage.

### Validation

- Documentation-only change; Flutter analysis and tests were not required.
- Verified the required design-document tree still exists under `docs/en/` and `docs/zh/`.
- Searched current rules and stable docs for stale README language-order rules, stale custom-exercise management wording, date-appended headings, stale root-level design-doc paths, and obvious replacement characters.

## 2026-06-13 Home First-Screen Strategy Placement

### Fixed

- Reworked the Home first-screen layout so the greeting, date, and active dashboard occupy the full available viewport before the strategy card is placed below it, preventing tall Pro Max-class screens from revealing the strategy row before scrolling.
- Updated Home widget coverage so both ordinary and tall viewport sizes assert that the strategy card is absent from the initial first screen and appears only after scrolling.

### Validation

- `flutter analyze`: success.
- `flutter test`: success.
- `flutter build apk --debug --split-per-abi --build-number 21`: success.

## 2026-06-13 Exercise Naming And Profile Guide Follow-up

### Changed

- Renamed Chinese built-in exercise labels so dumbbell and barbell names start with the equipment term, including `Incline Dumbbell Press` -> `哑铃上斜卧推`, `Underhand Barbell Row` -> `杠铃反手划船`, `Seal Barbell Row` -> `杠铃海豹划船`, and `Standing Barbell Front Raise` -> `杠铃站姿前平举`.
- Renamed `Barbell Upright Row` to `杠铃提拉` in Chinese.
- Removed `Barbell Row` from the active built-in exercise catalog because `Bent-over Barbell Row` already covers the intended barbell-row option, while leaving historical record display compatibility intact.
- Tightened the temporary custom-exercise card gaps to match the surrounding workout surfaces more closely.
- Removed example hint text from the custom-exercise name field so strength and cardio creation do not show a large example prompt inside the focused input.

### Fixed

- **Important Profile guide lesson:** device testing confirmed the current-plan information tap reached the Profile page, but the modal/bottom-sheet presentation path could still fail to appear on the real device. The shipped fix keeps the guide presentation inside the Profile widget tree with a page-local `Stack` overlay instead of relying on an external route overlay, which is the safer pattern for similarly dense Profile-only guide surfaces.

### Validation

- `flutter analyze`: success.
- `flutter test`: success.
- `flutter build apk --debug --split-per-abi --build-number 20`: success.

## 2026-06-13 Profile Tap Handling Fix

### Changed

- Removed the page-level Profile `GestureDetector` that had been used to collapse clean inline editors.
- Replaced the current-plan information trigger with a smaller green circular raw-pointer control that opens a Profile-local in-page overlay, bypassing the modal route path after device testing showed the button callback reached the page but `showModalBottomSheet` still failed to appear.
- Changed nickname editing to a value-tap flow with an inline same-row save button, removing the trailing pen shortcut and avoiding implicit outside-tap saving for text input.
- Kept body-profile editing on explicit card-local save, preserving direct-save chip behavior for plan-matrix and training-frequency controls that do not have freeform text drafts.
- Tuned the current-plan strategy badge to a middle size between the previous small badge and the oversized follow-up attempt, without changing the surrounding plan-card layout.
- Removed the remaining field-level outside-tap handlers from nickname and body-profile editors so text and numeric drafts can only be persisted through their visible save actions.
- Aligned the current-plan training-frequency and strategy rows by giving both leading icons the same layout slot.
- Kept nickname and body-profile save controls visible for the full edit state; pressing save with no changed draft now exits edit mode without writing to SQLite, while changed drafts still persist through the same explicit button.
- Removed duplicate unit text from the body-profile height and weight tile titles, keeping units beside the values and editors instead.

### Validation

- `flutter analyze`: success.
- `flutter test`: success.
- `flutter build apk --debug --split-per-abi --build-number 19`: success.

## 2026-06-12 Profile And Custom Exercise UI Redesign

### Changed

- Rebuilt temporary custom exercise creation into a card-first control surface with a compact slider-style strength/cardio toggle, isolated name card, bento-style strength metadata, cardio-specific summary rules, and a fixed bottom add action.
- Tightened custom-exercise typography and tile layout to match the scale of the existing Home, Food, and Workout surfaces, added short tile labels with full-width load-rule layout and narrow-screen fallback, and enlarged the transparent full-body workout icon presentation inside the exercise library.
- Reworked Profile into a summary-first dashboard with a current-plan hero, a compact display-first nickname card, a display-first 2x2 body-profile grid with single-tile editing, direct phase/mode/strategy chips, one-row g/kg self-check period choices, direct-save training-frequency setup, and card-local save actions for inline text and numeric fields instead of a single page-level save button.
- Switched shared workout body-part badges to the corresponding `assets/icons/workouts/*.png` assets where the app uses those fallback body-part icons.
- Followed up the Profile summary UI by turning nickname into a compact top identity row and allowing unchanged inline editors to collapse when the user taps elsewhere.
- Refined the custom-exercise page with a slider-style strength/cardio toggle, delayed single-column fallback, and denser two-column bento tiles so the strength layout stays compact on ordinary phone widths.
- Aligned the Profile header with the shared record-page title scale by renaming the visible top title to `User Settings` / `用户设置`, removing the extra top-right settings shortcut, restoring the plan matrix to stable horizontal wrap chips, and keeping the training-frequency setup card title fixed across diet modes.
- Changed the top nickname summary into a one-line identity row with a trailing pen trigger, inline auto-save on outside tap, and no persistent empty editor when nothing changed.
- Added a current-plan information trigger on Profile that reuses the Home strategy bottom-sheet style for beginner-friendly method guidance, mode-sensitive coefficient tables, and the g/kg explanatory note that was removed from the setup card body.
- Reordered Profile so `Energy Ratio Setup` now appears directly below the plan matrix in `energy_ratio` mode, while the shared training-frequency/self-check card stays below it and the plan matrix chips keep a stable wrap layout.
- Matched custom-exercise page typography more closely to the shared workout surfaces by reusing the Add Workout title scale for `Custom Exercise` / `自定义动作` and the Workout Parameter section-title scale for custom-exercise section headers.

### Validation

- `flutter analyze`: success.
- `flutter test`: success.
- `flutter build apk --debug --split-per-abi --build-number 6`: success.

## 2026-06-12 Inline Custom Deletion And Navigation Font

### Changed

- Replaced the separate custom-exercise management page and global library manage icon with inline swipe-to-delete for saved reusable custom exercises inside the dedicated custom picker group.
- Reworked the custom-exercise swipe delete row from Flutter `Dismissible` to a fixed-width short-swipe action button so tapping the revealed delete action reliably opens confirmation.
- Kept custom exercise deletion as a soft-hide flow with confirmation so saved workout history and exports remain explainable.
- Explicitly applied the selected `NotoSansSC` font family to bottom navigation labels and standard bottom-navigation label styles to avoid fallback fonts in the navigation bar.
- Updated bilingual product and app-guide docs plus the README workout description to reflect inline custom deletion instead of a dedicated management screen.

### Fixed

- Fixed the custom-exercise swipe row so inactive rows keep an opaque foreground, the delete action is not visible through the exercise tile, and tapping the revealed action uses a non-listening localization read before opening confirmation.

### Validation

- `flutter analyze`: success.
- `flutter test`: success.
- `flutter build apk --debug`: success.
- `flutter build apk --debug --split-per-abi`: success.

## 2026-06-12 Cardio Layout And Custom Exercise Management

### Changed

- Reordered cardio record-entry copy so the duration explanation sits above the duration field and the intensity question sits above the intensity picker, removing the stale extra duration sentence and reducing small-screen overflow risk.
- Added `isExpanded` cardio intensity dropdown handling plus ellipsized option labels to keep the closed picker stable on narrow mobile layouts.
- Moved reusable custom exercises into a dedicated picker group instead of mixing them into the built-in chest/back/legs/body-part filters.
- Added a dedicated custom-exercise management flow that hides saved custom exercises with confirmation instead of placing delete directly on ordinary picker rows.
- Added `is_hidden` export coverage for custom exercises.

### Added

- Added repository coverage for hiding a saved custom exercise while preserving it in the full local definition list.

### Validation

- `flutter analyze`: success.
- `flutter test`: success.
- `flutter build apk --debug`: success.

## 2026-06-11 Custom Exercises And Workout Input Modes

### Added

- Added reusable local custom exercises with separate strength and cardio creation flows, plus a save-time prompt for temporary ad-hoc exercises.
- Added schema version `11` with `custom_exercises`, workout-session exercise snapshots, cardio-intensity metadata, and workout-set raw-input versus normalized-calculation fields.
- Added workout calorie coverage for per-side load, per-side reps, duration-based strength sets, and interval-style cardio active minutes.
- Added export coverage for custom exercises, saved exercise metadata, cardio-intensity basis, active cardio minutes, and workout-set input/calculation fields.

### Changed

- Moved the built-in workout library onto exercise-definition metadata so built-in and custom strength exercises share load/reps/set metric handling.
- Updated cardio entry to use a maintainable-duration intensity basis and require active movement time for the under-3-minute interval option.
- Renamed the visible overhead press entry to Barbell Overhead Press / 杠铃推举 while preserving the existing overhead-press icon and legacy record compatibility.
- Renamed Rear Delt Fly to Dumbbell Rear Delt Fly / 哑铃反向飞鸟, removed Chest Fly and Hammer Strength High Row from the active picker, and mapped legacy Hammer Strength High Row display to Iso-lateral High Row / 分动式高位划船 in Chinese.
- Updated bilingual README and design docs for custom exercises, cardio intensity, strength input modes, schema version `11`, export coverage, and the no-app-internal-AI boundary.

### Validation

- `dart format lib test`: success.
- `flutter analyze`: success.
- `flutter test`: success.
- `flutter build apk --debug`: success.

## 2026-06-11 Shared Training-frequency Diet Setup

### Changed

- Replaced the `energy_ratio` Profile activity-level selector with the shared `training_frequency_per_week` setting and exposed the same training-frequency self-check controls in both diet modes.
- Updated the `energy_ratio` default no-exercise factor fallback so it now maps from the shared training-frequency setting, while keeping dynamic calibration as the higher-priority runtime source when local history is available.
- Kept `activity_level` as a compatibility/export field by deriving it from the shared training-frequency setting on profile save instead of using it as the primary user-facing input.
- Expanded training-frequency self-check so it can review workout history and suggest the shared setting in both `energy_ratio` and `gram_per_kg`.
- Updated bilingual product, algorithm, methodology, app-guide, database, agent-boundary, and README docs to describe the shared training-frequency setup and compatibility boundary.

### Validation

- `flutter analyze`: success.
- `flutter test`: success.
- `flutter build apk --debug`: success.

## 2026-06-11 Workout Draft Resume Flow

### Added

- Added SQLite schema version `10` with a dedicated `workout_record_drafts` table for one active unsaved workout editor state.
- Added a compact workout draft resume bar above `Add Workout` on the Workout tab so users can reopen or discard an unsaved training draft without creating a saved record first.
- Added a focused `workout_record_draft_test.dart` unit test covering draft payload parsing and repository-map round-tripping.

### Changed

- Reworked `AddWorkoutPage` so editor exit now keeps a local draft instead of forcing immediate save/discard handling on back navigation.
- Split workout editor persistence into draft autosave and explicit saved-record commit paths, keeping validation on the explicit save path only.
- Simplified workout draft internals by sharing one editor snapshot for draft comparison and persistence, and by reusing the Workout Log page data load for the draft bar.
- Refined the Workout Log draft bar into a two-line title/subtitle summary that prioritizes record name, body-part summary, and exercise count over a single-line unsaved warning label.
- Tightened the draft bar subtitle so it uses short body-part labels and shows at most three body parts before collapsing the remainder into `+n`.
- Added red in-editor discard actions for both new workout drafts and unsaved edits to existing workout records.
- Updated bilingual workout design docs to describe the draft bar, autosave behavior, and schema version `10`.

### Fixed

- Prevented unsaved workout edits from being lost when the user leaves the editor before saving.
- Hardened saved workout replacement for older single-session records so edit-save no longer depends on `plan_id` already existing.

### Validation

- `flutter analyze`: success.
- `flutter test`: success.
- `flutter build apk --debug`: success.

## 2026-06-11 Documentation Naming And Chinese Doc Polish

### Changed

- Renamed the current AI boundary design document references back to `docs/en/AgentDesign.md` and `docs/zh/AgentDesign.md` to match the repository rules and avoid collisions with `AGENTS.md`.
- Updated README, AppGuide, and Methodology links so the design-document map no longer points to deleted `Agent.md` paths.
- Reworked the Chinese Product, App Guide, and Database doc structure into finished-source wording by localizing remaining section headings and recurring guide labels.
- Updated Chinese cross-document anchors to match the localized Product headings and the current Methodology strength-calorie heading.

### Validation

- Verified the required design-document tree still exists under `docs/en/` and `docs/zh/`.
- Searched for stale `Agent.md` design-document links after the rename cleanup.
- Re-checked Chinese doc reads with UTF-8 to distinguish terminal mojibake from real file corruption.

## 2026-06-10 Exercise PNG Icon Mapping

### Changed
- Added 14 dedicated transparent PNG exercise thumbnails and mapped them by exact workout-library exercise name.
- Updated workout thumbnails to prefer matched per-exercise PNG assets while keeping the existing body-part SVG icons as the fallback for unmatched movements.
- Kept the workout library, exercise localization, and calorie logic unchanged; this change only affects thumbnail rendering.

### Validation
- `flutter analyze`: success.
- `flutter test`: success.
- `flutter build apk --debug`: success.

## 2026-06-09 Split Biceps Curl Variants

### Changed
- Split the arm exercise library entry `Biceps Curl` into `Barbell Biceps Curl` and `Dumbbell Biceps Curl`.
- Kept legacy `Biceps Curl` localization and calorie-profile compatibility for previously saved workout records.

### Validation
- `flutter analyze`: success.
- `flutter test`: success.

## 2026-06-09 Add Bulgarian Split Squat

### Changed
- Added `Bulgarian Split Squat` to the legs exercise library and mapped its Chinese display name.
- Classified `Bulgarian Split Squat` as a lower-body compound movement so strength calorie estimation uses the intended lower-body heuristic profile.

### Validation
- `flutter analyze`: success.
- `flutter test`: success.
- `flutter build apk --debug`: success.

## 2026-06-08 Mode-Switched Home Dashboard

### Changed
- Split Home into mode-specific first-screen layouts instead of forcing both diet calculation modes through one kcal-centered hero.
- Kept the existing `energy_ratio` Home structure with the calorie ring, target intake, remaining kcal, exercise kcal, and compact macro cards.
- Rebuilt the `gram_per_kg` Home surface into a macro-first dashboard with the clipped arc, lowest-completion macro focus, remaining grams, and a bottom detail list for protein, carbs, and fat.
- Moved kcal intake and workout burn into compact tappable summaries inside the `gram_per_kg` dashboard instead of keeping a separate Today's Records card in that mode.
- Kept the Home strategy card below the `gram_per_kg` dashboard so the first viewport stays focused on execution signals while the explainer entry remains one scroll step away.
- Tightened the `gram_per_kg` first viewport so the macro dashboard occupies the opening screen more completely, with a lighter section title, a larger clipped arc, and a continuous vertical macro detail stack.
- Bundled `NotoSansSC` into the app and switched Home typography from best-effort fallback matching to an explicit packaged Chinese sans family.
- Reworked the `gram_per_kg` hero into a taller first-viewport composition that keeps the macro strip pinned near the bottom while using any recovered vertical space to enlarge the clipped arc.
- Replaced the bottom `gram_per_kg` macro rows with a three-column vertical strip separated by light vertical dividers so the first viewport stays information-dense without reintroducing cards.
- Tuned the `gram_per_kg` hero proportions again so the clipped arc remains the left-side visual anchor without visually crossing the right-side metrics or the bottom macro strip.
- Tightened the `gram_per_kg` right-side metric hierarchy again so the remaining-grams line regains emphasis while the intake and exercise kcal values stay smaller and closer to their chevrons.
- Rebalanced the `gram_per_kg` arc geometry and bottom strip spacing so the first-screen macro dashboard keeps a larger rounder left arc without letting it drift into the detailed macro columns.
- Rebuilt the `gram_per_kg` macro arc as a more explicit shared semicircle geometry, then dropped it slightly lower in the hero so the chart reads less like three loose arcs and more like one coherent left-side figure.
- Repositioned the `gram_per_kg` bottom macro strip so protein stays anchored on the left, carbs remain the visual center, and fat finishes closer to the right edge with matching divider structure.
- Locked the `gram_per_kg` arc into a dedicated semicircle viewport so all three macro tracks now derive from the same circle geometry and only the visible half carries progress.
- Pulled the `gram_per_kg` semicircle viewport back to the screen edge so the visible chart now exposes more of the true half-circle instead of an over-trimmed arc slice.
- Enlarged the `gram_per_kg` semicircle viewport again so the outer protein arc pushes further toward the page midpoint while preserving the stable half-circle geometry.
- Scaled the `gram_per_kg` semicircle group by expanding the arc canvas downward, increasing the actual shared radius while keeping the title gap visually consistent.
- Lowered the `gram_per_kg` macro strip and the right-side kcal record cluster slightly so the lower half of the semicircle reads as part of one continuous composition instead of visually dropping away from the text blocks.
- Enlarged the `gram_per_kg` focus header hierarchy again so the “priority replenish” section reads more like the dominant status block above the kcal summaries.
- Reworked the root navigation into a single moving selection capsule and kept the four root pages alive in an `IndexedStack`, which makes tab switching feel more intentional and avoids repeated page reconstruction.
- Cached Home's loaded future across ordinary rebuilds and only refreshes it when the selected date or refresh version changes, which reduces loading flashes when switching tabs.
- Updated the `energy_ratio` calorie ring to use intake-aware color semantics, including a soft orange empty state, green intake progress against an orange remainder, a fully green on-target state, and a fully red over-target state.
- Pushed the `gram_per_kg` bottom macro strip down again by a visible step while moving the right-side kcal summary block down much further, so the lower half of the semicircle now reads as connected to the detail area instead of hanging in open space.
- Unified the `energy_ratio` remainder orange so the empty-day full ring and the in-range remainder track now use the same visible hue.
- Kept `energy_ratio` right-side kcal values on one line by switching the metric value row to scale down as a single non-wrapping unit, which prevents four-digit values from stretching the calorie card taller than the intended first viewport.
- Reduced the `energy_ratio` right-side metric typography and vertical spacing slightly, then tightened the macro-card internals so the calorie and macro modules are more likely to fit together in the opening viewport without the ring losing visual priority.
- Dropped the `gram_per_kg` macro strip farther again and nudged the right-side kcal links down with it so the lower strip-to-arc gap reads closer to the title-to-arc gap at the top of the hero.
- Wrapped the `energy_ratio` calorie and macro cards in a dedicated first-viewport dashboard height so the opening screen stops at those two modules and keeps the strategy card fully below the fold on common phone sizes.
- Shifted the `energy_ratio` right-side metric column slightly farther right by widening the gap from the circular ring.
- Re-aligned the `energy_ratio` right-side metric stack to share the ring's full vertical span, while slightly enlarging the kcal values so the top remaining-calorie label and bottom exercise value anchor more cleanly to the circle.
- Re-expanded the `energy_ratio` calorie hero again by restoring a more natural right-side metric rhythm, increasing the kcal typography and spacing, and slightly enlarging the card without letting the strategy card rise back into the first viewport.
- Replaced the measured `energy_ratio` trailing spacer with a dedicated first-viewport dashboard box that contains only the calorie hero and macro cards, keeps their internal gap controlled, and uses a shorter protective tail below the macro card so the strategy card follows with a normal list rhythm.
- Restored the p2-style `energy_ratio` metric rhythm by keeping the group spacing tight and only nudging the right-side kcal values larger.

### Fixed
- Removed the `gram_per_kg` macro row overflow path that appeared once percent and gram progress text expanded on narrower screens.
- Prevented the `gram_per_kg` strategy card from peeking into the initial viewport on common phone sizes.
- Removed the artificial middle spacer that was creating an obvious blank band between the top macro dashboard and the vertical macro detail list.
- Kept the `gram_per_kg` kcal summaries readable by switching them from ellipsized single-line text to a smaller scale-down number-plus-unit treatment closer to the previous visual hierarchy.
- Enlarged the `gram_per_kg` carbs icon badge so it matches the apparent visual weight of the protein and fat badges.
- Pulled the `gram_per_kg` right-side summary group closer to the trailing edge and tightened the chevron spacing so the tappable kcal rows read as one compact block.
- Reduced the remaining-grams text hierarchy so it stays bold but no longer competes with the main macro name.
- Added a larger bottom safe zone above the `gram_per_kg` macro strip so the clipped arc no longer visually overlaps the first row of macro details on short screens.
- Relaxed the spacing between gram totals and percentages in the `gram_per_kg` macro strip without reintroducing the earlier overflow path on smaller phones.
- Fixed the `gram_per_kg` macro strip dividers so they sit on the true column boundaries between protein/carbs and carbs/fat instead of drifting with the content alignment.
- Pulled the protein and fat macro-strip content slightly inward with matching edge spacing so the outer columns read more balanced without moving the center divider geometry.
- Nudged the protein and fat macro-strip content a bit further inward with mirrored alignment so the outer columns feel tighter around the centered carbs column.
- Tightened the protein and fat macro-strip columns slightly more toward center with matching mirrored offsets.

### Validation
- `flutter analyze`: success.
- `flutter test`: success.
- `flutter build apk --debug`: success.

## 2026-06-07 Workout Library Refresh

### Changed
- Rebuilt the workout exercise library from the updated master list, including expanded chest, back, shoulders, arms, glutes, full-body, and cardio coverage plus the new `Glutes` body-part bucket.
- Updated workout localization so the refreshed library names and the new glutes category display correctly in Chinese UI.
- Refined strength calorie profiling so the new movement set routes through the intended compound, isolation, lower-body, or high-density heuristic buckets.
- Changed assisted pull-up and assisted dip handling so the entered weight is treated as assistance load and actual movement load is calculated as `bodyweight - assistance`.
- Updated workout detail and record-entry copy so assisted movements show `Assist (kg)` instead of added load wording.
- Synced the bilingual workout design docs with the refreshed library structure and assisted-load calorie rule.

### Added
- Added a workout calorie test covering assisted bodyweight load handling.

### Validation
- `flutter analyze`: success.
- `flutter test`: success.
- `flutter build apk --debug`: success.

## 2026-06-07 Home And Log UI Follow-up

### Changed
- Reworked the Home macro section into three equal-size cards with matched badge sizing, aligned content slots, and clearer protein, carbs, and avocado-style fat icons.
- Forced long Home nicknames onto a dedicated second line so the greeting no longer wraps awkwardly beside the salutation.
- Migrated Home macro icons and workout body-part thumbnails from painter-based glyphs to SVG assets with shared icon-badge rendering.
- Adjusted the Home protein macro SVG to match the requested bone-style reference mark after the SVG migration.
- Redrew the Home carbs and fat macro SVGs to better match the wheat and avocado reference shapes, and refined the protein mark to read more cleanly at small sizes.
- Switched the Home macro icons from SVG to user-provided transparent PNG assets so the protein, carbs, and fat marks can preserve more visual detail inside the existing badge layout.
- Switched the Home strategy, food, and workout summary icons to transparent PNG assets and aligned their badge sizing with the updated macro icon treatment.
- Restored the Home strategy chevron as a tappable guidance card that opens a structured carb-cycling or carb-tapering explainer sheet.
- Expanded the Home strategy sheet with concrete principle, number-change, and setup guidance, including when to use low, medium, and high carb days and how to choose taper speed, step size, and review window.
- Moved the Food Log estimate notice to the end of the selected-day record list and removed the redundant Workout Log subtitle so both detail pages now place the calendar strip directly under the title.
- Removed the extra top spacer from Food Log so its title and date-strip card align with Workout Log in the first viewport.
- Removed the extra Home consistency tagline and tightened the top spacing so the calorie and macro cards sit higher in the first viewport.

### Fixed
- Updated the bilingual Methodology and References docs so carb-cycling and carb-tapering explanations match the current local algorithm boundaries and include explicit evidence-backed usage framing.

### Validation
- `flutter analyze`: success.
- `flutter test`: success.
- `flutter build apk --debug`: success.

## 2026-06-07 Local-First UI Refresh

### Added
- Added local-only `user_profile.nickname` storage so Home can greet the user without introducing accounts or cloud identity.
- Added a focused `user_profile` compatibility test for nickname mapping and empty-local-fallback handling.

### Changed
- Rebuilt the app shell into a soft light theme with page-owned headers and a rounded bottom navigation bar.
- Refactored Home into a lower-density entry screen with greeting, primary calorie or macro overview, current diet context, and compact food/workout summaries.
- Refactored Food Log, Add Food, Workout Log, and Profile into a shared card-based visual system with consistent spacing, icon treatment, and action hierarchy.
- Kept Add Food within the existing local-first boundary: prompt copy and external JSON paste stay manual, and `Photo AI Analysis` remains a placeholder.
- Added Profile nickname editing and surfaced it as local UI-only identity rather than an account concept.
- Renamed `docs/en/AgentDesign.md` and `docs/zh/AgentDesign.md` to `Agent.md` to match the required design-document structure.
- Updated Product, AppGuide, and Database design docs for the new Home information architecture, local nickname behavior, and schema version 9.

### Validation
- `flutter analyze`: success.
- `flutter test`: success.
- `flutter build apk --debug`: success.

## 2026-06-07 App Guide And Methodology Citations

### Added
- Added bilingual `docs/en/AppGuide.md` and `docs/zh/AppGuide.md` to explain each app area, high-level behavior, and related design-document entry points.

### Changed
- Added inline reference markers in Methodology so key user-facing claims point to `References.md` entries.
- Updated the README design-document table to include AppGuide.
- Updated `AGENTS.md` documentation rules so AppGuide is part of the required design documentation set.

### Validation
- Documentation-only change; Flutter analysis and tests were not required.

## 2026-06-07 Methodology Documentation

### Added
- Added bilingual `docs/en/Methodology.md` and `docs/zh/Methodology.md` to explain user-facing reasoning behind FitLog's diet modes, carb strategies, and exercise calorie methods.
- Added README method-summary sections that point users to Methodology, Algorithm, and References.

### Changed
- Updated the README documentation map into a design-document table and included Methodology.
- Updated `AGENTS.md` documentation rules so Methodology is part of the required design documentation set.

### Validation
- Documentation-only change; Flutter analysis and tests were not required.

## 2026-06-07 Documentation Structure Cleanup

### Changed
- Rebuilt `README.md` as a stable bilingual project overview with English first and matching Chinese content second.
- Kept `CHANGELOG.md` English-only and limited to dated project changes.
- Split design documentation into `docs/en/` and `docs/zh/`.
- Reworked Product, Algorithm, Database, Agent, and References docs as stable design files instead of date-appended update logs.
- Added document maintenance rules to `AGENTS.md`, including source-of-truth, language, and terminal-encoding verification rules.

### Validation
- Documentation-only change; Flutter analysis and tests were not required.

## 2026-06-07 Workout Record Summary Layout Follow-up

### Changed
- Rebalanced saved workout-record summary columns so the volume value keeps `kg` on the same line more reliably.
- Pushed the sets metric farther right to free more horizontal space for the volume column.
- Kept kcal on the body-part row for collapsed exercise cards and left set count out of the collapsed state.
- Kept the `#` column fixed in saved single-exercise strength tables while shifting the `weight + reps` block to the right.

### Validation
- `flutter analyze`: no issues found.
- `flutter test`: all tests passed.
- `flutter build apk --debug`: success.

## 2026-06-06 Workout Record UI Refinement

### Changed
- Moved the strength-calorie estimation note out of each individual strength exercise card and into the shared training-parameters area when strength exercises are present.
- Split workout notes into a separate optional card below training parameters.
- Increased spacing for the total-sets metric in saved workout-record summaries to reduce crowding with total volume.
- Changed saved strength exercise detail to use table-style weight and reps headers.
- Changed saved strength set rows to display weight and reps as separate columns, using `x` before reps.
- Removed the sample naming hint from the workout-record name field.
- Rebalanced vertical spacing around the workout-record name field inside training parameters.
- Workout records now preserve the user's exercise selection order instead of falling back to exercise-library order.
- Exercise-library multi-select now shows selection order as `1 / 2 / 3...` for chosen exercises.
- Saved workout-record summary metrics now stay aligned on one row and keep `kg` on the same line as the volume value.
- Collapsed exercise cards now place kcal beside the body-part line and remove the set-count line.
- Saved single-exercise strength tables now shift the `weight + reps` block to the right while keeping the `#` column fixed.

### Validation
- `flutter build apk --debug`: success.

## 2026-06-06 Workout Record Flow Update

### Added
- Added `record_name` to saved workout sessions so one multi-exercise workout record can carry a user-defined name across the whole saved group.
- Added create-time naming for workout records.
- Added saved workout record summary metrics: total duration, total volume, total sets, and estimated calories.
- Added full-record edit re-entry through the same page used for workout creation.

### Changed
- User-facing workout copy now uses `Workout Record` instead of `Workout Plan` for saved entries.
- Saved workout records still use shared `plan_id` internally, but now behave as editable named records in the UI.
- Saving a strength workout record now persists completed sets only.
- Unchecked strength sets are removed before save and remaining saved sets are renumbered from `1..n`.
- Create/edit workout rows now show a row-level highlight after a set is marked completed.
- Saved single-exercise detail pages are now read-only for completion state and focus on clearer weight/reps display.

### Validation
- `flutter analyze`: no issues found.
- `flutter test`: all tests passed.
- `flutter build apk --debug`: success.

## 2026-06-06 Diet Strategy UI Follow-up

### Fixed
- Home dashboard hero now shows goal phase and diet plan strategy on their own line above the macro title to avoid overflow on narrow mobile screens.
- Home dashboard hero now keeps the original single-line title layout when `diet_plan_strategy = none`, showing only the current phase on the right and hiding the `None` label.
- Carb cycling weekly preview now breaks the carb day label and the `P / C / F / kcal` values into two lines for better readability.
- Carb taper review cards no longer expose raw internal reason codes like `review_cooldown_active`; visible review reasons are now shown as user-facing text only.

### Validation
- `flutter analyze`: no issues found.
- `flutter test`: all tests passed.
- `flutter build apk --debug`: success.

## 2026-06-05 Cutting Diet Strategy Layer

### Added
- Added `diet_plan_strategy` with `none`, `carb_cycling`, and `carb_tapering`.
- Added cutting-only local deterministic carb cycling and carb tapering services.
- Added schema v7 fields on `user_profile` and the new `diet_adjustment_reviews` table.
- Added export coverage for strategy fields, base/final target columns, and diet adjustment review history.
- Added tests for carb cycling, carb taper review logic, daily summary integration, and migration compatibility.

### Changed
- `DailySummaryService` now computes base targets first and then applies a separate strategy layer to produce final displayed targets.
- Home now shows strategy badge and strategy-specific target context.
- Profile now exposes cutting-only strategy settings, weekly carb cycling preview, and carb taper review/apply/dismiss flow.
- Under-18 protection now blocks cutting carb strategies in addition to deficit handling.

### Validation
- `flutter analyze`: no issues found.
- `flutter test`: all tests passed.

## 2026-06-05 Round 2 Simplification Cleanup

### Changed
- Extracted shared food-form support helpers for repeated date rows, save buttons, and editable food item draft mapping without changing food save flows.
- Unified CSV and XLSX export row construction through a single `ExportTableBuilder` so both export formats keep the same columns from one source of truth.
- Collapsed repeated food/workout repository row-to-model assembly into private helpers while preserving query order and child-record loading behavior.

### Validation
- `flutter analyze`: no issues found.
- `flutter test`: all tests passed.
- `flutter build apk --debug`: success.

## 2026-06-05 Workout Plan Save Atomicity Fix

### Fixed
- Workout plan save now finishes all validation before any workout session is inserted.
- If any exercise is missing duration or required set data, the app only shows the validation prompt and does not save a partial plan.
- Full-plan saves now use one repository transaction so repeated taps on an invalid first-time exercise no longer leave behind duplicate incomplete plans.

### Validation
- `flutter analyze`: no issues found.
- `flutter test`: all tests passed.
- `flutter build apk --debug`: success.

## 2026-06-04 Round 1 Simplification Cleanup

### Changed
- Extracted a shared `SelectedDateHeader` widget for Home, Food Log, and Workout Log date navigation UI.
- Extracted reusable Profile form field widgets for repeated numeric and option inputs without changing save flow or field behavior.
- Centralized allowed-option resolution helpers in `AppConstants` and reused them from profile/model/service code paths.

### Validation
- `flutter analyze`: no issues found.
- `flutter test`: all tests passed.

## 2026-06-04 Diet Goal Phase Split

### Added
- Added `diet_goal_phase` with `cutting` and `bulking` as the source of truth above diet calculation mode.
- Upgraded SQLite to v6 with additive `user_profile.diet_goal_phase TEXT NOT NULL DEFAULT 'cutting'`.
- Added the 2 x 2 diet matrix: `cutting/bulking` x `gram_per_kg/energy_ratio`.
- Added a separate bulking g/kg table; `prefer_not_to_say` still averages same-tier male/female coefficients.
- Added `diet_goal_phase` to User Profile and Daily Summary CSV/XLSX export.

### Changed
- `energy_ratio` now interprets `daily_energy_goal_kcal` by phase: cutting means deficit, bulking means surplus.
- Profile phase now drives deficit/surplus semantics instead of letting goal types mix freely.
- Home and Profile show the current goal phase.
- `gram_per_kg` remains independent from BMR, activity level, daily energy goal, logged exercise calories, and macro ratios.
- `macro_energy_equivalent_kcal` remains auxiliary in g/kg mode, not a kcal target counter.

### Validation
- Added coverage for cutting/bulking g/kg tables, `prefer_not_to_say` averaging, and phase-based energy target direction.
- `flutter analyze`: no issues found.
- `flutter test`: all tests passed.

## 2026-06-04 Cut MVP g/kg Carbohydrate Table Update

### Changed
- Updated only the `gram_per_kg` coefficient table for the cut-phase MVP.
- Reduced carbohydrate coefficients for male/female 2/3/4/5 training-frequency tiers.
- Kept protein and fat coefficients aligned with the cut MVP default table.
- Preserved `prefer_not_to_say` as the same-tier male/female average.
- Clarified that `gram_per_kg` and `energy_ratio` are parallel independent diet calculation methods.
- Clarified that training frequency is a coarse lookup tier, not real intensity, training age, training volume, or performance demand.

### Validation
- Added macro target calculator coverage for male, female, `prefer_not_to_say`, and `energy_ratio` conversion behavior.

## 2026-06-01 Workout Readability Rework

### Changed
- Removed the `Previous` column from strength set entry rows to restore horizontal space for current weight/reps input.
- Removed the `previousLabel` localization string.
- Removed per-cell rounded input borders and filled capsules in set rows.
- Switched to lighter borderless numeric entry for weight/reps.
- Kept row structure and action buttons while simplifying visual containers.
- Added subtle row separators to preserve scanning rhythm without heavy blocks.

### Validation
- `flutter analyze`: no issues found.
- `flutter test`: all tests passed.

## 2026-06-01 Workout UI Compaction And Date-targeted Food Copy

### Changed
- Refined strength set input style with denser input decoration, smaller action buttons, and row-level structure.
- Added previous-set summary text in the compact workout row layout.
- Reduced per-exercise card visual weight.
- Changed food record copy to open a date picker before duplication.
- Copied meal name, nutrition fields, source, confidence, notes, and item rows into a new local record for the selected target date.

### Validation
- `flutter analyze`: no issues found.
- `flutter test`: all tests passed.

## 2026-05-31 UX And Food Log Copy Update

### Fixed
- Historical strength set values shown in muted text now select fully on tap when still in default-display state.
- New numeric input cleanly overwrites historical defaults instead of inserting into the middle of the value.

### Added
- Added a copy icon button on each food record card.
- Added localized copy action, success, and failure strings.

### Validation
- `flutter analyze`: no issues found.
- `flutter test`: all tests passed.

## 2026-05-17 Diet Algorithm Dual-Mode Update

### Added
- Added `diet_calculation_mode` with `energy_ratio` and `gram_per_kg`.
- Added `training_frequency_per_week` with 2/3/4/5 tiers.
- Added g/kg self-check fields: `macro_self_check_period_days`, `macro_self_check_enabled`, and `last_macro_self_check_at`.
- Added `MacroTargetCalculator` support for `energy_ratio` macro percentages and `gram_per_kg` table lookup.
- Added `TrainingFrequencySelfCheckService` for g/kg mode.
- Added profile, daily summary, CSV, and XLSX export coverage for diet mode and self-check fields.

### Changed
- `energy_ratio` kept the existing kcal target to macro grams flow.
- `gram_per_kg` computes protein, carbs, and fat directly from bodyweight and same-tier sex/frequency coefficients.
- In `gram_per_kg`, `target_intake` and `remaining_calories` are not primary counters.
- Dynamic calorie calibration remains independent from g/kg self-check.

## 2026-05-16 Dynamic Calorie Target Calibration

### Added
- Added `user_weight_logs` for daily weight history.
- Added `calorie_calibration_state` for calibrated lifestyle factor and confidence metadata.
- Saving Profile now upserts the current day's weight log.
- Added exported metrics for lifestyle factor used, no-exercise target intake, calibration confidence, window, and valid-day count.

### Changed
- Daily target logic now computes a no-exercise baseline first, then adds logged net exercise calories.
- Cardio now uses net MET: `(MET - 1) * 3.5 * weight / 200 * minutes`.
- Strength calories remain volume-driven and split into active lifting, post-training recovery, and muscle repair/adaptation components.
- Strength duration is used only for a capped recovery-density modifier, not linear calorie accumulation.
- Calibration uses 28/21/14/7 day candidate windows, 7-day start/end rolling average weight, observed non-exercise TDEE, EWMA smoothing, per-update step cap, and global factor clamp.

## 2026-05-16 Add Workout Follow-up Fixes

### Fixed
- Decimal historical set weights now render reliably in Add Workout.
- Default workout set values remain convenient while allowing direct overwrite on focus.

### Changed
- Strength duration now creates visible but capped kcal differences through the recovery-density modifier.
- The muscle-repair component remains enabled in strength net kcal.

## 2026-05-15 Workout Flow And Calorie Logic Update

### Fixed
- Hardened workout plan edit save flow against async route/context disposal issues.
- Replaced the bottom-sheet editor with a dedicated full-page editor for date, time, and total duration.

### Added
- Added walking as a cardio exercise and display-name mapping.
- Added a dedicated multi-select exercise picker page.
- Added per-exercise duration input, which is especially important for cardio.
- Added strength net-calorie guidance copy.
- Added localization for the collapsed picker flow, add-selected action, duration guidance, strength notice, and duration validation.

### Changed
- Cardio remains duration-based using MET logic.
- Strength no longer scales calories linearly by duration.
- Strength estimation is driven by set volume, effective load, reps, bounded body factor, bounded intensity factor, recovery, and adaptation.
- Creation and edit paths now use the same calorie logic.
- Historical set values are reusable as defaults, and user edits can directly overwrite them.

### Validation
- `flutter analyze`: no issues found.
- `flutter test`: all tests passed.
