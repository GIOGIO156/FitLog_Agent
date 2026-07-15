# 产品设计

## 目的

FitLog Local 是一款 local-first 的个人饮食与训练记录 App。它的产品价值不是单纯“记录 kcal”，而是把食物估算、结构化记录、每日目标、剩余宏量、训练消耗、饮食策略、复盘和导出串成一个可长期使用的本地工作流。

这个 App 面向的用户可以借助外部多模态 AI 估算复杂餐食，但需要把这些估算结果沉淀成可编辑、可查询、可导出的本地记录。

## 产品原则

- 本地优先：业务数据保存在 SQLite，除非用户主动导出。
- 确定性行为：核心计算由本地 Dart 逻辑完成，不依赖 App 内部 LLM 推理。
- 用户掌控：App 可以展示目标、剩余量和复盘建议，但不会自动配餐或自动修改目标。
- 加法兼容：数据库迁移必须保留现有本地用户数据。
- 饮食模式保持分离：`gram_per_kg` 和 `energy_ratio` 是并列方法，不得合并。
- 阶段显式：`diet_goal_phase` 是 cutting/bulking 行为的来源。

## 当前模块

| 模块 | 当前能力 | 主要代码 |
| --- | --- | --- |
| Home | 低信息密度的每日入口页，展示问候语、主 calorie/macro 概览、当前饮食上下文和简洁的饮食/训练摘要。 | `lib/features/home/home_page.dart`, `DailySummaryService` |
| Food Log | 按日期查看饮食记录，支持打开/编辑、复制到指定日期、删除和新增入口。 | `lib/features/food/food_log_page.dart`, `FoodRepository` |
| Add Food | 手动录入、外部 AI JSON 粘贴、Prompt 复制和占位的 `Photo AI Analysis`；手动录入复用与已保存饮食详情一致的紧凑表单网格。 | `add_food_page.dart`, `paste_ai_result_page.dart`, `manual_food_entry_page.dart` |
| Food Detail | 编辑已保存的饮食记录和 item 行；显示使用本地化字段标签与后缀单位，底层存储/JSON key 不变。 | `food_detail_page.dart` |
| Workout Log | 按日期展示已保存的训练记录，内部通过 `plan_id` 分组。 | `workout_log_page.dart`, `WorkoutRepository` |
| Add/Edit Workout Record | 命名的多动作训练记录创建/编辑、动作选择器、临时或可复用自定义动作、有氧时长/强度、力量输入口径、已完成组持久化、备注和摘要计算。 | `add_workout_page.dart` |
| Workout Record Detail | 保存后的记录详情、摘要指标、动作卡片和编辑入口。 | `workout_plan_page.dart` |
| Workout Session Detail | 单动作详情视图；当前记录流中，保存后的力量详情不再用于切换完成状态。 | `workout_session_page.dart` |
| Profile | 本地昵称、`用户设置` 摘要页头、当前计划摘要 hero、默认展示且支持年龄/身高/体重/性别统一编辑态的身体资料网格、可点按的阶段/模式/策略矩阵、命名稳定的训练频率与自检设置卡、输入卡片内局部保存、导出和清空本地数据。 | `profile_page.dart`, `ProfileRepository` |
| Export | 导出 XLSX 和 CSV ZIP，覆盖原始记录、自定义动作、保存时的训练输入 metadata、每日汇总、资料、策略字段和 review 历史。 | `lib/export/*` |

## 饮食流程

1. 用户打开 Food Log 并选择日期。
2. 用户选择 Add Food。
3. 如果使用外部 AI 辅助录入，用户复制 FitLog 的 Prompt，使用任意外部模型，并把返回 JSON 粘贴进 App。
4. FitLog 用 `NutritionCalculator.parseAiFoodJson` 在本地解析 JSON。
5. 用户预览、修正并保存 `FoodRecord` 和可选 `FoodItem` 行。
6. 手动录入会跳过 JSON 解析，并以 `source = manual` 保存记录。
7. 保存后的记录可以编辑、删除或复制到用户选择的目标日期。
8. Home 和 Food Log 通过本地 Repository 与刷新状态重新加载。

## 训练流程

