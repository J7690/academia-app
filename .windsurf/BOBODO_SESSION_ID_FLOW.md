# BOBODO_SESSION_ID_FLOW

## Mission 2 — Flux complet du session_id

---

### 1. Origine

**Flutter — `student_bobodo_tab.dart:965-967`**
```dart
BobodoVocalService _vocalService = BobodoVocalService(
  'ws://185.167.97.144:8000/ws',
);
```

**Flutter — `_connectVocalWebSocket()` (ligne ~1231)**
```dart
final provider = context.read<BobodoProvider>();
final sessionId = provider.currentSessionId;
await _vocalService.connect(sessionId);
```

**Origine :** Le `session_id` provient du `BobodoProvider` (état global Flutter). C'est l'ID de session de chat textuel déjà existant.

---

### 2. Transmission Flutter → Serveur (actuelle)

**Chemin A : Query param (connexion WS)**
```dart
// bobodo_vocal_service.dart:30
_channel = WebSocketChannel.connect(Uri.parse('$_url?session_id=$sessionId'));
```
Résultat : `ws://185.167.97.144:8000/ws?session_id=abc-123`

**Chemin B : Payload JSON (message audio)**
```dart
// bobodo_vocal_service.dart:847-851
final message = jsonEncode({
  'type': 'audio',
  'session_id': _sessionId,
  'audio': base64Audio,
});
```

---

### 3. Stockage côté Serveur

**`websocket_handler.py:178`**
```python
def __init__(self, ...):
    self.session_id: Optional[str] = None
```

**`websocket_handler.py:280-283`**
```python
async def handle_session_id(self, message: dict):
    self.session_id = message.get("session_id")
    logger.info(f"Session ID set: {self.session_id}")
```

**Stockage :** Variable d'instance `self.session_id` sur le `WebSocketHandler`. 
**Durée de vie :** Durée de la connexion WebSocket.

---

### 4. Consommation

**`websocket_handler.py:241-248`**
```python
if not self.session_id:
    logger.error("[WS_SESSION_ERROR] No session ID provided")
    await self.send_error("No session ID provided")
    return
```

**`websocket_handler.py:251-254`**
```python
response = await self.bobodo_client.send_message(
    session_id=self.session_id,
    message=transcription
)
```

**`bobodo_client.py:727-730`**
```python
payload = {
    "session_id": session_id,
    "message": message
}
```

---

### 5. Consommation côté Supabase Edge Function

**`supabase/functions/bobodo-chat/index.ts`** (Edge Function)
```typescript
const session_id = req.body.session_id;
// Utilisé pour maintenir le contexte conversationnel
```

---

### Tableau récapitulatif du flux

| Étape | Composant | Action | Fichier | Ligne |
|---|---|---|---|---|
| 1 | Flutter UI | Lit `currentSessionId` du `BobodoProvider` | `student_bobodo_tab.dart` | ~1240 |
| 2 | Flutter Service | Passe `sessionId` à `BobodoVocalService.connect()` | `bobodo_vocal_service.dart` | 25 |
| 3 | Flutter Service | **Inclut dans query param WS** `?session_id=...` | `bobodo_vocal_service.dart` | 30 |
| 4 | Flutter Service | **Inclut dans payload audio** `"session_id":...` | `bobodo_vocal_service.dart` | 849 |
| 5 | Serveur WS | Reçoit query param → **ignoré** par FastAPI | `main.py` | 117 |
| 6 | Serveur WS | Reçoit payload audio → **lu mais ignoré** | `websocket_handler.py` | 216 |
| 7 | Serveur WS | Attend message `type="session_id"` → **jamais reçu** | `websocket_handler.py` | 198 |
| 8 | Serveur WS | `self.session_id` reste `None` | `websocket_handler.py` | 178 |
| 9 | Serveur WS | Après STT, vérifie `self.session_id` → `None` → ERREUR | `websocket_handler.py` | 245 |
| 10 | Serveur WS | Envoie `{"type":"error","message":"No session ID provided"}` | `websocket_handler.py` | 247 |

---

### Problème identifié

**Le `session_id` est envoyé 2 fois par Flutter mais jamais stocké par le serveur :**

- **Query param** (`?session_id=...`) : FastAPI WebSocket **n'extrait pas automatiquement** les query params dans la logique actuelle.
- **Payload audio** (`{"type":"audio","session_id":"..."}`) : `handle_audio()` lit `audio_base64` mais **ne lit pas** `session_id`.
- **Message `session_id`** (`{"type":"session_id","session_id":"..."}`) : **Jamais envoyé** par Flutter.

**Résultat :** `self.session_id` reste `None` → erreur "No session ID provided".
