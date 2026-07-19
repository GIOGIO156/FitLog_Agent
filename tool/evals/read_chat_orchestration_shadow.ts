type LogRow = {
  created_at: string;
  workflow_type: string | null;
  expected_output: string | null;
  selected_output_type: string | null;
  decision_version: string | null;
  decision_source: string | null;
  decision_reason: string | null;
  decision_shadow_mismatch: string | null;
  clarification_id: string | null;
  clarification_state: string | null;
  clarification_attempt: number | null;
  attachment_policy: string | null;
  error_code: string | null;
  validation_issue_codes_json: string[] | null;
  semantic_issue_codes_json: string[] | null;
  grounding_issue_codes_json: string[] | null;
  failure_class: string | null;
  write_guard_reason: string | null;
};

await loadEnvFile("supabase/.env.local");

const minutes = Math.max(1, Math.min(240, Number(Deno.args[0] ?? "30")));
const supabaseUrl = requiredEnv("SUPABASE_URL").replace(/\/+$/, "");
const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
const query = new URL(`${supabaseUrl}/rest/v1/ai_request_logs`);
query.searchParams.set(
  "select",
  "created_at,workflow_type,expected_output,selected_output_type,decision_version,decision_source,decision_reason,decision_shadow_mismatch,clarification_id,clarification_state,clarification_attempt,attachment_policy,error_code,validation_issue_codes_json,semantic_issue_codes_json,grounding_issue_codes_json,failure_class,write_guard_reason",
);
query.searchParams.set("surface", "eq.ai_chat");
query.searchParams.set(
  "created_at",
  `gte.${new Date(Date.now() - minutes * 60_000).toISOString()}`,
);
query.searchParams.set("order", "created_at.asc");

const response = await fetch(query, {
  headers: {
    apikey: serviceRoleKey,
    authorization: `Bearer ${serviceRoleKey}`,
  },
});
if (!response.ok) {
  throw new Error(`Shadow telemetry query failed (${response.status}).`);
}
const rows = await response.json() as LogRow[];
const mismatchCounts: Record<string, number> = {};
for (const row of rows) {
  const key = row.decision_shadow_mismatch ?? "not_recorded";
  mismatchCounts[key] = (mismatchCounts[key] ?? 0) + 1;
}
console.log(
  JSON.stringify({ minutes, count: rows.length, mismatchCounts, rows }),
);

async function loadEnvFile(path: string): Promise<void> {
  const source = await Deno.readTextFile(path);
  for (const line of source.split(/\r?\n/)) {
    const match = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (match === null || Deno.env.get(match[1]) !== undefined) continue;
    Deno.env.set(match[1], match[2].trim().replace(/^['"]|['"]$/g, ""));
  }
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}
