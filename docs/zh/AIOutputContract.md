# AI 输出契约

## 目标

本文是 FitLog_Agent 模型输出治理的稳定 source of truth。它定义 AI provider 可以返回什么、AI Gateway 如何解析/校验/归一化输出、如何分类失败，以及哪些输出可以成为用户可审查的 artifact。

本文不定义检索输入、文档索引或上下文组装；这些内容属于 [RAGDesign.md](RAGDesign.md)。本文不定义 Flutter 与 Gateway 之间的 HTTP transport 字段；这些内容继续由 [../API_CONTRACT_DRAFT.md](../API_CONTRACT_DRAFT.md) 维护。实施顺序、发布门槛和验收清单见 [../../AI_OUTPUT_CONTRACT_ENGINEERING_PLAN.md](../../AI_OUTPUT_CONTRACT_ENGINEERING_PLAN.md)。

长期边界是：

```text
Provider 输出在 Gateway 完成解析、结构校验、领域归一化、
workflow 校验和写权限校验前，一律是不可信数据。
```

## 执行边界

同一份契约同时约束生成、Gateway 校验、持久化和客户端重建。任何一层都不能把 provider HTTP 请求成功当成业务 payload 已经有效的证明。

| Surface | 生成或输入约束 | 执行责任 |
| --- | --- | --- |
| Add Food AI 分析 | 专用 Surface 固定 Food capability，并映射到用户明确选择、支持图片的 OpenAI Structured Outputs 或 Qwen JSON Mode adapter 与 `food_analysis_envelope.v1`。 | 解析单个 object，应用共享事实优先级、目标语言、结构和语义 Food 校验，归一化 items totals，并最多允许一次受限纠错。 |
| AI Chat，Qwen 文字与图片 | 文字和图片 turn 使用同一个已配置的 Qwen 多模态生成模型，并统一采用非思考 JSON Mode 与 `provider_gateway_envelope.v2`。 | 解析严格 envelope；高置信度类型由 Gateway 固定，其余由模型在 envelope 内选择 `output_type`，且期待 draft 时不得降级为 prose success。 |
| AI Chat，OpenAI 文字与图片 | 文字和图片 turn 使用同一个已配置的 OpenAI 多模态生成模型，通过 Responses API Structured Outputs 与严格 canonical JSON Schema 生成结果；图片 turn 只增加 `input_image` part，不选择第二个模型 ID。 | 在共享校验前区分 completed、refusal 与 incomplete；发送图片时，配置模型还必须支持对应 Responses API image input。 |
| Gateway 共享校验 | 版本化共享模块维护 Chat、Food Draft、Workout Draft 与 clarification 的 provider-compatible schema 和确定性领域校验。 | 拒绝未知字段和类型转换，校验 bounds/真实日期，保留高优先级 Food 事实，校验语言/语义/grounding 一致性，把 Workout exercise 绑定到批准的 definition，并检查 workflow 与写入 policy。 |
| 持久化边界 | 只有通过校验的用户可见消息、兼容 artifact snapshot、evidence snapshot 和紧凑 metadata 可以进入存储。 | 永不持久化失败 raw provider output、correction prompt、chain-of-thought、provider secret 或 image/base64 payload。 |
| Flutter response models | 解析 typed Food Draft、Workout Draft 和新增 output error codes。 | 拒绝无法安全重建 editor 的 snapshot；只在历史兼容边界读取无版本旧 Food Draft。 |
| Provider 输出纠错 | 可纠正的结构失败可在原始总 deadline 内执行零次或一次纠错。 | 失败原文只存在于请求内存；语法纠错不重传图片，也不把 refusal、incomplete、safety、认证、entitlement 或 device 失败当成纠错候选。 |

结构化 provider 路径只接受一个可直接解析的 JSON object。Markdown fence、object 外 prose、多个 object、截断 JSON、宽松数字转换和广义 JSON Repair 都会被拒绝。

## 契约不变量

