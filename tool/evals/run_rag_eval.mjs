import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { access, mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import { join } from "node:path";

const fixtureDirectory = "test/evals/fixtures";
const reportDirectory = "test/evals/reports";
const executorRegistry = {
  ai_chat_behavior_parity_v2: [
    "supabase/functions/ai-chat-route/eval_fixture_executor_test.ts",
  ],
  document_retrieval: [
    "supabase/functions/ai-chat-route/rag/query_normalizer_test.ts",
    "supabase/functions/ai-chat-route/rag/retrieval_reranker_test.ts",
    "supabase/functions/ai-chat-route/rag/retrieval_coverage_test.ts",
    "supabase/functions/ai-chat-route/rag/retrieval_pipeline_test.ts",
  ],
  exercise_context: [
    "supabase/functions/ai-chat-route/exercise/exercise_resolver_test.ts",
  ],
  failure_retry: [
    "supabase/functions/ai-chat-route/rag/retrieval_retry_test.ts",
    "supabase/functions/ai-chat-route/rag/retrieval_pipeline_test.ts",
    "supabase/functions/ai-chat-route/rag/retrieval_reranker_test.ts",
  ],
  first_pass_reliability: [
    "supabase/functions/ai-chat-route/eval_fixture_executor_test.ts",
    "supabase/functions/ai-chat-route/planning/chat_decision_test.ts",
    "supabase/functions/ai-chat-route/planning/model_planners_test.ts",
    "supabase/functions/ai-chat-route/index_test.ts",
    "supabase/functions/_shared/ai_output_contract_test.ts",
  ],
  food_capability: [
    "supabase/functions/_shared/food_capability_test.ts",
    "supabase/functions/ai-food-photo-analyze/index_test.ts",
  ],
  grounded_output: [
    "supabase/functions/ai-chat-route/grounding/faithfulness_guard_test.ts",
  ],
  provider_canary: [
    "supabase/functions/ai-chat-route/index_test.ts",
    "supabase/functions/ai-food-photo-analyze/index_test.ts",
  ],
  provider_parity: [
    "supabase/functions/ai-chat-route/index_test.ts",
    "supabase/functions/ai-food-photo-analyze/index_test.ts",
  ],
  safety_privacy: [
    "supabase/functions/ai-chat-route/index_test.ts",
    "supabase/functions/ai-chat-route/guarding/write_claim_guard_test.ts",
  ],
  structured_context: [
    "supabase/functions/ai-chat-route/planning/task_planner_test.ts",
    "supabase/functions/ai-chat-route/index_test.ts",
  ],
  task_planning: [
    "supabase/functions/ai-chat-route/eval_fixture_executor_test.ts",
    "supabase/functions/ai-chat-route/planning/chat_decision_test.ts",
    "supabase/functions/ai-chat-route/planning/task_planner_test.ts",
  ],
};
const globalExecutorPaths = [...new Set(Object.values(executorRegistry).flat())];
const denoExecutable = await findDenoExecutable();
const globalExecution = runDenoTests(globalExecutorPaths, denoExecutable);

const fixtureNames = (await readdir(fixtureDirectory))
  .filter((name) => name.endsWith(".json"))
  .sort();
const suites = [];
for (const name of fixtureNames) {
  const raw = await readFile(`${fixtureDirectory}/${name}`, "utf8");
  const parsed = JSON.parse(raw);
  if (parsed.schema !== "fitlog_eval_suite.v1") {
    if (name === "rag_foundation_baseline.v1.json") continue;
    throw new Error(`Invalid eval fixture: ${name}`);
  }
  if (!Array.isArray(parsed.cases) || parsed.cases.length === 0) {
    throw new Error(`Invalid eval fixture: ${name}`);
  }
  const ids = parsed.cases.map((item) => item.case_id);
  if (ids.some((id) => typeof id !== "string" || id === "") ||
      new Set(ids).size !== ids.length) {
    throw new Error(`Invalid case IDs: ${name}`);
  }
  const executor = executorRegistry[parsed.suite];
  const externalIds = parsed.cases
    .filter((item) => item.requires_external === true)
    .map((item) => item.case_id);
  if (executor === undefined) {
    suites.push({
      name,
      suite: parsed.suite,
      hash: sha256(raw),
      status: "inventory_only",
      executor: null,
      declared: ids.length,
      executed: 0,
      passed: 0,
      failed: 0,
      skipped: ids.length,
      declared_case_ids: ids,
      executed_case_ids: [],
      skipped_case_ids: ids,
      output: "No registered executor",
    });
    continue;
  }
  const localIds = ids.filter((id) => !externalIds.includes(id));
  const passedIds = localIds.filter((id) =>
    globalExecution.passedCaseIds.has(`${parsed.suite}:${id}`)
  );
  const failedIds = localIds.filter((id) =>
    globalExecution.failedCaseIds.has(`${parsed.suite}:${id}`)
  );
  const unexecutedIds = localIds.filter((id) =>
    !passedIds.includes(id) && !failedIds.includes(id)
  );
  const executedIds = [...passedIds, ...failedIds];
  suites.push({
    name,
    suite: parsed.suite,
    hash: sha256(raw),
    status: failedIds.length > 0 || unexecutedIds.length > 0
      ? "fail"
      : externalIds.length > 0 ? "blocked" : "pass",
    executor,
    declared: ids.length,
    executed: executedIds.length,
    passed: passedIds.length,
    failed: failedIds.length + unexecutedIds.length,
    skipped: externalIds.length,
    declared_case_ids: ids,
    executed_case_ids: executedIds,
    passed_case_ids: passedIds,
    failed_case_ids: failedIds,
    unexecuted_case_ids: unexecutedIds,
    skipped_case_ids: externalIds,
    output: globalExecution.output,
  });
}

const corpus = JSON.parse(await readFile(
  "tool/phase5_document_rag/document_corpus_build.v1.json",
  "utf8",
));
let embeddings = null;
try {
  embeddings = JSON.parse(await readFile(
    "tool/phase5_document_rag/document_embeddings.v1.json",
    "utf8",
  ));
} catch (error) {
  if (error.code !== "ENOENT") throw error;
}
const embedded = embeddings?.records?.length ?? 0;
let cloud = null;
const cloudReportPath = process.env.FITLOG_RAG_CLOUD_REPORT_PATH ??
  "test/evals/reports/rag_foundation_cloud_chat-orchestrator-v2-legacy-retired.v1.json";
try {
  cloud = JSON.parse(await readFile(cloudReportPath, "utf8"));
} catch (error) {
  if (error.code !== "ENOENT") throw error;
}
const cloudCheck = (name) =>
  cloud?.checks?.find((check) => check.check === name);
const providerCanariesPassed = Array.isArray(cloud?.provider_checks) &&
  cloud.provider_checks.length >= 5 &&
  cloud.provider_checks.every((check) => check.status === "pass");
const retrievalQualityPassed = [
  "document_source_recall_at_3",
  "document_source_precision_at_3",
  "critical_source_top1",
  "no_answer_fabricated_source",
  "query_embedding_available",
].every((name) => cloudCheck(name)?.status === "pass");
const inventoryOnly = suites.filter((suite) =>
  suite.status === "inventory_only"
);
const executorFailures = suites.filter((suite) => suite.status === "fail");
const checks = [
  result(
    "required_corpus_source_coverage",
    corpus.source_count === corpus.sources.length &&
      new Set(corpus.sources).size === corpus.sources.length,
    `${corpus.source_count}/${corpus.sources.length} unique manifest sources`,
  ),
  result(
    "bilingual_required_file_pairing",
    corpus.sources.filter((source) => source.startsWith("docs/en/")).length ===
        10 &&
      corpus.sources.filter((source) => source.startsWith("docs/zh/")).length ===
        10,
    "10 en + 10 zh",
  ),
  result(
    "protected_markdown_token_fidelity",
    !/\. (?:dart|ts|sql)|developers\. openai\. com/.test(
      corpus.chunks.map((chunk) => chunk.content).join("\n"),
    ),
    "forbidden patterns=0",
  ),
  {
    metric: "active_chunks_embedding_freshness_parity",
    status: embedded === corpus.chunk_count ? "pass" : "blocked",
    evidence:
      `${embedded}/${corpus.chunk_count}; external embedding authorization required when incomplete`,
  },
  result(
    "fixture_executor_registry_complete",
    inventoryOnly.length === 0,
    inventoryOnly.length === 0
      ? `${suites.length}/${suites.length} suites registered`
      : inventoryOnly.map((suite) => suite.suite).join(", "),
  ),
  result(
    "fixture_executors_passed",
    executorFailures.length === 0,
    executorFailures.length === 0
      ? `${suites.reduce((sum, suite) => sum + suite.executed, 0)} local cases executed`
      : executorFailures.map((suite) => suite.suite).join(", "),
  ),
  {
    metric: "document_recall_precision_release_thresholds",
    status: cloud === null
      ? "blocked"
      : retrievalQualityPassed ? "pass" : "fail",
    evidence: cloud === null
      ? "requires deployed active hybrid corpus and query embeddings"
      : `recall@3=${cloud.retrieval_summary.source_recall_at_3}; precision@3=${cloud.retrieval_summary.source_precision_at_3}; critical top1=${cloud.retrieval_summary.critical_top1}`,
  },
  {
    metric: "provider_live_canaries",
    status: cloud === null
      ? "blocked"
      : providerCanariesPassed ? "pass" : "fail",
    evidence: cloud === null
      ? "requires deployed Edge and explicit external execution"
      : `${cloud.provider_checks.filter((check) => check.status === "pass").length}/${cloud.provider_checks.length}; synthetic inputs only`,
  },
  {
    metric: "edge_embedding_hybrid_latency_p95",
    status: cloud === null
      ? "blocked"
      : cloudCheck("edge_embedding_hybrid_latency_p95")?.status ?? "fail",
    evidence: cloud === null
      ? "requires deployed Edge latency samples"
      : `${cloud.edge_runtime_latency.p95_ms} ms / 1500 ms; samples=${cloud.edge_runtime_latency.sample_count}`,
  },
];
const report = {
  schema: "fitlog_rag_eval_report.v2",
  pipeline_version: "rag_foundation_v1+chat_decision.v2",
  corpus_id: corpus.corpus_id,
  build_id: corpus.build_id,
  fixture_suites: suites,
  fixture_totals: {
    declared: suites.reduce((sum, suite) => sum + suite.declared, 0),
    executed: suites.reduce((sum, suite) => sum + suite.executed, 0),
    passed: suites.reduce((sum, suite) => sum + suite.passed, 0),
    failed: suites.reduce((sum, suite) => sum + suite.failed, 0),
    skipped: suites.reduce((sum, suite) => sum + suite.skipped, 0),
  },
  checks,
  summary: {
    pass: checks.filter((check) => check.status === "pass").length,
    fail: checks.filter((check) => check.status === "fail").length,
    blocked: checks.filter((check) => check.status === "blocked").length,
  },
};
await mkdir(reportDirectory, { recursive: true });
await writeFile(
  `${reportDirectory}/rag_foundation_local.v1.json`,
  `${JSON.stringify(report, null, 2)}\n`,
  "utf8",
);
await writeFile(
  `${reportDirectory}/rag_foundation_local.v1.md`,
  markdownReport(report),
  "utf8",
);
console.log(JSON.stringify({
  ...report.summary,
  fixtures: report.fixture_totals,
}));
if (report.summary.fail > 0) process.exitCode = 1;

function runDenoTests(paths, executable) {
  if (executable === null && process.platform !== "win32") {
    return {
      ok: false,
      output: "Deno executable unavailable",
      passedCaseIds: new Set(),
      failedCaseIds: new Set(),
    };
  }
  const options = {
    encoding: "utf8",
    maxBuffer: 16 * 1024 * 1024,
    shell: executable === null && process.platform === "win32",
  };
  const command = executable ?? "npm.cmd";
  const args = executable === null
    ? ["exec", "--yes", "deno", "--", "test", "--allow-read", ...paths]
    : ["test", "--allow-read", ...paths];
  const result = spawnSync(
    command,
    args,
    options,
  );
  const output = `${result.stdout ?? ""}${result.stderr ?? ""}${
    result.error?.message ?? ""
  }`.trim();
  const cleanOutput = output.replace(/\x1b\[[0-9;]*m/g, "");
  const passedCaseIds = new Set();
  const failedCaseIds = new Set();
  for (const line of cleanOutput.split(/\r?\n/)) {
    const match = line.match(/fixture:([^:]+):([a-z0-9_-]+).*\b(ok|FAILED)\b/i);
    if (match === null) continue;
    const key = `${match[1]}:${match[2]}`;
    (match[3].toLowerCase() === "ok" ? passedCaseIds : failedCaseIds).add(key);
  }
  return {
    ok: result.status === 0,
    output: output.slice(-4000),
    passedCaseIds,
    failedCaseIds,
  };
}

async function findDenoExecutable() {
  const configured = process.env.FITLOG_DENO_BIN?.trim();
  if (configured) return configured;
  if (process.platform !== "win32") return "deno";
  const localAppData = process.env.LOCALAPPDATA;
  if (!localAppData) return null;
  const npxRoot = join(localAppData, "npm-cache", "_npx");
  let entries;
  try {
    entries = await readdir(npxRoot, { withFileTypes: true });
  } catch {
    return null;
  }
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const candidate = join(
      npxRoot,
      entry.name,
      "node_modules",
      "deno",
      "deno.exe",
    );
    try {
      await access(candidate);
      return candidate;
    } catch {
      // Continue to the next npm-distributed Deno installation.
    }
  }
  return null;
}

function result(metric, passed, evidence) {
  return { metric, status: passed ? "pass" : "fail", evidence };
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function markdownReport(value) {
  const suiteRows = value.fixture_suites.map((suite) =>
    `| ${suite.suite} | ${suite.status} | ${suite.declared} | ${suite.executed} | ${suite.passed} | ${suite.failed} | ${suite.skipped} |`
  ).join("\n");
  return `# RAG and Chat orchestration local evaluation

Pipeline: \`${value.pipeline_version}\`
Corpus build: \`${value.build_id}\`

## Fixture execution

| Suite | Status | Declared | Executed | Passed | Failed | Skipped |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
${suiteRows}

## Release checks

| Metric | Status | Evidence |
| --- | --- | --- |
${value.checks.map((check) =>
    `| ${check.metric} | ${check.status} | ${check.evidence} |`
  ).join("\n")}
`;
}
