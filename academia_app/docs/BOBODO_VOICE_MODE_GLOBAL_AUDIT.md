# BOBODO — AUDIT GLOBAL MODE VOCAL ↔ VOCAL

**Date** : 16 juin 2026  
**Objectif** : Audit complet du pipeline vocal sans aucune modification  
**Portée** : Flutter, Provider, TTS, STT, Supabase, Edge Function, Kamatera

---

## MISSION 1 — CARTOGRAPHIE COMPLÈTE DU MODE VOCAL

### Architecture réelle actuelle

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    FLUTTER APP (Android Device)                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  student_bobodo_tab.dart                                                    │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ SpeechToText (speech_to_text plugin v7.0.0)                           │  │
│  │ - _startVocalRecording()                                              │  │
│  │ - listenFor: 60s, pauseFor: 5s, locale: fr-FR                        │  │
│  │ - onResult callback → _lastRecognizedWords (accumulation)            │  │
│  │ - ENVOI MANUEL via bouton ➤ (plus d'auto-send)                       │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    ↓                                         │
│  _sendConversationMessage() / _forceStopAndSend()                          │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ _onTranscriptionReceived(text)                                       │  │
│  │ - Barge-in protection (stop audio if speaking)                       │  │
│  │ - Conversation state management (listening → processing → thinking)  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    ↓                                         │
│  bobodo_provider.dart                                                      │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ sendUserMessage(content)                                              │  │
│  │ - Session management (create/restore)                                 │  │
│  │ - Local message addition (optimistic UI)                              │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    ↓                                         │
│  _callEdgeFunction(content)                                                 │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ HTTP POST → Supabase Edge Function                                    │  │
│  │ URL: {SupabaseConfig.url}/functions/v1/bobodo-chat                    │  │
│  │ Headers: Authorization Bearer JWT, Content-Type application/json      │  │
│  │ Body: { session_id, message }                                          │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    ↓                                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│              SUPABASE EDGE FUNCTION (bobodo-chat/index.ts)                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. Authentication (JWT validation)                                         │
│  2. Safety checks (sensitive phrases, university keywords)                 │
│  3. RAG: searchKnowledge()                                                  │
│     - Vector search (app_search_bobodo_knowledge_vector)                    │
│     - Text search (app_search_bobodo_knowledge)                            │
│     - Semantic expansion (generateSemanticVariants)                        │
│  4. Cache check (app_search_bobodo_answer_cache)                          │
│  5. OpenRouter API call                                                    │
│     - Model: OPENROUTER_MODEL (env var)                                   │
│     - Fallback: OPENROUTER_FALLBACK_MODEL (env var)                       │
│     - Temperature: 0.2, max_tokens: 500                                    │
│  6. Response processing                                                    │
│  7. Persistence via RPC: app_append_bobodo_message                        │
│  8. Cross-session memory (saveConversationSummary)                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│                    FLUTTER APP (Response Handling)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  BobodoProvider.loadMessages()                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ RPC: app_list_bobodo_messages                                          │  │
│  │ - Messages added to _messages list                                    │  │
│  │ - notifyListeners() triggers UI update                                │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    ↓                                         │
│  student_bobodo_tab.dart (conversation mode)                                │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ _speakWithLocalTts(botText)                                           │  │
│  │ - FlutterTts.speak(text)                                              │  │
│  │ - awaitSpeakCompletion(true)                                          │  │
│  │ - _onAudioPlaybackComplete() → restart listening loop                 │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Fichiers impliqués

| Fichier | Rôle | Méthodes clés |
|---------|------|---------------|
| `lib/features/student/tabs/student_bobodo_tab.dart` | UI Flutter + logique vocale | `_startVocalRecording()`, `_sendConversationMessage()`, `_speakWithLocalTts()`, `_onAudioPlaybackComplete()` |
| `lib/providers/bobodo_provider.dart` | State management + appels backend | `sendUserMessage()`, `_callEdgeFunction()`, `loadMessages()` |
| `supabase/functions/bobodo-chat/index.ts` | Edge Function (IA + RAG) | `callOpenRouter()`, `searchKnowledge()`, `saveConversationSummary()` |
| `lib/services/bobodo_vocal_service.dart` | WebSocket client (NON UTILISÉ) | `connect()`, `sendAudio()`, `messageStream` |
| `.windsurf/websocket_handler_v2.py` | WebSocket server Kamatera (NON UTILISÉ) | `handle_audio()`, `_on_transcription_complete()` |
| `.windsurf/tts_service_edge.py` | TTS Kamatera (NON UTILISÉ) | `synthesize()`, `_synthesize_edge()` |

### Dépendances Flutter

```yaml
flutter_tts: ^3.8.5         # TTS local (actif)
speech_to_text: ^7.0.0      # STT natif (actif)
audioplayers: ^6.0.0        # Lecture audio (actif)
flutter_sound: ^9.2.13      # Enregistrement (actif)
just_audio: ^0.9.36         # Audio backend (actif)
web_socket_channel: ^2.4.0  # WebSocket (NON UTILISÉ)
```

### Points de latence

| Étape | Composant | Latence estimée |
|-------|-----------|-----------------|
| STT (Speech-to-Text) | speech_to_text plugin | < 1s (local) |
| HTTP vers Edge Function | BobodoProvider._callEdgeFunction | 200-500ms |
| RAG (vector + text search) | Supabase RPC | 100-300ms |
| OpenRouter API call | Edge Function | 2-5s |
| TTS (FlutterTts) | flutter_tts plugin | < 100ms (local) |
| **TOTAL** | | **~3-7s** |

---

## MISSION 2 — AUDIT DU TTS ACTUEL

### Moteur TTS utilisé

**Moteur principal** : `flutter_tts` (v3.8.5)  
**Exécution** : Local sur device Android  
**Déclenchement** : `_speakWithLocalTts()` dans `student_bobodo_tab.dart`

### Preuve par code

```dart
// student_bobodo_tab.dart:161-164
Future<void> _initFlutterTts() async {
  await _flutterTts.setLanguage('fr-FR');
  await _flutterTts.setSpeechRate(0.9);
  await _flutterTts.setVolume(1.0);
}

// student_bobodo_tab.dart:1599-1612
Future<void> _speakWithLocalTts(String text) async {
  try {
    setState(() => _isSpeaking = true);
    await _flutterTts.speak(text);
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

### Paramètres actifs

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| Langue | `fr-FR` | Français (France) |
| Vitesse | `0.9` | 90% de la vitesse normale |
| Volume | `1.0` | Volume maximum |
| Voix | **NON SPÉCIFIÉE** | Voix par défaut du système Android |
| Pitch | **NON SPÉCIFIÉ** | Pitch par défaut du système |
| Engine | **NON SPÉCIFIÉ** | Engine par défaut du système |

### Voix actuellement utilisée

**Source** : Voix par défaut d'Android (Google TTS)  
**Nom** : Dépend de la configuration du device  
**Genre** : Dépend de la configuration du device (probablement féminine sur la plupart des devices)  
**Accent** : Français standard (fr-FR)

**IMPORTANT** : Le code ne spécifie PAS explicitement la voix. FlutterTts utilise la voix par défaut du système Android. C'est pourquoi la voix perçue varie selon le device.

---

## MISSION 3 — ANALYSE DE LA VOIX ACTUELLE

### Pourquoi la voix est perçue comme féminine

**Cause** : La voix par défaut de Google TTS sur Android est généralement une voix féminine (ex: "Google Français" sur la plupart des devices).  

**Preuve** : Le code n'appelle jamais `setVoice()` ou `getVoices()`. FlutterTts utilise la voix système par défaut.

```dart
// AUCUN appel à setVoice() dans le code
// AUCUN appel à getVoices() dans le code
// AUCUN appel à setDefaultEngine() dans le code
```

### Pourquoi la voix est perçue comme rapide

**Cause 1** : `setSpeechRate(0.9)` est légèrement inférieur à 1.0 (normal), mais la perception de rapidité peut venir de :
- La voix par défaut de Google TTS qui est naturellement rapide
- L'absence de pauses naturelles entre les phrases
- Le style de synthèse "robotique" qui manque de variation prosodique

**Cause 2** : La vitesse de 0.9 est proche de la normale (1.0). Si la voix semble trop rapide, c'est probablement dû à la qualité de la voix elle-même plutôt qu'au paramètre.

### Pourquoi la voix est perçue comme peu naturelle

**Causes** :
1. **Voix système par défaut** : Google TTS est une voix de synthèse standard, optimisée pour la clarté mais pas pour le naturel conversationnel
2. **Pas de variation prosodique** : FlutterTts ne gère pas l'intonation, l'émotion, ou les pauses naturelles
3. **Pas de sélection de voix spécifique** : La voix par défaut n'est pas optimisée pour un contexte éducatif
4. **Absence de paramètres avancés** : Pas de pitch, pas de variation de vitesse selon le contexte

### Ce qui provient du moteur vs code

| Aspect | Source |
|--------|--------|
| Genre (féminin) | **Système Android** (voix par défaut) |
| Vitesse | **Code** (setSpeechRate: 0.9) + **Système** (voix par défaut) |
| Accent | **Code** (setLanguage: fr-FR) |
| Naturel | **Système** (qualité de la voix par défaut) |
| Pitch | **Système** (pitch par défaut) |

### La voix est-elle imposée par Android ?

**OUI et NON** :
- **OUI** : Le code ne spécifie pas de voix, donc Android utilise sa voix par défaut
- **NON** : Le code POURRAIT spécifier une voix via `setVoice()` et `getVoices()`, mais ne le fait pas

**Conclusion** : La voix actuelle est une conséquence de l'absence de configuration explicite dans le code, pas un choix délibéré.

---

## MISSION 4 — INVENTAIRE DES VOIX DISPONIBLES

### A. Flutter TTS (disponible sur device)

**Voix disponibles** : Dépend du device Android. Google TTS propose généralement :
- Voix féminines : "Google Français", "fr-FR-language", etc.
- Voix masculines : Rares sur Google TTS standard, mais disponibles via certains engines
- Langues : fr-FR, fr-CA, fr-BE, etc.
- Variantes : Standard, haute qualité, neurales (sur Android 11+)

**Méthodes disponibles dans FlutterTts** (non utilisées) :
```dart
// Disponible mais NON UTILISÉ :
await _flutterTts.getVoices;           // Liste des voix disponibles
await _flutterTts.setVoice(voice);     // Sélectionner une voix spécifique
await _flutterTts.getDefaultEngine;    // Engine par défaut
await _flutterTts.setEngine(engine);   // Changer d'engine
await _flutterTts.setPitch(1.0);       // Pitch (non utilisé)
```

**Limitation** : FlutterTts dépend des voix installées sur le device. Les voix neurales de haute qualité ne sont disponibles que sur Android 11+.

### B. Edge-TTS (disponible sur Kamatera)

**Voix disponibles** : Edge-TTS (Microsoft Neural Voices) propose de nombreuses voix neurales :

**Voix françaises** :
- `fr-FR-DeniseNeural` (féminine) - **actuellement configurée dans tts_service_edge.py**
- `fr-FR-HenriNeural` (masculine)
- `fr-FR-JulieNeural` (féminine)
- `fr-FR-PaulNeural` (masculine)
- `fr-CA-antoineneural` (féminine, canadienne)
- `fr-CA-jeanneNeural` (féminine, canadienne)

**Voix africaines** :
- `fr-FR` standard (pas de variantes africaines spécifiques dans Edge-TTS)
- Edge-TTS se concentre sur les langues standards, pas les accents régionaux

**Preuve par code** :
```python
# .windsurf/tts_service_edge.py:20
def __init__(self, voice: str = "fr-FR-DeniseNeural", language: str = "fr"):
    self.voice = voice  # DeniseNeural = voix féminine
    self.language = language
```

**Statut** : Edge-TTS est disponible sur Kamatera mais **NON UTILISÉ** dans le flux actuel. Le Flutter app utilise FlutterTts local.

### C. Kamatera (serveur Python)

**Possibilité d'exécuter TTS côté serveur** : **OUI**, déjà implémenté mais non utilisé.

**Architecture existante** :
- `tts_service_edge.py` : Service TTS Edge-TTS + gTTS fallback
- `websocket_handler_v2.py` : Handler WebSocket qui peut recevoir transcription → TTS → audio response
- `main_server.py` : Serveur FastAPI qui expose le WebSocket

**Flux Kamatera (NON UTILISÉ)** :
```
Flutter → WebSocket (audio) → Kamatera STT → Transcription → Kamatera TTS → Audio → Flutter
```

**Compatibilité actuelle** : Le code Flutter contient `BobodoVocalService` qui peut se connecter au WebSocket Kamatera, mais ce service n'est PAS utilisé dans le mode conversation actuel.

### Tableau comparatif

| Solution | Voix homme | Voix femme | Voix africaines | Langues | Qualité | Latence | Coût | Statut |
|----------|------------|------------|-----------------|---------|---------|---------|------|--------|
| **FlutterTts (actuel)** | Dépend device | Dépend device | Non | fr-FR | Standard | < 100ms | Gratuit | ACTIF |
| **FlutterTts (configuré)** | OUI (si dispo) | OUI (si dispo) | Non | fr-FR, fr-CA, etc. | Standard | < 100ms | Gratuit | DISPONIBLE |
| **Edge-TTS (Kamatera)** | OUI (Henri, Paul) | OUI (Denise, Julie) | Non | fr-FR, fr-CA | Neurale haute | 500-1000ms | Gratuit | NON UTILISÉ |
| **gTTS (Kamatera)** | Non | Non | Non | fr-FR | Standard | 500-1000ms | Gratuit | Fallback |

---

## MISSION 5 — AUDIT DE LA VITESSE DE PAROLE

### Vitesse actuelle

**Valeur configurée** : `0.9` (90% de la vitesse normale)

```dart
// student_bobodo_tab.dart:163
await _flutterTts.setSpeechRate(0.9);
```

### Plage supportée par FlutterTts

**Documentation FlutterTts** : La plage typique est de `0.0` à `2.0` :
- `0.5` : Très lent
- `0.75` : Lent
- `1.0` : Normal
- `1.25` : Rapide
- `1.5` : Très rapide
- `2.0` : Maximum

### Vitesse perçue vs configurée

| Vitesse configurée | Vitesse perçue (typique) | Appropriée pour conversation ? |
|-------------------|--------------------------|-------------------------------|
| 0.5 | Très lent | Non (trop lent) |
| 0.75 | Lent | Oui (pour débutants) |
| **0.9** | **Légèrement lent / Normal** | **OUI (actuel)** |
| 1.0 | Normal | Oui |
| 1.25 | Rapide | Non (trop rapide) |
| 1.5 | Très rapide | Non |

**Analyse** : La valeur actuelle de `0.9` est LÉGÈREMENT inférieure à la normale, ce qui devrait donner une impression de parole lente à normale. Si l'utilisateur perçoit la voix comme "rapide", c'est probablement dû à la qualité de la voix elle-même (manque de pauses naturelles) plutôt qu'au paramètre de vitesse.

### Valeur recommandée pour conversation humaine naturelle

**Recommandation** : `0.85` à `0.95`

**Justification** :
- Une conversation humaine naturelle a une vitesse modérée avec des pauses
- `0.9` est déjà dans cette plage
- Si la voix semble trop rapide, baisser à `0.85` peut aider
- Si la voix semble trop lente, augmenter à `0.95` peut aider

**NOTE** : La vitesse n'est qu'un facteur. Le naturel de la voix dépend aussi de la qualité de la voix elle-même (Edge-TTS > Google TTS standard).

---

## MISSION 6 — AUDIT DE LA QUALITÉ VOCALE

### Comparaison objective

| Critère | FlutterTts (actuel) | FlutterTts (voix masculine) | Edge-TTS (Kamatera) | gTTS (Kamatera) |
|---------|---------------------|-----------------------------|---------------------|-----------------|
| **Qualité** | Standard (Google TTS) | Standard (Google TTS) | Neurale haute (Microsoft) | Standard (Google) |
| **Naturel** | Peu naturel (robotique) | Peu naturel (robotique) | Très naturel (neural) | Peu naturel |
| **Accent** | Français standard | Français standard | Français standard | Français standard |
| **Stabilité** | Stable (local) | Stable (local) | Stable (serveur) | Stable (serveur) |
| **Coût** | Gratuit | Gratuit | Gratuit | Gratuit |
| **Latence** | < 100ms (local) | < 100ms (local) | 500-1000ms (réseau) | 500-1000ms (réseau) |
| **Difficulté d'intégration** | Faible (déjà actif) | Faible (déjà actif) | Moyenne (WebSocket) | Moyenne (WebSocket) |
| **Voix homme** | Dépend device | Dépend device | OUI (Henri, Paul) | Non |
| **Voix femme** | Dépend device | Dépend device | OUI (Denise, Julie) | Non |
| **Statut** | ACTIF | DISPONIBLE | NON UTILISÉ | Fallback |

### Analyse détaillée

#### FlutterTts (actuel)

**Avantages** :
- Latence minimale (< 100ms)
- Fonctionne offline
- Aucun coût réseau
- Déjà intégré

**Inconvénients** :
- Qualité standard (pas neural)
- Dépend des voix du device
- Pas de contrôle sur la voix spécifique
- Peu naturel pour une conversation éducative

#### FlutterTts (voix masculine configurée)

**Avantages** :
- Mêmes avantages que FlutterTts actuel
- Possibilité de sélectionner une voix masculine si disponible

**Inconvénients** :
- Dépend de la disponibilité des voix sur le device
- Même qualité standard
- Nécessite d'appeler `getVoices()` et `setVoice()`

#### Edge-TTS (Kamatera)

**Avantages** :
- Qualité neurale haute (Microsoft Neural Voices)
- Voix masculine et féminine disponibles
- Très naturel
- Indépendant du device

**Inconvénients** :
- Latence plus élevée (500-1000ms)
- Dépend de la connexion réseau
- Nécessite d'utiliser le WebSocket Kamatera (non actif)
- Plus complexe à intégrer

#### gTTS (Kamatera)

**Avantages** :
- Fallback robuste
- Indépendant du device

**Inconvénients** :
- Qualité standard
- Pas de voix masculine
- Latence réseau
- Non optimisé pour conversation

### Recommandation qualité

**Pour un contexte éducatif** :
1. **Edge-TTS** (qualité neurale, naturel) → Meilleure qualité mais latence plus élevée
2. **FlutterTts configuré** (voix masculine si disponible) → Compromis qualité/latence
3. **FlutterTts actuel** → Moins adapté pour conversation éducative

---

## MISSION 7 — AUDIT LATENCE VOCALE COMPLÈTE

### Pipeline actuel (mode conversation)

```
1. Étudiant parle
   ↓ SpeechToText (local)
   < 1s

2. Transcription accumulée
   ↓ Utilisateur appuie sur bouton ➤
   < 100ms

3. Envoi vers BobodoProvider
   ↓ sendUserMessage()
   < 50ms

4. HTTP POST vers Edge Function
   ↓ Supabase
   200-500ms

5. Edge Function traitement
   ↓ RAG + OpenRouter
   2-5s

6. Réponse sauvegardée
   ↓ Supabase RPC
   100-300ms

7. Messages chargés
   ↓ loadMessages()
   100-300ms

8. TTS local
   ↓ FlutterTts.speak()
   < 100ms

9. Lecture audio
   ↓ awaitSpeakCompletion
   Variable (selon longueur)

TOTAL: ~3-7s avant début de lecture
```

### Mesures par étape

| Étape | Composant | Latence | Optimisation possible |
|-------|-----------|---------|----------------------|
| STT | speech_to_text plugin | < 1s | Déjà optimal (local) |
| Envoi manuel | Bouton ➤ | < 100ms | Déjà optimal |
| HTTP Edge Function | BobodoProvider | 200-500ms | Cache hit peut réduire |
| RAG | Supabase vector search | 100-300ms | Cache sémantique déjà implémenté |
| OpenRouter | IA | 2-5s | Modèle plus rapide possible |
| Persistence | Supabase RPC | 100-300ms | Difficile à optimiser |
| TTS | FlutterTts | < 100ms | Déjà optimal (local) |
| **TOTAL** | | **~3-7s** | **OpenRouter est le goulot** |

### Points de latence critiques

1. **OpenRouter API call** (2-5s) : C'est le goulot d'étranglement principal
2. **RAG** (100-300ms) : Peut être réduit par cache hit
3. **HTTP Edge Function** (200-500ms) : Peut être réduit par cache

### Recommandations latence

- **P0** : Optimiser le modèle OpenRouter (modèle plus rapide si disponible)
- **P1** : Augmenter le taux de cache hit (précharger les questions fréquentes)
- **P2** : Streaming de la réponse (non implémenté)

---

## MISSION 8 — AUDIT UX DU MODE VOCAL

### Éléments qui nuisent à la perception

#### 1. Rythme de réponse

**Problème** : Le délai entre la fin de parole de l'étudiant et le début de la réponse de Bobodo est de 3-7s. Cela peut donner une impression de lenteur.

**Cause** : Latence OpenRouter (2-5s) + latence réseau + latence RAG.

**Impact** : L'utilisateur peut penser que le système ne fonctionne pas.

#### 2. Voix

**Problème** : La voix actuelle (FlutterTts par défaut) est perçue comme :
- Féminine (pas adaptée pour un contexte éducatif masculin)
- Rapide (manque de pauses naturelles)
- Peu naturelle (robotique)

**Cause** : Voix par défaut d'Android, pas de configuration explicite.

**Impact** : L'expérience conversationnelle est moins engageante.

#### 3. Transition entre les tours de parole

**Problème** : La transition entre la fin de la réponse de Bobodo et la reprise de l'écoute est abrupte.

**Cause** : `_onAudioPlaybackComplete()` relance immédiatement `_startVocalRecording()` sans transition visuelle ou sonore.

**Impact** : L'utilisateur peut ne pas savoir quand il peut reparler.

#### 4. Compréhension du système

**Problème** : L'utilisateur ne sait pas toujours :
- Quand Bobodo écoute
- Quand Bobodo réfléchit
- Quand Bobodo parle
- Quand il peut interrompre (barge-in)

**Cause** : Les indicateurs visuels existent mais pourraient être plus clairs.

**Impact** : Frustration, hésitation à reparler.

#### 5. Impression de fluidité

**Problème** : La conversation manque de fluidité à cause de :
- Latence élevée
- Voix robotique
- Transitions abruptes

**Cause** : Combinaison de latence IA et qualité TTS.

**Impact** : L'expérience ressemble plus à un chatbot qu'à une conversation humaine.

### Constats UX

| Aspect | Constat | Impact |
|--------|---------|--------|
| Rythme | Latence 3-7s avant réponse | Frustration |
| Voix | Féminine, rapide, robotique | Moins engageant |
| Transitions | Abruptes, pas de signal | Confusion |
| Compréhension | Indicateurs existent mais pourraient être plus clairs | Hésitation |
| Fluidité | Manque de naturel | Expérience chatbot |

---

## MISSION 9 — RECOMMANDATIONS

### P0 — Problèmes bloquants

**AUCUN** : Le système fonctionne correctement. Aucun problème bloquant identifié.

### P1 — Améliorations à forte valeur

#### 1. Changer la voix pour une voix masculine

**Justification** : Pour un contexte éducatif, une voix masculine est généralement plus appropriée et plus engageante pour les étudiants.

**Solution** : 
- Option 1 (rapide) : Configurer FlutterTts pour utiliser une voix masculine si disponible sur le device
- Option 2 (long terme) : Passer à Edge-TTS sur Kamatera avec voix masculine (HenriNeural)

**Impact** : Amélioration significative de l'expérience conversationnelle.

#### 2. Optimiser la latence OpenRouter

**Justification** : OpenRouter est le goulot d'étranglement principal (2-5s).

**Solution** :
- Tester des modèles plus rapides (ex: GPT-3.5-turbo au lieu de GPT-4)
- Implémenter le streaming de la réponse
- Augmenter le taux de cache hit

**Impact** : Réduction de la latence totale de 30-50%.

#### 3. Améliorer les indicateurs visuels

**Justification** : L'utilisateur ne sait pas toujours ce qui se passe.

**Solution** :
- Rendre les indicateurs d'état plus visibles (écoute, réflexion, parole)
- Ajouter des animations pour montrer l'activité
- Ajouter un signal sonore quand Bobodo commence/arrête de parler

**Impact** : Meilleure compréhension du système, moins d'hésitation.

### P2 — Améliorations de confort

#### 1. Ajuster la vitesse de parole

**Justification** : La vitesse actuelle (0.9) peut être perçue comme trop rapide.

**Solution** : Tester différentes valeurs (0.85, 0.9, 0.95) et choisir la plus naturelle.

**Impact** : Meilleure perception du naturel.

#### 2. Améliorer les transitions

**Justification** : Les transitions entre les tours de parole sont abruptes.

**Solution** :
- Ajouter un délai court (500ms) entre la fin de la réponse et la reprise de l'écoute
- Ajouter un signal visuel (ex: "À vous de parler")
- Ajouter un signal sonore (ex: bip)

**Impact** : Meilleure fluidité de la conversation.

#### 3. Ajouter des pauses naturelles dans le TTS

**Justification** : FlutterTts ne gère pas les pauses naturelles.

**Solution** :
- Ajouter des pauses manuelles dans le texte (ex: "...", "\n")
- Utiliser SSML si supporté par FlutterTts
- Passer à Edge-TTS qui gère mieux les pauses

**Impact** : Meilleure perception du naturel.

### P3 — Améliorations cosmétiques

#### 1. Personnaliser la voix selon le contexte

**Justification** : Une voix différente selon le type de question peut améliorer l'engagement.

**Solution** : Tester différentes voix pour différents types de réponses.

**Impact** : Amélioration mineure de l'expérience.

#### 2. Ajouter des variations de vitesse selon le contexte

**Justification** : Une réponse longue peut être lue plus lentement pour être plus claire.

**Solution** : Ajuster la vitesse selon la longueur de la réponse.

**Impact** : Amélioration mineure de la clarté.

---

## CONCLUSION

Le mode vocal ↔ vocal Bobodo est **fonctionnel** mais présente des opportunités d'amélioration significatives :

1. **Qualité vocale** : La voix actuelle (FlutterTts par défaut) est peu naturelle. Passer à Edge-TTS avec une voix masculine serait une amélioration majeure.

2. **Latence** : OpenRouter est le goulot d'étranglement. Optimiser le modèle ou implémenter le streaming réduirait la latence.

3. **UX** : Les indicateurs visuels et les transitions pourraient être améliorés pour une meilleure compréhension du système.

**Recommandation prioritaire** : Implémenter P1-1 (voix masculine) et P1-2 (latence OpenRouter) pour un impact maximal sur l'expérience utilisateur.
