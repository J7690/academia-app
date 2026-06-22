# BOBODO VOICE - Interruption Audit

## Date
12 Juin 2026

---

## OBJECTIF

Auditer la gestion des interruptions pour les cas obligatoires et documenter le comportement attendu.

---

## CAS D'INTERRUPTION OBLIGATOIRES

1. User coupe Bobodo
2. User parle pendant la réponse
3. User ferme l'écran
4. User reçoit un appel
5. User perd Internet
6. User revient

---

## ARCHITECTURE ACTUELLE (CODE RÉEL)

### Source de vérité analysée

**Flutter** :
- `academia_app/lib/features/student/tabs/student_bobodo_tab.dart` (1584 lignes)

**Gestion cycle de vie** :
- `initState()` (lignes 82-90)
- `dispose()` (lignes 92-110)

---

## CAS 1 : USER COUPE BOBODO

### Comportement actuel

**Bouton stop pendant lecture** (lignes 739-747) :
```dart
if (!isUser && _isSpeaking) ...[
  const SizedBox(width: 2),
  _FeedbackButton(
    icon: Icons.stop_circle_outlined,
    isActive: false,
    isUser: isUser,
    onTap: _stopAudioPlayback,
  ),
],
```

**Méthode _stopAudioPlayback()** (lignes 1304-1307) :
```dart
void _stopAudioPlayback() {
  _audioPlayer.stop();
  setState(() => _isSpeaking = false);
}
```

**Comportement** :
- ✅ Bouton stop existe
- ✅ Stop AudioPlayer
- ✅ Met `_isSpeaking = false`
- ❌ Micro ne se réactive pas
- ❌ Pas de transition vers état LISTENING

---

### Comportement attendu (mode conversation)

**Action** : User clique bouton stop

**Transitions** :
```
SPEAKING → INTERRUPTED → LISTENING
```

**Actions** :
1. Stop AudioPlayer
2. Met `_isSpeaking = false`
3. Passer `_vocalState = VocalState.interrupted`
4. Réactiver micro automatiquement
5. Passer `_vocalState = VocalState.listening`

**Code cible** :
```dart
void _stopAudioPlayback() {
  _audioPlayer.stop();
  setState(() => _isSpeaking = false);
  
  if (_isConversationMode) {
    setState(() => _vocalState = VocalState.interrupted);
    _startVocalRecording(); // Réactivation automatique
  }
}
```

---

### Comportement attendu (mode dictée)

**Action** : User clique bouton stop

**Transitions** :
```
SPEAKING → IDLE
```

**Actions** :
1. Stop AudioPlayer
2. Met `_isSpeaking = false`
3. Passer `_vocalState = VocalState.idle`
4. NE PAS réactiver micro

**Code cible** :
```dart
void _stopAudioPlayback() {
  _audioPlayer.stop();
  setState(() => _isSpeaking = false);
  setState(() => _vocalState = VocalState.idle);
}
```

---

## CAS 2 : USER PARLE PENDANT LA RÉPONSE

### Comportement actuel

**Détection** :
- ❌ Aucune détection de parole pendant la lecture
- ❌ Pas de VAD
- ❌ Pas de monitoring audio entrée pendant TTS

**Comportement** :
- User ne peut pas parler pendant la lecture
- Half duplex strict
- Pas d'interruption possible

---

### Comportement attendu (mode conversation)

**Action** : User parle pendant TTS

**Détection** :
- VAD côté client détecte parole
- Ou monitoring audio entrée pendant TTS

**Transitions** :
```
SPEAKING → INTERRUPTED → LISTENING
```

**Actions** :
1. Détecter parole (VAD)
2. Stop AudioPlayer
3. Met `_isSpeaking = false`
4. Passer `_vocalState = VocalState.interrupted`
5. Réactiver micro automatiquement
6. Passer `_vocalState = VocalState.listening`

