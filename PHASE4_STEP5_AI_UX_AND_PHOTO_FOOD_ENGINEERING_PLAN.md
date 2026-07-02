# Phase 4 Step 5 Engineering Plan: AI UX Stabilization And Photo Food Analysis

This document is a working engineering and acceptance plan, not a stable
product source of truth. Stable product claims should be updated in
`README.md`, `CHANGELOG.md`, `docs/en`, and `docs/zh` only after the
implementation and acceptance checks pass.

本计划覆盖当前集中暴露的两类问题：

1. AI Chat 已接入真实 provider 后的 UX 和性能稳定性修复。
2. Add Food 的图片 AI 分析从占位入口升级为可用的 Food Draft 生成流程。

这不是要把 FitLog_Agent 变成开放式 autonomous Agent。所有 AI 输出仍然只能作为草稿、解释或建议；正式 food record 必须由用户确认后才写入。

## 1. 当前问题清单

### 1.1 AI 页背景动效真机完全不可见

用户已在真机确认：AI 页背景不是“太慢”，而是肉眼看起来一点都没有动。当前自动测试只能证明 Flutter test 环境里的 `AnimationController` value 会推进，不能证明真机渲染可见。

当前相关实现：

- `_AiAnimatedBackground` 使用 `AnimationController.repeat()`：
  `lib/features/ai/ai_page.dart`
- 空白态 duration 当前为 11 秒。
- 输入、等待、阅读态 duration 当前为 56 秒，motion scale 为 0.24。
- 背景在 `RepaintBoundary` 内用 `CustomPainter` 全屏绘制渐变和 path。

初步风险判断：

- 动效参数过弱，导致物理上可能在动但肉眼不可见。
- `TickerMode`、route lifecycle、或页面层级可能让 ticker 在真机被禁用。
- `CustomPainter.shouldRepaint` 或 rebuild 边界可能导致 controller 变化没有实际 repaint。
- AI 页叠加全屏 painter、半透明层、阴影、loading spinner、keyboard animation 后可能造成 UI/raster jank。
- Debug APK 的性能不等于 profile/release 性能，必须用 profile build 做性能判断。

### 1.2 模型选择旁边的状态 pill 表意错误

当前发送中时，模型选择旁边的状态 pill 会变成 `Thinking/思考中`，并出现 spinner。用户反馈：发送键和 chat loading bubble 已经足够表达请求活跃，模型选择旁边应该只表达 provider/gateway readiness。

目标状态：

- 模型选择旁边的 pill 只表达可用性：
  - 可用
  - 不可用
  - 未登录
  - 未订阅
  - 准备中
  - active-device 失效
  - 后端 provider 未配置
- 请求进行中只体现在：
  - 发送按钮 spinner
  - assistant loading bubble

### 1.3 模型选择每次重启回到第一个选项

当前 `_AiProvider _provider = _AiProvider.chatGpt;` 是页面内存状态。App 重启后会回到第一个选项。

目标行为：

- 用户主动选择 ChatGPT 或千问后，本机记住该选择。
- App 重启后恢复上次选择。
- 不写入云端，不和账号同步。
- 不在用户未主动切换时自动改 provider。
- 如果本机记录的 provider 在未来被移除，才回退到默认 provider。

### 1.4 Chat history 的 archive/delete 交互不完整

当前 history tile 有 archive 和 delete，但：

- archive 点击后 session 从主列表消失。
- App 没有 archived list，所以用户无法找回。
- delete 没有二次确认。
- 用户认为 rename 比 archive 更有价值。

目标行为：

- 删除必须二次确认。
- 移除 archive 入口，避免半成品 UX。
- 新增 inline rename。
- Rename 不弹出新窗口；直接把 history tile 的 title 区变成输入框。
- 输入框出现后不能改变 tile 的整体结构关系，参考 Profile 身体资料输入框的稳定尺寸原则。

### 1.5 Add Food 仍保留 Local 版外部 AI prompt 主流程

当前 Add Food 页主入口仍是绿色大卡：

- `复制 AI 食物提示词`
- `粘贴 AI 结果`
- `手动录入`
- `图片 AI 分析` 只是占位，并且在最后。

Agent 版已接入服务端 provider 后，图片 AI 分析应该成为 Add Food 的主入口；复制 prompt 不应该继续作为主流程。

目标行为：

- 删除或降级外部 prompt copy 主入口。
- `图片 AI 分析` 移到第一位，并继承醒目的主卡视觉。
- `手动录入` 保留。
- `粘贴 AI 结果` 可作为 fallback 保留为次级入口，后续确认 App 内图片 AI 稳定后再移除。

### 1.6 当前 Gateway 明确禁止图片和 Food Draft

当前不是 Qwen3.7-Plus 不能看图，而是 FitLog 当前 contract 和 prompt 禁止看图。

当前限制点：

