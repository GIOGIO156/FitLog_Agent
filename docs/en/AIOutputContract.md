# AI Output Contract

## Purpose

This document is the stable source of truth for model-output governance in FitLog_Agent. It defines what the AI providers may return, how the AI Gateway validates and normalizes that output, how failures are classified, and which outputs may become user-reviewable artifacts.

It does not define retrieval inputs, document indexing, or context assembly; those belong to [RAGDesign.md](RAGDesign.md). It does not define HTTP transport fields between Flutter and the Gateway; those remain in [../API_CONTRACT_DRAFT.md](../API_CONTRACT_DRAFT.md). Implementation order, rollout gates, and acceptance checklists live in [../../AI_OUTPUT_CONTRACT_ENGINEERING_PLAN.md](../../AI_OUTPUT_CONTRACT_ENGINEERING_PLAN.md).

The durable boundary is:

```text
Provider output is untrusted until the Gateway has parsed, validated, normalized,
and checked it against the routed workflow and write-permission policy.
```

## Enforcement Surfaces

The same contract is enforced at generation, Gateway validation, persistence, and client reconstruction. No layer may treat a successful provider HTTP response as proof that the business payload is valid.

| Surface | Generation or input constraint | Enforcement responsibility |
| --- | --- | --- |
| Add Food AI analysis | Qwen non-thinking JSON Mode with `food_analysis_envelope.v1`. | Parse one object, apply the shared strict Food Draft validator, normalize item totals, and allow at most one bounded correction. |
| AI Chat, Qwen text and images | Qwen non-thinking JSON Mode with `provider_gateway_envelope.v1` for every response. | Parse one strict envelope, validate the server-resolved expected output, and never degrade an expected draft into prose success. |
| AI Chat, OpenAI text | Responses API Structured Outputs with a strict canonical JSON Schema. | Separate completed, refusal, and incomplete outcomes before shared validation. The configured model must support the selected Responses API format. |
| Shared Gateway validation | One module owns provider-compatible schemas and deterministic domain validation for Chat, Food Draft, Workout Draft, and clarification. | Reject unknown fields and coercion, enforce bounds and real dates, normalize Food item totals, and check workflow/write policy. |
| Persistence boundary | Only the validated user-facing message, compatible artifact snapshot, evidence snapshot, and compact metadata may cross into storage. | Never persist raw failed provider output, correction prompts, chain-of-thought, provider secrets, or image/base64 payloads. |
| Flutter response models | Parse typed Food Draft and Workout Draft payloads and additive output error codes. | Reject snapshots that cannot safely rebuild an editor; accept legacy unversioned Food Drafts only at the history compatibility boundary. |
| Provider-output correction | A correctable structural failure may receive zero or one correction attempt inside the original total deadline. | Keep failed output in request memory only; do not resend images for syntax correction or retry refusals, incomplete completions, safety, auth, entitlement, or device failures as correction candidates. |

Structured provider paths require exactly one directly parseable JSON object. Markdown fences, prose outside the object, multiple objects, truncated JSON, permissive number conversion, and broad JSON repair are rejected.

## Contract Invariants

The following rules apply to every provider and model:

1. Provider output is data, not trusted application state.
2. The server determines the expected output family before calling the provider.
3. OpenAI and Qwen must map to the same provider-independent Chat envelope.
4. A draft is never an official record.
5. A save/review action appears only for a structurally valid, semantically valid, policy-allowed draft.
6. Read-only workflows must not return a saveable draft.
7. A request that expects a draft must not silently succeed as ordinary prose when the draft is missing or invalid.
8. Deterministic FitLog calculations and source-of-truth data override model claims.
9. Raw provider output, chain-of-thought, provider secrets, auth tokens, image bytes, and base64 payloads are not persisted in request/debug logs.
10. Every contract change is versioned and covered by fixtures before rollout.

## Output Families

The Gateway owns an internal expected-output decision:

