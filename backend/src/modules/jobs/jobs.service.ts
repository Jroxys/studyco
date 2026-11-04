import type { FastifyBaseLogger } from 'fastify';

import type { TransactionClient, TransactionPool } from '../../db/pool.js';

type AdvisoryLockRow = { acquired: boolean };

export type JobDefinition = {
  name: string;
  lockKey: number;
  execute: (client: TransactionClient) => Promise<void>;
};

export interface JobRunner {
  runOnce(): Promise<void>;
  start(intervalSeconds: number): void;
  stop(): Promise<void>;
}

const defaultJobs: readonly JobDefinition[] = [
  {
    name: 'process_expired_confirmations',
    lockKey: 4_210_001,
    execute: async (client) => {
      await client.query('SELECT process_expired_confirmations()');
    }
  },
  {
    name: 'expire_stale_requests',
    lockKey: 4_210_002,
    execute: async (client) => {
      await client.query('SELECT expire_stale_requests()');
    }
  }
];

export function createJobRunner(
  db: TransactionPool,
  logger: Pick<FastifyBaseLogger, 'error' | 'info'>,
  jobs: readonly JobDefinition[] = defaultJobs
): JobRunner {
  let interval: NodeJS.Timeout | undefined;
  const activeRuns = new Set<Promise<void>>();

  async function runJob(job: JobDefinition): Promise<void> {
    let client: TransactionClient | undefined;
    let acquired = false;
    try {
      client = await db.connect();
      const lock = await client.query<AdvisoryLockRow>(
        'SELECT pg_try_advisory_lock($1) AS acquired',
        [job.lockKey]
      );
      acquired = lock.rows[0]?.acquired === true;
      if (!acquired) {
        logger.info({ job: job.name }, 'Background job already running elsewhere');
        return;
      }
      await job.execute(client);
    } catch (error) {
      logger.error({ err: error, job: job.name }, 'Background job failed');
    } finally {
      if (client) {
        if (acquired) {
          try {
            await client.query('SELECT pg_advisory_unlock($1)', [job.lockKey]);
          } catch (error) {
            logger.error({ err: error, job: job.name }, 'Background job lock release failed');
          }
        }
        client.release();
      }
    }
  }

  function runOnce(): Promise<void> {
    const run = Promise.all(jobs.map((job) => runJob(job))).then(() => undefined);
    activeRuns.add(run);
    void run.finally(() => activeRuns.delete(run));
    return run;
  }

  return {
    runOnce,
    start(intervalSeconds) {
      if (interval) {
        return;
      }
      const milliseconds = intervalSeconds * 1_000;
      void runOnce();
      interval = setInterval(() => {
        void runOnce();
      }, milliseconds);
      interval.unref();
    },
    async stop() {
      if (interval) {
        clearInterval(interval);
        interval = undefined;
      }
      await Promise.all([...activeRuns]);
    }
  };
}
