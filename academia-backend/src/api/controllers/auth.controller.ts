import type { Request, Response } from 'express';
import { env } from '../../config/env.js';
import { jwtService } from '../../auth/jwt.service.js';
import { isRole } from '../../auth/roles.js';
import { BadRequestError, ForbiddenError } from '../../utils/errors.js';

/**
 * Contrôleur d'authentification.
 *
 * NB: Academia s'appuie sur Supabase Auth pour l'identité. Ce contrôleur émet
 * les JWT applicatifs consommés par le backend. `issueDevToken` est un utilitaire
 * réservé au développement pour tester rapidement les routes protégées.
 */
export const authController = {
  /** Échange un refresh token valide contre un nouvel access token. */
  refresh(req: Request, res: Response): void {
    const { refreshToken, role, email } = req.body as {
      refreshToken?: string;
      role?: string;
      email?: string;
    };
    if (!refreshToken) throw new BadRequestError('refreshToken requis');
    if (!isRole(role)) throw new BadRequestError('role valide requis');

    const { sub } = jwtService.verifyRefreshToken(refreshToken);
    const accessToken = jwtService.signAccessToken({ sub, role, email });
    res.json({ data: { accessToken } });
  },

  /** DEV UNIQUEMENT : génère une paire de tokens pour tester l'API. */
  issueDevToken(req: Request, res: Response): void {
    if (env.NODE_ENV === 'production') {
      throw new ForbiddenError('Indisponible en production');
    }
    const { userId = 'dev-user', role = 'admin', email } = req.body as {
      userId?: string;
      role?: string;
      email?: string;
    };
    if (!isRole(role)) throw new BadRequestError('role invalide');
    const tokens = jwtService.issueTokens({ sub: userId, role, email });
    res.json({ data: tokens });
  },
};
