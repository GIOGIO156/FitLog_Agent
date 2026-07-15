import { existsSync, readFileSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  createEmbeddings,
  EMBEDDING_BATCH_SIZE,
  EMBEDDING_DIMENSION,
  EMBEDDING_INPUT_VERSION,
  embeddingInput,
  embeddingInputHash,
  isEmbeddingCurrent,
  qwenEmbeddingEndpoint,
} from "./embedding_client.mjs";

const repoRoot = process.cwd();
const artifactPath = path.join(repoRoot, "tool/phase5_document_rag/document_corpus_build.v1.json");
const embeddingPath = path.join(repoRoot, "tool/phase5_document_rag/document_embeddings.v1.json");
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const mode = process.argv.find((argument) => argument.startsWith("--")) ?? "--dry-run";
  const model = process.env.FITLOG_DOCUMENT_EMBEDDING_MODEL ?? "text-embedding-v4";
  const corpus = JSON.parse(readFileSync(artifactPath, "utf8"));
  const existing = readOptionalJson(embeddingPath) ?? emptyArtifact(corpus, model);

  if (mode === "--dry-run") {
    const parity = localParity(corpus, existing, model);
    console.log(JSON.stringify(parity));
  } else if (mode === "--build-local") {
    const recordsById = new Map(existing.records.map((record) => [record.section_id, record]));
    const stale = corpus.chunks.filter((chunk) => !isEmbeddingCurrent(recordsById.get(chunk.sectionId), chunk, { model }));
    const endpoint = qwenEmbeddingEndpoint(requiredEnv("FITLOG_QWEN_BASE_URL"));
    const batchSize = EMBEDDING_BATCH_SIZE;
    for (let start = 0; start < stale.length; start += batchSize) {
      const batch = stale.slice(start, start + batchSize);
      const vectors = await createEmbeddings({
        inputs: batch.map(embeddingInput),
        apiKey: process.env.FITLOG_QWEN_API_KEY,
        model,
        endpoint,
      });
      for (let index = 0; index < batch.length; index += 1) {
        const chunk = batch[index];
        recordsById.set(chunk.sectionId, recordFor(chunk, vectors[index], model));
      }
      await writeJsonAtomically(embeddingPath, {
        ...emptyArtifact(corpus, model),
        records: [...recordsById.values()],
      });
    }
    await writeJsonAtomically(embeddingPath, {
      ...emptyArtifact(corpus, model),
      records: currentEmbeddingRecords(corpus, recordsById.values()),
    });
    console.log(JSON.stringify(localParity(corpus, readOptionalJson(embeddingPath), model)));
  } else if (mode === "--sync-cloud" || mode === "--verify-cloud") {
    await cloudMode({ mode, corpus, embeddings: existing, model });
  } else {
    throw new Error(`Unknown mode: ${mode}`);
  }
}

export function localParity(corpus, embeddings, model) {
  const records = new Map((embeddings?.records ?? []).map((record) => [record.section_id, record]));
  const missing = [];
  const stale = [];
  for (const chunk of corpus.chunks) {
    const record = records.get(chunk.sectionId);
    if (!record) missing.push(chunk.sectionId);
    else if (!isEmbeddingCurrent(record, chunk, { model })) stale.push(chunk.sectionId);
  }
  const chunkIds = new Set(corpus.chunks.map((chunk) => chunk.sectionId));
  const extra = [...records.keys()].filter((id) => !chunkIds.has(id));
  return {
    corpus_id: corpus.corpus_id,
    build_id: corpus.build_id,
    chunks: corpus.chunks.length,
    matching: corpus.chunks.length - missing.length - stale.length,
    missing: missing.length,
    stale: stale.length,
    extra: extra.length,
    model,
    dimension: EMBEDDING_DIMENSION,
  };
}

export function currentEmbeddingRecords(corpus, records) {
  const currentSectionIds = new Set(corpus.chunks.map((chunk) => chunk.sectionId));
  return [...records].filter((record) => currentSectionIds.has(record.section_id));
}

function recordFor(chunk, embedding, model) {
  return {
    section_id: chunk.sectionId,
    chunk_hash: chunk.chunkHash,
    generator_version: chunk.generatorVersion,
    term_version: chunk.termVersion,
    embedding_model: model,
    embedding_dimension: EMBEDDING_DIMENSION,
    embedding_input_version: EMBEDDING_INPUT_VERSION,
    embedding_input_hash: embeddingInputHash(chunk, model),
    embedding,
  };
}

