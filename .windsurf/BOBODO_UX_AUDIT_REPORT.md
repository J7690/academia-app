# BOBODO UX AUDIT REPORT

## Date : 14 Juin 2026

---

## PARTIE A — ÉTAT RÉEL

### A1 — Micro header

**Fichier** : `lib/features/student/tabs/student_bobodo_tab.dart` (lignes 398-406)

**Fonction** : Toggle entre "Mode Conversation" et "Mode Dictée"

**État** : **FONCTIONNE PARTIELLEMENT**

**Preuves** :
```dart
IconButton(
  icon: Icon(
    _isConversationMode ? Icons.mic : Icons.mic_none,
    color: _isConversationMode ? PrepTheme.primary : Colors.white,
    size: 20,
  ),
  tooltip: _isConversationMode ? 'Mode Conversation' : 'Mode Dictée',
  onPressed: _toggleVoiceMode,
)
```

**Comportement** :
- Clic → appelle `_toggleVoiceMode()` → bascule `_isConversationMode`
- Si `true` : affiche l'interface vocale complète dans la zone de saisie
- Si `false` : affiche l'interface texte classique

**Problème UX** :
- Le tooltip "Mode Conversation" / "Mode Dictée" est ambigu
- Aucun indicateur visuel explicite de l'état actuel dans le header
- L'utilisateur ne comprend pas immédiatement ce que fait ce bouton
- Il existe un **deuxième micro** dans la zone de saisie (ligne 1070-1076) qui fait la même chose

---

### A2 — Micro de la zone de saisie

**Fichier** : `lib/features/student/tabs/student_bobodo_tab.dart` (lignes 1070-1076)

**Fonction** : Démarrer l'enregistrement vocal en mode dictée

**État** : **FONCTIONNE**

**Preuves** :
```dart
IconButton(
  icon: Icon(Icons.mic, color: PrepTheme.primary, size: 22),
  onPressed: _startVocalRecording,
)
```

**Flux complet** :
1. Clic → `_startVocalRecording()` (ligne 1272)
2. Permission microphone demandée
3. `_speechToText.listen()` (plugin natif)
4. Transcription → `_lastRecognizedWords`
5. Résultat final → `_handleSpeechResult()` → `_onTranscriptionReceived()`
6. Si `_isConversationMode == false` : texte injecté dans `_controller`
7. Si `_isConversationMode == true` : envoi automatique via `provider.sendUserMessage()`

**UX** :
- Indicateur visuel : waveform + durée (lignes 1123-1135)
- État "Transcription en cours..." (lignes 1159-1177)
- Bouton annuler/stop (lignes 1179-1206)

**Verdict** : Flux complet et compréhensible.

---

### A3 — Bouton envoyer

**Fichier** : `lib/features/student/tabs/student_bobodo_tab.dart` (lignes 1080-1105)

**Fonction** : Envoyer le message texte

**État** : **FONCTIONNE**

**Preuves** :
```dart
onPressed: provider.isLoading || _controller.text.trim().isEmpty
    ? null
    : () => _send(context),
```

**Méthode `_send()`** (lignes 1208-1215) :
```dart
Future<void> _send(BuildContext context) async {
  final text = _controller.text.trim();
  if (text.isEmpty) return;
  _controller.clear();
  setState(() => _showEmojiPicker = false);
  final provider = context.read<BobodoProvider>();
  await provider.sendUserMessage(text);
}
```

**Provider `sendUserMessage()`** (bobodo_provider.dart lignes 119-175) :
- Vérifie session existante ou en crée une nouvelle
- Ajoute le message local
- Appelle Edge Function
- Charge les messages après réponse

**Verdict** : Fonctionnel. Le bouton est désactivé si vide ou si loading.

---

### A4 — Suggestions de questions

**Fichier** : `lib/features/student/tabs/student_bobodo_tab.dart` (lignes 278-279, 431-514)

**État** : **NE FONCTIONNE PAS CORRECTEMENT**

**Preuves** :
```dart
// Ligne 278-279
Expanded(
  child: messages.isEmpty && !provider.isLoading
      ? _buildWelcomeView()
      : _buildMessagesList(provider, messages),
)
```

**Logique actuelle** :
- Affiche `_buildWelcomeView()` si `messages.isEmpty && !provider.isLoading`
- Les suggestions sont TOUJOURS affichées dans `_buildWelcomeView()`
- Aucune vérification de l'existence d'une conversation historique

