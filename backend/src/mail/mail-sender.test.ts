import type { Transporter } from 'nodemailer';
import { describe, expect, it, vi } from 'vitest';

import { SmtpMailSender } from './mail-sender.js';

describe('SmtpMailSender', () => {
  it('sends the code to the recipient from the configured address', async () => {
    const sendMail = vi.fn().mockResolvedValue({});
    const sender = new SmtpMailSender('smtp://localhost:2525', 'StudyCo <a@b.c>', {
      sendMail
    } as unknown as Transporter);

    await sender.sendPasswordReset('student@example.com', '123456');

    expect(sendMail).toHaveBeenCalledWith(
      expect.objectContaining({
        from: 'StudyCo <a@b.c>',
        to: 'student@example.com',
        text: expect.stringContaining('123456')
      })
    );
  });

  it('propagates delivery failures', async () => {
    const sender = new SmtpMailSender('smtp://localhost:2525', 'x@y.z', {
      sendMail: vi.fn().mockRejectedValue(new Error('down'))
    } as unknown as Transporter);
    await expect(sender.sendVerification('a@b.c', '000000')).rejects.toThrow('down');
  });
});
