import { retrieveFitLogDocuments } from "../../supabase/functions/ai-chat-route/rag/retrieval_pipeline.ts";
import { qwenEmbeddingEndpoint } from "../../supabase/functions/ai-chat-route/rag/query_embedding.ts";

type Json = Record<string, unknown>;
type CloudReport = {
  schema: string;
  label: string;
  target_project: string;
  expected_pipeline: string;
  active_build: Json | null;
  authority_counts: Record<string, number>;
  provider_checks: Json[];
  retrieval_summary: Json;
  edge_runtime_latency: Json;
  latency_diagnostic: Json;
  retrieval_cases: Json[];
  access_probes: Json[];
  transport_retries: number;
  checks: Json[];
  summary: { pass: number; fail: number };
};

const args = new Map<string, string>();
for (let index = 0; index < Deno.args.length; index += 2) {
  args.set(Deno.args[index], Deno.args[index + 1] ?? "");
}
const label = args.get("--label")?.trim() || "final";
const expectedPipeline = args.get("--expected-pipeline")?.trim() ||
  "rag_foundation_v1";
const diagnosticRepetitions = Math.max(
  1,
  Math.min(
    5,
    Number.parseInt(args.get("--diagnostic-repetitions") ?? "1", 10) || 1,
  ),
);
const requestedDiagnosticScenarios = new Set(
  (args.get("--diagnostic-scenarios") ?? "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean),
);
const requestedRetrievalRpc = args.get("--retrieval-rpc")?.trim();
const retrievalRpc = requestedRetrievalRpc ===
    "search_document_chunks_hybrid_v3"
  ? "search_document_chunks_hybrid_v3" as const
  : requestedRetrievalRpc === "search_document_chunks_hybrid_v2"
  ? "search_document_chunks_hybrid_v2" as const
  : "search_document_chunks_hybrid" as const;
const retrievalCandidateLimit = Math.min(
  Math.max(
    Number.parseInt(args.get("--retrieval-candidates") ?? "60", 10) || 60,
    12,
  ),
  60,
);
const canaryStartedAt = new Date().toISOString();
let transportRetryCount = 0;

await loadEnvFile("supabase/.env.local");
await loadEnvFile("supabase/.env.acceptance.local");

const supabaseUrl = requiredEnv("SUPABASE_URL").replace(/\/+$/, "");
const anonKey = requiredEnv("SUPABASE_ANON_KEY");
const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
const qwenApiKey = requiredEnv("FITLOG_QWEN_API_KEY");
const qwenBaseUrl = requiredEnv("FITLOG_QWEN_BASE_URL");
const embeddingModel = requiredEnv("FITLOG_DOCUMENT_EMBEDDING_MODEL");
const deviceId = `fitlog-rag-canary-${label}`.slice(0, 96);

const sessionA = await signIn(
  requiredEnv("USER_A_EMAIL"),
  requiredEnv("USER_A_PASSWORD"),
);
const sessionB = await signIn(
  requiredEnv("USER_B_EMAIL"),
  requiredEnv("USER_B_PASSWORD"),
);
await claimDevice(sessionA.accessToken, sessionA.sessionId, deviceId);

const checks: Json[] = [];
const providerChecks: Json[] = [];
const chat = await timedJson(`${supabaseUrl}/functions/v1/ai-chat-route`, {
  method: "POST",
  headers: userHeaders(sessionA.accessToken),
  body: JSON.stringify({
    session_id: null,
    message: { text: "Where is the workout exercise snapshot persisted?" },
    language: "en",
    model_choice: "qwen",
    workflow_hint: "auto",
    device_id: deviceId,
    allow_record_summary_context: false,
    client: { draft_schema_version: "v3" },
  }),
});
providerChecks.push(
  providerResult(
    "qwen_chat_database_auto",
    chat,
    databaseAnswerPassed,
  ),
);
if (expectedPipeline === "rag_foundation_v1") {
  for (
    const [check, text] of [
      ["qwen_chat_permission", "AI 能直接修改饮食目标吗？"],
      ["qwen_chat_rag_boundary", "Document RAG 会给用户记录做 embedding 吗？"],
    ]
  ) {
    const response = await timedJson(
      `${supabaseUrl}/functions/v1/ai-chat-route`,
      {
        method: "POST",
        headers: userHeaders(sessionA.accessToken),
        body: JSON.stringify({
          session_id: null,
          message: { text },
          language: "zh",
          model_choice: "qwen",
          workflow_hint: "auto",
          device_id: deviceId,
          allow_record_summary_context: false,
          client: { draft_schema_version: "v3" },
        }),
      },
    );
    providerChecks.push(
      providerResult(
        check,
        response,
        (body) =>
          body.error === null && body.model_provider === "qwen" &&
          body.workflow === "app_logic_answer" &&
          body.output_type === "text" &&
          body.needs_clarification === false &&
          typeof (body.message as Json | undefined)?.text === "string",
      ),
    );
  }
}

const allDiagnosticScenarios = [
  {
    scenario: "food_logging_no_document_rag",
    text: "记录鸡胸肉 200 克和米饭 150 克，生成食物草稿。",
    language: "zh",
    workflowHint: "food_logging",
  },
  {
    scenario: "workout_logging_no_document_rag",
    text: "记录深蹲 3 组，每组 10 次，100kg。",
    language: "zh",
    workflowHint: "workout_logging",
  },
  {
    scenario: "structured_meal_context_no_document_rag",
    text: "今天还能吃什么？",
    language: "zh",
    workflowHint: "meal_decision",
  },
  {
    scenario: "model_planner_no_document_rag",
    text: "帮我处理一下今天的安排。",
    language: "zh",
    workflowHint: "auto",
  },
  {
    scenario: "document_rag_zh",
    text: "保加利亚分腿蹲的每侧次数如何计算训练量？",
    language: "zh",
    workflowHint: "app_logic_answer",
  },
  {
    scenario: "document_rag_en",
    text: "Where is the workout exercise snapshot persisted?",
    language: "en",
    workflowHint: "app_logic_answer",
  },
  {
    scenario: "document_rag_mixed",
    text: "FitLog 的 Document RAG 会给 user records 做 embedding 吗？",
    language: "zh",
    workflowHint: "app_logic_answer",
  },
  {
    scenario: "document_rag_retry_probe",
    text: "FitLog 的 imaginary_latency_rule_9471 文档规则是什么？",
    language: "zh",
    workflowHint: "app_logic_answer",
  },
  {
    scenario: "document_rag_useful_retry_probe",
    text:
      "请简要说明 FitLog 中 energy_ratio、gram_per_kg、diet_goal_phase、carb_cycling、carb_tapering、Document RAG、Food Draft 和 Workout Draft 分别受什么规则约束。",
    language: "zh",
    workflowHint: "app_logic_answer",
  },
] as const;
const diagnosticScenarios = allDiagnosticScenarios.filter((scenario) =>
  requestedDiagnosticScenarios.size === 0
    ? scenario.scenario !== "document_rag_useful_retry_probe"
    : requestedDiagnosticScenarios.has(scenario.scenario)
);
const diagnosticCalls: Json[] = [];
await claimDevice(sessionA.accessToken, sessionA.sessionId, deviceId);
for (const scenario of diagnosticScenarios) {
  for (
    let repetition = 1;
    repetition <= diagnosticRepetitions;
    repetition += 1
  ) {
    const requestStartedAt = new Date().toISOString();
    const response = await timedJson(
      `${supabaseUrl}/functions/v1/ai-chat-route`,
      {
        method: "POST",
        headers: userHeaders(sessionA.accessToken),
        body: JSON.stringify({
          session_id: null,
          message: { text: scenario.text },
          language: scenario.language,
          model_choice: "qwen",
          workflow_hint: "auto",
          device_id: deviceId,
          selected_date: "2026-07-15",
          allow_record_summary_context: false,
          client: { draft_schema_version: "v3" },
        }),
      },
    );
    diagnosticCalls.push({
      scenario: scenario.scenario,
      repetition,
      http_status: response.status,
      gateway_error: (response.body.error as Json | null)?.code ?? null,
      external_latency_ms: response.latencyMs,
      session_id: response.body.session_id ?? null,
      request_started_at: requestStartedAt,
      request_finished_at: new Date().toISOString(),
    });
  }
}

await claimDevice(sessionA.accessToken, sessionA.sessionId, deviceId);
const foodText = await timedJson(
  `${supabaseUrl}/functions/v1/ai-food-photo-analyze`,
  {
    method: "POST",
    headers: userHeaders(sessionA.accessToken),
    body: JSON.stringify({
      images: [],
      language: "zh",
      model_choice: "qwen",
      device_id: deviceId,
      selected_date: "2026-07-15",
      schema_version: "food_draft.v2",
      user_note: "100g 三文鱼",
    }),
  },
);
providerChecks.push(
  providerResult(
    "qwen_food_text",
    foodText,
    (body) =>
      body.error === null && body.model_provider === "qwen" &&
      body.draft !== null && body.needs_clarification === false,
  ),
);

const imageBase64 = await syntheticPngBase64(256, 256);
const chatFoodImage = await timedJson(
  `${supabaseUrl}/functions/v1/ai-chat-route`,
  {
    method: "POST",
    headers: userHeaders(sessionA.accessToken),
    body: JSON.stringify({
      session_id: null,
      message: { text: "一锅武汉排骨藕汤，喝了三碗" },
      language: "zh",
      model_choice: "qwen",
      workflow_hint: "auto",
      device_id: deviceId,
      selected_date: "2026-07-15",
      allow_record_summary_context: false,
      attachments: [{
        kind: "image",
        mime_type: "image/png",
        base64_data: imageBase64,
        byte_length: Uint8Array.from(atob(imageBase64), (value) =>
          value.charCodeAt(0)).length,
      }],
      client: { draft_schema_version: "v3" },
    }),
  },
);
providerChecks.push(
  providerResult(
    "qwen_chat_food_image_auto",
    chatFoodImage,
    (body) =>
      body.error === null && body.model_provider === "qwen" &&
      body.workflow === "food_logging" && body.output_type === "food_draft" &&
      body.draft !== null && body.needs_clarification === false,
  ),
);

const clarificationOriginRequestId =
  `canary_clarification_origin_${label}_${Date.now()}`;
const clarificationReplyRequestId =
  `canary_clarification_reply_${label}_${Date.now()}`;
const clarificationOrigin = await timedJson(
  `${supabaseUrl}/functions/v1/ai-chat-route`,
  {
    method: "POST",
    headers: userHeaders(sessionA.accessToken),
    body: JSON.stringify({
      session_id: null,
      message: {
        text:
          "请记录保加利亚分腿蹲80kg 3组每侧10次，这个动作的每侧次数如何计算训练量？",
      },
      language: "zh",
      model_choice: "qwen",
      workflow_hint: "auto",
      device_id: deviceId,
      client_request_id: clarificationOriginRequestId,
      allow_record_summary_context: false,
      client: { draft_schema_version: "v3" },
    }),
  },
);
providerChecks.push(
  providerResult(
    "qwen_chat_typed_clarification_created",
    clarificationOrigin,
    (body) => {
      const clarification = body.clarification as Json | null;
      const options = Array.isArray(clarification?.options)
        ? clarification.options as Json[]
        : [];
      return body.error === null && body.needs_clarification === true &&
        clarification?.schema_version === "ai_chat_clarification.v2" &&
        clarification?.kind === "intent_selection" &&
        typeof clarification?.clarification_id === "string" &&
        options.some((option) => option.id === "answer") &&
        options.some((option) => option.id === "workout_draft");
    },
  ),
);

const originClarification = clarificationOrigin.body.clarification as
  | Json
  | null;
const clarificationId = typeof originClarification?.clarification_id ===
    "string"
  ? originClarification.clarification_id
  : "";
const clarificationSessionId = typeof clarificationOrigin.body.session_id ===
    "string"
  ? clarificationOrigin.body.session_id
  : "";
const clarificationReplyBody = {
  session_id: clarificationSessionId,
  message: { text: "回答问题" },
  language: "zh",
  model_choice: "qwen",
  workflow_hint: "auto",
  device_id: deviceId,
  client_request_id: clarificationReplyRequestId,
  clarification_reply: {
    clarification_id: clarificationId,
    option_id: "answer",
  },
  allow_record_summary_context: false,
  client: { draft_schema_version: "v3" },
};
const clarificationReply = clarificationId === "" ||
    clarificationSessionId === ""
  ? failedSyntheticResponse("clarification_origin_invalid")
  : await timedJson(`${supabaseUrl}/functions/v1/ai-chat-route`, {
    method: "POST",
    headers: userHeaders(sessionA.accessToken),
    body: JSON.stringify(clarificationReplyBody),
  });
providerChecks.push(
  providerResult(
    "qwen_chat_typed_clarification_consumed",
    clarificationReply,
    (body) =>
      body.error === null && body.workflow === "app_logic_answer" &&
      body.output_type === "text" && body.needs_clarification === false &&
      typeof body.assistant_message_id === "string",
  ),
);
const clarificationReplay = clarificationId === "" ||
    clarificationSessionId === ""
  ? failedSyntheticResponse("clarification_origin_invalid")
  : await timedJson(`${supabaseUrl}/functions/v1/ai-chat-route`, {
    method: "POST",
    headers: userHeaders(sessionA.accessToken),
    body: JSON.stringify(clarificationReplyBody),
  });
providerChecks.push({
  check: "qwen_chat_typed_clarification_replay_idempotent",
  status: clarificationReplay.ok && clarificationReply.ok &&
      clarificationReplay.body.assistant_message_id ===
        clarificationReply.body.assistant_message_id &&
      clarificationReplay.body.debug_summary_id ===
        clarificationReply.body.debug_summary_id
    ? "pass"
    : "fail",
  http_status: clarificationReplay.status,
  latency_ms: clarificationReplay.latencyMs,
  gateway_error: (clarificationReplay.body.error as Json | null)?.code ?? null,
  observed: {
    same_assistant_message: clarificationReplay.body.assistant_message_id ===
      clarificationReply.body.assistant_message_id,
    same_debug_summary: clarificationReplay.body.debug_summary_id ===
      clarificationReply.body.debug_summary_id,
  },
});
const clarificationStateResponse = clarificationId === ""
  ? failedSyntheticResponse("clarification_origin_invalid")
  : await timedJson(
    `${supabaseUrl}/rest/v1/ai_chat_clarifications?select=state,attempt_count,resolved_option_id,resolution_request_id&id=eq.${clarificationId}`,
    { headers: serviceHeaders() },
  );
const clarificationRows = Array.isArray(clarificationStateResponse.body)
  ? clarificationStateResponse.body as Json[]
  : [];
providerChecks.push({
  check: "qwen_chat_typed_clarification_state_resolved_once",
  status: clarificationStateResponse.ok && clarificationRows.length === 1 &&
      clarificationRows[0].state === "resolved" &&
      clarificationRows[0].attempt_count === 1 &&
      clarificationRows[0].resolved_option_id === "answer" &&
      clarificationRows[0].resolution_request_id === clarificationReplyRequestId
    ? "pass"
    : "fail",
  http_status: clarificationStateResponse.status,
  latency_ms: clarificationStateResponse.latencyMs,
  gateway_error: null,
  observed: clarificationRows[0] ?? null,
});

const foodImage = await timedJson(
  `${supabaseUrl}/functions/v1/ai-food-photo-analyze`,
  {
    method: "POST",
    headers: userHeaders(sessionA.accessToken),
    body: JSON.stringify({
      images: [{
        mime_type: "image/png",
        base64_data: imageBase64,
        byte_length: Uint8Array.from(atob(imageBase64), (value) =>
          value.charCodeAt(0)).length,
      }],
      language: "zh",
      model_choice: "qwen",
      device_id: deviceId,
      selected_date: "2026-07-15",
      schema_version: "food_draft.v2",
      user_note: "这是合成 canary 占位图；仅按文字生成 100g 香蕉食物草稿。",
    }),
  },
);
providerChecks.push(
  providerResult(
    "qwen_food_image",
    foodImage,
    (body) =>
      body.error === null && body.model_provider === "qwen" &&
      body.draft !== null && body.needs_clarification === false,
  ),
);

const retrievalFixture = JSON.parse(
  await Deno.readTextFile("test/evals/fixtures/document_retrieval.v1.json"),
) as {
  cases: Array<
    {
      case_id: string;
      language: string;
      query: string;
      expected_sources: string[];
      relevant_sources?: string[];
      expect_no_answer?: boolean;
    }
  >;
};
const retrievalCases: Json[] = [];
for (const testCase of retrievalFixture.cases) {
  const startedAt = performance.now();
  const result = await retrieveFitLogDocuments(
    {
      supabase: { supabaseUrl, supabaseServiceRoleKey: serviceRoleKey },
      embedding: {
        endpoint: qwenEmbeddingEndpoint(qwenBaseUrl),
        apiKey: qwenApiKey,
        model: embeddingModel,
        timeoutMs: 5000,
      },
      rpcName: retrievalRpc,
      candidateLimit: retrievalCandidateLimit,
    },
    testCase.query,
    retryingFetch,
  );
  const top3 = result.candidates.slice(0, 3);
  const top3Sources = top3.map((candidate) => candidate.doc_path);
  const hit = testCase.expect_no_answer === true
    ? top3.length === 0
    : testCase.expected_sources.some((source) => top3Sources.includes(source));
  retrievalCases.push({
    case_id: testCase.case_id,
    language: testCase.language,
    status: hit ? "pass" : "fail",
    expected_sources: testCase.expected_sources,
    relevant_sources: testCase.relevant_sources ?? testCase.expected_sources,
    top3_sources: top3Sources,
    top1_source: top3Sources[0] ?? null,
    embedding_issue: result.debug.issues.includes("embedding_unavailable"),
    vector_branch_hits: result.debug.branch_hits.vector,
    latency_ms: Math.round(performance.now() - startedAt),
    latency_breakdown: result.debug.latency,
  });
}

const answerable = retrievalCases.filter((item) =>
  Array.isArray(item.expected_sources) && item.expected_sources.length > 0
);
const hitCount = answerable.filter((item) => item.status === "pass").length;
const relevantTop3 = answerable.reduce(
  (sum, item) =>
    sum +
    (item.top3_sources as string[]).filter((source) =>
      (item.relevant_sources as string[]).includes(source)
    ).length,
  0,
);
const returnedTop3 = answerable.reduce(
  (sum, item) => sum + (item.top3_sources as string[]).length,
  0,
);
const criticalIds = new Set([
  "product_zh",
  "product_en",
  "algorithm_per_side",
  "agent_permission",
  "rag_boundary",
]);
const critical = retrievalCases.filter((item) =>
  criticalIds.has(String(item.case_id))
);
const criticalTop1 =
  critical.filter((item) =>
    (item.expected_sources as string[]).includes(String(item.top1_source))
  ).length;
const retrievalSummary = {
  answerable_cases: answerable.length,
  source_recall_at_3: ratio(hitCount, answerable.length),
  source_hit_at_3: `${hitCount}/${answerable.length}`,
  source_precision_at_3: ratio(relevantTop3, returnedTop3),
  source_precision_count: `${relevantTop3}/${returnedTop3}`,
  critical_top1: ratio(criticalTop1, critical.length),
  critical_top1_count: `${criticalTop1}/${critical.length}`,
  embedding_fallbacks:
    retrievalCases.filter((item) => item.embedding_issue === true).length,
  p50_ms: percentile(
    retrievalCases.map((item) => Number(item.latency_ms)),
    0.5,
  ),
  p95_ms: percentile(
    retrievalCases.map((item) => Number(item.latency_ms)),
    0.95,
  ),
  stage_latency_ms: {
    normalization: stats(
      retrievalCases.map((item) =>
        Number((item.latency_breakdown as Json).normalization_ms)
      ),
    ),
    embedding: stats(
      retrievalCases.map((item) =>
        Number((item.latency_breakdown as Json).embedding_ms)
      ),
    ),
    hybrid_rpc: stats(
      retrievalCases.map((item) =>
        Number((item.latency_breakdown as Json).hybrid_rpc_ms)
      ),
    ),
    reranker: stats(
      retrievalCases.map((item) =>
        Number((item.latency_breakdown as Json).reranker_ms)
      ),
    ),
  },
};

const edgeLogQuery = new URL(`${supabaseUrl}/rest/v1/ai_request_logs`);
edgeLogQuery.searchParams.set(
  "select",
  "created_at,session_id,status,error_code,latency_ms,workflow_type,expected_output,selected_output_type,planned_workflow,task_plan_source,target_response_language,query_language_profile,retrieval_latency_ms,planner_latency_ms,correction_latency_ms,retrieval_retry_count,retrieval_retry_gain,retrieval_coverage_status,retrieval_issue_codes_json,validation_issue_codes_json,semantic_issue_codes_json,grounding_issue_codes_json,first_pass_validation_status,correction_attempt_count,final_validation_status,latency_breakdown_json,prompt_context_bytes,corpus_build_id,embedding_model,reranker_version,decision_version,decision_source,decision_reason,decision_shadow_mismatch,selected_capability,clarification_id,clarification_state,clarification_attempt,attachment_policy,failure_class,write_guard_reason",
);
edgeLogQuery.searchParams.set("account_id", `eq.${sessionA.userId}`);
edgeLogQuery.searchParams.set("surface", "eq.ai_chat");
edgeLogQuery.searchParams.set("created_at", `gte.${canaryStartedAt}`);
edgeLogQuery.searchParams.set("order", "created_at.asc");
const edgeLogRows = await restJson(
  edgeLogQuery.toString(),
  serviceHeaders(),
) as Json[];
const edgeRetrievalLatencies = edgeLogRows
  .map((row) => Number(row.retrieval_latency_ms))
  .filter(Number.isFinite);
const edgeRuntimeLatency = {
  sample_count: edgeRetrievalLatencies.length,
  p50_ms: percentile(edgeRetrievalLatencies, 0.5),
  p95_ms: percentile(edgeRetrievalLatencies, 0.95),
  max_ms: edgeRetrievalLatencies.length === 0
    ? null
    : Math.max(...edgeRetrievalLatencies),
  corpus_build_ids: [
    ...new Set(edgeLogRows.map((row) => row.corpus_build_id).filter(Boolean)),
  ],
  embedding_models: [
    ...new Set(edgeLogRows.map((row) => row.embedding_model).filter(Boolean)),
  ],
  reranker_versions: [
    ...new Set(edgeLogRows.map((row) => row.reranker_version).filter(Boolean)),
  ],
  issue_codes: [
    ...new Set(
      edgeLogRows.flatMap((row) =>
        Array.isArray(row.retrieval_issue_codes_json)
          ? row.retrieval_issue_codes_json
          : []
      ),
    ),
  ],
  samples: edgeLogRows.flatMap((row) => {
    const latency = Number(row.retrieval_latency_ms);
    if (!Number.isFinite(latency) || latency <= 0) return [];
    const breakdown = row.latency_breakdown_json as Json | undefined;
    return [{
      workflow: row.workflow_type,
      language: row.target_response_language,
      retrieval_ms: latency,
      embedding_ms: breakdown?.initial_embedding_ms ?? null,
      lexical_candidate_rpc_ms: breakdown?.initial_lexical_candidate_rpc_ms ??
        null,
      hybrid_rpc_ms: breakdown?.initial_hybrid_rpc_ms ?? null,
      reranker_ms: breakdown?.initial_reranker_ms ?? null,
      coverage: row.retrieval_coverage_status,
      retry_count: row.retrieval_retry_count,
      prompt_context_bytes: row.prompt_context_bytes,
    }];
  }),
};
const latencyDiagnostic = buildLatencyDiagnostic(diagnosticCalls, edgeLogRows);

const activeBuild = await restJson(
  `${supabaseUrl}/rest/v1/document_corpus_builds?select=corpus_id,build_id,state,manifest_hash,generator_version,term_version,embedding_model,embedding_dimension,expected_source_count,expected_chunk_count,activated_at&corpus_id=eq.fitlog_user_stable_docs&state=eq.active&limit=1`,
  serviceHeaders(),
);
const authorityRows = await restJson(
  `${supabaseUrl}/rest/v1/document_chunks?select=authority,build_id&corpus_id=eq.fitlog_user_stable_docs&build_id=eq.${
    encodeURIComponent(String((activeBuild as Json[])[0]?.build_id ?? ""))
  }`,
  serviceHeaders({ Prefer: "count=exact" }),
);
const authorityCounts: Record<string, number> = {};
for (const row of authorityRows as Json[]) {
  const authority = String(row.authority);
  authorityCounts[authority] = (authorityCounts[authority] ?? 0) + 1;
}

const accessProbes = [];
for (
  const [name, token] of [["anon", null], ["user_a", sessionA.accessToken], [
    "user_b",
    sessionB.accessToken,
  ]] as const
) {
  const readProbe = await rawFetch(
    `${supabaseUrl}/rest/v1/document_chunks?select=id&limit=1`,
    { headers: token === null ? anonHeaders() : userHeaders(token) },
  );
  accessProbes.push({
    principal: name,
    operation: "document_chunks_read",
    status: deniedWithoutRows(readProbe) ? "pass" : "fail",
    http_status: readProbe.status,
  });
  const rpcProbe = await rawFetch(
    `${supabaseUrl}/rest/v1/rpc/begin_document_corpus_build`,
    {
      method: "POST",
      headers: token === null ? anonHeaders() : userHeaders(token),
      body: JSON.stringify({
        input_corpus_id: "permission-probe",
        input_build_id: "permission-probe",
        input_manifest_hash: "permission-probe",
        input_generator_version: "permission-probe",
        input_term_version: "permission-probe",
        input_expected_source_count: 0,
        input_expected_chunk_count: 0,
      }),
    },
  );
  accessProbes.push({
    principal: name,
    operation: "corpus_admin_rpc",
    status: rpcProbe.status >= 400 ? "pass" : "fail",
    http_status: rpcProbe.status,
  });
}

checks.push(...providerChecks, ...accessProbes);
checks.push({
  check: "active_corpus_metadata",
  status: Array.isArray(activeBuild) && activeBuild.length === 1 &&
      (activeBuild[0] as Json).embedding_model === embeddingModel &&
      (activeBuild[0] as Json).embedding_dimension === 1536 &&
      Object.values(authorityCounts).reduce((sum, value) => sum + value, 0) ===
        Number((activeBuild[0] as Json).expected_chunk_count)
    ? "pass"
    : "fail",
});
checks.push({
  check: "document_source_recall_at_3",
  status: retrievalSummary.source_recall_at_3 >= 0.97 ? "pass" : "fail",
  observed: retrievalSummary.source_recall_at_3,
  gate: 0.97,
});
checks.push({
  check: "document_source_precision_at_3",
  status: retrievalSummary.source_precision_at_3 >= 0.85 ? "pass" : "fail",
  observed: retrievalSummary.source_precision_at_3,
  gate: 0.85,
});
checks.push({
  check: "critical_source_top1",
  status: retrievalSummary.critical_top1 >= 0.95 ? "pass" : "fail",
  observed: retrievalSummary.critical_top1,
  gate: 0.95,
});
checks.push({
  check: "edge_embedding_hybrid_latency_p95",
  status: expectedPipeline === "phase5_legacy" ||
      (edgeRuntimeLatency.sample_count >= 3 &&
        edgeRuntimeLatency.p95_ms <= 1500)
    ? "pass"
    : "fail",
  observed_ms: edgeRuntimeLatency.p95_ms,
  sample_count: edgeRuntimeLatency.sample_count,
  gate_ms: 1500,
});
checks.push({
  check: "query_embedding_available",
  status: edgeRuntimeLatency.sample_count >= 3 &&
      !edgeRuntimeLatency.issue_codes.includes("embedding_unavailable")
    ? "pass"
    : "fail",
  edge_issue_codes: edgeRuntimeLatency.issue_codes,
  direct_runner_fallbacks: retrievalSummary.embedding_fallbacks,
});
const noAnswerFailures =
  retrievalCases.filter((item) =>
    item.case_id === "no_answer_weather" && item.status !== "pass"
  ).length;
checks.push({
  check: "no_answer_fabricated_source",
  status: noAnswerFailures === 0 ? "pass" : "fail",
  observed_failures: noAnswerFailures,
});
checks.push({
  check: "edge_pipeline_evidence",
  status: expectedPipeline === "phase5_legacy" || (
      edgeRuntimeLatency.corpus_build_ids.includes(
        String((activeBuild as Json[])[0]?.build_id ?? ""),
      ) &&
      edgeRuntimeLatency.embedding_models.includes(embeddingModel) &&
      edgeRuntimeLatency.reranker_versions.includes(
        "fitlog_document_reranker.v2",
      )
    )
    ? "pass"
    : "fail",
  expected_pipeline: expectedPipeline,
});
if (diagnosticCalls.length > 0) {
  const diagnosticReliability = latencyDiagnostic
    .first_pass_reliability as Json;
  const scenarioStats = latencyDiagnostic.scenario_stats as Record<
    string,
    Json
  >;
  const logged = Number(diagnosticReliability.logged_count);
  checks.push({
    check: "diagnostic_logs_complete",
    status:
      Number(latencyDiagnostic.matched_log_count) === diagnosticCalls.length
        ? "pass"
        : "fail",
    matched: latencyDiagnostic.matched_log_count,
    expected: diagnosticCalls.length,
  });
  checks.push({
    check: "diagnostic_http_success",
    status: diagnosticCalls.every((call) => Number(call.http_status) < 400)
      ? "pass"
      : "fail",
    failures: diagnosticCalls.filter((call) => Number(call.http_status) >= 400)
      .length,
  });
  checks.push({
    check: "diagnostic_first_pass_valid",
    status: Number(diagnosticReliability.first_pass_validation_pass_count) ===
        logged
      ? "pass"
      : "fail",
    passed: diagnosticReliability.first_pass_validation_pass_count,
    logged,
  });
  checks.push({
    check: "diagnostic_no_correction_or_final_failure",
    status: Number(diagnosticReliability.correction_trigger_count) === 0 &&
        Number(diagnosticReliability.final_validation_failure_count) === 0
      ? "pass"
      : "fail",
    corrections: diagnosticReliability.correction_trigger_count,
    final_failures: diagnosticReliability.final_validation_failure_count,
  });
  checks.push({
    check: "diagnostic_no_gain_retry_absent",
    status: Number(diagnosticReliability.retry_no_gain_count) === 0
      ? "pass"
      : "fail",
    observed: diagnosticReliability.retry_no_gain_count,
  });
  for (
    const scenario of [
      "document_rag_zh",
      "document_rag_en",
      "document_rag_mixed",
    ]
  ) {
    const value = scenarioStats[scenario];
    if (value === undefined) continue;
    const reliability = value.first_pass_reliability as Json;
    checks.push({
      check: `${scenario}_first_retrieval_complete`,
      status: Number(reliability.first_retrieval_complete_count) ===
          Number(reliability.document_request_count)
        ? "pass"
        : "fail",
      complete: reliability.first_retrieval_complete_count,
      requests: reliability.document_request_count,
    });
  }
  const retryProbe = scenarioStats.document_rag_retry_probe;
  if (retryProbe !== undefined) {
    checks.push({
      check: "unsupported_identifier_retry_stopped",
      status: Number(retryProbe.retry_count) === 0 ? "pass" : "fail",
      retries: retryProbe.retry_count,
    });
  }
  const usefulRetryProbe = scenarioStats.document_rag_useful_retry_probe;
  if (usefulRetryProbe !== undefined) {
    const reliability = usefulRetryProbe.first_pass_reliability as Json;
    const retryCount = Number(reliability.retry_trigger_count);
    const retryGainCount = Number(reliability.retry_gain_count);
    checks.push({
      check: "useful_retry_probe_triggered_with_gain",
      status: retryCount > 0 && retryGainCount === retryCount ? "pass" : "fail",
      retries: retryCount,
      gains: retryGainCount,
    });
  }
}

const failed = checks.filter((check) => check.status !== "pass");
const report: CloudReport = {
  schema: "fitlog_cloud_rag_canary.v1",
  label,
  target_project: new URL(supabaseUrl).hostname.split(".")[0],
  expected_pipeline: expectedPipeline,
  active_build: (activeBuild as Json[])[0] ?? null,
  authority_counts: authorityCounts,
  provider_checks: providerChecks,
  retrieval_summary: retrievalSummary,
  edge_runtime_latency: edgeRuntimeLatency,
  latency_diagnostic: latencyDiagnostic,
  retrieval_cases: retrievalCases,
  access_probes: accessProbes,
  transport_retries: transportRetryCount,
  checks,
  summary: { pass: checks.length - failed.length, fail: failed.length },
};
await Deno.mkdir("test/evals/reports", { recursive: true });
const reportBase = `test/evals/reports/rag_foundation_cloud_${label}.v1`;
await Deno.writeTextFile(
  `${reportBase}.json`,
  `${JSON.stringify(report, null, 2)}\n`,
);
await Deno.writeTextFile(`${reportBase}.md`, markdownReport(report));
console.log(JSON.stringify({
  label,
  summary: report.summary,
  provider_checks: providerChecks.map((item) => ({
    check: item.check,
    status: item.status,
    latency_ms: item.latency_ms,
  })),
  retrieval_summary: retrievalSummary,
  active_build_id: (activeBuild as Json[])[0]?.build_id ?? null,
}));
if (failed.length > 0) Deno.exitCode = 1;

async function loadEnvFile(path: string): Promise<void> {
  const content = await Deno.readTextFile(path);
  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (line === "" || line.startsWith("#")) continue;
    const separator = line.indexOf("=");
    if (separator < 1) continue;
    const key = line.slice(0, separator).trim();
    if (Deno.env.get(key) !== undefined) continue;
    let value = line.slice(separator + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) value = value.slice(1, -1);
    Deno.env.set(key, value);
  }
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

async function signIn(email: string, password: string) {
  const response = await timedJson(
    `${supabaseUrl}/auth/v1/token?grant_type=password`,
    {
      method: "POST",
      headers: { apikey: anonKey, "content-type": "application/json" },
      body: JSON.stringify({ email, password }),
    },
  );
  if (!response.ok || typeof response.body.access_token !== "string") {
    throw new Error(`acceptance sign-in failed (${response.status})`);
  }
  const accessToken = response.body.access_token;
  const payload = JSON.parse(
    new TextDecoder().decode(Uint8Array.from(
      atob(accessToken.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")),
      (value) => value.charCodeAt(0),
    )),
  );
  const sessionId = String(
    payload.session_id ?? payload.sid ?? payload.jti ?? "",
  );
  if (sessionId === "") {
    throw new Error("acceptance token has no session identifier");
  }
  const userId = String(payload.sub ?? "");
  if (userId === "") {
    throw new Error("acceptance token has no account identifier");
  }
  return { accessToken, sessionId, userId };
}

async function claimDevice(
  accessToken: string,
  sessionId: string,
  claimDeviceId: string,
) {
  const response = await timedJson(
    `${supabaseUrl}/rest/v1/rpc/claim_active_device`,
    {
      method: "POST",
      headers: userHeaders(accessToken),
      body: JSON.stringify({
        input_device_id: claimDeviceId,
        input_session_id: sessionId,
        input_platform: "canary",
        input_app_version: "rag_foundation_v1",
      }),
    },
  );
  if (!response.ok || response.body.ok !== true) {
    throw new Error(`active device claim failed (${response.status})`);
  }
}

function anonHeaders(extra: Record<string, string> = {}) {
  return { apikey: anonKey, "content-type": "application/json", ...extra };
}

function userHeaders(accessToken: string, extra: Record<string, string> = {}) {
  return {
    apikey: anonKey,
    authorization: `Bearer ${accessToken}`,
    "content-type": "application/json",
    ...extra,
  };
}

function serviceHeaders(extra: Record<string, string> = {}) {
  return {
    apikey: serviceRoleKey,
    authorization: `Bearer ${serviceRoleKey}`,
    "content-type": "application/json",
    ...extra,
  };
}

async function timedJson(url: string, init: RequestInit) {
  const startedAt = performance.now();
  const response = await retryingFetch(url, init);
  const body = await response.json().catch(() => ({})) as Json;
  return {
    ok: response.ok,
    status: response.status,
    body,
    latencyMs: Math.round(performance.now() - startedAt),
  };
}

function failedSyntheticResponse(code: string): {
  ok: boolean;
  status: number;
  body: Json;
  latencyMs: number;
} {
  return {
    ok: false,
    status: 0,
    body: { error: { code } },
    latencyMs: 0,
  };
}

async function rawFetch(url: string, init: RequestInit) {
  const response = await retryingFetch(url, init);
  const body = await response.text();
  return { status: response.status, body };
}

async function restJson(url: string, headers: Record<string, string>) {
  const response = await retryingFetch(url, { headers });
  if (!response.ok) {
    throw new Error(`REST verification failed (${response.status})`);
  }
  return await response.json();
}

async function retryingFetch(
  input: string | URL | Request,
  init?: RequestInit,
): Promise<Response> {
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      return await fetch(input, init);
    } catch (error) {
      if (attempt === 3 || !isConnectTransportError(error)) throw error;
      transportRetryCount += 1;
      await new Promise((resolve) => setTimeout(resolve, attempt * 250));
    }
  }
  throw new Error("unreachable transport retry state");
}

