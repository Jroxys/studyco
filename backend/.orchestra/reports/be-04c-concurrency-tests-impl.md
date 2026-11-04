# be-04c-concurrency-tests implementation

## Files changed

- `tests/concurrency.test.ts`
- `vitest.config.ts`

## Scenarios

- `C1 accepts only one of two simultaneous requests for the same listing across ten rounds`
- `C2 enforces TIME_CONFLICT when two overlapping accepts race across ten rounds`
- `C3 creates one hold when the same request is accepted twice simultaneously across ten rounds`
- `C4 settles exactly once when both participants confirm concurrently after time travel across ten rounds`
- `C5 leaves no pending request when acceptance races a new request across ten rounds`
- `C6 allows one of two simultaneous paid accepts with exactly one lesson balance across ten rounds`

Each round asserts response outcomes, resulting request/wallet/ledger/accepted-slot state, and an entity-scoped `v_integrity_violations` query. The serial `concurrency` Vitest project also performs one global integrity-view check after the file completes. The existing `src/db/pool.test.ts` already covers retry behaviour for both `40001` and `40P01`.

## Test output

`npm run check`:

```text
> studyco-backend@0.1.0 check
> tsc --noEmit && eslint .
```

Dedicated concurrency file, run three times:

```text
Test Files  1 passed (1)
Tests  6 passed (6)
Duration  16.96s

Test Files  1 passed (1)
Tests  6 passed (6)
Duration  24.52s

Test Files  1 passed (1)
Tests  6 passed (6)
Duration  17.49s
```

Other projects:

```text
integration: Test Files  4 passed (4), Tests  47 passed (47)
unit: Test Files  5 passed (5), Tests  49 passed (49)
```

`npm test` was invoked after the change, but the execution wrapper ended its output at 30 seconds while Vitest was still running, after the successful check phase. The individual unit, integration, and concurrency projects above completed successfully; this is the only unresolved verification limitation in this environment.

## Deviations from PLAN.md / prompt

- C2's losing API request returns `409 REQUEST_NOT_PENDING`, not `TIME_CONFLICT`. The DB function accepts one request and trigger-auto-cancels the other overlapping pending request with `auto_cancel_reason = 'TIME_CONFLICT'`; the latter API call then correctly finds a non-pending request. The test asserts both the API error and the persisted `TIME_CONFLICT` cause.
- C4 uses the test-only `confirmLessonAt` helper with explicit `p_now`. The public confirmation endpoint intentionally cannot accept a client supplied clock, and the task explicitly requires test time travel.
- C6 reserves seven tokens with accepted paid lessons, then races two price-three requests. The schema limits a listing's token price to `0..3`, so this is the safe way to model balance for exactly one additional paid lesson.

## Open questions

- None.
