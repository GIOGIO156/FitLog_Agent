create or replace function public.search_document_chunk_lexical_candidates_v1(
  input_corpus_id text,
  input_languages text[],
  input_query text,
  input_query_terms text[]
)
returns table (id uuid)
language sql
stable
security definer
set search_path = public
as $$
  with query_input as materialized (
    select
      lower(trim(coalesce(input_query, ''))) as query_text,
      array(
        select distinct lower(trim(term))
        from unnest(coalesce(input_query_terms, '{}'::text[])) term
        where trim(term) <> ''
        limit 24
      ) as query_terms,
      plainto_tsquery('simple', trim(coalesce(input_query, ''))) as query_ts
  ), active_build as materialized (
    select build_id
    from public.document_corpus_builds
    where corpus_id = input_corpus_id and state = 'active'
    limit 1
  ), term_candidates as materialized (
    select chunks.id
    from public.document_chunks chunks
    join active_build on active_build.build_id = chunks.build_id
    cross join query_input
    where chunks.corpus_id = input_corpus_id
      and chunks.language = any(input_languages)
      and chunks.authority in ('current_product', 'non_goal', 'evidence')
      and cardinality(query_input.query_terms) > 0
      and chunks.search_tokens && query_input.query_terms
    order by cardinality(
      array(
        select unnest(chunks.search_tokens)
        intersect
        select unnest(query_input.query_terms)
      )
    ) desc, chunks.doc_path, chunks.section_id
    limit 96
  ), full_text_candidates as materialized (
    select chunks.id
    from public.document_chunks chunks
    join active_build on active_build.build_id = chunks.build_id
    cross join query_input
    where chunks.corpus_id = input_corpus_id
      and chunks.language = any(input_languages)
      and chunks.authority in ('current_product', 'non_goal', 'evidence')
      and chunks.search_tsv @@ query_input.query_ts
    order by ts_rank_cd(chunks.search_tsv, query_input.query_ts) desc,
      chunks.doc_path, chunks.section_id
    limit 96
  ), trigram_candidates as materialized (
    select chunks.id
    from public.document_chunks chunks
    join active_build on active_build.build_id = chunks.build_id
    cross join query_input
    where chunks.corpus_id = input_corpus_id
      and chunks.language = any(input_languages)
      and chunks.authority in ('current_product', 'non_goal', 'evidence')
      and query_input.query_text <> ''
      and (
        chunks.heading ilike '%' || query_input.query_text || '%'
        or chunks.content ilike '%' || query_input.query_text || '%'
        or chunks.context_prefix ilike '%' || query_input.query_text || '%'
        or chunks.heading % query_input.query_text
        or chunks.content % query_input.query_text
        or chunks.context_prefix % query_input.query_text
      )
    order by greatest(
      similarity(chunks.heading, query_input.query_text),
      similarity(chunks.content, query_input.query_text),
      similarity(chunks.context_prefix, query_input.query_text)
    ) desc, chunks.doc_path, chunks.section_id
    limit 96
  )
  select id from term_candidates
  union
  select id from full_text_candidates
  union
  select id from trigram_candidates;
$$;

