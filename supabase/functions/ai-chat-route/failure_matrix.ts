export type RagFailureCode =
  | "query_normalization_failed"
  | "embedding_unavailable"
  | "vector_index_unavailable"
  | "lexical_search_unavailable"
  | "reranker_degraded"
  | "retrieval_retry_invalid"
  | "document_context_unavailable"
  | "structured_context_unavailable"
  | "provider_failure"
  | "logging_failed"
  | "grounding_failed";

export interface RagFailurePolicy {
  mayContinue: boolean;
  downgrade: string;
  userLimitationRequired: boolean;
}

export const ragFailureMatrix: Record<RagFailureCode, RagFailurePolicy> = {
  query_normalization_failed: { mayContinue: false, downgrade: "clarification", userLimitationRequired: true },
  embedding_unavailable: { mayContinue: true, downgrade: "lexical_only", userLimitationRequired: false },
  vector_index_unavailable: { mayContinue: true, downgrade: "lexical_only", userLimitationRequired: false },
  lexical_search_unavailable: { mayContinue: true, downgrade: "vector_only_if_coverage_complete", userLimitationRequired: true },
  reranker_degraded: { mayContinue: true, downgrade: "fused_order", userLimitationRequired: false },
  retrieval_retry_invalid: { mayContinue: true, downgrade: "stop_after_first_search", userLimitationRequired: true },
  document_context_unavailable: { mayContinue: true, downgrade: "general_knowledge_only", userLimitationRequired: true },
  structured_context_unavailable: { mayContinue: true, downgrade: "named_missing_dimension", userLimitationRequired: true },
  provider_failure: { mayContinue: false, downgrade: "stable_error", userLimitationRequired: true },
  logging_failed: { mayContinue: true, downgrade: "answer_without_optional_log", userLimitationRequired: false },
  grounding_failed: { mayContinue: false, downgrade: "correction_then_stable_error", userLimitationRequired: true },
};
