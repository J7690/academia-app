# BOBODO VOICE - State Machine Audit

## Date
12 Juin 2026

---

## OBJECTIF

Auditer le cycle vocal complet et documenter la machine d'états actuelle et cible.

---

## MACHINE D'ÉTATS ACTUELLE (CODE RÉEL)

### États identifiés (student_bobodo_tab.dart)

**Variables d'état** (lignes 42-47) :
```dart
bool _isRecordingMode = false;  // Mode vocal activé
bool _isRecording = false;       // Enregistrement en cours
bool _isTranscribing = false;   // Transcription en cours
bool _isSending = false;        // (non utilisé)
bool _isSpeaking = false;        // Lecture audio en cours
```

**UX TTS** (lignes 70-72) :
```dart
bool _autoTtsEnabled = true;    // Toggle auto TTS
Uint8List? _lastAudioResponse;   // Cache audio pour replay
```

---

## TRANSITIONS ACTUELLES

### 1. IDLE → RECORDING

**Déclencheur** : User clique bouton micro (ligne 998)

**Méthode** : `_startVocalRecording()` (lignes 1184-1218)

**Transitions** :
```dart
setState(() {
  _isRecordingMode = true;
  _isRecording = true;
  _recordingDuration = Duration.zero;
  _audioBuffer.clear();
});
```

**Validation** :
- Permission microphone requise
- Recorder initialisé

**Erreurs** :
- Permission refusée → return (sans message)
- Recorder error → log debug

---

### 2. RECORDING → TRANSCRIBING

**Déclencheur** : User clique bouton stop (ligne 1123)

**Méthode** : `_stopVocalRecording()` (lignes 1220-1236)

**Transitions** :
```dart
setState(() {
  _isRecording = false;
  _isTranscribing = true;
});
```

**Actions** :
- Stop recorder
- Envoyer audio via WebSocket
- Clear audio buffer

**Validation** :
- `_isRecording` doit être true

**Erreurs** :
- Aucune gestion explicite
- Si WebSocket non connecté → message d'erreur dans service

---

### 3. TRANSCRIBING → IDLE (avec transcription)

**Déclencheur** : WebSocket message type `transcription`

**Méthode** : `_onTranscriptionReceived()` (lignes 1272-1282)

**Transitions** :
```dart
setState(() {
  _isTranscribing = false;
  _isRecordingMode = false;
});
```

**Actions** :
- Injecter texte dans `_controller.text`
- Positionner curseur à la fin

**Validation** :
- Aucune

**Erreurs** :
- Aucune gestion explicite

---

### 4. IDLE → SPEAKING

**Déclencheur** : WebSocket message type `audio_response`

**Méthode** : `_onAudioResponseReceived()` (lignes 1284-1302)

**Transitions** :
```dart
if (_autoTtsEnabled) {
  await _audioPlayer.setSourceBytes(audioBytes);
  await _audioPlayer.resume();
  setState(() => _isSpeaking = true);
}
```

**Actions** :
- Décoder audio base64
- Jouer via AudioPlayer

**Validation** :
- `_autoTtsEnabled` doit être true
- AudioPlayer doit être initialisé

**Erreurs** :
- Try-catch générique → log debug
- Pas de fallback

---

### 5. SPEAKING → IDLE

**Déclencheur** : AudioPlayer complète lecture

**Méthode** : `onPlayerComplete` (lignes 1295-1297)

**Transitions** :
```dart
_audioPlayer.onPlayerComplete.listen((_) {
  setState(() => _isSpeaking = false);
});
```

**Actions** :
- Aucune

**Validation** :
- Aucune

**Erreurs** :
- Aucune gestion explicite

---

### 6. SPEAKING → IDLE (manuel)

**Déclencheur** : User clique bouton stop (ligne 745)

**Méthode** : `_stopAudioPlayback()` (lignes 1304-1307)

**Transitions** :
```dart
void _stopAudioPlayback() {
  _audioPlayer.stop();
  setState(() => _isSpeaking = false);
}
```

**Actions** :
- Stop AudioPlayer

**Validation** :
- Aucune

**Erreurs** :
- Aucune gestion explicite

---

### 7. RECORDING → IDLE (annulation)

**Déclencheur** : User clique bouton annuler (ligne 1108)

**Méthode** : `_cancelVocalRecording()` (lignes 1238-1249)

**Transitions** :
```dart
setState(() {
  _isRecordingMode = false;
  _isRecording = false;
  _recordingDuration = Duration.zero;
});
```

**Actions** :
- Stop recorder
- Cancel timers
- Clear audio buffer

**Validation** :
- Aucune

**Erreurs** :
- Aucune gestion explicite

---

## DIAGRAMME D'ÉTATS ACTUEL

