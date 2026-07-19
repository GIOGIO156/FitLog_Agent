import {
  assert,
  assertEquals,
  assertRejects,
  assertThrows,
} from "jsr:@std/assert@1";
import {
  OutputContractError,
  parseFoodAnalysisEnvelope,
  providerGatewayEnvelopeJsonSchemaForExpectedOutput,
} from "../_shared/ai_output_contract.ts";
import {
  explicitFoodFactsFromText,
  validateFoodSemantics,
} from "../_shared/food_capability.ts";
import {
  type GatewayExerciseReference,
  type GatewayRequest,
  parseGatewayRequest,
} from "./contracts.ts";
import { resolveExercise } from "./exercise/exercise_resolver.ts";
import { validateGroundedText } from "./grounding/faithfulness_guard.ts";
import { evaluateWriteClaim } from "./guarding/write_claim_guard.ts";
import { buildApprovedChatDecision } from "./planning/chat_decision.ts";
import {
  type ChatDecisionPlanningError,
  standardOption,
} from "./planning/chat_decision_contract.ts";
import { applyContextPolicy } from "./planning/context_policy.ts";
import type { TaskPlanV1 } from "./planning/task_plan_contract.ts";
import { ProviderError, providerForChoice } from "./providers.ts";
import { embedNormalizedQuery } from "./rag/query_embedding.ts";
import { normalizeRagQuery } from "./rag/query_normalizer.ts";
import { assessRetrievalCoverage } from "./rag/retrieval_coverage.ts";
import {
  fuseAndRerank,
  hasOwningDocumentCue,
} from "./rag/retrieval_reranker.ts";
import { retrieveWithSingleRetry } from "./rag/retrieval_retry.ts";
import type { RetrievalCandidate } from "./rag/types.ts";
import { routeGatewayWorkflow } from "./workflow_router.ts";

type FixtureCase = Record<string, unknown> & { case_id: string };
type Fixture = { suite: string; cases: FixtureCase[] };

for (
  const path of [
    "test/evals/fixtures/ai_chat_behavior_parity.v2.json",
    "test/evals/fixtures/task_planning.v1.json",
    "test/evals/fixtures/first_pass_reliability.v1.json",
    "test/evals/fixtures/document_retrieval.v1.json",
    "test/evals/fixtures/exercise_context.v1.json",
    "test/evals/fixtures/failure_retry.v1.json",
    "test/evals/fixtures/food_capability_regressions.v1.json",
    "test/evals/fixtures/grounded_output.v1.json",
    "test/evals/fixtures/provider_canary.v1.json",
    "test/evals/fixtures/provider_capability_parity.v1.json",
    "test/evals/fixtures/safety_privacy.v1.json",
    "test/evals/fixtures/structured_context.v1.json",
  ]
) {
  const fixture = JSON.parse(await Deno.readTextFile(path)) as Fixture;
  for (const testCase of fixture.cases) {
    Deno.test({
      name: `fixture:${fixture.suite}:${testCase.case_id}`,
      ignore: testCase.requires_external === true,
      fn: async () => {
        if (fixture.suite === "ai_chat_behavior_parity_v2") {
          await executeBehaviorParityCase(testCase);
        } else if (
          fixture.suite === "task_planning" ||
          fixture.suite === "first_pass_reliability"
        ) {
          await executeDecisionCase(testCase);
        } else {
          await executeSupportingCase(fixture.suite, testCase);
        }
      },
    });
  }
}

