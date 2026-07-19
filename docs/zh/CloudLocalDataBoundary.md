# 云端与本地数据边界设计

## 文件职责

本文是 FitLog_Agent 云端数据、本地 SQLite、本地 cache、UI read model、写入、读取、后台刷新、异常、冲突和修复规则的唯一设计来源。

`Database.md` 负责 schema、migration、表和字段。`AgentDesign.md` 负责 AI 如何使用数据。`Product.md` 和 `AppGuide.md` 负责用户体验层摘要。其他文件需要云端/本地规则时，应摘要引用本文，不应复制完整策略。

## 适用范围

这些规则适用于所有登录态 Agent 构建，覆盖 root auth gate、active-device claim/assert、body/food/workout cloud-first 写入、账号绑定 confirmed-cache metadata、cloud-backed repositories、非阻塞启动恢复、首屏账号绑定、选中日期 summary cache、stale-while-revalidate 重建、云端 `daily_summaries`、有界 warm cache、cache eviction 和导出完整性。

登录前的兼容行为仍以本地为主。离线正式写入队列、完整双向同步、旧设备历史自动迁移和复杂跨设备 merge UI 不在本文边界内。更丰富的 repair presentation 可以演进，但必须继续遵守下述状态、权威和失败规则。

## 核心原则

- 登录后的正式身体、饮食和训练数据以云端 records 为权威。
- 本地 SQLite 是 partial cache、草稿、运行期加速层和已确认 UI read model。
- 本地 cache 不是完整云端镜像，AI、导出、修复和跨设备正确性不能依赖本地 cache 完整性。
- 只要存在账号绑定的已确认 cache，且已知道当前登录 auth 账号，页面应先用本地数据打开，不等待 active-device 恢复或云端刷新。
- 本地 cache 淘汰不能导致用户正式数据丢失。
- AI 可以生成草稿、解释和复盘，但正式数据修改仍必须用户确认并云端写入成功。

## 账号运行期状态机

| 状态 | 进入条件 | UI 行为 | 云端行为 |
| --- | --- | --- | --- |
| `signed_out` | 无有效 session、用户退出、session 被证明不可恢复 | Root auth gate，底部导航不可见 | 不读写正式 records |
| `recovering_cached` | 有登录账号和匹配账号的 confirmed cache，但 Supabase session/Cloud Profile/订阅仍在恢复 | 立即显示 cached Home/Profile/Body Trends，不显示整页 loading 或错误 | 后台恢复 session 并刷新 Cloud Profile、订阅和可见窗口 |
| `online_confirmed` | session、Cloud Profile 和可见窗口刷新成功 | 正常交互；写入仍 cloud-first | 正常读写，成功后更新本地 read model |
| `offline_readonly` | 后台刷新网络失败、超时或临时服务失败，且存在 confirmed cache | 保留已显示 cache；正式写入阻断或保留草稿；可显示轻量同步失败提示 | 停止当前轮强制刷新，按退避重试 |
| `stale_cached` | cache 超过 freshness window 或后台刷新失败但并非危机 | 保留 cache；只更新受影响局部，不重建整页 | 下次 freshness 过期、resume 或用户刷新时再校验 |
| `device_replaced` | 服务端确认当前 device/session 已被同账号新登录设备替换 | 阻断正式写入和 AI 发送，显示“账号已在另一台设备登录”，清本机 auth session 后回到 root auth gate 或提供重新登录接管 | 不再允许该 device/session 写正式 records |
| `repair_required` | metadata 冲突、账号边界错位、版本倒退或不可合并 payload 差异 | 阻断相关写入，提示修复/刷新路径 | 以云端 records 或 rebuildable projection 修复 |

状态转换规则：

- `recovering_cached` 不得先切成 `loading` 再等待云端；它必须先渲染 confirmed cache。
- 后台 refresh 的 `auth_required`、网络失败或订阅失败，只能把 `online_confirmed` 降为 `stale_cached`/`offline_readonly`，不能覆盖已有 confirmed UI。
- 只有持久化 session 被恢复流程证明不可恢复时，才从登录态回到 `signed_out`。
- 服务端返回 `device_replaced` 时，不能当作普通上传失败；必须进入 `device_replaced`，停止正式写入并清理本机登录态。
- 用户显式写入永远不因本地 cache 存在而绕过云端成功条件。

## Auth Boundary

