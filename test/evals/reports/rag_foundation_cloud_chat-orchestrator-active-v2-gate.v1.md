# RAG foundation cloud canary: chat-orchestrator-active-v2-gate

Target: `dyacqajcinjwrkbngeif`

Expected pipeline: `rag_foundation_v1`

Active build: `a33cf90c1adf71ec7d08113d`

Embedding: `text-embedding-v4` / 1536
Connect-level transport retries: 0

## Provider canaries

| Check | Status | Latency (ms) | Error |
| --- | --- | ---: | --- |
| qwen_chat_database_auto | pass | 5782 |  |
| qwen_chat_permission | pass | 6013 |  |
| qwen_chat_rag_boundary | pass | 4313 |  |
| qwen_food_text | pass | 4714 |  |
| qwen_chat_food_image_auto | pass | 10578 |  |
| qwen_chat_typed_clarification_created | pass | 1432 |  |
| qwen_chat_typed_clarification_consumed | pass | 13044 |  |
| qwen_chat_typed_clarification_replay_idempotent | pass | 631 |  |
| qwen_chat_typed_clarification_state_resolved_once | pass | 210 |  |
| qwen_food_image | pass | 7721 |  |

## Retrieval

Source recall@3: 1 (13/13); source precision@3: 1 (39/39); critical top-1: 1 (5/5); p50/p95: 7031/8417 ms.

The direct-runner latency includes the test machine's route to both Qwen and Supabase. The production Edge sample is the release latency gate: p50/p95 1181/1263 ms across 7 requests.

| Case | Status | Top-3 sources | Latency (ms) |
| --- | --- | --- | ---: |
| product_zh | pass | docs/zh/Product.md<br>docs/zh/Product.md<br>docs/zh/Product.md | 7612 |
| product_en | pass | docs/en/Product.md<br>docs/en/Product.md<br>docs/en/Product.md | 3000 |
| app_guide_mixed | pass | docs/zh/AppGuide.md<br>docs/zh/AppGuide.md<br>docs/zh/AppGuide.md | 3731 |
| method_energy | pass | docs/zh/Methodology.md<br>docs/zh/Methodology.md<br>docs/zh/Methodology.md | 7734 |
| algorithm_per_side | pass | docs/zh/Algorithm.md<br>docs/zh/Algorithm.md<br>docs/zh/AppGuide.md | 8417 |
| algorithm_total_negative | pass | docs/zh/Algorithm.md<br>docs/zh/Database.md<br>docs/zh/Methodology.md | 7853 |
| database_snapshot | pass | docs/en/AppGuide.md<br>docs/en/Database.md<br>docs/en/Database.md | 3895 |
| cloud_local_zh | pass | docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md<br>docs/zh/CloudLocalDataBoundary.md | 7652 |
| cloud_local_en | pass | docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md<br>docs/en/CloudLocalDataBoundary.md | 4329 |
| agent_permission | pass | docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md<br>docs/zh/AgentDesign.md | 7774 |
| output_contract | pass | docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md<br>docs/en/AIOutputContract.md | 3601 |
| rag_boundary | pass | docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md<br>docs/zh/RAGDesign.md | 7387 |
| references_boundary | pass | docs/en/References.md<br>docs/en/References.md<br>docs/en/Methodology.md | 4738 |
| no_answer_weather | pass |  | 7031 |

## Per-stage latency diagnostic

| Scenario | N | External p50/p95 | Context p50/p95 | Embedding p50/p95 | Provider p50/p95 | First-pass valid | Retry/gain | Errors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| model_planner_no_document_rag | 1 | 4658/4658 | 1/1 | 0/0 | 0/0 | 1/1 | 0/0 | {"none":1} |

Embedding states: `{"not_requested":1}`; retry requests: 0; matched logs: 1/1.

## Access control

| Principal | Operation | Status | HTTP |
| --- | --- | --- | ---: |
| anon | document_chunks_read | pass | 401 |
| anon | corpus_admin_rpc | pass | 401 |
| user_a | document_chunks_read | pass | 403 |
| user_a | corpus_admin_rpc | pass | 403 |
| user_b | document_chunks_read | pass | 403 |
| user_b | corpus_admin_rpc | pass | 403 |

Summary: 29 passed, 0 failed.
