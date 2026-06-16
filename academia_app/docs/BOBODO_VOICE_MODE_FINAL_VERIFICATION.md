# BOBODO — Vérification Finale du Mode Voix

**Date**: 2025-06-15  
**Objectif**: Déterminer précisément la nature de la non-conformité du mode conversation vocale

---

## RÉPONSE AU POINT À VÉRIFIER

**Le problème est : CAS C**

> Le bouton existe, l'UI existe, mais l'appel à `_vocalService.sendAudio()` n'est jamais effectué.

Plus précisément :
- Le bouton existe ✅
- L'UI de conversation existe ✅ (indicateur d'état, contrôles)
- Le STT natif fonctionne ✅
- Le texte est envoyé via HTTP (pas WebSocket) ✅
- `_vocalService.sendAudio()` n'est jamais appelé ✅
- **En conséquence**, le serveur ne reçoit jamais d'audio, ne fait jamais TTS, et ne renvoie jamais de réponse vocale

---

## MISSION 1 — TRAÇAGE COMPLET DU FLUX DEPUIS LE BOUTON HEADER

### Widget source

```
student_bobodo_tab.dart, ligne 404-412
```

```dart
IconButton(
  icon: Icon(
    _isConversationMode ? Icons.mic : Icons.mic_none,
    color: _isConversationMode ? PrepTheme.primary : Colors.white,
    size: 20,
  ),
  tooltip: _isConversationMode ? 'Mode Conversation' : 'Mode Dictée',
  onPressed: _toggleVoiceMode,
),
```

### Schéma complet du flux

```
ÉTAPE 1: BOUTON HEADER
  Widget: IconButton [ligne 404]
  Callback: _toggleVoiceMode [ligne 411]

ÉTAPE 2: TOGGLE
  Méthode: _toggleVoiceMode() [ligne 1511]
  Changement d'état: _isConversationMode = true
  Appel suivant: _startConversationMode()

ÉTAPE 3: DÉMARRAGE MODE CONVERSATION
  Méthode: _startConversationMode() [ligne 1522]
  Changement d'état: _conversationState = ConversationState.listening
  Actions: _resetInactivityTimer() + _startVocalRecording()

ÉTAPE 4: ENREGISTREMENT VOCAL
  Méthode: _startVocalRecording() [ligne 1272]
  Service utilisé: _speechToText.listen() [PACKAGE speech_to_text — STT NATIF ANDROID]
  ⚠️ PAS _vocalService.sendAudio()
  Changement d'état: _isRecordingMode = true, _isRecording = true

ÉTAPE 5: RÉSULTAT STT
  Callback: onResult [ligne 1284]
  Condition: result.finalResult == true
  Appel suivant: _handleSpeechResult(_lastRecognizedWords)

ÉTAPE 6: TRAITEMENT RÉSULTAT
  Méthode: _handleSpeechResult() [ligne 1315]
  Actions: _stopVocalRecording() + _onTranscriptionReceived(text)

ÉTAPE 7: RÉCEPTION TRANSCRIPTION EN MODE CONVERSATION
  Méthode: _onTranscriptionReceived() [ligne 1379, branche _isConversationMode]
  Changement d'état: _conversationState = ConversationState.thinking
  Service appelé: provider.sendUserMessage(text) [ENVOI HTTP]
  Destination finale: Edge Function bobodo-chat via HTTP POST

ÉTAPE 8: RÉPONSE EDGE FUNCTION
  Retour: JSON {reply: "..."} — TEXTE UNIQUEMENT
  Action provider: loadMessages() → UI reconstruite
  Changement d'état: isLoading = false

ÉTAPE 9: FIN DU FLUX
  ❌ Aucun audio reçu
  ❌ _onAudioResponseReceived() jamais appelé
  ❌ _audioPlayer jamais déclenché
  ❌ _onAudioPlaybackComplete() jamais atteint
  ❌ _startVocalRecording() jamais relancé automatiquement
  ❌ La boucle conversationnelle s'arrête

FLUX MORT — L'utilisateur reste bloqué sur _conversationState = thinking
(jamais mis à jour car aucun callback ne le modifie après loadMessages)
```

---

## MISSION 2 — RÉPONSE BINAIRE

