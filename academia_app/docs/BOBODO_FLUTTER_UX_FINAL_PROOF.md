# BOBODO — Preuves UX Finales Flutter

**Date**: 2025-06-15  
**Méthode**: Analyse du code widget Flutter uniquement

---

## BLOC A — BOUTON ENVOYER

### Question 1 : Lorsque l'utilisateur saisit du texte, le widget du bouton envoi est-il rebuild ?

## NON — pas systématiquement.

**Preuve** :

Le bouton envoi est construit dans `_buildTextActionButtons(provider)` (ligne 1066), appelé depuis `_buildInputBar(provider)` (ligne 1023), lui-même appelé depuis le `Consumer<BobodoProvider>` builder (ligne 299).

```dart
// Ligne 257-258
Consumer<BobodoProvider>(
  builder: (context, provider, child) {
    // ... tout le contenu, y compris _buildInputBar(provider) ligne 299
  }
)
```

Le `Consumer` ne reconstruit que lorsque `BobodoProvider.notifyListeners()` est appelé.

Le `TextField` (ligne 1040) utilise un `TextEditingController` :
```dart
TextField(
  controller: _controller,
  // Pas de onChanged
)
```

Quand l'utilisateur tape, le `TextField` se met à jour INTERNEMENT (dans son propre `EditableTextState`). Il N'appelle PAS `setState()` sur le parent `_StudentBobodoTabState`.

**Cependant** : Tout appel à `setState()` sur `_StudentBobodoTabState` (pour n'importe quelle raison) déclenche un `build()` complet de la page, ce qui reconstruit le Consumer, qui réévalue `_controller.text.trim().isEmpty`.

**En pratique** : Si l'utilisateur tape du texte SANS aucune autre interaction (pas de tap sur emoji, pas d'ouverture de clavier avec `_showEmojiPicker`), et que le provider n'émet pas de `notifyListeners()`, alors le bouton envoi **ne se rebuild PAS** et sa condition `onPressed` n'est pas réévaluée.

### Question 2 : Valeur de `_controller.text` quand l'utilisateur saisit "Bonjour"

```
_controller.text == "Bonjour"
```

**Preuve** : Le `TextEditingController` maintient toujours la valeur saisie en temps réel, indépendamment des rebuilds. La valeur est synchronisée avec le `TextField` via le framework d'édition Flutter.

### Question 3 : Valeur de `_controller.text.trim().isEmpty` quand texte = "Bonjour"

```
_controller.text.trim().isEmpty == false
```

**Preuve** : `"Bonjour".trim()` = `"Bonjour"` ; `"Bonjour".isEmpty` = `false`.

### Question 4 : `onPressed` est-il `null` dans cet état ?

**Réponse** : **DÉPEND du moment de la dernière reconstruction du widget.**

```dart
// Ligne 1101-1103
onPressed: provider.isLoading || _controller.text.trim().isEmpty
    ? null
    : () => _send(context),
```

- **Si le widget a été reconstruit APRÈS la saisie** : `_controller.text.trim().isEmpty == false` → `onPressed = () => _send(context)` → **bouton actif**
- **Si le widget n'a PAS été reconstruit depuis que le champ était vide** : `onPressed` a été fixé à `null` lors du dernier build → **bouton inactif** même si du texte est présent

### Question 5 : Quel widget pilote l'état activé/désactivé ?

Le `Consumer<BobodoProvider>` (ligne 257) pilote la reconstruction. Le bouton est un `IconButton` dont `onPressed` est évalué à chaque build du Consumer.

**Le pilote réel est donc : la fréquence de rebuild du `Consumer<BobodoProvider>`.**

### Question 6 : Existe-t-il un scénario où le texte est visible mais le bouton reste inactif ?

## OUI — scénario identifié :

**Scénario de reproduction** :

1. L'utilisateur ouvre Bobodo — `build()` est exécuté → `_controller.text == ""` → `onPressed = null`
2. L'utilisateur tape "Bonjour" dans le TextField
3. Le `TextField` se met à jour visuellement (le texte "Bonjour" est visible)
4. **MAIS** : Aucun `setState()` n'est appelé sur `_StudentBobodoTabState` ET aucun `notifyListeners()` n'est émis par le provider
5. Le `Consumer` n'est pas reconstruit
6. `onPressed` reste à `null` (valeur du dernier build)
7. L'utilisateur voit "Bonjour" dans le champ mais le bouton envoi **ne réagit pas au tap**

**RÉFUTATION PARTIELLE — Facteur atténuant** :

En pratique, ce scénario est **ATTÉNUÉ** par :

