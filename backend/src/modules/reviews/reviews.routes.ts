import type { FastifyInstance } from 'fastify';
import type { Queryable } from '../../db/pool.js';
import { createReview, getRequestReviews, getUserReviews } from './reviews.service.js';
import {
  requestParams,
  reviewBody,
  reviewResponses,
  reviewsQuery,
  userParams
} from './reviews.schemas.js';

export function registerReviewRoutes(app: FastifyInstance, db: Queryable): void {
  app.post(
    '/api/v1/requests/:id/reviews',
    { schema: { params: requestParams, body: reviewBody, response: reviewResponses.created } },
    async (request, reply) =>
      reply
        .status(201)
        .send(
          await createReview(
            db,
            request,
            requestParams.parse(request.params).id,
            reviewBody.parse(request.body)
          )
        )
  );
  app.get(
    '/api/v1/users/:id/reviews',
    { schema: { params: userParams, querystring: reviewsQuery, response: reviewResponses.list } },
    (request) =>
      getUserReviews(
        db,
        request,
        userParams.parse(request.params).id,
        reviewsQuery.parse(request.query)
      )
  );
  app.get(
    '/api/v1/requests/:id/reviews',
    { schema: { params: requestParams, response: reviewResponses.list } },
    (request) => getRequestReviews(db, request, requestParams.parse(request.params).id)
  );
}
