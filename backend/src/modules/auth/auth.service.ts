import { createHash, createHmac, randomBytes, randomInt, randomUUID } from 'node:crypto';

import type { FastifyInstance, FastifyRequest } from 'fastify';

import type { Config } from '../../config.js';
import { query, type Queryable } from '../../db/pool.js';
import { AppError } from '../../errors.js';
import { findUserById, type AuthUserRow } from './auth.repo.js';

export function normalizeEmail(value: string): string {
  return value.trim().toLowerCase();
}

export function normalizePhone(value: string): string {
  const digits = value.replace(/[\s().-]/g, '');
  const normalized = digits.startsWith('+')
    ? digits
    : digits.startsWith('00')
      ? `+${digits.slice(2)}`
      : digits.startsWith('0')
        ? `+90${digits.slice(1)}`
        : digits.startsWith('5')
          ? `+90${digits}`
          : '';
  if (!/^\+[1-9]\d{7,14}$/.test(normalized)) {
    throw new AppError(400, 'VALIDATION_ERROR', 'Request validation failed');
  }
  return normalized;
}

export function isOldEnough(birthDate: string, minimumAge: number): boolean {
  const birth = new Date(`${birthDate}T00:00:00.000Z`);
  const today = new Date();
  let age = today.getUTCFullYear() - birth.getUTCFullYear();
  if (
    today.getUTCMonth() < birth.getUTCMonth() ||
    (today.getUTCMonth() === birth.getUTCMonth() && today.getUTCDate() < birth.getUTCDate())
  )
    age -= 1;
  return age >= minimumAge;
}

export function otpHash(secret: string, code: string): string {
  return createHmac('sha256', secret).update(code).digest('hex');
}

export function refreshHash(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

export function invalidCredentials(): AppError {
  return new AppError(401, 'INVALID_CREDENTIALS', 'Invalid email or password');
}

export function userDto(user: AuthUserRow) {
  return {
    id: user.user_id,
    firstName: user.first_name,
    lastName: user.last_name,
    birthDate: user.birth_date,
    email: user.email,
    phone: user.phone,
    departmentId: user.department_id,
    emailVerified: user.email_verified_at !== null
  };
}

export async function currentUser(request: FastifyRequest, db: Queryable): Promise<AuthUserRow> {
  const userId = authenticatedUserId(request);
  const user = await findUserById(db, userId);
  if (!user || user.anonymized_at)
    throw new AppError(401, 'UNAUTHORIZED', 'Authentication required');
  return user;
}

export function authenticatedUserId(request: FastifyRequest): string {
  const userId = (request as FastifyRequest & { authUserId?: string }).authUserId;
  if (!userId) throw new AppError(401, 'UNAUTHORIZED', 'Authentication required');
  return userId;
}

export async function issueOtp(
  db: Queryable,
  config: Config,
  userId: string,
  purpose: 'EMAIL_VERIFICATION' | 'PASSWORD_RESET'
): Promise<string> {
  const code = randomInt(0, 1_000_000).toString().padStart(6, '0');
  await query(db, 'SELECT issue_auth_token($1, $2, $3, $4::interval)', [
    userId,
    purpose,
    otpHash(config.otpHmacSecret, code),
    `${config.otpTtlMinutes} minutes`
  ]);
  return code;
}

export async function insertRefresh(
  db: Queryable,
  userId: string,
  familyId: string = randomUUID()
): Promise<{ refreshToken: string; familyId: string; tokenId: string }> {
  const refreshToken = randomBytes(32).toString('base64url');
  const rows = await query<{ token_id: string }>(
    db,
    "INSERT INTO refresh_tokens (user_id, family_id, token_hash, expires_at) VALUES ($1, $2, $3, now() + interval '30 days') RETURNING token_id",
    [userId, familyId, refreshHash(refreshToken)]
  );
  return { refreshToken, familyId, tokenId: rows[0]!.token_id };
}

export async function tokens(app: FastifyInstance, db: Queryable, user: AuthUserRow) {
  const refresh = await insertRefresh(db, user.user_id);
  return {
    user: userDto(user),
    accessToken: app.jwt.sign({ sub: user.user_id }),
    refreshToken: refresh.refreshToken
  };
}
