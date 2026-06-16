# BOBODO — UX REALITY CHECK MODE VOCAL↔VOCAL

**Date** : 16 juin 2026  
**Objectif** : Validation UX sur device réel  
**Contrainte** : AUCUNE MODIFICATION, uniquement observation

---

## INSTRUCTIONS POUR L'UTILISATEUR

Ce rapport est un TEMPLATE à compléter après avoir testé l'app sur le device réel.

### Étapes à suivre

1. **Compiler l'app** sur le TECNO LD7 (ou device de test)
2. **Ouvrir l'onglet Bobodo**
3. **Activer le mode conversation vocale** (bouton microphone)
4. **Tester le flux complet** :
   - Parler
   - Envoyer le message
   - Attendre la réponse
   - Écouter la réponse
5. **Observer chaque écran** et prendre des captures
6. **Remplir le tableau PROMIS/VISIBLE/ABSENT** ci-dessous
7. **Classer les défauts UX observés** (P0/P1/P2/P3)

---

## MISSION 1 — ÉLÉMENTS UX PROMIS PAR LE CODE

### 1.1. Activation du mode conversation

**Code** : `student_bobodo_tab.dart:441`  
**Méthode** : `_toggleVoiceMode()`

**Éléments promis** :
- [ ] Bouton pour activer/désactiver le mode conversation
- [ ] SnackBar "Conversation vocale activée. Parlez, Bobodo vous répondra." (3 secondes)

**Emplacement** : AppBar, bouton microphone

---

### 1.2. Indicateur d'état de conversation

**Code** : `student_bobodo_tab.dart:1762`  
**Méthode** : `_buildConversationStateIndicator()`

