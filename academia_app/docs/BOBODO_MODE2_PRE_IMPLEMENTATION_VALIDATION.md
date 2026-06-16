# BOBODO Mode 2 — Validation Pré-Implémentation

**Date**: 2025-06-15  
**Statut**: Prêt pour implémentation après validation

---

## MISSION 1 — PREUVE QUE `await sendUserMessage()` RETOURNE APRÈS TOUT

### Chaîne d'appel complète

```
sendUserMessage(content)             [ligne 136, async, await _callEdgeFunction]
  └─ await _callEdgeFunction(content)  [ligne 191]
       ├─ _setLoading(true)             [ligne 198 → notifyListeners]
       ├─ await http.post(...)          [ligne 212 — attend la réponse HTTP]
       ├─ _setLoading(false)            [ligne 243 → notifyListeners]
       └─ if (backendOk):
            └─ await loadMessages()     [ligne 248]
                 ├─ await _client.rpc(...) [ligne 117 — attend Supabase]
                 ├─ _messages..clear()..addAll(data)  [ligne 121-123]
                 ├─ _shouldScrollToBottom = true      [ligne 124]
                 └─ notifyListeners()                 [ligne 125]
```

### Preuves par le code

**1. `sendUserMessage()` attend `_callEdgeFunction()`** :
```dart
// bobodo_provider.dart ligne 191
await _callEdgeFunction(content);
```
→ `sendUserMessage()` ne retourne pas avant la fin de `_callEdgeFunction()`.

**2. `_callEdgeFunction()` attend la réponse HTTP** :
```dart
// bobodo_provider.dart ligne 212
final finalResponse = await http.post(uri, ...);
```
→ Attend la réponse complète du serveur.

**3. `_callEdgeFunction()` attend `loadMessages()`** :
```dart
// bobodo_provider.dart ligne 246-249
if (backendOk) {
  _lastFailedMessage = null;
  await loadMessages();
}
```
→ Attend le rechargement complet des messages.

**4. `loadMessages()` attend la RPC Supabase et notifie** :
```dart
// bobodo_provider.dart ligne 117-125
final data = await _client.rpc('app_list_bobodo_messages', ...);
_messages..clear()..addAll(data.cast<Map<String, dynamic>>());
_shouldScrollToBottom = true;
notifyListeners();
```
→ Attend la réponse Supabase, remplit `_messages`, notifie les listeners.

**5. `_setLoading(false)` est appelé dans le `finally`** :
```dart
// bobodo_provider.dart ligne 242-244
} finally {
  _setLoading(false);  // → notifyListeners()
}
```
→ Quoi qu'il arrive (succès ou erreur), `isLoading` repasse à `false` avant que `sendUserMessage()` retourne.

### Conclusion Mission 1

