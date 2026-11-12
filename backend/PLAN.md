# StudyCo Backend — Implementation Plan

Source of truth for the DB: `../database` (read `../database/README.md`, `docs/RAPOR.md`, `docs/data_dictionary.md`,
`migrations/up/*.sql`). The database is DONE and tested; the backend only talks to it. Flutter never talks to the DB.

## 1. Stack (decided)

Node.js 22, TypeScript (strict, ESM), Fastify 5, `pg` (raw parametrized SQL, NO ORM), Zod (validation, via
`fastify-type-provider-zod`), `@fastify/jwt`, `@fastify/rate-limit`, `@fastify/helmet`, `@fastify/cors`, `argon2` (argon2id),
`pino` (Fastify built-in), Vitest + real PostgreSQL for tests (no DB mocks: EXCLUDE/trigger/citext behaviour must be real).

## 2. Hard rules (zero-bug policy)

1. Critical flows ONLY through SQL functions: `accept_lesson_request`, `reject_lesson_request`, `confirm_lesson`,
   `issue_auth_token`, `verify_auth_token`, `process_expired_confirmations`, `expire_stale_requests`, `anonymize_user`.
   Never UPDATE `wallets`, `wallet_transactions`, `accepted_slots`, `lesson_requests` status columns by hand.
2. Never pass `p_now` (omit the argument; DB default `now()` is used).
3. Every query parametrized (`$1`). No string-built SQL. Dynamic filters use a whitelist of fixed fragments.
4. Every endpoint: Zod schema for params/query/body AND response. Responses never contain `password_hash`, `token_hash`,
   phone/e-mail of other users (only own profile shows them).
5. The authenticated user id comes ONLY from the JWT, never from body/query.
6. DB errors are mapped centrally: `error.code === 'P0001'` → `error.message` is a business code; other SQLSTATEs map by
   `error.constraint` / code (`23505` unique, `23514` check, `23503` fk, `40P01` deadlock, `40001` serialization, `22P02` bad uuid).
   Unknown errors → 500 with generic body (no SQL text leaked), full detail only in logs.