**Éléments promis** (selon l'état) :

| État | Texte promis | Icône promis | Couleur promis |
|------|--------------|--------------|----------------|
| idle | "En attente" | hourglass_empty | textTertiary |
| listening | "Parlez maintenant" | mic | primary |
| processing | "✓ Message reçu" | check | success |
| thinking | "Bobodo réfléchit..." | psychology | primary |
| responding | "Réponse..." | chat | primary |
| playing | "Bobodo parle..." | volume_up | primary |
| paused | "Pause" | pause | accent |
| ended | "Session terminée" | check_circle | success |

**Élément supplémentaire** :
- [ ] Transcription partielle en temps réel (si listening et texte non vide)

---

### 1.3. Visuel d'écoute (listening)

**Code** : `student_bobodo_tab.dart:1892`  
**Méthode** : `_buildListeningVisual()`

**Éléments promis** :
- [ ] Point rouge (indicateur d'enregistrement)
- [ ] Durée d'enregistrement (format MM:SS)
- [ ] Texte "Enregistrement..."
- [ ] Grand cercle micro (56x56) avec icône mic
- [ ] Bouton ENVOYER (56x56) avec icône send
- [ ] Transcription en direct (centré, max 2 lignes)
- [ ] Texte "Parlez, Bobodo écoute..." (si transcription vide)

---

### 1.4. Visuel de réflexion (thinking)

**Code** : `student_bobodo_tab.dart:1991`  
**Méthode** : `_buildThinkingVisual()`

**Éléments promis** :
- [ ] CircularProgressIndicator (40x40)
- [ ] Texte "Bobodo réfléchit..."

---

### 1.5. Visuel de lecture (playing)

**Code** : `student_bobodo_tab.dart:2014`  
**Méthode** : `_buildPlayingVisual()`

**Éléments promis** :
- [ ] Cercle volume_up (64x64)
- [ ] Texte "Bobodo parle..."

---

### 1.6. Contrôles de conversation

**Code** : `student_bobodo_tab.dart:1846`  
**Méthode** : `_buildConversationControls()`

**Éléments promis** :
- [ ] Bouton "Quitter" (toujours visible, icône close, couleur danger)
- [ ] Bouton "Couper" (si Bobodo parle, icône stop, couleur accent)
- [ ] Bouton "Reprendre" (si en pause, icône play_arrow, couleur primary)

---

### 1.7. Transcription en temps réel

**Code** : `student_bobodo_tab.dart:1831-1840`

**Éléments promis** :
- [ ] Affichage de `_lastRecognizedWords` dans l'indicateur d'état
- [ ] Style : italic, 13px, max 2 lignes
- [ ] Affichage dans le visuel d'écoute (centré, 14px, italic)

---

## MISSION 2 — TABLEAU PROMIS / VISIBLE / ABSENT

### Instructions

Pour chaque élément promis ci-dessus, indiquer :
- **PROMIS** : OUI (déjà listé)
- **VISIBLE** : OUI/NON (après test sur device)
- **ABSENT** : OUI/NON (après test sur device)

### Tableau à compléter

| # | Élément UX | PROMIS | VISIBLE | ABSENT | Notes |
|---|------------|--------|---------|--------|-------|
| 1 | Bouton activation mode conversation | OUI | [ ] | [ ] | |
| 2 | SnackBar "Conversation vocale activée" | OUI | [ ] | [ ] | |
| 3 | Indicateur "En attente" (idle) | OUI | [ ] | [ ] | |
| 4 | Indicateur "Parlez maintenant" (listening) | OUI | [ ] | [ ] | |
| 5 | Indicateur "✓ Message reçu" (processing) | OUI | [ ] | [ ] | |
| 6 | Indicateur "Bobodo réfléchit..." (thinking) | OUI | [ ] | [ ] | |
| 7 | Indicateur "Réponse..." (responding) | OUI | [ ] | [ ] | |
| 8 | Indicateur "Bobodo parle..." (playing) | OUI | [ ] | [ ] | |
| 9 | Indicateur "Pause" (paused) | OUI | [ ] | [ ] | |
| 10 | Indicateur "Session terminée" (ended) | OUI | [ ] | [ ] | |
| 11 | Transcription partielle (indicateur état) | OUI | [ ] | [ ] | |
| 12 | Point rouge (enregistrement) | OUI | [ ] | [ ] | |
| 13 | Durée d'enregistrement | OUI | [ ] | [ ] | |
| 14 | Texte "Enregistrement..." | OUI | [ ] | [ ] | |
| 15 | Cercle micro (56x56) | OUI | [ ] | [ ] | |
| 16 | Bouton ENVOYER (56x56) | OUI | [ ] | [ ] | |
| 17 | Transcription en direct (visuel écoute) | OUI | [ ] | [ ] | |
| 18 | Texte "Parlez, Bobodo écoute..." | OUI | [ ] | [ ] | |
| 19 | CircularProgressIndicator (thinking) | OUI | [ ] | [ ] | |
| 20 | Cercle volume_up (64x64) | OUI | [ ] | [ ] | |
| 21 | Bouton "Quitter" | OUI | [ ] | [ ] | |
| 22 | Bouton "Couper" | OUI | [ ] | [ ] | |
| 23 | Bouton "Reprendre" | OUI | [ ] | [ ] | |

---

## MISSION 3 — DÉFAUTS UX OBSERVÉS

### Instructions

Après avoir testé l'app, classer les défauts observés selon la gravité :

- **P0** = Utilisateur bloqué (ne peut pas continuer)
- **P1** = Utilisateur perdu (ne comprend pas ce qui se passe)
- **P2** = Confort (UX améliorable mais fonctionnel)
- **P3** = Cosmétique (détail visuel mineur)

### Tableau à compléter

| # | Défaut UX observé | Gravité | Description | Écran |
|---|------------------|---------|-------------|-------|
| 1 | | P0/P1/P2/P3 | | |
| 2 | | P0/P1/P2/P3 | | |
| 3 | | P0/P1/P2/P3 | | |
| 4 | | P0/P1/P2/P3 | | |
| 5 | | P0/P1/P2/P3 | | |

---

## MISSION 4 — ANALYSE DES DÉFAUTS UX POTENTIELS (BASÉE SUR LE CODE)

### 4.1. Défauts UX potentiels identifiés par analyse code

| # | Défaut potentiel | Gravité estimée | Raison | Code |
|---|-----------------|-----------------|--------|------|
| 1 | SnackBar trop courte (3s) | P2 | L'utilisateur peut ne pas voir le message | ligne 1667 |
| 2 | Transcription max 2 lignes | P2 | Texte peut être tronqué si long | ligne 1837 |
| 3 | Pas de signal sonore | P2 | Pas de feedback audio pour transitions | - |
| 4 | Bouton ENVOYER pas évident | P1 | Peut être confondu avec autre bouton | ligne 1939 |
| 5 | État "responding" jamais utilisé | P3 | Code existe mais état non atteint | ligne 1790 |
| 6 | Pas de guide d'utilisation | P1 | Nouvel utilisateur ne sait pas comment utiliser | - |
| 7 | Transcription vide pas claire | P2 | "Parlez, Bobodo écoute..." peut être confus | ligne 1983 |

---

## MISSION 5 — PLAN UX MINIMAL RECOMMANDÉ

### 5.1. Objectif

Résoudre les défauts P0/P1 avec des modifications minimales.

### 5.2. Plan proposé (basé sur l'analyse code)

#### Option A : Améliorer la clarté du bouton ENVOYER

**Fichier** : `student_bobodo_tab.dart`  
**Ligne** : 1939-1961  
**Modification** : Ajouter un label text sous le bouton

```dart
// Ajouter sous le bouton ENVOYER
Text(
  'Envoyer',
  style: TextStyle(fontSize: 12, color: PrepTheme.primary),
),
```

**Impact** : P1 → Résolu

---

#### Option B : Augmenter la durée du SnackBar

**Fichier** : `student_bobodo_tab.dart`  
**Ligne** : 1667  
**Modification** : Changer 3s en 5s

```dart
duration: Duration(seconds: 5),
```

**Impact** : P2 → Résolu

---

#### Option C : Ajouter un guide d'utilisation

**Fichier** : `student_bobodo_tab.dart`  
**Ligne** : 1762 (dans `_buildConversationStateIndicator`)  
**Modification** : Ajouter un texte explicatif au premier lancement

```dart
if (_isFirstConversationMode) {
  Text(
    'Parlez, puis appuyez sur ➤ pour envoyer',
    style: TextStyle(fontSize: 12, color: PrepTheme.textSecondary),
  ),
}
```

**Impact** : P1 → Résolu

---

### 5.3. Plan UX minimal recommandé

**Fichier unique** : `student_bobodo_tab.dart`  
**Modifications** :
1. Ajouter label sous bouton ENVOYER (Option A)
2. Augmenter durée SnackBar à 5s (Option B)

**Impact** :
- Résout P1 (clarté bouton)
- Résout P2 (SnackBar trop courte)
- Modifications minimales (2 lignes)
- Aucun changement d'architecture

---

## LIVRABLE FINAL

### À compléter par l'utilisateur après test sur device

1. [ ] Remplir le tableau PROMIS/VISIBLE/ABSENT
2. [ ] Ajouter captures d'écran réelles
3. [ ] Classer les défauts UX observés
4. [ ] Valider ou ajuster le plan UX minimal

### Notes de test

- Device utilisé : ___________________
- Version Android : ___________________
- Date du test : ___________________
- Observations générales : ___________________
