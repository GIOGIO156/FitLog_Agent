import assert from "node:assert/strict";
import test from "node:test";

import {
  createEmbeddings,
  EMBEDDING_BATCH_SIZE,
  EMBEDDING_DIMENSION,
  embeddingInputHash,
  isEmbeddingCurrent,
  qwenEmbeddingEndpoint,
  validateEmbeddingResponse,
} from "./embedding_client.mjs";
import { cloudRowFor, currentEmbeddingRecords, localParity } from "./sync_document_embeddings.mjs";

const chunk = {
  sectionId: "section",
  chunkHash: "chunk",
  generatorVersion: "generator",
  termVersion: "terms",
  contextPrefix: "Source. ",
  content: "Content",
};
const model = "embedding-model";
const vector = Array(EMBEDDING_DIMENSION).fill(0.1);

test("Qwen chat completion base URL derives the workspace embedding endpoint", () => {
  assert.equal(
    qwenEmbeddingEndpoint("https://workspace.example/compatible-mode/v1/chat/completions?ignored=true"),
    "https://workspace.example/compatible-mode/v1/embeddings",
  );
  assert.throws(() => qwenEmbeddingEndpoint("https://workspace.example/v1/chat/completions"));
});

test("Qwen embedding requests use the configured model, dimension, and bounded batch", async () => {
  let request;
  const result = await createEmbeddings({
    inputs: ["one", "two"],
    apiKey: "secret",
    model,
    endpoint: "https://workspace.example/compatible-mode/v1/embeddings",
    fetchImpl: async (url, init) => {
      request = { url, init };
      return new Response(JSON.stringify({ model, data: [
        { index: 0, embedding: vector },
        { index: 1, embedding: vector },
      ] }), { status: 200 });
    },
  });
  assert.equal(result.length, 2);
  assert.equal(request.url, "https://workspace.example/compatible-mode/v1/embeddings");
  assert.deepEqual(JSON.parse(request.init.body), {
    model,
    input: ["one", "two"],
    dimensions: EMBEDDING_DIMENSION,
  });
  await assert.rejects(() => createEmbeddings({
    inputs: Array(EMBEDDING_BATCH_SIZE + 1).fill("input"),
    apiKey: "secret",
    model,
    endpoint: "https://workspace.example/compatible-mode/v1/embeddings",
  }));
});

test("embedding responses preserve batch order and enforce dimension/finite values", () => {
  const result = validateEmbeddingResponse({ model, data: [
    { index: 1, embedding: vector },
    { index: 0, embedding: vector },
  ] }, { expectedCount: 2, model, dimension: EMBEDDING_DIMENSION });
  assert.equal(result.length, 2);
  assert.throws(() => validateEmbeddingResponse({ model, data: [{ index: 0, embedding: [1] }] }, { expectedCount: 1, model, dimension: EMBEDDING_DIMENSION }));
  const invalid = [...vector]; invalid[4] = Number.NaN;
  assert.throws(() => validateEmbeddingResponse({ model, data: [{ index: 0, embedding: invalid }] }, { expectedCount: 1, model, dimension: EMBEDDING_DIMENSION }));
});

test("stale detection includes content, generator, terms, model, dimension, and input hash", () => {
  const record = {
    section_id: chunk.sectionId,
    chunk_hash: chunk.chunkHash,
    generator_version: chunk.generatorVersion,
    term_version: chunk.termVersion,
    embedding_model: model,
    embedding_dimension: EMBEDDING_DIMENSION,
    embedding_input_hash: embeddingInputHash(chunk, model),
    embedding: vector,
  };
  assert.equal(isEmbeddingCurrent(record, chunk, { model }), true);
  for (const field of ["chunk_hash", "generator_version", "term_version", "embedding_model", "embedding_input_hash"]) {
    assert.equal(isEmbeddingCurrent({ ...record, [field]: "stale" }, chunk, { model }), false, field);
  }
  assert.equal(isEmbeddingCurrent({ ...record, embedding_dimension: 1 }, chunk, { model }), false);
});

test("local parity is idempotent and reports missing/stale/extra without content", () => {
  const corpus = { corpus_id: "corpus", build_id: "build", chunks: [chunk] };
  const current = {
    ...chunk,
    section_id: chunk.sectionId,
    chunk_hash: chunk.chunkHash,
    generator_version: chunk.generatorVersion,
    term_version: chunk.termVersion,
    embedding_model: model,
    embedding_dimension: EMBEDDING_DIMENSION,
    embedding_input_hash: embeddingInputHash(chunk, model),
    embedding: vector,
  };
  assert.deepEqual(localParity(corpus, { records: [current] }, model), localParity(corpus, { records: [current] }, model));
  assert.equal(localParity(corpus, { records: [] }, model).missing, 1);
  assert.equal(localParity(corpus, { records: [{ ...current, chunk_hash: "old" }] }, model).stale, 1);
  assert.equal(localParity(corpus, { records: [current, { ...current, section_id: "extra" }] }, model).extra, 1);
  assert.deepEqual(
    currentEmbeddingRecords(corpus, [current, { ...current, section_id: "extra" }]),
    [current],
  );
});

test("cloud rows carry explicit authority and matching embedding metadata", () => {
  const record = {
    section_id: chunk.sectionId,
    embedding_input_hash: embeddingInputHash(chunk, model),
    embedding: vector,
  };
  const row = cloudRowFor({
    ...chunk,
    language: "en",
    docPath: "docs/en/References.md",
    heading: "References",
    headingLevel: 1,
    headingPath: ["References"],
    chunkIndex: 1,
    chunkCount: 1,
    contextNote: null,
    tags: ["evidence"],
    searchTokens: ["references"],
    status: "evidence",
    authority: "evidence",
    sourceHash: "source",
    contentHash: "content",
    manifestHash: "manifest",
  }, record, { corpus_id: "corpus", build_id: "build" }, model);
  assert.equal(row.authority, "evidence");
  assert.equal(row.embedding_model, model);
  assert.equal(row.embedding_dimension, EMBEDDING_DIMENSION);
  assert.equal(row.embedding_input_hash, record.embedding_input_hash);
});
