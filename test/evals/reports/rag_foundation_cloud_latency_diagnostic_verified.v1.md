# RAG foundation cloud canary: latency_diagnostic_verified

Target: `dyacqajcinjwrkbngeif`  
Expected pipeline: `rag_foundation_v1`  
Active build: `b209353e25df637256a1825f`  
Embedding: `text-embedding-v4` / 1536

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_text | fail | 33077 | provider_output_invalid |
| qwen_chat_permission | pass | 13473 |  |
| qwen_chat_rag_boundary | pass | 14883 |  |
| qwen_food_text | pass | 6813 |  |
| qwen_food_image | pass | 7100 |  |

## Retrieval

Source recall@3: 1 (13/13); source precision@3: 0.9744 (38/39); critical top-1: 1 (5/5); p50/p95: 6612/11132 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 106/16600 ms across 18 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Product.md | 11132 |
| product_en | pass | docs/en/Product.md<br>docs/en/AgentDesign.md<br>docs/en/Product.md | 6853 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 3195 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 7361 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/zh/Algorithm.md<br>docs/zh/AppGuide.md | 6612 |
| algorithm_total_negative | pass | docs/zh/Algorithm.md<br>docs/zh/Database.md<br>docs/zh/Methodology.md | 6656 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 3775 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 8559 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 3784 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 6768 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 3450 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 6921 |
| references_boundary | pass | docs/en/References.md<br>docs/en/References.md<br>docs/en/Methodology.md | 3984 |
| no_answer_weather | pass |  | 6584 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | Retry | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| workout_logging_no_document_rag | 3 | 8165/8639 | 1/1 | 0/0 | 3757/4447 | 0 | {"provider_output_invalid":1,"none":2} |
| structured_meal_context_no_document_rag | 3 | 10510/10907 | 92/106 | 0/0 | 4611/4993 | 0 | {"none":1,"provider_output_invalid":2} |
| model_planner_no_document_rag | 3 | 5776/5999 | 1/1 | 0/0 | 0/0 | 0 | {"none":3} |
| document_rag_zh | 3 | 30978/31981 | 16395/16600 | 716/822 | 7213/7923 | 3 | {"provider_output_invalid":3} |
| document_rag_retry_probe | 3 | 12282/13719 | 6384/7551 | 812/839 | 2684/3297 | 3 | {"provider_output_invalid":2,"none":1} |

Embedding states: `{"not_requested":9,"completed":6}`; retry requests: 6; matched logs: 15/15.

## Access control

| Principal | Operation | Status | HTTP |
| --- | --- | --- | ---: |
| anon | document_chunks_read | pass | 401 |
| anon | corpus_admin_rpc | pass | 401 |
| user_a | document_chunks_read | pass | 403 |
| user_a | corpus_admin_rpc | pass | 403 |
| user_b | document_chunks_read | pass | 403 |
| user_b | corpus_admin_rpc | pass | 403 |

Summary: 16 passed, 3 failed.
