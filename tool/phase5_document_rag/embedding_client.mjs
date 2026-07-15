import { createHash } from "node:crypto";

export const EMBEDDING_DIMENSION = 1536;
export const EMBEDDING_INPUT_VERSION = "document_embedding_input.v1";
export const EMBEDDING_BATCH_SIZE = 10;

export function qwenEmbeddingEndpoint(baseUrl) {
  const value = baseUrl?.trim();
  if (!value) throw new Error("FITLOG_QWEN_BASE_URL is required for embedding generation");
  const url = new URL(value);
  const apiRoot = "/compatible-mode/v1";
  const rootIndex = url.pathname.indexOf(apiRoot);
  if (rootIndex === -1) throw new Error("FITLOG_QWEN_BASE_URL must use the compatible-mode/v1 API");
  url.pathname = `${url.pathname.slice(0, rootIndex)}${apiRoot}/embeddings`;
  url.search = "";
  url.hash = "";
  return url.toString();
}

export function embeddingInput(chunk) {
  return `${chunk.contextPrefix}${chunk.content}`;
}

export function embeddingInputHash(chunk, model) {
  return createHash("sha256")
    .update(`${EMBEDDING_INPUT_VERSION}\n${model}\n${embeddingInput(chunk)}`)
    .digest("hex");
}

export function isEmbeddingCurrent(record, chunk, { model, dimension = EMBEDDING_DIMENSION }) {
  return record?.chunk_hash === chunk.chunkHash &&
    record?.generator_version === chunk.generatorVersion &&
    record?.term_version === chunk.termVersion &&
    record?.embedding_model === model &&
    record?.embedding_dimension === dimension &&
    record?.embedding_input_hash === embeddingInputHash(chunk, model) &&
    Array.isArray(record?.embedding) && record.embedding.length === dimension &&
    record.embedding.every(Number.isFinite);
}

export async function createEmbeddings({
  inputs,
  apiKey,
  model,
  endpoint,
  fetchImpl = fetch,
  dimension = EMBEDDING_DIMENSION,
  maxAttempts = 3,
}) {
  if (!apiKey) throw new Error("FITLOG_QWEN_API_KEY is required for embedding generation");
  if (!endpoint) throw new Error("Qwen embedding endpoint is required for embedding generation");
  if (inputs.length === 0) return [];
  if (inputs.length > EMBEDDING_BATCH_SIZE) {
    throw new Error(`Qwen embedding batches must not exceed ${EMBEDDING_BATCH_SIZE} inputs`);
  }
  let lastError;
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      const response = await fetchImpl(endpoint, {
        method: "POST",
        headers: { authorization: `Bearer ${apiKey}`, "content-type": "application/json" },
        body: JSON.stringify({ model, input: inputs, dimensions: dimension }),
      });
      if (!response.ok) {
        const retryable = response.status === 429 || response.status >= 500;
        if (!retryable || attempt === maxAttempts) throw new Error(`embedding request failed (${response.status})`);
        await boundedBackoff(attempt);
        continue;
      }
      const body = await response.json();
      return validateEmbeddingResponse(body, { expectedCount: inputs.length, model, dimension });
    } catch (error) {
      lastError = error;
      if (attempt === maxAttempts || !isTransportError(error)) throw error;
      await boundedBackoff(attempt);
    }
  }
  throw lastError ?? new Error("embedding request failed");
}

export function validateEmbeddingResponse(body, { expectedCount, model, dimension }) {
  if (!body || body.model !== model || !Array.isArray(body.data) || body.data.length !== expectedCount) {
    throw new Error("embedding response model/count mismatch");
  }
  const ordered = [...body.data].sort((left, right) => left.index - right.index);
  return ordered.map((item, index) => {
    if (item.index !== index || !Array.isArray(item.embedding) || item.embedding.length !== dimension) {
      throw new Error("embedding response order/dimension mismatch");
    }
    if (!item.embedding.every(Number.isFinite)) throw new Error("embedding response contains non-finite values");
    return item.embedding;
  });
}

function isTransportError(error) {
  return error instanceof TypeError || /network|fetch|timeout|socket/i.test(String(error));
}

function boundedBackoff(attempt) {
  return new Promise((resolve) => setTimeout(resolve, Math.min(250 * 2 ** (attempt - 1), 1000)));
}
