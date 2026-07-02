# Phase 4 Step 6 Engineering Plan: Multimodal AI Chat And AI Page Performance

This document is a working engineering and acceptance plan. It is not a
stable product source of truth. Stable claims should be updated in
`README.md`, `CHANGELOG.md`, `docs/en`, and `docs/zh` only after
implementation and validation pass.

本计划承接 Phase 4 Step 5 暴露出来的两类问题：

1. 产品边界需要修正：AI Chat 不是纯文本聊天，而是 FitLog Agent 三类核心能力的整合入口。
2. AI 页面真机性能需要专项处理：背景动画不可见、键盘和 overlay 动画明显卡顿、回复状态切换出现空档。

## 1. 背景和纠偏

### 1.1 当前设计错误

Step 5 把 Add Food 图片 AI 分析作为专用 workflow 实现，这是正确的快捷入口；但同时把 AI Chat 路径继续描述和约束为 `text-only`，这是错误的。

正确产品判断：

- AI Chat 是 Agent 主入口。
- AI Chat 应整合：
  - 拍照识食物。
  - 拍照或截图配餐。
  - 周复盘、近期复盘和 App 规则问答。
- Add Food 图片分析是快速记食物入口，不是图片能力的唯一入口。
- 千问/Qwen 选择 `qwen3.7plus` 的核心理由之一就是多模态能力，因此 AI Chat 的 Qwen provider 必须支持图片。

### 1.2 仍然必须保留的安全边界

AI Chat 支持图片和结构化结果，不等于允许自动写库。

必须保留：

- 模型 API key 只由服务端管理。
- 不允许用户在客户端填写模型 API key。
- 图片、截图和文字只能生成草稿、建议、复盘或解释。
- Food Draft、Meal Recommendation 等正式写入前必须由用户确认。
- AI 不能静默写入正式 food/workout/body/profile 记录。
- AI 不能自动修改 diet goal、macro target、carb cycling、carb tapering。
- AI 不能自动删除记录。
- 不引入用户数据向量库、长期 semantic memory、GraphRAG 或开放式 autonomous agent loop。
- 原图/base64/provider raw response 不写入 logs/debug summaries/chat history。

## 2. 总目标

完成 AI Chat 多模态能力的产品和技术纠偏，并修复 AI 页面真机性能问题。

完成标准：

- AI Chat 支持添加一张图片或截图。
- Qwen 多模态 provider 能在 AI Chat 路径读取图片。
- AI Chat 能根据图片和文字生成：
  - 食物识别 Food Draft。
  - 拍照/截图配餐建议。
  - 普通文本回答。
- Add Food 图片分析仍保留为快速食物记录入口。
- Chat 结构化输出进入确认边界，保存前不写正式记录。
- AI 页面不再显示“我不能读取或分析图片”这类全局错误边界文案。
- 设计文档从 `text-only Chat` 改为 `multimodal Chat with confirmation boundary`。
- 重命名输入框原地编辑，不改变可见标题字号和可展示长度。
- assistant loading 到正式回复之间没有回到“我在听”的空白状态。
- AI 页真机键盘弹出、history 打开、重命名、发送等待等动画流畅度接近其它页面。
- 背景动效在真机上肉眼可见，且不会拖慢键盘和聊天操作。

## 3. 非目标

本计划不做：

- 用户自填 provider API key。
- 多图批量分析。
- 长期图片库。
- Supabase Storage 图片 retention 方案，除非另开隐私和清理设计。
- 用户业务数据向量库或长期 semantic memory。
- GraphRAG。
- 自动保存 Food Draft。
- 自动执行 Meal Recommendation。
- 自动修改 Profile、目标、策略或 carb taper。
- 自动写 workout/profile/body 记录。
- 生产支付或订阅管理。
- 完整 Document RAG 落地，除非当前任务明确进入 RAG 阶段。

## 4. 当前需要清点和修改的位置

### 4.1 稳定文档和计划文档

需要把 “AI Chat text-only / Chat 图片附件未实现 / Chat Food Draft 未来才做” 改成新的真实目标和实现状态。

预计涉及：

