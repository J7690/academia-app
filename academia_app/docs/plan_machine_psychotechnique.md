# Machine Psychotechnique IA — Proposition complète
## Le dispositif de préparation aux tests psychotechniques le plus robuste d'Afrique
**Date** : 16 Mars 2026

---

## 1. ANATOMIE COMPLÈTE DES TESTS PSYCHOTECHNIQUES

### 1.1 Les 12 types de tests utilisés dans les concours (BF + international)

Mes recherches sur les grandes plateformes (mon-qi.com, psychotechnique.be, concours-formation.fr, blog-rh.com, test-psychotechnique-en-ligne.fr, psychotechniqua.com, evalquiz.com) révèlent 12 catégories distinctes :

| # | Type | Capacité testée | Visuel | Générable algorithmiquement ? |
|---|------|----------------|--------|------|
| 1 | **Suites numériques** | Raisonnement inductif | Nombres | ✅ OUI — opérateurs mathématiques |
| 2 | **Suites alphabétiques** | Raisonnement inductif | Lettres | ✅ OUI — intervalles entre lettres |
| 3 | **Suites alphanumériques** | Raisonnement inductif | Lettres + chiffres | ✅ OUI — 2 suites imbriquées |
| 4 | **Dominos** | Raisonnement abstrait | 🎲 Images de dominos | ✅ OUI — valeurs 0-6 modulo 7 |
| 5 | **Cartes à jouer** | Raisonnement abstrait | 🃏 Images de cartes | ✅ OUI — valeurs 1-13 + 4 couleurs |
| 6 | **Matrices de Raven** | Intelligence fluide | 🔲 Grilles 3×3 de formes | ⚠️ PARTIELLEMENT — règles combinables |
| 7 | **Analogies verbales** | Raisonnement verbal | Mots | ✅ OUI — via LLM (OpenRouter) |
| 8 | **Analogies graphiques** | Raisonnement spatial | Formes géométriques | ⚠️ Nécessite rendu SVG |
| 9 | **Intrus (verbal)** | Classification | Mots | ✅ OUI — via LLM |
| 10 | **Intrus (graphique)** | Classification visuelle | Formes | ⚠️ Nécessite rendu SVG |
| 11 | **Attention / Concentration** | Rapidité + précision | Grilles de symboles | ✅ OUI — génération de grilles |
| 12 | **Masterminds** | Déduction logique | Couleurs + positions | ✅ OUI — combinatoire |

### 1.2 Fonctionnement détaillé de chaque type

#### 🎲 DOMINOS (Type le plus fréquent au BF)

**Principe** : Un domino a 2 faces, chacune avec une valeur de 0 (blanc) à 6. Les valeurs sont **circulaires** : après 6 vient 0 (modulo 7).

**7 patterns identifiés** (source : test-psychotechnique-en-ligne.fr) :
1. **Symétrie** : les dominos sont le miroir les uns des autres (axe horizontal/vertical)
2. **Progression linéaire** : chaque face augmente/diminue (+1, +2, -1, etc.) — la face haute et la face basse peuvent suivre des règles différentes ("croisée")
3. **Progression en Z** : lecture en dents de scie (zigzag) au lieu de gauche à droite
4. **Similarité** : pattern qui se répète (les 3 mêmes dominos en boucle dans un ordre différent)
5. **Opérations** : le 3ème domino = somme/différence des 2 premiers (par face)
6. **Superposition visuelle** : imaginer les points superposés par transparence
7. **Suites croisées** : face haute suit une règle, face basse une autre

**Algorithme de génération** :
```
1. Choisir un pattern (1-7)
2. Choisir les paramètres (opérateur, incrément, sens)
3. Générer N dominos selon la règle
4. Masquer le dernier (ou un au milieu)
5. Générer 3 distracteurs (qui suivent PARTIELLEMENT la règle)
6. Mélanger les 4 options
```

#### 🃏 CARTES À JOUER

**Principe** : Similaire aux dominos mais avec 2 paramètres : **valeur** (As=1 → 10, Valet=11, Dame=12, Roi=13) et **couleur** (♠♣♥♦). Dans les concours BF, souvent simplifié à As-10 sans figures.

**Patterns** : Mêmes que les dominos + logique sur les couleurs (alternance noir/rouge, suite ♠→♥→♦→♣)

