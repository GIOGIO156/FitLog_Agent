# FitLog RAG Reliability And Performance Optimization Report

## Document Control

| Item | Value |
| --- | --- |
| Purpose | Human-reviewed engineering evidence for the P0-P7 RAG reliability and performance optimization. |
| Audience | Product reviewers, AI/backend engineers, maintainers, and release reviewers. |
| Target environment | Supabase project `dyacqajcinjwrkbngeif`, Singapore region. |
| Runtime under review | `rag_foundation_v1`, Qwen generation, Qwen `text-embedding-v4` at 1,536 dimensions, one bounded Document RAG retry enabled. |
| Evidence class | Curated report backed by sanitized machine-readable canary and evaluation snapshots. |
| Architecture ownership | Current architecture remains owned by [RAGDesign.md](../en/RAGDesign.md) and [RAGDesign.md（中文）](../zh/RAGDesign.md); this report owns measured optimization evidence, not the stable design contract. |
| Raw evidence | [`test/evals/reports`](../../test/evals/reports/README.md). |
| Status | Normal release-set quality, retrieval latency, output, safety, privacy, compatibility, and stable-document cloud-refresh Gates pass. Stress latency and useful-retry sampling remain explicitly qualified below. |

## Executive Summary

The remediation began with a user-visible failure: ordinary FitLog document questions could spend 7-17 seconds in Context construction, while some Chinese Document RAG requests took more than 30 seconds end to end and still failed validation. Stage timing disproved the initial suspicion that client-to-Singapore distance or query embedding was the primary cause. The dominant costs were the old hybrid SQL/RPC execution shape, a second expensive retrieval after low-value rewrites, and Provider output correction.

The deployed solution changes the work performed, not the acceptance standard:

1. Indexed lexical candidates and Qwen query embedding run concurrently.
2. PostgreSQL v3 preserves global branch scores and ranks while evaluating a bounded candidate set and returning 30 final candidates to Edge reranking.
3. Complete, conflicting, unknown-identifier, and unchanged-rewrite cases stop before an unproductive second search.
4. Qwen receives only the selected output-family contract; prompt Context is compact, duplicate document summaries are removed, and output budgets are capability-specific.
5. Failed speed-only alternatives were rejected when they lowered retrieval quality.

The strongest same-scenario result is Chinese Document RAG:

- Context p95 fell from 16,600 ms to 1,015 ms, a 93.9% reduction and approximately 16.4x speedup.
- End-to-end p95 fell from 31,981 ms to 5,859 ms, an 81.7% reduction and approximately 5.5x speedup.
- Final success improved from 0/3 to 3/3.

The final release canary passed 28/28 checks. Retrieval recall@3 remained 100%, reviewed precision@3 was 97.44%, critical top-1 was 100%, and the final eight-workflow canary produced 8/8 first-pass-valid outputs with 0 correction attempts and 0 final failures. The result means every sampled workflow passed on its first Provider output; it does not mean all possible production requests have a measured 100% success rate.

## Scope And Non-Negotiable Gates

Optimization was not allowed to:

- lower recall@3 below 0.97, reviewed precision@3 below 0.85, or critical top-1 below 0.95;
- relax the normal Edge retrieval p95 limit of 1,500 ms or the conditional retry-increment p95 limit of 3,500 ms;
- disable `rag_foundation_v1` or `DOCUMENT_RAG_RETRY_ENABLED`;
- replace Qwen with another release dependency;
- weaken output validation, evidence grounding, authorization, source authority, or user confirmation;
- create embeddings for user food, workout, body, or other business records;
- introduce fabricated no-answer sources, unsupported official writes, cross-account access, raw-content observability leakage, or invalid artifact escape.

No runtime rollback, Provider switch, threshold relaxation, or retry disable was used to obtain the final result.

## Measurement Method And Evidence Provenance

### Metric Definitions

- **p50** is the median observed latency and represents a typical sampled request.
- **p95** is the slow-tail statistic used by the release Gate. With three samples it is effectively the slowest observation and must not be presented as a mature production SLA.
- **Context latency** covers authorized context construction, including Document RAG when requested.
- **End-to-end latency** covers external request time, including authentication, planning, Context, Provider generation/validation, persistence, and transport overhead.
- **First-pass valid** means the first Provider result passed structural, semantic, grounding, safety, and client-compatibility validation without correction.
- **Correction 0** means zero correction attempts were needed; it does not mean correction failed.

