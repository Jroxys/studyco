import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import jwt from '@fastify/jwt';
import rateLimit from '@fastify/rate-limit';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import Fastify, {
  type FastifyBaseLogger,
  type FastifyInstance,
  type FastifyRequest
} from 'fastify';
import {
  serializerCompiler,
  validatorCompiler,
  jsonSchemaTransform,
  type ZodTypeProvider
} from 'fastify-type-provider-zod';
import { z } from 'zod';

import { config, type Config } from './config.js';
import { mapDatabaseError } from './db/errors.js';
import { pool, type Queryable, type TransactionPool } from './db/pool.js';
import { AppError, internalError } from './errors.js';
import { registerAuthRoutes } from './modules/auth/auth.routes.js';
import { registerCatalogRoutes } from './modules/catalog/catalog.routes.js';
import { registerListingRoutes } from './modules/listings/listings.routes.js';
import { registerMessageRoutes } from './modules/messages/messages.routes.js';
import { registerRequestRoutes } from './modules/requests/requests.routes.js';
import { registerReviewRoutes } from './modules/reviews/reviews.routes.js';
import { registerWalletRoutes } from './modules/wallet/wallet.routes.js';
import { createMailSender, type MailSender } from './mail/mail-sender.js';

type AuthenticatedRequest = FastifyRequest & { authUserId?: string; authEmailVerified?: boolean };

export interface AppDependencies {
  config?: Config;
  logger?: FastifyBaseLogger | boolean;
  db?: TransactionPool & Queryable;
  mailSender?: MailSender;
}

const healthResponseSchema = z.object({ status: z.literal('ok') });
const openApiDocumentSchema = z
  .object({
    openapi: z.string(),
    info: z.object({ title: z.string(), version: z.string() }),
    paths: z.record(z.string(), z.unknown())
  })
  .passthrough();
const errorResponseSchema = z.object({
  error: z.object({
    code: z.string(),
    message: z.string(),
    details: z.record(z.string(), z.unknown()).optional()
  })
});

function isPublicRoute(method: string, url: string): boolean {
  if (!url.startsWith('/api/v1/')) return true;
  if (url === '/openapi.json' || url.startsWith('/documentation')) return true;
  if (url === '/api/v1/health' || url === '/api/v1/health/ready') return true;
  if (method === 'GET' && /^\/api\/v1\/users\/[^/]+$/.test(url)) return true;
  // Registration needs real department IDs before an account exists.
  if (method === 'GET' && url === '/api/v1/departments') return true;
  return new Set([
    'POST /api/v1/auth/register',
    'POST /api/v1/auth/login',
    'POST /api/v1/auth/refresh',
    'POST /api/v1/auth/logout',
    'POST /api/v1/auth/forgot-password',
    'POST /api/v1/auth/reset-password'
  ]).has(`${method} ${url}`);
}

