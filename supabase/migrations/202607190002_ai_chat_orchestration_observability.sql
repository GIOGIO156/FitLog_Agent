alter table public.ai_request_logs
  add column if not exists decision_version text,
  add column if not exists decision_source text,
  add column if not exists decision_reason text,
  add column if not exists selected_capability text,
  add column if not exists clarification_id uuid,
  add column if not exists clarification_state text,
  add column if not exists clarification_attempt integer,
  add column if not exists attachment_policy text,
  add column if not exists failure_class text,
  add column if not exists write_guard_reason text;
alter table public.ai_request_logs
  add column if not exists decision_shadow_mismatch text;

alter table public.ai_request_logs
  drop constraint if exists ai_request_logs_decision_source_check,
  add constraint ai_request_logs_decision_source_check check (
    decision_source is null or decision_source in (
      'clarification_reply', 'fixed_entry', 'deterministic', 'model'
    )
  ),
  drop constraint if exists ai_request_logs_clarification_state_check,
  add constraint ai_request_logs_clarification_state_check check (
    clarification_state is null or clarification_state in (
      'pending', 'resolving', 'resolved', 'superseded', 'cancelled', 'expired'
    )
  ),
  drop constraint if exists ai_request_logs_clarification_attempt_check,
  add constraint ai_request_logs_clarification_attempt_check check (
    clarification_attempt is null or clarification_attempt >= 0
  ),
  drop constraint if exists ai_request_logs_attachment_policy_check,
  add constraint ai_request_logs_attachment_policy_check check (
    attachment_policy is null or attachment_policy in (
      'none', 'consume_current', 'runtime_rebind_available', 'resend_required'
    )
  );

comment on column public.ai_request_logs.decision_version is
  'Provider-neutral orchestration decision contract version.';
comment on column public.ai_request_logs.decision_reason is
  'One compact reason code; never raw user or provider text.';
comment on column public.ai_request_logs.write_guard_reason is
  'Compact write-claim guard reason; never raw provider output.';