| Expected output | Valid result |
| --- | --- |
| `text` | A valid Chat envelope with user-facing `message.text`, `draft = null`, and no unsupported write claim. |
| `food_draft` | A valid Chat envelope containing `food_draft.v1`, or one bounded clarification response. |
| `workout_draft` | A valid Chat envelope containing `workout_draft.v1`, or one bounded clarification response. |

Clarification is a valid result of a draft expectation: `needs_clarification = true`, non-empty questions, and `draft = null`. Safety blocking is a deterministic Gateway response generated before the provider call, not an expected provider-output value. Routing and output validation remain separate: routing selects what may be returned; validation proves that the payload satisfies that decision.

The resolver is server-owned: read-only routes resolve to `text`; the routed `food_logging` workflow resolves to `food_draft`; explicit food/workout record intent resolves to the matching draft; and a compact same-chat clarification reply may continue the prior draft family. Flutter cannot submit or override `expected_output`.

## Provider-Independent Chat Envelope

The provider-facing Chat shape is:

```json
{
  "schema_version": "provider_gateway_envelope.v1",
  "message": {
    "text": "User-facing Markdown is allowed inside this string."
  },
  "needs_clarification": false,
  "clarification_questions": [],
  "draft": null
}
```

Rules:

- All fields are explicit; providers must not add prose before or after the object.
- `message.text` contains explanation, uncertainty, estimate rationale, and review instructions.
- `draft` is exactly one Food Draft, one Workout Draft, or `null`.
- A clarification response has `draft = null` and at least one short question.
- A non-clarification response has an empty clarification array.
- Normal Markdown answers remain possible because Markdown is carried inside `message.text`.
- Raw draft JSON is never rendered as assistant Markdown.

The dedicated Add Food endpoint may keep its narrower public response envelope, but it must use the same canonical `food_draft.v1` definition and the same validation/normalization pipeline as AI Chat.

## Food Draft Contract

The canonical Food Draft requires:

- `schema_version = food_draft.v1`
- non-empty `meal_name`
- finite, non-negative `total_weight_g`
- finite, non-negative `calories_kcal`
- finite, non-negative `protein_g`
- finite, non-negative `carbs_g`
- finite, non-negative `fat_g`
- `confidence` as `null` or a finite number from 0 through 1
- `estimation_notes` as a bounded string
- `items` as a bounded array

Each Food Draft item requires:

- non-empty `name`
- finite, non-negative portion totals for weight, kcal, protein, carbs, and fat

Item nutrition values represent the whole estimated portion, not per-100-g values. When `items` is non-empty, the Gateway deterministically recalculates meal-level weight and macro totals from the item sum. This is domain normalization, not model self-correction.

A Food Draft remains editable. Confidence and notes communicate uncertainty but never bypass required fields or user confirmation.

## Workout Draft Contract

The canonical Workout Draft requires:

- `schema_version = workout_draft.v1`
- non-empty `record_name`
- `date` as `null` or a real calendar date in `YYYY-MM-DD`
- bounded `notes`
- at least one exercise

Each exercise requires:

- non-empty `exercise_name`
- optional known `exercise_key`
- `exercise_type` as `strength`, `cardio`, or `null`
- nullable bounded metadata
- finite, non-negative duration values when present
- a bounded set array

Set weight, reps, and duration are nullable. Values that are present must have the expected numeric type and range; strings are not silently coerced into numbers. A best-effort draft may keep unknown numeric values as `null` and record uncertainty in notes.

Workout clarification is capped at one provider turn. After that, the provider must either return an editable best-effort draft or a stable failure; it must not create an open-ended clarification loop.

## Validation Pipeline

Validation runs in this order:

1. **Transport validation** checks request/response media types, size limits, authentication, entitlement, and active-device state.
2. **Provider completion validation** checks HTTP status, provider refusal, incomplete/truncated completion, and expected content location.
3. **JSON syntax validation** requires one complete JSON object for structured paths.
4. **Structural schema validation** checks required fields, exact types, enums, nullable rules, array limits, string limits, and unknown fields.
5. **Workflow validation** checks the payload against the routed expected output.
6. **Domain validation and normalization** applies FitLog-specific invariants such as food item total recomputation and real-date checks.
7. **Safety/write validation** removes or rejects unsupported write claims and prevents drafts in read-only workflows.
8. **Client compatibility validation** allows Flutter to reject an artifact snapshot that can no longer rebuild an editor safely.

