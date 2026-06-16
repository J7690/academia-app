# BOBODO — PRÉPARATION DU PATCH UX FINAL

**Date** : 16 juin 2026  
**Objectif** : Préparer la liste exacte des changements UX  
**Contrainte** : AUCUNE IMPLÉMENTATION, uniquement préparation

---

## MISSION 1 — EMPLACEMENTS EXACTS DES ÉTATS

### État listening

**Widget** : `_buildConversationStateIndicator()`  
**Méthode** : Ligne 1762-1844  
**Position** : Padding(top: 8) après le champ de saisie (ligne 457-461)  
**Taille actuelle** :
- Padding : horizontal 16, vertical 8
- Icône : size 16
- Texte : style par défaut (non spécifié)
- Fond : alpha 0.1 (très transparent)

**Visibilité réelle** : Faible (fond transparent, taille petite, position en haut)

---

### État processing

**Widget** : `_buildConversationStateIndicator()`  
**Méthode** : Ligne 1762-1844  
**Position** : Même emplacement que listening  
**Taille actuelle** : Identique à listening  
**Visibilité réelle** : Faible (fond transparent, taille petite)

---

### État thinking

**Widget** : `_buildConversationStateIndicator()` + `_buildThinkingVisual()`  
**Méthode** : Ligne 1762-1844 (indicateur) + 1991-2009 (visuel central)  
**Position** :
- Indicateur : Padding(top: 8) après champ de saisie
- Visuel central : `_buildConversationControls()` (ligne 1846-1888)

**Taille actuelle** :
- Indicateur : Identique à listening
- Visuel central : CircularProgressIndicator 40x40, texte 13px

