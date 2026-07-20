# RAG foundation cloud canary: activation-20260720

Target: `dyacqajcinjwrkbngeif`

Expected pipeline: `rag_foundation_v1`

Active build: `bbdd397f3d144e4ccea082e8`

Embedding: `text-embedding-v4` / 1536

Connect-level transport retries: 0

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_database_auto | pass | 6814 |  |
| qwen_chat_permission | pass | 6109 |  |
| qwen_chat_rag_boundary | pass | 4184 |  |
| qwen_food_text | pass | 5708 |  |
| qwen_chat_food_image_auto | pass | 12005 |  |
| qwen_chat_typed_clarification_created | pass | 1257 |  |
| qwen_chat_typed_clarification_consumed | pass | 7302 |  |
| qwen_chat_typed_clarification_replay_idempotent | pass | 566 |  |
| qwen_chat_typed_clarification_state_resolved_once | pass | 179 |  |
| qwen_food_image | pass | 7180 |  |

## Retrieval

Source recall@3: 1 (13/13); source precision@3: 0.9487 (37/39); critical top-1: 1 (5/5); p50/p95: 969/3628 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 595/1519 ms across 14 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Product.md | 1381 |
| product_en | pass | docs/en/Product.md<br>docs/en/Product.md<br>docs/en/AgentDesign.md | 821 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 914 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 957 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/zh/AppGuide.md<br>docs/zh/Methodology.md | 897 |
| algorithm_total_negative | pass | docs/zh/Algorithm.md<br>docs/zh/Database.md<br>docs/zh/Methodology.md | 994 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 906 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 3628 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 848 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 1201 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 969 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 1203 |
| references_boundary | pass | docs/en/References.md<br>docs/en/References.md<br>docs/en/Methodology.md | 1341 |
| no_answer_weather | pass |  | 1186 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| food_logging_no_document_rag | 1 | 7383/7383 | 0/0 | 0/0 | 6452/6452 | 1/1 | 0/0 | {"none":1} |
| workout_logging_no_document_rag | 1 | 7084/7084 | 3/3 | 0/0 | 5749/5749 | 1/1 | 0/0 | {"none":1} |
| structured_meal_context_no_document_rag | 1 | 4737/4737 | 106/106 | 0/0 | 3823/3823 | 1/1 | 0/0 | {"none":1} |
| model_planner_no_document_rag | 1 | 6046/6046 | 1/1 | 0/0 | 2193/2193 | 1/1 | 0/0 | {"none":1} |
| document_rag_zh | 1 | 4528/4528 | 595/595 | 186/186 | 2989/2989 | 1/1 | 0/0 | {"none":1} |
| document_rag_en | 1 | 4501/4501 | 1141/1141 | 779/779 | 2474/2474 | 1/1 | 0/0 | {"none":1} |
| document_rag_mixed | 1 | 4921/4921 | 1251/1251 | 862/862 | 2702/2702 | 1/1 | 0/0 | {"none":1} |
| document_rag_retry_probe | 1 | 3914/3914 | 1158/1158 | 758/758 | 1968/1968 | 1/1 | 0/0 | {"none":1} |

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

Summary: 32 passed, 1 failed.
