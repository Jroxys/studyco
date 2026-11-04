import type { Queryable } from '../../db/pool.js';

export type RequestRow = {
  id: string;
  status: string;
  completionStatus: string;
  agreedTokenAmount: number | null;
  respondedAt: string | null;
  autoCancelReason: string | null;
  studentCompletedAt: string | null;
  teacherCompletedAt: string | null;
  confirmationDeadlineAt: string | null;
  settledAt: string | null;
  settlementBasis: string | null;
  createdAt: string;
  listingId: string;
  topic: string;
  startAt: string;
  endAt: string;
  tokenPrice: number;
  studentId: string;
  studentFirstName: string;
  studentLastNameInitial: string;
  studentDepartmentId: string;
  teacherId: string;
  teacherFirstName: string;
  teacherLastNameInitial: string;
  teacherDepartmentId: string;
  conversationId: string | null;
};
export type RequestAction = 'accept' | 'reject' | 'confirm';
export type RequestCursor = { createdAt: string; id: string };

const requestSelect = `SELECT lr.request_id AS id, lr.request_status AS status,
  lr.completion_status AS "completionStatus", lr.agreed_token_amount AS "agreedTokenAmount",
  lr.responded_at::text AS "respondedAt", lr.auto_cancel_reason AS "autoCancelReason",
  lr.student_completed_at::text AS "studentCompletedAt", lr.teacher_completed_at::text AS "teacherCompletedAt",
  lr.confirmation_deadline_at::text AS "confirmationDeadlineAt", lr.settled_at::text AS "settledAt",
  lr.settlement_basis AS "settlementBasis", lr.created_at::text AS "createdAt", l.listing_id AS "listingId",
  l.topic, l.start_at::text AS "startAt", l.end_at::text AS "endAt", l.token_price AS "tokenPrice",
  su.user_id AS "studentId", su.first_name AS "studentFirstName", left(su.last_name, 1) AS "studentLastNameInitial",
  su.department_id AS "studentDepartmentId", tu.user_id AS "teacherId", tu.first_name AS "teacherFirstName",
  left(tu.last_name, 1) AS "teacherLastNameInitial", tu.department_id AS "teacherDepartmentId",
  c.conversation_id AS "conversationId" FROM lesson_requests lr JOIN listings l ON l.listing_id = lr.listing_id
  JOIN users su ON su.user_id = lr.student_id JOIN users tu ON tu.user_id = lr.teacher_id
  LEFT JOIN conversations c ON c.lesson_request_id = lr.request_id`;

export async function insertRequest(
  db: Queryable,
  listingId: string,
  studentId: string
): Promise<string> {
  const result = await db.query<{ id: string }>(
    'INSERT INTO lesson_requests (listing_id, student_id) VALUES ($1, $2) RETURNING request_id AS id',
    [listingId, studentId]
  );
  return result.rows[0]!.id;
}
export async function findRequest(
  db: Queryable,
  requestId: string
): Promise<RequestRow | undefined> {
  return (await db.query<RequestRow>(`${requestSelect} WHERE lr.request_id = $1`, [requestId]))
    .rows[0];
}
export async function findMyRequests(
  db: Queryable,
  userId: string,
  role: 'student' | 'teacher',
  status: string | undefined,
  cursor: RequestCursor | undefined,
  limit: number
): Promise<RequestRow[]> {
  const ownerColumn = role === 'student' ? 'lr.student_id' : 'lr.teacher_id';
  return (
    await db.query<RequestRow>(
      `${requestSelect} WHERE ${ownerColumn} = $1 AND ($2::text IS NULL OR lr.request_status = $2) AND ($3::timestamptz IS NULL OR (lr.created_at, lr.request_id) < ($3::timestamptz, $4::uuid)) ORDER BY lr.created_at DESC, lr.request_id DESC LIMIT $5`,
      [userId, status ?? null, cursor?.createdAt ?? null, cursor?.id ?? null, limit]
    )
  ).rows;
}
export async function runRequestAction(
  db: Queryable,
  action: RequestAction,
  requestId: string,
  userId: string
): Promise<void> {
  const functions: Record<RequestAction, string> = {
    accept: 'accept_lesson_request',
    reject: 'reject_lesson_request',
    confirm: 'confirm_lesson'
  };
  await db.query(`SELECT * FROM ${functions[action]}($1, $2)`, [requestId, userId]);
}
