import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { Client } from 'pg';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

type GlobalSetupContext = {
  provide: (key: string, value: unknown) => void;
};

const backendRoot = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const databaseRoot = join(backendRoot, '..', 'database');
const migrationsDirectory = join(databaseRoot, 'migrations', 'up');
const departmentsSeed = join(databaseRoot, 'seeds', '001_departments.sql');

function readAdminUrlFromEnvFile(contents: string): string | undefined {
  const match = contents.match(/^\s*TEST_PG_ADMIN_URL\s*=\s*(.+?)\s*$/m);
  return match?.[1]?.replace(/^['"]|['"]$/g, '');
}

async function getAdminUrl(): Promise<string> {
  if (process.env.TEST_PG_ADMIN_URL) {
    return process.env.TEST_PG_ADMIN_URL;
  }

  try {
    const contents = await readFile(join(backendRoot, '.env.test'), 'utf8');
    const adminUrl = readAdminUrlFromEnvFile(contents);
    if (adminUrl) {
      return adminUrl;
    }
  } catch (error) {
    if (
      typeof error !== 'object' ||
      error === null ||
      !('code' in error) ||
      error.code !== 'ENOENT'
    ) {
      throw error;
    }
  }

  throw new Error(
    'TEST_PG_ADMIN_URL is required for integration tests; set it in the environment or .env.test.'
  );
}

function createTestDatabaseName(): string {
  return `studyco_test_${randomUUID().replaceAll('-', '')}`;
}

function databaseUrl(adminUrl: string, databaseName: string): string {
  const url = new URL(adminUrl);
  url.pathname = `/${databaseName}`;
  return url.toString();
}

function assertTestDatabaseName(databaseName: string): void {
  if (!/^studyco_test_[a-f0-9]{32}$/.test(databaseName)) {
    throw new Error('Refusing to operate on a database outside the test naming convention.');
  }
}

async function removeTestDatabase(adminUrl: string, databaseName: string): Promise<void> {
  assertTestDatabaseName(databaseName);
  const client = new Client({ connectionString: adminUrl });
  await client.connect();
  try {
    await client.query(
      'SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = $1 AND pid <> pg_backend_pid()',
      [databaseName]
    );
    await client.query(`DROP DATABASE IF EXISTS ${databaseName}`);
  } finally {
    await client.end();
  }
}

async function applySchema(testDatabaseUrl: string): Promise<void> {
  const client = new Client({ connectionString: testDatabaseUrl });
  await client.connect();
  try {
    const migrationFiles = (await (await import('node:fs/promises')).readdir(migrationsDirectory))
      .filter((file) => /^\d+_.+\.sql$/.test(file))
      .sort((left, right) => left.localeCompare(right));

    for (const file of migrationFiles) {
      await client.query(await readFile(join(migrationsDirectory, file), 'utf8'));
    }
    await client.query(await readFile(departmentsSeed, 'utf8'));
  } finally {
    await client.end();
  }
}

export default async function setup({ provide }: GlobalSetupContext): Promise<() => Promise<void>> {
  const adminUrl = await getAdminUrl();
  const name = createTestDatabaseName();
  const testDatabaseUrl = databaseUrl(adminUrl, name);
  const admin = new Client({ connectionString: adminUrl });

  try {
    await admin.connect();
    await admin.query(`CREATE DATABASE ${name} ENCODING 'UTF8'`);
    await applySchema(testDatabaseUrl);
  } catch (error) {
    await admin.end().catch(() => undefined);
    await removeTestDatabase(adminUrl, name).catch(() => undefined);
    throw error;
  }
  await admin.end();

  provide('testDatabaseUrl', testDatabaseUrl);

  return async () => {
    await removeTestDatabase(adminUrl, name);
  };
}

export { createTestDatabaseName, databaseUrl, readAdminUrlFromEnvFile };
