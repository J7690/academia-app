# BOBODO VOICE - Flutter Changes

## Date
12 Juin 2026

---

## OBJECTIF

Documenter les modifications Flutter requises pour le mode conversation vocale continue.

---

## FICHIER CIBLE

`academia_app/lib/features/student/tabs/student_bobodo_tab.dart`

---

## ÉTAT ACTUEL

### Mode Dictée (existant)

**Flux** :
1. Utilisateur active mode dictée (bouton micro)
2. Utilisateur enregistre (maintient bouton)
3. Utilisateur arrête enregistrement
4. Transcription envoyée
5. Texte affiché dans champ de saisie
6. Utilisateur valide envoi manuel
7. Bobodo répond
8. Audio TTS joué si autoTtsEnabled

**États** :
- `_isRecordingMode` : mode enregistrement activé
- `_isRecording` : enregistrement en cours
- `_isTranscribing` : transcription en cours
- `_isSending` : envoi en cours
- `_isSpeaking` : lecture audio en cours

**Boutons** :
- Annuler (close)
- Stop (stop)

---

## MODIFICATIONS REQUISES

### 1. Ajout Mode Conversation

**Nouvel état** :
```dart
bool _isConversationMode = false;
```

**Toggle Mode Dictée / Mode Conversation** :
```dart
void _toggleVoiceMode() {
  setState(() {
    _isConversationMode = !_isConversationMode;
    if (_isConversationMode) {
      // Entrer en mode conversation
      _startConversationMode();
    } else {
      // Quitter mode conversation
      _stopConversationMode();
    }
  });
}
```

**UI Toggle** :
- Ajouter un switch ou toggle dans l'interface
- Position : près du bouton micro
- Label : "Mode Dictée" / "Mode Conversation"

---

### 2. Machine d'états Conversationnelle

**Nouveaux états** :
```dart
enum ConversationState {
  idle,           // En attente
  listening,      // Écoute utilisateur
  processing,     // Traitement transcription
  thinking,       // Bobodo réfléchit
  responding,     // Bobodo répond
  playing,        // Lecture audio
  paused,         // Pause
  ended,          // Fin session
}

ConversationState _conversationState = ConversationState.idle;
```

**Transitions** :
1. `idle` → `listening` : démarrage écoute
2. `listening` → `processing` : fin enregistrement
3. `processing` → `thinking` : transcription reçue
4. `thinking` → `responding` : réponse générée
5. `responding` → `playing` : audio reçu
6. `playing` → `listening` : fin lecture (réactivation auto)
7. `playing` → `paused` : utilisateur coupe
8. `paused` → `listening` : utilisateur reprend
9. `any` → `ended` : utilisateur quitte

---

### 3. Réactivation Automatique du Micro

**Méthode** :
```dart
void _onAudioPlaybackComplete() {
  if (_isConversationMode && _conversationState != ConversationState.ended) {
    // Réactivation automatique de l'écoute
    setState(() {
      _conversationState = ConversationState.listening;
    });
    _startVocalRecording();
  }
}
```

**Modification** :
- Modifier `_onAudioResponseReceived` pour appeler `_onAudioPlaybackComplete` après lecture
- Ajouter listener sur `_audioPlayer.onPlayerComplete`

---

### 4. Boutons de Contrôle

**Bouton Quitter Conversation** :
```dart
void _quitConversation() {
  setState(() {
    _isConversationMode = false;
    _conversationState = ConversationState.ended;
  });
  _stopVocalRecording();
  _stopAudioPlayback();
}
```

**UI** :
- Position : haut de l'écran
- Style : bouton rouge "Quitter Conversation"

---

**Bouton Couper Bobodo** :
```dart
void _cutBobodo() {
  _stopAudioPlayback();
  setState(() {
    _conversationState = ConversationState.paused;
  });
}
```

**UI** :
- Position : visible pendant `_isSpeaking`
- Style : bouton "Couper"

---

**Bouton Rejouer Dernière Réponse** :
```dart
void _replayLastResponse() {
  if (_lastAudioResponse != null) {
    _replayAudio();
    setState(() {
      _conversationState = ConversationState.playing;
    });
  }
}
```

**UI** :
- Position : visible après `_isSpeaking`
- Style : bouton "Rejouer"

---

### 5. Affichage des États

**Indicateur d'état** :
```dart
Widget _buildConversationStateIndicator() {
  if (!_isConversationMode) return SizedBox.shrink();

  String stateText;
  IconData stateIcon;
  Color stateColor;

  switch (_conversationState) {
    case ConversationState.idle:
      stateText = 'En attente';
      stateIcon = Icons.hourglass_empty;
      stateColor = PrepTheme.textTertiary;
      break;
    case ConversationState.listening:
      stateText = 'Écoute...';
      stateIcon = Icons.mic;
      stateColor = PrepTheme.primary;
      break;
    case ConversationState.processing:
      stateText = 'Traitement...';
      stateIcon = Icons.settings;
      stateColor = PrepTheme.warning;
      break;
    case ConversationState.thinking:
      stateText = 'Bobodo réfléchit...';
      stateIcon = Icons.psychology;
      stateColor = PrepTheme.primary;
      break;
    case ConversationState.responding:
      stateText = 'Réponse...';
      stateIcon = Icons.chat;
      stateColor = PrepTheme.primary;
      break;
    case ConversationState.playing:
      stateText = 'Lecture...';
      stateIcon = Icons.volume_up;
      stateColor = PrepTheme.primary;
      break;
    case ConversationState.paused:
      stateText = 'Pause';
      stateIcon = Icons.pause;
      stateColor = PrepTheme.warning;
      break;
    case ConversationState.ended:
      stateText = 'Session terminée';
      stateIcon = Icons.check_circle;
      stateColor = PrepTheme.success;
      break;
  }

  return Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: stateColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(stateIcon, size: 16, color: stateColor),
        SizedBox(width: 8),
        Text(stateText, style: TextStyle(color: stateColor)),
      ],
    ),
  );
}
```