function isConnectTransportError(error: unknown): boolean {
  if (!(error instanceof TypeError)) return false;
  const cause = error.cause instanceof Error
    ? `${error.cause.message} ${String(error.cause.cause ?? "")}`
    : String(error.cause ?? "");
  return /tls handshake|client error \(Connect\)|connection reset/i.test(cause);
}

function deniedWithoutRows(
  response: { status: number; body: string },
): boolean {
  if (response.status >= 400) return true;
  try {
    const body = JSON.parse(response.body);
    return Array.isArray(body) && body.length === 0;
  } catch {
    return false;
  }
}

function providerResult(
  check: string,
  response: { ok: boolean; status: number; body: Json; latencyMs: number },
  predicate: (body: Json) => boolean,
) {
  const clarification = response.body.clarification as Json | null;
  const draft = response.body.draft as Json | null;
  const evidence = response.body.evidence as Json | null;
  const sources = Array.isArray(evidence?.document_sources)
    ? evidence.document_sources as Json[]
    : [];
  return {
    check,
    status: response.ok && predicate(response.body) ? "pass" : "fail",
    http_status: response.status,
    latency_ms: response.latencyMs,
    gateway_error: (response.body.error as Json | null)?.code ?? null,
    observed: {
      workflow: response.body.workflow ?? null,
      output_type: response.body.output_type ?? null,
      needs_clarification: response.body.needs_clarification ?? null,
      clarification_kind: clarification?.kind ?? null,
      attachment_policy: clarification?.attachment_policy ?? null,
      draft_schema: draft?.schema_version ?? null,
      evidence_docs: sources.map((source) => source.doc_path).filter((value) =>
        typeof value === "string"
      ).slice(0, 5),
    },
  };
}