以下规则适用于所有 provider 和模型：

1. Provider 输出是数据，不是可信应用状态。
2. 明确产品工作流在调用 provider 前固定 output family；普通 AI Chat 只在高置信度时确定性指定，否则由模型在受限集合中选择 `output_type`。
3. OpenAI 和 Qwen 必须映射到同一个 provider-independent Chat envelope。
4. Draft 永远不是正式记录。
5. 只有结构有效、领域有效且 policy 允许的 draft 才能显示保存/审查入口。
6. Workflow 决定授权上下文和写权限，output type 决定结果形态；只读上下文可以辅助生成草稿，但草稿仍不是正式写入。
7. 预期生成 draft 的请求不能因为 draft 缺失或非法而静默成功为普通 prose。
8. FitLog 确定性算法和权威数据优先于模型声称的结果。
9. Request/debug logs 不保存 raw provider output、chain-of-thought、provider secret、auth token、原图或 base64 payload。
10. 每次 contract 变化都必须版本化，并在发布前由 fixtures 覆盖。
11. 每个 Provider 只暴露一个服务端配置的多模态生成模型 ID，统一用于 AI Chat 文字、AI Chat 图片和专用 Food 图片分析。Document RAG Embedding 是独立任务，使用自己的 model 与 endpoint；当前 Qwen 生成和 embedding 复用同一服务端管理的 Qwen credential。
12. Adapter 支持不等于当前发布可用。当前发布配置 Qwen，并保留 OpenAI adapter 和确定性 tests；未配置 ChatGPT selection 在 Flutter transport 前被拒绝，保留输入、显示短暂 unavailable error，并自动恢复 Qwen UI 选中态。恢复选择不触发 transport，因而不构成 provider fallback。

## 意图解析与输出类别

明确产品工作流与普通 AI Chat 使用不同的输出选择方式。Add Food 图片分析等明确入口不再判断用户意图：入口本身固定 `food_draft`，成功终态必须产生可编辑 Food Draft；信息不足时可以返回 clarification，但不能把普通 prose 当作成功结果。

普通 AI Chat 使用两层选择：

1. Gateway 的确定性 resolver 只接受高置信度信号。对于 Workout 意图：明确同时要求记录和提问时进入 clarification；明确记录请求固定 Workout Draft family；直接询问 FitLog 规则时固定 `text`；紧凑的同会话延续必须同时存在真实保留的 Workout Draft artifact 和编辑/继续操作。既有确定性 Food 意图选择保持不变。命中后直接固定 expected output。
2. Resolver 无法确定时返回 `auto`，而不是默认 `text`。Provider 必须结合自然语言、当前图片和已授权同会话上下文，在 `text`、`food_draft`、`workout_draft`、`clarification` 中选择一个 `output_type`。

这不是两次投票：第一层命中即使用其结果；只有第一层主动放弃时才由第二层选择。Flutter 不能提交或覆盖 `expected_output`。

| Expected output | 合法 provider 结果 |
| --- | --- |
| `auto` | 模型选择一个 contract-consistent `output_type`。 |
| `text` | `output_type = text`、用户可见 `message.text`、`draft = null`，且不得声称已创建草稿或正式记录。 |
| `food_draft` | `output_type = food_draft` 和 `food_draft.v2`，或一次有界 clarification。 |
| `workout_draft` | `output_type = workout_draft` 和 `workout_draft.v3`，或一次有界 clarification。 |

Clarification 使用 `output_type = clarification`、`needs_clarification = true`、questions 非空、`draft = null`。Safety blocked 在 provider call 前由 Gateway 确定性生成。Workflow routing 与 output selection 相互独立：前者决定上下文、RAG 与权限，后者决定结果形态；validation 证明最终 payload 同时满足两者。

## Provider-Independent Chat Envelope

Provider-facing Chat shape：