async function executeBehaviorParityCase(testCase: FixtureCase): Promise<void> {
  const input = String(testCase.input ?? "");
  if (testCase.case_id === "write_claim_storage_explanation_allowed") {
    assertEquals(evaluateWriteClaim(input).blocked, false);
    return;
  }
  if (testCase.case_id === "write_claim_completed_action_blocked") {
    assertEquals(evaluateWriteClaim(input).blocked, true);
    return;
  }
  const request = requestFor(testCase);
  if (testCase.case_id === "typed_answer_resume") {
    request.resolvedClarification = {
      clarificationId: "00000000-0000-4000-8000-000000000010",
      optionId: "answer",
      resultingOutput: "text",
      resultingWorkflow: "app_logic_answer",
      originMessageText: "锻炼快照保存在哪里？",
      attachmentPolicy: "none",
    };
    request.messageText = request.resolvedClarification.originMessageText;
  }
  if (testCase.case_id === "planner_unavailable_is_error") {
    const error = await assertRejects(
      () => buildApprovedChatDecision(request),
    ) as ChatDecisionPlanningError;
    assertEquals(error.code, "planner_unavailable");
    return;
  }
  const decision = await buildApprovedChatDecision(request);
  assertDecisionOracle(decision, testCase);
}

async function executeDecisionCase(testCase: FixtureCase): Promise<void> {
  const request = requestFor(testCase);
  const expectedWorkflow = String(
    testCase.expected_workflow ?? testCase.workflow ?? "auto",
  );
  const expectedOutput = String(
    testCase.expected_output ?? testCase.output ?? "text",
  );
  const decision = await buildApprovedChatDecision(
    request,
    async () => plannerDecision(testCase, expectedWorkflow, expectedOutput),
  );
  if (testCase.clarification_expected === true) {
    assertEquals(decision.requires_clarification, true);
  } else if (expectedWorkflow !== "auto") {
    assertEquals(decision.planned_workflow, expectedWorkflow);
  }
  if (testCase.clarification_expected !== true) {
    assertEquals(decision.selected_output_family, expectedOutput);
  }
  const expectedContexts = stringArray(
    testCase.expected_context ?? testCase.contexts,
  );
  for (const context of expectedContexts) {
    assert(
      decision.approved_context.includes(context as never),
      `${testCase.case_id}: missing approved context ${context}`,
    );
  }
  for (const context of stringArray(testCase.forbidden_contexts)) {
    assert(
      !decision.approved_context.includes(context as never),
      `${testCase.case_id}: forbidden context ${context}`,
    );
  }
  if (testCase.document_rag === true) {
    assert(decision.approved_context.includes("document_context"));
  }
  if (testCase.write_forbidden === true) {
    assertEquals(decision.capability, "safety_boundary");
  }
}

async function executeSupportingCase(
  suite: string,
  testCase: FixtureCase,
): Promise<void> {
  switch (suite) {
    case "document_retrieval":
      await executeDocumentRetrievalCase(testCase);
      return;
    case "exercise_context":
      executeExerciseCase(testCase);
      return;
    case "failure_retry":
      await executeFailureRetryCase(testCase);
      return;
    case "food_capability":
      executeFoodCapabilityCase(testCase);
      return;
    case "grounded_output":
      executeGroundedOutputCase(testCase);
      return;
    case "provider_canary":
      await executeProviderCanaryCase(testCase);
      return;
    case "provider_parity":
      executeProviderParityCase(testCase);
      return;
    case "safety_privacy":
      executeSafetyPrivacyCase(testCase);
      return;
    case "structured_context":
      await executeStructuredContextCase(testCase);
      return;
    default:
      throw new Error(`No fixture executor for ${suite}`);
  }
}

async function executeDocumentRetrievalCase(
  testCase: FixtureCase,
): Promise<void> {
  const query = normalizeRagQuery(String(testCase.query));
  if (testCase.expect_no_answer === true) {
    assertEquals(query.canonical_concepts, []);
    assertEquals(query.technical_identifiers, []);
    assertEquals(hasOwningDocumentCue(query), false);
    return;
  }
  const candidates = await localDocumentCandidates(query);
  const result = fuseAndRerank(candidates, query, 3);
  assertEquals(result.degraded, false);
  const topSources = result.candidates.map((candidate) => candidate.doc_path);
  assert(
    stringArray(testCase.expected_sources).some((source) =>
      topSources.includes(source)
    ),
    `${testCase.case_id}: ${topSources.join(", ")}`,
  );
  const coverage = assessRetrievalCoverage(query, result.candidates);
  assert(
    coverage.status === "complete" || coverage.status === "partial",
    `${testCase.case_id}: ${coverage.status}`,
  );
}

