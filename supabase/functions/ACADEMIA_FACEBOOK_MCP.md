# Academia — Connecteur Facebook & MCP sur Supabase (Edge Functions)

Déploiement **100 % Supabase**, sans VPS ni Railway. Trois Edge Functions déployées sur le projet `thevdfcwlcqzdoybfvgs` :

| Fonction | URL | Rôle | Auth |
|----------|-----|------|------|
| `facebook-connector` | `https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/facebook-connector` | API des 10 actions Facebook | `Bearer ACADEMIA_API_TOKEN` |
| `facebook-webhook` | `https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/facebook-webhook` | Webhooks Meta (GET/POST) | public (verify token Meta) |
| `academia-mcp` | `https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/academia-mcp` | Serveur MCP HTTP (10 outils) | `Bearer ACADEMIA_API_TOKEN` (optionnel) |

Les trois sont déployées avec `verify_jwt=false` : l'authentification est gérée **dans le code** (token Meta pour le webhook, `ACADEMIA_API_TOKEN` pour le reste).

## 1. Définir les secrets (indispensable)

Ces fonctions lisent leur configuration depuis les **secrets Edge Functions**. À définir une fois :

**Via le Dashboard** : Project Settings → Edge Functions → Manage secrets → Add secret.

**Via la CLI Supabase :**
```bash
supabase secrets set \
  FACEBOOK_GRAPH_VERSION=v20.0 \
  FACEBOOK_PAGE_ID=<id_de_ta_page> \
  FACEBOOK_PAGE_ACCESS_TOKEN=<page_access_token_longue_duree> \
  FACEBOOK_VERIFY_TOKEN=<chaine_secrete_de_ton_choix> \
  ACADEMIA_API_TOKEN=<jeton_secret_pour_appeler_le_connecteur_et_le_mcp> \
  --project-ref thevdfcwlcqzdoybfvgs
```

> `SUPABASE_URL` et `SUPABASE_SERVICE_ROLE_KEY` sont injectés automatiquement par la plateforme — inutile de les définir.

## 2. Configurer le webhook Meta
- **Callback URL** : `https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/facebook-webhook`
- **Verify Token** : la valeur mise dans `FACEBOOK_VERIFY_TOKEN`
- Champs à abonner : `feed`, `messages`, `messaging_postbacks`
Meta appelle `GET` pour vérifier (la fonction renvoie `hub.challenge`), puis `POST` pour les événements.

## 3. Utiliser le connecteur (REST)
```bash
BASE=https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/facebook-connector
TOKEN=<ACADEMIA_API_TOKEN>

# Publier
curl -X POST "$BASE" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"action":"facebook_publish_post","params":{"message":"Bonjour depuis Academia 👋"}}'

# Lister les publications
curl -X POST "$BASE" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"action":"facebook_list_posts","params":{"limit":10}}'

# Statistiques de la semaine
curl -X POST "$BASE" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"action":"facebook_get_page_insights","params":{"period":"week"}}'
```
Actions disponibles : `facebook_publish_post`, `facebook_delete_post`, `facebook_list_posts`, `facebook_get_comments`, `facebook_reply_comment`, `facebook_get_messages`, `facebook_send_message`, `facebook_get_page_insights`, `facebook_publish_photo`, `facebook_publish_video`.

## 4. Brancher le MCP sur Claude
Le serveur MCP est en **HTTP (Streamable)** à l'URL `academia-mcp`. Dans Claude (Desktop / claude.ai → Connectors → Ajouter un connecteur personnalisé), renseigne l'URL :
```
https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/academia-mcp
```
Si `ACADEMIA_API_TOKEN` est défini, ajoute l'en-tête `Authorization: Bearer <token>` (selon ce que permet ton client). Une fois connecté, les 10 outils `facebook_*` apparaissent et tu peux dire : *« Publie cette annonce sur Facebook »*, *« Donne-moi les statistiques de la semaine »*, *« Réponds aux commentaires contenant prix »*.

## 5. Test rapide (santé)
```bash
curl https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/academia-mcp        # {"service":"academia-mcp","tools":10}
curl "https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/facebook-connector?health=1"  # {"ok":true}
```

## 6. Ajouter un connecteur (Instagram, WhatsApp, Stripe…)
1. Créer `<connecteur>.ts` (logique) sur le modèle de `facebook.ts`.
2. Ajouter ses outils dans `tools.ts` (nom + schéma JSON + handler).
3. Ils apparaissent automatiquement dans le connecteur REST **et** dans le MCP — aucune autre modification.
