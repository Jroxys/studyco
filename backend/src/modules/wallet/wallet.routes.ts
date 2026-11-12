import type { FastifyInstance } from 'fastify';

import type { Queryable } from '../../db/pool.js';
import { getTransactions, getWallet } from './wallet.service.js';
import { walletQuery, walletResponses } from './wallet.schemas.js';

export function registerWalletRoutes(app: FastifyInstance, db: Queryable): void {
  app.get('/api/v1/wallet', { schema: { response: walletResponses.wallet } }, async (request) =>
    getWallet(db, request)
  );
  app.get(
    '/api/v1/wallet/transactions',
    { schema: { querystring: walletQuery, response: walletResponses.transactions } },
    async (request) => getTransactions(db, request, walletQuery.parse(request.query))
  );
}
