import { afterAll, afterEach, describe, expect, inject, it } from 'vitest';
import { Pool } from 'pg';
import { buildApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import type { MailSender } from '../src/mail/mail-sender.js';
import { createCourse, createLocation, createUser } from './helpers/factories.js';

class Mail implements MailSender {
  async sendVerification(): Promise<void> {}
  async sendPasswordReset(): Promise<void> {}
}
type App = ReturnType<typeof buildApp>;
type Account = { user: { id: string }; accessToken: string };
type Item = { id: string; topic: string; status: string; pendingRequestCount?: number };
const pool = new Pool({ connectionString: inject('testDatabaseUrl') });
const config = loadConfig({
  NODE_ENV: 'test',
  DATABASE_URL: inject('testDatabaseUrl'),
  JWT_SECRET: 'a-very-long-test-jwt-secret-that-is-not-production',
  OTP_HMAC_SECRET: 'a-very-long-test-otp-hmac-secret-that-is-not-production'
});
const apps: App[] = [];
afterEach(async () => {
  await Promise.all(apps.splice(0).map((value) => value.close()));
});
afterAll(async () => {
  await pool.end();
});
async function app(): Promise<App> {
  const value = buildApp({ config, db: pool, mailSender: new Mail() });
  apps.push(value);
  await value.ready();
  return value;
}
async function department(offset = 0): Promise<string> {
  return (
    await pool.query<{ id: string }>(
      'SELECT department_id AS id FROM departments WHERE is_active ORDER BY name OFFSET $1 LIMIT 1',
      [offset]
    )
  ).rows[0]!.id;
}
async function account(value: App, departmentId?: string): Promise<Account> {
  const response = await value.inject({
    method: 'POST',
    url: '/api/v1/auth/register',
    payload: {
      firstName: 'List',
      lastName: 'Tester',
      birthDate: '2000-01-01',
      email: `${crypto.randomUUID()}@example.test`,
      phone: `+905${Math.floor(100000000 + Math.random() * 899999999)}`,
      password: 'secure-password-123',
      departmentId: departmentId ?? (await department()),
      termsAccepted: true,
      termsVersion: 'v1'
    }
  });
  expect(response.statusCode).toBe(201);
  return response.json() as Account;
}
function auth(token: string) {
  return { authorization: `Bearer ${token}` };
}
function future(hours: number): string {
  return new Date(Date.now() + hours * 3_600_000).toISOString();
}
const sameStartAndEnd = future(24);
function payload(courseId: string, locationId: string, extra: Record<string, unknown> = {}) {
  return {
    courseId,
    locationId,
    topic: 'Linear Algebra',
    startAt: future(24),
    endAt: future(25),
    tokenPrice: 2,
    ...extra
  };
}
async function create(
  value: App,
  teacher: Account,
  courseId: string,
  locationId: string,
  extra: Record<string, unknown> = {}
): Promise<Item> {
  const response = await value.inject({
    method: 'POST',
    url: '/api/v1/listings',
    headers: auth(teacher.accessToken),
    payload: payload(courseId, locationId, extra)
  });
  expect(response.statusCode).toBe(201);
  return response.json() as Item;
}

describe('catalog', () => {
  it('requires auth (except departments, used by registration) and filters by department', async () => {
    const value = await app();
    expect((await value.inject({ method: 'GET', url: '/api/v1/departments' })).statusCode).toBe(
      200
    );
    expect((await value.inject({ method: 'GET', url: '/api/v1/courses' })).statusCode).toBe(401);
    expect((await value.inject({ method: 'GET', url: '/api/v1/locations' })).statusCode).toBe(401);
    const user = await account(value);
    const first = await department();
    const second = await department(1);
    const course = await createCourse(pool, first);
    const other = await createCourse(pool, second);
    const location = await createLocation(pool);
    const courses = await value.inject({
      method: 'GET',
      url: `/api/v1/courses?departmentId=${first}`,
      headers: auth(user.accessToken)
    });
    expect(courses.statusCode).toBe(200);
    expect(courses.json().map((x: Item) => x.id)).toEqual(expect.arrayContaining([course]));
    expect(courses.json().map((x: Item) => x.id)).not.toContain(other);
    expect(
      (
        await value.inject({
          method: 'GET',
          url: '/api/v1/locations',
          headers: auth(user.accessToken)
        })
      )
        .json()
        .map((x: Item) => x.id)
    ).toContain(location);
  });
  it('hides inactive courses and locations', async () => {
    const value = await app();
    const user = await account(value);
    const course = await createCourse(pool, await department());
    const location = await createLocation(pool);
    await pool.query('UPDATE courses SET is_active = false WHERE course_id = $1', [course]);
    await pool.query('UPDATE locations SET is_active = false WHERE location_id = $1', [location]);
    const courses = await value.inject({
      method: 'GET',
      url: '/api/v1/courses',
      headers: auth(user.accessToken)
    });
    const locations = await value.inject({
      method: 'GET',
      url: '/api/v1/locations',
      headers: auth(user.accessToken)
    });
    expect(courses.json().map((x: Item) => x.id)).not.toContain(course);
    expect(locations.json().map((x: Item) => x.id)).not.toContain(location);
  });
});

describe('POST /listings', () => {
  it('creates a listing', async () => {
    const value = await app();
    const teacher = await account(value);
    const listing = await create(
      value,
      teacher,
      await createCourse(pool, await department()),
      await createLocation(pool)
    );
    expect(
      (await pool.query('SELECT listing_id FROM listings WHERE listing_id = $1', [listing.id]))
        .rowCount
    ).toBe(1);
  });
  it('requires authentication', async () => {
    const value = await app();
    const response = await value.inject({
      method: 'POST',
      url: '/api/v1/listings',
      payload: payload(crypto.randomUUID(), crypto.randomUUID())
    });
    expect(response.statusCode).toBe(401);
    expect(response.json().error.code).toBe('UNAUTHORIZED');
  });
  it.each(['mismatch', 'inactive-course', 'inactive-location', 'past'] as const)(
    'returns the database error for %s without inserting',
    async (kind) => {
      const value = await app();
      const teacher = await account(value);
      const course = await createCourse(
        pool,
        kind === 'mismatch' ? await department(1) : await department()
      );
      const location = await createLocation(pool);
      const topic = `rejected-${crypto.randomUUID()}`;
      if (kind === 'inactive-course')
        await pool.query('UPDATE courses SET is_active = false WHERE course_id = $1', [course]);
      if (kind === 'inactive-location')
        await pool.query('UPDATE locations SET is_active = false WHERE location_id = $1', [
          location
        ]);
      const response = await value.inject({
        method: 'POST',
        url: '/api/v1/listings',
        headers: auth(teacher.accessToken),
        payload: payload(course, location, {
          topic,
          ...(kind === 'past' ? { startAt: future(-1), endAt: future(1) } : {})
        })
      });
      const code = {
        mismatch: 'COURSE_DEPARTMENT_MISMATCH',
        'inactive-course': 'COURSE_INACTIVE',
        'inactive-location': 'LOCATION_INACTIVE_OR_UNKNOWN',
        past: 'LISTING_START_IN_PAST'
      }[kind];
      expect(response.statusCode).toBe(422);
      expect(response.json().error.code).toBe(code);
      expect(
        (await pool.query('SELECT listing_id FROM listings WHERE topic = $1', [topic])).rowCount
      ).toBe(0);
    }
  );
  it.each([
    { startAt: sameStartAndEnd, endAt: sameStartAndEnd },
    { startAt: future(24), endAt: future(33) },
    { tokenPrice: 4 }
  ])('rejects invalid time or price before inserting', async (extra) => {
    const value = await app();
    const teacher = await account(value);
    const topic = `invalid-${crypto.randomUUID()}`;
    const response = await value.inject({
      method: 'POST',
      url: '/api/v1/listings',
      headers: auth(teacher.accessToken),
      payload: payload(await createCourse(pool, await department()), await createLocation(pool), {
        topic,
        ...extra
      })
    });
    expect(response.statusCode).toBe(400);
    expect(response.json().error.code).toBe('VALIDATION_ERROR');
    expect(
      (await pool.query('SELECT listing_id FROM listings WHERE topic = $1', [topic])).rowCount
    ).toBe(0);
  });
});

describe('GET /listings', () => {
  it('applies each filter and literal query escaping', async () => {
    const value = await app();
    const teacher = await account(value);
    const otherTeacher = await account(value, await department(1));
    const viewer = await account(value);
    const dep = await department();
    const course = await createCourse(pool, dep);
    const location = await createLocation(pool);
    const target = await create(value, teacher, course, location, {
      topic: '100%_target',
      startAt: future(48),
      endAt: future(49),
      tokenPrice: 2
    });
    const otherCourse = await createCourse(pool, await department(1));
    const otherLocation = await createLocation(pool);
    await create(value, otherTeacher, otherCourse, otherLocation, {
      topic: '100ZZtarget',
      startAt: future(72),
      endAt: future(73),
      tokenPrice: 3
    });
    for (const query of [
      `departmentId=${dep}`,
      `courseId=${course}`,
      `locationId=${location}`,
      `from=${encodeURIComponent(future(47))}`,
      `to=${encodeURIComponent(future(49))}`,
      'maxPrice=2',
      'q=100%25_'
    ]) {
      const response = await value.inject({
        method: 'GET',
        url: `/api/v1/listings?${query}`,
        headers: auth(viewer.accessToken)
      });
      expect(response.statusCode).toBe(200);
      expect(response.json().items.map((x: Item) => x.id)).toContain(target.id);
    }
    const literal = await value.inject({
      method: 'GET',
      url: '/api/v1/listings?q=100%25_',
      headers: auth(viewer.accessToken)
    });
    expect(literal.json().items.map((x: Item) => x.topic)).not.toContain('100ZZtarget');
  });
  it('paginates shared timestamps without duplicates or gaps', async () => {
    const value = await app();
    const teacher = await account(value);
    const viewer = await account(value);
    const course = await createCourse(pool, await department());
    const location = await createLocation(pool);
    const start = future(96);
    const ids = await Promise.all(
      [1, 2, 3, 4].map(
        async (n) =>
          (
            await create(value, teacher, course, location, {
              topic: `page-${n}`,
              startAt: start,
              endAt: future(97)
            })
          ).id
      )
    );
    let cursor = '';
    const seen: string[] = [];
    do {
      const response = await value.inject({
        method: 'GET',
        url: `/api/v1/listings?limit=1${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`,
        headers: auth(viewer.accessToken)
      });
      expect(response.statusCode).toBe(200);
      seen.push(
        ...response
          .json()
          .items.map((x: Item) => x.id)
          .filter((id: string) => ids.includes(id))
      );
      cursor = response.json().nextCursor ?? '';
    } while (cursor);
    expect(new Set(seen).size).toBe(ids.length);
    expect(seen.sort()).toEqual(ids.sort());
  });
  it('rejects bad cursors and limit bounds', async () => {
    const value = await app();
    const user = await account(value);
    for (const url of [
      '/api/v1/listings?cursor=x',
      '/api/v1/listings?limit=0',
      '/api/v1/listings?limit=51'
    ]) {
      const response = await value.inject({ method: 'GET', url, headers: auth(user.accessToken) });
      expect(response.statusCode).toBe(400);
      expect(response.json().error.code).toMatch(/BAD_CURSOR|VALIDATION_ERROR/);
    }
  });
  it('hides own, expired, and booked listings', async () => {
    const value = await app();
    const teacher = await account(value);
    const viewer = await account(value);
    const course = await createCourse(pool, await department());
    const location = await createLocation(pool);
    const own = await create(value, teacher, course, location);
    const expired = await create(value, teacher, course, location, {
      startAt: future(48),
      endAt: future(49)
    });
    const booked = await create(value, teacher, course, location);
    await pool.query(
      "UPDATE listings SET start_at = now() - interval '2 hours', end_at = now() - interval '1 hour' WHERE listing_id = $1",
      [expired.id]
    );
    await pool.query("UPDATE listings SET status = 'BOOKED' WHERE listing_id = $1", [booked.id]);
    const mine = await value.inject({
      method: 'GET',
      url: '/api/v1/listings?mine=true',
      headers: auth(teacher.accessToken)
    });
    const publicResults = await value.inject({
      method: 'GET',
      url: '/api/v1/listings',
      headers: auth(viewer.accessToken)
    });
    expect(
      (
        await value.inject({
          method: 'GET',
          url: '/api/v1/listings',
          headers: auth(teacher.accessToken)
        })
      )
        .json()
        .items.map((x: Item) => x.id)
    ).not.toContain(own.id);
    expect(mine.json().items.map((x: Item) => x.id)).toContain(own.id);
    expect(publicResults.json().items.map((x: Item) => x.id)).not.toEqual(
      expect.arrayContaining([expired.id, booked.id])
    );
    expect(
      (
        await pool.query<{ status: string }>(
          'SELECT effective_status AS status FROM v_listing_state WHERE listing_id = $1',
          [expired.id]
        )
      ).rows[0]!.status
    ).toBe('EXPIRED');
  });
});

describe('details, edits, and ownership', () => {
  it('returns details and validates unknown ids', async () => {
    const value = await app();
    const teacher = await account(value);
    const viewer = await account(value);
    const listing = await create(
      value,
      teacher,
      await createCourse(pool, await department()),
      await createLocation(pool)
    );
    expect(
      (
        await value.inject({
          method: 'GET',
          url: `/api/v1/listings/${listing.id}`,
          headers: auth(viewer.accessToken)
        })
      ).statusCode
    ).toBe(200);
    const missing = await value.inject({
      method: 'GET',
      url: `/api/v1/listings/${crypto.randomUUID()}`,
      headers: auth(viewer.accessToken)
    });
    const invalid = await value.inject({
      method: 'GET',
      url: '/api/v1/listings/nope',
      headers: auth(viewer.accessToken)
    });
    expect(missing.statusCode).toBe(404);
    expect(missing.json().error.code).toBe('LISTING_NOT_FOUND');
    expect(invalid.statusCode).toBe(400);
  });
  it('allows text edits after a pending request, but enforces ownership and field limits', async () => {
    const value = await app();
    const teacher = await account(value);
    const other = await account(value);
    const course = await createCourse(pool, await department());
    const location = await createLocation(pool);
    const listing = await create(value, teacher, course, location);
    await pool.query('INSERT INTO lesson_requests (listing_id, student_id) VALUES ($1, $2)', [
      listing.id,
      await createUser(pool)
    ]);
    const edited = await value.inject({
      method: 'PATCH',
      url: `/api/v1/listings/${listing.id}`,
      headers: auth(teacher.accessToken),
      payload: { topic: 'Edited', description: 'works' }
    });
    expect(edited.statusCode).toBe(200);
    expect(
      (
        await pool.query<{ topic: string }>('SELECT topic FROM listings WHERE listing_id = $1', [
          listing.id
        ])
      ).rows[0]!.topic
    ).toBe('Edited');
    const forbidden = await value.inject({
      method: 'PATCH',
      url: `/api/v1/listings/${listing.id}`,
      headers: auth(other.accessToken),
      payload: { topic: 'No' }
    });
    expect(forbidden.statusCode).toBe(403);
    expect(forbidden.json().error.code).toBe('NOT_LISTING_OWNER');
    for (const unsupported of [
      { startAt: future(48) },
      { endAt: future(49) },
      { tokenPrice: 3 },
      { courseId: crypto.randomUUID() },
      { locationId: crypto.randomUUID() }
    ]) {
      const response = await value.inject({
        method: 'PATCH',
        url: `/api/v1/listings/${listing.id}`,
        headers: auth(teacher.accessToken),
        payload: unsupported
      });
      expect(response.statusCode).toBe(400);
      expect(response.json().error.code).toBe('VALIDATION_ERROR');
    }
    const missing = await value.inject({
      method: 'PATCH',
      url: `/api/v1/listings/${crypto.randomUUID()}`,
      headers: auth(teacher.accessToken),
      payload: { topic: 'Missing' }
    });
    expect(missing.statusCode).toBe(404);
  });
});

describe('GET /me/listings and public users', () => {
  it('returns only own listings across statuses with pending counts', async () => {
    const value = await app();
    const teacher = await account(value);
    const other = await account(value);
    const course = await createCourse(pool, await department());
    const location = await createLocation(pool);
    const published = await create(value, teacher, course, location);
    const booked = await create(value, teacher, course, location);
    const completed = await create(value, teacher, course, location);
    const otherListing = await create(value, other, course, location);
    await pool.query("UPDATE listings SET status = 'BOOKED' WHERE listing_id IN ($1, $2)", [
      booked.id,
      completed.id
    ]);
    await pool.query("UPDATE listings SET status = 'COMPLETED' WHERE listing_id = $1", [
      completed.id
    ]);
    await pool.query('INSERT INTO lesson_requests (listing_id, student_id) VALUES ($1, $2)', [
      published.id,
      await createUser(pool)
    ]);
    const response = await value.inject({
      method: 'GET',
      url: '/api/v1/me/listings',
      headers: auth(teacher.accessToken)
    });
    const items = response.json() as Item[];
    expect(response.statusCode).toBe(200);
    expect(items.map((x) => x.id)).toEqual(
      expect.arrayContaining([published.id, booked.id, completed.id])
    );
    expect(items.map((x) => x.id)).not.toContain(otherListing.id);
    expect(items.find((x) => x.id === published.id)?.pendingRequestCount).toBe(1);
    expect(items.find((x) => x.id === booked.id)?.status).toBe('BOOKED');
    expect(items.find((x) => x.id === completed.id)?.status).toBe('COMPLETED');
  });
  it('does not leak profile secrets and returns USER_NOT_FOUND', async () => {
    const value = await app();
    const target = await createUser(pool);
    const response = await value.inject({ method: 'GET', url: `/api/v1/users/${target}` });
    const missing = await value.inject({
      method: 'GET',
      url: `/api/v1/users/${crypto.randomUUID()}`
    });
    expect(response.statusCode).toBe(200);
    expect(response.json()).not.toHaveProperty('email');
    expect(response.json()).not.toHaveProperty('phone');
    expect(response.json()).not.toHaveProperty('passwordHash');
    expect(missing.statusCode).toBe(404);
    expect(missing.json().error.code).toBe('USER_NOT_FOUND');
  });
});
