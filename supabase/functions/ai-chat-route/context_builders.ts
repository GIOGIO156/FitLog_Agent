import type { GatewayRequest } from "./contracts.ts";
import { searchDocumentSources, type SupabaseRestEnv } from "./document_rag.ts";
import type {
  Phase5ContextBundle,
  Phase5ContextObject,
  Phase5DocumentSource,
  Phase5WorkflowRoute,
} from "./phase5_types.ts";

export async function buildPhase5Context(
  env: SupabaseRestEnv,
  accountId: string,
  request: GatewayRequest,
  route: Phase5WorkflowRoute,
): Promise<Phase5ContextBundle> {
  const contextObjects: Phase5ContextObject[] = [];
  const calledTools: string[] = [];
  const missingDimensions: string[] = [];
  const retrievedDimensions: string[] = [];
  const safetyFlags = [...route.safety_flags];
  let documentSources: Phase5DocumentSource[] = [];

  if (route.required_context.includes("document_context")) {
    calledTools.push("search_document_chunks");
    documentSources = await searchDocumentSources(env, request);
    if (documentSources.length === 0) {
      missingDimensions.push("document_context");
    } else {
      retrievedDimensions.push("document_context");
      contextObjects.push(
        contextObject({
          type: "document_context",
          language: request.language,
          source: "document_chunks",
          dateRange: null,
          data: {
            sources: documentSources.map((source) => ({
              doc_path: source.doc_path,
              heading: source.heading,
              section_id: source.section_id,
              status: source.status,
              score: source.score,
            })),
          },
          missing: [],
        }),
      );
    }
  }

  if (route.required_context.includes("profile_context")) {
    calledTools.push("get_cloud_profile");
    const profile = await fetchCloudProfile(env, accountId);
    if (profile === null) {
      missingDimensions.push("profile_context");
    } else {
      retrievedDimensions.push("profile_context");
      contextObjects.push(profileContext(request.language, profile));
    }
  }

  if (route.required_context.includes("selected_day_summary")) {
    if (!request.allowRecordSummaryContext) {
      addRecordContextDenied("selected_day_summary", missingDimensions, safetyFlags);
    } else {
      calledTools.push("get_selected_day_summary");
      const date = request.selectedDate;
      if (date === null) {
        missingDimensions.push("selected_day_summary");
      } else {
        const summary = await fetchDailySummary(env, accountId, date);
        if (summary === null) {
          missingDimensions.push("selected_day_summary");
        } else {
          retrievedDimensions.push("selected_day_summary");
          contextObjects.push(selectedDaySummaryContext(request.language, date, summary));
        }
      }
    }
  }

  if (route.required_context.includes("recent_food_summary")) {
    if (!request.allowRecordSummaryContext) {
      addRecordContextDenied("recent_food_summary", missingDimensions, safetyFlags);
    } else {
      calledTools.push("build_recent_food_summary");
      const range = reviewRange(request);
      const summary = await fetchRecentFoodSummary(env, accountId, range);
      retrievedDimensions.push("recent_food_summary");
      contextObjects.push(
        contextObject({
          type: "recent_food_summary",
          language: request.language,
          source: "cloud_food_records_summary",
          dateRange: range,
          data: summary,
          missing: summary.recorded_days === 0 ? ["food_records"] : [],
        }),
      );
      if (summary.recorded_days === 0) {
        missingDimensions.push("recent_food_summary");
      }
    }
  }

  if (route.required_context.includes("recent_workout_summary")) {
    if (!request.allowRecordSummaryContext) {
      addRecordContextDenied("recent_workout_summary", missingDimensions, safetyFlags);
    } else {
      calledTools.push("build_recent_workout_summary");
      const range = reviewRange(request);
      const summary = await fetchRecentWorkoutSummary(env, accountId, range);
      retrievedDimensions.push("recent_workout_summary");
      contextObjects.push(
        contextObject({
          type: "recent_workout_summary",
          language: request.language,
          source: "cloud_workout_records_summary",
          dateRange: range,
          data: summary,
          missing: summary.workout_days === 0 ? ["workout_records"] : [],
        }),
      );
      if (summary.workout_days === 0) {
        missingDimensions.push("recent_workout_summary");
      }
    }
  }

  if (route.required_context.includes("body_metric_summary") ||
    route.required_context.includes("weight_trend_summary")) {
    if (!request.allowRecordSummaryContext) {
      if (route.required_context.includes("body_metric_summary")) {
        addRecordContextDenied("body_metric_summary", missingDimensions, safetyFlags);
      }
      if (route.required_context.includes("weight_trend_summary")) {
        addRecordContextDenied("weight_trend_summary", missingDimensions, safetyFlags);
      }
    } else {
      calledTools.push("build_body_metric_summary");
      const range = reviewRange(request);
      const body = await fetchBodyMetricSummary(env, accountId, range);
      contextObjects.push(
        contextObject({
          type: "body_metric_summary",
          language: request.language,
          source: "cloud_body_metric_logs_summary",
          dateRange: range,
          data: body.summary,
          missing: body.summary.entries === 0 ? ["body_metric_logs"] : [],
        }),
      );
      if (body.summary.entries === 0) {
        missingDimensions.push("body_metric_summary");
      } else {
        retrievedDimensions.push("body_metric_summary");
      }
      contextObjects.push(
        contextObject({
          type: "weight_trend_summary",
          language: request.language,
          source: "cloud_body_metric_logs_summary",
          dateRange: range,
          data: body.trend,
          missing: body.trend.status === "insufficient" ? ["weight_trend"] : [],
        }),
      );
      if (body.trend.status === "insufficient") {
        missingDimensions.push("weight_trend_summary");
      } else {
        retrievedDimensions.push("weight_trend_summary");
      }
    }
  }

  if (route.required_context.includes("strategy_context")) {
    const profile = contextObjects.find((object) => object.type === "profile_context");
    if (profile === undefined) {
      missingDimensions.push("strategy_context");
    } else {
      retrievedDimensions.push("strategy_context");
      contextObjects.push(strategyContext(request.language, profile.data));
    }
  }

  return {
    route,
    context_objects: contextObjects.map(sanitizeContextObject),
    document_sources: documentSources,
    called_tools: unique(calledTools),
    retrieved_dimensions: unique(retrievedDimensions),
    missing_dimensions: unique(missingDimensions),
    safety_flags: unique(safetyFlags),
  };
}

