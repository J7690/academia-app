# BOBODO VOICE - UX Final Audit

## Date
12 Juin 2026

---

## OBJECTIF

Auditer l'UX pour les deux modes : MODE DICTÉE et MODE CONVERSATION. Documenter l'emplacement, la navigation, les transitions, les maquettes et les composants Flutter réels à modifier.

---

## ARCHITECTURE UX ACTUELLE (CODE RÉEL)

### Source de vérité analysée

**Flutter** :
- `academia_app/lib/features/student/tabs/student_bobodo_tab.dart` (1584 lignes)

---

## UX ACTUELLE (MODE DICTÉE UNIQUE)

### Emplacement

**Onglet Bobodo** :
- Navigation : `StudentBobodoTab`
- Position : Onglet principal de l'app

---

### Interface actuelle

#### Header (lignes 284-356)

**Composants** :
- Avatar Bobodo (icône smart_toy)
- Titre "Bobodo"
- Sous-titre "Assistant Academia" / "En train de réfléchir..."
- Bouton "Nouvelle conversation" (add_comment_outlined)
- Bouton "Historique" (history)
- Bouton "Partager" (share)

---

#### Input bar (lignes 898-950)

**Composants** :
- Bouton emoji (emoji_emotions_outlined / keyboard)
- Zone de saisie (TextField)
- Bouton micro (mic)
- Bouton envoi (send)

**Code** (lignes 988-1030) :
```dart
Widget _buildTextActionButtons(BobodoProvider provider) {
  return Row(
    children: [
      // Bouton micro
      IconButton(
        icon: Icon(
          Icons.mic,
          color: PrepTheme.primary,
          size: 22,
        ),
        onPressed: _startVocalRecording,
      ),
      const SizedBox(width: 4),
      // Bouton envoi
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: PrepTheme.headerGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.send, color: Colors.white, size: 18),
          padding: EdgeInsets.zero,
          onPressed: provider.isLoading || _controller.text.trim().isEmpty
              ? null
              : () => _send(context),
        ),
      ),
    ],
  );
}
```

---

#### Interface vocale (lignes 1032-1128)

**Composants** :
- Waveform animation (lignes 1063-1079)
- Durée d'enregistrement (lignes 1050-1057)
- Indicateur "Transcription en cours..." (lignes 1081-1099)
- Bouton annuler (close)
- Bouton stop (stop)

**Code** (lignes 1101-1128) :
```dart
Widget _buildVocalActionButtons() {
  return Row(
    children: [
      // Bouton annuler
      IconButton(
        icon: const Icon(Icons.close, size: 22),
        color: PrepTheme.danger,
        onPressed: _cancelVocalRecording,
      ),
      const SizedBox(width: 4),
      // Bouton stop
      if (_isRecording)
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: PrepTheme.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.stop, color: Colors.white, size: 18),
            padding: EdgeInsets.zero,
            onPressed: _stopVocalRecording,
          ),
        ),
    ],
  );
}
```

---

#### Contrôles TTS (lignes 738-767)

**Composants** :
- Bouton stop (stop_circle_outlined) - pendant lecture
- Bouton replay (play_circle_outline) - après lecture
- Bouton volume (volume_up / volume_off) - toggle auto TTS

**Code** (lignes 738-767) :
```dart
// TTS controls for bot messages
if (!isUser && _isSpeaking) ...[
  const SizedBox(width: 2),
  _FeedbackButton(
    icon: Icons.stop_circle_outlined,
    isActive: false,
    isUser: isUser,
    onTap: _stopAudioPlayback,
  ),
],
if (!isUser && !_isSpeaking && _lastAudioResponse != null) ...[
  const SizedBox(width: 2),
  _FeedbackButton(
    icon: Icons.play_circle_outline,
    isActive: false,
    isUser: isUser,
    onTap: _replayAudio,
  ),
],
if (!isUser) ...[
  const SizedBox(width: 2),
  _FeedbackButton(
    icon: _autoTtsEnabled
        ? Icons.volume_up
        : Icons.volume_off,
    isActive: _autoTtsEnabled,
    isUser: isUser,
    onTap: _toggleAutoTts,
  ),
],
```

---

## UX CIBLE : DEUX MODES DISTINCTS

### MODE DICTÉE (existant - à conserver)

**Objectif** : Dictée vocale avec édition

**Emplacement** :
- Onglet Bobodo (inchangé)

**Interface** :
- Bouton micro (inchangé)
- Bouton envoi (inchangé)
- TextField éditable (inchangé)
- Contrôles TTS (inchangé)

