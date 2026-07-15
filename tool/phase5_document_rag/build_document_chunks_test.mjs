import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

import { chunkMarkdown, findProtectedRanges, splitLosslessly } from "./chunk_markdown.mjs";
import { loadAndValidateManifest, validateManifest } from "./validate_document_corpus.mjs";

const repoRoot = process.cwd();
const manifestPath = "tool/phase5_document_rag/document_corpus_manifest.v1.json";

test("canonical manifest exactly covers the stable bilingual corpus", () => {
  const { manifest } = loadAndValidateManifest({ repoRoot, manifestPath });
  assert.equal(manifest.sources.length, 21);
  assert.ok(manifest.sources.includes("docs/en/CloudLocalDataBoundary.md"));
  assert.ok(manifest.sources.includes("docs/zh/CloudLocalDataBoundary.md"));
  const unauthorized = structuredClone(manifest);
  unauthorized.sources.push("CHANGELOG.md");
  assert.ok(validateManifest({ repoRoot, manifest: unauthorized }).some((error) => error.includes("unauthorized")));
});

test("Markdown chunking is lossless, deterministic, and token safe", async () => {
  const markdown = await readFile("tool/phase5_document_rag/fixtures/lossless_markdown.md", "utf8");
  const input = {
    sourcePath: "docs/en/Fixture.md",
    markdown,
    manifestHash: "manifest",
    generatorVersion: "generator",
    termVersion: "terms",
    maxChunkLength: 180,
  };
  const first = chunkMarkdown(input);
  const second = chunkMarkdown(input);
  assert.deepEqual(first, second);
  assert.equal(first.map((chunk) => chunk.content).join(""), markdown);
  assert.equal(new Set(first.map((chunk) => chunk.sectionId)).size, first.length);
  assert.ok(first.every((chunk) => chunk.content !== ""));
  assert.ok(first.every((chunk) => chunk.contextPrefix.includes("Authority: current_product")));
  for (const token of [
    "[OpenAI](https://developers.openai.com/api/docs)",
    "CHANGELOG.md",
    "app_database.dart",
    "index.ts",
    "schema.sql",
    "gram_per_kg",
    "per_side_reps",
    "0.85",
    "v1.2.3",
    "2026-07-13",
    "RAG-S04",
  ]) {
    assert.ok(first.some((chunk) => chunk.content.includes(token)), token);
  }
  assert.doesNotMatch(first.map((chunk) => chunk.content).join(""), /\. (?:dart|ts|sql)|developers\. openai\. com/);
  assert.equal(first.filter((chunk) => chunk.heading === "Repeated").length >= 2, true);
});

test("a single oversized protected token remains intact", () => {
  const token = `https://example.com/${"a".repeat(300)}`;
  const chunks = splitLosslessly(`before ${token} after`, 80);
  assert.ok(chunks.some((chunk) => chunk.includes(token)));
  assert.equal(chunks.join(""), `before ${token} after`);
  assert.ok(findProtectedRanges(token).length > 0);
});

test("generated corpus is complete and contains no corruption patterns", async () => {
  const artifact = JSON.parse(await readFile("tool/phase5_document_rag/document_corpus_build.v1.json", "utf8"));
  const { manifest } = loadAndValidateManifest({ repoRoot, manifestPath });
  assert.deepEqual(artifact.sources, manifest.sources);
  assert.equal(artifact.source_count, 21);
  assert.equal(new Set(artifact.chunks.map((chunk) => chunk.sectionId)).size, artifact.chunks.length);
  assert.ok(artifact.chunks.filter((chunk) => chunk.docPath.endsWith("CloudLocalDataBoundary.md")).length > 0);
  assert.ok(artifact.chunks.every((chunk) => Array.isArray(chunk.searchTokens)));
  assert.ok(artifact.chunks.every((chunk) => ["current_product", "planned", "non_goal", "evidence"].includes(chunk.authority)));
  assert.ok(artifact.chunks.some((chunk) => chunk.status === "evidence" && chunk.authority === "evidence"));
  assert.ok(artifact.chunks.some((chunk) => chunk.status === "non_goal" && chunk.authority === "non_goal"));
  assert.ok(artifact.chunks.some((chunk) => chunk.searchTokens.includes("per_side_reps")));
  assert.ok(artifact.chunks.some((chunk) => chunk.searchTokens.includes("每侧次数")));
  assert.ok(artifact.chunks.some((chunk) => chunk.searchTokens.includes("产品承诺")));
  const contents = artifact.chunks.map((chunk) => chunk.content).join("\n");
  assert.doesNotMatch(contents, /\. (?:dart|ts|sql)|developers\. openai\. com/);
  const seed = await readFile("supabase/seed_phase5_document_chunks.sql", "utf8");
  assert.match(seed, /tags, search_tokens, status, authority/);
  assert.doesNotMatch(seed, /select public\.activate_document_corpus_build/);
});
