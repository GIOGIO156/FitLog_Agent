import { assertEquals } from "jsr:@std/assert@1";
import { matchClarificationReplyText } from "./clarification_reply.ts";

const options = [
  { id: "answer", label_zh: "回答问题", label_en: "Answer the question" },
  {
    id: "food_draft",
    label_zh: "生成食物草稿",
    label_en: "Create a food draft",
  },
  {
    id: "workout_draft",
    label_zh: "生成训练草稿",
    label_en: "Create a workout draft",
  },
];

Deno.test("free text aliases are scoped to the current pending options", () => {
  assertEquals(
    matchClarificationReplyText("回答问题", "intent_selection", options),
    "answer",
  );
  assertEquals(
    matchClarificationReplyText("第二个", "intent_selection", options),
    "food_draft",
  );
  assertEquals(
    matchClarificationReplyText("option 3", "intent_selection", options),
    "workout_draft",
  );
  assertEquals(
    matchClarificationReplyText("随便聊聊", "intent_selection", options),
    null,
  );
});

Deno.test("business-field follow-up is consumed only with a pending state", () => {
  assertEquals(
    matchClarificationReplyText("深蹲三组十次", "missing_business_fields", []),
    "continue",
  );
});
