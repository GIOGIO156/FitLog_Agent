import type { GatewayExerciseReference } from "../contracts.ts";
import { exerciseCatalogSnapshot } from "../generated/rag_assets.v1.ts";

export type BuiltinExerciseDefinition = typeof exerciseCatalogSnapshot.exercises[number];
export type ApprovedExerciseDefinition =
  | { source: "builtin"; key: string; name: string; definition_hash: string; exercise_type: string; body_part: string; strength_structure: string; strength_profile: string; load_input_mode: string; reps_input_mode: string; set_metric_type: string }
  | { source: "custom"; key: string; name: string; definition_hash: string; exercise_type: string; body_part: string; strength_structure: string; strength_profile: string; load_input_mode: string; reps_input_mode: string; set_metric_type: string };

export function builtinDefinitions(): ApprovedExerciseDefinition[] {
  return exerciseCatalogSnapshot.exercises.map((definition) => ({
    source: "builtin",
    key: definition.key,
    name: definition.name_en,
    definition_hash: definition.definition_hash,
    exercise_type: definition.exercise_type,
    body_part: definition.body_part,
    strength_structure: definition.strength_structure,
    strength_profile: definition.strength_profile,
    load_input_mode: definition.load_input_mode,
    reps_input_mode: definition.reps_input_mode,
    set_metric_type: definition.set_metric_type,
  }));
}

export function customDefinition(reference: GatewayExerciseReference): ApprovedExerciseDefinition {
  return {
    source: "custom", key: reference.key, name: reference.name, definition_hash: reference.definitionHash,
    exercise_type: reference.exerciseType, body_part: reference.bodyPart, strength_structure: reference.strengthStructure,
    strength_profile: reference.strengthProfile, load_input_mode: reference.loadInputMode,
    reps_input_mode: reference.repsInputMode, set_metric_type: reference.setMetricType,
  };
}
