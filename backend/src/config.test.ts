import { describe, expect, it } from 'vitest';

import { loadConfig } from './config.js';

describe('loadConfig', () => {
  it('parses configured values', () => {
    const config = loadConfig({
      NODE_ENV: 'test',
      PORT: '4567',
      REQUIRE_VERIFIED_EMAIL: 'true',
      JOBS_ENABLED: 'false'
    });

    expect(config).toMatchObject({
      nodeEnv: 'test',
      port: 4567,
      requireVerifiedEmail: true,
      jobsEnabled: false
    });
  });

  it('rejects malformed environment values', () => {
    expect(() => loadConfig({ PORT: 'invalid' })).toThrow();
  });

  it('requires a non-development JWT secret in production', () => {
    expect(() => loadConfig({ NODE_ENV: 'production' })).toThrow(
      'JWT_SECRET must be set in production'
    );
  });
});
