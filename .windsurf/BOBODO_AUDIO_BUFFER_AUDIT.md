# BOBODO_AUDIO_BUFFER_AUDIT

## Mission 2 — Audit complet du buffer audio

---

### Date
2026-06-13

---

### Question

Où est déclaré `audio_buffer` ?
Combien d'instances existent ?
Qui le crée ?
Qui le détruit ?
Quand est-il vidé ?
Peut-il survivre à la fermeture d'une session ?

---

### Preuve 1 : Déclaration du buffer

**Fichier :** `/opt/bobodo-vocal/stt_service.py`, ligne 30

```python
class STTService:
    def __init__(self, model_size: str = "medium", device: str = "cpu", compute_type: str = "int8"):
        # ...
        self.audio_buffer = bytearray()  # <--- DÉCLARÉ ICI
```

Le buffer est un **attribut d'instance** (pas d'attribut de classe). Chaque instance de `STTService` a son propre `audio_buffer`.

---

### Preuve 2 : Nombre d'instances de STTService

**Fichier :** `/opt/bobodo-vocal/main.py`, lignes 40-56

```python
stt_service = None  # Variable globale au module

@asynccontextmanager
async def lifespan(app: FastAPI):
    global stt_service, tts_service
    stt_service = STTService()  # <--- UNE SEULE INSTANCE
    tts_service = TTSService()
    # ...
```

**Il n'existe qu'UNE SEULE instance** de `STTService` pour l'ensemble du processus Python.

---

### Preuve 3 : Partage entre connexions WebSocket

**Fichier :** `/opt/bobodo-vocal/main.py`, ligne 91-95

```python
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    handler = WebSocketHandler(websocket, stt_service, tts_service, settings)
    await handler.handle()
```

**Fichier :** `/opt/bobodo-vocal/websocket_handler.py`, ligne 22-30

```python
class WebSocketHandler:
    def __init__(self, websocket, stt_service, tts_service, settings):
        self.websocket = websocket
        self.stt_service = stt_service  # <--- MÊME INSTANCE
```

**Toutes les connexions WebSocket reçoivent la MÊME instance** de `stt_service`. Elles partagent donc le **MÊME `audio_buffer`**.

---

### Preuve 4 : Le callback de transcription est écrasé

**Fichier :** `/opt/bobodo-vocal/websocket_handler.py`, ligne 29

```python
# Register transcription callback
self.stt_service.set_transcription_callback(self._on_transcription_complete)
```

Chaque nouvelle connexion WebSocket **écrase le callback** précédent. Si l'utilisateur A est connecté et l'utilisateur B se connecte :
- Le callback de A est remplacé par celui de B
- La transcription du buffer (qui contient peut-être l'audio de A) est envoyée à B

---

### Preuve 5 : Quand le buffer est-il vidé ?

**Fichier :** `/opt/bobodo-vocal/stt_service.py`, lignes 117-120

```python
async def _detect_silence(self) -> Optional[str]:
    # ...
    audio_to_transcribe = bytes(self.audio_buffer)
    self.audio_buffer.clear()  # <--- VIDÉ ICI
    self.last_audio_time = None
```

Le buffer n'est vidé que **après détection de silence ET vérification de durée minimale** (0.5s).

**Si une connexion se ferme AVANT la détection de silence, le buffer N'EST PAS vidé.**

---

### Preuve 6 : Le buffer survit à la fermeture d'une session

**Fichier :** `/opt/bobodo-vocal/websocket_handler.py`, lignes 45-58

```python
async def handle(self):
    await self.websocket.accept()
    try:
        while True:
            data = await self.websocket.receive_text()
            # ...
    except WebSocketDisconnect:
        logger.info("WebSocket connection closed")
    except Exception as e:
        # ...
```

**Aucun nettoyage du buffer** n'est effectué lors de la déconnexion. Le `except WebSocketDisconnect` ne fait qu'un `logger.info`. Le buffer reste intact.

---

### Diagramme mémoire

```
┌─────────────────────────────────────┐
│         Processus Python            │
│  ┌─────────────────────────────┐    │
│  │   Une instance STTService     │    │
│  │   audio_buffer = bytearray()  │◄───┼── Global à toutes les WS
│  │   model = WhisperModel(...)   │    │
│  └─────────────────────────────┘    │
│            ▲                          │
│            │                          │
│  ┌─────────┴──────────┐              │
│  │                    │              │
│  ▼                    ▼              │
│  WS 1              WS 2              │
│  callback=A        callback=B  ◄── B écrase A
│  audio=A+B         audio=A+B   ◄── Même buffer
└─────────────────────────────────────┘
```

---

### Réponses aux questions

| # | Question | Réponse | Preuve |
|---|---|---|---|
| 1 | Où est déclaré ? | `stt_service.py:30`, dans `__init__` | Code |
| 2 | Combien d'instances ? | **Une seule** | `main.py:56` crée `STTService()` une fois |
| 3 | Qui le crée ? | Le constructeur `STTService.__init__` | Code |
| 4 | Qui le détruit ? | **Personne.** Le garbage collector Python quand le process meurt | Code : aucun `__del__` |
| 5 | Quand est-il vidé ? | Après détection de silence ET durée > 0.5s | `stt_service.py:120` |
| 6 | Survit-il à une session ? | **OUI.** Aucun nettoyage en cas de déconnexion | `websocket_handler.py:52` |

---

### Conclusion

L'`audio_buffer` est :
- **Global au processus** (une seule instance de STTService)
- **Partagé entre TOUS les WebSocket** (passé par référence à chaque handler)
- **Non isolé par session** (aucune clé session_id sur le buffer)
- **Survivant aux déconnexions** (pas de cleanup)
- **Vulnérable à l'écrasement du callback** (dernier connecté gagne)

**C'est un bug architectural critique pour tout usage multi-utilisateur.**