function executeExerciseCase(testCase: FixtureCase): void {
  const mention = String(testCase.mention ?? "");
  let custom: GatewayExerciseReference[] = [];
  if (testCase.case_id === "custom_per_side") {
    custom = [customExercise("custom_side_squat", mention, "per_side_reps")];
  } else if (testCase.case_id === "duplicate_custom") {
    custom = [
      customExercise("custom_duplicate_1", mention, "total_reps"),
      customExercise("custom_duplicate_2", mention, "total_reps"),
    ];
  }
  const result = resolveExercise(mention, custom);
  if (testCase.expected === "ambiguous") {
    assertEquals(result.status, "ambiguous");
    return;
  }
  if (testCase.expected === "missing") {
    assertEquals(result.status, "missing");
    return;
  }
  assertEquals(result.status, "resolved");
  if (result.status !== "resolved") return;
  if (typeof testCase.key === "string") {
    assertEquals(result.definition.key, testCase.key);
  }
  if (typeof testCase.reps_input_mode === "string") {
    assertEquals(
      result.definition.reps_input_mode,
      testCase.reps_input_mode,
    );
  }
  if (testCase.source === "custom") {
    assertEquals(result.definition.source, "custom");
  }
}

async function executeFailureRetryCase(testCase: FixtureCase): Promise<void> {
  if (testCase.case_id === "embedding") {
    const result = await embedNormalizedQuery(
      {
        endpoint: "https://example.test/embeddings",
        apiKey: "test",
        model: "test",
        timeoutMs: 250,
      },
      ["FitLog"],
      () => Promise.resolve(new Response("", { status: 503 })),
    );
    assertEquals(result, { vector: null, issue: "embedding_unavailable" });
    return;
  }
  if (testCase.case_id === "reranker") {
    const candidate = retrievalRow("Product promise");
    candidate.lexical_rank = Number.NaN;
    candidate.vector_rank = null;
    candidate.lexical_score = Number.NaN;
    const result = fuseAndRerank(
      [candidate],
      normalizeRagQuery("FitLog product promise"),
    );
    assertEquals(result.degraded, true);
    assertEquals(result.candidates.length, 1);
    return;
  }
  if (testCase.case_id === "permission_same") {
    const request = requestFor({
      case_id: "permission_same",
      input: "Review workout history",
      permission: false,
    });
    const plan = contextPlan("workout_logging", ["exercise_history"]);
    assertEquals(applyContextPolicy(plan, request).approved_context, []);
    assertEquals(
      applyContextPolicy(plan, request).rejected_context,
      ["exercise_history"],
    );
    return;
  }
  const resultSets = testCase.case_id === "first_complete"
    ? [[retrievalRow("per_side_reps 每侧次数")]]
    : testCase.case_id === "retry_success"
    ? [[], [retrievalRow("per_side_reps 每侧次数")]]
    : [[], []];
  const outcome = await retrieveWithSingleRetry({
    config: retrievalConfig(),
    rawQuery: testCase.case_id === "first_complete"
      ? "per_side_reps"
      : "每侧次数",
    retryEnabled: true,
    rewritePlanner: () =>
      Promise.resolve({
        action: "search_fitlog_docs" as const,
        arguments: {
          query_variants: ["per_side_reps"],
          required_concepts: ["per_side_reps"],
        },
      }),
    fetchImpl: retrievalFetchSequence(resultSets),
  });
  assertEquals(outcome.attempts, Number(testCase.searches));
  if (testCase.case_id === "first_complete") {
    assertEquals(outcome.retry_action, "not_needed");
  } else if (testCase.case_id === "retry_success") {
    assertEquals(outcome.coverage.status, "complete");
    assertEquals(outcome.retry_gain, true);
  } else {
    assertEquals(outcome.coverage.status, "insufficient");
    assertEquals(outcome.retry_gain, false);
  }
}

