# Guide MCP — brancher Academia sur Claude Desktop

Le serveur MCP fait partie du backend : il réutilise les mêmes Services que l'API REST. Il communique via **STDIO** (standard pour Claude Desktop).

## 1. Compiler (recommandé en usage réel)
```bash
npm run build      # produit dist/mcp/server.js
```
En développement, on peut aussi utiliser `npm run dev:mcp` (via tsx).

## 2. Déclarer le serveur dans Claude Desktop

Éditer le fichier de configuration Claude Desktop :
- macOS : `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows : `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "academia": {
      "command": "node",
      "args": ["/CHEMIN/ABSOLU/vers/academia-backend/dist/mcp/server.js"],
      "env": {
        "SUPABASE_URL": "https://xxxx.supabase.co",
        "SUPABASE_SERVICE_ROLE_KEY": "…",
        "JWT_SECRET": "…",
        "FACEBOOK_GRAPH_VERSION": "v20.0",
        "FACEBOOK_APP_ID": "…",
        "FACEBOOK_APP_SECRET": "…",
        "FACEBOOK_PAGE_ID": "…",
        "FACEBOOK_PAGE_ACCESS_TOKEN": "…",
        "FACEBOOK_VERIFY_TOKEN": "…"
      }
    }
  }
}
```
> Le serveur MCP lit ses variables depuis l'environnement fourni par Claude Desktop (bloc `env`) ou depuis un `.env` présent dans le dossier.

Redémarrer Claude Desktop : les 10 outils `facebook_*` apparaissent.

## 3. Outils exposés
| Outil | Action |
|-------|--------|
| `facebook_publish_post` | Publier une publication (message + lien) |
| `facebook_delete_post` | Supprimer une publication |
| `facebook_list_posts` | Lister les publications |
| `facebook_get_comments` | Lire les commentaires d'un post |
| `facebook_reply_comment` | Répondre à un commentaire |
| `facebook_get_messages` | Historique d'une conversation Messenger |
| `facebook_send_message` | Envoyer un message Messenger |
| `facebook_get_page_insights` | Statistiques de la Page |
| `facebook_publish_photo` | Publier une image (URL) |
| `facebook_publish_video` | Publier une vidéo (URL) |

## 4. Ajouter les outils d'un nouveau connecteur
Créer `src/mcp/tools/<connecteur>.tools.ts` sur le modèle de `facebook.tools.ts`, puis l'ajouter à `allTools` dans `src/mcp/tools/index.ts`. Chaque outil ne fait que valider (Zod) et déléguer au Service — **aucune logique métier dans le MCP**.