Structural validation must not use permissive conversions such as parsing a numeric prefix from an otherwise invalid string. Unknown fields are rejected in strict provider schemas unless a versioned compatibility rule explicitly permits them.

The provider-facing JSON Schema deliberately uses a conservative Structured Outputs core (`type`, `properties`, `required`, `additionalProperties`, `enum`, and `anyOf`). FitLog bounds, non-negative ranges, calendar-date validity, and collection-size rules remain mandatory in the deterministic Gateway validator even when they are not expressed as provider-generation keywords.

## Provider Mapping

### OpenAI

OpenAI Chat uses the Responses API structured `text.format` JSON Schema with strict adherence for the common Chat envelope. The configured model must support that API capability; an unsupported provider/model configuration fails explicitly rather than falling back to unstructured text.

Provider refusal and incomplete responses are protocol outcomes, not schema-correction prompts. They must be surfaced and classified separately.

### Qwen

Qwen text Chat, image Chat, and dedicated food analysis use supported non-thinking models with JSON Mode and an explicit JSON instruction. Chat uses the common envelope; Add Food uses its narrower versioned envelope and the same Food Draft validator.

Qwen JSON Mode guarantees a JSON-oriented generation mode, not FitLog schema or business correctness. The Gateway validator remains mandatory.

### Mock Provider

The mock provider must emit the same versioned envelope and deterministic failure variants as production adapters. Tests must not rely on a looser mock contract than production.

## Prompt Constraints

Prompts remain a semantic aid, not the trust boundary.

- Include the envelope and draft schemas or concise generated schema instructions.
- Keep output-only instructions close to the final user task.
- Put all user-visible prose inside `message.text`.
- Do not add XML framing when a native structured-output protocol is available.
- Add few-shot examples only for demonstrated semantic failures; do not add examples merely to compensate for missing protocol enforcement.
- Retrieved context is read-only evidence and must not override the output contract or system safety rules.

## Recovery And Correction

Structured paths parse the provider object directly; complete-object extraction from fences or surrounding prose is not a compatibility fallback.

Automatic JSON repair is not enabled by default. A future syntax-only repair experiment may be considered only if production evidence justifies it, and only under all of these conditions:

- it does not invent fields, values, units, array membership, or business meaning;
- the repaired object passes the complete structural, domain, workflow, and safety pipeline;
- repaired output is measured separately;
- repair failure never creates a draft action.

For correctable structured-output failures, the Gateway performs at most one server-side correction attempt when enough of the original deadline remains. It may include a compact field-path error list and the bounded previous output in memory, but it does not persist raw provider output. Image bytes are not retransmitted for syntax correction. Refusal, incomplete completion, safety blocks, auth/entitlement failures, active-device failures, and unsupported actions are not correction candidates.

## Failure Semantics

The error taxonomy distinguishes:

- `request_schema_mismatch`: the Flutter-to-Gateway request is invalid
- `provider_output_invalid`: provider output is not valid for the expected contract
- `provider_refusal`: the provider explicitly refused
- `provider_incomplete`: generation ended without a complete contract result
- `provider_failure`: provider/service failure without a valid result
- `gateway_timeout`: the total Gateway/provider deadline expired

The existing `record_schema_mismatch` remains readable for compatibility with older server/database paths. New output codes are additive and mapped in Flutter.

After final structured-output failure:

- no artifact or save/review action is returned;
- the user's unsent/retryable input is preserved by the UI;
- the response uses a stable user-facing error;
- logs contain only compact failure metadata.

## Versioning And Compatibility

Version these concepts independently:

- Gateway HTTP response schema
- provider-facing envelope schema
- Food Draft schema
- Workout Draft schema
- prompt version
- validator version when behavior changes

