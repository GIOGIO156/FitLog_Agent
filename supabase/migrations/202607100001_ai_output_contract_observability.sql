alter table public.ai_request_logs
  add column if not exists expected_output text,
  add column if not exists validator_version text,
  add column if not exists first_pass_validation_status text,
  add column if not exists correction_attempt_count integer not null default 0,
  add column if not exists final_validation_status text,
  add column if not exists provider_completion_status text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'ai_request_logs_expected_output_check'
      and conrelid = 'public.ai_request_logs'::regclass
  ) then
    alter table public.ai_request_logs
      add constraint ai_request_logs_expected_output_check
      check (expected_output is null or expected_output in ('text', 'food_draft', 'workout_draft'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'ai_request_logs_correction_attempt_count_check'
      and conrelid = 'public.ai_request_logs'::regclass
  ) then
    alter table public.ai_request_logs
      add constraint ai_request_logs_correction_attempt_count_check
      check (correction_attempt_count between 0 and 1);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'ai_request_logs_first_pass_validation_status_check'
      and conrelid = 'public.ai_request_logs'::regclass
  ) then
    alter table public.ai_request_logs
      add constraint ai_request_logs_first_pass_validation_status_check
      check (
        first_pass_validation_status is null or
        first_pass_validation_status in ('not_attempted', 'passed', 'failed', 'blocked')
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'ai_request_logs_final_validation_status_check'
      and conrelid = 'public.ai_request_logs'::regclass
  ) then
    alter table public.ai_request_logs
      add constraint ai_request_logs_final_validation_status_check
      check (
        final_validation_status is null or
        final_validation_status in ('not_attempted', 'passed', 'failed', 'blocked')
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'ai_request_logs_provider_completion_status_check'
      and conrelid = 'public.ai_request_logs'::regclass
  ) then
    alter table public.ai_request_logs
      add constraint ai_request_logs_provider_completion_status_check
      check (
        provider_completion_status is null or
        provider_completion_status in ('not_called', 'completed', 'refusal', 'incomplete')
      );
  end if;
end
$$;

comment on column public.ai_request_logs.expected_output is
  'Server-resolved provider output family; never accepted from the client.';
comment on column public.ai_request_logs.validator_version is
  'Strict output validator version used for the request.';
comment on column public.ai_request_logs.first_pass_validation_status is
  'Compact first provider attempt validation result without raw provider output.';
comment on column public.ai_request_logs.correction_attempt_count is
  'Bounded schema-correction attempt count; current maximum is one.';
comment on column public.ai_request_logs.final_validation_status is
  'Final output-contract validation result.';
comment on column public.ai_request_logs.provider_completion_status is
  'Provider completion category: completed, refusal, incomplete, or not_called.';
