create extension if not exists pgcrypto;

alter table public.ai_request_logs
  add column if not exists client_request_id text;

create unique index if not exists idx_ai_request_logs_account_client_request
on public.ai_request_logs(account_id, client_request_id)
where client_request_id is not null;

create table if not exists public.ai_delivery_requests (
  request_id uuid primary key default gen_random_uuid(),
  account_id uuid not null references auth.users(id) on delete cascade,
  kind text not null,
  client_request_id text not null,
  status text not null default 'queued',
  session_id uuid,
  request_payload_json jsonb not null default '{}'::jsonb,
  asset_refs_json jsonb not null default '[]'::jsonb,
  result_json jsonb,
  error_code text,
  failure_stage text,
  retryable boolean not null default true,
  attempt_count integer not null default 0,
  max_attempts integer not null default 3,
  lease_owner text,
  claim_at timestamptz,
  lease_expires_at timestamptz,
  accepted_at timestamptz not null default timezone('utc', now()),
  completed_at timestamptz,
  expires_at timestamptz not null default timezone('utc', now()) + interval '72 hours',
  trace_id text,
  app_version text,
  edge_function_version text,
  provider text,
  provider_request_count integer not null default 0,
  client_image_count integer not null default 0,
  edge_asset_count integer not null default 0,
  provider_image_count integer not null default 0,
  duplicate_submit_count integer not null default 0,
  reclaimed_after_lease boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint ai_delivery_requests_account_client_kind_unique
    unique (account_id, kind, client_request_id),
  constraint ai_delivery_requests_session_account_fk
    foreign key (session_id, account_id)
    references public.ai_chat_sessions(id, account_id),
  constraint ai_delivery_requests_kind_check
    check (kind in ('ai_chat', 'food_photo_analysis')),
  constraint ai_delivery_requests_status_check
    check (status in ('queued', 'running', 'succeeded', 'failed')),
  constraint ai_delivery_requests_payload_object_check
    check (jsonb_typeof(request_payload_json) = 'object'),
  constraint ai_delivery_requests_assets_array_check
    check (jsonb_typeof(asset_refs_json) = 'array'),
  constraint ai_delivery_requests_result_object_check
    check (result_json is null or jsonb_typeof(result_json) = 'object'),
  constraint ai_delivery_requests_attempt_check
    check (attempt_count >= 0 and max_attempts between 1 and 5),
  constraint ai_delivery_requests_count_check
    check (
      provider_request_count >= 0
      and client_image_count >= 0
      and edge_asset_count >= 0
      and provider_image_count >= 0
      and duplicate_submit_count >= 0
    )
);

create index if not exists idx_ai_delivery_requests_account_status_updated
on public.ai_delivery_requests(account_id, status, updated_at desc);

create index if not exists idx_ai_delivery_requests_claim
on public.ai_delivery_requests(kind, status, lease_expires_at, accepted_at)
where status in ('queued', 'running');

drop trigger if exists ai_delivery_requests_touch_updated_at
on public.ai_delivery_requests;
create trigger ai_delivery_requests_touch_updated_at
before update on public.ai_delivery_requests
for each row execute function public.fitlog_touch_updated_at();

alter table public.ai_delivery_requests enable row level security;

drop policy if exists "ai_delivery_requests_select_own"
on public.ai_delivery_requests;
create policy "ai_delivery_requests_select_own"
on public.ai_delivery_requests
for select
using (auth.uid() = account_id);

