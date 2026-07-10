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
}

export interface Phase5WorkflowRoute {
  workflow: "auto" | "food_logging" | "meal_decision" | "weekly_review" | "app_logic_answer";
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
}

export interface Phase5Evidence {
  workflow: string;
  context_objects: string[];
  document_sources: Phase5DocumentSource[];
  missing_dimensions: string[];
  safety_flags: string[];
  user_final_action: "read_only" | "artifact_returned" | "blocked" | "none";
}
