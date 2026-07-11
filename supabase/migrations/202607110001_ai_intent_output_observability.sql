alter table public.ai_request_logs
  add column if not exists intent_resolution_source text,
  add column if not exists selected_output_type text,
  add column if not exists validation_issue_codes_json jsonb not null default '[]'::jsonb;

alter table public.ai_request_logs
  drop constraint if exists ai_request_logs_expected_output_check;

alter table public.ai_request_logs
  add constraint ai_request_logs_expected_output_check
  check (
    expected_output is null or
    expected_output in ('auto', 'text', 'food_draft', 'workout_draft')
  );

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'ai_request_logs_intent_resolution_source_check'
      and conrelid = 'public.ai_request_logs'::regclass
  ) then
    alter table public.ai_request_logs
      add constraint ai_request_logs_intent_resolution_source_check
      check (
        intent_resolution_source is null or
        intent_resolution_source in ('fixed_workflow', 'deterministic', 'model')
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'ai_request_logs_selected_output_type_check'
      and conrelid = 'public.ai_request_logs'::regclass
  ) then
    alter table public.ai_request_logs
      add constraint ai_request_logs_selected_output_type_check
      check (
        selected_output_type is null or
        selected_output_type in ('text', 'food_draft', 'workout_draft', 'clarification')
      );
  end if;
end
$$;

comment on column public.ai_request_logs.intent_resolution_source is
  'How output intent was selected: fixed workflow, deterministic high-confidence resolver, or model selection after resolver abstention.';
comment on column public.ai_request_logs.selected_output_type is
  'Validated provider output_type; null when no provider result passed validation.';
comment on column public.ai_request_logs.validation_issue_codes_json is
  'Privacy-safe validation issue categories; never contains raw provider output or user content.';
