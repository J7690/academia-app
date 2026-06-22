# BOBODO VOICE REALITY REPORT

**Horodatage audit :** 2026-06-12 20:26:15 UTC
**Cible :** 185.167.97.144 (root)
**Méthode :** SSH via paramiko, commandes exécutées directement sur le serveur

---

## MISSION 1 — Services réellement installés

### Commande exécutée
```bash
systemctl list-units --type=service --no-pager
```

### Sortie obtenue (extrait pertinent)
```
UNIT                                     LOAD   ACTIVE SUB     DESCRIPTION
  bobodo-vocal.service                     loaded active running Bobodo Vocal Service
  containerd.service                       loaded active running containerd container runtime
  docker.service                           loaded active running Docker Application Container Engine
  nginx.service                            loaded active running A high performance web server and a reverse proxy server
  redis-server.service                     loaded active running Advanced key-value store
  ssh.service                              loaded active running OpenBSD Secure Shell server
```

### Commande exécutée
```bash
systemctl list-unit-files --type=service | grep -i bobodo
```

### Sortie obtenue
```
bobodo-vocal.service                         enabled         enabled
```

### Commande exécutée
```bash
systemctl list-unit-files --type=service | grep -i voice
```

### Sortie obtenue
```
NO_VOICE_SERVICE_FOUND
```

### Commande exécutée
```bash
systemctl list-unit-files --type=service | grep -i whisper
```

### Sortie obtenue
```
NO_WHISPER_SERVICE_FOUND
```

### Commande exécutée
```bash
systemctl list-unit-files --type=service | grep -i piper
```

### Sortie obtenue
```
NO_PIPER_SERVICE_FOUND
```

**Conclusion Mission 1 :**
- **UN SEUL service vocal existe :** `bobodo-vocal.service` — `loaded active running`
- Aucun service nommé `voice_server`, `whisper` ou `piper` n'existe en tant qu'unité systemd.

---

## MISSION 2 — Ports réellement ouverts

### Commande exécutée
```bash
ss -tulpn
```

### Sortie obtenue (extrait pertinent)
```
Netid State  Recv-Q Send-Q Local Address:Port Peer Address:PortProcess
udp   UNCONN 0      0         127.0.0.54:53        0.0.0.0:*    users:(("systemd-resolve",pid=124981,fd=16))
tcp   LISTEN 0      2048         0.0.0.0:8000      0.0.0.0:*    users:(("python",pid=125021,fd=14))
tcp   LISTEN 0      511        127.0.0.1:6379      0.0.0.0:*    users:(("redis-server",pid=124968,fd=6))
tcp   LISTEN 0      511          0.0.0.0:80        0.0.0.0:*    users:(("nginx",pid=...))
tcp   LISTEN 0      4096         0.0.0.0:22        0.0.0.0:*    users:(("sshd",pid=125314,fd=3))
tcp   LISTEN 0      4096               *:7881            *:*    users:(("livekit-server",pid=12935,fd=8))
tcp   LISTEN 0      4096               *:7880            *:*    users:(("livekit-server",pid=12935,fd=9))
```

### Commande exécutée
```bash
netstat -tulpn
```

### Sortie obtenue
```
NETSTAT_NOT_AVAILABLE
```

**Conclusion Mission 2 :**
- **Port 8000 ouvert** sur `0.0.0.0` — processus Python (pid 125021)
- Port 80 (nginx), 22 (ssh), 6379 (redis), 7880/7881 (livekit)

---

## MISSION 3 — Emplacements réels des fichiers

### Commande exécutée
```bash
find / -iname '*bobodo*' -not -path '/proc/*' -not -path '/sys/*' 2>/dev/null | head -30
```

### Sortie obtenue (extrait pertinent)
```
/opt/bobodo-vocal
/opt/bobodo-vocal/bobodo_client.py
/opt/bobodo-vocal/main.py
/opt/bobodo-vocal/stt_service.py
/opt/bobodo-vocal/tts_service.py
/opt/bobodo-vocal/websocket_handler.py
/etc/systemd/system/bobodo-vocal.service
/etc/systemd/system/multi-user.target.wants/bobodo-vocal.service
```

### Commande exécutée
```bash
find / -iname '*voice*' -not -path '/proc/*' -not -path '/sys/*' 2>/dev/null | head -30
```

