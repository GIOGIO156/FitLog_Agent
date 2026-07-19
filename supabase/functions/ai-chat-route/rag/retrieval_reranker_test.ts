import { assertEquals } from "jsr:@std/assert@1";
import { normalizeRagQuery } from "./query_normalizer.ts";
import { fuseAndRerank } from "./retrieval_reranker.ts";
import type { RetrievalCandidate } from "./types.ts";

Deno.test("reranker preserves Database top ownership from hybrid retrieval", () => {
  const query = normalizeRagQuery(
    "Where is the workout exercise snapshot persisted?",
  );
  const result = fuseAndRerank([
    candidate("docs/en/AppGuide.md", "Workout", 2),
    candidate("docs/en/Database.md", "Workout persistence", 1),
  ], query);
  assertEquals(result.degraded, false);
  assertEquals(result.candidates[0].doc_path, "docs/en/Database.md");
});

Deno.test("reranker degrades to fused order without dropping candidates", () => {
  const query = normalizeRagQuery("FitLog product promise");
  const invalid = candidate("docs/en/Product.md", "Product", 1);
  invalid.lexical_rank = null;
  invalid.vector_rank = null;
  invalid.lexical_score = Number.NaN;
  const result = fuseAndRerank([invalid], query);
  assertEquals(result.candidates.length, 1);
});

function candidate(
  docPath: string,
  heading: string,
  lexicalRank: number,
): RetrievalCandidate {
  return {
    id: `${docPath}:${heading}`,
    build_id: "test",
    language: "en",
    doc_path: docPath,
    heading,
    heading_path: [heading],
    section_id: heading.toLowerCase().replaceAll(" ", "-"),
    chunk_index: 1,
    chunk_count: 1,
    content: `${heading} database persisted stored table product promise`,
    context_prefix: "",
    tags: [],
    status: "implemented",
    authority: "current_product",
    lexical_score: 1,
    exact_score: 0,
    term_score: 1,
    full_text_score: 1,
    trigram_score: 0,
    vector_score: 0.7,
    lexical_rank: lexicalRank,
    vector_rank: lexicalRank,
    matched_terms: [],
    matched_fields: [],
  };
}
