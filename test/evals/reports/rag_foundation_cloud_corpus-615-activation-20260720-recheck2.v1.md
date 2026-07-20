# RAG foundation cloud canary: corpus-615-activation-20260720-recheck2

Target: `dyacqajcinjwrkbngeif`

Expected pipeline: `rag_foundation_v1`

Active build: `4ebf00df876ce7cc62738c02`

Embedding: `text-embedding-v4` / 1536

Connect-level transport retries: 0

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_database_auto | pass | 5136 |  |
| qwen_chat_permission | pass | 4904 |  |
| qwen_chat_rag_boundary | pass | 4034 |  |
| qwen_food_text | pass | 5007 |  |
| qwen_chat_food_image_auto | pass | 9531 |  |
| qwen_chat_typed_clarification_created | pass | 968 |  |
| qwen_chat_typed_clarification_consumed | fail | 11064 | provider_incomplete |
| qwen_chat_typed_clarification_replay_idempotent | fail | 11678 |  |
| qwen_chat_typed_clarification_state_resolved_once | fail | 383 |  |
| qwen_food_image | pass | 8638 |  |

## Retrieval

Source recall@3: 1 (13/13); source precision@3: 0.9487 (37/39); critical top-1: 1 (5/5); p50/p95: 1145/2073 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 915/1299 ms across 15 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Product.md | 1664 |
| product_en | pass | docs/en/Product.md<br>docs/en/Product.md<br>docs/en/AgentDesign.md | 1145 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 1604 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 1926 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/zh/AppGuide.md<br>docs/zh/Methodology.md | 972 |
| algorithm_total_negative | pass | docs/zh/Algorithm.md<br>docs/zh/Database.md<br>docs/zh/Methodology.md | 996 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 1353 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 1342 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 982 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 1043 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 2073 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 1408 |
| references_boundary | pass | docs/en/References.md<br>docs/en/References.md<br>docs/en/Methodology.md | 971 |
| no_answer_weather | pass |  | 903 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| food_logging_no_document_rag | 1 | 6610/6610 | 1/1 | 0/0 | 5790/5790 | 1/1 | 0/0 | {"none":1} |
| workout_logging_no_document_rag | 1 | 7842/7842 | 3/3 | 0/0 | 6947/6947 | 1/1 | 0/0 | {"none":1} |
| structured_meal_context_no_document_rag | 1 | 4269/4269 | 90/90 | 0/0 | 2990/2990 | 1/1 | 0/0 | {"none":1} |
| model_planner_no_document_rag | 1 | 4425/4425 | 1/1 | 0/0 | 0/0 | 1/1 | 0/0 | {"none":1} |
| document_rag_zh | 1 | 5257/5257 | 978/978 | 477/477 | 3043/3043 | 1/1 | 0/0 | {"none":1} |
| document_rag_en | 1 | 5258/5258 | 957/957 | 587/587 | 2963/2963 | 1/1 | 0/0 | {"none":1} |
| document_rag_mixed | 1 | 4967/4967 | 921/921 | 544/544 | 2799/2799 | 1/1 | 0/0 | {"none":1} |
| document_rag_retry_probe | 1 | 3969/3969 | 888/888 | 473/473 | 2088/2088 | 1/1 | 0/0 | {"none":1} |

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