- `AiGatewayRequest` 只发文本。
- `qwen_provider.ts` 只把 `request.messageText` 作为 text message 发给 provider。
- `qwen_provider.ts` system prompt 明确写：
  - 不读取图片。
  - 不生成可保存草稿。
  - 不写入正式记录。
- `ai_request_logs.image_count` 固定为 `0`。
- `AiGatewayResponse` 看到 `draft != null` 会标成 unsupported draft payload。

目标不是简单删掉这几句话，而是新增一个受控的 Food Photo Analysis workflow：

- 输入：一张食物图片 + 可选文字补充。
- 输出：schema-validated Food Draft。
- 写入：不自动写入正式记录；用户确认保存后才使用现有 food repository 写入。
- 日志：只保存 compact metadata，不保存原图、不保存 base64、不保存 provider raw response。

## 2. 总目标

完成 AI Chat UX 稳定化，并让 Add Food 图片 AI 分析生成可编辑、可确认保存的 Food Draft。

完成标准：

- AI 页背景在真机上肉眼可见地运动。
- AI 页键盘弹出不再明显比其它页面卡顿。
- 模型选择旁边的 status pill 不再显示 `思考中`。
- 发送中只在发送按钮和 assistant loading bubble 表示活跃状态。
- 用户选择的 provider 在本机持久化，App 重启后不自动回到第一个。
- Chat history 删除有二次确认。
- Chat history 去掉 archive 入口，新增 inline rename。
- Rename 通过服务端 RPC 更新 cloud session title。
- Add Food 页把图片 AI 分析作为主入口。
- 用户可以拍照或从相册选择图片。
- 用户可以给图片补充文字描述。
- 发送图片分析请求时页面显示 FitLog 风格 loading overlay。
- 服务端调用 Qwen 多模态能力并返回严格 Food Draft schema。
- App 把 Food Draft 转入现有 food preview/editor 页面。
- 用户确认保存前，不写正式 food record。
- README、CHANGELOG、bilingual Product/AppGuide/AgentDesign/Database docs 在实现后同步。
- `dart format lib test`、`flutter analyze`、`flutter test`、相关 backend tests、配置版 debug split APK build 通过，或者环境 blocker 被明确记录。

## 3. 非目标和边界

本计划不做：

- RAG。
- 用户完整历史向量库。
- 长期 semantic memory。
- GraphRAG。
- 自动保存 food record。
- 自动修改 diet goal、macro target、carb cycling、carb tapering。
- 自动删除或修改任何正式记录。
- 让用户把自己的 model API key 填进客户端。
- 把原图长期存入 Supabase Storage，除非后续另立隐私和 retention 设计。
- 在 AI Chat 普通文本路径里混入 image attachment，除非后续明确设计。
- 生产支付或订阅管理。

如果 implementation 中需要改变这些边界，必须先停下来汇报。

## 4. 架构决策

### 4.1 拆成两个 checkpoint

Checkpoint A: AI Chat UX stabilization

- 修复 AI 页动画和性能。
- 修正 status pill 语义。
- 本机持久化 provider choice。
- History 删除确认、移除 archive、inline rename。
- 不引入图片分析。

Checkpoint B: Add Food Photo AI Analysis

- Add Food 入口改版。
- 新建图片分析页。
- 接入拍照/相册。
- 新增多模态 Gateway 路径。
- 返回 Food Draft 并进入预览编辑页。

这样可以先把已上线的 chat UI 稳住，再接入更大的图片能力。

### 4.2 图片分析使用 Food workflow，不默认写入 Chat history

图片 AI 分析属于 Add Food workflow，不应该默认把每次食物照片塞进 AI Chat session。

计划新增服务端路径：

- 推荐：`supabase/functions/ai-food-photo-analyze`
- 复用 auth/subscription/active-device/provider helper。
- `session_id` 可以为空。
- `ai_request_logs.workflow_type` 使用现有 `food_logging`。
- `ai_request_logs.image_count = 1`。
- `ai_debug_summaries.intent = food_photo_analysis`。

这样避免把 Food Draft 流程和普通聊天历史强绑。

### 4.3 图片传输先使用短期无持久化方案

第一版建议：

- 客户端用 `image_picker` 拍照或选相册。
- 客户端限制尺寸和质量，例如 max width/height + JPEG quality。
- 客户端把压缩后的图片转为 base64 data URL 或 provider 兼容 payload。
- Edge Function 只在请求内转发给 provider。
- 不把图片 bytes/base64 写入 logs/debug summaries/chat messages。

理由：

- 避免先设计 Supabase Storage bucket、RLS、retention、清理任务。
- 更符合 V1 隐私边界。
- 工程更小，更适合当前阶段。

必须加的限制：

- 单次只允许 1 张图片。
- 图片压缩后大小超过上限则拒绝，并提示用户换图或重拍。
- 仅允许 JPEG/PNG/WebP 中明确支持的格式。
- 日志只记录 `image_count`、mime type、compressed byte length、draft schema validation status 等 compact metadata。

