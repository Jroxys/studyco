import { afterEach, describe, expect, it } from 'vitest';

import { buildApp } from './app.js';
import { loadConfig } from './config.js';

describe('buildApp', () => {
  const apps: ReturnType<typeof buildApp>[] = [];

  afterEach(async () => {
    await Promise.all(apps.splice(0).map((app) => app.close()));
  });

  it('serves the liveness endpoint', async () => {
    const app = buildApp();
    apps.push(app);
    const response = await app.inject({ method: 'GET', url: '/api/v1/health' });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ status: 'ok' });
  });

  it('exports an OpenAPI document and only exposes Swagger UI outside production', async () => {
    const app = buildApp();
    apps.push(app);
    const document = await app.inject({ method: 'GET', url: '/openapi.json' });

    expect(document.statusCode).toBe(200);
    expect(document.json()).toMatchObject({
      openapi: expect.any(String),
      info: { title: 'StudyCo API' }
    });
    expect((await app.inject({ method: 'GET', url: '/documentation/' })).statusCode).toBe(200);

    const production = buildApp({
      config: loadConfig({
        NODE_ENV: 'production',
        DATABASE_URL: 'postgresql://test:password@localhost:5432/test',
        CORS_ORIGIN: 'https://studyco.example',
        JWT_SECRET: 'a-production-jwt-secret-that-is-long-enough',
        OTP_HMAC_SECRET: 'a-production-otp-secret-that-is-long-enough',
        SMTP_URL: 'smtp://mail.studyco.example:587'
      })
    });
    apps.push(production);
    expect((await production.inject({ method: 'GET', url: '/documentation/' })).statusCode).toBe(
      404
    );
    expect((await production.inject({ method: 'GET', url: '/openapi.json' })).statusCode).toBe(404);
  });

  it('allows any browser origin only in development', async () => {
    const preflight = {
      method: 'OPTIONS' as const,
      url: '/api/v1/health',
      headers: {
        origin: 'http://192.168.1.20:8080',
        'access-control-request-method': 'GET'
      }
    };
    const development = buildApp({ config: loadConfig({ NODE_ENV: 'development' }) });
    apps.push(development);
    expect((await development.inject(preflight)).headers['access-control-allow-origin']).toBe(
      'http://192.168.1.20:8080'
    );

    const test = buildApp({ config: loadConfig({ NODE_ENV: 'test' }) });
    apps.push(test);
    expect((await test.inject(preflight)).headers['access-control-allow-origin']).toBe(
      'http://localhost:3000'
    );
  });

  it('returns a generic body for unexpected errors', async () => {
    const app = buildApp();
    apps.push(app);
    app.get('/boom', async () => {
      throw new Error('database password is secret');
    });

    const response = await app.inject({ method: 'GET', url: '/boom' });
    expect(response.statusCode).toBe(500);
    expect(response.json()).toEqual({
      error: { code: 'INTERNAL', message: 'An unexpected error occurred' }
    });
  });
});
