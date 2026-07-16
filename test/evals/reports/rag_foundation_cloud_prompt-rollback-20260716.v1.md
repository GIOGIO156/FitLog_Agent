# RAG foundation cloud canary: prompt-rollback-20260716

Target: `dyacqajcinjwrkbngeif`  
Expected pipeline: `rag_foundation_v1`  
Active build: `942de22e58135187a7550327`  
Embedding: `text-embedding-v4` / 1536  
Connect-level transport retries: 0

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_text | pass | 7858 |  |
| qwen_chat_permission | pass | 7408 |  |
| qwen_chat_rag_boundary | pass | 5667 |  |
| qwen_food_text | pass | 7556 |  |
| qwen_food_image | pass | 7314 |  |

## Retrieval

Source recall@3: 1 (13/13); source precision@3: 0.9231 (36/39); critical top-1: 1 (5/5); p50/p95: 1172/1569 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 1109/1422 ms across 11 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>README.md | 1513 |
| product_en | pass | docs/en/Product.md<br>docs/en/Product.md<br>docs/en/AgentDesign.md | 979 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 1028 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 969 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/zh/AppGuide.md<br>docs/zh/Methodology.md | 969 |
| algorithm_total_negative | pass | docs/zh/Algorithm.md<br>docs/zh/Database.md<br>docs/zh/Methodology.md | 1569 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 1371 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 1240 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 1230 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 1172 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 1311 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 1108 |
| references_boundary | pass | docs/en/References.md<br>docs/en/References.md<br>docs/en/Methodology.md | 1220 |
| no_answer_weather | pass |  | 1099 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| food_logging_no_document_rag | 1 | 10030/10030 | 1/1 | 0/0 | 8962/8962 | 1/1 | 0/0 | {"none":1} |
| workout_logging_no_document_rag | 1 | 5246/5246 | 3/3 | 0/0 | 3776/3776 | 1/1 | 0/0 | {"none":1} |
| structured_meal_context_no_document_rag | 1 | 7300/7300 | 107/107 | 0/0 | 4832/4832 | 1/1 | 0/0 | {"none":1} |
| model_planner_no_document_rag | 1 | 6435/6435 | 1/1 | 0/0 | 0/0 | 1/1 | 0/0 | {"none":1} |
| document_rag_zh | 1 | 5604/5604 | 1172/1172 | 806/806 | 3410/3410 | 1/1 | 0/0 | {"none":1} |
| document_rag_en | 1 | 6679/6679 | 1095/1095 | 734/734 | 2974/2974 | 1/1 | 0/0 | {"none":1} |
| document_rag_mixed | 1 | 6089/6089 | 1109/1109 | 709/709 | 3259/3259 | 1/1 | 0/0 | {"none":1} |
| document_rag_retry_probe | 1 | 5434/5434 | 1162/1162 | 766/766 | 2664/2664 | 1/1 | 0/0 | {"none":1} |

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
