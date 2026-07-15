# RAG foundation cloud canary: final

Target: `dyacqajcinjwrkbngeif`  
Expected pipeline: `rag_foundation_v1`  
Active build: `062675a0d08b94c5872735b3`  
Embedding: `text-embedding-v4` / 1536

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_text | fail | 18488 | provider_output_invalid |
| qwen_chat_permission | pass | 13899 |  |
| qwen_chat_rag_boundary | pass | 11474 |  |
| qwen_food_text | pass | 7901 |  |
| qwen_food_image | pass | 7738 |  |

## Retrieval

Source recall@3: 1 (13/13); critical top-1: 1 (5/5); p50/p95: 2831/6504 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 2817/3892 ms across 3 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Methodology.md | 6504 |
| product_en | pass | docs/en/Product.md<br>docs/en/AgentDesign.md<br>docs/en/Product.md | 2392 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 2634 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/RAGDesign.md | 2940 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/zh/Algorithm.md<br>docs/zh/Algorithm.md | 2815 |
| algorithm_total_negative | pass | docs/zh/Database.md<br>docs/zh/Algorithm.md<br>docs/zh/AIOutputContract.md | 2360 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 3084 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 3945 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 3578 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>README.md | 2461 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 2831 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 3386 |
| references_boundary | pass | docs/en/References.md<br>docs/en/References.md<br>docs/en/Methodology.md | 4120 |
| no_answer_weather | pass |  | 2048 |

## Access control

| Principal | Operation | Status | HTTP |
| --- | --- | --- | ---: |
| anon | document_chunks_read | pass | 401 |
| anon | corpus_admin_rpc | pass | 401 |
| user_a | document_chunks_read | pass | 403 |
| user_a | corpus_admin_rpc | pass | 403 |
| user_b | document_chunks_read | pass | 403 |
| user_b | corpus_admin_rpc | pass | 403 |

Summary: 14 passed, 3 failed.
