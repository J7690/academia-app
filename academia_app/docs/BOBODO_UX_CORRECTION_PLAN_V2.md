# BOBODO — Plan de Correction UX Flutter V2

**Date**: 2025-06-15  
**Statut**: En attente de validation  
**Périmètre**: `student_bobodo_tab.dart` uniquement

---

## 1. COMPORTEMENT DE LA CROIX PENDANT LE MODE CONVERSATION

### Situation actuelle

| Attribut | Valeur |
|----------|--------|
| Icône | `Icons.close` |
| Couleur | `PrepTheme.danger` (rouge) |
| Tooltip | "Quitter" (visible au long press uniquement) |
| Position | En bas de l'écran, à gauche, dans les contrôles de conversation |
| Visibilité | Toujours visible quand `_isConversationMode == true` |
| Action | `_quitConversation()` → désactive le mode, arrête tout, retour au mode texte |

### Problème

L'utilisateur ne sait pas si ❌ signifie :
- Annuler le message en cours ?
- Arrêter l'enregistrement ?
- Quitter définitivement le mode ?

### Correction proposée

Remplacer le `IconButton` seul par un `TextButton.icon` avec label explicite :

```dart
TextButton.icon(
  icon: Icon(Icons.close, color: PrepTheme.danger, size: 18),
  label: Text(
    'Quitter',
    style: TextStyle(color: PrepTheme.danger, fontSize: 12),
  ),
  onPressed: _quitConversation,
)
```

**Résultat visible** : Le bouton affiche ❌ + "Quitter" en rouge. L'utilisateur comprend immédiatement que c'est une sortie définitive du mode.

---

## 2. TOUS LES ÉTATS CONVERSATIONNELS VISIBLES

### Tableau complet des états après correction

| # | État | Texte indicateur | Icône | Couleur | Contrôles bas | Ce que l'utilisateur comprend |
|---|------|-----------------|-------|---------|---------------|-------------------------------|
| 1 | **Activation** | SnackBar : "Conversation vocale activée. Parlez, Bobodo vous répondra." | — | — | ❌ "Quitter" | Le mode est activé, il peut parler |
| 2 | **Écoute** | **"Parlez maintenant"** | `Icons.mic` | Bleu primary | ❌ "Quitter" | C'est son tour de parler |
| 3 | **Transcription/Envoi** | "Bobodo réfléchit..." | `Icons.psychology` | Bleu primary | ❌ "Quitter" | Son message est parti, Bobodo traite |
| 4 | **Réflexion** | "Bobodo réfléchit..." | `Icons.psychology` | Bleu primary | ❌ "Quitter" | Identique à l'étape 3 (pas de distinction nécessaire) |
| 5 | **Lecture vocale** | **"Bobodo parle..."** | `Icons.volume_up` | Bleu primary | ❌ "Quitter" + ⏹ "Couper" | Bobodo répond vocalement, il écoute |
| 6 | **Reprise écoute** | **"Parlez maintenant"** | `Icons.mic` | Bleu primary | ❌ "Quitter" | C'est à nouveau son tour |

### Transitions visuelles

```
ACTIVATION
  → SnackBar "Conversation vocale activée. Parlez, Bobodo vous répondra."
  → Bandeau: "Parlez maintenant" [🎤 bleu]
  → L'utilisateur parle

ÉCOUTE (utilisateur parle)
  → Bandeau: "Parlez maintenant" [🎤 bleu]
  → Contrôles: [❌ Quitter]

FIN D'ÉCOUTE (silence 3s détecté)
  → Bandeau: "Bobodo réfléchit..." [🧠 bleu]
  → Contrôles: [❌ Quitter]

BOBODO RÉPOND (TTS en cours)
  → Bandeau: "Bobodo parle..." [🔊 bleu]
  → Contrôles: [❌ Quitter] + [⏹ Couper]
  → L'utilisateur entend la voix

REPRISE (fin TTS)
  → Bandeau: "Parlez maintenant" [🎤 bleu]
  → Contrôles: [❌ Quitter]
  → L'utilisateur comprend que c'est son tour
```

