# Instructions Windsurf — LWS : correctif moteur Vision + déploiement Phase 2

**Date** : 25 juillet 2026
**Serveur cible** : `lws-nexiom` (root@31.207.38.60) — **uniquement**. Ne touche pas à Kamatera.
**Deux tâches** : (A) réparer le moteur Vision, cassé en production. (B) déployer les
conteneurs backend (Phase 2 de `docs/MIGRATION_COMPLETE_KAMATERA_VERS_LWS.md`).

## Pourquoi ces tâches (constaté par Claude, pas supposé)

Claude a lancé de vrais jobs de rendu via Supabase le 25 juillet :
- Job `engine=remotion` → **succès en 169 s**, vidéo produite. Le moteur Remotion
  fonctionne sur LWS, aucun crash mémoire.
- Job `engine=vision` → **échec en 0,4 s** :
  `Error: Cannot find module 'playwright'` dans
  `/opt/whiteboard-worker/vision_engine/capture_scene.js`.

Le moteur Vision est celui que l'application utilise **actuellement en production**
(`engine: 'vision'` côté Flutter). Les fichiers ont été copiés sur le serveur, mais la
dépendance npm `playwright` n'a jamais été installée. **Tâche A est donc urgente.**

Par ailleurs `/opt/academia` n'existe pas : les conteneurs backend (Bobodo vocal,
compression vidéo) ne tournent pas encore sur LWS — d'où la **Tâche B**.

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`. Ne te connecte pas à Kamatera (185.167.97.144),
   ne l'arrête pas, ne le modifie pas. Il reste en service pendant toute la migration.
2. **Ne modifie AUCUN fichier du dépôt Git** et ne committe rien. Si un fichier source
   semble devoir changer → **STOP + rapport**, c'est Claude qui s'en charge.
3. **Ne touche pas à Supabase** (ni secrets, ni SQL, ni Edge Functions) — Claude s'en charge.
4. **Ne bascule aucune IP applicative.** L'app continue de pointer vers Kamatera
   volontairement, jusqu'à validation. Ne cherche pas à changer ça.
5. Secrets : ils vivent **uniquement** dans les fichiers `.env` **sur le serveur**, en
   `chmod 600`. Jamais dans Git, jamais affichés en clair dans les logs ou le rapport.
6. Ne touche pas au pare-feu / UFW / iptables / sshd_config.
7. À la moindre erreur ou sortie inattendue → **STOP + rapport**. Ne tente pas de contourner.

---

# TÂCHE A — Réparer le moteur Vision (prioritaire)

## A1. Constater l'état actuel
```bash
ssh lws-nexiom "ls -la /opt/whiteboard-worker/vision_engine/
ls -d /opt/whiteboard-worker/node_modules 2>/dev/null || echo 'pas de node_modules dans /opt/whiteboard-worker'
ls -d /opt/whiteboard-worker/vision_engine/node_modules 2>/dev/null || echo 'pas de node_modules dans vision_engine'"
```

## A2. Installer playwright + son navigateur
`capture_scene.js` fait `require('playwright')` : Node remonte l'arborescence depuis
`/opt/whiteboard-worker/vision_engine/`, donc installer dans `/opt/whiteboard-worker`
suffit et couvre les deux emplacements.
```bash
ssh lws-nexiom "cd /opt/whiteboard-worker
[ -f package.json ] || npm init -y
npm install playwright
npx playwright install --with-deps chromium"
```

## A3. Vérifier l'installation
```bash
ssh lws-nexiom "cd /opt/whiteboard-worker
node -e \"const {chromium}=require('playwright'); console.log('playwright OK'); chromium.launch().then(b=>b.close()).then(()=>console.log('chromium lance OK')).catch(e=>{console.error('ECHEC chromium:',e.message);process.exit(1)})\""
```
Attendu : `playwright OK` puis `chromium lance OK`. Sinon → STOP + rapport.

## A4. Redémarrer le worker
```bash
ssh lws-nexiom "systemctl restart whiteboard-worker && sleep 3 && systemctl is-active whiteboard-worker"
```
Attendu : `active`.

**Puis arrête-toi sur la Tâche A et signale-le** : Claude relancera lui-même un vrai job
`engine=vision` via Supabase pour valider, et te dira si tu peux passer à la Tâche B.

---

# TÂCHE B — Déployer les conteneurs backend (Phase 2)

À ne commencer **qu'après** validation de la Tâche A par Claude.

## B1. Copier les fichiers nécessaires (depuis la racine du dépôt `academia/`)
```powershell
ssh lws-nexiom "mkdir -p /opt/academia"
scp docker-compose.yml lws-nexiom:/opt/academia/
scp -r academia_bobodo_backend lws-nexiom:/opt/academia/
scp -r assets lws-nexiom:/opt/academia/
```
Note : `assets/images` est monté en lecture seule par le worker videoasset (filigrane).

## B2. Créer le fichier de secrets SUR LE SERVEUR
Reprends les valeurs depuis `.devin/deploy_vps_worker.py` ou demande-les au propriétaire.
**Ne les affiche jamais.**
```bash
ssh lws-nexiom "cd /opt/academia/academia_bobodo_backend
[ -f .env ] || cp .env.example .env
chmod 600 .env
grep -oE '^[A-Z_]+=' .env"
```
Complète ensuite `.env` sur le serveur (éditeur non interactif ou heredoc) avec au
minimum : `SUPABASE_SERVICE_KEY`, `OPENROUTER_API_KEY`. Laisse les autres vides si tu
n'as pas les valeurs, et **signale-le dans le rapport** plutôt que d'inventer.

## B3. Démarrer les conteneurs
```bash
ssh lws-nexiom "cd /opt/academia && docker compose up -d --build"
ssh lws-nexiom "docker ps -a"
```

## B4. Vérifier la santé
```bash
ssh lws-nexiom "sleep 20
echo '--- ffmpeg backend ---'; curl -sf http://localhost:8001/debug/ffmpeg || echo 'ECHEC 8001'
echo '--- ports en ecoute ---'; ss -tlnp | grep -E '8000|8001'
echo '--- logs backend ---'; docker logs --tail 30 academia-backend 2>&1
echo '--- logs videoasset ---'; docker logs --tail 20 academia-videoasset-worker 2>&1"
```

## B5. POINT À VÉRIFIER ET À RAPPORTER (ne corrige pas toi-même)
Le `docker-compose.yml` publie le backend sur le **port 8001** (`8001:8000`), or
l'application Flutter appelle Bobodo vocal sur `ws://<IP>:8000/ws`. Sur Kamatera, le
port 8000 est donc exposé autrement (processus hors conteneur, ou reverse proxy Nginx).
**Vérifie ce qui écoute sur le port 8000 et rapporte-le** — n'ajoute pas de mapping et
ne modifie pas `docker-compose.yml` de ta propre initiative :
```bash
ssh lws-nexiom "ss -tlnp | grep ':8000' || echo 'rien sur 8000'"
```

---

# RAPPORT À RENDRE

Pour chaque tâche exécutée, colle la **sortie brute complète** des commandes, dans
l'ordre, sans la résumer. Précise clairement :
1. Tâche A : résultat de A3 (`playwright OK` / `chromium lance OK` ?) et de A4 (`active` ?).
2. Tâche B : sortie de `docker ps -a`, résultat de `curl` sur 8001, et **ce qui écoute
   sur le port 8000** (point B5).
3. Toute variable `.env` que tu n'as pas pu renseigner faute de valeur.
4. Statut final : « terminé sans erreur » ou « arrêté à l'étape X » (avec l'erreur exacte).

Puis **arrête-toi**. Ne bascule aucune IP, ne touche pas à Kamatera, ne modifie pas le
dépôt. Claude valide ensuite par de vrais jobs via Supabase et procède lui-même à la
bascule applicative.