function databaseAnswerPassed(body: Json): boolean {
  const text = String((body.message as Json | undefined)?.text ?? "")
    .toLowerCase();
  const evidence = body.evidence as Json | null;
  const sources = Array.isArray(evidence?.document_sources)
    ? evidence.document_sources as Json[]
    : [];
  const safetyFlags = Array.isArray(evidence?.safety_flags)
    ? evidence.safety_flags.map(String)
    : [];
  return body.error === null && body.model_provider === "qwen" &&
    body.workflow === "app_logic_answer" && body.output_type === "text" &&
    body.needs_clarification === false &&
    /workout_(?:records|sessions|sets)/.test(text) &&
    sources.some((source) => /database\.md$/i.test(String(source.doc_path))) &&
    !safetyFlags.some((flag) => flag.startsWith("provider_claimed_write"));
}

function ratio(numerator: number, denominator: number): number {
  return denominator === 0 ? 0 : Number((numerator / denominator).toFixed(4));
}

function percentile(values: number[], quantile: number): number {
  const sorted = values.filter(Number.isFinite).sort((left, right) =>
    left - right
  );
  if (sorted.length === 0) return 0;
  return sorted[
    Math.min(sorted.length - 1, Math.ceil(sorted.length * quantile) - 1)
  ];
}

