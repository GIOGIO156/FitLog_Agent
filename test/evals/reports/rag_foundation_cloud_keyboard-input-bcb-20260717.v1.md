# RAG foundation cloud canary: keyboard-input-bcb-20260717

Target: `dyacqajcinjwrkbngeif`  
Expected pipeline: `rag_foundation_v1`  
Active build: `bcb0dc993a76fd71a9aa7528`  
Embedding: `text-embedding-v4` / 1536  
Connect-level transport retries: 4

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_text | pass | 8174 |  |
| qwen_chat_permission | pass | 6039 |  |
| qwen_chat_rag_boundary | pass | 4955 |  |
| qwen_food_text | pass | 5765 |  |
| qwen_food_image | pass | 7603 |  |

## Retrieval

Source recall@3: 0.9231 (12/13); source precision@3: 0.9459 (35/37); critical top-1: 0.8 (4/5); p50/p95: 1524/6513 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 1213/1982 ms across 6 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Product.md | 5612 |
| product_en | pass | docs/en/Product.md<br>docs/en/Product.md<br>docs/en/Product.md | 6513 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AgentDesign.md | 5664 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 5756 |
| algorithm_per_side | fail | docs/zh/Product.md | 5219 |
| algorithm_total_negative | pass | docs/zh/Algorithm.md<br>docs/zh/Database.md<br>docs/zh/Methodology.md | 1557 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 1524 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 1863 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 1401 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 1179 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 1146 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 1101 |
| references_boundary | pass | docs/en/References.md<br>docs/en/References.md<br>docs/en/Methodology.md | 1239 |
| no_answer_weather | pass |  | 1288 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| document_rag_zh | 1 | 7367/7367 | 1153/1153 | 828/828 | 4990/4990 | 1/1 | 0/0 | {"none":1} |
| document_rag_en | 1 | 5374/5374 | 1215/1215 | 853/853 | 3031/3031 | 1/1 | 0/0 | {"none":1} |
| document_rag_mixed | 1 | 4720/4720 | 829/829 | 468/468 | 2908/2908 | 1/1 | 0/0 | {"none":1} |

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

Summary: 24 passed, 3 failed.
