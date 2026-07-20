# Variables d'environnement

Toutes les variables sont validées au démarrage par `src/config/env.ts` (Zod). Une variable requise manquante empêche le démarrage (fail-fast). Les blocs connecteurs sont optionnels : le backend démarre sans eux, seule leur utilisation échoue si non configurés.

## Serveur
| Variable | Requis | Défaut | Description |
|----------|--------|--------|-------------|
| `NODE_ENV` | non | development | development / test / production |
| `PORT` | non | 4000 | Port HTTP |
| `LOG_LEVEL` | non | info | Niveau Pino (fatal→trace) |

## Supabase (requis)
| Variable | Requis | Description |
|----------|--------|-------------|
| `SUPABASE_URL` | oui | URL du projet |
| `SUPABASE_SERVICE_ROLE_KEY` | oui | Clé service role (jamais côté client !) |
| `SUPABASE_PROJECT_ID` | non | Pour `npm run generate:types` |

## Auth JWT (requis)
| Variable | Requis | Défaut | Description |
|----------|--------|--------|-------------|
| `JWT_SECRET` | oui | — | Secret des access tokens (≥16 car.) |
| `JWT_ACCESS_EXPIRES_IN` | non | 15m | Durée access token |
| `JWT_REFRESH_SECRET` | non | =JWT_SECRET | Secret des refresh tokens |
| `JWT_REFRESH_EXPIRES_IN` | non | 30d | Durée refresh token |

## Facebook / Meta
`FACEBOOK_GRAPH_VERSION` (défaut v20.0), `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET`, `FACEBOOK_PAGE_ID`, `FACEBOOK_PAGE_ACCESS_TOKEN`, `FACEBOOK_VERIFY_TOKEN`.

## Instagram
`INSTAGRAM_BUSINESS_ACCOUNT_ID`, `INSTAGRAM_ACCESS_TOKEN`.

## WhatsApp
`WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_BUSINESS_ACCOUNT_ID`, `WHATSAPP_ACCESS_TOKEN`, `WHATSAPP_VERIFY_TOKEN`.

## Google (Calendar / Drive / Gmail)
`GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI`, `GOOGLE_REFRESH_TOKEN`.

## Stripe
`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`.

> ⚠️ Ne jamais committer `.env`. Utiliser les *secrets* de la plateforme (Railway/Render) en production.
