import { facebookService } from '../facebook/index.js';
import { ExternalServiceError } from '../../utils/errors.js';

/**
 * Module Messenger. Les conversations/messages partagent l'API de la Page
 * Facebook : on délègue au FacebookService pour la lecture et l'envoi. Les
 * fonctionnalités spécifiques (réponse auto, pièces jointes) sont à compléter.
 */
export class MessengerService {
  /** Lister les conversations de la Page. */
  listConversations(limit = 25) {
    return facebookService.listConversations(limit);
  }

  /** Historique d'une conversation. */
  getHistory(conversationId: string, limit = 50) {
    return facebookService.getConversationMessages(conversationId, limit);
  }

  /** Répondre à un utilisateur (PSID). */
  reply(recipientId: string, message: string) {
    return facebookService.sendMessage({ recipientId, message });
  }

  /** Réponse automatique à partir d'une règle/mot-clé (à brancher sur webhook). */
  async autoReply(_recipientId: string, _incomingText: string): Promise<unknown> {
    throw new ExternalServiceError('Messenger', 'autoReply() non encore implémenté');
  }

  /** Envoi de pièces jointes (image/fichier). */
  async sendAttachment(_recipientId: string, _url: string): Promise<unknown> {
    throw new ExternalServiceError('Messenger', 'sendAttachment() non encore implémenté');
  }
}

export const messengerService = new MessengerService();