### Sortie obtenue (extrait pertinent)
```
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/piper/voice.py
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/piper/download_voices.py
```

**Conclusion Mission 3 :**
- **Projet vocal réel :** `/opt/bobodo-vocal/`
- Aucun dossier `/root/voice_server/` n'existe.
- Aucun dossier `/root/bobodo-vocal/` n'existe.

---

## MISSION 4 — Existence des fichiers serveur demandés

| Fichier demandé | Chemin testé | Résultat |
|---|---|---|
| `main.py` | `/root/voice_server/main.py` | **ABSENT** |
| `websocket_handler.py` | `/root/voice_server/websocket_handler.py` | **ABSENT** |
| `stt_service.py` | `/root/voice_server/stt_service.py` | **ABSENT** |
| `tts_service.py` | `/root/voice_server/tts_service.py` | **ABSENT** |

**Fichiers existants trouvés ailleurs :**

### Commande exécutée
```bash
ls -la /opt/bobodo-vocal/
```

### Sortie obtenue
```
total 68
drwxr-xr-x 5 root root  4096 Jun 10 17:10 .
drwxr-xr-x 6 root root  4096 Jun 10 16:11 ..
-rw-r--r-- 1 root root  2698 Jun 10 17:26 bobodo_client.py
-rw-r--r-- 1 root root   909 Jun 10 16:18 docker-compose.yml
-rw-r--r-- 1 root root   719 Jun 10 16:43 Dockerfile
-rw-r--r-- 1 root root   729 Jun 10 17:14 .env
-rw-r--r-- 1 root root  3220 Jun 10 17:26 main.py
drwxr-xr-x 2 root root  4096 Jun 12 14:07 models
drwxr-xr-x 2 root root  4096 Jun 11 00:27 __pycache__
-rw-r--r-- 1 root root   208 Jun 10 17:26 requirements.txt
-rw-r--r-- 1 root root 11038 Jun 11 00:27 stt_service.py
-rw-r--r-- 1 root root  2479 Jun 10 17:26 tts_service.py
drwxr-xr-x 5 root root  4096 Jun 10 17:23 venv
-rw-r--r-- 1 root root  6291 Jun 11 00:27 websocket_handler.py
```

**Conclusion Mission 4 :**
- Les 4 fichiers demandés (`main.py`, `websocket_handler.py`, `stt_service.py`, `tts_service.py`) n'existent PAS dans `/root/voice_server/`.
- Ils existent dans `/opt/bobodo-vocal/` avec des tailles et dates confirmées.

---

## MISSION 5 — Modèles réels

### Commande exécutée
```bash
du -sh /opt/bobodo-vocal/models/
```

### Sortie obtenue
```
904K	/opt/bobodo-vocal/models/
```

### Commande exécutée
```bash
ls -lh /opt/bobodo-vocal/models/model.onnx
```

### Sortie obtenue
```
-rw-r--r-- 1 root root 299K Jun 12 14:12 /opt/bobodo-vocal/models/model.onnx
```

### Commande exécutée
```bash
du -sh /root/.cache/huggingface/hub/models--Systran--faster-whisper-medium/
```

### Sortie obtenue
```
1.5G	/root/.cache/huggingface/hub/models--Systran--faster-whisper-medium/
```

**Conclusion Mission 5 :**
- **Modèle Piper :** `/opt/bobodo-vocal/models/model.onnx` — **299K** (créé le 12 juin 2026 à 14:12)
- **Modèle Faster Whisper :** `/root/.cache/huggingface/hub/models--Systran--faster-whisper-medium/` — **1.5G**

---

## MISSION 6 — Test des endpoints

### Commande exécutée
```bash
curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:8000/
```

### Sortie obtenue
```
404
```

### Commande exécutée
```bash
curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://127.0.0.1:8000/
```

### Sortie obtenue
```
404
```

### Commande exécutée
```bash
curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:8000/ws
```

### Sortie obtenue
```
404
```

### Commande exécutée
```bash
curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://185.167.97.144:8000/
```

### Sortie obtenue
```
404
```

### Commande exécutée
```bash
curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:8000/health
```

### Sortie obtenue
```
200
```