1. **`onTap` du TextField** (ligne 1057-1061) : Si l'utilisateur a touché le champ pour le focus, et que `_showEmojiPicker` était `true`, un `setState()` est appelé. Mais si `_showEmojiPicker == false` (cas normal), aucun `setState()` n'est déclenché.

2. **Le clavier Android** : Sur certains devices, l'apparition du clavier peut provoquer un layout change qui déclenche un rebuild. Mais ce n'est PAS garanti et dépend de l'implémentation Android.

3. **`onSubmitted`** (ligne 1056) : Si l'utilisateur appuie sur Entrée du clavier, `_send(context)` est appelé directement sans passer par le bouton. Ceci fonctionne toujours car `_send()` lit `_controller.text` au moment de l'appel.

**VERDICT FINAL SUR LE BOUTON ENVOI** :

Le défaut est **RÉEL mais RARE** en pratique. Dans la majorité des cas, un rebuild est déclenché par un autre événement (notification push, provider update, interaction avec un autre widget). Mais dans un scénario strict (ouverture → tape → tap bouton sans autre interaction), le bouton peut rester inactif.

**Sévérité corrigée** : ⚠️ Défaut UX intermittent, non systématique.

---

## BLOC B — MODE CONVERSATION VOCALE — ÉTATS VISUELS

### Tableau complet des 8 états

---

#### ÉTAT 1 — Écran normal (mode texte)

| Attribut | Valeur visible |
|----------|---------------|
| **Widget header** | Bouton micro : `Icons.mic_none` (micro vide/outline) |
| **Couleur header micro** | Blanc (identique aux autres boutons) |
| **Indicateur d'état** | Aucun (pas de bandeau) |
| **Zone bas de l'écran** | Input bar : champ texte + emoji + micro bleu + bouton envoi |
| **Texte affiché** | "Pose une question à Bobodo..." (hint) |
| **Animation** | Aucune |

---

#### ÉTAT 2 — Activation micro header (tap)

| Attribut | Valeur visible |
|----------|---------------|
| **Widget header** | Bouton micro : `Icons.mic` (micro rempli) |
| **Couleur header micro** | `PrepTheme.primary` (bleu) — se distingue des autres boutons |
| **Indicateur d'état** | Bandeau apparaît sous le header |
| **Texte bandeau** | "Écoute..." |
| **Icône bandeau** | `Icons.mic` (micro) |
| **Couleur bandeau** | Fond : bleu à 10% opacité. Texte/icône : bleu primary |
| **Zone bas de l'écran** | Input bar DISPARAÎT. Remplacée par contrôles de conversation |
| **Contrôles visibles** | Un seul bouton : ❌ rouge (quitter) |
| **Animation** | Aucune animation explicite |
| **Ce qui se passe en arrière-plan** | `_startVocalRecording()` est appelé automatiquement → STT natif commence |

---

#### ÉTAT 3 — Écoute active (utilisateur parle)

| Attribut | Valeur visible |
|----------|---------------|
| **Widget header** | Inchangé (micro bleu rempli) |
| **Indicateur d'état** | Bandeau "Écoute..." + micro bleu |
| **Zone bas** | ❌ rouge uniquement |
| **Animation** | **Aucune animation visible** — pas de waveform, pas de pulsation |
| **Texte** | "Écoute..." uniquement |
| **Couleur** | Bleu primary |

**DÉFAUT** : L'utilisateur n'a AUCUN feedback visuel confirmant que sa voix est captée. Pas de waveform. Pas de pulsation. Le seul indice est le texte statique "Écoute...".

---

#### ÉTAT 4 — Fin d'écoute (silence détecté, STT terminé)

| Attribut | Valeur visible |
|----------|---------------|
| **Transition** | Automatique (après 3s de silence ou résultat final STT) |
| **Indicateur d'état** | Change à "Bobodo réfléchit..." |
| **Icône bandeau** | `Icons.psychology` (cerveau) |
| **Couleur** | Bleu primary |
| **Instruction à l'utilisateur** | **Aucune** — l'utilisateur ne voit pas "Message envoyé" ou "Transcription terminée" |
| **Durée visible** | Le temps de l'appel HTTP à l'Edge Function (3-8 secondes) |

---

#### ÉTAT 5 — Envoi (message part vers Bobodo)

| Attribut | Valeur visible |
|----------|---------------|
| **Indicateur d'état** | "Bobodo réfléchit..." + 🧠 (identique à état 4) |
| **Zone messages** | Le message de l'utilisateur apparaît dans la bulle (ajouté localement) |
| **Typing indicator** | Shimmer avec 3 points (bulle bot en cours) visible si `isLoading` |
| **Instruction** | Aucune |
| **Distinction avec état 4** | **Aucune distinction visuelle** — l'utilisateur ne voit pas la différence entre "fin d'écoute" et "envoi en cours" |

---

