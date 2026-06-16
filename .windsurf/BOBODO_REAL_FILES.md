# BOBODO_REAL_FILES

**Timestamp :** 2026-06-12 20:11:49 UTC

---

## 1. Recherche globale

### Commande
```bash
find / -iname '*bobodo*' -not -path '/proc/*' -not -path '/sys/*' 2>/dev/null | head -30
```

### Résultat
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

### Commande
```bash
find / -iname '*voice*' -not -path '/proc/*' -not -path '/sys/*' 2>/dev/null | head -30
```

### Résultat (extrait pertinent)
```
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/piper/voice.py
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/piper/download_voices.py
```

---

## 2. Fichiers serveur demandés — Test d'existence

| Fichier | Chemin testé | Commande | Résultat |
|---|---|---|---|
| `main.py` | `/root/voice_server/main.py` | `ls -la` | **ABSENT** (`No such file or directory`) |
| `websocket_handler.py` | `/root/voice_server/websocket_handler.py` | `ls -la` | **ABSENT** |
| `stt_service.py` | `/root/voice_server/stt_service.py` | `ls -la` | **ABSENT** |
| `tts_service.py` | `/root/voice_server/tts_service.py` | `ls -la` | **ABSENT** |

---

## 3. Fichiers réels trouvés

### Commande
```bash
ls -la /opt/bobodo-vocal/
```

### Résultat
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

### Commande
```bash
ls -la /root/bobodo-vocal/ 2>&1 || echo 'DIR_NOT_FOUND'
```

### Résultat
```
ls: cannot access '/root/bobodo-vocal/': No such file or directory
DIR_NOT_FOUND
```

---

## 4. Modèles

### Piper

**Commande :** `ls -lh /opt/bobodo-vocal/models/model.onnx`

**Résultat :**
```
-rw-r--r-- 1 root root 299K Jun 12 14:12 /opt/bobodo-vocal/models/model.onnx
```

**Commande :** `du -sh /opt/bobodo-vocal/models/`

**Résultat :**
```
904K	/opt/bobodo-vocal/models/
```

### Faster Whisper

**Commande :** `du -sh /root/.cache/huggingface/hub/models--Systran--faster-whisper-medium/`

**Résultat :**
```
1.5G	/root/.cache/huggingface/hub/models--Systran--faster-whisper-medium/
```

---

## Conclusion

- **Les 4 fichiers demandés (`main.py`, `websocket_handler.py`, `stt_service.py`, `tts_service.py`) sont ABSENTS de `/root/voice_server/`.**
- **Ils existent dans `/opt/bobodo-vocal/` avec des tailles et dates confirmées.**
- **Modèle Piper :** `/opt/bobodo-vocal/models/model.onnx` (299K, modifié le 12 juin 2026 à 14:12)
- **Modèle Whisper :** `/root/.cache/huggingface/hub/models--Systran--faster-whisper-medium/` (1.5G)
