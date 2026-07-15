import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

test("RAG foundation migrations are additive, bounded, and service-role scoped", async () => {
  const hybrid = await readFile(
    "supabase/migrations/202607130001_rag_foundation_document_hybrid.sql",
    "utf8",
  );
  const history = await readFile(
    "supabase/migrations/202607130002_rag_foundation_exercise_history.sql",
    "utf8",
  );
  const observability = await readFile(
    "supabase/migrations/202607130003_rag_foundation_observability.sql",
    "utf8",
  );
  const latencyBreakdown = await readFile(
    "supabase/migrations/202607150001_rag_latency_breakdown.sql",
    "utf8",
  );
  const chatTurnWorkflows = await readFile(
    "supabase/migrations/202607150002_ai_chat_turn_rag_workflows.sql",
    "utf8",
  );
  const indexedHybrid = await readFile(
    "supabase/migrations/202607150003_rag_hybrid_indexed_candidates.sql",
    "utf8",
  );
  const parallelFusion = await readFile(
    "supabase/migrations/202607150004_rag_parallel_candidate_fusion.sql",
    "utf8",
  );

  assert.match(hybrid, /create extension if not exists vector/i);
  assert.match(hybrid, /input_embedding vector\(1536\)/i);
  assert.match(hybrid, /term = any\(chunks\.search_tokens\)/i);
  assert.match(hybrid, /exact_score[\s\S]+term_score[\s\S]+full_text_score[\s\S]+trigram_score[\s\S]+vector_score/i);
  assert.match(hybrid, /state = 'active'/i);
  assert.match(hybrid, /revoke all on function public\.search_document_chunks_hybrid[\s\S]+grant execute[\s\S]+service_role/i);
  assert.doesNotMatch(hybrid, /drop table/i);

  assert.match(history, /security definer/i);
  assert.match(history, /input_session_limit/i);
  assert.match(history, /input_account_id/i);
  assert.match(history, /revoke all[\s\S]+service_role/i);
  assert.doesNotMatch(history, /select\s+\*/i);

  assert.match(observability, /add column if not exists task_plan_version/i);
  assert.match(observability, /retrieval_retry_count between 0 and 1/i);
  assert.match(observability, /canonical_concept_ids_json[\s\S]+never raw query text/i);
  assert.match(observability, /workout_logging[\s\S]+general_chat[\s\S]+safety_boundary/i);
  assert.doesNotMatch(observability, /raw_provider_output|chain_of_thought|base64_data/i);

  assert.match(latencyBreakdown, /add column if not exists latency_breakdown_json jsonb/i);
  assert.match(latencyBreakdown, /jsonb_typeof\(latency_breakdown_json\) = 'object'/i);
  assert.match(latencyBreakdown, /never stores raw user text[\s\S]+query vectors[\s\S]+business records/i);
  assert.doesNotMatch(latencyBreakdown, /drop table|drop column/i);
  assert.match(chatTurnWorkflows, /create or replace function public\.record_ai_chat_turn/i);
  for (const workflow of ["workout_logging", "general_chat", "safety_boundary"]) {
    assert.match(chatTurnWorkflows, new RegExp(`'${workflow}'`));
  }
  assert.match(chatTurnWorkflows, /from public, anon, authenticated[\s\S]+to service_role/i);
  assert.doesNotMatch(chatTurnWorkflows, /drop table|drop column/i);
  assert.match(indexedHybrid, /search_tsv tsvector generated always/i);
  assert.match(indexedHybrid, /using gin\(search_tsv\)/i);
  assert.match(indexedHybrid, /search_tokens && query_input\.query_terms/i);
  assert.match(indexedHybrid, /order by chunks\.embedding <=> input_embedding[\s\S]+limit 96/i);
  assert.match(indexedHybrid, /candidate_ids as materialized/i);
  assert.match(indexedHybrid, /search_document_chunks_hybrid_v2[\s\S]+to service_role/i);
  assert.doesNotMatch(indexedHybrid, /drop table|drop column|drop function/i);
  assert.match(parallelFusion, /search_document_chunk_lexical_candidates_v1/i);
  assert.match(parallelFusion, /limit 96[\s\S]+limit 96[\s\S]+limit 96/i);
  assert.match(parallelFusion, /input_lexical_candidate_ids uuid\[\]/i);
  assert.match(parallelFusion, /search_document_chunks_hybrid_v3/i);
  assert.match(parallelFusion, /from public, anon, authenticated[\s\S]+to service_role/i);
  assert.doesNotMatch(parallelFusion, /drop table|drop column|drop function/i);
});
