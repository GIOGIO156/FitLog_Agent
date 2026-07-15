# RAG foundation cloud canary: p5_verified

Target: `dyacqajcinjwrkbngeif`  
Expected pipeline: `rag_foundation_v1`  
Active build: `b209353e25df637256a1825f`  
Embedding: `text-embedding-v4` / 1536  
Connect-level transport retries: 0

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_text | pass | 8645 |  |
| qwen_chat_permission | pass | 7953 |  |
| qwen_chat_rag_boundary | pass | 5523 |  |
| qwen_food_text | pass | 7080 |  |
| qwen_food_image | pass | 7415 |  |

## Retrieval

Source recall@3: 1 (13/13); source precision@3: 0.9487 (37/39); critical top-1: 1 (5/5); p50/p95: 1468/5740 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 1304/1953 ms across 12 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Product.md | 5740 |
| product_en | pass | docs/en/Product.md<br>docs/en/AgentDesign.md<br>docs/en/Product.md | 1468 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 1811 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 1172 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/zh/AppGuide.md<br>docs/zh/Methodology.md | 1027 |
| algorithm_total_negative | pass | docs/zh/Algorithm.md<br>docs/zh/Database.md<br>docs/zh/Methodology.md | 1556 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 2159 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 2051 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 1905 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 1455 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 1366 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 1332 |
| references_boundary | pass | docs/en/References.md<br>docs/en/References.md<br>docs/en/Methodology.md | 1856 |
| no_answer_weather | pass |  | 988 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| workout_logging_no_document_rag | 3 | 10138/10268 | 3/4 | 0/0 | 9025/9101 | 3/3 | 0/0 | {"none":3} |
| document_rag_zh | 3 | 5780/5982 | 1163/1304 | 777/823 | 3559/3732 | 3/3 | 0/0 | {"none":3} |
| document_rag_retry_probe | 3 | 5510/6024 | 1671/1724 | 809/898 | 2435/2463 | 3/3 | 0/0 | {"none":3} |

Embedding states: `{"not_requested":3,"completed":6}`; retry requests: 0; matched logs: 9/9.

## Access control

| Principal | Operation | Status | HTTP |
| --- | --- | --- | ---: |
| anon | document_chunks_read | pass | 401 |
| anon | corpus_admin_rpc | pass | 401 |
| user_a | document_chunks_read | pass | 403 |
| user_a | corpus_admin_rpc | pass | 403 |
| user_b | document_chunks_read | pass | 403 |
| user_b | corpus_admin_rpc | pass | 403 |

Summary: 18 passed, 1 failed.
