# FitLog Agent deterministic evaluation

Run `node tool/evals/run_rag_eval.mjs`. Fixtures contain no real user data or provider output. The report distinguishes deterministic local gates from cloud embedding, deployed Edge, and live-provider canaries; unavailable external gates are reported as blocked and never counted as passes.
