# BOBODO FULL VOICE CONVERSATION - Architecture Document

## Date
12 Juin 2026

---

## OBJECTIF

Documenter l'architecture cible pour le mode conversation vocale de Bobodo, synthétisant les 7 audits précédents. Ce document sert de référence pour l'implémentation.

---

## RÉSUMÉ EXÉCUTIF

### Architecture actuelle

**Mode dictée vocale unique** :
- User clique micro → enregistre → stop → transcription → édite → envoi → réponse → TTS optionnel
- Chaque tour nécessite des clics manuels
- Pas de cycle continu
- Pas de réactivation automatique du micro

### Architecture cible

**Deux modes distincts** :
- **Mode dictée** (existant - inchangé) : Dictée vocale avec édition
- **Mode conversation** (nouveau - à créer) : Conversation fluide type ChatGPT Voice

**Mode conversation** :
- User clique "Conversation vocale" → micro actif
- User parle → stop → transcription → envoi automatique → réponse → TTS automatique → micro réactif
- Cycle continu sans clics
- Interruptions gérées
- Mémoire compatible

---

## ARCHITECTURE CIBLE

### 1. Architecture globale

```
┌─────────────────────────────────────────────────────────────┐
│                        FLUTTER APP                          │
├─────────────────────────────────────────────────────────────┤
│  StudentBobodoTab                                           │
│  ├─ Mode dictée (existant)                                  │
│  │  ├─ Bouton micro                                         │
│  │  ├─ TextField éditable                                   │
│  │  ├─ Bouton envoi                                         │
│  │  └─ Contrôles TTS                                        │
│  │                                                          │
│  └─ Mode conversation (nouveau)                             │
│     ├─ Bouton "Conversation vocale" (header)                │
│     ├─ Indicateur "Micro actif"                             │
│     ├─ Bouton "Arrêter la conversation"                     │
│     ├─ Envoi automatique de transcription                  │
│     └─ Réactivation automatique du micro                   │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ WebSocket
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    KAMATERA SERVER                           │
├─────────────────────────────────────────────────────────────┤
│  Bobodo Vocal Service (ws://185.167.97.144:8000/ws)        │
│  ├─ STT Service (Faster Whisper)                           │
│  ├─ TTS Service (Piper)                                     │
│  └─ WebSocket Handler                                      │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ HTTP
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    SUPABASE EDGE FUNCTION                    │
├─────────────────────────────────────────────────────────────┤
│  bobodo-chat/index.ts                                        │
│  ├─ OpenRouter API (LLM)                                   │
│  ├─ RAG Academia (pgvector)                                │
│  ├─ Mémoire émotionnelle                                    │
│  ├─ Mémoire cross-session                                   │
│  ├─ Résumés automatiques                                    │
│  └─ Profil étudiant                                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ PostgreSQL
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    SUPABASE DATABASE                         │
├─────────────────────────────────────────────────────────────┤
│  bobodo_sessions                                             │
│  bobodo_messages                                            │
│  bobodo_emotional_memory                                    │
│  bobodo_cross_session_memory                                │
│  bobodo_conversation_summaries                              │
│  prep_knowledge (RAG)                                       │
│  students (profil)                                          │
└─────────────────────────────────────────────────────────────┘
```

---

### 2. User flow (Mode conversation)

