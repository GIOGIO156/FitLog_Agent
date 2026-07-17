# RAG foundation cloud canary: keyboard-input-20260717

Target: `dyacqajcinjwrkbngeif`  
Expected pipeline: `rag_foundation_v1`  
Active build: `e5dcd22e8989d3ae0914d3cd`  
Embedding: `text-embedding-v4` / 1536  
Connect-level transport retries: 1

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_text | pass | 5274 |  |
| qwen_chat_permission | pass | 6241 |  |
| qwen_chat_rag_boundary | pass | 5613 |  |
| qwen_food_text | pass | 5240 |  |
| qwen_food_image | pass | 7112 |  |

## Retrieval

Source recall@3: 0.7692 (10/13); source precision@3: 0.8108 (30/37); critical top-1: 0.8 (4/5); p50/p95: 5741/6201 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 995/1605 ms across 11 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Product.md | 6058 |
| product_en | pass | docs/en/Product.md<br>docs/en/Product.md<br>docs/en/Product.md | 6169 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AgentDesign.md | 5895 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 5741 |
| algorithm_per_side | fail | docs/zh/Product.md | 5201 |
| algorithm_total_negative | fail | docs/zh/Methodology.md<br>docs/zh/Product.md<br>docs/zh/AIOutputContract.md | 6043 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 5775 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 5684 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 5672 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 6201 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 5719 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 5760 |
| references_boundary | fail | docs/en/AgentDesign.md<br>docs/en/AgentDesign.md<br>docs/en/AIOutputContract.md | 5641 |
| no_answer_weather | pass |  | 5378 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| food_logging_no_document_rag | 1 | 8399/8399 | 0/0 | 0/0 | 6720/6720 | 1/1 | 0/0 | {"none":1} |
| workout_logging_no_document_rag | 1 | 7175/7175 | 3/3 | 0/0 | 6279/6279 | 1/1 | 0/0 | {"none":1} |
| structured_meal_context_no_document_rag | 1 | 5802/5802 | 135/135 | 0/0 | 4386/4386 | 1/1 | 0/0 | {"none":1} |
| model_planner_no_document_rag | 1 | 4744/4744 | 0/0 | 0/0 | 0/0 | 1/1 | 0/0 | {"none":1} |
| document_rag_zh | 1 | 6052/6052 | 1605/1605 | 840/840 | 3189/3189 | 1/1 | 0/0 | {"none":1} |
| document_rag_en | 1 | 4802/4802 | 1110/1110 | 754/754 | 2699/2699 | 1/1 | 0/0 | {"none":1} |
| document_rag_mixed | 1 | 5366/5366 | 1087/1087 | 735/735 | 3186/3186 | 1/1 | 0/0 | {"none":1} |
| document_rag_retry_probe | 1 | 4238/4238 | 955/955 | 537/537 | 2342/2342 | 1/1 | 0/0 | {"none":1} |

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

Summary: 24 passed, 4 failed.
