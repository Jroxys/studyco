# Implementation: be-06-jobs-ops

Date: 2026-11-05

## Files changed

- `src/modules/jobs/jobs.service.ts` — injectable runner with PostgreSQL advisory locks, interval lifecycle, `runOnce()`, error logging, and graceful stop support.
- `src/app.ts` — readiness endpoint, OpenAPI document endpoint, and non-production Swagger UI.
- `src/server.ts` — starts enabled jobs after listening and stops them before closing the pool.
- `src/app.test.ts`, `tests/jobs-ops.test.ts` — OpenAPI/UI, readiness, expiry settlement, and concurrent lock tests.
- `scripts/export-openapi.ts`, `package.json`, `package-lock.json`, `tsconfig.json` — OpenAPI export command and required Swagger plugins.
- `README.md` — setup, environment, commands, API overview, and errors.
- `openapi.json` — generated OpenAPI contract.

## Verification

`npm run check`:

```text
> studyco-backend@0.1.0 check
> tsc --noEmit && eslint .
```

`npx vitest run --project unit --project integration`:

```text
Test Files  11 passed (11)
     Tests  106 passed (106)
Duration  9.57s
```

`npx vitest run --project concurrency -t "C3"`:

```text
Test Files  1 passed (1)
     Tests  1 passed | 5 skipped (6)
```

`npx vitest run --project concurrency -t "C6"`:

```text
Test Files  1 passed (1)
     Tests  1 passed | 5 skipped (6)
```

`npm run openapi` completed and wrote `openapi.json` (323,899 bytes).

## Deviations from PLAN.md

- Added `@fastify/swagger` and `@fastify/swagger-ui`. The task explicitly requires an OpenAPI document generated from Zod schemas and a non-production Swagger UI; these plugins are the supported Fastify/Zod integration.
- The full concurrency project had one timing-only failure on its first run: existing C3 exceeded its fixed 5-second test timeout while the other C1, C2, C4, and C5 cases passed. Rerunning C3 alone passed in 2.94 seconds. No concurrency-test code was changed.

## Open questions

- None.
