import { query, type Queryable } from '../../db/pool.js';

export interface AuthUserRow extends Record<string, unknown> {
  user_id: string;
  first_name: string;
  last_name: string;
  birth_date: string;
  email: string;
  phone: string;
  department_id: string;
  email_verified_at: string | null;
  password_hash: string;
  anonymized_at: string | null;
}

const userColumns =
  'user_id, first_name, last_name, birth_date::text, email::text, phone, department_id, email_verified_at::text, password_hash, anonymized_at::text';

export async function findUserByEmail(
  db: Queryable,
  email: string
): Promise<AuthUserRow | undefined> {
  return (
    await query<AuthUserRow>(db, `SELECT ${userColumns} FROM users WHERE email = $1`, [email])
  )[0];
}

export async function findUserById(db: Queryable, id: string): Promise<AuthUserRow | undefined> {
  return (
    await query<AuthUserRow>(db, `SELECT ${userColumns} FROM users WHERE user_id = $1`, [id])
  )[0];
}
