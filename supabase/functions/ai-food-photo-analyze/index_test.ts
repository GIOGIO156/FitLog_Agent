import {
  buildOpenAiVisionRequestBody,
  buildQwenVisionRequestBody,
  extractOpenAiVisionCompletion,
  extractQwenCompletion,
  foodDraftForClient,
  parsePhotoAnalysisRequest,
  parseProviderFoodDraftBody,
  PhotoGatewayRequestError,
  stripImageDataForDebug,
} from "./contracts.ts";
import { OutputContractError } from "../_shared/ai_output_contract.ts";

Deno.test("parsePhotoAnalysisRequest accepts up to three compact supported images", () => {
  const parsed = parsePhotoAnalysisRequest({
    images: [{
      mime_type: "image/jpeg",
      base64_data: "abc123",
      byte_length: 128,
    }, {
      mime_type: "image/png",
      base64_data: "def456",
      byte_length: 256,
    }, {
      mime_type: "image/webp",
      base64_data: "ghi789",
      byte_length: 384,
    }],
    language: "zh",
    model_choice: "qwen",
    device_id: "device-a",
    selected_date: "2026-07-01",
    schema_version: "food_draft.v2" as const,
    user_note: "米饭吃了一半",
  });

  assertEquals(parsed.images.length, 3);
  assertEquals(parsed.images[0].mimeType, "image/jpeg");
  assertEquals(parsed.modelChoice, "qwen");
  assertEquals(parsed.userNote, "米饭吃了一半");
});

Deno.test("OpenAI and Qwen image adapters preserve capability input and configured model", () => {
  const request = parsePhotoAnalysisRequest({
    images: [{
      mime_type: "image/jpeg",
      base64_data: "abc123",
      byte_length: 128,
    }],
    language: "zh",
    model_choice: "chatgpt",
    device_id: "device-a",
    selected_date: "2026-07-01",
    schema_version: "food_draft.v2",
    user_note: "蛋白质 20g",
  });
  const openAi = buildOpenAiVisionRequestBody({
    request,
    model: "openai-model",
  });
  const qwen = buildQwenVisionRequestBody({
    request: { ...request, modelChoice: "qwen" },
    model: "qwen-model",
  });
  assertEquals(openAi.model, "openai-model");
  assertEquals(qwen.model, "qwen-model");
  assert(JSON.stringify(openAi).includes("abc123"));
  assert(JSON.stringify(qwen).includes("abc123"));
  assert(JSON.stringify(openAi).includes("蛋白质 20g"));
  assert(JSON.stringify(qwen).includes("蛋白质 20g"));
});

Deno.test("OpenAI vision completion maps completed and refusal states", () => {
  assertEquals(
    extractOpenAiVisionCompletion({ output_text: '{"draft":null}' }).status,
    "completed",
  );
  assertEquals(
    extractOpenAiVisionCompletion({
      output: [{ content: [{ type: "refusal" }] }],
    }).status,
    "refusal",
  );
});

Deno.test("parsePhotoAnalysisRequest accepts text-only food descriptions", () => {
  const parsed = parsePhotoAnalysisRequest({
    images: [],
    language: "zh",
    model_choice: "qwen",
    device_id: "device-a",
    selected_date: "2026-07-01",
    schema_version: "food_draft.v2",
    user_note: "100g 三文鱼",
  });

  assertEquals(parsed.images.length, 0);
  assertEquals(parsed.userNote, "100g 三文鱼");
});

Deno.test("legacy request version receives a legacy-compatible draft", () => {
  const request = parsePhotoAnalysisRequest({
    images: [],
    language: "zh",
    model_choice: "qwen",
    device_id: "device-a",
    selected_date: "2026-07-01",
    schema_version: "food_draft.v1",
    user_note: "100g 三文鱼",
  });
  const legacy = foodDraftForClient(
    validDraft(),
    request.schemaVersion,
  ) as Record<string, unknown>;

  assertEquals(legacy.schema_version, "food_draft.v1");
  assertEquals("date" in legacy, false);
});

