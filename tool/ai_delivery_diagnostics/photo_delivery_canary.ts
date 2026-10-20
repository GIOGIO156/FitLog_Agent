type Json = Record<string, unknown>;

await loadEnvFile("supabase/.env.local");
await loadEnvFile("supabase/.env.acceptance.local");

const args = parseArgs(Deno.args);
const supabaseUrl = requiredEnv("SUPABASE_URL").replace(/\/+$/, "");
const anonKey = requiredEnv("SUPABASE_ANON_KEY");
const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
const imageBytes = await Deno.readFile(args.imagePath);
const mimeType = mimeTypeForPath(args.imagePath);
const clientRequestId = `photo-delivery-canary-${crypto.randomUUID()}`;
const deviceId = `photo-delivery-canary-${crypto.randomUUID()}`.slice(0, 96);
const session = await signIn(
  requiredEnv("USER_A_EMAIL"),
  requiredEnv("USER_A_PASSWORD"),
);
await claimDevice(session.accessToken, session.sessionId, deviceId);

let requestId = "";
try {
  const requestStartedAt = Date.now();
  const acceptedResponse = await fetchJson(
    `${supabaseUrl}/functions/v1/ai-food-photo-analyze`,
    {
      method: "POST",
      headers: userHeaders(session.accessToken),
      body: JSON.stringify({
        images: [{
          mime_type: mimeType,
          base64_data: bytesToBase64(imageBytes),
          byte_length: imageBytes.byteLength,
        }],
        language: "zh",
        model_choice: "qwen",
        device_id: deviceId,
        selected_date: new Date().toISOString().slice(0, 10),
        schema_version: "food_draft.v2",
        user_note: "请分析这份餐食。",
        client_request_id: clientRequestId,
        client: {
          delivery_mode: "async_v1",
          app_version: "photo_delivery_canary.v1",
        },
      }),
    },
  );
  const acceptedResponseAt = Date.now();
  if (acceptedResponse.status !== 202) {
    throw new Error(`delivery accept failed (${acceptedResponse.status})`);
  }
  requestId = nestedString(acceptedResponse.body, "transport", "request_id");
  if (requestId === "") throw new Error("accepted response has no request_id");

  const appPollPromise = pollAtAppCadence(session.accessToken, requestId);
  const terminal = await pollTerminalWithServiceRole(requestId);
  const appVisible = await appPollPromise;
  const log = await loadRequestLog(requestId);
  const acceptedAt = parseDate(terminal.accepted_at, "accepted_at");
  const completedAt = parseDate(terminal.completed_at, "completed_at");
  const claimAt = parseOptionalDate(terminal.claim_at);
  const appObservedAt = appVisible.observed_at;

  console.log(JSON.stringify(
    {
      schema_version: "photo_delivery_canary.v1",
      image: {
        mime_type: mimeType,
        byte_length: imageBytes.byteLength,
      },
      terminal_status: terminal.status,
      error_code: terminal.error_code ?? null,
      client_accept_round_trip_ms: acceptedResponseAt - requestStartedAt,
      server_accepted_to_claim_ms: claimAt === null
        ? null
        : claimAt.getTime() - acceptedAt.getTime(),
      server_accepted_to_completed_ms: completedAt.getTime() -
        acceptedAt.getTime(),
      app_poll_count: appVisible.poll_count,
      app_terminal_query_ms: appVisible.query_ms,
      accepted_response_to_app_observed_ms: appObservedAt - acceptedResponseAt,
      client_send_to_app_observed_ms: appObservedAt - requestStartedAt,
      app_completion_visibility_upper_bound_ms: 3000 + appVisible.query_ms,
      latency_breakdown: recordValue(log.latency_breakdown_json),
    },
    null,
    2,
  ));
} finally {
  if (requestId !== "") await cleanupCanary(requestId);
}

async function signIn(email: string, password: string): Promise<{
  accessToken: string;
  sessionId: string;
}> {
  const response = await fetchJson(
    `${supabaseUrl}/auth/v1/token?grant_type=password`,
    {
      method: "POST",
      headers: { apikey: anonKey, "content-type": "application/json" },
      body: JSON.stringify({ email, password }),
    },
  );
  const accessToken = stringValue(recordValue(response.body).access_token);
  if (response.status !== 200 || accessToken === "") {
    throw new Error(`acceptance sign-in failed (${response.status})`);
  }
  const payload = decodeJwtPayload(accessToken);
  const sessionId = stringValue(
    payload.session_id ?? payload.sid ?? payload.jti,
  );
  if (sessionId === "") throw new Error("acceptance token has no session id");
  return { accessToken, sessionId };
}

async function claimDevice(
  accessToken: string,
  sessionId: string,
  claimDeviceId: string,
): Promise<void> {
  const response = await fetchJson(
    `${supabaseUrl}/rest/v1/rpc/claim_active_device`,
    {
      method: "POST",
      headers: userHeaders(accessToken),
      body: JSON.stringify({
        input_device_id: claimDeviceId,
        input_session_id: sessionId,
        input_platform: "canary",
        input_app_version: "photo_delivery_canary.v1",
      }),
    },
  );
  if (response.status !== 200 || recordValue(response.body).ok !== true) {
    throw new Error(`active device claim failed (${response.status})`);
  }
}

