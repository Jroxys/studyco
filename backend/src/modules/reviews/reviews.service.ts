import type { FastifyRequest } from 'fastify';
import { withTx, type Queryable, type TransactionPool } from '../../db/pool.js';
import { AppError } from '../../errors.js';
import { authenticatedUserId } from '../auth/auth.service.js';
import {
  findRequestParties,
  findRequestReviews,
  findUserReviews,
  insertReview,
  userExists,
  type Cursor,
  type ReviewRow
} from './reviews.repo.js';

async function userId(request: FastifyRequest): Promise<string> {
  return authenticatedUserId(request);
}
function review(row: ReviewRow) {
  return {
    id: row.id,
    requestId: row.requestId,
    reviewer: {
      id: row.reviewerId,
      firstName: row.reviewerFirstName,
      lastNameInitial: row.reviewerLastNameInitial,
      departmentId: row.reviewerDepartmentId
    },
    rating: row.rating,
    comment: row.comment,
    createdAt: new Date(row.createdAt).toISOString()
  };
}
function cursor(value: string): Cursor {
  try {
    const row = JSON.parse(Buffer.from(value, 'base64url').toString('utf8')) as unknown;
    if (
      typeof row === 'object' &&
      row !== null &&
      'createdAt' in row &&
      'id' in row &&
      typeof row.createdAt === 'string' &&
      typeof row.id === 'string' &&
      !Number.isNaN(Date.parse(row.createdAt))
    )
      return { createdAt: row.createdAt, id: row.id };
  } catch {
    /* mapped below */
  }
  throw new AppError(400, 'BAD_CURSOR', 'Invalid cursor');
}
function cursorFor(row: ReviewRow): string {
  return Buffer.from(JSON.stringify({ createdAt: row.createdAt, id: row.id })).toString(
    'base64url'
  );
}
async function participantRequest(
  db: Queryable,
  requestId: string,
  caller: string,
  hide: boolean
): Promise<{ studentId: string; teacherId: string }> {
  const parties = await findRequestParties(db, requestId);
  if (!parties || (parties.studentId !== caller && parties.teacherId !== caller))
    throw new AppError(
      hide ? 404 : 403,
      hide ? 'REQUEST_NOT_FOUND' : 'NOT_A_PARTICIPANT',
      hide ? 'Request not found' : 'You are not a participant'
    );
  return parties;
}
export async function createReview(
  db: Queryable,
  request: FastifyRequest,
  requestId: string,
  body: { rating: number; comment?: string | null | undefined }
) {
  const caller = await userId(request);
  const parties = await participantRequest(db, requestId, caller, true);
  const revieweeId = parties.studentId === caller ? parties.teacherId : parties.studentId;
  return review(
    await withTx(db as unknown as TransactionPool, (client) =>
      insertReview(client, requestId, caller, revieweeId, body.rating, body.comment ?? null)
    )
  );
}
export async function getUserReviews(
  db: Queryable,
  request: FastifyRequest,
  targetId: string,
  query: { limit: number; cursor?: string | undefined }
) {
  await userId(request);
  if (!(await userExists(db, targetId)))
    throw new AppError(404, 'USER_NOT_FOUND', 'User not found');
  const rows = await findUserReviews(
    db,
    targetId,
    query.cursor ? cursor(query.cursor) : undefined,
    query.limit + 1
  );
  const page = rows.slice(0, query.limit);
  return {
    items: page.map(review),
    nextCursor: rows.length > query.limit ? cursorFor(page[page.length - 1]!) : null
  };
}
export async function getRequestReviews(db: Queryable, request: FastifyRequest, requestId: string) {
  const caller = await userId(request);
  await participantRequest(db, requestId, caller, true);
  return { items: (await findRequestReviews(db, requestId)).map(review), nextCursor: null };
}
