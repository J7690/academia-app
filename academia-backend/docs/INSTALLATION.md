# Installation & lancement local

## Prérequis
- Node.js **20 LTS** (voir `.nvmrc`) et npm 10+
- Un projet **Supabase** (URL + service role key)
- (Optionnel) Une **app Meta/Facebook** pour le module Facebook — voir [FACEBOOK.md](FACEBOOK.md)

## Étapes

```bash
cd academia-backend
cp .env.example .env
# Éditer .env : au minimum SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, JWT_SECRET
npm install
```

### Lancer l'API REST (+ webhooks)
```bash
npm run dev        # développement (rechargement à chaud)
# ou
npm run build && npm start   # production
```
Le serveur écoute sur `http://localhost:4000`. Test : `curl http://localhost:4000/api/health`.

### Lancer le serveur MCP
```bash
npm run dev:mcp    # transport STDIO, à brancher sur Claude Desktop
```

## Générer un token de test (développement uniquement)
```bash
curl -X POST http://localhost:4000/api/auth/dev-token \
  -H "Content-Type: application/json" \
  -d '{"userId":"u1","role":"admin"}'
```
Réutiliser l'`accessToken` renvoyé dans l'en-tête `Authorization: Bearer <token>`.

## Dépannage
- **Le serveur refuse de démarrer avec une liste de variables** : une variable requise est absente ou invalide (`src/config/env.ts`). Corriger `.env`.
- **`FACEBOOK_NOT_CONFIGURED`** : les clés Facebook manquent — normal tant que le connecteur n'est pas configuré ; le reste du backend fonctionne.
