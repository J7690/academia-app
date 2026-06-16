# RAPPORT AUDIT AUTO-SCROLL BOBODO

**Date** : 9 juin 2026  
**Statut** : DIAGNOSTIC ÉTABLI

---

## 1. PROBLÈME CONSTATÉ

Lorsqu'un utilisateur revient dans Bobodo après plusieurs échanges, l'écran reste positionné en haut ou au milieu de l'historique. L'utilisateur doit faire défiler manuellement la conversation pour retrouver le dernier message et la zone de saisie.

---

## 2. AUDIT DU CODE

### Fichiers analysés

- `student_bobodo_tab.dart` (UI Bobodo)
- `bobodo_provider.dart` (Provider Bobodo)

### ScrollController existant

**Ligne 26** - `student_bobodo_tab.dart` :
```dart
final ScrollController _scrollController = ScrollController();
```

✅ Le ScrollController est correctement initialisé.

### Méthode _scrollToBottom()

**Lignes 48-62** - `student_bobodo_tab.dart` :
```dart
void _scrollToBottom({bool animate = true}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  });
}
```

✅ La méthode `_scrollToBottom()` est correctement implémentée avec `addPostFrameCallback`.

### Auto-scroll actuel

**Lignes 146-154** - `student_bobodo_tab.dart` :
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
```

---

## 3. CAUSE EXACTE DU PROBLÈME

### Problème 1 : Chargement initial des messages

**Dans `bobodo_provider.dart` - Lignes 87-106** :
```dart
Future<void> loadMessages() async {
  final sessionId = _currentSessionId;
  if (sessionId == null) return;
  _setLoading(true);
  _setError(null);
  try {
    final data = await _client.rpc(
      'app_list_bobodo_messages',
      params: {'p_session_id': sessionId},
    ) as List<dynamic>? ?? [];
    _messages
      ..clear()
      ..addAll(data.cast<Map<String, dynamic>>());
    notifyListeners();
  } catch (e) {
    _setError(e.toString());
  } finally {
    _setLoading(false);
  }
}
```

**Problème** : `loadMessages()` charge les messages mais ne déclenche PAS de scroll après le chargement.

### Problème 2 : Restauration de session

**Dans `bobodo_provider.dart` - Lignes 256-267** :
```dart
Future<void> switchToSession(String sessionId) async {
  _currentSessionId = sessionId;
  _messages.clear();
  _error = null;
  _lastFailedMessage = null;
  notifyListeners();
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionPrefKey, sessionId);
  } catch (_) {}
  await loadMessages();
}
```

**Problème** : `switchToSession()` appelle `loadMessages()` mais ne déclenche PAS de scroll après le chargement.

### Problème 3 : Auto-scroll dans build()

**Dans `student_bobodo_tab.dart` - Lignes 146-154** :
```dart
// Auto-scroll on new messages
if (messages.length != _prevMessageCount) {
  _prevMessageCount = messages.length;
  _scrollToBottom();
}
```

**Problème** : Ce code est dans le `build()`, ce qui signifie :
- Lors du chargement initial, `_prevMessageCount` est 0
- Les messages sont chargés asynchrone
- Le widget est reconstruit avec les nouveaux messages
- `_prevMessageCount` est mis à jour
- MAIS le scroll n'est PAS redéclenché car la condition `messages.length != _prevMessageCount` est fausse après la première reconstruction

### Problème 4 : Retour sur l'onglet Bobodo

Lorsqu'un utilisateur quitte l'onglet Bobodo et y revient :
- Le widget est reconstruit
- Les messages sont rechargés via `loadMessages()`
- MAIS aucun scroll automatique n'est déclenché

---

## 4. RÉSUMÉ DU DIAGNOSTIC

**Cause racine** : L'auto-scroll est implémenté pour les NOUVEAUX messages (envoyés en temps réel), mais PAS pour le chargement d'historique existant.

**Scénarios non couverts** :
1. Ouverture de Bobodo avec une session existante
2. Rechargement d'une session via l'historique
3. Retour sur l'onglet Bobodo après navigation
4. Restauration de session depuis SharedPreferences

---

## 5. SOLUTION PROPOSÉE

### Correction 1 : Scroll après loadMessages()

**Dans `bobodo_provider.dart`** :
Ajouter un callback ou un événement après `loadMessages()` pour permettre à l'UI de scroller.

### Correction 2 : Scroll après switchToSession()

**Dans `bobodo_provider.dart`** :
Ajouter un scroll automatique après le chargement des messages dans `switchToSession()`.

### Correction 3 : Scroll initial dans initState()

**Dans `student_bobodo_tab.dart`** :
Ajouter un scroll automatique dans `initState()` ou après le premier chargement des messages.

### Correction 4 : Utiliser WidgetsBindingObserver

**Dans `student_bobodo_tab.dart`** :
Implémenter `WidgetsBindingObserver` pour détecter quand l'onglet redevient actif et scroller automatiquement.

---

## 6. RECOMMANDATION

**Approche recommandée** :
1. Ajouter un flag `_shouldScrollToBottom` dans `BobodoProvider`
2. Définir ce flag à `true` après `loadMessages()` et `switchToSession()`
3. Dans `student_bobodo_tab.dart`, vérifier ce flag et scroller si nécessaire
4. Réinitialiser le flag après le scroll

Cette approche est :
- ✅ Non intrusive
- ✅ Compatible avec l'architecture existante
- ✅ Facile à tester
- ✅ Ne casse pas l'auto-scroll existant pour les nouveaux messages

---

**RAPPORT TERMINÉ - DIAGNOSTIC ÉTABLI**
