grant usage on schema public to service_role;

grant select on table
  public.cloud_profiles,
  public.body_metric_logs,
  public.food_records,
  public.food_items,
  public.workout_sessions,
  public.workout_sets,
  public.daily_summaries
to service_role;

grant select, insert, update on table
  public.ai_debug_summaries
to service_role;
