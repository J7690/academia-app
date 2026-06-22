# BOBODO_MULTI_SESSION_TARGET_ARCHITECTURE

## Mission 4 — Architecture cible sans codage

---

### Objectif

1 buffer par session.
1 callback par session.
1 état conversationnel par session.

---

### Architecture actuelle vs cible

```
ACTUEL                                  CIBLE
──────                                  ─────
STTService (singleton)                  STTService (factory)
├── audio_buffer                        ├── sessions: dict[session_id, STTSession]
├── transcription_callback                │   └── chaque entrée = 1 session
├── silence_task                          │
└── model (Whisper)                     └── model (Whisper partagé, thread-safe)
    │                                       (le modèle CTranslate2 est thread-safe)
    │
WebSocketHandler(1)                     WebSocketHandler(1)
WebSocketHandler(2)  ──même──► STT      WebSocketHandler(2)  ──session_2──► STTSession(2)
WebSocketHandler(3)                     WebSocketHandler(3)  ──session_3──► STTSession(3)
```

---

### Classes proposées

#### `STTSession`

Attributs par session :

| Attribut | Type | Description |
|---|---|---|
| `session_id` | `str` | Identifiant unique de session |
| `audio_buffer` | `bytearray` | Buffer audio isolé pour cette session |
| `silence_task` | `asyncio.Task | None` | Tâche de détection de silence |
| `last_audio_time` | `float | None` | Timestamp du dernier paquet audio |
| `transcription_callback` | `Callable | None` | Callback du handler associé |
| `lock` | `asyncio.Lock` | Verrou pour protéger les accès concurrents au buffer |

Méthodes :

| Méthode | Description |
|---|---|
| `append_audio(bytes)` | Ajoute des données au buffer, réinitialise le silence |
| `trigger_transcription()` | Vide le buffer, appelle le modèle, exécute le callback |
| `cancel_silence()` | Annule la tâche de silence en cours |
| `cleanup()` | Vide le buffer, annule les tâches, libère les ressources |

#### `STTService` (refactored)

Attributs globaux (partagés) :

| Attribut | Type | Description |
|---|---|---|
| `model` | `WhisperModel` | Modèle CTranslate2 (thread-safe, instance unique) |
| `sessions` | `dict[str, STTSession]` | Dictionnaire session_id → STTSession |
| `session_lock` | `asyncio.Lock` | Verrou pour les opérations sur le dictionnaire |

Méthodes :

| Méthode | Description |
|---|---|
| `create_session(session_id, callback)` | Crée une nouvelle `STTSession`, l'ajoute au dict |
| `get_session(session_id)` | Récupère une session existante |
| `destroy_session(session_id)` | Supprime une session et appelle `cleanup()` |
| `transcribe(session_id, audio_bytes)` | Délègue à la session correspondante |

#### `WebSocketHandler` (modifié)

Attributs :

| Attribut | Type | Description |
|---|---|---|
| `websocket` | `WebSocket` | Connexion WS du client |
| `stt_service` | `STTService` | Référence au service factory |
| `session_id` | `str | None` | ID de session (reçu du client) |
| `stt_session` | `STTSession | None` | Référence à la session STT de cet user |

Flux modifié :

```
handle():
    await websocket.accept()
    while True:
        msg = await websocket.receive_text()
        if msg.type == "session_id":
            self.session_id = msg.session_id
            self.stt_session = stt_service.create_session(
                session_id=self.session_id,
                callback=self._on_transcription_complete
            )
        elif msg.type == "audio":
            self.stt_service.transcribe(self.session_id, audio_bytes)
```

---

### Structure mémoire