- 登录、注册、退出和 session 恢复是账号层能力，不得依赖 Cloud Records cache、daily summary、warm cache 或订阅刷新成功。
- 未登录页不得启动正式 records 读取、records warm cache 或 daily summary warm cache。
- 后端未配置时，登录/注册按钮必须给出可读的配置缺失提示；不得表现为点击无反应。
- 用户点击登录、注册、刷新订阅或退出登录时，UI 必须进入可见的处理中、成功或失败状态；不得 silent no-op。
- 登录成功后，可以进入无 cache 的首次加载状态，也可以进入 `recovering_cached`；不得要求订阅状态、Cloud Records warm cache 或 30 天预热完成后才进入五栏。
- 持久化 session 恢复慢时，已有账号绑定 cache 的页面可先显示；无账号或 session 被证明不可恢复时必须回到 root auth gate。

## State Slice Rules

- App 运行期状态必须拆成独立 slice：auth/session、Cloud Profile、subscription、visible records/read model、daily summaries、warm cache、AI Gateway availability。
- 一个 slice 失败只能影响它负责的 UI 或能力。订阅失败只影响 AI 发送和订阅展示，不能阻断 Home/Food/Workout/Profile 的非 AI 数据页面。
- Cloud Profile 刷新失败不能抹掉已经显示的 matching Profile cache；records 刷新失败不能抹掉已经显示的 records read model。
- Warm cache 只影响下次打开和历史访问速度，不得控制页面是否可见、按钮是否可点或正式写入是否允许。
- Cloud Records ready 不能让 AI 发送按钮绕过 Gateway、active-device、provider 或服务端 entitlement 校验。
- 每个 slice 都要有自己的 freshness、loading、error、stale 和 retry 状态；不得用一个全局 loading/error 覆盖整个 tab shell。

## Single Active Device Policy

- Agent V1 采用单 active device，`last login wins`。同一账号在新设备登录成功后，新设备接管账号；旧设备不再允许正式写入或 AI 发送。
- V1 不做实时多端同步，也不依赖“另一台设备是否在线”的检测。移动端在线状态不可靠，因此设备替换以服务端记录的 active device/session 为准。
- 每个 App 安装生成一个本地 `device_id`。登录成功后，App 调用服务端 `claim_active_device`，把当前账号的 active device/session 更新为本设备。
- Supabase single-session 可以作为辅助，但不能作为唯一保护。旧 access token 在过期前可能仍短暂有效，因此正式写入路径必须额外校验 active device/session。
- 旧设备不需要被实时推送下线。它在下一次 session refresh、云端读取、正式写入、AI 发送或账号刷新时收到 `device_replaced` 后，进入设备替换状态。
- `device_replaced` 是账号安全/冲突边界，不是普通网络错误。App 应显示“账号已在另一台设备登录，请重新登录以接管”，并清本机 auth session、运行期草稿和账号绑定展示 cache。
- 设备替换不删除云端正式 records，也不删除本地可重建 cache；本地 cache 不能继续作为 active account 数据展示，除非用户重新登录并重新 claim active device。

## 订阅状态规则

- 订阅权威在云端；本地只保存最后一次已确认的展示/status cache。
- 启动时如果有匹配账号的订阅 cache，可以先显示上一份 active/inactive 状态，并在后台刷新。
- 订阅刷新成功后更新本地展示 cache。
- 订阅刷新失败但存在上一份已确认状态时，保留上一份状态并标记 stale/error reason；不能把 Profile 订阅卡或 AI 页面反复打回不可用闪烁态。
- 没有任何订阅 cache 且刷新失败时，AI 相关功能保持不可发送/待确认；非 AI 产品数据页面不被阻断。
- 真正的 AI 发送和额度扣减仍必须由服务端/Gateway 校验 entitlement；本地 active cache 只用于展示和减少打开等待。

## 数据分类

