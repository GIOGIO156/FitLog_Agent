# RAG foundation cloud canary: p4_first_pass

Target: `dyacqajcinjwrkbngeif`  
Expected pipeline: `rag_foundation_v1`  
Active build: `b209353e25df637256a1825f`  
Embedding: `text-embedding-v4` / 1536

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_text | pass | 7724 |  |
| qwen_chat_permission | pass | 7782 |  |
| qwen_chat_rag_boundary | pass | 5066 |  |
| qwen_food_text | pass | 6376 |  |
| qwen_food_image | pass | 7691 |  |

## Retrieval

Source recall@3: 0.9231 (12/13); source precision@3: 0.8974 (35/39); critical top-1: 0.8 (4/5); p50/p95: 1828/6495 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 265/5036 ms across 18 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Product.md | 6495 |
| product_en | fail | docs/en/AgentDesign.md<br>docs/en/AIOutputContract.md<br>docs/en/Methodology.md | 6477 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 6184 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 1980 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/zh/AppGuide.md<br>docs/zh/Methodology.md | 1493 |
| algorithm_total_negative | pass | docs/zh/Algorithm.md<br>docs/zh/Database.md<br>docs/zh/Methodology.md | 1425 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 1927 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 1360 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 2252 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 1828 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 1614 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 1612 |
| references_boundary | pass | docs/en/References.md<br>docs/en/References.md<br>docs/en/Methodology.md | 1524 |
| no_answer_weather | pass |  | 1997 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| food_logging_no_document_rag | 3 | 12445/13842 | 0/1 | 0/0 | 8806/9703 | 0/3 | 0/0 | {"none":3} |
| workout_logging_no_document_rag | 3 | 6507/7849 | 1/1 | 0/0 | 3600/4274 | 1/3 | 0/0 | {"none":2,"provider_output_invalid":1} |
| structured_meal_context_no_document_rag | 3 | 8743/9998 | 148/265 | 0/0 | 3558/5015 | 0/3 | 0/0 | {"none":3} |
| document_rag_zh | 3 | 5358/5715 | 1106/1310 | 744/918 | 3184/3580 | 3/3 | 0/0 | {"none":3} |
| document_rag_retry_probe | 3 | 8964/9178 | 4778/5036 | 704/770 | 2796/2807 | 3/3 | 3/0 | {"none":3} |

Embedding states: `{"not_requested":9,"completed":6}`; retry requests: 3; matched logs: 15/15.

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
