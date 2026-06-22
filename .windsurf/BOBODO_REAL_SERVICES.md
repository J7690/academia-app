# BOBODO_REAL_SERVICES

**Timestamp :** 2026-06-12 20:11:49 UTC
**Commande :** `systemctl list-units --type=service --no-pager`

## Sortie brute (services vocaux et connexes)

```
UNIT                                     LOAD   ACTIVE SUB     DESCRIPTION
  bobodo-vocal.service                     loaded active running Bobodo Vocal Service
  containerd.service                       loaded active running containerd container runtime
  docker.service                           loaded active running Docker Application Container Engine
  nginx.service                            loaded active running A high performance web server and a reverse proxy server
  redis-server.service                     loaded active running Advanced key-value store
  ssh.service                              loaded active running OpenBSD Secure Shell server
```

## Service vocal détaillé

**Commande :** `systemctl status bobodo-vocal.service --no-pager`

```
● bobodo-vocal.service - Bobodo Vocal Service
     Loaded: loaded (/etc/systemd/system/bobodo-vocal.service; enabled; preset: enabled)
     Active: active (running) since Thu 2026-06-11 06:05:26 UTC; 1 day 14h ago
   Main PID: 125021 (python)
      Tasks: 18 (limit: 11864)
     Memory: 1.8G (peak: 2.1G)
        CPU: 5min 37.849s
     CGroup: /system.slice/bobodo-vocal.service
             └─125021 /opt/bobodo-vocal/venv/bin/python main.py
```

## Grep unit-files

| Filtre | Commande | Résultat |
|---|---|---|
| voice | `grep -i voice` | `NO_VOICE_SERVICE_FOUND` |
| bobodo | `grep -i bobodo` | `bobodo-vocal.service enabled enabled` |
| whisper | `grep -i whisper` | `NO_WHISPER_SERVICE_FOUND` |
| piper | `grep -i piper` | `NO_PIPER_SERVICE_FOUND` |

## Conclusion

- **Service actif et running :** `bobodo-vocal.service` (PID 125021)
- **Aucun service** `voice_server`, `whisper`, `piper` en tant qu'unité systemd
- **Chemin du processus :** `/opt/bobodo-vocal/venv/bin/python main.py`
