# FitLog AI Output Contract Engineering Plan

## 0. Status And Responsibility

Status: repository implementation, corrective output-selection and draft-date hardening, linked-project deployment, deterministic validation, and Qwen text Draft canaries are complete. OpenAI production canaries, a user-approved real food-image device test, monitoring, and rollback rehearsal remain operational acceptance work and must not be inferred from deployment success alone.

This file owns implementation order, acceptance gates, rollout, rollback, and validation for the FitLog AI output-constraint upgrade. Stable design facts live in:

- `docs/en/AIOutputContract.md` / `docs/zh/AIOutputContract.md`
- `docs/en/RAGDesign.md` / `docs/zh/RAGDesign.md`
- `docs/en/AgentDesign.md` / `docs/zh/AgentDesign.md`

The plan is intentionally separate from stable design documents so phase checklists and rollout notes do not become permanent product architecture.

### Landing Summary

Completed in the repository:

- canonical provider-compatible schemas and shared strict validators;
- server-owned high-confidence output resolution, bounded model selection after resolver abstention, and a unified Chat envelope;
- OpenAI Structured Outputs and Qwen JSON Mode for text/image Chat;
- shared Add Food validation, direct object parsing, and Food Draft versioning;
- provider completion/refusal/incomplete separation;
- at most one in-deadline correction attempt without image retransmission;
- additive server/Flutter error taxonomy and compatibility parsing;
- compact output-contract observability migration without raw-output retention;
- Edge Function type checks/tests, Flutter contract tests, bilingual design updates, and Document RAG seed regeneration.

Deployed to linked Supabase project `dyacqajcinjwrkbngeif` on 2026-07-10:

- applied and registered `202607100001_ai_output_contract_observability.sql` after safely reconciling the existing RAG migrations;
- deployed `ai-chat-route` version 16 and `ai-food-photo-analyze` version 11;
- uploaded the generator v3 Document RAG corpus with 495 chunks across 19 source paths;
- confirmed all six `ai_request_logs` observability columns and ran bilingual Document RAG search-RPC smoke tests.

Operational acceptance still required:

- run OpenAI text canaries and the user-approved real food-image device canary; Qwen deterministic Workout Draft and dedicated Add Food text canaries already pass;
- monitor first-pass/final validation, correction rate, refusal/incomplete rate, latency, and invalid-artifact escapes;
- rehearse adapter rollback before broad traffic enablement.

### Corrective Hardening Landing

The completed corrective work addresses production regressions discovered after the first strict-contract deployment:

- ordinary AI Chat now uses a high-confidence deterministic resolver that may abstain with `auto`; no match is no longer treated as `text`;
- explicit product workflows such as Add Food bypass Chat intent inference and keep a fixed draft family;
- provider envelope `provider_gateway_envelope.v2` carries `output_type = text | food_draft | workout_draft | clarification`;
- workflow/context routing and result-shape selection are separate, so authorized read-only context can support a reviewable draft without granting an official write;
- cross-field validation rejects output-type/payload mismatch and prose that claims a nonexistent draft was created;
- client parsing separates socket/timeout failures, provider/SDK failures, and invalid response reconstruction;
- AI and app-level passive notices keep the compact no-close treatment, expire automatically, clear on navigation/backgrounding, and preserve retry input where applicable;
- meal-decision answers without a request image receive deterministic ingredient-photo/delivery-screenshot guidance;
- provider prompts no longer expose internal phase labels to user-facing answers;
- compact logs record intent-resolution source, selected output type, and privacy-safe validation issue codes;
- the service role can finalize request logs and debug summaries after their initial RPC insert.

Deployed to linked project `dyacqajcinjwrkbngeif`:

- migrations `202607110001_ai_intent_output_observability.sql` and `202607110002_ai_observability_update_grants.sql`;
- `ai-chat-route` version 19 and `ai-food-photo-analyze` version 12;
- generator v3 corpus regenerated and uploaded with 504 chunks across 19 source paths;
- bilingual retrieval smoke tests returned the new intent-resolution and notification-lifecycle sections;
- real Qwen deterministic Workout Draft returned `workout_draft.v1`, with `expected_output = workout_draft`, `intent_resolution_source = deterministic`, and both validation passes recorded;
- real dedicated Add Food text analysis returned `food_draft.v1` without clarification.

