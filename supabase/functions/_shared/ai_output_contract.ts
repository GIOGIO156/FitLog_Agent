export const providerGatewayEnvelopeSchemaVersion =
  "provider_gateway_envelope.v2" as const;
export const foodDraftSchemaVersion = "food_draft.v2" as const;
export const workoutDraftSchemaVersion = "workout_draft.v2" as const;
export const outputValidatorVersion = "ai_output_validator.v2" as const;

export type ProviderOutputType =
  | "text"
  | "food_draft"
  | "workout_draft"
  | "clarification";
export type ExpectedOutput =
  | "auto"
  | Exclude<ProviderOutputType, "clarification">;

export interface FoodDraftItem {
  name: string;
  weight_g: number;
  calories_kcal: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
}

export interface FoodDraft {
  schema_version: typeof foodDraftSchemaVersion;
  date: string;
  meal_name: string;
  total_weight_g: number;
  calories_kcal: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  confidence: number | null;
  estimation_notes: string;
  items: FoodDraftItem[];
}

export interface WorkoutDraftSet {
  weight_kg: number | null;
  reps: number | null;
  duration_seconds: number | null;
}

export interface WorkoutDraftExercise {
  exercise_name: string;
  exercise_key: string | null;
  exercise_type: "strength" | "cardio" | null;
  body_part: string | null;
  duration_minutes: number | null;
  active_duration_minutes: number | null;
  cardio_intensity_basis: string | null;
  sets: WorkoutDraftSet[];
}

export interface WorkoutDraft {
  schema_version: typeof workoutDraftSchemaVersion;
  record_name: string;
  date: string;
  notes: string;
  exercises: WorkoutDraftExercise[];
}

export type GatewayDraft = FoodDraft | WorkoutDraft;

export interface ParsedProviderGatewayBody {
  outputType: ProviderOutputType;
  messageText: string;
  draft: GatewayDraft | null;
  needsClarification: boolean;
  clarificationQuestions: string[];
}

export interface ParsedFoodAnalysisEnvelope {
  draft: FoodDraft | null;
  needsClarification: boolean;
  clarificationQuestions: string[];
}

export interface OutputValidationIssue {
  path: string;
  reason: string;
}

export class OutputContractError extends Error {
  readonly issues: OutputValidationIssue[];

  constructor(issues: OutputValidationIssue[]) {
    super("provider_output_invalid");
    this.name = "OutputContractError";
    this.issues = issues.slice(0, 12);
  }
}

const nutritionProperties = {
  weight_g: { type: "number" },
  calories_kcal: { type: "number" },
  protein_g: { type: "number" },
  carbs_g: { type: "number" },
  fat_g: { type: "number" },
};

export const foodDraftJsonSchema: Record<string, unknown> = {
  type: "object",
  additionalProperties: false,
  required: [
    "schema_version",
    "date",
    "meal_name",
    "total_weight_g",
    "calories_kcal",
    "protein_g",
    "carbs_g",
    "fat_g",
    "confidence",
    "estimation_notes",
    "items",
  ],
  properties: {
    schema_version: { type: "string", enum: [foodDraftSchemaVersion] },
    date: { type: "string" },
    meal_name: { type: "string" },
    total_weight_g: { type: "number" },
    calories_kcal: { type: "number" },
    protein_g: { type: "number" },
    carbs_g: { type: "number" },
    fat_g: { type: "number" },
    confidence: {
      anyOf: [
        { type: "number" },
        { type: "null" },
      ],
    },
    estimation_notes: { type: "string" },
    items: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: [
          "name",
          "weight_g",
          "calories_kcal",
          "protein_g",
          "carbs_g",
          "fat_g",
        ],
        properties: {
          name: { type: "string" },
          ...nutritionProperties,
        },
      },
    },
  },
};

