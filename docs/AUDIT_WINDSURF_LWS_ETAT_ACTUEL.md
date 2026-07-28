# Audit LWS — état actuel (LECTURE SEULE, aucune modification)

**Destinataire** : Windsurf.
**Objectif unique** : cartographier ce qui existe déjà sur le serveur LWS
(`lws-nexiom`, root@31.207.38.60) et rapporter le résultat brut. **Rien d'autre.**

## RÈGLES ABSOLUES (lecture seule stricte)

1. **Aucune commande d'écriture, d'installation ou de modification.** Interdits :
   `apt install`, `npm install`, `docker run`/`docker compose up`, `systemctl start`/
   `stop`/`enable`/`restart`, `mkdir`, `touch`, `rm`, `cp`, `mv`, `>` ou `>>` vers un
   fichier, `git commit`/`push`, édition de fichier (`nano`, `vim`, `sed -i`), création
   de clé SSH, changement de permissions. Si une commande ci-dessous semblait pouvoir en
   entraîner une autre par accident, ne l'exécute pas et note-le dans le rapport.
2. **N'affiche jamais le contenu d'un secret.** Pour les fichiers `.env` ou toute config
   contenant des clés/mots de passe : liste seulement les **noms des variables**
   (`grep -oE '^[A-Z_]+=' fichier`), jamais leur valeur. N'utilise pas `cat` sur un
   fichier `.env`.
3. Aucune commande interactive (pas de `nano`, pas de prompts) — tout doit tourner en
   non-interactif via `ssh lws-nexiom "..."`.
4. À la moindre commande qui échoue, **continue** avec la suivante (ce n'est pas un
   script de déploiement, un échec de lecture n'est pas bloquant) — note juste l'échec
   dans le rapport.
5. Ne touche à aucun autre serveur (Kamatera, 185.167.97.144) dans le cadre de cet audit.

## Ce qu'il faut vérifier (exécute chaque bloc, copie la sortie telle quelle)

### 1. Identité et ressources du serveur
```bash
ssh lws-nexiom "echo '--- OS ---'; lsb_release -d
echo '--- CPU ---'; nproc
echo '--- RAM ---'; free -h
echo '--- DISQUE ---'; df -h /
echo '--- UPTIME ---'; uptime"
```

### 2. Ce qui est installé (versions, présence)
```bash
ssh lws-nexiom "echo '--- node ---'; command -v node && node -v
echo '--- npm ---'; command -v npm && npm -v
echo '--- python3 ---'; command -v python3 && python3 --version
echo '--- ffmpeg ---'; command -v ffmpeg && ffmpeg -version | head -1
echo '--- docker ---'; command -v docker && docker --version
echo '--- redis-server ---'; command -v redis-server && redis-server --version
echo '--- nginx ---'; command -v nginx && nginx -v
echo '--- livekit-server ---'; command -v livekit-server && livekit-server --version"
```

### 3. Arborescence des dossiers de déploiement attendus
```bash
ssh lws-nexiom "echo '--- /opt ---'; ls -la /opt/ 2>&1
echo '--- /opt/whiteboard-worker ---'; ls -la /opt/whiteboard-worker/ 2>&1
echo '--- /opt/whiteboard-engine-remotion ---'; ls -la /opt/whiteboard-engine-remotion/ 2>&1
echo '--- /opt/academia ---'; ls -la /opt/academia/ 2>&1
echo '--- /opt/academia-backend ---'; ls -la /opt/academia-backend/ 2>&1
echo '--- /opt/livekit ---'; ls -la /opt/livekit/ 2>&1"
```

### 4. Variables de config présentes (NOMS SEULEMENT, jamais les valeurs)
```bash
ssh lws-nexiom "for f in /opt/whiteboard-worker/.env /opt/academia-backend/.env /opt/academia/academia_bobodo_backend/.env /opt/livekit/livekit.yaml; do
echo \"--- \$f ---\"
[ -f \"\$f\" ] && grep -oE '^[A-Za-z_]+' \"\$f\" || echo 'absent'
done"
```

### 5. Services systemd (lesquels existent, actifs ou non)
```bash
ssh lws-nexiom "systemctl list-units --type=service --all | grep -iE 'whiteboard|academia|livekit|redis|nginx|kokoro' 2>&1
echo '--- statuts détaillés ---'
for s in whiteboard-worker academia-node academia-backend livekit-server redis-server nginx; do
echo \">> \$s\"; systemctl is-active \$s 2>&1; systemctl is-enabled \$s 2>&1
done"
```

### 6. Conteneurs Docker en cours (le cas échéant)
```bash
ssh lws-nexiom "docker ps -a 2>&1"
```

### 7. Ports en écoute
```bash
ssh lws-nexiom "ss -tlnp 2>&1 || netstat -tlnp 2>&1"
```

### 8. Dernières lignes de logs pertinents (lecture seule, pas de -f)
```bash
ssh lws-nexiom "for s in whiteboard-worker academia-node livekit-server; do
echo \">> journal \$s (20 dernières lignes)\"
journalctl -u \$s -n 20 --no-pager 2>&1
done"
```

## RAPPORT À RENDRE

Colle la sortie **complète et brute** des 8 blocs ci-dessus, dans l'ordre, sans les
résumer ni les interpréter. Précise en une ligne si un bloc a échoué (et pourquoi si
visible). Puis **arrête-toi** — n'installe rien, ne corrige rien, même si tu vois un
service manquant ou arrêté. C'est Claude qui interprète le rapport et décide de la
suite avec le propriétaire du projet.