**Algorithme** : Identique aux dominos avec valeurs 1-13 modulo 13 + paramètre couleur

#### 🔲 MATRICES DE RAVEN (le plus difficile)

**Principe** : Grille 3×3 avec 8 cases remplies de formes géométriques et 1 case vide. Trouver la forme manquante parmi 6-8 options.

**5 règles fondamentales** (source : blog-rh.com) :
1. **Addition/Soustraction** : les éléments s'ajoutent ou se retirent d'une case à l'autre
2. **Rotation** : les formes pivotent de 45°, 90°, 180° entre les cases
3. **Symétrie** : miroir horizontal, vertical ou diagonal
4. **Progression numérique** : le nombre d'éléments suit une suite (Fibonacci, carrés, premiers)
5. **Superposition XOR/AND/OR** : les formes se combinent selon des opérateurs logiques

**Méthode LCP** : analyser d'abord les Lignes, puis les Colonnes, puis les Patterns globaux.

**Génération** : Possible via SVG programmatique — chaque règle est un algorithme de transformation de formes géométriques.

#### 📊 SUITES NUMÉRIQUES

**Types de suites** :
- Arithmétique : +n constant (2, 5, 8, 11...)
- Géométrique : ×n constant (2, 6, 18, 54...)
- Carrés/Cubes : 1, 4, 9, 16, 25...
- Fibonacci : chaque terme = somme des 2 précédents
- Triangulaire : 1, 3, 6, 10, 15...
- Suites imbriquées : 2 suites alternées
- Opérateurs croissants : +1, +2, +3, +4...
- Primes : 2, 3, 5, 7, 11, 13...

---

## 2. CE QUI EST UTILISÉ AU BURKINA FASO

### 2.1 Concours paramilitaires (Douane, Police, Gendarmerie, GSP)

D'après le document Scribd "Test Psychotechnique pour Concours Douane" (scribd.com/document/902315692) et les témoignages sur prepaconcoursbf.com :

**Épreuve de 3 heures** composée de :

| Partie | Contenu | Durée | Poids |
|--------|---------|-------|-------|
| **Raisonnement logique** | Suites numériques, suites logiques, dominos | 45 min | 25% |
| **Attention / Concentration** | Barrage, repérage d'erreurs, comptage | 30 min | 20% |
| **Logique administrative** | Tableaux à double entrée, organigrammes, planification | 30 min | 15% |
| **Aptitude numérique** | Calcul mental, pourcentages, proportions | 30 min | 20% |
| **Compréhension verbale** | Analogies, synonymes, antonymes, intrus | 30 min | 15% |
| **Personnalité** (optionnel) | Questionnaire comportemental | 15 min | 5% |

### 2.2 Concours ENAREF cycle C

- Suites numériques (niveau BAC)
- Logique verbale (grammaire, orthographe)
- Calcul rapide

### 2.3 Concours catégorie C (Adjoints)

- Tests de base : suites simples, calcul, français
- Moins de tests abstraits que les paramilitaires

---

## 3. ARCHITECTURE DE LA MACHINE PSYCHOTECHNIQUE

### 3.1 Vue d'ensemble

