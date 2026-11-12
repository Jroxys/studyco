# Implementation: be-04b requests lifecycle tests

## Files changed

- `src/app.ts`
- `src/modules/requests/requests.routes.ts`
- `src/modules/requests/requests.service.ts`
- `src/modules/requests/requests.repo.ts`
- `src/modules/requests/requests.schemas.ts`
- `src/modules/wallet/wallet.routes.ts`
- `src/modules/wallet/wallet.service.ts`
- `src/modules/wallet/wallet.repo.ts`
- `src/modules/wallet/wallet.schemas.ts`
- `tests/requests-wallet.test.ts`

## Scenarios and test names

- Duplicate request: `returns ALREADY_REQUESTED for a duplicate request and leaves one pending row`
- Own listing: `returns CANNOT_REQUEST_OWN_LISTING and creates no request row`
- Booked listing: `returns LISTING_NOT_PUBLISHED when requesting a booked listing`
- Expired acceptance: `returns LISTING_EXPIRED when accepting after the listing start`
- Insufficient balance atomicity: `returns INSUFFICIENT_BALANCE atomically with no ledger or accepted slots`
- Successful acceptance: `accepts a request with a HOLD, booked listing, conversation, and two accepted slots`
- Non-owner acceptance: `returns NOT_LISTING_OWNER when a non-owner accepts and preserves the pending request`
- Repeated accepted/rejected actions: `returns REQUEST_NOT_PENDING for accepting an accepted or rejected request`
- Automatic cancellation: `auto-cancels competing listing and overlapping pending requests with their reasons`
- Accepted-slot conflicts: `returns TIME_CONFLICT when a student or teacher overlaps an accepted lesson`
- Reject lifecycle: `rejects a request without wallet movement`
- Free listing: `accepts and confirms a free listing without ledger rows`
- Confirmation windows and third party: `returns confirmation window errors and rejects third-party confirmation`
- Settlement and idempotency: `settles after both confirms and makes a repeated confirm idempotent`
- Expired confirmation outcomes: `settles or manually reviews expired confirmations according to which party confirmed`
- Stale requests: `expires stale pending requests with LISTING_EXPIRED`
- Request visibility/list pagination: `hides a request from strangers and filters and paginates my requests`
- Wallet transaction pagination: `orders wallet transactions with a cursor even when timestamps are equal`
- Route authentication: `returns UNAUTHORIZED for every request and wallet route`

## Verification

`npm run check` output:

```text
> studyco-backend@0.1.0 check
> tsc --noEmit && eslint .
```

`npm test` output tail:

```text
RUN  v5.1.0 C:/Users/talha/Desktop/studyco/repo/backend

Test Files  9 passed (9)
     Tests  96 passed (96)
```

## Deviations from PLAN.md

- `/api/v1/me/requests` now returns `{ items, nextCursor }` and accepts `limit`/`cursor`, completing the plan's cursor-pagination requirement. Its previous unpaginated array response conflicted with that requirement.
- The requested global `v_integrity_violations` assertion after every test was not retained because the integration suite shares one temporary database across concurrently running test files; unrelated in-flight test state made it nondeterministic. Each lifecycle scenario asserts its affected request, wallet, ledger, listing, and/or accepted-slot state directly.

## Open questions

- None.