revoke all on table public.ai_delivery_requests from public, anon, authenticated;
grant select on table public.ai_delivery_requests to authenticated;
grant all on table public.ai_delivery_requests to service_role;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
) values (
  'fitlog-ai-temp-assets',
  'fitlog-ai-temp-assets',
  false,
  12582912,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create or replace function public.accept_ai_delivery_request(
  input_request_id uuid,
  input_account_id uuid,
  input_kind text,
  input_client_request_id text,
  input_session_id uuid,
  input_request_payload_json jsonb,
  input_asset_refs_json jsonb,
  input_trace_id text default null,
  input_app_version text default null,
  input_edge_function_version text default null,
  input_client_image_count integer default 0,
  input_edge_asset_count integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_row public.ai_delivery_requests%rowtype;
  active_session_id uuid := input_session_id;
  payload jsonb := coalesce(input_request_payload_json, '{}'::jsonb);
  title_source text;
  next_request_id uuid := coalesce(input_request_id, gen_random_uuid());
  now_utc timestamptz := timezone('utc', now());
begin
  if input_account_id is null
     or input_kind not in ('ai_chat', 'food_photo_analysis')
     or trim(coalesce(input_client_request_id, '')) = ''
     or jsonb_typeof(payload) <> 'object'
     or jsonb_typeof(coalesce(input_asset_refs_json, '[]'::jsonb)) <> 'array'
     or coalesce(input_client_image_count, 0) < 0
     or coalesce(input_edge_asset_count, 0) < 0 then
    raise exception 'record_schema_mismatch';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(
      input_account_id::text || ':' || input_kind || ':' ||
        trim(input_client_request_id),
      0
    )
  );

  select * into existing_row
  from public.ai_delivery_requests
  where account_id = input_account_id
    and kind = input_kind
    and client_request_id = trim(input_client_request_id)
  for update;

  if existing_row.request_id is not null then
    update public.ai_delivery_requests
    set duplicate_submit_count = duplicate_submit_count + 1
    where request_id = existing_row.request_id;

    return jsonb_build_object(
      'request_id', existing_row.request_id,
      'kind', existing_row.kind,
      'status', existing_row.status,
      'session_id', existing_row.session_id,
      'result', existing_row.result_json,
      'error_code', existing_row.error_code,
      'retryable', existing_row.retryable,
      'duplicate_submit', true
    );
  end if;

  if input_kind = 'ai_chat' then
    if active_session_id is null then
      title_source := trim(coalesce(payload #>> '{message,text}', ''));
      if title_source = '' then
        title_source := 'AI request';
      end if;
      insert into public.ai_chat_sessions (
        account_id,
        title,
        language,
        last_message_at,
        created_at,
        updated_at
      ) values (
        input_account_id,
        left(title_source, 48),
        coalesce(nullif(trim(payload ->> 'language'), ''), 'zh'),
        now_utc,
        now_utc,
        now_utc
      )
      returning id into active_session_id;
    else
      select id into active_session_id
      from public.ai_chat_sessions
      where id = active_session_id
        and account_id = input_account_id
        and deleted_at is null
      for update;

      if active_session_id is null then
        raise exception 'record_schema_mismatch';
      end if;
    end if;
    payload := payload || jsonb_build_object('session_id', active_session_id);
  end if;

  insert into public.ai_delivery_requests (
    request_id,
    account_id,
    kind,
    client_request_id,
    status,
    session_id,
    request_payload_json,
    asset_refs_json,
    trace_id,
    app_version,
    edge_function_version,
    client_image_count,
    edge_asset_count,
    accepted_at,
    expires_at,
    created_at,
    updated_at
  ) values (
    next_request_id,
    input_account_id,
    input_kind,
    trim(input_client_request_id),
    'queued',
    active_session_id,
    payload,
    coalesce(input_asset_refs_json, '[]'::jsonb),
    nullif(trim(coalesce(input_trace_id, '')), ''),
    nullif(trim(coalesce(input_app_version, '')), ''),
    nullif(trim(coalesce(input_edge_function_version, '')), ''),
    coalesce(input_client_image_count, 0),
    coalesce(input_edge_asset_count, 0),
    now_utc,
    now_utc + interval '72 hours',
    now_utc,
    now_utc
  );

  return jsonb_build_object(
    'request_id', next_request_id,
    'kind', input_kind,
    'status', 'queued',
    'session_id', active_session_id,
    'result', null,
    'error_code', null,
    'retryable', true,
    'duplicate_submit', false
  );
end;
$$;

create or replace function public.claim_ai_delivery_request(
  input_kind text,
  input_request_id uuid default null,
  input_worker_id text default null,
  input_lease_seconds integer default 90
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  claimed_row public.ai_delivery_requests%rowtype;
  now_utc timestamptz := timezone('utc', now());
  lease_seconds integer := greatest(30, least(coalesce(input_lease_seconds, 90), 300));
begin
  if input_kind not in ('ai_chat', 'food_photo_analysis') then
    raise exception 'record_schema_mismatch';
  end if;

  select * into claimed_row
  from public.ai_delivery_requests
  where kind = input_kind
    and (input_request_id is null or request_id = input_request_id)
    and (
      status = 'queued'
      or (status = 'running' and lease_expires_at <= now_utc)
    )
    and attempt_count < max_attempts
    and expires_at > now_utc
  order by
    case when input_request_id is null then accepted_at else now_utc end asc
  for update skip locked
  limit 1;

  if claimed_row.request_id is null then
    return null;
  end if;

  update public.ai_delivery_requests
  set status = 'running',
      attempt_count = attempt_count + 1,
      claim_at = now_utc,
      lease_owner = coalesce(nullif(trim(input_worker_id), ''), gen_random_uuid()::text),
      lease_expires_at = now_utc + make_interval(secs => lease_seconds),
      reclaimed_after_lease = reclaimed_after_lease
        or (claimed_row.status = 'running' and claimed_row.lease_expires_at <= now_utc)
  where request_id = claimed_row.request_id
  returning * into claimed_row;

  return to_jsonb(claimed_row);
end;
$$;

create or replace function public.finish_ai_delivery_request(
  input_request_id uuid,
  input_succeeded boolean,
  input_result_json jsonb default null,
  input_error_code text default null,
  input_failure_stage text default null,
  input_retryable boolean default false,
  input_provider text default null,
  input_provider_request_count integer default 0,
  input_provider_image_count integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  request_row public.ai_delivery_requests%rowtype;
  next_status text;
  now_utc timestamptz := timezone('utc', now());
begin
  if input_request_id is null then
    raise exception 'record_schema_mismatch';
  end if;

  select * into request_row
  from public.ai_delivery_requests
  where request_id = input_request_id
  for update;

  if request_row.request_id is null then
    raise exception 'record_schema_mismatch';
  end if;

  if request_row.status = 'succeeded' or request_row.status = 'failed' then
    return to_jsonb(request_row);
  end if;

  if input_succeeded then
    next_status := 'succeeded';
  elsif coalesce(input_retryable, false)
        and request_row.attempt_count < request_row.max_attempts
        and request_row.expires_at > now_utc then
    next_status := 'queued';
  else
    next_status := 'failed';
  end if;

  update public.ai_delivery_requests
  set status = next_status,
      result_json = case when input_succeeded then input_result_json else result_json end,
      error_code = case when input_succeeded then null else nullif(trim(coalesce(input_error_code, '')), '') end,
      failure_stage = case when input_succeeded then null else nullif(trim(coalesce(input_failure_stage, '')), '') end,
      retryable = case when input_succeeded then false else coalesce(input_retryable, false) end,
      provider = nullif(trim(coalesce(input_provider, '')), ''),
      provider_request_count = provider_request_count + greatest(coalesce(input_provider_request_count, 0), 0),
      provider_image_count = greatest(provider_image_count, coalesce(input_provider_image_count, 0)),
      lease_owner = null,
      lease_expires_at = null,
      completed_at = case when next_status in ('succeeded', 'failed') then now_utc else completed_at end
  where request_id = input_request_id
  returning * into request_row;

  return to_jsonb(request_row);
end;
$$;

create or replace function public.retry_ai_delivery_request(
  input_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  request_row public.ai_delivery_requests%rowtype;
begin
  select * into request_row
  from public.ai_delivery_requests
  where request_id = input_request_id
    and account_id = auth.uid()
  for update;

  if request_row.request_id is null then
    raise exception 'record_schema_mismatch';
  end if;

  if request_row.status = 'succeeded' then
    return to_jsonb(request_row);
  end if;

  if request_row.retryable = false
     or request_row.attempt_count >= request_row.max_attempts
     or request_row.expires_at <= timezone('utc', now()) then
    raise exception 'provider_failure';
  end if;

  update public.ai_delivery_requests
  set status = 'queued',
      error_code = null,
      failure_stage = null,
      lease_owner = null,
      lease_expires_at = null
  where request_id = input_request_id
  returning * into request_row;

  return to_jsonb(request_row);
end;
$$;

revoke all on function public.accept_ai_delivery_request(
  uuid, uuid, text, text, uuid, jsonb, jsonb, text, text, text, integer, integer
) from public, anon, authenticated;
revoke all on function public.claim_ai_delivery_request(
  text, uuid, text, integer
) from public, anon, authenticated;
revoke all on function public.finish_ai_delivery_request(
  uuid, boolean, jsonb, text, text, boolean, text, integer, integer
) from public, anon, authenticated;
revoke all on function public.retry_ai_delivery_request(uuid)
from public, anon, authenticated;

grant execute on function public.accept_ai_delivery_request(
  uuid, uuid, text, text, uuid, jsonb, jsonb, text, text, text, integer, integer
) to service_role;
grant execute on function public.claim_ai_delivery_request(
  text, uuid, text, integer
) to service_role;
grant execute on function public.finish_ai_delivery_request(
  uuid, boolean, jsonb, text, text, boolean, text, integer, integer
) to service_role;
grant execute on function public.retry_ai_delivery_request(uuid)
to authenticated;

create or replace function public.record_ai_chat_turn_v3(
  input_account_id uuid,
  input_session_id uuid,
  input_message_text text,
  input_language text,
  input_model_choice text,
  input_workflow_type text,
  input_model_provider text,
  input_model text,
  input_prompt_version text,
  input_schema_version text,
  input_profile_version text default null,
  input_latency_ms integer default null,
  input_token_estimate integer default null,
  input_assistant_text text default null,
  input_final_answer_json jsonb default null,
  input_image_count integer default 0,
  input_resolved_clarification_id uuid default null,
  input_resolution_request_id text default null,
  input_pending_clarification_json jsonb default null,
  input_supersede_pending boolean default false,
  input_delivery_request_id uuid default null,
  input_client_request_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  trimmed_message text := trim(coalesce(input_message_text, ''));
  trimmed_assistant_text text := trim(coalesce(input_assistant_text, ''));
  effective_language text := trim(coalesce(input_language, 'zh'));
  effective_workflow text := coalesce(input_workflow_type, 'auto');
  effective_model text := nullif(trim(coalesce(input_model, '')), '');
  effective_prompt_version text := nullif(trim(coalesce(input_prompt_version, '')), '');
  effective_schema_version text := nullif(trim(coalesce(input_schema_version, '')), '');
  safe_image_count integer := coalesce(input_image_count, 0);
  safe_client_request_id text := nullif(trim(coalesce(input_client_request_id, '')), '');
  active_session_id uuid;
  request_id uuid := coalesce(input_delivery_request_id, gen_random_uuid());
  user_message_id uuid;
  assistant_message_id uuid;
  debug_summary_id uuid;
  existing_log public.ai_request_logs%rowtype;
  next_sequence integer;
  pending_id uuid;
  pending_kind text;
  pending_attachment_policy text;
  pending_options jsonb;
  pending_missing jsonb;
  pending_signature text;
  parent_signature text;
  parent_kind text;
  stored_final_answer_json jsonb;
  resolution_row public.ai_chat_clarifications%rowtype;
  now_utc timestamptz := timezone('utc', now());
begin
  if input_account_id is null then
    raise exception 'auth_required';
  end if;

  if safe_client_request_id is not null then
    select * into existing_log
    from public.ai_request_logs
    where account_id = input_account_id
      and client_request_id = safe_client_request_id
    for update;

    if existing_log.request_id is not null then
      select id into user_message_id
      from public.ai_chat_messages
      where account_id = input_account_id
        and request_id = existing_log.request_id
        and role = 'user'
      order by created_at, message_sequence, id
      limit 1;

      select id into assistant_message_id
      from public.ai_chat_messages
      where account_id = input_account_id
        and request_id = existing_log.request_id
        and role = 'assistant'
      order by created_at, message_sequence, id
      limit 1;

      select id into debug_summary_id
      from public.ai_debug_summaries
      where account_id = input_account_id
        and request_id = existing_log.request_id
      limit 1;

      if user_message_id is not null
         and assistant_message_id is not null
         and debug_summary_id is not null then
        select id into pending_id
        from public.ai_chat_clarifications
        where account_id = input_account_id
          and session_id = existing_log.session_id
          and origin_assistant_message_id = assistant_message_id
          and state in ('pending', 'resolving')
        order by created_at desc
        limit 1;

        return jsonb_build_object(
          'session_id', existing_log.session_id,
          'request_id', existing_log.request_id,
          'user_message_id', user_message_id,
          'assistant_message_id', assistant_message_id,
          'debug_summary_id', debug_summary_id,
          'clarification_id', pending_id,
          'duplicate_replay', true
        );
      end if;
    end if;
  end if;

  if trimmed_message = '' or trimmed_assistant_text = '' then
    raise exception 'record_schema_mismatch';
  end if;

  if effective_language = '' then
    raise exception 'record_schema_mismatch';
  end if;

  if input_model_choice not in ('chatgpt', 'qwen') then
    raise exception 'record_schema_mismatch';
  end if;

  if input_model_provider not in ('openai', 'qwen', 'mock') then
    raise exception 'record_schema_mismatch';
  end if;

  if effective_workflow not in (
    'auto',
    'food_logging',
    'workout_logging',
    'meal_decision',
    'weekly_review',
    'app_logic_answer',
    'general_chat',
    'safety_boundary'
  ) then
    raise exception 'record_schema_mismatch';
  end if;

  if input_latency_ms is not null and input_latency_ms < 0 then
    raise exception 'record_schema_mismatch';
  end if;

  if input_token_estimate is not null and input_token_estimate < 0 then
    raise exception 'record_schema_mismatch';
  end if;

  if safe_image_count < 0 then
    raise exception 'record_schema_mismatch';
  end if;

  if input_final_answer_json is not null
     and jsonb_typeof(input_final_answer_json) <> 'object' then
    raise exception 'record_schema_mismatch';
  end if;

  if input_resolved_clarification_id is not null then
    select * into resolution_row
    from public.ai_chat_clarifications
    where id = input_resolved_clarification_id
      and account_id = input_account_id
    for update;
    if resolution_row.id is null
       or resolution_row.state <> 'resolving'
       or resolution_row.resolution_request_id <>
          trim(coalesce(input_resolution_request_id, '')) then
      raise exception 'clarification_conflict';
    end if;
    if input_session_id is distinct from resolution_row.session_id then
      raise exception 'clarification_conflict';
    end if;
  end if;

  if coalesce(input_supersede_pending, false)
     and input_resolved_clarification_id is null
     and input_session_id is not null then
    update public.ai_chat_clarifications
    set state = 'superseded'
    where account_id = input_account_id
      and session_id = input_session_id
      and state in ('pending', 'resolving');
  end if;

  if input_session_id is null then
    insert into public.ai_chat_sessions (
      account_id,
      title,
      language,
      last_message_at,
      created_at,
      updated_at
    ) values (
      input_account_id,
      left(trimmed_message, 48),
      effective_language,
      now_utc,
      now_utc,
      now_utc
    )
    returning id into active_session_id;
  else
    select id
    into active_session_id
    from public.ai_chat_sessions
    where id = input_session_id
      and account_id = input_account_id
      and deleted_at is null
    for update;

    if active_session_id is null then
      raise exception 'record_schema_mismatch';
    end if;
  end if;

  select coalesce(max(message_sequence), 0) + 1
  into next_sequence
  from public.ai_chat_messages
  where session_id = active_session_id
    and account_id = input_account_id;

  insert into public.ai_request_logs (
    request_id,
    account_id,
    session_id,
    workflow_type,
    model_choice,
    model_provider,
    model,
    prompt_version,
    schema_version,
    profile_version,
    status,
    error_code,
    latency_ms,
    token_estimate,
    image_count,
    client_request_id,
    created_at
  ) values (
    request_id,
    input_account_id,
    active_session_id,
    effective_workflow,
    input_model_choice,
    input_model_provider,
    effective_model,
    effective_prompt_version,
    effective_schema_version,
    input_profile_version,
    'ok',
    null,
    input_latency_ms,
    input_token_estimate,
    safe_image_count,
    safe_client_request_id,
    now_utc
  );

  insert into public.ai_chat_messages (
    session_id,
    account_id,
    message_sequence,
    role,
    content_text,
    message_type,
    workflow_type,
    model_choice,
    model_provider,
    request_id,
    final_answer_json,
    attachments_metadata,
    created_at
  ) values (
    active_session_id,
    input_account_id,
    next_sequence,
    'user',
    trimmed_message,
    'text',
    effective_workflow,
    input_model_choice,
    input_model_provider,
    request_id,
    null,
    '[]'::jsonb,
    now_utc
  )
  returning id into user_message_id;

  insert into public.ai_chat_messages (
    session_id,
    account_id,
    message_sequence,
    role,
    content_text,
    message_type,
    workflow_type,
    model_choice,
    model_provider,
    request_id,
    final_answer_json,
    attachments_metadata,
    created_at
  ) values (
    active_session_id,
    input_account_id,
    next_sequence + 1,
    'assistant',
    trimmed_assistant_text,
    'text',
    effective_workflow,
    input_model_choice,
    input_model_provider,
    request_id,
    input_final_answer_json,
    '[]'::jsonb,
    now_utc
  )
  returning id into assistant_message_id;

  insert into public.ai_debug_summaries (
    request_id,
    account_id,
    session_id,
    intent,
    intent_confidence,
    called_tools_json,
    retrieved_dimensions_json,
    missing_dimensions_json,
    safety_flags_json,
    schema_validation_status,
    user_final_action,
    created_at
  ) values (
    request_id,
    input_account_id,
    active_session_id,
    effective_workflow,
    null,
    jsonb_build_array(input_model_provider),
    '[]'::jsonb,
    case
      when input_final_answer_json is null then '[]'::jsonb
      else jsonb_build_array('artifact_review')
    end,
    '[]'::jsonb,
    'passed',
    case
      when input_final_answer_json is null then 'read_only'
      else 'artifact_returned'
    end,
    now_utc
  )
  returning id into debug_summary_id;

  update public.ai_chat_sessions
  set last_message_at = now_utc,
      title = case
        when trim(title) = '' then left(trimmed_message, 48)
        else title
      end
  where id = active_session_id
    and account_id = input_account_id;

  if input_pending_clarification_json is not null then
    if jsonb_typeof(input_pending_clarification_json) <> 'object' then
      raise exception 'record_schema_mismatch';
    end if;
    pending_kind := input_pending_clarification_json ->> 'kind';
    pending_attachment_policy := coalesce(
      input_pending_clarification_json ->> 'attachment_policy',
      'none'
    );
    pending_options := coalesce(
      input_pending_clarification_json -> 'options',
      '[]'::jsonb
    );
    pending_missing := coalesce(
      input_pending_clarification_json -> 'missing_dimensions',
      '[]'::jsonb
    );
    if pending_kind not in ('intent_selection', 'missing_business_fields')
       or pending_attachment_policy not in (
         'none',
         'consume_current',
         'runtime_rebind_available',
         'resend_required'
       )
       or jsonb_typeof(pending_options) <> 'array'
       or jsonb_array_length(pending_options) = 0
       or jsonb_typeof(pending_missing) <> 'array' then
      raise exception 'record_schema_mismatch';
    end if;

    pending_signature := encode(
      digest(
        pending_kind || '|' || pending_options::text || '|' ||
        pending_missing::text,
        'sha256'
      ),
      'hex'
    );
    if input_resolved_clarification_id is not null then
      select progress_signature, kind into parent_signature, parent_kind
      from public.ai_chat_clarifications
      where id = input_resolved_clarification_id;
      if parent_signature = pending_signature
         or pending_kind = 'intent_selection'
         or (
           parent_kind = 'missing_business_fields'
           and pending_kind = 'missing_business_fields'
         ) then
        raise exception 'clarification_no_progress';
      end if;
    end if;

    update public.ai_chat_clarifications
    set state = 'superseded'
    where account_id = input_account_id
      and session_id = active_session_id
      and state in ('pending', 'resolving');

    insert into public.ai_chat_clarifications (
      account_id,
      session_id,
      origin_user_message_id,
      origin_assistant_message_id,
      parent_clarification_id,
      kind,
      options_json,
      missing_dimensions_json,
      attachment_policy,
      progress_signature,
      expires_at
    ) values (
      input_account_id,
      active_session_id,
      user_message_id,
      assistant_message_id,
      input_resolved_clarification_id,
      pending_kind,
      pending_options,
      pending_missing,
      pending_attachment_policy,
      pending_signature,
      now_utc + interval '24 hours'
    ) returning id into pending_id;

    update public.ai_chat_messages
    set final_answer_json = coalesce(final_answer_json, '{}'::jsonb) ||
      jsonb_build_object(
        'clarification',
        input_pending_clarification_json || jsonb_build_object(
          'clarification_id', pending_id,
          'schema_version', 'ai_chat_clarification.v2',
          'expires_at', now_utc + interval '24 hours'
        )
      )
    where id = assistant_message_id
      and account_id = input_account_id;
  end if;

  select final_answer_json into stored_final_answer_json
  from public.ai_chat_messages
  where id = assistant_message_id;

  if input_resolved_clarification_id is not null then
    update public.ai_chat_clarifications
    set state = 'resolved',
        resolved_at = now_utc,
        resolution_result_json = jsonb_build_object(
          'turn', jsonb_build_object(
            'session_id', active_session_id,
            'request_id', request_id,
            'user_message_id', user_message_id,
            'assistant_message_id', assistant_message_id,
            'debug_summary_id', debug_summary_id,
            'user_message_sequence', next_sequence,
            'assistant_message_sequence', next_sequence + 1
          ),
          'assistant_text', input_assistant_text,
          'final_answer_json', stored_final_answer_json,
          'workflow', input_workflow_type,
          'model_choice', input_model_choice,
          'model_provider', input_model_provider,
          'pending_clarification_id', pending_id
        )
    where id = input_resolved_clarification_id;
  end if;

  return jsonb_build_object(
    'session_id', active_session_id,
    'request_id', request_id,
    'user_message_id', user_message_id,
    'assistant_message_id', assistant_message_id,
    'debug_summary_id', debug_summary_id,
    'user_message_sequence', next_sequence,
    'assistant_message_sequence', next_sequence + 1,
    'clarification_id', pending_id
  );
end;
$$;

revoke all on function public.record_ai_chat_turn_v3(
  uuid, uuid, text, text, text, text, text, text, text, text,
  text, integer, integer, text, jsonb, integer, uuid, text, jsonb, boolean,
  uuid, text
) from public, anon, authenticated;

grant execute on function public.record_ai_chat_turn_v3(
  uuid, uuid, text, text, text, text, text, text, text, text,
  text, integer, integer, text, jsonb, integer, uuid, text, jsonb, boolean,
  uuid, text
) to service_role;
