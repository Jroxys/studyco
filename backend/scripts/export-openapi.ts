import { writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

import { buildApp } from '../src/app.js';

const app = buildApp();
await app.ready();
const response = await app.inject({ method: 'GET', url: '/openapi.json' });
if (response.statusCode !== 200) {
  throw new Error(`OpenAPI export failed with status ${response.statusCode}`);
}
await writeFile(resolve('openapi.json'), `${JSON.stringify(response.json(), null, 2)}\n`);
await app.close();