```
┌────────────────────────────────────────────────────────────────────────┐
│                    MACHINE PSYCHOTECHNIQUE ACADEMIA                     │
│                                                                        │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │ GÉNÉRATEUR  │  │  MOTEUR DE   │  │ TUTEUR IA   │  │ ANALYTICS   │ │
│  │ DE TESTS    │  │  CORRECTION  │  │ EXPLICATIF  │  │ ADAPTATIF   │ │
│  │             │  │              │  │             │  │             │ │
│  │ • Dominos   │  │ • Vérif algo │  │ • Explique  │  │ • Force/    │ │
│  │ • Cartes    │  │ • Score auto │  │   la logique│  │   faiblesse │ │
│  │ • Suites    │  │ • Chrono     │  │ • Propose   │  │ • Niveau    │ │
│  │ • Matrices  │  │ • Historique │  │   des astuces│  │ • Progrès   │ │
│  │ • Analogies │  │              │  │ • Méthode   │  │ • Prédiction│ │
│  │ • Intrus    │  │              │  │   pas à pas │  │   de score  │ │
│  │ • Attention │  │              │  │             │  │             │ │
│  │ • Calcul    │  │              │  │             │  │             │ │
│  └──────┬──────┘  └──────┬───────┘  └──────┬──────┘  └──────┬──────┘ │
│         │                │                  │                │        │
│         └────────────────┴──────────────────┴────────────────┘        │
│                                   │                                    │
│                         ┌─────────▼─────────┐                         │
│                         │  MODES D'ENTRAÎN. │                         │
│                         │                   │                         │
│                         │ 1. Libre (choix)  │                         │
│                         │ 2. Exam blanc     │                         │
│                         │ 3. Adaptatif (IA) │                         │
│                         │ 4. Défi quotidien │                         │
│                         │ 5. Par type       │                         │
│                         │ 6. Chronométré    │                         │
│                         └───────────────────┘                         │
└────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Le Générateur — Comment chaque type est produit

#### A. Suites numériques (100% algorithmique)
```dart
// Algorithme de génération
1. Choisir un type : arithmétique | géométrique | carrés | fibonacci | imbriquée | opérateurs_croissants
2. Choisir les paramètres : valeur_initiale, opérateur, incrément
3. Générer la suite complète (8-10 termes)
4. Masquer 1-2 termes (le dernier, ou un au milieu)
5. Générer 3 distracteurs :
   - Un proche (±1 de la bonne réponse)
   - Un qui suit une règle SIMILAIRE mais pas identique
   - Un aléatoire dans la plage
6. Calculer la difficulté (1-5) selon le type + nb d'opérations
```

#### B. Dominos (100% algorithmique)
```dart
// Chaque domino = (face_haute: 0-6, face_basse: 0-6)
// Les valeurs sont modulo 7 (après 6 → 0)
1. Choisir un pattern : progression | symétrie | opération | Z | croisée
2. Choisir les paramètres : (incrément_haut, incrément_bas) ou (opérateur)
3. Générer 5-6 dominos
4. Masquer le dernier
5. Distracteurs : appliquer la règle avec une erreur sur UNE face
6. Rendu visuel : Widget Flutter avec 2 rectangles + points (Canvas/CustomPainter)
```

#### C. Cartes à jouer (100% algorithmique)
```dart
// Carte = (valeur: 1-13, couleur: ♠♣♥♦)
// Même logique que dominos + dimension couleur
1. Choisir les patterns valeur + couleur séparément
2. Générer la suite
3. Masquer une carte
4. Rendu visuel : Widget Flutter avec image de carte (SVG ou CustomPainter)
```

#### D. Matrices de Raven (algorithmique + IA)
```dart
// Matrice 3×3 de formes géométriques
1. Choisir 1-2 règles : rotation | addition | symétrie | progression | XOR
2. Définir les formes de base (cercle, carré, triangle, losange, étoile)
3. Appliquer les règles pour remplir 8 cases
4. La 9ème case = résultat logique des règles
5. Générer 5-7 distracteurs (appliquer la règle partiellement)
6. Rendu : SVG ou CustomPainter Flutter
7. OPTION IA : OpenRouter génère la description des formes, Flutter les rend
```

#### E. Analogies verbales (100% IA via OpenRouter)
```
Prompt : "Génère une analogie verbale pour concours BF niveau [difficulté].
Format : A est à B ce que C est à ?
Options : [bonne réponse, 3 distracteurs]
Explication : pourquoi cette relation"
```

#### F. Tests d'attention (100% algorithmique)
```dart
// Grille de symboles (lettres, chiffres, formes)
1. Générer une grille NxM de symboles aléatoires
2. Définir la cible (ex: "barrez tous les 'd'")
3. Compter les occurrences (réponse correcte)
4. Timer : 2 minutes
5. Score = nb correct / nb total
```

### 3.3 Le Tuteur IA — Explication pas à pas

Quand l'étudiant se trompe, l'IA explique :

```
❌ Mauvaise réponse !

La bonne réponse est [B].

📖 Explication :
Cette suite suit une progression géométrique de raison 3 :
• 2 × 3 = 6
• 6 × 3 = 18
• 18 × 3 = 54
• 54 × 3 = 162 ✅

