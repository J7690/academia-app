# BOBODO Mode 2 — Plan d'Implémentation

**Date**: 2025-06-15  
**Statut**: En attente de validation  
**Stratégie retenue**: STT natif + TTS local (Stratégie 2)

---

## MISSION 1 — POINT D'INSERTION EXACT

### Où la réponse Bobodo est reçue

**Fichier** : `lib/providers/bobodo_provider.dart`  
**Méthode** : `_callEdgeFunction()`  
**Ligne** : 246-249

```dart
if (backendOk) {
  _lastFailedMessage = null;
  await loadMessages();  // ← Messages rechargés ici, réponse Bobodo disponible
}
```

Après `loadMessages()`, la liste `_messages` contient le dernier message Bobodo. Le provider appelle `notifyListeners()` et `_isLoading` passe à `false`.

### Où le texte de réponse est disponible

Après que `sendUserMessage()` termine (c'est une méthode `async`), `provider.messages.last` contient la réponse Bobodo.

### Point d'insertion exact pour le TTS

**Fichier** : `lib/features/student/tabs/student_bobodo_tab.dart`  
**Méthode** : `_onTranscriptionReceived()`  
**Ligne** : 1399  
**Code actuel** :

```dart
final provider = context.read<BobodoProvider>();
provider.sendUserMessage(text);  // ← Fire-and-forget actuellement
```

**Modification requise** : `await` le `sendUserMessage()`, puis extraire la réponse et la lire vocalement.

**Point exact** : Après la ligne 1399, ajouter ~8 lignes pour :
1. Attendre la fin de `sendUserMessage()`
2. Extraire le dernier message bot
3. Mettre à jour `_conversationState` → `playing`
4. Appeler `_speakWithLocalTts(text)`

---

## MISSION 2 — PREUVE QUE _onAudioPlaybackComplete() RELANCE L'ÉCOUTE

**Fichier** : `lib/features/student/tabs/student_bobodo_tab.dart`  
**Méthode** : `_onAudioPlaybackComplete()`  
**Lignes** : 1564-1571

```dart
void _onAudioPlaybackComplete() {
  if (_isConversationMode && _conversationState != ConversationState.ended) {
    setState(() {
      _conversationState = ConversationState.listening;
    });
    _resetInactivityTimer();
    _startVocalRecording();  // ← Relance l'écoute STT natif
  }
}
```

**Preuve** :
1. Condition : `_isConversationMode == true` ET `_conversationState != ended` → les deux seront vraies pendant une conversation active
2. Action : `_startVocalRecording()` appelle `_speechToText.listen()` (ligne 1283) qui relance la reconnaissance vocale
3. État : `_conversationState` passe à `listening` → l'indicateur UI se met à jour

**ET** : `_speakWithLocalTts()` appelle déjà `_onAudioPlaybackComplete()` à la fin de la lecture (ligne 1462-1464) :

```dart
Future<void> _speakWithLocalTts(String text) async {
  try {
    setState(() => _isSpeaking = true);
    await _flutterTts.speak(text);
    await _flutterTts.awaitSpeakCompletion(true);
    setState(() => _isSpeaking = false);
    if (_isConversationMode) {
      _onAudioPlaybackComplete();  // ← Relance automatique
    }
  } catch (e) {
    debugPrint('[LOCAL_TTS_ERROR] $e');
    setState(() => _isSpeaking = false);
  }
}
```

**Conclusion** : La boucle `TTS terminé → relance écoute → utilisateur parle → transcription → envoi → réponse → TTS → boucle` est DÉJÀ codée. Il suffit de déclencher le premier `_speakWithLocalTts()`.

---

## MISSION 3 — FLUX COMPLET AVEC INDICATION EXISTANT/MANQUANT

```
ÉTAPE 1: Utilisateur parle
  ✅ EXISTE — _speechToText.listen() via _startVocalRecording()

ÉTAPE 2: STT natif transcrit
  ✅ EXISTE — onResult callback → _handleSpeechResult()

ÉTAPE 3: Transcription reçue
  ✅ EXISTE — _onTranscriptionReceived() branche _isConversationMode

ÉTAPE 4: sendUserMessage(text)
  ✅ EXISTE — provider.sendUserMessage(text) ligne 1399
  ⚠️ MODIF — Ajouter await pour attendre la réponse

ÉTAPE 5: Réponse Bobodo disponible
  ✅ EXISTE — Après sendUserMessage(), provider.messages contient la réponse
  ❌ MANQUE — Extraire le dernier message bot

ÉTAPE 6: Transition état → playing
  ✅ EXISTE — setState(() { _conversationState = ConversationState.playing; })
  ❌ MANQUE — Appeler cette transition

ÉTAPE 7: TTS lecture vocale
  ✅ EXISTE — _speakWithLocalTts(text) — méthode complète
  ❌ MANQUE — L'appel effectif avec le texte de la réponse

ÉTAPE 8: Fin lecture → relance écoute
  ✅ EXISTE — _speakWithLocalTts() appelle _onAudioPlaybackComplete()
  ✅ EXISTE — _onAudioPlaybackComplete() appelle _startVocalRecording()
  (Tout automatique, rien à ajouter)

ÉTAPE 9: Boucle relancée
  ✅ EXISTE — Retour à l'étape 1
```

**Résumé** : Sur 9 étapes, 7 sont entièrement implémentées. Les étapes 5, 6 et 7 nécessitent chacune 1-3 lignes de code.

---

## MISSION 4 — RISQUES DE RÉGRESSION

### Mode 1 (Dictée vocale)

**Risque : NUL**

Justification : Le Mode 1 passe par la branche `else` de `_onTranscriptionReceived()` (ligne 1400-1410). La modification concerne uniquement la branche `if (_isConversationMode)` (ligne 1380). Les deux branches sont mutuellement exclusives par le flag `_isConversationMode`. Le Mode 1 n'est jamais activé quand ce flag est `true`.

### Envoi texte (bouton Envoyer)

**Risque : NUL**

Justification : Le bouton Envoyer appelle `_send(context)` (ligne 1208) qui appelle `provider.sendUserMessage(text)` directement. Il ne passe pas par `_onTranscriptionReceived()`. La modification est dans `_onTranscriptionReceived()` uniquement, et seulement dans la branche conversation.

### Historique / Restauration

**Risque : NUL**

Justification : La restauration passe par `restoreLastSession()` → `loadMessages()` dans `initState`. Aucune interaction avec `_onTranscriptionReceived()` ni avec les flags de conversation.

### Auto-scroll

**Risque : NUL**

Justification : L'auto-scroll est déclenché dans le `Consumer<BobodoProvider>` builder par le changement de `messages.length`. Ce mécanisme n'est pas touché.

### setState during build (anomalie existante)

**Risque : FAIBLE**

Justification : L'ajout d'un `await` dans `_onTranscriptionReceived()` pourrait théoriquement interagir avec le `setState()` existant. Cependant, `_onTranscriptionReceived()` est appelé depuis un callback (`_handleSpeechResult`), pas depuis un `build()`. Le `await` s'exécutera dans le contexte du callback, pas du build. L'anomalie `setState during build` préexiste et n'est pas aggravée.

---

## MISSION 5 — PLAN D'IMPLÉMENTATION ULTRA-MINIMAL

### Fichiers concernés

| Fichier | Modification |
|---------|-------------|
| `lib/features/student/tabs/student_bobodo_tab.dart` | Seul fichier modifié |

### Méthode concernée

| Méthode | Action |
|---------|--------|
| `_onTranscriptionReceived()` | Ajouter `await` + extraction réponse + appel TTS |

### Ligne exacte de modification

**Ligne 1399** — Remplacer :
```dart
provider.sendUserMessage(text);
```

Par un bloc qui :
1. `await provider.sendUserMessage(text);`
2. Extraire le dernier message bot de `provider.messages`
3. Si message bot trouvé et `_isConversationMode` toujours actif :
   - `setState(() { _conversationState = ConversationState.playing; })`
   - `await _speakWithLocalTts(lastBotMessage)`

### Estimation du nombre de lignes modifiées

**~10 lignes modifiées/ajoutées** dans un seul fichier, une seule méthode.

### Pseudo-code de la modification

```dart
// Ligne 1398-1399 actuel:
final provider = context.read<BobodoProvider>();
provider.sendUserMessage(text);

// Remplacé par:
final provider = context.read<BobodoProvider>();
await provider.sendUserMessage(text);

// Après réponse: lire vocalement si toujours en mode conversation
if (_isConversationMode && !provider.isLoading && provider.messages.isNotEmpty) {
  final lastMsg = provider.messages.last;
  if (lastMsg['sender'] != 'student') {
    final botText = lastMsg['content']?.toString() ?? '';
    if (botText.isNotEmpty) {
      setState(() { _conversationState = ConversationState.playing; });
      await _speakWithLocalTts(botText);
    }
  }
}
```

### Signature de la méthode

La méthode `_onTranscriptionReceived()` est actuellement `void`. Elle devra devenir `Future<void>` pour supporter le `await`.

Vérification de l'appelant : `_handleSpeechResult()` (ligne 1319) appelle `_onTranscriptionReceived(text)` sans `await`. Il faudra soit :
- Rendre `_handleSpeechResult()` async et await
- Ou appeler sans await (fire-and-forget acceptable ici car le callback STT n'attend pas de retour)

**Option retenue** : Fire-and-forget — l'appel sans `await` est acceptable car le callback STT (`onResult`) ne gère pas de valeur de retour. La méthode s'exécutera correctement en arrière-plan.

### Récapitulatif final

| Métrique | Valeur |
|----------|--------|
| Fichiers modifiés | **1** |
| Méthodes modifiées | **1** (+ signature) |
| Lignes ajoutées | **~10** |
| Lignes supprimées | **1** (remplacement) |
| Impact Mode 1 | **Zéro** |
| Impact envoi texte | **Zéro** |
| Impact historique | **Zéro** |
| Dépendances nouvelles | **Aucune** |
| Changement serveur | **Aucun** |
| Changement Supabase | **Aucun** |

---

**Aucune implémentation effectuée. Aucune correction. Aucun commit.**

*En attente de validation pour procéder.*
