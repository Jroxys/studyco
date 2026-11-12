# StudyCo Backend

StudyCo is a Fastify REST API for a token-based, one-to-one lesson marketplace. PostgreSQL owns all financial and lesson-lifecycle invariants; this service calls its supported SQL functions and never changes database migrations.

## Setup

Use Node.js 22 and PostgreSQL 16 or later. The database project lives beside this repository in `../database`; apply its migrations and seeds as described in its README before starting the API.

```sh
npm install
cp .env.example .env
npm run dev
```

The API listens on `http://127.0.0.1:3000` by default. Its OpenAPI document is available at `/openapi.json`; Swagger UI is at `/documentation/` in development and test only.

## Configuration

Copy `.env.example` and set production secrets before deployment. Do not commit `.env` files.

| Variable | Default | Purpose |
| --- | --- | --- |
| `NODE_ENV` | `development` | `development`, `test`, or `production` |
| `PORT` / `HOST` | `3000` / `127.0.0.1` | HTTP listener |
| `DATABASE_URL` | local example URL | Application PostgreSQL connection |
| `JWT_SECRET` | development value | At least 32 characters; required in production |
| `JWT_EXPIRES_IN` | `15m` | Access-token lifetime |
| `CORS_ORIGIN` | `http://localhost:3000` | Allowed browser origin |
| `RATE_LIMIT_MAX` / `RATE_LIMIT_WINDOW` | `100` / `1 minute` | Global request limit |
| `MINIMUM_AGE` | `16` | Registration age floor |
| `OTP_TTL_MINUTES` / `OTP_MAX_ATTEMPTS` | `15` / `5` | OTP policy |
| `OTP_HMAC_SECRET` | development value | OTP HMAC secret; required in production |
| `REQUIRE_VERIFIED_EMAIL` | `false` | Require verified email for listings and requests |
| `JOBS_ENABLED` | `true` | Enables expiration/settlement jobs in the server process |
| `JOB_INTERVAL_SECONDS` | `300` | Background-job interval |
| `SMTP_URL` | empty | SMTP connection URL for verification/reset mail; required in production. Empty in development prints codes to the log |
| `MAIL_FROM` | `StudyCo <no-reply@studyco.local>` | Sender address |

Integration tests also need `TEST_PG_ADMIN_URL` in a local, gitignored `.env.test`; see `.env.test.example`. The harness creates and removes only randomly named `studyco_test_*` databases.

## Scripts

| Command | Description |
| --- | --- |
| `npm run dev` | Start the API with file watching and `.env` |
| `npm run build` | Compile TypeScript to `dist/` |
| `npm start` | Start compiled production output |
| `npm run check` | Type-check and lint |
| `npm test` | Run checks and all unit/integration tests |
| `npm run openapi` | Write the generated OpenAPI document to `openapi.json` |

## API overview

All application routes use the `/api/v1` prefix and JSON camelCase. Authenticated routes accept `Authorization: Bearer <accessJwt>`. `GET /departments` is public so the registration form can list departments.

| Area | Routes |
| --- | --- |
| Auth and profile | `/auth/*`, `/me`, `/users/:id` |
| Catalog and listings | `/departments`, `/courses`, `/locations`, `/listings`, `/me/listings` |
| Requests and wallet | `/listings/:id/requests`, `/requests/*`, `/me/requests`, `/wallet/*` |
| Messages and reviews | `/conversations/*`, `/requests/:id/reviews`, `/users/:id/reviews` |
| Operations | `/health`, `/health/ready`, `/openapi.json` |

Background jobs call `process_expired_confirmations()` and `expire_stale_requests()` under PostgreSQL advisory locks. They log failures and continue; graceful shutdown stops scheduling and waits for active runs before the database pool closes.

## Errors

Failures have this shape:

```json
{ "error": { "code": "TIME_CONFLICT", "message": "..." } }
```

Common error codes include `VALIDATION_ERROR` (400), `UNAUTHORIZED` (401), `INSUFFICIENT_BALANCE` (402), `NOT_LISTING_OWNER` (403), `REQUEST_NOT_FOUND` (404), `TIME_CONFLICT` / `ALREADY_REQUESTED` (409), and `COURSE_INACTIVE` (422). Unexpected database or server errors return `INTERNAL` (500) without SQL details. The full generated contract documents responses for every endpoint.
