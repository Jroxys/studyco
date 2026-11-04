import { z } from 'zod';

const error = z.object({
  error: z.object({
    code: z.string(),
    message: z.string(),
    details: z.record(z.string(), z.unknown()).optional()
  })
});
const listing = z.object({
  id: z.string().uuid(),
  courseId: z.string().uuid(),
  courseName: z.string(),
  locationId: z.string().uuid(),
  locationName: z.string(),
  topic: z.string(),
  description: z.string().nullable(),
  startAt: z.string(),
  endAt: z.string(),
  tokenPrice: z.number().int(),
  status: z.string(),
  teacher: z.object({
    id: z.string().uuid(),
    firstName: z.string(),
    lastNameInitial: z.string(),
    departmentId: z.string().uuid(),
    ratingAverage: z.number().nullable(),
    ratingCount: z.number().int()
  }),
  myRequest: z
    .object({
      id: z.string().uuid(),
      status: z.string(),
      completionStatus: z.string(),
      conversationId: z.string().uuid().nullable()
    })
    .nullable()
    .optional()
});
const myListing = listing.extend({ pendingRequestCount: z.number().int().nonnegative() });
export const listingParamsSchema = z.object({ id: z.string().uuid() });
export const createListingSchema = z
  .object({
    courseId: z.string().uuid(),
    locationId: z.string().uuid(),
    topic: z.string().trim().min(1).max(160),
    description: z.string().trim().max(5000).optional(),
    startAt: z.string().datetime(),
    endAt: z.string().datetime(),
    tokenPrice: z.number().int().min(0).max(3)
  })
  .superRefine((value, ctx) => {
    const start = new Date(value.startAt);
    const end = new Date(value.endAt);
    if (end <= start) ctx.addIssue({ code: 'custom', message: 'endAt must be after startAt' });
    if (end.getTime() - start.getTime() > 8 * 60 * 60 * 1000)
      ctx.addIssue({ code: 'custom', message: 'Duration must be at most eight hours' });
  });
export const patchListingSchema = z
  .object({
    topic: z.string().trim().min(1).max(160).optional(),
    description: z.string().trim().max(5000).nullable().optional()
  })
  .refine((v) => Object.keys(v).length > 0);
export const listingQuerySchema = z.object({
  departmentId: z.string().uuid().optional(),
  courseId: z.string().uuid().optional(),
  locationId: z.string().uuid().optional(),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
  maxPrice: z.coerce.number().int().min(0).max(3).optional(),
  q: z.string().trim().min(1).max(160).optional(),
  mine: z.enum(['true', 'false']).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
  cursor: z.string().min(1).max(500).optional()
});
export const listingResponses = {
  created: { 201: listing, 400: error, 401: error, 409: error, 422: error, 500: error },
  item: { 200: listing, 400: error, 401: error, 403: error, 404: error, 409: error, 500: error },
  list: {
    200: z.object({ items: z.array(listing), nextCursor: z.string().nullable() }),
    400: error,
    401: error,
    500: error
  },
  myList: { 200: z.array(myListing), 401: error, 500: error }
} as const;