后续如需保存原图或多图分析，另开设计。

### 4.4 拍照入口先用系统相机，保留未来自定义相机空间

第一版推荐使用 `image_picker`：

- `ImageSource.camera` 唤起系统相机。
- `ImageSource.gallery` 唤起系统相册。

优点：

- 工程小。
- 稳定。
- 权限和不同机型兼容成本低。
- 更适合先打通 Food Draft 流程。

暂不做自定义全屏相机 preview。自定义相机需要 `camera` plugin，涉及 lifecycle、preview aspect ratio、闪光灯、权限、横竖屏和性能，适合作为后续增强。

### 4.5 Food Draft 不复用普通 `AiGatewayResponse`

当前 `AiGatewayResponse` 把 `draft != null` 判为 unsupported。这对 Step 3/4 text chat 是正确的。

图片分析应新增专门 response model：

- `AiFoodPhotoAnalysisRequest`
- `AiFoodPhotoAnalysisResponse`
- `AiFoodDraft`
- `AiFoodDraftItem`

不要把 Food Draft 塞回普通 chat response，避免 text chat 又意外支持 saveable draft。

### 4.6 Rename 使用 RPC，不开放直接 table update

`ai_chat_sessions.title` 已存在，但客户端不应直接 update table。

新增 SQL RPC：

- `rename_ai_chat_session(input_session_id uuid, input_title text)`

规则：

- 只能改当前 authenticated account 自己的 session。
- `deleted_at is null`。
- title trim 后长度必须在限制内，例如 1..80。
- 不允许只包含空白。
- 可选：归档 session 如果未来还有 archived 状态，也可改名；但本轮 UI 不展示 archive。
- grant execute to authenticated。

Repository/controller 通过 RPC 调用。

## 5. 详细实施计划

### 5.1 Checkpoint A-0: Baseline audit

目标：开始改代码前，确认当前状态和已有变更。

操作：

1. `git status --short`
2. 读取：
   - `AGENTS.md`
   - `lib/features/ai/ai_page.dart`
   - `lib/features/ai/ai_chat_controller.dart`
   - `lib/data/repositories/ai_chat_repository.dart`
   - `supabase/migrations/202606300001_phase4_step3_4_chat_ops_real_providers.sql`
   - `test/ai_page_test.dart`
   - `test/ai_chat_controller_test.dart`
3. 确认没有未理解的用户手动改动。
4. 明确本轮不 bump SQLite `AppDatabase.dbVersion`，除非后续 implementation 实际修改 SQLite schema。

自动验收：

- 无代码改动。
- 若发现冲突或用户未说明的同文件改动，先汇报。

### 5.2 Checkpoint A-1: AI background performance diagnosis

目标：证明动画在真机为什么不可见，并用最小改动修复。

工程任务：

1. 增加 debug-only diagnostics，不进入 release UI：
   - controller value tick log 或 hidden test hook。
   - background painter progress exposure for tests。
2. 检查 `TickerMode.of(context)` 在 AI page route 下是否 enabled。
3. 检查 `_AiAnimatedBackground.didUpdateWidget` 是否在 mode/motion 切换时正确 repeat。
4. 检查 `shouldRepaint` 是否覆盖 progress、mode、motion。
5. 用 profile build 在真机查看：
   - keyboard open frame time。
   - AI page idle frame time。
   - message loading frame time。
6. 如果 controller 不 tick：
   - 查 route/TickerMode/lifecycle。
   - 修复 ticker owner 或避免被 offstage route 包裹。
7. 如果 controller tick 但画面不变：
   - 提高 visible motion amplitude。
   - 缩短 quiet state duration。
   - 增加低对比但可见的 moving layer。
8. 如果画面动但卡顿：
   - 减少每帧全屏复杂 path/gradient paint。
   - 把静态背景和动态轻量 overlay 分离。
   - 尽量让 AnimatedBuilder 的 child 静态化。
   - 避免在每帧 rebuild chat content、provider selector、bottom nav。
   - 检查 blur、shadow、opacity 是否触发 expensive layer。

推荐实现方向：

- 保留 AI page 的柔和彩色背景设计。
- 把动效拆为：
  - 静态 base gradient。
  - 1 到 2 个轻量 moving translucent wash layer。
- 空白 landing：
  - 12 到 18 秒周期。
  - 肉眼可见但不花。
- 输入/等待/阅读：
  - 22 到 32 秒周期。
  - 低对比、低位移，但真机肉眼可见。
- 不再使用 56 秒 + 0.24 这种过弱组合。

自动测试：

- Widget test 证明 background controller value advances.
- Widget test 证明 keyboard visible 时 background 仍 advances.
- Painter/unit test 或 widget pixel test 证明不同 progress 下渲染有可测差异。
- Widget test 证明进入 chat/read state 后 motion profile 是 quiet but visible。

必须人工验收：

