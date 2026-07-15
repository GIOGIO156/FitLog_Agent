export const searchFitLogDocsTool = {
  name: "search_fitlog_docs",
  description: "Search the current stable FitLog product documentation using a bounded query rewrite.",
  parameters: {
    type: "object",
    additionalProperties: false,
    properties: {
      query_variants: { type: "array", minItems: 1, maxItems: 3, items: { type: "string", minLength: 1, maxLength: 200 } },
      required_concepts: { type: "array", maxItems: 6, items: { type: "string", minLength: 1, maxLength: 80 } },
    },
    required: ["query_variants", "required_concepts"],
  },
} as const;

export interface SearchFitLogDocsArguments {
  query_variants: string[];
  required_concepts: string[];
}

export function parseSearchFitLogDocsArguments(value: unknown): SearchFitLogDocsArguments | null {
  if (!isRecord(value)) return null;
  if (Object.keys(value).some((key) => key !== "query_variants" && key !== "required_concepts")) return null;
  const variants = boundedStrings(value.query_variants, 3, 200);
  const concepts = boundedStrings(value.required_concepts, 6, 80);
  if (variants === null || variants.length === 0 || concepts === null) return null;
  if (variants.some((item) => /\b(select|insert|update|delete|drop|alter)\b|\bsql\b|corpus_id|account_id|service_role/i.test(item))) return null;
  return { query_variants: variants, required_concepts: concepts };
}

export function openAiRetrievalToolDefinition() {
  return { type: "function", name: searchFitLogDocsTool.name, description: searchFitLogDocsTool.description, parameters: searchFitLogDocsTool.parameters, strict: true };
}

export function qwenRetrievalToolDefinition() {
  return { type: "function", function: { name: searchFitLogDocsTool.name, description: searchFitLogDocsTool.description, parameters: searchFitLogDocsTool.parameters } };
}

function boundedStrings(value: unknown, maximum: number, maxLength: number): string[] | null {
  if (!Array.isArray(value) || value.length > maximum || value.some((item) => typeof item !== "string")) return null;
  const items = [...new Set(value.map((item) => item.trim()).filter(Boolean))];
  return items.some((item) => item.length > maxLength) ? null : items;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