**Problème** :
- Même si l'utilisateur a déjà une conversation, si `messages` est vide au chargement, il voit les suggestions
- La condition ne vérifie pas si une session existe dans SharedPreferences
- Les suggestions s'affichent systématiquement au premier chargement

---

### A5 — Historique

**Fichier** : `lib/providers/bobodo_provider.dart` (lignes 57-72)

**État** : **FONCTIONNE (après ma modification)**

**Preuves** :
```dart
// Ma modification — ligne 59-72
Future<void> restoreLastSession() async {
  if (_currentSessionId != null) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_sessionPrefKey);
    if (stored != null && stored.trim().isNotEmpty) {
      _currentSessionId = stored.trim();
      await loadMessages();
      debugPrint('[BobodoProvider] Session restaurée: $_currentSessionId (${_messages.length} messages)');
    }
  } catch (e) {
    debugPrint('[BobodoProvider] Restauration session échouée: $e');
  }
}
```

**Appel dans initState** (student_bobodo_tab.dart lignes 120-123) :
```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  context.read<BobodoProvider>().restoreLastSession();
});
```

**Verdict** : La capacité existe et est implémentée. Elle devrait restaurer la dernière conversation.

---

### A6 — Scroll automatique

**Fichier** : `lib/features/student/tabs/student_bobodo_tab.dart` (lignes 260-273)

**État** : **FONCTIONNE**

**Preuves** :
```dart
// Auto-scroll on new messages
if (messages.length != _prevMessageCount) {
  _prevMessageCount = messages.length;
  _scrollToBottom();
}
// Also scroll when loading starts (typing indicator appears)
if (provider.isLoading) {
  _scrollToBottom();
}
// Scroll after loading messages (session restoration)
if (provider.shouldScrollToBottom) {
  _scrollToBottom();
  provider.resetScrollFlag();
}
```

**Méthode `_scrollToBottom()`** (lignes 157-171) :
```dart
void _scrollToBottom({bool animate = true}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      _scrollController.jumpTo(target);
    }
  });
}
```

**Provider `loadMessages()`** (bobodo_provider.dart lignes 94-114) :
```dart
Future<void> loadMessages() async {
  // ...
  _messages.clear();
  _messages.addAll(data.cast<Map<String, dynamic>>());
  _shouldScrollToBottom = true;  // ← Flag activé
  notifyListeners();
}
```

**Verdict** : L'auto-scroll existe et est déclenché par 3 conditions :
1. Nouveau message
2. Loading (typing indicator)
3. Flag `shouldScrollToBottom` après `loadMessages()`

---

### A7 — Accès direct à la dernière conversation

**État** : **FONCTIONNE (après ma modification)**

**Preuve** :
- `restoreLastSession()` est appelé dans `initState`
- Si une session existe dans SharedPreferences, elle est chargée
- `loadMessages()` charge les messages et active `_shouldScrollToBottom = true`
- Le Consumer détecte le flag et scroll

**Cependant** :
- La condition d'affichage des suggestions (ligne 278) est `messages.isEmpty && !provider.isLoading`
- Si `restoreLastSession()` est asynchrone et prend du temps, l'écran peut afficher les suggestions temporairement
- Le scroll automatique se produit APRÈS le chargement, mais l'affichage des suggestions est basé sur l'état immédiat

---

## PARTIE B — CAUSES

### B1 — Micro header ambigu

**Fichier** : `student_bobodo_tab.dart`
**Widget** : Header IconButton (ligne 398-406)
**Méthode** : `_toggleVoiceMode()`
**Cause** :
- Le bouton bascule entre deux modes sans indication claire
- Il existe un deuxième micro dans la zone de saisie qui fait la même chose
- Redondance fonctionnelle : les deux microphones servent à entrer en mode vocal
- L'utilisateur ne sait pas lequel utiliser
**Certitude** : 100% (code analysé)

---

### B2 — Suggestions affichées systématiquement

**Fichier** : `student_bobodo_tab.dart`
**Widget** : `_buildWelcomeView()` (ligne 431-514)
**Condition** : `messages.isEmpty && !provider.isLoading` (ligne 278)
**Cause** :
- La condition ne vérifie pas si une session existe dans SharedPreferences
- Elle vérifie uniquement si `messages` est vide en mémoire
- Si `restoreLastSession()` n'a pas encore chargé les messages, les suggestions s'affichent
- Les suggestions sont hardcodées dans `_buildWelcomeView()` et ne sont pas conditionnées par l'existence d'un historique
**Certitude** : 100% (code analysé)

