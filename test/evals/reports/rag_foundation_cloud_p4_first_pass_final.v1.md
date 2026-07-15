# RAG foundation cloud canary: p4_first_pass_final

Target: `dyacqajcinjwrkbngeif`  
Expected pipeline: `rag_foundation_v1`  
Active build: `b209353e25df637256a1825f`  
Embedding: `text-embedding-v4` / 1536

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_text | pass | 7912 |  |
| qwen_chat_permission | pass | 7437 |  |
| qwen_chat_rag_boundary | pass | 5871 |  |
| qwen_food_text | pass | 7004 |  |
| qwen_food_image | pass | 7199 |  |

## Retrieval

Source recall@3: 1 (13/13); source precision@3: 0.9487 (37/39); critical top-1: 1 (5/5); p50/p95: 1346/2059 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 147/2126 ms across 18 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Product.md | 2059 |
| product_en | pass | docs/en/Product.md<br>docs/en/AgentDesign.md<br>docs/en/Product.md | 1494 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 1346 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 1053 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/zh/AppGuide.md<br>docs/zh/Methodology.md | 1463 |
| algorithm_total_negative | pass | docs/zh/Algorithm.md<br>docs/zh/Database.md<br>docs/zh/Methodology.md | 906 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 1396 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 1077 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 1249 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 1271 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 1628 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 1398 |
| references_boundary | pass | docs/en/References.md<br>docs/en/References.md<br>docs/en/Methodology.md | 1628 |
| no_answer_weather | pass |  | 1090 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| food_logging_no_document_rag | 3 | 10015/10362 | 1/1 | 0/0 | 8850/8927 | 3/3 | 0/0 | {"none":3} |
| workout_logging_no_document_rag | 3 | 4425/7770 | 0/0 | 0/0 | 3335/3896 | 2/3 | 0/0 | {"provider_output_invalid":1,"none":2} |
| structured_meal_context_no_document_rag | 3 | 6929/7118 | 138/147 | 0/0 | 5454/5721 | 3/3 | 0/0 | {"none":3} |
| document_rag_zh | 3 | 6282/6499 | 1427/1763 | 742/927 | 3325/3793 | 3/3 | 0/0 | {"none":3} |
| document_rag_retry_probe | 3 | 5438/6965 | 1929/2126 | 721/866 | 2658/2754 | 3/3 | 0/0 | {"none":3} |

Embedding states: `{"not_requested":9,"completed":6}`; retry requests: 0; matched logs: 15/15.

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
