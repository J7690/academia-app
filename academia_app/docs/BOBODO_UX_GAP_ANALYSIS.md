# BOBODO — UX GAP ANALYSIS

**Date** : 16 juin 2026  
**Objectif** : Analyse des écarts entre promesse code et réalité utilisateur  
**Source** : Constats utilisateur réels + analyse code

---

## MISSION 1 — SYNTHÈSE PROMESSE VS RÉALITÉ

### Ce qui a été promis par le code

#### Indicateurs d'état (8 états)

| État | Texte promis | Icône promis | Emplacement |
|------|--------------|--------------|-------------|
| idle | "En attente" | hourglass_empty | Indicateur d'état |
| listening | "Parlez maintenant" | mic | Indicateur d'état + visuel central |
| processing | "✓ Message reçu" | check | Indicateur d'état |
| thinking | "Bobodo réfléchit..." | psychology | Indicateur d'état + visuel central |
| responding | "Réponse..." | chat | Indicateur d'état |
| playing | "Bobodo parle..." | volume_up | Indicateur d'état + visuel central |
| paused | "Pause" | pause | Indicateur d'état |
| ended | "Session terminée" | check_circle | Indicateur d'état |

#### Visuels centraux

| État | Élément visuel promis |
|------|----------------------|
| listening | Point rouge, durée, cercle micro, bouton ENVOYER, transcription |
| thinking | CircularProgressIndicator |
| playing | Cercle volume_up |

#### Contrôles

| Contrôle | Condition promis |
|----------|------------------|
| Bouton "Quitter" | Toujours visible |
| Bouton "Couper" | Si Bobodo parle |
| Bouton "Reprendre" | Si en pause |

#### Transcription

- Affichage en temps réel dans l'indicateur d'état
- Affichage en temps réel dans le visuel d'écoute
- Max 2 lignes

### Ce qui a été observé par l'utilisateur

#### Constats factuels

1. **Le mode vocal↔vocal fonctionne** ✅
2. **Une réponse vocale a déjà été entendue** ✅

#### Problèmes de compréhension

1. **L'utilisateur ne comprend pas quand Bobodo écoute**
2. **L'utilisateur ne comprend pas quand l'écoute se termine**
3. **L'utilisateur ne comprend pas quand le message est envoyé**
4. **L'utilisateur ne comprend pas quand Bobodo réfléchit**
5. **L'utilisateur ne comprend pas quand Bobodo répond**
6. **L'utilisateur ne comprend pas quand il peut reprendre la parole**
7. **Les états visuels promis par le code ne sont pas clairement perçus**
8. **L'expérience donne l'impression que le système fonctionne "par hasard"**

### Contradictions identifiées

| Promis | Observé | Écart |
|--------|---------|-------|
| Indicateur "Parlez maintenant" | Utilisateur ne comprend pas quand Bobodo écoute | Indicateur non visible ou non clair |
| Indicateur "✓ Message reçu" | Utilisateur ne comprend pas quand le message est envoyé | Indicateur non visible ou non clair |
| Indicateur "Bobodo réfléchit..." | Utilisateur ne comprend pas quand Bobodo réfléchit | Indicateur non visible ou non clair |
| Indicateur "Bobodo parle..." | Utilisateur ne comprend pas quand Bobodo répond | Indicateur non visible ou non clair |
| Bouton ENVOYER | Utilisateur ne comprend pas quand l'écoute se termine | Bouton non évident |
| Transition listening → thinking | Utilisateur ne comprend pas quand il peut reprendre la parole | Transition non claire |

---

## MISSION 2 — TABLEAU PROMIS PAR LE CODE / OBSERVÉ PAR L'UTILISATEUR / ÉCART

