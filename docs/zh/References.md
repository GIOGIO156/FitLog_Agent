# 参考资料

## 范围

本文记录对 FitLog_Agent V1 设计有用的外部参考。它不是文献综述，也不为每一个产品选择背书。

References 用于：

- 确定性算法中的公式、范围和限制
- AI/Agent/RAG claim 的边界
- 数据库和工程选择
- 隐私与安全设计原则

References 不用于：

- UI 文案、页面名、按钮名或本地化字符串
- 内部字段名、表名、类名或文件路径
- changelog 历史
- 纯产品行为描述
- 已明确标记为本地设计决策的项目默认值

## 证据边界

- FitLog_Agent 是个人记录和估算工具，不是医疗建议。
- 营养和训练估算都是近似值。
- BMR/RMR、MET、g/kg、校准和 taper 规则都是有边界的启发式。
- g/kg 表是证据范围内的本地产品默认值，不是通用处方。
- 力量热量系数是项目启发式，不是实验室级能量模型。
- AI 输出在用户确认前只是草稿、解释或建议。
- RAG 可以改善相关上下文获取，但不能保证真理。
- 未成年人保护是安全边界，不是儿童治疗指导。

## 算法参考

| ID | Topic | Source | FitLog usage | Boundary |
| --- | --- | --- | --- | --- |
| REF-ALG-01 | BMR/RMR equation | Mifflin MD, St Jeor ST, Hill LA, Scott BJ, Daugherty SA, Koh YO. "A new predictive equation for resting energy expenditure in healthy individuals." Am J Clin Nutr. 1990. PMID: 2305711. | BMR estimate formula. | 只是估算，不是间接测热。 |
| REF-ALG-02 | BMR/RMR limitations | Frankenfield D, Roth-Yousey L, Compher C. "Comparison of predictive equations for resting metabolic rate in healthy nonobese and obese adults." J Am Diet Assoc. 2005. PMID: 15883556. | 说明个体误差仍然明显。 | 仅作限制说明。 |
| REF-ALG-03 | Macro kcal conversion | 21 CFR 101.9 Nutrition labeling, eCFR. | Protein/carbs 4 kcal/g，fat 9 kcal/g。 | 通用换算值。 |
| REF-ALG-04 | Macro percentage framing | National Academies / Institute of Medicine. Dietary Reference Intakes for Energy, Carbohydrate, Fiber, Fat, Fatty Acids, Cholesterol, Protein, and Amino Acids. | `energy_ratio` 的 percentage-of-energy 框架。 | 不验证用户输入比例。 |
| REF-ALG-05 | Protein g/kg range | Jager R, Kerksick CM, Campbell BI, et al. "International Society of Sports Nutrition Position Stand: protein and exercise." J Int Soc Sports Nutr. 2017. PMID: 28642676. | 活跃用户 protein range 背景。 | 不证明每个 FitLog 系数。 |
| REF-ALG-06 | Sports nutrition variability | Thomas DT, Erdman KA, Burke LM. "Nutrition and Athletic Performance." J Acad Nutr Diet. 2016. PMID: 26920240. | 训练和身体成分差异背景。 | 仅广义背景。 |
| REF-ALG-07 | Diet and body composition | Aragon AA, Schoenfeld BJ, Wildman R, et al. "International Society of Sports Nutrition Position Stand: diets and body composition." J Int Soc Sports Nutr. 2017. | cutting/bulking 与能量平衡背景。 | 不验证具体默认值。 |
| REF-ALG-08 | MET values | Ainsworth BE, Haskell WL, Herrmann SD, et al. "2011 Compendium of Physical Activities." Med Sci Sports Exerc. 2011. PMID: 21681120. | Cardio MET mapping。 | 近似活动映射。 |
| REF-ALG-09 | MET conversion | Adult Compendium of Physical Activities update and Compendium unit conversion notes. | MET to kcal/min formula。 | FitLog subtracts 1 MET 是本地 net-exercise 选择。 |
| REF-ALG-10 | 7700 kcal/kg history | Wishnofsky M. "Caloric equivalents of gained or lost weight." Am J Clin Nutr. 1958. PMID: 13594881. | 历史 kcal/kg 近似。 | 不是精确预测规则。 |
| REF-ALG-11 | 7700 kcal/kg limitations | Hall KD. "Why is the 3500 kcal per pound weight loss rule wrong?" Int J Obes. 2013. PMID: 23774459. | 校准限制说明。 | 支持平滑启发式，不支持精确更新。 |
| REF-ALG-12 | Under-18 safety boundary | USPSTF recommendation material on high body mass index interventions in children and adolescents. | 未成年人成人式 deficit 保护。 | 安全边界，不是治疗计划。 |
| REF-ALG-13 | Periodized carbohydrate availability | Jeukendrup AE. "Periodized Nutrition for Athletes." Sports Med. 2017. PMID: 28332115. | Carb cycling 概念背景。 | 只支持概念。 |
| REF-ALG-14 | Periodized carb restriction limitation | Gejl KD, et al. "Performance effects of periodized carbohydrate restriction in endurance-trained athletes: a systematic review and meta-analysis." Sports Med. 2021. PMID: 34001184. | 避免过度宣传 carb cycling。 | 耐力表现背景。 |
| REF-ALG-15 | Carbohydrate needs vary with training | Burke LM, Hawley JA, Wong SHS, Jeukendrup AE. "Carbohydrates for training and competition." J Sports Sci. 2011. PMID: 21660838. | Carb strategy 背景。 | 表现背景。 |
| REF-ALG-16 | Protein preservation | Jager R, et al. ISSN protein position stand. 2017. PMID: 28642676. | taper 中保持 protein 优先。 | 仅广义范围支持。 |
| REF-ALG-17 | Conservative loss-rate framing | Helms ER, Aragon AA, Fitschen PJ. "Evidence-based recommendations for natural bodybuilding contest preparation." J Int Soc Sports Nutr. 2014. PMID: 24864135. | taper target-loss 背景。 | 健美备赛人群。 |
| REF-ALG-18 | Prep macro shifts | Chappell AJ, Simper T, Barker ME. "Nutritional strategies of high level natural bodybuilders during competition preparation." J Int Soc Sports Nutr. 2018. PMID: 29371857. | 观察到 carbs/fats 常下降而 protein 保持较高。 | 观察性。 |
| REF-ALG-19 | Dynamic weight-change limitation | Hall KD. "Why is the 3500 kcal per pound weight loss rule wrong?" Int J Obes. 2013. PMID: 23774459. | 支持 rolling trend review 和用户确认。 | 不验证具体 taper step。 |
| REF-ALG-20 | Day-to-day body-mass variability | Schneditz D, Hofmann P, Krenn S, et al. "Day-to-day variability in euvolemic body mass." Ren Fail. 2023. PMID: 37955103. | 支持较长趋势窗口，避免根据一次称重反应。 | 体重波动背景，不是饮食规则。 |
| REF-ALG-21 | Practical carbohydrate day assignment | Burke LM, Cox GR, Cummings NK, Desbrow B. "Guidelines for daily carbohydrate intake: do athletes achieve them?" Sports Med. 2001. PMID: 11310548. | 支持把更多碳水分配给更高训练需求，并用 g/kg 表达摄入。 | 运动员供能背景，不验证 FitLog multipliers。 |