**Flux** :
- User clique micro → enregistre → stop → transcription → édite → envoi → réponse → TTS optionnel

**Cas d'usage** :
- Messages longs nécessitant édition
- Questions complexes nécessitant reformulation
- Utilisateurs préférant contrôle manuel

---

### MODE CONVERSATION (nouveau - à créer)

**Objectif** : Conversation fluide type ChatGPT Voice

**Emplacement** :
- Bouton dédié dans le header
- OU bouton flottant (FAB)
- OU onglet séparé

**Interface** :
- Bouton "Conversation vocale" dédié
- Indicateur visuel du mode actif
- Bouton "Arrêter la conversation"
- Contrôles TTS (inchangés)

**Flux** :
- User clique "Conversation vocale" → micro actif
- User parle → stop → transcription → envoi automatique → réponse → TTS automatique → micro réactif
- Cycle continu sans clics

**Cas d'usage** :
- Questions rapides
- Navigation naturelle
- Utilisateurs préférant fluidité

---

## OPTIONS D'EMPLACEMENT

### Option 1 : Bouton dans le header

**Emplacement** : À côté du bouton "Nouvelle conversation"

**Avantages** :
- Visible
- Accessible
- Cohérent avec l'interface actuelle

**Inconvénients** :
- Header déjà chargé
- Peut être confus avec "Nouvelle conversation"

**Code cible** :
```dart
// Header (lignes 333-353)
IconButton(
  icon: const Icon(Icons.mic_none_outlined, color: Colors.white, size: 20),
  tooltip: 'Conversation vocale',
  onPressed: _toggleConversationMode,
),
```

---

### Option 2 : Bouton flottant (FAB)

**Emplacement** : En bas à droite de l'écran

**Avantages** :
- Très visible
- Ne surcharge pas le header
- Accessible en permanence

**Inconvénients** :
- Peut gêner la lecture
- Peut être confus avec d'autres FABs

**Code cible** :
```dart
// Stack dans build()
Stack(
  children: [
    // ... contenu existant
    Positioned(
      right: 16,
      bottom: 80,
      child: FloatingActionButton(
        heroTag: 'conversation_mode',
        onPressed: _toggleConversationMode,
        child: Icon(
          _isConversationMode ? Icons.mic : Icons.mic_none,
        ),
      ),
    ),
  ],
)
```

---

### Option 3 : Onglet séparé

**Emplacement** : Nouvel onglet "Conversation" à côté de Bobodo

**Avantages** :
- Séparation claire des modes
- Pas de confusion
- Interface dédiée

**Inconvénients** :
- Navigation supplémentaire
- Duplication du code
- Plus complexe à maintenir

**Code cible** :
```dart
// Navigation (main.dart)
'/conversation': (context) => const StudentConversationTab(),
```

---

## RECOMMANDATION UX

### Option recommandée : Option 1 (Bouton dans le header)

**Justification** :
- Visible
- Accessible
- Cohérent avec l'interface actuelle
- Simple à implémenter
- Pas de duplication de code

---

## TRANSITIONS UX

### Transition DICTÉE → CONVERSATION

**Action** : User clique "Conversation vocale"

**Transitions UI** :
1. Bouton "Conversation vocale" devient actif (icon rempli)
2. Bouton micro disparaît (remplacé par indicateur)
3. TextField devient readonly (mode conversation)
4. Bouton envoi disparaît (envoi automatique)
5. Indicateur "Micro actif" apparaît
6. Bouton "Arrêter la conversation" apparaît

**Transitions d'état** :
```
IDLE → LISTENING
```

---

### Transition CONVERSATION → DICTÉE

**Action** : User clique "Arrêter la conversation"

**Transitions UI** :
1. Bouton "Conversation vocale" devient inactif (icon outline)
2. Bouton micro réapparaît
3. TextField devient éditable
4. Bouton envoi réapparaît
5. Indicateur "Micro actif" disparaît
6. Bouton "Arrêter la conversation" disparaît

**Transitions d'état** :
```
LISTENING → IDLE
```

---

## INDICATEURS VISUELS

### Mode conversation actif

**Indicateur 1 : Header**
- Bouton "Conversation vocale" avec icon rempli
- Couleur : PrepTheme.primary

**Indicateur 2 : Input bar**
- Remplacement du TextField par indicateur
- Texte : "Micro actif - Parlez pour continuer"
- Animation : pulsation du micro

