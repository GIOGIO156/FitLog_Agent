import type { OutputValidationIssue } from "../../_shared/ai_output_contract.ts";
import type { GatewayRequest } from "../contracts.ts";
import { normalizeRagQuery } from "../rag/query_normalizer.ts";

export const groundingValidatorVersion = "fitlog_grounding_guard.v2";

export interface ApprovedEvidenceEntry {
  id: string;
  kind: "document" | "context" | "deterministic_rule";
  status: string;
}

export function approvedEvidenceRegistry(
  request: GatewayRequest,
): ApprovedEvidenceEntry[] {
  const entries: ApprovedEvidenceEntry[] = [];
  for (const source of request.phase5Context?.document_sources ?? []) {
    entries.push({
      id: `doc:${source.section_id}`,
      kind: "document",
      status: source.status,
    });
  }
  for (const context of request.phase5Context?.context_objects ?? []) {
    entries.push({
      id: `context:${context.type}`,
      kind: "context",
      status: "implemented",
    });
  }
  entries.push({
    id: "rule:no_official_write_without_confirmation",
    kind: "deterministic_rule",
    status: "implemented",
  });
  return entries;
}

export function validateGroundedText(
  text: string,
  request: GatewayRequest,
): OutputValidationIssue[] {
  const workflow = activeWorkflow(request);
  if (
    isUnsupportedFitLogAttribution(text) &&
    workflow !== "app_logic_answer" &&
    workflow !== "safety_boundary"
  ) {
    return [{
      path: "$.message.text",
      reason: "unsupported_fitlog_attribution",
    }];
  }
  if (!isFitLogProductClaim(text)) return [];
  if (isNoWriteConfirmationClaim(text)) return [];
  const plannedSources = (request.phase5Context?.document_sources ?? [])
    .filter((source) =>
      source.status === "planned" || source.authority === "planned"
    );
  if (plannedSources.length > 0) {
    return [{ path: "$.message.text", reason: "authority_mismatch" }];
  }
  const documentSources = (request.phase5Context?.document_sources ?? [])
    .filter((source) => ["implemented", "evidence"].includes(source.status))
    .filter((source) =>
      source.authority === undefined || source.authority === "current_product"
    )
    .filter((source) =>
      source.doc_path === "README.md" ||
      source.doc_path.includes(`/docs/${request.language}/`) ||
      source.doc_path.includes(`docs/${request.language}/`)
    );
  if (documentSources.length === 0) {
    const anyCurrentDocumentSource =
      (request.phase5Context?.document_sources ?? [])
        .some((source) =>
          ["implemented", "evidence"].includes(source.status) &&
          (source.authority === undefined ||
            source.authority === "current_product")
        );
    return [{
      path: "$.message.text",
      reason: anyCurrentDocumentSource
        ? "fitlog_claim_exceeds_matching_evidence"
        : "fitlog_claim_without_approved_evidence",
    }];
  }
  const structured = request.phase5Context?.context_objects ?? [];
  const normalizedClaim = normalizeRagQuery(text);
  const evidenceText = [
    ...documentSources.map((source) =>
      `${source.heading} ${source.context_prefix} ${source.excerpt}`
    ),
    ...structured.map((context) => JSON.stringify(context.data)),
  ].join("\n").toLowerCase();
  const normalizedEvidence = normalizeRagQuery(evidenceText);
  const missingConcept =
    normalizedClaim.canonical_concepts.some((concept) =>
      !normalizedEvidence.canonical_concepts.includes(concept)
    ) || normalizedClaim.exercise_keys.some((key) =>
      !normalizedEvidence.exercise_keys.includes(key)
    );
  if (missingConcept) {
    return [{
      path: "$.message.text",
      reason: "fitlog_claim_exceeds_matching_evidence",
    }];
  }
  if (
    (request.phase5Context?.missing_dimensions.length ?? 0) > 0 &&
    /一定|必然|always|definitely/i.test(text)
  ) {
    return [{
      path: "$.message.text",
      reason: "missing_dimension_not_disclosed",
    }];
  }
  return [];
}

function activeWorkflow(request: GatewayRequest): string {
  return request.taskPlan?.planned_workflow ??
    request.phase5Context?.route.workflow ??
    request.workflowType;
}

function isUnsupportedFitLogAttribution(value: string): boolean {
  return /(?:根据|按照|依照)\s*FitLog\s*(?:的)?\s*(?:建议|推荐|分析|安排|判断)|FitLog\s*(?:建议|推荐|认为)|according to\s+FitLog|FitLog(?:'s)?\s+(?:recommendation|suggestion|advice)|FitLog\s+(?:recommends|suggests|advises|says)/i
    .test(value);
}

function isFitLogProductClaim(value: string): boolean {
  return /(?:FitLog|本应用|这个应用|系统).{0,24}(?:会|使用|规定|默认|建议|推荐|认为|规则|算法|数据库|保存|写入|读取|权限|直接|自动|source of truth|uses|will|always|stores|saves|requires|allows|recommends|suggests|advises|database|algorithm|rule)|(?:规则|算法|数据库|source of truth)(?:是|为|会)|the app (?:uses|will|always|stores|saves|requires|allows)/i
    .test(value);
}

function isNoWriteConfirmationClaim(value: string): boolean {
  return /(?:不会|不能|不得).{0,24}(?:保存|写入|修改|删除|正式记录|目标|策略)|不是.{0,12}正式记录|(?:必须|需要).{0,16}(?:用户)?确认.{0,24}(?:保存|写入|修改|记录)|(?:never|cannot|does not|doesn't|won't).{0,36}(?:save|write|modify|delete|official records?|goals?|strategies)|requires?.{0,24}(?:user\s+)?confirmation.{0,36}(?:save|write|modify|record)/i
    .test(value);
}
