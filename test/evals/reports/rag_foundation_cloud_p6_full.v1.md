# RAG foundation cloud canary: p6_full

Target: `dyacqajcinjwrkbngeif`  
Expected pipeline: `rag_foundation_v1`  
Active build: `b209353e25df637256a1825f`  
Embedding: `text-embedding-v4` / 1536  
Connect-level transport retries: 1

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_text | fail | 46681 | gateway_timeout |
| qwen_chat_permission | pass | 5646 |  |
| qwen_chat_rag_boundary | pass | 3435 |  |
| qwen_food_text | pass | 7631 |  |
| qwen_food_image | pass | 7626 |  |

## Retrieval

Source recall@3: 1 (13/13); source precision@3: 0.9744 (38/39); critical top-1: 1 (5/5); p50/p95: 1628/6040 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 915/1676 ms across 27 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Product.md | 6040 |
| product_en | pass | docs/en/Product.md<br>docs/en/Product.md<br>docs/en/Product.md | 3556 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 2367 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 1233 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/zh/AppGuide.md<br>docs/zh/Methodology.md | 1096 |
| algorithm_total_negative | pass | docs/zh/Algorithm.md<br>docs/zh/Database.md<br>docs/zh/Methodology.md | 1934 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 2048 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 1628 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 1562 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 1623 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 1247 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 1693 |
| references_boundary | pass | docs/en/References.md<br>docs/en/References.md<br>docs/en/Methodology.md | 1647 |
| no_answer_weather | pass |  | 1087 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| food_logging_no_document_rag | 3 | 10050/10210 | 0/0 | 0/0 | 8635/9065 | 3/3 | 0/0 | {"none":3} |
| workout_logging_no_document_rag | 3 | 9938/10916 | 3/3 | 0/0 | 8919/9089 | 3/3 | 0/0 | {"none":3} |
| structured_meal_context_no_document_rag | 3 | 5330/7545 | 103/111 | 0/0 | 4262/6282 | 3/3 | 0/0 | {"none":3} |
| model_planner_no_document_rag | 3 | 5168/5989 | 1/1 | 0/0 | 0/0 | 3/3 | 0/0 | {"none":3} |
| document_rag_zh | 3 | 3836/4186 | 915/1232 | 536/896 | 1912/2027 | 3/3 | 0/0 | {"none":3} |
| document_rag_en | 3 | 46340/46787 | 1154/1174 | 748/764 | 43294/43484 | 1/3 | 0/0 | {"gateway_timeout":2,"none":1} |
| document_rag_mixed | 3 | 5239/6835 | 1107/2455 | 746/752 | 2927/3064 | 3/3 | 0/0 | {"none":3} |
| document_rag_retry_probe | 3 | 4293/45640 | 1091/1335 | 704/837 | 1885/43618 | 2/3 | 0/0 | {"none":2,"gateway_timeout":1} |

Embedding states: `{"not_requested":12,"completed":12}`; retry requests: 0; matched logs: 24/24.

## Access control

| Principal | Operation | Status | HTTP |
| --- | --- | --- | ---: |
| anon | document_chunks_read | pass | 401 |
| anon | corpus_admin_rpc | pass | 401 |
| user_a | document_chunks_read | pass | 403 |
| user_a | corpus_admin_rpc | pass | 403 |
| user_b | document_chunks_read | pass | 403 |
| user_b | corpus_admin_rpc | pass | 403 |

Summary: 24 passed, 4 failed.
