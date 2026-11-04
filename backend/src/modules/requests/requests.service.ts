import type { FastifyRequest } from 'fastify';

import { withTx, type Queryable, type TransactionPool } from '../../db/pool.js';
import { AppError } from '../../errors.js';
import { authenticatedUserId as authenticatedUserIdFromGuard } from '../auth/auth.service.js';
import type { RequestQuery } from './requests.schemas.js';
import {
  findMyRequests,
  findRequest,
  insertRequest,
  runRequestAction,
  type RequestAction,
  type RequestCursor,
  type RequestRow
} from './requests.repo.js';

function asIso(value: string | null): string | null {
  return value === null ? null : new Date(value).toISOString();
}
function requestView(row: RequestRow, callerId: string) {
  const student = {
    id: row.studentId,
    firstName: row.studentFirstName,
    lastNameInitial: row.studentLastNameInitial,
    departmentId: row.studentDepartmentId
  };
  const teacher = {
    id: row.teacherId,
    firstName: row.teacherFirstName,
    lastNameInitial: row.teacherLastNameInitial,
    departmentId: row.teacherDepartmentId
  };
  return {
    id: row.id,
    status: row.status,
    completionStatus: row.completionStatus,
    agreedTokenAmount: row.agreedTokenAmount,
    respondedAt: asIso(row.respondedAt),
    autoCancelReason: row.autoCancelReason,
    studentCompletedAt: asIso(row.studentCompletedAt),
    teacherCompletedAt: asIso(row.teacherCompletedAt),
    confirmationDeadlineAt: asIso(row.confirmationDeadlineAt),
    settledAt: asIso(row.settledAt),
    settlementBasis: row.settlementBasis,
    createdAt: new Date(row.createdAt).toISOString(),
    listing: {
      id: row.listingId,
      topic: row.topic,
      startAt: new Date(row.startAt).toISOString(),
      endAt: new Date(row.endAt).toISOString(),
      tokenPrice: row.tokenPrice
    },
    counterpart: row.studentId === callerId ? teacher : student,
    conversationId: row.conversationId
  };
}
async function authenticatedUserId(request: FastifyRequest): Promise<string> {
  return authenticatedUserIdFromGuard(request);
}
function parseCursor(value: string): RequestCursor {
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
function cursorFor(row: RequestRow): string {
  return Buffer.from(JSON.stringify({ createdAt: row.createdAt, id: row.id })).toString(
    'base64url'
  );
}
async function participantRequest(
  db: Queryable,
  requestId: string,
  callerId: string,
  hide: boolean
): Promise<RequestRow> {
  const row = await findRequest(db, requestId);
  if (!row || (row.studentId !== callerId && row.teacherId !== callerId))
    throw new AppError(
      hide ? 404 : 403,
      hide ? 'REQUEST_NOT_FOUND' : 'NOT_A_PARTICIPANT',
      hide ? 'Request not found' : 'You are not a participant'
    );
  return row;
}
export async function createRequest(db: Queryable, request: FastifyRequest, listingId: string) {
  const callerId = await authenticatedUserId(request);
  const requestId = await withTx(db as unknown as TransactionPool, (client) =>
    insertRequest(client, listingId, callerId)
  );
  return requestView(await participantRequest(db, requestId, callerId, false), callerId);
}
export async function getRequest(db: Queryable, request: FastifyRequest, requestId: string) {
  const callerId = await authenticatedUserId(request);
  return requestView(await participantRequest(db, requestId, callerId, true), callerId);
}
export async function getMyRequests(db: Queryable, request: FastifyRequest, query: RequestQuery) {
  const callerId = await authenticatedUserId(request);
  const cursor = query.cursor ? parseCursor(query.cursor) : undefined;
  const rows = await findMyRequests(
    db,
    callerId,
    query.role,
    query.status,
    cursor,
    query.limit + 1
  );
  const page = rows.slice(0, query.limit);
  return {
    items: page.map((row) => requestView(row, callerId)),
    nextCursor: rows.length > query.limit ? cursorFor(page[page.length - 1]!) : null
  };
}
export async function mutateRequest(
  db: Queryable,
  request: FastifyRequest,
  requestId: string,
  action: RequestAction
) {
  const callerId = await authenticatedUserId(request);
  await participantRequest(db, requestId, callerId, true);
  await withTx(db as unknown as TransactionPool, (client) =>
    runRequestAction(client, action, requestId, callerId)
  );
  return requestView(await participantRequest(db, requestId, callerId, false), callerId);
}
