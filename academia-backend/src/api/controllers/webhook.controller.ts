import type { Request, Response } from 'express';
import { env } from '../../config/env.js';
import { logger } from '../../utils/logger.js';

/**
 * Webhooks Facebook/Meta.
 *
 * - GET  /webhook : handshake de vérification (hub.challenge)
 * - POST /webhook : réception des événements (messages, commentaires, réactions, feed)
 *
 * La logique de traitement métier reste minimale ici : on journalise et on
 * dispatche. Brancher un vrai traitement (réponse auto, persistance Supabase...)
 * en appelant les Services correspondants.
 */
export const webhookController = {
  /** Vérification de l'abonnement webhook par Meta. */
  verify(req: Request, res: Response): void {
    const mode = req.query['hub.mode'];
    const token = req.query['hub.verify_token'];
    const challenge = req.query['hub.challenge'];

    if (mode === 'subscribe' && token === env.FACEBOOK_VERIFY_TOKEN) {
      logger.info('Webhook Facebook vérifié');
      res.status(200).send(String(challenge ?? ''));
      return;
    }
    logger.warn({ mode }, 'Échec vérification webhook (token invalide)');
    res.sendStatus(403);
  },

  /** Réception et dispatch des événements. Répondre 200 rapidement à Meta. */
  receive(req: Request, res: Response): void {
    // Toujours acquitter immédiatement pour éviter les renvois de Meta.
    res.sendStatus(200);

    const body = req.body as {
      object?: string;
      entry?: Array<{ messaging?: unknown[]; changes?: Array<{ field?: string; value?: unknown }> }>;
    };

    if (!body?.entry) return;

    for (const entry of body.entry) {
      // Événements Messenger
      if (Array.isArray(entry.messaging)) {
        for (const event of entry.messaging) {
          logger.info({ event }, 'Événement Messenger reçu');
          // TODO: dispatchMessengerEvent(event) — réponse auto, persistance...
        }
      }
      // Changements sur le feed : commentaires, réactions, publications
      if (Array.isArray(entry.changes)) {
        for (const change of entry.changes) {
          logger.info({ field: change.field, value: change.value }, 'Changement feed reçu');
          // TODO: router selon change.field ('feed', 'comments', 'reactions'...)
        }
      }
    }
  },
};
