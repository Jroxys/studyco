import type { FastifyInstance } from 'fastify';
import type { Queryable } from '../../db/pool.js';
import {
  getConversations,
  getMessages,
  postMessage,
  readConversation
} from './messages.service.js';
import {
  conversationParams,
  emptyBody,
  messageBody,
  messagesQuery,
  messageResponses
} from './messages.schemas.js';

export function registerMessageRoutes(app: FastifyInstance, db: Queryable): void {
  app.get(
    '/api/v1/conversations',
    { schema: { querystring: messagesQuery, response: messageResponses.conversations } },
    (request) => getConversations(db, request, messagesQuery.parse(request.query))
  );
  app.get(
    '/api/v1/conversations/:id/messages',
    {
      schema: {
        params: conversationParams,
        querystring: messagesQuery,
        response: messageResponses.messages
      }
    },
    (request) =>
      getMessages(
        db,
        request,
        conversationParams.parse(request.params).id,
        messagesQuery.parse(request.query)
      )
  );
  app.post(
    '/api/v1/conversations/:id/messages',
    {
      schema: { params: conversationParams, body: messageBody, response: messageResponses.created }
    },
    async (request, reply) =>
      reply
        .status(201)
        .send(
          await postMessage(
            db,
            request,
            conversationParams.parse(request.params).id,
            messageBody.parse(request.body).body
          )
        )
  );
  app.post(
    '/api/v1/conversations/:id/read',
    { schema: { params: conversationParams, body: emptyBody, response: messageResponses.read } },
    async (request, reply) => {
      await readConversation(db, request, conversationParams.parse(request.params).id);
      return reply.status(204).send();
    }
  );
}
