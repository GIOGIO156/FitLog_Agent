# RAG foundation cloud canary: latency_diagnostic_failures

Target: `dyacqajcinjwrkbngeif`  
Expected pipeline: `rag_foundation_v1`  
Active build: `b209353e25df637256a1825f`  
Embedding: `text-embedding-v4` / 1536

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_text | fail | 33472 | provider_output_invalid |
| qwen_chat_permission | pass | 13183 |  |
| qwen_chat_rag_boundary | pass | 13696 |  |
| qwen_food_text | pass | 6521 |  |
| qwen_food_image | pass | 6801 |  |

## Retrieval

Source recall@3: 1 (13/13); source precision@3: 0.9744 (38/39); critical top-1: 1 (5/5); p50/p95: 6454/9026 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 101/17103 ms across 18 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Product.md | 9026 |
| product_en | pass | docs/en/Product.md<br>docs/en/AgentDesign.md<br>docs/en/Product.md | 2813 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 3813 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 7441 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/zh/Algorithm.md<br>docs/zh/AppGuide.md | 8448 |
| algorithm_total_negative | pass | docs/zh/Algorithm.md<br>docs/zh/Database.md<br>docs/zh/Methodology.md | 7001 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 4041 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 7067 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 3973 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 7206 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 3446 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 7063 |
| references_boundary | pass | docs/en/References.md<br>docs/en/References.md<br>docs/en/Methodology.md | 4343 |
| no_answer_weather | pass |  | 6454 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | Retry | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| workout_logging_no_document_rag | 3 | 8205/9320 | 1/1 | 0/0 | 4374/4605 | 0 | {"record_schema_mismatch":1,"provider_output_invalid":2} |
| structured_meal_context_no_document_rag | 3 | 9737/12875 | 98/101 | 0/0 | 4328/6527 | 0 | {"none":2,"provider_output_invalid":1} |
| model_planner_no_document_rag | 3 | 5211/5457 | 1/1 | 0/0 | 0/0 | 0 | {"record_schema_mismatch":3} |
| document_rag_zh | 3 | 31376/38285 | 16833/17015 | 776/798 | 6983/10953 | 0 | {"provider_output_invalid":3} |
| document_rag_retry_probe | 3 | 12347/13387 | 6683/7389 | 818/874 | 2562/2597 | 1 | {"none":1,"provider_output_invalid":2} |

Embedding states: `{"not_requested":9,"completed":6}`; retry requests: 1; matched logs: 15/15.

## Access control

| Principal | Operation | Status | HTTP |
| --- | --- | --- | ---: |
| anon | document_chunks_read | pass | 401 |
| anon | corpus_admin_rpc | pass | 401 |
| user_a | document_chunks_read | pass | 403 |
| user_a | corpus_admin_rpc | pass | 403 |
| user_b | document_chunks_read | pass | 403 |
| user_b | corpus_admin_rpc | pass | 403 |

Summary: 17 passed, 2 failed.
