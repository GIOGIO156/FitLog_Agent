import { assertEquals } from "jsr:@std/assert@1";
import {
  embedNormalizedQuery,
  queryEmbeddingDimension,
  qwenEmbeddingEndpoint,
} from "./query_embedding.ts";

Deno.test("query embedding derives the Qwen workspace endpoint", () => {
  assertEquals(
    qwenEmbeddingEndpoint(
      "https://workspace.example/compatible-mode/v1/chat/completions?ignored=true",
    ),
    "https://workspace.example/compatible-mode/v1/embeddings",
  );
});

Deno.test("query embedding skips empty input", async () => {
  let calls = 0;
  const result = await embedNormalizedQuery(
    config(),
    [" ", ""],
    (() => {
      calls += 1;
      throw new Error("not expected");
    }) as typeof fetch,
  );
  assertEquals(result, { vector: null, issue: null });
  assertEquals(calls, 0);
});

Deno.test("query embedding validates dimension and degrades without throwing", async () => {
  const invalid = await embedNormalizedQuery(
    config(),
    ["每侧次数"],
    (() =>
      Promise.resolve(
        new Response(
          JSON.stringify({ model: "model", data: [{ embedding: [1] }] }),
          { status: 200 },
        ),
      )) as typeof fetch,
  );
  assertEquals(invalid, { vector: null, issue: "embedding_unavailable" });
  const valid = await embedNormalizedQuery(
    config(),
    ["per_side_reps"],
    (() =>
      Promise.resolve(
        new Response(
          JSON.stringify({
            model: "model",
            data: [{ embedding: Array(queryEmbeddingDimension).fill(0) }],
          }),
          { status: 200 },
        ),
      )) as typeof fetch,
  );
  assertEquals(valid.issue, null);
  assertEquals(valid.vector?.length, queryEmbeddingDimension);
});

function config() {
  return {
    endpoint: "https://example.test/v1/embeddings",
    apiKey: "secret",
    model: "model",
    timeoutMs: 1000,
  };
}
