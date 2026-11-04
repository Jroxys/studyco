import { randomUUID } from 'node:crypto';

import type { Queryable } from '../../src/db/pool.js';

type IdRow = { id: string };

function phoneSuffix(value: string): string {
  return value
    .replaceAll('-', '')
    .slice(0, 9)
    .split('')
    .map((character) => (Number.parseInt(character, 16) % 10).toString())
    .join('');
}

export interface CreateUserOptions {
  departmentId?: string;
  email?: string;
  phone?: string;
  firstName?: string;
  lastName?: string;
}

export async function createUser(db: Queryable, options: CreateUserOptions = {}): Promise<string> {
  const unique = randomUUID();
  const departmentId =
    options.departmentId ??
    (
      await db.query<IdRow>(
        'SELECT department_id AS id FROM departments WHERE is_active = true ORDER BY name LIMIT 1'
      )
    ).rows[0]?.id;
  if (!departmentId) {
    throw new Error('Test database has no active department.');
  }

  const result = await db.query<IdRow>(
    `INSERT INTO users (department_id, first_name, last_name, birth_date, email, phone, password_hash, terms_accepted_at, terms_version)
     VALUES ($1, $2, $3, $4, $5, $6, $7, now(), $8)
     RETURNING user_id AS id`,
    [
      departmentId,
      options.firstName ?? 'Test',
      options.lastName ?? 'User',
      '2000-01-01',
      options.email ?? `test-${unique}@example.test`,
      options.phone ?? `+905${phoneSuffix(unique)}`,
      'test-password-hash',
      'test-v1'
    ]
  );
  return result.rows[0]!.id;
}

export async function createCourse(db: Queryable, departmentId?: string): Promise<string> {
  const selectedDepartmentId =
    departmentId ??
    (
      await db.query<IdRow>(
        'SELECT department_id AS id FROM departments WHERE is_active = true ORDER BY name LIMIT 1'
      )
    ).rows[0]?.id;
  if (!selectedDepartmentId) {
    throw new Error('Test database has no active department.');
  }
  const result = await db.query<IdRow>(
    'INSERT INTO courses (department_id, course_name) VALUES ($1, $2) RETURNING course_id AS id',
    [selectedDepartmentId, `Test course ${randomUUID()}`]
  );
  return result.rows[0]!.id;
}

export async function createLocation(db: Queryable): Promise<string> {
  const result = await db.query<IdRow>(
    'INSERT INTO locations (name) VALUES ($1) RETURNING location_id AS id',
    [`Test location ${randomUUID()}`]
  );
  return result.rows[0]!.id;
}

export interface CreateListingOptions {
  teacherId: string;
  courseId?: string;
  locationId?: string;
  startAt?: Date;
  endAt?: Date;
  tokenPrice?: 0 | 1 | 2 | 3;
}

export async function createListing(db: Queryable, options: CreateListingOptions): Promise<string> {
  const teacher = await db.query<IdRow>(
    'SELECT department_id AS id FROM users WHERE user_id = $1',
    [options.teacherId]
  );
  const departmentId = teacher.rows[0]?.id;
  if (!departmentId) {
    throw new Error('Listing teacher does not exist.');
  }
  const startAt = options.startAt ?? new Date(Date.now() + 24 * 60 * 60 * 1000);
  const endAt = options.endAt ?? new Date(startAt.getTime() + 60 * 60 * 1000);
  const result = await db.query<IdRow>(
    `INSERT INTO listings (teacher_id, course_id, location_id, topic, start_at, end_at, token_price)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING listing_id AS id`,
    [
      options.teacherId,
      options.courseId ?? (await createCourse(db, departmentId)),
      options.locationId ?? (await createLocation(db)),
      `Test listing ${randomUUID()}`,
      startAt.toISOString(),
      endAt.toISOString(),
      options.tokenPrice ?? 1
    ]
  );
  return result.rows[0]!.id;
}