### Bouton "Couper" pendant la lecture

| Attribut | Valeur |
|----------|--------|
| Icône | `Icons.stop` |
| Couleur | `PrepTheme.accent` |
| Label | "Couper" |
| Visibilité | Uniquement quand `_isSpeaking == true` |
| Action | Arrête la lecture TTS, passe à l'état "Parlez maintenant" |

Même traitement : remplacer l'IconButton par un `TextButton.icon` :
```dart
TextButton.icon(
  icon: Icon(Icons.stop, color: PrepTheme.accent, size: 18),
  label: Text('Couper', style: TextStyle(color: PrepTheme.accent, fontSize: 12)),
  onPressed: _cutBobodo,
)
```

---

## 3. DÉMONSTRATION DU PROBLÈME DU BOUTON ENVOYER

### Architecture du rendu

```
_StudentBobodoTabState.build()
  └─ Consumer<BobodoProvider>
       builder: (context, provider, child) {
         └─ _buildInputBar(provider)
              └─ _buildTextActionButtons(provider)
                   └─ IconButton(
                        onPressed: provider.isLoading || _controller.text.trim().isEmpty
                            ? null           // DÉSACTIVÉ
                            : () => _send()  // ACTIVÉ
                      )
       }
```

### Le problème

Le `Consumer<BobodoProvider>` builder est la **seule fonction** qui construit le bouton envoi. Il est invoqué UNIQUEMENT quand :

1. `BobodoProvider` appelle `notifyListeners()` → rebuild du Consumer
2. `setState()` est appelé sur `_StudentBobodoTabState` → rebuild de tout le `build()`

### Quand l'utilisateur tape du texte

```
Utilisateur tape "B" → "Bo" → "Bon" → "Bonj" → "Bonjour"

À chaque frappe :
  1. TextEditingController._value est mis à jour ✅
  2. TextField interne se reconstruit (affiche le texte) ✅
  3. _StudentBobodoTabState.setState() appelé ? ❌ NON
  4. Consumer rebuild ? ❌ NON
  5. onPressed réévalué ? ❌ NON
```

### Preuve par l'absence de listener

**Fichier** : `student_bobodo_tab.dart`  
**`initState()` lignes 118-132** :

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<BobodoProvider>().restoreLastSession();
  });
  _audioStreamController = StreamController<Uint8List>();
  _audioStreamController?.stream.listen(_onAudioData);
  _initRecorder();
  _connectVocalWebSocket();
  _initFlutterTts();
}
```

**Constats** :
- ❌ Pas de `_controller.addListener(...)`
- ❌ Pas de `_controller.addListener(() => setState(() {}))`
- ❌ Pas de mécanisme de rebuild sur changement de texte

**Comparaison avec le pattern Flutter standard** :

```dart
// Pattern correct (ce qui manque) :
@override
void initState() {
  super.initState();
  _controller.addListener(() => setState(() {}));
  // ...
}
```

### Scénario de reproduction confirmé

1. Ouvrir Bobodo (première fois ou après hot restart)
2. Le `build()` s'exécute → `_controller.text == ""` → `onPressed = null`
3. Taper "Bonjour" dans le champ
4. Le texte apparaît visuellement dans le TextField ✅
5. **MAIS** : aucun rebuild du Consumer n'a eu lieu
6. Le bouton envoi a toujours `onPressed = null` (fixé au dernier build)
7. L'utilisateur tape sur le bouton → **rien ne se passe**

### La correction : 1 ligne

```dart
_controller.addListener(() => setState(() {}));
```

Ajoutée dans `initState()`, cette ligne garantit qu'à chaque modification du texte, `setState()` est appelé → `build()` est relancé → la condition `_controller.text.trim().isEmpty` est réévaluée → le bouton passe de `null` à actif.

---

## 4. PROPOSITION UX — DIFFÉRENCIATION DES DEUX MICROS

### Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────┐
│ HEADER                                                      │
│ [🤖] Bobodo          [+💬] [⏰] [👤🔊] [📤]               │
│                              ↑                              │
│                       Micro conversation                    │
│                    (Icons.record_voice_over)                 │
│                    Tooltip: "Conversation vocale"            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [zone messages]                                            │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│ INPUT BAR                                                   │
│ [😀] [____Pose une question____] [🎤] [➤]                  │
│                                    ↑                        │
│                             Micro dictée                    │
│                           (Icons.mic)                       │
│                      Action: transcrit → champ              │
└─────────────────────────────────────────────────────────────┘
```

