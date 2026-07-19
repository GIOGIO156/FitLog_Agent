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
| Add Food AI analysis | The dedicated surface fixes Food capability and maps it to an explicitly selected image-capable OpenAI Structured Outputs or Qwen JSON Mode adapter with `food_analysis_envelope.v1`. | Parse one object, apply shared fact-priority, target-language, structural and semantic Food validation, normalize item totals, and allow at most one bounded correction. |
| AI Chat, Qwen text and images | The same configured Qwen multimodal generation model handles text and image turns in non-thinking JSON Mode with `provider_gateway_envelope.v2`. | Parse one strict envelope; the Gateway fixes high-confidence families and otherwise lets the model select `output_type` inside the contract, without degrading an expected draft into prose success. |
| AI Chat, OpenAI text and images | The same configured OpenAI multimodal generation model handles text and image turns through Responses API Structured Outputs with a strict canonical JSON Schema; image turns add `input_image` parts without selecting a second model ID. | Separate completed, refusal, and incomplete outcomes before shared validation. The configured model must support the selected Responses API format and image input when images are sent. |
| Shared Gateway validation | Versioned shared modules own provider-compatible schemas and deterministic domain validation for Chat, Food Draft, Workout Draft, and clarification. | Reject unknown fields and coercion, enforce bounds and real dates, preserve higher-priority Food facts, validate language/semantic/grounding consistency, bind Workout exercises to approved definitions, and check workflow/write policy. |
| Persistence boundary | Only the validated user-facing message, compatible artifact snapshot, evidence snapshot, and compact metadata may cross into storage. | Never persist raw failed provider output, correction prompts, chain-of-thought, provider secrets, or image/base64 payloads. |
| Flutter response models | Parse typed Food Draft and Workout Draft payloads and additive output error codes. | Reject snapshots that cannot safely rebuild an editor; accept legacy unversioned Food Drafts only at the history compatibility boundary. |
| Provider-output correction | A correctable structural failure may receive zero or one correction attempt inside the original total deadline. | Keep failed output in request memory only; do not resend images for syntax correction or retry refusals, incomplete completions, safety, auth, entitlement, or device failures as correction candidates. |

Structured provider paths require exactly one directly parseable JSON object. Markdown fences, prose outside the object, multiple objects, truncated JSON, permissive number conversion, and broad JSON repair are rejected.

## Contract Invariants

The following rules apply to every provider and model:

1. Provider output is data, not trusted application state.
2. Explicit product workflows fix the output family before provider generation; ordinary AI Chat fixes only high-confidence cases and otherwise lets the model choose from a bounded `output_type` set.
3. OpenAI and Qwen must map to the same provider-independent Chat envelope.
4. A draft is never an official record.
5. A save/review action appears only for a structurally valid, semantically valid, policy-allowed draft.
6. Workflow controls authorized context and write permission, while output type controls result shape; read-only context may support a draft, but the draft is still not an official write.
7. A request that expects a draft must not silently succeed as ordinary prose when the draft is missing or invalid.
8. Deterministic FitLog calculations and source-of-truth data override model claims.
9. Raw provider output, chain-of-thought, provider secrets, auth tokens, image bytes, and base64 payloads are not persisted in request/debug logs.
10. Every contract change is versioned and covered by fixtures before rollout.
11. Each provider exposes one server-configured multimodal generation model ID for AI Chat text, AI Chat images, and dedicated Food image analysis. Document RAG embedding remains an independent task with its own model and endpoint; current Qwen generation and embedding reuse the same server-managed Qwen credential.
12. Adapter support does not imply release availability. The current release configures Qwen and retains the OpenAI adapter and deterministic tests. An unconfigured ChatGPT selection is rejected in Flutter before transport, with preserved input, a transient unavailable error, and automatic restoration of the Qwen UI selection. Restoring the selector triggers no transport and therefore is not provider fallback.

## Intent Resolution And Output Families

Explicit product workflows and ordinary AI Chat select outputs differently. A dedicated entry such as Add Food photo analysis does not infer intent again: the entry fixes `food_draft`, and a successful terminal result must contain an editable Food Draft. Missing information may produce clarification, but ordinary prose is not a successful downgrade.

