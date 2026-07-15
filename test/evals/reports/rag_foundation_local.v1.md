# RAG foundation local evaluation

Pipeline: `rag_foundation_v1`  
Corpus build: `86820ab67bab9ba229f08530`

| Metric | Status | Evidence |
| --- | --- | --- |
| required_corpus_source_coverage | pass | 21/21 |
| bilingual_required_file_pairing | pass | 10 en + 10 zh |
| protected_markdown_token_fidelity | pass | forbidden patterns=0 |
| active_chunks_embedding_freshness_parity | blocked | 569/572; Qwen key/cloud authorization required when incomplete |
| per_side_total_reps_fixture_confusion | pass | covered by deterministic Edge tests |
| catalog_snapshot_parity | pass | 57/57; verified by tool test |
| document_recall_precision_release_thresholds | pass | recall@3=1; precision@3=0.9744; critical top1=1 |
| openai_unavailable_ui_no_request | pass | covered by AI Chat and Food photo Flutter lifecycle tests |
| qwen_live_canaries | pass | 5/5; synthetic inputs only |
| edge_embedding_hybrid_latency_p95 | fail | 16602 ms / 1500 ms; samples=3 |

Fixture suites: 11; cases: 102.
