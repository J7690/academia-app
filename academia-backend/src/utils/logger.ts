import pino from 'pino';
import { env } from '../config/env.js';

/**
 * Logger applicatif unique (Pino). En développement on active pino-pretty
 * pour une sortie lisible ; en production on émet du JSON structuré.
 */
export const logger = pino({
  level: env.LOG_LEVEL,
  base: { service: 'academia-backend' },
  timestamp: pino.stdTimeFunctions.isoTime,
  ...(env.NODE_ENV === 'development'
    ? {
        transport: {
          target: 'pino-pretty',
          options: { colorize: true, translateTime: 'SYS:standard', ignore: 'pid,hostname' },
        },
      }
    : {}),
});

export type Logger = typeof logger;
