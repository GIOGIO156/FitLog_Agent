create table if not exists public.workout_plan_commits (
  account_id uuid not null references auth.users(id) on delete cascade,
  mutation_id text not null,
  operation text not null,
  target_plan_id text not null,
  payload_hash text not null,
  status text not null default 'pending',
  result_session_ids uuid[] not null default '{}',
  committed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (account_id, mutation_id),
  constraint workout_plan_commits_operation_check
    check (operation in ('create', 'replace_plan', 'replace_session')),
  constraint workout_plan_commits_status_check
    check (status in ('pending', 'committed', 'abandoned')),
  constraint workout_plan_commits_payload_hash_check
    check (payload_hash ~ '^[0-9a-f]{64}$')
);

alter table public.workout_plan_commits enable row level security;

drop policy if exists "workout_plan_commits_select_own"
on public.workout_plan_commits;
create policy "workout_plan_commits_select_own"
on public.workout_plan_commits
for select
using (auth.uid() = account_id);

revoke all on table public.workout_plan_commits from anon, authenticated;

create or replace function public._workout_plan_commit_result_v1(
  input_account_id uuid,
  input_mutation_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  commit_row public.workout_plan_commits%rowtype;
  session_rows jsonb;
begin
  select *
  into commit_row
  from public.workout_plan_commits
  where account_id = input_account_id
    and mutation_id = input_mutation_id;

  if commit_row.account_id is null then
    return jsonb_build_object('status', 'not_found');
  end if;
  if commit_row.status = 'abandoned' then
    return jsonb_build_object(
      'status', 'abandoned',
      'mutation_id', commit_row.mutation_id
    );
  end if;
  if commit_row.status <> 'committed' then
    return jsonb_build_object('status', 'not_found');
  end if;

  select coalesce(
    jsonb_agg(
      (to_jsonb(session_row) - 'account_id') ||
      jsonb_build_object(
        'workout_sets',
        coalesce(
          (
            select jsonb_agg(
              to_jsonb(set_row) - 'account_id'
              order by set_row.set_number, set_row.created_at, set_row.id
            )
            from public.workout_sets set_row
            where set_row.workout_session_id = session_row.id
          ),
          '[]'::jsonb
        )
      )
      order by array_position(commit_row.result_session_ids, session_row.id)
    ),
    '[]'::jsonb
  )
  into session_rows
  from public.workout_sessions session_row
  where session_row.account_id = input_account_id
    and session_row.id = any(commit_row.result_session_ids);

  return jsonb_build_object(
    'status', 'committed',
    'mutation_id', commit_row.mutation_id,
    'target_plan_id', commit_row.target_plan_id,
    'payload_hash', commit_row.payload_hash,
    'committed_at', commit_row.committed_at,
    'sessions', session_rows
  );
end;
$$;

create or replace function public.get_workout_plan_commit_v1(
  input_mutation_id text,
  input_device_id text,
  input_session_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_account_id uuid := auth.uid();
  active_row public.account_active_devices%rowtype;
begin
  if current_account_id is null then
    raise exception 'auth_required';
  end if;

  select *
  into active_row
  from public.account_active_devices
  where account_id = current_account_id;

  if active_row.account_id is null
     or active_row.active_device_id is distinct from input_device_id
     or active_row.active_session_id is distinct from input_session_id then
    raise exception 'device_replaced';
  end if;

  update public.account_active_devices
  set last_seen_at = timezone('utc', now())
  where account_id = current_account_id;

  return public._workout_plan_commit_result_v1(
    current_account_id,
    input_mutation_id
  );
end;
$$;

create or replace function public.abandon_workout_plan_commit_v1(
  input_mutation_id text,
  input_operation text,
  input_target_plan_id text,
  input_payload_hash text,
  input_device_id text,
  input_session_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_account_id uuid := auth.uid();
  active_row public.account_active_devices%rowtype;
  existing_commit public.workout_plan_commits%rowtype;
begin
  if current_account_id is null then
    raise exception 'auth_required';
  end if;
  if input_mutation_id is null
     or length(input_mutation_id) < 8
     or length(input_mutation_id) > 160 then
    raise exception 'workout_commit_invalid_mutation_id';
  end if;
  if input_operation is null
     or input_operation not in ('create', 'replace_plan', 'replace_session') then
    raise exception 'workout_commit_invalid_operation';
  end if;
  if input_target_plan_id is null
     or length(input_target_plan_id) < 1
     or length(input_target_plan_id) > 160 then
    raise exception 'workout_commit_invalid_plan_id';
  end if;
  if input_payload_hash is null
     or input_payload_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'workout_commit_invalid_payload_hash';
  end if;

  select *
  into active_row
  from public.account_active_devices
  where account_id = current_account_id;

  if active_row.account_id is null
     or active_row.active_device_id is distinct from input_device_id
     or active_row.active_session_id is distinct from input_session_id then
    raise exception 'device_replaced';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(current_account_id::text || ':' || input_mutation_id, 0)
  );

  select *
  into existing_commit
  from public.workout_plan_commits
  where account_id = current_account_id
    and mutation_id = input_mutation_id;

  if existing_commit.account_id is not null then
    if existing_commit.payload_hash is distinct from input_payload_hash then
      raise exception 'idempotency_conflict';
    end if;
    if existing_commit.status = 'committed' then
      return public._workout_plan_commit_result_v1(
        current_account_id,
        input_mutation_id
      );
    end if;
    update public.workout_plan_commits
    set status = 'abandoned',
        updated_at = timezone('utc', now())
    where account_id = current_account_id
      and mutation_id = input_mutation_id;
  else
    insert into public.workout_plan_commits (
      account_id,
      mutation_id,
      operation,
      target_plan_id,
      payload_hash,
      status
    ) values (
      current_account_id,
      input_mutation_id,
      input_operation,
      input_target_plan_id,
      input_payload_hash,
      'abandoned'
    );
  end if;

  update public.account_active_devices
  set last_seen_at = timezone('utc', now())
  where account_id = current_account_id;

  return jsonb_build_object(
    'status', 'abandoned',
    'mutation_id', input_mutation_id
  );
end;
$$;

create or replace function public.commit_workout_plan_v1(
  input_mutation_id text,
  input_operation text,
  input_target_plan_id text,
  input_source_plan_id text,
  input_source_session_id uuid,
  input_payload_hash text,
  input_sessions jsonb,
  input_device_id text,
  input_session_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_account_id uuid := auth.uid();
  active_row public.account_active_devices%rowtype;
  existing_commit public.workout_plan_commits%rowtype;
  session_payload jsonb;
  set_payload jsonb;
  created_session_id uuid;
  created_session_ids uuid[] := '{}';
begin
  if current_account_id is null then
    raise exception 'auth_required';
  end if;
  if input_mutation_id is null
     or length(input_mutation_id) < 8
     or length(input_mutation_id) > 160 then
    raise exception 'workout_commit_invalid_mutation_id';
  end if;
  if input_operation is null
     or input_operation not in ('create', 'replace_plan', 'replace_session') then
    raise exception 'workout_commit_invalid_operation';
  end if;
  if input_target_plan_id is null
     or length(input_target_plan_id) < 1
     or length(input_target_plan_id) > 160 then
    raise exception 'workout_commit_invalid_plan_id';
  end if;
  if input_payload_hash is null
     or input_payload_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'workout_commit_invalid_payload_hash';
  end if;
  if input_sessions is null
     or jsonb_typeof(input_sessions) <> 'array'
     or jsonb_array_length(input_sessions) < 1
     or jsonb_array_length(input_sessions) > 64 then
    raise exception 'workout_commit_invalid_sessions';
  end if;
  if input_operation = 'replace_plan'
     and nullif(trim(input_source_plan_id), '') is null then
    raise exception 'workout_commit_source_plan_required';
  end if;
  if input_operation = 'replace_session'
     and input_source_session_id is null then
    raise exception 'workout_commit_source_session_required';
  end if;

  select *
  into active_row
  from public.account_active_devices
  where account_id = current_account_id;

  if active_row.account_id is null
     or active_row.active_device_id is distinct from input_device_id
     or active_row.active_session_id is distinct from input_session_id then
    raise exception 'device_replaced';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(current_account_id::text || ':' || input_mutation_id, 0)
  );

  select *
  into existing_commit
  from public.workout_plan_commits
  where account_id = current_account_id
    and mutation_id = input_mutation_id;

  if existing_commit.account_id is not null then
    if existing_commit.payload_hash is distinct from input_payload_hash then
      raise exception 'idempotency_conflict';
    end if;
    if existing_commit.status = 'committed' then
      return public._workout_plan_commit_result_v1(
        current_account_id,
        input_mutation_id
      );
    end if;
    if existing_commit.status = 'abandoned' then
      return jsonb_build_object(
        'status', 'abandoned',
        'mutation_id', input_mutation_id,
        'code', 'workout_commit_abandoned'
      );
    end if;
  else
    insert into public.workout_plan_commits (
      account_id,
      mutation_id,
      operation,
      target_plan_id,
      payload_hash,
      status
    ) values (
      current_account_id,
      input_mutation_id,
      input_operation,
      input_target_plan_id,
      input_payload_hash,
      'pending'
    );
  end if;

  if input_operation = 'replace_plan' then
    update public.workout_sessions
    set deleted_at = timezone('utc', now())
    where account_id = current_account_id
      and plan_id = input_source_plan_id
      and deleted_at is null;
  elsif input_operation = 'replace_session' then
    update public.workout_sessions
    set deleted_at = timezone('utc', now())
    where account_id = current_account_id
      and id = input_source_session_id
      and deleted_at is null;
  end if;

  for session_payload in
    select value from jsonb_array_elements(input_sessions)
  loop
    if nullif(trim(session_payload->>'date'), '') is null
       or nullif(trim(session_payload->>'body_part'), '') is null
       or nullif(trim(session_payload->>'exercise_name'), '') is null
       or nullif(trim(session_payload->>'exercise_type'), '') is null then
      raise exception 'workout_commit_invalid_session';
    end if;
    if coalesce(jsonb_typeof(session_payload->'workout_sets'), 'array') <> 'array'
       or jsonb_array_length(coalesce(session_payload->'workout_sets', '[]'::jsonb)) > 512 then
      raise exception 'workout_commit_invalid_sets';
    end if;

    insert into public.workout_sessions (
      account_id,
      plan_id,
      record_name,
      date,
      body_part,
      secondary_body_part,
      exercise_name,
      exercise_key,
      exercise_source,
      exercise_type,
      duration_minutes,
      intensity,
      strength_profile,
      load_input_mode,
      reps_input_mode,
      set_metric_type,
      cardio_met,
      cardio_intensity_basis,
      cardio_active_minutes,
      body_weight_kg_at_calculation,
      exercise_snapshot_json,
      estimated_calories,
      notes
    ) values (
      current_account_id,
      input_target_plan_id,
      nullif(session_payload->>'record_name', ''),
      (session_payload->>'date')::date,
      session_payload->>'body_part',
      nullif(session_payload->>'secondary_body_part', ''),
      session_payload->>'exercise_name',
      nullif(session_payload->>'exercise_key', ''),
      nullif(session_payload->>'exercise_source', ''),
      session_payload->>'exercise_type',
      coalesce((session_payload->>'duration_minutes')::integer, 0),
      coalesce(nullif(session_payload->>'intensity', ''), 'moderate'),
      nullif(session_payload->>'strength_profile', ''),
      nullif(session_payload->>'load_input_mode', ''),
      nullif(session_payload->>'reps_input_mode', ''),
      nullif(session_payload->>'set_metric_type', ''),
      (session_payload->>'cardio_met')::numeric,
      nullif(session_payload->>'cardio_intensity_basis', ''),
      (session_payload->>'cardio_active_minutes')::integer,
      (session_payload->>'body_weight_kg_at_calculation')::numeric,
      nullif(session_payload->>'exercise_snapshot_json', ''),
      coalesce((session_payload->>'estimated_calories')::numeric, 0),
      coalesce(session_payload->>'notes', '')
    )
    returning id into created_session_id;

    created_session_ids := array_append(
      created_session_ids,
      created_session_id
    );

    for set_payload in
      select value
      from jsonb_array_elements(
        coalesce(session_payload->'workout_sets', '[]'::jsonb)
      )
    loop
      insert into public.workout_sets (
        account_id,
        workout_session_id,
        set_number,
        weight_kg,
        reps,
        input_weight_kg,
        input_reps,
        input_duration_seconds,
        calculation_load_kg,
        calculation_reps,
        load_input_mode,
        reps_input_mode,
        set_metric_type,
        is_completed,
        completed_at
      ) values (
        current_account_id,
        created_session_id,
        (set_payload->>'set_number')::integer,
        coalesce((set_payload->>'weight_kg')::numeric, 0),
        coalesce((set_payload->>'reps')::integer, 0),
        (set_payload->>'input_weight_kg')::numeric,
        (set_payload->>'input_reps')::integer,
        (set_payload->>'input_duration_seconds')::integer,
        (set_payload->>'calculation_load_kg')::numeric,
        (set_payload->>'calculation_reps')::integer,
        nullif(set_payload->>'load_input_mode', ''),
        nullif(set_payload->>'reps_input_mode', ''),
        nullif(set_payload->>'set_metric_type', ''),
        coalesce((set_payload->>'is_completed')::boolean, false),
        nullif(set_payload->>'completed_at', '')
      );
    end loop;
  end loop;

  update public.workout_plan_commits
  set status = 'committed',
      result_session_ids = created_session_ids,
      committed_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  where account_id = current_account_id
    and mutation_id = input_mutation_id;

  update public.account_active_devices
  set last_seen_at = timezone('utc', now())
  where account_id = current_account_id;

  return public._workout_plan_commit_result_v1(
    current_account_id,
    input_mutation_id
  );
end;
$$;

revoke all on function public._workout_plan_commit_result_v1(uuid, text)
from public, anon, authenticated;
revoke all on function public.commit_workout_plan_v1(
  text, text, text, text, uuid, text, jsonb, text, text
) from public, anon;
revoke all on function public.get_workout_plan_commit_v1(text, text, text)
from public, anon;
revoke all on function public.abandon_workout_plan_commit_v1(
  text, text, text, text, text, text
) from public, anon;

grant execute on function public.commit_workout_plan_v1(
  text, text, text, text, uuid, text, jsonb, text, text
) to authenticated;
grant execute on function public.get_workout_plan_commit_v1(text, text, text)
to authenticated;
grant execute on function public.abandon_workout_plan_commit_v1(
  text, text, text, text, text, text
) to authenticated;
