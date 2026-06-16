# Validation 1 - Maquette Fonctionnelle Zone de Saisie Vocale

## Mode Texte (État IDLE)

```
┌─────────────────────────────────────────────────────────────────┐
│  [😊]  ┌──────────────────────────────────────────────────┐  [📤] │
│       │ Pose une question à Bobodo...                      │       │
│       └──────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

**Composants** :
- Bouton emoji (toggle emoji picker)
- Champ texte (TextField)
- Bouton micro (toggle mode vocal)
- Bouton envoi (gradient circle)

**Actions** :
- Tap emoji → Ouvre/ferme emoji picker
- Tap champ → Focus clavier
- Tap micro → Passe en mode vocal
- Tap envoi → Envoie message texte

---

## Mode Vocal - Enregistrement (État RECORDING)

```
┌─────────────────────────────────────────────────────────────────┐
│  [😊]  ┌──────────────────────────────────────────────────┐  [❌] │
│       │  ▂▃▅▆▇▆▅▃▂  ▂▃▅▆▇▆▅▃▂  ▂▃▅▆▇▆▅▃▂                │       │
│       │           Ondulations audio (animation)             │       │
│       │                                                       │
│       │              00:12                                   │
│       │         Durée d'enregistrement                       │
│       └──────────────────────────────────────────────────┘  [⏹] │
└─────────────────────────────────────────────────────────────────┘
```

**Composants** :
- Bouton emoji (désactivé/grisé)
- Zone vocale (remplace champ texte)
  - Animation ondulations audio (3-5 barres animées)
  - Durée d'enregistrement (format MM:SS)
- Bouton annuler (X)
- Bouton stop (carré)

**Actions** :
- Tap annuler → Supprime audio, retour mode texte
- Tap stop → Arrête enregistrement, lance transcription

**Visuel** :
- Fond de la zone vocale : légèrement différent du fond normal (ex: PrepTheme.primary.withAlpha(0.05))
- Ondulations : animation continue avec amplitude basée sur niveau audio
- Durée : texte centré, taille 16-18px, gras
- Boutons : icônes claires, fond distinctif

---

## Mode Vocal - Transcription (État TRANSCRIBING)

```
┌─────────────────────────────────────────────────────────────────┐
│  [😊]  ┌──────────────────────────────────────────────────┐  [❌] │
│       │                                                       │
│       │        ⏳ Transcription en cours...                  │
│       │                                                       │
│       │        [Spinner circulaire]                          │
│       │                                                       │
│       └──────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

**Composants** :
- Bouton emoji (désactivé/grisé)
- Zone vocale
  - Texte "Transcription en cours..."
  - Spinner circulaire
- Bouton annuler (X)
- Bouton envoi (désactivé/grisé)

**Actions** :
- Tap annuler → Annule transcription, retour mode texte

**Visuel** :
- Spinner : CircularProgressIndicator
- Texte : centré, couleur secondaire

---

## Mode Édition (État EDITING)

```
┌─────────────────────────────────────────────────────────────────┐
│  [😊]  ┌──────────────────────────────────────────────────┐  [📤] │
│       │ Bonjour Bobodo, comment vas-tu ?                    │       │
│       │ [curseur clignotant]                                 │       │
│       └──────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

**Composants** :
- Bouton emoji (actif)
- Champ texte (TextField) avec transcription injectée
- Bouton micro (actif)
- Bouton envoi (actif)

**Actions** :
- Identique au mode texte normal
- L'utilisateur peut éditer, supprimer, compléter le texte

**Visuel** :
- Identique au mode texte
- Aucune distinction visuelle entre texte saisi et texte dicté

---

## Mode Envoi (État SENDING)

```
┌─────────────────────────────────────────────────────────────────┐
│  [😊]  ┌──────────────────────────────────────────────────┐  [⏳] │
│       │ Bonjour Bobodo, comment vas-tu ?                    │       │
│       └──────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

**Composants** :
- Bouton emoji (désactivé)
- Champ texte (lecture seule ou désactivé)
- Bouton micro (désactivé)
- Bouton envoi (remplacé par spinner)

**Actions** :
- Aucune action possible pendant envoi

**Visuel** :
- Champ texte : légèrement grisé
- Bouton envoi : CircularProgressIndicator

---

## Mode Lecture Audio (État SPEAKING)

```
┌─────────────────────────────────────────────────────────────────┐
│  [😊]  ┌──────────────────────────────────────────────────┐  [🔊] │
│       │ Bonjour Bobodo, comment vas-tu ?                    │       │
│       └──────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

**Composants** :
- Bouton emoji (actif)
- Champ texte (actif)
- Bouton micro (actif)
- Bouton envoi (remplacé par icône haut-parleur animé)

**Actions** :
- Tap haut-parleur → Pause/Reprise lecture audio

**Visuel** :
- Icône haut-parleur : animation (ondulations sonores)
- Indicateur de lecture active

---

## Spécifications Techniques

### Animation Ondulations Audio

**Implémentation** :
- 3-5 barres verticales
- Hauteur variable basée sur niveau audio (0-100%)
- Animation fluide (60fps)
- Couleur : PrepTheme.primary

**Widget Flutter** :
```dart
AnimatedBuilder(
  animation: _audioLevelAnimation,
  builder: (context, child) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final height = _audioLevels[index] * 40.0; // max 40px
        return Container(
          width: 4,
          height: height,
          margin: EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: PrepTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  },
)
```

### Timer Durée

**Format** : MM:SS

**Implémentation** :
```dart
Timer.periodic(Duration(seconds: 1), (timer) {
  setState(() {
    _recordingDuration = Duration(seconds: _recordingDuration.inSeconds + 1);
  });
});
```

### Boutons

**Bouton Annuler** :
- Icône : Icons.close
- Couleur : PrepTheme.danger
- Fond : transparent
- Action : Annuler enregistrement

**Bouton Stop** :
- Icône : Icons.stop
- Couleur : Colors.white
- Fond : PrepTheme.primary (circle)
- Action : Arrêter et transcrire

**Bouton Micro** :
- Icône : Icons.mic
- Couleur : PrepTheme.primary (actif) / PrepTheme.textTertiary (inactif)
- Fond : transparent
- Action : Passer en mode vocal

---

## Contraintes Respectées

✅ **Validation 1 - Aucun envoi automatique** : Bouton envoi manuel uniquement
✅ **Validation 2 - Transcription = texte normal** : Même TextEditingController
✅ **Validation 3 - Aucune duplication d'interface** : Une seule zone de saisie
✅ **Validation 4 - Visualisation audio** : Ondulations + durée + niveau
✅ **Validation 5 - Boutons obligatoires** : [Annuler] [Stop] pendant enregistrement
