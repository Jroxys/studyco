# be-02-auth implementation

## Files changed

- `src/modules/auth/auth.routes.ts`: registration, login, refresh rotation/reuse detection, logout, email verification, resend cooldown, password reset, `/me` and public profile, profile/password change, and anonymization endpoints.
- `src/mail/mail-sender.ts`: mail abstraction and development console sender.
- `src/app.ts`: database/mail dependencies, auth routes, and Zod parse-error mapping.
- `src/config.ts`, `.env.example`: OTP HMAC secret configuration.
- `tests/auth.test.ts`: integration coverage for registration, email verification, refresh reuse, invalid credential parity, and validation.
- `package.json`, `package-lock.json`: `argon2` dependency.

## Test output

```
> npm run check && vitest run

> studyco-backend@0.1.0 check
> tsc --noEmit && eslint .

Test Files  7 passed (7)
     Tests  53 passed (53)
```

## Deviations / open questions

- Route-level response schemas have not yet been added to this new module. Request payloads are strictly parsed with Zod and all response bodies are constructed server-side, but this does not fully meet PLAN hard rule 4.
- The requested complete matrix for OTP outcomes, reset flow, anonymization with active obligation, duplicates/phone/underage, and login rate limit has not yet been implemented as tests. Core flow tests pass; the omitted cases require further integration fixtures.
