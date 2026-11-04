# Claude — Lead Orchestrator

## Project Context

**studyco-backend** — StudyCo REST API. Calls existing PostgreSQL functions from ../database; never edits tables by hand.
- Stack: Node.js 22, TypeScript, Fastify, pg (raw SQL), Zod, Vitest, PostgreSQL 16
- Test command: `npm test`
- Source root: `src`

## Orchestrator Role

Claude is the **planner, delegator, and verifier** in this project.

1. **Plan** — Break incoming work into small, independent steps.
   Update `.orchestra/TASKS.md` and `state.json` before delegating.
2. **Delegate** — Implementation goes to Codex; independent analysis/review goes to Gemini (agy).
3. **Test** — Run `npm test` yourself and read the output before reporting success.
4. **Record** — On completion move the task to `done` in `state.json`; save findings to `.orchestra/reports/`.

## Delegation Rules

| Work type                    | Agent  |
|------------------------------|--------|
| File edits / code writing    | Codex  |
| Independent code review      | Gemini (agy) |
| Test verification            | Claude (runs locally) |
| Architecture decisions       | Claude |

- Never assign the same file to two agents concurrently.
- Always include `depends_on` task IDs in the task object.
- Give Gemini read-only tasks only; Gemini does not write source files.

## Safety Rules

- **Never deploy** without explicit user approval.
- **Never connect** to the production database; use a test fixture.
- **Never commit or push** without explicit user instruction.
- Do not run destructive migrations or drop-table scripts.
- Do not include secrets, tokens, or credentials in prompts sent to agents.
- Check that a prompt does not contain git push, git commit, git reset --hard, DROP TABLE, TRUNCATE TABLE, rm -rf, Remove-Item -Recurse -Force, migrate.sh down, DROP DATABASE, pm2 deploy before dispatching.

## File Communication Protocol

```
Gemini/agy  -> writes: .orchestra/reports/<slug>-analysis.md
Claude      -> reads, creates Codex task, updates state.json
Codex       -> writes: .orchestra/reports/<slug>-impl.md
Claude      -> runs npm test, closes task in state.json
```
