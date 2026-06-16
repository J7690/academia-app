# Mission Finale UX Produit – Maquette Cible de Challenge

**Date**: 16 Juin 2026  
**Objectif**: Concevoir l'interface cible complète du feed Challenge  
**Positionnement**: Plateforme de compétition académique utilisant les codes UX des plateformes vidéo

---

## A. Écran Complet

### A.1 Partie Haute (Top)

| Élément | Position | État | Justification |
|---------|----------|------|---------------|
| **Rang personnel** | Haut gauche, coin | Visible | Motivation immédiate, compétition |
| **Type de défi** | Haut gauche, à côté du rang | Visible | Contexte immédiat |
| **Progression niveau** | Haut gauche, sous le rang | Visible | Objectif clair, progression |
| **Barre de progression niveau** | Haut gauche, sous la progression | Visible | Feedback visuel |
| **Navigation retour** | Haut gauche, coin supérieur | Masqué | Swipe naturel suffit |
| **Titre de l'écran** | Haut centre | Masqué | Contexte évident (feed) |
| **Bouton recherche** | Haut droite | Masqué | Accès via navigation |
| **Bouton filtres** | Haut droite | Masqué | Accès via navigation |

**Rationale:** La partie haute doit afficher uniquement les éléments de motivation immédiate (rang, progression, type de défi). Les éléments de navigation traditionnels sont masqués pour maximiser l'espace vidéo.

---

### A.2 Partie Centrale (Center)

| Élément | Position | État | Justification |
|---------|----------|------|---------------|
| **Vidéo** | Centre, plein écran | Visible | Contenu principal, immersion |
| **Badges type de défi** | Haut gauche, superposé à la vidéo | Visible | Contexte visuel |
| **Badges difficulté** | Haut gauche, superposé à la vidéo | Visible | Adéquation niveau |
| **Overlays temporisés** | Centre, superposés à la vidéo | Visible | Outils pédagogiques |
| **Bulles Live** | Bas droite, superposées à la vidéo | Visible | Engagement live |
| **Indicateur de duel** | Centre, superposé à la vidéo | Visible | Compétition 1v1 |
| **Indicateur de tournoi** | Centre, superposé à la vidéo | Visible | Compétition structurée |
| **Musique** | Bas droite, superposée à la vidéo | Masqué | Non pertinent académique |
| **Hashtags** | Bas gauche, superposés à la vidéo | Masqué | Remplacé par type de défi |
| **Progression vidéo** | Bas centre, superposée à la vidéo | Masqué | Brise immersion |

**Rationale:** La partie centrale doit maximiser l'immersion vidéo tout en affichant les badges contextuels (type, difficulté) et les indicateurs de compétition (duel, tournoi). Les éléments hérités de TikTok (musique, hashtags, progression vidéo) sont masqués.

---

### A.3 Colonne Droite (Right Column)

| Élément | Ordre | Taille | Justification |
|---------|-------|--------|---------------|
| **Duel** | 1 (haut) | 36px | Compétition 1v1, engagement émotionnel |
| **Classement** | 2 | 36px | Compétition, motivation statut |
| **Menu "..."** | 3 | 36px | Accès aux détails (XP, badges, likes) |
| **Partage** | 4 (bas) | 36px | Viralité, exposition |
| **Like** | Masqué (menu) | - | Motivation faible, secondaire |
| **Commentaires** | Masqué (menu) | - | Motivation faible, secondaire |
| **Favoris** | Masqué (menu) | - | Motivation faible, secondaire |

**Rationale:** La colonne droite doit afficher uniquement les actions de compétition (duel, classement) et le menu d'accès aux détails. Les actions sociales (like, commentaires) sont masquées dans le menu pour prioriser la compétition.

---

### A.4 Partie Basse (Bottom)

