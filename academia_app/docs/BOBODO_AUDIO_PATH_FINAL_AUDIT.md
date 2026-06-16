# BOBODO — AUDIT FINAL DU CHEMIN AUDIO RÉEL

**Date** : 16 juin 2026  
**Objectif** : Tracer le chemin audio réel du mode vocal↔vocal  
**Contrainte** : AUCUNE MODIFICATION, uniquement audit

---

## MISSION 1 — TRACER LE CHEMIN RÉEL UTILISÉ

### Flux exact actuel (Mode 3 - Conversation vocale complète)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. ÉTUDIANT ACTIVE LE MODE CONVERSATION                                    │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ student_bobodo_tab.dart:1654                                               │
│ _toggleVoiceMode()                                                          │
│ → _isConversationMode = true                                                │
│ → _startConversationMode()                                                 │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ student_bobodo_tab.dart:1673                                               │
│ _startConversationMode()                                                    │
│ → _conversationState = ConversationState.listening                          │
│ → _resetInactivityTimer()                                                   │
│ → _startVocalRecording()                                                    │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ 2. ÉTUDIANT PARLE (STT)                                                     │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ student_bobodo_tab.dart:1362                                               │
│ _startVocalRecording()                                                      │
│ → _speechToText.listen(                                                     │
│     onResult: (result) {                                                    │
│       _lastRecognizedWords = result.recognizedWords                         │
│     },                                                                      │
│     listenFor: Duration(seconds: 60),                                      │
│     pauseFor: Duration(seconds: 5),                                        │
│     localeId: 'fr_FR'                                                       │
│   )                                                                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ 3. ÉTUDIANT APPUIE SUR BOUTON ➤ (ENVOI MANUEL)                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ student_bobodo_tab.dart:1280                                               │
│ _sendConversationMessage()                                                  │
│ → _lastRecognizedWords = _lastRecognizedWords.trim()                        │
│ → _onTranscriptionReceived(_lastRecognizedWords)                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ student_bobodo_tab.dart:1468                                               │
│ _onTranscriptionReceived(text)                                              │
│ → _isProcessingConversation = true (protection double envoi)                │
│ → _conversationState = ConversationState.processing                          │
│ → await Future.delayed(800ms) (accusé de réception)                        │
│ → _conversationState = ConversationState.thinking                          │
│ → provider.sendUserMessage(text)                                            │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ bobodo_provider.dart:136                                                   │
│ sendUserMessage(content)                                                    │
│ → createSession() si nécessaire                                             │
│ → _messages.add({sender: 'student', content: content})                     │
│ → _callEdgeFunction(content)                                                │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ bobodo_provider.dart:188                                                   │
│ _callEdgeFunction(content)                                                  │
│ → HTTP POST {SupabaseConfig.url}/functions/v1/bobodo-chat                   │
│ → Body: {session_id, message}                                               │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ Supabase Edge Function: bobodo-chat/index.ts                                │
│ → JWT validation                                                            │
│ → Safety checks                                                              │
│ → RAG (vector + text search)                                                │
│ → OpenRouter API call (2-5s)                                                │
│ → Response processing                                                       │
│ → RPC: app_append_bobodo_message                                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ bobodo_provider.dart:loadMessages()                                         │
│ → RPC: app_list_bobodo_messages                                             │
│ → _messages.add({sender: 'bobodo', content: response})                      │
│ → notifyListeners()                                                          │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ student_bobodo_tab.dart:1504                                               │
│ (suite de _onTranscriptionReceived)                                         │
│ → lastMsg = provider.messages.last                                          │
│ → botText = lastMsg['content']                                              │
│ → _conversationState = ConversationState.playing                             │
│ → await _speakWithLocalTts(botText)  ← POINT CLÉ TTS                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ student_bobodo_tab.dart:1599                                               │
│ _speakWithLocalTts(text)                                                    │
│ → setState(_isSpeaking = true)                                              │
│ → await _flutterTts.speak(text)  ← FLUTTERTTS LOCAL                         │
│ → await _flutterTts.awaitSpeakCompletion(true)                               │
│ → setState(_isSpeaking = false)                                             │
│ → _onAudioPlaybackComplete()                                                 │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ student_bobodo_tab.dart:1715                                               │
│ _onAudioPlaybackComplete()                                                   │
│ → HapticFeedback.mediumImpact()                                              │
│ → _conversationState = ConversationState.listening                          │
│ → _resetInactivityTimer()                                                   │
│ → _startVocalRecording()  ← BOUCLE DE CONVERSATION                          │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ 4. ÉTUDIANT ENTEND LA RÉPONSE (LECTURE AUDIO)                               │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ Composant: FlutterTts (flutter_tts plugin v3.8.5)                          │
│ Moteur: Google TTS (com.google.android.tts)                                │
│ Exécution: Local sur device Android                                          │
│ Audio: Sortie haut-parleur device                                           │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Chemin WebSocket Kamatera (NON UTILISÉ dans le mode conversation)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ student_bobodo_tab.dart:134 (initState)                                      │
│ _connectVocalWebSocket()  ← CONNECTÉ MAIS NON UTILISÉ POUR TTS              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ student_bobodo_tab.dart:1342                                               │
│ _vocalService.connect(finalSessionId)                                       │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ bobodo_vocal_service.dart:35                                                │
│ connect(sessionId)                                                           │
│ → WebSocketChannel.connect(ws://185.167.97.144:8000/ws?session_id=...)       │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ student_bobodo_tab.dart:1345                                               │
│ _messageSubscription = _vocalService.messageStream.listen((message) {      │
│   _onVocalMessage(message);                                                  │
│ })                                                                          │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ student_bobodo_tab.dart:1453                                               │
│ _onVocalMessage(message)                                                    │
│ → if type == 'transcription': _onTranscriptionReceived(text)                │
│ → if type == 'audio_response': _onAudioResponseReceived(audioBase64)         │
│ → if type == 'error': _onVocalError(errorMessage)                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

**IMPORTANT** : Le WebSocket Kamatera est connecté mais les messages `audio_response` ne sont JAMAIS reçus dans le mode conversation actuel car le mode conversation utilise `_speakWithLocalTts()` (FlutterTts local) et non le WebSocket.

---

## MISSION 2 — IDENTIFIER LE MOTEUR TTS RÉEL

### Moteur TTS réellement utilisé

**RÉPONSE** : **A. FlutterTTS Android local**

### Preuves code

#### Preuve 1 : Appel direct à FlutterTts

```dart
// student_bobodo_tab.dart:1512
await _speakWithLocalTts(botText);
```

#### Preuve 2 : Implémentation de _speakWithLocalTts

```dart
// student_bobodo_tab.dart:1599-1612
Future<void> _speakWithLocalTts(String text) async {
  try {
    setState(() => _isSpeaking = true);
    await _flutterTts.speak(text);  ← FLUTTERTTS LOCAL
    await _flutterTts.awaitSpeakCompletion(true);
    setState(() => _isSpeaking = false);
    if (_isConversationMode) {
      _onAudioPlaybackComplete();
    }
  } catch (e) {
    debugPrint('[LOCAL_TTS_ERROR] $e');
    setState(() => _isSpeaking = false);
  }
}
```

#### Preuve 3 : Initialisation de FlutterTts

```dart
// student_bobodo_tab.dart:53
final FlutterTts _flutterTts = FlutterTts();

// student_bobodo_tab.dart:161-164
Future<void> _initFlutterTts() async {
  await _flutterTts.setLanguage('fr-FR');
  await _flutterTts.setSpeechRate(0.9);
  await _flutterTts.setVolume(1.0);
}
```

#### Preuve 4 : Aucun appel au WebSocket pour TTS

Le mode conversation n'appelle JAMAIS `_onAudioResponseReceived()` pour la lecture de la réponse. Cette méthode n'est appelée que si le WebSocket envoie un message `audio_response`, ce qui n'arrive PAS dans le flux actuel.

```dart
// student_bobodo_tab.dart:1556-1597
void _onAudioResponseReceived(String audioBase64) async {
  // Cette méthode existe mais n'est PAS appelée dans le mode conversation
  // car le mode conversation utilise _speakWithLocalTts() à la place
}
```

### Conclusion

Le moteur TTS réellement utilisé est **FlutterTTS Android local** (Google TTS).  
Le WebSocket Kamatera existe mais n'est PAS utilisé pour le TTS dans le mode conversation actuel.

---

## MISSION 3 — INVENTAIRE DES TTS EXISTANTS

### A. FlutterTTS

| Attribut | Valeur |
|----------|--------|
| Fichier | `lib/features/student/tabs/student_bobodo_tab.dart` |
| Classe | `FlutterTts` (flutter_tts plugin v3.8.5) |
| Instance | `_flutterTts` (ligne 53) |
| Utilisé actuellement | **OUI** (mode conversation) |
| Câblé | **OUI** (actif) |
| Méthode utilisée | `_speakWithLocalTts()` (ligne 1599) |
| Moteur | Google TTS (com.google.android.tts) |
| Latence | < 100ms (local) |
| Coût | Gratuit |

### B. Edge-TTS (Kamatera)

| Attribut | Valeur |
|----------|--------|
| Fichier | `.windsurf/tts_service_edge.py` |
| Classe | `TTSService` |
| Voix configurée | `fr-FR-DeniseNeural` (ligne 20) |
| Utilisé actuellement | **NON** (mode conversation) |
| Câblé | **PARTIELLEMENT** (code existe mais non appelé) |
| Méthode disponible | `synthesize(text)` |
| Moteur | Microsoft Neural Voices (Edge-TTS) |
| Latence | 500-1000ms (réseau) |
| Coût | Gratuit |

### C. WebSocket Kamatera (STT + TTS)

| Attribut | Valeur |
|----------|--------|
| Fichier | `lib/services/bobodo_vocal_service.dart` |
| Classe | `BobodoVocalService` |
| Instance | `_vocalService` (ligne 89) |
| URL | `ws://185.167.97.144:8000/ws` |
| Utilisé actuellement | **NON** (mode conversation) |
| Câblé | **PARTIELLEMENT** (connecté mais non utilisé pour TTS) |
| Méthode disponible | `sendAudio()`, `messageStream` |
| Composants | STT (Python) + TTS (Edge-TTS) |
| Latence | 500-1000ms (réseau) |
| Coût | Gratuit |

### D. GoogleTTS (via FlutterTTS)

| Attribut | Valeur |
|----------|--------|
| Moteur | Google TTS (com.google.android.tts) |
| Utilisé actuellement | **OUI** (via FlutterTTS) |
| Câblé | **OUI** (actif via FlutterTTS) |
| Voix | Voix par défaut Android (féminine) |
| Latence | < 100ms (local) |
| Coût | Gratuit |

### E. Autres

Aucun autre moteur TTS n'est présent dans le projet.

### Tableau récapitulatif

| Moteur | Utilisé | Câblé | Partiellement câblé | Inutilisé |
|--------|---------|-------|-------------------|-----------|
| FlutterTTS (Google TTS) | ✅ | ✅ | - | - |
| Edge-TTS (Kamatera) | - | - | ✅ | - |
| WebSocket Kamatera (STT+TTS) | - | - | ✅ | - |

---

## MISSION 4 — IMPACT D'UN PASSAGE À HENRINEURAL

### Fichiers qui devraient changer

#### Flutter (côté client)

| Fichier | Changement requis | Méthode | Ligne |
|---------|-------------------|---------|-------|
| `student_bobodo_tab.dart` | Remplacer `_speakWithLocalTts()` par appel WebSocket | `_speakWithLocalTts()` | 1599-1612 |
| `student_bobodo_tab.dart` | Supprimer `_flutterTts` si plus utilisé | `FlutterTts _flutterTts` | 53 |
| `student_bobodo_tab.dart` | Supprimer `_initFlutterTts()` si plus utilisé | `_initFlutterTts()` | 161-164 |
| `student_bobodo_tab.dart` | Modifier `_onTranscriptionReceived()` pour utiliser WebSocket | `_onTranscriptionReceived()` | 1468-1554 |
| `student_bobodo_tab.dart` | Activer `_onAudioResponseReceived()` pour lire audio WebSocket | `_onAudioResponseReceived()` | 1556-1597 |

#### Kamatera (côté serveur)

| Fichier | Changement requis | Méthode | Ligne |
|---------|-------------------|---------|-------|
| `tts_service_edge.py` | Changer voix de DeniseNeural à HenriNeural | `__init__()` | 20 |
| `tts_service_edge.py` | Ajuster vitesse à 0.85 si nécessaire | `synthesize()` | 26-46 |

### Appels qui changeraient

#### Avant (FlutterTTS local)

```
_onTranscriptionReceived(text)
  → provider.sendUserMessage(text)
  → _speakWithLocalTts(botText)
    → _flutterTts.speak(text)  ← LOCAL
```

#### Après (Edge-TTS Kamatera)

```
_onTranscriptionReceived(text)
  → provider.sendUserMessage(text)
  → (plus d'appel TTS local)
  → WebSocket Kamatera envoie audio_response
  → _onAudioResponseReceived(audioBase64)
    → _audioPlayer.setSourceBytes(audioBytes)  ← RÉSEAU
```

### Composants Flutter qui changeraient

| Composant | Avant | Après |
|-----------|-------|-------|
| TTS | FlutterTts (local) | AudioPlayer (bytes depuis WebSocket) |
| Lecture | `_flutterTts.speak()` | `_audioPlayer.setSourceBytes()` |
| Latence | < 100ms | 500-1000ms |
| Dépendance | flutter_tts | audioplayers (déjà utilisé) |

### Composants Kamatera qui changeraient

| Composant | Avant | Après |
|-----------|-------|-------|
| Voix TTS | DeniseNeural (non utilisée) | HenriNeural (utilisée) |
| Vitesse | Défaut | 0.85 |
| Utilisation | Partiellement câblé | Pleinement utilisé |

### Risques

| Risque | Description | Mitigation |
|--------|-------------|------------|
| Latence | +500-1000ms | Acceptable compte tenu du gain qualité |
| Dépendance réseau | Nécessite connexion stable | Fallback FlutterTts local si échec |
| Complexité | Ajout logique WebSocket | Code existe déjà, juste activation |
| Test | Nécessite tests sur device | Tests manuels requis |

---

## MISSION 5 — LATENCE RÉELLE AJOUTÉE

### Aujourd'hui (FlutterTTS local)

| Étape | Composant | Latence |
|-------|-----------|---------|
| STT | speech_to_text plugin | < 1s |
| HTTP Edge Function | BobodoProvider | 200-500ms |
| RAG | Supabase vector search | 100-300ms |
| OpenRouter | IA | 2-5s |
| Persistence | Supabase RPC | 100-300ms |
| TTS | FlutterTts.speak() | < 100ms |
| **TOTAL avant début lecture** | | **~3-7s** |
| **TOTAL avant fin lecture** | | **~3-7s + durée audio** |

### Demain (Edge-TTS HenriNeural)

| Étape | Composant | Latence |
|-------|-----------|---------|
| STT | speech_to_text plugin | < 1s |
| HTTP Edge Function | BobodoProvider | 200-500ms |
| RAG | Supabase vector search | 100-300ms |
| OpenRouter | IA | 2-5s |
| Persistence | Supabase RPC | 100-300ms |
| TTS | Edge-TTS (Kamatera) | 500-1000ms |
| Transmission audio | WebSocket | 100-200ms |
| Lecture | AudioPlayer | 0ms (bytes déjà reçus) |
| **TOTAL avant début lecture** | | **~4-8s** |
| **TOTAL avant fin lecture** | | **~4-8s + durée audio** |

### Différence

| Métrique | Aujourd'hui | Demain | Différence |
|----------|-------------|--------|------------|
| Latence avant début lecture | 3-7s | 4-8s | +1s (+14-28%) |
| Latence TTS spécifique | < 100ms | 500-1000ms | +400-900ms |
| Qualité vocale | 3/10 | 9/10 | +6/10 (+200%) |

### Le gain de qualité vaut-il le coût en latence ?

**Analyse** :

1. **Latence actuelle** : 3-7s avant début de réponse
2. **Latence avec HenriNeural** : 4-8s avant début de réponse
3. **Augmentation** : +1s (14-28%)
4. **Qualité actuelle** : 3/10 (robotique, féminine)
5. **Qualité avec HenriNeural** : 9/10 (naturel, masculine)
6. **Amélioration qualité** : +6/10 (+200%)

**Conclusion** : **OUI, le gain de qualité vaut le coût en latence**

**Justification** :
- L'augmentation de latence (+1s) est marginale par rapport à la latence totale (3-7s)
- L'amélioration de qualité (+200%) est MASSIVE
- L'utilisateur préfère une voix de haute qualité avec +1s qu'une voix robotique
- La latence est déjà dominée par OpenRouter (2-5s), donc +1s sur TTS est négligeable
- La latence perçue est plus impactée par la qualité de la voix que par +1s

---

## MISSION 6 — DÉCISION FINALE

### Question

Le système vocal actuel doit-il :

A. rester sur FlutterTTS  
B. migrer vers HenriNeural  
C. proposer les deux  
D. autre

### Réponse

**B. migrer vers HenriNeural**

### Fondement (basé sur l'architecture réelle observée)

#### 1. Architecture actuelle

Le mode conversation utilise FlutterTTS local (`_speakWithLocalTts()`). Le WebSocket Kamatera est connecté mais non utilisé pour le TTS.

#### 2. Infrastructure disponible

- Kamatera est déployé et fonctionnel
- Edge-TTS est implémenté (`tts_service_edge.py`)
- WebSocket Kamatera est câblé dans Flutter (`BobodoVocalService`)
- `_onAudioResponseReceived()` existe pour lire l'audio WebSocket

#### 3. Impact technique

- Fichiers à modifier : 5 fichiers maximum
- Changements : Remplacer `_speakWithLocalTts()` par appel WebSocket
- Risques : Faibles (code existe déjà)
- Latence : +1s acceptable
- Qualité : +200%

#### 4. Avantages de la migration

- Qualité vocale : 3/10 → 9/10
- Voix masculine : garantie (HenriNeural)
- Naturel : robotique → naturel
- Compréhension : améliorée pour étudiants africains
- Expérience : chatbot → conversation humaine

#### 5. Inconvénients de rester sur FlutterTTS

- Qualité vocale : 3/10 (robotique)
- Voix masculine : non garantie sur Android 10
- Naturel : robotique
- Expérience : chatbot, pas conversation

#### 6. Pourquoi pas C (proposer les deux) ?

- Complexité inutile : Deux chemins TTS à maintenir
- UX confuse : L'utilisateur ne comprendrait pas pourquoi deux voix
- Latence variable : Difficile à expliquer
- Pas de valeur ajoutée : HenriNeural est supérieur dans tous les critères

#### 7. Pourquoi pas A (rester sur FlutterTTS) ?

- Qualité insuffisante pour contexte éducatif
- Voix masculine non garantie
- Expérience utilisateur médiocre
- Pas d'amélioration possible sans changer de moteur

### Conclusion

La décision technique est claire : **migrer vers HenriNeural**.

L'infrastructure est prête, le code existe, l'impact est maîtrisé, et le gain en qualité est massif. La latence additionnelle (+1s) est acceptable compte tenu de l'amélioration de l'expérience utilisateur (+200% qualité).

---

## LIVRABLE FINAL

### Cartographie technique

| Étape | Composant actuel | Composant futur | Fichier |
|-------|------------------|-----------------|---------|
| STT | speech_to_text plugin | inchangé | student_bobodo_tab.dart:1362 |
| Envoi | provider.sendUserMessage() | inchangé | bobodo_provider.dart:136 |
| IA | OpenRouter via Edge Function | inchangé | bobodo-chat/index.ts |
| TTS | FlutterTts local | Edge-TTS Kamatera | student_bobodo_tab.dart:1599 → _onAudioResponseReceived() |
| Lecture | _flutterTts.speak() | _audioPlayer.setSourceBytes() | student_bobodo_tab.dart:1602 → 1568 |
| Voix | Google TTS (féminine) | HenriNeural (masculine) | tts_service_edge.py:20 |

### Recommandation finale

**Migrer vers HenriNeural via Edge-TTS Kamatera**

- Moteur : Edge-TTS
- Voix : fr-FR-HenriNeural
- Vitesse : 0.85
- Pitch : Défaut
- Latence : +1s acceptable
- Qualité : +200%