function addRecordContextDenied(
  dimension: string,
  missingDimensions: string[],
  safetyFlags: string[],
): void {
  missingDimensions.push(dimension);
  safetyFlags.push("record_summary_context_not_allowed");
}

function profileContext(
  language: "zh" | "en",
  row: Record<string, unknown>,
): Phase5ContextObject {
  return contextObject({
    type: "profile_context",
    language,
    source: "cloud_profiles",
    dateRange: null,
    data: {
      profile_version: row.profile_version ?? null,
      display_name_present: stringValue(row.display_name) !== "",
      age: numberOrNull(row.age),
      is_minor: numberOrNull(row.age) !== null && numberOrNull(row.age)! < 18,
      sex_for_formula: stringValue(row.sex_for_formula),
      diet_goal_phase: stringValue(row.diet_goal_phase),
      diet_calculation_mode: stringValue(row.diet_calculation_mode),
      daily_energy_goal_kcal: numberOrNull(row.daily_energy_goal_kcal),
      macro_ratios: {
        protein_percent: numberOrNull(row.protein_ratio_percent),
        carbs_percent: numberOrNull(row.carbs_ratio_percent),
        fat_percent: numberOrNull(row.fat_ratio_percent),
      },
      training_frequency_per_week: numberOrNull(row.training_frequency_per_week),
      diet_plan_strategy: stringValue(row.diet_plan_strategy),
      carb_cycling: {
        pattern: row.carb_cycle_pattern_json ?? null,
        high_multiplier: numberOrNull(row.carb_cycle_high_multiplier),
        medium_multiplier: numberOrNull(row.carb_cycle_medium_multiplier),
        low_multiplier: numberOrNull(row.carb_cycle_low_multiplier),
      },
      carb_tapering: {
        review_period_days: numberOrNull(row.carb_taper_review_period_days),
        target_loss_pct_per_week: numberOrNull(
          row.carb_taper_target_loss_pct_per_week,
        ),
        step_g: numberOrNull(row.carb_taper_step_g),
        current_delta_g: numberOrNull(row.carb_taper_current_delta_g),
      },
    },
    missing: [],
  });
}

