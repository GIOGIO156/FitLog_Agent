import {
  extractBearerToken,
  extractSessionIdFromAccessToken,
  GatewayRequestError,
  gatewayResponse,
  parseGatewayRequest,
  parseProviderGatewayBody,
} from "./contracts.ts";
import { buildPhase5Context } from "./context_builders.ts";
import { MockProviderError, runMockProvider } from "./mock_provider.ts";
import { extractOpenAiCompletion } from "./openai_provider.ts";
import type { Phase5WorkflowRoute } from "./phase5_types.ts";
import { providerForChoice } from "./providers.ts";
import {
  phase5PromptContext,
  prependMealDecisionImageTip,
} from "./prompt_builder.ts";
import { extractQwenCompletion } from "./qwen_provider.ts";
import { OutputContractError } from "../_shared/ai_output_contract.ts";

Deno.test("parseGatewayRequest accepts the Step 2 text-only contract", () => {
  const parsed = parseGatewayRequest({
    session_id: "00000000-0000-4000-8000-000000000001",
    message: { text: " hello " },
    language: "en",
    model_choice: "chatgpt",
    workflow_hint: "auto",
    selected_date: "2026-06-29",
    profile_version: "profile_1",
    device_id: "device-a",
  });

  assertEquals(parsed.messageText, "hello");
  assertEquals(parsed.modelChoice, "chatgpt");
  assertEquals(parsed.workflowType, "auto");
  assertEquals(parsed.deviceId, "device-a");
  assertEquals(parsed.attachments.length, 0);
  assertEquals(parsed.allowRecordSummaryContext, false);
  assertEquals(parsed.phase5Context, null);
});

Deno.test("controlled context stays product-facing and meal advice gets image guidance", () => {
  const base = parseGatewayRequest({
    message: { text: "晚饭怎么吃？" },
    language: "zh",
    model_choice: "qwen",
    workflow_hint: "meal_decision",
    device_id: "device-a",
  });
  const request = {
    ...base,
    workflowType: "meal_decision" as const,
    phase5Context: {
      route: {
        workflow: "meal_decision" as const,
        confidence: 1,
        reasons: ["test"],
        required_context: [],
        safety_flags: [],
        read_only: true,
      },
      context_objects: [],
      document_sources: [],
      retrieved_dimensions: [],
      missing_dimensions: [],
      safety_flags: [],
      called_tools: [],
    },
  };
  const prompt = phase5PromptContext(request);
  assertEquals(prompt.includes("Phase 5"), false);
  const answer = prependMealDecisionImageTip("优先补充蛋白质。", request);
  assert(answer.startsWith("你也可以上传现有食材照片或外卖平台截图"));
});

Deno.test("parseGatewayRequest accepts compact conversation context", () => {
  const parsed = parseGatewayRequest({
    session_id: "00000000-0000-4000-8000-000000000001",
    message: { text: "what about training?" },
    language: "en",
    model_choice: "qwen",
    workflow_hint: "auto",
    device_id: "device-a",
    allow_record_summary_context: true,
    conversation_context: {
      messages: [
        { role: "user", text: "Can this meal be logged?" },
        { role: "assistant", text: "A food draft was generated." },
      ],
      artifacts: [
        {
          type: "food_draft",
          title: "Chicken rice",
          summary: "Food draft artifact, about 520 kcal",
        },
      ],
    },
  });

  assertEquals(parsed.conversationContext?.messages.length, 2);
  assertEquals(parsed.conversationContext?.artifacts[0].type, "food_draft");
  assertEquals(parsed.allowRecordSummaryContext, true);
});

