import { describe, expect, it } from 'vitest';

import { withTx, type TransactionClient, type TransactionPool } from './pool.js';

function fakePool(events: string[], failures: string[] = []): TransactionPool {
  return {
    async connect(): Promise<TransactionClient> {
      return {
        async query<Result extends Record<string, unknown> = Record<string, unknown>>(
          text: string
        ): Promise<{ rows: Result[] }> {
          events.push(text);
          const failure = failures.shift();
          if (failure !== undefined) {
            throw { code: failure };
          }
          return { rows: [] };
        },
        release(): void {
          events.push('RELEASE');
        }
      };
    }
  };
}

describe('withTx', () => {
  it('commits and releases a successful transaction', async () => {
    const events: string[] = [];
    await expect(withTx(fakePool(events), async () => 'done')).resolves.toBe('done');
    expect(events).toEqual(['BEGIN', 'COMMIT', 'RELEASE']);
  });

  it('rolls back and retries serialization failures up to three attempts', async () => {
    const events: string[] = [];
    let calls = 0;
    const result = await withTx(
      fakePool(events),
      async () => {
        calls += 1;
        if (calls < 3) {
          throw { code: '40001' };
        }
        return 'done';
      },
      { sleep: async () => undefined, random: () => 0 }
    );

    expect(result).toBe('done');
    expect(events).toEqual([
      'BEGIN',
      'ROLLBACK',
      'RELEASE',
      'BEGIN',
      'ROLLBACK',
      'RELEASE',
      'BEGIN',
      'COMMIT',
      'RELEASE'
    ]);
  });

  it('does not retry non-retryable failures', async () => {
    const events: string[] = [];
    await expect(
      withTx(fakePool(events), async () => {
        throw new Error('nope');
      })
    ).rejects.toThrow('nope');
    expect(events).toEqual(['BEGIN', 'ROLLBACK', 'RELEASE']);
  });

  it('throws after the third retryable failure', async () => {
    const events: string[] = [];
    await expect(
      withTx(
        fakePool(events),
        async () => {
          throw { code: '40P01' };
        },
        { sleep: async () => undefined }
      )
    ).rejects.toMatchObject({ code: '40P01' });
    expect(events.filter((event) => event === 'BEGIN')).toHaveLength(3);
  });
});
