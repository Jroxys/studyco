import type { FastifyInstance, FastifyRequest } from 'fastify';
import type { Queryable } from '../../db/pool.js';
import { AppError } from '../../errors.js';
import { authenticatedUserId } from '../auth/auth.service.js';
import {
  createListingSchema,
  listingParamsSchema,
  listingQuerySchema,
  listingResponses,
  patchListingSchema
} from './listings.schemas.js';

type ListingRow = {
  id: string;
  courseId: string;
  courseName: string;
  locationId: string;
  locationName: string;
  topic: string;
  description: string | null;
  startAt: string;
  endAt: string;
  tokenPrice: number;
  status: string;
  teacherId: string;
  teacherFirstName: string;
  teacherLastNameInitial: string;
  teacherDepartmentId: string;
  ratingAverage: number | null;
  ratingCount: number;
  myRequest?: {
    id: string;
    status: string;
    completionStatus: string;
    conversationId: string | null;
  } | null;
};
type MyListingRow = ListingRow & { pendingRequestCount: number };
type Cursor = { startAt: string; id: string };

async function userId(request: FastifyRequest): Promise<string> {
  return authenticatedUserId(request);
}
function cursorFrom(value: string): Cursor {
  try {
    const parsed = JSON.parse(Buffer.from(value, 'base64url').toString('utf8')) as unknown;
    if (
      !parsed ||
      typeof parsed !== 'object' ||
      typeof (parsed as Cursor).startAt !== 'string' ||
      typeof (parsed as Cursor).id !== 'string' ||
      Number.isNaN(Date.parse((parsed as Cursor).startAt)) ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
        (parsed as Cursor).id
      )
    )
      throw new Error('bad');
    return parsed as Cursor;
  } catch {
    throw new AppError(400, 'BAD_CURSOR', 'Invalid cursor');
  }
}
function cursorFor(row: ListingRow): string {
  return Buffer.from(JSON.stringify({ startAt: row.startAt, id: row.id })).toString('base64url');
}
function dto(row: ListingRow) {
  return {
    id: row.id,
    courseId: row.courseId,
    courseName: row.courseName,
    locationId: row.locationId,
    locationName: row.locationName,
    topic: row.topic,
    description: row.description,
    startAt: new Date(row.startAt).toISOString(),
    endAt: new Date(row.endAt).toISOString(),
    tokenPrice: row.tokenPrice,
    status: row.status,
    teacher: {
      id: row.teacherId,
      firstName: row.teacherFirstName,
      lastNameInitial: row.teacherLastNameInitial,
      departmentId: row.teacherDepartmentId,
      ratingAverage: row.ratingAverage,
      ratingCount: row.ratingCount
    },
    ...(Object.hasOwn(row, 'myRequest') ? { myRequest: row.myRequest ?? null } : {})
  };
}

const selectListing = `SELECT l.listing_id AS id, l.course_id AS "courseId", c.course_name AS "courseName", l.location_id AS "locationId", loc.name AS "locationName", l.topic, l.description, l.start_at::text AS "startAt", l.end_at::text AS "endAt", l.token_price AS "tokenPrice", s.effective_status AS status, u.user_id AS "teacherId", u.first_name AS "teacherFirstName", left(u.last_name, 1) AS "teacherLastNameInitial", u.department_id AS "teacherDepartmentId", avg(r.rating)::float AS "ratingAverage", count(r.review_id)::int AS "ratingCount" FROM v_listing_state s JOIN listings l ON l.listing_id = s.listing_id JOIN courses c ON c.course_id = l.course_id JOIN locations loc ON loc.location_id = l.location_id JOIN users u ON u.user_id = l.teacher_id LEFT JOIN reviews r ON r.reviewee_id = u.user_id`;
const selectMyListing = selectListing.replace(
  ' FROM v_listing_state',
  ', (SELECT count(*)::int FROM lesson_requests lr WHERE lr.listing_id = l.listing_id AND lr.request_status = \'PENDING\') AS "pendingRequestCount" FROM v_listing_state'
);
const groupListing =
  ' GROUP BY l.listing_id, c.course_name, loc.name, s.effective_status, u.user_id';

