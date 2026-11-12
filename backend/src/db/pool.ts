import { Pool } from 'pg';

import { config } from '../config.js';

export interface Queryable {
  query<Result extends Record<string, unknown> = Record<string, unknown>>(
    text: string,
    values?: readonly unknown[]
  ): Promise<{ rows: Result[] }>;
}

export interface TransactionClient extends Queryable {
  release(): void;
}

export interface TransactionPool {
  connect(): Promise<TransactionClient>;
}

export interface TransactionOptions {
  maxAttempts?: number;
  sleep?: (milliseconds: number) => Promise<void>;
  random?: () => number;
}

const retryableCodes = new Set(['40P01', '40001']);

function isRetryable(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    typeof error.code === 'string' &&
    retryableCodes.has(error.code)
  );
}

function wait(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

export const pool = new Pool({
  connectionString: config.databaseUrl,
  max: config.pgPoolMax,
  connectionTimeoutMillis: config.pgConnectionTimeoutMillis,
  options: '-c statement_timeout=30000 -c lock_timeout=5000 -c idle_in_transaction_session_timeout=30000'
});

pool.on('error', (error) => {
  console.error('Unexpected PostgreSQL pool error', error);
});

export async function query<Result extends Record<string, unknown> = Record<string, unknown>>(
  db: Queryable,
  text: string,
  values: readonly unknown[] = []
): Promise<Result[]> {
  const result = await db.query<Result>(text, values);
  return result.rows;
}

export async function withTx<Result>(
  db: TransactionPool,
  operation: (client: TransactionClient) => Promise<Result>,
  options: TransactionOptions = {}
): Promise<Result> {
  const maxAttempts = options.maxAttempts ?? 3;
  const sleep = options.sleep ?? wait;
  const random = options.random ?? Math.random;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    const client = await db.connect();
    let started = false;

    try {
      await client.query('BEGIN');
      started = true;
      const result = await operation(client);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      if (started) {
        try {
          await client.query('ROLLBACK');
        } catch {
          // The original transaction error is more useful to the caller.
        }
      }

      if (!isRetryable(error) || attempt === maxAttempts) {
        throw error;
      }

      await sleep(5 + Math.floor(random() * 26));
    } finally {
      client.release();
    }
  }

  throw new Error('Transaction attempts exhausted');
}
