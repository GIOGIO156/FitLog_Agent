import {
  buildQwenVisionRequestBody,
  extractQwenContent,
  parsePhotoAnalysisRequest,
  parseProviderFoodDraftBody,
  PhotoGatewayRequestError,
  stripImageDataForDebug,
} from "./contracts.ts";

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
    schema_version: "food_draft.v1",
    user_note: "米饭吃了一半",
  });

  assertEquals(parsed.images.length, 3);
  assertEquals(parsed.images[0].mimeType, "image/jpeg");
  assertEquals(parsed.modelChoice, "qwen");
  assertEquals(parsed.userNote, "米饭吃了一半");
});

Deno.test("parsePhotoAnalysisRequest rejects missing, oversized, and unsupported images", () => {
  assertThrowsRequest(() =>
    parsePhotoAnalysisRequest({
      language: "zh",
      model_choice: "qwen",
      device_id: "device-a",
      selected_date: "2026-07-01",
      schema_version: "food_draft.v1",
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
      schema_version: "food_draft.v1",
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
      schema_version: "food_draft.v1",
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
      schema_version: "food_draft.v1",
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
    schema_version: "food_draft.v1",
  });

  const body = buildQwenVisionRequestBody({ request, model: "qwen-vl" });
  const json = JSON.stringify(body);

  assert(json.includes("data:image/webp;base64,base64-image"));
  assert(json.includes("data:image/png;base64,second-image"));
  assertEquals(body.model, "qwen-vl");
  assertEquals(body.enable_thinking, false);
});

Deno.test("parseProviderFoodDraftBody accepts valid and fenced JSON", () => {
  const json = JSON.stringify({
    needs_clarification: false,
    clarification_questions: [],
    draft: validDraft(),
  });
  const parsed = parseProviderFoodDraftBody(`\`\`\`json\n${json}\n\`\`\``);

  assertEquals(parsed.schemaValidationStatus, "passed");
  assertEquals(parsed.draft?.meal_name, "Chicken rice");
  assertEquals(parsed.draft?.items.length, 1);
});

Deno.test("parseProviderFoodDraftBody extracts JSON object from provider prose", () => {
  const json = JSON.stringify({
    needs_clarification: false,
    clarification_questions: [],
    draft: validDraft(),
  });
  const parsed = parseProviderFoodDraftBody(`已生成草稿：\n\`\`\`json\n${json}\n\`\`\``);

  assertEquals(parsed.schemaValidationStatus, "passed");
  assertEquals(parsed.draft?.meal_name, "Chicken rice");
});

Deno.test("parseProviderFoodDraftBody supports clarification without draft", () => {
  const parsed = parseProviderFoodDraftBody(JSON.stringify({
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
      needs_clarification: false,
      clarification_questions: [],
      draft: { ...validDraft(), calories_kcal: -1 },
    }))
  );
});

Deno.test("extractQwenContent reads OpenAI-compatible chat completion content", () => {
  assertEquals(
    extractQwenContent({ choices: [{ message: { content: " ok " } }] }),
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
    schema_version: "food_draft.v1",
  });

  const debug = JSON.stringify(stripImageDataForDebug(request));

  assert(debug.includes("image/jpeg"));
  assert(debug.includes("128"));
  assert(debug.includes("image/png"));
  assertEquals(debug.includes("secret-base64"), false);
});

function validDraft() {
  return {
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

function assertThrowsRequest(action: () => void): void {
  try {
    action();
  } catch (error) {
    assert(error instanceof PhotoGatewayRequestError);
    assertEquals((error as PhotoGatewayRequestError).code, "record_schema_mismatch");
    return;
  }
  throw new Error("Expected request error");
}

function assertThrowsProviderSchema(action: () => void): void {
  try {
    action();
  } catch (error) {
    assertEquals((error as Error).message, "record_schema_mismatch");
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
    throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}