```json
{
  "schema_version": "provider_gateway_envelope.v2",
  "output_type": "text",
  "message": {
    "text": "用户可见 Markdown 可以放在这个字符串中。"
  },
  "needs_clarification": false,
  "clarification_questions": [],
  "draft": null
}
```

规则：

- 所有字段都显式存在；provider 不能在 object 前后添加 prose。
- `message.text` 放解释、不确定性、估算依据和审查提示。
- `output_type` 必须与 `draft`、clarification 状态和用户可见文字一致。
- `draft` 只能是一个 Food Draft、一个 Workout Draft 或 `null`。
- Clarification response 必须有 `draft = null`、不超过 320 个字符的用户可见 `message.text`，以及一到两个简短问题。它只说明缺失或冲突事实，不能追加普通回答、草稿总结或第二项任务。
- 非 clarification response 的 questions array 必须为空。
- 普通 Markdown 回答仍然允许，因为 Markdown 被装在 `message.text` 字符串中。
- Raw draft JSON 永远不作为 assistant Markdown 渲染。
- `text` 结果不得用“已生成草稿”等措辞制造没有 artifact 的假成功。

专用 Add Food endpoint 可以保留更窄的公开 response envelope，但必须与 AI Chat 共用同一个 canonical `food_draft.v2` 定义和同一条校验/归一化 pipeline。

草稿日期解析与 output family 选择彼此独立。Provider 生成前，Gateway 以本次请求日期为基准解析用户明确给出的绝对日期或受支持的相对日期；没有日期表达时沿用请求的 selected date；无法确定或不支持的日期表达必须进入 clarification，不能猜测。Provider 必须把解析后的日期写入 draft，确定性校验会拒绝不同日期或不存在的日历日期。校验通过后，Gateway 再从合法 draft date 生成用户可见的草稿确认文案，使 `message.text`、artifact card 和编辑页不会互相矛盾。

## Food Draft 契约

Canonical Food Draft 必须包含：

- `schema_version = food_draft.v2`
- `date` 为必填、真实存在的 `YYYY-MM-DD` 日历日期
- 非空 `meal_name`
- 有限、非负 `total_weight_g`
- 有限、非负 `calories_kcal`
- 有限、非负 `protein_g`
- 有限、非负 `carbs_g`
- 有限、非负 `fat_g`
- `confidence` 为 `null` 或 0 到 1 的有限数值
- 有长度上限的 `estimation_notes`
- 有数量上限的 `items` array

每个 Food Draft item 必须包含：

- 非空 `name`
- 整份估算食物的有限、非负重量、kcal、蛋白质、碳水和脂肪 totals

Item 营养值表示该 item 整份估算结果，不是每 100 g 数值。当 `items` 非空时，Gateway 必须确定性地按 item sum 重新计算 meal-level 重量和宏量营养 totals。这是领域归一化，不是模型自我纠错。

Food understanding 使用有界 typed fact ledger。来源优先级固定为用户明确事实、包装/OCR 事实、图片观察、模型假设、模型估算；低优先级来源只能补缺，不能覆盖已解析的高优先级事实。进入 Preview 前，semantic validation 检查用户可见文字的目标语言、明确事实绑定、日期与 totals、notes/数值一致性，以及带版本化容差的营养/热量合理性；标签、纤维、糖醇、酒精和四舍五入可作为解释。语义失败可以使用同一个单次 correction budget，第二次仍失败不得进入 Preview。

Food Draft 始终可编辑。Confidence 和 notes 用于表达不确定性，但不能绕过必填字段和用户确认。

## Workout Draft 契约

Canonical Workout Draft 必须包含：

- `schema_version = workout_draft.v3`
- 非空 `record_name`
- `date` 为必填、真实存在的 `YYYY-MM-DD` 日历日期
- 有长度上限的 `notes`
- 至少一个 exercise

每个 exercise 必须包含：