| # | Élément UX | PROMIS PAR LE CODE | OBSERVÉ PAR L'UTILISATEUR | ÉCART |
|---|------------|-------------------|---------------------------|-------|
| 1 | Indicateur "Parlez maintenant" | OUI (listening) | NON (ne comprend pas quand Bobodo écoute) | Indicateur non perçu |
| 2 | Indicateur "✓ Message reçu" | OUI (processing) | NON (ne comprend pas quand message envoyé) | Indicateur non perçu |
| 3 | Indicateur "Bobodo réfléchit..." | OUI (thinking) | NON (ne comprend pas quand Bobodo réfléchit) | Indicateur non perçu |
| 4 | Indicateur "Bobodo parle..." | OUI (playing) | NON (ne comprend pas quand Bobodo répond) | Indicateur non perçu |
| 5 | Bouton ENVOYER | OUI (cercle avec icône send) | NON (ne comprend pas quand écoute se termine) | Bouton non évident |
| 6 | Transition listening → thinking | OUI (automatique après envoi) | NON (ne comprend pas quand reprendre parole) | Transition non claire |
| 7 | Transcription en temps réel | OUI (2 emplacements) | NON (non mentionné comme perçu) | Transcription non perçue |
| 8 | Bouton "Quitter" | OUI (toujours visible) | NON (non mentionné comme perçu) | Bouton non perçu |
| 9 | SnackBar activation | OUI ("Conversation vocale activée") | NON (non mentionné comme perçu) | SnackBar non perçue |

---

## MISSION 3 — PROBLÈMES UX QUI EMPÊCHENT LA COMPRÉHENSION

### Problème 1 : Indicateurs d'état non visibles

**Description** : Les indicateurs d'état ("Parlez maintenant", "✓ Message reçu", "Bobodo réfléchit...", "Bobodo parle...") existent dans le code mais ne sont pas clairement perçus par l'utilisateur.

**Impact** : L'utilisateur ne sait pas ce qui se passe à chaque étape de la conversation.

**Cause probable** :
- Indicateur trop petit ou mal positionné
- Couleur ou contraste insuffisant
- Texte trop court ou non explicite
- Indicateur masqué par d'autres éléments

---

### Problème 2 : Bouton ENVOI non évident

**Description** : Le bouton ENVOI (cercle avec icône send) existe mais l'utilisateur ne comprend pas quand l'écoute se termine et comment envoyer le message.

**Impact** : L'utilisateur ne sait pas quand et comment envoyer son message.

**Cause probable** :
- Bouton sans label textuel
- Bouton confondu avec autre élément
- Pas d'instruction claire "Appuyez sur ➤ pour envoyer"

---

### Problème 3 : Transitions d'état non signalées

**Description** : Les transitions entre les états (listening → processing → thinking → playing) ne sont pas clairement signalées.

**Impact** : L'utilisateur ne comprend pas quand il peut reprendre la parole.

**Cause probable** :
- Pas de signal visuel distinct pour chaque transition
- Pas de signal sonore
- Transitions trop rapides ou subtiles

---

### Problème 4 : Absence de guide d'utilisation

**Description** : Aucun guide ou instruction n'explique comment utiliser le mode conversation.

**Impact** : L'utilisateur découvre le système par essai-erreur, donnant l'impression que cela fonctionne "par hasard".

**Cause probable** :
- Pas de tutoriel ou onboarding
- Pas de texte explicatif au premier lancement
- SnackBar trop courte (3s)

---

### Problème 5 : Transcription non perçue

**Description** : La transcription en temps réel existe dans le code mais n'est pas mentionnée comme perçue par l'utilisateur.

**Impact** : L'utilisateur ne voit pas ce que Bobodo a compris de sa parole.

**Cause probable** :
- Transcription mal positionnée
- Transcription trop petite
- Transcription tronquée (max 2 lignes)

---

## MISSION 4 — CLASSIFICATION DES PROBLÈMES UX

