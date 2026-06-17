# Agent Boundary

## Current Status

FitLog Local currently has no app-internal AI, LLM, or Agent execution capability.

The app does not currently implement:

- OpenAI, Gemini, ChatGPT, or other LLM API calls
- LLM SDK usage
- embeddings
- vector database
- RAG
- function calling or tool calling
- Agent loop
- AI conversation memory
- Agent action logs

Current AI-adjacent features are static or user-mediated:

| Feature | What happens | App-internal AI? | Main code |
| --- | --- | --- | --- |
| Prompt copy | The app provides bilingual prompt text that the user can copy to an external model. | No | `PromptTemplates`, `AddFoodPage._copyPrompt` |
| External AI JSON paste | The user manually pastes JSON produced outside the app. FitLog parses it locally. | No | `PasteAiResultPage`, `NutritionCalculator.parseAiFoodJson` |
| `source = ai_paste` | Saved records can mark that their source was an AI paste workflow. | No | `AppConstants.sourceAiPaste`, `FoodRecord.source` |
| Photo AI Analysis | A visible placeholder entry point. | No, not implemented | `AddFoodPage` |

## Deterministic Local Workflows

The app has local workflows that may feel automated, but they are deterministic Dart/database flows, not Agents.

| Workflow | Input | Output | AI used inside app? |
| --- | --- | --- | --- |
| Prompt language selection | Current UI language | Chinese or English prompt text | No |
| JSON parsing | User-pasted JSON string | `FoodRecord` and `FoodItem` data | No |
| Food save | Food record and items | SQLite rows | No |
| Food summary | Selected date records | Daily kcal/protein/carbs/fat totals | No |
| Custom exercise save | User-entered exercise metadata | Local reusable exercise definition | No |
| Workout exercise normalization | Exercise metadata, set input, duration, bodyweight | Saved raw input and normalized calculation values | No |
| Workout summary | Selected date sessions | Daily net exercise kcal | No |
| BMR and target calculation | Profile, food, workout, calibration state | Daily target and remaining values | No |
| Macro target calculation | Diet phase and calculation mode | Protein/carbs/fat targets | No |
| Dynamic calibration | Food history and weight logs | Calibrated lifestyle factor | No |
| Training-frequency self-check | Workout history | Suggested shared training-frequency setting | No |
| Diet strategy review | Weight trend, food coverage, training stability | Local strategy result or review suggestion | No |
| Export | SQLite records and runtime summaries | XLSX or CSV ZIP | No |
| Clear local data | User confirmation | Local table deletion | No |

## Agent Boundary Rules

- External AI may help estimate food before data enters FitLog Local.
- FitLog Local only stores, parses, summarizes, calculates, reviews, and exports local data.
- Prompt templates are not app-internal AI.
- JSON parsing is not app-internal AI.
- `carb_tapering` is a deterministic local review flow, not an Agent that changes goals by itself.
- Custom exercise creation, cardio-intensity selection, and workout-set normalization are deterministic local UI/database/calculator flows, not AI classification.
- The app must not introduce backend, cloud sync, LLM API, vector database, RAG, tool calling, semantic memory, or Agent loop unless explicitly requested.
- If a future Agent layer is added, it must be documented separately from current local deterministic algorithms.

## Current Non-goals

FitLog Local does not currently provide:

- Meal Decision Agent
- Weekly Review Agent
- Goal Review Agent
- AI Coach
- automatic meal plans
- automatic target updates
- automatic carb taper application
- app-internal photo recognition API
- semantic memory
- vector search
- RAG
- tool calling
- multi-step Agent loop

## Code References

- Prompt templates: `lib/core/constants/prompt_templates.dart`
- AI-adjacent food entry: `lib/features/food/add_food_page.dart`, `lib/features/food/paste_ai_result_page.dart`
- JSON parser: `lib/domain/services/nutrition_calculator.dart`
- Source marker: `AppConstants.sourceAiPaste` in `lib/core/constants/app_constants.dart`
- Local deterministic services: `daily_summary_service.dart`, `macro_target_calculator.dart`, `workout_calorie_calculator.dart`, `training_frequency_self_check_service.dart`, `diet_plan_strategy_service.dart`, `carb_cycling_calculator.dart`, `carb_taper_review_service.dart`
- Exercise metadata: `lib/core/constants/exercise_catalog.dart`, `lib/core/constants/exercise_definition.dart`, `lib/data/repositories/custom_exercise_repository.dart`
- Dependency check: `pubspec.yaml`
