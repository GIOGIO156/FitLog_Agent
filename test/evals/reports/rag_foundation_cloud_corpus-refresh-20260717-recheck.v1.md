# RAG foundation cloud canary: corpus-refresh-20260717-recheck

Target: `dyacqajcinjwrkbngeif`  
Expected pipeline: `rag_foundation_v1`  
Active build: `b4400ad8b82742b465ffd6d7`  
Embedding: `text-embedding-v4` / 1536  
Connect-level transport retries: 0

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_text | pass | 5976 |  |
| qwen_chat_permission | pass | 6280 |  |
| qwen_chat_rag_boundary | pass | 6037 |  |
| qwen_food_text | pass | 4926 |  |
| qwen_food_image | pass | 7580 |  |

## Retrieval

Source recall@3: 1 (13/13); source precision@3: 0.9231 (36/39); critical top-1: 1 (5/5); p50/p95: 1192/1644 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 1246/1712 ms across 6 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>README.md | 1388 |
| product_en | pass | docs/en/Product.md<br>docs/en/Product.md<br>docs/en/AgentDesign.md | 1644 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 1598 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 834 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/zh/AppGuide.md<br>docs/zh/Methodology.md | 652 |
| algorithm_total_negative | pass | docs/zh/Algorithm.md<br>docs/zh/Database.md<br>docs/zh/Methodology.md | 664 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 1435 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 1112 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 1474 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 815 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 1435 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 1192 |
| references_boundary | pass | docs/en/References.md<br>docs/en/References.md<br>docs/en/Methodology.md | 1412 |
| no_answer_weather | pass |  | 708 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| document_rag_zh | 1 | 5413/5413 | 1210/1210 | 885/885 | 3372/3372 | 1/1 | 0/0 | {"none":1} |
| document_rag_en | 1 | 4654/4654 | 1327/1327 | 758/758 | 2286/2286 | 1/1 | 0/0 | {"none":1} |
| document_rag_mixed | 1 | 5605/5605 | 1187/1187 | 677/677 | 3553/3553 | 1/1 | 0/0 | {"none":1} |

Embedding states: `{"completed":3}`; retry requests: 0; matched logs: 3/3.

## Access control

| Principal | Operation | Status | HTTP |
| --- | --- | --- | ---: |
| anon | document_chunks_read | pass | 401 |
| anon | corpus_admin_rpc | pass | 401 |
| user_a | document_chunks_read | pass | 403 |
| user_a | corpus_admin_rpc | pass | 403 |
| user_b | document_chunks_read | pass | 403 |
| user_b | corpus_admin_rpc | pass | 403 |

Summary: 26 passed, 1 failed.
