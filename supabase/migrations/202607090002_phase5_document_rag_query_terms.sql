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
  with query_terms as (
    select coalesce(
      array_agg(distinct term order by term),
      array[]::text[]
    ) as terms
    from regexp_split_to_table(lower(query_text), '[^[:alnum:]_]+') as term
    where length(term) >= 3
      and term not in (
        'and', 'are', 'can', 'does', 'for', 'how', 'the', 'this', 'that',
        'what', 'when', 'where', 'why', 'with', 'work', 'works'
      )
  ),
  ranked as (
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
        case
          when length(trim(replace(chunks.heading, '_', ' '))) >= 4
            and (
              lower(query_text) like '%' || lower(chunks.heading) || '%'
              or lower(query_text) like '%' || lower(replace(chunks.heading, '_', ' ')) || '%'
            )
            then 2.0
          else 0.0
        end,
        similarity(chunks.heading, query_text),
        similarity(replace(chunks.heading, '_', ' '), query_text),
        similarity(chunks.content, query_text),
        similarity(chunks.context_prefix, query_text),
        ts_rank_cd(
          search.search_vector,
          plainto_tsquery('simple', query_text)
        ),
        case
          when array_length(query_terms.terms, 1) is null then 0
          else hits.term_hits::real / greatest(array_length(query_terms.terms, 1), 1)
        end
      )::real as score
    from public.document_chunks chunks
    cross join query_terms
    cross join lateral (
      select
        lower(
          chunks.heading || ' ' ||
          array_to_string(chunks.heading_path, ' ') || ' ' ||
          chunks.context_prefix || ' ' ||
          coalesce(chunks.context_note, '') || ' ' ||
          chunks.content
        ) as searchable_text,
        to_tsvector(
          'simple',
          chunks.heading || ' ' ||
          array_to_string(chunks.heading_path, ' ') || ' ' ||
          chunks.context_prefix || ' ' ||
          coalesce(chunks.context_note, '') || ' ' ||
          chunks.content
        ) as search_vector
    ) search
    cross join lateral (
      select count(*) as term_hits
      from unnest(query_terms.terms) as term
      where search.searchable_text like '%' || term || '%'
    ) hits
    where chunks.language = effective_language
      and (
        hits.term_hits > 0
        or chunks.heading % query_text
        or chunks.context_prefix % query_text
        or chunks.content % query_text
        or search.search_vector @@ plainto_tsquery('simple', query_text)
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
