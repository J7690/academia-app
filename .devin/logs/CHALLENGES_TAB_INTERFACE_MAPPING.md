# Cartographie de l'interface Challenges - Academia

**Date**: 16 Juin 2026  
**Fichier source**: `lib/features/student/tabs/student_challenges_tab.dart`  
**Objectif**: Cartographier tous les éléments visuels et fonctionnels de l'onglet Challenges

---

## Vue d'ensemble

L'onglet Challenges comporte **2 vues principales**:
1. **Feed TikTok-style** (vue par défaut) - Navigation verticale des vidéos
2. **Liste des Challenges** (vue grille) - Liste détaillée des challenges disponibles

---

## 1. Feed TikTok-style (_ChallengeVideosFeed)

### Structure globale
- **Arrière-plan**: Noir (`Colors.black`)
- **Navigation**: PageView vertical avec scroll personnalisé (_TikTokPageScrollPhysics)
- **Conteneur principal**: Stack avec plusieurs couches superposées

### Éléments de l'interface

#### 1.1 Couche vidéo (fond)
- **Composant**: `AcademiaPlaybackEngine.view`
- **Position**: `Positioned.fill` (plein écran)
- **Comportement**:
  - Lecture automatique si vidéo active
  - Boucle infinie
  - BoxFit.contain (affichage complet sans cropping)
  - Sans contrôles natifs
- **Overlays vidéo**: `_TimedVideoOverlaysLayer` (calques synchronisés avec le temps de lecture)

#### 1.2 Couche de chargement
- **Affiché quand**: `_initialized == false`
- **Contenu**:
  - Image de poster (thumbnail) si disponible
  - CircularProgressIndicator blanc au centre
  - Fond noir si pas de poster

#### 1.3 Couche d'erreur
- **Affiché quand**: `_errorMessage != null`
- **Contenu**:
  - Message d'erreur centré (texte blanc)
  - Fond noir
  - Conserve les overlays et actions

#### 1.4 Icône de pause
- **Position**: Centre de l'écran
- **Condition**: `_showPauseIcon == true` et `_isPaused == true`
- **Style**:
  - Icône `Icons.pause` (taille 48)
  - Couleur blanche
  - Fond circulaire semi-transparent (noir avec opacity 0.4)
  - Animation d'opacité (200ms)

#### 1.5 Animations double-tap (cœurs)
- **Déclencheur**: Double-tap sur la vidéo
- **Comportement**:
  - Animation de cœur à la position du tap
  - Rotation aléatoire
  - Disparition automatique après animation
- **Composant**: `_DoubleTapHeart`

#### 1.6 Dégradé de fond (bas de page)
- **Position**: Bas de l'écran, hauteur 280px
- **Style**: LinearGradient (noir87 → transparent)
- **Objectif**: Améliorer la lisibilité des textes en bas

#### 1.7 Métadonnées vidéo (gauche, bas)
- **Position**: `left: 12`, `right: 72`, `bottom: 12`
- **Éléments**:
  1. **Nom de l'auteur** (cliquable)
     - Style: Blanc, 15px, FontWeight.w700
     - Action: Navigation vers `StudentSocialProfileScreen`
  2. **Titre du challenge**
     - Style: Blanc, 13px
     - Max 2 lignes avec ellipsis
  3. **Métadonnées** (séparées par " • ")
     - Type: "Mission" ou "Concours"
     - Difficulté: "Difficulté: X"
     - Points: "X points"
     - Style: Blanc70, 13px
  4. **Badge Duo** (si remixType == 'duo')
     - Fond: Blanc avec opacity 0.18
     - Bordure arrondie (999)
     - Icône: `Icons.people_outline` (14px)
     - Texte: "Duo" (12px, FontWeight.w600)
     - Cliquable: Navigation vers vidéo parent

#### 1.8 Actions droite (colonne verticale)
- **Position**: `right: 10-14`, `bottom: 120`
- **Composant**: `_ChallengeVideoActions`
- **Éléments** (de haut en bas):

##### a. Like / J'aime
- **Icône**: 
  - `Icons.favorite` (rouge) si liké
  - `Icons.favorite_border` (blanc) sinon
- **Compteur**: Nombre de likes
- **Action**: Toggle like via provider

