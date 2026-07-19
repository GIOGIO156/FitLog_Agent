# RAG foundation cloud canary: chat-orchestrator-rollback-legacy-rehearsal

Target: `dyacqajcinjwrkbngeif`

Expected pipeline: `rag_foundation_v1`

Active build: `a33cf90c1adf71ec7d08113d`

Embedding: `text-embedding-v4` / 1536
Connect-level transport retries: 0

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_database_auto | pass | 7936 |  |
| qwen_chat_permission | fail | 4669 |  |
| qwen_chat_rag_boundary | fail | 4227 |  |
| qwen_food_text | pass | 5402 |  |
| qwen_chat_food_image_auto | fail | 1332 |  |
| qwen_chat_typed_clarification_created | fail | 980 |  |
| qwen_chat_typed_clarification_consumed | fail | 0 | clarification_origin_invalid |
| qwen_chat_typed_clarification_replay_idempotent | fail | 0 | clarification_origin_invalid |
| qwen_chat_typed_clarification_state_resolved_once | fail | 0 |  |
| qwen_food_image | pass | 7036 |  |

## Retrieval

Source recall@3: 1 (13/13); source precision@3: 1 (39/39); critical top-1: 1 (5/5); p50/p95: 7504/36193 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 3/2727 ms across 13 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Product.md | 8863 |
| product_en | pass | docs/en/Product.md<br>docs/en/Product.md<br>docs/en/Product.md | 3545 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 4522 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 8733 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/zh/Algorithm.md<br>docs/zh/AppGuide.md | 7751 |
| algorithm_total_negative | pass | docs/zh/Algorithm.md<br>docs/zh/Database.md<br>docs/zh/Methodology.md | 7504 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 4048 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 7872 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 4618 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 8096 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 4752 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 36193 |
| references_boundary | pass | docs/en/References.md<br>docs/en/References.md<br>docs/en/Methodology.md | 5639 |
| no_answer_weather | pass |  | 9309 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| food_logging_no_document_rag | 1 | 7578/7578 | 0/0 | 0/0 | 6220/6220 | 1/1 | 0/0 | {"none":1} |
| workout_logging_no_document_rag | 1 | 6400/6400 | 3/3 | 0/0 | 4973/4973 | 1/1 | 0/0 | {"none":1} |
| structured_meal_context_no_document_rag | 1 | 6866/6866 | 98/98 | 0/0 | 5623/5623 | 1/1 | 0/0 | {"none":1} |
| model_planner_no_document_rag | 1 | 4540/4540 | 0/0 | 0/0 | 0/0 | 1/1 | 0/0 | {"none":1} |
| document_rag_zh | 1 | 6125/6125 | 907/907 | 555/555 | 3815/3815 | 1/1 | 0/0 | {"none":1} |
| document_rag_en | 1 | 4113/4113 | 640/640 | 256/256 | 2426/2426 | 1/1 | 0/0 | {"none":1} |
| document_rag_mixed | 1 | 6167/6167 | 1388/1388 | 878/878 | 2925/2925 | 1/1 | 0/0 | {"none":1} |
| document_rag_retry_probe | 1 | 4979/4979 | 1297/1297 | 883/883 | 2363/2363 | 1/1 | 0/0 | {"none":1} |

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

Summary: 25 passed, 8 failed.