export const workoutDraftJsonSchema: Record<string, unknown> = {
  type: "object",
  additionalProperties: false,
  required: ["schema_version", "record_name", "date", "notes", "exercises"],
  properties: {
    schema_version: { type: "string", enum: [workoutDraftSchemaVersion] },
    record_name: { type: "string" },
    date: { type: "string" },
    notes: { type: "string" },
    exercises: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: [
          "exercise_name",
          "exercise_key",
          "exercise_type",
          "body_part",
          "duration_minutes",
          "active_duration_minutes",
          "cardio_intensity_basis",
          "sets",
        ],
        properties: {
          exercise_name: { type: "string" },
          exercise_key: nullableStringSchema(120),
          exercise_type: {
            anyOf: [
              { type: "string", enum: ["strength", "cardio"] },
              { type: "null" },
            ],
          },
          body_part: nullableStringSchema(120),
          duration_minutes: nullableNumberSchema(),
          active_duration_minutes: nullableNumberSchema(),
          cardio_intensity_basis: nullableStringSchema(500),
          sets: {
            type: "array",
            items: {
              type: "object",
              additionalProperties: false,
              required: ["weight_kg", "reps", "duration_seconds"],
              properties: {
                weight_kg: nullableNumberSchema(),
                reps: nullableIntegerSchema(),
                duration_seconds: nullableIntegerSchema(),
              },
            },
          },
        },
      },
    },
  },
};

export const providerGatewayEnvelopeJsonSchema: Record<string, unknown> = {
  type: "object",
  additionalProperties: false,
  required: [
    "schema_version",
    "output_type",
    "message",
    "needs_clarification",
    "clarification_questions",
    "draft",
  ],
  properties: {
    schema_version: {
      type: "string",
      enum: [providerGatewayEnvelopeSchemaVersion],
    },
    output_type: {
      type: "string",
      enum: ["text", "food_draft", "workout_draft", "clarification"],
    },
    message: {
      type: "object",
      additionalProperties: false,
      required: ["text"],
      properties: {
        text: { type: "string" },
      },
    },
    needs_clarification: { type: "boolean" },
    clarification_questions: {
      type: "array",
      items: { type: "string" },
    },
    draft: {
      anyOf: [foodDraftJsonSchema, workoutDraftJsonSchema, { type: "null" }],
    },
  },
};

export const foodAnalysisEnvelopeJsonSchema: Record<string, unknown> = {
  type: "object",
  additionalProperties: false,
  required: [
    "schema_version",
    "needs_clarification",
    "clarification_questions",
    "draft",
  ],
  properties: {
    schema_version: {
      type: "string",
      enum: ["food_analysis_envelope.v1"],
    },
    needs_clarification: { type: "boolean" },
    clarification_questions: {
      type: "array",
      items: { type: "string" },
    },
    draft: { anyOf: [foodDraftJsonSchema, { type: "null" }] },
  },
};