### Comparison Cohorts

| Evidence set | Diagnostic requests | Purpose |
| --- | ---: | --- |
| Baseline latency diagnostic | 15 | Establish pre-optimization stage latency, retry/correction probability, and failure modes. |
| Repeated text-budget canary | 9 | Three repetitions each for Chinese, English, and unknown-identifier Document paths after the output-budget fix. |
| Final release canary | 8 | One request for each final workflow category; combined with retrieval quality, Provider, access, and deployment checks for 28/28 total checks. |
| High-complexity stress probe | 3 | Test an eight-concept document request and attempt to obtain a genuine coverage-gain retry sample. |

The Chinese Context and end-to-end comparisons use the same scenario with 3 baseline and 3 final repetitions and are the strongest before/after evidence. Hybrid RPC and aggregate Provider comparisons use the same telemetry fields across different release query mixes; they are valid stage-level release comparisons but not isolated single-variable laboratory experiments. Each table states the applicable scope so the report does not overclaim causality or statistical confidence.

### Evidence Handling

Raw reports contain compact, privacy-safe metrics and identifiers. They do not retain full prompts, vectors, document excerpts, Provider output, secrets, authentication tokens, images, user business-history rows, or chain-of-thought. JSON files are the machine-readable record; same-name Markdown files are generated human-readable snapshots. Failed and rejected experiments remain in the evidence directory so later reviewers can reconstruct decisions rather than seeing only the winning result.

## Baseline: What Was Slow And Why

Baseline environment: `ai-chat-route` v34, `ai-food-photo-analyze` v20, active cloud corpus `b209353e25df637256a1825f` with 569 chunks from 21 stable sources, Qwen `text-embedding-v4` at 1,536 dimensions, foundation pipeline and bounded retry enabled.

### Baseline Stage Latency

| Path or stage | p50 | p95 | Diagnosis |
| --- | ---: | ---: | --- |
| Direct retrieval total | 6,612 ms | 11,132 ms | Normal retrieval Gate failed. |
| Query normalization | 1 ms | 5 ms | Negligible. |
| Query embedding | 368 ms | 5,005 ms | Usually secondary; one timeout used lexical failover. |
| Hybrid RPC | 5,909 ms | 8,200 ms | Primary direct-retrieval bottleneck. |
| Local reranker | 0 ms | 2 ms | Negligible. |
| Chinese Document Context | 16,395 ms | 16,600 ms | All three samples retried. |
| Rewrite planner | 2,575 ms | 2,677 ms | Material retry cost. |
| Retry embedding | 195 ms | 382 ms | Secondary retry cost. |
| Retry hybrid RPC | 2,981 ms | 6,599 ms | Primary retry cost. |
| Provider first pass | 3,757 ms | 7,923 ms | Dominant after Context became available. |
| Provider correction | 3,100 ms | 6,651 ms | High-cost recovery that could still fail. |
| Transport/startup/persistence remainder | about 0.5-0.8 s | no more than 0.91 s | Visible, but too small to explain the measured delay. |

### Baseline Reliability

| Capability | Samples | Result |
| --- | ---: | --- |
| Non-Document paths | 9 | Query embedding correctly remained `not_requested`. |
| Document paths | 6 | Query embedding completed, but all six requests entered retry. |
| Retrieval retry | 6 | Three gained coverage; three produced no gain. |
| Workout Logging | 3 | All entered correction; 2/3 final success. |
| Meal Context | 3 | All entered correction; 1/3 final success. |
| Chinese Document answer | 3 | 0/3 final success after grounding correction. |
| Unknown/no-answer probe | 3 | 1/3 final success; two failed grounding. |

### Measured Root Causes

1. The old hybrid SQL/RPC evaluated expensive term, full-text, trigram, vector, matched-term, and global-ranking expressions over too much of the active corpus before bounding work.
2. Retry repeated that expensive retrieval and added a Qwen rewrite planner. Half of the measured retries produced no coverage gain.
3. Qwen frequently selected or claimed the wrong output family, so correction added 3.1-6.7 seconds without guaranteeing a valid result.
4. Query embedding was normally below one second and therefore was not the cause of the recurring 7-17 second Context delay.
5. Client-to-Singapore transport contributed less than the server-side SQL, retry, and generation stages and was not the primary root cause.

