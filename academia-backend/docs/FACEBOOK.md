# Guide Facebook / Meta

## 1. Créer l'app Meta
1. https://developers.facebook.com → *Mes apps* → *Créer une app* (type **Business**).
2. Récupérer **App ID** et **App Secret** (Paramètres → De base) → `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET`.
3. Ajouter les produits **Facebook Login** et **Webhooks**.

## 2. Page & Access Token
1. Associer la **Page** de l'auto-école. Noter son **ID** → `FACEBOOK_PAGE_ID`.
2. Générer un **Page Access Token** (idéalement *longue durée* / *never-expiring* via l'échange de token) → `FACEBOOK_PAGE_ACCESS_TOKEN`.
3. Permissions utiles : `pages_manage_posts`, `pages_read_engagement`, `pages_manage_engagement`, `pages_messaging`, `pages_read_user_content`, `read_insights`.

## 3. Webhooks
1. Choisir une valeur secrète pour `FACEBOOK_VERIFY_TOKEN`.
2. Dans l'app Meta → Webhooks → *Page* :
   - **Callback URL** : `https://VOTRE-DOMAINE/webhook`
   - **Verify Token** : la même valeur que `FACEBOOK_VERIFY_TOKEN`
3. Meta appelle `GET /webhook` pour la vérification (le backend renvoie `hub.challenge`).
4. S'abonner aux champs : `feed` (publications/commentaires/réactions), `messages`, `messaging_postbacks`.
5. Les événements arrivent en `POST /webhook` — voir `src/api/controllers/webhook.controller.ts` (points d'extension `TODO`).

## 4. Tester via l'API REST
```bash
# Publier
curl -X POST http://localhost:4000/api/facebook/post \
  -H "Authorization: Bearer <token>" -H "Content-Type: application/json" \
  -d '{"message":"Inscriptions ouvertes ! Code + conduite dès 150 000 FCFA."}'

# Lister
curl http://localhost:4000/api/facebook/posts -H "Authorization: Bearer <token>"

# Statistiques de la semaine
curl -X POST http://localhost:4000/api/facebook/insights \
  -H "Authorization: Bearer <token>" -H "Content-Type: application/json" \
  -d '{"metrics":["page_impressions","page_engaged_users"],"period":"week"}'
```

## 5. Notes
- Tout passe par `FacebookService` (`src/modules/facebook/facebook.service.ts`), seul endroit qui appelle la Graph API.
- La version de l'API est pilotée par `FACEBOOK_GRAPH_VERSION`.
- Les erreurs Meta sont normalisées en `ExternalServiceError` (HTTP 502) avec le détail d'origine.