## Agent、RAG 与安全参考

| ID | Topic | Source | FitLog usage | Boundary |
| --- | --- | --- | --- | --- |
| REF-AI-01 | Retrieval-Augmented Generation | Lewis P, Perez E, Piktus A, et al. "Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks." 2020. | 支持回答前检索外部上下文的概念。 | 不规定 FitLog 实现，也不保证回答正确。 |
| REF-AI-02 | AI risk management | NIST Artificial Intelligence Risk Management Framework. | 可靠性、透明度和治理的通用风险框架。 | 高层框架，具体实现仍是项目决策。 |
| REF-AI-03 | LLM application security | OWASP Top 10 for LLM Applications. | prompt injection、数据暴露、tool abuse 等安全考虑。 | 实现/安全评审前需核验当前版本。 |
| REF-AI-04 | Structured model outputs and tool APIs | 所选模型供应商的官方 API 文档。 | schema validation、structured outputs、vision input 和 tool 边界实现。 | 供应商文档会变化；coding 时需核验当前文档。 |
| REF-AI-05 | Data minimization and privacy-by-design principles | 来自主要监管或标准来源的 privacy engineering / privacy-by-design 指南。 | 支持最小必要上下文和避免不必要原始历史上传。 | 实际上线地区的法律合规需要单独审查。 |
| REF-AI-06 | Document chunking patterns | LangChain text splitter documentation and Unstructured chunking documentation. | header-aware、recursive、title/element-aware document chunking 的工程参考。 | 不证明 FitLog 的最佳 chunk size 或检索质量；需要本地 retrieval tests 验证。 |
| REF-AI-07 | Contextual retrieval | Anthropic engineering note on Contextual Retrieval. | 支持在检索前为 chunks 增加文档级上下文。 | 供应商工程建议，不保证正确性；FitLog 的上下文必须保持确定性或经过审查。 |
| REF-AI-08 | OpenAI Structured Outputs | [OpenAI Structured model outputs](https://developers.openai.com/api/docs/guides/structured-outputs)。 | 支持 OpenAI Responses adapter 使用严格 provider-side JSON Schema generation。 | Structured output 不能替代 FitLog workflow、semantic、safety 和 write validation；实现时仍需核验配置模型支持。 |
| REF-AI-09 | Qwen JSON Mode | [阿里云百炼 Structured output](https://help.aliyun.com/en/model-studio/qwen-structured-output)。 | 支持 Qwen JSON Mode 要求以及下游 schema validation/retry 指南。 | JSON Mode 只提供 JSON-oriented output，不证明 FitLog schema 或业务正确；支持模型和 thinking-mode 限制需要重新核验。 |
| REF-AI-10 | Qwen text embeddings | [Alibaba Cloud Model Studio Embedding](https://www.alibabacloud.com/help/en/model-studio/embedding) 与 [Singapore synchronous Embedding API](https://www.alibabacloud.com/help/en/model-studio/text-embedding-synchronous-api)。 | 定义 Document RAG 使用的 `text-embedding-v4` compatible endpoint、dimensions 和 request batching。 | Provider compatibility 不决定 FitLog chunking、ranking、evidence quality 或 privacy boundary；这些仍是经过本地测试的设计决策。 |

FitLog-specific AI 产品边界：

- AI Gateway 由服务端管理。
- V1 不让用户填写模型 API key。
- 登录后 Cloud Profile 是权威版本。
- 登录用户的 body、food 和 workout 正式记录以云端为 source of truth。
- 本地 SQLite 是 partial cache、草稿和运行期加速层，不是完整历史镜像。
- V1 不做用户数据向量库和长期 semantic memory。
- AI 生成草稿和解释；正式写入由用户确认 gating。

## 数据库与工程参考

| ID | Topic | Source | FitLog usage | Boundary |
| --- | --- | --- | --- | --- |
| REF-DB-01 | SQLite local storage | SQLite official documentation/homepage. | 本地嵌入式结构化存储。 | 不验证每个 schema 决策。 |
| REF-DB-02 | Flutter SQLite persistence | Flutter docs "Persist data with SQLite"; `sqflite` package documentation. | Package 和平台持久化选择。 | Schema 仍是项目特定。 |
| REF-DB-03 | SharedPreferences | Flutter `shared_preferences` package documentation. | 简单语言偏好存储。 | 不用于关系记录。 |
| REF-DB-04 | Repository pattern | Martin Fowler, Repository pattern. | Repository/service 分离。 | 仅模式参考。 |

## 不应过度引用的内部决策

- 产品页描述和普通 UX 行为。
- AI 页面视觉风格、背景动效和导航位置。
- 页面名、label、本地化字符串和文件路径。
- 字段名、enum 名、class 名和表名。
- Changelog 和验证声明。
- SQLite migration statement 本身。
- `diet_goal_phase`、`diet_calculation_mode` 和 `diet_plan_strategy` 命名。
- `prefer_not_to_say` 平均值。
- Training-frequency self-check threshold 和 cooldown。
- 力量热量系数。
- `DailySummary` 是 runtime-only。
- V1 订阅制 UI 不显示用户可见额度。

## 写作规则

- 保持 reference IDs 稳定。
- 只引用来源能支持的窄 claim。
- 把启发式或产品特定选择标记为本地设计决策。
- 不把本文当 changelog。
- 实现快速变化的 AI、安全、支付或法律要求前，重新核验相关 primary/official sources。
