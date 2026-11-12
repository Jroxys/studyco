import type { Queryable } from '../../db/pool.js';

export type MessageRow = {
  id: string;
  senderId: string;
  body: string;
  sentAt: string;
  readAt: string | null;
};
export type ConversationRow = {
  id: string;
  requestId: string;
  listingId: string;
  topic: string;
  counterpartId: string;
  counterpartFirstName: string;
  counterpartLastNameInitial: string;
  counterpartDepartmentId: string;
  lastMessageId: string | null;
  lastMessageSenderId: string | null;
  lastMessageBody: string | null;
  lastMessageSentAt: string | null;
  lastMessageReadAt: string | null;
  unreadCount: number;
  createdAt: string;
};
export type Cursor = { sentAt: string; id: string };

export async function isParticipant(
  db: Queryable,
  userId: string,
  conversationId: string
): Promise<boolean> {
  return (
    (
      await db.query<{ participant: boolean }>(
        'SELECT is_conversation_participant($1, $2) AS participant',
        [userId, conversationId]
      )
    ).rows[0]?.participant === true
  );
}
export async function findConversations(
  db: Queryable,
  userId: string,
  cursor: Cursor | undefined,
  limit: number
): Promise<ConversationRow[]> {
  return (
    await db.query<ConversationRow>(
      `SELECT c.conversation_id AS id, c.lesson_request_id AS "requestId", l.listing_id AS "listingId", l.topic,
    CASE WHEN lr.student_id = $1 THEN teacher.user_id ELSE student.user_id END AS "counterpartId",
    CASE WHEN lr.student_id = $1 THEN teacher.first_name ELSE student.first_name END AS "counterpartFirstName",
    CASE WHEN lr.student_id = $1 THEN left(teacher.last_name, 1) ELSE left(student.last_name, 1) END AS "counterpartLastNameInitial",
    CASE WHEN lr.student_id = $1 THEN teacher.department_id ELSE student.department_id END AS "counterpartDepartmentId",
    latest.message_id AS "lastMessageId", latest.sender_id AS "lastMessageSenderId", latest.body AS "lastMessageBody", latest.sent_at::text AS "lastMessageSentAt", latest.read_at::text AS "lastMessageReadAt",
    count(m.message_id) FILTER (WHERE m.sender_id <> $1 AND m.read_at IS NULL)::int AS "unreadCount", c.created_at::text AS "createdAt"
    FROM conversations c JOIN lesson_requests lr ON lr.request_id = c.lesson_request_id JOIN listings l ON l.listing_id = lr.listing_id
    JOIN users student ON student.user_id = lr.student_id JOIN users teacher ON teacher.user_id = lr.teacher_id
    LEFT JOIN LATERAL (SELECT message_id, sender_id, body, sent_at, read_at FROM messages WHERE conversation_id = c.conversation_id ORDER BY sent_at DESC, message_id DESC LIMIT 1) latest ON true
    LEFT JOIN messages m ON m.conversation_id = c.conversation_id
    WHERE is_conversation_participant($1, c.conversation_id) AND ($2::timestamptz IS NULL OR (c.created_at, c.conversation_id) < ($2::timestamptz, $3::uuid))
    GROUP BY c.conversation_id, lr.request_id, l.listing_id, student.user_id, teacher.user_id, latest.message_id, latest.sender_id, latest.body, latest.sent_at, latest.read_at
    ORDER BY c.created_at DESC, c.conversation_id DESC LIMIT $4`,
      [userId, cursor?.sentAt ?? null, cursor?.id ?? null, limit]
    )
  ).rows;
}
export async function findMessages(
  db: Queryable,
  conversationId: string,
  cursor: Cursor | undefined,
  limit: number
): Promise<MessageRow[]> {
  return (
    await db.query<MessageRow>(
      'SELECT message_id AS id, sender_id AS "senderId", body, sent_at::text AS "sentAt", read_at::text AS "readAt" FROM messages WHERE conversation_id = $1 AND ($2::timestamptz IS NULL OR (sent_at, message_id) < ($2::timestamptz, $3::uuid)) ORDER BY sent_at DESC, message_id DESC LIMIT $4',
      [conversationId, cursor?.sentAt ?? null, cursor?.id ?? null, limit]
    )
  ).rows;
}
export async function insertMessage(
  db: Queryable,
  conversationId: string,
  senderId: string,
  body: string
): Promise<MessageRow> {
  return (
    await db.query<MessageRow>(
      'INSERT INTO messages (conversation_id, sender_id, body) VALUES ($1, $2, $3) RETURNING message_id AS id, sender_id AS "senderId", body, sent_at::text AS "sentAt", read_at::text AS "readAt"',
      [conversationId, senderId, body]
    )
  ).rows[0]!;
}
export async function markOtherMessagesRead(
  db: Queryable,
  conversationId: string,
  userId: string
): Promise<void> {
  await db.query(
    'UPDATE messages SET read_at = now() WHERE conversation_id = $1 AND sender_id <> $2 AND read_at IS NULL',
    [conversationId, userId]
  );
}