- 真机空白 AI 页背景肉眼可见流动。
- 真机打开键盘时背景仍流动。
- 真机等待 provider 回复时背景仍轻微流动。
- 键盘弹出动画不明显比 Home/Food/Profile 输入框更卡。
- 若仍卡，记录 profile build 的帧耗时截图或数据。

### 5.3 Checkpoint A-2: Status pill readiness-only

目标：status pill 不再显示 `思考中`，只显示当前可用性。

工程任务：

1. 拆分两个状态：
   - `AiGatewayReadinessPresentation`
   - `AiSendProgressPresentation`
2. `_statusPresentation` 不再接收 `sending` 或不再用 `sending` 改 label。
3. status pill tone 映射：
   - available -> green dot + 可用
   - signed out/offline -> gray
   - subscription/profile gate -> orange
   - backend/provider pending -> orange 或 muted preparing
4. 发送中：
   - send button spinner 保留。
   - assistant loading bubble 保留。
   - status pill 保持之前 readiness。

自动测试：

- 发送中时 status pill 仍显示 `Available/可用`。
- 发送中时 send button spinner 存在。
- 发送中时 assistant loading bubble 存在。
- 不再在 status pill 内出现 `Thinking/思考中`。

无需人工验收，除非 UI 视觉需要主观确认。

### 5.4 Checkpoint A-3: Provider choice local persistence

目标：用户选择千问后，App 重启仍保持千问。

工程任务：

1. 新增本机偏好 key：
   - `fitlog.ai.selected_provider`
2. 存储值：
   - `chatgpt`
   - `qwen`
3. 在 `AiPage` init 时异步读取偏好。
4. 初始读取前：
   - 可先显示默认值，读取完成后如果不同再 setState。
   - 或在 `AccountController`/small preference service 中提前加载。
5. 用户点击 provider selector 时：
   - 立即更新 UI。
   - 写入 SharedPreferences。
6. 不写入 Supabase。
7. 不按 account 区分。用户要求只是单 app 本机选择，不需要云端记忆。

自动测试：

- SharedPreferences fake 初始为 `qwen` 时，AI page provider selector 选中千问。
- 用户点击 ChatGPT 后，本地 key 写入 `chatgpt`。
- 本地 key 为未知值时 fallback 到默认 provider。

无需人工验收，除非需要真机重启确认。

### 5.5 Checkpoint A-4: Chat history delete confirm and inline rename

目标：删除安全，归档移除，重命名可用。

工程任务：

#### Backend

1. 新增 migration：
   - `supabase/migrations/<timestamp>_phase4_step5_chat_session_rename.sql`
2. 新增 RPC：
   - `public.rename_ai_chat_session(input_session_id uuid, input_title text)`
3. RPC 行为：
   - `auth.uid()` 必须存在。
   - title trim。
   - 空 title 抛 stable SQL error 或返回 ok false。
   - title 最大长度限制，例如 80。
   - 只能更新当前 account session。
   - `deleted_at is null`。
   - 更新 `updated_at` 由 trigger 或 update 触发。
   - 返回 JSON：
     - `ok`
     - `session_id`
     - `title`
4. Revoke public/anon execute。
5. Grant execute to authenticated。

#### Flutter data/controller

1. `AiChatRepository` 增加：
   - `Future<void> renameSession(String sessionId, String title)`
2. `SupabaseAiChatRepository` 调 RPC。
3. `AiChatController` 增加：
   - `renameSession(sessionId, title)`
   - optimistic update 或 rename 后 reload sessions。
4. 错误映射：
   - `ai_chat_rename_failed`

#### UI

1. `_AiHistoryTile` 移除 archive icon/action。
2. 增加 edit/rename icon。
3. 点击 rename：
   - 当前 tile 的 title 区切换为 `TextField`。
   - 使用固定高度和固定 padding。
   - 不改变 tile 的 card height。
   - focus 自动进入输入框。
   - Enter/Done 保存。
   - focus lost 可保存或取消，需选一个稳定规则。
   - 空 title 不保存，并显示 inline/notification error。
4. Delete icon 点击：
   - 打开确认 sheet/dialog。
   - 文案明确：删除后当前列表不再显示。
   - Confirm 使用危险色。
   - Cancel 保留。
5. 如果当前选中的 session 被删除：
   - 清空 selected session 或切到最新 session。
   - 保持 controller state 合理。

推荐交互规则：

- Rename:
  - Done 保存。
  - Escape/取消 icon 恢复旧 title。
  - 点击其它 session 前如输入非空，可先保存。
- Delete:
  - 必须二次确认。

自动测试：

- History tile 不再显示 archive button。
- 点击 delete 会先显示 confirm，不会立即调用 repository。
- confirm 后才调用 delete。
- cancel 后不调用 delete。
- 点击 rename 后 title 变成 fixed-size input。
- 输入新 title 并提交后调用 rename repository。
- rename 成功后 list title 更新。
- rename 空 title 显示错误且不调用 repository。
- cross-account rename 由 RPC 拒绝，手工 SQL 验收覆盖。

