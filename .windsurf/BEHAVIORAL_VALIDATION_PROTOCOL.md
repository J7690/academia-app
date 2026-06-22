# Protocole de Validation Comportementale - Parcours Import Vidéo

## Contexte

**Objectif**: Observer le comportement réel du parcours d'import vidéo sur appareil réel pour identifier les problèmes UX.

**Device**: TECNO LD7 (Android 10, API 29)
**APK**: app-debug.apk avec logs de timing

## Préparation

### Vidéos de Test

Préparer 3 vidéos de tailles différentes:
- **Cas 1**: Vidéo courte (~10 Mo)
- **Cas 2**: Vidéo moyenne (~50 Mo)
- **Cas 3**: Vidéo lourde (~150 Mo)

Les vidéos doivent être dans la galerie de l'appareil.

### Chronomètre

Avoir un chronomètre prêt pour mesurer les durées.

---

## Protocole de Test

### Pour chaque cas (10MB, 50MB, 150MB)

#### Étape 1: Démarrage

1. Ouvrir l'app Academia
2. Naviguer vers Challenge Feed
3. S'assurer que le feed Challenge a de l'audio actif
4. Noter l'état initial de l'audio

#### Étape 2: Import Vidéo

1. Cliquer sur le bouton "+"
2. Cliquer sur le bouton galerie (icône upload)
3. **DÉMARRER CHRONOMÈTRE**
4. Sélectionner la vidéo de test correspondante
5. **ARRÊTER CHRONOMÈTRE** (quand l'écran suivant apparaît)
6. Noter: **Temps Galerie → Écran Suivant**

#### Étape 3: Observation Écran Noir n°1

1. Observer l'écran qui apparaît après la sélection
2. **Écran noir n°1**: Existe-t-il ?
   - OUI / NON
3. Si OUI:
   - **DÉMARRER CHRONOMÈTRE** (apparition écran noir)
   - **ARRÊTER CHRONOMÈTRE** (disparition écran noir)
   - Noter: **Durée écran noir n°1**

#### Étape 4: Prévisualisation Vidéo

1. Attendre l'affichage de la prévisualisation vidéo
2. **DÉMARRER CHRONOMÈTRE** (fin écran noir n°1)
3. **ARRÊTER CHRONOMÈTRE** (apparition prévisualisation)
4. Noter: **Temps Écran Suivant → Prévisualisation**

#### Étape 5: Observation Écran Noir n°2

1. Observer après l'apparition de la prévisualisation
2. **Écran noir n°2**: Existe-t-il ?
   - OUI / NON
3. Si OUI:
   - **DÉMARRER CHRONOMÈTRE** (apparition écran noir)
   - **ARRÊTER CHRONOMÈTRE** (disparition écran noir)
   - Noter: **Durée écran noir n°2**

#### Étape 6: Activation Bouton Suivant

1. Attendre l'activation du bouton "Suivant"
2. **DÉMARRER CHRONOMÈTRE** (apparition prévisualisation)
3. **ARRÊTER CHRONOMÈTRE** (activation bouton Suivant)
4. Noter: **Temps Prévisualisation → Bouton Suivant**

#### Étape 7: Vérification Audio

1. Pendant tout le processus, observer l'audio du feed Challenge
2. **Audio persistant**: OUI / NON
3. Si OUI:
   - Noter: **Durée audio persistant**
   - À quel moment s'arrête-t-il ?

#### Étape 8: Vérification Réactivité UI

Pendant le chargement (entre galerie et activation bouton Suivant):

1. **Retour en arrière**: Peut-on cliquer sur le bouton retour ?
   - OUI / NON
2. **Annulation**: Peut-on annuler l'opération ?
   - OUI / NON
3. **Changement de vidéo**: Peut-on sélectionner une autre vidéo ?
   - OUI / NON
4. Noter: **État de réactivité UI**

---

## Grille de Collecte de Données

### Cas 1: Vidéo 10MB

| Mesure | Valeur | Notes |
|--------|--------|-------|
| Temps Galerie → Écran Suivant | ___ sec | |
| Écran noir n°1 | OUI / NON | |
| Durée écran noir n°1 | ___ sec | |
| Temps Écran Suivant → Prévisualisation | ___ sec | |
| Écran noir n°2 | OUI / NON | |
| Durée écran noir n°2 | ___ sec | |
| Temps Prévisualisation → Bouton Suivant | ___ sec | |
| Audio persistant | OUI / NON | |
| Durée audio persistant | ___ sec | |
| Réactivité UI (retour) | OUI / NON | |
| Réactivité UI (annulation) | OUI / NON | |
| Réactivité UI (changement vidéo) | OUI / NON | |

### Cas 2: Vidéo 50MB

| Mesure | Valeur | Notes |
|--------|--------|-------|
| Temps Galerie → Écran Suivant | ___ sec | |
| Écran noir n°1 | OUI / NON | |
| Durée écran noir n°1 | ___ sec | |
| Temps Écran Suivant → Prévisualisation | ___ sec | |
| Écran noir n°2 | OUI / NON | |
| Durée écran noir n°2 | ___ sec | |
| Temps Prévisualisation → Bouton Suivant | ___ sec | |
| Audio persistant | OUI / NON | |
| Durée audio persistant | ___ sec | |
| Réactivité UI (retour) | OUI / NON | |
| Réactivité UI (annulation) | OUI / NON | |
| Réactivité UI (changement vidéo) | OUI / NON | |

### Cas 3: Vidéo 150MB

| Mesure | Valeur | Notes |
|--------|--------|-------|
| Temps Galerie → Écran Suivant | ___ sec | |
| Écran noir n°1 | OUI / NON | |
| Durée écran noir n°1 | ___ sec | |
| Temps Écran Suivant → Prévisualisation | ___ sec | |
| Écran noir n°2 | OUI / NON | |
| Durée écran noir n°2 | ___ sec | |
| Temps Prévisualisation → Bouton Suivant | ___ sec | |
| Audio persistant | OUI / NON | |
| Durée audio persistant | ___ sec | |
| Réactivité UI (retour) | OUI / NON | |
| Réactivité UI (annulation) | OUI / NON | |
| Réactivité UI (changement vidéo) | OUI / NON | |

---

## Correspondance avec Logs T0→T8

Après les tests, corréler les observations avec les logs de timing:

| Étape UX | Log Timing Correspondant | Hypothèse |
|----------|------------------------|-----------|
| Galerie → Écran Suivant | T_GALLERY_START → T_GALLERY_END | Sélection galerie |
| Écran noir n°1 | T0 → T1 (début compression) | Compression |
| Écran Suivant → Prévisualisation | T2 → T5 (fin compression → init contrôleur) | Initialisation player |
| Écran noir n°2 | T5 → T6 (init contrôleur → setState) | Initialisation UI |
| Prévisualisation → Bouton Suivant | T6 → T7/T8 (setState → upload) | Upload |

---

## Livrable Attendu

### A. Résultat des 3 tests
- Grilles remplies pour les 3 cas

### B. Durée des écrans noirs
- Écran noir n°1: existence et durée pour chaque cas
- Écran noir n°2: existence et durée pour chaque cas

### C. Durée avant prévisualisation
- Temps Écran Suivant → Prévisualisation pour chaque cas

### D. Durée avant bouton Suivant
- Temps Prévisualisation → Bouton Suivant pour chaque cas

### E. État de l'audio
- Audio persistant: OUI/NON pour chaque cas
- Durée audio persistant pour chaque cas

### F. Correspondance avec les logs
- Tableau de corrélation étape UX ↔ log timing

### G. Conclusion
- Le parcours est-il acceptable pour un utilisateur moderne ?
  - OUI / NON
  - Justification détaillée
