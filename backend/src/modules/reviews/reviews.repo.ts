import type { Queryable } from '../../db/pool.js';

export type ReviewRow = {
  id: string;
  requestId: string;
  reviewerId: string;
  reviewerFirstName: string;
  reviewerLastNameInitial: string;
  reviewerDepartmentId: string;
  rating: number;
  comment: string | null;
  createdAt: string;
};
export type Cursor = { createdAt: string; id: string };
const selectReview = `SELECT r.review_id AS id, r.lesson_request_id AS "requestId", u.user_id AS "reviewerId", u.first_name AS "reviewerFirstName", left(u.last_name, 1) AS "reviewerLastNameInitial", u.department_id AS "reviewerDepartmentId", r.rating, r.comment, r.created_at::text AS "createdAt" FROM reviews r JOIN users u ON u.user_id = r.reviewer_id`;

export async function findRequestParties(
  db: Queryable,
  requestId: string
): Promise<{ studentId: string; teacherId: string } | undefined> {
  return (
    await db.query<{ studentId: string; teacherId: string }>(
      'SELECT student_id AS "studentId", teacher_id AS "teacherId" FROM lesson_requests WHERE request_id = $1',
      [requestId]
    )
  ).rows[0];
}
export async function insertReview(
  db: Queryable,
  requestId: string,
  reviewerId: string,
  revieweeId: string,
  rating: number,
  comment: string | null
): Promise<ReviewRow> {
  const inserted = await db.query<{ id: string }>(
    'INSERT INTO reviews (lesson_request_id, reviewer_id, reviewee_id, rating, comment) VALUES ($1,$2,$3,$4,$5) RETURNING review_id AS id',
    [requestId, reviewerId, revieweeId, rating, comment]
  );
  return (
    await db.query<ReviewRow>(`${selectReview} WHERE r.review_id = $1`, [inserted.rows[0]!.id])
  ).rows[0]!;
}
export async function userExists(db: Queryable, userId: string): Promise<boolean> {
  return (await db.query('SELECT 1 FROM users WHERE user_id = $1', [userId])).rows.length === 1;
}
export async function findUserReviews(
  db: Queryable,
  userId: string,
  cursor: Cursor | undefined,
  limit: number
): Promise<ReviewRow[]> {
  return (
    await db.query<ReviewRow>(
      `${selectReview} WHERE r.reviewee_id = $1 AND ($2::timestamptz IS NULL OR (r.created_at, r.review_id) < ($2::timestamptz, $3::uuid)) ORDER BY r.created_at DESC, r.review_id DESC LIMIT $4`,
      [userId, cursor?.createdAt ?? null, cursor?.id ?? null, limit]
    )
  ).rows;
}
export async function findRequestReviews(db: Queryable, requestId: string): Promise<ReviewRow[]> {
  return (
    await db.query<ReviewRow>(
      `${selectReview} WHERE r.lesson_request_id = $1 ORDER BY r.created_at DESC, r.review_id DESC`,
      [requestId]
    )
  ).rows;
}