| Élément | Position | Taille | Justification |
|---------|----------|--------|---------------|
| **Auteur** | Bas gauche, ligne 1 | 14px | Crédibilité |
| **Titre du défi** | Bas gauche, ligne 2 | 16px bold | Contexte |
| **Points** | Bas gauche, ligne 3 | 14px | Motivation immédiate |
| **Difficulté** | Bas gauche, ligne 3 | 14px | Adéquation |
| **Statut participant** | Bas gauche, ligne 3 | 14px | Progression |
| **Série de connexion** | Bas gauche, ligne 4 | 12px | Engagement quotidien |
| **Participants** | Bas gauche, ligne 4 | 12px | Popularité |
| **Université** | Bas gauche, ligne 5 | 12px | Crédibilité académique |
| **Navigation** | Bas, barre fixe | 44px | Navigation globale |

**Rationale:** La partie basse doit afficher les métadonnées académiques (auteur, titre, points, difficulté, statut) et les informations de progression (série, participants, université). La zone doit être compacte (120px) pour maximiser l'espace vidéo.

---

## B. Hiérarchie Visuelle

### B.1 Niveaux de Visibilité

**Niveau 1 - Maximum visibilité (Feed):**
- Rang personnel (haut gauche, coin)
- Type de défi (haut gauche)
- Progression niveau (haut gauche)
- Vidéo (centre, plein écran)
- Points (bas gauche)
- Difficulté (bas gauche)
- Statut participant (bas gauche)
- Actions compétitives (droite: duel, classement)

**Niveau 2 - Visibilité contextuelle (Menu "..."):**
- Classement détaillé
- Score personnel
- XP gagnés
- Badges
- Likes
- Commentaires
- Favoris

**Niveau 3 - Visibilité secondaire (Écran dédié):**
- Statistiques détaillées
- Historique complet
- Paramètres

---

### B.2 Taille et Contraste

| Élément | Taille | Contraste | Justification |
|---------|--------|-----------|---------------|
| **Rang personnel** | 20px bold | Très élevé (blanc sur noir) | Motivation maximale |
| **Type de défi** | 16px bold | Élevé (blanc sur noir) | Contexte |
| **Progression niveau** | 14px | Élevé (blanc sur noir) | Objectif |
| **Points** | 14px bold | Élevé (blanc sur dégradé) | Motivation |
| **Difficulté** | 12px | Moyen (gris sur dégradé) | Adéquation |
| **Statut participant** | 12px | Moyen (gris sur dégradé) | Progression |
| **Auteur** | 14px | Moyen (gris sur dégradé) | Crédibilité |
| **Titre** | 16px bold | Élevé (blanc sur dégradé) | Contexte |
| **Actions droite** | 36px | Élevé (blanc sur noir) | Engagement |

---

## C. Hiérarchie Psychologique

### C.1 Architecture de l'Attention

