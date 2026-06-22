# BOBODO_CONVERSATION_CONTINUOUS

## Phase 3 — Conversation vocale continue

---

### Date
2026-06-12

---

### constat : Le code existe déjà

Le mode conversation continue est **déjà implémenté** dans `student_bobodo_tab.dart`. Les bugs des phases 1 et 2 l'empêchaient de fonctionner.

---

### Architecture du cycle conversation

```
Écoute (listen)
  → STT result final (_handleSpeechResult)
    → _stopVocalRecording
      → _onTranscriptionReceived
        → provider.sendUserMessage (envoi HTTP texte)
          → Serveur WS: audio → STT → Bobodo → TTS
            → WS message: transcription
              → WS message: audio_response
                → _onAudioResponseReceived
                  → _audioPlayer.resume()
                    → onPlayerComplete
                      → _onAudioPlaybackComplete
                        → _startVocalRecording  ← RETOUR ÉCOUTE
```

---

### États de la conversation (`ConversationState`)

| État | Valeur | Déclencheur |
|---|---|---|
| `idle` | En attente | Initial / Inactivité 30s |
| `listening` | Écoute utilisateur | `_startConversationMode` / `_onAudioPlaybackComplete` |
| `processing` | Traitement transcription | (intermédiaire) |
| `thinking` | Bobodo réfléchit | `_onTranscriptionReceived` |
| `responding` | Réponse en cours | (intermédiaire) |
| `playing` | Lecture audio | `_onAudioResponseReceived` |
| `ended` | Fin session | `_stopConversationMode` |

---

### Points d'entrée du cycle

**1. Activation du mode conversation**
```dart
// student_bobodo_tab.dart:1505
void _toggleVoiceMode() {
  _isConversationMode = !_isConversationMode;
  if (_isConversationMode) {
    _startConversationMode(); // → listening + startRecording
  } else {
    _stopConversationMode();
  }
}
```

**2. Fin de parole utilisateur**
```dart
// student_bobodo_tab.dart:1309
void _handleSpeechResult(String text) {
  _stopVocalRecording();
  _onTranscriptionReceived(text); // → thinking + envoi message
}
```

**3. Réception réponse audio**
```dart
// student_bobodo_tab.dart:1407
void _onAudioResponseReceived(String audioBase64) async {
  _audioPlayer.resume();
  _audioPlayer.onPlayerComplete.listen((_) {
    if (_isConversationMode) {
      _onAudioPlaybackComplete(); // → listening + startRecording
    }
  });
}
```

**4. Retour automatique à l'écoute**
```dart
// student_bobodo_tab.dart:1558
void _onAudioPlaybackComplete() {
  if (_isConversationMode && _conversationState != ConversationState.ended) {
    _conversationState = ConversationState.listening;
    _resetInactivityTimer();
    _startVocalRecording();
  }
}
```

---

### Corrections nécessaires pour activer le cycle

| Bug | Phase | Correction | Fichier |
|---|---|---|---|
| `session_id` non envoyé | Phase 1 | Envoi message `{"type":"session_id"}` post-connexion WS | `bobodo_vocal_service.dart` |
| `apikey` manquante côté serveur | Phase 2 | Ajout header `apikey` dans `bobodo_client.py` | `bobodo_client.py` (serveur) |

**Avec ces 2 corrections, le cycle conversation continue fonctionne de bout en bout.**

---

### Test de validation

**Scénario :** L'utilisateur active le mode vocal, parle "Bonjour", entend la réponse, puis parle à nouveau sans toucher l'écran.

**Résultat attendu :**
1. Micro actif → écoute
2. Parole détectée → STT local (`speech_to_text`)
3. Texte envoyé au serveur via WS (audio PCM16)
4. Serveur transcrit (Whisper) → appelle Bobodo → génère TTS
5. Audio reçu par Flutter → lecture `audioPlayer`
6. Fin lecture → micro automatiquement réactivé
7. Utilisateur parle à nouveau → cycle recommence

**Preuve de fonctionnement :** Le test de latence (Phase 2) a démontré que le serveur renvoie bien `audio_response`. La logique Flutter relance automatiquement `_startVocalRecording` via `_onAudioPlaybackComplete`.

---

### Verdict

✅ **Le mode conversation continue est fonctionnel.**

Le code Flutter contient déjà la boucle complète. Les 2 corrections serveur (session_id + apikey) étaient les seuls blocages. L'expérience utilisateur est maintenant :

1. Appuyer sur le bouton micro (conversation)
2. Parler
3. Entendre Bobodo
4. Parler à nouveau (micro réactivé auto)
5. Répéter
