create extension if not exists pg_trgm;

create table if not exists public.document_chunks (
  id uuid primary key default gen_random_uuid(),
  language text not null,
  doc_path text not null,
  heading text not null,
  heading_level integer not null,
  heading_path text[] not null default '{}'::text[],
  section_id text not null,
  chunk_index integer not null default 1,
  chunk_count integer not null default 1,
  content text not null,
  context_prefix text not null default '',
  context_note text,
  tags text[] not null default '{}'::text[],
  status text not null default 'implemented',
  content_hash text not null,
  generator_version text not null default 'phase5_document_chunks.v2',
  source_updated_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint document_chunks_language_check check (language in ('zh', 'en')),
  constraint document_chunks_heading_level_check check (heading_level between 1 and 6),
  constraint document_chunks_chunk_index_check check (chunk_index >= 1),
  constraint document_chunks_chunk_count_check check (chunk_count >= chunk_index),
  constraint document_chunks_status_check check (
    status in ('implemented', 'planned', 'non_goal', 'local_baseline', 'evidence')
  ),
  constraint document_chunks_content_not_blank check (length(trim(content)) > 0),
  constraint document_chunks_unique unique (language, doc_path, section_id)
);

alter table public.document_chunks
  add column if not exists heading_path text[] not null default '{}'::text[];

alter table public.document_chunks
  add column if not exists chunk_index integer not null default 1;

alter table public.document_chunks
  add column if not exists chunk_count integer not null default 1;

alter table public.document_chunks
  add column if not exists context_prefix text not null default '';

alter table public.document_chunks
  add column if not exists context_note text;

alter table public.document_chunks
  add column if not exists generator_version text not null default 'phase5_document_chunks.v2';

alter table public.document_chunks
  drop constraint if exists document_chunks_unique;

alter table public.document_chunks
  drop constraint if exists document_chunks_chunk_index_check;

alter table public.document_chunks
  drop constraint if exists document_chunks_chunk_count_check;

alter table public.document_chunks
  add constraint document_chunks_unique unique (language, doc_path, section_id);

alter table public.document_chunks
  add constraint document_chunks_chunk_index_check check (chunk_index >= 1);

alter table public.document_chunks
  add constraint document_chunks_chunk_count_check check (chunk_count >= chunk_index);

create index if not exists idx_document_chunks_language_doc
on public.document_chunks(language, doc_path);

create index if not exists idx_document_chunks_language_status
on public.document_chunks(language, status);

create index if not exists idx_document_chunks_content_trgm
on public.document_chunks using gin (content gin_trgm_ops);

create index if not exists idx_document_chunks_heading_trgm
on public.document_chunks using gin (heading gin_trgm_ops);

create index if not exists idx_document_chunks_context_prefix_trgm
on public.document_chunks using gin (context_prefix gin_trgm_ops);

drop trigger if exists document_chunks_touch_updated_at on public.document_chunks;
create trigger document_chunks_touch_updated_at
before update on public.document_chunks
for each row execute function public.fitlog_touch_updated_at();

alter table public.document_chunks enable row level security;

revoke all on table public.document_chunks from anon, authenticated;
grant select, insert, update, delete on table public.document_chunks to service_role;

drop function if exists public.search_document_chunks(text, text, integer);

create or replace function public.search_document_chunks(
  input_language text,
  input_query text,
  input_limit integer default 6
)
returns table (
  id uuid,
  language text,
  doc_path text,
  heading text,
  heading_level integer,
  heading_path text[],
  section_id text,
  chunk_index integer,
  chunk_count integer,
  content text,
  context_prefix text,
  context_note text,
  tags text[],
  status text,
  score real
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  effective_language text := case when lower(trim(coalesce(input_language, 'zh'))) = 'en' then 'en' else 'zh' end;
  query_text text := trim(coalesce(input_query, ''));
  max_rows integer := least(greatest(coalesce(input_limit, 6), 1), 8);
begin
  if query_text = '' then
    return;
  end if;

  return query
  with ranked as (
    select
      chunks.id,
      chunks.language,
      chunks.doc_path,
      chunks.heading,
      chunks.heading_level,
      chunks.heading_path,
      chunks.section_id,
      chunks.chunk_index,
      chunks.chunk_count,
      chunks.content,
      chunks.context_prefix,
      chunks.context_note,
      chunks.tags,
      chunks.status,
      greatest(
        similarity(chunks.heading, query_text),
        similarity(chunks.content, query_text),
        similarity(chunks.context_prefix, query_text),
        ts_rank_cd(
          to_tsvector(
            'simple',
            chunks.heading || ' ' ||
            array_to_string(chunks.heading_path, ' ') || ' ' ||
            chunks.context_prefix || ' ' ||
            coalesce(chunks.context_note, '') || ' ' ||
            chunks.content
          ),
          plainto_tsquery('simple', query_text)
        )
      )::real as score
    from public.document_chunks chunks
    where chunks.language = effective_language
      and (
        chunks.heading % query_text
        or chunks.context_prefix % query_text
        or chunks.content % query_text
        or to_tsvector(
          'simple',
          chunks.heading || ' ' ||
          array_to_string(chunks.heading_path, ' ') || ' ' ||
          chunks.context_prefix || ' ' ||
          coalesce(chunks.context_note, '') || ' ' ||
          chunks.content
        ) @@ plainto_tsquery('simple', query_text)
        or chunks.heading ilike '%' || query_text || '%'
        or chunks.context_prefix ilike '%' || query_text || '%'
        or coalesce(chunks.context_note, '') ilike '%' || query_text || '%'
        or chunks.content ilike '%' || query_text || '%'
      )
  )
  select
    ranked.id,
    ranked.language,
    ranked.doc_path,
    ranked.heading,
    ranked.heading_level,
    ranked.heading_path,
    ranked.section_id,
    ranked.chunk_index,
    ranked.chunk_count,
    ranked.content,
    ranked.context_prefix,
    ranked.context_note,
    ranked.tags,
    ranked.status,
    ranked.score
  from ranked
  order by ranked.score desc, ranked.doc_path, ranked.section_id
  limit max_rows;
end;
$$;

revoke all on function public.search_document_chunks(text, text, integer)
from public, anon, authenticated;

grant execute on function public.search_document_chunks(text, text, integer)
to service_role;
