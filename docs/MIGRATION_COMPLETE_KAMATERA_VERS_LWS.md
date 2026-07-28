# Migration complète Kamatera → LWS (tout le dispositif, décommission définitive)

**Décidé le** : 25 juillet 2026, par le propriétaire du projet.
**Portée** : TOUT ce qui tourne aujourd'hui sur Kamatera (185.167.97.144) doit être
reproduit et validé sur LWS (31.207.38.60, alias SSH `lws-nexiom`), puis Kamatera doit
être définitivement arrêté. Ce document remplace/complète `INSTRUCTIONS_WINDSURF_LWS.md`
(qui ne couvrait que le moteur Remotion) et rend obsolètes `GO_LIVE_remotion.md` /
`INSTRUCTIONS_WINDSURF_GOLIVE.md` (ciblaient encore Kamatera).

## Règle d'or (non négociable)

**On n'éteint JAMAIS un service sur Kamatera avant que son équivalent sur LWS soit
installé, testé, ET validé en conditions réelles.** Chaque phase ci-dessous suit le
même schéma : installer sur LWS → tester en isolation → basculer le trafic (secret/DNS)
→ observer → seulement alors, désactiver l'ancien service sur Kamatera. La décommission
totale de Kamatera est la toute dernière étape, une fois les 4 phases validées.

## Pourquoi ce document existe (contexte pour Claude et pour Windsurf)

Un audit du 25 juillet a montré que Kamatera héberge en réalité **quatre familles de
services distincts**, pas seulement le smart whiteboard : le pipeline whiteboard, le
pipeline vidéo (compression/upload), LiveKit (appels en direct + Redis + Nginx), et un
backend Node séparé (API REST/connecteurs). Une décision d'architecture antérieure
(13-14 juillet, `ACADEMIA_ARCHITECTURE_DECISIONS.md`) recommandait de sortir LiveKit
vers LiveKit Cloud précisément pour éviter la contention CPU/RAM entre ces charges sur
une seule machine — c'est d'ailleurs cette contention qui a fait planter Remotion le 23
juillet (heap Node out-of-memory, voir `app.whiteboard_renders`). Le propriétaire du
projet a choisi de tout auto-héberger sur LWS quand même : **ce choix est acté, mais il
rend le dimensionnement RAM de LWS (Étape 0) critique** — ne pas sauter cette vérification.

---

## Inventaire des services à migrer

| # | Service | Rôle | Port(s) sur Kamatera | Dépendances |
|---|---|---|---|---|
| 1 | `whiteboard-worker` (vision + remotion) | Rendu vidéo Smart Whiteboard | — (poll Supabase) | Node 20, Chromium, ffmpeg, Kokoro |
| 2 | Kokoro TTS | Voix off whiteboard | 8880 (local) | Docker |
| 3 | `academia-backend` (Python/ffmpeg) | Compression + watermark vidéo | 8001→8000 | ffmpeg |
| 4 | `academia-videoasset-worker` | Upload/traitement assets vidéo | — (poll Supabase) | ffmpeg |
| 5 | LiveKit server | Appels/cours en direct (SFU) | 7880 | Redis |
| 6 | Redis | État LiveKit | 6379 (local) | — |
| 7 | Nginx | Reverse proxy / statut | 80 | — |
| 8 | LiveKit Egress | Enregistrement → Supabase Storage | — | LiveKit, ffmpeg |
| 9 | `academia-node` | API REST + connecteurs (FB/IG/WhatsApp/Google/Stripe) | 4000 | — |

Les services 1-4 (whiteboard + vidéo) sont prioritaires : c'est le chantier en cours et
la cause du blocage actuel. Les services 5-8 (LiveKit) sont une charge de travail
séparée mais doivent migrer aussi (décision du propriétaire). Le service 9 est
indépendant et peut migrer en dernier, sans urgence.

---

## ÉTAPE 0 — Vérifier LWS avant tout (obligatoire, ne pas sauter)