Deno.test("parseGatewayRequest accepts up to three Qwen image attachments", () => {
  const parsed = parseGatewayRequest({
    message: { text: "Can this work as dinner?" },
    language: "en",
    model_choice: "qwen",
    workflow_hint: "meal_decision",
    device_id: "device-a",
    attachments: [{
      kind: "image",
      mime_type: "image/png",
      base64_data: "abc123",
      byte_length: 128,
      name: "meal.png",
    }, {
      kind: "image",
      mime_type: "image/jpeg",
      base64_data: "def456",
      byte_length: 256,
      name: "label.jpg",
    }, {
      kind: "image",
      mime_type: "image/webp",
      base64_data: "ghi789",
      byte_length: 384,
      name: "portion.webp",
    }],
  });

  assertEquals(parsed.attachments.length, 3);
  assertEquals(parsed.attachments[0].mimeType, "image/png");
  assertEquals(parsed.attachments[0].name, "meal.png");
  assertEquals(parsed.attachments[2].mimeType, "image/webp");
});

Deno.test("parseGatewayRequest rejects future-phase fields", () => {
  assertThrowsGatewayRequest(() =>
    parseGatewayRequest({
      message: { text: "inspect image" },
      language: "en",
      model_choice: "qwen",
      workflow_hint: "food_logging",
      device_id: "device-a",
      context_objects: [{ kind: "profile" }],
    })
  );
  assertThrowsGatewayRequest(() =>
    parseGatewayRequest({
      message: { text: "inspect image" },
      language: "en",
      model_choice: "qwen",
      workflow_hint: "food_logging",
      device_id: "device-a",
      evidence: { workflow: "auto" },
    })
  );
});

Deno.test("parseGatewayRequest rejects unsupported image requests", () => {
  assertThrowsGatewayRequest(() =>
    parseGatewayRequest({
      message: { text: "inspect image" },
      language: "en",
      model_choice: "chatgpt",
      workflow_hint: "food_logging",
      device_id: "device-a",
      attachments: [{
        kind: "image",
        mime_type: "image/jpeg",
        base64_data: "abc123",
        byte_length: 128,
      }],
    })
  );

  assertThrowsGatewayRequest(() =>
    parseGatewayRequest({
      message: { text: "inspect image" },
      language: "en",
      model_choice: "qwen",
      workflow_hint: "food_logging",
      device_id: "device-a",
      attachments: [{
        kind: "image",
        mime_type: "image/gif",
        base64_data: "abc123",
        byte_length: 128,
      }],
    })
  );

  assertThrowsGatewayRequest(() =>
    parseGatewayRequest({
      message: { text: "inspect image" },
      language: "en",
      model_choice: "qwen",
      workflow_hint: "food_logging",
      device_id: "device-a",
      attachments: [{
        kind: "image",
        mime_type: "image/png",
        base64_data: "abc123",
        byte_length: 5 * 1024 * 1024,
      }],
    })
  );

  assertThrowsGatewayRequest(() =>
    parseGatewayRequest({
      message: { text: "inspect images" },
      language: "en",
      model_choice: "qwen",
      workflow_hint: "food_logging",
      device_id: "device-a",
      attachments: [0, 1, 2, 3].map((index) => ({
        kind: "image",
        mime_type: "image/png",
        base64_data: `abc${index}`,
        byte_length: 128,
      })),
    })
  );
});

Deno.test("parseGatewayRequest rejects unsupported model and workflow", () => {
  assertThrowsGatewayRequest(() =>
    parseGatewayRequest({
      message: { text: "hello" },
      language: "en",
      model_choice: "provider_raw",
      workflow_hint: "auto",
      device_id: "device-a",
    })
  );

  assertThrowsGatewayRequest(() =>
    parseGatewayRequest({
      message: { text: "hello" },
      language: "en",
      model_choice: "chatgpt",
      workflow_hint: "open_agent_loop",
      device_id: "device-a",
    })
  );
});