Baseline evidence: [Markdown](../../test/evals/reports/rag_foundation_cloud_latency_diagnostic_verified.v1.md) and [JSON](../../test/evals/reports/rag_foundation_cloud_latency_diagnostic_verified.v1.json).

## Engineering Changes And Causal Intent

### P1: Observability Before Optimization

The Gateway now separates normalization, embedding, lexical-candidate RPC, final hybrid RPC, reranking, rewrite planning, retry retrieval, Provider first pass, validation, correction, and persistence. It records first coverage, retry decision, query change, coverage gain, first validation, correction recovery, and final failure without retaining raw user or Provider content. This made the later SQL, retry, and output conclusions measurable rather than inferred.

### P2: Indexed Candidate Retrieval

Migration `202607150003_rag_hybrid_indexed_candidates.sql` adds generated `search_tsv`, a GIN index, and bounded indexed candidate retrieval. The v2 canary reduced direct hybrid RPC p50/p95 from 5,909/8,200 ms to 884/1,480 ms while retaining recall@3 100%, precision@3 94.87%, and critical top-1 100%.

### P3: Retry Only When It Can Change The Answer

Coverage recognizes official concepts and reviewed aliases. Complete or conflicting coverage, an unknown exact technical identifier, and a materially unchanged normalized rewrite all stop before a second search. One bounded retry remains available for genuine missing evidence, with a hard maximum of two searches and an independent output-correction counter.

### P4: First-Pass Output Reliability

Qwen receives only the selected output-family contract and a final exact-family reminder. OpenAI strict schemas are narrowed equivalently while the OpenAI adapter/tests remain available but are not a release dependency. Workout intent no longer gets forced into ordinary text, and text Context no longer advertises draft creation. These changes target `output_type_mismatch`, false draft-success claims, and grounding correction rather than masking invalid results.

### P5: Production-Safe Parallelism And Prompt Budget

Migration `202607150004_rag_parallel_candidate_fusion.sql` and the production v3 path start indexed lexical candidate collection and Qwen query embedding concurrently. PostgreSQL still computes the original global scores and ranks, fuses the bounded set, and returns 30 final candidates for Edge reranking. Subscription/device checks run concurrently, controlled Context is compactly serialized without a duplicate document summary, and the logged Context byte count reflects the actual Provider prompt.

Qwen maximum output budgets are:

| Capability | Maximum output tokens |
| --- | ---: |
| Chat text | 384 |
| Chat draft or auto | 1,600 |
| Dedicated Food analysis | 1,200 |

The budget limits cost and tail latency; it does not permit partial artifacts. `finish_reason=length` remains `provider_incomplete`.

## Rejected Alternatives And Quality Protection

| Alternative | Performance intent | Observed quality | Decision |
| --- | --- | --- | --- |
| Simplified parallel lexical/vector fusion in Edge | Avoid final global SQL ranking. | recall@3 84.62%, precision@3 84.21%, critical top-1 80%. | Rejected; it violated recall and top-1 Gates. |
| v3 with 24 final candidates | Reduce final work and payload. | Passed minimum thresholds but precision fell to 89.74%, versus 94.87% for 30 candidates in the paired A/B. | Rejected for production; 30 candidates retained. |
| Short timeout as the primary fix | Hide slow embedding/RPC work. | Would convert measured latency into failures and unobservable downgrade. | Rejected; the work shape was optimized instead. |
| Disable retry or revert to legacy | Remove retry cost. | Would reduce confirmed functionality and violate the locked release decision. | Rejected; retry remains enabled with evidence-based stop rules. |

These rejected experiments are central evidence: the final result is not a speed-only configuration that trades away retrieval quality.

## Measured Outcome

### Before/After Performance

