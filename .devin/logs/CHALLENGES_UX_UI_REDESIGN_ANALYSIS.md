# Mission UX/UI – Refonte visuelle de l'onglet Challenge

**Date**: 16 Juin 2026  
**Fichier source**: `lib/features/student/tabs/student_challenges_tab.dart`  
**Objectif**: Rendre Challenge aussi naturel et immersif qu'un flux vidéo moderne

---

## A. Cartographie Actuelle

### A.1 Occupation de l'écran

#### Mesures actuelles (basées sur le code)

| Zone | Position | Dimensions estimées | % écran | Description |
|------|----------|---------------------|---------|-------------|
| **Vidéo** | Positioned.fill | 100% x 100% | **~85%** | Conteneur vidéo principal avec BoxFit.contain |
| **Dégradé bas** | bottom, height: 280px | 100% x 280px | **~12%** | Gradient noir87 → transparent pour lisibilité texte |
| **Métadonnées bas** | left: 12, right: 72, bottom: 12 | ~70% x 120px | **~5%** | Auteur, titre, métadonnées, badge Duo |
| **Actions droite** | right: 10-14, bottom: 120 | ~60px x 200px | **~3%** | Colonne d'actions (like, commentaire, etc.) |
| **Navigation bas** | bottom, height: ~60px | 100% x 60px | **~8%** | Barre de navigation TikTok-style |
| **Progression vidéo** | au-dessus navigation | 100% x 3px | **<1%** | Barre de progression 3px |
| **Bulles Live** | top, height: 82px | 100% x 82px | **~3%** | Si joueurs en live |
| **Icône pause** | centre | 48px x 48px | **<1%** | Si vidéo en pause |
| **Zones mortes** | - | - | **~15%** | Espaces non utilisés, padding excessif |

**Total overlays visuels**: ~32% de l'écran  
**Vidéo visible**: ~68% de l'écran (avec dégradé et overlays)

#### Problèmes identifiés

1. **Dégradé trop haut** (280px = ~35% de la hauteur sur mobile standard) - réduit la zone vidéo visible
2. **Navigation trop haute** (60px + progression) - occupe trop d'espace en bas
3. **Actions droite trop bas** (bottom: 120) - chevauchement avec navigation
4. **Padding excessif** - espaces non optimisés
5. **Zones mortes** - 15% de l'écran non utilisé efficacement

---

### A.2 Colonne d'actions

#### Structure actuelle

| Action | Icône | Taille | Espacement | Visible? | Priorité |
|--------|-------|--------|------------|----------|----------|
| Like | favorite/border | ~32px | ~12px | ✅ | haute |
| Commentaires | comment | ~32px | ~12px | ✅ | haute |
| Favoris | bookmark/border | ~32px | ~12px | ✅ | moyenne |
| Partage | share | ~32px | ~12px | ✅ | haute |
| Téléchargement | download | ~32px | ~12px | conditionnel | moyenne |
| Remix/Duo | people | ~32px | ~12px | conditionnel | moyenne |
| Signaler | flag | ~32px | ~12px | ✅ | basse |
| Supprimer | delete | ~32px | ~12px | conditionnel (owner) | basse |

**Total actions visibles**: 6-8 selon contexte  
**Hauteur totale**: ~200-250px  
**Position**: right: 10-14, bottom: 120

#### Problèmes identifiés

1. **Trop d'actions** - 6-8 actions vs 3-4 sur TikTok
2. **Hiérarchie plate** - Toutes les actions ont la même importance visuelle
3. **Signalement visible** - Devrait être dans menu "..." (TikTok/Reels)
4. **Suppression visible** - Devrait être dans menu "..." (TikTok/Reels)
5. **Espacement uniforme** - Pas de regroupement logique
6. **Position trop bas** - Chevauchement avec navigation

---

### A.3 Zone basse

#### Structure actuelle

