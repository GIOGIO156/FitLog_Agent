export type AiContextPipelineVersion = "phase5_legacy" | "rag_foundation_v1";

export interface PipelineRuntimeConfig {
  contextPipelineVersion: AiContextPipelineVersion;
  documentRagRetryEnabled: boolean;
}

type EnvReader = (name: string) => string | undefined;

export function readPipelineRuntimeConfig(
  readEnv: EnvReader = (name) => Deno.env.get(name),
): PipelineRuntimeConfig {
  const requestedVersion = readEnv("AI_CONTEXT_PIPELINE_VERSION")?.trim();
  return {
    contextPipelineVersion: requestedVersion === "rag_foundation_v1"
      ? "rag_foundation_v1"
      : "phase5_legacy",
    documentRagRetryEnabled:
      readEnv("DOCUMENT_RAG_RETRY_ENABLED")?.trim().toLowerCase() === "true",
  };
}