| # | Problème | Gravité | Justification |
|---|----------|---------|---------------|
| 1 | Indicateurs d'état non visibles | **P1** | Utilisateur ne comprend pas ce qui se passe |
| 2 | Bouton ENVOI non évident | **P1** | Utilisateur ne sait pas comment envoyer |
| 3 | Transitions d'état non signalées | **P1** | Utilisateur ne sait pas quand reprendre parole |
| 4 | Absence de guide d'utilisation | **P1** | Utilisateur découvre par essai-erreur |
| 5 | Transcription non perçue | **P2** | Utilisateur comprend mais avec effort |

---

## MISSION 5 — TOP 5 CORRECTIONS UX

### Correction 1 : Rendre l'indicateur d'état massif et explicite

**Fichier** : `student_bobodo_tab.dart`  
**Méthode** : `_buildConversationStateIndicator()`  
**Ligne** : 1762-1844

**Modification** :
- Augmenter la taille de l'indicateur (padding, taille de texte)
- Ajouter un fond coloré plus visible
- Ajouter un texte explicite plus long
- Positionner l'indicateur en haut de l'écran (plus visible)

**Impact** : P1 → Résolu (utilisateur comprend ce qui se passe)

---

### Correction 2 : Ajouter un label textuel sous le bouton ENVOI

**Fichier** : `student_bobodo_tab.dart`  
**Méthode** : `_buildListeningVisual()`  
**Ligne** : 1939-1961

**Modification** :
- Ajouter le texte "ENVOYER" sous le bouton
- Augmenter la taille du bouton
- Ajouter une animation pulse pour attirer l'attention

**Impact** : P1 → Résolu (utilisateur sait comment envoyer)

---

### Correction 3 : Ajouter un signal sonore pour chaque transition

**Fichier** : `student_bobodo_tab.dart`  
**Méthode** : `_onTranscriptionReceived()`, `_onAudioPlaybackComplete()`  
**Ligne** : 1468, 1715

**Modification** :
- Ajouter un bip court quand l'état change
- Ajouter un bip distinct quand Bobodo commence/arrête de parler
- Utiliser `AudioPlayer` pour jouer des sons courts

**Impact** : P1 → Résolu (utilisateur comprend les transitions)

---

### Correction 4 : Ajouter un guide d'utilisation au premier lancement

**Fichier** : `student_bobodo_tab.dart`  
**Méthode** : `_toggleVoiceMode()`  
**Ligne** : 1654

**Modification** :
- Ajouter un dialog explicatif au premier lancement
- Expliquer : "Parlez, puis appuyez sur ➤ pour envoyer"
- Ajouter un bouton "Compris" pour fermer le dialog
- Stocker un flag pour ne pas afficher le dialog au prochain lancement

**Impact** : P1 → Résolu (utilisateur sait comment utiliser)

---

### Correction 5 : Améliorer la visibilité de la transcription

**Fichier** : `student_bobodo_tab.dart`  
**Méthode** : `_buildListeningVisual()`  
**Ligne** : 1966-1980

**Modification** :
- Augmenter la taille du texte de transcription
- Augmenter le nombre de lignes (max 4 au lieu de 2)
- Ajouter un fond coloré pour la transcription
- Positionner la transcription plus haut

**Impact** : P2 → Résolu (utilisateur voit ce que Bobodo a compris)

---

## PRIORITÉ D'EXÉCUTION

### Ordre recommandé

1. **Correction 2** (Bouton ENVOI) - Plus critique, résout le blocage principal
2. **Correction 1** (Indicateur d'état) - Améliore la compréhension globale
3. **Correction 4** (Guide d'utilisation) - Évite la confusion des nouveaux utilisateurs
4. **Correction 3** (Signal sonore) - Améliore les transitions
5. **Correction 5** (Transcription) - Amélioration de confort

### Résumé

**Fichier unique** : `student_bobodo_tab.dart`  
**Modifications** : 5 corrections ciblées  
**Impact** : Résout tous les problèmes P1 + P2 identifiés  
**Complexité** : Faible (modifications UI uniquement, pas d'architecture)
