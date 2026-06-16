# BOBODO VOICE - Auto Listening Audit

## Date
12 Juin 2026

---

## OBJECTIF

Auditer la faisabilité de la réactivation automatique du microphone à la fin de la réponse vocale. Déterminer les impacts et les risques.

---

## ARCHITECTURE ACTUELLE (CODE RÉEL)

### Source de vérité analysée

**Flutter** :
- `academia_app/lib/features/student/tabs/student_bobodo_tab.dart` (lignes 1284-1302)

---

## COMPORTEMENT ACTUEL

### Fin de lecture TTS

**Code actuel** (lignes 1295-1297) :
```dart
_audioPlayer.onPlayerComplete.listen((_) {
  setState(() => _isSpeaking = false);
  // RIEN - micro ne se réactive pas
});
```

**Comportement** :
- ✅ `_isSpeaking = false`
- ❌ Micro ne se réactive pas
- ❌ User doit recliquer manuellement
- ❌ Pas de cycle continu

---

## OBJECTIF CIBLE

### Comportement attendu (mode conversation)

**À la fin de la réponse vocale** :
```
TTS terminé
↓
lecture terminée
↓
micro réactivé automatiquement
```

**Cycle continu** :
```
User parle → stop → transcription → envoi auto → réponse → TTS auto → micro réactif → User reparle
```

---

## ANALYSE DE FAISABILITÉ

### 1. Réactivation automatique dans onPlayerComplete

**Code cible** :
```dart
_audioPlayer.onPlayerComplete.listen((_) {
  setState(() => _isSpeaking = false);
  
  if (_isConversationMode) {
    _startVocalRecording(); // Réactivation automatique
  }
});
```

**Faisabilité** : ✅ **FAISABLE**

**Prérequis** :
- `_isConversationMode` flag doit exister
- `_startVocalRecording()` doit être appelable
- Permission microphone déjà accordée

---

### 2. Permission microphone

**Code actuel** (lignes 1179-1182) :
```dart
Future<bool> _requestPermission() async {
  final status = await Permission.microphone.request();
  return status.isGranted;
}
```

**Comportement** :
- Permission demandée au premier clic sur micro
- Une fois accordée, persiste tant que l'app est installée

**Impact** :
- ✅ Pas de problème : permission déjà accordée
- ✅ Pas besoin de redemander
- ✅ Réactivation automatique possible

---

### 3. Recorder initialisation

**Code actuel** (lignes 1141-1147) :
```dart
Future<void> _initRecorder() async {
  try {
    await _recorder.openRecorder();
  } catch (e) {
    debugPrint('[VOICE_RECORDER_INIT_ERROR] $e');
  }
}
```

**Comportement** :
- Recorder initialisé dans `initState()`
- Reste ouvert tant que le widget est monté

**Impact** :
- ✅ Pas de problème : recorder déjà initialisé
- ✅ Pas besoin de réinitialiser
- ✅ Réactivation automatique possible

---

### 4. Cycle de vie Flutter

**Scénario** :
1. User active mode conversation
2. User parle → stop → transcription → envoi
3. Bobodo répond → TTS
4. TTS terminé → micro réactivé automatiquement
5. User reparle → cycle continue

**Risques** :
- Widget dispose pendant la réactivation
- Recorder error pendant la réactivation
- WebSocket déconnecté pendant la réactivation

**Mitigation** :
- Vérifier que le widget est monté avant réactivation
- Try-catch autour de `_startVocalRecording()`
- Reconnecter WebSocket si nécessaire

---

## IMPACTS

### 1. Impact UX

**Positif** :
- ✅ Cycle continu sans clics
- ✅ Mode conversation naturel
- ✅ Expérience ChatGPT Voice

**Négatif** :
- ⚠️ User peut être surpris par la réactivation automatique
- ⚠️ Peut être gênant si user ne veut plus parler
- ⚠️ Nécessite un bouton "Stop conversation" explicite

**Mitigation** :
- Indicateur visuel clair (micro actif)
- Bouton "Arrêter la conversation" évident
- Tooltip explicatif
- Onboarding

---

### 2. Impact technique

**Positif** :
- ✅ Implémentation simple (quelques lignes)
- ✅ Pas de nouveau package requis
- ✅ Compatible avec architecture actuelle

**Négatif** :
- ⚠️ Gestion d'erreurs supplémentaire
- ⚠️ Tests sur appareil réel requis
- ⚠️ Dépendance à `_isConversationMode`

**Mitigation** :
- Try-catch robuste
- Tests approfondis
- Documentation claire

---

### 3. Impact performance

**Positif** :
- ✅ Pas d'impact significatif
- ✅ Recorder déjà initialisé
- ✅ Pas de surcharge CPU

**Négatif** :
- ⚠️ Micro actif en permanence (mode conversation)
- ⚠️ Consommation batterie légèrement augmentée

**Mitigation** :
- Désactiver mode conversation facilement
- Timeout d'inactivité
- Indicateur de batterie

---

## RISQUES

### 1. Recorder error

**Risque** : Recorder peut échouer à la réactivation

**Mitigation** :
```dart
_audioPlayer.onPlayerComplete.listen((_) {
  setState(() => _isSpeaking = false);
  
  if (_isConversationMode) {
    try {
      _startVocalRecording();
    } catch (e) {
      debugPrint('[VOICE_AUTO_LISTEN_ERROR] $e');
      setState(() => _vocalState = VocalState.error);
      _errorMessage = "Impossible de réactiver le micro";
    }
  }
});
```

---

### 2. Widget dispose

