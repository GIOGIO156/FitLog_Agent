export const queryEmbeddingDimension = 1536;

export function qwenEmbeddingEndpoint(baseUrl: string): string {
  const value = baseUrl.trim();
  if (value === "") {
    throw new Error("FITLOG_QWEN_BASE_URL is required for query embedding");
  }
  const url = new URL(value);
  const apiRoot = "/compatible-mode/v1";
  const rootIndex = url.pathname.indexOf(apiRoot);
  if (rootIndex === -1) {
    throw new Error("FITLOG_QWEN_BASE_URL must use the compatible-mode/v1 API");
  }
  url.pathname = `${url.pathname.slice(0, rootIndex)}${apiRoot}/embeddings`;
  url.search = "";
  url.hash = "";
  return url.toString();
}

export interface QueryEmbeddingConfig {
  endpoint: string;
  apiKey: string;
  model: string;
  timeoutMs: number;
}

export interface QueryEmbeddingResult {
  vector: number[] | null;
  issue: "embedding_unavailable" | null;
}

export async function embedNormalizedQuery(
  config: QueryEmbeddingConfig,
  variants: string[],
  fetchImpl: typeof fetch = fetch,
): Promise<QueryEmbeddingResult> {
  const input = variants.map((item) => item.trim()).filter(Boolean).slice(0, 6)
    .join("\n");
  if (input === "") return { vector: null, issue: null };
  const controller = new AbortController();
  const timeout = setTimeout(
    () => controller.abort(),
    Math.min(Math.max(config.timeoutMs, 250), 5000),
  );
  try {
    const response = await fetchImpl(config.endpoint, {
      method: "POST",
      headers: {
        authorization: `Bearer ${config.apiKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: config.model,
        input,
        dimensions: queryEmbeddingDimension,
      }),
      signal: controller.signal,
    });
    if (!response.ok) return { vector: null, issue: "embedding_unavailable" };
    const body = await response.json();
    const vector = body?.data?.[0]?.embedding;
    if (
      body?.model !== config.model || !Array.isArray(vector) ||
      vector.length !== queryEmbeddingDimension ||
      !vector.every(Number.isFinite)
    ) {
      return { vector: null, issue: "embedding_unavailable" };
    }
    return { vector, issue: null };
  } catch {
    return { vector: null, issue: "embedding_unavailable" };
  } finally {
    clearTimeout(timeout);
  }
}