The private user screenshot was not exported to the provider during engineering canary work. A synthetic 1x1 image reached the multimodal route but was rejected before provider completion as `provider_failure`; real food-image recognition therefore remains a manual device acceptance item using the rebuilt APK and the user's own consent.

### Draft Date And Lifecycle Hardening

The current repository increment closes the remaining date and client-lifecycle gaps without changing the two-layer output-family resolver:

- `food_draft.v2` and `workout_draft.v2` require a real target date;
- Chat resolves supported explicit/relative dates against the request date, defaults to the selected date when no cue exists, and clarifies instead of guessing unsupported date language;
- provider output must match the server-resolved date, and user-visible draft confirmation text is derived from the validated artifact;
- Chat artifact cards and normal Food/Workout editors show the same date, with the existing themed calendar interaction available before save;
- new `ai_chat_artifacts.v2` snapshots retain target-date metadata, while mixed-deployment responses and stored v1 artifacts remain readable through bounded compatibility conversion;
- starting an official workout save freezes lifecycle autosave, and cloud success ends with an ordered final draft deletion that older queued writes cannot overwrite;
- passive app notifications return to the compact no-close presentation, expire automatically, and clear when the app leaves the foreground.

The increment is deployed to linked project `dyacqajcinjwrkbngeif` as `ai-chat-route` version 20 and `ai-food-photo-analyze` version 13. The uploaded generator-v3 corpus contains 506 chunks across 19 source paths and two languages; focused Chinese and English retrieval smoke tests returned the new date rules from their owning documents. An authenticated UTF-8 Qwen canary resolved “yesterday” against `2026-07-11` and returned `workout_draft.v2` dated `2026-07-10`; the dedicated Add Food text canary returned `food_draft.v2` with the exact selected date `2026-07-09`. Neither canary wrote an official record. The configured split debug APKs were rebuilt after all local gates passed.

## 1. Goal

Build a provider-independent, measurable output-governance pipeline for OpenAI and Qwen:

```text
Fixed output or resolver abstention
  -> bounded provider `output_type` selection when needed
  -> provider-native generation constraint
  -> strict structural validation
  -> FitLog semantic validation and deterministic normalization
  -> workflow/write-policy validation
  -> at most one bounded correction attempt
  -> user-visible text or editable artifact
  -> user confirmation before official write
```

The primary success condition is not merely “valid JSON.” It is:

- no invalid or policy-disallowed draft reaches an enabled review/save action;
- OpenAI and Qwen follow the same provider-independent contract;
- expected drafts cannot silently degrade into successful prose;
- failures are classified, observable, retryable when appropriate, and safe;
- current Cloud/Profile/diet/workout source-of-truth and confirmation rules remain unchanged.

## 2. Non-goals

- no SQLite schema change
- no Cloud Records source-of-truth change
- no new official-write tool
- no autonomous Agent loop
- no user-supplied provider keys
- no user-record vector database
- no SFT in the initial rollout
- no private-model grammar/logit masking
- no streaming JSON parser for current draft sizes
- no broad JSON Repair that guesses business values
- no change to `energy_ratio` / `gram_per_kg` semantics
- no change to `diet_goal_phase` authority
- no automatic target, Profile, carb-cycling, or carb-tapering write

## 3. Pre-Landing Baseline Audit

This section records the repository state that motivated the implementation; it is historical plan context, not the current runtime design. Current stable behavior lives in the bilingual `AIOutputContract.md` files.

### 3.1 Provider generation

