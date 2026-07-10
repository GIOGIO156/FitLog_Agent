# References

## Scope

This file records external references that are useful for FitLog_Agent V1 design. It is not a literature review and does not justify every product choice.

References are used for:

- formulas, ranges, and limitations used by deterministic algorithms
- boundaries around AI/Agent/RAG claims
- database and engineering choices
- privacy and safety design principles

References are not needed for:

- UI copy, page names, button names, or localization strings
- internal field names, table names, class names, or file paths
- changelog history
- product-only behavior descriptions
- project-specific defaults that are explicitly marked as local design decisions

## Evidence Boundaries

- FitLog_Agent is a personal logging and estimation tool, not medical advice.
- Nutrition and exercise estimates are approximate.
- BMR/RMR, MET, g/kg, calibration, and taper rules are bounded heuristics.
- g/kg tables are local product defaults within evidence-informed ranges, not universal prescriptions.
- Strength calorie coefficients are project heuristics, not lab-grade energy models.
- AI outputs are drafts, explanations, or suggestions until user confirmation.
- RAG improves access to relevant context; it does not guarantee truth.
- Under-18 protection is a safety boundary, not pediatric treatment guidance.

## Algorithm References

| ID | Topic | Source | FitLog usage | Boundary |
| --- | --- | --- | --- | --- |
| REF-ALG-01 | BMR/RMR equation | Mifflin MD, St Jeor ST, Hill LA, Scott BJ, Daugherty SA, Koh YO. "A new predictive equation for resting energy expenditure in healthy individuals." Am J Clin Nutr. 1990. PMID: 2305711. | BMR estimate formula. | Estimate only; not indirect calorimetry. |
| REF-ALG-02 | BMR/RMR limitations | Frankenfield D, Roth-Yousey L, Compher C. "Comparison of predictive equations for resting metabolic rate in healthy nonobese and obese adults." J Am Diet Assoc. 2005. PMID: 15883556. | Notes that individual error remains meaningful. | Limitation context only. |
| REF-ALG-03 | Macro kcal conversion | 21 CFR 101.9 Nutrition labeling, eCFR. | Protein/carbs 4 kcal/g, fat 9 kcal/g. | General conversion values. |
| REF-ALG-04 | Macro percentage framing | National Academies / Institute of Medicine. Dietary Reference Intakes for Energy, Carbohydrate, Fiber, Fat, Fatty Acids, Cholesterol, Protein, and Amino Acids. | `energy_ratio` percentage-of-energy framing. | Does not validate user-entered ratios. |
| REF-ALG-05 | Protein g/kg range | Jager R, Kerksick CM, Campbell BI, et al. "International Society of Sports Nutrition Position Stand: protein and exercise." J Int Soc Sports Nutr. 2017. PMID: 28642676. | Broad protein range context for active users. | Does not prove every FitLog coefficient. |
| REF-ALG-06 | Sports nutrition variability | Thomas DT, Erdman KA, Burke LM. "Nutrition and Athletic Performance." J Acad Nutr Diet. 2016. PMID: 26920240. | Training/body-composition variability context. | Broad context only. |
| REF-ALG-07 | Diet and body composition | Aragon AA, Schoenfeld BJ, Wildman R, et al. "International Society of Sports Nutrition Position Stand: diets and body composition." J Int Soc Sports Nutr. 2017. | Cutting/bulking and energy-balance framing. | Does not validate exact defaults. |
| REF-ALG-08 | MET values | Ainsworth BE, Haskell WL, Herrmann SD, et al. "2011 Compendium of Physical Activities." Med Sci Sports Exerc. 2011. PMID: 21681120. | Cardio MET mapping. | Approximate activity mapping. |
| REF-ALG-09 | MET conversion | Adult Compendium of Physical Activities update and Compendium unit conversion notes. | MET to kcal/min formula. | FitLog subtracts 1 MET as a local net-exercise choice. |
| REF-ALG-10 | 7700 kcal/kg history | Wishnofsky M. "Caloric equivalents of gained or lost weight." Am J Clin Nutr. 1958. PMID: 13594881. | Historical kcal/kg approximation. | Not an exact prediction rule. |
| REF-ALG-11 | 7700 kcal/kg limitations | Hall KD. "Why is the 3500 kcal per pound weight loss rule wrong?" Int J Obes. 2013. PMID: 23774459. | Calibration limitation framing. | Supports smoothed heuristic, not exact updates. |
| REF-ALG-12 | Under-18 safety boundary | USPSTF recommendation material on high body mass index interventions in children and adolescents. | Adult-style deficit protection for minors. | Safety boundary, not treatment plan. |
| REF-ALG-13 | Periodized carbohydrate availability | Jeukendrup AE. "Periodized Nutrition for Athletes." Sports Med. 2017. PMID: 28332115. | Carb cycling concept framing. | Concept support only. |
| REF-ALG-14 | Periodized carb restriction limitation | Gejl KD, et al. "Performance effects of periodized carbohydrate restriction in endurance-trained athletes: a systematic review and meta-analysis." Sports Med. 2021. PMID: 34001184. | Avoids overselling carb cycling. | Endurance-performance context. |
| REF-ALG-15 | Carbohydrate needs vary with training | Burke LM, Hawley JA, Wong SHS, Jeukendrup AE. "Carbohydrates for training and competition." J Sports Sci. 2011. PMID: 21660838. | Carb strategy context. | Performance context only. |
| REF-ALG-16 | Protein preservation | Jager R, et al. ISSN protein position stand. 2017. PMID: 28642676. | Keeps protein higher priority during taper. | Broad range support only. |
| REF-ALG-17 | Conservative loss-rate framing | Helms ER, Aragon AA, Fitschen PJ. "Evidence-based recommendations for natural bodybuilding contest preparation." J Int Soc Sports Nutr. 2014. PMID: 24864135. | Taper target-loss context. | Contest-prep population. |
| REF-ALG-18 | Prep macro shifts | Chappell AJ, Simper T, Barker ME. "Nutritional strategies of high level natural bodybuilders during competition preparation." J Int Soc Sports Nutr. 2018. PMID: 29371857. | Observation that carbs/fats often trend down while protein stays high. | Observational only. |
| REF-ALG-19 | Dynamic weight-change limitation | Hall KD. "Why is the 3500 kcal per pound weight loss rule wrong?" Int J Obes. 2013. PMID: 23774459. | Supports rolling trend review and user confirmation. | Does not validate exact taper step. |
| REF-ALG-20 | Day-to-day body-mass variability | Schneditz D, Hofmann P, Krenn S, et al. "Day-to-day variability in euvolemic body mass." Ren Fail. 2023. PMID: 37955103. | Supports longer trend windows instead of reacting to one weigh-in. | Variability context, not a diet-planning rule. |
| REF-ALG-21 | Practical carbohydrate day assignment | Burke LM, Cox GR, Cummings NK, Desbrow B. "Guidelines for daily carbohydrate intake: do athletes achieve them?" Sports Med. 2001. PMID: 11310548. | Supports assigning more carbohydrate to higher training demand and expressing intake in g/kg terms. | Athlete fueling context, not validation of FitLog multipliers. |

