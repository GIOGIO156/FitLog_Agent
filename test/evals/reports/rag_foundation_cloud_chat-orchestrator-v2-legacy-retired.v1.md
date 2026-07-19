# RAG foundation cloud canary: chat-orchestrator-v2-legacy-retired

Target: `dyacqajcinjwrkbngeif`

Expected pipeline: `rag_foundation_v1`

Active build: `a33cf90c1adf71ec7d08113d`

Embedding: `text-embedding-v4` / 1536
Connect-level transport retries: 0

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_database_auto | pass | 6717 |  |
| qwen_chat_permission | pass | 5946 |  |
| qwen_chat_rag_boundary | pass | 5669 |  |
| qwen_food_text | pass | 6550 |  |
| qwen_chat_food_image_auto | pass | 10244 |  |
| qwen_chat_typed_clarification_created | pass | 927 |  |
| qwen_chat_typed_clarification_consumed | pass | 7460 |  |
| qwen_chat_typed_clarification_replay_idempotent | pass | 687 |  |
| qwen_chat_typed_clarification_state_resolved_once | pass | 555 |  |
| qwen_food_image | pass | 7194 |  |

## Retrieval

Source recall@3: 1 (13/13); source precision@3: 0.9487 (37/39); critical top-1: 1 (5/5); p50/p95: 9667/12507 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 630/1324 ms across 14 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Product.md | 12186 |
| product_en | pass | docs/en/Product.md<br>docs/en/Product.md<br>docs/en/Product.md | 8203 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 8864 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 11853 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/zh/AppGuide.md<br>docs/zh/Methodology.md | 9516 |
| algorithm_total_negative | pass | docs/zh/Algorithm.md<br>docs/zh/Methodology.md<br>docs/zh/AppGuide.md | 9667 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 8684 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 12288 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 9154 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 12322 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 8302 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 12507 |
| references_boundary | pass | docs/en/References.md<br>docs/en/References.md<br>docs/en/References.md | 9763 |
| no_answer_weather | pass |  | 9896 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| food_logging_no_document_rag | 1 | 8287/8287 | 0/0 | 0/0 | 6994/6994 | 1/1 | 0/0 | {"none":1} |
| workout_logging_no_document_rag | 1 | 6923/6923 | 3/3 | 0/0 | 6007/6007 | 1/1 | 0/0 | {"none":1} |
| structured_meal_context_no_document_rag | 1 | 5467/5467 | 104/104 | 0/0 | 4519/4519 | 1/1 | 0/0 | {"none":1} |
| model_planner_no_document_rag | 1 | 4963/4963 | 1/1 | 0/0 | 0/0 | 1/1 | 0/0 | {"none":1} |
| document_rag_zh | 1 | 6043/6043 | 1037/1037 | 704/704 | 4159/4159 | 1/1 | 0/0 | {"none":1} |
| document_rag_en | 1 | 4418/4418 | 630/630 | 266/266 | 2783/2783 | 1/1 | 0/0 | {"none":1} |
| document_rag_mixed | 1 | 5723/5723 | 1018/1018 | 665/665 | 3023/3023 | 1/1 | 0/0 | {"none":1} |
| document_rag_retry_probe | 1 | 4382/4382 | 1261/1261 | 864/864 | 2166/2166 | 1/1 | 0/0 | {"none":1} |

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
