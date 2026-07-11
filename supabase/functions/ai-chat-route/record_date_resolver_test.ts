import { assertEquals } from "jsr:@std/assert@1";
import {
  isValidDateKey,
  resolveRecordDate,
} from "./record_date_resolver.ts";

Deno.test("record date resolver uses explicit relative and absolute dates", () => {
  assertEquals(resolveRecordDate("记录昨天的牛排", "2026-07-11"), {
    targetDate: "2026-07-10",
    source: "user_explicit",
  });
  assertEquals(resolveRecordDate("记录 2026年7月9日 的午餐", "2026-07-11"), {
    targetDate: "2026-07-09",
    source: "user_explicit",
  });
  assertEquals(resolveRecordDate("record today's workout", "2026-01-01"), {
    targetDate: "2026-01-01",
    source: "user_explicit",
  });
});

Deno.test("record date resolver defaults and refuses ambiguous cues", () => {
  assertEquals(resolveRecordDate("记录一份牛排", "2026-07-11"), {
    targetDate: "2026-07-11",
    source: "default",
  });
  assertEquals(resolveRecordDate("记录上周一的卧推", "2026-07-11"), {
    targetDate: null,
    source: "unresolved",
  });
});

Deno.test("date validation rejects impossible calendar dates", () => {
  assertEquals(isValidDateKey("2024-02-29"), true);
  assertEquals(isValidDateKey("2026-02-29"), false);
  assertEquals(isValidDateKey("2026-13-01"), false);
});