export function parseProviderGatewayEnvelope(
  content: string,
  expectedOutput: ExpectedOutput,
  expectedDate?: string | null,
): ParsedProviderGatewayBody {
  const root = parseJsonRecord(content);
  const issues: OutputValidationIssue[] = [];
  exactKeys(
    root,
    [
      "schema_version",
      "output_type",
      "message",
      "needs_clarification",
      "clarification_questions",
      "draft",
    ],
    "$",
    issues,
  );
  literal(
    root.schema_version,
    providerGatewayEnvelopeSchemaVersion,
    "$.schema_version",
    issues,
  );
  const outputType = enumString(
    root.output_type,
    "$.output_type",
    ["text", "food_draft", "workout_draft", "clarification"],
    issues,
  ) as ProviderOutputType;

  const message = recordAt(root.message, "$.message", issues);
  exactKeys(message, ["text"], "$.message", issues);
  const messageText = boundedString(
    message.text,
    "$.message.text",
    1,
    8000,
    issues,
  );
  const needsClarification = booleanAt(
    root.needs_clarification,
    "$.needs_clarification",
    issues,
  );
  const clarificationQuestions = stringArray(
    root.clarification_questions,
    "$.clarification_questions",
    5,
    500,
    issues,
  );
  const draft = root.draft === null
    ? null
    : parseDraft(root.draft, "$.draft", issues);

  if (needsClarification) {
    if (outputType !== "clarification") {
      issue(
        issues,
        "$.output_type",
        "clarification requires output_type=clarification",
      );
    }
    if (draft !== null) {
      issue(
        issues,
        "$.draft",
        "clarification and draft are mutually exclusive",
      );
    }
    if (clarificationQuestions.length === 0) {
      issue(
        issues,
        "$.clarification_questions",
        "at least one question is required",
      );
    }
  } else {
    if (outputType === "clarification") {
      issue(
        issues,
        "$.output_type",
        "output_type=clarification requires needs_clarification=true",
      );
    }
    if (clarificationQuestions.length !== 0) {
      issue(
        issues,
        "$.clarification_questions",
        "questions require needs_clarification=true",
      );
    }
  }

  if (outputType === "text") {
    if (draft !== null) {
      issue(issues, "$.draft", "text output must not include a draft");
    }
    if (claimsCompletedDraft(messageText)) {
      issue(
        issues,
        "$.message.text",
        "text output must not claim that a draft was created",
      );
    }
  } else if (outputType === "food_draft" && !needsClarification) {
    if (draft === null) {
      issue(issues, "$.draft", "expected food_draft");
    } else if (draft.schema_version !== foodDraftSchemaVersion) {
      issue(
        issues,
        "$.draft.schema_version",
        `expected ${foodDraftSchemaVersion}`,
      );
    }
  } else if (outputType === "workout_draft" && !needsClarification) {
    if (draft === null) {
      issue(issues, "$.draft", "expected workout_draft");
    } else if (draft.schema_version !== workoutDraftSchemaVersion) {
      issue(
        issues,
        "$.draft.schema_version",
        `expected ${workoutDraftSchemaVersion}`,
      );
    }
  }

  if (
    (outputType === "food_draft" || outputType === "workout_draft") &&
    !needsClarification &&
    draft !== null &&
    expectedDate !== undefined
  ) {
    if (expectedDate === null) {
      issue(issues, "$.draft.date", "record date unresolved; clarification required");
    } else if (draft.date !== expectedDate) {
      issue(issues, "$.draft.date", `expected resolved date ${expectedDate}`);
    }
  }

  if (expectedOutput === "text" && outputType !== "text") {
    issue(issues, "$.output_type", "expected text");
  } else if (
    expectedOutput === "food_draft" &&
    outputType !== "food_draft" &&
    outputType !== "clarification"
  ) {
    issue(issues, "$.output_type", "expected food_draft or clarification");
  } else if (
    expectedOutput === "workout_draft" &&
    outputType !== "workout_draft" &&
    outputType !== "clarification"
  ) {
    issue(issues, "$.output_type", "expected workout_draft or clarification");
  }

  throwIfIssues(issues);
  return {
    outputType,
    messageText,
    draft,
    needsClarification,
    clarificationQuestions,
  };
}

function claimsCompletedDraft(value: string): boolean {
  return /(?:已|已经|为你|为您).{0,12}(?:生成|创建|整理|设置).{0,12}(?:饮食|食物|训练|运动|锻炼)?.{0,8}草稿|草稿.{0,8}(?:已|已经).{0,8}(?:生成|创建)|(?:created|generated|prepared).{0,36}(?:food|meal|workout|training|exercise)?\s*draft/i
    .test(value);
}

export function parseFoodAnalysisEnvelope(
  content: string,
  expectedDate?: string,
): ParsedFoodAnalysisEnvelope {
  const root = parseJsonRecord(content);
  const issues: OutputValidationIssue[] = [];
  exactKeys(
    root,
    [
      "schema_version",
      "needs_clarification",
      "clarification_questions",
      "draft",
    ],
    "$",
    issues,
  );
  literal(
    root.schema_version,
    "food_analysis_envelope.v1",
    "$.schema_version",
    issues,
  );
  const needsClarification = booleanAt(
    root.needs_clarification,
    "$.needs_clarification",
    issues,
  );
  const clarificationQuestions = stringArray(
    root.clarification_questions,
    "$.clarification_questions",
    5,
    500,
    issues,
  );
  const draft = root.draft === null
    ? null
    : validateFoodDraft(root.draft, "$.draft", issues);
  if (needsClarification) {
    if (draft !== null) {
      issue(issues, "$.draft", "clarification requires draft null");
    }
    if (clarificationQuestions.length === 0) {
      issue(
        issues,
        "$.clarification_questions",
        "at least one question is required",
      );
    }
  } else {
    if (draft === null) issue(issues, "$.draft", "food draft is required");
    if (clarificationQuestions.length !== 0) {
      issue(
        issues,
        "$.clarification_questions",
        "questions require clarification",
      );
    }
  }
  if (draft !== null && expectedDate !== undefined && draft.date !== expectedDate) {
    issue(issues, "$.draft.date", `expected selected date ${expectedDate}`);
  }
  throwIfIssues(issues);
  return { draft, needsClarification, clarificationQuestions };
}