| Path | Current state | Risk |
| --- | --- | --- |
| Add Food Qwen | JSON Mode plus prompt shape | Valid JSON is more likely, but schema adherence remains Gateway-owned. |
| Chat Qwen image | JSON Mode plus mixed answer/draft envelope prompt | Better syntax control, but current hand-written validation and fallback are permissive. |
| Chat Qwen text | Draft format is Prompt-only; normal response is Markdown | Expected draft may return prose and be accepted as ordinary text. |
| Chat OpenAI text | Responses API without structured `text.format` | No hard schema constraint; current prompt does not define an equivalent strict draft contract. |
| Mock provider | Fixed text/failure fixtures | Can become less strict than production and hide integration gaps. |

### 3.2 Parsing and validation

Baseline strengths:

- request-side auth/subscription/active-device gates
- complete JSON-fence stripping and balanced-object extraction
- typed Food Draft and Workout Draft parsing
- finite/non-negative numeric checks in many fields
- deterministic Food item-total normalization
- native artifact cards instead of raw JSON
- Flutter-side compatibility parsing
- invalid stored artifact review buttons can be disabled

Baseline gaps:

- no single canonical machine-readable schema shared by both Edge Functions
- permissive number coercion may accept invalid numeric strings
- unknown fields are generally ignored
- Food Draft schema version is not consistently required by runtime validators
- confidence range is not limited to 0 through 1
- date shape checking is not full calendar validation
- array and string size limits are incomplete
- clarification combinations are not represented as an explicit strict union
- provider refusal/incomplete completion is not a separate output result
- expected draft missing can degrade into normal assistant text
- `record_schema_mismatch` conflates request compatibility and provider-output failure
- no server-side correction attempt

### 3.3 Observability

Current logs already hold provider/model, workflow, prompt/schema version, latency, token estimate, image count, compact debug dimensions, schema status, and final action.

Missing output-contract observations:

- expected output family
- first-pass validation result
- validator version
- correction attempt count
- provider refusal/incomplete category
- final structured-output result
- invalid-artifact escape measurement

## 4. Risks Before Modification

| Risk | Consequence | Mitigation |
| --- | --- | --- |
| Big-bang provider switch | Hard to identify whether failures come from schema, prompt, adapter, or model capability. | Land foundation first; enable OpenAI, Qwen text, and Qwen image separately. |
| Schema too strict | Valid clarifications or partial workout drafts are rejected. | Model all valid outcomes explicitly; create fixtures before enforcement. |
| Schema too loose | Invalid data reaches editors. | Exact types, bounded fields, unknown-field rejection, domain validation. |
| Provider capability mismatch | Configured model rejects structured-output parameters. | Document supported models, request-body tests, staging canary, stable rollback. |
| Retry doubles latency/cost | Slow image requests and poor UX. | Retry only schema-correctable failures, once, inside total deadline; measure separately. |
| Error-code migration breaks Flutter | Generic or incorrect user messages. | Add codes and Dart mappings before server enforcement. |
| Shared validator changes existing Add Food behavior | Food preview regression. | Preserve current draft shape through fixtures and migrate Add Food after Chat foundation. |
| Raw provider output leaks into logs | Privacy and security regression. | Keep correction payload in memory only and test log serialization. |
| Stored history becomes unreadable | Old artifact cards disappear or crash. | Additive schemas, version-aware parsing, disabled summary fallback. |

## 5. Target Components

The target implementation should have these narrowly scoped components:

| Component | Responsibility |
| --- | --- |
| Canonical schema module | Versioned Chat envelope, Food Draft, Workout Draft, and clarification schemas. |
| Expected-output resolver | Converts routed workflow/conversation state into `text`, `food_draft`, or `workout_draft`. |
| Provider adapters | Map canonical expected output to OpenAI Structured Outputs or Qwen JSON Mode. |
| Provider completion parser | Reads content/refusal/incomplete status without business coercion. |
| Structural validator | Enforces exact JSON Schema-compatible structure. |
| Domain normalizer | Applies Food item sums and other deterministic FitLog invariants. |
| Workflow/safety validator | Blocks draft/output combinations not allowed by the route. |
| Correction coordinator | Performs zero or one bounded schema-correction attempt. |
| Result mapper | Produces the existing public Gateway response and stable errors. |
| Metrics mapper | Writes compact attempt/final status without raw output. |

