import { assertEquals } from "jsr:@std/assert@1";
import { readPipelineRuntimeConfig } from "./pipeline_config.ts";

Deno.test("pipeline flags default to the legacy context path with retry off", () => {
  assertEquals(readPipelineRuntimeConfig(() => undefined), {
    contextPipelineVersion: "phase5_legacy",
    documentRagRetryEnabled: false,
  });
});

Deno.test("pipeline flags enable only explicit supported values", () => {
  const values: Record<string, string> = {
    AI_CONTEXT_PIPELINE_VERSION: " rag_foundation_v1 ",
    DOCUMENT_RAG_RETRY_ENABLED: " TRUE ",
  };
  assertEquals(readPipelineRuntimeConfig((name) => values[name]), {
    contextPipelineVersion: "rag_foundation_v1",
    documentRagRetryEnabled: true,
  });
});

Deno.test("invalid pipeline flag values fail closed", () => {
  const values: Record<string, string> = {
    AI_CONTEXT_PIPELINE_VERSION: "future_unreviewed",
    DOCUMENT_RAG_RETRY_ENABLED: "yes",
  };
  assertEquals(readPipelineRuntimeConfig((name) => values[name]), {
    contextPipelineVersion: "phase5_legacy",
    documentRagRetryEnabled: false,
  });
});

Deno.test("retired orchestrator flags cannot reactivate the legacy decision path", () => {
  const values: Record<string, string> = {
    AI_CHAT_ORCHESTRATOR_VERSION: "legacy",
    AI_CHAT_ORCHESTRATOR_SHADOW_ENABLED: "true",
  };
  assertEquals(readPipelineRuntimeConfig((name) => values[name]), {
    contextPipelineVersion: "phase5_legacy",
    documentRagRetryEnabled: false,
  });
});
