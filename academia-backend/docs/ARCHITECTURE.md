# Architecture

## Vue d'ensemble

```
             ┌──────────────┐        ┌──────────────┐
   Claude →  │ Serveur MCP  │        │  API REST    │  ← App Flutter / Web
             │ (STDIO)      │        │  (Express)   │
             └──────┬───────┘        └──────┬───────┘
                    │   mêmes Services       │
                    └───────────┬────────────┘
                                ▼
                      ┌───────────────────┐
                      │   src/modules/*    │  logique métier des connecteurs
                      │ facebook, insta,   │
                      │ whatsapp, gmail,   │
                      │ calendar, stripe   │
                      └─────────┬─────────┘
                                ▼
                      ┌───────────────────┐
                      │  DatabaseService  │  seule porte vers Supabase
                      └─────────┬─────────┘
                                ▼
                            Supabase
```

## Arborescence
```
src/
  api/            # Couche HTTP : controllers, routes, middlewares
  auth/           # JWT, rôles, types
  config/         # Chargement + validation des variables d'env (Zod)
  database/       # Client + DatabaseService générique + types
  modules/        # Un dossier par connecteur (logique métier isolée)
    facebook/ instagram/ messenger/ whatsapp/ gmail/ calendar/ stripe/ supabase/
  mcp/            # Serveur MCP + registre d'outils
    tools/
    server.ts
  services/       # Registre central des Services (injection de dépendances)
  utils/          # logger (Pino), erreurs, asyncHandler
index.ts          # Point d'entrée API REST
```

## Principes (SOLID & co.)
- **S**ingle responsibility : contrôleurs = HTTP, services = métier, DatabaseService = persistance.
- **O**pen/closed : ajouter un connecteur = ajouter des fichiers, sans modifier l'existant.
- **D**ependency inversion : les points d'entrée (REST/MCP) dépendent d'abstractions Service via `src/services/index.ts`.
- **DRY** : schémas Zod et Services partagés entre REST et MCP.
- **Fail-fast** : configuration validée au démarrage.
- **Gestion d'erreurs centralisée** : `AppError` → middleware unique → réponse JSON homogène `{ error: { code, message, details } }`.

## Flux d'une requête REST
1. `pino-http` journalise la requête.
2. `authenticate` vérifie le JWT et remplit `req.user`.
3. `authorize(...roles)` filtre par rôle.
4. `validate({ body/query/params })` applique le schéma Zod.
5. Le contrôleur appelle le Service.
6. Le Service appelle l'API externe (Axios) ou `DatabaseService`.
7. Les erreurs remontent au middleware `errorHandler`.

## Rôles
`admin`, `gestionnaire`, `moniteur`, `comptable`, `eleve` (voir `src/auth/roles.ts`).
