# BOBODO — Audit UX Complémentaire V4

**Date**: 2025-06-15  
**Méthode**: Code Flutter + comportements observés sur téléphone réel

---

## POINT 1 — CARTOGRAPHIE DU CYCLE DE CONFIANCE

### Cycle complet avec état visible actuel vs attendu

| # | Étape | Visible AUJOURD'HUI | Ce qui MANQUE | Ce qui DEVRAIT être visible |
|---|-------|--------------------|--------------|-----------------------------|
| 1 | **Écoute** | Texte statique "Parlez maintenant" | Animation, feedback audio | Animation pulsante + texte partiel reconnu |
| 2 | **Voix détectée** | Rien ne change | Tout changement | Waveform ou pulsation ou changement de couleur |
| 3 | **Fin de parole** | Passe direct à "Bobodo réfléchit..." | Texte transcrit visible | "Vous avez dit : [texte]" pendant 1-2s |
| 4 | **Message reçu** | Bulle utilisateur dans le chat | Accusé de réception explicite | Bulle utilisateur suffit (OK) |
| 5 | **Envoi vers Bobodo** | "Bobodo réfléchit..." + typing indicator | Rien de plus nécessaire | OK tel quel |
| 6 | **Réflexion** | "Bobodo réfléchit..." + shimmer 3 points | Rien de plus | OK tel quel |
| 7 | **Réponse** | "Bobodo parle..." + voix TTS + bulle bot | Rien de plus | OK tel quel |
| 8 | **Reprise** | "Parlez maintenant" réapparaît silencieusement | Signal de reprise | Vibration + "Parlez maintenant" |

### Diagnostic

Le cycle est **cassé en confiance** aux étapes 1, 2 et 3 :
- L'utilisateur parle dans le vide sans aucun retour
- Il ne sait pas si sa voix est captée
- Il ne voit jamais sa transcription avant envoi

---

## POINT 2 — TRANSCRIPTION DANS LE CODE

### La transcription existe-t-elle ?

**OUI** — elle est disponible dans `_lastRecognizedWords` (ligne 85).

### À quel moment exact ?

Le callback `onResult` du STT natif (ligne 1306-1311) :

```dart
onResult: (result) {
  _lastRecognizedWords = result.recognizedWords;  // ← texte partiel disponible ICI
  if (result.finalResult) {
    _handleSpeechResult(_lastRecognizedWords);   // ← texte final disponible ICI
  }
},
```

**Précision** : `partialResults: true` (ligne 1317) signifie que `_lastRecognizedWords` est mis à jour EN TEMPS RÉEL pendant que l'utilisateur parle. Chaque mot reconnu est disponible immédiatement.

### Peut-on l'afficher immédiatement ?

**OUI** — Il suffit d'ajouter un `setState()` dans le callback `onResult` pour mettre à jour l'UI avec le texte partiel :

```dart
onResult: (result) {
  setState(() {
    _lastRecognizedWords = result.recognizedWords;
  });
  if (result.finalResult) {
    _handleSpeechResult(_lastRecognizedWords);
  }
},
```

Puis dans `_buildConversationStateIndicator()`, afficher `_lastRecognizedWords` quand l'état est `listening` et que le texte n'est pas vide.

### Combien de lignes nécessaires ?

| Modification | Lignes |
|-------------|--------|
| Ajouter `setState` dans `onResult` | 2 modifiées |
| Afficher `_lastRecognizedWords` dans l'indicateur d'état quand listening | ~5 ajoutées |
| **Total** | **~7 lignes** |

---

## POINT 3 — AUDIT DES ÉTATS CONVERSATIONNELS

### Code source : `_buildConversationStateIndicator()` lignes 1678-1742

| État | Texte | Icône | Couleur | Quand | Durée | Compréhension utilisateur |
|------|-------|-------|---------|-------|-------|--------------------------|
| `idle` | "En attente" | `Icons.hourglass_empty` | Gris tertiaire | Après 30s d'inactivité (ligne 1646-1651) | Indéfini | ❌ **Incompréhensible** — l'utilisateur ne sait pas quoi faire |
| `listening` | "Parlez maintenant" | `Icons.mic` | Bleu primary | Activation + après chaque TTS (lignes 1594, 1637) | Jusqu'à 30s ou fin de parole | ⚠️ **Partiel** — indique quoi faire mais aucun feedback de captation |
| `processing` | "Traitement..." | `Icons.settings` | Accent | **Jamais utilisé dans le flux actuel** | — | — Non atteint |
| `thinking` | "Bobodo réfléchit..." | `Icons.psychology` | Bleu primary | Après transcription (ligne 1414) | 3-15s | ✅ Compréhensible |
| `responding` | "Réponse..." | `Icons.chat` | Bleu primary | **Jamais utilisé dans le flux actuel** | — | — Non atteint |
| `playing` | "Bobodo parle..." | `Icons.volume_up` | Bleu primary | Quand TTS démarre (ligne 1430) | Durée TTS | ✅ Compréhensible |
| `paused` | "Pause" | `Icons.pause` | Accent | Quand utilisateur coupe (ligne 1622) | Indéfini | ⚠️ Pas d'instruction pour reprendre |
| `ended` | "Session terminée" | `Icons.check_circle` | Vert success | Quand quitte (ligne 1612) | Fugitif (mode se désactive) | ✅ OK |