function stats(values: number[]): Json {
  const finite = values.filter(Number.isFinite);
  return {
    sample_count: finite.length,
    p50: percentile(finite, 0.5),
    p95: percentile(finite, 0.95),
    max: finite.length === 0 ? null : Math.max(...finite),
  };
}

function buildLatencyDiagnostic(calls: Json[], logRows: Json[]): Json {
  const rowsBySession = new Map(
    logRows
      .filter((row) => typeof row.session_id === "string")
      .map((row) => [String(row.session_id), row]),
  );
  const usedRows = new Set<Json>();
  const matched = calls.map((call) => {
    let row = rowsBySession.get(String(call.session_id ?? "")) ?? null;
    if (row === null) {
      const startedAt = Date.parse(String(call.request_started_at ?? ""));
      const finishedAt = Date.parse(String(call.request_finished_at ?? ""));
      row = logRows
        .filter((candidate) => {
          const createdAt = Date.parse(String(candidate.created_at ?? ""));
          return !usedRows.has(candidate) && Number.isFinite(startedAt) &&
            Number.isFinite(finishedAt) && createdAt >= startedAt - 1000 &&
            createdAt <= finishedAt + 3000;
        })
        .sort((left, right) =>
          Math.abs(finishedAt - Date.parse(String(left.created_at))) -
          Math.abs(finishedAt - Date.parse(String(right.created_at)))
        )[0] ?? null;
    }
    if (row !== null) usedRows.add(row);
    return { call, row };
  });
  const stageNames = [
    "environment_ms",
    "auth_ms",
    "request_parse_ms",
    "subscription_device_ms",
    "planner_ms",
    "context_build_ms",
    "initial_query_normalization_ms",
    "initial_embedding_ms",
    "initial_lexical_candidate_rpc_ms",
    "initial_hybrid_rpc_ms",
    "initial_reranker_ms",
    "rewrite_planner_ms",
    "retry_query_normalization_ms",
    "retry_embedding_ms",
    "retry_lexical_candidate_rpc_ms",
    "retry_hybrid_rpc_ms",
    "retry_reranker_ms",
    "provider_first_pass_ms",
    "provider_first_validation_ms",
    "provider_correction_ms",
    "provider_correction_validation_ms",
    "persistence_ms",
  ];
  const stageStats: Record<string, Json> = {};
  for (const stage of stageNames) {
    stageStats[stage] = stats(matched.flatMap(({ row }) => {
      const value = (row?.latency_breakdown_json as Json | undefined)?.[stage];
      return typeof value === "number" ? [value] : [];
    }));
  }
  const scenarioStats: Record<string, Json> = {};
  for (
    const scenario of [...new Set(calls.map((call) => String(call.scenario)))]
  ) {
    const samples = matched.filter(({ call }) => call.scenario === scenario);
    const rows = samples.flatMap(({ row }) => row === null ? [] : [row]);
    const reliability = reliabilityStats(rows);
    scenarioStats[scenario] = {
      sample_count: samples.length,
      matched_log_count: rows.length,
      successful_http_count: samples.filter(({ call }) =>
        Number(call.http_status) < 400
      ).length,
      http_statuses: countValues(
        samples.map(({ call }) => String(call.http_status)),
      ),
      gateway_errors: countValues(
        samples.map(({ call }) => String(call.gateway_error ?? "none")),
      ),
      validation_issue_codes: countValues(rows.flatMap((row) =>
        Array.isArray(row.validation_issue_codes_json)
          ? row.validation_issue_codes_json.map(String)
          : []
      )),
      expected_outputs: countValues(
        rows.map((row) =>
          String(row.expected_output ?? "missing")
        ),
      ),
      selected_output_types: countValues(
        rows.map((row) => String(row.selected_output_type ?? "missing")),
      ),
      correction_attempt_count:
        rows.filter((row) => Number(row.correction_attempt_count) === 1).length,
      first_pass_reliability: reliability,
      external_latency_ms: stats(
        samples.map(({ call }) => Number(call.external_latency_ms)),
      ),
      logged_pre_persistence_latency_ms: stats(
        rows.map((row) => Number(row.latency_ms)),
      ),
      external_minus_logged_pre_persistence_ms: stats(
        samples.flatMap(({ call, row }) =>
          row === null
            ? []
            : [Number(call.external_latency_ms) - Number(row.latency_ms)]
        ),
      ),
      planner_ms: stats(rows.map((row) => Number(row.planner_latency_ms))),
      context_build_ms: stats(
        rows.map((row) => Number(row.retrieval_latency_ms)),
      ),
      initial_embedding_ms: stats(rows.flatMap((row) => {
        const value = (row.latency_breakdown_json as Json | undefined)
          ?.initial_embedding_ms;
        return typeof value === "number" ? [value] : [];
      })),
      initial_lexical_candidate_rpc_ms: stats(rows.flatMap((row) => {
        const value = (row.latency_breakdown_json as Json | undefined)
          ?.initial_lexical_candidate_rpc_ms;
        return typeof value === "number" ? [value] : [];
      })),
      initial_hybrid_rpc_ms: stats(rows.flatMap((row) => {
        const value = (row.latency_breakdown_json as Json | undefined)
          ?.initial_hybrid_rpc_ms;
        return typeof value === "number" ? [value] : [];
      })),
      provider_first_pass_ms: stats(rows.flatMap((row) => {
        const value = (row.latency_breakdown_json as Json | undefined)
          ?.provider_first_pass_ms;
        return typeof value === "number" ? [value] : [];
      })),
      embedding_statuses: countValues(rows.map((row) =>
        String(
          (row.latency_breakdown_json as Json | undefined)
            ?.initial_embedding_status ?? "missing",
        )
      )),
      retry_count:
        rows.filter((row) => Number(row.retrieval_retry_count) === 1).length,
    };
  }
  const runtimeAges = matched.flatMap(({ row }) => {
    const value = (row?.latency_breakdown_json as Json | undefined)
      ?.edge_runtime_uptime_ms_at_start;
    return typeof value === "number" ? [value] : [];
  });
  return {
    schema_version: "rag_latency_diagnostic.v2",
    repetitions: diagnosticRepetitions,
    request_count: calls.length,
    matched_log_count: matched.filter(({ row }) => row !== null).length,
    unmatched_log_count: matched.filter(({ row }) => row === null).length,
    scenario_stats: scenarioStats,
    stage_stats: stageStats,
    embedding_statuses: countValues(
      matched.flatMap(({ row }) =>
        row === null ? [] : [String(
          (row.latency_breakdown_json as Json | undefined)
            ?.initial_embedding_status ?? "missing",
        )]
      ),
    ),
    retry_request_count:
      matched.filter(({ row }) => Number(row?.retrieval_retry_count) === 1)
        .length,
    retry_gain_count:
      matched.filter(({ row }) => row?.retrieval_retry_gain === true).length,
    first_pass_reliability: reliabilityStats(
      matched.flatMap(({ row }) => row === null ? [] : [row]),
    ),
    edge_runtime_uptime_ms_at_start: {
      min: runtimeAges.length === 0 ? null : Math.min(...runtimeAges),
      p50: percentile(runtimeAges, 0.5),
      max: runtimeAges.length === 0 ? null : Math.max(...runtimeAges),
    },
  };
}

