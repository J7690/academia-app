import axios, { type AxiosInstance } from 'axios';
import { env } from '../../config/env.js';
import { AppError, ExternalServiceError } from '../../utils/errors.js';

/**
 * Module Instagram (Graph API). Squelette prêt à compléter : publication,
 * commentaires, messages, insights. Réutilise le même patron que Facebook
 * (config paresseuse + client Axios).
 */
export class InstagramService {
  private clientCache: AxiosInstance | null = null;

  private config(): { igId: string; token: string; baseUrl: string } {
    const igId = env.INSTAGRAM_BUSINESS_ACCOUNT_ID;
    const token = env.INSTAGRAM_ACCESS_TOKEN;
    if (!igId || !token) {
      throw new AppError(
        'Configuration Instagram incomplète (INSTAGRAM_BUSINESS_ACCOUNT_ID / INSTAGRAM_ACCESS_TOKEN)',
        500,
        'INSTAGRAM_NOT_CONFIGURED',
      );
    }
    return { igId, token, baseUrl: `https://graph.facebook.com/${env.FACEBOOK_GRAPH_VERSION}` };
  }

  private client(): AxiosInstance {
    if (!this.clientCache) {
      this.clientCache = axios.create({ baseURL: this.config().baseUrl, timeout: 30_000 });
    }
    return this.clientCache;
  }

  /** Publier une image + légende (flux en 2 étapes : create media -> publish). */
  async publish(_input: { imageUrl: string; caption?: string }): Promise<unknown> {
    throw new ExternalServiceError('Instagram', 'publish() non encore implémenté');
  }

  /** Lire les commentaires d'un media. */
  async getComments(_mediaId: string): Promise<unknown> {
    throw new ExternalServiceError('Instagram', 'getComments() non encore implémenté');
  }

  /** Lire/envoyer les messages (Instagram Messaging API). */
  async getMessages(_conversationId: string): Promise<unknown> {
    throw new ExternalServiceError('Instagram', 'getMessages() non encore implémenté');
  }

  /** Insights du compte / des medias. */
  async getInsights(_metrics: string[]): Promise<unknown> {
    throw new ExternalServiceError('Instagram', 'getInsights() non encore implémenté');
  }
}

export const instagramService = new InstagramService();
