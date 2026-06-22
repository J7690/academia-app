# BOBODO_SESSION_FLOW_MAP

## Mission 3 — Cartographie complète des flux A/B/C

---

### Architecture actuelle (code source)

```
main.py
├── STTService()          ← instance unique (singleton)
├── TTSService()          ← instance unique
└── @app.websocket("/ws")
    └── websocket_endpoint(ws)
        └── WebSocketHandler(ws, stt_service, tts_service, settings)
            └── handle()
                ├── handle_audio(msg) → stt_service.transcribe(bytes)
                │   └── stt_service.set_transcription_callback(self._on_transcription)
                └── _on_transcription(text)
                    ├── send_transcription(text)
                    ├── bobodo_client.send_message(session_id, text)
                    └── send_audio_response(audio)
```

---

### Flux User A seul (fonctionne)

```
User A ──WebSocket──► main.py:115
    │                   WebSocketHandler_A(websocket_A, stt_service, ...)
    │                   handler_A.__init__()
    │                       stt_service.set_transcription_callback(handler_A._on_transcription)
    │                           ▼
    │                       stt_service.transcription_callback = handler_A._on_transcription
    │
    ├──audio──► handler_A.handle_audio()
    │               stt_service.transcribe(bytes_A)
    │                   audio_buffer.extend(bytes_A)          ← [A]
    │                   silence_task = asyncio.create_task(_wait_for_silence())
    │
    │           (1s de silence)
    │               _detect_silence()
    │                   audio_to_transcribe = bytes(audio_buffer)  ← [A]
    │                   audio_buffer.clear()                       ← []
    │                   transcribe_file(temp.wav)
    │                   transcription_callback(result)             ← handler_A._on_transcription
    │
    │           handler_A._on_transcription("texte A")
    │               websocket_A.send("transcription")
    │               bobodo_client.send_message(session_id_A, "texte A")
    │               websocket_A.send("audio_response")
    │
    ◄──transcription── User A reçoit "texte A"
    ◄──audio_response── User A reçoit la réponse vocale
```

**Résultat : User A reçoit sa transcription. Fonctionne.**

---

### Flux User A + User B (mélange)

```
User A ──WebSocket──► main.py:115
    │                   WebSocketHandler_A(ws_A, stt_service, ...)
    │                       stt_service.set_transcription_callback(handler_A._on_transcription)
    │                           ▼
    │                       stt_service.transcription_callback = handler_A._on_transcription
    │
    ├──audio_A──► handler_A.handle_audio()
    │               stt_service.transcribe(bytes_A)
    │                   audio_buffer.extend(bytes_A)          ← [A]
    │                   silence_task.cancel() + new task
    │
User B ──WebSocket──► main.py:115
    │                   WebSocketHandler_B(ws_B, stt_service, ...)
    │                       stt_service.set_transcription_callback(handler_B._on_transcription)
    │                           ▼
    │                       stt_service.transcription_callback = handler_B._on_transcription  ← ÉCRASE A
    │
    ├──audio_B──► handler_B.handle_audio()
    │               stt_service.transcribe(bytes_B)
    │                   audio_buffer.extend(bytes_B)          ← [A+B]  ← MÉLANGE
    │                   silence_task.cancel() + new task
    │
    │           (1s de silence, cumulé depuis le dernier audio)
    │               _detect_silence()
    │                   audio_to_transcribe = bytes(audio_buffer)  ← [A+B]
    │                   audio_buffer.clear()                       ← []
    │                   transcribe_file(temp.wav)
    │                   model.transcribe("A+B.wav")
    │
    │           Résultat : "texte de A et texte de B mélangés"
    │
    │                   transcription_callback(result)             ← handler_B._on_transcription  ← B SEUL
    │
    │           handler_B._on_transcription("texte A+B")
    │               websocket_B.send("transcription")                ← B reçoit le mélange
    │               bobodo_client.send_message(session_id_B, "texte A+B")
    │               websocket_B.send("audio_response")
    │
    ◄──RIEN──── User A n'a rien reçu (son callback a été écrasé)
    ◄──"A+B"─── User B reçoit le mélange des deux voix
```

**Résultat :**
- **User A** : 0 réponse (callback écrasé)
- **User B** : reçoit la transcription de **A+B mélangés**
- Le modèle Whisper voit un seul fichier audio contenant les deux voix superposées

---

### Flux User A + B + C (mélange total)

```
User A ──connect──► handler_A
    │                  set_callback(A)  → callback = A
    ├──audio_A──► buffer = [A]
    │
User B ──connect──► handler_B
    │                  set_callback(B)  → callback = B  (écrase A)
    ├──audio_B──► buffer = [A+B]
    │
User C ──connect──► handler_C
    │                  set_callback(C)  → callback = C  (écrase B)
    ├──audio_C──► buffer = [A+B+C]
    │
    │           silence détecté
    │           buffer = [A+B+C] → transcrit → "texte A+B+C"
    │           callback() → handler_C._on_transcription
    │
    ◄──RIEN──── User A
    ◄──RIEN──── User B
    ◄──"A+B+C"─ User C reçoit le mélange de 3 voix
```

**Résultat :**
- **User A** : 0 réponse
- **User B** : 0 réponse
- **User C** : reçoit la transcription des **3 voix mélangées**

---

### Points de fusion précis

| Point de fusion | Fichier | Ligne | Description |
|---|---|---|---|
| **F1 — Instance unique** | `main.py` | 67 | `stt_service = STTService()` — une seule instance pour toutes les connexions |
| **F2 — Passage de référence** | `main.py` | 115 | `WebSocketHandler(..., stt_service, ...)` — tous les handlers reçoivent la même référence |
| **F3 — Buffer global** | `stt_service.py` | 30 | `self.audio_buffer = bytearray()` — un seul buffer |
| **F4 — Accumulation** | `stt_service.py` | 166 | `self.audio_buffer.extend(audio_bytes)` — tous les users écrivent ici |
| **F5 — Callback unique** | `stt_service.py` | 37 | `self.transcription_callback = None` — une seule variable |
| **F6 — Écrasement** | `stt_service.py` | 44 | `self.transcription_callback = callback` — écrasé à chaque connexion |
| **F7 — Envoi unique** | `stt_service.py` | 144 | `await self.transcription_callback(result)` — un seul appel |
| **F8 — Destination** | `websocket_handler.py` | 101 | `await self.send_transcription(transcription)` — `self` = dernier handler |

---

### Résumé visuel

```
                    ┌─────────────────────────────────────┐
                    │         STTService (singleton)       │
                    │                                      │
   User A ──►┌──────┤  audio_buffer = [A+B+C]              │
              │      │  transcription_callback = handler_C │
   User B ──►┤      │                                      │
              │      └─────────────────────────────────────┘
   User C ──►┘
              ↑
         Tous les handlers partagent le même STTService
         → Mélange audio dans le buffer
         → Callback écrasé à chaque connexion
         → Seul le dernier handler reçoit le résultat
```

---

### Réponse Mission 3

| User | Audio envoyé | Buffer après envoi | Callback actif | Résultat reçu |
|---|---|---|---|---|
| **A** | audio_A | [A] → puis [A+B] → puis [A+B+C] | Écrasé par B puis C | **RIEN** |
| **B** | audio_B | [A+B] → puis [A+B+C] | Écrasé par C | **RIEN** |
| **C** | audio_C | [A+B+C] | **handler_C** | **"texte A+B+C"** (mélange) |

**Fusion à 8 points précis** identifiés dans le code source de production.
