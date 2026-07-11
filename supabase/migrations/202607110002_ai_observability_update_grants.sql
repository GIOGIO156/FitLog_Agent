grant update on table
  public.ai_request_logs,
  public.ai_debug_summaries
to service_role;

comment on table public.ai_request_logs is
  'Server-owned AI request telemetry. Authenticated clients have no direct read or write policy; Edge Functions insert and finalize compact rows through service-role access.';
comment on table public.ai_debug_summaries is
  'Server-owned compact AI debug summaries. Edge Functions may finalize retrieval and safety metadata without storing raw prompts, provider output, images, or secrets.';