| 数据类型 | 示例 | 权威来源 | 本地角色 |
| --- | --- | --- | --- |
| 账号身份 | Supabase auth user id、邮箱 session | 云端 | auth session cache |
| Active device | `device_id`、`active_session_id`、`claimed_at` | 云端 | 本机 device id 和展示/诊断状态 |
| 订阅 | entitlement rows、额度状态 | 云端 | 展示/状态 cache |
| Cloud Profile | 昵称、目标、阶段、模式、当前身体快照 | 登录后云端 | 展示 cache 和页面草稿 |
| 身体指标记录 | 按日期记录的体重、体脂、腰围 | 云端 | 已确认 read model 和 partial cache |
| 饮食记录 | `food_records`、`food_items` | 云端 | 已确认按日 read model 和 partial cache |
| 训练记录 | sessions、sets、workout records | 云端 | 已确认按日 read model 和 partial cache |
| Daily summaries | 选中日期 totals 和紧凑上下文 | 可重建云端 projection | 已确认 summary cache |
| 本地专属 App 数据 | 主题、运行期 UI 状态、未完成 prompt、本地导出文件 | 本地 | 本地权威 |
| 草稿 | 未发送 prompt、手动/AI 新建训练草稿、未确认 AI 饮食草稿 | 确认前本地 | 只做草稿存储；已保存训练的编辑状态仅存在于当前页面 |
| AI 记录 | chat sessions、messages、final answers、request metadata | 对应阶段落地后云端/服务端 | 运行期展示 cache |

## Source of Truth 规则

- 登录后的 body、food、workout 正式记录以 Supabase Cloud Records 为 source of truth。
- 本地 SQLite 不得被当成完整历史镜像。
- 本地已确认 read model 可以用于快速渲染 UI，但不能覆盖云端正式记录。
- 云端写入成功后，用返回的 row、version 和 timestamps 更新本地已确认 cache/read model。
- 本地 cache 淘汰不是云端删除。
- 云端删除或 soft delete 必须走正式 cloud repository 路径。
- 本地 cache 必须绑定账号；账号 metadata 不匹配的 cache 不能作为另一个用户的已确认数据展示。

## 写入规则

- body、food、workout 正式记录的新增、编辑和删除都是 cloud-first。
- body、food、workout、Cloud Profile 和 AI 发送等账号绑定正式操作必须先通过 active device/session 校验；旧设备收到 `device_replaced` 时不得继续提交。
- App 可以保留可编辑草稿或 pending UI 状态，但 Supabase 成功前不能报告正式写入成功。
- 云端成功需要有效账号、RLS 通过、payload 校验通过，并返回 cloud row 或被接受的 delete marker。
- 云端成功后，更新本地已确认 read model，并更新受影响的 `daily_summaries` projection/cache。
- 云端写入失败时，保留原正式数据，并把用户草稿/编辑留在可重试的非正式状态。
- AI 不得静默修改饮食目标、应用 carb tapering、删除记录或写正式记录；必须用户确认并走正式写入路径。
- 当前没有离线正式写入队列。离线编辑只能作为草稿，直到用户在线显式保存成功。
- Workout 生命周期 autosave 与正式保存是同一份本地草稿的有序 mutation。正式保存开始后禁止新的生命周期 autosave；云端成功后，最终草稿删除会排在所有更早草稿写入之后执行，因此切到后台也不能覆盖这个 cloud-confirmed 终态。正式保存失败时不执行最终删除，并保留可重试草稿。

## 用户操作反馈规则

- 新增、编辑、删除、复制到日期、保存身体记录和保存 Profile 都必须有可见结果：`validating`、`saving`、`saved`、`error/retry` 或明确的 disabled reason。
- 用户点击正式写入按钮后，不能静默失败。失败必须保留用户输入或可恢复草稿，并显示可读错误、重试入口或重新登录路径。
- 写入进行中应禁用重复提交，或使用 idempotency / mutation key 防止重复 records。
- 删除可以先显示 pending 状态，但云端失败时必须恢复原记录或展示清晰的未删除状态；不得让本地 UI 看起来删除成功而云端仍存在。
- 前台写入遇到 `auth_required`、RLS denied、payload validation、schema mismatch 或网络失败时，必须映射到用户可理解的状态；原始后端异常只应保留在诊断边界内。
- 前台写入遇到 `device_replaced` 时，必须显示设备替换提示并退出/重新登录，不得显示成普通保存失败或允许继续重试同一旧 session。
- 后台 refresh 的错误可以低打扰提示；前台用户动作的错误必须直接反馈。

## 读取规则

- cache-first UI 展示面：
  - Home 选中日期 summary/read model。
  - Food 选中日期记录。
  - Workout 选中日期记录。
  - Body Trends 当前 7/14/21/28 天窗口。
  - 账号 metadata 匹配时的 Profile 展示 cache。
- cloud/builder-first 流程：
  - AI context。
  - 导出正确性。
  - 账号修复。
  - 跨设备恢复和校准。
  - 长窗口历史重建。