Avoid creating a general framework for arbitrary future artifacts. Implement only current Chat envelope, Food Draft, Workout Draft, and clarification outcomes.

## 6. Phase 0 - Contract Freeze And Baseline

### 6.1 Objective

Freeze decisions and build a test baseline without changing provider or user-visible behavior.

### 6.2 Required decisions

- provider-facing envelope version name
- whether Food Draft gains required `schema_version` immediately or through compatibility normalization
- exact required/nullable fields
- string and array bounds
- numeric ranges
- real-date behavior
- unknown-field policy
- allowed clarification combinations
- expected-output rules for draft follow-up turns
- provider refusal/incomplete mapping
- total request deadline and correction budget
- error-code compatibility period

### 6.3 Fixture corpus

Add versioned fixtures for:

- normal Chinese/English Chat answer
- Food Draft with/without items
- Food totals disagreeing with item sums
- Workout strength/cardio/mixed draft
- best-effort workout draft with null values
- valid one-turn clarification
- missing required field
- wrong primitive type
- numeric string
- non-finite/negative/out-of-range number
- invalid date
- empty names
- extra fields
- unknown schema version
- raw Markdown fence
- prose before JSON
- multiple JSON objects
- truncated JSON
- provider refusal
- provider incomplete/length stop
- unsupported write claim
- read-only route returning a draft
- expected draft returning ordinary prose

Keep deterministic provider-response fixtures in the repository. Real-provider prompts belong in a separate manual/canary checklist because network calls and model drift should not make CI nondeterministic.

### 6.4 Files

Expected test-only or planning changes:

- `supabase/functions/ai-chat-route/index_test.ts`
- `supabase/functions/ai-food-photo-analyze/index_test.ts`
- `test/ai_gateway_contract_test.dart`
- optional fixture directory under the relevant function test tree

### 6.5 Acceptance gate

- decisions are recorded in the stable Output Contract;
- each allowed result family has at least one valid fixture;
- each listed invalid category has a rejection fixture;
- existing Gateway/Flutter tests pass unchanged;
- no runtime provider request has changed.

## 7. Phase 1 - Canonical Schemas And Strict Validators

### 7.1 Objective

Introduce one schema source and strict validation without changing provider generation parameters.

### 7.2 Schema approach

Use an OpenAI Structured Outputs-compatible JSON Schema subset as the canonical representation:

- explicit object `type`
- explicit `properties`
- all required fields listed
- `additionalProperties: false`
- nullable fields represented by supported unions
- bounded arrays and strings where supported
- discriminated draft outcome where supported

If the runtime validator needs rules not supported by the provider subset, keep two layers:

1. provider-compatible structural schema;
2. deterministic FitLog domain validator.

Do not create two independently hand-maintained schemas.

### 7.3 Strict behavior

- no `parseFloat` prefix coercion
- no number-from-string conversion in provider output
- no unknown fields in strict schemas
- actual calendar date validation
- confidence limited to `0..1`
- non-negative finite nutrition values
- integer-only reps/duration seconds where required
- bounded question, item, exercise, and set arrays
- bounded user-visible/provider notes
- exactly one draft type or null
- clarification and draft are mutually exclusive

### 7.4 Compatibility

- keep public Flutter Gateway response shape stable in this phase;
- normalize legacy Food Draft schema-version absence only at a clearly named compatibility boundary if needed;
- store the canonical version in new artifact snapshots;
- preserve disabled-summary behavior for unreadable old artifacts.

### 7.5 Candidate files

- new narrowly scoped schema/validation module under `supabase/functions/_shared/` or the existing Chat function tree
- `supabase/functions/ai-chat-route/contracts.ts`
- `supabase/functions/ai-food-photo-analyze/contracts.ts`
- provider/function tests
- Dart contract tests only if the public payload changes

Choose shared placement only if both Edge Functions can import and deploy it reliably under Supabase's function bundling. Otherwise keep a generated/shared source with an explicit drift test; do not copy-paste two validators silently.