function executeFoodCapabilityCase(testCase: FixtureCase): void {
  if (testCase.case_id === "dedicated_revision") {
    assertThrows(
      () =>
        parseFoodAnalysisEnvelope(JSON.stringify({
          schema_version: "food_analysis_envelope.v1",
          needs_clarification: false,
          clarification_questions: [],
          draft: { invalid: true },
        })),
      OutputContractError,
    );
    return;
  }
  if (testCase.case_id === "provider_parity") {
    const schema = providerGatewayEnvelopeJsonSchemaForExpectedOutput(
      "food_draft",
    );
    const outputType = (schema.properties as Record<string, unknown>)
      .output_type as { enum: string[] };
    assertEquals(outputType.enum, ["food_draft", "clarification"]);
    return;
  }
  const language = testCase.language === "en" ? "en" : "zh";
  const draft = foodDraft(
    testCase.case_id === "zh_wrong_language" ? "Chicken rice" : "鸡胸米饭",
    testCase.case_id === "explicit_protein" ? 8.5 : 10,
    testCase.case_id === "zh_wrong_language"
      ? "Estimated from the image."
      : testCase.case_id === "label_tolerance"
      ? "Copied from package label; fiber and rounding explain the difference."
      : language === "zh"
      ? "根据输入估算。"
      : "Estimated.",
    testCase.case_id === "label_tolerance" ? 400 : 200,
  );
  const issues = validateFoodSemantics({
    draft,
    responseLanguage: language,
    understanding: typeof testCase.input === "string"
      ? explicitFoodFactsFromText(testCase.input)
      : undefined,
  });
  if (typeof testCase.expected_issue === "string") {
    assert(issues.some((issue) => issue.reason === testCase.expected_issue));
  } else {
    assertEquals(
      issues.some((issue) =>
        issue.reason === "macro_energy_mismatch_unexplained"
      ),
      false,
    );
  }
}

function executeGroundedOutputCase(testCase: FixtureCase): void {
  const request = groundingRequest();
  if (testCase.case_id === "fitlog_claim_valid") {
    request.phase5Context!.document_sources.push(documentEvidence({
      content: "每侧次数使用动作定义 per_side_reps exercise_definition。",
    }));
  } else if (testCase.case_id === "planned_current") {
    request.phase5Context!.document_sources.push(documentEvidence({
      content: "Planned design only.",
      status: "planned",
      authority: "planned",
    }));
  }
  const claim = testCase.case_id === "planned_current"
    ? "FitLog 的当前规则一定如此。"
    : String(testCase.claim ?? "");
  const issues = validateGroundedText(claim, request);
  if (typeof testCase.expected_issue === "string") {
    assertEquals(issues[0]?.reason, testCase.expected_issue);
  } else {
    assertEquals(issues, []);
  }
}

async function executeProviderCanaryCase(testCase: FixtureCase): Promise<void> {
  let fetchCalls = 0;
  const error = assertThrows(() =>
    providerForChoice(
      String(testCase.provider) === "qwen" ? "qwen" : "chatgpt",
      unavailableProviderConfig(),
      ((..._args: Parameters<typeof fetch>) => {
        fetchCalls += 1;
        return Promise.resolve(new Response("{}", { status: 200 }));
      }) as typeof fetch,
    ), ProviderError) as ProviderError;
  assertEquals(error.code, "provider_unavailable");
  assertEquals(fetchCalls, 0);
}

function executeProviderParityCase(testCase: FixtureCase): void {
  const openAi = providerForChoice("chatgpt", providerConfig());
  const qwen = providerForChoice("qwen", providerConfig());
  assertEquals(openAi.providerId, "openai");
  assertEquals(qwen.providerId, "qwen");
  const expected = testCase.capability === "food_draft" ? "food_draft" : "text";
  const schema = providerGatewayEnvelopeJsonSchemaForExpectedOutput(expected);
  assertEquals(schema.type, "object");
  if (testCase.case_id === "preference_isolation") {
    assert(openAi !== qwen);
  }
}