create or replace function public.search_document_chunks_hybrid_v3(
  input_corpus_id text,
  input_languages text[],
  input_query text,
  input_query_terms text[],
  input_lexical_candidate_ids uuid[],
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
  with query_input as materialized (
    select
      lower(trim(coalesce(input_query, ''))) as query_text,
      array(
        select distinct lower(trim(term))
        from unnest(coalesce(input_query_terms, '{}'::text[])) term
        where trim(term) <> ''
        limit 24
      ) as query_terms,
      plainto_tsquery('simple', trim(coalesce(input_query, ''))) as query_ts
  ), active_build as materialized (
    select build_id, embedding_model
    from public.document_corpus_builds
    where corpus_id = input_corpus_id and state = 'active'
    limit 1
  ), vector_candidates as materialized (
    select chunks.id
    from public.document_chunks chunks
    join active_build on active_build.build_id = chunks.build_id
    where chunks.corpus_id = input_corpus_id
      and chunks.language = any(input_languages)
      and chunks.authority in ('current_product', 'non_goal', 'evidence')
      and input_embedding is not null
      and chunks.embedding is not null
      and active_build.embedding_model is not distinct from input_embedding_model
    order by chunks.embedding <=> input_embedding
    limit 96
  ), candidate_ids as materialized (
    select unnest(coalesce(input_lexical_candidate_ids, '{}'::uuid[])) as id
    union
    select id from vector_candidates
  ), scored as (
    select chunks.*,
      case
        when lower(chunks.heading) = query_input.query_text then 1.0
        when lower(chunks.heading) like '%' || query_input.query_text || '%' then 0.9
        when lower(chunks.content) like '%' || query_input.query_text || '%' then 0.8
        else 0.0
      end::real as exact_score,
      case when cardinality(query_input.query_terms) = 0 then 0.0 else
        matched.match_count::real / cardinality(query_input.query_terms)
      end::real as term_score,
      ts_rank_cd(chunks.search_tsv, query_input.query_ts)::real as full_text_score,
      greatest(
        similarity(chunks.heading, query_input.query_text),
        similarity(chunks.content, query_input.query_text),
        similarity(chunks.context_prefix, query_input.query_text)
      )::real as trigram_score,
      case
        when input_embedding is null or chunks.embedding is null
          or active_build.embedding_model is distinct from input_embedding_model
        then null
        else (1 - (chunks.embedding <=> input_embedding))::real
      end as vector_score,
      matched.terms as matched_terms,
      array_remove(array[
        case when lower(chunks.heading) like '%' || query_input.query_text || '%' then 'heading' end,
        case when lower(chunks.content) like '%' || query_input.query_text || '%' then 'content' end,
        case when lower(chunks.context_prefix) like '%' || query_input.query_text || '%' then 'context_prefix' end
      ], null)::text[] as matched_fields
    from candidate_ids
    join public.document_chunks chunks on chunks.id = candidate_ids.id
    join active_build on active_build.build_id = chunks.build_id
    cross join query_input
    cross join lateral (
      select
        coalesce(array_agg(term order by term), '{}'::text[]) as terms,
        count(*)::integer as match_count
      from unnest(query_input.query_terms) term
      where term = any(chunks.search_tokens)
        or chunks.content ilike '%' || term || '%'
        or chunks.heading ilike '%' || term || '%'
    ) matched
    where chunks.corpus_id = input_corpus_id
      and chunks.language = any(input_languages)
      and chunks.authority in ('current_product', 'non_goal', 'evidence')
  ), lexical_scored as (
    select scored.*,
      greatest(
        exact_score * 1.2,
        term_score,
        full_text_score,
        trigram_score * 0.75
      )::real as lexical_score
    from scored
  ), ranked as (
    select lexical_scored.*,
      rank() over (
        order by lexical_score desc, doc_path, section_id
      ) as lexical_rank,
      case when vector_score is null then null else rank() over (
        order by vector_score desc nulls last, doc_path, section_id
      ) end as vector_rank
    from lexical_scored
    where lexical_score > 0 or vector_score is not null
  )
  select id, build_id, language, doc_path, heading, heading_path, section_id,
    chunk_index, chunk_count, content, context_prefix, tags, status, authority,
    lexical_score, exact_score, term_score, full_text_score, trigram_score,
    vector_score, lexical_rank, vector_rank, matched_fields, matched_terms
  from ranked
  order by least(lexical_rank, coalesce(vector_rank, lexical_rank)),
    lexical_score desc
  limit least(greatest(coalesce(input_limit, 24), 1), 60);
$$;

revoke all on function public.search_document_chunk_lexical_candidates_v1(
  text, text[], text, text[]
) from public, anon, authenticated;
grant execute on function public.search_document_chunk_lexical_candidates_v1(
  text, text[], text, text[]
) to service_role;

revoke all on function public.search_document_chunks_hybrid_v3(
  text, text[], text, text[], uuid[], vector, integer, text
) from public, anon, authenticated;
grant execute on function public.search_document_chunks_hybrid_v3(
  text, text[], text, text[], uuid[], vector, integer, text
) to service_role;