- `README.md`
- `CHANGELOG.md`
- `docs/en/Product.md`
- `docs/zh/Product.md`
- `docs/en/AppGuide.md`
- `docs/zh/AppGuide.md`
- `docs/en/AgentDesign.md`
- `docs/zh/AgentDesign.md`
- `docs/en/Database.md`
- `docs/zh/Database.md`
- `docs/API_CONTRACT_DRAFT.md`
- `docs/ROADMAP.md`
- `docs/FitLog_Agent_V1_Implementation.md`

当前已知 stale wording：

- `text-only turn`
- `Chat-page image attachment remains out of scope`
- `Chat 文本路径不支持图片`
- `No image recognition from AI page`
- `Do not inspect images`
- `不读取图片`
- `Image attachment is not available yet`
- `Chat Food Draft writeback later`

### 4.2 Flutter App

预计涉及：

- `lib/features/ai/ai_page.dart`
  - 图片附件入口。
  - composer 附件 preview。
  - loading bubble 到 assistant response 的原地替换。
  - history rename 输入框尺寸。
  - 背景动效降负载。
  - keyboard inset 动画性能。
- `lib/domain/models/ai_gateway_request.dart`
  - 增加 image attachment payload。
- `lib/domain/models/ai_gateway_response.dart`
  - 支持结构化结果，而不是只允许 text。
- `lib/domain/models/ai_chat_message.dart`
  - 保留 compact `attachmentsMetadata`，不存 raw bytes/base64。
- `lib/domain/models/ai_food_photo_analysis.dart`
  - 复用 Food Draft model 或抽取通用 Food Draft model。
- `lib/data/remote/ai_gateway_client.dart`
  - 序列化 multimodal request。
- `lib/core/localization/app_strings.dart`
  - 删除或改写 “暂不支持图片附件”。
  - 增加图片附件、截图配餐、草稿确认相关文案。
- `lib/features/food/photo_food_analysis_page.dart`
  - 保持 Add Food 快捷通道，可复用 image picking/compression helper。
- `lib/features/food/food_image_picker.dart`
  - 复用到 AI Chat composer。

### 4.3 Supabase Edge Functions

预计涉及：

- `supabase/functions/ai-chat-route/contracts.ts`
  - 允许 `attachments`，限制 exactly one image for first version。
  - 校验 mime、byte length、schema version、future fields。
- `supabase/functions/ai-chat-route/qwen_provider.ts`
  - Qwen multimodal content payload。
  - 删除 “Do not inspect images”。
  - 增加 workflow-specific image prompt。
- `supabase/functions/ai-chat-route/openai_provider.ts`
  - 如果当前 OpenAI provider 未配置 vision model，则对 image request 返回 stable provider capability error，或者引导用户切换 Qwen。
  - 不要假装 OpenAI text model 能看图。
- `supabase/functions/ai-chat-route/index.ts`
  - image_count 不再固定为 0。
  - 写 compact attachment metadata。
  - workflow router 识别 food logging / meal decision / review。
  - 支持 structured response validation。
- `supabase/functions/ai-food-photo-analyze/*`
  - 复用图片校验、Qwen vision request body、Food Draft parser。
  - 避免两条路径逻辑漂移。

### 4.4 Tests

预计涉及：

- `test/ai_gateway_contract_test.dart`
  - text-only 测试改成 text + optional image。
  - image payload 不含 raw future fields。
  - Chat response 可以包含 Food Draft / Meal Recommendation。
- `test/ai_page_test.dart`
  - 图片附件入口。
  - 图片 preview/移除。
  - provider 不支持图片时的用户可见错误。
  - loading bubble 原地替换为 assistant response。
  - rename 输入框尺寸和字体一致。
  - 背景关闭/轻量模式下键盘布局仍正常。
- `test/photo_food_analysis_page_test.dart`
  - 确保 Add Food 快捷通道不回归。
- `supabase/functions/ai-chat-route/index_test.ts`
  - accepts one image attachment。
  - rejects oversized/unsupported image。
  - qwen multimodal payload contains image_url data URL only in provider request。
  - logs image_count = 1。
  - logs/debug summaries do not contain base64。