function selectedDaySummaryContext(
  language: "zh" | "en",
  date: string,
  summary: Record<string, unknown>,
): Phase5ContextObject {
  const mode = stringValue(summary.diet_calculation_mode);
  const isGramPerKg = mode === "gram_per_kg";
  return contextObject({
    type: "selected_day_summary",
    language,
    source: "cloud_daily_summaries",
    dateRange: { start: date, end: date },
    data: {
      date,
      diet_goal_phase: stringValue(summary.diet_goal_phase),
      diet_calculation_mode: mode,
      diet_plan_strategy: stringValue(summary.diet_plan_strategy),
      primary_signal: isGramPerKg ? "macro_gaps" : "kcal_remaining",
      kcal: {
        intake: numberOrNull(summary.calories_in),
        exercise: numberOrNull(summary.exercise_calories),
        target_intake: numberOrNull(summary.target_intake),
        remaining: numberOrNull(summary.remaining_calories),
        auxiliary_in_gram_per_kg: isGramPerKg,
      },
      macros: {
        protein_g: numberOrNull(summary.protein_g),
        carbs_g: numberOrNull(summary.carbs_g),
        fat_g: numberOrNull(summary.fat_g),
        target_protein_g: numberOrNull(summary.target_protein_g),
        target_carbs_g: numberOrNull(summary.target_carbs_g),
        target_fat_g: numberOrNull(summary.target_fat_g),
        remaining_protein_g: numberOrNull(summary.remaining_protein_g),
        remaining_carbs_g: numberOrNull(summary.remaining_carbs_g),
        remaining_fat_g: numberOrNull(summary.remaining_fat_g),
      },
      carb_day_type: summary.carb_day_type ?? null,
      strategy_reason_codes: arrayOfStrings(summary.diet_strategy_reason_codes),
    },
    missing: [],
  });
}

function strategyContext(
  language: "zh" | "en",
  profileData: Record<string, unknown>,
): Phase5ContextObject {
  return contextObject({
    type: "strategy_context",
    language,
    source: "cloud_profile_strategy_fields",
    dateRange: null,
    data: {
      diet_plan_strategy: profileData.diet_plan_strategy ?? "none",
      diet_goal_phase: profileData.diet_goal_phase ?? "cutting",
      diet_calculation_mode: profileData.diet_calculation_mode ?? "energy_ratio",
      carb_cycling: profileData.carb_cycling ?? null,
      carb_tapering: profileData.carb_tapering ?? null,
      allowed_actions: ["explain", "suggest_user_confirmed_ui"],
      forbidden_actions: ["apply_strategy", "modify_profile", "change_goal"],
    },
    missing: [],
  });
}

async function fetchCloudProfile(
  env: SupabaseRestEnv,
  accountId: string,
): Promise<Record<string, unknown> | null> {
  const rows = await fetchRows(
    env,
    `cloud_profiles?select=*&account_id=eq.${encodeURIComponent(accountId)}&limit=1`,
  );
  return rows[0] ?? null;
}

