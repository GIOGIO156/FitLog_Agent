export type RagLanguageProfile = "zh" | "en" | "mixed";

export interface NormalizedRagQuery {
  raw_query: string;
  normalized_query: string;
  language_profile: { value: RagLanguageProfile; confidence: number };
  protected_phrases: string[];
  technical_identifiers: string[];
  tokens: string[];
  canonical_concepts: string[];
  concept_evidence_terms: Record<string, string[]>;
  internal_values: string[];
  translations: string[];
  exercise_mentions: string[];
  exercise_keys: string[];
  query_variants: string[];
  term_dictionary_version: string;
}

export interface RetrievalCandidate {
  id: string;
  build_id: string;
  language: "zh" | "en";
  doc_path: string;
  heading: string;
  heading_path: string[];
  section_id: string;
  chunk_index: number;
  chunk_count: number;
  content: string;
  context_prefix: string;
  tags: string[];
  status: string;
  authority: string;
  lexical_score: number;
  exact_score: number;
  term_score: number;
  full_text_score: number;
  trigram_score: number;
  vector_score: number | null;
  lexical_rank: number | null;
  vector_rank: number | null;
  matched_terms: string[];
  matched_fields: string[];
  fused_score?: number;
  rerank_score?: number;
}

export interface RetrievalIssue {
  code:
    | "embedding_unavailable"
    | "hybrid_rpc_unavailable"
    | "reranker_degraded";
}

export interface RetrievalDebugSummary {
  pipeline_version: "rag_foundation_v1";
  reranker_version: string;
  branch_hits: {
    exact: number;
    terms: number;
    full_text: number;
    trigram: number;
    lexical: number;
    vector: number;
  };
  candidates_before_dedupe: number;
  candidates_after_dedupe: number;
  final_hits: number;
  elimination_reasons: { below_minimum_score: number };
  issues: RetrievalIssue["code"][];
  latency: RetrievalAttemptLatency;
}

export interface RetrievalAttemptLatency {
  total_ms: number;
  normalization_ms: number;
  embedding_ms: number | null;
  lexical_candidate_rpc_ms: number | null;
  hybrid_rpc_ms: number;
  reranker_ms: number;
  embedding_status:
    | "not_configured"
    | "completed"
    | "unavailable";
  embedding_input_chars: number;
  query_variant_count: number;
}

export interface RetrievalResult {
  query: NormalizedRagQuery;
  candidates: RetrievalCandidate[];
  debug: RetrievalDebugSummary;
}