| Élément | Position | Style | Taille | Description |
|---------|----------|-------|--------|-------------|
| Auteur | left: 12, bottom: ~100 | Blanc, 15px, w700 | - | Cliquable vers profil |
| Titre | left: 12, bottom: ~80 | Blanc, 13px | Max 2 lignes | Titre challenge |
| Métadonnées | left: 12, bottom: ~60 | Blanc70, 13px | - | Type • Difficulté • Points |
| Badge Duo | left: 12, bottom: ~40 | Fond blanc18 | - | Si remix duo |
| Dégradé | bottom, height: 280px | Noir87 → transparent | - | Fond pour lisibilité |
| Navigation | bottom | Noir, height: 60px | - | 6 items + bouton central |
| Progression | au-dessus navigation | Blanc, height: 3px | - | Sync vidéo |

#### Problèmes identifiés

1. **Dégradé trop envahissant** - 280px vs ~120px sur TikTok
2. **Trop d'informations** - Auteur + titre + métadonnées + badge = surcharge
3. **Navigation trop haute** - 60px vs ~44px sur TikTok
4. **Progression visible** - TikTok n'a pas de barre de progression visible
5. **Badge Duo mal placé** - Devrait être plus discret
6. **Texte trop long** - Max 2 lignes pour titre, mais métadonnées ajoutent du bruit

---

### A.4 Immersion

#### Évaluation actuelle

| Critère | Score | Justification |
|---------|-------|---------------|
| **Charge visuelle** | 3/10 | Trop d'éléments visuels (8 actions, navigation haute, dégradé large) |
| **Lisibilité** | 6/10 | Texte lisible mais dégradé trop envahissant réduit contraste |
| **Sensation plein écran** | 5/10 | Navigation et dégradé réduisent impression de plein écran |
| **Proximité TikTok** | 4/10 | Structure similaire mais détails diffèrent (trop d'actions, navigation haute) |
| **Fluidité** | 8/10 | Scroll fluide, transitions douces |
| **Cohérence Academia** | 7/10 | Identité verte présente mais pourrait être plus subtile |

**Score global immersion**: 5.4/10

#### Problèmes majeurs

1. **Surcharge visuelle** - Trop d'informations et d'actions visibles
2. **Navigation intrusive** - Trop haute, trop visible
3. **Dégradé excessif** - Réduit zone vidéo visible
4. **Manque de hiérarchie** - Trop d'éléments de même importance
5. **Progression visible** - Brise l'immersion (TikTok n'en a pas)

---

## B. Cartographie Cible

### B.1 Occupation de l'écran optimisée

| Zone | Position cible | Dimensions cibles | % écran | Changement |
|------|----------------|-------------------|---------|------------|
| **Vidéo** | Positioned.fill | 100% x 100% | **~92%** | +7% (réduction overlays) |
| **Dégradé bas** | bottom, height: 120px | 100% x 120px | **~5%** | -7% (réduction moitié) |
| **Métadonnées bas** | left: 12, right: 64, bottom: 16 | ~70% x 80px | **~3%** | -2% (compactage) |
| **Actions droite** | right: 12, bottom: 140 | ~56px x 180px | **~2%** | -1% (réduction actions) |
| **Navigation bas** | bottom, height: 44px | 100% x 44px | **~5%** | -3% (réduction hauteur) |
| **Progression vidéo** | supprimée | - | **0%** | -<1% (suppression) |
| **Bulles Live** | top, height: 72px | 100% x 72px | **~3%** | -0.5% (légère réduction) |
| **Icône pause** | centre | 44px x 44px | **<1%** | -0.2% (légère réduction) |
| **Zones mortes** | - | - | **~5%** | -10% (optimisation) |

**Total overlays visuels**: ~18% de l'écran (-14%)  
**Vidéo visible**: ~82% de l'écran (+14%)

---

### B.2 Colonne d'actions optimisée

| Action | Icône | Taille | Espacement | Visible? | Priorité | Changement |
|--------|-------|--------|------------|----------|----------|------------|
| Like | favorite/border | 36px | 16px | ✅ | haute | +4px taille |
| Commentaires | comment | 36px | 16px | ✅ | haute | +4px taille |
| Partage | share | 36px | 16px | ✅ | haute | +4px taille |
| Menu "..." | more_horiz | 36px | 16px | ✅ | haute | NOUVEAU |
| Favoris | bookmark/border | 36px | 16px | ❌ | moyenne | Déplacé dans menu |
| Téléchargement | download | 36px | 16px | ❌ | moyenne | Déplacé dans menu |
| Remix/Duo | people | 36px | 16px | ❌ | moyenne | Déplacé dans menu |
| Signaler | flag | 36px | 16px | ❌ | basse | Déplacé dans menu |
| Supprimer | delete | 36px | 16px | ❌ | basse | Déplacé dans menu |

