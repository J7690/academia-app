import type { NextFunction, Request, Response } from 'express';
import { jwtService } from '../../auth/jwt.service.js';
import { isRole, type Role } from '../../auth/roles.js';
import { ForbiddenError, UnauthorizedError } from '../../utils/errors.js';

/**
 * Vérifie le header `Authorization: Bearer <token>` et attache `req.user`.
 */
export function authenticate(req: Request, _res: Response, next: NextFunction): void {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    throw new UnauthorizedError('Header Authorization Bearer manquant');
  }
  const token = header.slice('Bearer '.length).trim();
  const payload = jwtService.verifyAccessToken(token);
  if (!isRole(payload.role)) {
    throw new UnauthorizedError('Rôle du token invalide');
  }
  req.user = { id: payload.sub, email: payload.email, role: payload.role };
  next();
}

/**
 * Restreint l'accès à une liste de rôles. À utiliser APRÈS `authenticate`.
 *   router.post('/x', authenticate, authorize('admin', 'gestionnaire'), handler)
 */
export function authorize(...allowed: Role[]) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    if (!req.user) throw new UnauthorizedError();
    if (allowed.length > 0 && !allowed.includes(req.user.role)) {
      throw new ForbiddenError(
        `Rôle "${req.user.role}" non autorisé (requis: ${allowed.join(', ')})`,
      );
    }
    next();
  };
}