async function pollAtAppCadence(
  accessToken: string,
  targetRequestId: string,
): Promise<{ poll_count: number; query_ms: number; observed_at: number }> {
  for (let pollCount = 1; pollCount <= 45; pollCount += 1) {
    const startedAt = Date.now();
    const row = await loadDelivery(targetRequestId, userHeaders(accessToken));
    const queryMs = Date.now() - startedAt;
    if (isTerminal(row.status)) {
      return {
        poll_count: pollCount,
        query_ms: queryMs,
        observed_at: Date.now(),
      };
    }
    await sleep(3000);
  }
  throw new Error("app cadence polling timed out");
}

async function pollTerminalWithServiceRole(
  targetRequestId: string,
): Promise<Json> {
  for (let index = 0; index < 600; index += 1) {
    const row = await loadDelivery(targetRequestId, serviceHeaders());
    if (isTerminal(row.status)) return row;
    await sleep(250);
  }
  throw new Error("rapid delivery polling timed out");
}

async function loadDelivery(
  targetRequestId: string,
  headers: HeadersInit,
): Promise<Json> {
  const select = [
    "request_id",
    "status",
    "accepted_at",
    "claim_at",
    "completed_at",
    "error_code",
  ].join(",");
  const response = await fetchJson(
    `${supabaseUrl}/rest/v1/ai_delivery_requests?select=${select}` +
      `&request_id=eq.${encodeURIComponent(targetRequestId)}&limit=1`,
    { headers },
  );
  const rows = Array.isArray(response.body) ? response.body : [];
  const row = recordValue(rows[0]);
  if (response.status !== 200 || Object.keys(row).length === 0) {
    throw new Error(`delivery lookup failed (${response.status})`);
  }
  return row;
}

async function loadRequestLog(targetRequestId: string): Promise<Json> {
  for (let index = 0; index < 20; index += 1) {
    const response = await fetchJson(
      `${supabaseUrl}/rest/v1/ai_request_logs` +
        `?select=latency_breakdown_json&request_id=eq.${targetRequestId}&limit=1`,
      { headers: serviceHeaders() },
    );
    const rows = Array.isArray(response.body) ? response.body : [];
    const row = recordValue(rows[0]);
    if (Object.keys(row).length > 0) return row;
    await sleep(250);
  }
  return {};
}

async function cleanupCanary(targetRequestId: string): Promise<void> {
  const headers = { ...serviceHeaders(), prefer: "return=minimal" };
  for (
    const table of [
      "ai_debug_summaries",
      "ai_request_logs",
      "ai_delivery_requests",
    ]
  ) {
    await fetch(
      `${supabaseUrl}/rest/v1/${table}?request_id=eq.${targetRequestId}`,
      { method: "DELETE", headers },
    );
  }
}

async function fetchJson(
  url: string,
  init: RequestInit = {},
): Promise<{ status: number; body: Json | unknown[] }> {
  const response = await fetch(url, init);
  let body: Json | unknown[] = {};
  try {
    const decoded = await response.json();
    body = Array.isArray(decoded) ? decoded : recordValue(decoded);
  } catch (_) {
    body = {};
  }
  return { status: response.status, body };
}

function userHeaders(accessToken: string): Record<string, string> {
  return {
    apikey: anonKey,
    authorization: `Bearer ${accessToken}`,
    "content-type": "application/json",
  };
}

function serviceHeaders(): Record<string, string> {
  return {
    apikey: serviceRoleKey,
    authorization: `Bearer ${serviceRoleKey}`,
    "content-type": "application/json",
  };
}

function decodeJwtPayload(token: string): Json {
  const segment = token.split(".")[1] ?? "";
  const normalized = segment.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  return recordValue(JSON.parse(atob(padded)));
}

function parseArgs(values: string[]): { imagePath: string } {
  const index = values.indexOf("--image");
  const imagePath = index >= 0 ? values[index + 1]?.trim() ?? "" : "";
  if (imagePath === "") throw new Error("--image is required");
  return { imagePath };
}

async function loadEnvFile(path: string): Promise<void> {
  const content = await Deno.readTextFile(path);
  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (line === "" || line.startsWith("#")) continue;
    const separator = line.indexOf("=");
    if (separator < 1) continue;
    const key = line.slice(0, separator).trim();
    if (Deno.env.get(key) !== undefined) continue;
    let value = line.slice(separator + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) value = value.slice(1, -1);
    Deno.env.set(key, value);
  }
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim() ?? "";
  if (value === "") throw new Error(`${name} is required`);
  return value;
}

function mimeTypeForPath(path: string): "image/jpeg" | "image/png" {
  const normalized = path.toLowerCase();
  if (normalized.endsWith(".jpg") || normalized.endsWith(".jpeg")) {
    return "image/jpeg";
  }
  if (normalized.endsWith(".png")) return "image/png";
  throw new Error("Only JPEG and PNG images are supported");
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000));
  }
  return btoa(binary);
}

function nestedString(value: unknown, parent: string, child: string): string {
  return stringValue(
    recordValue(value)[parent] instanceof Object
      ? recordValue(recordValue(value)[parent])[child]
      : "",
  );
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function recordValue(value: unknown): Json {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Json
    : {};
}

function parseDate(value: unknown, field: string): Date {
  const parsed = new Date(stringValue(value));
  if (Number.isNaN(parsed.getTime())) throw new Error(`${field} is invalid`);
  return parsed;
}

function parseOptionalDate(value: unknown): Date | null {
  const parsed = new Date(stringValue(value));
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function isTerminal(value: unknown): boolean {
  return value === "succeeded" || value === "failed";
}

function sleep(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