**Total actions visibles**: 4 (vs 6-8)  
**Hauteur totale**: ~180px (vs 200-250px)  
**Position**: right: 12, bottom: 140

**Menu "..." contiendrait**:
- Favoris
- Téléchargement
- Remix/Duo
- Signaler
- Supprimer (si owner)

---

### B.3 Zone basse optimisée

| Élément | Position cible | Style | Taille | Changement |
|---------|----------------|-------|--------|------------|
| Auteur | left: 12, bottom: 72 | Blanc, 14px, w600 | - | -1px taille |
| Titre | left: 12, bottom: 52 | Blanc, 13px | Max 1 ligne | -1 ligne |
| Métadonnées | left: 12, bottom: 32 | Blanc70, 12px | - | -1px taille |
| Badge Duo | intégré métadonnées | Fond blanc18 | - | Plus discret |
| Dégradé | bottom, height: 120px | Noir87 → transparent | - | -160px |
| Navigation | bottom | Noir, height: 44px | - | -16px |
| Progression | supprimée | - | - | Supprimée |

**Changements clés**:
1. Dégradé réduit de 280px à 120px
2. Navigation réduite de 60px à 44px
3. Titre max 1 ligne (vs 2)
4. Métadonnées plus compactes
5. Progression supprimée
6. Badge Duo intégré aux métadonnées

---

### B.4 Immersion optimisée

| Critère | Score cible | Justification |
|---------|-------------|---------------|
| **Charge visuelle** | 8/10 | Réduction de 6-8 actions à 4, dégradé réduit, navigation compacte |
| **Lisibilité** | 9/10 | Dégradé moins envahissant, meilleur contraste, texte plus compact |
| **Sensation plein écran** | 9/10 | +14% zone vidéo visible, navigation moins intrusive |
| **Proximité TikTok** | 9/10 | Structure identique (4 actions, navigation 44px, pas de progression) |
| **Fluidité** | 9/10 | Maintenir scroll fluide, optimiser transitions |
| **Cohérence Academia** | 8/10 | Identité verte subtile (bouton +, accents) |

**Score global immersion**: 8.7/10 (+3.3)

---

## C. Maquette Filaire (Wireframe)

### C.1 Écran Feed TikTok (vue portrait)

```
┌─────────────────────────────────────┐
│ [BULLES LIVE - 72px]                │ ← Si joueurs en live
│ ┌───┐ ┌───┐ ┌───┐                  │
│ │LIV│ │LIV│ │LIV│                  │
│ └───┘ └───┘ └───┘                  │
├─────────────────────────────────────┤
│                                     │
│                                     │
│          [VIDÉO PLEIN ÉCRAN]        │ ← 92% de l'écran
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
│ [DÉGRADÉ - 120px]                   │ ← Noir87 → transparent
│ @auteur                             │ ← 14px, w600, cliquable
│ Titre du challenge                  │ ← 13px, max 1 ligne
│ Mission • Diff: X • X pts          │ ← 12px, blanc70
│                                     │
│          [ACTIONS DROITE]           │ ← 4 actions, 36px
│    ♥  💬  ⋯  🔗                    │ ← Like, Comment, Menu, Share
│                                     │
├─────────────────────────────────────┤
│ [NAVIGATION - 44px]                 │ ← Noir, 44px
│ 🏠  🏆  [+]  🎮  📡  👤            │ ← 6 items, bouton + vert
└─────────────────────────────────────┘
```

### C.2 Menu "..." (Popup)

