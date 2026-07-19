create table if not exists public.ai_chat_clarifications (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid not null,
  origin_user_message_id uuid not null references public.ai_chat_messages(id)
    on delete cascade,
  origin_assistant_message_id uuid not null references public.ai_chat_messages(id)
    on delete cascade,
  parent_clarification_id uuid references public.ai_chat_clarifications(id),
  schema_version text not null default 'ai_chat_clarification.v2',
  kind text not null,
  options_json jsonb not null default '[]'::jsonb,
  missing_dimensions_json jsonb not null default '[]'::jsonb,
  attachment_policy text not null default 'none',
  progress_signature text not null,
  state text not null default 'pending',
  attempt_count integer not null default 0,
  resolution_request_id text,
  resolving_started_at timestamptz,
  resolved_option_id text,
  resolution_result_json jsonb,
  expires_at timestamptz not null,
  resolved_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint ai_chat_clarifications_session_account_fk
    foreign key (session_id, account_id)
    references public.ai_chat_sessions(id, account_id)
    on delete cascade,
  constraint ai_chat_clarifications_schema_check
    check (schema_version = 'ai_chat_clarification.v2'),
  constraint ai_chat_clarifications_kind_check
    check (kind in ('intent_selection', 'missing_business_fields')),
  constraint ai_chat_clarifications_options_array_check
    check (jsonb_typeof(options_json) = 'array'),
  constraint ai_chat_clarifications_missing_array_check
    check (jsonb_typeof(missing_dimensions_json) = 'array'),
  constraint ai_chat_clarifications_attachment_policy_check
    check (attachment_policy in (
      'none',
      'consume_current',
      'runtime_rebind_available',
      'resend_required'
    )),
  constraint ai_chat_clarifications_state_check
    check (state in (
      'pending',
      'resolving',
      'resolved',
      'superseded',
      'cancelled',
      'expired'
    )),
  constraint ai_chat_clarifications_attempt_check
    check (attempt_count >= 0),
  constraint ai_chat_clarifications_progress_not_blank
    check (length(trim(progress_signature)) > 0)
);

create unique index if not exists idx_ai_chat_clarifications_one_active_session
on public.ai_chat_clarifications(session_id)
where state in ('pending', 'resolving');

create index if not exists idx_ai_chat_clarifications_account_session_created
on public.ai_chat_clarifications(account_id, session_id, created_at desc);

create index if not exists idx_ai_chat_clarifications_expiry
on public.ai_chat_clarifications(state, expires_at)
where state in ('pending', 'resolving');

drop trigger if exists ai_chat_clarifications_touch_updated_at
on public.ai_chat_clarifications;
create trigger ai_chat_clarifications_touch_updated_at
before update on public.ai_chat_clarifications
for each row execute function public.fitlog_touch_updated_at();

alter table public.ai_chat_clarifications enable row level security;

drop policy if exists "ai_chat_clarifications_select_own"
on public.ai_chat_clarifications;
create policy "ai_chat_clarifications_select_own"
on public.ai_chat_clarifications
for select
using (
  auth.uid() = account_id
  and exists (
    select 1
    from public.ai_chat_sessions sessions
    where sessions.id = ai_chat_clarifications.session_id
      and sessions.account_id = ai_chat_clarifications.account_id
      and sessions.deleted_at is null
  )
);

revoke all on table public.ai_chat_clarifications from public, anon, authenticated;
grant select on table public.ai_chat_clarifications to authenticated;
grant all on table public.ai_chat_clarifications to service_role;