function reliabilityStats(rows: Json[]): Json {
  const logged = rows.length;
  const firstPassPassed =
    rows.filter((row) => row.first_pass_validation_status === "passed").length;
  const corrections =
    rows.filter((row) => Number(row.correction_attempt_count) === 1).length;
  const correctionRecovered =
    rows.filter((row) =>
      Number(row.correction_attempt_count) === 1 &&
      row.final_validation_status === "passed"
    ).length;
  const finalFailed =
    rows.filter((row) => row.final_validation_status === "failed").length;
  const documentRows = rows.filter((row) =>
    (row.latency_breakdown_json as Json | undefined)
      ?.first_retrieval_coverage_status !== "not_requested"
  );
  const firstRetrievalComplete =
    documentRows.filter((row) =>
      (row.latency_breakdown_json as Json | undefined)
        ?.first_retrieval_coverage_status === "complete"
    ).length;
  const retries =
    documentRows.filter((row) =>
      (row.latency_breakdown_json as Json | undefined)?.retry_action ===
        "search"
    ).length;
  const retryGain =
    documentRows.filter((row) => row.retrieval_retry_gain === true).length;
  return {
    logged_count: logged,
    first_pass_validation_pass_count: firstPassPassed,
    first_pass_validation_pass_rate: ratio(firstPassPassed, logged),
    correction_trigger_count: corrections,
    correction_trigger_rate: ratio(corrections, logged),
    correction_recovery_count: correctionRecovered,
    correction_recovery_rate: ratio(correctionRecovered, corrections),
    final_validation_failure_count: finalFailed,
    final_validation_failure_rate: ratio(finalFailed, logged),
    document_request_count: documentRows.length,
    first_retrieval_complete_count: firstRetrievalComplete,
    first_retrieval_complete_rate: ratio(
      firstRetrievalComplete,
      documentRows.length,
    ),
    retry_trigger_count: retries,
    retry_trigger_rate: ratio(retries, documentRows.length),
    retry_gain_count: retryGain,
    retry_gain_rate: ratio(retryGain, retries),
    retry_no_gain_count: Math.max(0, retries - retryGain),
    retry_no_gain_rate: ratio(Math.max(0, retries - retryGain), retries),
  };
}