```
┌─────────────────────────────────────────────────────────────┐
│  1. User clique "Conversation vocale"                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  2. Micro s'active automatiquement                         │
│     - Indicateur "Micro actif" apparaît                    │
│     - Waveform animation                                   │
│     - État : LISTENING                                      │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  3. User parle                                              │
│     - Audio enregistré (FlutterSoundRecorder)               │
│     - Waveform animation en temps réel                      │
│     - Durée affichée                                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  4. User clique stop (ou VAD automatique)                  │
│     - Recorder stop                                         │
│     - Audio envoyé via WebSocket                            │
│     - État : PROCESSING                                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  5. STT transcrit l'audio (Kamatera)                        │
│     - Faster Whisper                                        │
│     - Transcription renvoyée via WebSocket                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  6. Transcription reçue (Flutter)                           │
│     - Envoi automatique au BobodoProvider                  │
│     - Pas d'édition (mode conversation)                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  7. BobodoProvider envoie à Edge Function                  │
│     - bobodo-chat appelé                                    │
│     - session_id transmis                                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  8. Edge Function traite la demande                         │
│     - Charge le profil étudiant                             │
│     - Charge la mémoire cross-session                       │
│     - Charge l'historique de session                        │
│     - RAG Academia (vector + text search)                   │
│     - Appel OpenRouter (LLM)                                │
│     - Détection émotionnelle                                │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  9. Réponse générée                                          │
│     - Stockée dans bobodo_messages                           │
│     - Résumé automatique généré                             │
│     - État émotionnel loggé                                 │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  10. TTS génère l'audio (Kamatera)                          │
│      - Piper TTS                                            │
│      - Audio renvoyé via WebSocket                          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  11. Audio reçu (Flutter)                                   │
│      - Lecture via AudioPlayer                              │
│      - État : SPEAKING                                      │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  12. TTS terminé                                            │
│      - AudioPlayer.onPlayerComplete                         │
│      - Réactivation automatique du micro                     │
│      - État : LISTENING                                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  13. Cycle continue                                         │
│      - User peut reparler immédiatement                    │
│      - Pas de clics manuels                                │
└─────────────────────────────────────────────────────────────┘
```

---

### 3. State machine (Mode conversation)

```
┌─────────────────────────────────────────────────────────────┐
│                        IDLE                                │
│  _vocalState = VocalState.idle                             │
│  Micro inactif                                             │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ User active conversation
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      LISTENING                             │
│  _vocalState = VocalState.listening                         │
│  Micro actif, enregistrement                               │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ User stop (ou VAD)
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
        │ (réactivation) │              │               │
        └───────────────┘              └───────────────┘
                │                               │
                │                               │
                ▼                               ▼
        ┌───────────────┐              ┌───────────────┐
        │   IDLE        │              │   IDLE        │
        │ (user stop)   │              │               │
        └───────────────┘              └───────────────┘
```

**États** :
- `IDLE` : En attente (micro inactif)
- `LISTENING` : Écoute (micro actif, enregistrement)
- `PROCESSING` : Traitement (transcription + Bobodo)
- `SPEAKING` : Lecture (TTS en cours)
- `INTERRUPTED` : Interruption (user coupe)
- `ERROR` : Erreur (récupération)
- `PAUSED` : Pause (app fermé, appel reçu)
- `ENDED` : Fin (conversation terminée)

---

### 4. Audio flow (Mode conversation)

```
┌─────────────────────────────────────────────────────────────┐
│  ENREGISTREMENT (FlutterSoundRecorder)                      │
│  - Codec : PCM16 WAV                                        │
│  - Sortie : Stream vers _audioStreamController             │
│  - Buffer : _audioBuffer (List<Uint8List>)                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ WebSocket (base64)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  STT (Kamatera - Faster Whisper)                            │
│  - Réception audio via WebSocket                            │
│  - Transcription en temps réel                              │
│  - Renvoi transcription via WebSocket                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ WebSocket (texte)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  FLUTTER (Transcription reçue)                             │
│  - Envoi automatique à BobodoProvider                      │
│  - Pas d'édition (mode conversation)                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ HTTP (Edge Function)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  EDGE FUNCTION (bobodo-chat)                               │
│  - Traitement LLM (OpenRouter)                              │
│  - RAG Academia (pgvector)                                 │
│  - Mémoire émotionnelle                                     │
│  - Mémoire cross-session                                    │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ HTTP (réponse texte)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  TTS (Kamatera - Piper)                                     │
│  - Réception texte via HTTP                                 │
│  - Synthèse audio                                          │
│  - Renvoi audio via WebSocket (base64)                      │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ WebSocket (base64)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  FLUTTER (Audio reçu)                                      │
│  - Décodage base64                                         │
│  - Lecture via AudioPlayer                                  │
│  - Réactivation automatique du micro à la fin               │
└─────────────────────────────────────────────────────────────┘
```