function executeSafetyPrivacyCase(testCase: FixtureCase): void {
  if (typeof testCase.input === "string") {
    const route = routeGatewayWorkflow(requestFor(testCase));
    assert(route.safety_flags.length > 0);
    return;
  }
  if (typeof testCase.client_field === "string") {
    const body = requestBody("Forged context");
    body[testCase.client_field] = {};
    assertThrows(() => parseGatewayRequest(body));
    return;
  }
  const serialized = JSON.stringify(requestFor({
    case_id: "no_secret_log",
    input: "safe",
  })).toLowerCase();
  for (const forbidden of stringArray(testCase.forbidden)) {
    assert(!serialized.includes(forbidden));
  }
}

async function executeStructuredContextCase(
  testCase: FixtureCase,
): Promise<void> {
  if (testCase.case_id === "history_off") {
    const request = requestFor({
      case_id: "history_off",
      input: "workout history",
      permission: false,
    });
    const result = applyContextPolicy(
      contextPlan("workout_logging", ["exercise_history"]),
      request,
    );
    assertEquals(result.approved_context, []);
    assertEquals(result.rejected_context, ["exercise_history"]);
    return;
  }
  const workflow = String(testCase.workflow);
  const input = workflow === "weekly_review"
    ? `复盘最近 ${testCase.days ?? 7} 天`
    : "今天还能吃什么";
  const request = requestFor({
    case_id: testCase.case_id,
    input,
    permission: testCase.permission,
  });
  const decision = await buildApprovedChatDecision(request);
  assertEquals(decision.planned_workflow, workflow);
  for (const context of stringArray(testCase.contexts)) {
    assert(decision.approved_context.includes(context as never));
  }
  for (const missing of stringArray(testCase.missing)) {
    assert(decision.rejected_context.includes(missing as never));
  }
}

function assertDecisionOracle(
  decision: Awaited<ReturnType<typeof buildApprovedChatDecision>>,
  testCase: FixtureCase,
): void {
  const expectedOutput = String(testCase.expected_output ?? "text");
  if (expectedOutput === "clarification") {
    assertEquals(decision.requires_clarification, true);
  } else {
    assertEquals(decision.planned_workflow, testCase.expected_workflow);
    assertEquals(decision.selected_output_family, expectedOutput);
  }
  for (const context of stringArray(testCase.expected_context)) {
    assert(decision.approved_context.includes(context as never));
  }
}

function requestFor(testCase: FixtureCase): GatewayRequest {
  const input = String(testCase.input ?? testCase.message ?? "Fixture input");
  const language = testCase.language === "en" || /[a-z]{4}/i.test(input)
    ? "en"
    : "zh";
  const imageCount = Number(testCase.image_count ?? 0);
  return parseGatewayRequest({
    session_id: null,
    message: { text: input },
    language,
    model_choice: "qwen",
    workflow_hint: "auto",
    device_id: "eval-fixture",
    allow_record_summary_context: testCase.permission !== false,
    attachments: Array.from({ length: imageCount }, () => ({
      kind: "image",
      mime_type: "image/png",
      base64_data: "YQ==",
      byte_length: 1,
    })),
    client: { draft_schema_version: "v3" },
  });
}

function plannerDecision(
  testCase: FixtureCase,
  expectedWorkflow: string,
  expectedOutput: string,
): Record<string, unknown> {
  const clarification = testCase.clarification_expected === true;
  const workflow = clarification ? "general_chat" : expectedWorkflow;
  const output = clarification ? "text" : expectedOutput;
  const requested = requestedContexts(testCase, workflow);
  const options = ["answer", "food_draft", "workout_draft"].map((id) =>
    standardOption(id as "answer" | "food_draft" | "workout_draft")
  ).filter((value) => value !== null);
  return {
    schema_version: "chat_decision.v2",
    capability: clarification
      ? "general_chat"
      : output === "food_draft"
      ? "food_draft"
      : output === "workout_draft"
      ? "workout_draft"
      : workflow === "app_logic_answer"
      ? "answer"
      : workflow,
    planned_workflow: workflow,
    allowed_output_families: clarification
      ? ["text", "food_draft", "workout_draft"]
      : [output],
    selected_output_family: output,
    requested_context: requested,
    retrieval_needs: requested,
    reasons: ["fixture_bounded_model_decision"],
    confidence: 0.9,
    requires_clarification: clarification,
    clarification: clarification
      ? {
        kind: "intent_selection",
        options,
        missing_dimensions: ["requested_output_family"],
        attachment_policy: "none",
      }
      : null,
  };
}

