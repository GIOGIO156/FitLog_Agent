grant usage on schema public to service_role;

grant select on table public.subscriptions to service_role;

grant select, insert, update on table public.account_active_devices to service_role;

grant select on table
  public.ai_chat_sessions,
  public.ai_chat_messages
to service_role;

grant select, insert on table
  public.ai_request_logs,
  public.ai_debug_summaries
to service_role;