Deno.test("parsePhotoAnalysisRequest rejects empty, oversized, and unsupported input", () => {
  assertThrowsRequest(() =>
    parsePhotoAnalysisRequest({
      language: "zh",
      model_choice: "qwen",
      device_id: "device-a",
      selected_date: "2026-07-01",
      schema_version: "food_draft.v2",
    })
  );

  assertThrowsRequest(() =>
    parsePhotoAnalysisRequest({
      images: [{
        mime_type: "image/gif",
        base64_data: "abc123",
        byte_length: 128,
      }],
      language: "zh",
      model_choice: "qwen",
      device_id: "device-a",
      selected_date: "2026-07-01",
      schema_version: "food_draft.v2",
    })
  );

  assertThrowsRequest(() =>
    parsePhotoAnalysisRequest({
      images: [{
        mime_type: "image/png",
        base64_data: "abc123",
        byte_length: 5 * 1024 * 1024,
      }],
      language: "zh",
      model_choice: "qwen",
      device_id: "device-a",
      selected_date: "2026-07-01",
      schema_version: "food_draft.v2",
    })
  );

  assertThrowsRequest(() =>
    parsePhotoAnalysisRequest({
      images: [0, 1, 2, 3].map((index) => ({
        mime_type: "image/png",
        base64_data: `abc${index}`,
        byte_length: 128,
      })),
      language: "zh",
      model_choice: "qwen",
      device_id: "device-a",
      selected_date: "2026-07-01",
      schema_version: "food_draft.v2",
    })
  );
});

Deno.test("buildQwenVisionRequestBody uses an image_url data URL only in provider body", () => {
  const request = parsePhotoAnalysisRequest({
    images: [{
      mime_type: "image/webp",
      base64_data: "base64-image",
      byte_length: 256,
    }, {
      mime_type: "image/png",
      base64_data: "second-image",
      byte_length: 128,
    }],
    language: "en",
    model_choice: "qwen",
    device_id: "device-a",
    selected_date: "2026-07-01",
    schema_version: "food_draft.v2",
  });

  const body = buildQwenVisionRequestBody({ request, model: "qwen-vl" });
  const json = JSON.stringify(body);

  assert(json.includes("data:image/webp;base64,base64-image"));
  assert(json.includes("data:image/png;base64,second-image"));
  assertEquals(body.model, "qwen-vl");
  assertEquals(body.enable_thinking, false);
  assertEquals(body.max_tokens, 1200);
});

Deno.test("buildQwenVisionRequestBody supports text-only provider requests", () => {
  const request = parsePhotoAnalysisRequest({
    images: [],
    language: "zh",
    model_choice: "qwen",
    device_id: "device-a",
    selected_date: "2026-07-01",
    schema_version: "food_draft.v2",
    user_note: "100g 三文鱼",
  });

  const body = buildQwenVisionRequestBody({ request, model: "qwen-vl" });
  const json = JSON.stringify(body);

  assert(json.includes("100g 三文鱼"));
  assert(json.includes("Image count: 0"));
  assertEquals(json.includes("data:image/"), false);
});

Deno.test("food correction request does not resend image data", () => {
  const request = parsePhotoAnalysisRequest({
    images: [{
      mime_type: "image/jpeg",
      base64_data: "secret-image",
      byte_length: 128,
    }],
    language: "en",
    model_choice: "qwen",
    device_id: "device-a",
    selected_date: "2026-07-01",
    schema_version: "food_draft.v2",
  });
  const body = buildQwenVisionRequestBody({
    request,
    model: "qwen-vl",
    correction: {
      previousOutput: "not-json",
      issues: [{ path: "$", reason: "expected one JSON object" }],
    },
  });
  const json = JSON.stringify(body);
  assertEquals(json.includes("secret-image"), false);
  assert(json.includes("expected one JSON object"));
  assert(json.includes("not-json"));
});

Deno.test("parseProviderFoodDraftBody accepts one strict JSON object", () => {
  const json = JSON.stringify({
    schema_version: "food_analysis_envelope.v1",
    needs_clarification: false,
    clarification_questions: [],
    draft: validDraft(),
  });
  const parsed = parseProviderFoodDraftBody(json);

  assertEquals(parsed.schemaValidationStatus, "passed");
  assertEquals(parsed.draft?.meal_name, "Chicken rice");
  assertEquals(parsed.draft?.items.length, 1);
});

