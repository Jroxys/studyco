import { readFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';

const sourceRoot = fileURLToPath(new URL('.', import.meta.url));
const forbiddenText = ['p', '_now'].join('');

async function sourceFiles(directory: string): Promise<string[]> {
  const entries = await readdir(directory, { withFileTypes: true });
  const nested = await Promise.all(
    entries.map(async (entry) => {
      const path = join(directory, entry.name);
      return entry.isDirectory()
        ? sourceFiles(path)
        : entry.isFile() && path.endsWith('.ts')
          ? [path]
          : [];
    })
  );
  return nested.flat();
}

describe('production database calls', () => {
  it('never passes the database time-travel parameter', async () => {
    const files = await sourceFiles(sourceRoot);
    const offenders = (
      await Promise.all(
        files.map(async (file) => {
          const contents = await readFile(file, 'utf8');
          return contents.includes(forbiddenText) ? file : undefined;
        })
      )
    ).filter((file): file is string => file !== undefined);

    expect(offenders).toEqual([]);
  });
});