- 有已确认本地 cache 时，cache-first 页面应立即渲染，并只在过期或用户显式刷新时后台刷新。
- 没有已确认本地 cache 时，页面级 loading、空状态或登录状态是合理的。
- 过期 cache 可以继续展示并标记刷新状态；不能仅因为 refresh 开始就清空。

## App 启动规则

- 启动时不得为了首屏渲染强制拉取完整云端历史。
- 启动时不得为了 cache-backed 页面强制完整重拉最近 30 天。
- 已恢复登录态并进入五栏时，App 必须先把 Food、Workout 和 Profile repositories 绑定到 auth session 中的账号 id，再等待 active-device 运行期上下文 claim 或刷新完成。这样 Home、Food、Workout 首次渲染当前日期时可以读取匹配账号的本地 cache，不会先显示空白记录并且只有切换日期后才恢复。
- 首屏必需数据不属于 warm cache。如果没有匹配的已确认 Home cache，第一次登录后的 Home 首次渲染可以等待一个很小的首屏数据包：账号/Cloud Profile 基础状态、选中日期 Home summary/read model，以及默认可见展示面必需的数据。App 不应先渲染空 Home，再在用户注视下替换成真实 Home。
- 如果存在匹配的已确认 Home cache，应立即渲染并在后台校验云端。云端数据一致时不应可见刷新 Home；云端数据变化时，也只更新受影响数值，不做整页 loading reset。
- 如果存在匹配的本地 cache，Supabase session 恢复、订阅刷新、Cloud Profile 刷新和当前可见窗口 Cloud Records 刷新应在后台进行。
- 后台刷新期间的 `auth_required` 是 cache-backed UI 的可恢复同步/session 状态，不能把已确认 Home 或 Body Trends 内容替换成整页错误。
- 前台正式写入遇到 `auth_required` 时，应阻断该写入，并给出清晰的重试/登录路径。
- 没有登录账号或没有匹配账号 cache 时，cloud-backed 正式记录区域应显示登录 gate 或首次加载状态。

## Warm Cache 规则

Warm cache 在首个可见页面稳定渲染后执行。它服务下一次打开、切换日期、切换趋势窗口和历史浏览，但不是启动阻塞条件。

首屏渲染后的推荐预热顺序：

1. Body Trends 当前/默认身体指标窗口；body metric logs 数据轻量，优先级高。
2. Food/Workout 选中日期 detailed records，如果它们没有包含在首屏数据包里。
3. 最近 30 天 `daily_summaries`。
4. 最近 30 天 `body_metric_logs`；身体指标数据很小，可以一次覆盖 7/14/21/28 天趋势切换。
5. 最近 30 天 food/workout detailed records 分批节流补齐。

规则：

- 最近 30 天窗口是保留优先级和预热目标，不是显示 Home 前必须下载 30 天的条件。
- Warm cache 必须绑定账号；退出登录或切换账号时可取消，并且应节流，避免抢占当前交互。
- Warm cache 不得把已经渲染的页面重新打回 loading。
- 如果 warm cache 发现当前可见展示面的数据变化，只在 metadata 或 payload 不一致时更新受影响 read model。
- food/workout detailed records 比 body metric logs 和 summaries 重，应排在轻量 summaries 和身体指标之后预热。

## 后台刷新规则

- 只刷新当前可见账号、选中日期、选中月份或选中趋势窗口。
- 触发刷新：
  - cache freshness 过期；
  - 用户显式刷新；
  - 切换日期/窗口且 cache 缺失或过期；
  - 写入成功后需要重建 summary/read model；
  - app resume 后超过 freshness window；
  - 登录、退出或切换账号改变 cache 边界。
- 刷新由 `account_id`、`cached_at`、`source_updated_at`、`record_version`、选中日期/窗口和显式用户操作控制。
- metadata 和 payload 一致时，不应可见地 reset 或闪烁 UI。
- 数据变化时，只对当前可见展示面应用最小本地 read-model 更新。
- 后台刷新失败时，保留已显示的已确认 read model，并记录刷新失败状态。
- refresh loop 应节流/防抖，避免启动和 resume 反复查询未变化的可见数据。
- 账号级 Cloud Profile 和订阅刷新必须有 freshness 和失败退避。默认实现可使用约 5 分钟成功 freshness 和约 45 秒失败退避；用户显式刷新可以绕过 freshness，但仍要记录失败时间，避免自动循环。
- 后台刷新不能把 `recovering_cached` 页面重置为整页 loading。刷新结果一致时不触发可见刷新；结果变化时只更新对应字段或卡片。

