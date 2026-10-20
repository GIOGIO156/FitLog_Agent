alter table public.ai_delivery_requests
  drop constraint if exists ai_delivery_requests_status_check;

alter table public.ai_delivery_requests
  add constraint ai_delivery_requests_status_check
  check (status in ('queued', 'running', 'succeeded', 'failed', 'cancelled'));

create or replace function public.retry_ai_delivery_request_v2(
  input_request_id uuid,
  input_account_id uuid,
  input_kind text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  request_row public.ai_delivery_requests%rowtype;
  now_utc timestamptz := timezone('utc', now());
begin
  if input_request_id is null
     or input_account_id is null
     or input_kind not in ('ai_chat', 'food_photo_analysis') then
    raise exception 'record_schema_mismatch';
  end if;

  select * into request_row
  from public.ai_delivery_requests
  where request_id = input_request_id
    and account_id = input_account_id
    and kind = input_kind
  for update;

  if request_row.request_id is null then
    raise exception 'record_schema_mismatch';
  end if;

  if request_row.status = 'cancelled' then
    raise exception 'provider_failure';
  end if;

  if request_row.status in ('queued', 'running', 'succeeded') then
    return to_jsonb(request_row);
  end if;

  if request_row.retryable = false
     or request_row.attempt_count >= request_row.max_attempts
     or request_row.expires_at <= now_utc then
    raise exception 'provider_failure';
  end if;

  update public.ai_delivery_requests
  set status = 'queued',
      error_code = null,
      failure_stage = null,
      lease_owner = null,
      lease_expires_at = null,
      completed_at = null,
      updated_at = now_utc
  where request_id = input_request_id
  returning * into request_row;

  return to_jsonb(request_row);
end;
$$;

revoke all on function public.retry_ai_delivery_request_v2(uuid, uuid, text)
from public, anon, authenticated;
grant execute on function public.retry_ai_delivery_request_v2(uuid, uuid, text)
to service_role;

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

  if request_row.status in ('succeeded', 'failed', 'cancelled') then
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

revoke all on function public.finish_ai_delivery_request(
  uuid, boolean, jsonb, text, text, boolean, text, integer, integer
) from public, anon, authenticated;
grant execute on function public.finish_ai_delivery_request(
  uuid, boolean, jsonb, text, text, boolean, text, integer, integer
) to service_role;

create or replace function public.soft_delete_ai_chat_session(input_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_account_id uuid := auth.uid();
  now_utc timestamptz := timezone('utc', now());
  updated_session_id uuid;
  cancelled_count integer := 0;
begin
  if current_account_id is null then
    raise exception 'auth_required';
  end if;

  update public.ai_chat_sessions
  set deleted_at = now_utc
  where id = input_session_id
    and account_id = current_account_id
    and deleted_at is null
  returning id into updated_session_id;

  if updated_session_id is null then
    raise exception 'record_schema_mismatch';
  end if;

  with cancelled as (
    update public.ai_delivery_requests
    set status = 'cancelled',
        retryable = false,
        error_code = 'cancelled',
        failure_stage = 'user_deleted_session',
        lease_owner = null,
        lease_expires_at = null,
        completed_at = coalesce(completed_at, now_utc),
        expires_at = least(expires_at, now_utc + interval '10 minutes')
    where account_id = current_account_id
      and session_id = input_session_id
      and kind = 'ai_chat'
      and status in ('queued', 'running', 'failed')
    returning 1
  )
  select count(*) into cancelled_count from cancelled;

  return jsonb_build_object(
    'ok', true,
    'session_id', updated_session_id,
    'deleted_at', now_utc,
    'cancelled_delivery_count', cancelled_count
  );
end;
$$;

revoke all on function public.soft_delete_ai_chat_session(uuid)
from public, anon, authenticated;
grant execute on function public.soft_delete_ai_chat_session(uuid)
to authenticated;

create or replace function public.fitlog_ai_delivery_apply_kind_expiry()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.kind = 'food_photo_analysis'
     and (
       new.expires_at is null
       or new.expires_at > new.accepted_at + interval '2 hours'
     ) then
    new.expires_at := new.accepted_at + interval '2 hours';
  end if;
  return new;
end;
$$;

drop trigger if exists ai_delivery_requests_apply_kind_expiry
on public.ai_delivery_requests;
create trigger ai_delivery_requests_apply_kind_expiry
before insert or update of kind, accepted_at, expires_at
on public.ai_delivery_requests
for each row execute function public.fitlog_ai_delivery_apply_kind_expiry();

create or replace function public.purge_expired_ai_delivery_requests(
  input_batch_limit integer default 100
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count integer := 0;
begin
  with expired as (
    select request_id
    from public.ai_delivery_requests
    where expires_at <= timezone('utc', now())
      and jsonb_array_length(coalesce(asset_refs_json, '[]'::jsonb)) = 0
    order by expires_at
    limit least(greatest(coalesce(input_batch_limit, 100), 1), 500)
  ),
  deleted_rows as (
    delete from public.ai_delivery_requests
    where request_id in (select request_id from expired)
    returning 1
  )
  select count(*) into deleted_count from deleted_rows;

  return deleted_count;
end;
$$;

revoke all on function public.purge_expired_ai_delivery_requests(integer)
from public, anon, authenticated;
grant execute on function public.purge_expired_ai_delivery_requests(integer)
to service_role;

create or replace function public.list_expired_ai_delivery_requests(
  input_batch_limit integer default 100
)
returns table(request_id uuid, asset_refs_json jsonb)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select r.request_id, coalesce(r.asset_refs_json, '[]'::jsonb)
  from public.ai_delivery_requests r
  where r.expires_at <= timezone('utc', now())
  order by r.expires_at
  limit least(greatest(coalesce(input_batch_limit, 100), 1), 500);
end;
$$;

revoke all on function public.list_expired_ai_delivery_requests(integer)
from public, anon, authenticated;
grant execute on function public.list_expired_ai_delivery_requests(integer)
to service_role;

create or replace function public.delete_expired_ai_delivery_request(
  input_request_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count integer := 0;
begin
  if input_request_id is null then
    raise exception 'record_schema_mismatch';
  end if;

  delete from public.ai_delivery_requests
  where request_id = input_request_id
    and expires_at <= timezone('utc', now());

  get diagnostics deleted_count = row_count;
  return deleted_count > 0;
end;
$$;

revoke all on function public.delete_expired_ai_delivery_request(uuid)
from public, anon, authenticated;
grant execute on function public.delete_expired_ai_delivery_request(uuid)
to service_role;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to service_role;

create table if not exists private.fitlog_runtime_settings (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default timezone('utc', now())
);

alter table private.fitlog_runtime_settings enable row level security;
revoke all on private.fitlog_runtime_settings from public, anon, authenticated;
grant select, insert, update, delete on private.fitlog_runtime_settings
to service_role;

create or replace function public.invoke_ai_delivery_workers()
returns void
language plpgsql
security definer
set search_path = public, private
as $$
declare
  functions_url text;
  worker_secret text;
  headers jsonb;
begin
  select nullif(trim(value), '') into functions_url
  from private.fitlog_runtime_settings
  where key = 'supabase_functions_url';

  select nullif(trim(value), '') into worker_secret
  from private.fitlog_runtime_settings
  where key = 'fitlog_ai_worker_secret';

  if functions_url is null then
    functions_url := nullif(
      trim(current_setting('app.settings.supabase_functions_url', true)),
      ''
    );
  end if;

  if worker_secret is null then
    worker_secret := nullif(
      trim(current_setting('app.settings.fitlog_ai_worker_secret', true)),
      ''
    );
  end if;

  if functions_url is null or worker_secret is null then
    return;
  end if;

  headers := jsonb_build_object(
    'content-type', 'application/json',
    'x-fitlog-worker-secret', worker_secret
  );

  execute
    'select net.http_post(url := $1, headers := $2, body := $3)'
  using
    functions_url || '/ai-chat-route',
    headers,
    jsonb_build_object('worker_action', 'cleanup_expired', 'limit', 100);

  execute
    'select net.http_post(url := $1, headers := $2, body := $3)'
  using
    functions_url || '/ai-chat-route',
    headers,
    jsonb_build_object('worker_action', 'process_pending', 'limit', 3);

  execute
    'select net.http_post(url := $1, headers := $2, body := $3)'
  using
    functions_url || '/ai-food-photo-analyze',
    headers,
    jsonb_build_object('worker_action', 'process_pending', 'limit', 3);
exception
  when invalid_schema_name or undefined_function then
    return;
end;
$$;

revoke all on function public.invoke_ai_delivery_workers()
from public, anon, authenticated;
grant execute on function public.invoke_ai_delivery_workers() to service_role;

do $$
begin
  create extension if not exists pg_net with schema extensions;
exception
  when insufficient_privilege or feature_not_supported or undefined_file then
    null;
end;
$$;

do $$
begin
  create extension if not exists pg_cron with schema extensions;
exception
  when insufficient_privilege or feature_not_supported or undefined_file then
    null;
end;
$$;

do $$
begin
  if exists (
    select 1
    from pg_namespace n
    join pg_proc p on p.pronamespace = n.oid
    where n.nspname = 'cron'
      and p.proname = 'schedule'
  ) then
    begin
      perform cron.unschedule('fitlog-ai-delivery-workers');
    exception
      when others then
        null;
    end;

    perform cron.schedule(
      'fitlog-ai-delivery-workers',
      '* * * * *',
      'select public.invoke_ai_delivery_workers();'
    );
  end if;
end;
$$;
