create or replace function public.rename_ai_chat_session(
  input_session_id uuid,
  input_title text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_account_id uuid := auth.uid();
  trimmed_title text := trim(coalesce(input_title, ''));
  now_utc timestamptz := timezone('utc', now());
  updated_session_id uuid;
  updated_title text;
begin
  if current_account_id is null then
    raise exception 'auth_required';
  end if;

  if trimmed_title = '' or char_length(trimmed_title) > 80 then
    raise exception 'record_schema_mismatch';
  end if;

  update public.ai_chat_sessions
  set title = trimmed_title,
      updated_at = now_utc
  where id = input_session_id
    and account_id = current_account_id
    and deleted_at is null
  returning id, title into updated_session_id, updated_title;

  if updated_session_id is null then
    raise exception 'record_schema_mismatch';
  end if;

  return jsonb_build_object(
    'ok', true,
    'session_id', updated_session_id,
    'title', updated_title
  );
end;
$$;

revoke all on function public.rename_ai_chat_session(uuid, text)
from public, anon, authenticated;

grant execute on function public.rename_ai_chat_session(uuid, text)
to authenticated;