## 流量与可见刷新控制

云端 source of truth 不等于持续轮询。FitLog 使用 stale-while-revalidate：先显示本地 confirmed read model，再按受控条件校验云端。

- 不允许前台 records 无限轮询。自动刷新只能由 freshness 过期、app resume、日期/窗口切换、写入成功、显式刷新或修复流程触发。
- 每次刷新必须限定账号和可见范围；默认不拉全历史，不为首屏强制拉最近 30 天详细 records。
- 读取应优先使用 date range、month range、`updated_at`、`record_version`、summary version 或轻量 metadata 判断变化，避免重复下载未变化 payload。
- Warm cache 必须低优先级、可取消、可节流；用户正在输入、保存、滚动或切换页面时，warm cache 不得抢占当前交互。
- 失败退避必须记录在对应 slice；网络失败不能形成启动、resume 或页面切换时的自动重试循环。
- 云端结果与本地 metadata/payload 一致时，不得触发可见 UI 更新、loading 闪烁或列表重建。
- 云端结果变化时，只更新变化的字段、卡片或记录行；不得把整个页面切回 loading，也不得重置滚动位置、输入焦点或未保存草稿。
- 可见同步提示应低打扰，例如小型 stale/syncing 标记；成熟状态下不应出现用户眼前反复整页刷新。

## Cache 容量与淘汰

- 默认 pin 最近 30 天 records 和 summaries。
- 30 天外详细 records 每账号最多保留 180 个用户访问过的日期 bucket。
- 本地可重建 summary/records cache 必须受限；当前实现会淘汰最近 30 天窗口外的 cloud-confirmed 本地 cache，并用云端 records/builders 恢复更早历史。
- Body calendar 和 Body Trends 复用同一 cache 策略，不需要单独扩大容量。
- 最近 30 天不是唯一允许存在的 cache。某一天离开最近窗口后，可以作为旧历史访问日 bucket 继续保留，直到旧 bucket 容量或淘汰规则要求移除。
- cache metadata 应尽量记录账号、日期/窗口、`cached_at`、source updated/version 字段、pending/confirmed 状态和 last access。
- 只允许淘汰云端已确认、可重建的本地 cache。
- 不得淘汰 pending 草稿、当前可见数据、最近 pinned window、未确认编辑或云端正式数据。
- 更早历史按日期、月份或趋势窗口按需加载，展示后可以写入 cache。

## Daily Summaries

- `daily_summaries` 是由正式 records、Cloud Profile 和确定性算法生成的持久化可重建云端 projection。
- 它可以服务 Home、历史、导出、复盘和 AI context。
- 它不是用户手写的正式记录，也不替代原始正式 records。
- Home 可以立即展示本地已确认 summary。
- AI、导出、修复和跨设备正确性应使用云端 summaries 或受控 summary/context builder。
- summary 缺失或过期时，builder 可以从云端正式 records 重建并 upsert 云端 projection。
- summary rebuild 不得静默修改正式 records。

## Daily Summary 云端策略

- 当前设计使用 app/service-side deterministic builder 重建 summary，并通过 cloud repository upsert `daily_summaries`；该 summary 策略暂不要求 DB trigger 或 Edge Function 维护 summary。
- summary builder 必须复用现有确定性算法语义，不能把 `energy_ratio` 与 `gram_per_kg` 合并，也不能从 AI 输出推断正式目标。
- 写入 food/workout/body records 成功后，change coordinator 应重建受影响日期的 summary，并更新本地 confirmed summary cache。
- 读取 Home 或导出时，如果云端 summary 缺失、过期或版本不匹配，可以从云端正式 records 重建并 upsert。
- summary 应记录足够的输入版本或更新时间信息，例如 records `updated_at`/`record_version`、Profile version、algorithm/schema version 和 `built_at`，用于判断是否 stale。
- summary rebuild 必须幂等；同一账号同一日期重复 rebuild 不应产生多条正式 summary。
- summary rebuild 失败不应删除正式 records；Home 可以继续显示上一份 confirmed summary，并标记 stale/error。

## 异常与危机判定

非危机状态：

