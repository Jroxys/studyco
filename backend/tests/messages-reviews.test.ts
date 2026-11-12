import { afterAll, afterEach, describe, expect, inject, it } from 'vitest';
import { Pool } from 'pg';

import { buildApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import type { MailSender } from '../src/mail/mail-sender.js';
import { createListing } from './helpers/factories.js';
import { acceptLessonRequestAt, confirmLessonAt } from './helpers/time-travel.js';

class Mail implements MailSender {
  async sendVerification(): Promise<void> {}
  async sendPasswordReset(): Promise<void> {}
}
type App = ReturnType<typeof buildApp>;
type Account = { user: { id: string }; accessToken: string };
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
function auth(account: Account) {
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
      firstName: 'Message',
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
async function accepted(value: App): Promise<{
  teacher: Account;
  student: Account;
  stranger: Account;
  requestId: string;
  conversationId: string;
  start: Date;
}> {
  const teacher = await account(value);
  const student = await account(value);
  const stranger = await account(value);
  const start = new Date(Date.now() + 48 * 3_600_000);
  const listingId = await createListing(pool, { teacherId: teacher.user.id, startAt: start });
  const requestId = (
    await pool.query<{ id: string }>(
      'INSERT INTO lesson_requests (listing_id, student_id) VALUES ($1,$2) RETURNING request_id AS id',
      [listingId, student.user.id]
    )
  ).rows[0]!.id;
  await acceptLessonRequestAt(pool, requestId, teacher.user.id, new Date());
  const conversationId = (
    await pool.query<{ id: string }>(
      'SELECT conversation_id AS id FROM conversations WHERE lesson_request_id = $1',
      [requestId]
    )
  ).rows[0]!.id;
  return { teacher, student, stranger, requestId, conversationId, start };
}
async function complete(data: Awaited<ReturnType<typeof accepted>>): Promise<void> {
  const afterEnd = new Date(data.start.getTime() + 61 * 60_000);
  await confirmLessonAt(pool, data.requestId, data.student.user.id, afterEnd);
  await confirmLessonAt(
    pool,
    data.requestId,
    data.teacher.user.id,
    new Date(afterEnd.getTime() + 60_000)
  );
}

describe('messages', () => {
  it('requires authentication for every messages endpoint', async () => {
    const value = await app();
    const id = crypto.randomUUID();
    for (const options of [
      { method: 'GET', url: '/api/v1/conversations' },
      { method: 'GET', url: `/api/v1/conversations/${id}/messages` },
      { method: 'POST', url: `/api/v1/conversations/${id}/messages`, payload: { body: 'hello' } },
      { method: 'POST', url: `/api/v1/conversations/${id}/read` }
    ] as const) {
      const response = await value.inject(options);
      expect(response.statusCode).toBe(401);
      expect(response.json().error.code).toBe('UNAUTHORIZED');
    }
  });
  it('lists accepted rooms, sends messages, reports unread counts, and marks only the other party read', async () => {
    const value = await app();
    const data = await accepted(value);
    const sent = await value.inject({
      method: 'POST',
      url: `/api/v1/conversations/${data.conversationId}/messages`,
      headers: auth(data.teacher),
      payload: { body: '  Hello student  ' }
    });
    expect(sent.statusCode).toBe(201);
    expect(sent.json().body).toBe('Hello student');
    const rooms = await value.inject({
      method: 'GET',
      url: '/api/v1/conversations',
      headers: auth(data.student)
    });
    expect(rooms.statusCode).toBe(200);
    expect(rooms.json().items[0]).toMatchObject({
      id: data.conversationId,
      unreadCount: 1,
      lastMessage: { body: 'Hello student' }
    });
    const read = await value.inject({
      method: 'POST',
      url: `/api/v1/conversations/${data.conversationId}/read`,
      headers: auth(data.student)
    });
    expect(read.statusCode).toBe(204);
    expect(
      (
        await pool.query<{ read_at: string | null }>(
          'SELECT read_at FROM messages WHERE message_id = $1',
          [sent.json().id]
        )
      ).rows[0]!.read_at
    ).not.toBeNull();
    const reply = await value.inject({
      method: 'POST',
      url: `/api/v1/conversations/${data.conversationId}/messages`,
      headers: auth(data.student),
      payload: { body: 'Reply' }
    });
    expect(reply.statusCode).toBe(201);
    await value.inject({
      method: 'POST',
      url: `/api/v1/conversations/${data.conversationId}/read`,
      headers: auth(data.student)
    });
    expect(
      (
        await pool.query<{ read_at: string | null }>(
          'SELECT read_at FROM messages WHERE message_id = $1',
          [reply.json().id]
        )
      ).rows[0]!.read_at
    ).toBeNull();
  });
  it('rejects non-participant reads and writes, invalid body values, and invalid cursors', async () => {
    const value = await app();
    const data = await accepted(value);
    for (const options of [
      {
        method: 'GET',
        url: `/api/v1/conversations/${data.conversationId}/messages`,
        headers: auth(data.stranger)
      },
      {
        method: 'POST',
        url: `/api/v1/conversations/${data.conversationId}/messages`,
        headers: auth(data.stranger),
        payload: { body: 'nope' }
      },
      {
        method: 'POST',
        url: `/api/v1/conversations/${data.conversationId}/read`,
        headers: auth(data.stranger)
      }
    ] as const) {
      const response = await value.inject(options);
      expect(response.statusCode).toBe(403);
      expect(response.json().error.code).toBe('NOT_A_PARTICIPANT');
    }
    for (const body of [{ body: '' }, { body: '   ' }, { body: 'x'.repeat(2001) }]) {
      const response = await value.inject({
        method: 'POST',
        url: `/api/v1/conversations/${data.conversationId}/messages`,
        headers: auth(data.teacher),
        payload: body
      });
      expect(response.statusCode).toBe(400);
      expect(response.json().error.code).toBe('VALIDATION_ERROR');
    }
    const cursor = await value.inject({
      method: 'GET',
      url: `/api/v1/conversations/${data.conversationId}/messages?cursor=x`,
      headers: auth(data.teacher)
    });
    expect(cursor.statusCode).toBe(400);
  });
});

describe('reviews', () => {
  it('requires authentication for every reviews endpoint', async () => {
    const value = await app();
    const id = crypto.randomUUID();
    for (const options of [
      { method: 'POST', url: `/api/v1/requests/${id}/reviews`, payload: { rating: 5 } },
      { method: 'GET', url: `/api/v1/users/${id}/reviews` },
      { method: 'GET', url: `/api/v1/requests/${id}/reviews` }
    ] as const) {
      const response = await value.inject(options);
      expect(response.statusCode).toBe(401);
      expect(response.json().error.code).toBe('UNAUTHORIZED');
    }
  });
  it('requires a completed lesson, derives reviewee, prevents duplicates, and updates public rating', async () => {
    const value = await app();
    const data = await accepted(value);
    const tooEarly = await value.inject({
      method: 'POST',
      url: `/api/v1/requests/${data.requestId}/reviews`,
      headers: auth(data.student),
      payload: { rating: 5, comment: 'Great' }
    });
    expect(tooEarly.statusCode).toBe(409);
    expect(tooEarly.json().error.code).toBe('REVIEW_REQUIRES_COMPLETED_LESSON');
    await complete(data);
    const created = await value.inject({
      method: 'POST',
      url: `/api/v1/requests/${data.requestId}/reviews`,
      headers: auth(data.student),
      payload: { rating: 5, comment: '  Great  ' }
    });
    expect(created.statusCode).toBe(201);
    expect(created.json()).toMatchObject({ rating: 5, comment: 'Great' });
    expect(
      (
        await pool.query<{ reviewee_id: string }>(
          'SELECT reviewee_id FROM reviews WHERE review_id = $1',
          [created.json().id]
        )
      ).rows[0]!.reviewee_id
    ).toBe(data.teacher.user.id);
    const duplicate = await value.inject({
      method: 'POST',
      url: `/api/v1/requests/${data.requestId}/reviews`,
      headers: auth(data.student),
      payload: { rating: 4 }
    });
    expect(duplicate.statusCode).toBe(409);
    expect(duplicate.json().error.code).toBe('ALREADY_REVIEWED');
    const publicUser = await value.inject({
      method: 'GET',
      url: `/api/v1/users/${data.teacher.user.id}`
    });
    expect(publicUser.statusCode).toBe(200);
    expect(publicUser.json()).toMatchObject({ ratingAverage: 5, ratingCount: 1 });
    const reviews = await value.inject({
      method: 'GET',
      url: `/api/v1/users/${data.teacher.user.id}/reviews`,
      headers: auth(data.stranger)
    });
    expect(reviews.statusCode).toBe(200);
    expect(reviews.json().items).toHaveLength(1);
  });
  it('rejects rating and comment validation and hides request reviews from strangers', async () => {
    const value = await app();
    const data = await accepted(value);
    for (const payload of [
      { rating: 0 },
      { rating: 6 },
      { rating: 1.5 },
      { rating: 4, comment: ' '.repeat(1001) }
    ]) {
      const response = await value.inject({
        method: 'POST',
        url: `/api/v1/requests/${data.requestId}/reviews`,
        headers: auth(data.student),
        payload
      });
      expect(response.statusCode).toBe(400);
    }
    const hidden = await value.inject({
      method: 'GET',
      url: `/api/v1/requests/${data.requestId}/reviews`,
      headers: auth(data.stranger)
    });
    expect(hidden.statusCode).toBe(404);
    expect(hidden.json().error.code).toBe('REQUEST_NOT_FOUND');
  });
});
