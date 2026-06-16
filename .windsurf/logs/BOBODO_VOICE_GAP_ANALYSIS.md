# BOBODO VOICE - Gap Analysis

## Date
12 Juin 2026

---

## OBJECTIF

Déterminer précisément ce qui relève de la dictée vocale et ce qui relève du mode conversation, et identifier ce qui manque pour atteindre un comportement ChatGPT Voice.

---

## ARCHITECTURE ACTUELLE (CODE RÉEL)

### Source de vérité analysée

**Flutter** :
- `academia_app/lib/features/student/tabs/student_bobodo_tab.dart` (1584 lignes)
- `academia_app/lib/services/bobodo_vocal_service.dart` (95 lignes)
- `academia_app/lib/providers/bobodo_provider.dart` (337 lignes)

**Backend** :
- `supabase/functions/bobodo-chat/index.ts` (1561 lignes)
- Services STT/TTS sur Kamatera (stt_service.py, tts_service.py) - NON dans codebase local

**Supabase** :
- Tables : `bobodo_sessions`, `bobodo_messages`
- RPCs : `app_get_or_create_bobodo_session`, `app_list_bobodo_messages`

---

## ÉTATS ACTUELS (student_bobodo_tab.dart)

### Variables d'état (lignes 42-47)

```dart
bool _isRecordingMode = false;  // Mode vocal activé
bool _isRecording = false;       // Enregistrement en cours
bool _isTranscribing = false;   // Transcription en cours
bool _isSending = false;        // (non utilisé dans le code actuel)
bool _isSpeaking = false;        // Lecture audio en cours
```

### UX TTS (lignes 70-72)

```dart
bool _autoTtsEnabled = true;    // Toggle auto TTS
Uint8List? _lastAudioResponse;   // Cache audio pour replay
```

---

## FLUX ACTUEL (DICTÉE VOCALE)

### Séquence d'actions

1. **User clique bouton micro** (ligne 998)
   - Appel `_startVocalRecording()`

2. **Enregistrement** (lignes 1184-1218)
   - Permission microphone
   - `FlutterSoundRecorder.startRecorder()`
   - Audio bufferisé dans `_audioBuffer`
   - Timer durée d'enregistrement
   - Animation waveform simulée

3. **User clique stop** (ligne 1123)
   - Appel `_stopVocalRecording()`

4. **Transcription** (lignes 1220-1236)
   - `_recorder.stopRecorder()`
   - Audio envoyé via WebSocket : `_vocalService.sendAudio(audioBytes)`
   - État `_isTranscribing = true`

5. **Réception transcription** (lignes 1257-1282)
   - WebSocket message type `transcription`
   - `_onTranscriptionReceived(text)`
   - Texte injecté dans `_controller.text`
   - `_isRecordingMode = false`
   - `_isTranscribing = false`

6. **User édite le texte** (optionnel)
   - TextField éditable
   - User peut modifier la transcription

7. **User clique envoi** (ligne 1025)
   - Appel `_send(context)`
   - `provider.sendUserMessage(text)`

8. **Réponse Bobodo** (bobodo_provider.dart)
   - Appel Edge Function `bobodo-chat`
   - Réponse texte stockée dans Supabase
   - Messages rechargés via `loadMessages()`

9. **TTS (optionnel)** (lignes 1284-1302)
   - Si `_autoTtsEnabled = true`
   - WebSocket message type `audio_response`
   - `_onAudioResponseReceived(audioBase64)`
   - Lecture via `AudioPlayer`
   - `_isSpeaking = true`

10. **Fin de lecture** (lignes 1295-1297)
    - `onPlayerComplete` → `_isSpeaking = false`
    - **AUCUNE réactivation automatique du micro**

---

## ANALYSE : DICTÉE VS CONVERSATION

### Ce qui est DICTÉE VOCALE

✅ **Enregistrement audio**
- User clique micro → enregistre
- User clique stop → arrête
- Audio envoyé au serveur STT

✅ **Transcription**
- STT renvoie texte
- Texte injecté dans TextField
- User peut éditer

✅ **Envoi manuel**
- User DOIT cliquer sur bouton envoi
- Texte envoyé à Bobodo

✅ **Réponse texte**
- Bobodo répond avec texte
- Affiché dans chat

✅ **TTS optionnel**
- Toggle auto TTS
- Lecture audio de la réponse
- Boutons stop/replay/volume

---

### Ce qui est MANQUANT pour CONVERSATION VOCALE (ChatGPT Voice)

