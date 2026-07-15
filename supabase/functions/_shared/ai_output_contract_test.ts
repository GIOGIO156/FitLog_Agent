import {
  OutputContractError,
  parseFoodAnalysisEnvelope,
  parseProviderGatewayEnvelope,
  providerGatewayEnvelopeJsonSchemaForExpectedOutput,
} from "./ai_output_contract.ts";

Deno.test("expected-output schemas exclude unrelated draft families", () => {
  const text = JSON.stringify(
    providerGatewayEnvelopeJsonSchemaForExpectedOutput("text"),
  );
  assertEquals(text.includes("food_draft.v2"), false);
  assertEquals(text.includes("workout_draft.v3"), false);
  const food = JSON.stringify(
    providerGatewayEnvelopeJsonSchemaForExpectedOutput("food_draft"),
  );
  assertEquals(food.includes("food_draft.v2"), true);
  assertEquals(food.includes("workout_draft.v3"), false);
});

Deno.test("strict text envelope accepts Markdown only inside message.text", () => {
  const parsed = parseProviderGatewayEnvelope(
    JSON.stringify({
      schema_version: "provider_gateway_envelope.v2",
      output_type: "text",
      message: { text: "**Grounded answer**" },
      needs_clarification: false,
      clarification_questions: [],
      draft: null,
    }),
    "text",
  );
  assertEquals(parsed.messageText, "**Grounded answer**");
  assertEquals(parsed.draft, null);
});

Deno.test("Food Draft exact types and item totals are enforced and normalized", () => {
  const parsed = parseProviderGatewayEnvelope(
    JSON.stringify({
      schema_version: "provider_gateway_envelope.v2",
      output_type: "food_draft",
      message: { text: "Review before saving." },
      needs_clarification: false,
      clarification_questions: [],
      draft: {
        ...foodDraft(),
        total_weight_g: 999,
        calories_kcal: 999,
      },
    }),
    "food_draft",
  );
  const draft = parsed.draft as ReturnType<typeof foodDraft>;
  assertEquals(draft.total_weight_g, 100);
  assertEquals(draft.calories_kcal, 120);
});

Deno.test("strict validator rejects wrong types, unknown fields, bounds, and fences", () => {
  for (
    const invalid of [
      envelope({ ...foodDraft(), calories_kcal: "120" }),
      envelope({ ...foodDraft(), extra: true }),
      envelope({ ...foodDraft(), confidence: 1.1 }),
    ]
  ) {
    assertOutputError(() =>
      parseProviderGatewayEnvelope(JSON.stringify(invalid), "food_draft")
    );
  }
  assertOutputError(() =>
    parseProviderGatewayEnvelope(
      `\`\`\`json\n${JSON.stringify(envelope(foodDraft()))}\n\`\`\``,
      "food_draft",
    )
  );
});

Deno.test("workout validator rejects impossible calendar dates and numeric strings", () => {
  assertOutputError(() =>
    parseProviderGatewayEnvelope(
      JSON.stringify(envelope({
        ...workoutDraft(),
        date: "2026-02-30",
      })),
      "workout_draft",
    )
  );
  assertOutputError(() =>
    parseProviderGatewayEnvelope(
      JSON.stringify(envelope({
        ...workoutDraft(),
        exercises: [{
          ...workoutDraft().exercises[0],
          sets: [{ weight_kg: 20, reps: "10", duration_seconds: null }],
        }],
      })),
      "workout_draft",
    )
  );
});

Deno.test("draft date must match the software-resolved target date", () => {
  assertOutputError(() =>
    parseProviderGatewayEnvelope(
      JSON.stringify(envelope(foodDraft())),
      "food_draft",
      "2026-07-11",
    )
  );
  const parsed = parseProviderGatewayEnvelope(
    JSON.stringify(envelope(foodDraft())),
    "food_draft",
    "2026-07-10",
  );
  assertEquals(parsed.draft?.date, "2026-07-10");
});