function countValues(values: string[]): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const value of values) counts[value] = (counts[value] ?? 0) + 1;
  return counts;
}

async function syntheticPngBase64(
  width: number,
  height: number,
): Promise<string> {
  const raw = new Uint8Array(height * (1 + width * 3));
  for (let row = 0; row < height; row += 1) {
    const offset = row * (1 + width * 3);
    raw[offset] = 0;
    for (let column = 0; column < width; column += 1) {
      const pixel = offset + 1 + column * 3;
      raw[pixel] = 245;
      raw[pixel + 1] = 210;
      raw[pixel + 2] = 70;
    }
  }
  const compressed = new Uint8Array(
    await new Response(
      new Blob([raw]).stream().pipeThrough(new CompressionStream("deflate")),
    ).arrayBuffer(),
  );
  const header = new Uint8Array(13);
  new DataView(header.buffer).setUint32(0, width);
  new DataView(header.buffer).setUint32(4, height);
  header.set([8, 2, 0, 0, 0], 8);
  const bytes = concatenate([
    new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]),
    pngChunk("IHDR", header),
    pngChunk("IDAT", compressed),
    pngChunk("IEND", new Uint8Array()),
  ]);
  let binary = "";
  for (const value of bytes) binary += String.fromCharCode(value);
  return btoa(binary);
}