| Measurement | Before | After | Improvement | Comparison note |
| --- | ---: | ---: | ---: | --- |
| Edge initial Hybrid RPC p50 | 973 ms | 330 ms | 66.1% lower; 2.95x faster | Same telemetry stage; baseline 6 document requests, final 4 document requests with a different query mix. |
| Edge initial Hybrid RPC p95 | 6,324 ms | 491 ms | 92.2% lower; 12.9x faster | Same stage-level qualification as above. |
| Chinese Document Context p50 | 16,395 ms | 925 ms | 94.4% lower; 17.7x faster | Same Chinese scenario, 3 baseline vs 3 final repetitions. |
| Chinese Document Context p95 | 16,600 ms | 1,015 ms | 93.9% lower; 16.4x faster | Same Chinese scenario, 3 baseline vs 3 final repetitions. |
| Chinese Document RAG end-to-end p50 | 30,978 ms | 3,925 ms | 87.3% lower; 7.9x faster | Same scenario and sample count; baseline requests ultimately failed, final requests succeeded. |
| Chinese Document RAG end-to-end p95 | 31,981 ms | 5,859 ms | 81.7% lower; 5.5x faster | Same scenario and sample count; p95 is the maximum-like value of three samples. |
| Provider first-pass p50 | 3,757 ms | 2,980 ms | 20.7% lower; 1.26x faster | Aggregate baseline 15 vs final 8 workflows; directional release comparison, not isolated Provider A/B. |
| Provider first-pass p95 | 7,923 ms | 4,577 ms | 42.2% lower; 1.73x faster | Same aggregate-comparison qualification as above. |

Query embedding improved only modestly in the repeated Chinese scenario: p50 fell from 716 to 598 ms and p95 from 822 to 654 ms. This confirms that embedding was a secondary cost and that the largest improvement came from hybrid SQL shape, retry elimination, and first-pass output reliability.

### Reliability And Quality

| Measure | Baseline | Final evidence | Interpretation |
| --- | --- | --- | --- |
| Chinese Document final success | 0/3 | 3/3 | Faster Context also became usable and grounded. |
| Workout Logging | 2/3 final success; 3/3 correction | 1/1 first-pass success in final workflow canary | Directionally fixed; final workflow sample is small. |
| Meal Context | 1/3 final success; 3/3 correction | 1/1 first-pass success in final workflow canary | Directionally fixed; final workflow sample is small. |
| Final workflow first-pass validation | Not achieved | 8/8 | Eight sampled workflow categories passed the first Provider result. |
| Final workflow correction | Frequent in affected paths | 0/8 | No sampled workflow needed the 3.1-6.7 second recovery stage. |
| Final workflow validation failure | Present | 0/8 | No sampled final workflow escaped or exhausted validation. |
| Retrieval recall@3 | 100% (13/13) | 100% (13/13) | Speed did not reduce expected-source recall. |
| Reviewed precision@3 | 97.44% (38/39) | 97.44% (38/39) | Final precision was preserved. |
| Critical top-1 | 100% (5/5) | 100% (5/5) | Critical owning sources remained first. |
| Fabricated no-answer source | 0 | 0 | Fail-closed behavior remained intact. |

The repeated text-budget canary ran Chinese, English, and unknown-identifier Document paths three times each. All were 3/3 first-pass valid with zero correction and zero retrieval retry. The final all-workflow canary passed 28/28 combined checks and 8/8 diagnostic workflow requests.

## Why The Optimization Worked

The result is causally consistent with the measured bottlenecks:

```text
Full-corpus multi-branch scoring
  -> indexed lexical candidates + bounded vector candidates
  -> global ranking retained inside PostgreSQL
  -> Hybrid RPC p95 6,324 ms -> 491 ms

Embedding followed by database retrieval
  -> independent lexical candidate and embedding work runs concurrently
  -> the first phase approaches max(branch latency), not their sum

Incomplete/unknown query -> model rewrite -> second expensive retrieval
  -> complete/conflict/unknown/no-change stop policy
  -> no-gain retry disappears from the final release set

Broad output contract -> wrong family -> correction
  -> selected-family contract + compact Context + bounded output
  -> final first-pass 8/8, correction 0/8
```

The remediation was effective because it removed expensive unnecessary work at the stages where timing showed it occurred. It did not attempt to hide latency with shorter timeouts, blame geography without evidence, or replace quality controls with permissive success handling.

## Bottleneck Shift

Before remediation, Context construction was commonly the dominant stage and could exceed 16 seconds. After remediation, normal Document retrieval is usually approximately 0.9-1.3 seconds. The dominant remaining time is now Qwen generation:

