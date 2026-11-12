import argon2 from 'argon2';
import type { FastifyInstance } from 'fastify';
import type { Config } from '../../config.js';
import { query, withTx, type Queryable, type TransactionPool } from '../../db/pool.js';
import { AppError } from '../../errors.js';
import type { MailSender } from '../../mail/mail-sender.js';
import {
  codeSchema,
  credentialsSchema,
  deleteSchema,
  forgotPasswordSchema,
  passwordSchema,
  profilePatchSchema,
  refreshSchema,
  registrationSchema,
  resetSchema,
  responses,
  userIdParamsSchema
} from './auth.schemas.js';
import { findUserByEmail, type AuthUserRow } from './auth.repo.js';
import {
  currentUser,
  invalidCredentials,
  insertRefresh,
  isOldEnough,
  issueOtp,
  normalizeEmail,
  normalizePhone,
  otpHash,
  refreshHash,
  tokens,
  userDto
} from './auth.service.js';

type Database = TransactionPool & Queryable;
type Dependencies = { config: Config; db: Database; mailSender: MailSender };
type UserRow = AuthUserRow;
type TokenRow = {
  token_id: string;
  user_id: string;
  family_id: string;
  revoked_at: string | null;
  expires_at: string;
};

const dummyPasswordHash = argon2.hash('studyco-dummy-password-not-a-secret', {
  type: argon2.argon2id
});

