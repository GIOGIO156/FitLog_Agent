# RAG foundation cloud canary: keyboard-input-20260717-recheck

Target: `dyacqajcinjwrkbngeif`  
Expected pipeline: `rag_foundation_v1`  
Active build: `e5dcd22e8989d3ae0914d3cd`  
Embedding: `text-embedding-v4` / 1536  
Connect-level transport retries: 0

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_text | pass | 6770 |  |
| qwen_chat_permission | pass | 5911 |  |
| qwen_chat_rag_boundary | pass | 4589 |  |
| qwen_food_text | pass | 5473 |  |
| qwen_food_image | pass | 7708 |  |

## Retrieval

Source recall@3: 0.7692 (10/13); source precision@3: 0.8108 (30/37); critical top-1: 0.8 (4/5); p50/p95: 1142/1927 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 1121/1364 ms across 11 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Product.md | 1913 |
| product_en | pass | docs/en/Product.md<br>docs/en/Product.md<br>docs/en/Product.md | 1117 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AgentDesign.md | 1371 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 1108 |
| algorithm_per_side | fail | docs/zh/Product.md | 894 |
| algorithm_total_negative | fail | docs/zh/Methodology.md<br>docs/zh/Product.md<br>docs/zh/AIOutputContract.md | 1927 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 1139 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 1181 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 1167 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 1152 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 958 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 1142 |
| references_boundary | fail | docs/en/AgentDesign.md<br>docs/en/AgentDesign.md<br>docs/en/AIOutputContract.md | 1346 |
| no_answer_weather | pass |  | 669 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| food_logging_no_document_rag | 1 | 9413/9413 | 0/0 | 0/0 | 8493/8493 | 1/1 | 0/0 | {"none":1} |
| workout_logging_no_document_rag | 1 | 7169/7169 | 3/3 | 0/0 | 6115/6115 | 1/1 | 0/0 | {"none":1} |
| structured_meal_context_no_document_rag | 1 | 5285/5285 | 96/96 | 0/0 | 3947/3947 | 1/1 | 0/0 | {"none":1} |
| model_planner_no_document_rag | 1 | 5416/5416 | 1/1 | 0/0 | 0/0 | 1/1 | 0/0 | {"none":1} |
| document_rag_zh | 1 | 4313/4313 | 875/875 | 530/530 | 2565/2565 | 1/1 | 0/0 | {"none":1} |
| document_rag_en | 1 | 4567/4567 | 1121/1121 | 770/770 | 2543/2543 | 1/1 | 0/0 | {"none":1} |
| document_rag_mixed | 1 | 6792/6792 | 1229/1229 | 845/845 | 3761/3761 | 1/1 | 0/0 | {"none":1} |
| document_rag_retry_probe | 1 | 4672/4672 | 1184/1184 | 786/786 | 2048/2048 | 1/1 | 0/0 | {"none":1} |

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

Summary: 25 passed, 3 failed.
