# Mission Produit – Interface Challenge inspirée des plateformes vidéo mais optimisée pour la compétition académique

**Date**: 16 Juin 2026  
**Objectif**: Interface TikTok-like + identité Academia (compétition académique)  
**Niveau**: Produit (stratégie)

---

## A. Standards TikTok à Conserver

### A.1 Standards universels (à conserver tels quels)

| Standard | Pourquoi conserver | Application Academia |
|----------|-------------------|----------------------|
| **Vidéo plein écran** | Immersion maximale, pattern reconnu | Maintenir 90%+ zone vidéo |
| **Colonne actions droite** | Pattern universel, muscle memory | Maintenir position droite |
| **4 actions visibles max** | Réduit charge cognitive, standard marché | Like, Commentaires, Partage, Menu |
| **Menu "..."** | Hiérarchie claire, standard marché | Actions secondaires dedans |
| **Swipe vertical** | Navigation intuitive, réflexe TikTok | Maintenir scroll vertical |
| **Double-tap like** | Interaction universelle, feedback immédiat | Maintenir double-tap |
| **Tap central play/pause** | Contrôle intuitif | Maintenir tap central |
| **Métadonnées bas gauche** | Pattern naturel de lecture | Maintenir position |

**Rationale**: Ces standards sont devenus des réflexes utilisateur. Les modifier créerait de la friction inutile.

---

### A.2 Standards TikTok à adapter

