# BOBODO_PROTOCOL_INDUSTRY_PRACTICES

## Mission 4 — Pratiques industrielles des leaders

---

### A. OpenAI Realtime API (ChatGPT Voice)

**Source :** https://developers.openai.com/api/docs/guides/realtime-websocket

**Protocole :**
- Connexion WebSocket avec authentification via **headers** (pas query param)
- **Pas de session_id dans les messages**
- La session est implicitement liée à la connexion WebSocket
- Messages bidirectionnels de type JSON avec champ `type`

**Format messages client → serveur :**
```json
{
  "type": "conversation.item.create",
  "item": {
    "type": "message",
    "role": "user",
    "content": [{"type": "input_audio", "audio": "base64..."}]
  }
}
```

**Point clé :** OpenAI ne transporte pas de session_id dans chaque message. La session est gérée au niveau de la connexion.

---

### B. Gemini Live API (Google)

**Source :** https://ai.google.dev/gemini-api/docs/live-api/get-started-websocket

**Protocole :**
- Connexion WebSocket avec `key=API_KEY` en **query param**
- **Premier message obligatoire** : `setup` avec configuration
- Les messages suivants utilisent `realtimeInput` pour l'audio/texte

**Format connexion :**
```
wss://generativelanguage.googleapis.com/ws/...?key=YOUR_API_KEY
```

**Premier message (setup) :**
```json
{
  "setup": {
    "model": "models/gemini-2.0-flash-live-001",
    "generation_config": {...}
  }
}
```

**Messages audio suivants :**
```json
{
  "realtimeInput": {
    "audio": {
      "data": "base64...",
      "mimeType": "audio/pcm;rate=16000"
    }
  }
}
```

**Point clé :** Gemini utilise un message de **configuration initial** (`setup`) séparé des messages de données (`realtimeInput`).

---

### C. LiveKit Agents

**Source :** https://docs.livekit.io/agents/logic/sessions/

**Protocole :**
- Utilise **WebRTC** (pas WebSocket) pour l'audio temps réel
- Session gérée par `AgentSession.start(room=..., agent=...)`
- Pas de session_id manuel ; la session est liée à la room LiveKit
- Événements émis : `agent_state_changed`, `user_input_transcribed`

**Architecture :**
```python
session = AgentSession(
    stt="deepgram/nova-3:en",
    llm="openai/gpt-5.3-chat-latest",
    tts="cartesia/sonic-3",
)
await session.start(room=ctx.room, agent=Agent(...))
```

**Point clé :** LiveKit abstrait complètement la session. L'identifiant est la room.

---

### Tableau comparatif industriel

| | **OpenAI** | **Gemini** | **LiveKit** | **Bobodo actuel** |
|---|---|---|---|---|
| **Transport** | WebSocket | WebSocket | WebRTC | WebSocket |
| **Auth** | Headers | Query param | Room token | Query param (ignoré) |
| **Session init** | Implicit (connexion) | Message `setup` explicite | Room join | Message `session_id` (non envoyé) |
| **Session dans data** | ❌ Non | ❌ Non | ❌ Non | ✅ Oui (mais ignoré) |
| **Config séparée** | ❌ Non | ✅ Oui | ✅ Oui (room) | ✅ Oui (message `session_id`) |

---

### Conclusion de la recherche

**Aucun leader ne transporte l'identifiant de session dans chaque message de données.**

- OpenAI : Session = connexion WebSocket
- Gemini : Configuration initiale via message `setup` dédié
- LiveKit : Session = room WebRTC

**Tous utilisent une phase de configuration/initiation séparée des messages de données.**

Cela confirme que **l'Option A (message `session_id` dédié)** est alignée avec les pratiques industrielles de Gemini et du pattern général de séparation "config vs data".
