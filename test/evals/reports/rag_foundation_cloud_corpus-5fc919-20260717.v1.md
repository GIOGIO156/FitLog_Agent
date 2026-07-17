# RAG foundation cloud canary: corpus-5fc919-20260717

Target: `dyacqajcinjwrkbngeif`  
Expected pipeline: `rag_foundation_v1`  
Active build: `5fc91991637d6621a0f56e8f`  
Embedding: `text-embedding-v4` / 1536  
Connect-level transport retries: 8

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_text | pass | 8268 |  |
| qwen_chat_permission | pass | 5900 |  |
| qwen_chat_rag_boundary | pass | 5860 |  |
| qwen_food_text | pass | 5791 |  |
| qwen_food_image | pass | 6970 |  |

## Retrieval

Source recall@3: 0.8462 (11/13); source precision@3: 0.8649 (32/37); critical top-1: 0.8 (4/5); p50/p95: 5851/6153 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 924/1313 ms across 11 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Product.md | 6073 |
| product_en | pass | docs/en/Product.md<br>docs/en/Product.md<br>docs/en/Product.md | 5674 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 5864 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 5813 |
| algorithm_per_side | fail | docs/zh/Product.md | 6138 |
| algorithm_total_negative | fail | docs/zh/Methodology.md<br>docs/zh/Product.md<br>docs/zh/AIOutputContract.md | 5573 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 5851 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 5900 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 5748 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 5812 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 6153 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 6079 |
| references_boundary | pass | docs/en/References.md<br>docs/en/AgentDesign.md<br>docs/en/AgentDesign.md | 6041 |
| no_answer_weather | pass |  | 5557 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| food_logging_no_document_rag | 1 | 7795/7795 | 0/0 | 0/0 | 6189/6189 | 1/1 | 0/0 | {"none":1} |
| workout_logging_no_document_rag | 1 | 7665/7665 | 3/3 | 0/0 | 6390/6390 | 1/1 | 0/0 | {"none":1} |
| structured_meal_context_no_document_rag | 1 | 5087/5087 | 116/116 | 0/0 | 3793/3793 | 1/1 | 0/0 | {"none":1} |
| model_planner_no_document_rag | 1 | 4792/4792 | 0/0 | 0/0 | 0/0 | 1/1 | 0/0 | {"none":1} |
| document_rag_zh | 1 | 4718/4718 | 1255/1255 | 899/899 | 2533/2533 | 1/1 | 0/0 | {"none":1} |
| document_rag_en | 1 | 4421/4421 | 1134/1134 | 742/742 | 2361/2361 | 1/1 | 0/0 | {"none":1} |
| document_rag_mixed | 1 | 4770/4770 | 893/893 | 538/538 | 2994/2994 | 1/1 | 0/0 | {"none":1} |
| document_rag_retry_probe | 1 | 3977/3977 | 924/924 | 517/517 | 2183/2183 | 1/1 | 0/0 | {"none":1} |

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

Summary: 26 passed, 2 failed.
