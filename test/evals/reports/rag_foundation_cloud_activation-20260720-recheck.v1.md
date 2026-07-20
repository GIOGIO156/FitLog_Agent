# RAG foundation cloud canary: activation-20260720-recheck

Target: `dyacqajcinjwrkbngeif`

Expected pipeline: `rag_foundation_v1`

Active build: `bbdd397f3d144e4ccea082e8`

Embedding: `text-embedding-v4` / 1536

Connect-level transport retries: 0

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_database_auto | pass | 5686 |  |
| qwen_chat_permission | pass | 5973 |  |
| qwen_chat_rag_boundary | pass | 4604 |  |
| qwen_food_text | pass | 5317 |  |
| qwen_chat_food_image_auto | pass | 10289 |  |
| qwen_chat_typed_clarification_created | pass | 861 |  |
| qwen_chat_typed_clarification_consumed | pass | 7101 |  |
| qwen_chat_typed_clarification_replay_idempotent | pass | 816 |  |
| qwen_chat_typed_clarification_state_resolved_once | pass | 418 |  |
| qwen_food_image | pass | 7708 |  |

## Retrieval

Source recall@3: 1 (13/13); source precision@3: 0.9487 (37/39); critical top-1: 1 (5/5); p50/p95: 925/2633 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 926/1244 ms across 14 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Product.md | 2633 |
| product_en | pass | docs/en/Product.md<br>docs/en/Product.md<br>docs/en/AgentDesign.md | 1105 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 1192 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 962 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/zh/AppGuide.md<br>docs/zh/Methodology.md | 947 |
| algorithm_total_negative | pass | docs/zh/Algorithm.md<br>docs/zh/Database.md<br>docs/zh/Methodology.md | 1235 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 916 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 925 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 903 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 919 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 934 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 868 |
| references_boundary | pass | docs/en/References.md<br>docs/en/References.md<br>docs/en/Methodology.md | 857 |
| no_answer_weather | pass |  | 888 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| food_logging_no_document_rag | 1 | 8216/8216 | 0/0 | 0/0 | 7397/7397 | 1/1 | 0/0 | {"none":1} |
| workout_logging_no_document_rag | 1 | 6332/6332 | 3/3 | 0/0 | 5362/5362 | 1/1 | 0/0 | {"none":1} |
| structured_meal_context_no_document_rag | 1 | 5841/5841 | 106/106 | 0/0 | 4549/4549 | 1/1 | 0/0 | {"none":1} |
| model_planner_no_document_rag | 1 | 5567/5567 | 0/0 | 0/0 | 2730/2730 | 1/1 | 0/0 | {"none":1} |
| document_rag_zh | 1 | 5411/5411 | 926/926 | 599/599 | 3513/3513 | 1/1 | 0/0 | {"none":1} |
| document_rag_en | 1 | 4607/4607 | 1016/1016 | 663/663 | 2550/2550 | 1/1 | 0/0 | {"none":1} |
| document_rag_mixed | 1 | 5710/5710 | 971/971 | 589/589 | 3690/3690 | 1/1 | 0/0 | {"none":1} |
| document_rag_retry_probe | 1 | 4290/4290 | 1096/1096 | 684/684 | 1920/1920 | 1/1 | 0/0 | {"none":1} |

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

Summary: 33 passed, 0 failed.