Deno.test("buildPhase5Context does not fetch record summaries without permission", async () => {
  const originalFetch = globalThis.fetch;
  const requestedUrls: string[] = [];
  const fakeFetch = ((url: string | URL | Request) => {
    requestedUrls.push(url.toString());
    return Promise.resolve(new Response("[]", { status: 200 }));
  }) as typeof fetch;

  try {
    (globalThis as unknown as { fetch: typeof fetch }).fetch = fakeFetch;
    const request = parseGatewayRequest({
      message: { text: "review my week" },
      language: "en",
      model_choice: "chatgpt",
      workflow_hint: "weekly_review",
      selected_date: "2026-07-08",
      device_id: "device-a",
    });
    const route: Phase5WorkflowRoute = {
      workflow: "weekly_review",
      confidence: 1,
      reasons: ["test"],
      required_context: [
        "selected_day_summary",
        "recent_food_summary",
        "recent_workout_summary",
        "body_metric_summary",
        "weight_trend_summary",
      ],
      safety_flags: [],
      read_only: true,
    };

    const context = await buildPhase5Context(
      {
        supabaseUrl: "https://example.test",
        supabaseServiceRoleKey: "service-key",
      },
      "acct_1",
      request,
      route,
    );

    assertEquals(requestedUrls, []);
    assertEquals(context.called_tools, []);
    assert(context.missing_dimensions.includes("recent_food_summary"));
    assert(context.missing_dimensions.includes("weight_trend_summary"));
    assert(context.safety_flags.includes("record_summary_context_not_allowed"));
  } finally {
    (globalThis as unknown as { fetch: typeof fetch }).fetch = originalFetch;
  }
});

Deno.test("extractSessionIdFromAccessToken uses session claim fallback order", () => {
  const token = tokenFor({
    sub: "acct",
    session_id: "session-primary",
    sid: "session-secondary",
    jti: "session-tertiary",
  });
  const sidToken = tokenFor({ sub: "acct", sid: "session-secondary" });
  const jtiToken = tokenFor({ sub: "acct", jti: "session-tertiary" });

  assertEquals(extractSessionIdFromAccessToken(token), "session-primary");
  assertEquals(extractSessionIdFromAccessToken(sidToken), "session-secondary");
  assertEquals(extractSessionIdFromAccessToken(jtiToken), "session-tertiary");
  assertEquals(extractSessionIdFromAccessToken("not-a-jwt"), null);
});

Deno.test("extractBearerToken parses Authorization header", () => {
  assertEquals(extractBearerToken("Bearer token_1"), "token_1");
  assertEquals(extractBearerToken("bearer token_2"), "token_2");
  assertEquals(extractBearerToken("token_3"), null);
});

Deno.test("gatewayResponse emits Step 1-compatible error envelope", () => {
  const body = gatewayResponse({
    modelChoice: "qwen",
    language: "en",
    workflow: "meal_decision",
    error: {
      code: "subscription_required",
      message: "AI subscription is required.",
    },
  });

  assertEquals(body.model_choice, "qwen");
  assertEquals(body.model_provider, null);
  assertEquals((body.message as Record<string, unknown>).language, "en");
  assertEquals(
    (body.error as Record<string, unknown>).code,
    "subscription_required",
  );
  assertEquals(body.draft, null);
});

Deno.test("gatewayResponse emits Phase 5 evidence envelope", () => {
  const body = gatewayResponse({
    modelChoice: "chatgpt",
    language: "en",
    workflow: "app_logic_answer",
    evidence: {
      workflow: "app_logic_answer",
      context_objects: ["document_context"],
      document_sources: [{
        doc_path: "docs/en/AgentDesign.md",
        heading: "Agent V1",
        heading_path: ["Agent Design", "Agent V1"],
        section_id: "agent-v1",
        chunk_index: 1,
        chunk_count: 1,
        status: "implemented",
        score: 1.2,
        context_prefix:
          "Source: docs/en/AgentDesign.md > Agent Design > Agent V1.",
        context_note: null,
        excerpt: "Phase 5 uses controlled document retrieval.",
      }],
      missing_dimensions: [],
      safety_flags: [],
      user_final_action: "read_only",
    },
  });

  const evidence = body.evidence as Record<string, unknown>;
  assertEquals(evidence.workflow, "app_logic_answer");
  assertEquals(
    (evidence.document_sources as Record<string, unknown>[])[0].doc_path,
    "docs/en/AgentDesign.md",
  );
});