**Risque** : Widget dispose pendant la réactivation

**Mitigation** :
```dart
_audioPlayer.onPlayerComplete.listen((_) {
  if (!mounted) return; // Vérifier que le widget est monté
  
  setState(() => _isSpeaking = false);
  
  if (_isConversationMode) {
    _startVocalRecording();
  }
});
```

---

### 3. WebSocket déconnecté

**Risque** : WebSocket déconnecté pendant la réactivation

**Mitigation** :
```dart
Future<void> _startVocalRecording() async {
  if (!_isVocalConnected) {
    await _connectVocalWebSocket();
  }
  
  // ... reste du code
}
```

---

### 4. User confusion

**Risque** : User ne comprend pas pourquoi le micro se réactive

**Mitigation** :
- Indicateur visuel clair (icône micro animée)
- Message explicatif "Micro actif - Parlez pour continuer"
- Bouton "Arrêter la conversation" évident
- Onboarding explicite

---

## SOLUTION RECOMMANDÉE

### Phase 1 (CRITIQUE - Auto listening basique)

**Implémentation** :

1. **Ajouter flag `_isConversationMode`**
   ```dart
   bool _isConversationMode = false;
   ```

2. **Modifier `onPlayerComplete`**
   ```dart
   _audioPlayer.onPlayerComplete.listen((_) {
     if (!mounted) return;
     
     setState(() => _isSpeaking = false);
     
     if (_isConversationMode) {
       try {
         _startVocalRecording();
       } catch (e) {
         debugPrint('[VOICE_AUTO_LISTEN_ERROR] $e');
         setState(() => _vocalState = VocalState.error);
       }
     }
   });
   ```

3. **Ajouter gestion d'erreurs**
   - Try-catch autour de `_startVocalRecording()`
   - Vérifier `mounted` avant setState
   - Reconnecter WebSocket si nécessaire

4. **Ajouter indicateur visuel**
   - Icône micro animée quand actif
   - Message "Micro actif"
   - Bouton "Arrêter la conversation"

---

### Phase 2 (IMPORTANT - UX améliorée)

**Implémentation** :

5. **Bouton "Arrêter la conversation"**
   - Remplace le bouton micro en mode conversation
   - Désactive `_isConversationMode`
   - Arrête le recorder

6. **Timeout d'inactivité**
   - Si user ne parle pas pendant 30 secondes
   - Désactiver mode conversation automatiquement
   - Afficher message "Conversation terminée"

7. **Onboarding**
   - Expliquer le mode conversation
   - Montrer comment arrêter
   - Expliquer l'indicateur visuel

---

### Phase 3 (OPTIONNEL - Optimisation)

**Implémentation** :

8. **VAD automatique**
   - Détecter automatiquement la fin de parole
   - Stopper l'enregistrement automatiquement
   - Envoyer la transcription automatiquement

9. **Indicateur de batterie**
   - Avertir si batterie faible
   - Désactiver mode conversation si batterie < 10%
   - Proposer de passer en mode dictée

---

## TESTS REQUIS

### Tests fonctionnels

1. **Réactivation automatique**
   - Activer mode conversation
   - Parler → stop → transcription → envoi
   - Attendre TTS terminé
   - Vérifier que le micro se réactive

2. **Arrêt manuel**
   - Activer mode conversation
   - Cliquer "Arrêter la conversation"
   - Vérifier que le micro s'arrête

3. **Timeout d'inactivité**
   - Activer mode conversation
   - Ne pas parler pendant 30 secondes
   - Vérifier que le mode se désactive

4. **Widget dispose**
   - Activer mode conversation
   - Fermer l'écran pendant TTS
   - Vérifier qu'il n'y a pas d'erreur

5. **Recorder error**
   - Simuler une erreur recorder
   - Vérifier que l'erreur est gérée
   - Vérifier que le mode passe en ERROR

### Tests UX

6. **Indicateur visuel**
   - Vérifier que l'icône micro est visible
   - Vérifier que le message est clair
   - Vérifier que le bouton "Arrêter" est évident

7. **Onboarding**
   - Vérifier que l'explication est claire
   - Vérifier que l'utilisateur comprend
   - Vérifier que l'utilisateur peut arrêter

---

## CONCLUSION

### Faisabilité

**Réactivation automatique du microphone** : ✅ **FAISABLE**

**Preuves** :
- Permission déjà accordée
- Recorder déjà initialisé
- Implémentation simple (quelques lignes)
- Compatible avec architecture actuelle

**Complexité** : FAIBLE

**Risques** : GÉRABLES

---

### Impacts

**UX** : POSITIF
- Cycle continu sans clics
- Mode conversation naturel
- Expérience ChatGPT Voice

**Technique** : POSITIF
- Implémentation simple
- Pas de nouveau package
- Compatible avec architecture actuelle

**Performance** : NÉGLIGEABLE
- Pas d'impact significatif
- Consommation batterie légèrement augmentée

---

### Recommandation

**Implémenter la réactivation automatique du microphone en Phase 1**

**Justification** :
- Faisable
- Simple
- Impact UX positif
- Risques gérables

**Conditions** :
- Ajouter flag `_isConversationMode`
- Gestion d'erreurs robuste
- Indicateur visuel clair
- Bouton "Arrêter la conversation"
- Tests sur appareil réel

---

## LIVRABLES SUIVANTS

1. BOBODO_VOICE_MEMORY_COMPATIBILITY_V2.md
2. BOBODO_VOICE_UX_FINAL.md
3. BOBODO_FULL_VOICE_CONVERSATION_ARCHITECTURE.md
