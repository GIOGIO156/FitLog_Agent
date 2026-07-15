create or replace function public.record_ai_chat_turn(
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
  input_image_count integer default 0
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

revoke all on function public.record_ai_chat_turn(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  integer,
  integer,
  text,
  jsonb,
  integer
) from public, anon, authenticated;

grant execute on function public.record_ai_chat_turn(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  integer,
  integer,
  text,
  jsonb,
  integer
) to service_role;
