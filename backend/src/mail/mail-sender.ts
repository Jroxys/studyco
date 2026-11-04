import type { FastifyBaseLogger } from 'fastify';

export interface MailSender {
  sendVerification(email: string, code: string): Promise<void>;
  sendPasswordReset(email: string, code: string): Promise<void>;
}

export class ConsoleMailSender implements MailSender {
  public constructor(
    private readonly logger: FastifyBaseLogger,
    private readonly environment: string
  ) {}

  public async sendVerification(email: string, code: string): Promise<void> {
    this.write('email verification', email, code);
  }

  public async sendPasswordReset(email: string, code: string): Promise<void> {
    this.write('password reset', email, code);
  }

  private write(kind: string, email: string, code: string): void {
    if (this.environment !== 'development') {
      this.logger.info({ kind, email }, 'Mail queued');
      return;
    }
    this.logger.info({ kind, email, code }, 'Console mail');
  }
}