**Indicateur 3 : Waveform**
- Waveform animation quand micro actif
- Couleur : PrepTheme.primary

**Code cible** :
```dart
Widget _buildConversationIndicator() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: PrepTheme.primary.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: PrepTheme.primary.withValues(alpha: 0.2)),
    ),
    child: Row(
      children: [
        Icon(
          Icons.mic,
          color: PrepTheme.primary,
          size: 20,
        ),
        const SizedBox(width: 8),
        const Text(
          'Micro actif - Parlez pour continuer',
          style: TextStyle(
            fontSize: 14,
            color: PrepTheme.primary,
          ),
        ),
      ],
    ),
  );
}
```

---

### Mode dictée actif

**Indicateur 1 : Header**
- Bouton "Conversation vocale" avec icon outline
- Couleur : Colors.white

**Indicateur 2 : Input bar**
- TextField éditable
- Bouton micro
- Bouton envoi

---

## COMPOSANTS FLUTTER À MODIFIER

### 1. Header (student_bobodo_tab.dart)

**Modifications** :
- Ajouter bouton "Conversation vocale"
- Ajouter état `_isConversationMode`
- Ajouter méthode `_toggleConversationMode()`

**Code cible** :
```dart
// Header (lignes 333-353)
IconButton(
  icon: Icon(
    _isConversationMode ? Icons.mic : Icons.mic_none_outlined,
    color: _isConversationMode ? PrepTheme.primary : Colors.white,
    size: 20,
  ),
  tooltip: _isConversationMode ? 'Arrêter la conversation' : 'Conversation vocale',
  onPressed: _toggleConversationMode,
),

void _toggleConversationMode() {
  setState(() {
    _isConversationMode = !_isConversationMode;
    if (_isConversationMode) {
      _startVocalRecording();
    } else {
      _cancelVocalRecording();
    }
  });
}
```

---

### 2. Input bar (student_bobodo_tab.dart)

**Modifications** :
- Conditionner l'affichage sur `_isConversationMode`
- Remplacer TextField par indicateur en mode conversation
- Masquer bouton envoi en mode conversation

**Code cible** :
```dart
// Input bar (lignes 936-940)
Expanded(
  child: _isConversationMode
      ? _buildConversationIndicator()
      : _buildTextInputInterface(),
),

// Text action buttons (lignes 943-945)
_isRecordingMode
    ? _buildVocalActionButtons()
    : _isConversationMode
        ? const SizedBox.shrink() // Pas de bouton envoi en mode conversation
        : _buildTextActionButtons(provider),
```

---

### 3. Interface vocale (student_bobodo_tab.dart)

**Modifications** :
- Conditionner l'envoi automatique sur `_isConversationMode`
- Modifier `_onTranscriptionReceived()`

**Code cible** :
```dart
// Transcription received (lignes 1272-1282)
void _onTranscriptionReceived(String text) {
  setState(() {
    _isTranscribing = false;
    _isRecordingMode = false;
  });

  if (_isConversationMode) {
    // Envoi automatique en mode conversation
    final provider = context.read<BobodoProvider>();
    provider.sendUserMessage(text);
  } else {
    // Édition en mode dictée
    _controller.text = text;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
  }
}
```

---

### 4. TTS controls (student_bobodo_tab.dart)

**Modifications** :
- Conditionner la réactivation automatique sur `_isConversationMode`
- Modifier `onPlayerComplete`

**Code cible** :
```dart
// Audio response received (lignes 1295-1297)
_audioPlayer.onPlayerComplete.listen((_) {
  if (!mounted) return;
  
  setState(() => _isSpeaking = false);
  
  if (_isConversationMode) {
    try {
      _startVocalRecording(); // Réactivation automatique
    } catch (e) {
      debugPrint('[VOICE_AUTO_LISTEN_ERROR] $e');
      setState(() => _vocalState = VocalState.error);
    }
  }
});
```

---

## MAQUETTES

### Mode dictée (actuel - inchangé)

```
┌─────────────────────────────────────────────────────────────┐
│ [🤖] Bobodo            [+] [📜] [🔗]                      │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Messages...                                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│ [😊] [TextField................] [🎤] [➤]               │
└─────────────────────────────────────────────────────────────┘
```

---

### Mode conversation (nouveau)

```
┌─────────────────────────────────────────────────────────────┐
│ [🤖] Bobodo            [🎤] [+] [📜] [🔗]              │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Messages...                                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│ [😊] [🎤 Micro actif - Parlez pour continuer] [⏹]       │
└─────────────────────────────────────────────────────────────┘
```