Deno.test("parseProviderGatewayBody parses multimodal JSON with food draft", () => {
  const request = parseGatewayRequest({
    message: { text: "log this food" },
    language: "en",
    model_choice: "qwen",
    workflow_hint: "food_logging",
    device_id: "device-a",
    attachments: [{
      kind: "image",
      mime_type: "image/jpeg",
      base64_data: "abc123",
      byte_length: 128,
    }],
  });
  const parsed = parseProviderGatewayBody(
    JSON.stringify({
      schema_version: "provider_gateway_envelope.v2",
      output_type: "food_draft",
      message: { text: "Review this draft before saving." },
      needs_clarification: false,
      clarification_questions: [],
      draft: validDraft(),
    }),
    { ...request, expectedOutput: "food_draft" },
  );

  assertEquals(parsed.messageText, "Review this draft before saving.");
  assertEquals(
    (parsed.draft as { meal_name: string }).meal_name,
    "Chicken rice",
  );
  assertEquals(parsed.needsClarification, false);
});

Deno.test("parseProviderGatewayBody normalizes food draft meal totals from items", () => {
  const request = parseGatewayRequest({
    message: { text: "log this food" },
    language: "en",
    model_choice: "qwen",
    workflow_hint: "food_logging",
    device_id: "device-a",
  });
  const parsed = parseProviderGatewayBody(
    JSON.stringify({
      schema_version: "provider_gateway_envelope.v2",
      output_type: "food_draft",
      message: { text: "Review this draft before saving." },
      needs_clarification: false,
      clarification_questions: [],
      draft: mismatchedFoodDraft(),
    }),
    { ...request, expectedOutput: "food_draft" },
  );

  const draft = parsed.draft as ReturnType<typeof mismatchedFoodDraft>;
  assertEquals(draft.total_weight_g, 280);
  assertEquals(draft.calories_kcal, 315);
  assertEquals(draft.protein_g, 12);
  assertEquals(draft.carbs_g, 53);
  assertEquals(draft.fat_g, 5);
});

Deno.test("parseProviderGatewayBody parses workout draft JSON", () => {
  const request = parseGatewayRequest({
    message: { text: "Log bench press 20 kg for 3 sets of 10" },
    language: "en",
    model_choice: "qwen",
    workflow_hint: "auto",
    device_id: "device-a",
  });
  const parsed = parseProviderGatewayBody(
    JSON.stringify({
      schema_version: "provider_gateway_envelope.v2",
      output_type: "workout_draft",
      message: { text: "Review this workout draft before saving." },
      needs_clarification: false,
      clarification_questions: [],
      draft: validWorkoutDraft(),
    }),
    { ...request, expectedOutput: "workout_draft" },
  );

  assertEquals(parsed.messageText, "Review this workout draft before saving.");
  assertEquals(
    (parsed.draft as { schema_version?: string } | null)?.schema_version,
    "workout_draft.v1",
  );
});

Deno.test("parseProviderGatewayBody rejects Markdown fences and provider prose", () => {
  const request = parseGatewayRequest({
    message: { text: "I walked 10 minutes. Create a workout draft." },
    language: "en",
    model_choice: "qwen",
    workflow_hint: "auto",
    device_id: "device-a",
  });
  assertThrowsOutputContract(() =>
    parseProviderGatewayBody("Sure\n```json\n{}\n```", {
      ...request,
      expectedOutput: "workout_draft",
    })
  );
});

Deno.test("parseProviderGatewayBody rejects prose before valid food JSON", () => {
  const request = parseGatewayRequest({
    message: { text: "200ml 全脂牛奶，生成饮食草稿。" },
    language: "zh",
    model_choice: "qwen",
    workflow_hint: "food_logging",
    device_id: "device-a",
  });
  const draft = {
    ...validDraft(),
    meal_name: "全脂牛奶",
    total_weight_g: 200,
    calories_kcal: 130,
    protein_g: 6.4,
    carbs_g: 9.6,
    fat_g: 7.6,
    estimation_notes: "按常见全脂牛奶营养数据估算。",
    items: [{
      name: "全脂牛奶",
      weight_g: 200,
      calories_kcal: 130,
      protein_g: 6.4,
      carbs_g: 9.6,
      fat_g: 7.6,
    }],
  };
  assertThrowsOutputContract(() =>
    parseProviderGatewayBody(`额外说明\n${JSON.stringify(draft)}`, {
      ...request,
      expectedOutput: "food_draft",
    })
  );
});

