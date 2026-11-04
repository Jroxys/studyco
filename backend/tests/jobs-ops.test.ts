import { afterAll, describe, expect, inject, it } from 'vitest';
import { Pool } from 'pg';

import { buildApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import type { Queryable, TransactionPool } from '../src/db/pool.js';
import { createJobRunner, type JobDefinition } from '../src/modules/jobs/jobs.service.js';
import { createListing, createUser } from './helpers/factories.js';
import { acceptLessonRequestAt, confirmLessonAt } from './helpers/time-travel.js';

const pool = new Pool({ connectionString: inject('testDatabaseUrl') });
const logger = { error: () => undefined, info: () => undefined };

afterAll(async () => {
  await pool.end();
});

describe('jobs and readiness', () => {
  it('settles an expired confirmation through the production job function', async () => {
    const teacherId = await createUser(pool);
    const studentId = await createUser(pool);
    const start = new Date(Date.now() + 2 * 60 * 60 * 1_000);
    const listingId = await createListing(pool, {
      teacherId,
      startAt: start,
      endAt: new Date(start.getTime() + 60 * 60 * 1_000)
    });
    const requestId = (
      await pool.query<{ id: string }>(
        'INSERT INTO lesson_requests (listing_id, student_id) VALUES ($1, $2) RETURNING request_id AS id',
        [listingId, studentId]
      )
    ).rows[0]!.id;
    await acceptLessonRequestAt(pool, requestId, teacherId, new Date());
    await confirmLessonAt(
      pool,
      requestId,
      studentId,
      new Date(start.getTime() + 2 * 60 * 60 * 1_000)
    );
    const fixtureStart = new Date(Date.now() - 27 * 60 * 60 * 1_000);
    const fixtureEnd = new Date(fixtureStart.getTime() + 60 * 60 * 1_000);
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query('SET LOCAL session_replication_role = replica');
      await client.query(
        "UPDATE lesson_requests SET time_range = tstzrange($2, $3, '[)'), confirmation_deadline_at = $4, student_completed_at = $3 WHERE request_id = $1",
        [
          requestId,
          fixtureStart.toISOString(),
          fixtureEnd.toISOString(),
          new Date(fixtureEnd.getTime() + 24 * 60 * 60 * 1_000).toISOString()
        ]
      );
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }

    const runner = createJobRunner(pool, logger);
    await runner.runOnce();

    const request = await pool.query<{ completion: string; basis: string | null }>(
      'SELECT completion_status AS completion, settlement_basis AS basis FROM lesson_requests WHERE request_id = $1',
      [requestId]
    );
    expect(request.rows[0]).toEqual({ completion: 'COMPLETED', basis: 'STUDENT_ONLY_AT_DEADLINE' });
  });

  it('uses advisory locks so concurrent runs do not overlap', async () => {
    let executions = 0;
    let entered!: () => void;
    let release!: () => void;
    const enteredPromise = new Promise<void>((resolve) => {
      entered = resolve;
    });
    const releasePromise = new Promise<void>((resolve) => {
      release = resolve;
    });
    const jobs: readonly JobDefinition[] = [
      {
        name: 'test-lock',
        lockKey: 4_210_099,
        execute: async () => {
          executions += 1;
          entered();
          await releasePromise;
        }
      }
    ];
    const runner = createJobRunner(pool, logger, jobs);
    const first = runner.runOnce();
    await enteredPromise;
    await runner.runOnce();
    release();
    await first;

    expect(executions).toBe(1);
  });

  it('returns 503 when the integrity check reports a violation', async () => {
    const violatingDb: TransactionPool & Queryable = {
      async connect() {
        throw new Error('connect should not be called');
      },
      async query<Result extends Record<string, unknown>>() {
        return { rows: [{ count: 1 } as unknown as Result] };
      }
    };
    const config = loadConfig({
      NODE_ENV: 'test',
      DATABASE_URL: inject('testDatabaseUrl'),
      JWT_SECRET: 'a-very-long-test-jwt-secret-that-is-not-production',
      OTP_HMAC_SECRET: 'a-very-long-test-otp-hmac-secret-that-is-not-production'
    });
    const app = buildApp({ config, db: violatingDb });
    await app.ready();
    try {
      const response = await app.inject({ method: 'GET', url: '/api/v1/health/ready' });
      expect(response.statusCode).toBe(503);
      expect(response.json()).toEqual({
        error: { code: 'NOT_READY', message: 'Service is not ready' }
      });
    } finally {
      await app.close();
    }
  });
});