## 5. 架构决策

### 5.1 AI Chat 是统一入口，Add Food 是快捷入口

产品路由：

```text
Add Food -> Photo AI Analysis -> Food Draft -> Food Preview -> user save

AI Chat -> text/image/screenshot -> workflow router
  -> food_logging -> Food Draft card or Food Preview
  -> meal_decision -> Meal Recommendation card
  -> weekly_review -> Review card/text
  -> app_logic_answer -> text/card
```

Add Food 和 AI Chat 可以共享：

- image picker/compression。
- Food Draft schema。
- Food Draft validation。
- Qwen multimodal provider helper。

但它们的 UX 不完全相同：

- Add Food 默认目标是快速创建一个 Food Draft。
- AI Chat 默认目标是对话式整合：可以追问、解释、配餐、复盘。

### 5.2 第一版 Chat 图片传输仍使用 inline payload

为保持 Step 5 的隐私边界，第一版 Chat 图片也使用单图 inline base64 payload：

- exactly 1 image per request。
- JPEG/PNG/WebP。
- compressed bytes <= 4 MB。
- longest edge around 1600 px。
- no Storage persistence。
- no raw image/base64 in logs/debug/chat history。

后续如需多图、长会话图片引用或图片 retention，再另开 Storage/RLS/TTL 设计。

### 5.3 Qwen 作为第一版 Chat Vision provider

第一版：

- Qwen provider 支持 text + image。
- ChatGPT/OpenAI provider 如果当前未配置 vision model：
  - text request 正常走 OpenAI。
  - image request 返回 stable `provider_capability_missing` 或提示切换 Qwen。

这样避免把未配置的 provider 能力写成已实现。

### 5.4 Chat response 需要结构化结果

当前 `AiGatewayResponse` 主要是 assistant text。Step 6 需要支持：

```text
assistant_text
food_draft
meal_recommendation
review_summary
app_logic_answer
clarification
```

第一版至少实现：

- `message.text`
- `workflow`
- `needs_clarification`
- `clarification_questions`
- `food_draft`
- `meal_recommendation`

所有可保存或可执行结果必须有用户确认边界。

### 5.5 Chat image metadata storage

`ai_chat_messages.attachments_metadata` 可以保存 compact metadata：

```json
[
  {
    "kind": "image",
    "mime_type": "image/jpeg",
    "byte_length": 512000,
    "width": 1280,
    "height": 960,
    "source": "camera|gallery|screenshot|unknown"
  }
]
```

禁止保存：

- raw image bytes。
- base64 payload。
- provider raw response。
- provider secrets。
- local file path。

### 5.6 Workflow router 初版规则

第一版不需要复杂 autonomous routing。使用可解释规则：

- 有图片且用户明确说“记录/估算/这是什么/多少热量” -> `food_logging`。
- 有图片或截图且用户问“怎么吃/怎么配/下一餐/搭配/还差什么” -> `meal_decision`。
- 无图片且问近期表现/总结/复盘 -> `weekly_review`。
- 问 App 规则/怎么用 -> `app_logic_answer`。
- 不确定 -> normal chat + clarification。

后续可以把 workflow classification 交给 server-side prompt，但仍要记录 compact metadata。

## 6. AI 页面性能专项

### 6.1 已观察问题

- 真机背景动画肉眼不可见。
- 键盘弹出明显比其它页面卡。
- history overlay 和重命名输入框交互卡。
- assistant loading 后短暂回到 “我在听” 页面，再显示回复。
- 重命名输入框字号/内边距和普通标题不一致，导致可见标题进编辑态后被遮挡。

### 6.2 官方性能依据

Flutter 官方建议：

- 动画性能必须用 profile build 判断，debug build 不代表 release/profile 性能。
  - https://docs.flutter.dev/perf/rendering-performance
- 使用 DevTools Performance view 观察 UI thread、Raster thread、jank frame、Track Widget Builds、Track Layouts、Track Paints。
  - https://docs.flutter.dev/tools/devtools/performance
- 避免过度 `saveLayer()`、Opacity、clip、shadow、blur。`saveLayer()` 会触发离屏 buffer 和 render target switch，移动 GPU 上代价高。
  - https://docs.flutter.dev/perf/best-practices