- 非空 `exercise_name`
- 必填且经过批准的 `exercise_key`、`exercise_source` 和 `definition_hash`
- `exercise_type` 为 `strength` 或 `cardio`
- 从 approved definition context 精确复制的 `body_part`、`load_input_mode`、`reps_input_mode` 和 `set_metric_type`
- 出现时必须有限且非负的时长
- 有数量上限的 sets array

Set 的重量、次数和时长可以为 `null`。出现的值必须符合预期数值类型和范围；不能把字符串静默转换成数字。Best-effort draft 可以把未知数值保留为 `null`，并在 notes 中记录不确定性。

Gateway 拒绝不在本次 approved definition registry 中的内置/自定义 key，也拒绝 hash 或 mode 不匹配。Flutter 按 stable key 重新绑定 v3；未解析 v3 entry 不能生成 ad-hoc total-load/total-reps 动作。历史 v1/v2 artifact 继续通过兼容路径读取。

Workout clarification 最多一轮。之后 provider 必须返回可编辑的 best-effort draft 或稳定失败，不能进入开放式追问循环。

## 校验 Pipeline

校验按以下顺序进行：

1. **Transport validation**：request/response media type、大小限制、认证、entitlement 和 active-device。
2. **Provider completion validation**：HTTP status、provider refusal、incomplete/truncated completion 和预期 content 位置。
3. **JSON syntax validation**：结构化路径必须得到一个完整 JSON object。
4. **Structural schema validation**：required fields、精确类型、enum、nullable、array/string limits 和 unknown fields。
5. **Output consistency validation**：`output_type`、draft family、clarification 和 `message.text` 必须相互一致，并满足固定或模型选择的 expected output。
6. **Workflow validation**：实际 payload 必须满足 routed workflow 的授权上下文和安全边界；workflow 名称本身不替代 output selection。
7. **Domain validation and normalization**：应用 Food item totals 重算、真实日期检查等 FitLog 不变量。
8. **Grounding validation**：把 FitLog claim 与批准的 evidence registry 对齐；经过审查的中英文 alias 与内部 enum 使用同一 canonical concept normalization 比较，既接受等价表述，也不会把相邻但不同的 concept 当作证据。
9. **Safety/write validation**：移除或拒绝不支持的正式写入声明；可审查草稿不能被表述为已保存记录。
10. **Client compatibility validation**：Flutter 拒绝无法安全重建的 response；历史 artifact 仍按版本化兼容边界读取。

Structural validation 不得使用从非法字符串中解析数值前缀的宽松转换。严格 provider schema 默认拒绝 unknown fields，除非版本化兼容规则明确允许。

Provider-facing JSON Schema 刻意只使用保守的 Structured Outputs core：`type`、`properties`、`required`、`additionalProperties`、`enum` 与 `anyOf`。FitLog 的 bounds、非负范围、真实日期和 collection size 仍由确定性 Gateway validator 强制执行，即使这些规则没有表达为 provider-generation keyword。

## Provider 映射

### OpenAI

OpenAI Chat 使用 Responses API 的结构化 `text.format` JSON Schema，并启用 strict adherence。Provider schema 只保留当前选择的 output family，不会在每个 turn 暴露全部 artifact families。配置的模型必须支持该 API 能力；不支持的 provider/model 配置会明确失败，不会回退到非结构化文字。

Provider refusal 和 incomplete response 是协议结果，不是 schema-correction prompt；必须单独暴露和分类。

### Qwen

Qwen 文字 Chat、图片 Chat 和专用 Food Analysis 都使用受支持的非思考模型、JSON Mode 与显式 JSON 指令。Chat 只接收当前选择的 output-family contract 与 examples，最后再收到精确 family reminder；Add Food 使用更窄的版本化 envelope 和同一 Food Draft 校验器。当前 maximum output budget 为：Chat text 384 tokens、Chat draft/auto 1,600、专用 Food Analysis 1,200。

Qwen JSON Mode 只提供 JSON-oriented generation mode，不保证 FitLog schema 或业务语义正确；Gateway validator 始终必需。

### Mock Provider