Deno.test("parseProviderGatewayBody rejects multiple JSON objects", () => {
  const request = parseGatewayRequest({
    message: { text: "Log this milk." },
    language: "en",
    model_choice: "qwen",
    workflow_hint: "food_logging",
    device_id: "device-a",
  });
  assertThrowsOutputContract(() =>
    parseProviderGatewayBody('{"note":"one"}\n{"note":"two"}', {
      ...request,
      expectedOutput: "food_draft",
    })
  );
});

Deno.test("runMockProvider returns fixed text and stable simulated failures", () => {
  const baseRequest = parseGatewayRequest({
    message: { text: "hello" },
    language: "en",
    model_choice: "chatgpt",
    workflow_hint: "auto",
    device_id: "device-a",
  });
  assert(runMockProvider(baseRequest).content.includes("mock reply"));

  const timeoutRequest = parseGatewayRequest({
    message: { text: "[mock_timeout]" },
    language: "en",
    model_choice: "chatgpt",
    workflow_hint: "auto",
    device_id: "device-a",
  });
  try {
    runMockProvider(timeoutRequest);
    throw new Error("expected timeout");
  } catch (error) {
    assert(error instanceof MockProviderError);
    assertEquals((error as MockProviderError).code, "gateway_timeout");
  }
});

Deno.test("provider router maps stable choices to provider adapters", () => {
  const openAi = providerForChoice("chatgpt", {
    openAiApiKey: "openai-key",
    openAiModel: "openai-model",
    qwenApiKey: "qwen-key",
    qwenModel: "qwen-model",
    qwenBaseUrl: "https://example.test/qwen",
    timeoutMs: 1000,
    allowMockProvider: false,
  }, fakeFetch({ output_text: "ok" }));
  const qwen = providerForChoice("qwen", {
    openAiApiKey: "openai-key",
    openAiModel: "openai-model",
    qwenApiKey: "qwen-key",
    qwenModel: "qwen-model",
    qwenBaseUrl: "https://example.test/qwen",
    timeoutMs: 1000,
    allowMockProvider: false,
  }, fakeFetch({ choices: [{ message: { content: "ok" } }] }));

  assertEquals(openAi.providerId, "openai");
  assertEquals(openAi.model, "openai-model");
  assertEquals(qwen.providerId, "qwen");
  assertEquals(qwen.model, "qwen-model");
});

Deno.test("provider parsers extract text and reject invalid payloads", () => {
  assertEquals(
    extractOpenAiCompletion({ output_text: " hello " }).content,
    "hello",
  );
  assertEquals(
    extractQwenCompletion({ choices: [{ message: { content: " 你好 " } }] })
      .content,
    "你好",
  );

  assertThrowsProviderFailure(() =>
    extractOpenAiCompletion({ output_text: "" })
  );
  assertThrowsProviderFailure(() => extractQwenCompletion({ choices: [] }));
});

Deno.test("provider completion parsers separate refusal and incomplete output", () => {
  assertEquals(
    extractOpenAiCompletion({
      output: [{ content: [{ type: "refusal", refusal: "declined" }] }],
    }).status,
    "refusal",
  );
  assertEquals(
    extractOpenAiCompletion({
      status: "incomplete",
      incomplete_details: { reason: "max_output_tokens" },
      output_text: "{",
    }).status,
    "incomplete",
  );
  assertEquals(
    extractQwenCompletion({
      choices: [{ finish_reason: "length", message: { content: "{" } }],
    }).status,
    "incomplete",
  );
});

