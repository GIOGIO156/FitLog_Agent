create extension if not exists pgcrypto;

create table if not exists public.account_active_devices (
  account_id uuid primary key references auth.users(id) on delete cascade,
  active_device_id text not null,
  active_session_id text not null,
  platform text,
  app_version text,
  claimed_at timestamptz not null default timezone('utc', now()),
  last_seen_at timestamptz not null default timezone('utc', now()),
  replaced_at timestamptz,
  replaced_reason text
);

alter table public.account_active_devices enable row level security;

drop policy if exists "account_active_devices_select_own" on public.account_active_devices;
create policy "account_active_devices_select_own"
on public.account_active_devices
for select
using (auth.uid() = account_id);

drop policy if exists "account_active_devices_insert_own" on public.account_active_devices;
create policy "account_active_devices_insert_own"
on public.account_active_devices
for insert
with check (auth.uid() = account_id);

drop policy if exists "account_active_devices_update_own" on public.account_active_devices;
create policy "account_active_devices_update_own"
on public.account_active_devices
for update
using (auth.uid() = account_id)
with check (auth.uid() = account_id);

create or replace function public.claim_active_device(
  input_device_id text,
  input_session_id text,
  input_platform text default null,
  input_app_version text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  current_account_id uuid := auth.uid();
begin
  if current_account_id is null then
    raise exception 'auth_required';
  end if;

  insert into public.account_active_devices (
    account_id,
    active_device_id,
    active_session_id,
    platform,
    app_version,
    claimed_at,
    last_seen_at,
    replaced_at,
    replaced_reason
  )
  values (
    current_account_id,
    input_device_id,
    input_session_id,
    input_platform,
    input_app_version,
    timezone('utc', now()),
    timezone('utc', now()),
    null,
    null
  )
  on conflict (account_id) do update set
    active_device_id = excluded.active_device_id,
    active_session_id = excluded.active_session_id,
    platform = excluded.platform,
    app_version = excluded.app_version,
    claimed_at = excluded.claimed_at,
    last_seen_at = excluded.last_seen_at,
    replaced_at = timezone('utc', now()),
    replaced_reason = 'last_login_wins';

  return jsonb_build_object('ok', true, 'code', 'ok');
end;
$$;

create or replace function public.assert_active_device(
  input_device_id text,
  input_session_id text
)
returns jsonb
language plpgsql
security invoker
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
    return jsonb_build_object('ok', false, 'code', 'device_replaced');
  end if;

  update public.account_active_devices
  set last_seen_at = timezone('utc', now())
  where account_id = current_account_id;

  return jsonb_build_object('ok', true, 'code', 'ok');
end;
$$;

create or replace function public.release_active_device(
  input_device_id text,
  input_session_id text
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  current_account_id uuid := auth.uid();
begin
  if current_account_id is null then
    return jsonb_build_object('ok', true, 'code', 'signed_out');
  end if;

  update public.account_active_devices
  set replaced_at = timezone('utc', now()),
      replaced_reason = 'signed_out',
      active_session_id = input_session_id || ':released'
  where account_id = current_account_id
    and active_device_id = input_device_id
    and active_session_id = input_session_id;

  return jsonb_build_object('ok', true, 'code', 'released');
end;
$$;

create or replace function public.fitlog_touch_record_version()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc', now());
  new.record_version = coalesce(old.record_version, 0) + 1;
  return new;
end;
$$;

create table if not exists public.body_metric_logs (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date date not null,
  weight_kg numeric not null,
  body_fat_percent numeric,
  waist_cm numeric,
  source text not null default 'manual',
  record_version integer not null default 1,
  deleted_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique(account_id, date)
);

create table if not exists public.food_records (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date date not null,
  meal_name text not null,
  total_weight_g numeric not null default 0,
  calories_kcal numeric not null default 0,
  protein_g numeric not null default 0,
  carbs_g numeric not null default 0,
  fat_g numeric not null default 0,
  confidence numeric,
  estimation_notes text not null default '',
  source text not null default 'manual',
  record_version integer not null default 1,
  deleted_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.food_items (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  food_record_id uuid not null references public.food_records(id) on delete cascade,
  name text not null,
  estimated_weight_g numeric not null default 0,
  calories_kcal numeric not null default 0,
  protein_g numeric not null default 0,
  carbs_g numeric not null default 0,
  fat_g numeric not null default 0,
  notes text not null default '',
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  plan_id text,
  record_name text,
  date date not null,
  body_part text not null,
  secondary_body_part text,
  exercise_name text not null,
  exercise_key text,
  exercise_source text,
  exercise_type text not null,
  duration_minutes integer not null default 0,
  intensity text not null default 'moderate',
  strength_profile text,
  load_input_mode text,
  reps_input_mode text,
  set_metric_type text,
  cardio_met numeric,
  cardio_intensity_basis text,
  cardio_active_minutes integer,
  body_weight_kg_at_calculation numeric,
  exercise_snapshot_json text,
  estimated_calories numeric not null default 0,
  notes text not null default '',
  record_version integer not null default 1,
  deleted_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.workout_sets (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  workout_session_id uuid not null references public.workout_sessions(id) on delete cascade,
  set_number integer not null,
  weight_kg numeric not null default 0,
  reps integer not null default 0,
  input_weight_kg numeric,
  input_reps integer,
  input_duration_seconds integer,
  calculation_load_kg numeric,
  calculation_reps integer,
  load_input_mode text,
  reps_input_mode text,
  set_metric_type text,
  is_completed boolean not null default false,
  completed_at text,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.daily_summaries (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date date not null,
  summary_json jsonb not null,
  record_version integer not null default 1,
  source_updated_at timestamptz,
  profile_version integer,
  algorithm_version text,
  built_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique(account_id, date)
);

create index if not exists idx_body_metric_logs_account_date on public.body_metric_logs(account_id, date);
create index if not exists idx_food_records_account_date on public.food_records(account_id, date);
create index if not exists idx_food_items_record on public.food_items(food_record_id);
create index if not exists idx_workout_sessions_account_date on public.workout_sessions(account_id, date);
create index if not exists idx_workout_sets_session on public.workout_sets(workout_session_id);
create index if not exists idx_daily_summaries_account_date on public.daily_summaries(account_id, date);

drop trigger if exists body_metric_logs_touch_record_version on public.body_metric_logs;
create trigger body_metric_logs_touch_record_version
before update on public.body_metric_logs
for each row execute function public.fitlog_touch_record_version();

drop trigger if exists food_records_touch_record_version on public.food_records;
create trigger food_records_touch_record_version
before update on public.food_records
for each row execute function public.fitlog_touch_record_version();

drop trigger if exists workout_sessions_touch_record_version on public.workout_sessions;
create trigger workout_sessions_touch_record_version
before update on public.workout_sessions
for each row execute function public.fitlog_touch_record_version();

drop trigger if exists daily_summaries_touch_record_version on public.daily_summaries;
create trigger daily_summaries_touch_record_version
before update on public.daily_summaries
for each row execute function public.fitlog_touch_record_version();

alter table public.body_metric_logs enable row level security;
alter table public.food_records enable row level security;
alter table public.food_items enable row level security;
alter table public.workout_sessions enable row level security;
alter table public.workout_sets enable row level security;
alter table public.daily_summaries enable row level security;

drop policy if exists "body_metric_logs_own_rows" on public.body_metric_logs;
create policy "body_metric_logs_own_rows" on public.body_metric_logs
for all using (auth.uid() = account_id) with check (auth.uid() = account_id);

drop policy if exists "food_records_own_rows" on public.food_records;
create policy "food_records_own_rows" on public.food_records
for all using (auth.uid() = account_id) with check (auth.uid() = account_id);

drop policy if exists "food_items_own_rows" on public.food_items;
create policy "food_items_own_rows" on public.food_items
for all using (auth.uid() = account_id) with check (auth.uid() = account_id);

drop policy if exists "workout_sessions_own_rows" on public.workout_sessions;
create policy "workout_sessions_own_rows" on public.workout_sessions
for all using (auth.uid() = account_id) with check (auth.uid() = account_id);

drop policy if exists "workout_sets_own_rows" on public.workout_sets;
create policy "workout_sets_own_rows" on public.workout_sets
for all using (auth.uid() = account_id) with check (auth.uid() = account_id);

drop policy if exists "daily_summaries_own_rows" on public.daily_summaries;
create policy "daily_summaries_own_rows" on public.daily_summaries
for all using (auth.uid() = account_id) with check (auth.uid() = account_id);

grant usage on schema public to authenticated;

grant select, insert, update, delete on table
  public.account_active_devices,
  public.body_metric_logs,
  public.food_records,
  public.food_items,
  public.workout_sessions,
  public.workout_sets,
  public.daily_summaries
to authenticated;

grant execute on function public.claim_active_device(text, text, text, text) to authenticated;
grant execute on function public.assert_active_device(text, text) to authenticated;
grant execute on function public.release_active_device(text, text) to authenticated;