export function validateFoodDraftValue(
  value: unknown,
  expectedDate?: string,
): FoodDraft {
  const issues: OutputValidationIssue[] = [];
  const draft = validateFoodDraft(value, "$", issues);
  if (expectedDate !== undefined && draft.date !== expectedDate) {
    issue(issues, "$.date", `expected selected date ${expectedDate}`);
  }
  throwIfIssues(issues);
  return draft;
}

function parseDraft(
  value: unknown,
  path: string,
  issues: OutputValidationIssue[],
): GatewayDraft {
  const map = recordAt(value, path, issues);
  if (map.schema_version === workoutDraftSchemaVersion) {
    return validateWorkoutDraft(map, path, issues);
  }
  return validateFoodDraft(map, path, issues);
}

function validateFoodDraft(
  value: unknown,
  path: string,
  issues: OutputValidationIssue[],
): FoodDraft {
  const map = recordAt(value, path, issues);
  exactKeys(
    map,
    [
      "schema_version",
      "date",
      "meal_name",
      "total_weight_g",
      "calories_kcal",
      "protein_g",
      "carbs_g",
      "fat_g",
      "confidence",
      "estimation_notes",
      "items",
    ],
    path,
    issues,
  );
  literal(
    map.schema_version,
    foodDraftSchemaVersion,
    `${path}.schema_version`,
    issues,
  );
  const requestedTotals = {
    total_weight_g: nonNegativeNumber(
      map.total_weight_g,
      `${path}.total_weight_g`,
      issues,
    ),
    calories_kcal: nonNegativeNumber(
      map.calories_kcal,
      `${path}.calories_kcal`,
      issues,
    ),
    protein_g: nonNegativeNumber(map.protein_g, `${path}.protein_g`, issues),
    carbs_g: nonNegativeNumber(map.carbs_g, `${path}.carbs_g`, issues),
    fat_g: nonNegativeNumber(map.fat_g, `${path}.fat_g`, issues),
  };
  const items = arrayAt(map.items, `${path}.items`, 50, issues).map(
    (item, index) => {
      const itemPath = `${path}.items[${index}]`;
      const itemMap = recordAt(item, itemPath, issues);
      exactKeys(
        itemMap,
        [
          "name",
          "weight_g",
          "calories_kcal",
          "protein_g",
          "carbs_g",
          "fat_g",
        ],
        itemPath,
        issues,
      );
      return {
        name: boundedString(itemMap.name, `${itemPath}.name`, 1, 200, issues),
        weight_g: nonNegativeNumber(
          itemMap.weight_g,
          `${itemPath}.weight_g`,
          issues,
        ),
        calories_kcal: nonNegativeNumber(
          itemMap.calories_kcal,
          `${itemPath}.calories_kcal`,
          issues,
        ),
        protein_g: nonNegativeNumber(
          itemMap.protein_g,
          `${itemPath}.protein_g`,
          issues,
        ),
        carbs_g: nonNegativeNumber(
          itemMap.carbs_g,
          `${itemPath}.carbs_g`,
          issues,
        ),
        fat_g: nonNegativeNumber(itemMap.fat_g, `${itemPath}.fat_g`, issues),
      };
    },
  );
  const confidence = nullableNumber(
    map.confidence,
    `${path}.confidence`,
    issues,
    1,
  );
  const totals = items.length === 0 ? requestedTotals : foodTotals(items);
  return {
    schema_version: foodDraftSchemaVersion,
    date: validDate(map.date, `${path}.date`, issues),
    meal_name: boundedString(
      map.meal_name,
      `${path}.meal_name`,
      1,
      200,
      issues,
    ),
    ...totals,
    confidence,
    estimation_notes: boundedString(
      map.estimation_notes,
      `${path}.estimation_notes`,
      0,
      2000,
      issues,
    ),
    items,
  };
}

