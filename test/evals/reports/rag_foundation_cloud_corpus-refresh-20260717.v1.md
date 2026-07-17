# RAG foundation cloud canary: corpus-refresh-20260717

Target: `dyacqajcinjwrkbngeif`  
Expected pipeline: `rag_foundation_v1`  
Active build: `b4400ad8b82742b465ffd6d7`  
Embedding: `text-embedding-v4` / 1536  
Connect-level transport retries: 0

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_text | pass | 6821 |  |
| qwen_chat_permission | pass | 4366 |  |
| qwen_chat_rag_boundary | pass | 4666 |  |
| qwen_food_text | pass | 5253 |  |
| qwen_food_image | pass | 7443 |  |

## Retrieval

Source recall@3: 1 (13/13); source precision@3: 0.9231 (36/39); critical top-1: 1 (5/5); p50/p95: 1103/1461 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 1252/1909 ms across 6 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>README.md | 1103 |
| product_en | pass | docs/en/Product.md<br>docs/en/Product.md<br>docs/en/AgentDesign.md | 1461 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 1417 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 766 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/zh/AppGuide.md<br>docs/zh/Methodology.md | 718 |
| algorithm_total_negative | pass | docs/zh/Algorithm.md<br>docs/zh/Database.md<br>docs/zh/Methodology.md | 625 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 1402 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 1096 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 1458 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 793 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 1421 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 1174 |
| references_boundary | pass | docs/en/References.md<br>docs/en/References.md<br>docs/en/Methodology.md | 1390 |
| no_answer_weather | pass |  | 712 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| document_rag_zh | 1 | 6256/6256 | 1090/1090 | 773/773 | 3994/3994 | 1/1 | 0/0 | {"none":1} |
| document_rag_en | 1 | 5704/5704 | 1589/1589 | 898/898 | 2847/2847 | 1/1 | 0/0 | {"none":1} |
| document_rag_mixed | 1 | 5513/5513 | 1252/1252 | 823/823 | 2790/2790 | 1/1 | 0/0 | {"none":1} |

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