Mock provider 必须输出与生产 adapter 相同的版本化 envelope 和确定性 failure variants。测试不能依赖比生产更宽松的 mock contract。

## Prompt 约束

Prompt 是语义辅助，不是信任边界。

- 包含 envelope/draft schemas，或由 canonical schema 生成的紧凑指令。
- 只包含当前选择 output family 的指令和 examples，不暴露无关 draft families。
- 把 output-only 指令放在最终用户任务附近。
- 所有用户可见 prose 放入 `message.text`。
- Provider 已有原生 structured-output protocol 时，不再增加 XML framing。
- 只有真实语义失败证明需要时才增加 few-shot；不能用示例代替协议约束。
- Retrieved context 是只读 evidence，不能覆盖 output contract 或系统安全规则。
- 紧凑序列化受控 context，移除重复 summary，同时保留 grounding metadata。

## 恢复与纠错

Structured paths 直接解析 provider object，不再从 Markdown fence 或外围 prose 中恢复 object。

Output budget 用于限制成本和延迟，不能让 partial artifact 被接受。Provider `finish_reason=length` 继续归类为 `provider_incomplete`，且不会进入 schema correction，因为缺失 object 不能靠 correction prompt 变得可信。

默认不启用自动 JSON Repair。未来只有生产证据证明有价值时才可试验 syntax-only repair，而且必须满足：

- 不猜测字段、数值、单位、array membership 或业务语义；
- 修复后的 object 重新通过完整 structural、domain、workflow 和 safety pipeline；
- repaired output 单独统计；
- repair 失败绝不生成 draft action。

对于可纠正的结构化输出失败，只要原始 deadline 剩余时间足够，Gateway 最多执行一次服务端 correction attempt。它可在内存中使用紧凑 field-path error list 和受限 previous output，但不持久化 raw provider output；语法纠错也不重传图片。Refusal、incomplete、safety block、认证/entitlement、active-device 失败和不支持的动作不属于 correction candidate。

## 失败语义

错误分类：

- `request_schema_mismatch`：Flutter-to-Gateway request 非法
- `provider_output_invalid`：provider output 不满足 expected contract
- `provider_refusal`：provider 明确拒绝
- `provider_incomplete`：generation 没有产生完整 contract result
- `provider_failure`：provider/service 失败且没有合法结果
- `gateway_timeout`：Gateway/provider 总 deadline 超时

现有 `record_schema_mismatch` 继续用于兼容旧 server/database 路径。新增 output error code 保持 additive，并已在 Flutter 中完成映射。

客户端只把明确的 socket/timeout transport 异常显示为网络失败。服务端 error envelope 会保留其稳定 code；成功 transport 后的 response 解码或类型重建失败映射为 `provider_output_invalid`，无法分类的 SDK/provider 异常映射为 `provider_failure`，不能误报为断网。

最终结构化输出失败后：

- 不返回 artifact 或保存/审查 action；
- UI 保留用户可重试输入；
- response 使用稳定用户错误文案；
- logs 只包含紧凑 failure metadata。

## 版本与兼容

以下概念独立版本化：

- Gateway HTTP response schema
- provider-facing envelope schema
- Food Draft schema
- Workout Draft schema
- prompt version
- 行为变化时的 validator version

Provider alias 或模型升级不能静默改变 accepted contract。Schema 变化应尽量 additive、包含 fixture coverage，并保持历史 artifact 可读。新客户端请求 v2 draft；混合部署期间，Gateway 可以把通过校验的 v2 response 降级给 v1 client，Flutter 也可以使用 artifact 中保存的 target/selected date 重建 v1 history。新持久化 artifact snapshot 使用 `ai_chat_artifacts.v2`，并在 canonical v2 draft 旁保存 `target_date`。无法安全重建的旧 history artifact 继续显示为 disabled summary。

## 日志与评测

紧凑日志可以包含：

