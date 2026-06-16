# BOBODO_BUFFER_ROOT_CAUSE

## Mission 1 — Identification précise de audio_buffer

---

### Où est créé audio_buffer

```python
# @/opt/bobodo-vocal/stt_service.py:30
self.audio_buffer = bytearray()
```

| | |
|---|---|
| **Fichier** | `stt_service.py` |
| **Ligne** | 30 |
| **Variable** | `self.audio_buffer` |
| **Type** | `bytearray()` |

---

### Où il est stocké

```python
# @/opt/bobodo-vocal/stt_service.py:21-40
class STTService:
    def __init__(self, model_size: str = "medium", ...):
        self.model_size = model_size
        ...
        self.audio_buffer = bytearray()   # ← LIGNE 30
```

`audio_buffer` est un **attribut d'instance** de la classe `STTService`.

---

### Qui le partage

```python
# @/opt/bobodo-vocal/main.py:67
stt_service = STTService()
```

```python
# @/opt/bobodo-vocal/main.py:112-116
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    handler = WebSocketHandler(websocket, stt_service, tts_service, settings)
    await handler.handle()
```

| | |
|---|---|
| **Création** | `main.py:67` — une seule fois au démarrage |
| **Partage** | `main.py:115` — passé à **tous** les `WebSocketHandler` |
| **Conséquence** | Chaque connexion WS utilise le **même objet** `STTService` |

---

### Pourquoi plusieurs utilisateurs écrivent dedans

```python
# @/opt/bobodo-vocal/stt_service.py:166
self.audio_buffer.extend(audio_bytes)
```

Quand 3 users envoient de l'audio simultanément :

1. **User A** envoie 3200 bytes → `audio_buffer.extend(bytes_A)` → buffer = [A]
2. **User B** envoie 3200 bytes → `audio_buffer.extend(bytes_B)` → buffer = [A+B]
3. **User C** envoie 3200 bytes → `audio_buffer.extend(bytes_C)` → buffer = [A+B+C]

Il n'y a **aucune clé de session**, aucun verrou par user. Le `bytearray` est append-only pour tout le monde.

---

### Cycle de vie

| Phase | Action | Code |
|---|---|---|
| **Création** | Démarrage serveur | `main.py:67` → `STTService.__init__()` → `bytearray()` |
| **Écriture** | Chaque requête audio | `stt_service.py:166` → `extend(audio_bytes)` |
| **Lecture** | Détection de silence | `stt_service.py:119` → `bytes(self.audio_buffer)` |
| **Vidage** | Après transcription | `stt_service.py:120` → `self.audio_buffer.clear()` |
| **Destruction** | Arrêt serveur | Jamais explicitement nettoyé |

**Problème critique :** Le vidage (`clear()`) survient après transcription. Si un user A parle pendant que le silence de B est détecté, l'audio de A est **perdu** dans le `clear()`.

---

### Preuve du mélange dans les logs

```
[STT_SILENCE_DETECTED] Buffer duration: 10.68s
[STT_TEMP_FILE_SIZE] File size: 341804 bytes
[STT_TRANSCRIPTION_RESULT] Text:
  'Je veux parler à Bobodo.
   Comment fonctionne Academia ?
   Bobodo, explique-moi, c'est le con.
   Academia est une super plateforme.
   Bonjour Bobodo.'
```

5 phrases de 5 users distincts, concaténées dans un seul buffer.

---

### Réponse Mission 1

| Question | Réponse |
|---|---|
| **Fichier** | `stt_service.py` |
| **Ligne** | 30 |
| **Variable** | `self.audio_buffer` (attribut d'instance de `STTService`) |
| **Cycle de vie** | Créé au démarrage du serveur (`main.py:67`), partagé par tous les handlers jusqu'à l'arrêt |
| **Pourquoi le mélange** | `extend()` append-only sans clé de session ; `clear()` vide tout le buffer pour tout le monde |