- repeated Chinese Document Provider p95: 3,686 ms;
- repeated English Document Provider p95: 4,235 ms;
- repeated unknown-identifier Provider p95: 4,792 ms;
- transport, startup, authentication, and persistence commonly add about 0.5-1.0 seconds.

As a result, full Document answers still commonly take roughly 3.9-6.7 seconds even though retrieval itself is near one second. Further user-visible latency work should therefore measure Provider generation, deterministic routing, response length, and transport separately rather than continuing to treat embedding or the database as the assumed primary bottleneck.

## Residual Risks And Evidence Limits

| Item | Current evidence | Status |
| --- | --- | --- |
| Normal Edge retrieval Gate | Repeated p95 1,299 ms over 12 Edge retrieval samples; final release p95 1,250 ms over 11 samples. | Pass on the defined release sets. |
| Eight-concept stress query | First retrieval complete 3/3; Context p95 1,566 ms and combined Edge sample p95 1,669 ms. | Open performance observation; not hidden by normal-set results. |
| Useful-retry increment | Current Chinese/English/mixed/stress requests were first-retrieval complete; unknown identifier stopped deterministically. No current request produced a genuine coverage-gain retry. | Live p95 not sampled and not claimed as passed. Deterministic coverage-gain path remains tested. |
| Sample size | Final workflow canary has one request per category; repeated Document canary has three per language/path. | Adequate for release evidence, insufficient for a long-term production SLA claim. |
| Query embedding availability | One direct-runner timeout used lexical failover; normal Edge samples completed. | Failover works; continued monitoring required. |
| Stable-document cloud parity | Build `99d908c576c844fd3c39d853` has 577 chunks from 21 sources with 577/577 local and cloud parity, zero stale/extra/missing local vectors, and zero cloud hash/vector metadata mismatches. | Pass after explicit document-egress authorization and atomic activation. |

The report intentionally distinguishes a release-set pass from a universal performance guarantee. Broader production claims require a larger versioned sample, repeated time windows, and an observed useful-retry cohort.

## Deployment And Validation Record

| Area | Verified state |
| --- | --- |
| Supabase project | `dyacqajcinjwrkbngeif` |
| Edge Functions | `ai-chat-route` v44; `ai-food-photo-analyze` v21 |
| Runtime flags | `AI_CONTEXT_PIPELINE_VERSION=rag_foundation_v1`; `DOCUMENT_RAG_RETRY_ENABLED=true` |
| Generation/embedding | Qwen generation; Qwen `text-embedding-v4`, 1,536 dimensions |
| OpenAI | Adapter and deterministic tests retained; no remote secret and no current RAG/release dependency |
| Applied RAG migrations | `202607130001` through `202607130003`; `202607150001` through `202607150004` |
| Active cloud corpus | `99d908c576c844fd3c39d853`, 577/577 vectors, 21 stable sources, zero cloud mismatches |
| Refresh canary | First run 25/26 due to one transient 1,991 ms Edge p95 miss; independent recheck 26/26 with Edge retrieval p50/p95 1,217/1,438 ms, 13/13 recall@3, 97.44% reviewed precision@3, 5/5 critical top-1, and zero embedding fallbacks |
| Required Edge tests | 61/61 passed |
| Full Edge suite | 130/130 passed |
| Node corpus/docs suite | 20/20 passed |
| Flutter tests | 223/223 passed |
| Static analysis | `flutter analyze` reported no issues |
| Build | Configured split debug APKs built for `armeabi-v7a`, `arm64-v8a`, and `x86_64` |
| Diff/document checks | `git diff --check`, bilingual outline/link, stale-heading, UTF-8, and corpus validation passed |

## Gate Summary

| Gate | Result | Evidence |
| --- | --- | --- |
| Retrieval quality | Pass | recall@3 100%, reviewed precision@3 97.44%, critical top-1 100%, fabricated no-answer source 0. |
| Normal Edge retrieval p95 <= 1,500 ms | Pass on release sets | 1,299 ms repeated and 1,250 ms final. |
| Retry increment p95 <= 3,500 ms | Not sampled in current useful-retry cohort | No current genuine useful retry occurred; no numeric claim is made. |
| First-pass output reliability | Pass on release set | 8/8 first-pass valid, correction 0/8, final failure 0/8; repeated Document paths 3/3 each. |
| Safety/privacy/access | Pass | Anonymous and two-account table/admin-RPC probes denied; official write, user embedding, raw-content logging, fabricated source, and invalid artifact escape remained zero. |
| Deployment/compatibility | Pass | Remote migrations aligned, Edge versions active, foundation/retry enabled, legacy rollback compatibility retained. |
| Stable-document cloud refresh | Pass | Explicitly authorized build `99d908c576c844fd3c39d853` is active with 577/577 local/cloud parity and a 26/26 independent refresh canary. |

