create or replace function public.record_ai_mock_chat_turn(
  input_account_id uuid,
  input_session_id uuid,
  input_message_text text,
  input_language text,
  input_model_choice text,
  input_workflow_type text,
  input_profile_version text default null,
  input_latency_ms integer default null,
  input_token_estimate integer default null,
  input_assistant_text text default 'This is a FitLog AI mock reply. Your text message was received.'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  trimmed_message text := trim(coalesce(input_message_text, ''));
  effective_language text := trim(coalesce(input_language, 'zh'));
  effective_workflow text := coalesce(input_workflow_type, 'auto');
  active_session_id uuid;
  request_id uuid;
  user_message_id uuid;
  assistant_message_id uuid;
  debug_summary_id uuid;
  next_sequence integer;
  now_utc timestamptz := timezone('utc', now());
begin
  if input_account_id is null then
    raise exception 'auth_required';
  end if;

  if trimmed_message = '' then
    raise exception 'record_schema_mismatch';
  end if;

  if effective_language = '' then
    raise exception 'record_schema_mismatch';
  end if;

  if input_model_choice not in ('chatgpt', 'qwen') then
    raise exception 'record_schema_mismatch';
  end if;

  if effective_workflow not in (
    'auto',
    'food_logging',
    'meal_decision',
    'weekly_review',
    'app_logic_answer'
  ) then
    raise exception 'record_schema_mismatch';
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
    created_at
  ) values (
    input_account_id,
    active_session_id,
    effective_workflow,
    input_model_choice,
    'mock',
    'mock-provider-v1',
    'mock_prompt_v1',
    'ai_chat_response.v1',
    input_profile_version,
    'ok',
    null,
    input_latency_ms,
    input_token_estimate,
    0,
    now_utc
  )
  returning ai_request_logs.request_id into request_id;

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
    'mock',
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
    input_assistant_text,
    'text',
    effective_workflow,
    input_model_choice,
    'mock',
    request_id,
    null,
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
    jsonb_build_array('mock_provider'),
    '[]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    'passed',
    'read_only',
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

  return jsonb_build_object(
    'session_id', active_session_id,
    'request_id', request_id,
    'user_message_id', user_message_id,
    'assistant_message_id', assistant_message_id,
    'debug_summary_id', debug_summary_id,
    'user_message_sequence', next_sequence,
    'assistant_message_sequence', next_sequence + 1
  );
end;
$$;

revoke all on function public.record_ai_mock_chat_turn(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  text,
  integer,
  integer,
  text
) from public, anon, authenticated;

grant execute on function public.record_ai_mock_chat_turn(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  text,
  integer,
  integer,
  text
) to service_role;