export function registerAuthRoutes(app: FastifyInstance, dependencies: Dependencies): void {
  const { config, db, mailSender } = dependencies;
  app.post(
    '/api/v1/auth/register',
    {
      config: { rateLimit: { max: 100, timeWindow: '1 hour' } },
      schema: { body: registrationSchema, response: responses.register }
    },
    async (request, reply) => {
      const body = registrationSchema.parse(request.body);
      if (!isOldEnough(body.birthDate, config.minimumAge))
        throw new AppError(422, 'UNDERAGE', 'You must meet the minimum age requirement');
      const passwordHash = await argon2.hash(body.password, { type: argon2.argon2id });
      const email = normalizeEmail(body.email);
      const phone = normalizePhone(body.phone);
      const result = await withTx(db, async (client) => {
        const rows = await query<UserRow>(
          client,
          'INSERT INTO users (department_id, first_name, last_name, birth_date, email, phone, password_hash, terms_accepted_at, terms_version) VALUES ($1,$2,$3,$4,$5,$6,$7,now(),$8) RETURNING user_id, first_name, last_name, birth_date::text, email::text, phone, department_id, email_verified_at::text, password_hash, anonymized_at::text',
          [
            body.departmentId,
            body.firstName,
            body.lastName,
            body.birthDate,
            email,
            phone,
            passwordHash,
            body.termsVersion
          ]
        );
        const code = await issueOtp(client, config, rows[0]!.user_id, 'EMAIL_VERIFICATION');
        const response = await tokens(app, client, rows[0]!);
        return { code, email, response };
      });
      await mailSender.sendVerification(result.email, result.code);
      return reply.status(201).send(result.response);
    }
  );
  app.post(
    '/api/v1/auth/login',
    {
      config: { rateLimit: { max: 5, timeWindow: '1 minute' } },
      schema: { body: credentialsSchema, response: responses.login }
    },
    async (request) => {
      const body = credentialsSchema.parse(request.body);
      const user = await findUserByEmail(db, normalizeEmail(body.email));
      if (!user) {
        await argon2.verify(await dummyPasswordHash, body.password);
        throw invalidCredentials();
      }
      if (user.anonymized_at || !(await argon2.verify(user.password_hash, body.password)))
        throw invalidCredentials();
      return withTx(db, (client) => tokens(app, client, user));
    }
  );
  app.post(
    '/api/v1/auth/refresh',
    {
      config: { rateLimit: { max: 10, timeWindow: '1 minute' } },
      schema: { body: refreshSchema, response: responses.refresh }
    },
    async (request) => {
      const { refreshToken } = refreshSchema.parse(request.body);
      const hash = refreshHash(refreshToken);
      const result = await withTx(db, async (client) => {
        const token = (
          await query<TokenRow>(
            client,
            'SELECT token_id, user_id, family_id, revoked_at::text, expires_at::text FROM refresh_tokens WHERE token_hash = $1 FOR UPDATE',
            [hash]
          )
        )[0];
        if (!token) throw new AppError(401, 'INVALID_REFRESH_TOKEN', 'Invalid refresh token');
        if (token.revoked_at) {
          await query(
            client,
            'UPDATE refresh_tokens SET revoked_at = COALESCE(revoked_at, now()) WHERE family_id = $1',
            [token.family_id]
          );
          return { reused: true as const };
        }
        if (new Date(token.expires_at) <= new Date()) {
          await query(client, 'UPDATE refresh_tokens SET revoked_at = now() WHERE token_id = $1', [
            token.token_id
          ]);
          throw new AppError(401, 'INVALID_REFRESH_TOKEN', 'Invalid refresh token');
        }
        const user = (
          await query<UserRow>(
            client,
            'SELECT user_id, first_name, last_name, birth_date::text, email::text, phone, department_id, email_verified_at::text, password_hash, anonymized_at::text FROM users WHERE user_id = $1',
            [token.user_id]
          )
        )[0];
        if (!user || user.anonymized_at)
          throw new AppError(401, 'INVALID_REFRESH_TOKEN', 'Invalid refresh token');
        const replacement = await insertRefresh(client, user.user_id, token.family_id);
        await query(
          client,
          'UPDATE refresh_tokens SET revoked_at = now(), replaced_by = $2 WHERE token_id = $1',
          [token.token_id, replacement.tokenId]
        );
        return {
          reused: false as const,
          user: userDto(user),
          accessToken: app.jwt.sign({ sub: user.user_id }),
          refreshToken: replacement.refreshToken
        };
      });
      if (result.reused)
        throw new AppError(401, 'REFRESH_REUSED', 'Refresh token was already used');
      return result;
    }
  );
  app.post(
    '/api/v1/auth/logout',
    { schema: { body: refreshSchema, response: responses.logout } },
    async (request, reply) => {
      const { refreshToken } = refreshSchema.parse(request.body);
      await query(
        db,
        'UPDATE refresh_tokens SET revoked_at = now() WHERE token_hash = $1 AND revoked_at IS NULL',
        [refreshHash(refreshToken)]
      );
      return reply.status(204).send();
    }
  );
  app.post(
    '/api/v1/auth/verify-email',
    {
      config: { rateLimit: { max: 10, timeWindow: '1 minute' } },
      schema: { body: codeSchema, response: responses.verify }
    },
    async (request, reply) => {
      const user = await currentUser(request, db);
      const { code } = codeSchema.parse(request.body);
      const result = await withTx(
        db,
        async (client) =>
          (
            await query<{ verify_auth_token: string }>(
              client,
              'SELECT verify_auth_token($1,$2,$3,$4)',
              [
                user.user_id,
                'EMAIL_VERIFICATION',
                otpHash(config.otpHmacSecret, code),
                config.otpMaxAttempts
              ]
            )
          )[0]!.verify_auth_token
      );
      if (result === 'OK') return reply.status(204).send();
      const status: Record<string, [number, string]> = {
        INVALID: [400, 'INVALID_CODE'],
        EXPIRED: [410, 'EXPIRED'],
        LOCKED: [429, 'LOCKED'],
        NOT_FOUND: [400, 'NOT_FOUND']
      };
      const [http, errorCode] = status[result] ?? [400, 'INVALID_CODE'];
      throw new AppError(http, errorCode, 'Verification code could not be accepted');
    }
  );
  app.post(
    '/api/v1/auth/resend-verification',
    { schema: { response: responses.resend } },
    async (request, reply) => {
      const user = await currentUser(request, db);
      const recent = await query<{ recent: boolean }>(
        db,
        "SELECT EXISTS (SELECT 1 FROM auth_tokens WHERE user_id = $1 AND purpose = 'EMAIL_VERIFICATION' AND created_at > now() - interval '60 seconds') AS recent",
        [user.user_id]
      );
      if (recent[0]?.recent)
        throw new AppError(
          429,
          'VERIFICATION_COOLDOWN',
          'Please wait before requesting another code'
        );
      const code = await issueOtp(db, config, user.user_id, 'EMAIL_VERIFICATION');
      await mailSender.sendVerification(user.email, code);
      return reply.status(204).send();
    }
  );
  app.post(
    '/api/v1/auth/forgot-password',
    {
      config: {
        rateLimit: {
          max: 3,
          timeWindow: '1 hour',
          keyGenerator: (request) => {
            const body = request.body as { email?: unknown } | undefined;
            return typeof body?.email === 'string' ? normalizeEmail(body.email) : request.ip;
          }
        }
      },
      schema: { body: forgotPasswordSchema, response: responses.forgot }
    },
    async (request, reply) => {
      const { email } = forgotPasswordSchema.parse(request.body);
      const user = await findUserByEmail(db, normalizeEmail(email));
      if (user?.anonymized_at) await argon2.verify(await dummyPasswordHash, 'not-a-real-password');
      if (user && !user.anonymized_at) {
        const code = await withTx(db, async (client) => {
          await query(client, 'SELECT pg_advisory_xact_lock(hashtext($1))', [
            `PASSWORD_RESET:${user.user_id}`
          ]);
          const recent = await query<{ recent: boolean }>(
            client,
            "SELECT EXISTS (SELECT 1 FROM auth_tokens WHERE user_id = $1 AND purpose = 'PASSWORD_RESET' AND created_at > now() - interval '60 seconds') AS recent",
            [user.user_id]
          );
          if (recent[0]?.recent) return null;
          return issueOtp(client, config, user.user_id, 'PASSWORD_RESET');
        });
        if (code) {
          try {
            await mailSender.sendPasswordReset(user.email, code);
          } catch (error) {
            request.log.error({ err: error }, 'Password-reset email delivery failed');
          }
        }
      }
      return reply.status(202).send();
    }
  );
  app.post(
    '/api/v1/auth/reset-password',
    {
      config: { rateLimit: { max: 10, timeWindow: '1 minute' } },
      schema: { body: resetSchema, response: responses.reset }
    },
    async (request, reply) => {
      const body = resetSchema.parse(request.body);
      const user = await findUserByEmail(db, normalizeEmail(body.email));
      if (!user || user.anonymized_at)
        throw new AppError(400, 'INVALID_CODE', 'Reset code could not be accepted');
      const passwordHash = await argon2.hash(body.newPassword, { type: argon2.argon2id });
      await withTx(db, async (client) => {
        const result = (
          await query<{ verify_auth_token: string }>(
            client,
            'SELECT verify_auth_token($1,$2,$3,$4)',
            [user.user_id, 'PASSWORD_RESET', otpHash(config.otpHmacSecret, body.code), config.otpMaxAttempts]
          )
        )[0]!.verify_auth_token;
        if (result !== 'OK')
          throw new AppError(400, 'INVALID_CODE', 'Reset code could not be accepted');
        await query(client, 'UPDATE users SET password_hash = $2 WHERE user_id = $1', [
          user.user_id,
          passwordHash
        ]);
        await query(
          client,
          'UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL',
          [user.user_id]
        );
      });
      return reply.status(204).send();
    }
  );
  app.get('/api/v1/me', { schema: { response: responses.me } }, async (request) =>
    userDto(await currentUser(request, db))
  );
  app.patch(
    '/api/v1/me',
    { schema: { body: profilePatchSchema, response: responses.me } },
    async (request) => {
      const user = await currentUser(request, db);
      const body = profilePatchSchema.parse(request.body);
      const phone = body.phone === undefined ? user.phone : normalizePhone(body.phone);
      if (body.departmentId && body.departmentId !== user.department_id) {
        const active = await query<{ exists: boolean }>(
          db,
          "SELECT EXISTS (SELECT 1 FROM listings WHERE teacher_id = $1 AND status IN ('PUBLISHED', 'BOOKED')) AS exists",
          [user.user_id]
        );
        if (active[0]?.exists)
          throw new AppError(
            409,
            'DEPARTMENT_CHANGE_BLOCKED',
            'Department cannot be changed with active listings'
          );
      }
      const updated = await query<UserRow>(
        db,
        'UPDATE users SET first_name = $2, last_name = $3, phone = $4, department_id = $5 WHERE user_id = $1 RETURNING user_id, first_name, last_name, birth_date::text, email::text, phone, department_id, email_verified_at::text, password_hash, anonymized_at::text',
        [
          user.user_id,
          body.firstName ?? user.first_name,
          body.lastName ?? user.last_name,
          phone,
          body.departmentId ?? user.department_id
        ]
      );
      return userDto(updated[0]!);
    }
  );
  app.get(
    '/api/v1/users/:id',
    { schema: { params: userIdParamsSchema, response: responses.publicUser } },
    async (request) => {
      const { id } = userIdParamsSchema.parse(request.params);
      const rows = await query<{
        id: string;
        firstName: string;
        lastNameInitial: string;
        departmentId: string;
        department: string;
        ratingAverage: number | null;
        ratingCount: number;
        completedLessonsCount: number;
      }>(
        db,
        `SELECT u.user_id AS id, u.first_name AS "firstName", left(u.last_name, 1) AS "lastNameInitial", u.department_id AS "departmentId", d.name AS department, avg(r.rating)::float AS "ratingAverage", count(r.review_id)::int AS "ratingCount", (SELECT count(*)::int FROM lesson_requests lr WHERE (lr.student_id = u.user_id OR lr.teacher_id = u.user_id) AND lr.completion_status = 'COMPLETED') AS "completedLessonsCount" FROM users u JOIN departments d ON d.department_id = u.department_id LEFT JOIN reviews r ON r.reviewee_id = u.user_id WHERE u.user_id = $1 AND u.anonymized_at IS NULL GROUP BY u.user_id, d.name`,
        [id]
      );
      if (!rows[0]) throw new AppError(404, 'USER_NOT_FOUND', 'User not found');
      return rows[0];
    }
  );
  app.post(
    '/api/v1/me/change-password',
    { schema: { body: passwordSchema, response: responses.changePassword } },
    async (request, reply) => {
      const user = await currentUser(request, db);
      const body = passwordSchema.parse(request.body);
      if (!(await argon2.verify(user.password_hash, body.currentPassword)))
        throw invalidCredentials();
      const hash = await argon2.hash(body.newPassword, { type: argon2.argon2id });
      await withTx(db, async (client) => {
        await query(client, 'UPDATE users SET password_hash = $2 WHERE user_id = $1', [
          user.user_id,
          hash
        ]);
        await query(
          client,
          'UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL',
          [user.user_id]
        );
      });
      return reply.status(204).send();
    }
  );
  app.delete(
    '/api/v1/me',
    { schema: { body: deleteSchema, response: responses.deleteMe } },
    async (request, reply) => {
      const user = await currentUser(request, db);
      const { password } = deleteSchema.parse(request.body);
      if (!(await argon2.verify(user.password_hash, password))) throw invalidCredentials();
      await withTx(db, async (client) => {
        await query(client, 'SELECT anonymize_user($1)', [user.user_id]);
        await query(
          client,
          'UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL',
          [user.user_id]
        );
      });
      return reply.status(204).send();
    }
  );
}