Deno.test("parseProviderFoodDraftBody rejects fences and provider prose", () => {
  const json = JSON.stringify({
    schema_version: "food_analysis_envelope.v1",
    needs_clarification: false,
    clarification_questions: [],
    draft: validDraft(),
  });
  assertThrowsProviderSchema(() =>
    parseProviderFoodDraftBody(`已生成草稿：\n\`\`\`json\n${json}\n\`\`\``)
  );
});

Deno.test("parseProviderFoodDraftBody normalizes food draft meal totals from items", () => {
  const parsed = parseProviderFoodDraftBody(JSON.stringify({
    schema_version: "food_analysis_envelope.v1",
    needs_clarification: false,
    clarification_questions: [],
    draft: mismatchedFoodDraft(),
  }));

  assertEquals(parsed.draft?.total_weight_g, 280);
  assertEquals(parsed.draft?.calories_kcal, 315);
  assertEquals(parsed.draft?.protein_g, 12);
  assertEquals(parsed.draft?.carbs_g, 53);
  assertEquals(parsed.draft?.fat_g, 5);
});

Deno.test("parseProviderFoodDraftBody supports clarification without draft", () => {
  const parsed = parseProviderFoodDraftBody(JSON.stringify({
    schema_version: "food_analysis_envelope.v1",
    needs_clarification: true,
    clarification_questions: ["How much rice did you eat?"],
    draft: null,
  }));

  assertEquals(parsed.needsClarification, true);
  assertEquals(parsed.draft, null);
  assertEquals(parsed.clarificationQuestions.length, 1);
});

Deno.test("parseProviderFoodDraftBody rejects invalid numeric draft fields", () => {
  assertThrowsProviderSchema(() =>
    parseProviderFoodDraftBody(JSON.stringify({
      schema_version: "food_analysis_envelope.v1",
      needs_clarification: false,
      clarification_questions: [],
      draft: { ...validDraft(), calories_kcal: -1 },
    }))
  );
});

Deno.test("extractQwenCompletion reads OpenAI-compatible chat completion content", () => {
  assertEquals(
    extractQwenCompletion({ choices: [{ message: { content: " ok " } }] })
      .content,
    "ok",
  );
});

Deno.test("stripImageDataForDebug keeps only compact image metadata", () => {
  const request = parsePhotoAnalysisRequest({
    images: [{
      mime_type: "image/jpeg",
      base64_data: "secret-base64",
      byte_length: 128,
    }, {
      mime_type: "image/png",
      base64_data: "secret-base64-2",
      byte_length: 256,
    }],
    language: "zh",
    model_choice: "qwen",
    device_id: "device-a",
    selected_date: "2026-07-01",
    schema_version: "food_draft.v2",
  });

  const debug = JSON.stringify(stripImageDataForDebug(request));

  assert(debug.includes("image/jpeg"));
  assert(debug.includes("128"));
  assert(debug.includes("image/png"));
  assertEquals(debug.includes("secret-base64"), false);
});

Deno.test("stripImageDataForDebug keeps compact text-only metadata", () => {
  const request = parsePhotoAnalysisRequest({
    images: [],
    language: "zh",
    model_choice: "qwen",
    device_id: "device-a",
    selected_date: "2026-07-01",
    schema_version: "food_draft.v2",
    user_note: "100g 三文鱼",
  });

  const debug = JSON.stringify(stripImageDataForDebug(request));

  assert(debug.includes("text"));
  assert(debug.includes("2026-07-01"));
  assert(debug.includes("has_user_note"));
});

function validDraft() {
  return {
    schema_version: "food_draft.v2" as const,
    date: "2026-07-01",
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
    schema_version: "food_draft.v2",
    date: "2026-07-01",
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

function assertThrowsRequest(action: () => void): void {
  try {
    action();
  } catch (error) {
    assert(error instanceof PhotoGatewayRequestError);
    assertEquals(
      (error as PhotoGatewayRequestError).code,
      "request_schema_mismatch",
    );
    return;
  }
  throw new Error("Expected request error");
}

function assertThrowsProviderSchema(action: () => void): void {
  try {
    action();
  } catch (error) {
    assert(error instanceof OutputContractError);
    return;
  }
  throw new Error("Expected provider schema error");
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
