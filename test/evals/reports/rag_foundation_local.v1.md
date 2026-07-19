# RAG and Chat orchestration local evaluation

Pipeline: `rag_foundation_v1+chat_decision.v2`
Corpus build: `0fc1fdfe9be09ac849bbb8a6`

## Fixture execution

| Suite | Status | Declared | Executed | Passed | Failed | Skipped |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| ai_chat_behavior_parity_v2 | pass | 8 | 8 | 8 | 0 | 0 |
| document_retrieval | pass | 14 | 14 | 14 | 0 | 0 |
| exercise_context | pass | 7 | 7 | 7 | 0 | 0 |
| failure_retry | pass | 6 | 6 | 6 | 0 | 0 |
| first_pass_reliability | pass | 40 | 40 | 40 | 0 | 0 |
| food_capability | pass | 5 | 5 | 5 | 0 | 0 |
| grounded_output | pass | 4 | 4 | 4 | 0 | 0 |
| provider_canary | blocked | 4 | 2 | 2 | 0 | 2 |
| provider_parity | pass | 4 | 4 | 4 | 0 | 0 |
| safety_privacy | pass | 7 | 7 | 7 | 0 | 0 |
| structured_context | pass | 5 | 5 | 5 | 0 | 0 |
| task_planning | pass | 6 | 6 | 6 | 0 | 0 |

## Release checks

| Metric | Status | Evidence |
| --- | --- | --- |
| required_corpus_source_coverage | pass | 21/21 unique manifest sources |
| bilingual_required_file_pairing | pass | 10 en + 10 zh |
| protected_markdown_token_fidelity | pass | forbidden patterns=0 |
| active_chunks_embedding_freshness_parity | blocked | 586/613; external embedding authorization required when incomplete |
| fixture_executor_registry_complete | pass | 12/12 suites registered |
| fixture_executors_passed | pass | 108 local cases executed |
| document_recall_precision_release_thresholds | pass | recall@3=1; precision@3=0.9487; critical top1=1 |
| provider_live_canaries | pass | 10/10; synthetic inputs only |
| edge_embedding_hybrid_latency_p95 | pass | 1324 ms / 1500 ms; samples=14 |
