import type { AiGatewayErrorCode, GatewayRequest } from "./contracts.ts";
import type {
  ProviderCompletion,
  ProviderGenerationOptions,
} from "./providers.ts";
import { providerGatewayEnvelopeSchemaVersion } from "../_shared/ai_output_contract.ts";

export const mockProviderText =
  "This is a FitLog AI mock reply. Your text message was received.";

export class MockProviderError extends Error {
  readonly code: AiGatewayErrorCode;

  constructor(code: AiGatewayErrorCode) {
    super(code);
    this.code = code;
  }
}

export function runMockProvider(
  request: GatewayRequest,
  options?: ProviderGenerationOptions,
): ProviderCompletion {
  if (request.messageText.includes("[mock_timeout]")) {
    throw new MockProviderError("gateway_timeout");
  }
  if (request.messageText.includes("[mock_failure]")) {
    throw new MockProviderError("provider_failure");
  }
  if (request.messageText.includes("[mock_refusal]")) {
    return { status: "refusal", content: "", finishReason: "refusal" };
  }
  if (request.messageText.includes("[mock_incomplete]")) {
    return { status: "incomplete", content: "{", finishReason: "length" };
  }
  if (
    request.messageText.includes("[mock_invalid]") &&
    options?.correction === undefined
  ) {
    return { status: "completed", content: "not-json", finishReason: "stop" };
  }
  return {
    status: "completed",
    content: JSON.stringify(mockEnvelope(request)),
    finishReason: "stop",
  };
}

function mockEnvelope(request: GatewayRequest): Record<string, unknown> {
  const common = {
    schema_version: providerGatewayEnvelopeSchemaVersion,
    message: { text: mockProviderText },
    needs_clarification: false,
    clarification_questions: [],
  };
  if (request.expectedOutput === "food_draft") {
    return {
      ...common,
      draft: {
        schema_version: "food_draft.v1",
        meal_name: "Mock meal",
        total_weight_g: 100,
        calories_kcal: 120,
        protein_g: 10,
        carbs_g: 15,
        fat_g: 2,
        confidence: 0.8,
        estimation_notes: "Mock provider draft.",
        items: [],
      },
    };
  }
  if (request.expectedOutput === "workout_draft") {
    return {
      ...common,
      draft: {
        schema_version: "workout_draft.v1",
        record_name: "Mock workout",
        date: request.selectedDate,
        notes: "Mock provider draft.",
        exercises: [{
          exercise_name: "Squat",
          exercise_key: null,
          exercise_type: "strength",
          body_part: null,
          duration_minutes: null,
          active_duration_minutes: null,
          cardio_intensity_basis: null,
          sets: [{ weight_kg: 20, reps: 10, duration_seconds: null }],
        }],
      },
    };
  }
  return { ...common, draft: null };
}