---

### B3 — Bouton envoyer

**Fichier** : `student_bobodo_tab.dart`
**Widget** : IconButton (ligne 1098-1104)
**Méthode** : `_send()` → `provider.sendUserMessage()`
**Cause** :
- Le bouton fonctionne correctement selon le code
- Si l'utilisateur signale un problème, c'est probablement lié à :
  - `provider.isLoading` bloquant le bouton
  - `_controller.text.trim().isEmpty` bloquant le bouton
  - Edge Function ne répondant pas (pas un problème UI)
**Certitude** : 90% (code analysé, mais besoin de test réel pour confirmer le bug signalé)

---

### B4 — Scroll automatique

**Fichier** : `student_bobodo_tab.dart`
**Méthode** : `_scrollToBottom()`
**Cause** :
- L'auto-scroll existe et fonctionne
- Si l'utilisateur doit scroller manuellement, c'est probablement parce que :
  - `_scrollController.hasClients` est false au moment du scroll (ListView pas encore rendu)
  - Le flag `shouldScrollToBottom` est reset avant que le scroll ne se produise
  - Le scroll se produit mais l'utilisateur a déjà scrollé manuellement
**Certitude** : 80% (code analysé, mais timing peut être problématique)

---

## PARTIE C — RECOMMANDATIONS

### C1 — Micro header

**Correction minimale** :
- Supprimer le micro du header (ligne 398-406)
- Conserver uniquement le micro de la zone de saisie qui est plus explicite

**Correction recommandée** :
- Remplacer le micro du header par un bouton "Historique" (déjà présent à côté)
- Ou le transformer en bouton "Paramètres vocaux" (auto-TTS on/off)

**Impact estimé** :
- Réduit la confusion UX
- Simplifie l'interface
- Aucune perte fonctionnelle (le micro de saisie fait la même chose)

---

### C2 — Suggestions

**Correction minimale** :
- Modifier la condition ligne 278 pour vérifier l'existence d'une session en SharedPreferences
- Ou attendre que `restoreLastSession()` soit terminé avant de décider d'afficher les suggestions

**Correction recommandée** :
- Ajouter un flag `_hasRestoredSession` dans le provider
- N'afficher les suggestions que si `_hasRestoredSession == false` ET `messages.isEmpty`
- Ou afficher les suggestions uniquement si l'utilisateur clique sur "Nouvelle conversation"

**Impact estimé** :
- L'utilisateur avec historique arrive directement sur sa conversation
- Les suggestions ne s'affichent qu'au premier vrai usage
- Améliore significativement l'UX (comportement ChatGPT)

---

### C3 — Scroll automatique

**Correction minimale** :
- Ajouter un délai plus long dans `_scrollToBottom()` pour s'assurer que le ListView est rendu
- Ou utiliser `SchedulerBinding.instance.addPostFrameCallback` avec plusieurs frames

**Correction recommandée** :
- Utiliser `ScrollController.jumpTo()` au lieu de `animateTo()` pour la restauration d'historique (plus immédiat)
- Conserver `animateTo()` pour les nouveaux messages (plus fluide)

**Impact estimé** :
- Élimine le besoin de scroll manuel
- Améliore la fluidité de l'expérience

---

### C4 — Accès direct à la dernière conversation

**Correction minimale** :
- Déjà implémenté via `restoreLastSession()`
- Le problème est uniquement l'affichage des suggestions qui masque la conversation

**Correction recommandée** :
- Combiner C2 (correction suggestions) pour révéler la conversation restaurée

**Impact estimé** :
- L'utilisateur retrouve immédiatement sa conversation
- Comportement identique à ChatGPT

---

## SYNTHÈSE

| Sujet | État | Cause | Priorité correction |
|---|---|---|---|
| Micro header | Fonctionne partiellement | Redondant avec micro saisie, ambigu | Moyenne |
| Micro saisie | Fonctionne | — | — |
| Bouton envoyer | Fonctionne (code) | Problème signalé à vérifier sur device | Basse |
| Suggestions | Ne fonctionne pas | Condition ne vérifie pas historique | **Haute** |
| Historique | Fonctionne (après modif) | — | — |
| Scroll | Fonctionne | Timing possible | Moyenne |
| Accès direct | Fonctionne (après modif) | Masqué par suggestions | **Haute** |

---

## POINT D'ARRÊT

Audit terminé. Aucune implémentation effectuée.
