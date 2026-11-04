import type { FastifyRequest } from 'fastify';

import type { Queryable } from '../../db/pool.js';
import { AppError } from '../../errors.js';
import { authenticatedUserId as authenticatedUserIdFromGuard } from '../auth/auth.service.js';
import { findTransactions, findWallet, type TransactionRow } from './wallet.repo.js';

async function authenticatedUserId(request: FastifyRequest): Promise<string> {
  return authenticatedUserIdFromGuard(request);
}
function parseCursor(value: string): { createdAt: string; id: string } {
  try {
    const parsed: unknown = JSON.parse(Buffer.from(value, 'base64url').toString('utf8'));
    if (
      typeof parsed === 'object' &&
      parsed !== null &&
      'createdAt' in parsed &&
      'id' in parsed &&
      typeof parsed.createdAt === 'string' &&
      typeof parsed.id === 'string' &&
      !Number.isNaN(Date.parse(parsed.createdAt))
    )
      return { createdAt: parsed.createdAt, id: parsed.id };
  } catch {
    /* mapped below */
  }
  throw new AppError(400, 'BAD_CURSOR', 'Invalid cursor');
}
function cursorFor(row: TransactionRow): string {
  return Buffer.from(JSON.stringify({ createdAt: row.createdAt, id: row.id })).toString(
    'base64url'
  );
}
export async function getWallet(db: Queryable, request: FastifyRequest) {
  const userId = await authenticatedUserId(request);
  const wallet = await findWallet(db, userId);
  if (!wallet) throw new AppError(500, 'INTERNAL', 'Internal server error');
  return wallet;
}
export async function getTransactions(
  db: Queryable,
  request: FastifyRequest,
  query: { limit: number; cursor?: string | undefined }
) {
  const userId = await authenticatedUserId(request);
  const cursor = query.cursor ? parseCursor(query.cursor) : undefined;
  const rows = await findTransactions(db, userId, cursor, query.limit + 1);
  const page = rows.slice(0, query.limit);
  return {
    items: page,
    nextCursor: rows.length > query.limit ? cursorFor(page[page.length - 1]!) : null
  };
}
