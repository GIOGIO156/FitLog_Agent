# AGENTS.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

## FitLog Project Rules

- This is a Flutter + Dart FitLog_Agent project copied from FitLog Local.
- Treat the Local version as the product and algorithm baseline. Preserve current Local behavior unless the task explicitly asks to change it.
- Agent V1 may introduce backend, accounts, subscriptions, quota, server-managed model API keys, remote LLM calls, AI Gateway, AI request logs, AI chat history, and scoped RAG because those are explicit Agent-version goals.
- Do not add user-supplied model API keys unless explicitly requested; model API keys should be managed server-side.
- Do not turn FitLog_Agent into an unbounded cloud-sync platform unless explicitly requested. Cloud storage must have a stated product purpose, privacy boundary, and source-of-truth rule.
- User profile data may be cloud-stored for account, subscription, AI personalization, and context-building needs, but food/workout/weight history should not be fully cloud-synced by default in V1 unless the task explicitly asks for that scope.
- RAG in Agent V1 should be scoped: structured retrieval over local/service summaries and document retrieval are allowed; user-data vector databases, user embedding storage, semantic memory, GraphRAG, and open-ended autonomous Agent loops require explicit approval.
- Preserve SQLite migrations and additive compatibility.
- Do not merge gram_per_kg and energy_ratio logic.
- diet_goal_phase is the source of truth for cutting/bulking phase.
- In gram_per_kg mode, macros are primary and kcal target is auxiliary only.
- In energy_ratio mode, kcal target/intake/remaining is primary.
- AI must not silently modify diet goals, apply carb tapering, delete user records, or write official food/workout/profile data without user confirmation.
- AppGuide should treat the new AI navigation tab as the primary Agent entry. Apart from the Add Food photo-recognition path, other Agent workflows should be launched from the AI page unless a task explicitly changes that UX.
- After code changes, run:
  - flutter analyze
  - flutter test
- For audit/refactor tasks, report risks before modifying code.

## FitLog Design Documentation Rules

Design docs are maintained as finished source-of-truth documents, not as running notes.

Required structure:

```text
README.md
CHANGELOG.md
docs/
  en/
    Product.md
    AppGuide.md
    Methodology.md
    Algorithm.md
    Database.md
    AgentDesign.md
    References.md
  zh/
    Product.md
    AppGuide.md
    Methodology.md
    Algorithm.md
    Database.md
    AgentDesign.md
    References.md
```

File responsibilities:

- `README.md`: project face and quick-start overview. Keep Chinese first and English second in the same file because the project primarily serves Chinese users. The two language sections must match in facts, scope, commands, and links. Do not append date-based update sections.
- `CHANGELOG.md`: English only. Record dated changes under Added/Changed/Fixed/Validation style headings. State what changed, why it changed, and what problem it solved, but keep entries concise. Concise implementation details, engineering rationale, and complex bug/debugging lessons are allowed when they explain a shipped fix or help future maintainers diagnose similar failures. Do not store broad product design, architecture explanations, future notes, or agent memory here.
- `docs/en/Product.md` and `docs/zh/Product.md`: stable product design. Cover purpose, product principles, modules, workflows, UX behavior, implemented scope, non-goals, and code references. Do not write release notes here.
- `docs/en/AppGuide.md` and `docs/zh/AppGuide.md`: app-area guide. Explain what each app module does, how it works at a high level, and which design file to read for details. Keep it navigational; do not duplicate all Product/Algorithm/Database content.
- `docs/en/Methodology.md` and `docs/zh/Methodology.md`: user-facing method explanation. Explain why the app uses `energy_ratio`, `gram_per_kg`, carb cycling, carb tapering, net exercise calories, and strength calorie heuristics. Keep it understandable, evidence-aware, and honest about limitations.
- `docs/en/Algorithm.md` and `docs/zh/Algorithm.md`: stable algorithm design. Cover inputs, formulas, diet phase/mode/strategy separation, workout calorie logic, calibration, self-check, boundaries, and code references. Do not merge `gram_per_kg` and `energy_ratio`.
- `docs/en/Database.md` and `docs/zh/Database.md`: stable database design. Cover current schema version, additive migrations, tables, fields, runtime aggregates, data flows, export coverage, non-implemented storage capabilities, and code references. Preserve migration compatibility.
- `docs/en/AgentDesign.md` and `docs/zh/AgentDesign.md`: current AI/Agent boundary and Agent V1 design boundary. Distinguish implemented behavior from planned Agent V1 behavior. External AI prompt copy and JSON paste are not app-internal AI. Agent V1 AI Gateway, remote LLM calls, structured retrieval, document retrieval, request/response retention, cloud profile handling, and confirmation rules must be documented without claiming unimplemented features are already shipped.
- `docs/en/References.md` and `docs/zh/References.md`: evidence and citation boundaries. Keep reference IDs stable. Cite narrow claims only. Do not turn this file into a literature review or changelog.

Language and sync rules:

- `CHANGELOG.md` stays English only.
- `README.md` is bilingual in one file: Chinese first, English second, with matching content.
- All other design docs live in both `docs/en` and `docs/zh`; when one changes, update the other in the same task.
- Keep docs concise but complete: every important field, mode, formula, boundary, and non-goal must appear exactly where it belongs.
- New feature details should be integrated into the stable section they affect, not appended as "2026-xx update" blocks.
- Historical implementation details belong in `CHANGELOG.md`; durable design facts belong in `README.md` or `docs/*`.

Encoding and terminal-output rules:

- Markdown files are UTF-8.
- Treat all repository text files that may contain Chinese as UTF-8, including Markdown docs, README, Dart UI strings, localization files, prompt templates, and generated text fixtures.
- When inspecting Chinese-heavy files from PowerShell, prefer explicit UTF-8 reads such as `Get-Content -Encoding UTF8 -Path <file>`; do not rely on default terminal decoding to judge whether source text is corrupted.
- PowerShell or terminal output may display valid UTF-8 Chinese or symbols as mojibake. Do not treat terminal display mojibake as file corruption.
- Before changing text for suspected encoding issues, verify the actual file content by reading it as UTF-8, checking Unicode code points, or inspecting it in an editor that correctly renders UTF-8.
- Do not record a "garbled text fix" in `CHANGELOG.md` unless the source file or rendered app/docs are actually corrupted.
- Prefer ASCII punctuation in English docs when it does not reduce clarity; Chinese docs may use normal Chinese punctuation.
- For Chinese-heavy files or bilingual docs, first verify the real UTF-8 source content before editing; do not spend time "repairing" text based only on PowerShell or terminal mojibake.
- Keep edits small and surgical after encoding verification: apply the minimal patch, run a local targeted check when available, then run `flutter analyze`, `flutter test`, and build only after code changes are stable.

Validation for documentation-only changes:

- Confirm the required documentation tree exists.
- Run text searches for old root-level design docs, date-appended headings in stable docs, stale paths, and obvious replacement characters.
- Flutter analysis/tests are required after code changes; for documentation-only edits, do not run them unless the task also touched code.

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