Deno.test("expected output and clarification combinations cannot silently degrade", () => {
  assertOutputError(() =>
    parseProviderGatewayEnvelope(JSON.stringify(envelope(null)), "food_draft")
  );
  assertOutputError(() =>
    parseProviderGatewayEnvelope(
      JSON.stringify(envelope(workoutDraft())),
      "food_draft",
    )
  );
  assertOutputError(() =>
    parseProviderGatewayEnvelope(
      JSON.stringify({
        ...envelope(null),
        output_type: "clarification",
        needs_clarification: true,
        clarification_questions: [],
      }),
      "food_draft",
    )
  );
  const clarification = parseProviderGatewayEnvelope(
    JSON.stringify({
      ...envelope(null),
      output_type: "clarification",
      needs_clarification: true,
      clarification_questions: ["How much did you eat?"],
    }),
    "food_draft",
  );
  assertEquals(clarification.needsClarification, true);
});

Deno.test("auto output lets the model select a contract-consistent family", () => {
  const parsed = parseProviderGatewayEnvelope(
    JSON.stringify(envelope(workoutDraft())),
    "auto",
  );
  assertEquals(parsed.outputType, "workout_draft");
  assertEquals(parsed.draft?.schema_version, "workout_draft.v3");
});

Deno.test("text output cannot claim a draft was created without an artifact", () => {
  assertOutputError(() =>
    parseProviderGatewayEnvelope(
      JSON.stringify({
        ...envelope(null),
        message: { text: "已为您生成卧推训练草稿。" },
      }),
      "auto",
    )
  );
});

Deno.test("dedicated food endpoint uses the same strict Food Draft validator", () => {
  const parsed = parseFoodAnalysisEnvelope(JSON.stringify({
    schema_version: "food_analysis_envelope.v1",
    needs_clarification: false,
    clarification_questions: [],
    draft: foodDraft(),
  }));
  assertEquals(parsed.draft?.schema_version, "food_draft.v2");
  assertOutputError(() =>
    parseFoodAnalysisEnvelope(JSON.stringify({
      schema_version: "food_analysis_envelope.v1",
      needs_clarification: false,
      clarification_questions: [],
      draft: { ...foodDraft(), calories_kcal: "120" },
    }))
  );
});

function envelope(draft: unknown): Record<string, unknown> {
  const outputType = draft !== null &&
      typeof draft === "object" &&
      (draft as Record<string, unknown>).schema_version === "workout_draft.v3"
    ? "workout_draft"
    : draft === null
    ? "text"
    : "food_draft";
  return {
    schema_version: "provider_gateway_envelope.v2",
    output_type: outputType,
    message: { text: "Review result." },
    needs_clarification: false,
    clarification_questions: [],
    draft,
  };
}

function foodDraft() {
  return {
    schema_version: "food_draft.v2",
    date: "2026-07-10",
    meal_name: "Chicken",
    total_weight_g: 100,
    calories_kcal: 120,
    protein_g: 20,
    carbs_g: 0,
    fat_g: 4,
    confidence: 0.8,
    estimation_notes: "Estimate.",
    items: [{
      name: "Chicken",
      weight_g: 100,
      calories_kcal: 120,
      protein_g: 20,
      carbs_g: 0,
      fat_g: 4,
    }],
  };
}

function workoutDraft() {
  return {
    schema_version: "workout_draft.v3",
    record_name: "Squat",
    date: "2026-07-10",
    notes: "",
    exercises: [{
      exercise_name: "Squat",
      exercise_key: "squat",
      exercise_source: "builtin",
      definition_hash: "1234abcd",
      exercise_type: "strength",
      body_part: "Legs",
      load_input_mode: "total_load",
      reps_input_mode: "total_reps",
      set_metric_type: "reps",
      duration_minutes: null,
      active_duration_minutes: null,
      cardio_intensity_basis: null,
      sets: [{ weight_kg: 20, reps: 10, duration_seconds: null }],
    }],
  };
}

function assertOutputError(action: () => void): void {
  try {
    action();
  } catch (error) {
    if (error instanceof OutputContractError) return;
    throw error;
  }
  throw new Error("Expected OutputContractError");
}

function assertEquals(actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