### Tableau comparatif

| Attribut | Micro BAS (dictée) | Micro HAUT (conversation) |
|----------|-------------------|--------------------------|
| **Position** | Zone de saisie, à gauche du bouton envoi | Header, entre Historique et Partager |
| **Icône** | `Icons.mic` | **`Icons.record_voice_over`** |
| **Couleur inactive** | `PrepTheme.primary` (bleu) | Blanc |
| **Couleur active** | — (passe en mode enregistrement) | `PrepTheme.primary` (bleu) |
| **Tooltip** | Aucun (implicite par position) | **"Conversation vocale"** / **"Arrêter la conversation"** |
| **Action** | Démarre STT → texte dans le champ | Toggle mode conversation continue |
| **Résultat** | Texte modifiable avant envoi | Envoi auto + réponse vocale + boucle |
| **Contrôle** | Boutons Stop/Annuler dans la zone | Bandeau + contrôles en bas |

### Pourquoi `Icons.record_voice_over` ?

| Icône | Signification visuelle | Approprié pour |
|-------|----------------------|---------------|
| `Icons.mic` | Microphone simple | Enregistrer/dicter |
| `Icons.mic_none` | Microphone éteint | Micro inactif |
| `Icons.record_voice_over` | Personne avec ondes sonores | **Conversation vocale** |

L'icône `record_voice_over` montre une silhouette humaine avec des ondes de parole. Elle évoque immédiatement un échange vocal bidirectionnel, par opposition à `mic` qui évoque un simple enregistrement unidirectionnel.

### Tooltips finaux

| État | Tooltip micro header |
|------|---------------------|
| Mode conversation inactif | "Conversation vocale" |
| Mode conversation actif | "Arrêter la conversation" |

---

## RÉCAPITULATIF COMPLET DES MODIFICATIONS

### Fichier unique : `student_bobodo_tab.dart`

| # | Zone | Modification | Lignes |
|---|------|-------------|--------|
| 1 | `initState()` | Ajouter `_controller.addListener(() => setState(() {}));` | +1 |
| 2 | Micro header (lignes 404-412) | `Icons.mic`/`Icons.mic_none` → `Icons.record_voice_over` | 2 modifiées |
| 3 | Tooltip header (ligne 410) | "Mode Dictée"/"Mode Conversation" → "Conversation vocale"/"Arrêter la conversation" | 1 modifiée |
| 4 | `_toggleVoiceMode()` | Ajouter SnackBar d'activation | +6 |
| 5 | `_buildConversationStateIndicator()` case listening | "Écoute..." → "Parlez maintenant" | 1 modifiée |
| 6 | `_buildConversationStateIndicator()` case playing | "Lecture..." → "Bobodo parle..." | 1 modifiée |
| 7 | `_buildConversationControls()` bouton Quitter | `IconButton` → `TextButton.icon` avec label "Quitter" | 4 modifiées |
| 8 | `_buildConversationControls()` bouton Couper | `IconButton` → `TextButton.icon` avec label "Couper" | 4 modifiées |

### Total

- **1 fichier**
- **~7 lignes ajoutées**
- **~13 lignes modifiées**
- **0 dépendances**
- **0 changement backend**
- **Risque régression : nul**

---

**En attente de validation V2 avant implémentation.**

*Aucune modification effectuée. Aucun commit.*
