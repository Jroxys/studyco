import type { FastifyInstance, FastifyRequest } from 'fastify';
import type { Queryable } from '../../db/pool.js';
import { AppError } from '../../errors.js';
import { catalogResponses, coursesQuerySchema, departmentParamsSchema } from './catalog.schemas.js';

async function authenticate(request: FastifyRequest): Promise<void> {
  try {
    await request.jwtVerify();
  } catch {
    throw new AppError(401, 'UNAUTHORIZED', 'Authentication required');
  }
}

export function registerCatalogRoutes(app: FastifyInstance, db: Queryable): void {
  app.get(
    '/api/v1/departments',
    { schema: { response: catalogResponses.departments } },
    async (request, reply) => {
      await authenticate(request);
      reply.header('cache-control', 'private, max-age=60');
      return (
        await db.query<{ id: string; name: string }>(
          'SELECT department_id AS id, name FROM departments WHERE is_active = true ORDER BY name'
        )
      ).rows;
    }
  );
  app.get(
    '/api/v1/departments/:id/courses',
    { schema: { params: departmentParamsSchema, response: catalogResponses.courses } },
    async (request, reply) => {
      await authenticate(request);
      const { id } = departmentParamsSchema.parse(request.params);
      reply.header('cache-control', 'private, max-age=60');
      return (
        await db.query<{ id: string; departmentId: string; name: string }>(
          'SELECT course_id AS id, department_id AS "departmentId", course_name AS name FROM courses WHERE department_id = $1 AND is_active = true ORDER BY course_name',
          [id]
        )
      ).rows;
    }
  );
  app.get(
    '/api/v1/courses',
    { schema: { querystring: coursesQuerySchema, response: catalogResponses.courses } },
    async (request, reply) => {
      await authenticate(request);
      const { departmentId } = coursesQuerySchema.parse(request.query);
      reply.header('cache-control', 'private, max-age=60');
      return (
        await db.query<{ id: string; departmentId: string; name: string }>(
          'SELECT course_id AS id, department_id AS "departmentId", course_name AS name FROM courses WHERE is_active = true AND ($1::uuid IS NULL OR department_id = $1) ORDER BY course_name',
          [departmentId ?? null]
        )
      ).rows;
    }
  );
  app.get(
    '/api/v1/locations',
    { schema: { response: catalogResponses.locations } },
    async (request, reply) => {
      await authenticate(request);
      reply.header('cache-control', 'private, max-age=60');
      return (
        await db.query<{
          id: string;
          name: string;
          description: string | null;
          latitude: number | null;
          longitude: number | null;
        }>(
          'SELECT location_id AS id, name, description, latitude::float, longitude::float FROM locations WHERE is_active = true ORDER BY name'
        )
      ).rows;
    }
  );
}
