import jwt, { type SignOptions } from 'jsonwebtoken';
import { env, jwtRefreshSecret } from '../config/env.js';
import { UnauthorizedError } from '../utils/errors.js';
import type { JwtPayload } from './auth.types.js';

/**
 * Service d'émission et de vérification des JWT (access + refresh).
 * Le refresh token utilise un secret distinct (ou retombe sur JWT_SECRET).
 */
export class JwtService {
  signAccessToken(payload: JwtPayload): string {
    const options: SignOptions = { expiresIn: env.JWT_ACCESS_EXPIRES_IN as SignOptions['expiresIn'] };
    return jwt.sign(payload, env.JWT_SECRET, options);
  }

  signRefreshToken(payload: Pick<JwtPayload, 'sub'>): string {
    const options: SignOptions = {
      expiresIn: env.JWT_REFRESH_EXPIRES_IN as SignOptions['expiresIn'],
    };
    return jwt.sign(payload, jwtRefreshSecret, options);
  }

  /** Émet la paire access+refresh. */
  issueTokens(payload: JwtPayload): { accessToken: string; refreshToken: string } {
    return {
      accessToken: this.signAccessToken(payload),
      refreshToken: this.signRefreshToken({ sub: payload.sub }),
    };
  }

  verifyAccessToken(token: string): JwtPayload {
    try {
      return jwt.verify(token, env.JWT_SECRET) as JwtPayload;
    } catch {
      throw new UnauthorizedError('Access token invalide ou expiré');
    }
  }

  verifyRefreshToken(token: string): Pick<JwtPayload, 'sub'> {
    try {
      return jwt.verify(token, jwtRefreshSecret) as Pick<JwtPayload, 'sub'>;
    } catch {
      throw new UnauthorizedError('Refresh token invalide ou expiré');
    }
  }
}

export const jwtService = new JwtService();