```
┌─────────────────────────────────────────────────────────────┐
│                         Process Python                        │
├─────────────────────────────────────────────────────────────┤
│  STTService                                                   │
│  ├── model: WhisperModel (1 instance, ~680 MB Small)       │
│  ├── sessions: dict                                           │
│  │   ├── "sess-A" → STTSession                                │
│  │   │            ├── audio_buffer: bytearray (~50 KB)         │
│  │   │            ├── silence_task: Task                      │
│  │   │            ├── last_audio_time: float                  │
│  │   │            └── transcription_callback: handler_A        │
│  │   ├── "sess-B" → STTSession                                │
│  │   │            ├── audio_buffer: bytearray (~50 KB)         │
│  │   │            ├── silence_task: Task                      │
│  │   │            ├── last_audio_time: float                  │
│  │   │            └── transcription_callback: handler_B        │
│  │   └── "sess-C" → STTSession ...                            │
│  └── session_lock: asyncio.Lock                               │
│                                                               │
│  WebSocketHandler_A ──ref──► STTSession("sess-A")            │
│  WebSocketHandler_B ──ref──► STTSession("sess-B")            │
│  WebSocketHandler_C ──ref──► STTSession("sess-C")            │
└─────────────────────────────────────────────────────────────┘
```

**Avantage :** Chaque session a son propre buffer. Aucun mélange possible. Le modèle Whisper reste partagé (il est thread-safe).

---

### Dictionnaires

```python
# STTService.sessions
{
    "test-session-0": STTSession(...),
    "test-session-1": STTSession(...),
    "test-session-2": STTSession(...),
}

# WebSocketHandler garde une référence à sa session
self.stt_session = stt_service.sessions[self.session_id]
```

---

### Nettoyage des ressources

#### Scénario 1 — Déconnexion normale

```
User ferme l'app → WebSocketDisconnect
    └── handler.handle() finally:
        └── stt_service.destroy_session(self.session_id)
            └── sessions.pop(session_id).cleanup()
                └── audio_buffer.clear()
                └── silence_task.cancel()
                └── transcription_callback = None
```

#### Scénario 2 — Timeout / inactivité

```
Tâche périodique (toutes les 5 minutes):
    └── Parcourir sessions
        └── Si last_audio_time > 5 min:
            └── destroy_session(session_id)
```

#### Scénario 3 — Crash handler

```
Exception dans handler:
    └── handler.__del__ ou try/except finally:
        └── destroy_session(session_id)
```

---

### Classes complètes (pseudocode)

```python
class STTSession:
    def __init__(self, session_id, callback, model):
        self.session_id = session_id
        self.audio_buffer = bytearray()
        self.silence_task = None
        self.last_audio_time = None
        self.transcription_callback = callback
        self.model = model          # référence partagée
        self.lock = asyncio.Lock()

    async def append_audio(self, audio_bytes):
        async with self.lock:
            self.audio_buffer.extend(audio_bytes)
            self.last_audio_time = time.time()
            self._reschedule_silence()

    async def trigger_transcription(self):
        async with self.lock:
            if len(self.audio_buffer) < min_size:
                self.audio_buffer.clear()
                return
            wav = self._create_wav(self.audio_buffer)
            self.audio_buffer.clear()
        text = await self._transcribe(wav)
        if self.transcription_callback:
            await self.transcription_callback(text)

    def cleanup(self):
        if self.silence_task and not self.silence_task.done():
            self.silence_task.cancel()
        self.audio_buffer.clear()
        self.transcription_callback = None


class STTService:
    def __init__(self):
        self.model = WhisperModel("small", device="cpu", compute_type="int8")
        self.sessions = {}
        self.lock = asyncio.Lock()

    def create_session(self, session_id, callback):
        self.sessions[session_id] = STTSession(session_id, callback, self.model)
        return self.sessions[session_id]

    def destroy_session(self, session_id):
        if session_id in self.sessions:
            self.sessions[session_id].cleanup()
            del self.sessions[session_id]

    async def transcribe(self, session_id, audio_bytes):
        session = self.sessions.get(session_id)
        if session:
            await session.append_audio(audio_bytes)
```

---

### Points clés de l'architecture cible

| Principe | Implémentation |
|---|---|
| **1 buffer par session** | `STTSession.audio_buffer` (bytearray isolé) |
| **1 callback par session** | `STTSession.transcription_callback` (pointeur vers handler) |
| **1 état par session** | `STTSession` contient silence_task, last_audio_time, lock |
| **Modèle partagé** | `STTService.model` — CTranslate2 est thread-safe |
| **Isolation complète** | `asyncio.Lock` par session évite les courses |
| **Nettoyage automatique** | `destroy_session()` au disconnect ou timeout |
