# BOBODO_WS_COMPATIBILITY

## Mission 6 — Comparaison endpoint Flutter vs endpoint serveur

---

### URL exacte utilisée par Flutter

**Fichier :** `academia_app/lib/services/voice_provider.dart:53`

```dart
_channel = WebSocketChannel.connect(
  Uri.parse('ws://185.167.97.144:8000/ws'),
);
```

**Fichier :** `academia_app/lib/features/student/tabs/student_bobodo_tab.dart:88`

```dart
_vocalService = BobodoVocalService(
  'ws://185.167.97.144:8000/ws',
);
```

**Fichier :** `academia_app/lib/services/bobodo_vocal_service.dart:30`

```dart
_channel = WebSocketChannel.connect(Uri.parse('$_url?session_id=$sessionId'));
```

**URL effective envoyée :**
```
ws://185.167.97.144:8000/ws?session_id=<SESSION_ID>
```

---

### Route exposée par le serveur

**Fichier :** `/opt/bobodo-vocal/main.py:116`

```python
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for voice interaction"""
    handler = WebSocketHandler(websocket, stt_service, tts_service, settings)
    await handler.handle()
```

**Fichier :** `/opt/bobodo-vocal/main.py:38-39`

```python
websocket_host: str = "0.0.0.0"
websocket_port: int = 8000
```

---

### Tableau comparatif

| | Flutter | Serveur | Compatible |
|---|---|---|---|
| **Protocole** | `ws://` | `ws://` | ✅ OUI |
| **IP** | `185.167.97.144` | `0.0.0.0` (toutes interfaces) | ✅ OUI |
| **Port** | `8000` | `8000` | ✅ OUI |
| **Path** | `/ws` | `/ws` | ✅ OUI |
| **Query param** | `?session_id=xxx` | Non défini dans la route | ⚠️ Ignoré par FastAPI |
| **Upgrade header** | `WebSocket` | `WebSocket` | ✅ OUI |

---

### Preuve de compatibilité

**Test exécuté :**

```python
import asyncio, websockets, json

async def test():
    async with websockets.connect("ws://185.167.97.144:8000/ws") as ws:
        await ws.send(json.dumps({"type": "session_id", "session_id": "test"}))
        await ws.send(json.dumps({"type": "ping"}))
        resp = await ws.recv()
        print(resp)

asyncio.run(test())
```

**Résultat :**
```
{"type": "pong"}
```

**Statut :** `SUCCESS` — connexion établie, messages échangés.

---

### Anomalie identifiée : format du message `session_id`

**Ce que Flutter envoie :**

Dans `bobodo_vocal_service.dart:69-73` :
```dart
final message = jsonEncode({
  'type': 'audio',
  'session_id': _sessionId,
  'audio': base64Audio,
});
```

**Ce que le serveur attend :**

Dans `websocket_handler.py:192-195` :
```python
if message_type == "audio":
    await self.handle_audio(message)
elif message_type == "session_id":
    await self.handle_session_id(message)
```

Dans `handle_audio()` (ligne 208-223) :
```python
async def handle_audio(self, message: dict):
    audio_base64 = message.get("audio")
    audio_bytes = base64.b64decode(audio_base64)
    await self.stt_service.transcribe(audio_bytes)
```

**Problème :** `handle_audio()` n'extrait **PAS** le `session_id` du message audio. Il ne fait que transmettre l'audio au STT.

Ensuite, dans `_on_transcription_complete()` (ligne 241-244) :
```python
if not self.session_id:
    logger.error("[WS_SESSION_ERROR] No session ID provided")
    await self.send_error("No session ID provided")
    return
```

**Résultat :** Si Flutter n'envoie **jamais** un message `{"type": "session_id", "session_id": "..."}`, le serveur répondra par une erreur `{"type": "error", "message": "No session ID provided"}` après la transcription.

---

## Conclusion Mission 6

| Élément | Verdict |
|---|---|
| Le WebSocket `/ws` existe sur le serveur | ✅ CONFIRMÉ |
| L'URL Flutter correspond à la route serveur | ✅ CONFIRMÉ |
| La connexion WebSocket établit correctement | ✅ CONFIRMÉ (test réussi) |
| Le `session_id` est envoyé via query param par Flutter | ⚠️ INCOMPATIBLE avec la logique serveur |
| Le serveur attend `type: "session_id"` dans un message séparé | ⚠️ INCOMPATIBLE avec l'envoi Flutter |
