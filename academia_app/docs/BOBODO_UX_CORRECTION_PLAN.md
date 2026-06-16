# BOBODO — Plan de Correction UX Flutter

**Date**: 2025-06-15  
**Statut**: En attente de validation avant implémentation  
**Périmètre**: `student_bobodo_tab.dart` uniquement

---

## MISSION 1 — BOUTON ENVOYER

### Cause racine

Le `Consumer<BobodoProvider>` ne se reconstruit pas quand l'utilisateur tape du texte. Le `TextEditingController` n'a pas de listener qui déclenche `setState()`. Le bouton envoi évalue `_controller.text.trim().isEmpty` à chaque build, mais n'est pas rebuild quand le texte change.

### Correction

**Fichier** : `student_bobodo_tab.dart`  
**Méthode** : `initState()` (ligne 118)  
**Action** : Ajouter un listener sur `_controller` qui déclenche un rebuild

**Code à ajouter dans `initState()`, après la ligne 131** :
```dart
_controller.addListener(() => setState(() {}));
```

**Impact** : Chaque caractère tapé déclenche un rebuild → la condition `_controller.text.trim().isEmpty` est réévaluée → le bouton envoi passe de `null` à actif dès qu'il y a du texte.

**Lignes modifiées** : 1 ligne ajoutée

---

## MISSION 2 — MODE VOCAL CONVERSATION (États visuels)

### Modifications de l'indicateur d'état

**Fichier** : `student_bobodo_tab.dart`  
**Méthode** : `_buildConversationStateIndicator()` (ligne 1648)

| État | Texte actuel | Texte proposé | Icône |
|------|-------------|---------------|-------|
| idle | "En attente" | "En attente" | `Icons.hourglass_empty` |
| listening | "Écoute..." | **"Parlez maintenant"** | `Icons.mic` |
| processing | "Traitement..." | "Traitement..." | `Icons.settings` |
| thinking | "Bobodo réfléchit..." | "Bobodo réfléchit..." | `Icons.psychology` |
| responding | "Réponse..." | "Réponse..." | `Icons.chat` |
| playing | "Lecture..." | **"Bobodo parle..."** | `Icons.volume_up` |
| paused | "Pause" | "Pause" | `Icons.pause` |
| ended | "Session terminée" | "Session terminée" | `Icons.check_circle` |

**Changements** :
- `listening` : "Écoute..." → **"Parlez maintenant"** — instruction directe à l'utilisateur
- `playing` : "Lecture..." → **"Bobodo parle..."** — identifie clairement qui parle

### Message d'activation

**Action** : Quand `_isConversationMode` passe à `true`, afficher un SnackBar informatif.

**Méthode** : `_toggleVoiceMode()` (ligne 1551)  
**Code à ajouter après `_startConversationMode()`** :
```dart
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(
    content: Text('Conversation vocale activée. Parlez, Bobodo vous répondra.'),
    duration: Duration(seconds: 3),
  ),
);
```

**Lignes ajoutées** : 6

---

## MISSION 3 — ICONOGRAPHIE ET DIFFÉRENCIATION DES MICROS

### Micro header (Mode conversation)

| Attribut | Actuel | Proposé |
|----------|--------|---------|
| Icône inactive | `Icons.mic_none` | **`Icons.record_voice_over`** |
| Icône active | `Icons.mic` | **`Icons.record_voice_over`** |
| Couleur inactive | Blanc | Blanc |
| Couleur active | `PrepTheme.primary` (bleu) | `PrepTheme.primary` (bleu) |
| Tooltip inactif | "Mode Dictée" | **"Conversation vocale"** |
| Tooltip actif | "Mode Conversation" | **"Arrêter la conversation"** |

**Justification** : `Icons.record_voice_over` (silhouette avec ondes sonores) est visuellement distinct de `Icons.mic` (simple microphone). L'utilisateur comprend immédiatement que c'est un mode "conversation avec quelqu'un", pas un simple enregistrement.

### Micro zone de saisie (Mode dictée)

| Attribut | Actuel | Proposé |
|----------|--------|---------|
| Icône | `Icons.mic` | `Icons.mic` (inchangé) |
| Couleur | `PrepTheme.primary` (bleu) | `PrepTheme.primary` (bleu) |

**Pas de changement sur le micro de dictée** — il est déjà clair dans son contexte (à côté du champ texte).

### Modifications code

**Fichier** : `student_bobodo_tab.dart`  
**Lignes 404-411** — Micro header :

Actuel :
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

Proposé :
```dart
IconButton(
  icon: Icon(
    Icons.record_voice_over,
    color: _isConversationMode ? PrepTheme.primary : Colors.white,
    size: 20,
  ),
  tooltip: _isConversationMode ? 'Arrêter la conversation' : 'Conversation vocale',
  onPressed: _toggleVoiceMode,
),
```

**Lignes modifiées** : 3 lignes modifiées

---

## RÉSUMÉ DU PLAN

### Fichier unique modifié

`lib/features/student/tabs/student_bobodo_tab.dart`

### Modifications détaillées

| # | Localisation | Action | Lignes |
|---|-------------|--------|--------|
| 1 | `initState()` après ligne 131 | Ajouter `_controller.addListener(() => setState(() {}));` | +1 |
| 2 | `_buildConversationStateIndicator()` case listening | "Écoute..." → "Parlez maintenant" | 1 modifiée |
| 3 | `_buildConversationStateIndicator()` case playing | "Lecture..." → "Bobodo parle..." | 1 modifiée |
| 4 | `_toggleVoiceMode()` | Ajouter SnackBar d'activation | +6 |
| 5 | Micro header (ligne 406) | `Icons.mic`/`Icons.mic_none` → `Icons.record_voice_over` | 2 modifiées |
| 6 | Tooltip header (ligne 410) | Tooltips corrigés | 1 modifiée |

### Total

- **1 fichier modifié**
- **7 lignes ajoutées**
- **5 lignes modifiées**
- **0 lignes supprimées**
- **0 dépendances ajoutées**
- **0 changement backend**

### Risques de régression

| Fonctionnalité | Risque |
|----------------|--------|
| Mode texte classique | **Nul** — le listener rebuild le widget mais ne change pas le comportement |
| Mode dictée | **Nul** — le micro zone saisie n'est pas modifié |
| Mode conversation | **Nul** — seuls les textes et icônes changent |
| Historique/restauration | **Nul** — aucun lien |
| Auto-scroll | **Nul** — le rebuild supplémentaire n'affecte pas le scroll |

### Performance

Le `_controller.addListener(() => setState(() {}))` provoque un rebuild à chaque frappe. C'est un pattern courant en Flutter (utilisé par défaut dans `TextFormField` avec `onChanged`). L'impact est négligeable sur un écran de chat.

---

**En attente de validation avant implémentation.**

*Aucune modification effectuée. Aucun commit.*
