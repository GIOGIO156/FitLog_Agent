# RAG foundation cloud canary: p6_release

Target: `dyacqajcinjwrkbngeif`  
Expected pipeline: `rag_foundation_v1`  
Active build: `b209353e25df637256a1825f`  
Embedding: `text-embedding-v4` / 1536  
Connect-level transport retries: 2

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_text | pass | 6713 |  |
| qwen_chat_permission | pass | 5543 |  |
| qwen_chat_rag_boundary | pass | 5198 |  |
| qwen_food_text | pass | 3429 |  |
| qwen_food_image | pass | 6938 |  |

## Retrieval

Source recall@3: 1 (13/13); source precision@3: 0.9744 (38/39); critical top-1: 1 (5/5); p50/p95: 1342/3649 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 1061/1250 ms across 11 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Product.md | 3649 |
| product_en | pass | docs/en/Product.md<br>docs/en/Product.md<br>docs/en/Product.md | 2029 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 1342 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 978 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/zh/AppGuide.md<br>docs/zh/Methodology.md | 1126 |
| algorithm_total_negative | pass | docs/zh/Algorithm.md<br>docs/zh/Database.md<br>docs/zh/Methodology.md | 1080 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 1628 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 1748 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 1332 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 1160 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 2308 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 1730 |
| references_boundary | pass | docs/en/References.md<br>docs/en/References.md<br>docs/en/Methodology.md | 1470 |
| no_answer_weather | pass |  | 1274 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| food_logging_no_document_rag | 1 | 4799/4799 | 0/0 | 0/0 | 3482/3482 | 1/1 | 0/0 | {"none":1} |
| workout_logging_no_document_rag | 1 | 4613/4613 | 3/3 | 0/0 | 3742/3742 | 1/1 | 0/0 | {"none":1} |
| structured_meal_context_no_document_rag | 1 | 5563/5563 | 109/109 | 0/0 | 4577/4577 | 1/1 | 0/0 | {"none":1} |
| model_planner_no_document_rag | 1 | 5573/5573 | 0/0 | 0/0 | 0/0 | 1/1 | 0/0 | {"none":1} |
| document_rag_zh | 1 | 5565/5565 | 861/861 | 534/534 | 3406/3406 | 1/1 | 0/0 | {"none":1} |
| document_rag_en | 1 | 5115/5115 | 1167/1167 | 823/823 | 2980/2980 | 1/1 | 0/0 | {"none":1} |
| document_rag_mixed | 1 | 3473/3473 | 1079/1079 | 717/717 | 1542/1542 | 1/1 | 0/0 | {"none":1} |
| document_rag_retry_probe | 1 | 3830/3830 | 1250/1250 | 746/746 | 1653/1653 | 1/1 | 0/0 | {"none":1} |

Embedding states: `{"not_requested":4,"completed":4}`; retry requests: 0; matched logs: 8/8.

## Access control

| Principal | Operation | Status | HTTP |
| --- | --- | --- | ---: |
| anon | document_chunks_read | pass | 401 |
| anon | corpus_admin_rpc | pass | 401 |
| user_a | document_chunks_read | pass | 403 |
| user_a | corpus_admin_rpc | pass | 403 |
| user_b | document_chunks_read | pass | 403 |
| user_b | corpus_admin_rpc | pass | 403 |

Summary: 28 passed, 0 failed.
