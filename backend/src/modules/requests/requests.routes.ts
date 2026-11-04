import type { FastifyInstance } from 'fastify';

import type { Queryable } from '../../db/pool.js';
import { createRequest, getMyRequests, getRequest, mutateRequest } from './requests.service.js';
import { emptyBody, idParams, requestQuery, requestResponses } from './requests.schemas.js';

export function registerRequestRoutes(app: FastifyInstance, db: Queryable): void {
  app.post(
    '/api/v1/listings/:id/requests',
    {
      schema: { params: idParams, body: emptyBody, response: requestResponses.created }
    },
    async (request, reply) => {
      const result = await createRequest(db, request, idParams.parse(request.params).id);
      return reply.status(201).send(result);
    }
  );

  app.get(
    '/api/v1/me/requests',
    {
      schema: { querystring: requestQuery, response: requestResponses.list }
    },
    async (request) => getMyRequests(db, request, requestQuery.parse(request.query))
  );

  app.get(
    '/api/v1/requests/:id',
    {
      schema: { params: idParams, response: requestResponses.item }
    },
    async (request) => getRequest(db, request, idParams.parse(request.params).id)
  );

  for (const action of ['accept', 'reject', 'confirm'] as const) {
    app.post(
      `/api/v1/requests/:id/${action}`,
      {
        schema: { params: idParams, body: emptyBody, response: requestResponses.item }
      },
      async (request) => mutateRequest(db, request, idParams.parse(request.params).id, action)
    );
  }
}