export function registerListingRoutes(app: FastifyInstance, db: Queryable): void {
  app.post(
    '/api/v1/listings',
    { schema: { body: createListingSchema, response: listingResponses.created } },
    async (request, reply) => {
      const teacherId = await userId(request);
      const body = createListingSchema.parse(request.body);
      const result = await db.query<{ id: string }>(
        'INSERT INTO listings (teacher_id, course_id, location_id, topic, description, start_at, end_at, token_price) VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING listing_id AS id',
        [
          teacherId,
          body.courseId,
          body.locationId,
          body.topic,
          body.description ?? null,
          body.startAt,
          body.endAt,
          body.tokenPrice
        ]
      );
      const rows = await db.query<ListingRow>(
        `${selectListing} WHERE l.listing_id = $1${groupListing}`,
        [result.rows[0]!.id]
      );
      return reply.status(201).send(dto(rows.rows[0]!));
    }
  );
  app.get(
    '/api/v1/listings',
    { schema: { querystring: listingQuerySchema, response: listingResponses.list } },
    async (request) => {
      const caller = await userId(request);
      const filters = listingQuerySchema.parse(request.query);
      const cursor = filters.cursor ? cursorFrom(filters.cursor) : undefined;
      const rows = await db.query<ListingRow>(
        `${selectListing} WHERE s.effective_status = 'PUBLISHED' AND ($1::uuid IS NULL OR c.department_id = $1) AND ($2::uuid IS NULL OR l.course_id = $2) AND ($3::uuid IS NULL OR l.location_id = $3) AND ($4::timestamptz IS NULL OR l.start_at >= $4) AND ($5::timestamptz IS NULL OR l.start_at <= $5) AND ($6::smallint IS NULL OR l.token_price <= $6) AND ($7::text IS NULL OR l.topic ILIKE '%' || replace(replace(replace($7, '\\', '\\\\'), '%', '\\%'), '_', '\\_') || '%' ESCAPE '\\') AND ($8::boolean OR l.teacher_id <> $9::uuid) AND ($10::timestamptz IS NULL OR (l.start_at, l.listing_id) > ($10::timestamptz, $11::uuid))${groupListing} ORDER BY l.start_at ASC, l.listing_id ASC LIMIT $12`,
        [
          filters.departmentId ?? null,
          filters.courseId ?? null,
          filters.locationId ?? null,
          filters.from ?? null,
          filters.to ?? null,
          filters.maxPrice ?? null,
          filters.q ?? null,
          filters.mine === 'true',
          caller,
          cursor?.startAt ?? null,
          cursor?.id ?? null,
          filters.limit + 1
        ]
      );
      const page = rows.rows.slice(0, filters.limit);
      return {
        items: page.map(dto),
        nextCursor: rows.rows.length > filters.limit ? cursorFor(page[page.length - 1]!) : null
      };
    }
  );
  app.get(
    '/api/v1/me/listings',
    { schema: { response: listingResponses.myList } },
    async (request) => {
      const caller = await userId(request);
      const rows = await db.query<MyListingRow>(
        `${selectMyListing} WHERE l.teacher_id = $1${groupListing} ORDER BY l.start_at ASC, l.listing_id ASC`,
        [caller]
      );
      return rows.rows.map((row) => ({
        ...dto(row),
        pendingRequestCount: row.pendingRequestCount
      }));
    }
  );
  app.get(
    '/api/v1/listings/:id',
    { schema: { params: listingParamsSchema, response: listingResponses.item } },
    async (request) => {
      const caller = await userId(request);
      const { id } = listingParamsSchema.parse(request.params);
      const detailSelect = selectListing.replace(
        ' FROM v_listing_state',
        `, (SELECT json_build_object('id', lr.request_id, 'status', lr.request_status, 'completionStatus', lr.completion_status, 'conversationId', c.conversation_id) FROM lesson_requests lr LEFT JOIN conversations c ON c.lesson_request_id = lr.request_id WHERE lr.listing_id = l.listing_id AND lr.student_id = $2) AS "myRequest" FROM v_listing_state`
      );
      const rows = await db.query<ListingRow>(
        `${detailSelect} WHERE l.listing_id = $1${groupListing}`,
        [id, caller]
      );
      if (!rows.rows[0]) throw new AppError(404, 'LISTING_NOT_FOUND', 'Listing not found');
      return dto(rows.rows[0]);
    }
  );
  app.patch(
    '/api/v1/listings/:id',
    {
      schema: {
        params: listingParamsSchema,
        body: patchListingSchema,
        response: listingResponses.item
      }
    },
    async (request) => {
      const caller = await userId(request);
      const { id } = listingParamsSchema.parse(request.params);
      const body = patchListingSchema.parse(request.body);
      const owner = await db.query<{ teacherId: string }>(
        'SELECT teacher_id AS "teacherId" FROM listings WHERE listing_id = $1',
        [id]
      );
      if (!owner.rows[0]) throw new AppError(404, 'LISTING_NOT_FOUND', 'Listing not found');
      if (owner.rows[0].teacherId !== caller)
        throw new AppError(403, 'NOT_LISTING_OWNER', 'You do not own this listing');
      await db.query(
        'UPDATE listings SET topic = COALESCE($2, topic), description = CASE WHEN $3::boolean THEN $4 ELSE description END WHERE listing_id = $1 AND teacher_id = $5',
        [id, body.topic ?? null, Object.hasOwn(body, 'description'), body.description ?? null, caller]
      );
      const rows = await db.query<ListingRow>(
        `${selectListing} WHERE l.listing_id = $1${groupListing}`,
        [id]
      );
      return dto(rows.rows[0]!);
    }
  );
}