Deno.test("OpenAI adapter sends the canonical strict Structured Outputs schema", async () => {
  let capturedBody: Record<string, unknown> | null = null;
  const provider = providerForChoice("chatgpt", {
    openAiApiKey: "openai-key",
    openAiModel: "openai-model",
    qwenApiKey: "qwen-key",
    qwenModel: "qwen-model",
    qwenBaseUrl: "https://example.test/qwen",
    timeoutMs: 1000,
    allowMockProvider: false,
  }, async (_url, init) => {
    capturedBody = JSON.parse(init?.body?.toString() ?? "{}");
    return new Response(JSON.stringify({ output_text: "{}" }), { status: 200 });
  });

  await provider.generateText(parseGatewayRequest({
    message: { text: "hello" },
    language: "en",
    model_choice: "chatgpt",
    workflow_hint: "auto",
    device_id: "device-a",
  }));

  const body = capturedBody as unknown as Record<string, unknown>;
  const text = body.text as Record<string, unknown>;
  const format = text.format as Record<string, unknown>;
  assertEquals(format.type, "json_schema");
  assertEquals(format.strict, true);
  const schemaJson = JSON.stringify(format.schema);
  assert(schemaJson.includes("provider_gateway_envelope.v2"));
  assert(schemaJson.includes("output_type"));
  for (
    const unsupportedKeyword of [
      '"const"',
      '"minimum"',
      '"maximum"',
      '"minLength"',
      '"maxLength"',
      '"pattern"',
      '"minItems"',
      '"maxItems"',
    ]
  ) {
    assertEquals(schemaJson.includes(unsupportedKeyword), false);
  }
});

Deno.test("provider adapter builds safe request without leaking unsupported fields", async () => {
  let capturedBody: Record<string, unknown> | null = null;
  const provider = providerForChoice("qwen", {
    openAiApiKey: "openai-key",
    openAiModel: "openai-model",
    qwenApiKey: "qwen-key",
    qwenModel: "qwen-model",
    qwenBaseUrl: "https://example.test/qwen",
    timeoutMs: 1000,
    allowMockProvider: false,
  }, async (_url, init) => {
    capturedBody = JSON.parse(init?.body?.toString() ?? "{}");
    return new Response(
      JSON.stringify({ choices: [{ message: { content: "ok" } }] }),
      { status: 200 },
    );
  });

  const result = await provider.generateText(parseGatewayRequest({
    message: { text: "hello" },
    language: "en",
    model_choice: "qwen",
    workflow_hint: "auto",
    device_id: "device-a",
  }));

  const body = capturedBody as unknown as Record<string, unknown>;
  const json = JSON.stringify(body);
  assertEquals(result.content, "ok");
  assertEquals(body.model, "qwen-model");
  assertEquals(body.enable_thinking, false);
  assert(json.includes("provider_gateway_envelope.v2"));
  assert(json.includes("output_type"));
  assert(json.includes("message.text"));
  assertEquals("attachments" in body, false);
  assertEquals("context_objects" in body, false);
});

Deno.test("Qwen provider adapter builds multimodal image request", async () => {
  let capturedBody: Record<string, unknown> | null = null;
  const provider = providerForChoice("qwen", {
    openAiApiKey: "openai-key",
    openAiModel: "openai-model",
    qwenApiKey: "qwen-key",
    qwenModel: "qwen-model",
    qwenBaseUrl: "https://example.test/qwen",
    timeoutMs: 1000,
    allowMockProvider: false,
  }, async (_url, init) => {
    capturedBody = JSON.parse(init?.body?.toString() ?? "{}");
    return new Response(
      JSON.stringify({
        choices: [{
          message: {
            content: JSON.stringify({
              message: { text: "ok" },
              needs_clarification: false,
              clarification_questions: [],
              draft: null,
            }),
          },
        }],
      }),
      { status: 200 },
    );
  });

  await provider.generateText(parseGatewayRequest({
    message: { text: "Can this be dinner?" },
    language: "en",
    model_choice: "qwen",
    workflow_hint: "meal_decision",
    device_id: "device-a",
    attachments: [{
      kind: "image",
      mime_type: "image/webp",
      base64_data: "base64-image",
      byte_length: 256,
    }, {
      kind: "image",
      mime_type: "image/png",
      base64_data: "second-image",
      byte_length: 128,
    }],
  }));

  const body = capturedBody as unknown as Record<string, unknown>;
  const json = JSON.stringify(body);
  assertEquals(body.response_format, { type: "json_object" });
  assert(json.includes("data:image/webp;base64,base64-image"));
  assert(json.includes("data:image/png;base64,second-image"));
  assertEquals(json.includes("official_record_write"), false);
  assertEquals(json.includes("rag_context"), false);
});