### Problèmes identifiés

1. **`idle` est un état piège** : L'utilisateur y arrive après 30s de silence. Aucun bouton "Reparler" n'existe. Il doit quitter et réactiver.
2. **`processing` et `responding` ne sont jamais atteints** : Ces états existent dans l'enum mais ne sont jamais utilisés dans le flux Mode 2. Code mort.
3. **`listening` ne change pas visuellement quand l'utilisateur parle** : Le texte reste "Parlez maintenant" que l'utilisateur parle ou non.

---

## POINT 4 — DUPLICATION DES MESSAGES

### Diagnostic

Le problème de duplication vient du flux de `sendUserMessage()` dans `bobodo_provider.dart`.

**Séquence des événements quand `_currentSessionId != null`** :

```
1. sendUserMessage(text) appelé
2. sessionId != null → branche ELSE (ligne 163)
3. await loadMessages()       ← PREMIER CHARGEMENT (ligne 167)
   → _messages = [tous les messages Supabase]
   → notifyListeners()       ← UI REBUILD #1
4. _messages.add({sender:'student', content:text})  ← AJOUT LOCAL (ligne 181)
   → notifyListeners()       ← UI REBUILD #2 (message étudiant visible)
5. await _callEdgeFunction(text)
6. Edge Function:
   → app_append_bobodo_message(student) ← INSERT SUPABASE #1 (message étudiant)
   → ... génère réponse ...
   → app_append_bobodo_message(assistant) ← INSERT SUPABASE #2 (réponse bot)
7. Si backendOk:
   → await loadMessages()    ← DEUXIÈME CHARGEMENT (ligne 248)
   → _messages.clear() + addAll(data from Supabase)
   → notifyListeners()       ← UI REBUILD #3
```

### Source de la duplication

**Le `loadMessages()` à l'étape 3 (ligne 167) recharge TOUS les messages existants.** Puis à l'étape 4, un message local est ajouté. Ce message local a `id: null` et un `created_at` différent de celui en base.

Ensuite à l'étape 7, `loadMessages()` recharge tout depuis Supabase. À ce moment, `_messages.clear()` supprime le local ET charge les vrais messages Supabase (y compris le message étudiant inséré par l'Edge Function à l'étape 6).