async function fetchDailySummary(
  env: SupabaseRestEnv,
  accountId: string,
  date: string,
): Promise<Record<string, unknown> | null> {
  const rows = await fetchRows(
    env,
    `daily_summaries?select=summary_json&account_id=eq.${encodeURIComponent(accountId)}&date=eq.${date}&deleted_at=is.null&limit=1`,
  );
  const raw = rows[0]?.summary_json;
  return isRecord(raw) ? raw : null;
}

async function fetchRecentFoodSummary(
  env: SupabaseRestEnv,
  accountId: string,
  range: { start: string; end: string },
) {
  const rows = await fetchRows(
    env,
    `food_records?select=date,calories_kcal,protein_g,carbs_g,fat_g&account_id=eq.${encodeURIComponent(accountId)}&date=gte.${range.start}&date=lte.${range.end}&deleted_at=is.null&order=date.asc`,
  );
  const totals = rows.reduce<{
    kcal: number;
    protein_g: number;
    carbs_g: number;
    fat_g: number;
  }>((sum, row) => ({
    kcal: sum.kcal + numberValue(row.calories_kcal),
    protein_g: sum.protein_g + numberValue(row.protein_g),
    carbs_g: sum.carbs_g + numberValue(row.carbs_g),
    fat_g: sum.fat_g + numberValue(row.fat_g),
  }), { kcal: 0, protein_g: 0, carbs_g: 0, fat_g: 0 });
  const dates = new Set(rows.map((row) => stringValue(row.date)).filter(Boolean));
  const days = daysBetweenInclusive(range.start, range.end);
  return {
    days,
    recorded_days: dates.size,
    coverage: days === 0 ? 0 : dates.size / days,
    totals,
    average_per_recorded_day: dates.size === 0
      ? { kcal: 0, protein_g: 0, carbs_g: 0, fat_g: 0 }
      : {
        kcal: totals.kcal / dates.size,
        protein_g: totals.protein_g / dates.size,
        carbs_g: totals.carbs_g / dates.size,
        fat_g: totals.fat_g / dates.size,
      },
  };
}

async function fetchRecentWorkoutSummary(
  env: SupabaseRestEnv,
  accountId: string,
  range: { start: string; end: string },
) {
  const rows = await fetchRows(
    env,
    `workout_sessions?select=date,duration_minutes,estimated_calories,body_part&account_id=eq.${encodeURIComponent(accountId)}&date=gte.${range.start}&date=lte.${range.end}&deleted_at=is.null&order=date.asc`,
  );
  const dates = new Set(rows.map((row) => stringValue(row.date)).filter(Boolean));
  const bodyParts: Record<string, number> = {};
  let duration = 0;
  let kcal = 0;
  for (const row of rows) {
    duration += numberValue(row.duration_minutes);
    kcal += numberValue(row.estimated_calories);
    const bodyPart = stringValue(row.body_part);
    if (bodyPart !== "") {
      bodyParts[bodyPart] = (bodyParts[bodyPart] ?? 0) + 1;
    }
  }
  return {
    days: daysBetweenInclusive(range.start, range.end),
    workout_days: dates.size,
    session_count: rows.length,
    total_duration_minutes: duration,
    total_estimated_kcal: kcal,
    body_part_pattern: Object.entries(bodyParts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 4)
      .map(([body_part, count]) => ({ body_part, count })),
  };
}

