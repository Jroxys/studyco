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
const listing = z.object({
  id: z.string().uuid(),
  topic: z.string(),
  startAt: z.string(),
  endAt: z.string(),
  tokenPrice: z.number().int()
});
export const requestView = z.object({
  id: z.string().uuid(),
  status: z.string(),
  completionStatus: z.string(),
  agreedTokenAmount: z.number().int().nullable(),
  respondedAt: z.string().nullable(),
  autoCancelReason: z.string().nullable(),
  studentCompletedAt: z.string().nullable(),
  teacherCompletedAt: z.string().nullable(),
  confirmationDeadlineAt: z.string().nullable(),
  settledAt: z.string().nullable(),
  settlementBasis: z.string().nullable(),
  createdAt: z.string(),
  listing,
  counterpart: person,
  conversationId: z.string().uuid().nullable()
});
export const idParams = z.object({ id: z.string().uuid() });
export const emptyBody = z.object({}).strict().nullable().optional();
export const requestQuery = z.object({
  role: z.enum(['student', 'teacher']).default('student'),
  status: z.enum(['PENDING', 'ACCEPTED', 'REJECTED', 'AUTO_CANCELLED']).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
  cursor: z.string().min(1).max(500).optional()
});
export type RequestQuery = z.infer<typeof requestQuery>;
export const requestResponses = {
  created: {
    201: requestView,
    400: error,
    401: error,
    402: error,
    409: error,
    422: error,
    500: error
  },
  item: {
    200: requestView,
    400: error,
    401: error,
    402: error,
    403: error,
    404: error,
    409: error,
    422: error,
    500: error
  },
  list: {
    200: z.object({ items: z.array(requestView), nextCursor: z.string().nullable() }),
    400: error,
    401: error,
    500: error
  }
} as const;
