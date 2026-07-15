# RAG foundation cloud canary: latency_diagnostic

Target: `dyacqajcinjwrkbngeif`  
Expected pipeline: `rag_foundation_v1`  
Active build: `b209353e25df637256a1825f`  
Embedding: `text-embedding-v4` / 1536

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_text | pass | 32996 |  |
| qwen_chat_permission | pass | 13408 |  |
| qwen_chat_rag_boundary | pass | 12981 |  |
| qwen_food_text | pass | 7333 |  |
| qwen_food_image | pass | 7111 |  |

## Retrieval

Source recall@3: 1 (13/13); source precision@3: 0.9744 (38/39); critical top-1: 1 (5/5); p50/p95: 6651/10433 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 3263/17095 ms across 27 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Product.md | 10433 |
| product_en | pass | docs/en/Product.md<br>docs/en/AgentDesign.md<br>docs/en/Product.md | 3486 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 3727 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 8081 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/zh/Algorithm.md<br>docs/zh/AppGuide.md | 7285 |
| algorithm_total_negative | pass | docs/zh/Algorithm.md<br>docs/zh/Database.md<br>docs/zh/Methodology.md | 7260 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 3514 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 7026 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 4141 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 7328 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 3341 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 6651 |
| references_boundary | pass | docs/en/References.md<br>docs/en/References.md<br>docs/en/Methodology.md | 4097 |
| no_answer_weather | pass |  | 7358 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | Retry |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| food_logging_no_document_rag | 3 | 4562/4727 | 1/1 | 0/0 | 2874/3151 | 0 |
| workout_logging_no_document_rag | 3 | 8729/9828 | 0/0 | 0/0 | 0/0 | 0 |
| structured_meal_context_no_document_rag | 3 | 11227/12087 | 100/103 | 0/0 | 4520/5675 | 0 |
| model_planner_no_document_rag | 3 | 5368/5818 | 0/0 | 0/0 | 0/0 | 0 |
| document_rag_zh | 3 | 31323/31936 | 0/0 | 0/0 | 0/0 | 0 |
| document_rag_en | 3 | 10186/10353 | 3718/3730 | 687/796 | 5283/5609 | 0 |
| document_rag_mixed | 3 | 11317/11467 | 4364/4390 | 786/789 | 5880/6020 | 0 |
| document_rag_retry_probe | 3 | 9496/10569 | 3263/3329 | 775/784 | 5195/6206 | 0 |

Embedding states: `{"not_requested":5,"completed":9}`; retry requests: 0; matched logs: 14/24.

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
