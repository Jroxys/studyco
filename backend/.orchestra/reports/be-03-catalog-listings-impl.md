# be-03-catalog-listings implementation

## Files changed

- `src/app.ts`
- `src/modules/catalog/catalog.routes.ts`
- `src/modules/catalog/catalog.schemas.ts`
- `src/modules/listings/listings.routes.ts`
- `src/modules/listings/listings.schemas.ts`
- `src/modules/auth/auth.repo.ts`
- `src/modules/auth/auth.routes.ts`
- `tests/catalog-listings.test.ts`
- `tests/auth.test.ts`

## Delivered

- Authenticated active catalog endpoints with short private cache headers.
- Listing create, browse/filter, opaque base64url keyset cursor pagination, detail, and owner-only topic/description patching.
- Listing browse reads `v_listing_state`, only exposes effective published listings, escapes `ILIKE` wildcards, and excludes own listings unless `mine=true`.
- Auth user lookups are now shared through `auth.repo.ts`; profile endpoint tests cover GET, normalized phone update, duplicate phone, active-listing department guard, and validation.
- Integration tests cover catalog auth, listing error paths reachable by API, filtering, equal-time cursor stability, cursor tampering, ownership, and public user profile.

## Verification

```text
> studyco-backend@0.1.0 check
> tsc --noEmit && eslint .

> studyco-backend@0.1.0 test
> npm run check && vitest run

 RUN  v5.1.0 C:/Users/talha/Desktop/studyco/repo/backend

 Test Files  8 passed (8)
      Tests  61 passed (61)
   Start at  22:50:51
   Duration  7.79s (tests 73%, import 22%, transform 4%, worker 1%)
```

## Deviations / open questions

- The API deliberately delegates the start-time rule to the database trigger so the specified `LISTING_START_IN_PAST` business error remains reachable through `POST /listings`; this is safer than duplicating a clock-sensitive rule in Zod.
- `GET /listings/:id` returns the listing detail currently available in this phase. `myRequest` is intentionally deferred until the requests module introduces its request summary DTO.