## Conclusion

This remediation converted RAG retrieval from the dominant latency and reliability failure into a bounded, quality-preserving stage. The strongest result is not only a 16.4x Chinese Context p95 speedup, but the simultaneous change from 0/3 to 3/3 grounded Chinese Document success while recall, precision, top-1 accuracy, safety, privacy, and confirmation boundaries remained intact.

The engineering lesson is specific: measure the whole request by stage, optimize the actual expensive work, and reject faster designs that weaken evidence quality. Indexed candidates, concurrency, preserved global ranking, evidence-aware retry stops, and first-pass output contracts addressed the measured SQL, retry, and correction costs. The remaining latency is primarily Provider generation and should be treated as the next independently measured optimization domain.

## Evidence Index

### Primary Before/After Evidence

- Baseline root-cause diagnostic: [Markdown](../../test/evals/reports/rag_foundation_cloud_latency_diagnostic_verified.v1.md) / [JSON](../../test/evals/reports/rag_foundation_cloud_latency_diagnostic_verified.v1.json)
- Repeated post-budget validation: [Markdown](../../test/evals/reports/rag_foundation_cloud_p6_text_budget.v1.md) / [JSON](../../test/evals/reports/rag_foundation_cloud_p6_text_budget.v1.json)
- Final all-workflow release canary: [Markdown](../../test/evals/reports/rag_foundation_cloud_p6_release.v1.md) / [JSON](../../test/evals/reports/rag_foundation_cloud_p6_release.v1.json)
- Stress/useful-retry sampling: [Markdown](../../test/evals/reports/rag_foundation_cloud_p6_useful_retry.v1.md) / [JSON](../../test/evals/reports/rag_foundation_cloud_p6_useful_retry.v1.json)
- Corpus-refresh first sample (one transient latency miss): [Markdown](../../test/evals/reports/rag_foundation_cloud_corpus-refresh-20260715.v1.md) / [JSON](../../test/evals/reports/rag_foundation_cloud_corpus-refresh-20260715.v1.json)
- Corpus-refresh independent passing recheck: [Markdown](../../test/evals/reports/rag_foundation_cloud_corpus-refresh-recheck-20260715.v1.md) / [JSON](../../test/evals/reports/rag_foundation_cloud_corpus-refresh-recheck-20260715.v1.json)

### Design-Decision Evidence

- Indexed v2 and 36-candidate evaluation: [v2](../../test/evals/reports/rag_foundation_cloud_p2_indexed_v2.v1.md) / [c36](../../test/evals/reports/rag_foundation_cloud_p2_indexed_v2_c36.v1.md)
- Retry behavior: [P3 final](../../test/evals/reports/rag_foundation_cloud_p3_retry_final.v1.md)
- First-pass output: [P4 final](../../test/evals/reports/rag_foundation_cloud_p4_first_pass_final.v1.md)
- Rejected simplified parallel retrieval: [P5 parallel retrieval](../../test/evals/reports/rag_foundation_cloud_p5_parallel_retrieval.v1.md)
- Candidate-count A/B: [24 candidates](../../test/evals/reports/rag_foundation_cloud_p5_v3_c24_ab.v1.md) / [30 candidates](../../test/evals/reports/rag_foundation_cloud_p5_v3_c30_ab.v1.md)
- Production v3 final: [P5 final](../../test/evals/reports/rag_foundation_cloud_p5_final.v1.md)

### Final Engineering Record And Stable Contracts

- [Consolidated Phase 5 AI/RAG scope, deployment, rollback, and engineering record](../history/phase5/PHASE5_AI_RAG_FINAL_ENGINEERING_RECORD.md)
- [Current RAG architecture](../en/RAGDesign.md) / [当前 RAG 架构](../zh/RAGDesign.md)
- [Current output contract](../en/AIOutputContract.md) / [当前输出协议](../zh/AIOutputContract.md)
