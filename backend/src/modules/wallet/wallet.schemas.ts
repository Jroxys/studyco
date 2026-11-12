import { z } from 'zod';

const error = z.object({
  error: z.object({
    code: z.string(),
    message: z.string(),
    details: z.record(z.string(), z.unknown()).optional()
  })
});
const transaction = z.object({
  id: z.string().uuid(),
  type: z.string(),
  availableDelta: z.number().int(),
  heldDelta: z.number().int(),
  createdAt: z.string(),
  requestId: z.string().uuid().nullable(),
  listingId: z.string().uuid().nullable(),
  listingTopic: z.string().nullable()
});
export const walletQuery = z.object({
  limit: z.coerce.number().int().min(1).max(50).default(20),
  cursor: z.string().min(1).max(500).optional()
});
export const walletResponses = {
  wallet: {
    200: z.object({ available: z.number().int(), held: z.number().int() }),
    401: error,
    500: error
  },
  transactions: {
    200: z.object({ items: z.array(transaction), nextCursor: z.string().nullable() }),
    400: error,
    401: error,
    500: error
  }
} as const;