**Mode duplex** :
- Actuel : Half duplex (enregistrement OU lecture)
- Cible V1 : Pseudo duplex (interruption possible)
- Cible V2 : Full duplex (enregistrement ET lecture simultanés)

---

### 5. Interruption management (Mode conversation)

```
┌─────────────────────────────────────────────────────────────┐
│  CAS 1 : User coupe Bobodo                                 │
│  - Bouton stop pendant lecture                              │
│  - Transition : SPEAKING → INTERRUPTED → LISTENING         │
│  - Réactivation automatique du micro                        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  CAS 2 : User parle pendant la réponse                     │
│  - VAD détecte parole pendant TTS                           │
│  - Transition : SPEAKING → INTERRUPTED → LISTENING         │
│  - Réactivation automatique du micro                        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  CAS 3 : User ferme l'écran                                 │
│  - Sauvegarde d'état                                       │
│  - Transition : [ANY] → PAUSED                              │
│  - Reprise : PAUSED → [PREVIOUS STATE]                     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  CAS 4 : User reçoit un appel                               │
│  - Détection d'appel (flutter_phone_state)                  │
│  - Transition : [ANY] → PAUSED                              │
│  - Reprise : PAUSED → [PREVIOUS STATE]                     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  CAS 5 : User perd Internet                                 │
│  - Détection de perte réseau (connectivity_plus)           │
│  - Transition : [ANY] → ERROR                               │
│  - Retry automatique                                        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  CAS 6 : User revient                                       │
│  - Restauration d'état                                      │
│  - Transition : PAUSED → [PREVIOUS STATE]                  │
└─────────────────────────────────────────────────────────────┘
```

---

### 6. Memory integration (Mode conversation)

**100% compatible avec les systèmes de mémoire existants** :

```
┌─────────────────────────────────────────────────────────────┐
│  MÉMOIRE ÉMOTIONNELLE                                      │
│  - Détection émotionnelle (texte)                          │
│  - Logging des états significatifs                         │
│  - Adaptation du prompt selon l'émotion                    │
│  - Compatibilité : ✅ 100%                                 │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  PROFIL ÉTUDIANT                                            │
│  - Chargement du profil (prénom, bac, projet, etc.)        │
│  - Injection dans le prompt                                 │
│  - Personnalisation des réponses                           │
│  - Compatibilité : ✅ 100%                                 │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  RÉSUMÉS AUTOMATIQUES                                      │
│  - Génération après chaque réponse                         │
│  - Sauvegarde dans bobodo_conversation_summaries           │
│  - Cross-session memory                                     │
│  - Compatibilité : ✅ 100%                                 │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  MÉMOIRE CROSS-SESSION                                     │
│  - Chargement des résumés précédents                       │
│  - Injection dans le prompt                                 │
│  - Maintien du contexte entre sessions                      │
│  - Compatibilité : ✅ 100%                                 │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  RAG ACADEMIA                                               │
│  - Recherche vectorielle (embeddings)                      │
│  - Recherche textuelle (ILIKE)                              │
│  - Expansion sémantique (reformulations)                    │
│  - Fallback web search (Perplexity)                         │
│  - Compatibilité : ✅ 100%                                 │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  HISTORIQUE DE SESSIONS                                     │
│  - Chargement des 14 derniers messages                      │
│  - Injection dans le prompt                                 │
│  - Maintien du contexte dans la session                     │
│  - Compatibilité : ✅ 100%                                 │
└─────────────────────────────────────────────────────────────┘
```

**Améliorations optionnelles** :
- Fréquence des résumés (tous les 3 échanges en mode conversation)
- Taille de l'historique (20 messages en mode conversation)
- Détection émotionnelle vocale (V2)

---

### 7. UX (Mode conversation)

**Interface** :

```
┌─────────────────────────────────────────────────────────────┐
│ [🤖] Bobodo            [🎤] [+] [📜] [🔗]              │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Messages...                                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│ [😊] [🎤 Micro actif - Parlez pour continuer] [⏹]       │
└─────────────────────────────────────────────────────────────┘
```