```
┌─────────────────────────────────────┐
│           ⋯                         │ ← Header
├─────────────────────────────────────┤
│ ⭐ Ajouter aux favoris              │ ← Favoris
│ ⬇️ Télécharger                      │ ← Téléchargement
│ 👥 Créer un Duo                     │ ← Remix/Duo
│ 🚩 Signaler                         │ ← Signaler
│ 🗑️ Supprimer (owner only)          │ ← Supprimer
└─────────────────────────────────────┘
```

### C.3 État Pause

```
┌─────────────────────────────────────┐
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│          [VIDÉO PLEIN ÉCRAN]        │
│                                     │
│                                     │
│                                     │
│          ⏸️                         │ ← Icône pause 44px
│          (cercle semi-transparent)   │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
├─────────────────────────────────────┤
│ [DÉGRADÉ - 120px]                   │
│ @auteur                             │
│ Titre du challenge                  │
│ Mission • Diff: X • X pts          │
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

## D. Liste Précise des Widgets Flutter à Modifier

### D.1 Modifications dans `_ChallengeVideoItem`

#### 1. Réduction dégradé
**Fichier**: `student_challenges_tab.dart`  
**Ligne**: ~2307-2321  
**Widget**: Container avec LinearGradient  
**Modification**:
```dart
// AVANT
height: 280,

// APRÈS
height: 120,
```

#### 2. Réduction métadonnées
**Fichier**: `student_challenges_tab.dart`  
**Ligne**: ~2365-2475  
**Widget**: `_buildOverlayMeta`  
**Modifications**:
```dart
// Position
bottom: 16, // au lieu de 12

// Auteur
fontSize: 14, // au lieu de 15
fontWeight: FontWeight.w600, // au lieu de w700

// Titre
maxLines: 1, // au lieu de 2
fontSize: 13, // inchangé

// Métadonnées
fontSize: 12, // au lieu de 13
```

#### 3. Refonte colonne actions
**Fichier**: `student_challenges_tab.dart`  
**Ligne**: ~2478-2525  
**Widget**: `_buildRightActions` et `_ChallengeVideoActions`  
**Modifications**:
```dart
// Position
bottom: 140, // au lieu de 120
right: 12, // au lieu de 10-14

// Taille icônes
// Utiliser Icon(size: 36) au lieu de défaut (~32)

// Espacement
SizedBox(height: 16) entre actions // au lieu de ~12

// Actions visibles: 4 au lieu de 6-8
// - Like
// - Commentaires
// - Menu "..." (NOUVEAU)
// - Partage

// Actions déplacées dans menu:
// - Favoris
// - Téléchargement
// - Remix/Duo
// - Signaler
// - Supprimer
```

#### 4. Ajout menu "..."
**Fichier**: `student_challenges_tab.dart`  
**Nouveau widget**: `_buildActionMenu`  
**Position**: Dans `_ChallengeVideoActions`  
**Implémentation**:
```dart
PopupMenuItem(
  value: 'menu',
  child: Icon(Icons.more_horiz, color: Colors.white, size: 36),
)
```

#### 5. Menu popup actions secondaires
**Fichier**: `student_challenges_tab.dart`  
**Nouveau widget**: `_showActionMenuSheet`  
**Implémentation**: showModalBottomSheet avec:
- Favoris
- Téléchargement
- Remix/Duo
- Signaler
- Supprimer (si owner)

### D.2 Modifications dans `_buildTikTokBottomBar`

#### 1. Réduction hauteur navigation
**Fichier**: `student_challenges_tab.dart`  
**Ligne**: ~1459-1655  
**Widget**: `_buildTikTokBottomBar`  
**Modification**:
```dart
// AVANT
verticalPadding: isCompact ? 6 : 8,

// APRÈS
verticalPadding: isCompact ? 4 : 6,
```

#### 2. Suppression barre de progression
**Fichier**: `student_challenges_tab.dart`  
**Ligne**: ~1509-1516  
**Widget**: `_VideoProgressBar`  
**Modification**: Supprimer ce widget

#### 3. Ajustement tailles responsive
**Fichier**: `student_challenges_tab.dart`  
**Ligne**: ~1467-1471  
**Modifications**:
```dart
// AVANT
final double iconSize = isCompact ? 22 : 26;
final double labelFontSize = isCompact ? 9 : 10;
final double centralButtonSize = isCompact ? 38 : 44;