function validateWorkoutDraft(
  value: unknown,
  path: string,
  issues: OutputValidationIssue[],
): WorkoutDraft {
  const map = recordAt(value, path, issues);
  exactKeys(
    map,
    ["schema_version", "record_name", "date", "notes", "exercises"],
    path,
    issues,
  );
  literal(
    map.schema_version,
    workoutDraftSchemaVersion,
    `${path}.schema_version`,
    issues,
  );
  const exercises = arrayAt(map.exercises, `${path}.exercises`, 50, issues, 1)
    .map((item, index) =>
      validateWorkoutExercise(item, `${path}.exercises[${index}]`, issues)
    );
  return {
    schema_version: workoutDraftSchemaVersion,
    record_name: boundedString(
      map.record_name,
      `${path}.record_name`,
      1,
      200,
      issues,
    ),
    date: validDate(map.date, `${path}.date`, issues),
    notes: boundedString(map.notes, `${path}.notes`, 0, 2000, issues),
    exercises,
  };
}

function validateWorkoutExercise(
  value: unknown,
  path: string,
  issues: OutputValidationIssue[],
): WorkoutDraftExercise {
  const map = recordAt(value, path, issues);
  exactKeys(
    map,
    [
      "exercise_name",
      "exercise_key",
      "exercise_type",
      "body_part",
      "duration_minutes",
      "active_duration_minutes",
      "cardio_intensity_basis",
      "sets",
    ],
    path,
    issues,
  );
  const exerciseType = map.exercise_type === null
    ? null
    : enumString(map.exercise_type, `${path}.exercise_type`, [
      "strength",
      "cardio",
    ], issues) as
      | "strength"
      | "cardio";
  return {
    exercise_name: boundedString(
      map.exercise_name,
      `${path}.exercise_name`,
      1,
      200,
      issues,
    ),
    exercise_key: nullableString(
      map.exercise_key,
      `${path}.exercise_key`,
      120,
      issues,
    ),
    exercise_type: exerciseType,
    body_part: nullableString(map.body_part, `${path}.body_part`, 120, issues),
    duration_minutes: nullableNumber(
      map.duration_minutes,
      `${path}.duration_minutes`,
      issues,
    ),
    active_duration_minutes: nullableNumber(
      map.active_duration_minutes,
      `${path}.active_duration_minutes`,
      issues,
    ),
    cardio_intensity_basis: nullableString(
      map.cardio_intensity_basis,
      `${path}.cardio_intensity_basis`,
      500,
      issues,
    ),
    sets: arrayAt(map.sets, `${path}.sets`, 100, issues).map((item, index) => {
      const setPath = `${path}.sets[${index}]`;
      const setMap = recordAt(item, setPath, issues);
      exactKeys(
        setMap,
        ["weight_kg", "reps", "duration_seconds"],
        setPath,
        issues,
      );
      return {
        weight_kg: nullableNumber(
          setMap.weight_kg,
          `${setPath}.weight_kg`,
          issues,
        ),
        reps: nullableInteger(setMap.reps, `${setPath}.reps`, issues),
        duration_seconds: nullableInteger(
          setMap.duration_seconds,
          `${setPath}.duration_seconds`,
          issues,
        ),
      };
    }),
  };
}

function parseJsonRecord(content: string): Record<string, unknown> {
  try {
    const value = JSON.parse(content.trim());
    if (isRecord(value)) return value;
  } catch (_) {
    // Report one stable validation category without exposing raw provider output.
  }
  throw new OutputContractError([{
    path: "$",
    reason: "expected one JSON object",
  }]);
}

function exactKeys(
  value: Record<string, unknown>,
  keys: string[],
  path: string,
  issues: OutputValidationIssue[],
): void {
  const allowed = new Set(keys);
  for (const key of Object.keys(value)) {
    if (!allowed.has(key)) issue(issues, `${path}.${key}`, "unknown field");
  }
  for (const key of keys) {
    if (!(key in value)) {
      issue(issues, `${path}.${key}`, "required field is missing");
    }
  }
}

function recordAt(
  value: unknown,
  path: string,
  issues: OutputValidationIssue[],
): Record<string, unknown> {
  if (isRecord(value)) return value;
  issue(issues, path, "expected object");
  return {};
}

function boundedString(
  value: unknown,
  path: string,
  minLength: number,
  maxLength: number,
  issues: OutputValidationIssue[],
): string {
  if (typeof value !== "string") {
    issue(issues, path, "expected string");
    return "";
  }
  const text = value.trim();
  if (text.length < minLength || text.length > maxLength) {
    issue(issues, path, `length must be ${minLength}..${maxLength}`);
  }
  return text;
}

