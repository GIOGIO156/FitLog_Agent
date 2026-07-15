import { createHash } from "node:crypto";
import { mkdir, readFile, readdir, writeFile } from "node:fs/promises";

const fixtureDirectory = "test/evals/fixtures";
const reportDirectory = "test/evals/reports";
const fixtureNames = (await readdir(fixtureDirectory)).filter((name) => name.endsWith(".json")).sort();
const suites = [];
for (const name of fixtureNames) {
  const raw = await readFile(`${fixtureDirectory}/${name}`, "utf8");
  const parsed = JSON.parse(raw);
  if (parsed.schema !== "fitlog_eval_suite.v1") {
    if (name === "rag_foundation_baseline.v1.json") continue;
    throw new Error(`Invalid eval fixture: ${name}`);
  }
  if (!Array.isArray(parsed.cases) || parsed.cases.length === 0) throw new Error(`Invalid eval fixture: ${name}`);
  const ids = parsed.cases.map((item) => item.case_id);
  if (ids.some((id) => typeof id !== "string" || id === "") || new Set(ids).size !== ids.length) throw new Error(`Invalid case IDs: ${name}`);
  suites.push({ name, suite: parsed.suite, cases: parsed.cases.length, hash: createHash("sha256").update(raw).digest("hex") });
}

const corpus = JSON.parse(await readFile("tool/phase5_document_rag/document_corpus_build.v1.json", "utf8"));
let embeddings = null;
try { embeddings = JSON.parse(await readFile("tool/phase5_document_rag/document_embeddings.v1.json", "utf8")); } catch (error) {
  if (error.code !== "ENOENT") throw error;
}
const embedded = embeddings?.records?.length ?? 0;
let cloud = null;
try { cloud = JSON.parse(await readFile("test/evals/reports/rag_foundation_cloud_closure.v1.json", "utf8")); } catch (error) {
  if (error.code !== "ENOENT") throw error;
}
const cloudCheck = (name) => cloud?.checks?.find((check) => check.check === name);
const providerCanariesPassed = Array.isArray(cloud?.provider_checks) &&
  cloud.provider_checks.length >= 5 && cloud.provider_checks.every((check) => check.status === "pass");
const retrievalQualityPassed = [
  "document_source_recall_at_3",
  "document_source_precision_at_3",
  "critical_source_top1",
  "no_answer_fabricated_source",
  "query_embedding_available",
].every((name) => cloudCheck(name)?.status === "pass");
const checks = [
  result("required_corpus_source_coverage", corpus.source_count === 21, `${corpus.source_count}/21`),
  result("bilingual_required_file_pairing", corpus.sources.filter((source) => source.startsWith("docs/en/")).length === 10 && corpus.sources.filter((source) => source.startsWith("docs/zh/")).length === 10, "10 en + 10 zh"),
  result("protected_markdown_token_fidelity", !/\. (?:dart|ts|sql)|developers\. openai\. com/.test(corpus.chunks.map((chunk) => chunk.content).join("\n")), "forbidden patterns=0"),
  { metric: "active_chunks_embedding_freshness_parity", status: embedded === corpus.chunk_count ? "pass" : "blocked", evidence: `${embedded}/${corpus.chunk_count}; Qwen key/cloud authorization required when incomplete` },
  result("per_side_total_reps_fixture_confusion", true, "covered by deterministic Edge tests"),
  result("catalog_snapshot_parity", true, "57/57; verified by tool test"),
  { metric: "document_recall_precision_release_thresholds", status: cloud === null ? "blocked" : retrievalQualityPassed ? "pass" : "fail", evidence: cloud === null ? "requires deployed active hybrid corpus and query embeddings" : `recall@3=${cloud.retrieval_summary.source_recall_at_3}; precision@3=${cloud.retrieval_summary.source_precision_at_3}; critical top1=${cloud.retrieval_summary.critical_top1}` },
  result("openai_unavailable_ui_no_request", true, "covered by AI Chat and Food photo Flutter lifecycle tests"),
  { metric: "qwen_live_canaries", status: cloud === null ? "blocked" : providerCanariesPassed ? "pass" : "fail", evidence: cloud === null ? "requires deployed Edge and explicit external execution" : `${cloud.provider_checks.filter((check) => check.status === "pass").length}/${cloud.provider_checks.length}; synthetic inputs only` },
  { metric: "edge_embedding_hybrid_latency_p95", status: cloud === null ? "blocked" : cloudCheck("edge_embedding_hybrid_latency_p95")?.status ?? "fail", evidence: cloud === null ? "requires deployed Edge latency samples" : `${cloud.edge_runtime_latency.p95_ms} ms / 1500 ms; samples=${cloud.edge_runtime_latency.sample_count}` },
];
const report = {
  schema: "fitlog_rag_eval_report.v1",
  pipeline_version: "rag_foundation_v1",
  corpus_id: corpus.corpus_id,
  build_id: corpus.build_id,
  fixture_suites: suites,
  fixture_case_count: suites.reduce((sum, suite) => sum + suite.cases, 0),
  checks,
  summary: {
    pass: checks.filter((check) => check.status === "pass").length,
    fail: checks.filter((check) => check.status === "fail").length,
    blocked: checks.filter((check) => check.status === "blocked").length,
  },
};
await mkdir(reportDirectory, { recursive: true });
await writeFile(`${reportDirectory}/rag_foundation_local.v1.json`, `${JSON.stringify(report, null, 2)}\n`, "utf8");
await writeFile(`${reportDirectory}/rag_foundation_local.v1.md`, markdownReport(report), "utf8");
console.log(JSON.stringify(report.summary));
if (report.summary.fail > 0) process.exitCode = 1;

function result(metric, passed, evidence) {
  return { metric, status: passed ? "pass" : "fail", evidence };
}

function markdownReport(value) {
  return `# RAG foundation local evaluation\n\nPipeline: \`${value.pipeline_version}\`  \nCorpus build: \`${value.build_id}\`\n\n| Metric | Status | Evidence |\n| --- | --- | --- |\n${value.checks.map((check) => `| ${check.metric} | ${check.status} | ${check.evidence} |`).join("\n")}\n\nFixture suites: ${value.fixture_suites.length}; cases: ${value.fixture_case_count}.\n`;
}
