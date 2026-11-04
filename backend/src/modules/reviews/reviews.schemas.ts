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
const review = z.object({
  id: z.string().uuid(),
  requestId: z.string().uuid(),
  reviewer: person,
  rating: z.number().int().min(1).max(5),
  comment: z.string().nullable(),
  createdAt: z.string()
});

export const requestParams = z.object({ id: z.string().uuid() });
export const userParams = z.object({ id: z.string().uuid() });
export const reviewBody = z.object({
  rating: z.number().int().min(1).max(5),
  comment: z.string().trim().min(1).max(1000).nullable().optional()
});
export const reviewsQuery = z.object({
  limit: z.coerce.number().int().min(1).max(50).default(20),
  cursor: z.string().min(1).max(500).optional()
});
export const reviewResponses = {
  created: { 201: review, 400: error, 401: error, 403: error, 404: error, 409: error, 500: error },
  list: {
    200: z.object({ items: z.array(review), nextCursor: z.string().nullable() }),
    400: error,
    401: error,
    403: error,
    404: error,
    500: error
  }
} as const;
