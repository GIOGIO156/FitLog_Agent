create extension if not exists vector;

alter table public.document_chunks add column if not exists corpus_id text not null default 'fitlog_user_stable_docs';
alter table public.document_chunks add column if not exists build_id text not null default 'phase5_legacy';
alter table public.document_chunks add column if not exists source_hash text not null default '';
alter table public.document_chunks add column if not exists chunk_hash text not null default '';
alter table public.document_chunks add column if not exists manifest_hash text not null default '';
alter table public.document_chunks add column if not exists term_version text not null default '';
alter table public.document_chunks add column if not exists authority text not null default 'current_product';
alter table public.document_chunks add column if not exists search_tokens text[] not null default '{}'::text[];
alter table public.document_chunks add column if not exists embedding vector(1536);
alter table public.document_chunks add column if not exists embedding_model text;
alter table public.document_chunks add column if not exists embedding_dimension integer;
alter table public.document_chunks add column if not exists embedding_input_hash text;
alter table public.document_chunks add column if not exists embedding_normalization_version text;
alter table public.document_chunks add column if not exists embedding_generated_at timestamptz;

update public.document_chunks
set source_hash = content_hash
where source_hash = '';
update public.document_chunks
set chunk_hash = content_hash
where chunk_hash = '';

alter table public.document_chunks drop constraint if exists document_chunks_unique;
alter table public.document_chunks drop constraint if exists document_chunks_corpus_build_unique;
alter table public.document_chunks
  add constraint document_chunks_corpus_build_unique
  unique (corpus_id, build_id, language, doc_path, section_id);
alter table public.document_chunks drop constraint if exists document_chunks_authority_check;
alter table public.document_chunks
  add constraint document_chunks_authority_check
  check (authority in ('current_product', 'planned', 'historical', 'non_goal', 'evidence'));
alter table public.document_chunks drop constraint if exists document_chunks_embedding_dimension_check;
alter table public.document_chunks
  add constraint document_chunks_embedding_dimension_check
  check (embedding_dimension is null or embedding_dimension = 1536);

create table if not exists public.document_corpus_builds (
  corpus_id text not null,
  build_id text not null,
  state text not null default 'staging',
  manifest_hash text not null,
  generator_version text not null,
  term_version text not null,
  embedding_model text,
  embedding_dimension integer,
  expected_source_count integer not null,
  expected_chunk_count integer not null,
  activated_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (corpus_id, build_id),
  constraint document_corpus_builds_state_check check (state in ('staging', 'active', 'superseded', 'failed')),
  constraint document_corpus_builds_counts_check check (expected_source_count > 0 and expected_chunk_count > 0),
  constraint document_corpus_builds_embedding_dimension_check check (embedding_dimension is null or embedding_dimension = 1536)
);

create unique index if not exists idx_document_corpus_one_active
on public.document_corpus_builds(corpus_id)
where state = 'active';
create index if not exists idx_document_chunks_active_lookup
on public.document_chunks(corpus_id, build_id, language, authority, status);
create index if not exists idx_document_chunks_search_tokens
on public.document_chunks using gin(search_tokens);
create index if not exists idx_document_chunks_embedding_cosine
on public.document_chunks using hnsw (embedding vector_cosine_ops)
where embedding is not null;

alter table public.document_corpus_builds enable row level security;
revoke all on table public.document_corpus_builds from public, anon, authenticated;
grant select, insert, update, delete on table public.document_corpus_builds to service_role;

