# RAG foundation cloud canary: keyboard-input-20260717-final

Target: `dyacqajcinjwrkbngeif`  
Expected pipeline: `rag_foundation_v1`  
Active build: `e5dcd22e8989d3ae0914d3cd`  
Embedding: `text-embedding-v4` / 1536  
Connect-level transport retries: 0

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_text | pass | 5658 |  |
| qwen_chat_permission | pass | 5519 |  |
| qwen_chat_rag_boundary | pass | 4267 |  |
| qwen_food_text | pass | 5716 |  |
| qwen_food_image | pass | 7132 |  |

## Retrieval

Source recall@3: 1 (13/13); source precision@3: 0.9231 (36/39); critical top-1: 1 (5/5); p50/p95: 1660/2371 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 1023/1576 ms across 11 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>README.md | 2371 |
| product_en | pass | docs/en/Product.md<br>docs/en/Product.md<br>docs/en/AgentDesign.md | 2067 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 1776 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 1627 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/zh/AppGuide.md<br>docs/zh/Methodology.md | 1431 |
| algorithm_total_negative | pass | docs/zh/Algorithm.md<br>docs/zh/Database.md<br>docs/zh/Methodology.md | 1660 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 1928 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 1423 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 1547 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 2060 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 999 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 1630 |
| references_boundary | pass | docs/en/References.md<br>docs/en/References.md<br>docs/en/Methodology.md | 1672 |
| no_answer_weather | pass |  | 1999 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| food_logging_no_document_rag | 1 | 7620/7620 | 0/0 | 0/0 | 6362/6362 | 1/1 | 0/0 | {"none":1} |
| workout_logging_no_document_rag | 1 | 6772/6772 | 3/3 | 0/0 | 5912/5912 | 1/1 | 0/0 | {"none":1} |
| structured_meal_context_no_document_rag | 1 | 5323/5323 | 101/101 | 0/0 | 4282/4282 | 1/1 | 0/0 | {"none":1} |
| model_planner_no_document_rag | 1 | 4930/4930 | 1/1 | 0/0 | 0/0 | 1/1 | 0/0 | {"none":1} |
| document_rag_zh | 1 | 6303/6303 | 1023/1023 | 656/656 | 3066/3066 | 1/1 | 0/0 | {"none":1} |
| document_rag_en | 1 | 4648/4648 | 984/984 | 636/636 | 2777/2777 | 1/1 | 0/0 | {"none":1} |
| document_rag_mixed | 1 | 5285/5285 | 1218/1218 | 848/848 | 3150/3150 | 1/1 | 0/0 | {"none":1} |
| document_rag_retry_probe | 1 | 4123/4123 | 1217/1217 | 804/804 | 2003/2003 | 1/1 | 0/0 | {"none":1} |

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

Summary: 27 passed, 1 failed.