**EN THÉORIE** : Pas de duplication finale (le `clear()` à l'étape 7 nettoie).

**EN PRATIQUE — SCÉNARIO DE DUPLICATION** :

Le problème survient quand **l'étape 3 (`loadMessages()` de validation de session) retrouve le message étudiant d'un échange précédent IDENTIQUE**. Si l'utilisateur dit la même chose deux fois (ou si la boucle vocale relance un envoi avant que le premier ne soit complété), on obtient :

1. `loadMessages()` charge les messages existants (incluant les échanges précédents)
2. Ajout local du nouveau message
3. Edge Function insère le message → Supabase a le message
4. `loadMessages()` recharge → tout est correct

**LE VRAI BUG** : Le `loadMessages()` de la ligne 167 (validation de session) est **inutile et coûteux**. Il provoque un rebuild UI avec l'ancien état des messages, puis un ajout local immédiat qui provoque un second rebuild. En mode conversation vocale rapide, si deux `_onTranscriptionReceived()` s'exécutent en chevauchement (ce qui est possible car le `await` peut être interrompu par un barge-in), les `loadMessages()` multiples peuvent produire des états intermédiaires incohérents.

**Scénario de duplication confirmé** :
```
T0: Premier message vocal envoyé → sendUserMessage("bonjour")
    → loadMessages() charge état vide → add local → Edge Function → loadMessages() → OK
    
T1: Deuxième message vocal envoyé → sendUserMessage("comment ça va")
    → loadMessages() charge ["bonjour", réponse_bot]  ← messages existants
    → add local {"comment ça va"}
    → _messages = ["bonjour", réponse_bot, "comment ça va"]
    → Edge Function insère "comment ça va" dans Supabase
    → loadMessages() recharge TOUT depuis Supabase
    → _messages = ["bonjour", réponse_bot, "comment ça va", réponse_bot2]
    → OK — pas de duplication dans l'état final
```

**MAIS** : Si l'Edge Function prend du temps et que le `loadMessages()` de l'étape 3 du TROISIÈME message se lance pendant que le deuxième est en cours, on peut voir des états intermédiaires avec des messages en double dans l'UI.

### Verdict duplication

- **Cause** : Le `loadMessages()` de validation (ligne 167) combiné avec l'ajout local (ligne 181) crée des rebuilds intermédiaires qui peuvent montrer brièvement des doublons
- **Gravité** : Majeur en mode conversation vocale (échanges rapides)
- **Correction** : Supprimer le `loadMessages()` de validation (ligne 167) OU ne pas faire d'ajout local en mode conversation

---

## POINT 5 — ERREUR "Enregistrement du message étudiant"

### Cause exacte

**Fichier** : `supabase/functions/bobodo-chat/index.ts` ligne 1450-1461

```typescript
const { error: appendStudentError } = await supabaseForUser.rpc('app_append_bobodo_message', {
  p_session_id: sessionId,
  p_sender: 'student',
  p_content: message,
  p_safety_flag: null,
});
if (appendStudentError) {
  return new Response(JSON.stringify({ error: 'Erreur lors de lenregistrement du message étudiant.' }), {
    status: 500,
  });
}
```

### Flux concerné

```
Flutter → sendUserMessage() → _callEdgeFunction() → HTTP POST /bobodo-chat
  → Edge Function → supabaseForUser.rpc('app_append_bobodo_message')
  → RPC échoue → HTTP 500 → Flutter reçoit erreur
  → backendOk = false → _setError(message) → barre rouge visible
```

### Causes possibles de l'échec RPC

1. **Session invalide** : Le `session_id` envoyé n'existe plus en base (session supprimée, expirée, ou corrigée)
2. **RLS (Row Level Security)** : L'utilisateur authentifié n'a pas le droit d'écrire dans cette session
3. **JWT expiré** : Le token d'authentification Supabase est expiré
4. **Conflit de session** : Le `session_id` dans SharedPreferences est obsolète

### Niveau de gravité

**ÉLEVÉ** — Cette erreur bloque complètement l'envoi de message. En mode conversation vocale, le flux est interrompu. La gestion d'erreur dans `_onTranscriptionReceived()` relance l'écoute (lignes 1444-1452), mais le message est perdu.

### Impact sur le mode conversation vocale

**OUI, directement impacté** :
1. Utilisateur parle → transcription → `sendUserMessage()` → erreur 500
2. `backendOk = false` → `loadMessages()` non appelé
3. `provider.messages.last['sender']` = toujours 'student' (le local ajouté à ligne 181)
4. Le flux retombe dans la branche "erreur backend" (ligne 1443-1452)
5. L'écoute est relancée → l'utilisateur peut reparler
6. **MAIS** : le message est perdu sans notification claire à l'utilisateur

---

## POINT 6 — BOUTON D'ACTIVATION — COMPARAISON UX

### Comparaison avec les standards du marché

| App | Bouton vocal | Taille | Position | Comportement |
|-----|-------------|--------|----------|-------------|
| **ChatGPT Voice** | Cercle avec waveform, PLEIN ÉCRAN | ~60px puis fullscreen | Centre bas, puis prend tout l'écran | Tap → écran dédié avec animation waveform géante |
| **Gemini Live** | Bouton "Parler à Gemini" avec texte | ~50px + label | Centre bas | Tap → interface dédiée avec instructions |
| **WhatsApp vocal** | Micro à droite du champ | ~40px | Input bar, droite | Hold → enregistre, release → envoie |
| **Telegram vocal** | Micro à droite du champ | ~40px | Input bar, droite | Hold → enregistre, swipe → lock |
| **Bobodo (actuel)** | `Icons.record_voice_over` | **20px** | Header, noyé parmi 4 boutons | Tap → change l'interface in-place |

### Pourquoi un étudiant ne comprend pas

1. **Taille** : 20px vs 50-60px chez les concurrents. Le bouton est trop petit.
2. **Position** : Dans le header (zone de navigation), pas dans la zone d'action (input). Les apps vocales mettent toujours le bouton vocal dans la zone d'interaction principale.
3. **Absence de label** : ChatGPT et Gemini ont un texte visible ("Parler à..."). Bobodo n'a qu'un tooltip au long press.
4. **Pas d'écran dédié** : ChatGPT Voice et Gemini Live passent en plein écran. Bobodo reste dans le même écran avec des modifications subtiles.
5. **Même contexte visuel** : Le header bleu reste identique. L'utilisateur ne perçoit pas le changement de mode.

### Alternatives Flutter simples

| Alternative | Description | Complexité |
|-------------|-------------|-----------|
| **A. Bouton FAB (Floating Action Button)** | Un FAB avec micro en bas à droite, visible en permanence, distinct de l'input bar | ~20 lignes |
| **B. Bouton intégré à l'input bar** | Un bouton "🎤 Conversation" à côté du micro dictée, plus grand avec label | ~10 lignes |
| **C. Bottom sheet dédié** | Tap sur le micro → bottom sheet qui monte avec interface conversation dédiée | ~50 lignes |
| **D. Agrandir et labelliser le bouton header actuel** | Badge "CONV" ou indicateur permanent sous le bouton | ~8 lignes |

---

## RÉCAPITULATIF

### Défauts BLOQUANTS (empêchent l'utilisation)

| # | Défaut | Cause code |
|---|--------|-----------|
| B1 | Aucun feedback visuel pendant l'écoute | `_lastRecognizedWords` jamais affiché (ligne 1307 : pas de setState) |
| B2 | Transcription jamais montrée à l'utilisateur | `_lastRecognizedWords` disponible mais non rendu dans l'UI |
| B3 | Pas de signal de reprise (silencieux) | `_onAudioPlaybackComplete()` ligne 1637 ne produit aucun feedback sensoriel |

### Défauts FONCTIONNELS BLOQUANTS

| # | Défaut | Cause code |
|---|--------|-----------|
| F1 | Duplication de messages en mode conversation rapide | `loadMessages()` ligne 167 avant ajout local (ligne 181) crée des états intermédiaires |
| F2 | Erreur "enregistrement message étudiant" perd le message | Edge Function RPC échoue (session invalide ou JWT expiré) |

### Défauts VISUELS

| # | Défaut | Cause |
|---|--------|-------|
| V1 | Bouton activation trop petit (20px) et non identifiable | `size: 20` ligne 430, noyé dans le header |
| V2 | État "idle" sans instruction ni action possible | Ligne 1687 : texte "En attente" sans explication |
| V3 | États `processing` et `responding` jamais utilisés | Code mort dans l'enum, lignes 1696-1710 |

---

## RECOMMANDATIONS CLASSÉES

### P0 — Critiques (résoudre avant mise en production)

| # | Action | Fichier | Lignes estimées |
|---|--------|---------|-----------------|
| P0-1 | Afficher `_lastRecognizedWords` en temps réel dans l'indicateur d'état pendant listening | `student_bobodo_tab.dart` | ~7 |
| P0-2 | Ajouter vibration (`HapticFeedback.mediumImpact()`) à la reprise d'écoute | `student_bobodo_tab.dart` | ~2 |
| P0-3 | Supprimer le `loadMessages()` de validation (ligne 167) pour éviter doublons | `bobodo_provider.dart` | ~3 (suppr) |

### P1 — Majeurs (résoudre rapidement)

| # | Action | Fichier | Lignes estimées |
|---|--------|---------|-----------------|
| P1-1 | Ajouter un bouton "Envoyer" dans les contrôles conversation (arrête écoute + envoie immédiatement) | `student_bobodo_tab.dart` | ~8 |
| P1-2 | Ajouter un bouton "Reparler" quand état idle | `student_bobodo_tab.dart` | ~6 |
| P1-3 | Améliorer le bandeau : ajouter instruction "Parlez naturellement, Bobodo comprend quand vous avez fini" | `student_bobodo_tab.dart` | ~2 |
| P1-4 | Augmenter taille et distinction du bouton header (24px + badge ou couleur distinctive au repos) | `student_bobodo_tab.dart` | ~5 |

### P2 — Améliorations (à planifier)

| # | Action | Fichier | Lignes estimées |
|---|--------|---------|-----------------|
| P2-1 | Animation pulsante sur l'icône mic dans l'indicateur pendant listening | `student_bobodo_tab.dart` | ~15 |
| P2-2 | Bottom sheet ou écran dédié pour le mode conversation (style ChatGPT Voice) | `student_bobodo_tab.dart` | ~80+ |
| P2-3 | Supprimer les états `processing` et `responding` non utilisés | `student_bobodo_tab.dart` | ~10 (suppr) |

---

## ESTIMATION TOTALE

| Phase | Lignes | Risque régression |
|-------|--------|-------------------|
| P0 | ~12 | Faible (P0-3 modifie le provider) |
| P1 | ~21 | Nul (ajouts visuels) |
| P2 | ~105+ | Moyen (si écran dédié) |

**Aucune modification effectuée. Aucun commit. Audit uniquement.**

---

*Fin du rapport V4.*
