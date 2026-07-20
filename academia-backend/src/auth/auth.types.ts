import type { Role } from './roles.js';

/** Charge utile (claims) portée par les JWT. */
export interface JwtPayload {
  /** Identifiant utilisateur (souvent l'UUID Supabase auth). */
  sub: string;
  email?: string;
  role: Role;
}

/** Utilisateur authentifié attaché à la requête. */
export interface AuthUser {
  id: string;
  email?: string;
  role: Role;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}