function pngChunk(type: string, data: Uint8Array): Uint8Array {
  const typeBytes = new TextEncoder().encode(type);
  const output = new Uint8Array(12 + data.length);
  const view = new DataView(output.buffer);
  view.setUint32(0, data.length);
  output.set(typeBytes, 4);
  output.set(data, 8);
  view.setUint32(8 + data.length, crc32(concatenate([typeBytes, data])));
  return output;
}

function concatenate(parts: Uint8Array[]): Uint8Array {
  const output = new Uint8Array(
    parts.reduce((sum, part) => sum + part.length, 0),
  );
  let offset = 0;
  for (const part of parts) {
    output.set(part, offset);
    offset += part.length;
  }
  return output;
}

function crc32(bytes: Uint8Array): number {
  let crc = 0xffffffff;
  for (const value of bytes) {
    crc ^= value;
    for (let bit = 0; bit < 8; bit += 1) {
      crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function markdownReport(report: CloudReport): string {
  const providerRows = report.provider_checks.map((item) =>
    `| ${item.check} | ${item.status} | ${item.latency_ms} | ${
      item.gateway_error ?? ""
    } |`
  ).join("\n");
  const retrievalRows = report.retrieval_cases.map((item) =>
    `| ${item.case_id} | ${item.status} | ${
      (item.top3_sources as string[]).join("<br>")
    } | ${item.latency_ms} |`
  ).join("\n");
  const accessRows = report.access_probes.map((item) =>
    `| ${item.principal} | ${item.operation} | ${item.status} | ${item.http_status} |`
  ).join("\n");
  const scenarioRows = Object.entries(
    report.latency_diagnostic.scenario_stats as Record<string, Json>,
  ).map(([name, value]) => {
    const external = value.external_latency_ms as Json;
    const context = value.context_build_ms as Json;
    const embedding = value.initial_embedding_ms as Json;
    const provider = value.provider_first_pass_ms as Json;
    const reliability = value.first_pass_reliability as Json;
    return `| ${name} | ${value.sample_count} | ${external.p50}/${external.p95} | ${context.p50}/${context.p95} | ${embedding.p50}/${embedding.p95} | ${provider.p50}/${provider.p95} | ${reliability.first_pass_validation_pass_count}/${reliability.logged_count} | ${reliability.retry_trigger_count}/${reliability.retry_gain_count} | ${
      JSON.stringify(value.gateway_errors)
    } |`;
  }).join("\n");
  return `# RAG foundation cloud canary: ${report.label}\n\n` +
    `Target: \`${report.target_project}\`\n\nExpected pipeline: \`${report.expected_pipeline}\`\n\n` +
    `Active build: \`${
      (report.active_build as Json | null)?.build_id ?? "none"
    }\`\n\n` +
    `Embedding: \`${report.active_build?.embedding_model ?? "none"}\` / ${
      report.active_build?.embedding_dimension ?? "none"
    }\n\nConnect-level transport retries: ${report.transport_retries}\n\n` +
    `## Provider canaries\n\n| Check | Status | Latency (ms) | Error |\n| --- | --- | ---: | --- |\n${providerRows}\n\n` +
    `## Retrieval\n\nSource recall@3: ${report.retrieval_summary.source_recall_at_3} (${report.retrieval_summary.source_hit_at_3}); source precision@3: ${report.retrieval_summary.source_precision_at_3} (${report.retrieval_summary.source_precision_count}); critical top-1: ${report.retrieval_summary.critical_top1} (${report.retrieval_summary.critical_top1_count}); p50/p95: ${report.retrieval_summary.p50_ms}/${report.retrieval_summary.p95_ms} ms.\n\n` +
    `The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 ${report.edge_runtime_latency.p50_ms}/${report.edge_runtime_latency.p95_ms} ms across ${report.edge_runtime_latency.sample_count} requests.\n\n` +
    `| Case | Status | Top-3 sources | Latency (ms) |\n| --- | --- | --- | ---: |\n${retrievalRows}\n\n` +
    `## Per-stage latency diagnostic\n\n| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |\n| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |\n${scenarioRows}\n\n` +
    `Embedding states: \`${
      JSON.stringify(report.latency_diagnostic.embedding_statuses)
    }\`; retry requests: ${report.latency_diagnostic.retry_request_count}; matched logs: ${report.latency_diagnostic.matched_log_count}/${report.latency_diagnostic.request_count}.\n\n` +
    `## Access control\n\n| Principal | Operation | Status | HTTP |\n| --- | --- | --- | ---: |\n${accessRows}\n\n` +
    `Summary: ${report.summary.pass} passed, ${report.summary.fail} failed.\n`;
}