### 7.6 Acceptance gate

- both Edge Functions accept/reject identical Food Draft fixtures;
- all wrong-type and unknown-field fixtures fail;
- Food totals are still normalized deterministically;
- no valid existing Food/Workout fixture regresses unintentionally;
- public Gateway success/error behavior remains unchanged;
- `flutter analyze`, `flutter test`, and relevant Deno tests pass.

## 8. Phase 2 - Expected Output And Unified Chat Envelope

### 8.1 Objective

Make every Chat provider response machine-readable while preserving user-visible Markdown inside `message.text`.

### 8.2 Expected-output resolver

Derive expected output from:

- server-routed workflow
- whether the user explicitly requests a Food/Workout record draft
- same-chat clarification/artifact summary
- safety/read-only route

Do not trust a client-provided `draft` or expected-output field.

The resolver should return only:

- `text`
- `food_draft`
- `workout_draft`
- deterministic `blocked` before provider call

Clarification is a valid result of a draft expectation, not a client-selected workflow.

### 8.3 Unified envelope

Update OpenAI, Qwen, and mock prompts/adapters to return:

- schema version
- `message.text`
- `needs_clarification`
- `clarification_questions`
- `draft`

At this phase, provider-native strict settings may remain disabled; the purpose is to make parser, workflow, UI, history, and fixtures agree first.

### 8.4 Remove silent success

When expected output is a draft:

- plain prose is `provider_output_invalid`, not successful assistant text;
- a null draft without valid clarification is invalid;
- the wrong draft type is invalid;
- a read-only route returning a draft is rejected or deterministically downgraded with a safety flag, never exposed as reviewable.

### 8.5 Public response compatibility

Continue mapping the provider envelope to the existing Gateway response:

- assistant text remains `message.text`;
- draft stays in the existing `draft` field;
- evidence stays separate;
- Flutter Markdown rendering does not change;
- artifact cards remain native.

### 8.6 Candidate files

- `supabase/functions/ai-chat-route/workflow_router.ts`
- `supabase/functions/ai-chat-route/contracts.ts`
- `supabase/functions/ai-chat-route/providers.ts`
- `supabase/functions/ai-chat-route/mock_provider.ts`
- `supabase/functions/ai-chat-route/openai_provider.ts`
- `supabase/functions/ai-chat-route/qwen_provider.ts`
- `supabase/functions/ai-chat-route/index.ts`
- associated tests

### 8.7 Acceptance gate

- normal Chat still renders Markdown correctly;
- both draft types still create the correct native artifact;
- valid clarification works;
- expected draft plus prose fails deterministically;
- read-only route plus draft never creates a review action;
- stored artifact snapshot remains compatible;
- all automated tests pass.

## 9. Phase 3 - Provider-Native Generation Constraints

Land each adapter independently.

### 9.1 OpenAI first

Target:

- use Responses API structured `text.format`;
- send the canonical Chat envelope JSON Schema with strict adherence;
- verify configured model capability;
- handle text content, refusal content, and incomplete response status separately;
- preserve timeout and provider-failure mapping.

Tests:

- captured request body contains the exact structured format and schema version;
- no provider secret or unsupported client field enters the body;
- valid structured response parses;
- refusal maps separately;
- incomplete output maps separately;
- unsupported model/config failure is explicit.

Rollout:

1. mock/request-body tests
2. local/staging configured model call
3. text-answer canary
4. Food Draft canary
5. Workout Draft canary
6. enable for OpenAI traffic

### 9.2 Qwen text second

Target:

- supported non-thinking model;
- JSON Mode enabled for the unified Chat envelope;
- explicit JSON instruction remains in the prompt;
- no Prompt-only fallback when structured mode is required;
- schema validation remains fully server-side.

Tests:

- captured request body has `response_format = json_object`;
- `enable_thinking = false`;
- prompt contains JSON/envelope instruction;
- ordinary Markdown is carried inside `message.text`;
- valid/invalid Qwen content uses the same validator as OpenAI.

### 9.3 Qwen image third

Target:

- preserve up to three supported compressed images;
- preserve request-scoped image transport and no-retention boundary;
- use the same envelope and validator as Qwen text;
- keep image and user-note data out of logs and history.

Tests:

- image URL data exists only in provider request body;
- no image/base64 in evidence/debug/history;
- Food and Workout Draft cases;
- image clarification case;
- timeout and malformed output.

### 9.4 Dedicated Add Food last

Target:

- preserve its narrower product response;
- reuse canonical Food Draft schema and normalization;
- keep JSON Mode;
- align refusal/incomplete/error categories where public compatibility permits.

Do not force chat-style explanation into this endpoint.

### 9.5 Acceptance gate

For each provider/path:

- request-body contract test passes;
- staging/manual provider test passes;
- first-pass structured success is recorded;
- public Flutter behavior is unchanged except clearer failures;
- rollback has been rehearsed before the next adapter is enabled.

## 10. Phase 4 - Error Taxonomy And Client Mapping

### 10.1 Objective

Separate request compatibility from provider-output failures before correction enforcement.

### 10.2 Additive server codes

Planned:

- `request_schema_mismatch`
- `provider_output_invalid`
- `provider_refusal`
- `provider_incomplete`
- existing `provider_failure`
- existing `gateway_timeout`

Keep `record_schema_mismatch` during compatibility migration.

### 10.3 Flutter changes

- add enum/mapping cases;
- provide concise Chinese and English messages;
- restore/preserve user input for retryable output failure;
- do not mark refusal or safety block as network failure;
- no artifact action for any failed output;
- maintain device-replaced/auth/subscription semantics.

### 10.4 Candidate files

- server contract/error modules
- `lib/domain/models/ai_gateway_error.dart`
- `lib/core/localization/app_strings.dart`
- Gateway client/controller tests
- AI page retry-state tests

### 10.5 Acceptance gate

- every server code has Dart mapping and bilingual user text;
- retryable input is preserved;
- no failed result produces artifact UI;
- old server code remains readable by the new client during rollout;
- all tests pass before server enforcement.

## 11. Phase 5 - One Bounded Correction Attempt

### 11.1 Eligible failures

- malformed/incomplete JSON object when the provider did not explicitly refuse
- missing required field
- wrong primitive type
- invalid enum
- invalid draft/output combination
- extra field under strict schema

### 11.2 Ineligible failures

- auth, subscription, or active-device failure
- router safety block
- provider refusal
- unsupported action request
- provider/network timeout after the total deadline
- provider configuration error
- user cancellation

Transport-level retry, if ever added, is a separate policy from model schema correction.

### 11.3 Correction prompt

The correction request may include:

- the expected schema/version
- compact field-path validation errors
- bounded previous provider output
- explicit instruction to return one corrected object and no prose

It must not:

- enter logs/debug summaries as raw content;
- expose secrets;
- expand context beyond the original authorized request;
- ask the model to change official data;
- run more than once.

For image requests, decide during Phase 0 whether the correction call resends images or corrects only the previous structured content. The default should minimize image retransmission when the failure is syntactic, while preserving correctness for truly missing visual fields. Record the decision and cost impact before implementation.

### 11.4 Deadline and budget

- correction must fit inside one total Gateway deadline;
- reserve a first-attempt and correction budget explicitly;
- do not start correction when too little deadline remains;
- log attempt count and final result;
- preserve user input after final failure.

### 11.5 Acceptance gate

- first-fail/second-pass fixture;
- first-fail/second-fail fixture;
- refusal does not retry;
- safety block does not retry;
- timeout budget prevents a late second call;
- raw previous output is absent from persisted logs;
- final failure produces no artifact;
- latency/cost impact is measurable.

## 12. Phase 6 - Observability And Evaluation

### 12.1 Compact metadata

Add or derive:

- expected output
- validator version
- first-pass status
- correction attempt count
- correction result
- final validation status
- refusal/incomplete/failure category
- provider/model/prompt/schema versions
- latency/token estimate
- artifact/clarification result

Do not add raw provider response retention.