function assertThrowsGatewayRequest(action: () => void): void {
  try {
    action();
  } catch (error) {
    assert(error instanceof GatewayRequestError);
    assertEquals(
      (error as GatewayRequestError).code,
      "request_schema_mismatch",
    );
    return;
  }
  throw new Error("Expected GatewayRequestError");
}

function assertThrowsProviderFailure(action: () => void): void {
  try {
    action();
  } catch (error) {
    assertEquals((error as Error).message, "provider_failure");
    return;
  }
  throw new Error("Expected provider failure");
}

function assertThrowsOutputContract(action: () => void): void {
  try {
    action();
  } catch (error) {
    assert(error instanceof OutputContractError);
    return;
  }
  throw new Error("Expected OutputContractError");
}

function fakeFetch(body: unknown): typeof fetch {
  return (() =>
    Promise.resolve(
      new Response(JSON.stringify(body), { status: 200 }),
    )) as typeof fetch;
}

function validDraft() {
  return {
    schema_version: "food_draft.v1",
    meal_name: "Chicken rice",
    total_weight_g: 320,
    calories_kcal: 520,
    protein_g: 32,
    carbs_g: 62,
    fat_g: 14,
    confidence: 0.72,
    estimation_notes: "Estimated from visible plate.",
    items: [{
      name: "Chicken",
      weight_g: 120,
      calories_kcal: 220,
      protein_g: 28,
      carbs_g: 0,
      fat_g: 10,
    }],
  };
}

function mismatchedFoodDraft() {
  return {
    schema_version: "food_draft.v1",
    meal_name: "Rice and tofu",
    total_weight_g: 999,
    calories_kcal: 999,
    protein_g: 999,
    carbs_g: 999,
    fat_g: 999,
    confidence: 0.72,
    estimation_notes: "Estimated from visible plate.",
    items: [{
      name: "Rice",
      weight_g: 180,
      calories_kcal: 234,
      protein_g: 4,
      carbs_g: 51,
      fat_g: 0,
    }, {
      name: "Tofu",
      weight_g: 100,
      calories_kcal: 81,
      protein_g: 8,
      carbs_g: 2,
      fat_g: 5,
    }],
  };
}

function validWorkoutDraft() {
  return {
    schema_version: "workout_draft.v1",
    record_name: "Bench press",
    date: null,
    notes: "Generated by AI chat.",
    exercises: [{
      exercise_name: "Bench Press",
      exercise_key: null,
      exercise_type: "strength",
      body_part: null,
      duration_minutes: null,
      active_duration_minutes: null,
      cardio_intensity_basis: null,
      sets: [{
        weight_kg: 20,
        reps: 10,
        duration_seconds: null,
      }],
    }],
  };
}

function tokenFor(payload: Record<string, unknown>): string {
  return [
    encodeBase64Url(JSON.stringify({ alg: "none", typ: "JWT" })),
    encodeBase64Url(JSON.stringify(payload)),
    "signature",
  ].join(".");
}

function encodeBase64Url(value: string): string {
  return btoa(value).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/g,
    "",
  );
}

function assert(value: boolean, message = "Assertion failed"): void {
  if (!value) {
    throw new Error(message);
  }
}

function assertEquals(actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
