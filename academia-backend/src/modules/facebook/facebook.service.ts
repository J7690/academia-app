import axios, { AxiosError, type AxiosInstance } from 'axios';
import { ExternalServiceError } from '../../utils/errors.js';
import { logger } from '../../utils/logger.js';
import { getFacebookConfig } from './facebook.config.js';
import type {
  PublishPostInput,
  PublishPhotoInput,
  PublishVideoInput,
  ReplyCommentInput,
  SendMessageInput,
  InsightsInput,
} from './facebook.schemas.js';
import type {
  FacebookComment,
  FacebookPost,
  InsightMetric,
  MessengerConversation,
  MessengerMessage,
  PublishResult,
} from './facebook.types.js';

/**
 * Module Facebook — encapsule tous les appels à la Meta Graph API.
 *
 * C'est ici, et NULLE PART AILLEURS, que vit la logique métier Facebook.
 * Le serveur MCP et les contrôleurs REST se contentent d'appeler ces méthodes.
 */
export class FacebookService {
  private clientCache: AxiosInstance | null = null;

  /** Client Axios paresseux (créé au premier usage, après validation config). */
  private client(): AxiosInstance {
    if (!this.clientCache) {
      const cfg = getFacebookConfig();
      this.clientCache = axios.create({ baseURL: cfg.baseUrl, timeout: 30_000 });
    }
    return this.clientCache;
  }

  private get pageId(): string {
    return getFacebookConfig().pageId;
  }

  private get token(): string {
    return getFacebookConfig().pageAccessToken;
  }

  /** Normalise les erreurs de la Graph API en ExternalServiceError. */
  private wrap(error: unknown, action: string): never {
    if (error instanceof AxiosError) {
      const apiError = error.response?.data?.error;
      logger.error({ action, apiError, status: error.response?.status }, 'Erreur Graph API');
      throw new ExternalServiceError(
        'Facebook',
        apiError?.message ?? error.message ?? `Échec: ${action}`,
        apiError,
      );
    }
    logger.error({ action, error }, 'Erreur Facebook inattendue');
    throw new ExternalServiceError('Facebook', `Échec inattendu: ${action}`);
  }

  // ---------------------------------------------------------------------------
  // PUBLICATIONS
  // ---------------------------------------------------------------------------

  /** Publier une publication texte (avec lien optionnel). */
  async publishPost(input: PublishPostInput): Promise<PublishResult> {
    try {
      const { data } = await this.client().post<PublishResult>(`/${this.pageId}/feed`, null, {
        params: {
          message: input.message,
          ...(input.link ? { link: input.link } : {}),
          ...(input.published === false ? { published: false } : {}),
          access_token: this.token,
        },
      });
      return data;
    } catch (e) {
      this.wrap(e, 'publishPost');
    }
  }

  /** Supprimer une publication. */
  async deletePost(postId: string): Promise<{ success: boolean }> {
    try {
      const { data } = await this.client().delete<{ success: boolean }>(`/${postId}`, {
        params: { access_token: this.token },
      });
      return { success: data?.success ?? true };
    } catch (e) {
      this.wrap(e, 'deletePost');
    }
  }

  /** Lister les publications de la Page. */
  async listPosts(limit = 25): Promise<FacebookPost[]> {
    try {
      const { data } = await this.client().get<{ data: FacebookPost[] }>(`/${this.pageId}/posts`, {
        params: {
          fields: 'id,message,created_time,permalink_url,full_picture',
          limit,
          access_token: this.token,
        },
      });
      return data.data ?? [];
    } catch (e) {
      this.wrap(e, 'listPosts');
    }
  }

  /** Publier une image à partir d'une URL. */
  async publishPhoto(input: PublishPhotoInput): Promise<PublishResult> {
    try {
      const { data } = await this.client().post<PublishResult>(`/${this.pageId}/photos`, null, {
        params: {
          url: input.imageUrl,
          ...(input.caption ? { caption: input.caption } : {}),
          access_token: this.token,
        },
      });
      return data;
    } catch (e) {
      this.wrap(e, 'publishPhoto');
    }
  }

