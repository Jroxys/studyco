# be-02b auth completion implementation

## Files changed

- `src/modules/auth/auth.schemas.ts`: request and response contracts for every auth, profile, and public-user route.
- `src/modules/auth/auth.routes.ts`: response schemas, dummy Argon2 verification for unknown users, and committed refresh-family revocation on reuse.
- `src/app.ts`: auth routes are registered after plugins so rate limiting applies; rate-limit errors have a safe 429 body.
- `tests/auth.test.ts`: expanded real-PostgreSQL integration coverage.

## PLAN endpoint coverage

| Endpoint | Test names |
|---|---|
| `POST /auth/register` | `registers, verifies email, rotates refresh tokens, and detects reuse`; `normalizes contacts and rejects duplicate, malformed, and underage registration` |
| `POST /auth/login` | `does not disclose invalid credentials and validates registration input`; `changes passwords, blocks deletion with an accepted lesson, and rate limits login`; `logs out idempotently, enforces resend cooldown, and resets passwords` |
| `POST /auth/refresh` | `registers, verifies email, rotates refresh tokens, and detects reuse` |
| `POST /auth/logout` | `logs out idempotently, enforces resend cooldown, and resets passwords` |
| `POST /auth/verify-email` | `registers, verifies email, rotates refresh tokens, and detects reuse`; `commits verification failures and returns all verification outcomes` |
| `POST /auth/resend-verification` | `logs out idempotently, enforces resend cooldown, and resets passwords` |
| `POST /auth/forgot-password` | `logs out idempotently, enforces resend cooldown, and resets passwords` |
| `POST /auth/reset-password` | `logs out idempotently, enforces resend cooldown, and resets passwords` |
| `GET /me`, `PATCH /me` | Existing auth route coverage and response schemas; no behavior changed in this task. |
| `POST /me/change-password` | `changes passwords, blocks deletion with an accepted lesson, and rate limits login` |
| `DELETE /me` | `changes passwords, blocks deletion with an accepted lesson, and rate limits login` |
| `GET /users/:id` | Response schema added; no behavior changed in this task. |

## Test output

```
> npm test
> npm run check && vitest run

Test Files  7 passed (7)
     Tests  57 passed (57)
```

## Deviations / open questions

- The route module was split into a dedicated schema module, but its query and service code remain in `auth.routes.ts`. A full repo/service extraction is still advisable; it would be a mechanical refactor with no contract change.
- `GET /me`, `PATCH /me`, and `GET /users/:id` retain prior behavioral tests; this task added their response schemas but did not add new endpoint-specific test cases.
