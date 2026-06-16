# BOBODO_REAL_PORTS

**Timestamp :** 2026-06-12 20:11:49 UTC
**Commande :** `ss -tulpn`

## Sortie brute

```
Netid State  Recv-Q Send-Q Local Address:Port Peer Address:PortProcess
udp   UNCONN 0      0         127.0.0.54:53        0.0.0.0:*    users:(("systemd-resolve",pid=124981,fd=16))
udp   UNCONN 0      0      127.0.0.53%lo:53        0.0.0.0:*    users:(("systemd-resolve",pid=124981,fd=14))
tcp   LISTEN 0      2048         0.0.0.0:8000      0.0.0.0:*    users:(("python",pid=125021,fd=14))
tcp   LISTEN 0      511        127.0.0.1:6379      0.0.0.0:*    users:(("redis-server",pid=124968,fd=6))
tcp   LISTEN 0      511          0.0.0.0:80        0.0.0.0:*    users:(("nginx",pid=124964,fd=5),("nginx",pid=124963,fd=5),("nginx",pid=124962,fd=5),("nginx",pid=124961,fd=5),("nginx",pid=124960,fd=5))
tcp   LISTEN 0      4096         0.0.0.0:22        0.0.0.0:*    users:(("sshd",pid=125314,fd=3),("systemd",pid=1,fd=155))
tcp   LISTEN 0      4096      127.0.0.54:53        0.0.0.0:*    users:(("systemd-resolve",pid=124981,fd=17))
tcp   LISTEN 0      511            [::1]:6379         [::]:*    users:(("redis-server",pid=124968,fd=7))
tcp   LISTEN 0      4096               *:7881            *:*    users:(("livekit-server",pid=12935,fd=8))
tcp   LISTEN 0      4096               *:7880            *:*    users:(("livekit-server",pid=12935,fd=9))
tcp   LISTEN 0      4096            [::]:22           [::]:*    users:(("sshd",pid=125314,fd=4),("systemd",pid=1,fd=156))
```

**Commande :** `netstat -tulpn`

```
NETSTAT_NOT_AVAILABLE
```

## Tableau récapitulatif

| Port | Protocole | État | Processus | Note |
|---|---|---|---|---|
| 8000 | TCP | LISTEN | python (pid 125021) | **Serveur vocal Bobodo** |
| 80 | TCP | LISTEN | nginx | Reverse proxy (livekit uniquement) |
| 22 | TCP | LISTEN | sshd | SSH |
| 6379 | TCP | LISTEN | redis-server | Cache |
| 7880 | TCP | LISTEN | livekit-server | LiveKit |
| 7881 | TCP | LISTEN | livekit-server | LiveKit |
| 53 | UDP/TCP | UNCONN/LISTEN | systemd-resolve | DNS local |

## Conclusion

- **Port 8000 ouvert et actif** — lié au processus Python du service vocal.
- Aucun autre port vocal détecté.
