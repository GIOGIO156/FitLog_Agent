import type { GatewayRequest } from "./contracts.ts";
import type { Phase5DocumentSource } from "./phase5_types.ts";

export interface SupabaseRestEnv {
  supabaseUrl: string;
  supabaseServiceRoleKey: string;
}

export async function searchDocumentSources(
  env: SupabaseRestEnv,
  request: GatewayRequest,
  limit = 6,
): Promise<Phase5DocumentSource[]> {
  const response = await fetch(
    `${env.supabaseUrl}/rest/v1/rpc/search_document_chunks`,
    {
      method: "POST",
      headers: serviceHeaders(env),
      body: JSON.stringify({
        input_language: documentLanguage(request),
        input_query: request.messageText,
        input_limit: limit,
      }),
    },
  );
  if (!response.ok) {
    return [];
  }
  const rows = await response.json();
  if (!Array.isArray(rows)) {
    return [];
  }
  return rows.map(documentSourceFromRow).filter((item) => item !== null);
}

export function documentLanguage(request: GatewayRequest): "zh" | "en" {
  const text = request.messageText;
  const cjk = [...text].filter((char) => {
    const code = char.codePointAt(0) ?? 0;
    return (code >= 0x4e00 && code <= 0x9fff) ||
      (code >= 0x3400 && code <= 0x4dbf);
  }).length;
  const asciiLetters = [...text].filter((char) => /[A-Za-z]/.test(char)).length;
  if (cjk > 0 && cjk >= asciiLetters * 0.2) {
    return "zh";
  }
  return request.language;
}

function documentSourceFromRow(row: unknown): Phase5DocumentSource | null {
  if (typeof row !== "object" || row === null || Array.isArray(row)) {
    return null;
  }
  const map = row as Record<string, unknown>;
  const docPath = stringField(map, "doc_path");
  const heading = stringField(map, "heading");
  const headingPath = stringArrayField(map, "heading_path");
  const sectionId = stringField(map, "section_id");
  const status = stringField(map, "status") || "implemented";
  const content = stringField(map, "content");
  const contextPrefix = stringField(map, "context_prefix");
  const contextNote = nullableStringField(map, "context_note");
  const chunkIndex = integerField(map, "chunk_index", 1);
  const chunkCount = Math.max(integerField(map, "chunk_count", 1), chunkIndex);
  if (docPath === "" || heading === "" || sectionId === "" || content === "") {
    return null;
  }
  return {
    doc_path: docPath,
    heading,
    heading_path: headingPath.length === 0 ? [heading] : headingPath,
    section_id: sectionId,
    chunk_index: chunkIndex,
    chunk_count: chunkCount,
    status,
    score: numberField(map, "score"),
    context_prefix: contextPrefix,
    context_note: contextNote,
    excerpt: content.length > 900 ? `${content.slice(0, 900)}...` : content,
  };
}

function serviceHeaders(env: SupabaseRestEnv): HeadersInit {
  return {
    apikey: env.supabaseServiceRoleKey,
    authorization: `Bearer ${env.supabaseServiceRoleKey}`,
    "content-type": "application/json",
  };
}

function stringField(map: Record<string, unknown>, key: string): string {
  const value = map[key];
  return typeof value === "string" ? value.trim() : "";
}

function nullableStringField(
  map: Record<string, unknown>,
  key: string,
): string | null {
  const value = stringField(map, key);
  return value === "" ? null : value;
}

function stringArrayField(map: Record<string, unknown>, key: string): string[] {
  const value = map[key];
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .map((item) => String(item).trim())
    .filter((item) => item !== "");
}

function numberField(map: Record<string, unknown>, key: string): number {
  const value = map[key];
  const parsed = typeof value === "number"
    ? value
    : Number.parseFloat(String(value ?? ""));
  return Number.isFinite(parsed) ? parsed : 0;
}

function integerField(
  map: Record<string, unknown>,
  key: string,
  fallback: number,
): number {
  const parsed = Math.trunc(numberField(map, key));
  return parsed >= 1 ? parsed : fallback;
}
