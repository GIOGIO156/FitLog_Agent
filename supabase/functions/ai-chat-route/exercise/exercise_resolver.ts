import type { GatewayExerciseReference } from "../contracts.ts";
import { exerciseCatalogSnapshot } from "../generated/rag_assets.v1.ts";
import { customDefinition, type ApprovedExerciseDefinition } from "./exercise_reference.ts";

export type ExerciseResolution =
  | { status: "resolved"; definition: ApprovedExerciseDefinition; candidates: [] }
  | { status: "ambiguous"; definition: null; candidates: ApprovedExerciseDefinition[] }
  | { status: "missing"; definition: null; candidates: [] };

export function resolveExercise(message: string, customReferences: GatewayExerciseReference[] = []): ExerciseResolution {
  const normalized = normalize(message);
  const explicitKeys = exerciseCatalogSnapshot.exercises.filter((exercise) =>
    containsStableKey(message, exercise.key)
  );
  if (explicitKeys.length === 1) return resolvedBuiltin(explicitKeys[0]);
  if (explicitKeys.length > 1) return ambiguous(explicitKeys.map(builtin));

  const named = longestMatches(
    exerciseCatalogSnapshot.exercises,
    (exercise) => [
      exercise.name_en,
      exercise.name_zh,
      ...exercise.aliases.en,
      ...exercise.aliases.zh,
    ],
    normalized,
  );
  if (named.length === 1) return resolvedBuiltin(named[0]);
  if (named.length > 1) return ambiguous(named.map(builtin));

  const custom = customReferences.filter((reference) => containsPhrase(normalized, normalize(reference.name))).map(customDefinition);
  if (custom.length === 1) return { status: "resolved", definition: custom[0], candidates: [] };
  if (custom.length > 1) return ambiguous(custom);
  return { status: "missing", definition: null, candidates: [] };
}

function builtin(definition: typeof exerciseCatalogSnapshot.exercises[number]): ApprovedExerciseDefinition {
  return { source: "builtin", key: definition.key, name: definition.name_en, definition_hash: definition.definition_hash, exercise_type: definition.exercise_type, body_part: definition.body_part, strength_structure: definition.strength_structure, strength_profile: definition.strength_profile, load_input_mode: definition.load_input_mode, reps_input_mode: definition.reps_input_mode, set_metric_type: definition.set_metric_type };
}

function resolvedBuiltin(definition: typeof exerciseCatalogSnapshot.exercises[number]): ExerciseResolution {
  return { status: "resolved", definition: builtin(definition), candidates: [] };
}

function ambiguous(candidates: ApprovedExerciseDefinition[]): ExerciseResolution {
  return { status: "ambiguous", definition: null, candidates };
}

function normalize(value: string): string {
  return value.normalize("NFKC").toLowerCase().replace(/[\s_.,，。()（）/\\-]+/g, "");
}

function containsPhrase(message: string, phrase: string): boolean {
  return phrase !== "" && message.includes(phrase);
}

function containsStableKey(message: string, key: string): boolean {
  if (!key.includes("_")) return message.trim().toLowerCase() === key.toLowerCase();
  const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return new RegExp(`(^|[^a-z0-9_])${escaped}($|[^a-z0-9_])`, "i").test(message);
}

function longestMatches<T>(items: readonly T[], phrases: (item: T) => readonly string[], message: string): T[] {
  const matches = items.flatMap((item) => phrases(item).map(normalize).filter((phrase) => containsPhrase(message, phrase)).map((phrase) => ({ item, length: phrase.length })));
  const longest = Math.max(0, ...matches.map((match) => match.length));
  return [...new Set(matches.filter((match) => match.length === longest).map((match) => match.item))];
}
