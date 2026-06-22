# BOBODO_CALLBACK_ROOT_CAUSE

## Mission 2 — Identification du callback transcription

---

### Où est stocké callback transcription

```python
# @/opt/bobodo-vocal/stt_service.py:37
self.transcription_callback = None
```

| | |
|---|---|
| **Fichier** | `stt_service.py` |
| **Ligne** | 37 |
| **Variable** | `self.transcription_callback` |
| **Type initial** | `None` |

---

### Où il est remplacé

```python
# @/opt/bobodo-vocal/stt_service.py:42-45
def set_transcription_callback(self, callback):
    """Set callback for transcription results"""
    self.transcription_callback = callback
    logger.info("[STT_CALLBACK] Transcription callback registered")
```

| | |
|---|---|
| **Fichier** | `stt_service.py` |
| **Ligne** | 42–45 |
| **Action** | Écrase `self.transcription_callback` avec le nouveau callback |

```python
# @/opt/bobodo-vocal/websocket_handler.py:38-39
def __init__(self, websocket, stt_service, tts_service, settings):
    ...
    self.stt_service.set_transcription_callback(self._on_transcription_complete)
```

| | |
|---|---|
| **Fichier** | `websocket_handler.py` |
| **Ligne** | 39 |
| **Action** | Chaque `WebSocketHandler` appelle `set_transcription_callback()` sur le **même** `stt_service` |

---

### Pourquoi une connexion écrase l'autre

**Séquence chronologique prouvée par le code :**

| Temps | Événement | État du callback |
|---|---|---|
| t0 | Démarrage serveur | `transcription_callback = None` |
| t1 | User A se connecte | `transcription_callback = handler_A._on_transcription_complete` |
| t2 | User B se connecte | `transcription_callback = handler_B._on_transcription_complete` **← écrase A** |
| t3 | User C se connecte | `transcription_callback = handler_C._on_transcription_complete` **← écrase B** |
| t4 | Transcription finie (audio de A+B+C) | Appelé sur `handler_C._on_transcription_complete` |

**Preuve dans les logs :**

```
[WS_STT_CALLBACK] Transcription completed: Je veux parler à Bobodo...
```

Ce log provient du **dernier handler connecté** (User C) car c'est le seul callback actif.

```
[WS_STT_CALLBACK] Transcription completed
[WS_BOBODO_START] Sending transcription to Bobodo...
```

Le callback envoie la transcription à `self.websocket` — qui est la websocket du **dernier** handler, pas de celui qui a parlé.

---

### Preuve de code — L'envoi va au mauvais user

```python
# @/opt/bobodo-vocal/websocket_handler.py:95-137
async def _on_transcription_complete(self, transcription: str):
    ...
    # Send transcription to client
    await self.send_transcription(transcription)        # ← self = dernier handler
    ...
    response = await self.bobodo_client.send_message(
        session_id=self.session_id,                       # ← session_id du dernier handler
        message=transcription
    )
    ...
    await self.send_audio_response(audio_response)        # ← self = dernier handler
```

**`self`** fait référence au handler qui a **enregistré** le callback, pas au handler qui a **envoyé** l'audio. Comme le callback est écrasé à chaque connexion, `self` est toujours le dernier connecté.

---

### Preuve de code — Le callback est unique

```python
# @/opt/bobodo-vocal/stt_service.py:142-144
if self.transcription_callback and result:
    logger.info("[STT_CALLBACK] Calling transcription callback with result")
    await self.transcription_callback(result)
```

Il n'y a **qu'un seul appel** à `transcription_callback`. Une seule transcription est envoyée. Une seule websocket reçoit la réponse. Les autres users restent en attente indéfinie.

---

### Réponse Mission 2

| Question | Réponse |
|---|---|
| **Où stocké** | `stt_service.py:37` — `self.transcription_callback` (attribut d'instance de `STTService`) |
| **Où remplacé** | `stt_service.py:42` — `set_transcription_callback()` écrase la valeur |
| **Qui l'appelle** | `websocket_handler.py:39` — chaque handler appelle `set_transcription_callback()` sur le même `STTService` |
| **Pourquoi l'écrasement** | `STTService` est singleton global ; il n'y a qu'une seule variable `transcription_callback` |
| **Conséquence** | La transcription de N users est envoyée à 1 seul handler (le dernier connecté) |