#### ÉTAT 6 — Bobodo réfléchit (attente réponse)

| Attribut | Valeur visible |
|----------|---------------|
| **Indicateur d'état** | "Bobodo réfléchit..." + 🧠 bleu |
| **Zone messages** | Typing indicator (shimmer 3 points) sous la bulle étudiant |
| **Sous-titre header** | "En train de réfléchir..." (ligne 384) |
| **Durée** | 3-15 secondes selon la latence réseau + OpenRouter |
| **Animation** | Shimmer sur le typing indicator uniquement |

---

#### ÉTAT 7 — Bobodo parle (TTS en cours)

| Attribut | Valeur visible |
|----------|---------------|
| **Indicateur d'état** | Change à "Lecture..." |
| **Icône bandeau** | `Icons.volume_up` (haut-parleur) |
| **Couleur** | Bleu primary |
| **Zone messages** | La réponse texte de Bobodo apparaît dans la bulle bot |
| **Contrôles bas** | ❌ rouge (quitter) + ⏹ accent (couper) — le bouton "Couper" apparaît |
| **Audio** | L'utilisateur ENTEND la voix TTS (FlutterTts Google) |
| **Animation** | Aucune animation visuelle pendant la lecture |
| **Instruction** | Aucun texte ne dit "Écoutez Bobodo" |

---

#### ÉTAT 8 — Reprise écoute (après fin TTS)

| Attribut | Valeur visible |
|----------|---------------|
| **Indicateur d'état** | Revient à "Écoute..." + micro bleu |
| **Contrôles bas** | ❌ rouge uniquement (le bouton "Couper" disparaît) |
| **Transition** | Automatique à la fin de la lecture TTS |
| **Audio** | Silence |
| **Instruction à l'utilisateur** | **Aucune** — rien ne dit "Parlez maintenant" ou "C'est votre tour" |
| **Animation** | Aucune |

**DÉFAUT CRITIQUE** : L'utilisateur ne reçoit AUCUN signal explicite qu'il peut reparler. Il doit déduire de "Écoute..." que c'est son tour.

---

### Synthèse visuelle du cycle complet

```
┌─────────────────────────────────────────────────────────┐
│ HEADER: [robot] Bobodo  [+] [⏰] [🎤bleu] [📤]        │
│ BANDEAU: [🎤] Écoute...                                │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  [Messages de conversation]                             │
│                                                         │
│  ┌──────────────────────┐                               │
│  │ Texte de l'étudiant  │ (bulle droite)                │
│  └──────────────────────┘                               │
│                                                         │
│  ┌──────────────────────┐                               │
│  │ Réponse de Bobodo    │ (bulle gauche)                │
│  └──────────────────────┘                               │
│                                                         │
├─────────────────────────────────────────────────────────┤
│ CONTRÔLES: [❌]                                         │
└─────────────────────────────────────────────────────────┘
```

---

### Question finale : Un étudiant découvre-t-il seul le fonctionnement ?

## NON.

### Preuves par état :

| Étape critique | Compréhensible seul ? | Raison |
|----------------|:---:|--------|
| Trouver le bouton d'activation | ❌ | Micro blanc parmi 4 icônes blanches identiques dans le header. Tooltip "Mode Dictée" trompeur. |
| Comprendre qu'il peut parler | ✅ | "Écoute..." + micro indique l'écoute |
| Comprendre que l'écoute est terminée | ❌ | Aucune notification "Message capté" — passage direct à "Bobodo réfléchit" |
| Comprendre que Bobodo répond | ✅ | "Lecture..." + voix audible |
| Comprendre que c'est son tour de reparler | ❌ | "Écoute..." réapparaît sans signal. Pas de son, pas d'animation, pas de texte "Parlez" |
| Comprendre comment quitter | ⚠️ | ❌ rouge visible mais pas de label "Quitter la conversation" |

### Défauts UX bloquants confirmés

| # | Défaut | Type |
|---|--------|------|
| 1 | **Pas de découvrabilité du mode** — Le bouton header n'est pas identifiable comme "Mode conversation vocale continue" | Bloquant |
| 2 | **Tooltip inversé** — Dit "Mode Dictée" quand inactif, devrait dire "Conversation vocale" | Bloquant |
| 3 | **Pas d'instruction de reprise de parole** — L'utilisateur ne sait pas quand c'est son tour | Bloquant |
| 4 | **Pas de feedback audio/visuel d'écoute active** — Aucune animation confirme que la voix est captée | Majeur |
| 5 | **Bouton envoi potentiellement non réactif** — Défaut intermittent lié à l'absence de listener | Mineur (rare en pratique) |

---

**Aucune modification effectuée. Aucun commit. Aucun patch.**

*Fin du rapport.*
