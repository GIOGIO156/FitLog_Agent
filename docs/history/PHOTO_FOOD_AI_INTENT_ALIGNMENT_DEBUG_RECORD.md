# Photo Food AI Intent Alignment Debug Record

Date: 2026-08-05

This record preserves the debugging lesson behind the Food Photo AI intent-alignment work. It is intentionally stored under `docs/history` because it explains how the implementation drifted from the product goal, how the drift was diagnosed, and how the system was corrected. The current source of truth remains the stable product and contract documents:

- `docs/en/AIOutputContract.md` / `docs/zh/AIOutputContract.md`
- `docs/en/AgentDesign.md` / `docs/zh/AgentDesign.md`
- `docs/en/AppGuide.md` / `docs/zh/AppGuide.md`
- `docs/API_CONTRACT_DRAFT.md`

## 1. Product Goal

FitLog is a consumer food and training logging product. The Food Photo AI workflow should produce a low-friction, credible, user-editable draft, not a forensic conclusion.

The intended behavior is close to the earlier GPTs/local prompt experience:

1. The user may provide text, images, or both.
2. Text and images are complementary evidence.
3. A user-explicit food should not be removed only because it is not visible in the photo.
4. A visually identified extra food may be included when reasonable, with uncertainty reflected in the draft.
5. Conflicts and uncertainty should be exposed through notes and confidence, then left for user confirmation.
6. The app must still receive strict JSON that can be parsed into a stable food draft.
7. The AI result remains a draft until the user explicitly saves it.

## 2. Original Implementation Intent

The Agent version added Edge Functions, server-managed model keys, structured AI output, request logs, quota/auth boundaries, and app-native parsing. These were valid product and engineering goals:

| Decision | Original purpose |
| --- | --- |
| Use Supabase Edge Functions | Keep provider keys server-side, enforce auth/quota, and centralize model routing. |
| Use strict output contracts | Let Flutter parse drafts safely instead of asking users to paste free-form text. |
| Use `food_draft.v2` | Add a stable date-bearing draft shape shared by Add Food and AI Chat. |
| Validate and normalize provider output | Prevent malformed JSON, invalid numbers, inconsistent totals, or unsupported schema versions from reaching the client. |
| Add correction/retry | Recover from correctable structural output failures without forcing the user to retry. |
| Keep Add Food as a dedicated endpoint | Preserve a narrow, low-friction photo-analysis flow separate from full AI Chat. |

The intent was not to make the model less capable than the GPTs prompt. The intent was to wrap the same kind of model judgment in app-safe transport and confirmation boundaries.

## 3. Where The Implementation Drifted

The drift came from moving some product judgment out of the model prompt and into deterministic backend rules.

| Drift | Why it happened | Why it became wrong for C-end food logging |
| --- | --- | --- |
| Text/image food facts became hard validation candidates. | The team wanted to prevent hallucination and preserve user-stated facts. | Food photos are often partial, occluded, packaged, eaten, or multi-angle. Missing visual evidence is not proof that a user-explicit food is absent. |
| Semantic validators could reject otherwise usable drafts. | The team tried to make provider output more reliable after moving from GPTs into app-parsed JSON. | Reliability was conflated with food-judgment correctness. Structure should be hard-gated; food interpretation should mostly stay in model reasoning and user review. |
| Correction could run without original image context. | Correction was treated like syntax/schema repair, so image bytes were not resent. | For multimodal food drafts, correction without images can cause the model to reinterpret the task as text-only or claim that visual evidence is unavailable. |
| Multiple constraints accumulated independently. | Prompt, expected output, validator, normalizer, correction, and client parsing were each improved locally. | Locally sensible constraints stacked into a system that could optimize for passing gates instead of matching user intent. |
| App UX assumed the request result would return while the page was foregrounded. | Most manual tests waited on the page until completion. | Real users often background the app during long AI requests, especially when network latency is high. |

## 4. User-Visible Symptoms

Observed or suspected symptoms included:

1. The user uploaded an image and wrote a description such as “Snickers and banana”, but the returned analysis removed the banana with wording similar to “banana image or related description was not detected”.
2. Some valid-looking analyses returned “AI result did not pass validation; input preserved; please retry.”
3. After starting photo analysis and switching the app to the background, returning to the page could show no result.
4. Retrying on the same page after an interrupted/failed flow could still fail validation.
5. The photo-analysis page showed both a central loading dialog and a loading animation on the bottom button.

## 5. Debug Method

The effective debugging route was to trace the whole chain instead of blaming the model first.

| Layer | What was checked | Key lesson |
| --- | --- | --- |
| Flutter request assembly | Image count, MIME, base64 payload, selected date, user note, model choice. | The client can send a valid request while later lifecycle handling still loses the result presentation. |
| Dedicated Food Edge Function | Request parsing, image validation, prompt construction, provider payload, correction, strict parsing. | Image availability and correction context must be verified at the provider-request level, not inferred from the UI. |
| AI Chat Edge Function | Food draft prompt, expected output, correction, provider adapters. | AI Chat and Add Food share the same food draft contract, so intent-alignment fixes must apply to both. |
| Shared output contract | JSON parse, schema, date, numeric bounds, item totals, normalization. | These are appropriate hard gates and should remain. |
| Food semantic validation | Explicit fact, language, notes/nutrition plausibility, semantic issue codes. | These checks were too strong as blockers for consumer food drafts. |
| Correction path | Whether original images are resent during correction. | Multimodal correction needs the original image context. |
| Flutter response handling | Navigation/error display while lifecycle state changes. | A request that completes in the background should be consumed after resume. |
| Tests and eval fixtures | Which behavior was deterministic and which was model-dependent. | Tests should protect contracts and lifecycle behavior without over-specifying model judgment. |

## 6. Root Cause Summary

| Evidence level | Root cause | Evidence |
| --- | --- | --- |
| Code-proven | Food semantic validation had become a hard blocker for food drafts. | The Edge flow called shared semantic validation after provider output parsing. |
| Code-proven | Correction did not consistently keep original image context for multimodal food drafts. | Correction paths were treated mainly as structural repair. |
| Code-proven | Flutter could complete the async request while the page was backgrounded, then attempt result handling at the wrong lifecycle moment. | The photo-analysis page lacked an explicit pending-result handoff on app resume. |
| High-confidence inference | The “banana removed” class of failures came from over-constrained interaction between prompt, validator, correction, and model behavior. | The product text/image relationship was stricter in the app pipeline than in the GPTs prompt. |
| Needs production logs | Whether a specific user incident lost images before the provider request. | Existing logs were not sufficient to prove client image count, Edge image count, provider image count, and per-stage item changes for that exact request. |

## 7. Final Engineering Direction

The fix was not “remove all constraints”. The fix was to put each constraint at the right layer.

| Keep as hard Edge constraints | Move back to model/product judgment |
| --- | --- |
| Request shape, auth, quota, image count, image MIME, image size. | Whether a user-explicit food should stay when not visible. |
| JSON parseability and schema version. | Whether a visually seen extra food is certain enough to include. |
| Date validity and selected-date binding. | How to describe text/image conflict. |
| Finite non-negative numeric fields. | How much confidence to assign to an uncertain item or meal. |
| Item totals matching top-level totals. | Whether a partially visible/occluded food is a reasonable estimate. |
| Stable error envelopes. | Notes that explain uncertainty, missing visibility, packaging, or partial photos. |
| No automatic official food-record write. | Consumer-facing food interpretation. |
| Provider failure and missing-image technical errors. | Consumer draft wording and uncertainty expression. |

## 8. Implemented Changes

