import type { NormalizedRagQuery, RetrievalCandidate } from "./types.ts";

export type CoverageStatus = "complete" | "partial" | "insufficient" | "conflicting";

export interface RetrievalCoverage {
  status: CoverageStatus;
  missing_dimensions: string[];
  covered_concepts: string[];
}

export function assessRetrievalCoverage(
  query: NormalizedRagQuery,
  candidates: RetrievalCandidate[],
  requiredDimensions: string[] = ["document_context"],
): RetrievalCoverage {
  if (candidates.length === 0) {
    return {
      status: "insufficient",
      missing_dimensions: requiredDimensions,
      covered_concepts: [],
    };
  }
  const usable = candidates.filter((candidate) =>
    candidate.authority === "current_product" &&
    ["implemented", "evidence", "non_goal"].includes(candidate.status)
  );
  const haystacks = usable.map((candidate) =>
    normalizeEvidence(`${candidate.heading} ${candidate.content}`)
  );
  const coveredConcepts = query.canonical_concepts.filter((concept) => {
    const evidenceTerms = query.concept_evidence_terms[concept] ?? [concept];
    return evidenceTerms.some((term) =>
      haystacks.some((haystack) => haystack.includes(normalizeEvidence(term)))
    );
  });
  const exerciseCovered = query.exercise_keys.length === 0 ||
    query.exercise_keys.every((key) => {
      const terms = [key, ...query.exercise_mentions];
      return terms.some((term) =>
        haystacks.some((haystack) =>
          haystack.includes(normalizeEvidence(term))
        )
      );
    });
  const identifiersCovered = query.technical_identifiers.every((identifier) =>
    haystacks.some((haystack) =>
      haystack.includes(normalizeEvidence(identifier))
    )
  );
  const contradictoryStatus = usable.some((candidate) => candidate.status === "implemented") && usable.some((candidate) => candidate.status === "non_goal" && candidate.heading.toLowerCase() === usable[0].heading.toLowerCase());
  if (contradictoryStatus) return { status: "conflicting", missing_dimensions: ["resolved_source_authority"], covered_concepts: coveredConcepts };
  const missing = [];
  if (usable.length === 0) missing.push("current_product_evidence");
  if (coveredConcepts.length < query.canonical_concepts.length) missing.push("canonical_concepts");
  if (!exerciseCovered) missing.push("exercise_definition");
  if (!identifiersCovered) missing.push("technical_identifiers");
  if (missing.length === 0) return { status: "complete", missing_dimensions: [], covered_concepts: coveredConcepts };
  return { status: usable.length > 0 ? "partial" : "insufficient", missing_dimensions: missing, covered_concepts: coveredConcepts };
}

function normalizeEvidence(value: string): string {
  return value.normalize("NFKC").toLowerCase().replace(/[\s\u3000]+/g, " ")
    .trim();
}