❌ **Réactivation automatique du micro**
- Après TTS terminé, micro ne se réactive pas
- User doit recliquer micro pour chaque tour
- **BLOCAGE CRITIQUE** pour mode conversation

❌ **Cycle continu**
- Chaque tour nécessite : clic micro → parler → stop → éditer → envoyer
- Pas de flux naturel "parler → répondre → reparler"
- **BLOCAGE CRITIQUE** pour mode conversation

❌ **Full duplex**
- Impossible de parler pendant la réponse
- AudioPlayer monopolise la sortie audio
- Pas de détection VAD (Voice Activity Detection) côté client
- **BLOCAGE CRITIQUE** pour mode conversation

❌ **Machine d'états robuste**
- États actuels : 5 booléens simples
- Pas de transitions explicites
- Pas de gestion d'erreurs d'état
- Pas de récupération après interruption
- **BLOCAGE CRITIQUE** pour stabilité

❌ **Gestion des interruptions**
- User coupe Bobodo : bouton stop existe
- User parle pendant réponse : NON géré
- User ferme l'écran : NON géré
- User reçoit appel : NON géré
- User perd Internet : NON géré
- **BLOCAGE CRITIQUE** pour UX

❌ **Mode conversation dédié**
- Pas de bouton "Conversation vocale"
- Pas de distinction UI entre dictée et conversation
- Toggle auto TTS est global, pas par mode
- **BLOCAGE CRITIQUE** pour UX

---

## DÉCISION : ARCHITECTURE CIBLE

### Mode DICTÉE (existant - à conserver)

**Objectif** : Dictée vocale avec édition

**Flux** :
- User clique micro → enregistre → stop → transcription → édite → envoi → réponse → TTS optionnel

**Cas d'usage** :
- Messages longs nécessitant édition
- Questions complexes nécessitant reformulation
- Utilisateurs préférant contrôle manuel

---

### Mode CONVERSATION (nouveau - à créer)

**Objectif** : Conversation fluide type ChatGPT Voice

**Flux** :
- User clique "Conversation vocale" → micro actif
- User parle → stop → transcription → envoi automatique → réponse → TTS automatique → micro réactif
- Cycle continu sans clics
- Interruptions gérées

**Cas d'usage** :
- Questions rapides
- Navigation naturelle
- Utilisateurs préférant fluidité

---

## ÉCARTS IDENTIFIÉS

### 1. Réactivation automatique du micro

**État actuel** :
```dart
_audioPlayer.onPlayerComplete.listen((_) {
  setState(() => _isSpeaking = false);
  // RIEN - micro ne se réactive pas
});
```

**État cible** :
```dart
_audioPlayer.onPlayerComplete.listen((_) {
  setState(() => _isSpeaking = false);
  if (_isConversationMode) {
    _startVocalRecording(); // Réactivation automatique
  }
});
```

**Impact** : CRITIQUE - Sans cela, pas de mode conversation

---

### 2. Envoi automatique de la transcription

**État actuel** :
```dart
void _onTranscriptionReceived(String text) {
  setState(() {
    _isTranscribing = false;
    _isRecordingMode = false;
  });
  _controller.text = text; // Injecté dans TextField
  // User DOIT cliquer envoi
}
```

**État cible** :
```dart
void _onTranscriptionReceived(String text) {
  setState(() {
    _isTranscribing = false;
    _isRecordingMode = false;
  });
  if (_isConversationMode) {
    provider.sendUserMessage(text); // Envoi automatique
  } else {
    _controller.text = text; // Mode dictée : édition
  }
}
```

**Impact** : CRITIQUE - Sans cela, pas de mode conversation

---

### 3. Machine d'états

**État actuel** :
- 5 booléens simples
- Pas de transitions explicites
- Pas de diagramme d'états

**État cible** :
- Enum d'états : `IDLE`, `LISTENING`, `PROCESSING`, `SPEAKING`, `INTERRUPTED`, `ENDED`
- Transitions explicites avec validation
- Diagramme d'états documenté
- Gestion d'erreurs d'état

**Impact** : CRITIQUE - Sans cela, instabilité

---

### 4. Full duplex (optionnel pour V1)

**État actuel** :
- Half duplex : enregistrement OU lecture
- AudioPlayer monopolise sortie audio

**État cible** :
- Pseudo duplex : détection VAD pendant réponse
- Si user parle → interruption → arrêt TTS → transcription

**Impact** : MOYEN - Peut être V2, mais important pour UX ChatGPT Voice

---

### 5. Gestion des interruptions

