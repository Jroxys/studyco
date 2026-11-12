import type { Queryable } from '../../db/pool.js';

export type WalletRow = { available: number; held: number };
export type TransactionRow = {
  id: string;
  type: string;
  availableDelta: number;
  heldDelta: number;
  createdAt: string;
  requestId: string | null;
  listingId: string | null;
  listingTopic: string | null;
};
export async function findWallet(db: Queryable, userId: string): Promise<WalletRow | undefined> {
  return (
    await db.query<WalletRow>(
      'SELECT available_balance AS available, held_balance AS held FROM wallets WHERE user_id = $1',
      [userId]
    )
  ).rows[0];
}
export async function findTransactions(
  db: Queryable,
  userId: string,
  cursor: { createdAt: string; id: string } | undefined,
  limit: number
): Promise<TransactionRow[]> {
  return (
    await db.query<TransactionRow>(
      'SELECT wt.transaction_id AS id, wt.transaction_type AS type, wt.available_delta AS "availableDelta", wt.held_delta AS "heldDelta", to_char(wt.created_at AT TIME ZONE \'UTC\', \'YYYY-MM-DD"T"HH24:MI:SS.US"Z"\') AS "createdAt", wt.lesson_request_id AS "requestId", lr.listing_id AS "listingId", l.topic AS "listingTopic" FROM wallet_transactions wt JOIN wallets w ON w.wallet_id = wt.wallet_id LEFT JOIN lesson_requests lr ON lr.request_id = wt.lesson_request_id LEFT JOIN listings l ON l.listing_id = lr.listing_id WHERE w.user_id = $1 AND ($2::timestamptz IS NULL OR (wt.created_at, wt.transaction_id) < ($2::timestamptz, $3::uuid)) ORDER BY wt.created_at DESC, wt.transaction_id DESC LIMIT $4',
      [userId, cursor?.createdAt ?? null, cursor?.id ?? null, limit]
    )
  ).rows;
}
