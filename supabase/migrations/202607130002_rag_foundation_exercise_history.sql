create or replace function public.build_exercise_history_summary(
  input_account_id uuid,
  input_exercise_keys text[],
  input_start_date date,
  input_end_date date,
  input_session_limit integer default 20
)
returns table (
  exercise_key text,
  exercise_name text,
  session_count bigint,
  latest_date date,
  latest_input_weight_kg numeric,
  latest_input_reps integer,
  latest_calculation_load_kg numeric,
  latest_calculation_reps integer,
  legacy_name_match boolean,
  snapshot_conflict_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with bounded as (
    select sessions.*
    from public.workout_sessions sessions
    where sessions.account_id = input_account_id
      and sessions.deleted_at is null
      and sessions.date between greatest(input_start_date, input_end_date - 365) and input_end_date
      and cardinality(input_exercise_keys) between 1 and 4
      and (
        sessions.exercise_key = any(input_exercise_keys)
        or (sessions.exercise_key is null and sessions.exercise_name = any(input_exercise_keys))
      )
    order by sessions.date desc, sessions.created_at desc
    limit least(greatest(coalesce(input_session_limit, 20), 1), 40)
  ), latest_sets as (
    select distinct on (sets.workout_session_id)
      sets.workout_session_id, sets.input_weight_kg, sets.input_reps,
      sets.calculation_load_kg, sets.calculation_reps
    from public.workout_sets sets
    join bounded on bounded.id = sets.workout_session_id
    where sets.account_id = input_account_id
    order by sets.workout_session_id, sets.set_number desc
  )
  select coalesce(bounded.exercise_key, bounded.exercise_name) exercise_key,
    max(bounded.exercise_name) exercise_name,
    count(*) session_count,
    max(bounded.date) latest_date,
    (array_agg(latest_sets.input_weight_kg order by bounded.date desc))[1],
    (array_agg(latest_sets.input_reps order by bounded.date desc))[1],
    (array_agg(latest_sets.calculation_load_kg order by bounded.date desc))[1],
    (array_agg(latest_sets.calculation_reps order by bounded.date desc))[1],
    bool_or(bounded.exercise_key is null) legacy_name_match,
    count(*) filter (where bounded.exercise_snapshot_json is null) snapshot_conflict_count
  from bounded
  left join latest_sets on latest_sets.workout_session_id = bounded.id
  group by coalesce(bounded.exercise_key, bounded.exercise_name);
$$;

revoke all on function public.build_exercise_history_summary(uuid, text[], date, date, integer)
from public, anon, authenticated;
grant execute on function public.build_exercise_history_summary(uuid, text[], date, date, integer)
to service_role;