**État actuel** :
- Bouton stop pendant lecture
- Pas d'autres interruptions gérées

**État cible** :
- User coupe Bobodo → arrêt TTS + réactivation micro
- User parle pendant réponse → VAD → interruption
- User ferme l'écran → pause + reprise
- User reçoit appel → pause + reprise
- User perd Internet → erreur + retry

**Impact** : CRITIQUE - Sans cela, UX dégradée

---

### 6. UI Mode Conversation

**État actuel** :
- Bouton micro unique
- Toggle auto TTS global
- Pas de distinction dictée/conversation

**État cible** :
- Bouton "Conversation vocale" dédié
- Toggle auto TTS par mode
- Indicateur visuel du mode actif
- Transition fluide entre modes

**Impact** : CRITIQUE - Sans cela, confusion utilisateur

---

## RISQUES IDENTIFIÉS

### 1. Compatibilité STT/TTS

**Risque** : Le serveur STT/TTS actuel (Kamatera) est optimisé pour dictée, pas conversation

**Mitigation** :
- Vérifier si STT supporte streaming
- Vérifier si TTS supporte interruption
- Tester latence en mode conversation

---

### 2. Performance Flutter

**Risque** : Réactivation automatique du micro peut causer des problèmes de cycle de vie

**Mitigation** :
- Tests approfondis sur différents appareils
- Gestion stricte des timers et subscriptions
- Fallback en cas d'erreur

---

### 3. UX Confusion

**Risque** : Deux modes vocaux peuvent confondre les utilisateurs

**Mitigation** :
- UI claire avec distinction visuelle
- Onboarding explicite
- Tooltip explicatifs

---

## RECOMMANDATIONS

### Phase 1 (CRITIQUE - Mode conversation basique)

1. **Ajouter enum d'états**
   - Définir `VocalState` avec tous les états
   - Remplacer booléens par enum
   - Documenter transitions

2. **Réactivation automatique du micro**
   - Implémenter dans `onPlayerComplete`
   - Ajouter flag `_isConversationMode`
   - Tests sur appareil réel

3. **Envoi automatique de transcription**
   - Conditionnel sur `_isConversationMode`
   - Conserver mode dictée existant
   - Tests sur appareil réel

4. **UI Mode conversation**
   - Bouton "Conversation vocale" dédié
   - Toggle auto TTS par mode
   - Indicateur visuel

### Phase 2 (IMPORTANT - Stabilité)

5. **Gestion des interruptions**
   - Cycle de vie app
   - Appels téléphoniques
   - Perte réseau

6. **Machine d'états robuste**
   - Validation des transitions
   - Récupération d'erreur
   - Logging d'état

### Phase 3 (OPTIONNEL - Full duplex)

7. **VAD pendant réponse**
   - Détection parole pendant TTS
   - Interruption fluide
   - Tests approfondis

---

## CONCLUSION

### Architecture actuelle = DICTÉE VOCALE

Le système actuel est **100% dictée vocale** :
- Enregistrement → transcription → édition → envoi → réponse → TTS optionnel
- Chaque tour nécessite des clics manuels
- Pas de cycle continu
- Pas de réactivation automatique du micro

### Ce qui manque pour CONVERSATION VOCALE

**BLOCAGES CRITIQUES** :
1. Réactivation automatique du micro après TTS
2. Envoi automatique de la transcription
3. Machine d'états robuste
4. Gestion des interruptions
5. UI mode conversation dédié

**BLOCAGES MOYENS** :
6. Full duplex (VAD pendant réponse)

### Feasibility

**Phase 1 (Mode conversation basique)** : FEASIBLE
- Modifications Flutter limitées
- Pas de changements serveur
- Tests sur appareil requis

**Phase 2 (Stabilité)** : FEASIBLE
- Machine d'états documentée
- Gestion interruptions
- Tests approfondis

**Phase 3 (Full duplex)** : DIFFICILE
- Nécessite modifications STT/TTS
- Tests complexes
- Peut être différé en V2

---

## LIVRABLES SUIVANTS

1. BOBODO_VOICE_STATE_MACHINE.md
2. BOBODO_VOICE_AUDIO_ARCHITECTURE.md
3. BOBODO_VOICE_INTERRUPTION_AUDIT.md
4. BOBODO_VOICE_AUTO_LISTENING.md
5. BOBODO_VOICE_MEMORY_COMPATIBILITY_V2.md
6. BOBODO_VOICE_UX_FINAL.md
7. BOBODO_FULL_VOICE_CONVERSATION_ARCHITECTURE.md