1. 用户打开 Workout Log 并选择日期。
2. 用户创建 `Workout Record`，填写名称，并选择一个或多个动作。
3. 动作库支持按部位筛选、搜索、多选、显示选择顺序，以及保存在本地的可复用自定义动作。
4. 用户可以在当前记录中添加临时自定义动作；保存训练时，FitLog 会询问是否保存到可复用动作库。
5. 可复用自定义动作会显示在独立的 `自定义动作` 分组里，不再混进胸部、背部、腿部等内置部位分组。
6. 当用户正在查看这个独立自定义分组时，可复用自定义动作支持在原列表内左滑删除，并在确认后从未来选择中隐藏，而不是跳到单独管理页操作。
7. 临时自定义动作创建页改成卡片式控制面板：页面标题沿用 `添加训练` 的标题级别，顶部使用紧凑的力量/有氧滑块切换、独立的动作身份卡、力量模式下的 bento 归类卡、短 tile 标签、让长重量口径独占一行的紧凑记录规则卡、窄屏单列降级、与训练卡片标题一致的 section title、贴近真实手机比例的字号，以及底部固定添加按钮。
8. 有氧动作需要每个动作自己的时长和本次强度，不使用组清单。
9. 有氧时长说明显示在时长输入框上方，本次强度问题显示在强度选择器上方，以降低下拉文案溢出风险并保持问题可读。
10. 有氧强度使用可维持时长表示：60 分钟以上、30-60 分钟、10-30 分钟、3-10 分钟，或小于 3 分钟且需要休息。
11. 间歇或极高强度有氧会记录实际运动时长，避免把休息时间按极高强度计算。
12. 力量动作使用包含重量、次数或单组时长、完成状态的组行。
13. 内置和自定义力量动作保存当次输入口径：总重量、每侧重量、自重加重、辅助重量、总次数、每侧次数或按时长记录的组。
14. 用户编辑时，FitLog 会先把当前状态持久化为一条本地训练草稿，而不是立刻创建或覆盖正式训练记录。
15. 用户通过应用返回键或系统返回手势离开编辑页时，会保留草稿，而不是强制弹出保存/舍弃弹窗。
16. Workout Log 会在 `添加训练` 上方显示一条紧凑的双行草稿恢复条；标题优先显示训练记录名，否则回退为 `训练草稿`，副标题使用短部位名，最多直接显示三个部位，超过后改为 `+n`，然后再拼接动作数量摘要，或在还没有动作时显示 `点击继续编辑`。
17. 只有用户显式点击保存且校验通过后，才会写入正式训练记录。
18. 力量训练保存时只持久化已完成组；未勾选组会被移除，保存后的组号按 `1..n` 重排。
19. 一条多动作记录存储为多条共享同一 `plan_id` 的 `workout_sessions`；每条 session 也保存相同的 `record_name`。
20. 保存后的记录保留动作快照，所以之后修改可复用自定义动作不会重新解释历史记录。
21. 保存后的记录展示总时长、计算口径训练量、总组数、估算消耗和动作卡片。
22. 编辑已保存记录时，正式保存仍会以事务替换整个 `plan_id` 分组；未保存改动在用户保存或舍弃前只停留在草稿层。

## 每日看板行为

- Home、Food Log 和 Workout Log 共享选中日期。
- Home 的信息密度刻意低于其他副页。
- Home 展示本地时间问候语、本地昵称 fallback、选中日期、当前饮食上下文，以及简洁的饮食/训练摘要，但首屏结构会随计算模式切换。
- 在 `energy_ratio` 中，kcal 目标/摄入/剩余是主计数器，Home 保留热量圆环 hero 和紧随其后的宏量小卡片。
- 在 `gram_per_kg` 中，宏量克数是主计数器，kcal 只是辅助信息；Home 用专属宏量 dashboard 取代热量圆环，并把饮食/训练 kcal 摘要收进 dashboard，让 dashboard 尽量占满首页首屏，把策略卡片放到首屏宏量区域之后。
- 在 `energy_ratio` 中，首屏被定义为一个只包含热量卡和宏量卡的 kcal-first 大盒子：这两张卡片一起待在首屏容器里，二者之间的距离保持受控，宏量卡片下方只保留较短的保护间距，让策略卡片以正常列表节奏接在大盒子之后。
- 在 `gram_per_kg` 中，策略卡片之所以留在首屏之外，同样主要依赖专属首屏 dashboard 容器本身；只是它使用的是 macro-first 的专属 dashboard，而不是 `energy_ratio` 的 kcal-first 双卡盒子。
- BMR、TDEE、校准和长表单细节保留在 Profile、Food、Workout 和详情页，不堆在 Home。
- Home 同时展示 `diet_goal_phase`、`diet_calculation_mode` 和 `diet_plan_strategy` 上下文。
- `carb_cycling` 展示碳水日类型和碳水调整上下文。
- `carb_tapering` 在有数据时展示当前 taper 偏移和待处理 review 上下文。

