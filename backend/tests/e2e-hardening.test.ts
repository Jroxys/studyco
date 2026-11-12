import { afterAll, afterEach, describe, expect, inject, it } from 'vitest';
import { Pool } from 'pg';

import { buildApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import type { MailSender } from '../src/mail/mail-sender.js';
import { createCourse, createLocation } from './helpers/factories.js';
import { confirmLessonAt } from './helpers/time-travel.js';

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
  OTP_HMAC_SECRET: 'a-very-long-test-otp-hmac-secret-that-is-not-production',
  RATE_LIMIT_MAX: '1000'
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
async function register(value: App, firstName: string): Promise<Account> {
  const departmentId = (
    await pool.query<{ id: string }>(
      'SELECT department_id AS id FROM departments WHERE is_active ORDER BY name LIMIT 1'
    )
  ).rows[0]!.id;
  const response = await value.inject({
    method: 'POST',
    url: '/api/v1/auth/register',
    payload: {
      firstName,
      lastName: 'E2E',
      birthDate: '2000-01-01',
      email: `${firstName.toLowerCase()}-${crypto.randomUUID()}@example.test`,
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

describe('full flow and authentication boundary', () => {
  it('completes registration, lesson, settlement, chat, review, wallet, and integrity flow', async () => {
    const value = await app();
    const teacher = await register(value, 'Teacher');
    const student = await register(value, 'Student');
    const departmentId = (
      await pool.query<{ id: string }>('SELECT department_id AS id FROM users WHERE user_id = $1', [
        teacher.user.id
      ])
    ).rows[0]!.id;
    const courseId = await createCourse(pool, departmentId);
    const locationId = await createLocation(pool);
    const startAt = new Date(Date.now() + 48 * 60 * 60 * 1000);
    const endAt = new Date(startAt.getTime() + 60 * 60 * 1000);
    const listing = await value.inject({
      method: 'POST',
      url: '/api/v1/listings',
      headers: auth(teacher),
      payload: {
        courseId,
        locationId,
        topic: 'Calculus review',
        startAt: startAt.toISOString(),
        endAt: endAt.toISOString(),
        tokenPrice: 2
      }
    });
    expect(listing.statusCode).toBe(201);
    const requested = await value.inject({
      method: 'POST',
      url: `/api/v1/listings/${listing.json().id}/requests`,
      headers: auth(student),
      payload: {}
    });
    expect(requested.statusCode).toBe(201);
    const requestId = requested.json().id as string;
    const accepted = await value.inject({
      method: 'POST',
      url: `/api/v1/requests/${requestId}/accept`,
      headers: auth(teacher),
      payload: {}
    });
    expect(accepted.statusCode).toBe(200);
    const conversationId = accepted.json().conversationId as string;
    const sent = await value.inject({
      method: 'POST',
      url: `/api/v1/conversations/${conversationId}/messages`,
      headers: auth(student),
      payload: { body: 'See you at the library.' }
    });
    expect(sent.statusCode).toBe(201);
    const messages = await value.inject({
      method: 'GET',
      url: `/api/v1/conversations/${conversationId}/messages`,
      headers: auth(teacher)
    });
    expect(messages.json().items[0].body).toBe('See you at the library.');
    const afterLesson = new Date(endAt.getTime() + 60_000);
    await confirmLessonAt(pool, requestId, student.user.id, afterLesson);
    await confirmLessonAt(pool, requestId, teacher.user.id, afterLesson);
    expect(
      (await value.inject({ method: 'GET', url: '/api/v1/wallet', headers: auth(student) })).json()
    ).toEqual({ available: 8, held: 0 });
    expect(
      (await value.inject({ method: 'GET', url: '/api/v1/wallet', headers: auth(teacher) })).json()
    ).toEqual({ available: 12, held: 0 });
    for (const [reviewer, rating] of [
      [student, 5],
      [teacher, 4]
    ] as const) {
      const review = await value.inject({
        method: 'POST',
        url: `/api/v1/requests/${requestId}/reviews`,
        headers: auth(reviewer),
        payload: { rating, comment: 'Helpful session' }
      });
      expect(review.statusCode).toBe(201);
    }
    expect(
      (await value.inject({ method: 'GET', url: `/api/v1/users/${teacher.user.id}` })).json()
    ).toMatchObject({ ratingAverage: 5, ratingCount: 1, completedLessonsCount: 1 });
    expect(
      (await value.inject({ method: 'GET', url: `/api/v1/users/${student.user.id}` })).json()
    ).toMatchObject({ ratingAverage: 4, ratingCount: 1, completedLessonsCount: 1 });
    expect((await pool.query('SELECT * FROM v_integrity_violations')).rows).toHaveLength(0);
  });

  it('rejects every protected route without a valid JWT before request validation', async () => {
    const value = await app();
    const id = crypto.randomUUID();
    const routes = [
      ['POST', '/api/v1/auth/verify-email'],
      ['POST', '/api/v1/auth/resend-verification'],
      ['GET', '/api/v1/me'],
      ['PATCH', '/api/v1/me'],
      ['POST', '/api/v1/me/change-password'],
      ['DELETE', '/api/v1/me'],
      // GET /api/v1/departments is intentionally public (registration form).
      ['GET', `/api/v1/departments/${id}/courses`],
      ['GET', '/api/v1/courses'],
      ['GET', '/api/v1/locations'],
      ['POST', '/api/v1/listings'],
      ['GET', '/api/v1/listings'],
      ['GET', '/api/v1/me/listings'],
      ['GET', `/api/v1/listings/${id}`],
      ['PATCH', `/api/v1/listings/${id}`],
      ['POST', `/api/v1/listings/${id}/requests`],
      ['GET', '/api/v1/me/requests'],
      ['GET', `/api/v1/requests/${id}`],
      ['POST', `/api/v1/requests/${id}/accept`],
      ['POST', `/api/v1/requests/${id}/reject`],
      ['POST', `/api/v1/requests/${id}/confirm`],
      ['GET', '/api/v1/wallet'],
      ['GET', '/api/v1/wallet/transactions'],
      ['GET', '/api/v1/conversations'],
      ['GET', `/api/v1/conversations/${id}/messages`],
      ['POST', `/api/v1/conversations/${id}/messages`],
      ['POST', `/api/v1/conversations/${id}/read`],
      ['POST', `/api/v1/requests/${id}/reviews`],
      ['GET', `/api/v1/users/${id}/reviews`],
      ['GET', `/api/v1/requests/${id}/reviews`]
    ] as const;
    for (const [method, url] of routes) {
      for (const headers of [{}, { authorization: 'Bearer invalid.jwt.value' }]) {
        const response = await value.inject({ method, url, headers, payload: {} });
        expect(response.statusCode, `${method} ${url}`).toBe(401);
        expect(response.json().error.code, `${method} ${url}`).toBe('UNAUTHORIZED');
      }
    }
  });
});
