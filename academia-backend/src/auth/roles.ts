/**
 * Rôles applicatifs Academia. L'ordre de la liste peut servir de hiérarchie
 * implicite (Admin le plus élevé), mais l'autorisation reste basée sur une
 * appartenance explicite au rôle via le middleware `authorize`.
 */
export const ROLES = ['admin', 'gestionnaire', 'moniteur', 'comptable', 'eleve'] as const;

export type Role = (typeof ROLES)[number];

export function isRole(value: unknown): value is Role {
  return typeof value === 'string' && (ROLES as readonly string[]).includes(value);
}
