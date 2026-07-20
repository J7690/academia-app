import { env } from '../../config/env.js';
import { AppError } from '../../utils/errors.js';

/**
 * Résout et valide la configuration Facebook au moment de l'utilisation
 * (lazy). Le backend peut ainsi démarrer sans les clés Facebook ; seule
 * l'utilisation effective du module échoue si elles manquent.
 */
export interface FacebookConfig {
  graphVersion: string;
  appId: string;
  appSecret: string;
  pageId: string;
  pageAccessToken: string;
  verifyToken: string;
  baseUrl: string;
}

export function getFacebookConfig(): FacebookConfig {
  const missing: string[] = [];
  if (!env.FACEBOOK_APP_ID) missing.push('FACEBOOK_APP_ID');
  if (!env.FACEBOOK_APP_SECRET) missing.push('FACEBOOK_APP_SECRET');
  if (!env.FACEBOOK_PAGE_ID) missing.push('FACEBOOK_PAGE_ID');
  if (!env.FACEBOOK_PAGE_ACCESS_TOKEN) missing.push('FACEBOOK_PAGE_ACCESS_TOKEN');

  if (missing.length > 0) {
    throw new AppError(
      `Configuration Facebook incomplète. Variables manquantes: ${missing.join(', ')}`,
      500,
      'FACEBOOK_NOT_CONFIGURED',
    );
  }

  const graphVersion = env.FACEBOOK_GRAPH_VERSION;
  return {
    graphVersion,
    appId: env.FACEBOOK_APP_ID!,
    appSecret: env.FACEBOOK_APP_SECRET!,
    pageId: env.FACEBOOK_PAGE_ID!,
    pageAccessToken: env.FACEBOOK_PAGE_ACCESS_TOKEN!,
    verifyToken: env.FACEBOOK_VERIFY_TOKEN ?? '',
    baseUrl: `https://graph.facebook.com/${graphVersion}`,
  };
}