##### b. Commentaires
- **Icône**: `Icons.comment` (blanc)
- **Compteur**: Nombre de commentaires
- **Action**: Ouvre bottom sheet de commentaires

##### c. Favoris
- **Icône**: 
  - `Icons.bookmark` (jaune/orange) si favori
  - `Icons.bookmark_border` (blanc) sinon
- **Compteur**: Nombre de favoris
- **Action**: Toggle favori via provider

##### d. Partage
- **Icône**: `Icons.share` (blanc)
- **Action**: Ouvre menu de partage (Share+)

##### e. Téléchargement (si allowDownload == true)
- **Icône**: `Icons.download` (blanc)
- **Action**: Télécharge la vidéo avec watermark
- **Flow**:
  1. Vérifie permission stockage
  2. Tente rendition serveur (watermark)
  3. Polling si nécessaire (15s max)
  4. Fallback sur URL source
  5. Affiche sheet de progression

##### f. Remix / Duo
- **Icône**: `Icons.people` (blanc)
- **Action**: Ouvre caméra pour créer duo
- **Condition**: Si parentParticipationId existe

##### g. Signaler
- **Icône**: `Icons.flag` (blanc)
- **Action**: Ouvre dialog de signalement
- **Champs**:
  - Motif (obligatoire)
  - Détails (optionnel)

##### h. Supprimer (si isOwner == true)
- **Icône**: `Icons.delete` (rouge)
- **Action**: Supprime la vidéo
- **Confirmation**: Dialog de confirmation

#### 1.9 Bulles Live (haut de page)
- **Position**: `top: safeArea + 4`, horizontal scroll
- **Condition**: Si `_livePlayers.isNotEmpty`
- **Composant**: `_buildLiveBubbles()`
- **Éléments par joueur**:
  - Avatar circulaire (52x52)
  - Bordure rouge (2.5px)
  - Badge "LIVE" (rouge, 8px, FontWeight.w800)
  - Nom affiché (tronqué à 8 caractères)
- **Action**: Tap → Pause vidéo → Navigation vers `ChallengeLiveScreen`

#### 1.10 Barre de navigation inférieure (TikTok-style)
- **Position**: Bas de l'écran
- **Composant**: `_buildTikTokBottomBar()`
- **Structure**:

##### a. Barre de progression vidéo
- **Position**: Juste au-dessus de la barre de navigation
- **Hauteur**: 3px
- **Composant**: `_VideoProgressBar`
- **Sync**: Synchronisé avec le contrôleur vidéo actif

##### b. Barre de navigation (5 items + bouton central)
- **Fond**: Noir
- **Disposition**: Row avec espace autour

**Éléments**:

1. **Accueil**
   - Icône: `Icons.home_filled` (blanc)
   - Label: "Accueil"
   - Action: `StudentDashboardNavController.setIndex(0)`

2. **Challenges**
   - Icône: `Icons.emoji_events_outlined` (blanc)
   - Label: "Challenges"
   - Action: Navigation vers `_ChallengesListBody` (Scaffold avec AppBar vert)

