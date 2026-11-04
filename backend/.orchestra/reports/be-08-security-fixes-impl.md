# be-08 Security Fixes — Implementation Report

## Files changed

- `.env.example`
- `src/app.ts`, `src/config.ts`, `src/db/errors.ts`, `src/db/pool.ts`, `src/mail/mail-sender.ts`
- `src/modules/auth/auth.routes.ts`, `src/modules/auth/auth.service.ts`
- `src/modules/{listings,requests,wallet,messages,reviews}/*`
- `src/app.test.ts`, `tests/auth.test.ts`, `tests/requests-wallet.test.ts`

## Findings and proof

- H1 — `auth > issues expiring HS256 access tokens and rejects expired access tokens` asserts `exp` and a 401 for an expired token.
- H2 — `auth > rejects an anonymized user access token on every protected module` covers me, wallet, messages, listings, reviews, and requests after `DELETE /me`.
- H3 — forgot-password now uses a transaction advisory lock plus the existing `auth_tokens.created_at` for a 60-second atomic cooldown, and normalised-email rate limiting (3/hour). Mail errors are logged and swallowed.
- M1 — JWT guard enforces verified e-mail for listing/request creation; register, refresh, verify-email, and reset-password have route limits.
- M3/L2 — reset errors are uniformly `400 INVALID_CODE`; verification and password update occur in one transaction. Anonymized forgot-password requests perform dummy argon2 work.
- M4 — request lifecycle mutations, request creation, review insertion, and message insertion use `withTx`.
- M5/M6 — pool limits/timeouts/error handling and hardened production configuration, proxy handling, mail logging policy, and example variables were added.
- M7 — wallet cursor serializes the raw database microsecond timestamp and does not round it through JavaScript dates.
- L4/L7/L8/L11 — mutation authorization now hides non-participant requests with 404; invalid timestamp SQLSTATEs map to `BAD_CURSOR`; OpenAPI is absent in production; the listing update includes `teacher_id` in its WHERE clause.

## Required database-schema deviation

The requested cumulative PASSWORD_RESET failure lock (10 failures/hour then 15-minute lock) cannot be implemented without persistent state. The completed, read-only schema has only per-token `attempt_count`, which resets when a new reset token is issued; it has no per-user cumulative attempt/lock columns or table. Per AGENTS.md and the task prompt, no database migration was made. This remains an open item for the database owner.

## Verification output

`npm run check`:

```text
> tsc --noEmit && eslint .
```

Unit + integration:

```text
Test Files  12 passed (12)
Tests  111 passed (111)
```

Concurrency:

```text
Test Files  1 passed (1)
Tests  6 passed (6)
```