```
┌─────────────────────────────────────────────────────────────┐
│                        IDLE                                │
│  _isRecordingMode = false                                 │
│  _isRecording = false                                     │
│  _isTranscribing = false                                  │
│  _isSpeaking = false                                      │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ User clique micro
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      RECORDING                             │
│  _isRecordingMode = true                                  │
│  _isRecording = true                                       │
│  _isTranscribing = false                                  │
│  _isSpeaking = false                                      │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ User clique stop
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    TRANSCRIBING                             │
│  _isRecordingMode = true                                  │
│  _isRecording = false                                      │
│  _isTranscribing = true                                   │
│  _isSpeaking = false                                      │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ WebSocket transcription
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                        IDLE                                 │
│  (texte injecté dans TextField)                            │
│  User peut éditer                                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ User clique envoi
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   PROCESSING (Bobodo)                       │
│  (géré par BobodoProvider, pas d'état local)              │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ WebSocket audio_response
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      SPEAKING                               │
│  _isRecordingMode = false                                  │
│  _isRecording = false                                      │
│  _isTranscribing = false                                  │
│  _isSpeaking = true                                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ onPlayerComplete
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                        IDLE                                 │
│  (micro ne se réactive PAS)                                │
└─────────────────────────────────────────────────────────────┘
```

---

## PROBLÈMES IDENTIFIÉS

### 1. Pas de machine d'états formelle

**Problème** :
- 5 booléens simples
- Pas de validation des transitions
- Pas d'état invalides détectés
- Pas de diagramme d'états

**Impact** :
- États inconsistants possibles
- Difficile à déboguer
- Difficile à étendre

---

### 2. Pas d'état PROCESSING local

**Problème** :
- BobodoProvider gère `_isLoading`
- Mais pas synchronisé avec états vocaux
- Pas d'état "Bobodo réfléchit" en mode vocal

**Impact** :
- UI peut être confuse
- Pas d'indicateur visuel clair

---

### 3. Pas d'état ERROR

**Problème** :
- Aucun état d'erreur explicite
- Erreurs loguées mais pas gérées
- Pas de récupération

**Impact** :
- UX dégradée en cas d'erreur
- Difficile à déboguer

---

### 4. Pas d'état INTERRUPTED

**Problème** :
- User peut interrompre (stop pendant lecture)
- Mais pas d'état explicite
- Pas de gestion de reprise

**Impact** :
- Interruptions non gérées proprement
- Pas de possibilité de reprendre

---

### 5. Pas d'état ENDED

**Problème** :
- Pas de notion de "fin de conversation"
- Pas de nettoyage explicite
- Pas de fermeture WebSocket

**Impact** :
- Ressources non libérées
- Connexions non fermées

---

## MACHINE D'ÉTATS CIBLE

### Enum d'états

```dart
enum VocalState {
  idle,           // En attente (micro inactif)
  listening,      // Écoute (micro actif, enregistrement)
  processing,     // Traitement (transcription + Bobodo)
  speaking,       // Lecture (TTS en cours)
  interrupted,    // Interruption (user coupe)
  error,          // Erreur (récupération)
  ended,          // Fin (conversation terminée)
}
```

### Variables d'état

```dart
VocalState _vocalState = VocalState.idle;
bool _isConversationMode = false;  // Mode conversation vs dictée
String? _errorMessage;             // Message d'erreur
```

---

## TRANSITIONS CIBLES

### 1. IDLE → LISTENING

**Déclencheur** : User active mode vocal

**Validation** :
- Permission microphone accordée
- Recorder initialisé
- WebSocket connecté

**Erreur** :
- Si permission refusée → ERROR
- Si recorder error → ERROR
- Si WebSocket non connecté → ERROR

---

### 2. LISTENING → PROCESSING

**Déclencheur** : User stoppe enregistrement

**Validation** :
- Audio buffer non vide
- Durée > 1 seconde

**Erreur** :
- Si buffer vide → IDLE
- Si durée < 1s → IDLE

---

### 3. PROCESSING → SPEAKING

**Déclencheur** : Bobodo renvoie réponse + audio

**Validation** :
- Audio non null
- Auto TTS activé

**Erreur** :
- Si audio null → IDLE (texte seulement)
- Si Auto TTS désactivé → IDLE

---

### 4. SPEAKING → LISTENING (mode conversation)

**Déclencheur** : TTS terminé

**Validation** :
- `_isConversationMode = true`

**Action** :
- Réactiver micro automatiquement

**Erreur** :
- Si recorder error → ERROR

---

### 5. SPEAKING → IDLE (mode dictée)

**Déclencheur** : TTS terminé

**Validation** :
- `_isConversationMode = false`

**Action** :
- Ne rien faire (user doit recliquer)

---

### 6. SPEAKING → INTERRUPTED