function emptyArtifact(corpus, model) {
  return {
    schema: "fitlog_document_embeddings.v1",
    corpus_id: corpus.corpus_id,
    build_id: corpus.build_id,
    model,
    dimension: EMBEDDING_DIMENSION,
    input_version: EMBEDDING_INPUT_VERSION,
    records: [],
  };
}

async function cloudMode({ mode, corpus, embeddings, model }) {
  const supabaseUrl = requiredEnv("SUPABASE_URL");
  const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  const parity = localParity(corpus, embeddings, model);
  if (parity.missing !== 0 || parity.stale !== 0 || parity.extra !== 0) {
    throw new Error(`Local embedding parity failed: ${JSON.stringify(parity)}`);
  }
  if (mode === "--sync-cloud") {
    const existingBuilds = await restJson(
      supabaseUrl,
      serviceRoleKey,
      `document_corpus_builds?select=state&corpus_id=eq.${corpus.corpus_id}&build_id=eq.${corpus.build_id}`,
    );
    if (existingBuilds[0]?.state !== "active") {
      if (existingBuilds[0]?.state !== "staging") {
        await rpc(supabaseUrl, serviceRoleKey, "begin_document_corpus_build", {
          input_corpus_id: corpus.corpus_id,
          input_build_id: corpus.build_id,
          input_manifest_hash: corpus.manifest_hash,
          input_generator_version: corpus.generator_version,
          input_term_version: corpus.term_version,
          input_expected_source_count: corpus.source_count,
          input_expected_chunk_count: corpus.chunk_count,
        });
      }
      const byId = new Map(embeddings.records.map((record) => [record.section_id, record]));
      const rows = corpus.chunks.map((chunk) => cloudRowFor(chunk, byId.get(chunk.sectionId), corpus, model));
      for (let start = 0; start < rows.length; start += EMBEDDING_BATCH_SIZE) {
        const response = await fetchWithRetry(
          `${supabaseUrl}/rest/v1/document_chunks?on_conflict=corpus_id,build_id,language,doc_path,section_id`,
          {
            method: "POST",
            headers: serviceHeaders(serviceRoleKey, "resolution=merge-duplicates,return=minimal"),
            body: JSON.stringify(rows.slice(start, start + EMBEDDING_BATCH_SIZE)),
          },
          "Cloud corpus/vector upsert",
        );
        if (!response.ok) throw new Error(`Cloud corpus/vector upsert failed (${response.status})`);
      }
      await restPatch(supabaseUrl, serviceRoleKey, `document_corpus_builds?corpus_id=eq.${corpus.corpus_id}&build_id=eq.${corpus.build_id}`, {
        embedding_model: model,
        embedding_dimension: EMBEDDING_DIMENSION,
      });
      await rpc(supabaseUrl, serviceRoleKey, "activate_document_corpus_build", {
        input_corpus_id: corpus.corpus_id,
        input_build_id: corpus.build_id,
        input_expected_source_count: corpus.source_count,
        input_expected_chunk_count: corpus.chunk_count,
        input_require_embeddings: true,
      });
    }
  }
  const rows = await restJson(supabaseUrl, serviceRoleKey, `document_chunks?select=section_id,chunk_hash,embedding_model,embedding_dimension,embedding_input_hash&corpus_id=eq.${corpus.corpus_id}&build_id=eq.${corpus.build_id}`);
  const cloudById = new Map(rows.map((row) => [row.section_id, row]));
  const mismatched = corpus.chunks.filter((chunk) => {
    const local = embeddings.records.find((record) => record.section_id === chunk.sectionId);
    const cloud = cloudById.get(chunk.sectionId);
    return !cloud || cloud.chunk_hash !== chunk.chunkHash || cloud.embedding_model !== model || cloud.embedding_dimension !== EMBEDDING_DIMENSION || cloud.embedding_input_hash !== local.embedding_input_hash;
  });
  const report = { ...parity, cloud_rows: rows.length, cloud_mismatched: mismatched.length };
  console.log(JSON.stringify(report));
  if (rows.length !== corpus.chunk_count || mismatched.length > 0) throw new Error("Cloud corpus/embedding parity failed");
}