create or replace function public.begin_document_corpus_build(
  input_corpus_id text,
  input_build_id text,
  input_manifest_hash text,
  input_generator_version text,
  input_term_version text,
  input_expected_source_count integer,
  input_expected_chunk_count integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if trim(coalesce(input_corpus_id, '')) = '' or trim(coalesce(input_build_id, '')) = '' then
    raise exception 'corpus_id and build_id are required';
  end if;
  if input_expected_source_count < 1 or input_expected_chunk_count < 1 then
    raise exception 'expected counts must be positive';
  end if;
  insert into public.document_corpus_builds (
    corpus_id, build_id, state, manifest_hash, generator_version, term_version,
    expected_source_count, expected_chunk_count, activated_at
  ) values (
    input_corpus_id, input_build_id, 'staging', input_manifest_hash,
    input_generator_version, input_term_version, input_expected_source_count,
    input_expected_chunk_count, null
  )
  on conflict (corpus_id, build_id) do update set
    state = 'staging', manifest_hash = excluded.manifest_hash,
    generator_version = excluded.generator_version, term_version = excluded.term_version,
    expected_source_count = excluded.expected_source_count,
    expected_chunk_count = excluded.expected_chunk_count,
    activated_at = null, updated_at = timezone('utc', now());
  delete from public.document_chunks
  where corpus_id = input_corpus_id and build_id = input_build_id;
end;
$$;

create or replace function public.activate_document_corpus_build(
  input_corpus_id text,
  input_build_id text,
  input_expected_source_count integer,
  input_expected_chunk_count integer,
  input_require_embeddings boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  actual_sources integer;
  actual_chunks integer;
  actual_embeddings integer;
begin
  select count(distinct doc_path), count(*), count(embedding)
  into actual_sources, actual_chunks, actual_embeddings
  from public.document_chunks
  where corpus_id = input_corpus_id and build_id = input_build_id;
  if actual_sources <> input_expected_source_count or actual_chunks <> input_expected_chunk_count then
    raise exception 'corpus parity mismatch sources %/% chunks %/%', actual_sources,
      input_expected_source_count, actual_chunks, input_expected_chunk_count;
  end if;
  if input_require_embeddings and actual_embeddings <> actual_chunks then
    raise exception 'embedding parity mismatch %/%', actual_embeddings, actual_chunks;
  end if;
  update public.document_corpus_builds
  set state = 'superseded', updated_at = timezone('utc', now())
  where corpus_id = input_corpus_id and state = 'active' and build_id <> input_build_id;
  update public.document_corpus_builds
  set state = 'active', activated_at = timezone('utc', now()), updated_at = timezone('utc', now())
  where corpus_id = input_corpus_id and build_id = input_build_id;
  if not found then raise exception 'unknown corpus build'; end if;
end;
$$;

create or replace function public.search_document_chunks_hybrid(
  input_corpus_id text,
  input_languages text[],
  input_query text,
  input_query_terms text[],
  input_embedding vector(1536) default null,
  input_limit integer default 24,
  input_embedding_model text default null
)
returns table (
  id uuid, build_id text, language text, doc_path text, heading text, heading_path text[],
  section_id text, chunk_index integer, chunk_count integer, content text,
  context_prefix text, tags text[], status text, authority text,
  lexical_score real, exact_score real, term_score real, full_text_score real,
  trigram_score real, vector_score real, lexical_rank bigint, vector_rank bigint,
  matched_fields text[], matched_terms text[]
)
language sql
stable
security definer
set search_path = public
as $$
  with query_input as (
    select lower(trim(input_query)) query_text,
      coalesce(input_query_terms, '{}'::text[]) query_terms
  ), active_build as (
    select build_id, embedding_model from public.document_corpus_builds
    where corpus_id = input_corpus_id and state = 'active' limit 1
  ), candidates as (
    select chunks.*,
      case
        when lower(chunks.heading) = query_input.query_text then 1.0
        when lower(chunks.heading) like '%' || query_input.query_text || '%' then 0.9
        when lower(chunks.content) like '%' || query_input.query_text || '%' then 0.8
        else 0.0
      end::real exact_score,
      case when cardinality(query_input.query_terms) = 0 then 0.0 else
        (select count(*)::real / cardinality(query_input.query_terms)
         from unnest(query_input.query_terms) term
         where term = any(chunks.search_tokens)
            or chunks.content ilike '%' || term || '%'
            or chunks.heading ilike '%' || term || '%')
      end::real term_score,
      ts_rank_cd(
        to_tsvector('simple', chunks.heading || ' ' || chunks.content),
        plainto_tsquery('simple', input_query)
      )::real full_text_score,
      greatest(
        similarity(chunks.heading, trim(input_query)),
        similarity(chunks.content, trim(input_query)),
        coalesce((select max(similarity(chunks.content, term)) from unnest(query_input.query_terms) term), 0)
      )::real trigram_score,
      case when input_embedding is null or chunks.embedding is null
          or active_build.embedding_model is distinct from input_embedding_model then null
        else (1 - (chunks.embedding <=> input_embedding))::real end vector_score,
      array(select term from unnest(query_input.query_terms) term
        where term = any(chunks.search_tokens)
           or chunks.content ilike '%' || term || '%'
           or chunks.heading ilike '%' || term || '%') matched_terms,
      array_remove(array[
        case when lower(chunks.heading) like '%' || query_input.query_text || '%' then 'heading' end,
        case when lower(chunks.content) like '%' || query_input.query_text || '%' then 'content' end,
        case when chunks.context_prefix ilike '%' || input_query || '%' then 'context_prefix' end
      ], null)::text[] matched_fields
    from public.document_chunks chunks
    join active_build on active_build.build_id = chunks.build_id
    cross join query_input
    where chunks.corpus_id = input_corpus_id
      and chunks.language = any(input_languages)
      and chunks.authority in ('current_product', 'non_goal', 'evidence')
  ), scored as (
    select candidates.*,
      greatest(
        exact_score * 1.2,
        term_score,
        full_text_score,
        trigram_score * 0.75
      )::real lexical_score
    from candidates
  ), ranked as (
    select scored.*,
      rank() over (order by lexical_score desc, doc_path, section_id) lexical_rank,
      case when vector_score is null then null else rank() over (order by vector_score desc nulls last, doc_path, section_id) end vector_rank
    from scored
    where lexical_score > 0 or vector_score is not null
  )
  select id, build_id, language, doc_path, heading, heading_path, section_id, chunk_index,
    chunk_count, content, context_prefix, tags, status, authority, lexical_score,
    exact_score, term_score, full_text_score, trigram_score, vector_score,
    lexical_rank, vector_rank, matched_fields, matched_terms
  from ranked
  order by least(lexical_rank, coalesce(vector_rank, lexical_rank)), lexical_score desc
  limit least(greatest(coalesce(input_limit, 24), 1), 60);
$$;

revoke all on function public.begin_document_corpus_build(text, text, text, text, text, integer, integer) from public, anon, authenticated;
revoke all on function public.activate_document_corpus_build(text, text, integer, integer, boolean) from public, anon, authenticated;
revoke all on function public.search_document_chunks_hybrid(text, text[], text, text[], vector, integer, text) from public, anon, authenticated;
grant execute on function public.begin_document_corpus_build(text, text, text, text, text, integer, integer) to service_role;
grant execute on function public.activate_document_corpus_build(text, text, integer, integer, boolean) to service_role;
grant execute on function public.search_document_chunks_hybrid(text, text[], text, text[], vector, integer, text) to service_role;
