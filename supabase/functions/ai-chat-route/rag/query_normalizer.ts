import { domainTerms, exerciseCatalogSnapshot } from "../generated/rag_assets.v1.ts";
import type { NormalizedRagQuery, RagLanguageProfile } from "./types.ts";

export function normalizeRagQuery(rawQuery: string): NormalizedRagQuery {
  const normalized = normalizeText(rawQuery);
  const language = languageProfile(rawQuery);
  const canonicalConcepts: string[] = [];
  const conceptEvidenceTerms: Record<string, string[]> = {};
  const internalValues: string[] = [];
  const translations: string[] = [];
  const protectedPhrases = new Set<string>();

  for (const concept of domainTerms.concepts) {
    const phrases = [
      concept.concept,
      concept.official.zh,
      concept.official.en,
      ...concept.aliases.zh,
      ...concept.aliases.en,
      ...concept.internal_values,
    ];
    const matched = phrases.filter((phrase) => includesPhrase(normalized, normalizeText(phrase)));
    if (matched.length === 0) continue;
    canonicalConcepts.push(concept.concept);
    conceptEvidenceTerms[concept.concept] = unique(phrases.map(normalizeText));
    internalValues.push(...concept.internal_values);
    translations.push(concept.official.zh, concept.official.en);
    matched.forEach((phrase) => protectedPhrases.add(phrase));
  }

  const exerciseMatches = exerciseCatalogSnapshot.exercises.filter((exercise) => {
    const phrases = [exercise.key, exercise.name_en, exercise.name_zh, ...exercise.aliases.en, ...exercise.aliases.zh];
    return phrases.some((phrase) => includesPhrase(normalized, normalizeText(phrase))) ||
      (exercise.key === "bulgarian_split_squat" && normalized.includes("保加利亚") && normalized.includes("split squat"));
  });
  const exerciseMentions = exerciseMatches.flatMap((exercise) => [exercise.name_zh, exercise.name_en]);
  const exerciseKeys = exerciseMatches.map((exercise) => exercise.key);
  const tokens = segmentRagText(normalized);
  const recognizedIdentifiers = new Set<string>([
    ...internalValues,
    ...exerciseKeys,
  ]);
  const technicalIdentifiers = unique(
    normalized.match(/\b[a-z][a-z0-9]*(?:_[a-z0-9]+)+\b/gu) ?? [],
  ).filter((identifier) => !recognizedIdentifiers.has(identifier));
  const variants = unique([
    rawQuery.trim(),
    normalized,
    [...canonicalConcepts, ...internalValues, ...exerciseKeys].join(" "),
    translations.join(" "),
  ]).filter(Boolean).slice(0, 6);

  return {
    raw_query: rawQuery,
    normalized_query: normalized,
    language_profile: language,
    protected_phrases: [...protectedPhrases],
    technical_identifiers: technicalIdentifiers,
    tokens,
    canonical_concepts: unique(canonicalConcepts),
    concept_evidence_terms: conceptEvidenceTerms,
    internal_values: unique(internalValues),
    translations: unique(translations),
    exercise_mentions: unique(exerciseMentions),
    exercise_keys: unique(exerciseKeys),
    query_variants: variants,
    term_dictionary_version: domainTerms.dictionary_version,
  };
}

export function queryLanguages(query: NormalizedRagQuery): ("zh" | "en")[] {
  if (query.language_profile.value === "mixed") return ["zh", "en"];
  return query.language_profile.value === "zh" ? ["zh", "en"] : ["en", "zh"];
}

function languageProfile(value: string): { value: RagLanguageProfile; confidence: number } {
  const cjk = [...value].filter((character) => /[\u3400-\u4dbf\u4e00-\u9fff]/u.test(character)).length;
  const latin = [...value].filter((character) => /[A-Za-z]/.test(character)).length;
  if (cjk > 0 && latin > 2) return { value: "mixed", confidence: Math.min(1, (cjk + latin) / 12) };
  if (cjk > 0) return { value: "zh", confidence: Math.min(1, cjk / 4) };
  return { value: "en", confidence: latin === 0 ? 0.5 : Math.min(1, latin / 8) };
}

function normalizeText(value: string): string {
  return value.normalize("NFKC").toLowerCase().replace(/[\s\u3000]+/g, " ").trim();
}

function includesPhrase(source: string, phrase: string): boolean {
  if (phrase === "") return false;
  if (/^[a-z0-9 _.-]+$/i.test(phrase)) {
    const escaped = phrase.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    return new RegExp(`(^|[^a-z0-9_])${escaped}($|[^a-z0-9_])`, "i").test(source);
  }
  return source.includes(phrase);
}

export function segmentRagText(value: string): string[] {
  return segmentedTokens(value, 48);
}

function segmentedTokens(value: string, limit: number): string[] {
  const normalized = normalizeText(value);
  const tokens: string[] = [...(normalized.match(/[a-z][a-z0-9_./-]*|\d+(?:\.\d+)?/gu) ?? [])];
  const cjkRuns = normalized.match(/[\u3400-\u4dbf\u4e00-\u9fff]+/gu) ?? [];
  for (const run of cjkRuns) {
    const characters = [...run];
    if (characters.length <= 12) tokens.push(run);
    for (let size = 4; size >= 2; size -= 1) {
      for (let index = 0; index + size <= characters.length; index += 1) {
        tokens.push(characters.slice(index, index + size).join(""));
      }
    }
  }
  return unique(tokens.filter((token) => token.length > 1)).slice(0, limit);
}

function unique(values: string[]): string[] {
  return [...new Set(values.filter(Boolean))];
}