| Area | Change |
| --- | --- |
| Shared food semantics | `validateFoodSemantics` no longer blocks food drafts. Existing helper types remain for compatibility and future observation. |
| Dedicated Add Food endpoint | Food draft parsing now relies on the shared strict structural contract, not semantic food-fact hard gates. |
| AI Chat endpoint | `food_draft.v2` follows the same reduced-hard-gate strategy as Add Food. |
| Provider prompts | Food prompts now state that text and images are complementary, user-explicit foods should be preserved, visual additions may be included when reasonable, and uncertainty belongs in notes/confidence. |
| Correction prompts | Correction keeps the original user note and original images in provider context. |
| Flutter lifecycle | Backgrounded analysis results are stored as pending results and consumed after app resume. |
| Flutter UI | The bottom button remains static while disabled; the central overlay is the single visible progress indicator. |
| Tests | Added/updated tests for soft semantic behavior, correction image retention, provider prompt behavior, and background-result delivery. |
| Docs | Stable contracts now describe the current behavior; this file records the debugging history. |

## 9. Why This Is Closer To The GPTs Experience

The earlier GPTs setup worked well because it had a clear natural-language instruction and left most ambiguous food judgment to the model. The app still needs more structure than GPTs because Flutter must parse the result, show a preview, and preserve confirmation boundaries.

The corrected design keeps the app-only necessities:

- strict JSON;
- stable `food_draft.v2`;
- safe numeric fields;
- item-total consistency;
- request limits;
- server-managed model keys;
- no automatic official write.

It removes the app-specific overreach:

- no deterministic deletion of user-explicit food only because the photo does not show it;
- no correction that silently drops image context;
- no semantic hard gate that forces a model to satisfy backend assumptions over user intent;
- no new item-level evidence/confidence protocol expansion unless a real UI need later proves it necessary.

The result should behave more like “GPTs prompt + app-safe parser”, instead of “GPTs prompt + several hidden semantic judges”.

## 10. Validation Strategy

The validation goal is regression safety: the change should improve Food Photo AI behavior without changing mature app features.

| Validation layer | Acceptance |
| --- | --- |
| Deno type check | Both `ai-chat-route` and `ai-food-photo-analyze` type-check. |
| Edge contract tests | Shared AI output contract, AI Chat expected output, AI Chat route, and Food Photo route tests pass. |
| Food semantics tests | Text/image disagreement is treated as soft prompt behavior, not a blocking issue. |
| Correction tests | Food correction requests include original image context. |
| Flutter photo tests | Request assembly, retry preservation, static loading button, and background result delivery pass. |
| Full Flutter tests | Existing app tests pass to protect mature non-AI behavior. |
| APK build | Debug split APK builds successfully with the configured Supabase local define file. |

## 11. What Should Not Be Changed As Part Of This Fix

These were intentionally out of scope:

1. Do not introduce `food_draft.v3` only to model every possible evidence state.
2. Do not add item-level `evidence_source`, `needs_confirmation`, or `conflict_reason` until the UI has a concrete display need.
3. Do not merge AI Chat and Add Food into one Edge Function merely for symmetry.
4. Do not weaken strict JSON/schema/date/numeric/item-total validation.
5. Do not allow AI to write official food records without user confirmation.
6. Do not expand cloud sync, vector memory, or Document RAG scope.
7. Do not persist image bytes or base64 in logs.
8. Do not regenerate Document RAG corpus unless explicitly requested after the documentation batch is stable.

## 12. Interview-Ready Narrative

The useful engineering story is not “we removed validation”. The story is:

1. We moved from a local/GPTs prompt experience to an app-native AI pipeline with Edge Functions, strict contracts, correction, logs, and UI preview.
2. Those additions were individually reasonable because a production app needs parseable drafts, server-managed keys, auth, quota, and safe confirmation boundaries.
3. The bug appeared because semantic food judgment accidentally migrated from model reasoning into backend hard gates.
4. In a consumer logging product, the correct invariant is not “every item must be visually proven”; it is “preserve user intent, expose uncertainty, and require user confirmation before saving.”
5. The debug strategy traced the full data path from Flutter image selection to provider payload, raw output, validation, correction, normalization, and final UI display.
6. The fix reduced only the overreaching semantic blockers while preserving the structural and safety constraints that make the app reliable.
7. Regression tests were added around the exact failure classes: text/image disagreement, correction image context, background lifecycle, and strict output parsing.

That is the main lesson: production AI reliability is not maximized by adding more rules everywhere. It is maximized by deciding which layer owns which responsibility.
