create extension if not exists pgcrypto;

create or replace function public.fitlog_touch_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.ai_chat_sessions (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null default '',
  language text not null default 'zh',
  last_message_at timestamptz,
  archived_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint ai_chat_sessions_id_account_unique unique (id, account_id),
  constraint ai_chat_sessions_language_not_blank check (length(trim(language)) > 0)
);

create table if not exists public.ai_request_logs (
  request_id uuid primary key default gen_random_uuid(),
  account_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid,
  workflow_type text not null default 'auto',
  model_choice text,
  model_provider text,
  model text,
  prompt_version text,
  schema_version text,
  profile_version text,
  status text not null,
  error_code text,
  latency_ms integer,
  token_estimate integer,
  image_count integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  constraint ai_request_logs_request_account_unique unique (request_id, account_id),
  constraint ai_request_logs_session_account_fk
    foreign key (session_id, account_id)
    references public.ai_chat_sessions(id, account_id),
  constraint ai_request_logs_workflow_check check (
    workflow_type in ('auto', 'food_logging', 'meal_decision', 'weekly_review', 'app_logic_answer')
  ),
  constraint ai_request_logs_model_choice_check check (
    model_choice is null or model_choice in ('chatgpt', 'qwen')
  ),
  constraint ai_request_logs_provider_check check (
    model_provider is null or model_provider in ('mock', 'openai', 'qwen')
  ),
  constraint ai_request_logs_status_check check (
    status in ('ok', 'error', 'blocked', 'timeout')
  ),
  constraint ai_request_logs_latency_check check (
    latency_ms is null or latency_ms >= 0
  ),
  constraint ai_request_logs_token_check check (
    token_estimate is null or token_estimate >= 0
  ),
  constraint ai_request_logs_image_count_check check (image_count >= 0)
);

create table if not exists public.ai_chat_messages (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null,
  account_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  message_sequence integer not null,
  role text not null,
  content_text text not null,
  message_type text not null default 'text',
  workflow_type text not null default 'auto',
  model_choice text,
  model_provider text,
  request_id uuid,
  final_answer_json jsonb,
  attachments_metadata jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  constraint ai_chat_messages_session_account_fk
    foreign key (session_id, account_id)
    references public.ai_chat_sessions(id, account_id)
    on delete cascade,
  constraint ai_chat_messages_request_account_fk
    foreign key (request_id, account_id)
    references public.ai_request_logs(request_id, account_id),
  constraint ai_chat_messages_session_sequence_unique unique (session_id, message_sequence),
  constraint ai_chat_messages_sequence_positive check (message_sequence > 0),
  constraint ai_chat_messages_role_check check (role in ('user', 'assistant')),
  constraint ai_chat_messages_content_not_blank check (length(trim(content_text)) > 0),
  constraint ai_chat_messages_type_check check (message_type = 'text'),
  constraint ai_chat_messages_workflow_check check (
    workflow_type in ('auto', 'food_logging', 'meal_decision', 'weekly_review', 'app_logic_answer')
  ),
  constraint ai_chat_messages_model_choice_check check (
    model_choice is null or model_choice in ('chatgpt', 'qwen')
  ),
  constraint ai_chat_messages_provider_check check (
    model_provider is null or model_provider in ('mock', 'openai', 'qwen')
  ),
  constraint ai_chat_messages_attachments_array_check check (
    jsonb_typeof(attachments_metadata) = 'array'
  )
);

create table if not exists public.ai_debug_summaries (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null,
  account_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid,
  intent text,
  intent_confidence numeric,
  called_tools_json jsonb not null default '[]'::jsonb,
  retrieved_dimensions_json jsonb not null default '[]'::jsonb,
  missing_dimensions_json jsonb not null default '[]'::jsonb,
  safety_flags_json jsonb not null default '[]'::jsonb,
  schema_validation_status text,
  user_final_action text,
  created_at timestamptz not null default timezone('utc', now()),
  constraint ai_debug_summaries_request_unique unique (request_id),
  constraint ai_debug_summaries_request_account_fk
    foreign key (request_id, account_id)
    references public.ai_request_logs(request_id, account_id)
    on delete cascade,
  constraint ai_debug_summaries_session_account_fk
    foreign key (session_id, account_id)
    references public.ai_chat_sessions(id, account_id),
  constraint ai_debug_summaries_confidence_check check (
    intent_confidence is null or (intent_confidence >= 0 and intent_confidence <= 1)
  ),
  constraint ai_debug_summaries_called_tools_array_check check (
    jsonb_typeof(called_tools_json) = 'array'
  ),
  constraint ai_debug_summaries_retrieved_array_check check (
    jsonb_typeof(retrieved_dimensions_json) = 'array'
  ),
  constraint ai_debug_summaries_missing_array_check check (
    jsonb_typeof(missing_dimensions_json) = 'array'
  ),
  constraint ai_debug_summaries_safety_array_check check (
    jsonb_typeof(safety_flags_json) = 'array'
  )
);

create index if not exists idx_ai_chat_sessions_account_updated
on public.ai_chat_sessions(account_id, updated_at desc);

create index if not exists idx_ai_chat_sessions_account_state_updated
on public.ai_chat_sessions(account_id, archived_at, deleted_at, updated_at desc);

create index if not exists idx_ai_chat_messages_account_session_sequence
on public.ai_chat_messages(account_id, session_id, message_sequence);

create index if not exists idx_ai_chat_messages_account_session_created
on public.ai_chat_messages(account_id, session_id, created_at, message_sequence, id);

create index if not exists idx_ai_request_logs_account_created
on public.ai_request_logs(account_id, created_at desc);

create index if not exists idx_ai_request_logs_session_created
on public.ai_request_logs(session_id, created_at desc);

create index if not exists idx_ai_request_logs_status_error_created
on public.ai_request_logs(status, error_code, created_at desc);

create index if not exists idx_ai_debug_summaries_account_created
on public.ai_debug_summaries(account_id, created_at desc);

create index if not exists idx_ai_debug_summaries_request
on public.ai_debug_summaries(request_id);

drop trigger if exists ai_chat_sessions_touch_updated_at on public.ai_chat_sessions;
create trigger ai_chat_sessions_touch_updated_at
before update on public.ai_chat_sessions
for each row execute function public.fitlog_touch_updated_at();

alter table public.ai_chat_sessions enable row level security;
alter table public.ai_chat_messages enable row level security;
alter table public.ai_request_logs enable row level security;
alter table public.ai_debug_summaries enable row level security;

drop policy if exists "ai_chat_sessions_select_own_active" on public.ai_chat_sessions;
create policy "ai_chat_sessions_select_own_active"
on public.ai_chat_sessions
for select
using (
  auth.uid() = account_id
  and deleted_at is null
);

drop policy if exists "ai_chat_messages_select_own_active" on public.ai_chat_messages;
create policy "ai_chat_messages_select_own_active"
on public.ai_chat_messages
for select
using (
  auth.uid() = account_id
  and deleted_at is null
  and exists (
    select 1
    from public.ai_chat_sessions sessions
    where sessions.id = ai_chat_messages.session_id
      and sessions.account_id = ai_chat_messages.account_id
      and sessions.deleted_at is null
  )
);

revoke all on table
  public.ai_chat_sessions,
  public.ai_chat_messages,
  public.ai_request_logs,
  public.ai_debug_summaries
from anon, authenticated;

grant usage on schema public to authenticated;

grant select on table
  public.ai_chat_sessions,
  public.ai_chat_messages
to authenticated;