必须人工验收：

- 真机 history panel 中 rename 输入框不改变 tile 结构。
- 长标题不撑破卡片。
- 删除确认文案和危险按钮视觉符合 FitLog 风格。

### 5.6 Checkpoint B-1: Add Food entry redesign

目标：图片 AI 分析成为 Agent 版 Add Food 主入口。

工程任务：

1. `AddFoodPage` 删除 `_PromptShortcutButton` 主卡。
2. `图片 AI 分析` 变成第一张 hero card：
   - 使用原绿色醒目背景。
   - 主标题：`图片 AI 分析`
   - 副标题：类似 `拍照或选择图片，生成可编辑食物草稿`
   - CTA：`开始`
3. `粘贴 AI 结果` 降级为普通 action card：
   - 保留作为 fallback。
   - 文案从 `ChatGPT/Gemini` 改成更中性：
     - `粘贴外部 AI JSON 并解析`
4. `手动录入` 保留。
5. 页面 header 文案移除 “本地版本没有 App 内 AI 或图片识别”。
6. copy prompt 相关 localization 和 prompt template 暂不立即删除，除非确认没有其它入口引用；本轮至少不再作为主入口展示。

自动测试：

- Add Food 页第一张主卡是 `图片 AI 分析`。
- 不显示 `复制 AI 食物提示词` 主入口。
- `粘贴 AI 结果` 仍可进入 paste flow。
- `手动录入` 仍可进入 manual flow。

必须人工验收：

- 真机 Add Food 页视觉不粗糙。
- 图片 AI 主卡足够醒目。
- 卡片顺序符合预期。

### 5.7 Checkpoint B-2: Photo Food Analysis page

目标：建立拍照/相册/补充描述/发送/等待/失败恢复的完整 UI。

推荐页面：

- `lib/features/food/photo_food_analysis_page.dart`

页面结构：

1. AppBar:
   - title: `图片 AI 分析`
   - back button
2. Header:
   - 轻量说明，不写长教程。
3. Image selection area:
   - 未选择图片：
     - 大 preview placeholder。
     - 两个 icon buttons：
       - 拍照
       - 从相册选择
   - 已选择图片：
     - 图片预览，固定 aspect ratio。
     - 左下/下方操作：
       - 重拍
       - 换图
       - 移除
4. Optional text field:
   - label: `补充说明`
   - hint: `例如：米饭只吃了一半，鸡腿去皮`
   - max lines: 3 到 5
   - 使用 app theme 字体。
   - 固定最小高度，避免键盘出现时结构突跳。
5. Bottom submit:
   - `开始分析`
   - 没有图片时 disabled。
6. Loading overlay:
   - 当前页面 blur 或 translucent veil。
   - 中央 compact card。
   - spinner + `思考中`
   - 禁止重复提交。
7. Failure:
   - 保留图片和补充说明。
   - 显示可读错误。
   - 用户可重试。
8. Success:
   - 进入 `FoodPreviewPage(initialRecord: draft.toFoodRecord(...))`。
   - 用户确认保存后才写正式记录。

视觉要求：

- 不做粗糙表单堆叠。
- 使用 FitLog existing card radius、surface、theme color。
- 不出现嵌套卡片里的卡片。
- 图片预览尺寸稳定。
- 键盘弹出时，补充说明输入框滚到键盘上方。

自动测试：

- 未选择图片时 submit disabled。
- 选择 mock image 后 preview 出现，submit enabled。
- 输入补充说明后 request payload 包含 note。
- loading overlay 出现时不能重复提交。
- failure keeps selected image and note.
- success pushes FoodPreviewPage with parsed draft.

必须人工验收：

- Android 真机拍照权限。
- Android 真机相册选择。
- 拍照后预览方向正确。
- 相册图片预览不变形。
- 键盘输入补充说明时布局稳定。
- loading overlay 符合 AI 页风格，不粗糙。

### 5.8 Checkpoint B-3: Image picker dependency and permissions

目标：使用稳定插件接入系统相机/相册。

推荐依赖：

- `image_picker`

工程任务：

1. `flutter pub add image_picker`
2. Android permission/config review:
   - Camera intent / gallery picker behavior按当前 Android target 检查。
   - 如需 `android.permission.CAMERA`，更新 `android/app/src/main/AndroidManifest.xml`。
3. 新增 wrapper service：
   - `FoodImagePicker`
   - 用于 widget test mock。
4. 设置 image constraints：
   - maxWidth，例如 1280 或 1600。
   - maxHeight，例如 1280 或 1600。
   - imageQuality，例如 75 到 85。
5. 读取 `XFile` bytes。
6. 检查大小上限：
   - 例如 compressed bytes <= 4 MB。
7. 生成 request image payload。

自动测试：

- wrapper service mock test。
- oversized image rejected before network call。
- unsupported mime rejected before network call。

必须人工验收：

