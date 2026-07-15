alter table public.ai_request_logs add column if not exists surface text;
alter table public.ai_request_logs add column if not exists capability text;
alter table public.ai_request_logs add column if not exists provider_adapter_version text;
alter table public.ai_request_logs add column if not exists policy_version text;
alter table public.ai_request_logs add column if not exists target_response_language text;
alter table public.ai_request_logs add column if not exists language_validation_status text;
alter table public.ai_request_logs add column if not exists task_plan_version text;
alter table public.ai_request_logs add column if not exists task_plan_source text;
alter table public.ai_request_logs add column if not exists task_plan_confidence real;
alter table public.ai_request_logs add column if not exists planned_workflow text;
alter table public.ai_request_logs add column if not exists requested_context_types_json jsonb not null default '[]'::jsonb;
alter table public.ai_request_logs add column if not exists approved_context_types_json jsonb not null default '[]'::jsonb;
alter table public.ai_request_logs add column if not exists rejected_context_types_json jsonb not null default '[]'::jsonb;
alter table public.ai_request_logs add column if not exists query_language_profile text;
alter table public.ai_request_logs add column if not exists canonical_concept_ids_json jsonb not null default '[]'::jsonb;
alter table public.ai_request_logs add column if not exists corpus_id text;
alter table public.ai_request_logs add column if not exists corpus_build_id text;
alter table public.ai_request_logs add column if not exists embedding_model text;
alter table public.ai_request_logs add column if not exists reranker_version text;
alter table public.ai_request_logs add column if not exists retrieval_branch_counts_json jsonb not null default '{}'::jsonb;
alter table public.ai_request_logs add column if not exists retrieval_final_hit_count integer;
alter table public.ai_request_logs add column if not exists retrieval_coverage_status text;
alter table public.ai_request_logs add column if not exists retrieval_missing_dimensions_json jsonb not null default '[]'::jsonb;
alter table public.ai_request_logs add column if not exists retrieval_retry_reason text;
alter table public.ai_request_logs add column if not exists retrieval_retry_count integer not null default 0;
alter table public.ai_request_logs add column if not exists retrieval_retry_gain boolean;
alter table public.ai_request_logs add column if not exists retrieval_issue_codes_json jsonb not null default '[]'::jsonb;
alter table public.ai_request_logs add column if not exists planner_latency_ms integer;
alter table public.ai_request_logs add column if not exists retrieval_latency_ms integer;
alter table public.ai_request_logs add column if not exists correction_latency_ms integer;
alter table public.ai_request_logs add column if not exists prompt_context_bytes integer;
alter table public.ai_request_logs add column if not exists grounding_validation_status text;
alter table public.ai_request_logs add column if not exists grounding_issue_codes_json jsonb not null default '[]'::jsonb;
alter table public.ai_request_logs add column if not exists food_fact_count integer;
alter table public.ai_request_logs add column if not exists food_conflict_count integer;
alter table public.ai_request_logs add column if not exists semantic_validation_status text;
alter table public.ai_request_logs add column if not exists semantic_issue_codes_json jsonb not null default '[]'::jsonb;
alter table public.ai_request_logs add column if not exists final_action text;

alter table public.ai_request_logs drop constraint if exists ai_request_logs_workflow_check;
alter table public.ai_request_logs add constraint ai_request_logs_workflow_check check (
  workflow_type in ('auto', 'food_logging', 'workout_logging', 'meal_decision', 'weekly_review', 'app_logic_answer', 'general_chat', 'safety_boundary')
);
alter table public.ai_chat_messages drop constraint if exists ai_chat_messages_workflow_check;
alter table public.ai_chat_messages add constraint ai_chat_messages_workflow_check check (
  workflow_type in ('auto', 'food_logging', 'workout_logging', 'meal_decision', 'weekly_review', 'app_logic_answer', 'general_chat', 'safety_boundary')
);

alter table public.ai_request_logs drop constraint if exists ai_request_logs_retrieval_retry_count_check;
alter table public.ai_request_logs add constraint ai_request_logs_retrieval_retry_count_check check (retrieval_retry_count between 0 and 1);
alter table public.ai_request_logs drop constraint if exists ai_request_logs_nonnegative_rag_metrics_check;
alter table public.ai_request_logs add constraint ai_request_logs_nonnegative_rag_metrics_check check (
  coalesce(retrieval_final_hit_count, 0) >= 0 and coalesce(planner_latency_ms, 0) >= 0 and
  coalesce(retrieval_latency_ms, 0) >= 0 and coalesce(correction_latency_ms, 0) >= 0 and
  coalesce(prompt_context_bytes, 0) >= 0 and coalesce(food_fact_count, 0) >= 0 and
  coalesce(food_conflict_count, 0) >= 0
);

comment on column public.ai_request_logs.canonical_concept_ids_json is
  'Bounded reviewed concept IDs only; never raw query text, custom exercise names, or history rows.';
comment on column public.ai_request_logs.retrieval_issue_codes_json is
  'Privacy-safe issue codes; never raw provider output, context objects, images, secrets, or chain-of-thought.';
