# BOBODO_REAL_ENDPOINTS

**Timestamp :** 2026-06-12 20:26:15 UTC

---

## Tests curl exécutés

### Test 1 — localhost:8000/

**Commande :**
```bash
curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:8000/
```

**Sortie :**
```
404
```

### Test 2 — 127.0.0.1:8000/

**Commande :**
```bash
curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://127.0.0.1:8000/
```

**Sortie :**
```
404
```

### Test 3 — localhost:8000/ws

**Commande :**
```bash
curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:8000/ws
```

**Sortie :**
```
404
```

### Test 4 — IP publique:8000/

**Commande :**
```bash
curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://185.167.97.144:8000/
```

**Sortie :**
```
404
```

### Test 5 — localhost:8000/health

**Commande :**
```bash
curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:8000/health
```

**Sortie :**
```
200
```

---

## Logs du service (journalctl) confirmant les requêtes

**Commande :**
```bash
journalctl -u bobodo-vocal.service --no-pager -n 20
```

**Sortie pertinente :**
```
Jun 12 20:12:14 academia00 python[125021]: INFO:     127.0.0.1:38004 - "GET / HTTP/1.1" 404 Not Found
Jun 12 20:12:15 academia00 python[125021]: INFO:     127.0.0.1:38012 - "GET / HTTP/1.1" 404 Not Found
Jun 12 20:12:15 academia00 python[125021]: INFO:     127.0.0.1:38026 - "GET /ws HTTP/1.1" 404 Not Found
Jun 12 20:12:16 academia00 python[125021]: INFO:     185.167.97.144:42362 - "GET / HTTP/1.1" 404 Not Found
Jun 12 20:26:15 academia00 python[125021]: INFO:     127.0.0.1:42028 - "GET /health HTTP/1.1" 200 OK
Jun 12 20:26:16 academia00 python[125021]: INFO:     127.0.0.1:42032 - "GET /ws HTTP/1.1" 404 Not Found
```

---

## Conclusion

| Endpoint | Méthode | Code HTTP | Interprétation |
|---|---|---|---|
| `http://localhost:8000/` | GET | 404 | Route `/` non implémentée |
| `http://localhost:8000/ws` | GET | 404 | Route `/ws` non implémentée |
| `http://localhost:8000/health` | GET | 200 | **Route `/health` fonctionnelle** |
| `http://185.167.97.144:8000/` | GET | 404 | Accessible depuis l'extérieur, mais 404 |

- Le **serveur HTTP est actif** sur le port 8000 (pas de timeout, pas de connexion refusée).
- **Aucune route WebSocket `/ws` n'existe** actuellement sur ce serveur.
- La seule route confirmée fonctionnelle est `/health` (200 OK).
