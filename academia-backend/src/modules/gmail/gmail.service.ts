import { env } from '../../config/env.js';
import { AppError, ExternalServiceError } from '../../utils/errors.js';

/**
 * Module Gmail (Google API). Architecture préparée — implémentation à finaliser.
 * L'authentification OAuth2 (client id/secret + refresh token) est lue depuis l'env.
 */
export class GmailService {
  protected requireGoogleConfig(): void {
    if (!env.GOOGLE_CLIENT_ID || !env.GOOGLE_CLIENT_SECRET || !env.GOOGLE_REFRESH_TOKEN) {
      throw new AppError(
        'Configuration Google incomplète (GOOGLE_CLIENT_ID / SECRET / REFRESH_TOKEN)',
        500,
        'GOOGLE_NOT_CONFIGURED',
      );
    }
  }

  /** Envoyer un email. */
  async sendEmail(_input: { to: string; subject: string; body: string }): Promise<unknown> {
    this.requireGoogleConfig();
    throw new ExternalServiceError('Gmail', 'sendEmail() non encore implémenté');
  }

  /** Lister les messages récents. */
  async listMessages(_query?: string): Promise<unknown> {
    throw new ExternalServiceError('Gmail', 'listMessages() non encore implémenté');
  }
}

export const gmailService = new GmailService();
