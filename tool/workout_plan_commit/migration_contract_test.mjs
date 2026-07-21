import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const migrationPath =
  "supabase/migrations/202607220001_workout_plan_commit_protocol.sql";
const localDatabasePath = "lib/data/db/app_database.dart";

test("workout plan commit migration is atomic, idempotent, and scoped", async () => {
  const sql = await readFile(migrationPath, "utf8");

  assert.match(sql, /primary key \(account_id, mutation_id\)/i);
  assert.match(sql, /pg_advisory_xact_lock/i);
  assert.match(sql, /idempotency_conflict/i);
  assert.match(sql, /commit_workout_plan_v1/i);
  assert.match(sql, /get_workout_plan_commit_v1/i);
  assert.match(sql, /abandon_workout_plan_commit_v1/i);
  assert.match(sql, /status in \('pending', 'committed', 'abandoned'\)/i);
  assert.match(sql, /existing_commit\.status = 'abandoned'/i);
  assert.match(sql, /'status', 'abandoned'/i);
  assert.match(sql, /input_sessions is null/i);
  assert.match(sql, /result_session_ids uuid\[\]/i);
  assert.doesNotMatch(sql, /payload_json\s+jsonb/i);
  assert.match(
    sql,
    /revoke all on table public\.workout_plan_commits from anon, authenticated/i,
  );
  assert.match(sql, /active_device_id is distinct from input_device_id/i);
  assert.match(sql, /active_session_id is distinct from input_session_id/i);
});

test("SQLite v18 repairs and retains the local idempotency ledger", async () => {
  const source = await readFile(localDatabasePath, "utf8");

  assert.match(source, /static const int dbVersion = 18/);
  assert.match(source, /CREATE TABLE IF NOT EXISTS workout_plan_commits/i);
  assert.match(source, /PRIMARY KEY \(account_scope, mutation_id\)/i);
  assert.match(source, /onOpen:[\s\S]*_createWorkoutPlanCommitTable\(db\)/);
  assert.match(source, /oldVersion < 17[\s\S]*_createWorkoutPlanCommitTable\(db\)/);
  assert.match(source, /oldVersion < 18[\s\S]*_repairWorkoutPlanCommitStatuses\(db\)/);
});