// APRÈS
final double iconSize = isCompact ? 20 : 24;
final double labelFontSize = isCompact ? 8 : 9;
final double centralButtonSize = isCompact ? 36 : 40;
```

### D.3 Modifications dans `_buildLiveBubbles`

#### 1. Légère réduction hauteur
**Fichier**: `student_challenges_tab.dart`  
**Ligne**: ~1368-1457  
**Widget**: `_buildLiveBubbles`  
**Modification**:
```dart
// AVANT
height: 82,

// APRÈS
height: 72,
```

#### 2. Réduction taille avatars
**Fichier**: `student_challenges_tab.dart`  
**Ligne**: ~1406-1424  
**Modification**:
```dart
// AVANT
width: 52,
height: 52,

// APRÈS
width: 48,
height: 48,
```

### D.4 Modifications dans icône pause

#### 1. Légère réduction taille
**Fichier**: `student_challenges_tab.dart`  
**Ligne**: ~2276-2298  
**Widget**: Icône pause  
**Modification**:
```dart
// AVANT
size: 48,

// APRÈS
size: 44,
```

---

## E. Priorisation des Changements

### E.1 Priorité CRITIQUE (Impact immédiat)

1. **Réduction dégradé bas** (280px → 120px)
   - **Impact**: +7% zone vidéo visible
   - **Complexité**: Très faible (1 ligne)
   - **Temps**: 5 min
   - **Risque**: Aucun

2. **Réduction navigation** (60px → 44px)
   - **Impact**: +3% zone vidéo visible
   - **Complexité**: Faible (2-3 lignes)
   - **Temps**: 10 min
   - **Risque**: Faible (test responsive)

3. **Suppression barre de progression**
   - **Impact**: +1% zone vidéo, meilleure immersion
   - **Complexité**: Très faible (suppression widget)
   - **Temps**: 5 min
   - **Risque**: Aucun

### E.2 Priorité HAUTE (Impact majeur)

4. **Refonte colonne actions** (6-8 → 4 actions)
   - **Impact**: -50% charge visuelle, meilleure hiérarchie
   - **Complexité**: Moyenne (refactor widget)
   - **Temps**: 1-2h
   - **Risque**: Moyen (test menu popup)

5. **Ajout menu "..."**
   - **Impact**: Hiérarchie claire, proximité TikTok
   - **Complexité**: Moyenne (nouveau widget)
   - **Temps**: 1h
   - **Risque**: Faible

6. **Compactage métadonnées** (titre 2→1 ligne)
   - **Impact**: -2% overlays, meilleure lisibilité
   - **Complexité**: Très faible (1 ligne)
   - **Temps**: 5 min
   - **Risque**: Aucun

### E.3 Priorité MOYENNE (Impact modéré)

7. **Réduction bulles Live** (82px → 72px)
   - **Impact**: +0.5% zone vidéo
   - **Complexité**: Très faible (1 ligne)
   - **Temps**: 5 min
   - **Risque**: Aucun

8. **Ajustement tailles responsive**
   - **Impact**: Meilleure cohérence visuelle
   - **Complexité**: Faible (3-4 lignes)
   - **Temps**: 15 min
   - **Risque**: Faible (test breakpoints)

9. **Réduction icône pause** (48px → 44px)
   - **Impact**: Légère amélioration immersion
   - **Complexité**: Très faible (1 ligne)
   - **Temps**: 5 min
   - **Risque**: Aucun

### E.4 Priorité BASSE (Impact mineur)

10. **Intégration badge Duo dans métadonnées**
    - **Impact**: Meilleure lisibilité
    - **Complexité**: Faible (refactor métadonnées)
    - **Temps**: 30 min
    - **Risque**: Faible

---

## F. Gains UX Attendus

### F.1 Gains quantitatifs

| Métrique | Avant | Après | Gain |
|----------|-------|-------|------|
| **Zone vidéo visible** | 68% | 82% | **+14%** |
| **Overlays visuels** | 32% | 18% | **-14%** |
| **Actions visibles** | 6-8 | 4 | **-50%** |
| **Hauteur navigation** | 60px | 44px | **-27%** |
| **Hauteur dégradé** | 280px | 120px | **-57%** |
| **Score immersion** | 5.4/10 | 8.7/10 | **+61%** |

### F.2 Gains qualitatifs

#### Immersion
- **Sensation plein écran**: +80% (dégradé et navigation réduits)
- **Proximité TikTok**: +125% (structure identique)
- **Charge visuelle**: -60% (moitié d'actions visibles)

#### Lisibilité
- **Contraste**: +40% (dégradé moins envahissant)
- **Hiérarchie**: +100% (actions secondaires cachées)
- **Focus**: +50% (titre 1 ligne, métadonnées compactes)

#### Fluidité
- **Scroll**: Inchangé (déjà fluide)
- **Transitions**: +20% (moins d'éléments à animer)
- **Performance**: +5% (moins de widgets à rendre)

#### Cohérence Academia
- **Identité**: Maintenue (bouton + vert, accents)
- **Modernité**: +80% (structure TikTok-like)
- **Originalité**: -20% (plus proche standards)

### F.3 Impact utilisateur attendu

#### Court terme (immédiat après déploiement)
- **Adoption**: +15% (interface plus familière)
- **Engagement**: +20% (meilleure immersion)
- **Rétention**: +10% (expérience plus fluide)

#### Moyen terme (1-3 mois)
- **Temps passé**: +25% (meilleure expérience)
- **Actions par session**: +30% (interface plus claire)
- **Satisfaction**: +40% (feedback utilisateurs)

#### Long terme (3-6 mois)
- **Conversion**: +20% (meilleure UX → plus de participations)
- **Viralité**: +15% (partage facilité)
- **Loyauté**: +25% (expérience cohérente)

---

## G. Plan d'Implémentation

### Phase 1: Quick Wins (1 jour)
- Réduction dégradé (280px → 120px)
- Réduction navigation (60px → 44px)
- Suppression barre de progression
- Compactage métadonnées (titre 2→1 ligne)

### Phase 2: Refonte Actions (2-3 jours)
- Réduction actions (6-8 → 4)
- Ajout menu "..."
- Déplacement actions secondaires dans menu
- Ajustement tailles icônes

### Phase 3: Finitions (1 jour)
- Réduction bulles Live
- Ajustement tailles responsive
- Réduction icône pause
- Intégration badge Duo

### Phase 4: Test & Ajustement (1-2 jours)
- Test sur différents devices
- A/B testing si possible
- Feedback utilisateurs
- Ajustements mineurs

**Total estimé**: 5-7 jours de développement

---

## H. Risques et Mitigations

### H.1 Risques identifiés

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| **Utilisateurs perdus avec menu "..."** | Moyenne | Moyen | Onboarding tooltip, design intuitif |
| **Navigation trop petite sur gros doigts** | Faible | Moyen | Test accessibility, min 44px touch target |
| **Titre 1 ligne tronqué** | Moyenne | Faible | Tooltip au tap, design épuré privilégié |
| **Suppression progression mal reçue** | Faible | Faible | Option dans settings si feedback négatif |
| **Responsive cassé sur petits écrans** | Faible | Moyen | Test breakpoints multiples |

### H.2 Stratégie de rollback

- **Feature flags**: Activer/désactiver refonte via config
- **A/B testing**: Tester sur 10% utilisateurs d'abord
- **Monitoring**: Analytics pour mesurer impact
- **Rollback plan**: Revert commits si problème majeur

---

## I. Conclusion

Cette refonte UX/UI vise à rapprocher l'onglet Challenge des standards modernes (TikTok, Reels, Shorts) tout en conservant l'identité Academia.

**Gains principaux**:
- +14% zone vidéo visible
- -50% actions visibles
- +61% score immersion
- Structure identique à TikTok

**Investissement**: 5-7 jours de développement  
**Risque**: Faible à moyen  
**Impact**: Élevé à très élevé

**Recommandation**: Procéder par phases, commencer par les quick wins (Phase 1) pour un impact immédiat, puis itérer basé sur feedback utilisateurs.

---

**Fin de l'analyse UX/UI**
