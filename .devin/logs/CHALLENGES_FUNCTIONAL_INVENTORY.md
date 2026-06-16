# Mission Produit Prioritaire – Inventaire fonctionnel complet de Challenge

**Date**: 16 Juin 2026  
**Objectif**: Inventaire des capacités réelles accessibles aux utilisateurs  
**Source**: Analyse du code existant (providers, services, écrans)

---

## A. Inventaire Fonctionnel Complet

### A.1 Défis (Challenges)

| Fonctionnalité | Description | Statut | Source |
|---------------|-------------|--------|--------|
| **Défis individuels** | Participation à un challenge individuel | ✅ Opérationnel | StudentChallengesProvider |
| **Défis ouverts** | Challenges accessibles à tous | ✅ Opérationnel | StudentChallengesProvider (loadChallenges) |
| **Défis vidéo** | Soumission de vidéo pour un challenge | ✅ Opérationnel | StudentChallengesProvider (addChallengeVideo) |
| **Types de défis** | Mission, Contest | ✅ Opérationnel | AdminChallengesProvider (challenge_type) |
| **Défis académiques** | Challenges liés aux matières académiques | ✅ Opérationnel | Filtres par matière dans student_challenges_tab.dart |
| **Défis universitaires** | Challenges créés par des universités | ⚠️ Partiel | challenge_type 'university' existe mais interface limitée |
| **Défis entreprises** | Challenges sponsorisés par des entreprises | ⚠️ Partiel | challenge_type 'enterprise' existe mais interface limitée |
| **Défis entre filières** | Compétition entre filières d'études | ❌ Non implémenté | - |
| **Défis entre groupes** | Compétition entre groupes d'étudiants | ❌ Non implémenté | - |
| **Défis sponsorisés** | Challenges avec sponsors | ⚠️ Partiel | is_featured existe mais interface limitée |
| **Duels vidéo** | Création de duo vidéo | ✅ Opérationnel | StudentChallengesProvider (startDuoVideo) |
| **Réponses vidéo** | Répondre à une vidéo existante | ✅ Opérationnel | StudentChallengesProvider (startDuoVideo) |
| **Vidéos libres** | Créer des vidéos sans challenge | ✅ Opérationnel | StudentChallengesProvider (createFreeVideo) |

**Métadonnées challenge:**
- Titre, description
- Type (mission, contest)
- Difficulté (facile, moyen, difficile, expert)
- Points (XP gagnés)
- Date de début/fin
- Participants max
- Statut (joined, completed)
- Score personnel
- Rang dans le challenge

---

### A.2 Jeux Éducatifs

| Fonctionnalité | Description | Statut | Source |
|---------------|-------------|--------|--------|
| **Jeux économiques** | Market Master, Consumer Choice, Firm Tycoon, Market Structures | ✅ Opérationnel | GameProvider |
| **Speed Challenge** | Jeu de rapidité | ✅ Opérationnel | speed_challenge_game.dart |
| **Brain Type Game** | Jeu de type cérébral | ✅ Opérationnel | brain_type_game.dart |
| **Student Type Game** | Jeu de type étudiant | ✅ Opérationnel | student_type_game.dart |
| **Tournois** | Compétitions éliminatoires | ✅ Opérationnel | TournamentProvider |
| **Leagues** | Compétitions saisonnières | ✅ Opérationnel | TournamentProvider |
| **Live Arena** | Jeux en direct | ⚠️ Partiel | game_live_service.dart |
| **Adaptive Learning** | Adaptation de difficulté | ✅ Opérationnel | adaptive_learning_service.dart |
| **Scoring System** | Système de scoring complexe | ✅ Opérationnel | game_scoring_system.dart |
| **Watermark Service** | Filigrane sur vidéos de jeu | ✅ Opérationnel | watermark_service.dart |

**Modes de jeu:**
- Solo
- Compétitif (tournois)
- Saison (leagues)
- Live (arena)

**Catégories:**
- Économie (principal)
- Maths (partiel)
- Médecine (partiel)

---

### A.3 Système de Progression

