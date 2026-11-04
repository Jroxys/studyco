import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',
      include: ['src/modules/**/*.ts'],
      thresholds: { lines: 85 }
    },
    projects: [
      {
        test: {
          name: 'unit',
          include: ['src/**/*.test.ts'],
          environment: 'node'
        }
      },
      {
        test: {
          name: 'integration',
          include: ['tests/**/*.test.ts'],
          exclude: ['tests/concurrency.test.ts'],
          environment: 'node',
          globalSetup: ['./tests/helpers/global-setup.ts']
        }
      },
      {
        test: {
          name: 'concurrency',
          include: ['tests/concurrency.test.ts'],
          environment: 'node',
          globalSetup: ['./tests/helpers/global-setup.ts'],
          fileParallelism: false
        }
      }
    ]
  }
});
