import type { RetrievalCoverage } from "./retrieval_coverage.ts";
import { assessRetrievalCoverage } from "./retrieval_coverage.ts";
import type { RetrievalPipelineConfig } from "./retrieval_pipeline.ts";
import { retrieveFitLogDocuments } from "./retrieval_pipeline.ts";
import {
  parseSearchFitLogDocsArguments,
  type SearchFitLogDocsArguments,
} from "./retrieval_tool.ts";
import type { RetrievalAttemptLatency, RetrievalResult } from "./types.ts";

export interface RetrievalRetryOutcome {
  result: RetrievalResult;
  first_coverage: RetrievalCoverage;
  coverage: RetrievalCoverage;
  attempts: 1 | 2;
  retry_action:
    | "not_needed"
    | "disabled"
    | "conflict_stop"
    | "unsupported_identifier_stop"
    | "planner_stop"
    | "planner_failed"
    | "invalid"
    | "no_change"
    | "search";
  retry_query_changed: boolean;
  retry_reason: string | null;
  retry_gain: boolean;
  issue:
    | "retrieval_attempt_limit_reached"
    | "retrieval_retry_invalid"
    | "retrieval_retry_timeout"
    | null;
  latency: {
    attempts: RetrievalAttemptLatency[];
    rewrite_planner_ms: number | null;
  };
}

export type RetrievalRewritePlanner = (input: {
  original_query: string;
  normalized_concepts: string[];
  missing_dimensions: string[];
}) => Promise<
  { action: "stop" } | { action: "search_fitlog_docs"; arguments: unknown }
>;

export async function retrieveWithSingleRetry(params: {
  config: RetrievalPipelineConfig;
  rawQuery: string;
  requiredDimensions?: string[];
  retryEnabled: boolean;
  rewritePlanner: RetrievalRewritePlanner;
  fetchImpl?: typeof fetch;
}): Promise<RetrievalRetryOutcome> {
  const first = await retrieveFitLogDocuments(
    params.config,
    params.rawQuery,
    params.fetchImpl,
  );
  const firstCoverage = assessRetrievalCoverage(
    first.query,
    first.candidates,
    params.requiredDimensions,
  );
  if (firstCoverage.status === "complete") {
    return outcome(
      first,
      firstCoverage,
      firstCoverage,
      1,
      "not_needed",
      false,
      null,
      false,
      null,
      null,
      [first.debug.latency],
    );
  }
  if (!params.retryEnabled) {
    return outcome(
      first,
      firstCoverage,
      firstCoverage,
      1,
      "disabled",
      false,
      firstCoverage.status,
      false,
      null,
      null,
      [first.debug.latency],
    );
  }
  if (firstCoverage.status === "conflicting") {
    return outcome(
      first,
      firstCoverage,
      firstCoverage,
      1,
      "conflict_stop",
      false,
      firstCoverage.status,
      false,
      null,
      null,
      [first.debug.latency],
    );
  }
  if (firstCoverage.missing_dimensions.includes("technical_identifiers")) {
    return outcome(
      first,
      firstCoverage,
      firstCoverage,
      1,
      "unsupported_identifier_stop",
      false,
      firstCoverage.status,
      false,
      null,
      null,
      [first.debug.latency],
    );
  }
  let plan;
  const rewriteStartedAt = Date.now();
  try {
    plan = await params.rewritePlanner({
      original_query: params.rawQuery,
      normalized_concepts: first.query.canonical_concepts,
      missing_dimensions: firstCoverage.missing_dimensions,
    });
  } catch {
    return outcome(
      first,
      firstCoverage,
      firstCoverage,
      1,
      "planner_failed",
      false,
      firstCoverage.status,
      false,
      "retrieval_retry_timeout",
      Date.now() - rewriteStartedAt,
      [first.debug.latency],
    );
  }
  const rewritePlannerMs = Date.now() - rewriteStartedAt;
  if (plan.action === "stop") {
    return outcome(
      first,
      firstCoverage,
      firstCoverage,
      1,
      "planner_stop",
      false,
      firstCoverage.status,
      false,
      null,
      rewritePlannerMs,
      [first.debug.latency],
    );
  }
  const argumentsValue = parseSearchFitLogDocsArguments(plan.arguments);
  if (argumentsValue === null) {
    return outcome(
      first,
      firstCoverage,
      firstCoverage,
      1,
      "invalid",
      false,
      firstCoverage.status,
      false,
      "retrieval_retry_invalid",
      rewritePlannerMs,
      [first.debug.latency],
    );
  }
  const retryQuery = boundedRetryQuery(params.rawQuery, argumentsValue);
  if (retryQuery === null) {
    return outcome(
      first,
      firstCoverage,
      firstCoverage,
      1,
      "no_change",
      false,
      firstCoverage.status,
      false,
      null,
      rewritePlannerMs,
      [first.debug.latency],
    );
  }
  const second = await retrieveFitLogDocuments(
    params.config,
    retryQuery,
    params.fetchImpl,
  );
  const merged: RetrievalResult = {
    ...second,
    candidates: mergeCandidates(first.candidates, second.candidates),
    debug: {
      ...second.debug,
      branch_hits: {
        exact: first.debug.branch_hits.exact + second.debug.branch_hits.exact,
        terms: first.debug.branch_hits.terms + second.debug.branch_hits.terms,
        full_text: first.debug.branch_hits.full_text +
          second.debug.branch_hits.full_text,
        trigram: first.debug.branch_hits.trigram +
          second.debug.branch_hits.trigram,
        lexical: first.debug.branch_hits.lexical +
          second.debug.branch_hits.lexical,
        vector: first.debug.branch_hits.vector +
          second.debug.branch_hits.vector,
      },
      final_hits: mergeCandidates(first.candidates, second.candidates).length,
      elimination_reasons: {
        below_minimum_score:
          first.debug.elimination_reasons.below_minimum_score +
          second.debug.elimination_reasons.below_minimum_score,
      },
      issues: [...new Set([...first.debug.issues, ...second.debug.issues])],
    },
  };
  const secondCoverage = assessRetrievalCoverage(
    first.query,
    merged.candidates,
    params.requiredDimensions,
  );
  return outcome(
    merged,
    firstCoverage,
    secondCoverage,
    2,
    "search",
    true,
    firstCoverage.status,
    coverageRank(secondCoverage.status) > coverageRank(firstCoverage.status),
    null,
    rewritePlannerMs,
    [first.debug.latency, second.debug.latency],
  );
}

