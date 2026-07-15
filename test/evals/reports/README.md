# RAG Evaluation Evidence Directory

This directory stores generated, sanitized evaluation evidence. The curated human-reviewed report lives at [docs/reports/RAG_RELIABILITY_OPTIMIZATION_REPORT.md](../../../docs/reports/RAG_RELIABILITY_OPTIMIZATION_REPORT.md).

## File Contract

Reports normally appear as same-name pairs:

- `.json` is the machine-readable source containing checks, sample counts, stage latency, retrieval quality, retry/correction outcomes, error classes, and Gate results.
- `.md` is the generated human-readable snapshot of the same run.
- `.v1` identifies the report schema version; it is not an Edge Function, model, or product version.

Generated snapshots are evidence, not stable architecture documents and not App runtime inputs. Do not hand-edit them to change a result. Failed, superseded, and rejected experiments remain intentionally so reviewers can reconstruct the baseline, diagnosis, design tradeoffs, and final decision.

## Reading Order

1. Read the [curated optimization report](../../../docs/reports/RAG_RELIABILITY_OPTIMIZATION_REPORT.md).
2. Inspect `rag_foundation_cloud_latency_diagnostic_verified.v1.md` for the baseline root cause.
3. Inspect `rag_foundation_cloud_p6_text_budget.v1.md` for repeated post-fix Document results.
4. Inspect `rag_foundation_cloud_p6_release.v1.md` for the final all-workflow canary.
5. Inspect `rag_foundation_cloud_p6_useful_retry.v1.md` for stress and unsampled useful-retry evidence.
6. Inspect `rag_foundation_cloud_corpus-refresh-recheck-20260715.v1.md` for the passing 577-chunk cloud-refresh verification; the adjacent non-recheck report preserves the first transient latency miss.
7. Use adjacent JSON only when exact samples or automated comparison are required.

## Name Groups

| Group | Purpose |
| --- | --- |
| `rag_foundation_local` | Local deterministic evaluation. |
| `pre_activation*` | Cloud state before runtime activation. |
| `latency_diagnostic*` | Baseline stage timing and failure/root-cause evidence. |
| `p2_*` | Indexed SQL and candidate-count experiments. |
| `p3_*` | Retry trigger, stop, and coverage-gain behavior. |
| `p4_*` | First-pass output-family and grounding reliability. |
| `p5_*` | Parallelism, rejected fusion, candidate A/B, and production v3 evidence. |
| `p6_full` | Full workflow run that exposed long Qwen text generation. |
| `p6_text_budget` | Repeated validation after the text-output budget fix. |
| `p6_release` | Final release canary. |
| `p6_useful_retry` | High-complexity stress and useful-retry sampling attempt. |
| `corpus-refresh*` | Stable-document embedding, activation, runtime-build, retrieval, and access revalidation. |
| `final*` / `closure*` | Earlier remediation closure snapshots retained for audit history. |

Reports are designed not to store full prompts, vectors, excerpts, Provider output, secrets, tokens, images, raw user business history, or chain-of-thought. Review newly added evidence for privacy and size before committing it.