**Si un étudiant appuie aujourd'hui sur le micro du header, peut-il réellement entrer dans une conversation vocale continue comparable à ChatGPT Voice ?**

## NON.

**Preuves** :

1. Après avoir parlé, le texte est envoyé par HTTP à l'Edge Function — la réponse est TEXTE uniquement
2. `_vocalService.sendAudio()` n'est appelé NULLE PART dans le code source (grep confirmé : 0 appels)
3. Le serveur WebSocket Kamatera ne reçoit jamais d'audio et ne produit jamais de réponse vocale
4. `_onAudioResponseReceived()` n'est jamais déclenché
5. `_onAudioPlaybackComplete()` — qui relancerait l'écoute — n'est jamais atteint
6. La conversation s'arrête après le premier échange

---

## MISSION 3 — PREMIER POINT EXACT D'INTERRUPTION

| Attribut | Valeur |
|----------|--------|
| **Fichier** | `lib/features/student/tabs/student_bobodo_tab.dart` |
| **Méthode** | `_onTranscriptionReceived()` |
| **Ligne** | **1399** |
| **Code** | `provider.sendUserMessage(text);` |
| **Raison** | Le texte transcrit est envoyé via HTTP (Edge Function) au lieu d'être envoyé comme audio brut au WebSocket via `_vocalService.sendAudio()`. L'Edge Function retourne du texte. Aucune réponse vocale n'est jamais générée. Le flux audio serveur (STT → Bobodo → TTS → audio_response) n'est jamais activé. |