- 已显示 confirmed cache 时，后台 refresh 返回 `auth_required`。
- Supabase session 恢复慢。
- 后台 refresh 发生临时网络失败或超时。
- 当前页面有 confirmed cache 时，云端 refresh 失败。
- Home 的可选辅助历史窗口，例如校准样本或训练频率自检失败，但选中日期 summary 仍能由本地 read model 构建。

提示但不阻断已有 confirmed UI：

- 当前可见 cache 超过 freshness window。
- 当前日期/窗口刷新失败。
- `daily_summaries` 缺失、过期或正在重建。
- 订阅刷新失败，但非 AI 产品数据仍可用。

阻断正式写入：

- 用户未登录。
- Supabase 写入失败。
- RLS 拒绝操作。
- `account_id` 与 authenticated user 不匹配。
- 云端 schema 或必需字段缺失。
- payload 校验失败。
- 返回的 cloud data 无法通过 mapper 校验。
- 云端版本冲突，需要刷新/重试。

进入修复或校准流程：

- 本地已确认 metadata 与云端 metadata 冲突。
- 云端 `record_version` 倒退或无法排序。
- 同一正式记录出现不可合并的本地/云端 payload 差异。
- summary 与正式 records 在重建后仍长期不一致。
- 某账号 cache 出现在另一个账号边界下。
- cache 更新或淘汰后出现本地孤立 child rows。
- 持久化 auth session 在后台恢复时被证明不可恢复，App 必须回到 root auth gate。

## 用户发起的本地数据清空

- Profile 的“清空本地数据”只删除当前设备 SQLite 业务表中的 rows；它不调用 cloud repository 删除路径，也不删除 Supabase Auth session、SharedPreferences、已导出文件或任何云端数据。
- 该操作同时覆盖可重建的账号绑定 confirmed cache 和没有云端副本的本地训练草稿、自定义动作、校准与复盘状态，因此它不是 cache eviction，也不能承诺所有删除内容都能恢复。
- Cloud Profile、Cloud Records、cloud `daily_summaries`、AI chat history 和云端 AI logs 保持不变。登录状态下，页面刷新可以按照正常 cloud-authoritative 读取规则重新建立本地 confirmed cache。
- 该操作还清除设备独有的 Chat/Add Food picker recovery、workout-editor resume marker、内存图片 lease、pending retry request IDs 和本地可重建 AI draft handle。Cloud `ai_chat_clarifications` 与 message history 保持不变，但任何依赖已清除像素的步骤都会显示为 `resend_required`，不能静默复活附件或已清除的本地训练草稿。
- 该操作不改变 active account，不等于退出登录、切换账号、删除账号或云端正式删除。UI 和文档必须明确提示：云端数据可能重新出现，本地独有数据会永久丢失。
- 精确 SQLite 表范围和代码引用由 [Database.md](Database.md) 维护。

## 冲突与修复

- 云端正式 records 是冲突权威。
- 本地已确认 cache 可以被云端 rebuild/refresh 结果覆盖。
- 离线正式写入和自动端云合并不属于 V1 范围。
- 版本冲突应提示 refresh/retry，而不是静默选择客户端 payload。
- 修复流程必须显式、可解释，并基于云端正式 records 或可重建 projections。
- 代码和 UI 必须区分本地 cache 删除与云端正式删除。
- 退出登录或切换账号会清空本地 auth/session 展示 cache、运行期草稿和本地 records cache，但不删除云端正式数据。

## 安全与隐私

- 只保存性能和可见 workflow 需要的最小本地 cache。
- 不保存用户自带模型 API key。
- 本地 cache 不是长期 semantic memory。
- AI request logs、chat history、RAG 输入和 debug summaries 遵循 `AgentDesign.md`。
- RLS 必须限制云端正式记录只能访问 own-row。
- 导出和账号修复以云端正式 records 或 summaries 为权威。
- 删除账号时应删除 Cloud Profile、云端正式 records、可识别 chat history 和可识别 AI request/response 数据。

## 页面规则

Root auth gate：

- 未登录或后端未配置的 Agent 构建必须先在 tab shell 之前显示登录/onboarding 屏。
- 登录成功前，底部导航不应可见或可点击。
- 后端未配置的构建可以显示 Supabase 配置提示，但不能当作有效的 Cloud Records 测试包。

Home：

- 有已确认本地选中日期 summary/read model 时立即渲染。
- 后台刷新返回 `auth_required` 时，不能把 cached Home 变成整页错误。
- 云端数据未变化时，不能闪回 loading。

Food：

