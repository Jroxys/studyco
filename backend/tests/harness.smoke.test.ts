import { afterAll, describe, expect, inject, it } from 'vitest';
import { Pool } from 'pg';

import { createUser } from './helpers/factories.js';

const pool = new Pool({ connectionString: inject('testDatabaseUrl') });

afterAll(async () => {
  await pool.end();
});

describe('integration test database', () => {
  it('applies the schema, seeds departments, and creates the welcome bonus', async () => {
    const schema = await pool.query<{ exists: boolean }>(
      "SELECT to_regclass('public.users') IS NOT NULL AS exists"
    );
    expect(schema.rows[0]?.exists).toBe(true);

    const userId = await createUser(pool);
    const wallet = await pool.query<{ available: number; welcomeBonusCount: number }>(
      `SELECT w.available_balance AS available,
              count(wt.transaction_id)::int AS "welcomeBonusCount"
       FROM wallets w
       LEFT JOIN wallet_transactions wt
         ON wt.wallet_id = w.wallet_id AND wt.transaction_type = 'WELCOME_BONUS'
       WHERE w.user_id = $1
       GROUP BY w.wallet_id, w.available_balance`,
      [userId]
    );

    expect(wallet.rows).toEqual([{ available: 10, welcomeBonusCount: 1 }]);
  });

  it('starts with no integrity violations', async () => {
    const result = await pool.query('SELECT * FROM v_integrity_violations');
    expect(result.rows).toEqual([]);
  });
});
