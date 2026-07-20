import { createApp } from './api/app.js';
import { env } from './config/env.js';
import { logger } from './utils/logger.js';

/**
 * Point d'entrée du serveur HTTP (API REST + webhooks).
 * Le serveur MCP a son propre point d'entrée : src/mcp/server.ts
 */
function main(): void {
  const app = createApp();
  const server = app.listen(env.PORT, () => {
    logger.info(`🚀 Academia backend démarré sur http://localhost:${env.PORT} (${env.NODE_ENV})`);
  });

  const shutdown = (signal: string): void => {
    logger.info(`${signal} reçu — arrêt en cours...`);
    server.close(() => {
      logger.info('Serveur arrêté proprement');
      process.exit(0);
    });
    // Filet de sécurité si close() traîne
    setTimeout(() => process.exit(1), 10_000).unref();
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('unhandledRejection', (reason) => {
    logger.error({ reason }, 'unhandledRejection');
  });
}

main();
