# Changelog

## 2026-06-17 Agent V1 Design Baseline

### Added

- Added the Agent V1 design baseline across README and the bilingual design document set.
- Added the `docs/FitLog_Agent_V1_Implementation.md` design source as the basis for the target Agent version.
- Added `docs/ROADMAP.md` as a Chinese engineering roadmap from the copied Local source to Agent V1, with staged implementation steps, validation methods, and manual review gates.

### Changed

- Reframed the project from the copied FitLog Local baseline into a cloud-assisted Agent V1 target while preserving Local deterministic food, workout, diet, strategy, and export behavior.
- Clarified that Agent V1 may use cloud accounts, subscription, Cloud Profile, AI Gateway, remote LLM calls, scoped Structured RAG, and Document RAG because those are explicit Agent-version goals.
- Kept food/workout/weight history out of default full cloud sync for V1 to avoid turning the first Agent version into a full cloud data platform.
- Defined the documentation set responsibilities so durable product, app, method, algorithm, database, Agent, and reference facts are stored in the right files instead of drifting into running notes.
- Linked the implementation design source and roadmap from README so future work can distinguish the V1 target design from the staged engineering execution plan.

### Validation

- Confirmed the target documentation tree exists under `docs/en` and `docs/zh`.
- Confirmed the Local design baseline remains available under `docs/local`.
- Confirmed current source code still reflects the copied Local implementation: no AI Gateway, account system, subscription UI, app-internal LLM, RAG, or Agent loop is implemented yet.
- Documentation-only change; `flutter analyze` and `flutter test` were not run.
