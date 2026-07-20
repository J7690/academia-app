import type { NextFunction, Request, Response } from 'express';
import { AppError } from '../../utils/errors.js';
import { logger } from '../../utils/logger.js';

/** 404 pour toute route non gérée. */
export function notFoundHandler(req: Request, res: Response): void {
  res.status(404).json({
    error: { code: 'NOT_FOUND', message: `Route introuvable: ${req.method} ${req.originalUrl}` },
  });
}

/**
 * Middleware d'erreurs centralisé. Doit être enregistré EN DERNIER.
 * Les AppError (opérationnelles) sont renvoyées telles quelles ; toute autre
 * exception devient une 500 générique et est loggée en `error`.
 */
export function errorHandler(
  err: unknown,
  _req: Request,
  res: Response,
  // next requis pour qu'Express reconnaisse le handler d'erreurs (4 args)
  _next: NextFunction,
): void {
  if (err instanceof AppError) {
    if (err.statusCode >= 500) logger.error({ err }, err.message);
    else logger.warn({ code: err.code }, err.message);
    res.status(err.statusCode).json({
      error: { code: err.code, message: err.message, details: err.details ?? undefined },
    });
    return;
  }

  logger.error({ err }, 'Erreur non gérée');
  res.status(500).json({
    error: { code: 'INTERNAL_ERROR', message: 'Erreur interne du serveur' },
  });
}
