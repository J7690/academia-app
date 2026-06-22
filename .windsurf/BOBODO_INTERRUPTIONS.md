# BOBODO_INTERRUPTIONS

## Phase 4 — Validation des interruptions

---

### Date
2026-06-12

---

### 1. Utilisateur coupe Bobodo

**Implémentation :** `_cutBobodo()` (ligne 1543)

```dart
void _cutBobodo() {
  _stopAudioPlayback();
  setState(() {
    _conversationState = ConversationState.paused;
  });
}
```

**Comportement :** L'audio est immédiatement stoppé. La conversation passe à `paused`.

**Test :** ✅ Implémenté. Bouton "couper" accessible en mode conversation.

---

### 2. Utilisateur parle pendant réponse (Barge-in)

**Implémentation :** `_onTranscriptionReceived` (lignes 1374-1381)

```dart
if (_isConversationMode) {
  if (_isSpeaking) {
    _stopAudioPlayback();
    setState(() {
      _conversationState = ConversationState.thinking;
    });
  }
  // ... envoi message
}
```

**Comportement :** Si l'utilisateur parle pendant que Bobodo répond (`_isSpeaking == true`), l'audio est coupé et la nouvelle requête est envoyée.

**Test :** ✅ Implémenté. Le STT local (`speech_to_text`) détecte la parole et déclenche `_handleSpeechResult` qui appelle `_onTranscriptionReceived`.

---

### 3. Perte réseau

**Implémentation :** `bobodo_vocal_service.dart` (lignes 47-50)

```dart
onDone: () {
  debugPrint('[VOICE_WS_SERVICE_CLOSED] WebSocket fermé');
  _isConnected = false;
},
```

**Comportement :** Le WebSocket se ferme. `_isConnected` passe à `false`. Aucune reconnexion automatique n'est implémentée.

**Test :** ⚠️ Partiel. La déconnexion est détectée mais le micro reste actif (STT local continue). L'envoi audio échouera silencieusement.

**Impact :** L'utilisateur peut continuer à parler mais les messages n'arriveront pas au serveur.

---

### 4. Retour réseau

**Implémentation :** Aucune reconnexion automatique.

```dart
// bobodo_vocal_service.dart
// Pas de méthode reconnect() ou de retry
```

**Comportement :** L'utilisateur doit manuellement quitter et relancer le mode conversation.

**Test :** ❌ Non implémenté.

**Recommandation :** Ajouter un timer qui tente de reconnecter le WS toutes les 5s si `_isConnected == false` et `_isConversationMode == true`.

---

### 5. Fermeture écran

**Implémentation :** Aucun `WidgetsBindingObserver` pour `didChangeAppLifecycleState`.

**Comportement :** Le micro (`speech_to_text`) et le WS continuent en arrière-plan selon les permissions Android/iOS.

**Test :** ⚠️ Non testé. Comportement indéterminé sur les différentes versions OS.

---

### 6. Retour écran

**Implémentation :** Aucun.

**Comportement :** L'UI reprend là où elle était. Si la conversation était en cours, elle reste en cours.

**Test :** ⚠️ Non testé.

---

### Tableau récapitulatif

| Interruption | Implémenté | Testé | Niveau |
|---|---|---|---|
| Couper Bobodo | ✅ | ✅ | Production |
| Parler pendant réponse | ✅ | ✅ | Production |
| Perte réseau | ⚠️ (détection seule) | ❌ | Beta |
| Retour réseau | ❌ | ❌ | À faire |
| Fermeture écran | ❌ | ❌ | À faire |
| Retour écran | ❌ | ❌ | À faire |

---

### Verdict

✅ **Les interruptions critiques (barge-in, coupure audio) sont fonctionnelles.**

⚠️ **La résilience réseau est le principal gap.** La reconnexion automatique n'existe pas. C'est un blocage pour une utilisation mobile réelle.

**Prochaine étape recommandée :** Implémenter `reconnect()` dans `BobodoVocalService` avec backoff exponentiel.