**Composants** :
- Bouton "Conversation vocale" dans le header (icon mic)
- Indicateur "Micro actif - Parlez pour continuer"
- Bouton "Arrêter la conversation" (icon stop)
- Waveform animation pendant l'enregistrement
- Contrôles TTS (inchangés)

**Transitions** :
- DICTÉE → CONVERSATION : Bouton "Conversation vocale" devient actif, TextField disparaît, indicateur apparaît
- CONVERSATION → DICTÉE : Bouton "Conversation vocale" devient inactif, TextField réapparaît, indicateur disparaît

**Onboarding** :
- Message explicatif au premier lancement
- Explication du fonctionnement
- Bouton "Compris" pour fermer

---

## IMPACTS

### 1. Impact Flutter

**Fichiers à modifier** :
- `academia_app/lib/features/student/tabs/student_bobodo_tab.dart`

**Modifications** :
1. Ajouter enum `VocalState` (7 états)
2. Ajouter flag `_isConversationMode`
3. Ajouter bouton "Conversation vocale" dans le header
4. Modifier `_onTranscriptionReceived()` pour envoi automatique
5. Modifier `onPlayerComplete` pour réactivation automatique
6. Ajouter indicateur visuel "Micro actif"
7. Ajouter gestion d'erreurs robuste
8. Ajouter sauvegarde/restauration d'état
9. Ajouter détection d'appel téléphonique
10. Ajouter gestion de perte réseau

**Complexité** : MOYENNE
- ~200 lignes de code à ajouter
- ~50 lignes de code à modifier
- Tests sur appareil réel requis

---

### 2. Impact Kamatera

**Fichiers à modifier** : AUCUN

**Composants existants** :
- STT Service (Faster Whisper) : ✅ Compatible
- TTS Service (Piper) : ✅ Compatible
- WebSocket Handler : ✅ Compatible

**Modifications** : AUCUNE
- Le serveur actuel supporte déjà le mode conversation
- Pas de changement requis

**Complexité** : NULLE

---

### 3. Impact Supabase

**Fichiers à modifier** : AUCUN

**Tables existantes** :
- `bobodo_sessions` : ✅ Compatible
- `bobodo_messages` : ✅ Compatible
- `bobodo_emotional_memory` : ✅ Compatible
- `bobodo_cross_session_memory` : ✅ Compatible
- `bobodo_conversation_summaries` : ✅ Compatible

**RPCs existantes** :
- `app_get_or_create_bobodo_session` : ✅ Compatible
- `app_list_bobodo_messages` : ✅ Compatible
- `log_bobodo_emotional_state` : ✅ Compatible
- `get_bobodo_cross_session_memory` : ✅ Compatible
- `save_bobodo_conversation_memory` : ✅ Compatible

**Edge Function** :
- `bobodo-chat/index.ts` : ✅ Compatible

**Modifications** : AUCUNE
- Les systèmes de mémoire sont 100% compatibles
- Pas de changement requis

**Complexité** : NULLE

---

## PHASES D'IMPLÉMENTATION

### Phase 1 (CRITIQUE - Mode conversation basique)

**Objectif** : Mode conversation fonctionnel

**Tâches** :
1. Ajouter enum `VocalState` (7 états)
2. Ajouter flag `_isConversationMode`
3. Ajouter bouton "Conversation vocale" dans le header
4. Modifier `_onTranscriptionReceived()` pour envoi automatique
5. Modifier `onPlayerComplete` pour réactivation automatique
6. Ajouter indicateur visuel "Micro actif"
7. Ajouter gestion d'erreurs robuste

**Durée estimée** : 2-3 jours

**Tests** :
- Réactivation automatique du micro
- Envoi automatique de transcription
- Gestion d'erreurs
- Tests sur appareil réel

---

### Phase 2 (IMPORTANT - Stabilité)

**Objectif** : Gestion des interruptions

