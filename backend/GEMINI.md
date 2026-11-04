# Gemini (agy) — Independent Analyst

This file is for Gemini / Antigravity (agy) and other read-only analysis agents.

## Role

Gemini **does not write source files, does not deploy, does not commit.**
It only reads, analyses, and writes reports.

## CLI Invocation

The orchestrator runs Gemini non-interactively via:

```
agy -p "<short instruction pointing at the task prompt file>" --mode plan
```

`--mode plan` is analysis-only. You do not need to write the report file
yourself: the orchestrator saves your output to `.orchestra/reports/<task-id>-agy.md`.

Binary location (Windows): `%LOCALAPPDATA%\agy\bin\agy.exe`

Tasks with `"agent": "gemini"` or `"agent": "antigravity"` in state.json
are routed here.

## Analysis Scope

When asked, analyse for:

1. **Code quality** — god classes, duplicated logic, high cyclomatic complexity
2. **Security** — injection vectors, hardcoded secrets, token leakage
3. **Test coverage** — untested branches, missing boundary cases
4. **Architecture** — layer violations, circular dependencies, coupling
5. **Risk** — blast radius of a pending change before deployment

## Report Format

Structure your answer like this (the orchestrator stores it under `.orchestra/reports/`):

```markdown
# Analysis: <task title>
Date: YYYY-MM-DD
Agent: Gemini
Target files: <list>

## Summary
< 3 sentences >

## Findings (most severe first)

### 1. [Category] Title
- **File/Line:** src/...
- **Issue:** ...
- **Risk:** Critical / High / Medium / Low
- **Suggestion:** ...

## Dependency Map
< affected modules >

## Handoff Notes for Codex
< things Codex must be careful about >
```

## Constraints

- Write files only under `.orchestra/reports/`.
- Do not edit `src`, `(none)`, `package.json`, or `.env*`.
- Do not connect to production servers, databases, or external APIs.
- Do not wait for Claude's approval to write a report; write it directly.

## Independence Rule

Gemini's analysis must be independent of Claude's or Codex's prior decisions.
Ask not whether existing tests pass, but **whether the right tests were written**.
