import type { GatewayRequest } from "../contracts.ts";
import type { Phase5ContextObject } from "../phase5_types.ts";
import { resolveExercise, type ExerciseResolution } from "./exercise_resolver.ts";

export function buildExerciseDefinitionContext(request: GatewayRequest): {
  resolution: ExerciseResolution;
  context: Phase5ContextObject | null;
  missing: string[];
} {
  const resolution = resolveExercise(request.messageText, request.exerciseReferences ?? []);
  if (resolution.status !== "resolved") return { resolution, context: null, missing: [resolution.status === "ambiguous" ? "exercise_definition_ambiguous" : "exercise_definition"] };
  const definition = resolution.definition;
  return {
    resolution,
    missing: [],
    context: {
      type: "exercise_definition", version: "v1", language: request.language,
      date_range: null, source: definition.source === "builtin" ? "builtin_exercise_catalog" : "request_scoped_custom_exercise",
      data: { ...definition }, missing: [],
      privacy: { contains_raw_records: false, contains_images: false, contains_user_free_text_notes: false },
    },
  };
}