**Position** :
- En haut de l'écran, sous le bouton Quitter Conversation
- Visible uniquement en mode conversation

---

### 6. Gestion des Interruptions

**Utilisateur coupe Bobodo** :
- Bouton Couper Bobodo → `_cutBobodo()`
- Transition : `playing` → `paused`

**Utilisateur quitte écran** :
- `dispose()` → `_quitConversation()`
- Nettoyage WebSocket, enregistrement, audio

**Perte Internet** :
- WebSocket error → `_onVocalError()`
- Transition : `any` → `paused`
- Afficher message "Connexion perdue"

**Retour Internet** :
- Reconnexion WebSocket → `_connectVocalWebSocket()`
- Transition : `paused` → `listening`
- Redémarrer enregistrement

**Timeout inactivité** :
- Timer inactivité (ex: 30s sans parole)
- Transition : `listening` → `idle`
- Afficher message "Session en pause"

**Reprise session** :
- Utilisateur tape ou parle
- Transition : `idle` → `listening`
- Redémarrer enregistrement

---

### 7. Timeout Inactivité

**Timer** :
```dart
Timer? _inactivityTimer;

void _resetInactivityTimer() {
  _inactivityTimer?.cancel();
  _inactivityTimer = Timer(Duration(seconds: 30), () {
    if (_isConversationMode && _conversationState == ConversationState.listening) {
      setState(() {
        _conversationState = ConversationState.idle;
      });
      _stopVocalRecording();
    }
  });
}
```

**Activation** :
- Reset timer à chaque parole détectée
- Reset timer à chaque transition d'état

---

### 8. Modifications Existantes

**_onTranscriptionReceived** :
```dart
void _onTranscriptionReceived(String text) {
  if (_isConversationMode) {
    // Mode conversation : envoi automatique
    setState(() {
      _isTranscribing = false;
      _conversationState = ConversationState.thinking;
    });
    final provider = context.read<BobodoProvider>();
    provider.sendUserMessage(text);
  } else {
    // Mode dictée : affichage dans champ
    setState(() {
      _isTranscribing = false;
      _isRecordingMode = false;
    });
    _controller.text = text;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
  }
}
```

**_onAudioResponseReceived** :
```dart
void _onAudioResponseReceived(String audioBase64) async {
  try {
    final audioBytes = base64Decode(audioBase64);
    _lastAudioResponse = audioBytes;

    if (_isConversationMode) {
      setState(() {
        _conversationState = ConversationState.playing;
      });
    }

    if (_autoTtsEnabled) {
      await _audioPlayer.setSourceBytes(audioBytes);
      await _audioPlayer.resume();

      setState(() => _isSpeaking = true);

      _audioPlayer.onPlayerComplete.listen((_) {
        setState(() => _isSpeaking = false);
        if (_isConversationMode) {
          _onAudioPlaybackComplete();
        }
      });
    }
  } catch (e) {
    debugPrint('[VOICE_AUDIO_ERROR] $e');
  }
}
```

---

## RÉSUMÉ DES MODIFICATIONS

### Nouveaux états
- `_isConversationMode` : toggle mode conversation
- `_conversationState` : machine d'états conversationnelle

### Nouvelles méthodes
- `_toggleVoiceMode()` : toggle mode dictée/conversation
- `_startConversationMode()` : démarrage mode conversation
- `_stopConversationMode()` : arrêt mode conversation
- `_quitConversation()` : quitter conversation
- `_cutBobodo()` : couper Bobodo
- `_replayLastResponse()` : rejouer dernière réponse
- `_onAudioPlaybackComplete()` : fin lecture audio
- `_resetInactivityTimer()` : reset timer inactivité

### Nouveaux widgets
- `_buildConversationStateIndicator()` : indicateur d'état
- Bouton Quitter Conversation
- Bouton Couper Bobodo
- Bouton Rejouer Dernière Réponse
- Toggle Mode Dictée / Mode Conversation

### Modifications existantes
- `_onTranscriptionReceived()` : envoi automatique en mode conversation
- `_onAudioResponseReceived()` : réactivation auto en mode conversation
- `dispose()` : nettoyage mode conversation

---

## IMPACT SUR CODE EXISTANT

### Aucun impact sur :
- Bobodo texte
- Mémoire émotionnelle
- Historique
- RAG
- Support Escalation
- Sessions existantes
- Fonctionnalités Academia

### Impact sur :
- Mode dictée (ajout toggle)
- Interface Bobodo (ajout UI mode conversation)

---

## TESTS REQUIS

1. Toggle Mode Dictée / Mode Conversation
2. Cycle conversationnel complet
3. Réactivation automatique du micro
4. Boutons de contrôle (Quitter, Couper, Rejouer)
5. Affichage des états
6. Interruptions (couper, quitter, perte Internet)
7. Timeout inactivité
8. Reprise session
9. Non-régression mode dictée

---

## SIGN-OFF

**Document créé** : 12 Juin 2026
**Auteur** : Cascade AI
**Statut** : PRÊT POUR IMPLÉMENTATION