💡 Astuce : Quand les nombres augmentent très vite,
pensez à la multiplication (suite géométrique).
Divisez chaque terme par le précédent pour trouver la raison.

🎯 Tu as du mal avec les suites géométriques.
Voici 3 exercices supplémentaires pour t'entraîner.
```

### 3.4 Analytics Adaptatif

```
L'étudiant Jean a fait 50 tests psychotechniques :

📊 Profil de compétences :
  Suites numériques     ████████░░  82%  ↑
  Dominos               █████░░░░░  52%  →
  Analogies verbales    ███████░░░  73%  ↑
  Attention             ████████░░  80%  ↑
  Calcul mental         ██████░░░░  65%  ↓
  Cartes à jouer        ████░░░░░░  40%  ↓  ⚠️ Point faible

🎯 Recommandation IA :
"Jean, tes dominos et cartes à jouer sont tes points faibles.
Les cartes suivent la MÊME logique que les dominos.
Je te recommande 10 exercices de dominos faciles → moyens
avant de revenir aux cartes."

📈 Prédiction de score au concours :
Si tu continues à ce rythme → ~65% au test psychotechnique
Pour atteindre 80% → 30 exercices/jour pendant 2 semaines
```

---

## 4. IMPLÉMENTATION TECHNIQUE

### 4.1 Côté Flutter — Nouveau sous-module dans l'onglet Concours

**Nouveau fichier** : `lib/features/student/prep/prep_psychotech_engine.dart`

Ce fichier contient :
- `PsychotechGenerator` : classe statique qui génère chaque type de test algorithmiquement
- `PsychotechRenderer` : widgets Flutter pour le rendu visuel (dominos, cartes, grilles)
- `PsychotechScorer` : correction automatique + calcul de score
- `PsychotechAdaptiveEngine` : choisit les prochains exercices selon le profil

**Nouveau écran** : `lib/features/student/prep/prep_psychotech_screen.dart`
- Mode sélection (choisir le type de test)
- Mode entraînement (série de N tests avec timer)
- Mode exam blanc (tous les types mélangés, 45 min chronométrées)
- Résultats + explications + profil de compétences

### 4.2 Côté Supabase — Tables analytics

```sql
-- Résultats par type de test
CREATE TABLE app.prep_psychotech_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES auth.users(id),
    test_type TEXT NOT NULL,        -- dominos, cartes, suites_num, etc.
    difficulty INTEGER NOT NULL,     -- 1-5
    is_correct BOOLEAN NOT NULL,
    time_spent_ms INTEGER,
    question_data JSONB,            -- la question générée
    student_answer JSONB,
    correct_answer JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Profil adaptatif par étudiant
CREATE TABLE app.prep_psychotech_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES auth.users(id) UNIQUE,
    scores_by_type JSONB DEFAULT '{}'::jsonb,  -- {"dominos": 52, "suites_num": 82, ...}
    total_tests INTEGER DEFAULT 0,
    avg_time_ms INTEGER,
    weak_areas TEXT[],
    strong_areas TEXT[],
    predicted_score INTEGER,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 4.3 Côté IA (OpenRouter) — Pour les types non-algorithmiques

| Besoin | Modèle | Coût |
|--------|--------|------|
| Analogies verbales | Claude Haiku | ~$0.001/question |
| Intrus verbaux | Claude Haiku | ~$0.001/question |
| Explication d'erreur | Claude Haiku | ~$0.002/explication |
| Recommandation adaptative | Claude Haiku | ~$0.001/recommandation |

**Coût estimé** : ~$0.005 par session d'entraînement (10 questions + explications)

### 4.4 Rendu visuel des dominos et cartes

```dart
// Widget Domino (CustomPainter Flutter)
class DominoPainter extends CustomPainter {
  final int topValue;   // 0-6
  final int bottomValue; // 0-6
  final bool isHidden;  // afficher "?" si masqué
  
  // Dessine un rectangle blanc avec bordure noire
  // Ligne de séparation au milieu
  // Points disposés selon la valeur (comme un vrai domino)
  // Si isHidden → affiche "?" en gros
}

// Widget Carte à jouer
class PlayingCardWidget extends StatelessWidget {
  final int value;    // 1-13
  final String suit;  // ♠, ♥, ♦, ♣
  final bool isHidden;
  
  // Affiche la valeur (A, 2-10, J, Q, K) et le symbole
  // Couleur rouge pour ♥♦, noire pour ♠♣
}
```