**Code cible** :
```dart
// VAD monitoring pendant TTS
void _startVadMonitoring() {
  _vadSubscription = _vadService.activityStream.listen((isActive) {
    if (isActive && _isSpeaking && _isConversationMode) {
      _stopAudioPlayback(); // Interruption automatique
    }
  });
}
```

---

### Comportement attendu (mode dictée)

**Action** : User parle pendant TTS

**Comportement** :
- Ignorer (mode dictée = contrôle manuel)
- User doit cliquer stop manuellement

---

## CAS 3 : USER FERME L'ÉCRAN

### Comportement actuel

**Cycle de vie** (lignes 92-110) :
```dart
@override
void dispose() {
  // Vocal
  _recorder.closeRecorder();
  _vocalService.disconnect();
  _vocalService.dispose();
  _messageSubscription?.cancel();
  _errorSubscription?.cancel();
  _audioStreamController?.close();
  _recordingTimer?.cancel();
  _audioLevelTimer?.cancel();

  // Existant
  _controller.dispose();
  _scrollController.dispose();
  _focusNode.dispose();
  _audioPlayer.dispose();
  super.dispose();
}
```

**Comportement** :
- ✅ WebSocket déconnecté
- ✅ Recorder fermé
- ✅ AudioPlayer disposé
- ✅ Timers annulés
- ❌ Pas de sauvegarde d'état
- ❌ Pas de reprise possible

---

### Comportement attendu (mode conversation)

**Action** : User ferme l'écran

**Transitions** :
```
[ANY STATE] → PAUSED
```

**Actions** :
1. Sauvegarder l'état actuel
2. Pause AudioPlayer (si en cours)
3. Stop recorder (si en cours)
4. Garder WebSocket connecté
5. Passer `_vocalState = VocalState.paused`

**Reprise** :
```
PAUSED → [PREVIOUS STATE]
```

**Actions** :
1. Restaurer l'état sauvegardé
2. Reprendre AudioPlayer (si était SPEAKING)
3. Réactiver recorder (si était LISTENING)
4. Passer `_vocalState = previousState`

**Code cible** :
```dart
@override
void dispose() {
  if (_isConversationMode) {
    _saveState(); // Sauvegarder état
  }
  
  _recorder.closeRecorder();
  _vocalService.disconnect();
  // ... reste du dispose
}

void _saveState() {
  _savedState = _vocalState;
  _savedAudioBytes = _lastAudioResponse;
}

void _restoreState() {
  if (_savedState == VocalState.speaking && _savedAudioBytes != null) {
    _audioPlayer.setSourceBytes(_savedAudioBytes!);
    _audioPlayer.resume();
    setState(() => _isSpeaking = true);
  } else if (_savedState == VocalState.listening) {
    _startVocalRecording();
  }
}
```

---

### Comportement attendu (mode dictée)

**Action** : User ferme l'écran

**Comportement** :
- Dispose complet (comme actuel)
- Pas de sauvegarde
- Pas de reprise

---

## CAS 4 : USER REÇOIT UN APPEL

### Comportement actuel

**Détection** :
- ❌ Aucune détection d'appel téléphonique
- ❌ Pas de listener d'appel
- ❌ Pas de gestion d'interruption

**Comportement** :
- Appel téléphonique interrompt l'audio système
- AudioPlayer peut continuer en arrière-plan
- Pas de gestion explicite

---

### Comportement attendu (mode conversation)

**Action** : User reçoit un appel

**Détection** :
- Utiliser `flutter_phone_state` ou équivalent
- Écouter les événements d'appel

**Transitions** :
```
[ANY STATE] → PAUSED
```

**Actions** :
1. Détecter appel entrant
2. Pause AudioPlayer (si en cours)
3. Stop recorder (si en cours)
4. Passer `_vocalState = VocalState.paused`
5. Afficher notification "Conversation en pause"

**Reprise** :
```
PAUSED → [PREVIOUS STATE]
```

