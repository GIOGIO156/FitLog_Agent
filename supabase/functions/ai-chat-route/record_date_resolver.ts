export type DateResolutionSource =
  | "default"
  | "user_explicit"
  | "unresolved";

export interface RecordDateResolution {
  targetDate: string | null;
  source: DateResolutionSource;
}

export function resolveRecordDate(
  messageText: string,
  baseDate: string | null,
): RecordDateResolution {
  const validBase = isValidDateKey(baseDate) ? baseDate : null;
  const normalized = messageText.trim();

  const absolute = firstAbsoluteDate(normalized, validBase);
  if (absolute !== null) {
    return {
      targetDate: isValidDateKey(absolute) ? absolute : null,
      source: isValidDateKey(absolute) ? "user_explicit" : "unresolved",
    };
  }

  if (validBase !== null) {
    if (/(?:大前天|three\s+days?\s+ago)/i.test(normalized)) {
      return { targetDate: shiftDate(validBase, -3), source: "user_explicit" };
    }
    if (/(?:前天|day\s+before\s+yesterday)/i.test(normalized)) {
      return { targetDate: shiftDate(validBase, -2), source: "user_explicit" };
    }
    if (/(?:昨天|昨日|yesterday)/i.test(normalized)) {
      return { targetDate: shiftDate(validBase, -1), source: "user_explicit" };
    }
    if (/(?:今天|今日|today)/i.test(normalized)) {
      return { targetDate: validBase, source: "user_explicit" };
    }
  }

  if (hasUnresolvedDateCue(normalized)) {
    return { targetDate: null, source: "unresolved" };
  }
  return { targetDate: validBase, source: "default" };
}

export function isValidDateKey(value: string | null): value is string {
  if (value === null || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }
  const [year, month, day] = value.split("-").map(Number);
  const parsed = new Date(Date.UTC(year, month - 1, day));
  return parsed.getUTCFullYear() === year &&
    parsed.getUTCMonth() === month - 1 &&
    parsed.getUTCDate() === day;
}

function firstAbsoluteDate(
  value: string,
  baseDate: string | null,
): string | null {
  const iso = /(?:^|\D)(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?:\D|$)/
    .exec(value);
  if (iso !== null) {
    return dateKey(Number(iso[1]), Number(iso[2]), Number(iso[3]));
  }
  const chinese = /(?:^|\D)(\d{4})年(\d{1,2})月(\d{1,2})日?(?:\D|$)/
    .exec(value);
  if (chinese !== null) {
    return dateKey(
      Number(chinese[1]),
      Number(chinese[2]),
      Number(chinese[3]),
    );
  }
  if (baseDate === null) return null;
  const year = Number(baseDate.slice(0, 4));
  const monthDay = /(?:^|\D)(\d{1,2})月(\d{1,2})日?(?:\D|$)/.exec(value);
  if (monthDay !== null) {
    return dateKey(year, Number(monthDay[1]), Number(monthDay[2]));
  }
  return null;
}

function hasUnresolvedDateCue(value: string): boolean {
  return /(?:上周|下周|周[一二三四五六日天]|星期|上个月|下个月|月初|月底|last\s+(?:week|monday|tuesday|wednesday|thursday|friday|saturday|sunday)|next\s+(?:week|monday|tuesday|wednesday|thursday|friday|saturday|sunday))/i
    .test(value);
}

function shiftDate(value: string, days: number): string {
  const [year, month, day] = value.split("-").map(Number);
  const parsed = new Date(Date.UTC(year, month - 1, day + days));
  return dateKey(
    parsed.getUTCFullYear(),
    parsed.getUTCMonth() + 1,
    parsed.getUTCDate(),
  );
}

function dateKey(year: number, month: number, day: number): string {
  return `${year.toString().padStart(4, "0")}-${month.toString().padStart(2, "0")}-${day.toString().padStart(2, "0")}`;
}
