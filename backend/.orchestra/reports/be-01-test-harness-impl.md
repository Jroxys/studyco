# Implementation: be-01-test-harness

## Files changed

- `vitest.config.ts` — separate `unit` and `integration` Vitest projects.
- `tests/helpers/global-setup.ts` — temporary database lifecycle, migrations, seed loading, and teardown.
- `tests/helpers/factories.ts` — parameterized user, course, location, and listing fixtures.
- `tests/helpers/time-travel.ts` — test-only explicit-time SQL function calls.
- `tests/helpers/authed-request.ts` — authenticated `app.inject` helper.
- `tests/vitest.d.ts` — typed test database URL context.
- `tests/harness.smoke.test.ts` — schema, welcome bonus, and integrity-view smoke coverage.
- `src/no-production-time-travel.test.ts` — guards production source against the explicit database time parameter.

## Verification

`npm run check` passed:

```text
> studyco-backend@0.1.0 check
> tsc --noEmit && eslint .
```

`npm test` passed:

```text
 RUN  v5.1.0 C:/Users/talha/Desktop/studyco/repo/backend

 Test Files  6 passed (6)
      Tests  51 passed (51)
```

## Deviations from PLAN.md

None. The harness intentionally does not load catalog fixtures because the task requests migrations plus the departments seed; factories create the course and location data each integration test needs.

## Open questions

None.