function requestedContexts(
  testCase: FixtureCase,
  workflow: string,
): string[] {
  const explicit = stringArray(testCase.contexts);
  if (explicit.length > 0) return explicit;
  if (testCase.document_rag === true || workflow === "app_logic_answer") {
    return ["document_context"];
  }
  if (workflow === "meal_decision") {
    return ["profile_context", "selected_day_summary", "strategy_context"];
  }
  if (workflow === "weekly_review") {
    return [
      "profile_context",
      "recent_food_summary",
      "recent_workout_summary",
      "body_metric_summary",
      "weight_trend_summary",
      "strategy_context",
    ];
  }
  if (workflow === "workout_logging") return ["exercise_definition"];
  return [];
}

function stringArray(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string")
    : [];
}

type CorpusChunk = {
  language: "zh" | "en";
  docPath: string;
  heading: string;
  headingPath: string[];
  sectionId: string;
  chunkIndex: number;
  chunkCount: number;
  content: string;
  contextPrefix: string;
  tags: string[];
  status: string;
  authority: string;
};

const corpusPromise = Deno.readTextFile(
  "tool/phase5_document_rag/document_corpus_build.v1.json",
).then((raw) => JSON.parse(raw) as { build_id: string; chunks: CorpusChunk[] });

async function localDocumentCandidates(
  query: ReturnType<typeof normalizeRagQuery>,
): Promise<RetrievalCandidate[]> {
  const corpus = await corpusPromise;
  const groups = new Map<string, CorpusChunk[]>();
  for (const chunk of corpus.chunks) {
    const key = `${chunk.language}:${chunk.docPath}`;
    groups.set(key, [...(groups.get(key) ?? []), chunk]);
  }
  const tokens = query.tokens.filter((token) => token.length >= 2);
  const ranked = [...groups.values()].map((chunks) => {
    const first = chunks[0];
    const content = chunks.map((chunk) => chunk.content).join("\n");
    const haystack = content.normalize("NFKC").toLocaleLowerCase();
    const hits = tokens.filter((token) => haystack.includes(token)).length;
    return { first, content, score: hits / Math.max(tokens.length, 1) };
  }).sort((left, right) =>
    right.score - left.score ||
    left.first.docPath.localeCompare(right.first.docPath)
  );
  return ranked.map(({ first, content, score }, index) => ({
    id: `${first.docPath}:${first.language}`,
    build_id: corpus.build_id,
    language: first.language,
    doc_path: first.docPath,
    heading: first.heading,
    heading_path: first.headingPath,
    section_id: first.sectionId,
    chunk_index: first.chunkIndex,
    chunk_count: first.chunkCount,
    content,
    context_prefix: first.contextPrefix,
    tags: first.tags,
    status: first.status,
    authority: first.authority,
    lexical_score: score,
    exact_score: 0,
    term_score: score,
    full_text_score: score,
    trigram_score: 0,
    vector_score: score,
    lexical_rank: index + 1,
    vector_rank: index + 1,
    matched_terms: [],
    matched_fields: ["content"],
  }));
}

function customExercise(
  key: string,
  name: string,
  repsInputMode: "total_reps" | "per_side_reps",
): GatewayExerciseReference {
  return {
    key,
    name,
    definitionHash: "12345678",
    exerciseType: "strength",
    bodyPart: "legs",
    strengthStructure: "bilateral",
    strengthProfile: "compound",
    loadInputMode: "total_load",
    repsInputMode,
    setMetricType: "reps",
  };
}

function retrievalConfig() {
  return {
    supabase: {
      supabaseUrl: "https://example.test",
      supabaseServiceRoleKey: "test",
    },
    embedding: null,
  };
}

