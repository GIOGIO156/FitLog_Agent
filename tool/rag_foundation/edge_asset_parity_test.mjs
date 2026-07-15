import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import test from "node:test";

test("generated Edge exercise snapshot matches the canonical 57-item asset", async () => {
  const asset = JSON.parse(await readFile("assets/rag/exercise_terms.v1.json", "utf8"));
  const generated = await readFile("supabase/functions/ai-chat-route/generated/rag_assets.v1.ts", "utf8");
  const hash = createHash("sha256").update(JSON.stringify(asset.exercises)).digest("hex");
  assert.equal(asset.exercises.length, 57);
  assert.match(generated, new RegExp(`"catalog_hash": "${hash}"`));
  assert.match(generated, /"exercise_count": 57/);
  assert.match(generated, /"key": "bulgarian_split_squat"[\s\S]+?"reps_input_mode": "per_side_reps"/);
});

test("generated asset can be reproduced without changes", async () => {
  const before = await readFile("supabase/functions/ai-chat-route/generated/rag_assets.v1.ts", "utf8");
  const childProcess = await import("node:child_process");
  childProcess.execFileSync(process.execPath, ["tool/rag_foundation/export_edge_rag_assets.mjs"], { stdio: "ignore" });
  const after = await readFile("supabase/functions/ai-chat-route/generated/rag_assets.v1.ts", "utf8");
  assert.equal(after, before);
});