## 饮食设置交互

Profile 改成“摘要优先”的控制台，而不是首屏长表单，顺序如下：

1. 本地身份摘要：仅用于本机 UI 的昵称，例如 Home 问候语；显示在 `用户设置` 页头下方的一行紧凑身份行里，右侧使用笔形入口触发就地编辑。
2. 当前计划 hero：当前阶段、饮食模式、训练频率/自检摘要、策略标签和静态宏量目标 strip。
3. 身体资料摘要与单 tile 编辑：年龄、身高、体重和性别保持可读的 2x2 展示网格；用户点某一项时只有该 tile 进入编辑态，未改动时点别处可自然收起，有改动时在同卡片内完成保存/取消，而不是跳到单独长表单。
4. 计划矩阵：直接点按 `diet_goal_phase`、`diet_calculation_mode` 和 `diet_plan_strategy` 的 chips，并保持稳定的横向换行排列，而不是切换成全宽竖排按钮。
5. 当前计划 hero 右上角保留一个信息入口，打开后沿用首页策略说明那种非全屏 bottom sheet；`gram_per_kg` 下展示当前阶段/性别对应的频率系数表，`energy_ratio` 下展示默认宏量起步比例和默认生活活动系数表。
6. 靠上的共享训练频率/自检卡，训练频率与自检周期使用直接保存的 chips，四个自检周期选项保持同一行，不在设置卡内重复塞入自检摘要，并且不同饮食模式下沿用同一个卡片标题。
7. `energy_ratio` 模式下，热量比例设置卡紧跟在计划矩阵下面，再往下才是共享训练频率/自检卡，避免模式切换后还要跨卡片找对应输入项。
8. 输入型卡片如昵称、身体资料和 `energy_ratio` 细项，都在当前卡片底部提供局部保存；昵称和身体资料默认是只读展示态，点按类 chips 和 switch 直接保存。
9. 完整的训练频率自检卡保留在设置卡下方的滚动区域，而不是和 `g/kg` 设置混成一张卡；原先那段较长的 g/kg 解释文字也迁入信息弹窗，而不是继续占用设置卡高度。

预期行为：

- `cutting + gram_per_kg`：展示共享训练频率设置、自检设置、减脂 g/kg 表上下文和宏量目标预览。
- `bulking + gram_per_kg`：展示共享训练频率设置、自检设置、增肌 g/kg 表上下文和宏量目标预览。
- `cutting + energy_ratio`：展示共享训练频率设置、每日赤字、宏量比例和目标预览。
- `bulking + energy_ratio`：展示共享训练频率设置、每日盈余、宏量比例、默认 25/50/25 建议和目标预览。
- `carb_cycling`：展示每周 high/medium/low 日选择、倍率和本周预览。
- `carb_tapering`：展示 review 周期、目标减重速度、taper 步长、当前碳水偏移和本地 review 的 Apply/Dismiss 流程。

## 已实现边界

已实现：

- 本地饮食记录 CRUD 和复制到指定日期
- 外部 AI JSON 粘贴和本地解析
- 内置中英 Prompt 复制
- 本地训练记录创建、编辑、分组、摘要和删除
- 每日汇总计算与展示
- 动态热量校准
- 两种饮食模式共享的训练频率自检
- cutting/bulking 阶段拆分
- `energy_ratio` 和 `gram_per_kg` 饮食计算模式
- 本地确定性的 `carb_cycling` 和 `carb_tapering`
- XLSX 和 CSV ZIP 导出
- 语言切换
- 二次确认后清空本地数据

未实现：

- 后端、云同步、账号系统、远程数据库或数据导入
- App 内图片识别
- App 内 LLM API 调用
- RAG、向量数据库、embedding 存储、语义记忆、tool calling 或 Agent loop
- 自动配餐、AI Coach 或自动修改目标
- 医疗建议

## 代码引用

- App 启动与 providers：`lib/main.dart`, `lib/app.dart`
- Home：`lib/features/home/home_page.dart`
- Food：`lib/features/food/*`
- Workout：`lib/features/workout/*`
- Profile：`lib/features/profile/profile_page.dart`
- Models：`lib/domain/models/*`
- Services：`lib/domain/services/*`
- Database 与 repositories：`lib/data/db/app_database.dart`, `lib/data/repositories/*`
- Export：`lib/export/*`
- 本地化与 Prompt：`lib/core/localization/*`, `lib/core/constants/prompt_templates.dart`