7. Deadlock/serialization (`40P01`, `40001`): retry the transaction up to 3 times with jitter (helper `withTx`).
8. Timestamps are ISO-8601 UTC strings in the API. Money = integer tokens.
9. No secrets in git. Config only from env, validated by Zod at boot (fail fast). `.env` is gitignored; `.env.example` committed.
10. Each module has tests: happy path + every business error code + authz (other user's resource) + validation errors.

## 3. Folder layout (`backend/`)

```
src/
  config.ts            env (Zod), single exported config object
  db/pool.ts           pg Pool, query helper, withTx (retry on 40P01/40001)
  db/errors.ts         DB error -> AppError mapping (table in section 5)
  errors.ts            AppError class, error codes, HTTP statuses
  app.ts               buildApp(deps) -> Fastify instance (no listen; used by tests)
  server.ts            listen + graceful shutdown + start jobs
  plugins/             auth (jwt guard), error-handler, rate-limit, security headers
  modules/
    auth/ users/ catalog/ listings/ requests/ wallet/ messages/ reviews/ jobs/ health/
      <name>.routes.ts  <name>.schemas.ts  <name>.service.ts  <name>.repo.ts  <name>.test.ts
  mail/                MailSender interface + ConsoleMailSender (dev/test); real provider later
tests/helpers/         test DB lifecycle, factories (createUser, createListing, ...), authed request helper
sql/                   (none; migrations live in ../database/migrations)
```

## 4. Test database strategy

- Env `TEST_PG_ADMIN_URL` (superuser URL, in gitignored `.env.test`, example in `.env.test.example`). Never commit it.
- Vitest `globalSetup`: creates DB `studyco_test_<random>` (UTF8), applies `../database/migrations/up/*.sql` in order via `pg`
  (multi-statement simple queries), loads departments seed. Teardown removes only that DB.
- Tests use unique random e-mail/phone per test and never depend on order. Dates are relative to now.
- Time travel for "after lesson end" scenarios: ONLY in test helpers, call the DB functions with an explicit `p_now` argument
  (e.g. `confirm_lesson($1,$2,$3)`, `process_expired_confirmations($1)`) or insert fixtures the way `../database/tests/tests.sql` does
  (read it first and copy its technique). Production code never passes `p_now`; add a test that greps `src/` for `p_now` and fails if found.
- Local PostgreSQL 16 service is already running on this machine (`E:\Postegro`). Docker is not required.

## 5. DB error code → HTTP table (implement once in `db/errors.ts`, unit-test every row)

| DB code | HTTP | API `code` |
|---|---|---|
| REQUEST_NOT_FOUND, USER_NOT_FOUND, LISTING_NOT_FOUND | 404 | same |
| NOT_LISTING_OWNER, NOT_A_PARTICIPANT, REVIEW_PARTIES_MISMATCH | 403 | same |
| REQUEST_NOT_PENDING, REQUEST_NOT_ACCEPTED, LISTING_NOT_PUBLISHED, LISTING_ALREADY_BOOKED, TIME_CONFLICT, REQUEST_NOT_SETTLEABLE, USER_HAS_ACTIVE_OBLIGATIONS, CONFIRMATION_TOO_EARLY, CONFIRMATION_WINDOW_CLOSED, LISTING_CORE_FIELDS_LOCKED, LISTING_TEACHER_IMMUTABLE, REVIEW_REQUIRES_COMPLETED_LESSON, CONVERSATION_REQUIRES_ACCEPTED_REQUEST | 409 | same |
| LISTING_EXPIRED | 409 | same |
| LISTING_START_IN_PAST, COURSE_DEPARTMENT_MISMATCH, COURSE_INACTIVE, LOCATION_INACTIVE_OR_UNKNOWN, TEACHER_ANONYMIZED, LISTING_MUST_START_PUBLISHED | 422 | same |
| INSUFFICIENT_BALANCE | 402 | same |
| LEDGER_IS_APPEND_ONLY, WALLET_* | 500 | INTERNAL (log loudly) |
| constraint `users_email_uq` | 409 | EMAIL_TAKEN |
| constraint `users_phone_uq` | 409 | PHONE_TAKEN |
| constraint `lr_one_per_student_listing_uq` | 409 | ALREADY_REQUESTED |
| constraint `lr_not_self_ck` | 422 | CANNOT_REQUEST_OWN_LISTING |
| constraint `reviews_once_per_reviewer_uq` | 409 | ALREADY_REVIEWED |
| any other 23505/23514/23503 | 409/422/409 | CONSTRAINT_VIOLATION |
| 22P02 (bad uuid/enum text) | 400 | BAD_REQUEST |

Error body everywhere: `{ "error": { "code": "TIME_CONFLICT", "message": "...", "details"?: ... } }`.

## 6. API contract (v1, prefix `/api/v1`, JSON, camelCase in API)

Auth header: `Authorization: Bearer <accessJwt>`. Cursor pagination: `?limit=1..50&cursor=<opaque>` → `{ items, nextCursor }`.

**Auth** (public unless noted; strict rate limit)
- `POST /auth/register` {firstName,lastName,birthDate,email,phone,password,departmentId,termsAccepted:true,termsVersion} → 201 {user,accessToken,refreshToken}. Phone normalized to E.164 (`+905xxxxxxxxx`, TR default); e-mail trimmed/lowercased; password ≥ 8 chars, ≤ 128; birth date must give age ≥ 16 (config). DB trigger creates wallet + 10 token bonus (do not do it in code). Sends e-mail-verification OTP.
- `POST /auth/login` {email,password} → {user,accessToken,refreshToken}. Same generic error for unknown e-mail / wrong password (`INVALID_CREDENTIALS` 401), dummy hash verify on unknown e-mail (timing). Anonymized users cannot log in.
- `POST /auth/refresh` {refreshToken} → rotated pair. Reuse of an already-rotated token revokes the whole family (401 `REFRESH_REUSED`).
- `POST /auth/logout` {refreshToken} → 204 (idempotent).
- `POST /auth/verify-email` (auth) {code} → 204. Uses `verify_auth_token` with HMAC-SHA256(server secret, code); COMMIT even when result is `INVALID`. Results: OK→204, INVALID→400 `INVALID_CODE`, EXPIRED→410, LOCKED→429, NOT_FOUND→400.
- `POST /auth/resend-verification` (auth) → 204 (cooldown 60s, per-user).
- `POST /auth/forgot-password` {email} → always 202 (no user enumeration). `POST /auth/reset-password` {email,code,newPassword} → 204; revokes all refresh tokens.
- OTP: 6 digits via `crypto.randomInt`, TTL 15 min (config), max attempts 5 (config).
- Access JWT 15 min (HS256, `sub`=userId); refresh = 32 random bytes base64url, only SHA-256 stored; TTL 30 days.
- `REQUIRE_VERIFIED_EMAIL` config flag (default `false`, matches RAPOR G6): when true, creating listings/requests needs `email_verified_at`.

**Me / users**
- `GET /me` (own profile incl. email, phone, emailVerified), `PATCH /me` {firstName,lastName,phone,departmentId?} — NOTE changing department is forbidden if user has active listings (409 `DEPARTMENT_CHANGE_BLOCKED`), `POST /me/change-password` {currentPassword,newPassword} (revokes other refresh tokens), `DELETE /me` {password} → calls `anonymize_user` (409 `USER_HAS_ACTIVE_OBLIGATIONS` passes through), revokes tokens.
- `GET /users/:id` public profile: firstName, lastName initial, department, rating avg/count, completed lessons count. No email/phone.

**Catalog** (auth): `GET /departments`, `GET /departments/:id/courses`, `GET /courses?departmentId=`, `GET /locations`. Only `is_active = true`. Cache headers short.

**Listings** (auth)
- `POST /listings` {courseId,locationId,topic,description?,startAt,endAt,tokenPrice(0..3)} → 201. teacher = JWT user. Validate in Zod: startAt in future, endAt > startAt, duration ≤ 8h; DB is the final judge.
- `GET /listings` filters: departmentId, courseId, locationId, from, to, maxPrice, q (topic ILIKE with escaped wildcards), sort=start_at asc; cursor on (start_at, listing_id). Reads `v_listing_state`, only `effective_status='PUBLISHED'`; excludes own listings unless `?mine=true`. Item = listing + course + location + teacher public summary (+ rating).
- `GET /listings/:id` detail; includes `myRequest` summary if the caller has one.
- `GET /me/listings` (all statuses, with pending request count).
- `PATCH /listings/:id` {topic?,description?} only owner; core fields locked by DB (409 passes through). Time/price/course/location changes are NOT supported by API (explicit 400 if sent) — documented limitation.
- No delete endpoint (not in DB design). Not-owner → 403, unknown → 404.

**Requests** (auth)
- `POST /listings/:id/requests` → 201 (student = JWT user; INSERT into `lesson_requests(listing_id,student_id)` only; trigger fills the rest). Pre-check balance is NOT done here (hold happens at accept → `INSUFFICIENT_BALANCE` returned to the teacher; document it).
- `GET /me/requests?role=student|teacher&status=` (sent/incoming), `GET /requests/:id` (only student or teacher; else 404 to avoid existence leak).
- `POST /requests/:id/accept` → `SELECT * FROM accept_lesson_request($1,$2)`; `POST /requests/:id/reject`; `POST /requests/:id/confirm` → `confirm_lesson`. Response = request view incl. completion status, deadline, settlement basis.
- Request view contains listing summary, counterpart public summary, `conversationId` when accepted.

**Wallet** (auth): `GET /wallet` {available, held}; `GET /wallet/transactions` cursor on (created_at, transaction_id), includes related request/listing title.

**Messages** (auth, REST only, polling for MVP)
- `GET /conversations` (my accepted lessons' rooms + last message + unread count), `GET /conversations/:id/messages?cursor&limit` (participant check via `is_conversation_participant`, else 403), `POST /conversations/:id/messages` {body ≤ 2000 chars, trimmed, non-empty}, `POST /conversations/:id/read` marks other party's messages read.

**Reviews** (auth): `POST /requests/:id/reviews` {rating 1..5, comment? ≤ 1000}, reviewee derived server-side from the request, `GET /users/:id/reviews` (cursor), `GET /requests/:id/reviews`.

**Ops**: `GET /health` (liveness), `GET /health/ready` (SELECT 1 + `v_integrity_violations` count = 0 → else 503 + log), OpenAPI JSON at `/openapi.json` (swagger only in non-production).

## 7. Background jobs (`modules/jobs`)

Every `JOB_INTERVAL_SECONDS` (default 300) run `SELECT process_expired_confirmations()` then `SELECT expire_stale_requests()`,
each wrapped in `pg_try_advisory_lock` so multiple instances never overlap. Errors are logged, never crash the process. Job runner
is injectable/disable-able (`JOBS_ENABLED`) and exposes `runOnce()` for tests. Stop on graceful shutdown.

## 8. Additional migration (owned by Claude, not Codex)

`../database/migrations/up/006_refresh_tokens.sql` (+ down): `refresh_tokens(token_id uuid pk, user_id fk, family_id uuid, token_hash
text unique, expires_at, revoked_at, replaced_by uuid, created_at)` + indexes. Coordinate with the DB owner before merging.

## 9. Phases and tasks (each ends with `npm test` green, then next)

| # | Task id | Content |
|---|---|---|
| 0 | `be-00-scaffold` | package.json, tsconfig, eslint/prettier, config, errors, db pool/withTx, error mapper (+unit tests), app.ts skeleton, health, `.env.example`, `.gitignore`. Tests need NO database. |
| 1 | `be-01-test-harness` | Vitest globalSetup creating/dropping temp DB, applying migrations, factories, authed-request helper; smoke test proving schema + welcome bonus + `v_integrity_violations` empty. |
| 2 | `be-02-auth` | Section 6 Auth + Me + refresh tokens (needs 006 migration present) + mail interface + rate limit + tests incl. enumeration/timing, token reuse, OTP lockout. |
| 3 | `be-03-catalog-listings` | Catalog + Listings + public user profile. |
| 4 | `be-04-requests-wallet` | Requests lifecycle + wallet + all error codes; concurrency tests (two teachers accepting at once, two requests same slot) through the API. |
| 5 | `be-05-messages-reviews` | Conversations/messages/reviews + authz tests. |
| 6 | `be-06-jobs-ops` | Jobs, readiness, graceful shutdown, OpenAPI export script, README (run, env, test, API table). |
| 7 | `be-07-hardening-review` | Full-flow e2e (register→listing→request→accept→confirm→review→wallet), coverage report, review pass; Gemini review (high-risk: money/auth). |

## 10. Open items (decisions taken, easy to change)

- E-mail provider: console sender for now; real SMTP/Resend later behind `MailSender`.
- Admin flow for `MANUAL_REVIEW`: out of MVP (DB state is terminal).
- Push notifications / WebSocket: out of MVP (REST polling).
- No real courses/locations until the DB owner loads `seeds/data/*.csv`; tests create their own.
- University e-mail domain restriction: not enforced (RAPOR O-08).
