import { assertEquals } from "jsr:@std/assert@1";
import { evaluateWriteClaim } from "./write_claim_guard.ts";

for (
  const text of [
    "I saved your record.",
    "We have successfully updated your goal.",
    "Your workout record has been saved.",
    "Saved your record.",
    "我已经为你保存了训练记录。",
    "你的目标已被修改。",
    "删除成功。",
  ]
) {
  Deno.test(`write claim guard blocks completed action: ${text}`, () => {
    assertEquals(evaluateWriteClaim(text).blocked, true);
  });
}

for (
  const text of [
    "The record is saved in the workout_records table.",
    "Workout snapshots are persisted in workout_sessions and workout_sets.",
    "The saved field is only a database status flag.",
    "I cannot save or delete official records.",
    "I have not saved your record.",
    "训练记录保存在 workout_records 表中。",
    "数据已保存于 SQLite 是对存储位置的说明。",
    "保存成功后，请返回训练页面查看。",
    "我可以解释如何保存，但不会替你写入。",
  ]
) {
  Deno.test(`write claim guard allows explanation or negation: ${text}`, () => {
    assertEquals(evaluateWriteClaim(text), { blocked: false, reason: null });
  });
}