- 有已确认选中日期本地记录时立即渲染。
- 登录后正式记录新增、编辑、复制和删除都走 cloud write path。
- 云端成功后更新选中日期 read model。

Workout：

- 有已确认选中日期本地 sessions/sets/records 时立即渲染。
- 登录后正式记录新增、编辑和删除都走 cloud write path。
- 只保留手动/AI 新建训练草稿；已保存记录的编辑状态仅存在于当前页面，未成功保存就关闭编辑器时直接放弃。
- 云端成功后更新训练 summary 和选中日期 read model。

Profile：

- 登录后 Cloud Profile 是权威；匹配账号的本地展示 cache 可以先渲染。
- Profile 编辑是页面本地草稿，直到用户保存完整 Cloud Profile snapshot。
- 身体资料卡提供按日期的身体记录入口；身体记录通过 Cloud Records 写入。
- Body Trends 只读，应先渲染本地已确认可见窗口，再后台刷新。
- Body Trends 必须区分 `partial_cache`、`confirmed_empty` 和 `confirmed_ready`。未确认窗口里本地缺少记录，不等于云端真的没有记录。
- 趋势窗口处于 `partial_cache` 时，应保持图表区域高度稳定，展示已有 confirmed 点位并显示轻量同步/刷新状态，或显示固定高度的“正在同步近期身体记录”状态。
- 只有云端确认当前可见窗口是 `confirmed_empty` 后，才能显示最终“暂无记录”或“记录不足”。
- 用户正在查看 Body Trends 时，如果 body-metric warm cache 完成，只更新图表区域和必要控件，不重建整个 Profile 页面，也不造成布局位移。

AI：

- AI context 不能把本地 SQLite cache 当最终权威。
- 使用 Cloud Profile、云端 `daily_summaries` 或受控 summary/context builder。
- AI 草稿写成正式记录必须用户确认，并走正常 cloud write path。

导出与修复：

- 正确性以云端正式 records、云端 summaries 或 builders 为准。
- 本地 cache 可以加速读取，但不能要求完整。

## 实现映射

以下组件负责执行本文边界：

- Supabase migration：`supabase/migrations/202606260001_phase3_cloud_records.sql`。
- 本地 SQLite schema：`lib/data/db/app_database.dart`。
- Cloud cache/read model：当前由 `FoodRepository`、`WorkoutRepository`、`ProfileRepository` 的账号绑定 v15 元数据承载；`CacheMaintenanceService` 只淘汰云端已确认、可重建的本地 cache。
- Cloud records repositories：`CloudBackedFoodRepository`、`CloudBackedWorkoutRepository`、`CloudBackedProfileRepository` 分别位于 `lib/data/repositories/food_repository.dart`、`workout_repository.dart`、`profile_repository.dart`。
- Daily summaries：`lib/domain/services/daily_summary_service.dart` 按需从 cloud-backed repositories 构建，通过 `lib/data/repositories/daily_summary_cloud_repository.dart` 读写云端 `daily_summaries` projection，并通过 `lib/data/repositories/daily_summary_cache_repository.dart` 更新本地选中日期 confirmed summary cache；Home 对选中日期使用 stale-while-revalidate。
- Warm cache 与淘汰：`lib/domain/services/warm_cache_coordinator.dart` 在五栏 shell 稳定渲染后预热最近 30 天 summaries；`lib/domain/services/cache_maintenance_service.dart` 淘汰旧的 cloud-confirmed 本地 cache，不删除云端正式 records。
- 写入/read-model 协调：当前写入成功后由 cloud-backed repository 更新本地 confirmed cache，页面通过 `RefreshNotifier` 刷新，food/workout/Profile 成功写入后会调度受影响日期 summary cache 和云端 projection 刷新。
- 导出正确性：`lib/export/export_table_builder.dart` 在生成 CSV/XLSX 前通过 cloud-backed all-record loaders 补齐 food、workout 和 body metric 正式记录，并包含 Body Metrics 表。
- Root auth gate、首屏账号绑定和 cache-backed 页面：`lib/app.dart`、`profile_page.dart`、`home_page.dart`、`food_log_page.dart`、`workout_log_page.dart`。
- 账号状态机、Cloud Profile 展示 cache、订阅展示 cache、后台恢复和刷新退避：`lib/features/account/account_controller.dart`。
- Active device claim / guard：Supabase RPC `claim_active_device`、`assert_active_device`、`release_active_device`，Flutter repository 在 `lib/data/repositories/active_device_repository.dart`，运行时状态在 `lib/domain/models/cloud_runtime_context.dart`。
- Profile gate 必须把 `offline_readonly` 和“已有 matching cache 的 refresh error”当成可展示状态，不能整页错误覆盖。
- AI 页面可以读取订阅展示 cache 做状态呈现，但真正发送能力仍受 Gateway 和服务端 entitlement 控制。

