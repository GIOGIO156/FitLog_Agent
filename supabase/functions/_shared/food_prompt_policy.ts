export type FoodPromptLanguage = "zh" | "en";

export function foodDraftEvidencePolicy(
  language: FoodPromptLanguage,
): string {
  return language === "zh"
    ? [
      "文字和图片是并列、互补的证据，不是互相否定的完整清单。",
      "用户文字通常只补充、修正或说明餐食的一部分；除非用户明确表示只有、只记录、不要或不包含某些食物，不要因为文字未提到就忽略图片中其他合理可识别的食物。",
      "用户明确给出且作用对象清楚的食物名称、份量、重量、包装营养或食用量，只在对应食物和对应字段上优先于视觉观察和通用估算；不要把局部事实误套到整餐，也不要把大概、可能、像是等不确定表述当成确定事实。",
      "份量估算按证据优先级进行：用户明确重量/数量/尺寸/食用量、图片可读营养标签/包装净含量/菜单规格、常见标准商品或品牌规格、用户声明的尺度参照物、图片中的常见参照物，最后才是普通视觉估算。",
      "可以使用模型已有的通用食品和标准商品常识作为估算先验，例如常见连锁汉堡、三明治或包装饮品规格；但不得声称进行了网页搜索，也不得虚构来源。",
      "如果用户声明 40mm 标准乒乓球、330ml 易拉罐等物体作为尺度参照，应优先尝试用它估算食物尺寸；若参照物不在同一平面、距离较远、遮挡、透视明显或尺寸不确定，只能作为弱线索并降低 confidence 或简短说明。",
      "没有明确参照物时，使用餐具、容器、手、手机、键盘、鼠标、杯子、银行卡等可见常见物体作为弱尺度线索，并结合数量、可见面积、厚度、体积、熟重/生重差异、食物密度、含水量、酱汁和不可食用部分估算可食重量。",
      "不要凭整张图的直觉直接估整餐总重量；先确定最终 items，再逐 item 估算整份可食重量和营养，最后用将写入 JSON 的 item 数值相加得到 totals，并静默检查总重量是否明显违背可见体积、容器容量、标准商品规格或用户说明。",
      "文字未覆盖的食物和字段继续根据全部图片合理识别和估算；图片未显示某个用户明确食物不能单独成为删除理由，图片中额外识别到的食物可以加入草稿。",
      "文字与图片冲突时，不要虚构确定结论、删除用户意图或把同一对象重复成两个条目；保留用户明确意图，在 confidence 和 estimation_notes 中说明冲突或不确定性，等待用户确认。",
    ].join(" ")
    : [
      "Text and images are parallel, complementary evidence rather than mutually exclusive complete inventories.",
      "User text usually supplements, corrects, or describes only part of the meal; unless the user explicitly says only, log only, exclude, or without, do not ignore other reasonably identifiable foods merely because the text did not mention them.",
      "A clear user statement with an unambiguous scope about a food name, portion, weight, package nutrition, or consumed amount takes priority over visual observation and generic estimation only for that food and field; do not apply an item-specific fact to the whole meal, and treat words such as approximately, maybe, or looks like as uncertain clues rather than confirmed facts.",
      "Estimate portions by evidence priority: explicit user weight/count/size/consumed amount, readable image nutrition labels/package net weight/menu specs, common standard product or brand-size knowledge, user-declared scale references, common visible reference objects, and only then ordinary visual estimation.",
      "You may use built-in general food and standard-product knowledge as an estimation prior, such as common chain burgers, sandwiches, or packaged drink sizes; never claim that you browsed the web or invent a source.",
      "If the user declares a 40 mm standard ping-pong ball, 330 ml can, or similar object as a scale reference, first try to use it to estimate food dimensions; if the reference is not on the same plane, far away, occluded, perspective-distorted, or uncertain in size, use it only as a weak clue and lower confidence or briefly explain.",
      "When no explicit reference exists, use visible common objects such as utensils, containers, hands, phones, keyboards, mice, cups, or credit cards as weak scale clues, then combine count, visible area, thickness, volume, raw/cooked difference, food density, water content, sauces, and inedible parts to estimate edible weight.",
      "Do not estimate total meal weight from a vague whole-image impression; determine final items first, estimate each item's full edible weight and nutrition, sum the item numbers that will be written to JSON into totals, and silently sanity-check the total weight against visible volume, container capacity, standard product size, and user facts.",
      "Continue using all images to identify and estimate foods and fields not covered by the text; visual absence alone must not delete a user-explicit food, and additional foods reasonably identified in the images may be added to the draft.",
      "When text and images conflict, do not invent certainty, discard the user's intent, or duplicate one physical item as two entries; preserve the clear intent, explain the conflict or uncertainty in confidence and estimation_notes, and leave the draft for user confirmation.",
    ].join(" ");
}