- `BackdropFilter` blur 对复杂场景很贵，能用 `ImageFiltered` 或静态背景替代时应替代。
  - https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html
- `AnimatedBuilder` 应把不依赖动画的 subtree 放进 `child`，避免每 tick rebuild。
  - https://api.flutter.dev/flutter/widgets/AnimatedBuilder-class.html
- `CustomPainter` 可通过 `repaint` listenable 直接触发 paint，避开 build/layout。
  - https://api.flutter.dev/flutter/rendering/CustomPainter-class.html
- `RepaintBoundary` 用于隔离真正变化的区域，避免 ancestor/descendant 动画导致整层 repaint。
  - https://api.flutter.dev/flutter/widgets/RepaintBoundary-class.html

### 6.3 性能诊断顺序

1. 用 profile build 在真机复现：
   - AI 首页 idle。
   - 打开键盘。
   - 输入文字。
   - 打开 history panel。
   - inline rename。
   - 发送消息等待回复。
2. 记录 DevTools Performance：
   - UI thread frame time。
   - Raster thread frame time。
   - 是否有 jank frame。
   - Track Builds / Layouts / Paints。
3. 加 debug/profile-only feature flags：
   - 关闭背景 painter。
   - 关闭 glass/blur。
   - 关闭 shadows。
   - 关闭 history panel backdrop。
4. 对比是否立刻流畅：
   - 关闭背景后流畅 -> 背景 painter 是主因。
   - 关闭 blur 后流畅 -> blur/backdrop 是主因。
   - Track Builds 显示整页 rebuild -> state/rebuild 范围是主因。
   - Track Paints 显示整页 repaint -> repaint boundary/layer 是主因。

### 6.4 性能修复方向

优先级从高到低：

1. 回复状态原子切换
   - assistant loading bubble 不应先移除。
   - 收到响应后，用同一个 placeholder message 原地替换为 assistant message。
   - 页面不应回到 empty/listening state。

2. 重命名输入框原地编辑
   - 展示态标题和编辑态 TextField 使用同一 theme text style。
   - TextField 去掉额外厚边框和过大 horizontal padding。
   - 保持 tile height 不变。
   - 标题显示区域宽度与普通标题一致。
   - 如果普通标题可完整展示，编辑态也必须完整展示。

3. 背景动画降负载
   - 先证明关闭背景后键盘是否恢复。
   - 如果背景是主因，改为：
     - static base gradient。
     - 轻量单层 moving wash。
     - 不使用复杂 path 每帧全屏绘制。
     - 不使用全屏 blur。
   - CustomPainter 使用 `repaint: animation`，避免每 tick rebuild。
   - 背景和 chat content 分离 repaint boundary。

4. 玻璃和 overlay 降级
   - 限制 BackdropFilter 区域，不做全屏 blur。
   - history panel 不做昂贵全屏滤镜。
   - 减少 Opacity layer 嵌套。
   - 减少大面积 shadow/elevation/clip。

5. Keyboard inset 重建范围收缩
   - 键盘高度变化只影响 composer/list bottom inset。
   - 不让背景、history、message bubbles 每帧重 layout。
   - composer、message list、background 拆成独立 widgets。

6. Motion 可见性
   - 性能稳定后再提高可见度。
   - 空白态可以略明显。
   - 阅读/输入态低幅度，但必须可见。

## 7. 分阶段实施计划

### Checkpoint A: 设计纠偏和 contract 清点

目标：把 AI Chat 多模态整合入口写清楚，不再让文档或 prompt 否认图片能力。

任务：

1. 更新 API contract draft：
   - `/ai/chat/route` 从 text-only 改为 multimodal chat route。
   - `attachments` 支持 one image。
   - 说明 Add Food photo 是 shortcut，不是唯一图片入口。
2. 更新 bilingual Product/AppGuide/AgentDesign/Database。
3. 更新 README/ROADMAP。
4. 更新 provider prompt 文案，不再全局说不能读图。
5. 新增 tests 标记当前 desired contract。

验收：