create or replace function public.claim_ai_chat_clarification(
  input_account_id uuid,
  input_session_id uuid,
  input_clarification_id uuid,
  input_option_id text,
  input_client_request_id text,
  input_attachment_available boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  clarification_row public.ai_chat_clarifications%rowtype;
  selected_option jsonb;
  origin_message text;
  now_utc timestamptz := timezone('utc', now());
begin
  if input_account_id is null
     or input_session_id is null
     or input_clarification_id is null
     or trim(coalesce(input_option_id, '')) = ''
     or trim(coalesce(input_client_request_id, '')) = '' then
    raise exception 'record_schema_mismatch';
  end if;

  select * into clarification_row
  from public.ai_chat_clarifications
  where id = input_clarification_id
    and account_id = input_account_id
    and session_id = input_session_id
  for update;

  if clarification_row.id is null then
    raise exception 'clarification_conflict';
  end if;

  if clarification_row.state = 'resolving'
     and clarification_row.resolution_result_json is null
     and clarification_row.resolving_started_at < now_utc - interval '30 seconds' then
    update public.ai_chat_clarifications
    set state = 'pending',
        resolution_request_id = null,
        resolved_option_id = null,
        resolving_started_at = null
    where id = clarification_row.id;
    select * into clarification_row
    from public.ai_chat_clarifications
    where id = input_clarification_id
    for update;
  end if;

  if clarification_row.state in ('pending', 'resolving')
     and clarification_row.expires_at <= now_utc then
    update public.ai_chat_clarifications
    set state = 'expired'
    where id = clarification_row.id;
    raise exception 'clarification_expired';
  end if;

  if clarification_row.state = 'resolved'
     and clarification_row.resolution_request_id = input_client_request_id
     and clarification_row.resolved_option_id = input_option_id then
    return jsonb_build_object(
      'status', 'resolved_replay',
      'clarification_id', clarification_row.id,
      'cached_result', clarification_row.resolution_result_json
    );
  end if;

  if clarification_row.state = 'resolving'
     and clarification_row.resolution_request_id = input_client_request_id
     and clarification_row.resolved_option_id = input_option_id then
    return jsonb_build_object(
      'status', 'resolution_in_progress',
      'clarification_id', clarification_row.id
    );
  elsif clarification_row.state <> 'pending' then
    raise exception 'clarification_conflict';
  end if;

  select value into selected_option
  from jsonb_array_elements(clarification_row.options_json)
  where value ->> 'id' = input_option_id
  limit 1;

  if selected_option is null then
    raise exception 'clarification_conflict';
  end if;

  if clarification_row.attachment_policy in (
       'runtime_rebind_available',
       'resend_required'
     ) and coalesce(input_attachment_available, false) = false then
    raise exception 'attachment_unavailable';
  end if;

  if clarification_row.state = 'pending' then
    update public.ai_chat_clarifications
    set state = 'resolving',
        attempt_count = attempt_count + 1,
        resolution_request_id = input_client_request_id,
        resolved_option_id = input_option_id,
        resolving_started_at = now_utc
    where id = clarification_row.id;
  end if;

  select content_text into origin_message
  from public.ai_chat_messages
  where id = clarification_row.origin_user_message_id
    and account_id = input_account_id
    and session_id = input_session_id;

  return jsonb_build_object(
    'status', 'claimed',
    'clarification_id', clarification_row.id,
    'option_id', input_option_id,
    'resulting_output', selected_option ->> 'resulting_output',
    'resulting_workflow', selected_option ->> 'resulting_workflow',
    'origin_message_text', origin_message,
    'attachment_policy', clarification_row.attachment_policy,
    'attempt_count', clarification_row.attempt_count +
      case when clarification_row.state = 'pending' then 1 else 0 end
  );
end;
$$;

create or replace function public.release_ai_chat_clarification(
  input_account_id uuid,
  input_clarification_id uuid,
  input_client_request_id text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.ai_chat_clarifications
  set state = case
        when expires_at <= timezone('utc', now()) then 'expired'
        else 'pending'
      end,
      resolution_request_id = null,
      resolved_option_id = null,
      resolving_started_at = null
  where id = input_clarification_id
    and account_id = input_account_id
    and state = 'resolving'
    and resolution_request_id = input_client_request_id;
  return found;
end;
$$;

create or replace function public.record_ai_chat_turn_v2(
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
  input_supersede_pending boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  turn_result jsonb;
  active_session_id uuid;
  user_message_id uuid;
  assistant_message_id uuid;
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

  turn_result := public.record_ai_chat_turn(
    input_account_id => input_account_id,
    input_session_id => input_session_id,
    input_message_text => input_message_text,
    input_language => input_language,
    input_model_choice => input_model_choice,
    input_workflow_type => input_workflow_type,
    input_model_provider => input_model_provider,
    input_model => input_model,
    input_prompt_version => input_prompt_version,
    input_schema_version => input_schema_version,
    input_profile_version => input_profile_version,
    input_latency_ms => input_latency_ms,
    input_token_estimate => input_token_estimate,
    input_assistant_text => input_assistant_text,
    input_final_answer_json => input_final_answer_json,
    input_image_count => input_image_count
  );

  active_session_id := (turn_result ->> 'session_id')::uuid;
  user_message_id := (turn_result ->> 'user_message_id')::uuid;
  assistant_message_id := (turn_result ->> 'assistant_message_id')::uuid;

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
          'turn', turn_result,
          'assistant_text', input_assistant_text,
          'final_answer_json', stored_final_answer_json,
          'workflow', input_workflow_type,
          'model_choice', input_model_choice,
          'model_provider', input_model_provider,
          'pending_clarification_id', pending_id
        )
    where id = input_resolved_clarification_id;
  end if;

  return turn_result || jsonb_build_object('clarification_id', pending_id);
end;
$$;

revoke all on function public.claim_ai_chat_clarification(
  uuid, uuid, uuid, text, text, boolean
) from public, anon, authenticated;
revoke all on function public.release_ai_chat_clarification(
  uuid, uuid, text
) from public, anon, authenticated;
revoke all on function public.record_ai_chat_turn_v2(
  uuid, uuid, text, text, text, text, text, text, text, text,
  text, integer, integer, text, jsonb, integer, uuid, text, jsonb, boolean
) from public, anon, authenticated;

grant execute on function public.claim_ai_chat_clarification(
  uuid, uuid, uuid, text, text, boolean
) to service_role;
grant execute on function public.release_ai_chat_clarification(
  uuid, uuid, text
) to service_role;
grant execute on function public.record_ai_chat_turn_v2(
  uuid, uuid, text, text, text, text, text, text, text, text,
  text, integer, integer, text, jsonb, integer, uuid, text, jsonb, boolean
) to service_role;
