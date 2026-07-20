# RAG foundation cloud canary: corpus-615-activation-20260720-recheck3

Target: `dyacqajcinjwrkbngeif`

Expected pipeline: `rag_foundation_v1`

Active build: `4ebf00df876ce7cc62738c02`

Embedding: `text-embedding-v4` / 1536

Connect-level transport retries: 0

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_database_auto | pass | 5659 |  |
| qwen_chat_permission | pass | 3820 |  |
| qwen_chat_rag_boundary | pass | 4675 |  |
| qwen_food_text | pass | 4988 |  |
| qwen_chat_food_image_auto | pass | 10404 |  |
| qwen_chat_typed_clarification_created | pass | 1015 |  |
| qwen_chat_typed_clarification_consumed | fail | 7877 | provider_incomplete |
| qwen_chat_typed_clarification_replay_idempotent | fail | 10326 | provider_incomplete |
| qwen_chat_typed_clarification_state_resolved_once | fail | 562 |  |
| qwen_food_image | pass | 7113 |  |

## Retrieval

Source recall@3: 1 (13/13); source precision@3: 0.9487 (37/39); critical top-1: 1 (5/5); p50/p95: 1093/2125 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 968/1236 ms across 15 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Product.md | 1935 |
| product_en | pass | docs/en/Product.md<br>docs/en/Product.md<br>docs/en/AgentDesign.md | 1049 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 1398 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 1390 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/zh/AppGuide.md<br>docs/zh/Methodology.md | 1093 |
| algorithm_total_negative | pass | docs/zh/Algorithm.md<br>docs/zh/Database.md<br>docs/zh/Methodology.md | 1056 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 1400 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 974 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 1033 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 2125 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 1508 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 1633 |
| references_boundary | pass | docs/en/References.md<br>docs/en/References.md<br>docs/en/Methodology.md | 1074 |
| no_answer_weather | pass |  | 989 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| food_logging_no_document_rag | 1 | 6785/6785 | 1/1 | 0/0 | 5914/5914 | 1/1 | 0/0 | {"none":1} |
| workout_logging_no_document_rag | 1 | 6629/6629 | 3/3 | 0/0 | 5747/5747 | 1/1 | 0/0 | {"none":1} |
| structured_meal_context_no_document_rag | 1 | 4923/4923 | 103/103 | 0/0 | 3801/3801 | 1/1 | 0/0 | {"none":1} |
| model_planner_no_document_rag | 1 | 4547/4547 | 0/0 | 0/0 | 0/0 | 1/1 | 0/0 | {"none":1} |
| document_rag_zh | 1 | 5473/5473 | 907/907 | 576/576 | 3724/3724 | 1/1 | 0/0 | {"none":1} |
| document_rag_en | 1 | 5206/5206 | 1198/1198 | 856/856 | 2875/2875 | 1/1 | 0/0 | {"none":1} |
| document_rag_mixed | 1 | 4744/4744 | 1170/1170 | 804/804 | 2685/2685 | 1/1 | 0/0 | {"none":1} |
| document_rag_retry_probe | 1 | 3880/3880 | 968/968 | 594/594 | 2054/2054 | 1/1 | 0/0 | {"none":1} |

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

Summary: 30 passed, 3 failed.