**Actions** :
1. Détecter fin d'appel
2. Restaurer l'état sauvegardé
3. Reprendre AudioPlayer (si était SPEAKING)
4. Réactiver recorder (si était LISTENING)
5. Passer `_vocalState = previousState`

**Code cible** :
```dart
// Détection d'appel
void _initPhoneStateListener() {
  _phoneStateSubscription = PhoneState.phoneStateStream.listen((state) {
    if (state == PhoneStateState.CALL_INCOMING || 
        state == PhoneStateState.CALL_STARTED) {
      _pauseConversation();
    } else if (state == PhoneStateState.CALL_ENDED) {
      _resumeConversation();
    }
  });
}

void _pauseConversation() {
  if (_isSpeaking) {
    _audioPlayer.pause();
  }
  if (_isRecording) {
    _recorder.pauseRecorder();
  }
  setState(() => _vocalState = VocalState.paused);
}

void _resumeConversation() {
  if (_savedState == VocalState.speaking) {
    _audioPlayer.resume();
  } else if (_savedState == VocalState.listening) {
    _recorder.resumeRecorder();
  }
  setState(() => _vocalState = _savedState);
}
```

---

### Comportement attendu (mode dictée)

**Action** : User reçoit un appel

**Comportement** :
- Pause AudioPlayer (si en cours)
- Stop recorder (si en cours)
- Pas de reprise automatique
- User doit recliquer manuellement

---

## CAS 5 : USER PERD INTERNET

### Comportement actuel

**Détection** :
- ❌ Aucune détection de perte réseau
- ❌ Pas de listener de connectivité
- ❌ Pas de gestion d'erreur réseau

**Comportement** :
- WebSocket peut se déconnecter
- Erreur loguée mais pas gérée
- Pas de retry automatique

---

### Comportement attendu (mode conversation)

**Action** : User perd Internet

**Détection** :
- Utiliser `connectivity_plus` ou équivalent
- Écouter les événements de connectivité

**Transitions** :
```
[ANY STATE] → ERROR
```

**Actions** :
1. Détecter perte de connexion
2. Passer `_vocalState = VocalState.error`
3. Afficher message d'erreur "Connexion perdue"
4. Tenter de reconnecter WebSocket
5. Passer `_vocalState = VocalState.idle` si reconnexion réussie

**Code cible** :
```dart
// Détection de connectivité
void _initConnectivityListener() {
  _connectivitySubscription = Connectivity()
    .onConnectivityChanged
    .listen((ConnectivityResult result) {
      if (result == ConnectivityResult.none) {
        _handleNetworkLoss();
      } else {
        _handleNetworkRecovery();
      }
    });
}

void _handleNetworkLoss() {
  setState(() => _vocalState = VocalState.error);
  _errorMessage = "Connexion perdue";
  
  if (_isSpeaking) {
    _audioPlayer.stop();
  }
  if (_isRecording) {
    _recorder.stopRecorder();
  }
}

void _handleNetworkRecovery() {
  _reconnectWebSocket();
  setState(() => _vocalState = VocalState.idle);
}
```

---

### Comportement attendu (mode dictée)

**Action** : User perd Internet

**Comportement** :
- Même que mode conversation
- Gestion d'erreur identique

---

## CAS 6 : USER REVIENT

### Comportement actuel

**Cycle de vie** :
- `initState()` appelé au retour
- Reconnexion WebSocket (lignes 1149-1177)
- Rechargement des messages

**Comportement** :
- ✅ Reconnexion WebSocket
- ✅ Rechargement messages
- ❌ Pas de restauration d'état vocal
- ❌ Pas de reprise de lecture

---

### Comportement attendu (mode conversation)

**Action** : User revient sur l'écran

**Transitions** :
```
PAUSED → [PREVIOUS STATE]
```

**Actions** :
1. Restaurer l'état sauvegardé
2. Reconnecter WebSocket
3. Reprendre AudioPlayer (si était SPEAKING)
4. Réactiver recorder (si était LISTENING)
5. Passer `_vocalState = previousState`

