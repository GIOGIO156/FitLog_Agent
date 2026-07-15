export interface Phase5ContextObject {
  type: string;
  version: "v1";
  language: "zh" | "en";
  date_range: { start: string; end: string } | null;
  source: string;
  data: Record<string, unknown>;
  missing: string[];
  privacy: {
    contains_raw_records: false;
    contains_images: false;
    contains_user_free_text_notes: false;
  };
}

export interface Phase5DocumentSource {
  doc_path: string;
  heading: string;
  heading_path: string[];
  section_id: string;
  chunk_index: number;
  chunk_count: number;
  status: string;
  score: number;
  context_prefix: string;
  context_note: string | null;
  excerpt: string;
  authority?: string;
  retrieval_attempt?: 1 | 2;
  coverage_status?: "complete" | "partial" | "insufficient" | "conflicting";
}

export interface Phase5WorkflowRoute {
  workflow:
    | "auto"
    | "food_logging"
    | "workout_logging"
    | "meal_decision"
    | "weekly_review"
    | "app_logic_answer"
    | "general_chat"
    | "safety_boundary";
  confidence: number | null;
  reasons: string[];
  required_context: string[];
  safety_flags: string[];
  read_only: boolean;
}

export interface Phase5ContextBundle {
  route: Phase5WorkflowRoute;
  context_objects: Phase5ContextObject[];
  document_sources: Phase5DocumentSource[];
  called_tools: string[];
  retrieved_dimensions: string[];
  missing_dimensions: string[];
  safety_flags: string[];
  retrieval_debug?: Phase5RetrievalDebug | null;
}

export interface Phase5RetrievalDebug {
  pipeline_version: "rag_foundation_v1";
  query_language_profile: "zh" | "en" | "mixed";
  canonical_concept_ids: string[];
  corpus_id: string;
  corpus_build_id: string | null;
  embedding_model: string | null;
  reranker_version: string;
  branch_hits: {
    exact: number;
    terms: number;
    full_text: number;
    trigram: number;
    lexical: number;
    vector: number;
  };
  final_hit_count: number;
  first_coverage_status:
    | "complete"
    | "partial"
    | "insufficient"
    | "conflicting";
  first_missing_dimensions: string[];
  coverage_status: "complete" | "partial" | "insufficient" | "conflicting";
  missing_dimensions: string[];
  retry_reason: string | null;
  retry_count: 0 | 1;
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
  retry_gain: boolean;
  issue_codes: string[];
  latency_breakdown: {
    attempts: Array<{
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
    }>;
    rewrite_planner_ms: number | null;
  };
}

export interface Phase5Evidence {
  workflow: string;
  context_objects: string[];
  document_sources: Phase5DocumentSource[];
  missing_dimensions: string[];
  safety_flags: string[];
  user_final_action: "read_only" | "artifact_returned" | "blocked" | "none";
}