function retrievalFetchSequence(resultSets: unknown[][]): typeof fetch {
  let index = 0;
  return (() =>
    Promise.resolve(
      new Response(JSON.stringify(resultSets[index++] ?? []), { status: 200 }),
    )) as typeof fetch;
}

function retrievalRow(content: string): RetrievalCandidate {
  return {
    id: crypto.randomUUID(),
    build_id: "eval",
    language: "zh",
    doc_path: "docs/zh/Algorithm.md",
    heading: "训练次数",
    heading_path: ["训练次数"],
    section_id: crypto.randomUUID(),
    chunk_index: 1,
    chunk_count: 1,
    content,
    context_prefix: "来源",
    tags: ["algorithm"],
    status: "implemented",
    authority: "current_product",
    lexical_score: 0.9,
    exact_score: 0,
    term_score: 0.9,
    full_text_score: 0,
    trigram_score: 0.8,
    vector_score: null,
    lexical_rank: 1,
    vector_rank: null,
    matched_terms: [],
    matched_fields: ["content"],
  };
}

function contextPlan(
  workflow: TaskPlanV1["planned_workflow"],
  contexts: TaskPlanV1["requested_context"],
): TaskPlanV1 {
  return {
    schema_version: "task_plan.v1",
    source: "deterministic",
    confidence: 1,
    original_workflow_hint: "auto",
    planned_workflow: workflow,
    expected_output: "text",
    entities: [],
    requested_context: contexts,
    retrieval_needs: contexts,
    approved_context: [],
    rejected_context: [],
    reasons: ["eval"],
    safety_flags: [],
    requires_clarification: false,
  };
}

function foodDraft(
  mealName: string,
  protein: number,
  notes: string,
  calories: number,
) {
  return {
    schema_version: "food_draft.v2" as const,
    date: "2026-07-19",
    meal_name: mealName,
    total_weight_g: 100,
    calories_kcal: calories,
    protein_g: protein,
    carbs_g: 10,
    fat_g: 2,
    confidence: 0.8,
    estimation_notes: notes,
    items: [],
  };
}

function groundingRequest(): GatewayRequest {
  const request = requestFor({
    case_id: "grounding",
    input: "FitLog 规则",
  });
  request.language = "zh";
  request.phase5Context = {
    route: {
      workflow: "app_logic_answer",
      confidence: 1,
      reasons: [],
      required_context: ["document_context"],
      safety_flags: [],
      read_only: true,
    },
    context_objects: [],
    document_sources: [],
    called_tools: [],
    retrieved_dimensions: [],
    missing_dimensions: [],
    safety_flags: [],
  };
  return request;
}

function documentEvidence({
  content,
  status = "implemented",
  authority = "current_product",
}: {
  content: string;
  status?: string;
  authority?: string;
}) {
  return {
    doc_path: "docs/zh/Algorithm.md",
    heading: "规则",
    heading_path: ["规则"],
    section_id: "eval-rule",
    chunk_index: 1,
    chunk_count: 1,
    status,
    authority,
    score: 1,
    context_prefix: "来源",
    context_note: null,
    excerpt: content,
  };
}

function providerConfig() {
  return {
    openAiApiKey: "test-openai-key",
    openAiModel: "test-openai-model",
    qwenApiKey: "test-qwen-key",
    qwenModel: "test-qwen-model",
    qwenBaseUrl:
      "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
    timeoutMs: 1000,
    allowMockProvider: false,
  };
}

function unavailableProviderConfig() {
  return {
    ...providerConfig(),
    openAiApiKey: "",
    openAiModel: "",
    qwenApiKey: "",
    qwenModel: "",
  };
}

function requestBody(text: string): Record<string, unknown> {
  return {
    session_id: null,
    message: { text },
    language: "en",
    model_choice: "qwen",
    workflow_hint: "auto",
    device_id: "eval-fixture",
    allow_record_summary_context: false,
    client: { draft_schema_version: "v3" },
  };
}
