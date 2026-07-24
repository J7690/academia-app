# Instructions Windsurf — Installation COMPLÈTE sur le nouveau serveur LWS (exécution stricte)

Tu es un agent d'exécution. Kamatera est hors-jeu. Tu vas installer **tout le pipeline
Smart Whiteboard** sur le **serveur LWS vierge**, puis le configurer. Fais **EXACTEMENT**
les étapes ci-dessous, dans l'ordre, et **RIEN d'autre**. Aucune initiative.

## RÈGLES ABSOLUES (obligatoires)
1. Accès serveur : **uniquement** via l'alias SSH `lws-nexiom` (clé déjà configurée, root@31.207.38.60).
2. NE JAMAIS lire, copier, afficher ou committer la clé privée `C:/Users/fasop/.ssh/id_ed25519`.
3. NE JAMAIS écrire de secret dans le dépôt Git ni dans un fichier `.windsurf` versionné.
   Les secrets vont **uniquement** dans `/opt/whiteboard-worker/.env` **sur le serveur**.
4. NE PAS modifier de code du dépôt. NE PAS toucher à Supabase (Claude s'en charge).
5. NE PAS modifier le pare-feu / UFW / iptables / sshd_config. NE RIEN supprimer hors des
   dossiers `/opt/whiteboard-worker` et `/opt/whiteboard-engine-remotion`.
   Si une de ces opérations semble nécessaire → **STOP + demande au propriétaire**.
6. À la moindre erreur ou sortie inattendue → **STOP + rapport**. Ne tente pas de contourner.
7. Aucun port entrant n'est requis (le worker sort vers Supabase). Ne touche pas au réseau.

## GESTION DES SECRETS (réponse à « comment ne pas exposer les clés »)
- **SSH** : déjà réglé par clé (`lws-nexiom`). Rien à exposer, la clé privée reste locale.
- **Secrets applicatifs** (Supabase) : ils vivent SEULEMENT dans `/opt/whiteboard-worker/.env`
  **sur le serveur**, créé par SSH (Étape 3). Jamais dans Git, jamais affiché en clair, jamais
  dans `.windsurf`.
- Valeur de `SUPABASE_SERVICE_KEY` : reprends-la depuis `.devin/deploy_vps_worker.py`
  (variable `SERVICE_KEY`) OU demande-la au propriétaire. Ne l'imprime pas dans les logs.
- Claude n'a PAS besoin de ces secrets : il passe par Supabase. Le serveur poussera sa
  « balise » vers Supabase, et Claude lira l'état de là.

---

## ÉTAPE 0 — Vérifier l'accès
```bash
ssh lws-nexiom "echo OK && lsb_release -d && nproc && df -h / | tail -1"
```
Attendu : `OK`, Ubuntu 24.04, 4 CPU, ~146 Go libres. Sinon → STOP + rapport.

## ÉTAPE 1 — Créer les dossiers cibles
```bash
ssh lws-nexiom "mkdir -p /opt/whiteboard-worker && rm -rf /opt/whiteboard-engine-remotion"
```

## ÉTAPE 2 — Copier les fichiers (depuis la racine du dépôt academia/)
```bash
scp academia_bobodo_backend/whiteboard_render_worker.py ^
    academia_bobodo_backend/whiteboard_png_renderer.py ^
    academia_bobodo_backend/whiteboard_ffmpeg_assembler.py ^
    academia_bobodo_backend/whiteboard_upload_renderer.py ^
    lws-nexiom:/opt/whiteboard-worker/
scp -r whiteboard_engine_remotion lws-nexiom:/opt/whiteboard-engine-remotion
```
(Le `^` est la continuation de ligne PowerShell/CMD ; sinon mets tout sur une seule ligne.)

## ÉTAPE 3 — Créer le fichier de secrets `.env` SUR LE SERVEUR
Remplace `COLLE_ICI_LA_SERVICE_KEY` par la valeur de `SERVICE_KEY` trouvée dans
`.devin/deploy_vps_worker.py` (ne l'affiche pas ailleurs). Puis :
```bash
ssh lws-nexiom "cat > /opt/whiteboard-worker/.env <<'EOF'
SUPABASE_URL=https://thevdfcwlcqzdoybfvgs.supabase.co
SUPABASE_SERVICE_KEY=COLLE_ICI_LA_SERVICE_KEY
WORKER_LOOP=1
WORKER_INTERVAL_SECONDS=2
WORKER_MAX_JOBS=1
REMOTION_ENGINE_DIR=/opt/whiteboard-engine-remotion
KOKORO_URL=http://127.0.0.1:8880/v1/audio/speech
KOKORO_VOICE=ff_siwis
KOKORO_MODEL=kokoro
KOKORO_SPEED=0.95
EOF
chmod 600 /opt/whiteboard-worker/.env"
```

## ÉTAPE 4 — Lancer le bootstrap complet (installe TOUT sur le serveur)
```bash
ssh lws-nexiom "bash /opt/whiteboard-engine-remotion/deploy/bootstrap_lws.sh"
```
Le script installe : ffmpeg, deps Python, Node 20, dépendances du moteur + Chromium,
Docker + Kokoro (voix), le **service systemd** `whiteboard-worker`, fait un **rendu de test**,
et publie la **balise de santé** vers Supabase. Laisse-le se dérouler et **copie toute la sortie**.

## CE QUE LA SORTIE DOIT MONTRER (sinon STOP + rapport)
- `node -v` : v20.x.
- « Rendu de test » : `✅ Rendu de test : /tmp/pro.mp4` + `ffprobe` = `profile=Main level=40 720 1280`.
- Service : `active (running)` pour `whiteboard-worker`.
- « Balise de santé » : se termine sans erreur.

## CONDITIONS D'ARRÊT IMMÉDIAT (STOP + rapport, ne rien tenter d'autre)
- Toute commande en erreur, tout `❌`, tout `⚠️`.
- `.env` refusé / clé absente.
- Besoin apparent de toucher au pare-feu, à `sshd`, ou de supprimer autre chose.

## RAPPORT À RENDRE (obligatoire, texte brut)
1. Sortie complète de l'Étape 4 (bootstrap), du début à la fin.
2. La ligne `ffprobe` (profil/level/résolution).
3. `systemctl is-active whiteboard-worker` → résultat.
4. Statut final : « terminé sans erreur » ou « arrêté à l'étape X ».
Puis **arrête-toi**. Claude lira `app.whiteboard_engine_health` côté Supabase et fera la
validation finale + un job de rendu de test. Tu n'as rien d'autre à faire.
