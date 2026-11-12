import type { FastifyBaseLogger } from 'fastify';
import nodemailer, { type Transporter } from 'nodemailer';

export interface MailSender {
  sendVerification(email: string, code: string): Promise<void>;
  sendPasswordReset(email: string, code: string): Promise<void>;
}

/** Development/test sender: codes are written to the log only in development. */
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
      this.logger.warn({ kind, email }, 'SMTP_URL is not configured; mail was not delivered');
      return;
    }
    this.logger.info({ kind, email, code }, 'Console mail');
  }
}

/** Real delivery through any SMTP provider (smtp://user:pass@host:587 or smtps://...). */
export class SmtpMailSender implements MailSender {
  private readonly transport: Transporter;

  public constructor(
    smtpUrl: string,
    private readonly from: string,
    transport?: Transporter
  ) {
    this.transport = transport ?? nodemailer.createTransport(smtpUrl);
  }

  public async sendVerification(email: string, code: string): Promise<void> {
    await this.send(
      email,
      'StudyCo e-posta doğrulama kodu',
      `StudyCo hesabını doğrulamak için kodun: ${code}\n\nBu isteği sen yapmadıysan bu e-postayı yok sayabilirsin.`
    );
  }

  public async sendPasswordReset(email: string, code: string): Promise<void> {
    await this.send(
      email,
      'StudyCo şifre sıfırlama kodu',
      `Şifreni sıfırlamak için kodun: ${code}\n\nBu isteği sen yapmadıysan şifren değişmez; bu e-postayı yok sayabilirsin.`
    );
  }

  private async send(to: string, subject: string, text: string): Promise<void> {
    await this.transport.sendMail({ from: this.from, to, subject, text });
  }
}

export function createMailSender(
  options: { smtpUrl: string | undefined; mailFrom: string; nodeEnv: string },
  logger: FastifyBaseLogger
): MailSender {
  return options.smtpUrl
    ? new SmtpMailSender(options.smtpUrl, options.mailFrom)
    : new ConsoleMailSender(logger, options.nodeEnv);
}