## Agent, RAG, And Safety References

| ID | Topic | Source | FitLog usage | Boundary |
| --- | --- | --- | --- | --- |
| REF-AI-01 | Retrieval-Augmented Generation | Lewis P, Perez E, Piktus A, et al. "Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks." 2020. | Conceptual support for retrieving external context before answering. | Does not prescribe FitLog's implementation or guarantee answer correctness. |
| REF-AI-02 | AI risk management | NIST Artificial Intelligence Risk Management Framework. | General risk framing for reliability, transparency, and governance. | High-level framework; implementation remains project-specific. |
| REF-AI-03 | LLM application security | OWASP Top 10 for LLM Applications. | Security consideration for prompt injection, data exposure, and tool abuse. | Verify the current version before implementation/security review. |
| REF-AI-04 | Structured model outputs and tool APIs | The selected model provider's official API documentation. | Schema validation, structured outputs, vision input, and tool boundary implementation. | Provider docs change; verify current docs during coding. |
| REF-AI-05 | Data minimization and privacy-by-design principles | Privacy engineering and privacy-by-design guidance from primary regulatory or standards sources. | Supports sending minimal necessary context and avoiding unnecessary raw-history upload. | Legal compliance must be reviewed separately for the actual launch region. |
| REF-AI-06 | Document chunking patterns | LangChain text splitter documentation and Unstructured chunking documentation. | Engineering references for header-aware, recursive, and title/element-aware document chunking. | Does not prove the best chunk size or retrieval quality for FitLog; verify with local retrieval tests. |
| REF-AI-07 | Contextual retrieval | Anthropic engineering note on Contextual Retrieval. | Supports adding document-level context around chunks before retrieval. | Vendor guidance, not a guarantee of correctness; FitLog must keep context deterministic or reviewed. |

FitLog-specific AI decisions that are product boundaries:

- AI Gateway is server-managed.
- Users do not provide model API keys in V1.
- Cloud Profile is authoritative after login.
- After Phase 3, signed-in body/food/workout official records use the cloud as the source of truth.
- Local SQLite is partial cache, draft storage, and runtime acceleration, not a complete history mirror.
- User-data vector databases and long-term semantic memory are out of scope for V1.
- AI creates drafts and explanations; user confirmation gates official writes.

## Database And Engineering References

| ID | Topic | Source | FitLog usage | Boundary |
| --- | --- | --- | --- | --- |
| REF-DB-01 | SQLite local storage | SQLite official documentation/homepage. | Local embedded structured storage. | Does not validate every schema decision. |
| REF-DB-02 | Flutter SQLite persistence | Flutter docs "Persist data with SQLite"; `sqflite` package documentation. | Package and platform persistence choice. | Schema remains project-specific. |
| REF-DB-03 | SharedPreferences | Flutter `shared_preferences` package documentation. | Simple language preference storage. | Not for relational records. |
| REF-DB-04 | Repository pattern | Martin Fowler, Repository pattern. | Repository/service separation. | Pattern reference only. |

## Internal Decisions That Should Not Be Over-Cited

- Product page descriptions and normal UX behavior.
- AI page visual style, background animation, and navigation placement.
- Page names, labels, localization strings, and file paths.
- Field names, enum names, class names, and table names.
- Changelog and validation statements.
- SQLite migration statements themselves.
- `diet_goal_phase`, `diet_calculation_mode`, and `diet_plan_strategy` names.
- `prefer_not_to_say` averaging.
- Training-frequency self-check thresholds and cooldown.
- Strength calorie coefficients.
- `DailySummary` being runtime-only.
- Subscription-only UI with no user-visible quota in V1.

## Writing Rules

- Keep reference IDs stable.
- Cite only the narrow claim a source supports.
- Mark heuristic or product-specific choices as local design decisions.
- Do not use this file as a changelog.
- Before implementing fast-moving AI, security, payment, or legal requirements, re-check the relevant primary/official sources.