**Tâches** :
8. Ajouter sauvegarde d'état à la fermeture
9. Ajouter restauration d'état au retour
10. Ajouter détection d'appel téléphonique
11. Ajouter gestion de perte réseau
12. Ajouter timeout d'inactivité

**Durée estimée** : 2-3 jours

**Tests** :
- Sauvegarde/restauration d'état
- Détection d'appel
- Gestion de perte réseau
- Timeout d'inactivité

---

### Phase 3 (OPTIONNEL - Optimisations)

**Objectif** : UX améliorée

**Tâches** :
13. Ajouter VAD automatique
14. Augmenter fréquence des résumés
15. Augmenter taille de l'historique
16. Ajouter détection émotionnelle vocale

**Durée estimée** : 3-5 jours

**Tests** :
- VAD automatique
- Résumés fréquents
- Historique étendu
- Détection émotionnelle vocale

---

## RISQUES ET MITIGATION

### 1. Recorder error

**Risque** : Recorder peut échouer à la réactivation

**Mitigation** :
- Try-catch robuste autour de `_startVocalRecording()`
- Vérifier `mounted` avant setState
- Fallback sur mode dictée

---

### 2. Widget dispose

**Risque** : Widget dispose pendant la réactivation

**Mitigation** :
- Vérifier `mounted` avant setState
- Annuler les subscriptions dans dispose
- Tests approfondis

---

### 3. WebSocket déconnecté

**Risque** : WebSocket déconnecté pendant la réactivation

**Mitigation** :
- Reconnecter WebSocket automatiquement
- Gestion d'erreur explicite
- Retry automatique

---

### 4. User confusion

**Risque** : User ne comprend pas pourquoi le micro se réactive

**Mitigation** :
- Indicateur visuel clair
- Onboarding explicite
- Bouton "Arrêter la conversation" évident

---

### 5. Performance

**Risque** : Mode conversation consomme plus de batterie

**Mitigation** :
- Timeout d'inactivité
- Indicateur de batterie
- Désactivation facile

---

## CONCLUSION

### Architecture actuelle

**Mode dictée vocale unique** :
- Enregistrement → transcription → édition → envoi → réponse → TTS optionnel
- Chaque tour nécessite des clics manuels
- Pas de cycle continu
- Pas de réactivation automatique du micro

### Architecture cible

**Deux modes distincts** :
- **Mode dictée** (existant - inchangé) : Dictée vocale avec édition
- **Mode conversation** (nouveau - à créer) : Conversation fluide type ChatGPT Voice

**Mode conversation** :
- Cycle continu sans clics
- Réactivation automatique du micro
- Envoi automatique de transcription
- Interruptions gérées
- Mémoire 100% compatible

### Impacts

- **Flutter** : Modifications moyennes (~200 lignes)
- **Kamatera** : Aucune modification
- **Supabase** : Aucune modification

### Recommandation

**Implémenter Phase 1 (Mode conversation basique)**

**Justification** :
- Faisable
- Simple
- Impact UX positif
- Risques gérables
- Aucun impact serveur

---

## LIVRABLES

### Audits complétés

1. ✅ BOBODO_VOICE_GAP_ANALYSIS.md
2. ✅ BOBODO_VOICE_STATE_MACHINE.md
3. ✅ BOBODO_VOICE_AUDIO_ARCHITECTURE.md
4. ✅ BOBODO_VOICE_INTERRUPTION_AUDIT.md
5. ✅ BOBODO_VOICE_AUTO_LISTENING.md
6. ✅ BOBODO_VOICE_MEMORY_COMPATIBILITY_V2.md
7. ✅ BOBODO_VOICE_UX_FINAL.md

### Livrable final

8. ✅ BOBODO_FULL_VOICE_CONVERSATION_ARCHITECTURE.md (ce document)

---

## PROCHAINES ÉTAPES

1. Validation de l'architecture par l'utilisateur
2. Implémentation Phase 1 (Mode conversation basique)
3. Tests sur appareil réel
4. Validation UX
5. Implémentation Phase 2 (Stabilité)
6. Tests approfondis
7. Validation finale
8. Déploiement en production