| Standard | Adaptation Academia | Pourquoi |
|----------|---------------------|----------|
| **Navigation bas** | 5 items vs 6 TikTok | Academia a besoin de: Accueil, Challenges, +, Jeux, Live, Profil |
| **Métadonnées** | Ajouter type/difficulté/points | Contexte compétition académique |
| **Hashtags** | Hashtags académiques (#maths #physique) | Découvrabilité par matière |
| **Musique** | Optionnel ou remplacé par son challenge | Contexte académique |

**Rationale**: Adaptations minimales pour préserver le pattern TikTok tout en ajoutant le contexte Academia.

---

## B. Éléments Academia à Mettre en Avant

### B.1 Éléments uniques à Academia (n'existent pas sur TikTok)

| Élément | Description | Valeur pour l'étudiant |
|---------|-------------|----------------------|
| **Type de défi** | Mission / Concours / Duel / Universitaire / Entreprise | Contexte de compétition |
| **Difficulté** | Facile / Moyen / Difficile / Expert | Progression adaptée |
| **Points** | XP gagnés en participant | Gamification |
| **Classement** | Rang dans le challenge | Compétition |
| **Statut participant** | Rejoint / En cours / Terminé | Progression personnelle |
| **Score personnel** | Points obtenus dans le challenge | Performance |
| **Série de connexion** | Jours consécutifs d'activité | Engagement |
| **Niveau** | Niveau académique global | Progression long terme |
| **Badges** | Récompenses visuelles | Accomplissements |
| **Délai** | Temps restant pour participer | Urgence |
| **Participants** | Nombre de participants | Popularité |

---

### B.2 Ce qui doit rester visible

**Visibilité permanente (feed):**
1. **Type de défi** - Contexte immédiat
2. **Difficulté** - Adéquation niveau
3. **Points** - Motivation gamification
4. **Statut participant** - Progression personnelle

**Visibilité contextuelle (tap/menu):**
1. **Classement** - Dans menu "..." ou sheet dédiée
2. **Score personnel** - Dans métadonnées ou sheet
3. **Niveau global** - Dans profil
4. **Badges** - Dans profil ou sheet

**Rationale**: Équilibre entre information visible (motivation) et information contextuelle (immersion).

---

## C. Risque de Copie Excessive

### C.1 Ce qui transformerait Challenge en clone TikTok

| Élément | Risque | Mitigation |
|---------|--------|------------|
| **Supprimer métadonnées académiques** | Perte d'identité | Conserver type/difficulté/points |
| **Navigation identique TikTok** | Confusion | Adapter items (Jeux, Live) |
| **Absence de gamification visible** | Perte de valeur | Afficher points/XP clairement |
| **Pas de contexte compétition** | Perte de différentiation | Afficher type/difficulté/classement |
| **Design identique TikTok** | Clone visuel | Adapter couleurs (vert Academia) |

---

### C.2 Ce qui ferait perdre l'identité Academia

| Élément | Impact | Comment éviter |
|---------|--------|----------------|
| **Supprimer progression académique** | Perte de valeur éducative | Maintenir XP/niveau/badges |
| **Supprimer classements** | Perte de compétition | Maintenir rangs/leaderboards |
| **Supprimer types de défis** | Perte de variété | Maintenir Mission/Concours/Duel |
| **Supprimer contexte universitaire** | Perte de crédibilité | Maintenir badges/établissements |
| **Design purement divertissement** | Perte de sérieux | Maintenir identité visuelle Academia |

---

## D. Architecture de l'Attention

### D.1 Niveau 1 - Ce qui doit attirer l'œil en premier

**Pour un étudiant utilisant Challenge:**

1. **Vidéo** (plein écran) - Contenu principal
2. **Type de défi** (badge en haut) - Contexte immédiat
3. **Points** (icône + nombre) - Motivation gamification

**Rationale**: L'étudiant doit comprendre instantanément:
- C'est quoi? (vidéo)
- C'est quel type de défi? (badge)
- Ça vaut quoi? (points)

---

### D.2 Niveau 2 - Ce qui doit attirer l'œil en second

1. **Auteur** (bas gauche) - Crédibilité
2. **Difficulté** (bas gauche) - Adéquation niveau
3. **Statut participant** (bas gauche) - Progression personnelle
4. **Actions droite** (like, commentaires, partage) - Engagement

**Rationale**: Après le premier scan, l'étudiant veut savoir:
- Qui a créé ça? (auteur)
- Est-ce pour moi? (difficulté)
- Où en suis-je? (statut)
- Comment interagir? (actions)

---

### D.3 Niveau 3 - Ce qui doit attirer l'œil en troisième

1. **Navigation** (bas) - Navigation globale
2. **Classement** (menu "...") - Compétition
3. **Score personnel** (menu "...") - Performance
4. **Détails challenge** (tap sur titre) - Information complète

**Rationale**: Informations contextuelles accessibles sur demande, sans surcharger l'interface.

---

## E. Classements et Progression

### E.1 Intégration sans réduire immersion

**Principe**: Afficher les informations de progression de manière subtile, non intrusive.

| Élément | Position | Style | Condition |
|---------|----------|-------|----------|
| **Points** | Bas gauche, à côté du titre | Petit badge vert | Toujours visible |
| **XP total** | Menu "..." ou profil | Texte compact | Contextuel |
| **Niveau** | Menu "..." ou profil | Badge circulaire | Contextuel |
| **Classement** | Menu "..." ou sheet dédiée | Texte avec rang | Contextuel |
| **Série connexion** | Menu "..." ou profil | Icône feu + nombre | Contextuel |
| **Badges** | Menu "..." ou profil | Grille d'icônes | Contextuel |

---

### E.2 Affichage dans le feed

**Éléments visibles dans le feed:**
```
@auteur
Titre du challenge
🏆 Mission • ⭐ Diff: Moyen • 💎 500 pts
📊 123 participants
```

**Éléments contextuels (menu "..."):**
- Classement du challenge
- Mon rang dans le challenge
- Mon score personnel
- XP gagnés
- Badges disponibles

**Rationale**: Feed = motivation immédiate (points, difficulté). Menu = progression détaillée (classement, XP).

---

### E.3 Sheet classement (tap sur rang)

**Structure:**
```
┌─────────────────────────────────────┐
│ Classement Challenge                │
├─────────────────────────────────────┤
│ 🥇 @user1 - 2500 pts               │
│ 🥈 @user2 - 2300 pts               │
│ 🥉 @user3 - 2100 pts               │
│ 4️⃣ @user4 - 1900 pts               │
│ ...                                 │
├─────────────────────────────────────┤
│ Ton rang: #12                       │
│ Ton score: 850 pts                 │
│ XP gagnés: +100                    │
└─────────────────────────────────────┘
```

**Rationale**: Classement accessible sur demande, sans surcharger le feed.

---

## F. Types de Défis

### F.1 Intégration dans l'interface vidéo

| Type de défi | Badge | Couleur | Position |
|--------------|-------|---------|----------|
| **Mission** | 🎯 | Bleu | Haut de la vidéo (coin gauche) |
| **Concours** | 🏆 | Or | Haut de la vidéo (coin gauche) |
| **Duel** | ⚔️ | Rouge | Haut de la vidéo (coin gauche) |
| **Universitaire** | 🎓 | Violet | Haut de la vidéo (coin gauche) |
| **Entreprise** | 💼 | Gris | Haut de la vidéo (coin gauche) |

**Rationale**: Badge en haut pour identification immédiate du type de défi.

---

### F.2 Métadonnées spécifiques par type

**Mission:**
```
🎯 Mission
Titre du challenge
⭐ Diff: Moyen • 💎 500 pts
📊 123 participants
```

**Concours:**
```
🏆 Concours
Titre du challenge
⭐ Diff: Difficile • 💎 1000 pts
⏰ 2j restants • 📊 456 participants
```

**Duel:**
```
⚔️ Duel
Titre du challenge
⭐ Diff: Expert • 💎 2000 pts
👤 @adversaire • ⏰ 24h restants
```

**Universitaire:**
```
🎓 Universitaire
Titre du challenge
🏛️ Université X • ⭐ Diff: Moyen
💎 500 pts • 📊 78 participants
```

**Entreprise:**
```
💼 Entreprise
Titre du challenge
🏢 Entreprise Y • ⭐ Diff: Difficile
💎 1500 pts • 📊 234 participants
```

---

### F.3 Actions spécifiques par type

| Type | Actions spécifiques | Menu "..." |
|------|---------------------|------------|
| **Mission** | Rejoindre, Voir progression | Détails mission, XP gagnés |
| **Concours** | Rejoindre, Voir classement | Classement complet, Règles |
| **Duel** | Accepter, Défier | Historique duels, Stats adversaire |
| **Universitaire** | Rejoindre, Voir établissement | Info université, Badges |
| **Entreprise** | Rejoindre, Voir entreprise | Info entreprise, Offres |

---

## G. Différenciation Produit

### G.1 Pourquoi un étudiant utiliserait Challenge au lieu de TikTok?

| Avantage Academia | TikTok | Pourquoi c'est différent |
|-------------------|--------|-------------------------|
| **Compétition académique** | Divertissement pur | Progression mesurable, classements |
| **Gamification** | Likes/vues seulement | XP, niveaux, badges, récompenses |
| **Contexte éducatif** | Contenu général | Défis par matière, niveau adapté |
| **Crédibilité** | Créateurs anonymes | Universités, entreprises, établissements |
| **Progression** | Aucune | XP, niveaux, séries de connexion |
| **Objectifs** | Divertissement | Amélioration académique, compétences |
| **Récompenses** | Aucunes | Badges, certificats, opportunités |
| **Communauté** | Général | Étudiants, universités, entreprises |

---

### G.2 Proposition de valeur unique

**Academia Challenge = TikTok + Gamification + Éducation**

**Équation valeur:**
- TikTok: Divertissement infini
- Challenge: Divertissement + Progression + Compétition + Crédibilité

**Message:**
"Sur TikTok, tu perds du temps. Sur Challenge, tu progresses."

---

### G.3 Identité visuelle distincte

**Éléments de différenciation:**
1. **Couleur principale**: Vert Academia (vs noir/blanc TikTok)
2. **Badges types de défis**: 🎯🏆⚔️🎓💼 (vs aucun sur TikTok)
3. **Métadonnées académiques**: Difficulté, points, participants (vs hashtags seulement)
4. **Gamification visible**: XP, niveaux, badges (vs likes seulement)
5. **Classements**: Rangs, leaderboards (vs aucun sur TikTok)

---

## H. Architecture Visuelle Recommandée

### H.1 Structure globale

```
┌─────────────────────────────────────┐
│ [BADGE TYPE - Coin gauche]          │ ← 🎯🏆⚔️🎓💼
│                                     │
│          [VIDÉO PLEIN ÉCRAN]        │ ← 90%+ attention
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
├─────────────────────────────────────┤
│ [DÉGRADÉ - 120px]                   │ ← Standard marché
│ @auteur                             │
│ Titre du challenge                  │
│ 🎯 Mission • ⭐ Diff: Moyen • 💎 500 pts ← Academia
│ 📊 123 participants                │ ← Academia
│                                     │
│          [ACTIONS DROITE]           │ ← Standard marché
│    ♥  💬  ⋯  🔗                    │ ← 4 actions
│                                     │
├─────────────────────────────────────┤
│ [NAVIGATION - 44px]                 │ ← Standard marché
│ 🏠  🏆  [+]  🎮  📡  👤            │ ← Academia (Jeux, Live)
└─────────────────────────────────────┘
```

---

### H.2 Menu "..." (Academia)

```
┌─────────────────────────────────────┐
│           ⋯                         │
├─────────────────────────────────────┤
│ 🏆 Classement (#12/456)            │ ← Academia
│ 📊 Mon score: 850 pts              │ ← Academia
│ ⭐ Ajouter aux favoris              │
│ ⬇️ Télécharger                      │
│ 👥 Créer un Duo                     │
│ 🚩 Signaler                         │
│ 🗑️ Supprimer (owner only)          │
└─────────────────────────────────────┘
```

---

### H.3 Sheet Classement (Academia)

```
┌─────────────────────────────────────┐
│ 🏆 Classement Challenge            │
├─────────────────────────────────────┤
│ 🥇 @user1 - 2500 pts               │
│ 🥈 @user2 - 2300 pts               │
│ 🥉 @user3 - 2100 pts               │
│ 4️⃣ @user4 - 1900 pts               │
│ ...                                 │
├─────────────────────────────────────┤
│ Ton rang: #12                       │
│ Ton score: 850 pts                 │
│ XP gagnés: +100                    │
│ Badges: 🎓🏆⭐                      │
└─────────────────────────────────────┘
```

---

## I. Hiérarchie de l'Attention (Étudiant)

### I.1 Scan visuel (500ms)

1. **Vidéo** (centre) - Contenu
2. **Badge type** (haut gauche) - Contexte défi
3. **Points** (bas gauche) - Motivation

**Question**: "C'est quoi? Ça vaut quoi?"

---

### I.2 Scan visuel (2s)

1. **Auteur** (bas gauche) - Crédibilité
2. **Difficulté** (bas gauche) - Adéquation
3. **Statut** (bas gauche) - Progression
4. **Actions** (droite) - Engagement

**Question**: "C'est pour moi? Où en suis-je?"

---

### I.3 Scan visuel (5s)

1. **Navigation** (bas) - Exploration
2. **Menu "..."** - Classement, score
3. **Tap sur titre** - Détails complets

**Question**: "Comment je progresse? Quels autres défis?"

---

## J. Wireframe Cible Academia

### J.1 Feed Challenge (Portrait)

```
┌─────────────────────────────────────┐
│ [🎯 MISSION]                        │ ← Badge type (coin gauche)
│                                     │
│          [VIDÉO PLEIN ÉCRAN]        │ ← 90%+ zone vidéo
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
├─────────────────────────────────────┤
│ [DÉGRADÉ - 120px]                   │
│ @prof_maths                         │
│ Résoudre cette équation en 30s      │
│ 🎯 Mission • ⭐ Diff: Moyen • 💎 500 pts
│ 📊 123 participants • ✅ Rejoint     │
│                                     │
│          [ACTIONS DROITE]           │
│    ♥  💬  ⋯  🔗                    │ ← 4 actions, 36px
│                                     │
├─────────────────────────────────────┤
│ [NAVIGATION - 44px]                 │
│ 🏠  🏆  [+]  🎮  📡  👤            │
└─────────────────────────────────────┘
```

---

### J.2 Feed Concours (Portrait)

```
┌─────────────────────────────────────┐
│ [🏆 CONCOURS]                       │ ← Badge type (coin gauche)
│                                     │
│          [VIDÉO PLEIN ÉCRAN]        │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
├─────────────────────────────────────┤
│ [DÉGRADÉ - 120px]                   │
│ @univ_paris                         │
│ Défi maths national 2026            │
│ 🏆 Concours • ⭐ Diff: Difficile • 💎 1000 pts
│ ⏰ 2j restants • 📊 456 participants  │
│                                     │
│          [ACTIONS DROITE]           │
│    ♥  💬  ⋯  🔗                    │
│                                     │
├─────────────────────────────────────┤
│ [NAVIGATION - 44px]                 │
│ 🏠  🏆  [+]  🎮  📡  👤            │
└─────────────────────────────────────┘
```

---

### J.3 Feed Duel (Portrait)

```
┌─────────────────────────────────────┐
│ [⚔️ DUEL]                           │ ← Badge type (coin gauche)
│                                     │
│          [VIDÉO PLEIN ÉCRAN]        │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
├─────────────────────────────────────┤
│ [DÉGRADÉ - 120px]                   │
│ @marie_dupont                       │
│ Vs @jean_martin                     │
│ ⚔️ Duel • ⭐ Diff: Expert • 💎 2000 pts
│ 👤 @adversaire • ⏰ 24h restants    │
│                                     │
│          [ACTIONS DROITE]           │
│    ♥  💬  ⋯  🔗                    │
│                                     │
├─────────────────────────────────────┤
│ [NAVIGATION - 44px]                 │
│ 🏠  🏆  [+]  🎮  📡  👤            │
└─────────────────────────────────────┘
```

---

## K. Conclusion

### K.1 Résumé

**Standards TikTok conservés:**
- Vidéo plein écran (90%+)
- Colonne actions droite (4 actions)
- Menu "..."
- Swipe vertical, double-tap like
- Métadonnées bas gauche

**Éléments Academia ajoutés:**
- Badge type de défi (haut gauche)
- Métadonnées académiques (difficulté, points, participants)
- Gamification visible (XP, niveaux, badges)
- Classements (menu "..." ou sheet)
- Navigation adaptée (Jeux, Live)

**Différenciation produit:**
- TikTok = Divertissement
- Challenge = Divertissement + Progression + Compétition + Crédibilité

---

### K.2 Proposition de valeur

"Sur TikTok, tu perds du temps. Sur Challenge, tu progresses."

**Équation:**
- TikTok: Likes, vues, divertissement
- Challenge: XP, niveaux, badges, classements, crédibilité académique

---

### K.3 Plan d'implémentation

**Phase 1: Quick Wins (1 jour)**
- Optimiser zone vidéo (90%+)
- Réduire navigation à 44px
- Supprimer progression
- Ajuster icônes à 36px

**Phase 2: Academia Identity (2-3 jours)**
- Ajouter badge type de défi (haut gauche)
- Ajouter métadonnées académiques (difficulté, points, participants)
- Ajouter menu "..." avec classement/score
- Adapter navigation (Jeux, Live)

**Phase 3: Gamification (2-3 jours)**
- Intégrer XP visible
- Intégrer niveaux
- Intégrer badges
- Intégrer classements

**Total: 5-7 jours**

---

### K.4 Impact attendu

**Adoption:**
- Reconnaissance pattern TikTok (immédiat)
- Identification valeur Academia (progression)
- Différenciation claire (vs TikTok)

**Engagement:**
- Temps passé: +30% (gamification)
- Actions/session: +40% (compétition)
- Rétention: +50% (progression)

**ROI:** Très élevé - Combinaison standards TikTok + identité Academia unique

---

**Fin de la stratégie produit**