- 搜索不到当前状态文档里的 `text-only Chat`、`Chat image attachment out of scope`、`Do not inspect images`。
- 保留 no auto-write/no user API key/no vector memory 边界。

### Checkpoint B: AI Chat image attachment UI

目标：用户能在 AI Chat composer 添加一张图片。

任务：

1. 复用 `FoodImagePicker` 或抽成通用 `AiImagePicker`。
2. Composer `+` 打开 image source menu：
   - 拍照。
   - 从相册选择。
   - 选择截图/图片。
3. 显示 thumbnail preview。
4. 支持移除图片。
5. 未登录/未订阅/active device 失效时图片发送仍 gated。
6. ChatGPT provider 不支持 image 时提示切 Qwen，或自动要求选择 Qwen。

验收：

- Widget test 覆盖图片选择、预览、移除、发送 payload。
- 真机拍照/相册/取消/权限拒绝路径可用。

### Checkpoint C: Multimodal Gateway contract

目标：`ai-chat-route` 能接收 text + image，并路由 Qwen 多模态。

任务：

1. `AiGatewayRequest` 增加 attachments。
2. `supabase/functions/ai-chat-route/contracts.ts` 接收 one image。
3. 图片校验：
   - mime。
   - byte length。
   - schema version。
   - no future unsupported fields。
4. Qwen provider 构造 content array：
   - text part。
   - image_url data URL。
5. `ai_request_logs.image_count = 1`。
6. `ai_debug_summaries` 只写 compact metadata。
7. OpenAI provider 缺 vision 时返回 stable capability error。

验收：

- Deno tests 覆盖 accepted image、oversized image、unsupported mime、provider payload、no base64 logging。
- Flutter contract tests 覆盖 request serialization。

### Checkpoint D: Chat structured response

目标：AI Chat 可以返回 Food Draft 和 Meal Recommendation，但不自动写正式记录。

任务：

1. 扩展 `AiGatewayResponse`：
   - `structured_result_type`。
   - `food_draft`。
   - `meal_recommendation`。
   - `review_summary` 预留。
2. 服务端 schema validation。
3. Flutter UI：
   - Food Draft card。
   - Meal Recommendation card。
   - Clarification questions。
4. Food Draft card：
   - 可打开 Food Preview。
   - 保存前用户确认。
   - 返回/丢弃不写库。
5. Meal Recommendation card：
   - 显示推荐方案。
   - 如果转 Food Draft，必须用户确认。

验收：

- Food Draft invalid schema 不显示保存入口。
- Food Draft 打开 Food Preview 后才可保存。
- 返回/取消不写 food record。
- Meal Recommendation 不自动改目标或写食物。

### Checkpoint E: AI page performance fix

目标：真机动画和键盘交互恢复流畅。

任务：

1. 加 profile-only diagnostics flag。
2. 先关背景测基线。
3. 优化背景 painter：
   - `CustomPainter(repaint: animation)`。
   - static/dynamic split。
   - 移除复杂全屏 path。
4. 降级 glass/blur/shadow。
5. 拆分 rebuild boundary：
   - background。
   - message list。
   - composer。
   - history panel。
6. 修复 loading bubble 原地替换。
7. 修复 rename TextField 原地编辑尺寸。

验收：

- 真机 AI 页键盘弹出速度接近 Food/Profile 输入框。
- 背景 idle/typing/waiting/read 都可见移动。
- history 打开/rename 不明显掉帧。
- assistant loading 直接替换为回复。

### Checkpoint F: 文档和验收闭环

目标：稳定文档与实现同步。

任务：

1. README 中英文同步。
2. CHANGELOG English only。
3. docs/en 与 docs/zh 同步。
4. API contract draft/roadmap 更新。
5. 搜索 stale wording。

验收：

- required documentation tree exists。
- no replacement characters。
- stable docs 无 date-appended update block。
- 搜索旧词：
  - `text-only`
  - `Do not inspect images`
  - `不读取图片`
  - `Chat-page image attachment remains out of scope`
  - `暂不支持图片附件`
  - `Chat 文本路径不支持图片`

## 8. 自动验收矩阵

Flutter:

