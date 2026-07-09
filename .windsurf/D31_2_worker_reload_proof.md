# D31_2_worker_reload_proof.md

**Date :** 2026-06-30T18:07:02Z

---

## 1. PID avant redémarrage

`526693`

## 2. Suppression des pycache

Commande : `rm -rf /opt/whiteboard-worker/__pycache__`

Résultat : erreur = ``

## 3. Redémarrage

Commande : `systemctl restart whiteboard-worker`

Résultat : erreur = ``

## 4. PID après redémarrage

`527612`

**PID différent :** `True`

## 5. Statut du service après redémarrage

```
● whiteboard-worker.service - Whiteboard Render Worker Service
     Loaded: loaded (/etc/systemd/system/whiteboard-worker.service; enabled; preset: enabled)
     Active: active (running) since Tue 2026-06-30 18:06:54 UTC; 5s ago
   Main PID: 527612 (python3)
      Tasks: 2 (limit: 11864)
     Memory: 28.2M (peak: 28.7M)
        CPU: 558ms
     CGroup: /system.slice/whiteboard-worker.service
             └─527612 /usr/bin/python3 /opt/whiteboard-worker/whiteboard_render_worker.py

Jun 30 18:06:54 academia00 systemd[1]: Started whiteboard-worker.service - Whiteboard Render Worker Service.
Jun 30 18:06:55 academia00 python3[527612]: INFO:httpx:HTTP Request: POST https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/whiteboard_fetch_queued_jobs "HTTP/1.1 200 OK"
Jun 30 18:06:55 academia00 python3[527612]: INFO:whiteboard_render_worker:[whiteboard_render_worker] Found 0 queued job(s)
Jun 30 18:06:57 academia00 python3[527612]: INFO:httpx:HTTP Request: POST https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/whiteboard_fetch_queued_jobs "HTTP/1.1 200 OK"
Jun 30 18:06:57 academia00 python3[527612]: INFO:whiteboard_render_worker:[whiteboard_render_worker] Found 0 queued job(s)
Jun 30 18:06:59 academia00 python3[527612]: INFO:httpx:HTTP Request: POST https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/whiteboard_fetch_queued_jobs "HTTP/1.1 200 OK"
Jun 30 18:06:59 academia00 python3[527612]: INFO:whiteboard_render_worker:[whiteboard_render_worker] Found 0 queued job(s)

```

## 6. Empreintes des fichiers modifiés

```
b84d3b2548cece1807f022c034ad927376e6538b1f1952d0713ab26db6eb080d  /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py
5f5dba85682301ba8afb901f23bf43afd1779505cd7930d779af5a84d5a428ba  /opt/whiteboard-worker/whiteboard_render_worker.py

```

## 7. Uptime du processus

```
    PID ELAPSED COMMAND
 527612       8 python3

```

**Conclusion :** Le service a redémarré avec un nouveau PID. Les fichiers modifiés sont en place. Le worker chargera le nouveau code à son prochain cycle de poll.