async function fetchBodyMetricSummary(
  env: SupabaseRestEnv,
  accountId: string,
  range: { start: string; end: string },
) {
  const rows = await fetchRows(
    env,
    `body_metric_logs?select=date,weight_kg,body_fat_percent,waist_cm&account_id=eq.${encodeURIComponent(accountId)}&date=gte.${range.start}&date=lte.${range.end}&deleted_at=is.null&order=date.asc`,
  );
  const weights = rows
    .map((row) => ({ date: stringValue(row.date), weight: numberOrNull(row.weight_kg) }))
    .filter((item) => item.date !== "" && item.weight !== null) as {
      date: string;
      weight: number;
    }[];
  const trend = weights.length < 2
    ? { status: "insufficient", reason: "need_at_least_two_weight_logs" }
    : {
      status: "available",
      start_date: weights[0].date,
      end_date: weights[weights.length - 1].date,
      start_weight_kg: weights[0].weight,
      end_weight_kg: weights[weights.length - 1].weight,
      delta_kg: weights[weights.length - 1].weight - weights[0].weight,
    };
  return {
    summary: {
      entries: rows.length,
      weight_entries: weights.length,
      body_fat_entries: rows.filter((row) => row.body_fat_percent !== null).length,
      waist_entries: rows.filter((row) => row.waist_cm !== null).length,
    },
    trend,
  };
}

async function fetchRows(
  env: SupabaseRestEnv,
  path: string,
): Promise<Record<string, unknown>[]> {
  const response = await fetch(`${env.supabaseUrl}/rest/v1/${path}`, {
    headers: {
      apikey: env.supabaseServiceRoleKey,
      authorization: `Bearer ${env.supabaseServiceRoleKey}`,
    },
  });
  if (!response.ok) {
    console.warn("phase5_context_fetch_failed", {
      table: path.split("?")[0],
      status: response.status,
    });
    return [];
  }
  const rows = await response.json();
  return Array.isArray(rows)
    ? rows.filter(isRecord).map((row) => row as Record<string, unknown>)
    : [];
}

function contextObject(params: {
  type: string;
  language: "zh" | "en";
  source: string;
  dateRange: { start: string; end: string } | null;
  data: Record<string, unknown>;
  missing: string[];
}): Phase5ContextObject {
  return {
    type: params.type,
    version: "v1",
    language: params.language,
    date_range: params.dateRange,
    source: params.source,
    data: params.data,
    missing: params.missing,
    privacy: {
      contains_raw_records: false,
      contains_images: false,
      contains_user_free_text_notes: false,
    },
  };
}

function sanitizeContextObject(object: Phase5ContextObject): Phase5ContextObject {
  const json = JSON.stringify(object);
  if (
    json.length > 9000 ||
    /base64|auth_token|authorization|service_role|provider_key|api_key/i.test(json)
  ) {
    return {
      ...object,
      data: { status: "redacted_by_context_sanitizer" },
      missing: unique([...object.missing, "sanitized_context_payload"]),
    };
  }
  return object;
}

function reviewRange(request: GatewayRequest): { start: string; end: string } {
  const end = request.selectedDate ?? todayKey();
  const days = /14|十四|两周|two weeks/i.test(request.messageText) ? 14 : 7;
  return { start: shiftDate(end, -(days - 1)), end };
}

function daysBetweenInclusive(start: string, end: string): number {
  const ms = Date.parse(`${end}T00:00:00Z`) - Date.parse(`${start}T00:00:00Z`);
  return Number.isFinite(ms) ? Math.floor(ms / 86400000) + 1 : 0;
}

function shiftDate(date: string, offsetDays: number): string {
  const parsed = new Date(`${date}T00:00:00Z`);
  parsed.setUTCDate(parsed.getUTCDate() + offsetDays);
  return parsed.toISOString().slice(0, 10);
}

function todayKey(): string {
  return new Date().toISOString().slice(0, 10);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function numberValue(value: unknown): number {
  const parsed = typeof value === "number"
    ? value
    : Number.parseFloat(String(value ?? ""));
  return Number.isFinite(parsed) ? parsed : 0;
}

function numberOrNull(value: unknown): number | null {
  const parsed = typeof value === "number"
    ? value
    : Number.parseFloat(String(value ?? ""));
  return Number.isFinite(parsed) ? parsed : null;
}

function arrayOfStrings(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.map((item) => String(item));
}

function unique(values: string[]): string[] {
  return [...new Set(values.filter((value) => value.trim() !== ""))];
}