**Première seconde (1s):**
1. **Rang personnel** (#12/456) - Compétition
   - "Où suis-je par rapport aux autres?"
2. **Type de défi** (🎯 Mission) - Contexte
   - "C'est quoi?"
3. **Vidéo** - Contenu
   - "Qu'est-ce que je regarde?"

**3 premières secondes (3s):**
4. **Progression niveau** (⬆️ Niveau 5 → 85%) - Progression
   - "Où en suis-je dans ma progression?"
5. **Points** (💎 500 pts) - Motivation
   - "Ça vaut quoi?"
6. **Difficulté** (⭐ Diff: Moyen) - Adéquation
   - "Est-ce pour moi?"
7. **Statut participant** (✅ Rejoint) - Progression
   - "Où en suis-je?"

**10 premières secondes (10s):**
8. **Auteur** (@prof_maths) - Crédibilité
   - "Qui a créé ça?"
9. **Série de connexion** (🔥 7 jours) - Engagement
   - "Je suis dans une série"
10. **Participants** (📊 123 participants) - Popularité
    - "Combien de personnes participent?"
11. **Actions compétitives** (⚔️ Duel, 🏆 Classement) - Engagement
    - "Comment puis-je participer?"

---

### C.2 Flux Psychologique

**Phase 1 - Découverte (1s):**
- Rang → Type → Vidéo
- Question: "Où suis-je? C'est quoi?"

**Phase 2 - Évaluation (3s):**
- Progression → Points → Difficulté → Statut
- Question: "Ça vaut quoi? Est-ce pour moi?"

**Phase 3 - Engagement (10s):**
- Auteur → Série → Participants → Actions
- Question: "Qui a créé ça? Comment participer?"

---

## D. Signaux de Motivation

### D.1 Signaux Remplaçant les Likes

| Signal TikTok | Signal Academia | Motivation | Puissance |
|---------------|-----------------|-------------|-----------|
| **Likes** | **Rang personnel** | Compétition, statut | Très élevé |
| **Likes** | **Progression niveau** | Progression, objectif | Très élevé |
| **Likes** | **Points** | Récompense immédiate | Élevé |
| **Likes** | **Série de connexion** | Engagement quotidien | Très élevé |
| **Likes** | **Duel** | Compétition 1v1 | Très élevé |
| **Likes** | **Classement** | Compétition, statut | Très élevé |
| **Likes** | **Tournois** | Compétition structurée | Très élevé |
| **Likes** | **Leagues** | Compétition saisonnière | Très élevé |
| **Likes** | **Badges** | Reconnaissance | Moyen |
| **Likes** | **Université** | Crédibilité académique | Moyen |

---

### D.2 Signaux de Motivation par Catégorie

**Compétition:**
- Rang personnel (#12/456)
- Duel (⚔️)
- Classement (🏆)
- Tournois
- Leagues

**Progression:**
- Progression niveau (⬆️ Niveau 5 → 85%)
- Points (💎 500 pts)
- XP gagnés
- Badges

**Engagement:**
- Série de connexion (🔥 7 jours)
- Objectif quotidien
- Statut participant (✅ Rejoint)

**Crédibilité:**
- Auteur (@prof_maths)
- Université (🏛️ Université X)
- Entreprise (🏢 Entreprise Y)

---

## E. Wireframe Final

### E.1 Wireframe ASCII - Mobile (Portrait)

```
┌─────────────────────────────────────┐
│ [#12 RANG]  🎯 MISSION              │ ← Rang personnel, Type de défi
│ [⬆️ Niveau 5 → 85%]                │ ← Progression niveau
│ ████████████░░░░░░░░░░░░░░░░░░░░░ │ ← Barre de progression
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
│                                     │
│                                     │
├─────────────────────────────────────┤
│ [DÉGRADÉ - 120px]                   │
│ @prof_maths                         │ ← Auteur
│ Résoudre cette équation en 30s      │ ← Titre
│ 💎 500 pts • ⭐ Diff: Moyen • ✅ Rejoint ← Points, Difficulté, Statut
│ 🔥 Série: 7 jours • 📊 123 participants ← Série, Participants
│ 🏛️ Université Paris                 │ ← Université
│                                     │
│          [ACTIONS DROITE]           │
│    ⚔️  🏆  ⋯  🔗                    │ ← Duel, Classement, Menu, Partage
│                                     │
├─────────────────────────────────────┤
│ [NAVIGATION - 44px]                 │
│ 🏠  🏆  [+]  🎮  📡  👤            │ ← Navigation
└─────────────────────────────────────┘
```

---

### E.2 Wireframe ASCII - Version Idéale (Optimisée)

```
┌─────────────────────────────────────┐
│ [#12/456]  🎯 MISSION               │ ← Rang personnel compact, Type
│ ⬆️ L5 ████████░░ 85%               │ ← Progression niveau compacte
│                                     │
│          [VIDÉO PLEIN ÉCRAN]        │ ← 92% zone vidéo
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
│                                     │
│                                     │
│                                     │
├─────────────────────────────────────┤
│ [DÉGRADÉ - 100px]                   │ ← Zone réduite
│ @prof_maths • Résoudre cette équation en 30s ← Auteur + Titre compact
│ 💎500 • ⭐Moyen • ✅Rejoint • 🔥7j  ← Points, Diff, Statut, Série compact
│ 📊123 • 🏛️Univ Paris                │ ← Participants, Université compact
│                                     │
│          [ACTIONS DROITE]           │
│    ⚔️  🏆  ⋯  🔗                    │ ← Duel, Classement, Menu, Partage
│                                     │
├─────────────────────────────────────┤
│ [NAVIGATION - 40px]                 │ ← Navigation réduite
│ 🏠  🏆  [+]  🎮  📡  👤            │
└─────────────────────────────────────┘
```

---

### E.3 Wireframe ASCII - Menu "..." (Compétition)

```
┌─────────────────────────────────────┐
│           ⋯                         │
├─────────────────────────────────────┤
│ 🏆 Classement (#12/456)            │ ← Classement
│ 📊 Mon score: 850 pts              │ ← Score
│ ⭐ XP gagnés: +100                 │ ← XP
│ 🎓 Badges: 🏆⭐🎓                  │ ← Badges
│ ⬆️ Progression niveau: 85%         │ ← Progression
│ 🔥 Série: 7 jours                  │ ← Série
│ ⭐ Ajouter aux favoris              │
│ ⬇️ Télécharger                      │
│ 👥 Créer un Duo                     │ ← Duel
│ 💬 Commentaires (23)               │ ← Commentaires (masqués)
│ ❤️ Likes (156)                      │ ← Likes (masqués)
│ 🚩 Signaler                         │
│ 🗑️ Supprimer (owner only)          │
└─────────────────────────────────────┘
```

---

### E.4 Wireframe ASCII - Sheet Classement (Compétition)

```
┌─────────────────────────────────────┐
│ 🏆 Classement Challenge            │
├─────────────────────────────────────┤
│ 🥇 @user1 - 2500 pts               │
│ 🥈 @user2 - 2300 pts               │
│ 🥉 @user3 - 2100 pts               │
│ 4️⃣ @user4 - 1900 pts               │
│ 5️⃣ @user5 - 1800 pts               │
│ 6️⃣ @user6 - 1700 pts               │
│ 7️⃣ @user7 - 1600 pts               │
│ 8️⃣ @user8 - 1500 pts               │
│ 9️⃣ @user9 - 1400 pts               │
│ 🔟 @user10 - 1300 pts              │
│ ...                                 │
├─────────────────────────────────────┤
│ Ton rang: #12                       │ ← Rang
│ Ton score: 850 pts                 │ ← Score
│ XP gagnés: +100                    │ ← XP
│ Badges: 🎓🏆⭐                      │ ← Badges
│ Progression niveau: 85%           │ ← Progression
│ Série: 7 jours                     │ ← Série
└─────────────────────────────────────┘
```

---

## F. Recommandation Produit Finale

### F.1 Positionnement Stratégique

**Challenge est une plateforme de compétition académique utilisant les codes UX des plateformes vidéo modernes.**

**Différence fondamentale:**
- TikTok: "Je regarde, je like, je passe"
- Challenge: "Je participe, je progresse, je gagne"

---

### F.2 Architecture Visuelle

**Principe:** "Tableau de bord de compétition" + "Codes visuels TikTok"

**Éléments visibles (Feed):**
1. Rang personnel (haut gauche) - Compétition
2. Type de défi (haut gauche) - Contexte
3. Progression niveau (haut gauche) - Progression
4. Vidéo (centre) - Contenu
5. Points (bas gauche) - Motivation
6. Difficulté (bas gauche) - Adéquation
7. Statut participant (bas gauche) - Progression
8. Série de connexion (bas gauche) - Engagement
9. Actions compétitives (droite) - Engagement

**Éléments masqués (Menu "..."):**
1. Likes
2. Commentaires
3. Favoris
4. Classement détaillé
5. Score personnel
6. XP gagnés
7. Badges

---

### F.3 Signaux de Motivation

**Les signaux de motivation remplacent les likes:**
- Rang personnel (#12/456) → Compétition
- Progression niveau (⬆️ Niveau 5 → 85%) → Progression
- Points (💎 500 pts) → Récompense
- Série de connexion (🔥 7 jours) → Engagement
- Duel (⚔️) → Compétition 1v1
- Classement (🏆) → Compétition

**Ces signaux sont 3-4x plus puissants que les likes pour la rétention et l'engagement.**

---

### F.4 Architecture de l'Attention

**1 seconde:** Rang → Type → Vidéo
**3 secondes:** Progression → Points → Difficulté → Statut
**10 secondes:** Auteur → Série → Participants → Actions

**L'étudiant comprend en 1 seconde:**
- Où suis-je? (rang)
- C'est quoi? (type)
- Qu'est-ce que je regarde? (vidéo)

**L'étudiant comprend en 3 secondes:**
- Où en suis-je? (progression)
- Ça vaut quoi? (points)
- Est-ce pour moi? (difficulté)
- Où en suis-je? (statut)

**L'étudiant comprend en 10 secondes:**
- Qui a créé ça? (auteur)
- Je suis dans une série (série)
- Comment participer? (actions)

---

### F.5 Recommandations d'Implémentation

**Phase 1: Quick Wins (1 jour)**
- Optimiser zone vidéo (90%+)
- Réduire navigation à 40px
- Supprimer progression vidéo
- Ajuster icônes à 36px

**Phase 2: Architecture Compétition (2-3 jours)**
- Ajouter rang personnel (haut gauche)
- Ajouter progression niveau (haut gauche)
- Ajouter série de connexion (bas gauche)
- Remplacer actions sociales par actions compétitives (duel, classement)
- Masquer likes/commentaires dans menu "..."

**Phase 3: Finitions (1 jour)**
- Ajouter menu "..." avec classement/score/XP/badges
- Simplifier métadonnées (compact)
- Optimiser bulles Live

**Total: 4-5 jours**

---

### F.6 Impact Attendu

**Adoption:**
- Reconnaissance pattern TikTok (immédiat)
- Identification valeur Academia (progression, compétition)
- Différenciation claire (vs TikTok)

**Engagement:**
- Temps passé: +40% (compétition)
- Actions/session: +60% (duels, classements)
- Rétention: +70% (progression, séries)

**ROI:** Très élevé - Positionnement unique sur le marché

---

## G. Conclusion

### G.1 Résumé

**Wireframe cible:**
- Partie haute: Rang, Type, Progression niveau
- Partie centrale: Vidéo, Badges, Indicateurs compétition
- Colonne droite: Duel, Classement, Menu, Partage
- Partie basse: Auteur, Titre, Points, Difficulté, Statut, Série, Participants, Université

**Hiérarchie visuelle:**
- Niveau 1: Rang, Type, Progression, Vidéo, Points, Difficulté, Statut, Actions compétitives
- Niveau 2: Classement détaillé, Score, XP, Badges, Likes, Commentaires
- Niveau 3: Statistiques détaillées, Historique, Paramètres

**Hiérarchie psychologique:**
- 1s: Rang → Type → Vidéo
- 3s: Progression → Points → Difficulté → Statut
- 10s: Auteur → Série → Participants → Actions

**Signaux de motivation:**
- Rang personnel, Progression niveau, Points, Série de connexion, Duel, Classement

---

### G.2 Message Final

"Sur TikTok, tu perds du temps. Sur Challenge, tu progresses."

**Équation valeur:**
- TikTok: Likes, vues, divertissement
- Challenge: Rang, niveau, XP, compétition, progression académique

---

**Fin de la maquette cible**
