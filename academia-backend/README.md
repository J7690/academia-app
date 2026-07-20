# Academia Backend

Backend modulaire de l'ERP **Academia** (gestion d'auto-écoles) : une API REST **et** un serveur **MCP** (Model Context Protocol) qui partagent exactement les mêmes Services, adossés à **Supabase**.

L'objectif : permettre à une IA (Claude Desktop, ChatGPT…) de **piloter l'application** via des outils MCP, tout en gardant une API REST classique pour l'app Flutter et le web. Facebook n'est que **le premier connecteur** d'une architecture pensée pour en accueillir beaucoup d'autres (Instagram, WhatsApp, Gmail, Google Calendar, Stripe…).

## Sommaire des guides

| Guide | Contenu |
|-------|---------|
| [docs/INSTALLATION.md](docs/INSTALLATION.md) | Installer et lancer en local |
| [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md) | Toutes les variables d'environnement |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Structure, principes SOLID, flux de données |
| [docs/MCP.md](docs/MCP.md) | Brancher le serveur MCP sur Claude Desktop |
| [docs/FACEBOOK.md](docs/FACEBOOK.md) | Configurer l'app Meta, tokens et webhooks |
| [docs/SUPABASE.md](docs/SUPABASE.md) | Connexion Supabase et couche Service |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Railway, Render, Docker, VPS Ubuntu (24/7) |

## Démarrage rapide

```bash
cd academia-backend
cp .env.example .env      # puis remplir les valeurs
npm install
npm run dev               # API REST + webhooks sur http://localhost:4000
npm run dev:mcp           # serveur MCP (STDIO) pour Claude Desktop
```

Vérifier que le serveur répond :

```bash
curl http://localhost:4000/api/health
```

## Stack technique

Node.js 20 (LTS) · TypeScript (strict) · Express · MCP SDK officiel · Supabase JS · Axios · Zod · Pino · JWT · Nodemon/tsx.

## Principes d'architecture

- **Une seule source de vérité par connecteur** : toute la logique métier vit dans `src/modules/<connecteur>`. L'API REST et les outils MCP ne font qu'appeler ces Services — zéro duplication.
- **La base n'est jamais touchée directement** : toutes les opérations passent par `DatabaseService` (`src/database/database.service.ts`).
- **Validation partagée** : les schémas Zod d'un connecteur servent à la fois à l'API REST et aux outils MCP.
- **Erreurs centralisées** : hiérarchie `AppError` + middleware unique.
- **Config validée au démarrage** : `src/config/env.ts` (fail-fast).

## Endpoints REST principaux (préfixe `/api`)

| Méthode | Route | Rôles | Description |
|---------|-------|-------|-------------|
| GET | `/api/health` | public | État du service |
| POST | `/api/auth/refresh` | public | Rafraîchir l'access token |
| POST | `/api/auth/dev-token` | dev | Générer un token de test |
| POST | `/api/facebook/post` | admin, gestionnaire | Publier une publication |
| GET | `/api/facebook/posts` | authentifié | Lister les publications |
| DELETE | `/api/facebook/post/:postId` | admin, gestionnaire | Supprimer une publication |
| POST | `/api/facebook/photo` | admin, gestionnaire | Publier une image |
| POST | `/api/facebook/video` | admin, gestionnaire | Publier une vidéo |
| GET | `/api/facebook/comments?objectId=` | authentifié | Lire les commentaires |
| POST | `/api/facebook/comment/reply` | admin, gestionnaire | Répondre à un commentaire |
| GET | `/api/facebook/conversations` | authentifié | Lister les conversations Messenger |
| GET | `/api/facebook/messages?conversationId=` | authentifié | Historique d'une conversation |
| POST | `/api/facebook/message/send` | admin, gestionnaire | Envoyer un message Messenger |
| POST | `/api/facebook/insights` | authentifié | Statistiques de la Page |
| GET | `/api/facebook/events` | authentifié | Événements de la Page |
| GET/POST | `/webhook` | public (Meta) | Vérification + réception d'événements |

## Outils MCP (10)

`facebook_publish_post`, `facebook_delete_post`, `facebook_list_posts`, `facebook_get_comments`, `facebook_reply_comment`, `facebook_get_messages`, `facebook_send_message`, `facebook_get_page_insights`, `facebook_publish_photo`, `facebook_publish_video`.

Voir [docs/MCP.md](docs/MCP.md) pour le branchement Claude Desktop.

## Scripts npm

| Script | Rôle |
|--------|------|
| `npm run dev` | API REST en watch (tsx + nodemon) |
| `npm run dev:mcp` | Serveur MCP en watch |
| `npm run build` | Compilation TypeScript → `dist/` |
| `npm start` | Lancer l'API compilée |
| `npm run start:mcp` | Lancer le MCP compilé |
| `npm run typecheck` | Vérification de types sans émission |
| `npm run generate:types` | Générer les types Supabase |

## Ajouter un connecteur (recette)

1. Créer `src/modules/<connecteur>/<connecteur>.service.ts` (toute la logique + appels API).
2. Créer les schémas Zod partagés `<connecteur>.schemas.ts`.
3. Exposer en REST : contrôleur + routes sous `src/api/`.
4. Exposer en MCP : `src/mcp/tools/<connecteur>.tools.ts`, ajouté au registre `src/mcp/tools/index.ts`.
5. Enregistrer le service dans `src/services/index.ts`.

L'architecture ne change pas — d'où l'objectif final : *« Publie cette annonce sur Facebook », « Réponds aux commentaires contenant le mot prix », « Crée une facture Stripe »* deviennent de simples outils MCP.
