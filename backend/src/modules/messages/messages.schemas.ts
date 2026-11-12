import { z } from 'zod';

const error = z.object({
  error: z.object({
    code: z.string(),
    message: z.string(),
    details: z.record(z.string(), z.unknown()).optional()
  })
});
const person = z.object({
  id: z.string().uuid(),
  firstName: z.string(),
  lastNameInitial: z.string(),
  departmentId: z.string().uuid()
});
const message = z.object({
  id: z.string().uuid(),
  senderId: z.string().uuid(),
  body: z.string(),
  sentAt: z.string(),
  readAt: z.string().nullable()
});
const conversation = z.object({
  id: z.string().uuid(),
  requestId: z.string().uuid(),
  listing: z.object({ id: z.string().uuid(), topic: z.string() }),
  counterpart: person,
  lastMessage: message.nullable(),
  unreadCount: z.number().int().nonnegative()
});

export const conversationParams = z.object({ id: z.string().uuid() });
export const messagesQuery = z.object({
  limit: z.coerce.number().int().min(1).max(50).default(20),
  cursor: z.string().min(1).max(500).optional()
});
export const messageBody = z.object({ body: z.string().trim().min(1).max(2000) });
export const emptyBody = z.object({}).strict().nullable().optional();
export const messageResponses = {
  conversations: {
    200: z.object({ items: z.array(conversation), nextCursor: z.string().nullable() }),
    401: error,
    500: error
  },
  messages: {
    200: z.object({ items: z.array(message), nextCursor: z.string().nullable() }),
    400: error,
    401: error,
    403: error,
    500: error
  },
  created: { 201: message, 400: error, 401: error, 403: error, 500: error },
  read: { 204: z.null(), 400: error, 401: error, 403: error, 500: error }
} as const;