- provider 和配置模型
- workflow、expected output、意图解析来源和最终 `output_type`
- prompt/schema/validator versions
- first-pass validation result
- correction attempt count
- final validation result
- refusal/incomplete/failure category
- 不含用户内容的 validation issue codes
- latency 和 token estimate
- 是否返回 draft 或 clarification

不得包含 raw provider responses、chain-of-thought、provider keys、auth tokens、原图、base64 payload、完整记录历史或不受限的用户 notes。

必测维度：

- OpenAI 和 Qwen
- 文字和图片路径
- 中文和英文
- resolver 命中与主动放弃、模型选择、普通回答、clarification、Food Draft、Workout Draft、假成功声明、refusal、truncation、malformed JSON、错类型、缺字段、额外字段、不支持的写入声明
- first-pass success、correction recovery、final success、invalid-artifact escape count、latency 和 cost

没有版本化项目评测集以及实际 provider/model/schema 数据前，FitLog 不得声称通用错误率低于 0.1%。

## 用户确认边界

模型成功输出仍然只创建可编辑 proposal：

- Food Draft 只有经过相应 review action 后才打开 Food Preview。
- Workout Draft 只有 review 后才重建训练编辑器；已有草稿时还需要 replacement confirmation。
- 正式记录只由正常 confirmed save path 写入。
- AI 不能静默修改 Profile、目标、`diet_goal_phase`、`diet_calculation_mode`、`carb_cycling` 或 `carb_tapering`。

## 非目标

- 把 Prompt 文案当成唯一 output constraint
- 开放式 self-correction 或 autonomous Agent loop
- 让 JSON Repair 猜测业务语义
- 为当前小型 draft schema 引入 streaming JSON parser
- 在 protocol、validation、correction 和 evaluation 证据不足前做 SFT
- 当前 hosted-provider V1 引入私有模型 grammar/logit masking
- 在 UI 暴露 raw provider JSON 或内部校验 trace

## 相关文档

- [AgentDesign.md](AgentDesign.md)：Agent 权限、workflow、确认、隐私和产品边界
- [RAGDesign.md](RAGDesign.md)：上下文输入、检索、文档 ingestion、evidence 和 RAG 安全
- [Algorithm.md](Algorithm.md)：确定性计算和 workflow 语义
- [Database.md](Database.md)：Chat、log、debug 和 document index 持久化结构
- [../API_CONTRACT_DRAFT.md](../API_CONTRACT_DRAFT.md)：Flutter-to-Gateway transport contract
- [References.md](References.md)：外部证据边界
- [../../AI_OUTPUT_CONTRACT_ENGINEERING_PLAN.md](../../AI_OUTPUT_CONTRACT_ENGINEERING_PLAN.md)：分阶段实施和发布计划

## 代码引用

- Chat Gateway：`supabase/functions/ai-chat-route/index.ts`
- Canonical schemas/validators：`supabase/functions/_shared/ai_output_contract.ts`
- Chat request/response contracts：`supabase/functions/ai-chat-route/contracts.ts`
- Expected-output resolver：`supabase/functions/ai-chat-route/expected_output.ts`
- OpenAI adapter：`supabase/functions/ai-chat-route/openai_provider.ts`
- Qwen adapter：`supabase/functions/ai-chat-route/qwen_provider.ts`
- 专用 Food Analysis：`supabase/functions/ai-food-photo-analyze/index.ts`、`supabase/functions/ai-food-photo-analyze/contracts.ts`
- Flutter Gateway response：`lib/domain/models/ai_gateway_response.dart`
- Flutter Food Draft：`lib/domain/models/ai_food_photo_analysis.dart`
- Flutter Workout Draft：`lib/domain/models/ai_workout_draft.dart`
- Contract tests：`supabase/functions/_shared/ai_output_contract_test.ts`、`supabase/functions/ai-chat-route/index_test.ts`、`supabase/functions/ai-food-photo-analyze/index_test.ts`、`test/ai_gateway_contract_test.dart`