- 首次拍照权限弹窗。
- 拒绝权限后的错误提示。
- 允许权限后的拍照流程。
- 相册选择取消不破坏页面。

### 5.9 Checkpoint B-4: Food photo Gateway contract

目标：新增与普通 chat 解耦的 Food Photo Analysis contract。

Flutter models:

- `AiFoodPhotoAnalysisRequest`
  - `image`
    - `mime_type`
    - `base64_data` or `data_url`
    - `byte_length`
  - `language`
  - `model_choice`
  - `device_id`
  - `selected_date`
  - `user_note`
  - `schema_version = food_draft.v1`
- `AiFoodPhotoAnalysisResponse`
  - `model_choice`
  - `model_provider`
  - `draft`
  - `needs_clarification`
  - `clarification_questions`
  - `debug_summary_id`
  - `error`
- `AiFoodDraft`
  - `meal_name`
  - `total_weight_g`
  - `calories_kcal`
  - `protein_g`
  - `carbs_g`
  - `fat_g`
  - `confidence`
  - `estimation_notes`
  - `items`
- `AiFoodDraftItem`
  - `name`
  - `weight_g`
  - `calories_kcal`
  - `protein_g`
  - `carbs_g`
  - `fat_g`

Rules:

- Numeric fields must be finite and non-negative.
- Empty item list is allowed only if clarification is required.
- Draft response must not save record.
- `source` for confirmed save should become `ai_photo`.

App constants:

- Add `AppConstants.sourceAiPhoto = 'ai_photo'`.
- Add localization for `AI Photo` source label.

Automatic tests:

- Request serializes without raw future fields.
- Response parses valid draft.
- Response rejects invalid numeric fields.
- Response maps provider/schema errors to stable error codes.
- Draft converts to `FoodRecord` with `source = ai_photo`.

### 5.10 Checkpoint B-5: Edge Function for photo analysis

目标：服务端验证账号和 entitlement，调用 Qwen 多模态模型，返回严格 Food Draft。

Recommended artifact:

- `supabase/functions/ai-food-photo-analyze/index.ts`

Shared helper extraction:

- Move common auth/subscription/active-device/provider helpers into reusable files if needed.
- Avoid duplicating large logic in two functions.

Server request flow:

1. Handle CORS.
2. Parse JSON.
3. Reject unsupported fields.
4. Validate auth token.
5. Validate subscription.
6. Validate active device.
7. Validate image:
   - exactly one image.
   - supported mime.
   - byte length under limit.
   - no image logging.
8. Select provider:
   - first pass uses Qwen for photo analysis.
   - If ChatGPT/OpenAI image provider is not configured, do not route there.
9. Build provider request:
   - system instruction for food photo draft only.
   - user content includes:
     - image
     - optional note
     - strict output schema instruction
     - no official record write instruction
10. Parse provider response:
   - Prefer JSON object.
   - Strip markdown code fence if provider wraps JSON.
   - Validate schema.
11. Insert `ai_request_logs`:
   - `workflow_type = food_logging`
   - `session_id = null`
   - `model_choice = qwen`
   - `model_provider = qwen`
   - `image_count = 1`
   - no raw image or raw provider response.
12. Insert `ai_debug_summaries`:
   - `intent = food_photo_analysis`
   - `schema_validation_status`
   - compact missing dimensions / safety flags.
13. Return response.

Provider prompt boundaries:

- Can inspect the provided image.
- Can use user note.
- Must estimate, not claim certainty.
- Must ask clarification if food type, portion, or consumed amount is too unclear.
- Must output only strict JSON for successful draft.
- Must not write records.
- Must not claim medical diagnosis.

Automatic backend tests:

- No-auth returns `auth_required`.
- Missing subscription returns `subscription_required`.
- Replaced device returns `device_replaced`.
- Missing image returns validation error.
- Oversized image returns validation error.
- Provider valid JSON returns draft.
- Provider fenced JSON still parses.
- Provider invalid JSON maps to schema/provider failure.
- Logs have `image_count = 1`.
- Logs/debug summaries do not contain base64 image data.

Local blocker:

- Deno tests should run when Deno is available.
- If local Deno is unavailable, deployed function acceptance must cover the server path.

Must be manually done if CLI is not available:

- Deploy the new Supabase Edge Function.
- Apply any SQL migration.
- Ensure Qwen provider secrets are set.

### 5.11 Checkpoint B-6: Food preview integration

目标：图片分析完成后进入现有可编辑保存页。

工程任务：

1. `AiFoodDraft.toFoodRecord(date)`:
   - date from Add Food selected date.
   - source = `ai_photo`.
   - estimation notes include model/provider and user note only if useful, not raw JSON.
2. Push `FoodPreviewPage`.
3. `FoodPreviewPage` remains the confirmation boundary:
   - user can edit.
   - user taps save.
   - only then repository writes official food record.
4. On successful save:
   - mark `RefreshNotifier`.
   - refresh daily summary cache.
   - pop back to Food Log.