**Logs du service confirmant les requêtes :**
```
Jun 12 20:26:15 academia00 python[125021]: INFO:     127.0.0.1:42028 - "GET /health HTTP/1.1" 200 OK
Jun 12 20:26:16 academia00 python[125021]: INFO:     127.0.0.1:42032 - "GET /ws HTTP/1.1" 404 Not Found
```

**Conclusion Mission 6 :**
- Le serveur HTTP sur le port 8000 **répond** (pas de timeout, pas de connexion refusée).
- `/health` retourne **200 OK**.
- `/` et `/ws` retournent **404 Not Found**.
- Le endpoint WebSocket `/ws` n'existe pas sur ce serveur.

---

## MISSION 7 — Comparatif : ÉTAT DOCUMENTÉ vs ÉTAT RÉEL

| Élément | Annoncé / Documenté | Observé / Réel | Validé |
|---|---|---|---|
| Service systemd `voice_server` | Exister dans `/etc/systemd/system/voice_server.service` | **ABSENT** — aucun service `voice_server` | ❌ INVALIDE |
| Service systemd `bobodo-vocal` | Non mentionné dans les rapports précédents | **`loaded active running`** depuis le 11 juin | ✅ VALIDÉ (réel mais non documenté) |
| Répertoire `/root/voice_server/` | Contient `main.py`, `tts_service.py`, etc. | **ABSENT** — dossier inexistant | ❌ INVALIDE |
| Répertoire `/opt/bobodo-vocal/` | Non documenté | **EXISTE** — contient tous les fichiers source | ✅ VALIDÉ (réel mais non documenté) |
| Port 8000 | Écoute par le serveur vocal | **OUVERT** — process Python pid 125021 | ✅ VALIDÉ |
| Endpoint `/ws` | WebSocket pour TTS audio | **404 Not Found** — route inexistante | ❌ INVALIDE |
| Endpoint `/health` | Non documenté | **200 OK** — fonctionne | ✅ VALIDÉ (réel mais non documenté) |
| Modèle Piper | Présent dans `/root/piper_voices/` | **ABSENT** de `/root/piper_voices/` | ❌ INVALIDE |
| Modèle Piper réel | Non documenté | **`/opt/bobodo-vocal/models/model.onnx`** (299K) | ✅ VALIDÉ (réel mais non documenté) |
| Modèle Faster Whisper | Présent | **`/root/.cache/huggingface/hub/models--Systran--faster-whisper-medium/`** (1.5G) | ✅ VALIDÉ |
| Nginx reverse proxy pour 8000 | Non documenté | **ABSENT** — seul `livekit` est configuré | ❌ INVALIDE (pas de proxy pour le vocal) |
| Processus Python vocal | `/root/voice_server/venv/bin/python` | **`/opt/bobodo-vocal/venv/bin/python main.py`** | ❌ INVALIDE (chemin différent) |

---

## Conclusion finale

### A) Vocal réellement déployé

**OUI — avec réserves techniques.**

Preuves :
1. `bobodo-vocal.service` est `active (running)` depuis le 11 juin 2026, PID 125021.
2. Un processus Python `/opt/bobodo-vocal/venv/bin/python main.py` écoute sur le port 8000.
3. Les fichiers source (`main.py`, `stt_service.py`, `tts_service.py`, `websocket_handler.py`) existent dans `/opt/bobodo-vocal/`.
4. Les modèles sont présents : Piper (299K ONNX) et Faster Whisper (1.5G).
5. L'endpoint `/health` retourne 200.

### B) Mais non conforme à la documentation

- Le service ne s'appelle pas `voice_server` mais `bobodo-vocal`.
- Les fichiers ne sont pas dans `/root/voice_server/` mais dans `/opt/bobodo-vocal/`.
- Le endpoint WebSocket `/ws` retourne 404 — il n'y a **pas de preuve** qu'une route WebSocket fonctionne actuellement.
- Aucun reverse nginx n'expose le port 8000 (seul LiveKit est proxifié).

---

**Fichiers de preuve bruts :**
- `BOBODO_VOICE_REALITY_AUDIT_RAW.txt` — sorties complètes des commandes
- `BOBODO_AUDIT_PHASE2.txt` — logs service, fichiers, endpoints, modèles