  /** Publier une vidéo à partir d'une URL (upload par URL hébergée). */
  async publishVideo(input: PublishVideoInput): Promise<PublishResult> {
    try {
      const { data } = await this.client().post<PublishResult>(`/${this.pageId}/videos`, null, {
        params: {
          file_url: input.videoUrl,
          ...(input.title ? { title: input.title } : {}),
          ...(input.description ? { description: input.description } : {}),
          access_token: this.token,
        },
      });
      return data;
    } catch (e) {
      this.wrap(e, 'publishVideo');
    }
  }

  // ---------------------------------------------------------------------------
  // COMMENTAIRES
  // ---------------------------------------------------------------------------

  /** Lire les commentaires d'un post (ou les réponses d'un commentaire). */
  async getComments(objectId: string, limit = 50): Promise<FacebookComment[]> {
    try {
      const { data } = await this.client().get<{ data: FacebookComment[] }>(
        `/${objectId}/comments`,
        {
          params: {
            fields: 'id,message,created_time,from,like_count',
            limit,
            access_token: this.token,
          },
        },
      );
      return data.data ?? [];
    } catch (e) {
      this.wrap(e, 'getComments');
    }
  }

  /** Répondre à un commentaire. */
  async replyToComment(input: ReplyCommentInput): Promise<PublishResult> {
    try {
      const { data } = await this.client().post<PublishResult>(
        `/${input.commentId}/comments`,
        null,
        { params: { message: input.message, access_token: this.token } },
      );
      return data;
    } catch (e) {
      this.wrap(e, 'replyToComment');
    }
  }

  // ---------------------------------------------------------------------------
  // MESSENGER
  // ---------------------------------------------------------------------------

  /** Lister les conversations Messenger de la Page. */
  async listConversations(limit = 25): Promise<MessengerConversation[]> {
    try {
      const { data } = await this.client().get<{ data: MessengerConversation[] }>(
        `/${this.pageId}/conversations`,
        {
          params: {
            fields: 'id,snippet,updated_time,participants',
            limit,
            access_token: this.token,
          },
        },
      );
      return data.data ?? [];
    } catch (e) {
      this.wrap(e, 'listConversations');
    }
  }

  /** Lire l'historique des messages d'une conversation. */
  async getConversationMessages(conversationId: string, limit = 50): Promise<MessengerMessage[]> {
    try {
      const { data } = await this.client().get<{ messages?: { data: MessengerMessage[] } }>(
        `/${conversationId}`,
        {
          params: {
            fields: `messages.limit(${limit}){id,message,created_time,from}`,
            access_token: this.token,
          },
        },
      );
      return data.messages?.data ?? [];
    } catch (e) {
      this.wrap(e, 'getConversationMessages');
    }
  }

  /** Envoyer un message Messenger à un utilisateur (PSID). */
  async sendMessage(input: SendMessageInput): Promise<{ message_id?: string; recipient_id?: string }> {
    try {
      const { data } = await this.client().post<{ message_id?: string; recipient_id?: string }>(
        `/${this.pageId}/messages`,
        {
          recipient: { id: input.recipientId },
          messaging_type: 'RESPONSE',
          message: { text: input.message },
        },
        { params: { access_token: this.token } },
      );
      return data;
    } catch (e) {
      this.wrap(e, 'sendMessage');
    }
  }

  // ---------------------------------------------------------------------------
  // STATISTIQUES
  // ---------------------------------------------------------------------------

  /** Télécharger les statistiques (insights) de la Page. */
  async getPageInsights(input: InsightsInput): Promise<InsightMetric[]> {
    try {
      const { data } = await this.client().get<{ data: InsightMetric[] }>(
        `/${this.pageId}/insights`,
        {
          params: {
            metric: input.metrics.join(','),
            period: input.period,
            access_token: this.token,
          },
        },
      );
      return data.data ?? [];
    } catch (e) {
      this.wrap(e, 'getPageInsights');
    }
  }

  /** Lire les événements de la Page. */
  async getPageEvents(limit = 25): Promise<Array<Record<string, unknown>>> {
    try {
      const { data } = await this.client().get<{ data: Array<Record<string, unknown>> }>(
        `/${this.pageId}/events`,
        {
          params: {
            fields: 'id,name,description,start_time,end_time,place',
            limit,
            access_token: this.token,
          },
        },
      );
      return data.data ?? [];
    } catch (e) {
      this.wrap(e, 'getPageEvents');
    }
  }
}

export const facebookService = new FacebookService();