```powershell
dart format lib test
flutter analyze
flutter test
flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json
```

Targeted Flutter tests:

```powershell
flutter test test\ai_page_test.dart
flutter test test\ai_gateway_contract_test.dart
flutter test test\ai_gateway_client_test.dart
flutter test test\photo_food_analysis_page_test.dart
```

Backend, if Deno is available:

```powershell
deno fmt supabase/functions
deno test supabase/functions
```

If Deno is unavailable:

- Document blocker。
- Cover server path through deployed function acceptance。

Performance:

```powershell
flutter build apk --profile --split-per-abi --dart-define-from-file=config/supabase.local.json
```

Manual profile checks:

- AI page idle。
- Keyboard open/close。
- History open/close。
- Rename start/save/cancel。
- Send waiting。
- Assistant response insertion。

## 9. 必须人工验收

### 9.1 Chat 图片和 Qwen 多模态

- AI Chat 选择 Qwen。
- 添加食物照片。
- 问“帮我估算这顿饭”。
- 返回 Food Draft 或 clarification。
- 不自动写入正式记录。
- 打开 Food Preview 后保存才写入 `food_records`。

### 9.2 截图配餐

- AI Chat 添加当天饮食截图或食物照片。
- 问“我下一餐怎么配”。
- 返回 Meal Recommendation。
- 不自动创建记录。
- 不自动修改目标/策略。

### 9.3 Provider capability

- 选择 Qwen + 图片：可发送。
- 选择 ChatGPT + 图片但 OpenAI vision 未配置：显示可理解错误或提示切 Qwen。
- 不允许客户端填 provider key。

### 9.4 AI 页性能

- 空白 AI 页背景肉眼可见流动。
- 键盘弹出不明显慢于其它页面。
- history overlay 不明显卡。
- rename 输入框不缩小标题可见范围。
- waiting bubble 直接变成回复。

## 10. Supabase 人工部署和 SQL 验收

若本地不能直接部署：

1. Deploy updated `ai-chat-route`。
2. Deploy updated `ai-food-photo-analyze` if shared helpers changed。
3. Set provider secrets:
   - `FITLOG_QWEN_API_KEY`
   - `FITLOG_QWEN_MODEL`
   - `FITLOG_QWEN_VISION_MODEL` if different
   - `FITLOG_QWEN_BASE_URL`
   - `FITLOG_AI_PROVIDER_TIMEOUT_MS`

验收 SQL:

```sql
select request_id, workflow_type, model_choice, model_provider, image_count, schema_version, status, error_code
from public.ai_request_logs
where created_at > now() - interval '1 hour'
order by created_at desc
limit 20;

select intent, schema_validation_status, retrieved_dimensions_json::text
from public.ai_debug_summaries
where created_at > now() - interval '1 hour'
order by created_at desc
limit 20;
```

确认：

- Chat image request 有 `image_count = 1`。
- `retrieved_dimensions_json` 不含 base64。
- logs/debug summaries 不含 raw image。
- Food Draft save 由 app-side user confirmation 触发，而不是 function 自动写入。

## 11. 风险和缓解

### 11.1 Multimodal contract 膨胀

风险：一次性把 Food Draft、Meal Recommendation、Review、RAG 都塞进 Chat，导致 contract 失控。

缓解：

- Step 6 先做 one image + food/meal decision。
- Review 可先保持文本或 summary card。
- RAG 另开阶段。

### 11.2 图片隐私风险

风险：图片进入 chat history 或 debug summaries。

缓解：

- request 内转发。
- metadata-only storage。
- no Storage retention。
- no base64 logging tests。

### 11.3 真机性能修复误判

风险：只靠 debug build 或模拟器判断。

缓解：

- profile build。
- DevTools frame data。
- feature flags 逐层关闭定位。

### 11.4 Provider 能力差异

风险：OpenAI text provider 不支持图，Qwen 支持图，UI 却表现一致。

缓解：

- Capability matrix。
- image request 优先 Qwen。
- 不支持时稳定错误或切换提示。

## 12. 建议 commit message

```text
feat(ai): add multimodal chat plan and performance audit
```