**Déclencheur** : User clique stop

**Validation** :
- `_isSpeaking = true`

**Action** :
- Stop AudioPlayer
- Si mode conversation → LISTENING
- Si mode dictée → IDLE

---

### 7. LISTENING → IDLE (annulation)

**Déclencheur** : User clique annuler

**Validation** :
- `_vocalState = VocalState.listening`

**Action** :
- Stop recorder
- Clear buffer
- Cancel timers

---

### 8. ERROR → IDLE

**Déclencheur** : User clique retry ou timeout

**Validation** :
- Erreur récupérable

**Action** :
- Réinitialiser
- Afficher message d'erreur

---

### 9. IDLE → ENDED

**Déclencheur** : User quitte conversation

**Validation** :
- Session active

**Action** :
- Fermer WebSocket
- Libérer ressources
- Nettoyer buffers

---

## DIAGRAMME D'ÉTATS CIBLE

```
┌─────────────────────────────────────────────────────────────┐
│                        IDLE                                │
│  _vocalState = VocalState.idle                             │
│  Micro inactif                                             │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ User active vocal
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      LISTENING                             │
│  _vocalState = VocalState.listening                         │
│  Micro actif, enregistrement                               │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ User stop
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    PROCESSING                             │
│  _vocalState = VocalState.processing                       │
│  Transcription + Bobodo                                    │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Réponse + audio
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      SPEAKING                               │
│  _vocalState = VocalState.speaking                          │
│  TTS en cours                                              │
└─────────────────────────────────────────────────────────────┘
                            │
                ┌───────────────┴───────────────┐
                │                               │
                │ TTS terminé                   │ User stop
                ▼                               ▼
        ┌───────────────┐              ┌───────────────┐
        │  LISTENING    │              │ INTERRUPTED   │
        │ (conversation) │              │               │
        └───────────────┘              └───────────────┘
                │                               │
                │                               │
                ▼                               ▼
        ┌───────────────┐              ┌───────────────┐
        │   IDLE        │              │   IDLE        │
        │ (dictée)      │              │               │
        └───────────────┘              └───────────────┘
```

---

## ÉVÉNEMENTS

### Événements utilisateur

- `VOCAL_START` : User active mode vocal
- `VOCAL_STOP` : User stoppe enregistrement
- `VOCAL_CANCEL` : User annule enregistrement
- `AUDIO_STOP` : User stoppe lecture
- `AUDIO_REPLAY` : User relance lecture
- `TOGGLE_AUTO_TTS` : User toggle auto TTS
- `SWITCH_MODE` : User change mode (dictée/conversation)

### Événements système

- `TRANSCRIPTION_RECEIVED` : STT renvoie transcription
- `AUDIO_RESPONSE_RECEIVED` : TTS renvoie audio
- `AUDIO_COMPLETE` : AudioPlayer termine lecture
- `WEBSOCKET_CONNECTED` : WebSocket connecté
- `WEBSOCKET_DISCONNECTED` : WebSocket déconnecté
- `WEBSOCKET_ERROR` : WebSocket erreur
- `PERMISSION_GRANTED` : Permission microphone accordée
- `PERMISSION_DENIED` : Permission microphone refusée
- `APP_LIFECYCLE_PAUSE` : App en pause
- `APP_LIFECYCLE_RESUME` : App reprise
- `PHONE_CALL_RECEIVED` : Appel téléphonique reçu

---

## ERREURS

### Erreurs permission

- `PERMISSION_DENIED` : Permission microphone refusée
- `PERMANENTLY_DENIED` : Permission refusée définitivement

**Récupération** :
- Afficher message explicite
- Rediriger vers settings système
- Passer en état ERROR

---

### Erreurs recorder

- `RECORDER_INIT_FAILED` : Recorder initialisation échouée
- `RECORDER_START_FAILED` : Recorder démarrage échoué
- `RECORDER_STOP_FAILED` : Recorder arrêt échoué

**Récupération** :
- Réinitialiser recorder
- Passer en état ERROR
- Proposer retry

---

### Erreurs WebSocket

- `WEBSOCKET_CONNECTION_FAILED` : Connexion échouée
- `WEBSOCKET_SEND_FAILED` : Envoi échoué
- `WEBSOCKET_RECEIVE_FAILED` : Réception échouée
- `WEBSOCKET_TIMEOUT` : Timeout

**Récupération** :
- Reconnecter WebSocket
- Passer en état ERROR
- Proposer retry

---

### Erreurs STT

- `STT_TRANSCRIPTION_FAILED` : Transcription échouée
- `STT_TIMEOUT` : Timeout STT
- `STT_EMPTY_RESULT` : Résultat vide

**Récupération** :
- Afficher message d'erreur
- Passer en état IDLE
- Proposer retry

