import { buildApp } from './app.js';
import { config } from './config.js';
import { pool } from './db/pool.js';
import { createJobRunner } from './modules/jobs/jobs.service.js';

const app = buildApp({ logger: true });
const jobs = createJobRunner(pool, app.log);

let closing = false;
async function shutdown(signal: string): Promise<void> {
  if (closing) {
    return;
  }
  closing = true;
  app.log.info({ signal }, 'Shutting down');
  await jobs.stop();
  await app.close();
  await pool.end();
}

process.once('SIGINT', () => {
  void shutdown('SIGINT').catch((error: unknown) => {
    app.log.error({ err: error }, 'Shutdown failed');
    process.exitCode = 1;
  });
});
process.once('SIGTERM', () => {
  void shutdown('SIGTERM').catch((error: unknown) => {
    app.log.error({ err: error }, 'Shutdown failed');
    process.exitCode = 1;
  });
});

try {
  await app.listen({ host: config.host, port: config.port });
  if (config.jobsEnabled) {
    jobs.start(config.jobIntervalSeconds);
  }
} catch (error) {
  app.log.error({ err: error }, 'Server failed to start');
  await pool.end();
  process.exitCode = 1;
}
