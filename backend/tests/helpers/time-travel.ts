import type { Queryable } from '../../src/db/pool.js';

export async function acceptLessonRequestAt(
  db: Queryable,
  requestId: string,
  teacherId: string,
  now: Date
): Promise<void> {
  await db.query('SELECT * FROM accept_lesson_request($1, $2, $3)', [
    requestId,
    teacherId,
    now.toISOString()
  ]);
}

export async function rejectLessonRequestAt(
  db: Queryable,
  requestId: string,
  teacherId: string,
  now: Date
): Promise<void> {
  await db.query('SELECT * FROM reject_lesson_request($1, $2, $3)', [
    requestId,
    teacherId,
    now.toISOString()
  ]);
}

export async function confirmLessonAt(
  db: Queryable,
  requestId: string,
  userId: string,
  now: Date
): Promise<void> {
  await db.query('SELECT * FROM confirm_lesson($1, $2, $3)', [
    requestId,
    userId,
    now.toISOString()
  ]);
}

export async function processExpiredConfirmationsAt(db: Queryable, now: Date): Promise<void> {
  await db.query('SELECT process_expired_confirmations($1)', [now.toISOString()]);
}

export async function expireStaleRequestsAt(db: Queryable, now: Date): Promise<void> {
  await db.query('SELECT expire_stale_requests($1)', [now.toISOString()]);
}
