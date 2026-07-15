# RAG foundation cloud canary: pre_activation

Target: `dyacqajcinjwrkbngeif`  
Expected pipeline: `phase5_legacy`  
Active build: `45de8995d3841575ea1619f9`  
Embedding: `text-embedding-v4` / 1536

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_text | fail | 18920 | provider_output_invalid |
| qwen_food_text | pass | 7938 |  |
| qwen_food_image | fail | 2087 | provider_failure |

## Retrieval

Source recall@3: 0.8462 (11/13); critical top-1: 0.6 (3/5); p50/p95: 2863/5193 ms.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Methodology.md | 5193 |
| product_en | pass | docs/en/Product.md<br>docs/en/AgentDesign.md<br>docs/en/Product.md | 2516 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/Product.md<br>docs/zh/AppGuide.md | 2728 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/RAGDesign.md<br>docs/zh/AppGuide.md | 2863 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/en/Algorithm.md<br>docs/zh/Database.md | 2842 |
| algorithm_total_negative | pass | docs/zh/Database.md<br>docs/zh/Algorithm.md<br>docs/zh/AIOutputContract.md | 2754 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 3319 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/Database.md | 3326 |
| cloud_local_en | pass | docs/en/Database.md<br>README.md<br>docs/en/CloudLocalDataBoundary.md | 3593 |
| agent_permission | fail | README.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/Methodology.md | 2387 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AgentDesign.md<br>docs/en/AIOutputContract.md | 2924 |
| rag_boundary | pass | docs/zh/Database.md<br>docs/zh/Database.md<br>docs/zh/RAGDesign.md | 3440 |
| references_boundary | fail | docs/en/Methodology.md<br>docs/en/RAGDesign.md<br>docs/en/AgentDesign.md | 3940 |
| no_answer_weather | pass |  | 2033 |

## Access control

| Principal | Operation | Status | HTTP |
| --- | --- | --- | ---: |
| anon | document_chunks_read | pass | 401 |
| anon | corpus_admin_rpc | pass | 401 |
| user_a | document_chunks_read | pass | 403 |
| user_a | corpus_admin_rpc | pass | 403 |
| user_b | document_chunks_read | pass | 403 |
| user_b | corpus_admin_rpc | pass | 403 |

Summary: 10 passed, 5 failed.
