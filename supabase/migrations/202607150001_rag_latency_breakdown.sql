alter table public.ai_request_logs
  add column if not exists latency_breakdown_json jsonb not null default '{}'::jsonb;

alter table public.ai_request_logs
  drop constraint if exists ai_request_logs_latency_breakdown_object_check;
alter table public.ai_request_logs
  add constraint ai_request_logs_latency_breakdown_object_check check (
    jsonb_typeof(latency_breakdown_json) = 'object'
  );

comment on column public.ai_request_logs.latency_breakdown_json is
  'Bounded stage durations and finite status labels only. Never stores raw user text, query vectors, document excerpts, images, provider output, secrets, business records, or chain-of-thought.';
