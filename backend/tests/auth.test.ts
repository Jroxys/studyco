import { afterAll, afterEach, describe, expect, inject, it } from 'vitest';
import { Pool } from 'pg';

import { buildApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import type { MailSender } from '../src/mail/mail-sender.js';
import { createListing } from './helpers/factories.js';
import { acceptLessonRequestAt } from './helpers/time-travel.js';

class TestMailSender implements MailSender {
  public readonly verification: Array<{ email: string; code: string }> = [];
  public readonly resets: Array<{ email: string; code: string }> = [];
  public async sendVerification(email: string, code: string): Promise<void> {
    this.verification.push({ email, code });
  }
  public async sendPasswordReset(email: string, code: string): Promise<void> {
    this.resets.push({ email, code });
  }
}

const pool = new Pool({ connectionString: inject('testDatabaseUrl') });
const config = loadConfig({
  NODE_ENV: 'test',
  DATABASE_URL: inject('testDatabaseUrl'),
  JWT_SECRET: 'a-very-long-test-jwt-secret-that-is-not-production',
  OTP_HMAC_SECRET: 'a-very-long-test-otp-hmac-secret-that-is-not-production'
});
const apps: ReturnType<typeof buildApp>[] = [];
afterEach(async () => {
  await Promise.all(apps.splice(0).map((app) => app.close()));
});
afterAll(async () => {
  await pool.end();
});

async function appAndMail() {
  const mail = new TestMailSender();
  const app = buildApp({ config, db: pool, mailSender: mail });
  apps.push(app);
  await app.ready();
  return { app, mail };
}
async function register(app: ReturnType<typeof buildApp>, patch: Record<string, unknown> = {}) {
  const department = await pool.query<{ department_id: string }>(
    'SELECT department_id FROM departments WHERE is_active LIMIT 1'
  );
  return app.inject({
    method: 'POST',
    url: '/api/v1/auth/register',
    payload: {
      firstName: 'Auth',
      lastName: 'Tester',
      birthDate: '2000-01-01',
      email: `auth-${crypto.randomUUID()}@example.test`,
      phone: `+905${Math.floor(100000000 + Math.random() * 899999999)}`,
      password: 'secure-password-123',
      departmentId: department.rows[0]!.department_id,
      termsAccepted: true,
      termsVersion: 'v1',
      ...patch
    }
  });
}

describe('auth', () => {
  it('issues expiring HS256 access tokens and rejects expired access tokens', async () => {
    const { app } = await appAndMail();
    const registered = (await register(app)).json();
    const payload = JSON.parse(Buffer.from(registered.accessToken.split('.')[1], 'base64url').toString());
    expect(payload).toMatchObject({ sub: registered.user.id, exp: expect.any(Number) });
    const expired = app.jwt.sign({ sub: registered.user.id }, { expiresIn: -1 });
    const response = await app.inject({
      method: 'GET',
      url: '/api/v1/me',
      headers: { authorization: `Bearer ${expired}` }
    });
    expect(response.statusCode).toBe(401);
  });

  it('rejects an anonymized user access token on every protected module', async () => {
    const { app } = await appAndMail();
    const registered = (await register(app)).json();
    const token = registered.accessToken as string;
    expect(
      (
        await app.inject({
          method: 'DELETE',
          url: '/api/v1/me',
          headers: { authorization: `Bearer ${token}` },
          payload: { password: 'secure-password-123' }
        })
      ).statusCode
    ).toBe(204);
    for (const request of [
      { method: 'GET', url: '/api/v1/me' },
      { method: 'GET', url: '/api/v1/wallet' },
      { method: 'GET', url: '/api/v1/conversations' },
      { method: 'GET', url: '/api/v1/listings' },
      { method: 'GET', url: `/api/v1/users/${crypto.randomUUID()}/reviews` },
      { method: 'POST', url: `/api/v1/listings/${crypto.randomUUID()}/requests`, payload: {} }
    ]) {
      const response = await app.inject({
        ...request,
        headers: { authorization: `Bearer ${token}` }
      });
      expect(response.statusCode).toBe(401);
    }
  });

  it('registers, verifies email, rotates refresh tokens, and detects reuse', async () => {
    const { app, mail } = await appAndMail();
    const response = await register(app);
    expect(response.statusCode).toBe(201);
    const body = response.json();
    expect(mail.verification).toHaveLength(1);
    const verified = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/verify-email',
      headers: { authorization: `Bearer ${body.accessToken}` },
      payload: { code: mail.verification[0]!.code }
    });
    expect(verified.statusCode).toBe(204);
    const refreshed = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/refresh',
      payload: { refreshToken: body.refreshToken }
    });
    expect(refreshed.statusCode).toBe(200);
    const reused = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/refresh',
      payload: { refreshToken: body.refreshToken }
    });
    expect(reused.statusCode).toBe(401);
    expect(reused.json().error.code).toBe('REFRESH_REUSED');
    expect(
      (
        await app.inject({
          method: 'POST',
          url: '/api/v1/auth/refresh',
          payload: { refreshToken: refreshed.json().refreshToken }
        })
      ).json().error.code
    ).toBe('REFRESH_REUSED');
  });

  it('does not disclose invalid credentials and validates registration input', async () => {
    const { app } = await appAndMail();
    const weak = await register(app, { password: 'short' });
    expect(weak.statusCode).toBe(400);
    const unknown = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      payload: { email: 'absent@example.test', password: 'secure-password-123' }
    });
    const wrong = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      payload: { email: 'also-absent@example.test', password: 'bad-password' }
    });
    expect(unknown.json()).toEqual(wrong.json());
  });

  it('normalizes contacts and rejects duplicate, malformed, and underage registration', async () => {
    const { app } = await appAndMail();
    const email = ` Mixed-${crypto.randomUUID()}@Example.TEST `;
    const phone = `05${Math.floor(100000000 + Math.random() * 899999999)}`;
    const registered = await register(app, { email, phone });
    expect(registered.statusCode).toBe(201);
    expect(registered.json().user.email).toBe(email.trim().toLowerCase());
    expect(registered.json().user.phone).toBe(`+90${phone.slice(1)}`);
    expect(
      (
        await register(app, {
          email: email.trim().toLowerCase(),
          phone: `+905${Math.floor(100000000 + Math.random() * 899999999)}`
        })
      ).json().error.code
    ).toBe('EMAIL_TAKEN');
    expect(
      (await register(app, { email: `other-${crypto.randomUUID()}@example.test`, phone })).json()
        .error.code
    ).toBe('PHONE_TAKEN');
    expect((await register(app, { phone: 'not-a-phone' })).statusCode).toBe(400);
    expect(
      (await register(app, { birthDate: new Date().toISOString().slice(0, 10) })).json().error.code
    ).toBe('UNDERAGE');
  });

  it('commits verification failures and returns all verification outcomes', async () => {
    const { app, mail } = await appAndMail();
    const registered = await register(app);
    const token = registered.json().accessToken as string;
    const userId = registered.json().user.id as string;
    const invalid = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/verify-email',
      headers: { authorization: `Bearer ${token}` },
      payload: { code: '000000' }
    });
    expect(invalid.json().error.code).toBe('INVALID_CODE');
    expect(
      (
        await pool.query<{ attempt_count: number }>(
          'SELECT attempt_count FROM auth_tokens WHERE user_id = $1',
          [userId]
        )
      ).rows[0]!.attempt_count
    ).toBe(1);
    for (let attempt = 0; attempt < 4; attempt += 1)
      await app.inject({
        method: 'POST',
        url: '/api/v1/auth/verify-email',
        headers: { authorization: `Bearer ${token}` },
        payload: { code: '000000' }
      });
    expect(
      (
        await app.inject({
          method: 'POST',
          url: '/api/v1/auth/verify-email',
          headers: { authorization: `Bearer ${token}` },
          payload: { code: '000000' }
        })
      ).json().error.code
    ).toBe('LOCKED');
    await pool.query(
      "UPDATE auth_tokens SET created_at = now() - interval '2 minutes', expires_at = now() - interval '1 second' WHERE user_id = $1",
      [userId]
    );
    expect(
      (
        await app.inject({
          method: 'POST',
          url: '/api/v1/auth/verify-email',
          headers: { authorization: `Bearer ${token}` },
          payload: { code: mail.verification[0]!.code }
        })
      ).json().error.code
    ).toBe('EXPIRED');
    await pool.query('UPDATE auth_tokens SET revoked_at = now() WHERE user_id = $1', [userId]);
    expect(
      (
        await app.inject({
          method: 'POST',
          url: '/api/v1/auth/verify-email',
          headers: { authorization: `Bearer ${token}` },
          payload: { code: mail.verification[0]!.code }
        })
      ).json().error.code
    ).toBe('NOT_FOUND');
  });

  it('logs out idempotently, enforces resend cooldown, and resets passwords', async () => {
    const { app, mail } = await appAndMail();
    const registered = await register(app);
    const body = registered.json();
    expect(
      (
        await app.inject({
          method: 'POST',
          url: '/api/v1/auth/resend-verification',
          headers: { authorization: `Bearer ${body.accessToken}` }
        })
      ).json().error.code
    ).toBe('VERIFICATION_COOLDOWN');
    expect(
      (
        await app.inject({
          method: 'POST',
          url: '/api/v1/auth/logout',
          payload: { refreshToken: body.refreshToken }
        })
      ).statusCode
    ).toBe(204);
    expect(
      (
        await app.inject({
          method: 'POST',
          url: '/api/v1/auth/logout',
          payload: { refreshToken: body.refreshToken }
        })
      ).statusCode
    ).toBe(204);
    expect(
      (
        await app.inject({
          method: 'POST',
          url: '/api/v1/auth/forgot-password',
          payload: { email: 'unknown@example.test' }
        })
      ).statusCode
    ).toBe(202);
    expect(
      (
        await app.inject({
          method: 'POST',
          url: '/api/v1/auth/forgot-password',
          payload: { email: body.user.email }
        })
      ).statusCode
    ).toBe(202);
    const code = mail.resets[0]!.code;
    expect(
      (
        await app.inject({
          method: 'POST',
          url: '/api/v1/auth/reset-password',
          payload: { email: body.user.email, code, newPassword: 'new-secure-password-123' }
        })
      ).statusCode
    ).toBe(204);
    expect(
      (
        await app.inject({
          method: 'POST',
          url: '/api/v1/auth/login',
          payload: { email: body.user.email, password: 'secure-password-123' }
        })
      ).json().error.code
    ).toBe('INVALID_CREDENTIALS');
    expect(
      (
        await app.inject({
          method: 'POST',
          url: '/api/v1/auth/login',
          payload: { email: body.user.email, password: 'new-secure-password-123' }
        })
      ).statusCode
    ).toBe(200);
  });

  it('changes passwords, blocks deletion with an accepted lesson, and rate limits login', async () => {
    const { app } = await appAndMail();
    const student = (await register(app)).json();
    const teacher = (await register(app)).json();
    const listingId = await createListing(pool, { teacherId: teacher.user.id });
    const request = await pool.query<{ request_id: string }>(
      'INSERT INTO lesson_requests (listing_id, student_id) VALUES ($1, $2) RETURNING request_id',
      [listingId, student.user.id]
    );
    await acceptLessonRequestAt(pool, request.rows[0]!.request_id, teacher.user.id, new Date());
    expect(
      (
        await app.inject({
          method: 'DELETE',
          url: '/api/v1/me',
          headers: { authorization: `Bearer ${student.accessToken}` },
          payload: { password: 'secure-password-123' }
        })
      ).json().error.code
    ).toBe('USER_HAS_ACTIVE_OBLIGATIONS');
    expect(
      (
        await app.inject({
          method: 'POST',
          url: '/api/v1/me/change-password',
          headers: { authorization: `Bearer ${teacher.accessToken}` },
          payload: {
            currentPassword: 'secure-password-123',
            newPassword: 'changed-secure-password-123'
          }
        })
      ).statusCode
    ).toBe(204);
    const anonymized = (await register(app)).json();
    await pool.query('SELECT anonymize_user($1)', [anonymized.user.id]);
    expect(
      (
        await app.inject({
          method: 'POST',
          url: '/api/v1/auth/login',
          payload: { email: anonymized.user.email, password: 'secure-password-123' }
        })
      ).json().error.code
    ).toBe('INVALID_CREDENTIALS');
    const rateApp = buildApp({
      config: { ...config, rateLimitMax: 5 },
      db: pool,
      mailSender: {
        sendVerification: async () => undefined,
        sendPasswordReset: async () => undefined
      }
    });
    apps.push(rateApp);
    await rateApp.ready();
    for (let attempt = 0; attempt < 5; attempt += 1)
      await rateApp.inject({
        method: 'POST',
        url: '/api/v1/auth/login',
        payload: { email: `rate-${attempt}@example.test`, password: 'secure-password-123' }
      });
    expect(
      (
        await rateApp.inject({
          method: 'POST',
          url: '/api/v1/auth/login',
          payload: { email: 'rate-final@example.test', password: 'secure-password-123' }
        })
      ).statusCode
    ).toBe(429);
  });

  it('gets and updates the authenticated profile with normalized phone and department guard', async () => {
    const { app } = await appAndMail();
    const user = (await register(app)).json();
    expect(
      (
        await app.inject({
          method: 'GET',
          url: '/api/v1/me',
          headers: { authorization: `Bearer ${user.accessToken}` }
        })
      ).json().email
    ).toBe(user.user.email);
    const changed = await app.inject({
      method: 'PATCH',
      url: '/api/v1/me',
      headers: { authorization: `Bearer ${user.accessToken}` },
      payload: { phone: '05321234567' }
    });
    expect(changed.statusCode).toBe(200);
    expect(changed.json().phone).toBe('+905321234567');
    const duplicate = (await register(app)).json();
    expect(
      (
        await app.inject({
          method: 'PATCH',
          url: '/api/v1/me',
          headers: { authorization: `Bearer ${duplicate.accessToken}` },
          payload: { phone: '05321234567' }
        })
      ).json().error.code
    ).toBe('PHONE_TAKEN');
    const newDepartment = (
      await pool.query<{ department_id: string }>(
        'INSERT INTO departments (name) VALUES ($1) RETURNING department_id',
        [`Test department ${crypto.randomUUID()}`]
      )
    ).rows[0]!.department_id;
    await createListing(pool, { teacherId: user.user.id });
    expect(
      (
        await app.inject({
          method: 'PATCH',
          url: '/api/v1/me',
          headers: { authorization: `Bearer ${user.accessToken}` },
          payload: { departmentId: newDepartment }
        })
      ).json().error.code
    ).toBe('DEPARTMENT_CHANGE_BLOCKED');
    expect(
      (
        await app.inject({
          method: 'PATCH',
          url: '/api/v1/me',
          headers: { authorization: `Bearer ${user.accessToken}` },
          payload: {}
        })
      ).statusCode
    ).toBe(400);
  });

  it('returns a null public rating before a user receives any reviews', async () => {
    const { app } = await appAndMail();
    const user = (await register(app)).json();
    const response = await app.inject({ method: 'GET', url: `/api/v1/users/${user.user.id}` });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({ ratingAverage: null, ratingCount: 0 });
  });
});
