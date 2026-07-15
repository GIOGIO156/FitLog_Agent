import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const migrationPath = "supabase/migrations/202607130001_rag_foundation_document_hybrid.sql";

test("hybrid migration is additive, bounded, and service-role only", async () => {
  const sql = await readFile(migrationPath, "utf8");
  assert.match(sql, /create extension if not exists vector/i);
  assert.match(sql, /embedding vector\(1536\)/i);
  assert.match(sql, /document_corpus_builds/i);
  assert.match(sql, /using hnsw \(embedding vector_cosine_ops\)/i);
  assert.match(sql, /security definer\s+set search_path = public/gi);
  assert.match(sql, /least\(greatest\(coalesce\(input_limit, 24\), 1\), 60\)/i);
  assert.match(sql, /revoke all on table public\.document_corpus_builds from public, anon, authenticated/i);
  assert.match(sql, /revoke all on function public\.search_document_chunks_hybrid[\s\S]+from public, anon, authenticated/i);
  assert.match(sql, /grant execute on function public\.search_document_chunks_hybrid[\s\S]+to service_role/i);
  assert.doesNotMatch(sql, /drop table\s+public\.document_chunks/i);
  assert.doesNotMatch(sql, /drop function[^\n]+search_document_chunks\(text, text, integer\)/i);
});
