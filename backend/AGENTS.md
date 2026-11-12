# AGENTS.md - Codex instructions (studyco-backend)

Read `PLAN.md` first. It is the specification. The database in `../database` is finished: read it, never edit it.

## Layout

```
src/            application code (see PLAN.md section 3)
tests/helpers/  test utilities
../database/    READ ONLY (migrations, docs). Do not modify.
.orchestra/     orchestration state (read-only for Codex, except your own report)
```

## Stack and conventions

- Node.js 22, TypeScript strict, ESM, Fastify 5, `pg` raw SQL, Zod, Vitest. No ORM.
- Tests: `<module>.test.ts` next to the module (or `tests/`). Command: `npm test` (must also run `tsc --noEmit` and lint via `npm run check`).
- Follow PLAN.md section 2 "Hard rules" literally. They override your own preferences.
- Comments only for non-obvious WHY, one line.
- No new dependencies beyond those listed in PLAN.md section 1 (plus their types / dev tooling) unless the task says so.
- Edit only files needed for the task. `package.json` and lock files may be edited only by task `be-00-scaffold` or when the task asks for a dependency.
- Never edit `../database/**` and never run migrations against anything except the temporary test database created by the test harness.

## Test database

`TEST_PG_ADMIN_URL` comes from `.env.test` (gitignored; do not create it with real credentials, do not print it).
If it is missing, DB-dependent tests must fail with a clear message, not hang. Never connect to any database other than
the temp `studyco_test_*` one that the harness creates, and never touch other databases on that server.

## Forbidden

- git commit / push / reset, deploy commands, destructive SQL outside the temp test database.
- Concatenating input into SQL or shell. Logging secrets, tokens, passwords, OTP codes (the console mailer in dev may print the OTP; never in tests logs at info level in production mode).
- Committing `.env*` (except `.env.example`), `*.pem`, `credentials.json`.

## Definition of done for every task

1. `npm run check` (typecheck + lint) and `npm test` pass; paste the real output tail in the report.
2. Every endpoint/function added has tests for: success, each business error code, authorization failure, validation failure.
3. Write `.orchestra/reports/<task-id>-impl.md`: files changed, test output, deviations from PLAN.md (with reason), open questions.
4. If PLAN.md is ambiguous or contradicts the DB, STOP that part, note it in the report, implement the safest interpretation.