3. **Bouton + central** (Créer vidéo)
   - Style: Bouton circulaire avec dégradé
   - Couleurs: Vert clair → Vert foncé (#A3D65C → #1EA75C)
   - Ombre: BoxShadow verte
   - Icône: `Icons.add` (blanc)
   - Taille: 38-44px (responsive)
   - Action: `_openCreateVideoFromFeed()`
     - Pause vidéo
     - Navigation vers `ChallengeCameraCaptureScreen`
     - Si capture → `StudentChallengeVideoEditorScreen`
     - Si publié → Reload feed + scroll à index 0

4. **Jeux**
   - Icône: `Icons.sports_esports` (blanc)
   - Label: "Jeux"
   - Action: `Navigator.pushNamed('/games')`

5. **Live**
   - Icône: `Icons.sensors` (blanc)
   - Label: "Live"
   - Action: Navigation vers `ChallengeLiveScreen(isHost: true)`

6. **Profil**
   - Icône: `Icons.person_outline` (blanc)
   - Label: "Profil"
   - Action: Navigation vers `StudentSocialProfileScreen` (userId actuel)

**Responsive**:
- Écran compact (<700px hauteur ou <360px largeur):
  - Icones: 22px (vs 26px)
  - Labels: 9px (vs 10px)
  - Bouton central: 38px (vs 44px)
  - Padding vertical: 6px (vs 8px)

#### 1.11 État vide (pas de vidéos)
- **Composant**: `_buildEmptyTikTokShell()`
- **Contenu**:
  - Icône: `Icons.slow_motion_video` (72px, blanc70)
  - Titre: "Aucune vidéo de challenge n'est disponible pour le moment."
  - Sous-titre: "Sois le premier à en publier une en créant une vidéo de challenge."
  - Bouton: "Créer une vidéo de challenge" (ElevatedButton avec icône caméra)
- **Fond**: Noir

#### 1.12 Indicateur de chargement (load more)
- **Position**: `right: 16`, `top: 40`
- **Condition**: `_isLoadingMore == true`
- **Style**:
  - Fond: Noir54
  - BorderRadius: 16
  - CircularProgressIndicator blanc (16x16, strokeWidth 2)

---

## 2. Liste des Challenges (_ChallengesListBody)

### Structure globale
- **Arrière-plan**: Gris clair (`Color(0xFFF3F4F6)`)
- **Layout**: Column avec header + liste scrollable

### Éléments de l'interface

#### 2.1 Header

##### a. Titre
- **Texte**: "Challenges"
- **Style**: 20px, FontWeight.bold

##### b. Bobodo (assistant IA)
- **Position**: À gauche du texte
- **Taille**: 52px
- **États**:
  - `idle`: Utilisateur n'a jamais rejoint de challenge
  - `thinking`: A rejoint mais pas terminé
  - `success`: A terminé ou gagné des points
- **Message contextuel** (selon stats):
  - Aucun challenge: Encouragement à rejoindre
  - En cours: Encouragement à terminer
  - Terminé: Encouragement à continuer

##### c. Carte de statistiques
- **Condition**: Si stats != null
- **Style**:
  - Fond: Blanc
  - Elevation: 0
  - BorderRadius: 16
  - Padding: 12px
- **Layout**: Row avec 3 colonnes (espace autour)
- **Métriques**:
  1. "Challenges rejoints" + nombre
  2. "Terminés" + nombre
  3. "Points gagnés" + nombre
- **Style valeur**: 16px, FontWeight.bold
- **Style label**: 11px, gris

##### d. Barre de recherche
- **Placeholder**: "Rechercher un challenge (titre, description...)"
- **Style**:
  - Fond: Blanc
  - PrefixIcon: `Icons.search`
  - BorderRadius: 24
  - BorderSide: none
- **Action**: Recherche en temps réel (debounce via _reload)

##### e. Filtres par type (chips)
- **Layout**: Wrap horizontal
- **Chips disponibles**:
  1. "Tous" (value: 'all')
  2. "Missions" (value: 'mission')
  3. "Concours" (value: 'contest')
- **Style chip sélectionné**:
  - Fond: Vert clair (#E5F9E7)
  - Texte: Vert foncé (#006D3C)
  - Bordure: Vert (#1EA75C)
  - BorderRadius: 999
- **Style chip non sélectionné**:
  - Fond: Gris clair (#F3F4F6)
  - Texte: Noir87
  - Bordure: transparent

##### f. Filtre "Mes challenges"
- **Type**: FilterChip
- **Label**: "Mes challenges"
- **Action**: Filtre les challenges rejoints par l'utilisateur

#### 2.2 Liste des challenges

##### a. Structure de section
- **Layout**: Card blanc avec borderRadius 16
- **Padding**: 16px
- **Sections**:
  1. "Mes challenges" (challenges rejoints)
  2. "Découvrir des challenges" (challenges non rejoints)

##### b. État vide de section
- **Message**: Selon section
  - Mes challenges: "Tu n'as pas encore rejoint de challenge. Découvre ceux disponibles ci-dessous."
  - Découvrir: "Aucun challenge ne correspond à ta recherche pour le moment."
- **Style**: 13px

##### c. Grille de challenges
- **Layout**: Wrap avec spacing 12px
- **Responsive**:
  - <600px: 1 colonne
  - 600-1000px: 2 colonnes
  - >1000px: 3 colonnes

##### d. Carte de challenge (_buildChallengeTile)
- **Style**:
  - Fond: Blanc
  - Elevation: 0
  - BorderRadius: 16
  - Padding: 12px
- **Contenu**:

1. **Titre**
   - Style: 15px, FontWeight.w600
   - Max 1 ligne avec ellipsis

2. **Description**
   - Style: 13px
   - Max 2 lignes avec ellipsis
   - Condition: Si non vide

3. **Métadonnées** (séparées par " • ")
   - Type: "Mission" ou "Concours"
   - Difficulté: "Difficulté: X"
   - Points: "X points"
   - Participants: "X participant(s)"
   - Style: 12px, gris

4. **Statut utilisateur** (si participé)
   - Format: "Mon statut: X • Score: Y"
   - Style: 12px, noir87

5. **Bouton d'action** (aligné à droite)
   - Texte: "Rejoindre" ou "Voir"
   - Style: TextButton
   - Action:
     - Si non rejoint: `provider.joinChallenge()`
     - Si rejoint: Navigation vers `StudentChallengeDetailScreen`

---

## 3. Bottom Sheet Commentaires

### Structure
- **Type**: DraggableScrollableSheet
- **Dimensions**:
  - initialChildSize: 0.6
  - minChildSize: 0.4
  - maxChildSize: 0.92
- **Fond**: Noir (#0B0B0B)
- **BorderRadius**: Vertical top 16px

### Éléments

#### 3.1 Header
- **Poignée**: Barre horizontale (44x4px, blanc24, borderRadius 99)
- **Titre**: "Commentaires (X)" (blanc, 16px, FontWeight.w700)
- **Actions**:
  - Icône refresh (rafraîchir)
  - Icône close (fermer)

#### 3.2 Liste de commentaires
- **Layout**: ListView.builder
- **Élément vide**: "Aucun commentaire pour le moment." (blanc70, 13px)

#### 3.3 Item de commentaire
- **Layout**: Row
- **Éléments**:

1. **Avatar**
   - Taille: 32px (radius 16)
   - Fond: Vert (#1EA75C)
   - Image: NetworkImage si avatar_url disponible
   - Fallback: Initiale du nom (blanc, 12px, FontWeight.w700)

2. **Contenu**
   - **Nom**: Blanc70, 12px, FontWeight.w600, max 1 ligne
   - **Timestamp**: Blanc38, 11px (format relatif: "à l'instant", "il y a X min", "il y a X h", "il y a X j")
   - **Texte**: Blanc, 14px

3. **Actions** (selon propriétaire)
   - **Si propre commentaire**: Icône delete (rouge)
   - **Si commentaire autre**: Menu avec:
     - "Signaler"
     - "Bloquer l'auteur" (rouge)

#### 3.4 Zone de saisie
- **Position**: Bas de la sheet
- **Layout**: Row
- **TextField**:
  - Placeholder: "Ajouter un commentaire..."
  - MaxLines: 4
  - MinLines: 1
  - Fond: Noir (#111111)
  - BorderRadius: 999
  - Texte: Blanc
- **Bouton envoi**:
  - Fond: Vert (#1EA75C)
  - Forme: Cercle
  - Icône: `Icons.send` (blanc)

---

## 4. Dialog de signalement

### Structure
- **Type**: AlertDialog
- **Titre**: "Signaler la vidéo"

### Champs
1. **Motif** (obligatoire)
   - TextField avec labelText

2. **Détails** (optionnel)
   - TextField avec labelText
   - MaxLines: 3

### Actions
- **Annuler**: TextButton
- **Envoyer**: ElevatedButton → `provider.reportVideo()`

---

## 5. Comportements et Interactions

### 5.1 Navigation
- **Pause automatique**: Toutes les vidéos sont mises en pause avant navigation
- **Reprise automatique**: La vidéo active reprend après retour de navigation
- **Lifecycle**: Pause en background, reprise en foreground

### 5.2 Scroll TikTok
- **Physics**: _TikTokPageScrollPhysics
  - Spring rapide (mass: 0.3, stiffness: 200, damping: 22)
  - Seuil de fling très bas (30.0)
  - Seuil de drag réduit (2.0)
- **Preload**: Pages adjacentes pré-construites (viewportFraction: 0.9999)
- **Buffering**: ExoPlayer buffer natif des vidéos adjacentes

### 5.3 Gestion des contrôleurs
- **Par page**: Un AcademiaPlaybackController par index
- **Cleanup**: Contrôleurs loin de la page actuelle (N-3..N+3) sont supprimés
- **Auto-pause**: Tous les contrôleurs sauf l'actif sont en pause

### 5.4 Double-tap
- **Détection**: Custom (évite délai 300ms de GestureDetector)
- **Seuil**: 250ms entre taps, distance < 60px
- **Action**: Like + animation cœur

### 5.5 Single-tap
- **Action**: Toggle play/pause
- **Délai**: 180ms (pour permettre double-tap)

### 5.6 Analytics
- **VideoStarted**: Déclenché au changement de page
- **VideoStopped**: Déclenché au changement de page
- **Données**: videoId, videoType, participationId

---

## 6. Données affichées

### 6.1 Données vidéo
- **Identifiants**: participation_id, video_id, video_asset_id
- **Métadonnées**: video_type, challenge_title, challenge_type, difficulty, points
- **Auteur**: user_id, display_name, user_name
- **Stats**: likes_count, comments_count, favorites_count
- **État utilisateur**: has_liked, has_favorited, is_joined, my_status, my_score
- **URLs**: video_url, poster_url, thumbnail_url
- **Renditions**: video_renditions (map avec URLs par qualité)
- **Overlays**: overlays/layers (calques synchronisés)
- **Remix**: remix_type, parent_participation_id
- **Permissions**: allow_download

### 6.2 Données challenge
- **Identifiant**: id
- **Métadonnées**: title, description, challenge_type, difficulty, points
- **Stats**: participants_count
- **État utilisateur**: is_joined, my_status, my_score
- **Configuration**: requires_submission

---

## 7. Responsive Design

### 7.1 Breakpoints
- **Hauteur compacte**: <700px
- **Largeur compacte**: <360px

### 7.2 Adaptations
- **Taille icônes**: 22px vs 26px
- **Taille labels**: 9px vs 10px
- **Taille bouton central**: 38px vs 44px
- **Padding vertical**: 6px vs 8px
- **Grille challenges**: 1/2/3 colonnes selon largeur

---

## 8. États de chargement

### 8.1 Feed TikTok
- **Initial**: LoadingWidget "Chargement des vidéos..."
- **Erreur**: CustomErrorWidget avec retry
- **Vide**: _buildEmptyTikTokShell
- **Load more**: CircularProgressIndicator en haut à droite

### 8.2 Liste challenges
- **Initial**: LoadingWidget dans provider
- **Erreur**: CustomErrorWidget avec retry
- **Vide**: Message dans chaque section

---

## 9. Accessibilité

### 9.1 Contrastes
- **Texte sur noir**: Blanc / Blanc70 / Blanc38
- **Texte sur blanc**: Noir / Gris
- **Actions**: Icônes blanches sur fond sombre

### 9.2 Touch targets
- **Boutons navigation**: Minimum 44px (Material Design)
- **Actions vidéo**: Icônes avec padding implicite
- **Chips**: Touchable entière

### 9.3 Feedback visuel
- **Like**: Icône rouge + animation cœur
- **Pause**: Icône centrale semi-transparente
- **Loading**: CircularProgressIndicator
- **Erreur**: Messages explicites

---

## 10. Résumé des flux utilisateur

### Flux 1: Navigation feed TikTok
1. User ouvre onglet Challenges → Feed TikTok
2. Scroll vertical → Changement de vidéo
3. Tap sur vidéo → Play/Pause
4. Double-tap → Like + animation
5. Tap sur actions droite → Interactions (like, commentaire, partage, etc.)
6. Tap sur navigation bas → Navigation vers autres sections

### Flux 2: Création vidéo
1. Tap sur bouton + central
2. Navigation vers caméra
3. Capture de segments
4. Navigation vers Studio
5. Édition + publication
6. Retour → Feed rechargé + scroll à index 0

### Flux 3: Liste challenges
1. Tap sur "Challenges" dans navigation
2. Affichage liste avec filtres
3. Recherche / filtres
4. Tap sur challenge → Détail
5. Tap sur "Rejoindre" → Join challenge

### Flux 4: Commentaires
1. Tap sur icône commentaire
2. Ouverture bottom sheet
3. Lecture / ajout de commentaires
4. Signalement / blocage si nécessaire

---

**Fin de la cartographie**
