import type { FastifyInstance, InjectOptions } from 'fastify';
import type { Response as LightMyRequestResponse } from 'light-my-request';

export function authedRequest(
  app: FastifyInstance,
  accessToken: string,
  options: InjectOptions
): Promise<LightMyRequestResponse> {
  return app.inject({
    ...options,
    headers: {
      ...options.headers,
      authorization: `Bearer ${accessToken}`
    }
  });
}