**Code cible** :
```dart
@override
void initState() {
  super.initState();
  
  _audioStreamController = StreamController<Uint8List>();
  _audioStreamController?.stream.listen(_onAudioData);
  _initRecorder();
  _connectVocalWebSocket();
  
  if (_isConversationMode) {
    _restoreState(); // Restaurer état sauvegardé
  }
}
```

---

### Comportement attendu (mode dictée)

**Action** : User revient sur l'écran

**Comportement** :
- Comportement actuel (pas de restauration)
- User doit recliquer manuellement

---

## SYNTHÈSE

### Cas gérés actuellement

| Cas | Géré | Complet | Mode conversation | Mode dictée |
|-----|------|---------|------------------|-------------|
| User coupe Bobodo | ✅ | ⚠️ (pas de réactivation) | ❌ | ✅ |
| User parle pendant réponse | ❌ | ❌ | ❌ | N/A |
| User ferme l'écran | ✅ | ⚠️ (pas de reprise) | ❌ | ✅ |
| User reçoit appel | ❌ | ❌ | ❌ | ❌ |
| User perd Internet | ❌ | ❌ | ❌ | ❌ |
| User revient | ✅ | ⚠️ (pas de restauration) | ❌ | ✅ |

---

### Cas à implémenter (mode conversation)

**CRITIQUE** :
1. Réactivation automatique du micro après stop
2. Détection VAD pendant TTS
3. Sauvegarde d'état à la fermeture
4. Restauration d'état au retour
5. Détection d'appel téléphonique
6. Gestion de perte réseau

**IMPORTANT** :
7. Reprise après appel
8. Retry automatique après perte réseau

---

## RECOMMANDATIONS

### Phase 1 (CRITIQUE)

1. **Réactivation automatique du micro**
   - Implémenter dans `_stopAudioPlayback()`
   - Conditionnel sur `_isConversationMode`
   - Tests sur appareil réel

2. **Sauvegarde d'état**
   - Implémenter `_saveState()` dans `dispose()`
   - Sauvegarder `_vocalState` et `_lastAudioResponse`
   - Tests sur appareil réel

3. **Restauration d'état**
   - Implémenter `_restoreState()` dans `initState()`
   - Restaurer état sauvegardé
   - Tests sur appareil réel

### Phase 2 (IMPORTANT)

4. **Détection d'appel téléphonique**
   - Package `flutter_phone_state`
   - Pause à l'appel, reprise après
   - Tests sur appareil réel

5. **Gestion de perte réseau**
   - Package `connectivity_plus`
   - Détection + retry automatique
   - Tests sur différents réseaux

### Phase 3 (OPTIONNEL)

6. **VAD pendant TTS**
   - Package VAD
   - Interruption automatique
   - Tests approfondis

---

## CONCLUSION

### Gestion des interruptions actuelle

**Problèmes majeurs** :
- Pas de réactivation automatique du micro
- Pas de détection VAD
- Pas de sauvegarde d'état
- Pas de détection d'appel
- Pas de gestion de perte réseau

**Impact** :
- Mode conversation impossible
- UX dégradée
- Instabilité en cas d'interruption

### Gestion des interruptions cible

**Améliorations** :
- Réactivation automatique du micro
- Sauvegarde/restauration d'état
- Détection d'appel téléphonique
- Gestion de perte réseau
- VAD pendant TTS (optionnel)

**Impact** :
- Mode conversation possible
- UX améliorée
- Stabilité garantie

---

## LIVRABLES SUIVANTS

1. BOBODO_VOICE_AUTO_LISTENING.md
2. BOBODO_VOICE_MEMORY_COMPATIBILITY_V2.md
3. BOBODO_VOICE_UX_FINAL.md
4. BOBODO_FULL_VOICE_CONVERSATION_ARCHITECTURE.md