```powershell
ssh lws-nexiom "echo OK && lsb_release -d && nproc && free -h && df -h / | tail -1"
```
Attendu : Ubuntu 24.04, 4 CPU, **au moins 8 Go de RAM libre** (idéalement 16 Go — c'est le
point qui a fait planter Remotion sur Kamatera), ~146 Go disque libre. Si la RAM est
insuffisante → **STOP, remonte l'info au propriétaire** avant d'installer quoi que ce
soit (mieux vaut upgrader LWS maintenant que revivre le crash du 23 juillet).

---

## PHASE 1 — Pipeline Smart Whiteboard (priorité 1)

Reprend `INSTRUCTIONS_WINDSURF_LWS.md` (déjà rédigé, toujours valide), avec un ajout
obligatoire : le correctif mémoire, pour ne pas reproduire le crash `JavaScript heap out
of memory` observé deux fois le 23 juillet sur Kamatera (jobs `211914e2` et `9c34fa1d`
dans `app.whiteboard_renders`).

### 1.1 — Correctif mémoire à appliquer AVANT le premier rendu de test
Dans `whiteboard_engine_remotion/deploy/bootstrap_lws.sh` (ou juste avant de lancer
`render.mjs`), fixer explicitement la limite de heap Node et précharger les polices au
lieu de les laisser se télécharger à la volée pendant le rendu :
```bash
export NODE_OPTIONS="--max-old-space-size=6144"   # ajuster selon la RAM réelle de LWS (Étape 0)
```
Et dans `whiteboard_engine_remotion/src/` (Windsurf ne doit PAS modifier de code du
dépôt de son propre chef — si un fichier source doit changer pour précharger les
polices, **Claude s'en charge en amont**, pas Windsurf).

### 1.2 — Exécution
Suivre `INSTRUCTIONS_WINDSURF_LWS.md` Étapes 0 à 4 telles quelles (déjà écrites,
toujours correctes : copie des fichiers, `.env`, `bootstrap_lws.sh`).

### 1.3 — Validation (avant de couper Kamatera pour ce service)
- `app.whiteboard_engine_health.host` doit passer de `vps122603` à l'hôte LWS.
- Lancer 2-3 rendus de test réels avec `engine=remotion` **et** `engine=vision` depuis
  l'app (pas de simulation) → tous `status=done` dans `app.whiteboard_renders`, aucun
  `error_message` contenant `heap` ou `OOM`.
- Repasser `academia_app/lib/.../smart_whiteboard_provider.dart` ligne ~202 de
  `'engine': 'vision'` à `'engine': 'remotion'` **seulement après** validation ci-dessus
  — Claude s'en charge, pas Windsurf (règle : ne pas toucher au code du dépôt).

---

## PHASE 2 — Pipeline vidéo (compression, upload, watermark)

### 2.1 — Ce qui doit être installé sur LWS
Le container `academia-backend` (Python + ffmpeg, sert `/compress` sur le port 8001) et
`academia-videoasset-worker`. Reprendre `docker-compose.yml` du dépôt tel quel — il ne
contient aucune IP en dur, il suffit de le déployer sur LWS :
```bash
scp -r academia_bobodo_backend docker-compose.yml lws-nexiom:/opt/academia/
ssh lws-nexiom "cd /opt/academia && cp academia_bobodo_backend/.env.example academia_bobodo_backend/.env"
# Remplir .env sur le serveur (SUPABASE_SERVICE_KEY, OPENROUTER_API_KEY, etc. — jamais dans Git)
ssh lws-nexiom "cd /opt/academia && docker compose up -d --build"
```

### 2.2 — Validation
```bash
ssh lws-nexiom "curl -sf http://localhost:8000/debug/ffmpeg"
```
Puis tester `compress-video` réellement (upload d'une courte vidéo test dans l'app) —
**seulement après** avoir basculé le secret `LIVEKIT_URL` en Phase 3 (voir plus bas :
`compress-video` dérive son hôte de ce même secret depuis le correctif appliqué
aujourd'hui par Claude, donc les Phases 2 et 3 sont liées pour ce point précis).

---

## PHASE 3 — LiveKit + Redis + Nginx + Egress

### 3.1 — Installation LiveKit self-hosted sur LWS
```bash
ssh lws-nexiom "curl -sSL https://get.livekit.io | bash"
ssh lws-nexiom "livekit-server generate-keys"   # note l'API Key / Secret générés
```
Config minimale (`/opt/livekit/livekit.yaml` sur LWS) :
```yaml
port: 7880
rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: true
redis:
  address: localhost:6379
keys:
  <API_KEY>: <API_SECRET>
```
Redis (local, jamais exposé publiquement — cf. avertissement sécurité ci-dessous) :
```bash
ssh lws-nexiom "apt-get install -y redis-server && systemctl enable --now redis-server"
```
Service systemd LiveKit + Nginx en reverse proxy : mêmes principes que l'installation
Kamatera actuelle (voir `academia_app/docs/INFRASTRUCTURE_KAMATERA.md` pour la
configuration de référence à reproduire, en remplaçant l'IP par celle de LWS).

**Sécurité, important** : Redis doit être bindé sur `127.0.0.1` uniquement (jamais
`0.0.0.0`) — un Redis exposé publiquement compromet tout l'état des sessions LiveKit.

### 3.2 — Validation AVANT bascule
Lancer une session live de test (rôle enseignant → « Mes classes en direct ») pointée
**manuellement** vers `ws://<IP_LWS>:7880` (variable d'environnement temporaire côté
test, pas encore le secret de prod) : connexion, chat, enregistrement, coupure micro à
distance doivent tous fonctionner.

### 3.3 — Bascule (secrets Supabase, un seul point de bascule pour LiveKit + vidéo)
```bash
supabase secrets set LIVEKIT_URL="ws://<IP_LWS>:7880"
supabase secrets set LIVEKIT_API_KEY="<nouvelle clé générée à l'étape 3.1>"
supabase secrets set LIVEKIT_API_SECRET="<nouveau secret généré à l'étape 3.1>"
supabase functions deploy livekit-token
supabase functions deploy livekit-recording
supabase functions deploy livekit-admin
supabase functions deploy transcode-multi-resolution
supabase functions deploy compress-video
```
`compress-video` et `transcode-multi-resolution` dérivent désormais automatiquement leur
hôte VPS depuis `LIVEKIT_URL` (correctif appliqué aujourd'hui par Claude, déployé en
v23) — un seul secret fait basculer LiveKit **et** la compression/transcodage vidéo en
même temps. C'est pour ça que Phase 2 et Phase 3 doivent être validées ensemble avant
la bascule finale.

### 3.4 — Validation post-bascule (test réel, pas de simulation)
- Session live réelle depuis l'app en prod → fonctionne de bout en bout.
- Upload + compression d'une vidéo réelle depuis l'app → `compress-video` répond 200.
- Vérifier les logs Supabase (`get_logs` service `edge-function`) : aucune erreur de
  connexion vers l'ancienne IP Kamatera.

---

## PHASE 4 — `academia-node` (API REST, connecteurs) — sans urgence

```bash
bash academia-backend/scripts/deploy-from-local.sh   # avec VPS_HOST=<IP_LWS>
```
Valider : `curl http://<IP_LWS>:4000/api/health`.

---

## DÉCOMMISSION KAMATERA (dernière étape, uniquement après validation des 4 phases)

1. Confirmation explicite du propriétaire du projet (« GO décommission »).
2. Sur Kamatera : arrêter les services un par un (`docker compose down`, `systemctl stop
   livekit-server redis-server nginx`), observer 24-48h qu'aucun trafic ne les
   sollicite plus (logs vides), **avant** de résilier l'instance Kamatera elle-même.
3. Mettre à jour `academia_app/docs/INFRASTRUCTURE_KAMATERA.md` (renommé/archivé) et
   `docs/ACADEMIA_ARCHITECTURE_DECISIONS.md` avec un nouvel ADR documentant la bascule
   complète vers LWS, conformément au protocole de gouvernance documentaire du projet.
4. Marquer `docs/GO_LIVE_remotion.md`, `docs/INSTRUCTIONS_WINDSURF_GOLIVE.md` comme
   obsolètes (remplacés par ce document).

## Rollback (à tout moment avant la décommission)

Kamatera reste actif et inchangé jusqu'à l'étape finale : il suffit de restaurer les
anciens secrets Supabase (`LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` vers
185.167.97.144) et de redéployer les mêmes Edge Functions pour revenir à l'état actuel
en quelques minutes, sans aucun redéploiement Flutter.
