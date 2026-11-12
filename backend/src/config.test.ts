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

  it('requires SMTP delivery in production', () => {
    expect(() =>
      loadConfig({
        NODE_ENV: 'production',
        DATABASE_URL: 'postgresql://app:secret@db.example.com:5432/studyco',
        CORS_ORIGIN: 'https://studyco.example.com',
        JWT_SECRET: 'a'.repeat(40),
        OTP_HMAC_SECRET: 'b'.repeat(40)
      })
    ).toThrow('SMTP_URL must be set in production');
  });

  it('treats an empty SMTP_URL as not configured', () => {
    expect(loadConfig({ NODE_ENV: 'test', SMTP_URL: '' }).smtpUrl).toBeUndefined();
  });
});
