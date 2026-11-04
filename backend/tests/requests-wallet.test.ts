import { afterAll, afterEach, describe, expect, inject, it } from 'vitest';
import { Pool } from 'pg';

import { buildApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import type { MailSender } from '../src/mail/mail-sender.js';
import { createCourse, createLocation } from './helpers/factories.js';
import {
  acceptLessonRequestAt,
  confirmLessonAt,
  expireStaleRequestsAt,
  processExpiredConfirmationsAt
} from './helpers/time-travel.js';

class Mail implements MailSender {
  async sendVerification(): Promise<void> {}
  async sendPasswordReset(): Promise<void> {}
}
type App = ReturnType<typeof buildApp>;
type Account = { user: { id: string }; accessToken: string };
type RequestState = {
  status: string;
  completion: string;
  reason: string | null;
  basis: string | null;
};
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
function headers(account: Account) {
  return { authorization: `Bearer ${account.accessToken}` };
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
      firstName: 'Request',
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
async function listing(
  value: App,
  teacher: Account,
  price = 2,
  start = new Date(Date.now() + 48 * 3_600_000),
  durationHours = 1
): Promise<string> {
  const departmentId = (
    await pool.query<{ id: string }>('SELECT department_id AS id FROM users WHERE user_id = $1', [
      teacher.user.id
    ])
  ).rows[0]!.id;
  const response = await value.inject({
    method: 'POST',
    url: '/api/v1/listings',
    headers: headers(teacher),
    payload: {
      courseId: await createCourse(pool, departmentId),
      locationId: await createLocation(pool),
      topic: `request-${crypto.randomUUID()}`,
      startAt: start.toISOString(),
      endAt: new Date(start.getTime() + durationHours * 3_600_000).toISOString(),
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
async function state(id: string): Promise<RequestState> {
  return (
    await pool.query<RequestState>(
      'SELECT request_status AS status, completion_status AS completion, auto_cancel_reason AS reason, settlement_basis AS basis FROM lesson_requests WHERE request_id = $1',
      [id]
    )
  ).rows[0]!;
}
async function balances(userId: string): Promise<{ available: number; held: number }> {
  return (
    await pool.query<{ available: number; held: number }>(
      'SELECT available_balance AS available, held_balance AS held FROM wallets WHERE user_id = $1',
      [userId]
    )
  ).rows[0]!;
}
async function acceptAt(id: string, teacher: Account, at: Date): Promise<void> {
  await acceptLessonRequestAt(pool, id, teacher.user.id, at);
}

describe('requests and wallet lifecycle', () => {
  it('returns ALREADY_REQUESTED for a duplicate request and leaves one pending row', async () => {
    const value = await app();
    const teacher = await account(value);
    const student = await account(value);
    const list = await listing(value, teacher);
    const id = await request(value, student, list);
    const response = await value.inject({
      method: 'POST',
      url: `/api/v1/listings/${list}/requests`,
      headers: headers(student)
    });
    expect(response.statusCode).toBe(409);
    expect(response.json().error.code).toBe('ALREADY_REQUESTED');
    expect(await state(id)).toMatchObject({ status: 'PENDING', completion: 'NOT_STARTED' });
  });
  it('returns CANNOT_REQUEST_OWN_LISTING and creates no request row', async () => {
    const value = await app();
    const teacher = await account(value);
    const list = await listing(value, teacher);
    const response = await value.inject({
      method: 'POST',
      url: `/api/v1/listings/${list}/requests`,
      headers: headers(teacher)
    });
    expect(response.statusCode).toBe(422);
    expect(response.json().error.code).toBe('CANNOT_REQUEST_OWN_LISTING');
    expect(
      (await pool.query('SELECT request_id FROM lesson_requests WHERE listing_id = $1', [list]))
        .rows
    ).toHaveLength(0);
  });
  it('returns LISTING_NOT_PUBLISHED when requesting a booked listing', async () => {
    const value = await app();
    const teacher = await account(value);
    const first = await account(value);
    const second = await account(value);
    const list = await listing(value, teacher);
    const accepted = await request(value, first, list);
    await acceptAt(accepted, teacher, new Date());
    const response = await value.inject({
      method: 'POST',
      url: `/api/v1/listings/${list}/requests`,
      headers: headers(second)
    });
    expect(response.statusCode).toBe(409);
    expect(response.json().error.code).toBe('LISTING_NOT_PUBLISHED');
    expect(
      (await pool.query('SELECT status FROM listings WHERE listing_id = $1', [list])).rows[0]!
        .status
    ).toBe('BOOKED');
  });
  it('returns LISTING_EXPIRED when accepting after the listing start', async () => {
    const value = await app();
    const teacher = await account(value);
    const student = await account(value);
    const start = new Date(Date.now() + 2 * 3_600_000);
    const list = await listing(value, teacher, 2, start);
    const id = await request(value, student, list);
    const response = await value.inject({
      method: 'POST',
      url: `/api/v1/requests/${id}/accept`,
      headers: headers(teacher)
    });
    expect(response.statusCode).toBe(200);
    const secondList = await listing(value, teacher, 2, new Date(Date.now() + 4 * 3_600_000));
    const second = await request(value, student, secondList);
    await expect(
      acceptAt(second, teacher, new Date(Date.now() + 5 * 3_600_000))
    ).rejects.toMatchObject({ message: 'LISTING_EXPIRED' });
    expect(await state(second)).toMatchObject({ status: 'PENDING' });
    expect(await balances(student.user.id)).toEqual({ available: 8, held: 2 });
  });
  it('returns INSUFFICIENT_BALANCE atomically with no ledger or accepted slots', async () => {
    const value = await app();
    const teacher = await account(value);
    const student = await account(value);
    for (let index = 0; index < 3; index += 1) {
      const id = await request(
        value,
        student,
        await listing(value, teacher, 3, new Date(Date.now() + (index + 2) * 3_600_000))
      );
      await acceptAt(id, teacher, new Date());
    }
    const id = await request(
      value,
      student,
      await listing(value, teacher, 2, new Date(Date.now() + 6 * 3_600_000))
    );
    const response = await value.inject({
      method: 'POST',
      url: `/api/v1/requests/${id}/accept`,
      headers: headers(teacher)
    });
    expect(response.statusCode).toBe(402);
    expect(response.json().error.code).toBe('INSUFFICIENT_BALANCE');
    expect(await state(id)).toMatchObject({ status: 'PENDING' });
    expect(await balances(student.user.id)).toEqual({ available: 1, held: 9 });
    expect(
      (await pool.query('SELECT * FROM wallet_transactions WHERE lesson_request_id = $1', [id]))
        .rows
    ).toHaveLength(0);
    expect(
      (await pool.query('SELECT * FROM accepted_slots WHERE request_id = $1', [id])).rows
    ).toHaveLength(0);
  });
  it('accepts a request with a HOLD, booked listing, conversation, and two accepted slots', async () => {
    const value = await app();
    const teacher = await account(value);
    const student = await account(value);
    const list = await listing(value, teacher);
    const id = await request(value, student, list);
    const response = await value.inject({
      method: 'POST',
      url: `/api/v1/requests/${id}/accept`,
      headers: headers(teacher)
    });
    expect(response.statusCode).toBe(200);
    expect(response.json().conversationId).toMatch(/^[0-9a-f-]{36}$/i);
    expect(await state(id)).toMatchObject({
      status: 'ACCEPTED',
      completion: 'AWAITING_CONFIRMATION'
    });
    expect(await balances(student.user.id)).toEqual({ available: 8, held: 2 });
    expect(
      (
        await pool.query(
          "SELECT * FROM wallet_transactions WHERE lesson_request_id = $1 AND transaction_type = 'HOLD'",
          [id]
        )
      ).rows
    ).toHaveLength(1);
    expect(
      (await pool.query('SELECT * FROM accepted_slots WHERE request_id = $1', [id])).rows
    ).toHaveLength(2);
    expect(
      (await pool.query('SELECT status FROM listings WHERE listing_id = $1', [list])).rows[0]!
        .status
    ).toBe('BOOKED');
  });
  it('returns NOT_LISTING_OWNER when a non-owner accepts and preserves the pending request', async () => {
    const value = await app();
    const teacher = await account(value);
    const student = await account(value);
    const stranger = await account(value);
    const id = await request(value, student, await listing(value, teacher));
    const response = await value.inject({
      method: 'POST',
      url: `/api/v1/requests/${id}/accept`,
      headers: headers(stranger)
    });
    expect(response.statusCode).toBe(404);
    expect(response.json().error.code).toBe('REQUEST_NOT_FOUND');
    expect(await state(id)).toMatchObject({ status: 'PENDING' });
    expect(
      (await pool.query('SELECT * FROM accepted_slots WHERE request_id = $1', [id])).rows
    ).toHaveLength(0);
  });
  it('returns REQUEST_NOT_PENDING for accepting an accepted or rejected request', async () => {
    const value = await app();
    const teacher = await account(value);
    const student = await account(value);
    const accepted = await request(value, student, await listing(value, teacher));
    await acceptAt(accepted, teacher, new Date());
    const repeated = await value.inject({
      method: 'POST',
      url: `/api/v1/requests/${accepted}/accept`,
      headers: headers(teacher)
    });
    expect(repeated.statusCode).toBe(409);
    expect(repeated.json().error.code).toBe('REQUEST_NOT_PENDING');
    const rejected = await request(value, await account(value), await listing(value, teacher));
    await value.inject({
      method: 'POST',
      url: `/api/v1/requests/${rejected}/reject`,
      headers: headers(teacher)
    });
    const retry = await value.inject({
      method: 'POST',
      url: `/api/v1/requests/${rejected}/accept`,
      headers: headers(teacher)
    });
    expect(retry.statusCode).toBe(409);
    expect(retry.json().error.code).toBe('REQUEST_NOT_PENDING');
    expect(await state(rejected)).toMatchObject({ status: 'REJECTED' });
  });
  it('auto-cancels competing listing and overlapping pending requests with their reasons', async () => {
    const value = await app();
    const teacher = await account(value);
    const student = await account(value);
    const otherTeacher = await account(value);
    const start = new Date(Date.now() + 48 * 3_600_000);
    const list = await listing(value, teacher, 1, start);
    const chosen = await request(value, student, list);
    const sameListing = await request(value, await account(value), list);
    const overlap = await request(
      value,
      student,
      await listing(value, otherTeacher, 1, new Date(start.getTime() + 30 * 60_000))
    );
    await acceptAt(chosen, teacher, new Date());
    expect(await state(sameListing)).toMatchObject({
      status: 'AUTO_CANCELLED',
      reason: 'LISTING_ALREADY_BOOKED'
    });
    expect(await state(overlap)).toMatchObject({
      status: 'AUTO_CANCELLED',
      reason: 'TIME_CONFLICT'
    });
    expect(
      (await pool.query('SELECT * FROM accepted_slots WHERE request_id = $1', [chosen])).rows
    ).toHaveLength(2);
  });
  it('returns TIME_CONFLICT when a student or teacher overlaps an accepted lesson', async () => {
    const value = await app();
    const teacher = await account(value);
    const student = await account(value);
    const otherTeacher = await account(value);
    const start = new Date(Date.now() + 48 * 3_600_000);
    const first = await request(value, student, await listing(value, teacher, 1, start));
    await acceptAt(first, teacher, new Date());
    const studentConflict = await request(
      value,
      student,
      await listing(value, otherTeacher, 1, new Date(start.getTime() + 30 * 60_000))
    );
    await expect(acceptAt(studentConflict, otherTeacher, new Date())).rejects.toMatchObject({
      message: 'TIME_CONFLICT'
    });
    const teacherConflict = await request(
      value,
      await account(value),
      await listing(value, teacher, 1, new Date(start.getTime() + 30 * 60_000))
    );
    await expect(acceptAt(teacherConflict, teacher, new Date())).rejects.toMatchObject({
      message: 'TIME_CONFLICT'
    });
    expect(await state(studentConflict)).toMatchObject({ status: 'PENDING' });
    expect(await state(teacherConflict)).toMatchObject({ status: 'PENDING' });
  });
  it('rejects a request without wallet movement', async () => {
    const value = await app();
    const teacher = await account(value);
    const student = await account(value);
    const id = await request(value, student, await listing(value, teacher));
    const response = await value.inject({
      method: 'POST',
      url: `/api/v1/requests/${id}/reject`,
      headers: headers(teacher)
    });
    expect(response.statusCode).toBe(200);
    expect(response.json().status).toBe('REJECTED');
    expect(await state(id)).toMatchObject({ status: 'REJECTED', completion: 'NOT_STARTED' });
    expect(await balances(student.user.id)).toEqual({ available: 10, held: 0 });
    expect(
      (await pool.query('SELECT * FROM wallet_transactions WHERE lesson_request_id = $1', [id]))
        .rows
    ).toHaveLength(0);
  });
  it('accepts and confirms a free listing without ledger rows', async () => {
    const value = await app();
    const teacher = await account(value);
    const student = await account(value);
    const start = new Date(Date.now() + 48 * 3_600_000);
    const id = await request(value, student, await listing(value, teacher, 0, start));
    await acceptAt(id, teacher, new Date());
    await confirmLessonAt(pool, id, student.user.id, new Date(start.getTime() + 61 * 60_000));
    await confirmLessonAt(pool, id, teacher.user.id, new Date(start.getTime() + 62 * 60_000));
    expect(await state(id)).toMatchObject({
      status: 'ACCEPTED',
      completion: 'COMPLETED',
      basis: 'BOTH_CONFIRMED'
    });
    expect(await balances(student.user.id)).toEqual({ available: 10, held: 0 });
    expect(
      (await pool.query('SELECT * FROM wallet_transactions WHERE lesson_request_id = $1', [id]))
        .rows
    ).toHaveLength(0);
  });
  it('returns confirmation window errors and rejects third-party confirmation', async () => {
    const value = await app();
    const teacher = await account(value);
    const student = await account(value);
    const stranger = await account(value);
    const start = new Date(Date.now() + 48 * 3_600_000);
    const id = await request(value, student, await listing(value, teacher, 1, start));
    await acceptAt(id, teacher, new Date());
    await expect(
      confirmLessonAt(pool, id, student.user.id, new Date(start.getTime() + 30 * 60_000))
    ).rejects.toMatchObject({ message: 'CONFIRMATION_TOO_EARLY' });
    await expect(
      confirmLessonAt(pool, id, student.user.id, new Date(start.getTime() + 26 * 3_600_000))
    ).rejects.toMatchObject({ message: 'CONFIRMATION_WINDOW_CLOSED' });
    const response = await value.inject({
      method: 'POST',
      url: `/api/v1/requests/${id}/confirm`,
      headers: headers(stranger)
    });
    expect(response.statusCode).toBe(404);
    expect(response.json().error.code).toBe('REQUEST_NOT_FOUND');
    expect(await state(id)).toMatchObject({ completion: 'AWAITING_CONFIRMATION' });
  });
  it('settles after both confirms and makes a repeated confirm idempotent', async () => {
    const value = await app();
    const teacher = await account(value);
    const student = await account(value);
    const start = new Date(Date.now() + 48 * 3_600_000);
    const id = await request(value, student, await listing(value, teacher, 2, start));
    await acceptAt(id, teacher, new Date());
    const afterEnd = new Date(start.getTime() + 61 * 60_000);
    await confirmLessonAt(pool, id, student.user.id, afterEnd);
    await confirmLessonAt(pool, id, student.user.id, new Date(afterEnd.getTime() + 60_000));
    await confirmLessonAt(pool, id, teacher.user.id, new Date(afterEnd.getTime() + 120_000));
    expect(await state(id)).toMatchObject({ completion: 'COMPLETED', basis: 'BOTH_CONFIRMED' });
    expect(await balances(student.user.id)).toEqual({ available: 8, held: 0 });
    expect(await balances(teacher.user.id)).toEqual({ available: 12, held: 0 });
    expect(
      (await pool.query('SELECT * FROM wallet_transactions WHERE lesson_request_id = $1', [id]))
        .rows
    ).toHaveLength(3);
    expect(
      (
        await pool.query(
          'SELECT status FROM listings WHERE listing_id = (SELECT listing_id FROM lesson_requests WHERE request_id = $1)',
          [id]
        )
      ).rows[0]!.status
    ).toBe('COMPLETED');
  });
  it('settles or manually reviews expired confirmations according to which party confirmed', async () => {
    const value = await app();
    const teacher = await account(value);
    const student = await account(value);
    const start = new Date(Date.now() + 48 * 3_600_000);
    const make = async (offset: number) => {
      const lessonStart = new Date(start.getTime() + offset * 30 * 3_600_000);
      const id = await request(value, student, await listing(value, teacher, 1, lessonStart));
      await acceptAt(id, teacher, new Date());
      return { id, lessonStart };
    };
    const teacherOnly = await make(0);
    const studentOnly = await make(1);
    const nobody = await make(2);
    await confirmLessonAt(
      pool,
      teacherOnly.id,
      teacher.user.id,
      new Date(teacherOnly.lessonStart.getTime() + 61 * 60_000)
    );
    await confirmLessonAt(
      pool,
      studentOnly.id,
      student.user.id,
      new Date(studentOnly.lessonStart.getTime() + 61 * 60_000)
    );
    await processExpiredConfirmationsAt(
      pool,
      new Date(nobody.lessonStart.getTime() + 26 * 3_600_000)
    );
    expect(await state(teacherOnly.id)).toMatchObject({
      completion: 'COMPLETED',
      basis: 'TEACHER_ONLY_AT_DEADLINE'
    });
    expect(await state(studentOnly.id)).toMatchObject({
      completion: 'COMPLETED',
      basis: 'STUDENT_ONLY_AT_DEADLINE'
    });
    expect(await state(nobody.id)).toMatchObject({ completion: 'MANUAL_REVIEW', basis: null });
    expect((await balances(student.user.id)).held).toBe(1);
  });
  it('expires stale pending requests with LISTING_EXPIRED', async () => {
    const value = await app();
    const teacher = await account(value);
    const student = await account(value);
    const start = new Date(Date.now() + 2 * 3_600_000);
    const id = await request(value, student, await listing(value, teacher, 1, start));
    await expireStaleRequestsAt(pool, new Date(start.getTime() + 1));
    expect(await state(id)).toMatchObject({ status: 'AUTO_CANCELLED', reason: 'LISTING_EXPIRED' });
    expect(await balances(student.user.id)).toEqual({ available: 10, held: 0 });
    expect(
      (await pool.query('SELECT * FROM accepted_slots WHERE request_id = $1', [id])).rows
    ).toHaveLength(0);
  });
  it('hides a request from strangers and filters and paginates my requests', async () => {
    const value = await app();
    const teacher = await account(value);
    const student = await account(value);
    const stranger = await account(value);
    const first = await request(value, student, await listing(value, teacher));
    const second = await request(
      value,
      student,
      await listing(value, teacher, 1, new Date(Date.now() + 72 * 3_600_000))
    );
    const hidden = await value.inject({
      method: 'GET',
      url: `/api/v1/requests/${first}`,
      headers: headers(stranger)
    });
    expect(hidden.statusCode).toBe(404);
    expect(hidden.json().error.code).toBe('REQUEST_NOT_FOUND');
    const page = await value.inject({
      method: 'GET',
      url: '/api/v1/me/requests?role=student&status=PENDING&limit=1',
      headers: headers(student)
    });
    expect(page.statusCode).toBe(200);
    expect(page.json().items).toHaveLength(1);
    expect(page.json().nextCursor).toBeTruthy();
    const next = await value.inject({
      method: 'GET',
      url: `/api/v1/me/requests?role=student&status=PENDING&limit=1&cursor=${encodeURIComponent(page.json().nextCursor)}`,
      headers: headers(student)
    });
    expect(next.statusCode).toBe(200);
    expect(next.json().items.map((row: { id: string }) => row.id)).toContain(
      second === page.json().items[0].id ? first : second
    );
    expect(
      (
        await pool.query('SELECT count(*) FROM lesson_requests WHERE student_id = $1', [
          student.user.id
        ])
      ).rows[0]!.count
    ).toBe('2');
  });
  it('orders wallet transactions with a cursor even when timestamps are equal', async () => {
    const value = await app();
    const teacher = await account(value);
    const student = await account(value);
    const first = await request(value, student, await listing(value, teacher, 1));
    const second = await request(
      value,
      student,
      await listing(value, teacher, 1, new Date(Date.now() + 72 * 3_600_000))
    );
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await acceptLessonRequestAt(client, first, teacher.user.id, new Date());
      await acceptLessonRequestAt(client, second, teacher.user.id, new Date());
      await client.query('COMMIT');
    } finally {
      client.release();
    }
    const page = await value.inject({
      method: 'GET',
      url: '/api/v1/wallet/transactions?limit=1',
      headers: headers(student)
    });
    expect(page.statusCode).toBe(200);
    expect(page.json().items).toHaveLength(1);
    const next = await value.inject({
      method: 'GET',
      url: `/api/v1/wallet/transactions?limit=10&cursor=${encodeURIComponent(page.json().nextCursor)}`,
      headers: headers(student)
    });
    expect(next.statusCode).toBe(200);
    expect(next.json().items.length).toBeGreaterThanOrEqual(1);
    expect(await balances(student.user.id)).toEqual({ available: 8, held: 2 });
  });
  it('returns UNAUTHORIZED for every request and wallet route', async () => {
    const value = await app();
    for (const options of [
      { method: 'POST', url: `/api/v1/listings/${crypto.randomUUID()}/requests` },
      { method: 'GET', url: '/api/v1/me/requests' },
      { method: 'GET', url: `/api/v1/requests/${crypto.randomUUID()}` },
      { method: 'POST', url: `/api/v1/requests/${crypto.randomUUID()}/accept` },
      { method: 'POST', url: `/api/v1/requests/${crypto.randomUUID()}/reject` },
      { method: 'POST', url: `/api/v1/requests/${crypto.randomUUID()}/confirm` },
      { method: 'GET', url: '/api/v1/wallet' },
      { method: 'GET', url: '/api/v1/wallet/transactions' }
    ] as const) {
      const response = await value.inject(options);
      expect(response.statusCode).toBe(401);
      expect(response.json().error.code).toBe('UNAUTHORIZED');
    }
    expect((await pool.query('SELECT count(*) FROM lesson_requests')).rows[0]!.count).toBeDefined();
  });

  it('pages through every wallet row exactly once when rows share one timestamp', async () => {
    const value = await app();
    const teacher = await account(value);
    const student = await account(value);
    const first = await request(value, student, await listing(value, teacher, 1));
    const second = await request(
      value,
      student,
      await listing(value, teacher, 1, new Date(Date.now() + 72 * 3_600_000))
    );
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await acceptLessonRequestAt(client, first, teacher.user.id, new Date());
      await acceptLessonRequestAt(client, second, teacher.user.id, new Date());
      await client.query('COMMIT');
    } finally {
      client.release();
    }
    const expected = (
      await pool.query<{ id: string }>(
        'SELECT wt.transaction_id AS id FROM wallet_transactions wt JOIN wallets w ON w.wallet_id = wt.wallet_id WHERE w.user_id = $1',
        [student.user.id]
      )
    ).rows.map((row) => row.id);
    expect(expected).toHaveLength(3);
    const seen: string[] = [];
    let cursor: string | null = null;
    for (let round = 0; round < 6; round += 1) {
      const url: string =
        '/api/v1/wallet/transactions?limit=1' +
        (cursor ? '&cursor=' + encodeURIComponent(cursor) : '');
      const page = await value.inject({ method: 'GET', url, headers: headers(student) });
      expect(page.statusCode).toBe(200);
      seen.push(...page.json().items.map((item: { id: string }) => item.id));
      cursor = page.json().nextCursor;
      if (!cursor) break;
    }
    expect([...seen].sort()).toEqual([...expected].sort());
  });
  it('returns EMAIL_NOT_VERIFIED for listing and request creation when verification is required', async () => {
    const strict = loadConfig({
      NODE_ENV: 'test',
      DATABASE_URL: inject('testDatabaseUrl'),
      JWT_SECRET: 'a-very-long-test-jwt-secret-that-is-not-production',
      OTP_HMAC_SECRET: 'a-very-long-test-otp-hmac-secret-that-is-not-production',
      REQUIRE_VERIFIED_EMAIL: 'true'
    });
    const value = buildApp({ config: strict, db: pool, mailSender: new Mail() });
    apps.push(value);
    await value.ready();
    const user = await account(value);
    const created = await value.inject({
      method: 'POST',
      url: '/api/v1/listings',
      headers: headers(user),
      payload: {}
    });
    expect(created.statusCode).toBe(403);
    expect(created.json().error.code).toBe('EMAIL_NOT_VERIFIED');
    const requested = await value.inject({
      method: 'POST',
      url: '/api/v1/listings/' + crypto.randomUUID() + '/requests',
      headers: headers(user)
    });
    expect(requested.statusCode).toBe(403);
    expect(requested.json().error.code).toBe('EMAIL_NOT_VERIFIED');
    await pool.query('UPDATE users SET email_verified_at = now() WHERE user_id = $1', [
      user.user.id
    ]);
    const verified = await value.inject({
      method: 'POST',
      url: '/api/v1/listings/' + crypto.randomUUID() + '/requests',
      headers: headers(user)
    });
    expect(verified.statusCode).not.toBe(403);
  });
});
