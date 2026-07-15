import type { OutputValidationIssue } from "../../_shared/ai_output_contract.ts";
import type { GatewayRequest } from "../contracts.ts";
import { normalizeRagQuery } from "../rag/query_normalizer.ts";

export const groundingValidatorVersion = "fitlog_grounding_guard.v2";

export interface ApprovedEvidenceEntry {
  id: string;
  kind: "document" | "context" | "deterministic_rule";
  status: string;
}

export function approvedEvidenceRegistry(request: GatewayRequest): ApprovedEvidenceEntry[] {
  const entries: ApprovedEvidenceEntry[] = [];
  for (const source of request.phase5Context?.document_sources ?? []) {
    entries.push({ id: `doc:${source.section_id}`, kind: "document", status: source.status });
  }
  for (const context of request.phase5Context?.context_objects ?? []) {
    entries.push({ id: `context:${context.type}`, kind: "context", status: "implemented" });
  }
  entries.push({ id: "rule:no_official_write_without_confirmation", kind: "deterministic_rule", status: "implemented" });
  return entries;
}

export function validateGroundedText(text: string, request: GatewayRequest): OutputValidationIssue[] {
  if (!isFitLogClaim(text)) return [];
  const registry = approvedEvidenceRegistry(request);
  const usable = registry.filter((entry) => ["implemented", "evidence"].includes(entry.status));
  if (usable.length === 0) return [{ path: "$.message.text", reason: "fitlog_claim_without_approved_evidence" }];
  const documentSources = (request.phase5Context?.document_sources ?? [])
    .filter((source) => ["implemented", "evidence"].includes(source.status))
    .filter((source) => source.authority === undefined || source.authority === "current_product")
    .filter((source) => source.doc_path === "README.md" || source.doc_path.includes(`/docs/${request.language}/`) || source.doc_path.includes(`docs/${request.language}/`));
  const structured = request.phase5Context?.context_objects ?? [];
  const normalizedClaim = normalizeRagQuery(text);
  const evidenceText = [
    ...documentSources.map((source) => `${source.heading} ${source.context_prefix} ${source.excerpt}`),
    ...structured.map((context) => JSON.stringify(context.data)),
  ].join("\n").toLowerCase();
  const normalizedEvidence = normalizeRagQuery(evidenceText);
  const missingConcept = normalizedClaim.canonical_concepts.some((concept) =>
    !normalizedEvidence.canonical_concepts.includes(concept)
  ) || normalizedClaim.exercise_keys.some((key) =>
    !normalizedEvidence.exercise_keys.includes(key)
  );
  if (missingConcept) {
    return [{ path: "$.message.text", reason: "fitlog_claim_exceeds_matching_evidence" }];
  }
  const onlyBoundaryRule = usable.every((entry) => entry.id === "rule:no_official_write_without_confirmation");
  if (onlyBoundaryRule && !/确认|保存|写入|confirm|save|write/i.test(text)) return [{ path: "$.message.text", reason: "fitlog_claim_without_matching_evidence" }];
  if ((request.phase5Context?.missing_dimensions.length ?? 0) > 0 && /一定|必然|always|definitely/i.test(text)) return [{ path: "$.message.text", reason: "missing_dimension_not_disclosed" }];
  return [];
}

function isFitLogClaim(value: string): boolean {
  return /FitLog|本应用|系统(?:会|使用|规定|默认)|(?:规则|算法|数据库|source of truth)(?:是|为|会)|FitLog's|the app (?:uses|will|always)/i.test(value);
}