**CONFIRMÉ** : Quand `await provider.sendUserMessage(text)` retourne :
- ✅ La réponse HTTP a été reçue
- ✅ La réponse a été sauvegardée côté serveur (par l'Edge Function)
- ✅ `loadMessages()` a rechargé les messages depuis Supabase
- ✅ `_messages` contient la réponse Bobodo
- ✅ `notifyListeners()` a été appelé
- ✅ `isLoading == false`

---

## MISSION 2 — RÉCUPÉRATION EXACTE DE LA DERNIÈRE RÉPONSE BOBODO

### Code exact de récupération

```dart
final provider = context.read<BobodoProvider>();
final messages = provider.messages;  // List<Map<String, dynamic>> (unmodifiable)
```

Après `await sendUserMessage(text)`, la liste `messages` contient tous les messages dans l'ordre chronologique (retournés par `app_list_bobodo_messages` RPC). Le dernier message est la réponse Bobodo.

### Logique d'extraction

```dart
if (messages.isNotEmpty) {
  final lastMsg = messages.last;
  final sender = lastMsg['sender']?.toString();
  final content = lastMsg['content']?.toString() ?? '';
}
```

### Garantie que c'est la réponse de l'instant T

**Preuve** : `loadMessages()` (ligne 121-123) fait :
```dart
_messages
  ..clear()                               // Vide la liste entière
  ..addAll(data.cast<Map<String, dynamic>>());  // Remplit avec TOUTES les données fraîches
```

Donc `_messages` est TOUJOURS le reflet exact de la base Supabase au moment du chargement. Le dernier élément est chronologiquement le dernier message inséré — c'est la réponse Bobodo qui vient d'être générée par l'Edge Function (`app_append_bobodo_message` avec `p_sender: 'assistant'` exécuté avant le retour HTTP).

### Vérification du sender

Le dernier message DEVRAIT être `sender == 'assistant'` car :
1. L'Edge Function insère d'abord le message étudiant (`p_sender: 'student'`)
2. Puis insère la réponse IA (`p_sender: 'assistant'`)
3. Puis retourne HTTP 200

Mais par sécurité, on vérifie `lastMsg['sender'] != 'student'` pour ne pas lire le texte de l'utilisateur.

### Code exact retenu

```dart
final messages = provider.messages;
if (messages.isNotEmpty && messages.last['sender'] != 'student') {
  final botText = messages.last['content']?.toString() ?? '';
  // botText = réponse Bobodo de l'instant T, garantie fraîche
}
```

---

## MISSION 3 — COMPORTEMENT EN CAS D'ERREUR

### Cas 1 : Bobodo retourne une erreur HTTP (status >= 400)

**Code** (`bobodo_provider.dart` lignes 223-237) :
```dart
if (finalResponse.statusCode >= 400) {
  backendOk = false;
  _lastFailedMessage = content;
  _setError(message);
}
```

**Conséquence** :
- `backendOk = false` → `loadMessages()` N'EST PAS appelé (ligne 246 : `if (backendOk)`)
- `_messages` garde l'état précédent (message étudiant ajouté localement, pas de réponse bot)
- `messages.last['sender'] == 'student'` → condition `!= 'student'` est `false`
- **TTS NON déclenché** ✅
- **Boucle NON relancée** ✅
- **Utilisateur bloqué ?** : L'état `_conversationState` reste sur `thinking`. L'erreur est affichée via `_buildErrorBar`. L'utilisateur peut quitter le mode conversation via le bouton "Quitter".

### Cas 2 : Bobodo retourne une réponse vide

L'Edge Function (`index.ts` ligne 1622) retourne toujours `{reply: "..."}`. Si le contenu est vide, il est stocké comme chaîne vide dans `bobodo_messages`.

**Conséquence** :
- `loadMessages()` recharge normalement
- `messages.last['content']` = `''`
- `botText.isNotEmpty` est `false`
- **TTS NON déclenché** ✅
- **Boucle NON relancée** ✅
- **Utilisateur bloqué ?** : Même situation — `_conversationState` reste sur `thinking`. L'utilisateur peut quitter.

### Cas 3 : Le réseau coupe

**Code** (`bobodo_provider.dart` lignes 238-241) :
```dart
} catch (e) {
  backendOk = false;
  _lastFailedMessage = content;
  _setError('Erreur lors de l\'appel Bobodo (Edge Function): $e');
}
```

**Conséquence** :
- Même logique que Cas 1 — `backendOk = false`, pas de `loadMessages()`
- **TTS NON déclenché** ✅
- **Boucle NON relancée** ✅
- **Utilisateur bloqué ?** : Erreur affichée + bouton Quitter disponible.

### Cas 4 : Le provider échoue (`loadMessages()` throw)

**Code** (`bobodo_provider.dart` lignes 126-130) :
```dart
} catch (e) {
  _setError(e.toString());
} finally {
  _setLoading(false);
}
```

**Conséquence** :
- `_messages` reste vide ou dans son état précédent (car `clear()` est dans le `try` avant l'erreur, donc si l'erreur est sur le `rpc`, les messages sont déjà vidés)
- `sendUserMessage()` retourne normalement (pas de rethrow)
- `messages.last` pourrait être le message étudiant ajouté localement
- Condition `messages.last['sender'] != 'student'` → `false`
- **TTS NON déclenché** ✅
- **Boucle NON relancée** ✅

### Résumé des cas d'erreur

| Scénario | TTS déclenché | Boucle relancée | Utilisateur bloqué |
|----------|:---:|:---:|:---:|
| Erreur HTTP | ❌ | ❌ | Non (bouton Quitter + erreur affichée) |
| Réponse vide | ❌ | ❌ | Non (bouton Quitter) |
| Réseau coupé | ❌ | ❌ | Non (bouton Quitter + erreur affichée) |
| Provider échoue | ❌ | ❌ | Non (bouton Quitter + erreur affichée) |

**Aucun cas d'erreur ne déclenche le TTS ni ne relance la boucle. L'utilisateur n'est jamais bloqué grâce au bouton Quitter toujours visible.**

---

## MISSION 4 — DIAGRAMME SÉQUENTIEL COMPLET

```
┌──────────┐    ┌────────────┐    ┌──────────────┐    ┌──────────┐    ┌────────────┐
│Utilisateur│    │  STT Natif │    │  Provider    │    │Edge Func │    │ FlutterTts │
└─────┬─────┘    └──────┬─────┘    └──────┬───────┘    └─────┬────┘    └──────┬─────┘
      │                  │                  │                  │                 │
      │ Parle            │                  │                  │                 │
      │─────────────────>│                  │                  │                 │
      │                  │                  │                  │                 │
      │                  │ onResult(final)  │                  │                 │
      │                  │─────────────────>│                  │                 │
      │                  │ _handleSpeechResult()               │                 │
      │                  │ _onTranscriptionReceived(text)       │                 │
      │                  │                  │                  │                 │
      │                  │     setState(thinking)               │                 │
      │                  │                  │                  │                 │
      │                  │  await sendUserMessage(text)         │                 │
      │                  │                  │─────────────────>│                 │
      │                  │                  │  POST /bobodo-chat                 │
      │                  │                  │                  │                 │
      │                  │                  │  HTTP 200 {reply}│                 │
      │                  │                  │<─────────────────│                 │
      │                  │                  │                  │                 │
      │                  │  await loadMessages()                │                 │
      │                  │  _messages = [... réponse bot]       │                 │
      │                  │  notifyListeners()                   │                 │
      │                  │                  │                  │                 │
      │                  │  ← sendUserMessage() retourne        │                 │
      │                  │                  │                  │                 │
      │                  │  Extraire messages.last['content']   │                 │
      │                  │  Vérifier sender != 'student'        │                 │
      │                  │  Vérifier botText.isNotEmpty         │                 │
      │                  │                  │                  │                 │
      │                  │     setState(playing)                │                 │
      │                  │                  │                  │                 │
      │                  │  await _speakWithLocalTts(botText)   │                 │
      │                  │                  │                  │────────────────>│
      │                  │                  │                  │   speak(text)   │
      │  ◄── Entend ─── │                  │                  │                 │
      │     la voix      │                  │                  │                 │
      │                  │                  │                  │ awaitCompletion │
      │                  │                  │                  │<────────────────│
      │                  │                  │                  │                 │
      │                  │     setState(_isSpeaking = false)    │                 │
      │                  │                  │                  │                 │
      │                  │  _onAudioPlaybackComplete()          │                 │
      │                  │     setState(listening)              │                 │
      │                  │     _startVocalRecording()           │                 │
      │                  │                  │                  │                 │
      │                  │<─────────────────│                  │                 │
      │                  │ _speechToText.listen()               │                 │
      │                  │                  │                  │                 │
      │ Parle à nouveau  │                  │                  │                 │
      │─────────────────>│                  │                  │                 │
      │                  │                  │                  │                 │
      │            ══════ BOUCLE RECOMMENCE ══════              │                 │
```

---

## MISSION 5 — PATCH EXACT

### Fichier

`lib/features/student/tabs/student_bobodo_tab.dart`

### Méthode

`_onTranscriptionReceived()`

### Signature à modifier

**Ligne 1379 actuelle** :
```dart
  void _onTranscriptionReceived(String text) {
```

**Remplacer par** :
```dart
  Future<void> _onTranscriptionReceived(String text) async {
```

### Corps à modifier

**Lignes 1389-1399 actuelles** :
```dart
      // Mode conversation : envoi automatique
      setState(() {
        _isTranscribing = false;
        _conversationState = ConversationState.thinking;
      });

      // Ajouter à la mémoire
      _addToConversationMemory(text, '');

      final provider = context.read<BobodoProvider>();
      provider.sendUserMessage(text);
```

**Remplacer par** :
```dart
      // Mode conversation : envoi automatique
      setState(() {
        _isTranscribing = false;
        _conversationState = ConversationState.thinking;
      });

      // Ajouter à la mémoire
      _addToConversationMemory(text, '');

      final provider = context.read<BobodoProvider>();
      await provider.sendUserMessage(text);

      // Mode 2 : lecture vocale de la réponse Bobodo
      if (_isConversationMode && provider.messages.isNotEmpty) {
        final lastMsg = provider.messages.last;
        if (lastMsg['sender'] != 'student') {
          final botText = lastMsg['content']?.toString() ?? '';
          if (botText.isNotEmpty) {
            setState(() {
              _conversationState = ConversationState.playing;
            });
            await _speakWithLocalTts(botText);
          }
        }
      }
```

### Diff complet

```diff
--- a/lib/features/student/tabs/student_bobodo_tab.dart
+++ b/lib/features/student/tabs/student_bobodo_tab.dart
@@ -1376,7 +1376,7 @@
   }
 
-  void _onTranscriptionReceived(String text) {
+  Future<void> _onTranscriptionReceived(String text) async {
     if (_isConversationMode) {
       // Barge-in: si Bobodo parle, arrêter la lecture
       if (_isSpeaking) {
@@ -1396,7 +1396,19 @@
       _addToConversationMemory(text, '');
 
       final provider = context.read<BobodoProvider>();
-      provider.sendUserMessage(text);
+      await provider.sendUserMessage(text);
+
+      // Mode 2 : lecture vocale de la réponse Bobodo
+      if (_isConversationMode && provider.messages.isNotEmpty) {
+        final lastMsg = provider.messages.last;
+        if (lastMsg['sender'] != 'student') {
+          final botText = lastMsg['content']?.toString() ?? '';
+          if (botText.isNotEmpty) {
+            setState(() {
+              _conversationState = ConversationState.playing;
+            });
+            await _speakWithLocalTts(botText);
+          }
+        }
+      }
     } else {
       // Mode dictée : affichage dans champ
       setState(() {
```

### Vérification de l'appelant

`_handleSpeechResult()` (ligne 1319) appelle `_onTranscriptionReceived(text)` :
```dart
void _handleSpeechResult(String text) {
  if (text.trim().isEmpty) return;
  debugPrint('[SPEECH_RESULT] $text');
  _stopVocalRecording();
  _onTranscriptionReceived(text);  // ← Appel sans await — fire-and-forget
}
```

Cet appel sans `await` est **correct et voulu** : le callback STT (`onResult`) ne gère pas de retour. La méthode `_onTranscriptionReceived()` s'exécute de manière asynchrone en arrière-plan. Aucun problème — le pattern fire-and-forget est standard pour les callbacks d'événements.

`_onVocalMessage()` (ligne 1369) appelle aussi `_onTranscriptionReceived()` :
```dart
if (type == 'transcription') {
  final text = message['text'] as String?;
  _onTranscriptionReceived(text ?? '');  // ← Aussi fire-and-forget — OK
}
```

Même pattern — aucun changement nécessaire sur les appelants.

### Résumé des modifications

| Élément | Avant | Après |
|---------|-------|-------|
| Signature `_onTranscriptionReceived` | `void` | `Future<void> async` |
| `provider.sendUserMessage(text)` | Fire-and-forget | `await` |
| Après sendUserMessage | Rien | Extraction réponse + setState(playing) + await _speakWithLocalTts |
| Lignes ajoutées | — | **11** |
| Lignes modifiées | — | **2** (signature + await) |
| Total lignes impactées | — | **13** |
| Fichiers impactés | — | **1** |

---

**Aucune implémentation effectuée. Aucune modification. Aucun commit.**

*En attente de validation du patch exact.*