Automatic tests:

- Draft preview page gets AI photo source.
- Save writes through existing repository once.
- Cancel/back from preview does not write.
- Failed save keeps user on preview page.

Manual验收:

- 拍一张简单食物图，能进入预览。
- 预览字段可编辑。
- 保存后 Food Log 出现新记录。
- 返回不保存时 Food Log 不出现新记录。

## 6. 文档更新计划

Implementation 完成并验收后更新，不要提前写成已实现。

必须更新：

- `README.md`
  - 中文和英文都更新。
  - 标明 Add Food photo AI analysis implemented。
  - 标明图片只生成 draft，确认后保存。
- `CHANGELOG.md`
  - English only。
  - Added/Changed/Fixed/Validation。
- `docs/en/Product.md`
- `docs/zh/Product.md`
- `docs/en/AppGuide.md`
- `docs/zh/AppGuide.md`
- `docs/en/AgentDesign.md`
- `docs/zh/AgentDesign.md`
- `docs/en/Database.md`
- `docs/zh/Database.md`
  - 如果只新增 Supabase RPC/function 且不改 SQLite schema，Database docs 只更新 cloud AI tables/functions/log behavior。
  - 不 bump `AppDatabase.dbVersion`，除非真的改 SQLite schema。
- `docs/API_CONTRACT_DRAFT.md`
  - 更新 Food Photo Analysis endpoint contract。
- `docs/ROADMAP.md`
  - 把图片 AI 分析从占位/计划改成当前实现状态。

需要删除或改写的旧文案：

- 当前 chat path text-only 的稳定文档表述。
- Add Food photo analysis placeholder。
- Add Food 复制 prompt 作为主流程的表述。
- History archive support 的当前表述，若 UI 移除 archive。

仍需保留的边界：

- No RAG unless implemented.
- No automatic official record write.
- No user API key.
- No full local history upload.
- No user-data vector database.

文档-only validation:

- Required documentation tree exists.
- No root-level stable design docs.
- No replacement characters.
- No date-appended headings in stable docs.
- Search stale phrases:
  - `placeholder`
  - `text-only`
  - `image recognition not implemented`
  - `Photo AI placeholder`
  - `archive`
  - `复制 AI 食物提示词`
  - `图片识别尚未实现`

## 7. 自动验收矩阵

### Flutter formatting and static checks

Run after code changes:

```powershell
dart format lib test
flutter analyze
```

### Flutter tests

Targeted:

```powershell
flutter test test\ai_page_test.dart
flutter test test\ai_chat_controller_test.dart
flutter test test\ai_gateway_contract_test.dart
flutter test test\ai_gateway_client_test.dart
```

New/updated tests to add:

- `test/ai_page_test.dart`
  - status pill remains available while sending.
  - send button and assistant bubble show loading.
  - provider selector restores persisted Qwen.
  - history no longer shows archive.
  - delete requires confirm.
  - inline rename keeps stable layout.
  - background is visibly different across progress states.
- `test/ai_chat_controller_test.dart`
  - rename success.
  - rename failure maps stable error.
- `test/ai_gateway_contract_test.dart`
  - Food photo request/response contract.
  - Food draft schema validation.
- New `test/photo_food_analysis_page_test.dart`
  - no image -> disabled submit.
  - selected image -> enabled submit.
  - loading overlay.
  - failure preserves state.
  - success pushes preview.
- Existing food preview tests or new food photo draft tests.

Full:

```powershell
flutter test
```

### Backend tests

If Deno is available:

```powershell
deno fmt supabase/functions
deno test supabase/functions
```

If Deno is not available:

- Document blocker.
- Use deployed function acceptance checks.

### APK build

Default configured build:

```powershell
flutter build apk --debug --split-per-abi --dart-define-from-file=config/supabase.local.json
```

Optional performance build:

```powershell
flutter build apk --profile --split-per-abi --dart-define-from-file=config/supabase.local.json
```

Profile build may require device-side manual install/profiling.

## 8. 必须人工操作和验收

Only these should require human/manual validation. Everything else should be covered by automated tests or Codex-run commands.

### 8.1 Supabase SQL

If Supabase CLI cannot apply migrations from this environment, manually apply:

- chat rename RPC migration.
- any request-log/debug-summary workflow constraint update, if implementation chooses to add a new workflow enum instead of reusing `food_logging`.

验收 SQL:

- `rename_ai_chat_session` exists.
- authenticated user can rename own active session.
- authenticated user cannot rename another account's session.
- empty title is rejected.
- deleted session is rejected.

### 8.2 Supabase Edge Function deploy

If CLI deploy is not available here, manually deploy:

- `ai-food-photo-analyze`
- any shared helper changes needed by `ai-chat-route`

验收:

- no-auth request returns stable `auth_required`.
- subscribed active-device request with a small test image returns draft or clarification.
- logs/debug summaries exist and do not contain raw image/base64.

