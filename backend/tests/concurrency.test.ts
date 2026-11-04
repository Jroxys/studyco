import { afterAll, afterEach, describe, expect, inject, it } from 'vitest';
import { Pool } from 'pg';

import { buildApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import type { MailSender } from '../src/mail/mail-sender.js';
import { confirmLessonAt } from './helpers/time-travel.js';

class Mail implements MailSender {
  async sendVerification(): Promise<void> {}
  async sendPasswordReset(): Promise<void> {}
}

type App = ReturnType<typeof buildApp>;
type Account = { user: { id: string }; accessToken: string };
type Response = { statusCode: number; json: () => { error?: { code: string }; id?: string } };

const databaseUrl = inject('testDatabaseUrl');
const pool = new Pool({ connectionString: databaseUrl, max: 20 });
const config = loadConfig({
  NODE_ENV: 'test',
  DATABASE_URL: databaseUrl,
  JWT_SECRET: 'a-very-long-test-jwt-secret-that-is-not-production',
  OTP_HMAC_SECRET: 'a-very-long-test-otp-hmac-secret-that-is-not-production',
  RATE_LIMIT_MAX: '1000'
});
const apps: App[] = [];

afterEach(async () => {
  await Promise.all(apps.splice(0).map((app) => app.close()));
});
afterAll(async () => {
  try {
    expect((await pool.query('SELECT * FROM v_integrity_violations')).rows).toHaveLength(0);
  } finally {
    await pool.end();
  }
});

async function app(): Promise<App> {
  const value = buildApp({ config, db: pool, mailSender: new Mail() });
  apps.push(value);
  await value.ready();
  return value;
}

function headers(account: Account) {
  return { authorization: `Bearer ${account.accessToken}` };
}
function body(response: Response) {
  return response.json();
}
function errorCode(response: Response) {
  return body(response).error?.code;
}

async function account(value: App): Promise<Account> {
  const departmentId = (
    await pool.query<{ id: string }>(
      'SELECT department_id AS id FROM departments WHERE is_active ORDER BY name LIMIT 1'
    )
  ).rows[0]!.id;
  const response = await value.inject({
    method: 'POST',
    url: '/api/v1/auth/register',
    payload: {
      firstName: 'Concurrency',
      lastName: 'Tester',
      birthDate: '2000-01-01',
      email: `${crypto.randomUUID()}@example.test`,
      phone: `+905${Math.floor(100000000 + Math.random() * 899999999)}`,
      password: 'secure-password-123',
      departmentId,
      termsAccepted: true,
      termsVersion: 'v1'
    }
  });
  expect(response.statusCode).toBe(201);
  return response.json() as Account;
}

async function listing(value: App, teacher: Account, start: Date, price = 2): Promise<string> {
  const departmentId = (
    await pool.query<{ id: string }>('SELECT department_id AS id FROM users WHERE user_id = $1', [
      teacher.user.id
    ])
  ).rows[0]!.id;
  const [course, location] = await Promise.all([
    pool.query<{ id: string }>(
      'INSERT INTO courses (department_id, course_name) VALUES ($1, $2) RETURNING course_id AS id',
      [departmentId, `Concurrency ${crypto.randomUUID()}`]
    ),
    pool.query<{ id: string }>(
      'INSERT INTO locations (name) VALUES ($1) RETURNING location_id AS id',
      [`Concurrency ${crypto.randomUUID()}`]
    )
  ]);
  const response = await value.inject({
    method: 'POST',
    url: '/api/v1/listings',
    headers: headers(teacher),
    payload: {
      courseId: course.rows[0]!.id,
      locationId: location.rows[0]!.id,
      topic: `Concurrency ${crypto.randomUUID()}`,
      startAt: start.toISOString(),
      endAt: new Date(start.getTime() + 60 * 60_000).toISOString(),
      tokenPrice: price
    }
  });
  expect(response.statusCode).toBe(201);
  return (response.json() as { id: string }).id;
}

async function request(value: App, student: Account, listingId: string): Promise<string> {
  const response = await value.inject({
    method: 'POST',
    url: `/api/v1/listings/${listingId}/requests`,
    headers: headers(student)
  });
  expect(response.statusCode).toBe(201);
  return (response.json() as { id: string }).id;
}

async function accept(value: App, teacher: Account, requestId: string): Promise<Response> {
  return value.inject({
    method: 'POST',
    url: `/api/v1/requests/${requestId}/accept`,
    headers: headers(teacher)
  });
}

async function assertIntegrity(ids: string[]): Promise<void> {
  const rows = await pool.query(
    'SELECT * FROM v_integrity_violations WHERE entity_id = ANY($1::text[])',
    [ids]
  );
  expect(rows.rows).toHaveLength(0);
}

async function requestState(id: string) {
  return (
    await pool.query<{ status: string; completion: string }>(
      'SELECT request_status AS status, completion_status AS completion FROM lesson_requests WHERE request_id = $1',
      [id]
    )
  ).rows[0]!;
}

async function wallet(userId: string) {
  return (
    await pool.query<{ available: number; held: number }>(
      'SELECT available_balance AS available, held_balance AS held FROM wallets WHERE user_id = $1',
      [userId]
    )
  ).rows[0]!;
}

async function count(sql: string, values: unknown[]): Promise<number> {
  return Number((await pool.query<{ count: string }>(sql, values)).rows[0]!.count);
}

function assertNoServerOrDeadlock(responses: Response[]): void {
  for (const response of responses) {
    expect(response.statusCode).not.toBe(500);
    expect(errorCode(response)).not.toBe('40P01');
  }
}

describe('request concurrency', () => {
  it('C1 accepts only one of two simultaneous requests for the same listing across ten rounds', async () => {
    const value = await app();
    for (let round = 0; round < 10; round += 1) {
      const teacher = await account(value);
      const students = await Promise.all([account(value), account(value)]);
      const listingId = await listing(
        value,
        teacher,
        new Date(Date.now() + (48 + round) * 3_600_000)
      );
      const ids = await Promise.all(students.map((student) => request(value, student, listingId)));
      const responses = await Promise.all(ids.map((id) => accept(value, teacher, id)));
      assertNoServerOrDeadlock(responses);
      expect(responses.filter((response) => response.statusCode === 200)).toHaveLength(1);
      expect(responses.filter((response) => response.statusCode === 409)).toHaveLength(1);
      expect(['LISTING_ALREADY_BOOKED', 'REQUEST_NOT_PENDING']).toContain(
        errorCode(responses.find((response) => response.statusCode === 409)!)
      );
      expect(
        await count(
          "SELECT count(*) FROM lesson_requests WHERE listing_id = $1 AND request_status = 'ACCEPTED'",
          [listingId]
        )
      ).toBe(1);
      expect(
        await count(
          "SELECT count(*) FROM wallet_transactions WHERE lesson_request_id = ANY($1::uuid[]) AND transaction_type = 'HOLD'",
          [ids]
        )
      ).toBe(1);
      expect(
        await count('SELECT count(*) FROM accepted_slots WHERE request_id = ANY($1::uuid[])', [ids])
      ).toBe(2);
      expect(
        (
          await pool.query<{ status: string }>(
            'SELECT status FROM listings WHERE listing_id = $1',
            [listingId]
          )
        ).rows
      ).toEqual([{ status: 'BOOKED' }]);
      await assertIntegrity([...ids, listingId, ...students.map((student) => student.user.id)]);
    }
  });

  it('C2 enforces TIME_CONFLICT when two overlapping accepts race across ten rounds', async () => {
    const value = await app();
    for (let round = 0; round < 10; round += 1) {
      const student = await account(value);
      const teachers = await Promise.all([account(value), account(value)]);
      const start = new Date(Date.now() + (72 + round * 3) * 3_600_000);
      const listings = await Promise.all([
        listing(value, teachers[0]!, start),
        listing(value, teachers[1]!, new Date(start.getTime() + 30 * 60_000))
      ]);
      const ids = await Promise.all(listings.map((id) => request(value, student, id)));
      const responses = await Promise.all(
        ids.map((id, index) => accept(value, teachers[index]!, id))
      );
      assertNoServerOrDeadlock(responses);
      expect(responses.filter((response) => response.statusCode === 200)).toHaveLength(1);
      expect(
        responses.filter(
          (response) => response.statusCode === 409 && errorCode(response) === 'REQUEST_NOT_PENDING'
        )
      ).toHaveLength(1);
      expect(
        await count(
          "SELECT count(*) FROM lesson_requests WHERE request_id = ANY($1::uuid[]) AND request_status = 'ACCEPTED'",
          [ids]
        )
      ).toBe(1);
      expect(
        await count(
          "SELECT count(*) FROM lesson_requests WHERE request_id = ANY($1::uuid[]) AND request_status = 'AUTO_CANCELLED' AND auto_cancel_reason = 'TIME_CONFLICT'",
          [ids]
        )
      ).toBe(1);
      expect(
        await count(
          "SELECT count(*) FROM wallet_transactions WHERE lesson_request_id = ANY($1::uuid[]) AND transaction_type = 'HOLD'",
          [ids]
        )
      ).toBe(1);
      expect(
        await count('SELECT count(*) FROM accepted_slots WHERE request_id = ANY($1::uuid[])', [ids])
      ).toBe(2);
      await assertIntegrity([
        ...ids,
        ...listings,
        student.user.id,
        ...teachers.map((teacher) => teacher.user.id)
      ]);
    }
  });

  it('C3 creates one hold when the same request is accepted twice simultaneously across ten rounds', async () => {
    const value = await app();
    for (let round = 0; round < 10; round += 1) {
      const teacher = await account(value);
      const student = await account(value);
      const listingId = await listing(
        value,
        teacher,
        new Date(Date.now() + (120 + round) * 3_600_000)
      );
      const id = await request(value, student, listingId);
      const responses = await Promise.all([accept(value, teacher, id), accept(value, teacher, id)]);
      assertNoServerOrDeadlock(responses);
      expect(responses.filter((response) => response.statusCode === 200)).toHaveLength(1);
      expect(responses.filter((response) => response.statusCode === 409)).toHaveLength(1);
      expect(errorCode(responses.find((response) => response.statusCode === 409)!)).toBe(
        'REQUEST_NOT_PENDING'
      );
      expect(await requestState(id)).toMatchObject({
        status: 'ACCEPTED',
        completion: 'AWAITING_CONFIRMATION'
      });
      expect(
        await count(
          "SELECT count(*) FROM wallet_transactions WHERE lesson_request_id = $1 AND transaction_type = 'HOLD'",
          [id]
        )
      ).toBe(1);
      expect(await count('SELECT count(*) FROM accepted_slots WHERE request_id = $1', [id])).toBe(
        2
      );
      expect(await wallet(student.user.id)).toEqual({ available: 8, held: 2 });
      await assertIntegrity([id, listingId, teacher.user.id, student.user.id]);
    }
  });

  it('C4 settles exactly once when both participants confirm concurrently after time travel across ten rounds', async () => {
    const value = await app();
    for (let round = 0; round < 10; round += 1) {
      const teacher = await account(value);
      const student = await account(value);
      const start = new Date(Date.now() + (160 + round) * 3_600_000);
      const listingId = await listing(value, teacher, start);
      const id = await request(value, student, listingId);
      const accepted = await accept(value, teacher, id);
      expect(accepted.statusCode).toBe(200);
      expect(errorCode(accepted)).toBeUndefined();
      const afterEnd = new Date(start.getTime() + 61 * 60_000);
      await Promise.all([
        confirmLessonAt(pool, id, student.user.id, afterEnd),
        confirmLessonAt(pool, id, teacher.user.id, afterEnd)
      ]);
      expect(await requestState(id)).toMatchObject({ status: 'ACCEPTED', completion: 'COMPLETED' });
      expect(
        await count(
          "SELECT count(*) FROM wallet_transactions WHERE lesson_request_id = $1 AND transaction_type = 'SETTLEMENT_DEBIT'",
          [id]
        )
      ).toBe(1);
      expect(
        await count(
          "SELECT count(*) FROM wallet_transactions WHERE lesson_request_id = $1 AND transaction_type = 'SETTLEMENT_CREDIT'",
          [id]
        )
      ).toBe(1);
      expect(await count('SELECT count(*) FROM accepted_slots WHERE request_id = $1', [id])).toBe(
        2
      );
      expect(await wallet(student.user.id)).toEqual({ available: 8, held: 0 });
      expect(await wallet(teacher.user.id)).toEqual({ available: 12, held: 0 });
      await assertIntegrity([id, listingId, teacher.user.id, student.user.id]);
    }
  });

  it('C5 leaves no pending request when acceptance races a new request across ten rounds', async () => {
    const value = await app();
    for (let round = 0; round < 10; round += 1) {
      const teacher = await account(value);
      const acceptedStudent = await account(value);
      const racingStudent = await account(value);
      const listingId = await listing(
        value,
        teacher,
        new Date(Date.now() + (200 + round) * 3_600_000)
      );
      const acceptedId = await request(value, acceptedStudent, listingId);
      const [accepted, racing] = await Promise.all([
        accept(value, teacher, acceptedId),
        value.inject({
          method: 'POST',
          url: `/api/v1/listings/${listingId}/requests`,
          headers: headers(racingStudent)
        })
      ]);
      assertNoServerOrDeadlock([accepted, racing]);
      expect(accepted.statusCode).toBe(200);
      expect(errorCode(accepted)).toBeUndefined();
      expect([201, 409]).toContain(racing.statusCode);
      if (racing.statusCode === 409) expect(errorCode(racing)).toBe('LISTING_NOT_PUBLISHED');
      const requestIds = (
        await pool.query<{ id: string }>(
          'SELECT request_id AS id FROM lesson_requests WHERE listing_id = $1',
          [listingId]
        )
      ).rows.map((row) => row.id);
      expect(
        await count(
          "SELECT count(*) FROM lesson_requests WHERE listing_id = $1 AND request_status = 'PENDING'",
          [listingId]
        )
      ).toBe(0);
      expect(
        await count(
          "SELECT count(*) FROM lesson_requests WHERE listing_id = $1 AND request_status = 'ACCEPTED'",
          [listingId]
        )
      ).toBe(1);
      expect(
        await count(
          "SELECT count(*) FROM wallet_transactions WHERE lesson_request_id = $1 AND transaction_type = 'HOLD'",
          [acceptedId]
        )
      ).toBe(1);
      expect(
        await count('SELECT count(*) FROM accepted_slots WHERE request_id = $1', [acceptedId])
      ).toBe(2);
      await assertIntegrity([
        ...requestIds,
        listingId,
        teacher.user.id,
        acceptedStudent.user.id,
        racingStudent.user.id
      ]);
    }
  });

  it('C6 allows one of two simultaneous paid accepts with exactly one lesson balance across ten rounds', async () => {
    const value = await app();
    for (let round = 0; round < 10; round += 1) {
      const student = await account(value);
      const teachers = await Promise.all([account(value), account(value)]);
      const start = new Date(Date.now() + (240 + round * 3) * 3_600_000);
      const fundingTeacher = await account(value);
      for (const [offset, price] of [
        [-12, 3],
        [-10, 3],
        [-8, 1]
      ] as const) {
        const fundedListing = await listing(
          value,
          fundingTeacher,
          new Date(start.getTime() + offset * 3_600_000),
          price
        );
        const fundedRequest = await request(value, student, fundedListing);
        const funded = await accept(value, fundingTeacher, fundedRequest);
        expect(funded.statusCode).toBe(200);
      }
      expect(await wallet(student.user.id)).toEqual({ available: 3, held: 7 });
      const listings = await Promise.all([
        listing(value, teachers[0]!, start, 3),
        listing(value, teachers[1]!, new Date(start.getTime() + 2 * 3_600_000), 3)
      ]);
      const ids = await Promise.all(listings.map((id) => request(value, student, id)));
      const responses = await Promise.all(
        ids.map((id, index) => accept(value, teachers[index]!, id))
      );
      assertNoServerOrDeadlock(responses);
      expect(responses.filter((response) => response.statusCode === 200)).toHaveLength(1);
      expect(
        responses.filter(
          (response) =>
            response.statusCode === 402 && errorCode(response) === 'INSUFFICIENT_BALANCE'
        )
      ).toHaveLength(1);
      expect(
        await count(
          "SELECT count(*) FROM lesson_requests WHERE request_id = ANY($1::uuid[]) AND request_status = 'ACCEPTED'",
          [ids]
        )
      ).toBe(1);
      expect(
        await count(
          "SELECT count(*) FROM wallet_transactions WHERE lesson_request_id = ANY($1::uuid[]) AND transaction_type = 'HOLD'",
          [ids]
        )
      ).toBe(1);
      expect(
        await count('SELECT count(*) FROM accepted_slots WHERE request_id = ANY($1::uuid[])', [ids])
      ).toBe(2);
      expect(await wallet(student.user.id)).toEqual({ available: 0, held: 10 });
      await assertIntegrity([
        ...ids,
        ...listings,
        student.user.id,
        fundingTeacher.user.id,
        ...teachers.map((teacher) => teacher.user.id)
      ]);
    }
  });
}, 60_000);
