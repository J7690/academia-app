import type { NextFunction, Request, Response } from 'express';

type AsyncRoute = (req: Request, res: Response, next: NextFunction) => Promise<unknown>;

/**
 * Enrobe un handler async pour propager toute exception vers le middleware
 * d'erreurs Express (évite les try/catch répétés dans chaque contrôleur).
 */
export const asyncHandler =
  (fn: AsyncRoute) =>
  (req: Request, res: Response, next: NextFunction): void => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