function nullableString(
  value: unknown,
  path: string,
  maxLength: number,
  issues: OutputValidationIssue[],
): string | null {
  if (value === null) return null;
  return boundedString(value, path, 1, maxLength, issues);
}

function booleanAt(
  value: unknown,
  path: string,
  issues: OutputValidationIssue[],
): boolean {
  if (typeof value === "boolean") return value;
  issue(issues, path, "expected boolean");
  return false;
}

function stringArray(
  value: unknown,
  path: string,
  maxItems: number,
  maxStringLength: number,
  issues: OutputValidationIssue[],
): string[] {
  return arrayAt(value, path, maxItems, issues).map((item, index) =>
    boundedString(item, `${path}[${index}]`, 1, maxStringLength, issues)
  );
}

function arrayAt(
  value: unknown,
  path: string,
  maxItems: number,
  issues: OutputValidationIssue[],
  minItems = 0,
): unknown[] {
  if (!Array.isArray(value)) {
    issue(issues, path, "expected array");
    return [];
  }
  if (value.length < minItems || value.length > maxItems) {
    issue(issues, path, `item count must be ${minItems}..${maxItems}`);
  }
  return value.slice(0, maxItems);
}

function nonNegativeNumber(
  value: unknown,
  path: string,
  issues: OutputValidationIssue[],
  maximum?: number,
): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
    issue(issues, path, "expected finite non-negative number");
    return 0;
  }
  if (maximum !== undefined && value > maximum) {
    issue(issues, path, `must be <= ${maximum}`);
  }
  return value;
}

function nullableNumber(
  value: unknown,
  path: string,
  issues: OutputValidationIssue[],
  maximum?: number,
): number | null {
  if (value === null) return null;
  return nonNegativeNumber(value, path, issues, maximum);
}

function nullableInteger(
  value: unknown,
  path: string,
  issues: OutputValidationIssue[],
): number | null {
  const number = nullableNumber(value, path, issues);
  if (number !== null && !Number.isInteger(number)) {
    issue(issues, path, "expected integer");
  }
  return number;
}

function enumString(
  value: unknown,
  path: string,
  allowed: string[],
  issues: OutputValidationIssue[],
): string {
  if (typeof value !== "string" || !allowed.includes(value)) {
    issue(issues, path, `expected one of ${allowed.join(", ")}`);
    return allowed[0];
  }
  return value;
}

function literal(
  value: unknown,
  expected: string,
  path: string,
  issues: OutputValidationIssue[],
): void {
  if (value !== expected) issue(issues, path, `expected ${expected}`);
}

function validDate(
  value: unknown,
  path: string,
  issues: OutputValidationIssue[],
): string {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    issue(issues, path, "expected YYYY-MM-DD");
    return "";
  }
  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    issue(issues, path, "expected a real calendar date");
  }
  return value;
}

function foodTotals(items: FoodDraftItem[]) {
  return items.reduce((sum, item) => ({
    total_weight_g: sum.total_weight_g + item.weight_g,
    calories_kcal: sum.calories_kcal + item.calories_kcal,
    protein_g: sum.protein_g + item.protein_g,
    carbs_g: sum.carbs_g + item.carbs_g,
    fat_g: sum.fat_g + item.fat_g,
  }), {
    total_weight_g: 0,
    calories_kcal: 0,
    protein_g: 0,
    carbs_g: 0,
    fat_g: 0,
  });
}

function issue(
  issues: OutputValidationIssue[],
  path: string,
  reason: string,
): void {
  if (issues.length < 24) issues.push({ path, reason });
}

function throwIfIssues(issues: OutputValidationIssue[]): void {
  if (issues.length > 0) throw new OutputContractError(issues);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function nullableStringSchema(_maxLength: number): Record<string, unknown> {
  return {
    anyOf: [
      { type: "string" },
      { type: "null" },
    ],
  };
}

function nullableNumberSchema(): Record<string, unknown> {
  return {
    anyOf: [{ type: "number" }, { type: "null" }],
  };
}

function nullableIntegerSchema(): Record<string, unknown> {
  return {
    anyOf: [{ type: "integer" }, { type: "null" }],
  };
}