export function buildApp(dependencies: AppDependencies = {}): FastifyInstance {
  const appConfig = dependencies.config ?? config;
  const app = Fastify({
    logger: dependencies.logger ?? false,
    trustProxy: appConfig.trustProxy
  }).withTypeProvider<ZodTypeProvider>();

  app.setValidatorCompiler(validatorCompiler);
  app.setSerializerCompiler(serializerCompiler);

  app.register(helmet);
  // Development accepts any browser origin so the Flutter web build can be served
  // from another port or from this machine's LAN address. Other environments
  // keep the single configured origin.
  app.register(cors, {
    origin: appConfig.nodeEnv === 'development' ? true : appConfig.corsOrigin
  });
  app.register(rateLimit, {
    max: appConfig.rateLimitMax,
    timeWindow: appConfig.rateLimitWindow
  });
  app.register(jwt, {
    secret: appConfig.jwtSecret,
    sign: { expiresIn: appConfig.jwtExpiresIn, algorithm: 'HS256' },
    verify: { algorithms: ['HS256'] }
  });
  app.addHook('onRequest', async (request) => {
    if (!isPublicRoute(request.method, request.url.split('?')[0]!)) {
      await request.jwtVerify();
      const userId = (request.user as { sub?: string }).sub;
      if (!userId) throw new AppError(401, 'UNAUTHORIZED', 'Authentication required');
      const db: Queryable = dependencies.db ?? pool;
      const user = await db.query<{
        anonymized_at: string | null;
        email_verified_at: string | null;
      }>('SELECT anonymized_at::text, email_verified_at::text FROM users WHERE user_id = $1', [
        userId
      ]);
      if (!user.rows[0] || user.rows[0].anonymized_at)
        throw new AppError(401, 'UNAUTHORIZED', 'Authentication required');
      if (
        appConfig.requireVerifiedEmail &&
        request.method === 'POST' &&
        (/^\/api\/v1\/listings$/.test(request.url.split('?')[0]!) ||
          /^\/api\/v1\/listings\/[^/]+\/requests$/.test(request.url.split('?')[0]!)) &&
        !user.rows[0].email_verified_at
      ) {
        throw new AppError(403, 'EMAIL_NOT_VERIFIED', 'Email verification is required');
      }
      const authenticated = request as AuthenticatedRequest;
      authenticated.authUserId = userId;
      authenticated.authEmailVerified = user.rows[0].email_verified_at !== null;
    }
  });
  app.register(swagger, {
    openapi: {
      info: { title: 'StudyCo API', version: '1.0.0' },
      servers: [{ url: '/' }]
    },
    transform: jsonSchemaTransform
  });
  if (appConfig.nodeEnv !== 'production') {
    app.register(swaggerUi, { routePrefix: '/documentation' });
  }

  app.setErrorHandler((error, _request, reply) => {
    const appError =
      error instanceof AppError
        ? error
        : error instanceof z.ZodError ||
            (typeof error === 'object' && error !== null && 'validation' in error)
          ? new AppError(400, 'VALIDATION_ERROR', 'Request validation failed')
          : typeof error === 'object' &&
              error !== null &&
              'statusCode' in error &&
              error.statusCode === 429
            ? new AppError(429, 'RATE_LIMITED', 'Too many requests')
            : typeof error === 'object' &&
                error !== null &&
                'statusCode' in error &&
                error.statusCode === 401
              ? new AppError(401, 'UNAUTHORIZED', 'Authentication required')
              : typeof error === 'object' &&
                  error !== null &&
                  'statusCode' in error &&
                  typeof error.statusCode === 'number' &&
                  error.statusCode >= 400 &&
                  error.statusCode < 500
                ? new AppError(
                    error.statusCode,
                    'BAD_REQUEST',
                    error instanceof Error ? error.message : 'Bad request'
                  )
                : mapDatabaseError(error);
    const safeError = appError.code === 'INTERNAL' ? internalError() : appError;

    if (safeError.statusCode >= 500) {
      reply.log.error({ err: error }, 'Request failed');
    }

    return reply.status(safeError.statusCode).send({
      error: {
        code: safeError.code,
        message: safeError.message,
        ...(safeError.details === undefined ? {} : { details: safeError.details })
      }
    });
  });

  app.get(
    '/api/v1/health',
    {
      schema: {
        response: {
          200: healthResponseSchema,
          400: errorResponseSchema,
          500: errorResponseSchema
        }
      }
    },
    async () => ({ status: 'ok' as const })
  );

  app.get(
    '/api/v1/health/ready',
    {
      schema: {
        response: {
          200: healthResponseSchema,
          503: errorResponseSchema,
          500: errorResponseSchema
        }
      }
    },
    async (_request, reply) => {
      const db: Queryable = dependencies.db ?? pool;
      const result = await db.query<{ count: number }>(
        'SELECT count(*)::int AS count FROM v_integrity_violations'
      );
      const violations = result.rows[0]?.count ?? 0;
      if (violations > 0) {
        reply.log.error({ integrityViolations: violations }, 'Database integrity check failed');
        throw new AppError(503, 'NOT_READY', 'Service is not ready');
      }
      return { status: 'ok' as const };
    }
  );

  if (appConfig.nodeEnv !== 'production') {
    app.get(
      '/openapi.json',
      { schema: { response: { 200: openApiDocumentSchema } } },
      async () => app.swagger() as unknown as z.infer<typeof openApiDocumentSchema>
    );
  }

  app.after(() => {
    registerAuthRoutes(app, {
      config: appConfig,
      db: dependencies.db ?? pool,
      mailSender: dependencies.mailSender ?? createMailSender(appConfig, app.log)
    });
    const db = dependencies.db ?? pool;
    registerCatalogRoutes(app, db);
    registerListingRoutes(app, db);
    registerRequestRoutes(app, db);
    registerWalletRoutes(app, db);
    registerMessageRoutes(app, db);
    registerReviewRoutes(app, db);
  });

  return app;
}