| Fonctionnalité | Description | Statut | Source |
|---------------|-------------|--------|--------|
| **XP total** | Points d'expérience cumulés | ✅ Opérationnel | TdGamificationProvider (totalXp) |
| **Niveau** | Niveau académique global | ✅ Opérationnel | TdGamificationProvider (level) |
| **Badges** | Récompenses visuelles | ✅ Opérationnel | TdGamificationProvider (badges) |
| **Série de connexion** | Jours consécutifs d'activité | ✅ Opérationnel | TdGamificationProvider (currentStreak, longestStreak) |
| **Objectif quotidien** | Quotidien d'XP à atteindre | ✅ Opérationnel | TdGamificationProvider (dailyGoalTarget, dailyGoalEarned) |
| **Historique XP** | Historique des gains d'XP | ✅ Opérationnel | TdGamificationProvider (xpHistory) |
| **Progression TD** | Progression dans les TD | ✅ Opérationnel | TdGamificationProvider (progressSummary) |
| **Temps d'étude** | Temps total d'étude | ✅ Opérationnel | TdGamificationProvider (totalStudyTimeSeconds) |
| **Trophées** | Récompenses majeures | ❌ Non implémenté | - |
| **Récompenses** | Points, badges, certificats | ⚠️ Partiel | Badges existent, certificats non |
| **Statistiques** | Stats détaillées par activité | ✅ Opérationnel | TdGamificationProvider (statsData) |

