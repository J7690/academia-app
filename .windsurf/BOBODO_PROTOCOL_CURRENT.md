# BOBODO_PROTOCOL_CURRENT

## Mission 1 — Cartographie intégrale du protocole actuel

---

### CLIENT → SERVEUR (Flutter → FastAPI)

| Type | Champ | Obligatoire | Description | Source code |
|---|---|---|---|---|
| `session_id` | `session_id` (string) | OUI | Identifiant de session Bobodo | `websocket_handler.py:282` |
| `audio` | `audio` (base64 string) | OUI | Données audio PCM16 encodées base64 | `websocket_handler.py:216` |
| `audio` | `session_id` (string) | NON | Session ID inclus dans le payload audio | `bobodo_vocal_service.dart:848` |
| `ping` | — | — | Heartbeat client | `websocket_handler.py:285` |

### SERVEUR → CLIENT (FastAPI → Flutter)

| Type | Champ | Description | Source code |
|---|---|---|---|
| `pong` | — | Réponse au ping | `websocket_handler.py:287` |
| `transcription` | `text` (string) | Texte transcrit par STT | `websocket_handler.py:292` |
| `audio_response` | `audio` (base64 string) | Réponse audio TTS encodée base64 | `websocket_handler.py:301` |
| `error` | `message` (string) | Message d'erreur | `websocket_handler.py:307` |

---

### Diagramme de séquence actuel (cas nominal)

```
Flutter                                    FastAPI
  |                                           |
  |---- WS CONNECT ws://IP:8000/ws --------->|
  |                                           |
  |---- {"type":"audio","session_id":"X",    |
  |      "audio":"base64..."} --------------->|
  |                                           |
  |                              [STT Buffer accumule]
  |                              [Silence détecté]
  |                              [Transcription Whisper]
  |                                           |
  |<--- {"type":"transcription","text":"..."}--|
  |                                           |
  |                              [Vérification session_id]
  |                              [Si session_id == None]
  |<--- {"type":"error","message":"No session ID"}--|
  |                                           |
  |                              [Si session_id OK]
  |                              [Appel Bobodo Edge Function]
  |                              [TTS gTTS]
  |<--- {"type":"audio_response","audio":"..."}---|
```

---

### Types de messages détaillés

#### `session_id` (CLIENT → SERVEUR)
```json
{
  "type": "session_id",
  "session_id": "abc-123-def"
}
```
**Handler:** `handle_session_id()` → stocke `self.session_id = message.get("session_id")`

#### `audio` (CLIENT → SERVEUR)
```json
{
  "type": "audio",
  "session_id": "abc-123-def",
  "audio": "//uQZAAAAAA..."
}
```
**Handler:** `handle_audio()` → extrait `audio_base64`, décode, passe au STT
**Note:** Le champ `session_id` dans ce message est **lu mais ignoré** par `handle_audio()`.

#### `ping` (CLIENT → SERVEUR)
```json
{"type": "ping"}
```
**Handler:** `handle_ping()` → répond `{"type": "pong"}`

#### `transcription` (SERVEUR → CLIENT)
```json
{
  "type": "transcription",
  "text": "Bonjour Bobodo"
}
```

#### `audio_response` (SERVEUR → CLIENT)
```json
{
  "type": "audio_response",
  "audio": "//uQZAAAAAA..."
}
```

#### `error` (SERVEUR → CLIENT)
```json
{
  "type": "error",
  "message": "No session ID provided"
}
```

---

### Architecture du flux STT → LLM → TTS

```
[Client Audio] → [WS /ws] → [STTService.transcribe()]
                                              ↓
                                    [Audio Buffer] → [Silence Detection]
                                              ↓
                                    [WhisperModel.transcribe()] → "text"
                                              ↓
                                    [Callback _on_transcription_complete()]
                                              ↓
                                    [Check session_id ?]
                                              ↓
                                    [IF OK: BobodoClient.send_message()]
                                              ↓
                                    [HTTP POST /functions/v1/bobodo-chat]
                                              ↓
                                    [IF response: TTSService.synthesize()]
                                              ↓
                                    [gTTS → MP3 bytes]
                                              ↓
                                    [WS send audio_response]
```

---

## Fichiers source audités

| Fichier | Rôle | Lignes |
|---|---|---|
| `/opt/bobodo-vocal/main.py` | FastAPI app, endpoint WS | 136 |
| `/opt/bobodo-vocal/websocket_handler.py` | Logique WS, routage messages | 314 |
| `/opt/bobodo-vocal/stt_service.py` | Faster Whisper STT | 578 |
| `/opt/bobodo-vocal/tts_service.py` | gTTS TTS | 114 |
| `/opt/bobodo-vocal/bobodo_client.py` | HTTP client vers Edge Function | 115 |
| `academia_app/lib/services/bobodo_vocal_service.dart` | Client WS Flutter | 95 |
| `academia_app/lib/features/student/tabs/student_bobodo_tab.dart` | UI Flutter | 1942 |
