# BOBODO WS REALITY REPORT

**Horodatage :** 2026-06-12 21:21 UTC
**Cible :** 185.167.97.144

---

## Mission 1 — Routes WebSocket découvertes

### Commandes exécutées
```bash
grep -R "@app.websocket" /opt/bobodo-vocal/
grep -R "@router.websocket" /opt/bobodo-vocal/
grep -R "websocket" /opt/bobodo-vocal/*.py
```

### Résultats
```
/opt/bobodo-vocal/main.py:@app.websocket("/ws")
/opt/bobodo-vocal/main.py:async def websocket_endpoint(websocket: WebSocket):
/opt/bobodo-vocal/websocket_handler.py:from starlette.websockets import WebSocketDisconnect
/opt/bobodo-vocal/websocket_handler.py:        websocket: WebSocket,
/opt/bobodo-vocal/websocket_handler.py:        self.websocket = websocket
/opt/bobodo-vocal/websocket_handler.py:        await self.websocket.accept()
```

**Découverte :** La route `@app.websocket("/ws")` **existe** dans `/opt/bobodo-vocal/main.py:116`.

---

## Mission 2 — Contenu exact des fichiers

### main.py (parties WebSocket)

```python
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for voice interaction"""
    handler = WebSocketHandler(websocket, stt_service, tts_service, settings)
    await handler.handle()
```

### websocket_handler.py (logique message)

```python
async def handle(self):
    await self.websocket.accept()
    try:
        while True:
            data = await self.websocket.receive_text()
            message = json.loads(data)
            message_type = message.get("type")
            if message_type == "audio":
                await self.handle_audio(message)
            elif message_type == "session_id":
                await self.handle_session_id(message)
            elif message_type == "ping":
                await self.handle_ping()
    except WebSocketDisconnect:
        logger.info("WebSocket connection closed")
```

---

## Mission 3 — Test avec vrai client WebSocket

### Commande exécutée
```python
import asyncio, websockets, json

async def test_ws(url):
    async with websockets.connect(url, timeout=10) as ws:
        await ws.send(json.dumps({"type": "session_id", "session_id": "test"}))
        await ws.send(json.dumps({"type": "ping"}))
        return await asyncio.wait_for(ws.recv(), timeout=5)

for url in [
    "ws://localhost:8000/ws",
    "ws://localhost:8000/ws?session_id=test",
    "ws://127.0.0.1:8000/ws",
    "ws://185.167.97.144:8000/ws",
]:
    print(url, "=>", asyncio.run(test_ws(url)))
```

### Résultats
```
ws://localhost:8000/ws => {"type": "pong"}
ws://localhost:8000/ws?session_id=test => {"type": "pong"}
ws://127.0.0.1:8000/ws => {"type": "pong"}
ws://185.167.97.144:8000/ws => {"type": "pong"}
```

**Verdict :** Toutes les connexions WebSocket réussissent. Le endpoint `/ws` existe et fonctionne.

---

## Mission 4 — Preuve de trafic réel

### Test exécuté
Envoi de faux audio (3200 bytes de silence) avec `session_id: audit-test-12345`.

### Logs journalctl capturés
```
Jun 12 21:21:08 academia00 python[125021]: INFO: ('127.0.0.1', 59220) - "WebSocket /ws" [accepted]
Jun 12 21:21:08 academia00 python[125021]: INFO: WebSocket connection established
Jun 12 21:21:08 academia00 python[125021]: INFO: connection open
Jun 12 21:21:08 academia00 python[125021]: INFO: Session ID set: audit-test-12345
Jun 12 21:21:08 academia00 python[125021]: INFO: [WS_AUDIO_RECEIVED] Audio decoded: 3200 bytes
Jun 12 21:21:08 academia00 python[125021]: INFO: [STT_AUDIO_RECEIVED] Audio received: 3200 bytes
Jun 12 21:21:08 academia00 python[125021]: INFO: [STT_BUFFER] Buffer size: 3200 bytes, Duration: 0.10s
Jun 12 21:21:09 academia00 python[125021]: INFO: [STT_SILENCE_CANCELLED] New audio received (1000ms < 1000ms)
Jun 12 21:21:11 academia00 python[125021]: INFO: WebSocket connection closed
```

**Verdict :** Le trafic WebSocket passe réellement. Audio reçu, buffer STT actif.

---

## Mission 5 — URL exacte utilisée par Flutter

| Fichier | Ligne | URL exacte |
|---|---|---|
| `lib/services/voice_provider.dart` | 53 | `ws://185.167.97.144:8000/ws` |
| `lib/features/student/tabs/student_bobodo_tab.dart` | 88 | `ws://185.167.97.144:8000/ws` |
| `lib/services/bobodo_vocal_service.dart` | 30 | `ws://185.167.97.144:8000/ws?session_id=<ID>` |

---

## Mission 6 — Tableau comparatif

| | Flutter | Serveur FastAPI | Compatible |
|---|---|---|---|
| URL | `ws://185.167.97.144:8000/ws` | `@app.websocket("/ws")` port 8000 | ✅ OUI |
| Connexion établie | Oui | Accepte | ✅ OUI |
| Envoi audio | `{"type":"audio","session_id":"...","audio":"..."}` | Lit `audio`, passe au STT | ⚠️ PARTIEL |
| Envoi session_id | Via query param `?session_id=` | Attend message `{"type":"session_id"}` | ❌ NON |

---

## CONCLUSION OBLIGATOIRE

Réponse : **D — Le websocket existe mais échoue après connexion.**

### Preuves :

1. **Le WebSocket `/ws` existe et fonctionne.**
   - `@app.websocket("/ws")` est présent dans `/opt/bobodo-vocal/main.py:116`.
   - Tous les tests clients Python `websockets` réussissent (`ws://185.167.97.144:8000/ws` → pong reçu).

2. **curl retournait 404 car curl n'est PAS un client WebSocket.**
   - curl envoie une requête HTTP GET sans header `Upgrade: websocket`.
   - FastAPI reçoit une requête HTTP sur une route WebSocket et retourne 404.
   - C'est le comportement attendu, pas une absence de route.

3. **L'erreur "Transcription failed" vient d'une incompatibilité de protocole après connexion.**
   - Le serveur attend un message séparé `{"type": "session_id", "session_id": "..."}` pour stocker le session_id.
   - Le Flutter envoie le `session_id` uniquement dans le payload audio (`{"type": "audio", "session_id": "..."}`).
   - Le `handle_audio()` du serveur n'extrait pas le `session_id` du message audio.
   - Après transcription STT, `_on_transcription_complete()` vérifie `self.session_id` → `None` → envoie `"No session ID provided"`.

4. **La contradiction A vs B est résolue :**
   - A (erreur Flutter) = vrai → le serveur envoie une erreur après connexion.
   - B (curl 404) = vrai mais mal interprété → curl n'est pas un client WS.

---

**Fichiers de preuve :**
- `BOBODO_WS_ROUTE_DISCOVERY.md` — grep routes
- `BOBODO_WS_REGISTRATION.md` — contenu fichiers serveur
- `BOBODO_WS_REAL_TEST.md` — tests clients WebSocket
- `BOBODO_WS_TRAFFIC_PROOF.md` — logs journalctl
- `BOBODO_FLUTTER_WS_URL.md` — URLs Flutter
- `BOBODO_WS_COMPATIBILITY.md` — tableau comparatif
