export type WriteClaimGuardReason =
  | "first_person_completed_write"
  | "user_object_completed_write"
  | "completed_write_success_claim";

export interface WriteClaimGuardResult {
  blocked: boolean;
  reason: WriteClaimGuardReason | null;
}

const firstPersonCompletedWrite = [
  /\b(?:i|we|fitlog\s+ai)\s+(?:(?:have|already)\s+)?(?:successfully\s+)?(?:saved|deleted|updated|changed|applied)\b/i,
  /(?:我|我们|FitLog\s*AI)\s*(?:已经|已|刚刚)?\s*(?:为你|帮你|替你)?\s*(?:保存|删除|修改|更改|应用)/i,
  /(?:已经|已)(?:为你|帮你|替你)\s*(?:保存|删除|修改|更改|应用)/i,
];

const userObjectCompletedWrite = [
  /\byour\s+(?:(?:workout|food)\s+)?(?:record|records|goal|goals|profile|strategy|data)\s+(?:has|have)\s+been\s+(?:successfully\s+)?(?:saved|deleted|updated|changed|applied)\b/i,
  /(?:你的|您的)(?:记录|目标|资料|档案|策略|数据).{0,8}(?:已经|已)(?:被)?(?:成功)?(?:保存|删除|修改|更改|应用)/i,
];

const completedWriteSuccessClaim = [
  /^(?:successfully\s+)?(?:saved|deleted|updated|changed|applied)\s+(?:your\s+)?(?:record|records|goal|goals|profile|strategy|data)\b/i,
  /(?:保存|删除|修改|更改|应用)(?:成功|完成|好了)(?:[。.!！]|$)/i,
];

export function evaluateWriteClaim(value: string): WriteClaimGuardResult {
  const text = value.trim();
  if (text === "") return { blocked: false, reason: null };
  if (firstPersonCompletedWrite.some((pattern) => pattern.test(text))) {
    return { blocked: true, reason: "first_person_completed_write" };
  }
  if (userObjectCompletedWrite.some((pattern) => pattern.test(text))) {
    return { blocked: true, reason: "user_object_completed_write" };
  }
  if (completedWriteSuccessClaim.some((pattern) => pattern.test(text))) {
    return { blocked: true, reason: "completed_write_success_claim" };
  }
  return { blocked: false, reason: null };
}