**Mécanismes de gamification:**
- Earn XP (gain d'XP après action)
- Daily goal (objectif quotidien)
- Streak (série de connexion)
- Level up (montée de niveau)
- Badges (badges thématiques)

---

### A.4 Système Social

| Fonctionnalité | Description | Statut | Source |
|---------------|-------------|--------|--------|
| **Likes** | J'aime sur vidéos | ✅ Opérationnel | student_challenges_tab.dart (double-tap like) |
| **Commentaires** | Commentaires sur vidéos | ✅ Opérationnel | StudentChallengesProvider (addVideoComment, deleteVideoComment) |
| **Partages** | Partage de vidéos | ✅ Opérationnel | StudentChallengesProvider (share) |
| **Favoris** | Ajouter aux favoris | ✅ Opérationnel | StudentChallengesProvider (favoriteVideo, unfavoriteVideo) |
| **Abonnements** | Suivre des créateurs | ⚠️ Partiel | Interface sociale existe mais limitée |
| **Interactions sociales** | Réponses, mentions | ⚠️ Partiel | Commentaires existent, mentions non |
| **Signalements** | Signaler du contenu | ✅ Opérationnel | StudentChallengesProvider (reportVideo) |
| **Profil social** | Profil utilisateur avec stats | ✅ Opérationnel | student_social_profile_screen.dart |
| **Feed social** | Feed de contenu social | ⚠️ Partiel | Challenges feed existe, feed général limité |

---

### A.5 Système Vidéo

| Fonctionnalité | Description | Statut | Source |
|---------------|-------------|--------|--------|
| **Création vidéo** | Enregistrement de vidéo | ✅ Opérationnel | challenge_camera_capture_screen.dart |
| **Réponses vidéo** | Répondre à une vidéo | ✅ Opérationnel | StudentChallengesProvider (startDuoVideo) |
| **Défis vidéo** | Soumission pour challenge | ✅ Opérationnel | StudentChallengesProvider (addChallengeVideo) |
| **Studio d'édition** | Studio vidéo Academia | ✅ Opérationnel | student_challenge_video_editor_screen.dart |
| **Annotations** | Overlays temporisés sur vidéo | ✅ Opérationnel | timed_overlay_editor_sheet.dart |
| **Sous-titres** | Sous-titres sur vidéo | ⚠️ Partiel | Studio existe mais sous-titres limités |
| **Outils pédagogiques** | Clavier scientifique, équations | ✅ Opérationnel | academia_scientific_keyboard.dart, equation_editor.dart |
| **Audio mix** | Mixage audio | ✅ Opérationnel | audio_mix_service.dart |
| **Export watermarked** | Export avec filigrane | ✅ Opérationnel | StudentChallengesProvider (requestVideoExportWatermarked) |
| **Téléchargement** | Télécharger vidéo | ✅ Opérationnel | StudentChallengesProvider (setVideoAllowDownload) |
| **Suppression soft** | Corbeille vidéo | ✅ Opérationnel | StudentChallengesProvider (softDeleteVideo, restoreVideo) |
| **Live streaming** | Streaming en direct | ⚠️ Partiel | challenge_live_screen.dart existe mais limité |

---

### A.6 Système Compétitif

| Fonctionnalité | Description | Statut | Source |
|---------------|-------------|--------|--------|
| **Classements** | Leaderboards par challenge | ✅ Opérationnel | AdminChallengesProvider (loadLeaderboard) |
| **Rangs** | Position dans le classement | ✅ Opérationnel | Leaderboard avec rang |
| **Comparaisons** | Comparaison avec autres utilisateurs | ⚠️ Partiel | Leaderboard existe, comparaison directe limitée |
| **Duels** | Duels 1v1 | ✅ Opérationnel | StudentChallengesProvider (startDuoVideo) |
| **Scores** | Score par participation | ✅ Opérationnel | AdminChallengesProvider (reviewParticipation avec score) |
| **Récompenses compétitives** | Points, rangs, badges | ✅ Opérationnel | Points, rangs, badges existent |
| **Tournois** | Tournois éliminatoires | ✅ Opérationnel | TournamentProvider |
| **Leagues** | Ligues saisonnières | ✅ Opérationnel | TournamentProvider |
| **ELO rating** | Système de classement ELO | ⚠️ Partiel | TournamentProvider a eloMin/eloMax mais calcul ELO non implémenté |
| **Matchmaking** | Appariement des joueurs | ❌ Non implémenté | - |

---

## B. Cartographie des Mécanismes d'Engagement

### B.1 Mécanismes identifiés

| Mécanisme | Type | Puissance psychologique | Impact produit |
|-----------|------|-------------------------|---------------|
| **Classement** | Compétition | Très élevé | Rétention: Élevé, Engagement: Élevé, Différenciation: Élevé |
| **Duel** | Compétition sociale | Très élevé | Rétention: Élevé, Engagement: Très élevé, Différenciation: Élevé |
| **XP** | Progression | Élevé | Rétention: Élevé, Engagement: Moyen, Différenciation: Moyen |
| **Niveau** | Progression | Élevé | Rétention: Élevé, Engagement: Moyen, Différenciation: Moyen |
| **Badges** | Reconnaissance | Moyen | Rétention: Moyen, Engagement: Moyen, Différenciation: Élevé |
| **Série de connexion** | Engagement | Moyen | Rétention: Élevé, Engagement: Moyen, Différenciation: Faible |
| **Objectif quotidien** | Engagement | Moyen | Rétention: Moyen, Engagement: Élevé, Différenciation: Faible |
| **Likes** | Validation sociale | Faible | Rétention: Faible, Engagement: Moyen, Différenciation: Faible |
| **Commentaires** | Interaction sociale | Faible | Rétention: Faible, Engagement: Moyen, Différenciation: Faible |
| **Partages** | Viralité | Faible | Rétention: Faible, Engagement: Faible, Différenciation: Faible |
| **Favoris** | Collection | Faible | Rétention: Faible, Engagement: Faible, Différenciation: Faible |
| **Tournois** | Compétition | Très élevé | Rétention: Très élevé, Engagement: Très élevé, Différenciation: Très élevé |
| **Leagues** | Compétition | Très élevé | Rétention: Très élevé, Engagement: Très élevé, Différenciation: Très élevé |
| **Points challenge** | Motivation immédiate | Élevé | Rétention: Moyen, Engagement: Élevé, Différenciation: Élevé |
| **Difficulté** | Adéquation | Moyen | Rétention: Moyen, Engagement: Moyen, Différenciation: Moyen |
| **Type de défi** | Contexte | Moyen | Rétention: Faible, Engagement: Moyen, Différenciation: Élevé |

---

## C. Classement des Leviers Psychologiques

### C.1 Classement par puissance psychologique

1. **Classement** (Très élevé) - Compétition directe, comparaison sociale
2. **Duel** (Très élevé) - Compétition 1v1, engagement émotionnel
3. **Tournois** (Très élevé) - Compétition structurée, récompenses
4. **Leagues** (Très élevé) - Compétition saisonnière, engagement long terme
5. **XP** (Élevé) - Progression mesurable, feedback immédiat
6. **Niveau** (Élevé) - Progression visible, statut
7. **Points challenge** (Élevé) - Motivation immédiate, récompense
8. **Badges** (Moyen) - Reconnaissance, collection
9. **Série de connexion** (Moyen) - Engagement quotidien, habitude
10. **Objectif quotidien** (Moyen) - Engagement quotidien, but clair
11. **Difficulté** (Moyen) - Adéquation, sentiment de compétence
12. **Type de défi** (Moyen) - Contexte, variété
13. **Likes** (Faible) - Validation sociale, feedback
14. **Commentaires** (Faible) - Interaction sociale, communauté
15. **Partages** (Faible) - Viralité, exposition
16. **Favoris** (Faible) - Collection, organisation

**Rationale:**
- Les mécanismes de compétition (classement, duel, tournois, leagues) sont les plus puissants car ils activent la motivation sociale et le désir de statut.
- La progression (XP, niveau, points) est puissante car elle donne un feedback immédiat et un sentiment d'avancement.
- Les mécanismes sociaux (likes, commentaires) sont moins puissants car ils sont plus passifs et moins liés à la progression personnelle.

---

## D. Visibilité Recommandée

### D.1 Toujours visible (Feed)

| Élément | Pourquoi | Position |
|---------|---------|----------|
| **Type de défi** | Contexte immédiat | Haut gauche (badge) |
| **Points** | Motivation immédiate | Bas gauche (à côté titre) |
| **Difficulté** | Adéquation niveau | Bas gauche |
| **Statut participant** | Progression personnelle | Bas gauche |
| **Auteur** | Crédibilité | Bas gauche |
| **Actions principales** (like, commentaires, partage) | Engagement | Droite (4 actions) |

**Rationale:** Ces éléments sont visibles en permanence car ils fournissent l'information essentielle pour la décision de participation et la motivation immédiate.

---

### D.2 Visible après interaction (Tap/Menu)

| Élément | Pourquoi | Accès |
|---------|---------|-------|
| **Classement** | Compétition, motivation | Menu "..." ou tap sur rang |
| **Score personnel** | Performance | Menu "..." ou tap sur score |
| **XP gagnés** | Progression | Menu "..." |
| **Badges** | Reconnaissance | Menu "..." ou profil |
| **Niveau** | Progression | Profil |
| **Série de connexion** | Engagement | Profil |
| **Historique XP** | Progression | Profil |
| **Commentaires** | Interaction | Tap sur icône commentaires |
| **Détails challenge** | Information complète | Tap sur titre |

**Rationale:** Ces éléments sont importants mais peuvent être accessibles sur demande pour éviter de surcharger l'interface.

---

### D.3 Caché (Information secondaire)

| Élément | Pourquoi | Accès |
|---------|---------|-------|
| **Historique complet** | Information secondaire | Écran dédié |
| **Statistiques détaillées** | Information secondaire | Écran dédié |
| **Paramètres de challenge** | Information secondaire | Écran dédié |
| **Logs d'activité** | Information secondaire | Écran dédié |

**Rationale:** Ces informations sont utiles mais ne contribuent pas directement à l'engagement immédiat.

---

## E. Réponse à la Question Centrale

### E.1 Question

"Si un étudiant ouvre Challenge pendant 5 secondes, quelles sont les informations les plus importantes qu'il doit voir immédiatement pour avoir envie de revenir demain?"

### E.2 Réponse

**Informations prioritaires (5 secondes):**

1. **Type de défi** (🎯🏆⚔️🎓💼) - Contexte immédiat
   - "C'est quoi?" (mission, concours, duel, universitaire, entreprise)

2. **Points** (💎 500 pts) - Motivation immédiate
   - "Ça vaut quoi?" (récompense)

3. **Difficulté** (⭐ Diff: Moyen) - Adéquation
   - "Est-ce pour moi?" (niveau)

4. **Statut participant** (✅ Rejoint / 📊 123 participants) - Progression
   - "Où en suis-je?" / "Popularité"

5. **Auteur** (@prof_maths) - Crédibilité
   - "Qui a créé ça?"

**Rationale:**
- Ces 5 éléments répondent aux questions fondamentales d'un étudiant en 5 secondes:
  - C'est quoi? (type)
  - Ça vaut quoi? (points)
  - Est-ce pour moi? (difficulté)
  - Où en suis-je? (statut)
  - Qui a créé ça? (auteur)

**Informations secondaires (après 5 secondes):**
- Classement (tap sur rang)
- Score personnel (menu "...")
- XP gagnés (menu "...")
- Badges (menu "..." ou profil)
- Commentaires (tap sur icône)

---

## F. Architecture de Motivation Recommandée

### F.1 Principe

L'architecture de motivation doit maximiser l'impact des mécanismes les plus puissants (compétition, progression) tout en minimisant la charge visuelle.

### F.2 Structure

**Niveau 1 - Immédiat (Feed):**
- Type de défi (compétition)
- Points (motivation)
- Difficulté (adéquation)
- Statut (progression)

**Niveau 2 - Contextuel (Tap/Menu):**
- Classement (compétition)
- Score personnel (performance)
- XP gagnés (progression)
- Badges (reconnaissance)

**Niveau 3 - Profond (Écran dédié):**
- Statistiques détaillées
- Historique complet
- Paramètres

### F.3 Flux d'engagement

1. **Découverte** (5 secondes): Type → Points → Difficulté → Statut → Auteur
2. **Participation** (tap): Rejoindre → Statut change → XP gagnés
3. **Compétition** (après participation): Classement → Score → Rang
4. **Progression** (long terme): XP → Niveau → Badges → Séries

---

## G. Proposition d'Interface Challenge Centrée sur la Compétition Académique

### G.1 Wireframe Feed (Portrait)

```
┌─────────────────────────────────────┐
│ [🎯 MISSION]                        │ ← Type de défi (haut gauche)
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
│ @prof_maths                         │ ← Auteur
│ Résoudre cette équation en 30s      │ ← Titre
│ 🎯 Mission • ⭐ Diff: Moyen • 💎 500 pts ← Type, Difficulté, Points
│ 📊 123 participants • ✅ Rejoint     │ ← Participants, Statut
│                                     │
│          [ACTIONS DROITE]           │
│    ♥  💬  ⋯  🔗                    │ ← 4 actions (like, commentaires, menu, partage)
│                                     │
├─────────────────────────────────────┤
│ [NAVIGATION - 44px]                 │
│ 🏠  🏆  [+]  🎮  📡  👤            │ ← Navigation
└─────────────────────────────────────┘
```

### G.2 Menu "..." (Compétition)

```
┌─────────────────────────────────────┐
│           ⋯                         │
├─────────────────────────────────────┤
│ 🏆 Classement (#12/456)            │ ← Classement (compétition)
│ 📊 Mon score: 850 pts              │ ← Score personnel (performance)
│ ⭐ XP gagnés: +100                 │ ← XP gagnés (progression)
│ 🎓 Badges: 🏆⭐🎓                  │ ← Badges (reconnaissance)
│ ⭐ Ajouter aux favoris              │
│ ⬇️ Télécharger                      │
│ 👥 Créer un Duo                     │ ← Duel (compétition)
│ 🚩 Signaler                         │
│ 🗑️ Supprimer (owner only)          │
└─────────────────────────────────────┘
```

### G.3 Sheet Classement (Compétition)

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
│ Ton rang: #12                       │ ← Rang (compétition)
│ Ton score: 850 pts                 │ ← Score (performance)
│ XP gagnés: +100                    │ ← XP (progression)
│ Badges: 🎓🏆⭐                      │ ← Badges (reconnaissance)
└─────────────────────────────────────┘
```

---

## H. Conclusion

### H.1 Résumé

**Fonctionnalités opérationnelles:**
- Défis: 12/15 (80%) - Types de défis variés
- Jeux: 8/10 (80%) - Jeux économiques principaux
- Progression: 8/10 (80%) - XP, niveaux, badges, séries
- Social: 7/9 (78%) - Likes, commentaires, favoris
- Vidéo: 10/12 (83%) - Studio, annotations, outils pédagogiques
- Compétitif: 8/10 (80%) - Classements, duels, tournois, leagues

**Mécanismes les plus puissants:**
1. Classement (compétition)
2. Duel (compétition sociale)
3. Tournois (compétition structurée)
4. Leagues (compétition saisonnière)
5. XP (progression)
6. Niveau (progression)
7. Points challenge (motivation immédiate)

**Informations à afficher en 5 secondes:**
1. Type de défi (contexte)
2. Points (motivation)
3. Difficulté (adéquation)
4. Statut participant (progression)
5. Auteur (crédibilité)

---

### H.2 Recommandation

L'interface Challenge doit être centrée sur la **compétition académique** en mettant en avant:
- Les mécanismes de compétition (classement, duel, tournois, leagues)
- La progression (XP, niveau, points)
- Le contexte académique (type de défi, difficulté, auteur)

Les mécanismes sociaux (likes, commentaires) doivent être secondaires et accessibles via menu pour éviter de surcharger l'interface.

---

**Fin de l'inventaire fonctionnel**