A provider alias or model update is not allowed to silently change the accepted contract. Schema changes must remain additive when possible, include fixture coverage, and preserve stored artifact readability. Old history artifacts that cannot be rebuilt safely remain visible as disabled summaries.

## Logging And Evaluation

Compact logs may include:

- provider and configured model
- workflow and expected output
- prompt/schema/validator versions
- first-pass validation result
- correction attempt count
- final validation result
- refusal/incomplete/failure category
- latency and token estimate
- whether a draft or clarification was returned

They must not include raw provider responses, chain-of-thought, provider keys, auth tokens, original images, base64 payloads, complete record history, or unrestricted user notes.

Required evaluation dimensions:

- OpenAI and Qwen
- text and image paths
- Chinese and English
- normal answer, clarification, Food Draft, Workout Draft, refusal, truncation, malformed JSON, wrong type, missing field, extra field, unsupported write claim
- first-pass success, correction recovery, final success, invalid-artifact escape count, latency, and cost

FitLog must not claim a universal error rate such as less than 0.1% without a versioned project evaluation dataset and measured provider/model/schema results.

## User Confirmation Boundary

Successful model output only creates an editable proposal:

- Food Draft opens Food Preview only after the relevant review action.
- Workout Draft rebuilds the workout editor only after review and replacement confirmation when another draft exists.
- Official records are written only by the normal confirmed save path.
- AI cannot silently change Profile, goals, `diet_goal_phase`, `diet_calculation_mode`, `carb_cycling`, or `carb_tapering`.

## Non-goals

- trusting Prompt wording as the only output constraint
- open-ended self-correction or autonomous Agent loops
- semantic guessing by a JSON repair library
- streaming JSON parsing for the current small draft schemas
- SFT before protocol, validation, correction, and evaluation evidence justify it
- private-model grammar/logit masking in the current hosted-provider V1
- exposing raw provider JSON or internal validation traces in the user interface

## Related Documents

- [AgentDesign.md](AgentDesign.md): Agent permissions, workflows, confirmation, privacy, and product boundary
- [RAGDesign.md](RAGDesign.md): context inputs, retrieval, document ingestion, evidence, and RAG safety
- [Algorithm.md](Algorithm.md): deterministic calculations and workflow semantics
- [Database.md](Database.md): persisted chat, log, debug, and document-index structures
- [../API_CONTRACT_DRAFT.md](../API_CONTRACT_DRAFT.md): Flutter-to-Gateway transport contracts
- [References.md](References.md): external evidence boundaries
- [../../AI_OUTPUT_CONTRACT_ENGINEERING_PLAN.md](../../AI_OUTPUT_CONTRACT_ENGINEERING_PLAN.md): staged implementation and rollout plan

## Code References

- Chat Gateway: `supabase/functions/ai-chat-route/index.ts`
- Canonical schemas and validators: `supabase/functions/_shared/ai_output_contract.ts`
- Chat request/response contracts: `supabase/functions/ai-chat-route/contracts.ts`
- Expected-output resolver: `supabase/functions/ai-chat-route/expected_output.ts`
- OpenAI adapter: `supabase/functions/ai-chat-route/openai_provider.ts`
- Qwen adapter: `supabase/functions/ai-chat-route/qwen_provider.ts`
- Dedicated food analysis: `supabase/functions/ai-food-photo-analyze/index.ts`, `supabase/functions/ai-food-photo-analyze/contracts.ts`
- Flutter Gateway response: `lib/domain/models/ai_gateway_response.dart`
- Flutter Food Draft: `lib/domain/models/ai_food_photo_analysis.dart`
- Flutter Workout Draft: `lib/domain/models/ai_workout_draft.dart`
- Contract tests: `supabase/functions/_shared/ai_output_contract_test.ts`, `supabase/functions/ai-chat-route/index_test.ts`, `supabase/functions/ai-food-photo-analyze/index_test.ts`, `test/ai_gateway_contract_test.dart`