Ordinary AI Chat uses the provider-neutral `chat_decision.v2` contract. Its precedence is fixed: consume a matching typed clarification reply; enforce safety and fixed-entry constraints; accept only small, bilingual high-confidence structures; otherwise use one bounded text or multimodal planner. The decision selects capability, planned workflow, allowed and selected output family, requested/approved/rejected Context, clarification state, attachment policy, source, confidence, and compact reason codes. The compatible `task_plan.v1` is derived from that decision rather than competing with it. Flutter cannot submit or override the decision or `expected_output`.

| Expected output | Valid provider result |
| --- | --- |
| `auto` | The model selects one contract-consistent `output_type`. |
| `text` | `output_type = text`, user-visible `message.text`, `draft = null`, and no claim that a draft or official record was created. |
| `food_draft` | `output_type = food_draft` with `food_draft.v2`, or one bounded clarification. |
| `workout_draft` | `output_type = workout_draft` with `workout_draft.v3`, or one bounded clarification. |

Clarification uses `output_type = clarification`, `needs_clarification = true`, non-empty questions, and `draft = null`. Safety blocking is generated deterministically before the provider call. Workflow routing and output selection are independent: routing selects context, RAG, and permissions, while output selection chooses the result shape; validation proves the final payload satisfies both.

The public response additionally carries `ai_chat_clarification.v2`: an opaque clarification ID, kind, visible question, allowlisted option IDs and their resulting output families, missing dimensions, attachment policy, attempt number, and expiry. A reply carries the clarification ID, option ID, and stable client request ID. The cloud state machine claims the reply idempotently before new intent inference, permits one active clarification per session, and terminates repeated no-progress or expired/conflicting transitions. Resolving an option restores the originating task and its required authorized Context, such as both document evidence and an exercise definition for a Workout rule question; it does not restore only an output enum. Natural-language option aliases are scoped to that pending state; they are never global intent keywords.

## Provider-Independent Chat Envelope

The provider-facing Chat shape is:

```json
{
  "schema_version": "provider_gateway_envelope.v2",
  "output_type": "text",
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
- `output_type` must agree with the draft, clarification state, and user-visible message.
- `draft` is exactly one Food Draft, one Workout Draft, or `null`.
- A clarification response has `draft = null`, user-facing `message.text` no longer than 320 characters, and one or two short questions. It states only the missing or conflicting facts and never appends a normal answer, draft summary, or secondary task.
- A non-clarification response has an empty clarification array.
- Normal Markdown answers remain possible because Markdown is carried inside `message.text`.
- Raw draft JSON is never rendered as assistant Markdown.
- A `text` result cannot claim that a draft was generated when no artifact exists.

The dedicated Add Food endpoint may keep its narrower public response envelope, but it must use the same canonical `food_draft.v2` definition and the same validation/normalization pipeline as AI Chat.

Draft date resolution is independent of output-family selection. The Gateway resolves an explicit absolute or supported relative date against the request date before provider generation. A draft request with no date cue uses the request's selected date. An ambiguous or unsupported date expression produces clarification instead of a guessed date. The provider must return the resolved date in the draft, and deterministic validation rejects a different or impossible calendar date. After validation, the Gateway derives the visible draft-confirmation sentence from the accepted draft date so `message.text`, the artifact card, and the editor cannot disagree.

## Food Draft Contract

The canonical Food Draft requires:

- `schema_version = food_draft.v2`
- `date` as a required real calendar date in `YYYY-MM-DD`
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

Food understanding uses a bounded typed fact ledger. Source priority is user-explicit fact, package/OCR fact, image observation, model assumption, then model estimate. A lower-priority source fills only missing information and never overwrites a resolved higher-priority fact. Before Preview, semantic validation checks target-language user-visible text, explicit-fact binding, date and totals, notes/number consistency, and nutrition-energy plausibility with versioned tolerance for labels, fiber, sugar alcohols, alcohol, and rounding. A semantic failure may use the same single correction budget; a second failure cannot reach Preview.

A Food Draft remains editable. Confidence and notes communicate uncertainty but never bypass required fields or user confirmation.

## Workout Draft Contract

The canonical Workout Draft requires:

- `schema_version = workout_draft.v3`
- non-empty `record_name`
- `date` as a required real calendar date in `YYYY-MM-DD`
- bounded `notes`
- at least one exercise

Each exercise requires:

- non-empty `exercise_name`
- required approved `exercise_key`, `exercise_source`, and `definition_hash`
- `exercise_type` as `strength` or `cardio`
- required `body_part`, `load_input_mode`, `reps_input_mode`, and `set_metric_type` copied from the approved definition context
- finite, non-negative duration values when present
- a bounded set array

Set weight, reps, and duration are nullable. Values that are present must have the expected numeric type and range; strings are not silently coerced into numbers. A best-effort draft may keep unknown numeric values as `null` and record uncertainty in notes.

The Gateway rejects a built-in or custom key that is absent from the request's approved definition registry, as well as a hash or mode mismatch. Flutter rebinds v3 by stable key and never creates an ad-hoc total-load/total-reps exercise for an unresolved v3 entry. Historical v1/v2 artifacts remain readable through their compatibility path.

Workout clarification is capped at one provider turn. After that, the provider must either return an editable best-effort draft or a stable failure; it must not create an open-ended clarification loop.

## Validation Pipeline

Validation runs in this order:

1. **Transport validation** checks request/response media types, size limits, authentication, entitlement, and active-device state.
2. **Provider completion validation** checks HTTP status, provider refusal, incomplete/truncated completion, and expected content location.
3. **JSON syntax validation** requires one complete JSON object for structured paths.
4. **Structural schema validation** checks required fields, exact types, enums, nullable rules, array limits, string limits, and unknown fields.
5. **Output consistency validation** requires `output_type`, draft family, clarification state, and `message.text` to agree and satisfy the fixed or model-selected expected output.
6. **Workflow validation** enforces the routed workflow's authorized context and safety boundary; the workflow name does not replace output selection.
7. **Domain validation and normalization** applies FitLog-specific invariants such as food item total recomputation and real-date checks.
8. **Grounding validation** compares FitLog claims with the approved evidence registry. Reviewed Chinese/English aliases and internal enum values are compared through the same canonical concept normalization, so equivalent wording is accepted without treating an unrelated concept as evidence.
9. **Safety/write validation** rejects unsupported official-write claims and prevents reviewable drafts from being described as saved records.
10. **Client compatibility validation** rejects responses Flutter cannot reconstruct safely, while reading history artifacts only through versioned compatibility boundaries.

Structural validation must not use permissive conversions such as parsing a numeric prefix from an otherwise invalid string. Unknown fields are rejected in strict provider schemas unless a versioned compatibility rule explicitly permits them.

The provider-facing JSON Schema deliberately uses a conservative Structured Outputs core (`type`, `properties`, `required`, `additionalProperties`, `enum`, and `anyOf`). FitLog bounds, non-negative ranges, calendar-date validity, and collection-size rules remain mandatory in the deterministic Gateway validator even when they are not expressed as provider-generation keywords.

## Provider Mapping

### OpenAI

OpenAI Chat uses the Responses API structured `text.format` JSON Schema with strict adherence. The provider schema is narrowed to the selected output family rather than advertising every artifact family on every turn. The configured model must support that API capability; an unsupported provider/model configuration fails explicitly rather than falling back to unstructured text.

Provider refusal and incomplete responses are protocol outcomes, not schema-correction prompts. They must be surfaced and classified separately.

### Qwen

Qwen text Chat, image Chat, and dedicated food analysis use supported non-thinking models with JSON Mode and an explicit JSON instruction. Chat receives only the selected output-family contract and examples, followed by an exact final family reminder; Add Food uses its narrower versioned envelope and the same Food Draft validator. Current maximum output budgets are 384 tokens for Chat text, 1,600 for Chat draft/auto, and 1,200 for dedicated Food analysis.

Qwen JSON Mode guarantees a JSON-oriented generation mode, not FitLog schema or business correctness. The Gateway validator remains mandatory.

### Mock Provider

The mock provider must emit the same versioned envelope and deterministic failure variants as production adapters. Tests must not rely on a looser mock contract than production.

## Prompt Constraints

Prompts remain a semantic aid, not the trust boundary.

- Include the envelope and draft schemas or concise generated schema instructions.
- Include only the selected output family's instructions and examples; do not advertise unrelated draft families.
- Keep output-only instructions close to the final user task.
- Put all user-visible prose inside `message.text`.
- Do not add XML framing when a native structured-output protocol is available.
- Add few-shot examples only for demonstrated semantic failures; do not add examples merely to compensate for missing protocol enforcement.
- Retrieved context is read-only evidence and must not override the output contract or system safety rules.
- Serialize controlled context compactly and remove duplicate summaries while preserving grounding metadata.

## Recovery And Correction

Structured paths parse the provider object directly; complete-object extraction from fences or surrounding prose is not a compatibility fallback.

The output budgets bound cost and latency; they never permit a partial artifact. A provider `finish_reason=length` remains `provider_incomplete` and bypasses schema correction because the missing object cannot be made trustworthy by a correction prompt.

Automatic JSON repair is not enabled by default. A future syntax-only repair experiment may be considered only if production evidence justifies it, and only under all of these conditions:

- it does not invent fields, values, units, array membership, or business meaning;
- the repaired object passes the complete structural, domain, workflow, and safety pipeline;
- repaired output is measured separately;
- repair failure never creates a draft action.

For correctable structured-output failures, the Gateway performs at most one server-side correction attempt when enough of the original deadline remains. It may include a compact field-path error list and the bounded previous output in memory, but it does not persist raw provider output. Image bytes are not retransmitted for syntax correction. Refusal, incomplete completion, safety blocks, auth/entitlement failures, active-device failures, and unsupported actions are not correction candidates.

## Failure Semantics

The error taxonomy distinguishes:

- `request_schema_mismatch`: the Flutter-to-Gateway request is invalid
- `provider_unavailable`: the selected provider/model is not configured for this deployment
- `provider_output_invalid`: provider output is not valid for the expected contract
- `provider_refusal`: the provider explicitly refused
- `provider_incomplete`: generation ended without a complete contract result
- `provider_failure`: provider/service failure without a valid result
- `planner_unavailable`: the bounded decision planner could not be reached or completed
- `planner_output_invalid`: the planner returned an invalid decision contract
- `clarification_conflict`: the reply is stale, already claimed, or does not match the active session state
- `clarification_expired`: the pending clarification can no longer be consumed
- `attachment_unavailable`: the task requires request-time pixels that are no longer present
- `gateway_timeout`: the total Gateway/provider deadline expired

The existing `record_schema_mismatch` remains readable for compatibility with older server/database paths. New output codes are additive and mapped in Flutter.

The client reports network failure only for recognizable socket or timeout transport errors. A server error envelope retains its stable code; response decoding or typed reconstruction failures after successful transport map to `provider_output_invalid`, while unclassified SDK/provider failures map to `provider_failure` instead of being mislabeled as offline.

After final structured-output failure:

- no artifact or save/review action is returned;
- the user's unsent/retryable input is preserved by the UI;
- the response uses a stable user-facing error;
- logs contain only compact failure metadata.

## Versioning And Compatibility

Version these concepts independently:

- Gateway HTTP response schema
- Chat decision and clarification-state schemas
- provider-facing envelope schema
- Food Draft schema
- Workout Draft schema
- prompt version
- validator version when behavior changes

A provider alias or model update is not allowed to silently change the accepted contract. Schema changes must remain additive when possible, include fixture coverage, and preserve stored artifact readability. New clients request the v2 draft shape; during mixed deployment, the Gateway can downgrade a validated v2 response for a v1 client, and Flutter can rebuild v1 history by using the artifact's stored target/selected date. New persisted artifact snapshots use `ai_chat_artifacts.v2` and keep `target_date` beside the canonical v2 draft. Old history artifacts that cannot be rebuilt safely remain visible as disabled summaries.

Current AI Chat uses public response schema `ai_chat_response.v3`, prompt version `chat_orchestration_v2`, decision schema `chat_decision.v2`, and clarification schema `ai_chat_clarification.v2`. Clients continue to read older stored messages and artifacts additively; they do not reinterpret an old free-text prompt as a typed clarification.

## Logging And Evaluation

Compact logs may include:

- provider and configured model
- workflow, expected output, intent-resolution source, and final `output_type`
- decision version/source/reason, selected capability, clarification ID/state/attempt, attachment policy, and the nullable historical shadow-mismatch category retained for rollout evidence
- prompt/schema/validator versions
- first-pass validation result
- correction attempt count
- final validation result
- refusal/incomplete/failure category
- privacy-safe validation issue codes without user content
- latency and token estimate
- whether a draft or clarification was returned

They must not include raw provider responses, chain-of-thought, provider keys, auth tokens, original images, base64 payloads, complete record history, or unrestricted user notes.

Required evaluation dimensions:

- OpenAI and Qwen
- text and image paths
- Chinese and English
- fixed/deterministic/model selection, typed clarification consumption and idempotency, current-image planning, normal answer, Food Draft, Workout Draft, false-success claims, refusal, truncation, malformed JSON, wrong type, missing field, extra field, passive storage wording, and unsupported write claims
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