**Ce qui DEVRAIT se passer à la place** (mais qui n'est pas implémenté) :

À la ligne 1399, en mode conversation, il faudrait SOIT :
- Envoyer l'audio brut au WebSocket (`_vocalService.sendAudio(audioBytes)`) pour que le serveur fasse tout le pipeline
- OU après réception de la réponse texte, appeler un TTS (local ou serveur) pour produire de l'audio et le jouer

---

## MISSION 4 — ÉLÉMENTS UI VISIBLES POUR L'UTILISATEUR

### Bouton visible ?

**OUI** — `IconButton` dans le header (ligne 404-412)
- Icône : `Icons.mic` quand actif, `Icons.mic_none` quand inactif
- Couleur : `PrepTheme.primary` quand actif, blanc quand inactif
- Tooltip : "Mode Conversation" / "Mode Dictée"

### État visible ?

**OUI** — Indicateur d'état dans le header (lignes 426-430, 1608-1673)
- Affiché sous le header quand `_isConversationMode == true`
- États possibles : "En attente", "Écoute...", "Traitement...", "Bobodo réfléchit...", "Réponse...", "Lecture...", "Pause", "Session terminée"
- Chaque état a une icône et une couleur distincte

### Indicateur visible ?

**OUI** — Contrôles de conversation (lignes 1675-1712)
- Bouton "Quitter" (toujours visible en mode conversation)
- Bouton "Couper" (visible quand `_isSpeaking == true`)
- Bouton "Rejouer" (visible quand audio disponible et pas en lecture)
- Bouton "Reprendre" (visible quand état == paused)

### L'input bar est cachée ?

**OUI** — La barre de saisie texte est remplacée par les contrôles de conversation :
```dart
if (_isConversationMode)
  _buildConversationControls(),    // ligne 292-296
if (!_isConversationMode)
  _buildInputBar(provider),         // ligne 298-299
```

### Conclusion UX

L'interface visuelle est **complète et cohérente** avec un mode conversation vocale de type ChatGPT Voice :
- Le bouton active clairement le mode
- L'indicateur montre l'état en temps réel
- Les contrôles permettent de couper/quitter/reprendre
- La barre de saisie texte disparaît

**Le problème n'est pas l'UI. L'UI est prête. Le problème est que le flux audio ne connecte pas au bon service.**

---

## MISSION 5 — CE QUI MANQUE PRÉCISÉMENT

### 1. Liaison manquante : Envoi audio → WebSocket

| Élément | Existe | Utilisé |
|---------|--------|---------|
| `_vocalService.sendAudio(Uint8List)` | ✅ Défini ligne 122 de `bobodo_vocal_service.dart` | ❌ Jamais appelé |
| Enregistrement audio brut (PCM/WAV) | ❌ Non implémenté | — |
| `FlutterSoundRecorder` déclaré | ✅ Ligne 76 | ❌ Non utilisé pour envoyer au WebSocket |

**Manque** : En mode conversation, l'audio brut n'est jamais capturé pour envoi WebSocket. Le code utilise `_speechToText.listen()` (STT natif on-device) qui ne produit que du texte.

### 2. Callback manquant : Réponse texte → TTS

| Élément | Existe | Utilisé |
|---------|--------|---------|
| `_speakWithLocalTts(text)` | ✅ Défini ligne 1456 | ❌ Jamais appelé dans le flux normal de conversation |
| `_flutterTts` initialisé | ✅ Ligne 53, configuré en `fr-FR` | ❌ Non utilisé après réception réponse |

**Manque** : Après que `sendUserMessage()` aboutit et que `loadMessages()` recharge les messages, AUCUN callback ne récupère la réponse texte pour la synthétiser vocalement.

### 3. État non connecté : `_conversationState` reste bloqué

| Élément | Attendu | Réalité |
|---------|---------|---------|
| Après envoi message | `thinking` → `playing` → `listening` | `thinking` → **bloqué** |
| Transition `thinking` → `playing` | Via `_onAudioResponseReceived()` | Jamais atteint |
| Transition `playing` → `listening` | Via `_onAudioPlaybackComplete()` | Jamais atteint |

**Manque** : Aucun mécanisme ne fait avancer la machine à états après que la réponse texte est reçue par l'Edge Function.

### 4. Service non utilisé : WebSocket vocal

| Élément | État |
|---------|------|
| `BobodoVocalService` instancié | ✅ Ligne 88 |
| Connexion WebSocket établie | ✅ Ligne 1252 `_vocalService.connect(finalSessionId)` |
| Écoute `messageStream` | ✅ Ligne 1255 |
| Écoute `errorStream` | ✅ Ligne 1259 |
| Envoi audio via `sendAudio()` | ❌ **JAMAIS** |

**Le WebSocket est connecté, les listeners sont en place, mais rien n'est jamais envoyé.**

### 5. Résumé des manques

```
MANQUE 1: Pas d'envoi audio brut au WebSocket
  → _vocalService.sendAudio() existe mais n'est jamais appelé
  → Pas d'enregistrement audio brut en mode conversation

MANQUE 2: Pas de TTS après réponse texte
  → _speakWithLocalTts() existe mais n'est jamais appelé après réponse Edge Function
  → Aucun pont entre "réponse texte reçue" et "lecture vocale"

MANQUE 3: Pas de relance d'écoute après réponse
  → _onAudioPlaybackComplete() existe et relancerait l'écoute
  → Mais il n'est jamais atteint car aucune lecture audio ne démarre

MANQUE 4: Machine à états bloquée
  → _conversationState reste sur "thinking" indéfiniment
  → Aucun mécanisme de transition après réception de la réponse texte
```

---

## VERDICT FINAL

| Question | Réponse |
|----------|---------|
| Le bouton existe ? | OUI |
| L'UI est prête ? | OUI |
| L'indicateur d'état existe ? | OUI |
| Les contrôles existent ? | OUI |
| Le WebSocket est connecté ? | OUI |
| Le serveur STT+TTS est prêt ? | OUI |
| L'audio est envoyé au WebSocket ? | **NON** |
| Un TTS est joué après réponse ? | **NON** |
| La boucle conversationnelle fonctionne ? | **NON** |

**Nature exacte du problème** : L'UI est complète. Le serveur est prêt. Les listeners sont en place. Il manque **une seule liaison** : connecter la sortie de l'enregistrement audio (ou de la réponse texte) au pipeline qui produit et lit une réponse vocale.

**Complexité estimée de la correction** : Faible à moyenne. Deux approches possibles :
- **Approche minimale** : Après `sendUserMessage()` + `loadMessages()`, récupérer la réponse texte et appeler `_speakWithLocalTts()` puis `_onAudioPlaybackComplete()` pour relancer la boucle.
- **Approche complète** : Utiliser `_vocalService.sendAudio()` pour envoyer l'audio brut au serveur et laisser le pipeline serveur faire STT + Bobodo + TTS + retour audio.

---

**Aucune correction effectuée. Aucune implémentation. Aucun commit.**

*Fin du rapport.*