---

### Erreurs TTS

- `TTS_SYNTHESIS_FAILED` : Synthèse échouée
- `TTS_TIMEOUT` : Timeout TTS
- `TTS_EMPTY_AUDIO` : Audio vide

**Récupération** :
- Afficher message d'erreur
- Passer en état IDLE
- Proposer retry (texte seulement)

---

### Erreurs AudioPlayer

- `AUDIO_PLAYER_INIT_FAILED` : Initialisation échouée
- `AUDIO_PLAYER_PLAY_FAILED` : Lecture échouée
- `AUDIO_PLAYER_STOP_FAILED` : Arrêt échoué

**Récupération** :
- Réinitialiser AudioPlayer
- Passer en état ERROR
- Proposer retry

---

## RÉCUPÉRATION

### Stratégie de récupération

1. **Erreur permission** → Rediriger settings
2. **Erreur recorder** → Réinitialiser + retry
3. **Erreur WebSocket** → Reconnecter + retry
4. **Erreur STT** → Afficher erreur + retry
5. **Erreur TTS** → Fallback texte + retry
6. **Erreur AudioPlayer** → Réinitialiser + retry

### Timeout de récupération

- Permission : immédiat (redirection)
- Recorder : 5 secondes
- WebSocket : 10 secondes
- STT : 30 secondes
- TTS : 30 secondes
- AudioPlayer : 5 secondes

---

## LOGGING

### Logs d'état

Chaque transition doit être loggée :
```
[VOCAL_STATE] IDLE → LISTENING
[VOCAL_STATE] LISTENING → PROCESSING
[VOCAL_STATE] PROCESSING → SPEAKING
[VOCAL_STATE] SPEAKING → LISTENING (conversation mode)
```

### Logs d'erreur

Chaque erreur doit être loggée avec contexte :
```
[VOCAL_ERROR] RECORDER_INIT_FAILED: [détails]
[VOCAL_ERROR] WEBSOCKET_CONNECTION_FAILED: [détails]
[VOCAL_ERROR] STT_TRANSCRIPTION_FAILED: [détails]
```

### Logs d'événement

Chaque événement doit être loggée :
```
[VOCAL_EVENT] VOCAL_START
[VOCAL_EVENT] TRANSCRIPTION_RECEIVED: "Bonjour Bobodo"
[VOCAL_EVENT] AUDIO_RESPONSE_RECEIVED: 1024 bytes
[VOCAL_EVENT] AUDIO_COMPLETE
```

---

## RECOMMANDATIONS

### Phase 1 (CRITIQUE)

1. **Implémenter enum VocalState**
   - Remplacer booléens par enum
   - Ajouter validation des transitions
   - Ajouter logging d'état

2. **Ajouter état ERROR**
   - Gérer toutes les erreurs
   - Proposer retry
   - Logging d'erreur

3. **Ajouter état INTERRUPTED**
   - Gérer interruptions utilisateur
   - Récupération propre
   - Logging d'interruption

### Phase 2 (IMPORTANT)

4. **Ajouter état PROCESSING local**
   - Synchroniser avec BobodoProvider
   - Indicateur visuel clair
   - Logging de progression

5. **Ajouter état ENDED**
   - Nettoyage explicite
   - Fermeture WebSocket
   - Libération ressources

6. **Implémenter logging complet**
   - Transitions
   - Erreurs
   - Événements
   - Performance

### Phase 3 (OPTIONNEL)

7. **Ajouter métriques**
   - Temps par état
   - Taux d'erreur
   - Taux de récupération

8. **Ajouter monitoring**
   - Dashboard d'état
   - Alertes en temps réel
   - Analytics

---

## CONCLUSION

### Machine d'états actuelle

**Problèmes majeurs** :
- Pas de machine d'états formelle
- 5 booléens simples non validés
- Pas de gestion d'erreurs
- Pas de récupération
- Pas de logging d'état

**Impact** :
- Instabilité potentielle
- Difficile à déboguer
- Difficile à étendre

### Machine d'états cible

**Améliorations** :
- Enum VocalState avec 7 états
- Transitions validées
- Gestion d'erreurs explicite
- Récupération automatique
- Logging complet

**Impact** :
- Stabilité améliorée
- Débogage facilité
- Extensibilité garantie

---

## LIVRABLES SUIVANTS

1. BOBODO_VOICE_AUDIO_ARCHITECTURE.md
2. BOBODO_VOICE_INTERRUPTION_AUDIT.md
3. BOBODO_VOICE_AUTO_LISTENING.md
4. BOBODO_VOICE_MEMORY_COMPATIBILITY_V2.md
5. BOBODO_VOICE_UX_FINAL.md
6. BOBODO_FULL_VOICE_CONVERSATION_ARCHITECTURE.md
