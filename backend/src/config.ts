import { z } from 'zod';

const booleanFromEnvironment = z.enum(['true', 'false']).transform((value) => value === 'true');
const developmentDatabaseUrl = 'postgresql://studyco_app:studyco_dev@127.0.0.1:5432/studyco';
const developmentCorsOrigin = 'http://localhost:3000';

const configSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  HOST: z.string().min(1).default('127.0.0.1'),
  DATABASE_URL: z
    .string()
    .url()
    .default('postgresql://studyco_app:studyco_dev@127.0.0.1:5432/studyco'),
  JWT_SECRET: z.string().min(32).default('development-only-secret-change-me-123'),
  JWT_EXPIRES_IN: z.string().min(1).default('15m'),
  CORS_ORIGIN: z.string().min(1).default('http://localhost:3000'),
  TRUST_PROXY: booleanFromEnvironment.default(false),
  RATE_LIMIT_MAX: z.coerce.number().int().positive().default(100),
  RATE_LIMIT_WINDOW: z.string().min(1).default('1 minute'),
  MINIMUM_AGE: z.coerce.number().int().min(1).max(120).default(16),
  OTP_TTL_MINUTES: z.coerce.number().int().positive().default(15),
  OTP_MAX_ATTEMPTS: z.coerce.number().int().positive().default(5),
  OTP_HMAC_SECRET: z.string().min(32).default('development-only-otp-hmac-secret-change-me'),
  REQUIRE_VERIFIED_EMAIL: booleanFromEnvironment.default(false),
  JOBS_ENABLED: booleanFromEnvironment.default(true),
  JOB_INTERVAL_SECONDS: z.coerce.number().int().positive().default(300),
  PG_POOL_MAX: z.coerce.number().int().positive().default(10),
  PG_CONNECTION_TIMEOUT_MILLIS: z.coerce.number().int().positive().default(5_000)
});

export type Config = {
  nodeEnv: 'development' | 'test' | 'production';
  port: number;
  host: string;
  databaseUrl: string;
  jwtSecret: string;
  jwtExpiresIn: string;
  corsOrigin: string;
  trustProxy: boolean;
  rateLimitMax: number;
  rateLimitWindow: string;
  minimumAge: number;
  otpTtlMinutes: number;
  otpMaxAttempts: number;
  otpHmacSecret: string;
  requireVerifiedEmail: boolean;
  jobsEnabled: boolean;
  jobIntervalSeconds: number;
  pgPoolMax: number;
  pgConnectionTimeoutMillis: number;
};

export function loadConfig(environment: NodeJS.ProcessEnv = process.env): Config {
  const parsed = configSchema.parse(environment);

  if (parsed.NODE_ENV === 'production') {
    for (const name of ['DATABASE_URL', 'CORS_ORIGIN', 'JWT_SECRET', 'OTP_HMAC_SECRET'] as const) {
      if (parsed[name].startsWith('change-this') || parsed[name].includes('development-only')) {
        throw new Error(`${name} must be set in production`);
      }
    }
    if (parsed.DATABASE_URL === developmentDatabaseUrl || parsed.CORS_ORIGIN === developmentCorsOrigin) {
      throw new Error('DATABASE_URL and CORS_ORIGIN must be explicitly configured in production');
    }
    if (parsed.JWT_SECRET === parsed.OTP_HMAC_SECRET) {
      throw new Error('JWT_SECRET and OTP_HMAC_SECRET must differ in production');
    }
  }

  return {
    nodeEnv: parsed.NODE_ENV,
    port: parsed.PORT,
    host: parsed.HOST,
    databaseUrl: parsed.DATABASE_URL,
    jwtSecret: parsed.JWT_SECRET,
    jwtExpiresIn: parsed.JWT_EXPIRES_IN,
    corsOrigin: parsed.CORS_ORIGIN,
    trustProxy: parsed.TRUST_PROXY,
    rateLimitMax: parsed.RATE_LIMIT_MAX,
    rateLimitWindow: parsed.RATE_LIMIT_WINDOW,
    minimumAge: parsed.MINIMUM_AGE,
    otpTtlMinutes: parsed.OTP_TTL_MINUTES,
    otpMaxAttempts: parsed.OTP_MAX_ATTEMPTS,
    otpHmacSecret: parsed.OTP_HMAC_SECRET,
    requireVerifiedEmail: parsed.REQUIRE_VERIFIED_EMAIL,
    jobsEnabled: parsed.JOBS_ENABLED,
    jobIntervalSeconds: parsed.JOB_INTERVAL_SECONDS,
    pgPoolMax: parsed.PG_POOL_MAX,
    pgConnectionTimeoutMillis: parsed.PG_CONNECTION_TIMEOUT_MILLIS
  };
}

export const config = loadConfig();