export function cloudRowFor(chunk, record, corpus, model) {
  if (!record) throw new Error(`Missing embedding record for ${chunk.sectionId}`);
  return {
    corpus_id: corpus.corpus_id,
    build_id: corpus.build_id,
    language: chunk.language,
    doc_path: chunk.docPath,
    heading: chunk.heading,
    heading_level: chunk.headingLevel,
    heading_path: chunk.headingPath,
    section_id: chunk.sectionId,
    chunk_index: chunk.chunkIndex,
    chunk_count: chunk.chunkCount,
    content: chunk.content,
    context_prefix: chunk.contextPrefix,
    context_note: chunk.contextNote,
    tags: chunk.tags,
    search_tokens: chunk.searchTokens,
    status: chunk.status,
    authority: chunk.authority,
    source_hash: chunk.sourceHash,
    chunk_hash: chunk.chunkHash,
    content_hash: chunk.contentHash,
    manifest_hash: chunk.manifestHash,
    generator_version: chunk.generatorVersion,
    term_version: chunk.termVersion,
    embedding: record.embedding,
    embedding_model: model,
    embedding_dimension: EMBEDDING_DIMENSION,
    embedding_input_hash: record.embedding_input_hash,
    embedding_normalization_version: EMBEDDING_INPUT_VERSION,
    embedding_generated_at: new Date().toISOString(),
  };
}

function readOptionalJson(filePath) {
  try { return JSON.parse(readFileSync(filePath, "utf8")); } catch (error) {
    if (error?.code === "ENOENT") return null;
    throw error;
  }
}

async function writeJsonAtomically(filePath, value) {
  const temporaryPath = `${filePath}.tmp`;
  const backupPath = `${filePath}.bak`;
  if (!existsSync(filePath) && existsSync(backupPath)) renameSync(backupPath, filePath);
  if (existsSync(filePath) && existsSync(backupPath)) unlinkSync(backupPath);
  writeFileSync(temporaryPath, `${JSON.stringify(value, null, 2)}\n`, "utf8");
  let lastError;
  for (let attempt = 1; attempt <= 5; attempt += 1) {
    let backupCreated = false;
    try {
      if (existsSync(filePath)) {
        renameSync(filePath, backupPath);
        backupCreated = true;
      }
      renameSync(temporaryPath, filePath);
      if (backupCreated) unlinkSync(backupPath);
      return;
    } catch (error) {
      lastError = error;
      if (backupCreated && !existsSync(filePath) && existsSync(backupPath)) {
        renameSync(backupPath, filePath);
      }
      await new Promise((resolve) => setTimeout(resolve, attempt * 100));
    }
  }
  try {
    unlinkSync(temporaryPath);
  } catch (cleanupError) {
    if (cleanupError?.code !== "ENOENT") throw cleanupError;
  }
  throw lastError ?? new Error("Embedding artifact replacement failed");
}

function requiredEnv(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

function serviceHeaders(key, prefer = "return=minimal") {
  return { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json", prefer };
}

async function rpc(url, key, name, body) {
  const response = await fetchWithRetry(
    `${url}/rest/v1/rpc/${name}`,
    { method: "POST", headers: serviceHeaders(key), body: JSON.stringify(body) },
    name,
  );
  if (!response.ok) throw new Error(`${name} failed (${response.status})`);
}

async function restJson(url, key, query) {
  const response = await fetchWithRetry(
    `${url}/rest/v1/${query}`,
    { headers: serviceHeaders(key) },
    "Cloud verification",
  );
  if (!response.ok) throw new Error(`Cloud verification failed (${response.status})`);
  const body = await response.json();
  if (!Array.isArray(body)) throw new Error("Cloud verification returned an invalid body");
  return body;
}

async function restPatch(url, key, query, body) {
  const response = await fetchWithRetry(
    `${url}/rest/v1/${query}`,
    { method: "PATCH", headers: serviceHeaders(key), body: JSON.stringify(body) },
    "Cloud metadata update",
  );
  if (!response.ok) throw new Error(`Cloud metadata update failed (${response.status})`);
}

async function fetchWithRetry(url, init, label, maxAttempts = 5) {
  let lastError;
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      const response = await fetch(url, init);
      if (response.status !== 429 && response.status < 500) return response;
      lastError = new Error(`${label} failed (${response.status})`);
    } catch (error) {
      lastError = error;
    }
    if (attempt < maxAttempts) {
      await new Promise((resolve) => setTimeout(resolve, Math.min(250 * 2 ** (attempt - 1), 2000)));
    }
  }
  throw lastError ?? new Error(`${label} failed`);
}