### 8.3 Provider secrets/config

Likely no new API key is required if existing Qwen config is reused:

- `FITLOG_QWEN_API_KEY`
- `FITLOG_QWEN_MODEL`
- `FITLOG_QWEN_BASE_URL`

If implementation separates text model and vision model, add:

- `FITLOG_QWEN_VISION_MODEL`

验收:

- The deployed photo function uses the expected Qwen model.
- Missing provider config returns stable provider/config error.

### 8.4 Real Android camera/gallery

必须真机验收:

- Tap Add Food -> 图片 AI 分析.
- Tap 拍照.
- First permission prompt behavior is acceptable.
- Take photo, return to app, preview displays correctly.
- Tap 从相册选择.
- Pick existing image, preview displays correctly.
- Cancel camera/gallery returns to page without losing previous valid state.
- Denied permission shows readable error.

### 8.5 Real model food-photo result

必须真机 + 真实 backend 验收:

- Use a simple food photo.
- Add optional note.
- Submit.
- Loading overlay appears and blocks duplicate submit.
- Result enters FoodPreviewPage.
- Draft values are plausible enough for a first AI estimate.
- User can edit values.
- Save writes official food record.
- Back/cancel before save writes nothing.

### 8.6 AI page animation and performance

必须真机验收:

- Empty AI page background visibly flows.
- Keyboard open does not freeze the background.
- Waiting state background still subtly moves.
- Sending spinner and assistant loading bubble animate.
- Status pill does not show `思考中`.
- Keyboard animation is not noticeably worse than comparable Profile/Food text fields.
- If still poor, capture profile build performance trace.

### 8.7 Chat history rename/delete

必须真机验收:

- Delete asks for confirmation.
- Cancel delete does nothing.
- Confirm delete removes the session.
- Archive button is gone.
- Rename changes the tile title inline.
- Inline input does not resize/reflow the history tile.
- Renamed title persists after closing/reopening history panel.

## 9. 风险和缓解

### 9.1 Qwen image payload shape risk

Provider APIs are time-sensitive. Before implementation, verify current Alibaba Cloud Model Studio OpenAI-compatible image payload shape and model support.

Mitigation:

- Keep provider adapter isolated.
- Add backend parser tests with captured fake provider responses.
- Do not hard-code console-only values in Flutter.

### 9.2 Large image payload risk

Base64 image can make request too large.

Mitigation:

- Client resize/compress.
- Server hard limit.
- Clear user-facing error.
- Future Storage upload path can be designed separately.

### 9.3 Food estimates can be wrong

AI food estimation is inherently approximate.

Mitigation:

- Show confidence/notes.
- Make preview editable.
- Require user confirmation.
- Prompt model to ask clarification when uncertain.

### 9.4 Animation fix can regress readability

Making motion visible can become distracting.

Mitigation:

- Keep two motion profiles.
- Validate on real device.
- Avoid fast motion during reading.

### 9.5 Rename RPC can open unintended writes

Direct table updates would weaken RLS boundaries.

Mitigation:

- RPC-only update.
- Auth/account check inside SQL.
- No direct update grant.

### 9.6 Dependency and permissions risk

`image_picker` may require platform config or behave differently across Android versions.

Mitigation:

- Wrap picker behind service.
- Manual Android camera/gallery permission checks.
- Keep custom camera out of first pass.

## 10. Suggested implementation order

1. Checkpoint A baseline audit.
2. Fix status pill readiness-only.
3. Persist provider choice locally.
4. Add chat rename RPC/repository/controller.
5. Replace archive with inline rename and delete confirm.
6. Diagnose and fix AI page animation/performance.
7. Run targeted AI tests.
8. Redesign Add Food entry.
9. Add image picker dependency and wrapper.
10. Build PhotoFoodAnalysisPage UI with mock analyzer.
11. Add Food Draft request/response models.
12. Add photo analysis Gateway client/repository/controller.
13. Implement `ai-food-photo-analyze` Edge Function.
14. Wire real Qwen photo provider.
15. Convert draft to `FoodRecord` and push `FoodPreviewPage`.
16. Add tests.
17. Update stable docs and changelog.
18. Run full validation.
19. Build configured debug split APK.
20. Manual Supabase deploy/SQL acceptance if needed.
21. Manual Android camera/gallery/model/animation acceptance.

## 11. Exit criteria

This work is complete only when:

- All automatic Flutter checks pass.
- Backend tests pass or Deno blocker is documented and deployed acceptance covers the path.
- Configured debug split APK builds.
- Supabase SQL/function acceptance passes.
- Real-device camera/gallery acceptance passes.
- Real-device AI page animation acceptance passes.
- Real provider photo food analysis returns a draft and does not write official records before user confirmation.
- Stable docs match implemented behavior in both English and Chinese.
- Commit message is prepared.

Suggested commit message after implementation:

```text
feat(ai): add photo food analysis and stabilize chat ux
```

