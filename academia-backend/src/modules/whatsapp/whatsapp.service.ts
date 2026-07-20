import { env } from '../../config/env.js';
import { AppError, ExternalServiceError } from '../../utils/errors.js';

/**
 * Module WhatsApp (Cloud API). Architecture préparée — implémentation à finaliser.
 */
export class WhatsAppService {
  private config(): { phoneNumberId: string; token: string; baseUrl: string } {
    const phoneNumberId = env.WHATSAPP_PHONE_NUMBER_ID;
    const token = env.WHATSAPP_ACCESS_TOKEN;
    if (!phoneNumberId || !token) {
      throw new AppError(
        'Configuration WhatsApp incomplète (WHATSAPP_PHONE_NUMBER_ID / WHATSAPP_ACCESS_TOKEN)',
        500,
        'WHATSAPP_NOT_CONFIGURED',
      );
    }
    return { phoneNumberId, token, baseUrl: `https://graph.facebook.com/${env.FACEBOOK_GRAPH_VERSION}` };
  }

  /** Envoyer un message texte à un numéro (format international). */
  async sendText(_to: string, _message: string): Promise<unknown> {
    this.config();
    throw new ExternalServiceError('WhatsApp', 'sendText() non encore implémenté');
  }

  /** Envoyer un message via template approuvé. */
  async sendTemplate(_to: string, _template: string, _params: string[]): Promise<unknown> {
    throw new ExternalServiceError('WhatsApp', 'sendTemplate() non encore implémenté');
  }
}

export const whatsappService = new WhatsAppService();
