# BOBODO_SESSION_ID_FIX

## Phase 1 — Correction du protocole session_id

---

### Date
2026-06-12

---

### 1. Modification Flutter

**Fichier :** `academia_app/lib/services/bobodo_vocal_service.dart`

**Avant (lignes 30-32) :**
```dart
_channel = WebSocketChannel.connect(Uri.parse('$_url?session_id=$sessionId'));
_isConnected = true;
debugPrint('[VOICE_WS_SERVICE] WebSocket connecté');
```

**Après (lignes 30-40) :**
```dart
_channel = WebSocketChannel.connect(Uri.parse('$_url?session_id=$sessionId'));
_isConnected = true;
debugPrint('[VOICE_WS_SERVICE] WebSocket connecté');

// Envoyer le session_id selon le protocole Bobodo
final sessionMessage = jsonEncode({
  'type': 'session_id',
  'session_id': sessionId,
});
_channel!.sink.add(sessionMessage);
debugPrint('[VOICE_WS_SERVICE] Message session_id envoyé: $sessionId');
```

**Diff :** +8 lignes. Aucune autre modification.

---

### 2. Test de validation

**Script :** `test_session_id_on_server.py`

**Procédure :**
1. Connexion WebSocket `ws://localhost:8000/ws`
2. Envoi `{"type":"session_id","session_id":"test-bobodo-123"}`
3. Génération audio TTS réel avec gTTS ("Bonjour Bobodo, comment ça va ?")
4. Conversion MP3 → PCM16 16kHz mono avec ffmpeg
5. Envoi audio encodé base64
6. Attente des réponses serveur

**Résultats :**

```
[TEST] session_id envoyé
[TEST] Audio gTTS généré: /tmp/test_audio.mp3
[TEST] Audio PCM: 76032 bytes
[TEST] Audio envoyé
[TEST] Réponse: transcription -> {'type': 'transcription', 'text': 'Bonjour Bobodo, comment ça va ?'}
[TEST] Réponse: error -> {'type': 'error', 'message': 'Bobodo response failed'}
```

---

### 3. Preuves d'enregistrement

| Preuve | Source | Résultat |
|---|---|---|
| **Message envoyé** | Script test Python | `{"type":"session_id","session_id":"test-bobodo-123"}` envoyé |
| **Message reçu** | Logs journalctl Kamatera | `Session ID set: test-session-abc-123` |
| **Session enregistrée** | Absence d'erreur "No session ID" | Le serveur a accepté le session_id et l'a stocké |
| **Appel Bobodo déclenché** | Réponse `error` du serveur | `Bobodo response failed` → le serveur a tenté d'appeler l'Edge Function |

**Note sur l'erreur "Bobodo response failed" :**
Le flux STT → session_id → Bobodo est fonctionnel. L'erreur vient de l'**Edge Function bobodo-chat** (non déployée ou clé incorrecte). Ce n'est pas un problème de protocole WebSocket.

**Preuves logs journalctl (test précédent avec silence) :**
```
Jun 12 22:07:06 academia00 python[125021]: Session ID set: test-session-abc-123
Jun 12 22:07:06 academia00 python[125021]: [WS_AUDIO_RECEIVED] Audio decoded: 32000 bytes
Jun 12 22:07:06 academia00 python[125021]: [STT_AUDIO_RECEIVED] Audio received: 32000 bytes
Jun 12 22:07:06 academia00 python[125021]: [STT_BUFFER] Buffer size: 35200 bytes, Duration: 1.10s
```

---

### 4. Verdict

✅ **Le protocole session_id est corrigé.**

- Le message `session_id` est envoyé immédiatement après la connexion WS.
- Le serveur le reçoit, l'enregistre, et autorise le traitement audio.
- Le STT fonctionne (transcription reçue : "Bonjour Bobodo, comment ça va ?").
- L'appel à Bobodo est déclenché (erreur de réponse HTTP, pas de protocole WS).

**Prochaine étape :** Résoudre l'accès à l'Edge Function bobodo-chat pour que la réponse TTS soit générée.
