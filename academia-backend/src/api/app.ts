import express, { type Express } from 'express';
import { pinoHttp } from 'pino-http';
import { logger } from '../utils/logger.js';
import { errorHandler, notFoundHandler } from './middlewares/error.middleware.js';
import apiRoutes from './routes/index.js';
import webhookRoutes from './routes/webhook.routes.js';

/**
 * Construit et configure l'application Express (sans l'écouter).
 * Séparer la création de l'app de son démarrage facilite les tests.
 */
export function createApp(): Express {
  const app = express();

  // Journalisation HTTP structurée (chaque requête est loggée).
  app.use(pinoHttp({ logger }));

  app.use(express.json({ limit: '5mb' }));
  app.use(express.urlencoded({ extended: true }));

  // Racine
  app.get('/', (_req, res) => {
    res.json({ service: 'academia-backend', status: 'running' });
  });

  // Webhooks (hors /api, appelés par Meta/Stripe/etc.)
  app.use('/webhook', webhookRoutes);

  // API REST versionnée logiquement sous /api
  app.use('/api', apiRoutes);

  // 404 + gestion d'erreurs centralisée (toujours en dernier)
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
