export type ClarificationOptionId =
  | "answer"
  | "food_draft"
  | "workout_draft"
  | "continue";

export interface ClarificationReplyOption {
  id?: unknown;
  label_zh?: unknown;
  label_en?: unknown;
}

export function matchClarificationReplyText(
  text: string,
  kind: unknown,
  options: ClarificationReplyOption[],
): ClarificationOptionId | null {
  const normalized = normalize(text);
  if (normalized === "") return null;
  if (kind === "missing_business_fields") return "continue";

  const direct = options.find((option) =>
    [option.id, option.label_zh, option.label_en].some((value) =>
      typeof value === "string" && normalize(value) === normalized
    )
  );
  if (isPublicOptionId(direct?.id)) return direct.id;

  const ordinal = ordinalIndex(normalized);
  if (ordinal === null || ordinal >= options.length) return null;
  const selected = options[ordinal]?.id;
  return isPublicOptionId(selected) ? selected : null;
}

function normalize(value: string): string {
  return value.trim().toLocaleLowerCase().replace(/[。.!！?？\s]+$/g, "");
}

function ordinalIndex(value: string): number | null {
  if (/^(?:第?一(?:个|项)?|1|1st|first|option\s*1)$/.test(value)) return 0;
  if (/^(?:第?二(?:个|项)?|2|2nd|second|option\s*2)$/.test(value)) return 1;
  if (/^(?:第?三(?:个|项)?|3|3rd|third|option\s*3)$/.test(value)) return 2;
  return null;
}

function isPublicOptionId(
  value: unknown,
): value is Exclude<ClarificationOptionId, "continue"> {
  return value === "answer" || value === "food_draft" ||
    value === "workout_draft";
}