---

## 5. MODES D'ENTRAÎNEMENT

### 5.1 Mode Libre
L'étudiant choisit le type de test et la difficulté. Pas de timer. Correction après chaque question.

### 5.2 Mode Exam Blanc Paramilitaire (3h)
Reproduit l'épreuve réelle des concours BF :
- 15 suites numériques (30 min)
- 10 dominos (20 min)
- 10 cartes à jouer (15 min)
- 10 analogies verbales (15 min)
- 1 grille d'attention (10 min)
- 10 calculs rapides (15 min)
- Score global sur 100

### 5.3 Mode Adaptatif IA
L'IA analyse le profil et propose des exercices ciblés sur les points faibles. La difficulté s'ajuste automatiquement :
- Si l'étudiant réussit 3 de suite → augmenter la difficulté
- Si l'étudiant échoue 2 de suite → baisser la difficulté
- Toujours proposer 70% du temps sur les points faibles

### 5.4 Défi Quotidien
5 exercices par jour (1 de chaque type), avec classement entre candidats. Gagne des XP + maintient le streak.

### 5.5 Mode Chronométré
Comme l'exam blanc mais par type : "30 suites numériques en 15 minutes". Entraîne la vitesse.

---

## 6. AVANTAGE CONCURRENTIEL

| Critère | Apps existantes (Play Store) | **Academia Machine Psychotechnique** |
|---|---|---|
| Types de tests | 1-2 (dominos ou suites seulement) | **12 types complets** |
| Génération | Questions statiques (même pool) | **Génération illimitée algorithmique** |
| Contexte BF | Aucun (apps françaises/européennes) | **Adapté aux concours BF (douane, ENAREF, paramilitaire)** |
| Explication | Réponse correcte affichée | **Tuteur IA qui explique pas à pas + astuces** |
| Adaptatif | Non | **IA qui cible les points faibles** |
| Analytics | Non | **Profil de compétences + prédiction de score** |
| Exam blanc | Non | **Reproduction fidèle de l'épreuve 3h paramilitaire** |
| Visuel | Basique | **CustomPainter Flutter : dominos, cartes, grilles interactifs** |
| Gamification | Non | **XP, streak, défi quotidien, classement** |
| Prix | 3-10€ / app | **Intégré dans Academia (freemium)** |

---

## 7. PLAN D'IMPLÉMENTATION

| Phase | Contenu | Durée |
|---|---|---|
| **A** | Générateur algorithmique Flutter (suites numériques/alpha, dominos textuels) | 2j |
| **B** | Rendu visuel CustomPainter (dominos visuels, cartes à jouer) | 2j |
| **C** | Matrices de Raven simplifiées (formes SVG/Canvas) | 2j |
| **D** | Analogies + Intrus via OpenRouter | 1j |
| **E** | Tests d'attention + Calcul mental | 1j |
| **F** | Écran principal + modes (libre, exam blanc, adaptatif, chrono) | 2j |
| **G** | Supabase tables + analytics + profil adaptatif | 1j |
| **H** | Tuteur IA explicatif (correction détaillée + recommandations) | 1j |

**Total : ~12 jours**

---

## 8. RÉSUMÉ

La Machine Psychotechnique d'Academia sera **unique en Afrique** parce que :

1. **12 types de tests** couvrant TOUT ce qui existe dans les concours BF
2. **Génération illimitée** — jamais les mêmes questions, contrairement aux apps statiques
3. **Adapté au BF** — format exact des concours paramilitaires (3h, 6 parties)
4. **IA tuteur** qui explique chaque erreur et enseigne les astuces de résolution
5. **Adaptatif** — l'IA cible les faiblesses de chaque candidat
6. **Prédictif** — "Si tu continues à ce rythme, tu auras ~65% au concours"
7. **Visuel** — vrais dominos, vraies cartes, vraies grilles (pas du texte)
8. **Gamifié** — XP, streak, défi quotidien, classement national

Sur un marché où **2 millions de candidats** passent des tests psychotechniques chaque année au BF, et où **aucune app mobile native n'existe** pour s'y préparer sérieusement.