**Visibilité réelle** : Moyenne (visuel central plus visible que l'indicateur)

---

### État playing

**Widget** : `_buildConversationStateIndicator()` + `_buildPlayingVisual()`  
**Méthode** : Ligne 1762-1844 (indicateur) + 2014-2036 (visuel central)  
**Position** :
- Indicateur : Padding(top: 8) après champ de saisie
- Visuel central : `_buildConversationControls()` (ligne 1846-1888)

**Taille actuelle** :
- Indicateur : Identique à listening
- Visuel central : Cercle 64x64, texte 13px

**Visibilité réelle** : Moyenne (visuel central plus visible que l'indicateur)

---

### État ended

**Widget** : `_buildConversationStateIndicator()`  
**Méthode** : Ligne 1762-1844  
**Position** : Même emplacement que listening  
**Taille actuelle** : Identique à listening  
**Visibilité réelle** : Faible (fond transparent, taille petite)

---

## MISSION 2 — TRANSCRIPTION TEMPS RÉEL

### Composant exact

**Widget** : `_buildConversationStateIndicator()`  
**Méthode** : Ligne 1831-1840  
**Variable** : `_lastRecognizedWords` (String)

### Emplacements actuels

1. **Indicateur d'état** (ligne 1831-1840)
   - Condition : `if (_conversationState == ConversationState.listening && _lastRecognizedWords.isNotEmpty)`
   - Style : fontSize 13, italic, maxLines 2
   - Position : Sous l'icône et texte de l'indicateur

2. **Visuel d'écoute** (ligne 1966-1980)
   - Condition : `if (_lastRecognizedWords.isNotEmpty)`
   - Style : fontSize 14, italic, maxLines 2, centré
   - Position : Sous le cercle micro et bouton ENVOYER

### Variable disponible

**Nom** : `_lastRecognizedWords`  
**Type** : String  
**Mise à jour** : Dans le callback `onResult` de `speech_to_text` (ligne 1374-1380)  
**Accès** : Disponible dans tout le widget

---

## MISSION 3 — FUTUR PARCOURS UTILISATEUR

### Écran 1 : Activation du mode conversation

**Action** : Utilisateur appuie sur le bouton microphone dans l'AppBar  
**Code** : `_toggleVoiceMode()` (ligne 1654)  
**Résultat attendu** :
- SnackBar : "Conversation vocale activée. Parlez, Bobodo vous répondra." (5s)
- Dialog explicatif (nouveau) : "Parlez, puis appuyez sur ➤ pour envoyer"
- État : listening
- Indicateur : "Parlez maintenant" (massif, en haut de l'écran)
- Visuel central : Cercle micro + bouton ENVOYER avec label "ENVOYER"

---

### Écran 2 : Écoute (listening)

**Action** : Utilisateur parle  
**Code** : `_startVocalRecording()` (ligne 1362)  
**Résultat attendu** :
- Indicateur : "Parlez maintenant" (massif, visible)
- Transcription : Affichée en temps réel (taille augmentée, max 4 lignes)
- Visuel central : Point rouge + durée + cercle micro + bouton ENVOYER
- Bouton ENVOI : Label "ENVOYER" visible, animation pulse

---

### Écran 3 : Envoi du message

**Action** : Utilisateur appuie sur le bouton ENVOYER  
**Code** : `_sendConversationMessage()` (ligne 1280)  
**Résultat attendu** :
- Signal sonore : Bip court
- État : processing (800ms)
- Indicateur : "✓ Message reçu" (massif, visible)
- Visuel central : Masqué

---

### Écran 4 : Réflexion (thinking)

**Action** : Système traite le message  
**Code** : `_onTranscriptionReceived()` (ligne 1468)  
**Résultat attendu** :
- Signal sonore : Bip distinct
- État : thinking
- Indicateur : "Bobodo réfléchit..." (massif, visible)
- Visuel central : CircularProgressIndicator (taille augmentée)

---

### Écran 5 : Réponse vocale (playing)

**Action** : Bobodo répond vocalement  
**Code** : `_speakWithLocalTts()` (ligne 1599)  
**Résultat attendu** :
- Signal sonore : Bip au début
- État : playing
- Indicateur : "Bobodo parle..." (massif, visible)
- Visuel central : Cercle volume_up (taille augmentée)
- Contrôles : Bouton "Couper" visible

---

### Écran 6 : Reprise de parole

**Action** : Bobodo termine de parler  
**Code** : `_onAudioPlaybackComplete()` (ligne 1715)  
**Résultat attendu** :
- Signal sonore : Bip distinct
- État : listening
- Indicateur : "Parlez maintenant" (massif, visible)
- Visuel central : Cercle micro + bouton ENVOYER
- Haptic feedback : Vibration légère

---

## MISSION 4 — LISTE FINALE DES CORRECTIONS

### Correction 1 : Rendre l'indicateur d'état massif et visible

**Fichier** : `student_bobodo_tab.dart`  
**Méthode** : `_buildConversationStateIndicator()`  
**Lignes** : 1812-1843  
**Nombre de lignes** : ~10 lignes  
**Modifications** :
- Augmenter padding : horizontal 24, vertical 16
- Augmenter taille icône : size 24
- Augmenter taille texte : fontSize 18, fontWeight bold
- Augmenter opacité fond : alpha 0.3 au lieu de 0.1
- Ajouter bordure : Border.all(color: stateColor, width: 2)

**Risque de régression** : Faible (modifications UI uniquement, pas de logique)

---

### Correction 2 : Ajouter label "ENVOYER" sous le bouton

**Fichier** : `student_bobodo_tab.dart`  
**Méthode** : `_buildListeningVisual()`  
**Lignes** : 1939-1961  
**Nombre de lignes** : ~3 lignes  
**Modifications** :
- Ajouter Text("ENVOYER") sous le bouton
- Style : fontSize 14, color: PrepTheme.primary, fontWeight bold
- Ajouter animation pulse sur le bouton

**Risque de régression** : Faible (ajout de texte, pas de logique)

---

### Correction 3 : Ajouter guide d'utilisation au premier lancement

**Fichier** : `student_bobodo_tab.dart`  
**Méthode** : `_toggleVoiceMode()`  
**Lignes** : 1654-1671  
**Nombre de lignes** : ~15 lignes  
**Modifications** :
- Ajouter variable bool `_hasSeenConversationGuide`
- Ajouter showDialog avec instructions
- Stocker flag dans SharedPreferences
- Ne pas afficher si déjà vu

**Risque de régression** : Faible (ajout de dialog, pas de logique existante modifiée)

---

### Correction 4 : Améliorer la visibilité de la transcription

**Fichier** : `student_bobodo_tab.dart`  
**Méthode** : `_buildListeningVisual()`  
**Lignes** : 1966-1980  
**Nombre de lignes** : ~5 lignes  
**Modifications** :
- Augmenter taille texte : fontSize 16
- Augmenter maxLines : 4 au lieu de 2
- Ajouter fond coloré : Container avec background
- Augmenter padding

**Risque de régression** : Faible (modifications UI uniquement)

---

### Correction 5 : Ajouter signaux sonores pour transitions

**Fichier** : `student_bobodo_tab.dart`  
**Méthodes** : `_onTranscriptionReceived()`, `_onAudioPlaybackComplete()`  
**Lignes** : 1468, 1715  
**Nombre de lignes** : ~10 lignes  
**Modifications** :
- Ajouter méthode `_playTransitionSound()`
- Utiliser AudioPlayer pour jouer des sons courts
- Jouer son à chaque transition d'état

**Risque de régression** : Moyen (nécessite gestion AudioPlayer, mais code existe déjà)

---

## MISSION 5 — ORDRE D'EXÉCUTION

### Ordre recommandé

1. **Correction 2** (Bouton ENVOI) - Plus critique, résout le blocage principal
2. **Correction 1** (Indicateur d'état) - Améliore la compréhension globale
3. **Correction 3** (Guide d'utilisation) - Évite la confusion des nouveaux utilisateurs
4. **Correction 4** (Transcription) - Amélioration de confort
5. **Correction 5** (Signaux sonores) - Amélioration supplémentaire

### Justification

- **Correction 2 en premier** : Sans bouton ENVOYER évident, l'utilisateur ne peut pas utiliser le mode conversation
- **Correction 1 en second** : Indicateur visible est essentiel pour comprendre ce qui se passe
- **Correction 3 en troisième** : Guide évite la confusion des nouveaux utilisateurs
- **Correction 4 en quatrième** : Transcription améliore l'expérience mais n'est pas bloquante
- **Correction 5 en dernier** : Signaux sonores sont un "nice to have", pas essentiel

---

## RÉSUMÉ

**Fichier unique** : `student_bobodo_tab.dart`  
**Nombre total de corrections** : 5  
**Nombre total de lignes** : ~43 lignes  
**Risque global** : Faible à moyen (modifications UI uniquement, une correction avec AudioPlayer)  
**Temps estimé** : 1-2 heures d'implémentation

---

## PRÉPARATION POUR IMPLÉMENTATION

Ce rapport contient toutes les informations nécessaires pour implémenter les corrections sans nouveaux audits :

- Emplacements exacts des états (lignes, méthodes, widgets)
- Variable de transcription disponible (`_lastRecognizedWords`)
- Futur parcours utilisateur complet (écran par écran)
- Liste des 5 corrections avec fichiers, méthodes, lignes, risques
- Ordre d'exécution recommandé

**Prochaine étape** : Implémenter les corrections dans l'ordre recommandé.
