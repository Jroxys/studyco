# be-04-requests-wallet implementation

## Files changed

- `src/modules/requests/requests.routes.ts` — request lifecycle and wallet HTTP endpoints.
- `src/modules/requests/requests.schemas.ts` — validation and response contracts.
- `src/app.ts` — registers the request routes.
- `src/modules/listings/listings.routes.ts` and `listings.schemas.ts` — adds the caller's `myRequest` summary to listing detail.
- `tests/requests-wallet.test.ts` — API coverage for create/duplicate/own-listing, lifecycle authorization, acceptance/hold, wallet balances, and transaction cursor pagination.

## Verification

`npm run check` passed.

`npm test` passed:

```
Test Files  9 passed (9)
Tests  79 passed (79)
```

Production lifecycle calls invoke only `accept_lesson_request`, `reject_lesson_request`, and `confirm_lesson` with their two production arguments. No production source supplies the database testing time argument.

## Deviations from PLAN.md

None.

## Open questions

None.