## 验证不变量

自动测试和手动验收应保持以下不变量：

- 后端未配置或网络失败时，登录/注册按钮不会 silent no-op。
- 无 cache 的首次登录不会显示空 Home 后再跳变为真实 Home。
- 有 cache 的冷启动不会等待 session/订阅/Cloud Profile/records 全部刷新才显示。
- 订阅刷新失败不阻断非 AI 数据页。
- 新增、编辑、删除 cloud write 失败时，UI 有错误和重试，且不创建正式本地记录。
- 后台 `auth_required` 不会把 cached Home、Food、Workout 或 Body Trends 替换成整页错误。
- refresh metadata 一致时不触发可见 loading、列表重建或滚动位置重置。
- 切换账号或退出登录后不显示上一账号 cache。

## 构建配置

- 真实账号、Cloud Profile 和 Cloud Records 测试必须使用已配置构建。
- 本地 release/debug APK 应使用 `--dart-define-from-file=config/supabase.local.json`，或等价的 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY` defines 构建。
- 没有这些 defines 的构建只是未配置 auth-shell 包；它不能验证 Supabase session 持久化、云端记录或云端/本地 cache 恢复。

## 运行期验收不变量

- 未登录启动时显示 root auth gate，且不显示底部导航。
- 登录/注册/退出入口不依赖 records cache、warm cache、daily summary 或订阅刷新；点击后必须有可见反馈。
- 新设备登录后会 claim active device；旧设备下一次云端交互收到 `device_replaced` 时会停止正式写入并回到登录/接管路径。
- 已配置构建应恢复有效的本地 Supabase session，除非用户主动退出、Android app data 被清除、包名/签名变化导致必须重装，或 session 本身不可恢复。
- 有 confirmed cache 的冷启动会立即渲染 Home。
- 进程被杀后冷启动会先绑定当前账号 cache，再等待 active-device 刷新，因此 Home/Food/Workout 不会先显示空白当前日并且只有切换日期后才恢复。
- 没有 cache 的第一次登录 Home 首屏会等待选中日期 summary/read model，不先渲染空 Home 再在用户注视下刷新。
- 后台刷新期间的 `auth_required` 不会把 cached Home 替换成整页错误。
- 可选校准/自检历史窗口失败时，不会把选中日期 Home summary 替换成整页错误。
- 持久化 session 不可恢复时回到 root auth gate，而不是让 tab shell 永久停在 `auth_required` 状态。
- 有匹配账号 Profile cache 时，Cloud Profile 或订阅后台刷新失败不会把 Profile 变成整页错误或持续自动重试循环。
- 订阅刷新失败但存在上一份已确认 active/inactive cache 时，Profile 订阅状态保留上一份展示并标记 stale，不闪烁为 loading/error。
- Body Trends 在云端 refresh 前先展示本地已确认记录，并且在可见窗口仍是 `partial_cache` 时不显示最终空态/记录不足态。
- Home 选中日期 stale-while-revalidate cache 可以在首屏后后台刷新，且不能造成整页 loading 或可见布局跳动；当前 warm cache 已按同一规则预热最近 30 天 summaries。
- 云端写入失败不会创建或覆盖正式本地记录。
- 前台新增、编辑、删除失败时有可读错误和重试/恢复路径，不出现点击无反应。
- 旧设备不能在 `device_replaced` 后继续新增、编辑、删除或发送 AI；该错误不能被展示成普通 upload failure。
- 云端写入成功会更新本地 read models 和受影响 summaries。
- 新建训练正式保存成功过程中切到后台不能重新创建已清理的本地草稿；新建记录保存失败则保留草稿。
- 后台刷新结果一致时，不会出现可见 loading 闪烁。
- 后台刷新受 freshness、可见窗口和失败退避限制，不出现持续轮询或用户眼前反复整页刷新。
- cache 淘汰不会删除云端正式数据。
- AI 和导出正确性不依赖本地 cache 完整性。
- 切换账号或退出登录后，不会展示其他账号的 cached records。
