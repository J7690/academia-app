# BOBODO — Audit UX Flutter Interface Visible

**Date**: 2025-06-15  
**Méthode**: Analyse exclusive des widgets Flutter visibles par l'utilisateur  
**Périmètre**: Ce que l'étudiant voit, comprend et peut faire sur son téléphone

---

## 1. MODE TEXTE — BOUTON ENVOYER

### Widget qui déclenche l'envoi

```
Container (cercle gradient bleu, 40x40px)
  └─ IconButton
       icon: Icons.send (blanc, 18px)
       onPressed: conditionnel
```

**Localisation** : `student_bobodo_tab.dart` lignes 1080-1105

### Condition d'activation/désactivation du bouton

```dart
onPressed: provider.isLoading || _controller.text.trim().isEmpty
    ? null        // DÉSACTIVÉ
    : () => _send(context)   // ACTIVÉ
```

**Le bouton est cliquable UNIQUEMENT si** :
1. `provider.isLoading == false` (Bobodo n'est pas en train de répondre)
2. `_controller.text.trim().isEmpty == false` (le champ contient du texte non vide)

### DÉFAUT UX BLOQUANT — Bouton envoi potentiellement non réactif

**Problème identifié** : La condition `_controller.text.trim().isEmpty` est évaluée dans le `Consumer<BobodoProvider>` builder (ligne 1101). Ce builder ne se reconstruit QUE lorsque le provider appelle `notifyListeners()`.

**Or** : Il n'existe AUCUN mécanisme pour reconstruire le bouton quand l'utilisateur tape du texte :
- Pas de `_controller.addListener(...)` → pas de `setState()` sur changement de texte
- Pas de `onChanged` sur le TextField
- Le TextField (ligne 1040) utilise `_controller` mais aucun callback de changement

**Conséquence visible** : Après avoir ouvert Bobodo et tapé du texte, le bouton envoi peut rester visuellement désactivé (grisé) même si du texte est présent dans le champ. Il ne se réactive potentiellement qu'après un événement qui déclenche un rebuild du Consumer (ex: `notifyListeners()` du provider pour une autre raison).

**Note** : En pratique, Flutter peut quand même reconstruire le widget lors d'interactions clavier (les interactions avec le TextField peuvent provoquer des rebuilds indirects). Le comportement exact dépend du contexte de rendering. Cependant, le design est fragile et non garanti.

**Verdict** : ⚠️ **DÉFAUT UX POTENTIELLEMENT BLOQUANT** — Le bouton envoi ne dispose pas d'un mécanisme fiable pour se mettre à jour quand l'utilisateur tape.

### Cas où le bouton envoi est définitivement non cliquable

1. `provider.isLoading == true` (en attente de réponse) → **Normal, attendu**
2. Champ vide → **Normal, attendu**
3. Après dictée vocale → `_isRecordingMode` revient à `false` (ligne 1444), input bar réapparaît → **OK**
4. En mode conversation → Input bar cachée entièrement (ligne 298) → **Normal, le bouton n'existe pas dans ce mode**

---

## 2. MODE DICTÉE VOCALE (Mode 1) — Parcours utilisateur

### Parcours exact

| Étape | Ce que l'utilisateur voit | Ce qu'il fait |
|-------|--------------------------|---------------|
| 1 | Icône micro bleu (Icons.mic) à droite du champ | Appuie dessus |
| 2 | Le champ texte est REMPLACÉ par un container bleu clair avec chrono "00:00" | Il parle |
| 3 | 5 barres d'animation (waveform) bleues au centre | Il continue à parler |
| 4 | Chrono incrémente (00:01, 00:02...) | Il voit le temps |
| 5 | À droite : icône ❌ rouge (annuler) + cercle bleu avec ⏹ (stop) | Il appuie sur stop |
| 6 | Texte transcrit apparaît dans le champ de saisie | Il peut modifier |
| 7 | Bouton envoi (cercle bleu avec ➤) redevient disponible | Il appuie pour envoyer |

### Widgets concernés

| Widget | Icône | Couleur | Rôle |
|--------|-------|---------|------|
| Micro zone saisie | `Icons.mic` | `PrepTheme.primary` (bleu) | Démarrer la dictée |
| Waveform | 5 barres verticales | `PrepTheme.primary` (bleu) | Indicateur audio actif |
| Chrono | Texte "MM:SS" | `PrepTheme.primary` (bleu) | Durée d'enregistrement |
| Bouton annuler | `Icons.close` | `PrepTheme.danger` (rouge) | Annuler sans envoyer |
| Bouton stop | `Icons.stop` | Blanc sur cercle bleu | Arrêter l'enregistrement |

### États visuels

| État | Affichage |
|------|-----------|
| Mode texte normal | Champ texte + micro bleu + bouton envoi |
| Enregistrement actif | Container bleu clair + waveform + chrono + bouton stop + bouton annuler |
| Transcription en cours | Spinner circulaire + texte "Transcription en cours..." |
| Retour mode texte | Texte dans le champ + bouton envoi |

### Verdict Mode 1 : ✅ Interface claire

L'utilisateur comprend visuellement qu'il est en mode dictée grâce à :
- Changement visuel du champ de saisie
- Chrono visible
- Waveform animé
- Boutons stop/annuler explicites

---

## 3. MODE CONVERSATION VOCALE (Mode 2) — Interface visible

### Comment l'étudiant découvre ce mode

| Élément | Ce qu'il voit |
|---------|--------------|
| Bouton | IconButton dans le header, à droite de "Historique" |
| Icône inactive | `Icons.mic_none` (micro vide/outline) |
| Couleur inactive | Blanc (comme les autres boutons du header) |
| Tooltip | "Mode Dictée" (affiché au long press sur Android) |

### DÉFAUT UX BLOQUANT — Tooltip trompeur

Le tooltip du bouton header quand il est inactif dit **"Mode Dictée"** (ligne 410) :
```dart
tooltip: _isConversationMode ? 'Mode Conversation' : 'Mode Dictée',
```

**Problème** : Quand le mode conversation n'est PAS actif, le tooltip dit "Mode Dictée". C'est le texte qui s'affiche au long press. L'utilisateur pense que ce bouton active la dictée, PAS la conversation vocale continue.

### Ce qui apparaît quand l'utilisateur appuie

| Changement visuel | Description |
|-------------------|-------------|
| Icône header change | `Icons.mic` (rempli) en couleur `PrepTheme.primary` |
| Indicateur d'état apparaît | Bandeau sous le header avec icône + texte |
| Input bar disparaît | Remplacée par les contrôles de conversation |
| Contrôles bas | Bouton ❌ rouge (quitter) — seul bouton visible initialement |

### Indicateur d'état (bandeau sous le header)

| État | Icône | Texte affiché | Couleur |
|------|-------|---------------|---------|
| idle | `Icons.hourglass_empty` | "En attente" | Gris tertiaire |
| listening | `Icons.mic` | "Écoute..." | Bleu primary |
| processing | `Icons.settings` | "Traitement..." | Accent |
| thinking | `Icons.psychology` | "Bobodo réfléchit..." | Bleu primary |
| playing | `Icons.volume_up` | "Lecture..." | Bleu primary |
| paused | `Icons.pause` | "Pause" | Accent |
| ended | `Icons.check_circle` | "Session terminée" | Vert success |

### Contrôles de conversation (en bas, remplacent l'input bar)

| Bouton | Icône | Couleur | Condition d'affichage | Tooltip |
|--------|-------|---------|-----------------------|---------|
| Quitter | `Icons.close` | Rouge danger | **Toujours visible** | "Quitter" |
| Couper | `Icons.stop` | Accent | Seulement quand `_isSpeaking == true` | "Couper" |
| Rejouer | `Icons.replay` | Bleu primary | Seulement quand audio dispo et pas en lecture | "Rejouer" |
| Reprendre | `Icons.play_arrow` | Bleu primary | Seulement quand état == paused | "Reprendre" |

---

## 4. MICRO HEADER — La croix rouge

### La croix en bas de l'écran

**Widget** : `student_bobodo_tab.dart` ligne 1721-1724
```dart
IconButton(
  icon: Icon(Icons.close, color: PrepTheme.danger),
  onPressed: _quitConversation,
  tooltip: 'Quitter',
),
```

### Ce que la croix fait exactement

**Réponse : A — Quitter le mode vocal**

`_quitConversation()` (ligne 1579-1587) :
- Met `_isConversationMode = false`
- Met `_conversationState = ended`
- Arrête l'enregistrement
- Arrête la lecture audio
- Annule le timer d'inactivité
- **Résultat** : Retour complet au mode texte classique

### DÉFAUT UX — Aucune instruction visible

**Ce que l'utilisateur voit** : Un bouton ❌ rouge sans texte explicatif.

**Ce que l'utilisateur comprend** :
- Il ne sait pas s'il annule l'enregistrement en cours
- Il ne sait pas s'il annule le dernier message
- Il ne sait pas s'il quitte définitivement le mode conversation

**Tooltip** : "Quitter" — visible uniquement au long press. Pas visible sur un tap normal.

**Verdict** : ⚠️ **DÉFAUT UX MINEUR** — La croix manque de contexte. Un texte "Quitter la conversation" serait plus explicite.

---

## 5. MODE 2 RÉELLEMENT ACCESSIBLE ?

### Question : Un nouvel étudiant qui ouvre Bobodo pour la première fois peut-il comprendre seul comment utiliser le mode conversation vocale ?

## NON.

### Preuves :

| Question | Réponse | Explication |
|----------|---------|-------------|
| Comment activer le mode ? | **Non compréhensible** | Le bouton est un micro gris/blanc dans le header parmi 4 autres icônes. Aucun label. Le tooltip dit "Mode Dictée" (!). Rien n'indique qu'il active une conversation vocale continue. |
| Comment parler ? | **Partiellement compréhensible** | Une fois activé, l'indicateur dit "Écoute..." avec un micro. L'utilisateur comprend qu'il peut parler. |
| Quand arrêter ? | **Non compréhensible** | Aucune instruction n'indique que l'écoute s'arrête automatiquement après silence (3s). L'utilisateur ne sait pas s'il doit appuyer quelque part pour terminer son message. |
| Quand Bobodo répond ? | **Partiellement compréhensible** | L'indicateur passe à "Bobodo réfléchit..." puis "Lecture...". L'utilisateur entend la voix. Compréhensible une fois qu'il l'a vécu. |
| Quand reprendre la parole ? | **Non compréhensible** | Aucune instruction ne dit "Parlez maintenant" ou "C'est votre tour". L'indicateur repasse à "Écoute..." mais l'utilisateur ne sait pas qu'il peut/doit reparler. |

### Raisons de l'inaccessibilité

1. **Pas d'onboarding** — Aucun tutoriel, popup ou texte explicatif lors de la première activation
2. **Tooltip trompeur** — Le tooltip dit "Mode Dictée" quand le mode est inactif
3. **Pas de distinction visuelle suffisante** — Le micro header ressemble à tous les autres boutons du header (blanc, même taille)
4. **Pas d'instruction de fin de tour** — L'utilisateur ne sait pas que l'écoute s'arrête après 3s de silence
5. **Pas d'instruction de reprise** — L'utilisateur ne sait pas que Bobodo réécoute automatiquement après avoir parlé

---

## INVENTAIRE COMPLET DES BOUTONS

### Header (de gauche à droite)

| Position | Icône | Couleur | Tooltip | Action |
|----------|-------|---------|---------|--------|
| 1 | `Icons.smart_toy` | Blanc sur cercle semi-transparent | — | Décoratif (avatar Bobodo) |
| 2 | `Icons.add_comment_outlined` | Blanc | "Nouvelle conversation" | Nouvelle session |
| 3 | `Icons.history` | Blanc | "Historique" | Ouvre la liste des sessions |
| 4 | `Icons.mic_none` / `Icons.mic` | Blanc / Bleu | "Mode Dictée" / "Mode Conversation" | Toggle mode conversation |
| 5 | `Icons.share` | Blanc | "Partager" | Partage de l'écran |

### Zone de saisie (mode texte)

| Position | Icône | Couleur | Action |
|----------|-------|---------|--------|
| Gauche | `Icons.emoji_emotions_outlined` | Gris | Toggle emoji picker |
| Droite 1 | `Icons.mic` | Bleu | Démarrer dictée vocale |
| Droite 2 | `Icons.send` | Blanc sur cercle gradient bleu | Envoyer message |

### Zone de saisie (mode enregistrement)

| Position | Icône | Couleur | Action |
|----------|-------|---------|--------|
| Gauche | `Icons.emoji_emotions_outlined` | Gris (désactivé) | Rien |
| Centre | Waveform + chrono | Bleu | Indicateur |
| Droite 1 | `Icons.close` | Rouge | Annuler enregistrement |
| Droite 2 | `Icons.stop` | Blanc sur cercle bleu | Arrêter enregistrement |

### Contrôles conversation (remplacent l'input bar)

| Position | Icône | Couleur | Condition | Action |
|----------|-------|---------|-----------|--------|
| 1 | `Icons.close` | Rouge | Toujours | Quitter mode conversation |
| 2 | `Icons.stop` | Accent | Si Bobodo parle | Couper la lecture |
| 3 | `Icons.replay` | Bleu | Si audio dispo | Rejouer dernier audio |
| 4 | `Icons.play_arrow` | Bleu | Si en pause | Reprendre conversation |

---

## INVENTAIRE COMPLET DES ÉTATS VISUELS

| Contexte | Élément visible | Texte | Condition |
|----------|-----------------|-------|-----------|
| Header normal | Sous-titre | "Assistant Academia" | Quand pas en loading |
| Header loading | Sous-titre | "En train de réfléchir..." | `provider.isLoading` |
| Conversation - idle | Bandeau | "En attente" + ⏳ | Mode conversation + idle |
| Conversation - listening | Bandeau | "Écoute..." + 🎤 | Mode conversation + écoute |
| Conversation - processing | Bandeau | "Traitement..." + ⚙️ | Mode conversation + processing |
| Conversation - thinking | Bandeau | "Bobodo réfléchit..." + 🧠 | Mode conversation + envoi |
| Conversation - playing | Bandeau | "Lecture..." + 🔊 | Mode conversation + TTS |
| Conversation - paused | Bandeau | "Pause" + ⏸ | Mode conversation + pause |
| Conversation - ended | Bandeau | "Session terminée" + ✓ | Mode conversation + fin |
| Erreur backend | Barre rouge | Message d'erreur + "Réessayer" | `provider.error != null` |

---

## DÉFAUTS UX IDENTIFIÉS

### Bloquants

| # | Défaut | Impact | Localisation |
|---|--------|--------|-------------|
| B1 | **Tooltip trompeur sur micro header** | L'utilisateur ne comprend pas que ce bouton active le mode conversation vocale. Le tooltip dit "Mode Dictée" quand inactif. | Ligne 410 |
| B2 | **Aucune instruction d'utilisation du mode conversation** | L'utilisateur ne sait pas : quand parler, quand s'arrêter, quand Bobodo écoute à nouveau | Aucun widget d'onboarding |
| B3 | **Bouton envoi potentiellement non réactif** | Le `Consumer<BobodoProvider>` ne se reconstruit pas sur changement de texte dans le champ. Le bouton peut rester disabled même avec du texte. | Ligne 1101 (pas de `addListener` sur `_controller`) |

### Mineurs

| # | Défaut | Impact | Localisation |
|---|--------|--------|-------------|
| M1 | **Croix rouge sans contexte** | L'utilisateur ne sait pas si ❌ = annuler message ou quitter le mode | Ligne 1722, tooltip "Quitter" invisible au tap |
| M2 | **Pas de distinction entre les deux micros** | Le micro header et le micro zone saisie ont la même icône (`Icons.mic` / `Icons.mic_none`), confusion possible | Lignes 406 et 1072 |
| M3 | **Indicateur "Écoute..." sans instruction** | L'utilisateur voit "Écoute..." mais ne sait pas s'il doit parler maintenant ou attendre | Ligne 1662 |
| M4 | **Pas d'indicateur de "votre tour"** | Après que Bobodo finit de parler, l'indicateur repasse à "Écoute..." mais rien ne signale explicitement "Parlez maintenant" | Ligne 1604-1611 |
| M5 | **Waveform statique** | Les `_audioLevels` restent à 0.0 car aucune mise à jour ne les alimente (le STT natif ne fournit pas de niveaux audio). L'utilisateur voit des barres de hauteur 0. | Lignes 96, 1141-1156 |

---

## RECOMMANDATIONS UX

### Priorité Haute

| # | Recommandation |
|---|---------------|
| R1 | **Corriger le tooltip** : Quand `_isConversationMode == false`, le tooltip devrait dire "Activer la conversation vocale" et non "Mode Dictée" |
| R2 | **Ajouter un onboarding minimal** : Lors de la première activation, afficher un dialog ou un overlay expliquant "Parlez, Bobodo vous répondra vocalement. La conversation continue automatiquement." |
| R3 | **Ajouter un listener sur le TextEditingController** : `_controller.addListener(() => setState(() {}))` dans `initState` pour garantir que le bouton envoi se met à jour en temps réel |

### Priorité Moyenne

| # | Recommandation |
|---|---------------|
| R4 | **Ajouter un texte sous la croix** : Afficher "Quitter" en texte visible sous ou à côté du bouton ❌ |
| R5 | **Différencier visuellement les deux micros** : Utiliser `Icons.record_voice_over` ou un badge "CONV" pour le micro header |
| R6 | **Enrichir l'indicateur "Écoute..."** : Ajouter "Parlez maintenant" ou une animation pulsante pour signaler que c'est le tour de l'utilisateur |
| R7 | **Remplacer waveform par pulsation** : Puisque les niveaux audio ne sont pas alimentés, utiliser une animation de pulsation (pulse) au lieu de barres statiques |

### Priorité Basse

| # | Recommandation |
|---|---------------|
| R8 | **Ajouter un compteur d'échanges** : "Échange 3/10" pour que l'utilisateur comprenne le cycle |
| R9 | **Ajouter un bouton micro visible pendant "Écoute..."** : Pour que l'utilisateur comprenne visuellement que c'est son tour |

---

## CONCLUSION

Le Mode 2 (conversation vocale continue) **fonctionne techniquement** mais n'est **pas accessible pour un nouvel utilisateur** :

1. Le bouton d'activation n'est pas identifiable
2. Le tooltip est trompeur
3. Il n'y a aucune instruction d'utilisation
4. L'utilisateur ne sait pas quand c'est son tour de parler

Le bouton envoi (mode texte) a un **défaut de réactivité potentiel** lié à l'absence de listener sur le TextEditingController.

**Aucune modification effectuée. Aucun commit. Aucun déploiement.**

---

*Fin du rapport.*
