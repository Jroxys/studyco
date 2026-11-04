# Implementation: be-07-e2e-hardening

Date: 2026-11-05

## Files changed

- `src/app.ts` — authenticate all protected `/api/v1` routes before validation and normalize JWT failures to `401 UNAUTHORIZED`.
- `src/modules/auth/auth.routes.ts`, `auth.service.ts` — extracted auth helpers/token issuance into the service layer and corrected absent public ratings to `null`.
- `src/modules/listings/listings.routes.ts` — preserves nullable teacher ratings.
- `tests/e2e-hardening.test.ts` — full lifecycle test and protected-route missing/invalid-JWT matrix.
- `tests/auth.test.ts` — public user with no reviews has `ratingAverage: null`.
- `tests/concurrency.test.ts` — per-file 60-second timeout.
- Route modules and message/review tests — formatted with Prettier.
- `package.json`, `package-lock.json`, `.prettierrc.json`, `vitest.config.ts` — Prettier command/configuration, sequential test projects, V8 coverage command with 85% module line threshold, and coverage tooling.

## Verification

`npm run check`:

```text
> studyco-backend@0.1.0 check
> tsc --noEmit && eslint .
```

`npm test` was run three consecutive times after the timeout change; each completed with:

```text
Test Files  12 passed (12)
     Tests  109 passed (109)

Test Files  1 passed (1)
     Tests  6 passed (6)
```

Final post-dependency-update run:

```text
Test Files  12 passed (12)
     Tests  109 passed (109)

Test Files  1 passed (1)
     Tests  6 passed (6)
```

`npx vitest run --coverage --project unit --project integration` passed with module coverage of 89.44% lines, above the configured 85% threshold.

`npm audit --omit=dev --audit-level=high --cache .npm-cache`:

```text
found 0 vulnerabilities
```

## Deviations from PLAN.md

- The E2E test uses the existing test-only `confirmLessonAt(..., p_now)` helper for post-lesson confirmation. Production code still never supplies `p_now`, as required.
- Added Prettier and Vitest's V8 coverage provider as development tooling required by this task.
- Upgraded `@fastify/swagger-ui` to 6.1.3 to remove the production audit finding; its existing OpenAPI/UI tests pass.

## Remaining risks

- `npm audit` without `--omit=dev` still reports moderate development-tooling advisories. Production dependency audit is clean.
- The full E2E test intentionally relies on DB time travel only through test helpers; wall-clock expiry behavior remains covered separately by jobs tests.
