# RAG foundation cloud canary: p5_parallel_retrieval

Target: `dyacqajcinjwrkbngeif`  
Expected pipeline: `rag_foundation_v1`  
Active build: `b209353e25df637256a1825f`  
Embedding: `text-embedding-v4` / 1536

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_text | pass | 14573 |  |
| qwen_chat_permission | pass | 5274 |  |
| qwen_chat_rag_boundary | pass | 5730 |  |
| qwen_food_text | pass | 6345 |  |
| qwen_food_image | pass | 7205 |  |

## Retrieval

Source recall@3: 0.8462 (11/13); source precision@3: 0.8421 (32/38); critical top-1: 0.8 (4/5); p50/p95: 1422/3320 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 1019/4810 ms across 12 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Product.md | 1990 |
| product_en | fail | docs/en/AgentDesign.md<br>docs/en/AIOutputContract.md<br>docs/en/Methodology.md | 1529 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 1718 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 3320 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/zh/Product.md | 1253 |
| algorithm_total_negative | fail | docs/zh/Database.md<br>docs/zh/Methodology.md<br>docs/zh/Product.md | 1422 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 1190 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 2084 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 1103 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 2326 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 1279 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 1052 |
| references_boundary | pass | docs/en/References.md<br>docs/en/Methodology.md<br>docs/en/RAGDesign.md | 2182 |
| no_answer_weather | pass |  | 1128 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| workout_logging_no_document_rag | 3 | 10006/10309 | 3/4 | 0/0 | 8932/9035 | 3/3 | 0/0 | {"none":3} |
| document_rag_zh | 3 | 17241/17389 | 4228/4367 | 781/910 | 5943/6621 | 1/3 | 3/3 | {"none":1,"provider_output_invalid":2} |
| document_rag_retry_probe | 3 | 4998/5042 | 1019/1163 | 740/770 | 3066/3137 | 3/3 | 0/0 | {"none":3} |

Embedding states: `{"not_requested":3,"completed":6}`; retry requests: 3; matched logs: 9/9.

## Access control

| Principal | Operation | Status | HTTP |
| --- | --- | --- | ---: |
| anon | document_chunks_read | pass | 401 |
| anon | corpus_admin_rpc | pass | 401 |
| user_a | document_chunks_read | pass | 403 |
| user_a | corpus_admin_rpc | pass | 403 |
| user_b | document_chunks_read | pass | 403 |
| user_b | corpus_admin_rpc | pass | 403 |

Summary: 15 passed, 4 failed.
