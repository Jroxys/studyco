import type { FastifyRequest } from 'fastify';

import { withTx, type Queryable, type TransactionPool } from '../../db/pool.js';
import { AppError } from '../../errors.js';
import { authenticatedUserId } from '../auth/auth.service.js';
import {
  findConversations,
  findMessages,
  insertMessage,
  isParticipant,
  markOtherMessagesRead,
  type ConversationRow,
  type Cursor,
  type MessageRow
} from './messages.repo.js';

async function userId(request: FastifyRequest): Promise<string> {
  return authenticatedUserId(request);
}
function iso(value: string | null): string | null {
  return value === null ? null : new Date(value).toISOString();
}
function message(row: MessageRow) {
  return { ...row, sentAt: new Date(row.sentAt).toISOString(), readAt: iso(row.readAt) };
}
function conversation(row: ConversationRow) {
  return {
    id: row.id,
    requestId: row.requestId,
    listing: { id: row.listingId, topic: row.topic },
    counterpart: {
      id: row.counterpartId,
      firstName: row.counterpartFirstName,
      lastNameInitial: row.counterpartLastNameInitial,
      departmentId: row.counterpartDepartmentId
    },
    lastMessage:
      row.lastMessageId === null
        ? null
        : {
            id: row.lastMessageId,
            senderId: row.lastMessageSenderId!,
            body: row.lastMessageBody!,
            sentAt: new Date(row.lastMessageSentAt!).toISOString(),
            readAt: iso(row.lastMessageReadAt)
          },
    unreadCount: row.unreadCount
  };
}
function cursor(value: string): Cursor {
  try {
    const row = JSON.parse(Buffer.from(value, 'base64url').toString('utf8')) as unknown;
    if (
      typeof row === 'object' &&
      row !== null &&
      'sentAt' in row &&
      'id' in row &&
      typeof row.sentAt === 'string' &&
      typeof row.id === 'string' &&
      !Number.isNaN(Date.parse(row.sentAt))
    )
      return { sentAt: row.sentAt, id: row.id };
  } catch {
    /* mapped below */
  }
  throw new AppError(400, 'BAD_CURSOR', 'Invalid cursor');
}
function cursorFor(row: { sentAt?: string; createdAt?: string; id: string }): string {
  return Buffer.from(JSON.stringify({ sentAt: row.sentAt ?? row.createdAt, id: row.id })).toString(
    'base64url'
  );
}
async function requireParticipant(
  db: Queryable,
  caller: string,
  conversationId: string
): Promise<void> {
  if (!(await isParticipant(db, caller, conversationId)))
    throw new AppError(403, 'NOT_A_PARTICIPANT', 'You are not a conversation participant');
}
export async function getConversations(
  db: Queryable,
  request: FastifyRequest,
  query: { limit: number; cursor?: string | undefined }
): Promise<{ items: ReturnType<typeof conversation>[]; nextCursor: string | null }> {
  const caller = await userId(request);
  const rows = await findConversations(
    db,
    caller,
    query.cursor ? cursor(query.cursor) : undefined,
    query.limit + 1
  );
  const page = rows.slice(0, query.limit);
  return {
    items: page.map(conversation),
    nextCursor: rows.length > query.limit ? cursorFor(page[page.length - 1]!) : null
  };
}
export async function getMessages(
  db: Queryable,
  request: FastifyRequest,
  conversationId: string,
  query: { limit: number; cursor?: string | undefined }
) {
  const caller = await userId(request);
  await requireParticipant(db, caller, conversationId);
  const rows = await findMessages(
    db,
    conversationId,
    query.cursor ? cursor(query.cursor) : undefined,
    query.limit + 1
  );
  const page = rows.slice(0, query.limit);
  return {
    items: page.map(message),
    nextCursor: rows.length > query.limit ? cursorFor(page[page.length - 1]!) : null
  };
}
export async function postMessage(
  db: Queryable,
  request: FastifyRequest,
  conversationId: string,
  body: string
) {
  const caller = await userId(request);
  await requireParticipant(db, caller, conversationId);
  return message(
    await withTx(db as unknown as TransactionPool, (client) =>
      insertMessage(client, conversationId, caller, body)
    )
  );
}
export async function readConversation(
  db: Queryable,
  request: FastifyRequest,
  conversationId: string
): Promise<void> {
  const caller = await userId(request);
  await requireParticipant(db, caller, conversationId);
  await markOtherMessagesRead(db, conversationId, caller);
}