---

## ONBOARDING

### Premier lancement du mode conversation

**Message** :
```
Mode conversation activé

Bobodo écoute en continu. Parlez pour poser vos questions.
Cliquez sur ⏹ pour arrêter la conversation.
```

**Actions** :
- Afficher un SnackBar ou AlertDialog
- Expliquer le fonctionnement
- Proposer de désactiver

**Code cible** :
```dart
void _toggleConversationMode() {
  setState(() {
    _isConversationMode = !_isConversationMode;
    if (_isConversationMode) {
      _showConversationOnboarding();
      _startVocalRecording();
    } else {
      _cancelVocalRecording();
    }
  });
}

void _showConversationOnboarding() {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text(
        'Mode conversation activé. Bobodo écoute en continu. Cliquez sur ⏹ pour arrêter.',
      ),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Compris',
        onPressed: () {},
      ),
    ),
  );
}
```

---

## ACCESSIBILITÉ

### Screen reader

**Mode dictée** :
- Bouton micro : "Mode dictée vocale"
- TextField : "Saisir votre message"
- Bouton envoi : "Envoyer le message"

**Mode conversation** :
- Bouton conversation : "Mode conversation vocale"
- Indicateur : "Micro actif, parlez pour continuer"
- Bouton arrêt : "Arrêter la conversation"

**Code cible** :
```dart
Semantics(
  label: _isConversationMode ? 'Mode conversation vocale' : 'Mode dictée vocale',
  hint: _isConversationMode ? 'Bobodo écoute en continu' : 'Cliquez pour enregistrer',
  child: IconButton(
    icon: Icon(
      _isConversationMode ? Icons.mic : Icons.mic_none_outlined,
    ),
    onPressed: _toggleConversationMode,
  ),
)
```

---

## TESTS UX

### Tests fonctionnels

1. **Transition dictée → conversation**
   - Cliquer sur bouton "Conversation vocale"
   - Vérifier que le bouton devient actif
   - Vérifier que le TextField disparaît
   - Vérifier que l'indicateur apparaît
   - Vérifier que le micro s'active

2. **Transition conversation → dictée**
   - Cliquer sur bouton "Arrêter la conversation"
   - Vérifier que le bouton devient inactif
   - Vérifier que le TextField réapparaît
   - Vérifier que l'indicateur disparaît
   - Vérifier que le micro s'arrête

3. **Envoi automatique**
   - Activer mode conversation
   - Parler → stop
   - Vérifier que la transcription s'envoie automatiquement
   - Vérifier que le TextField n'apparaît pas

4. **Réactivation automatique**
   - Activer mode conversation
   - Parler → stop → transcription → envoi
   - Attendre TTS terminé
   - Vérifier que le micro se réactive automatiquement

### Tests UX

5. **Indicateur visuel**
   - Vérifier que l'indicateur est clair
   - Vérifier que l'animation est fluide
   - Vérifier que le texte est lisible

6. **Onboarding**
   - Vérifier que le message est clair
   - Vérifier que l'utilisateur comprend
   - Vérifier que l'utilisateur peut fermer

7. **Accessibilité**
   - Vérifier que le screen reader fonctionne
   - Vérifier que les labels sont corrects
   - Vérifier que les hints sont utiles

---

## CONCLUSION

### UX actuelle

**Mode dictée unique** :
- Bouton micro dans l'input bar
- TextField éditable
- Bouton envoi
- Contrôles TTS

**Limitations** :
- Pas de mode conversation
- Pas de distinction UI
- Pas d'indicateur de mode

---

### UX cible

**Deux modes distincts** :
- Mode dictée (existant - inchangé)
- Mode conversation (nouveau - à créer)

**Mode conversation** :
- Bouton dédié dans le header
- Indicateur visuel clair
- Bouton "Arrêter la conversation"
- Réactivation automatique du micro
- Envoi automatique de la transcription

---

### Recommandation

**Implémenter Option 1 (Bouton dans le header)**

**Justification** :
- Visible
- Accessible
- Cohérent avec l'interface actuelle
- Simple à implémenter
- Pas de duplication de code

**Composants à modifier** :
1. Header (ajouter bouton "Conversation vocale")
2. Input bar (conditionner affichage)
3. Interface vocale (envoi automatique)
4. TTS controls (réactivation automatique)

---

## LIVRABLE FINAL

1. BOBODO_FULL_VOICE_CONVERSATION_ARCHITECTURE.md