function boundedRetryQuery(
  original: string,
  args: SearchFitLogDocsArguments,
): string | null {
  const normalizedOriginal = normalizeRetryPart(original);
  const additions = [...args.query_variants, ...args.required_concepts]
    .map((value) => value.trim())
    .filter((value, index, values) =>
      value !== "" && values.indexOf(value) === index &&
      !normalizedOriginal.includes(normalizeRetryPart(value))
    );
  if (additions.length === 0) return null;
  return [original, ...additions].join(" ").slice(0, 700);
}

function normalizeRetryPart(value: string): string {
  return value.normalize("NFKC").toLowerCase().replace(/[\s\u3000]+/g, " ")
    .trim();
}

function mergeCandidates(
  first: RetrievalResult["candidates"],
  second: RetrievalResult["candidates"],
) {
  const map = new Map<string, RetrievalResult["candidates"][number]>();
  for (const candidate of [...second, ...first]) {
    map.set(`${candidate.doc_path}:${candidate.section_id}`, candidate);
  }
  return [...map.values()].slice(0, 12);
}

function coverageRank(status: RetrievalCoverage["status"]): number {
  return { conflicting: 0, insufficient: 1, partial: 2, complete: 3 }[status];
}

function outcome(
  result: RetrievalResult,
  firstCoverage: RetrievalCoverage,
  coverage: RetrievalCoverage,
  attempts: 1 | 2,
  retryAction: RetrievalRetryOutcome["retry_action"],
  retryQueryChanged: boolean,
  retryReason: string | null,
  retryGain: boolean,
  issue: RetrievalRetryOutcome["issue"],
  rewritePlannerMs: number | null,
  attemptLatencies: RetrievalAttemptLatency[],
): RetrievalRetryOutcome {
  return {
    result,
    first_coverage: firstCoverage,
    coverage,
    attempts,
    retry_action: retryAction,
    retry_query_changed: retryQueryChanged,
    retry_reason: retryReason,
    retry_gain: retryGain,
    issue,
    latency: {
      attempts: attemptLatencies,
      rewrite_planner_ms: rewritePlannerMs,
    },
  };
}