### 12.2 Automated contract metrics

CI acceptance:

- zero invalid fixture reaches a reviewable artifact;
- all valid fixtures pass;
- both providers use equivalent output families;
- client/server fixture compatibility passes;
- no secret/base64/raw-history leakage in serialized logs/evidence.

### 12.3 Real-provider evaluation set

Maintain a reviewed, versioned prompt set by category:

- Chinese/English
- normal text
- Food Draft text/image
- Workout Draft text/image where supported
- clarification
- ambiguous inputs
- refusal/safety
- long context
- malformed/adversarial format instructions
- RAG context containing JSON-like text or conflicting instructions

Record:

- first-pass structural success
- first-pass semantic/workflow success
- correction recovery
- final success
- invalid-artifact escape
- refusal/incomplete rate
- latency p50/p95
- token/cost impact

Set production thresholds after baseline measurement. Do not pre-commit to a universal `< 0.1%` claim.

## 13. Rollout And Rollback

### 13.1 Recommended order

```text
contract fixtures
  -> strict validators without behavior change
  -> unified envelope in mock/staging
  -> OpenAI structured output
  -> Qwen text JSON Mode
  -> Qwen image unified envelope
  -> Add Food shared validator
  -> error taxonomy/client mapping
  -> bounded correction
  -> full metrics enforcement
```

### 13.2 Feature control

If production traffic exists, use one narrow server-side output-contract mode:

- `legacy`: old provider generation/parser behavior
- `validate`: new validator observes/classifies but old public behavior remains where safe
- `enforce`: new envelope, strict failure semantics, and optional one correction attempt

Do not create a general feature-flag framework. Provider-specific enablement may be environment configuration if the existing deployment process already supports it.

### 13.3 Rollback

Rollback must not require:

- Flutter downgrade
- SQLite migration
- local-data clearing
- cloud-record rewrite

Rollback actions:

- return provider adapter to prior generation parameters;
- return output-contract mode to `legacy` or prior version;
- keep additive error parsing in the client;
- retain versioned logs/fixtures for diagnosis.

## 14. Validation Commands

After code changes:

```powershell
flutter analyze
flutter test
```

Run relevant Deno tests for both Edge Function trees using the repository's available Deno runtime. If no standard command is yet documented, establish one in the first implementation batch and add it to project instructions rather than relying on ad-hoc commands.

For provider adapter changes, also perform configured staging calls for:

- OpenAI normal answer and draft
- Qwen text answer and draft
- Qwen image draft and clarification
- dedicated Add Food text-only and image cases

Real provider checks must use server-managed secrets and must not print secrets, auth tokens, raw images, or full provider responses into shared logs.

## 15. Documentation Update Rules During Landing

After each completed phase:

- update implemented/partial/planned status in both `AIOutputContract.md` files;
- update both `AgentDesign.md` files only if Agent capability or user-visible boundary changes;
- update both `Database.md` files only if persisted fields/tables change;
- update API contract only if public request/response/error shapes change;
- update `References.md` only for stable source/evidence changes;
- add a concise English `CHANGELOG.md` entry for shipped behavior;
- regenerate Document RAG seed when indexed stable docs change.

Do not copy phase checklists into stable docs.

## 16. Completion Criteria

This engineering plan is complete only when:

- both providers use the approved provider-independent Chat envelope;
- OpenAI uses supported strict Structured Outputs;
- Qwen uses supported JSON Mode for all structured Chat paths;
- both endpoints share canonical Food Draft validation;
- draft expectations cannot silently become prose success;
- exact types, enums, bounds, dates, and unknown fields are enforced;
- Food item totals remain deterministically normalized;
- refusal and incomplete output are distinct from invalid schema;
- one bounded correction attempt is implemented and measured, or explicitly rejected after evaluation;
- invalid provider output never produces an enabled artifact action;
- compact first-pass/final metrics exist without raw-output retention;
- Flutter and Edge Function tests pass;
- real-provider acceptance passes for each enabled path;
- bilingual stable docs match the shipped state;
- rollback is documented and verified.
