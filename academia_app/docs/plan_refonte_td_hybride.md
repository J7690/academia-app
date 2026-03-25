# Plan de Refonte — Onglet TD : Cours d'appui Hybride IA + Humain + Regroupement
## Toutes filières universitaires — Système éducatif burkinabè
**Date** : 16 Mars 2026

---

## 1. CE QUE LES RECHERCHES RÉVÈLENT

### 1.1 Les modèles internationaux qui fonctionnent

| Plateforme | Pays | Modèle | Ce qu'on retient |
|---|---|---|---|
| **Khanmigo** (Khan Academy) | USA/Mondial | IA tuteur gratuit + enseignant humain supervise | L'IA ne donne JAMAIS la réponse directement, elle guide l'étudiant pas à pas (méthode socratique). L'enseignant voit le dashboard de progression |
| **Vedantu WAVE** | Inde | Live classes + IA tracking + quiz interactifs en classe | Classes live avec leaderboard en temps réel, doute-solving instantané, IA qui détecte l'engagement facial. **25M+ étudiants** |
| **Squirrel AI** | Chine | IA adaptative + **1 700 centres physiques** | L'IA décompose chaque matière en nano-compétences, détecte les lacunes, prescrit des exercices. L'enseignant humain intervient sur les points que l'IA ne résout pas. **24M étudiants, 10 milliards de comportements analysés** |
| **TAL Education / Xueersi** | Chine | IA MathGPT + tablettes en classe + enseignant présentiel | L'IA évalue la compréhension en temps réel. L'enseignant utilise un grand écran, l'étudiant répond sur tablette. **Bidirectionnel** |
| **Superprof** | France/Mondial | Marketplace tuteurs physiques/en ligne | Matching par matière + localisation + prix. Profils vérifiés. **Le modèle marketplace est scalable** |
| **StudyBuddy / Gingembre** | USA/France | Matching étudiants même matière + cours collaboratif | Algorithme de matching par cours, disponibilité, compatibilité. Groupes de 3-6 étudiants |
| **Groupe Réussite** | France | Stages intensifs + cours particuliers présentiels | Groupes par niveau + matière dans des locaux physiques. Suivi personnalisé |

### 1.2 Le point clé : le modèle **Squirrel AI** est le plus pertinent pour le BF

Squirrel AI a prouvé en Chine que la combinaison **IA adaptative + centres physiques** est la plus efficace :
- L'IA détecte les lacunes avec précision (nano-compétences)
- L'enseignant humain intervient UNIQUEMENT là où l'IA ne suffit pas
- Les étudiants viennent dans des centres physiques locaux
- **Résultat : les étudiants progressent 5-10× plus vite qu'en cours magistral**

→ C'est EXACTEMENT ce que vous décrivez : **IA qui fait le gros du travail + enseignant physique dans les quartiers de Ouagadougou**.

### 1.3 Ce qui manque dans TOUTES ces plateformes et qu'Academia peut faire

Aucune de ces plateformes n'offre les 3 combinaisons en même temps :
1. ✅ IA tuteur adaptatif (Khanmigo, Squirrel AI)
2. ✅ Cours live en ligne (Vedantu, TAL)
3. ❌ **Regroupement physique local par quartier** — PERSONNE ne fait ça en app mobile

**L'innovation Academia** : un algorithme qui regroupe les étudiants par matière + quartier + niveau, et leur affecte un enseignant physique qui se déplace.

---

## 2. CE QUI EXISTE DÉJÀ DANS ACADEMIA (ONGLET TD)

### 2.1 Architecture actuelle (audit réel)

**40 fichiers Flutter** dans le module TD, répartis sur 3 rôles :

**Étudiant** (8 écrans) :
| Écran | Fichier | Fonction |
|---|---|---|
| `StudentTdRootScreen` | `student_td_root_screen.dart` | Écran principal TD (7 onglets) |
| `TdHomeTab` | `td/td_home_tab.dart` | Accueil TD |
| `TdCatalogTab` | `td/td_catalog_tab.dart` | Catalogue des matières/sessions |
| `TdMyEnrollmentsTab` | `td/td_my_enrollments_tab.dart` | Mes inscriptions |
| `TdResourcesTab` | `td/td_resources_tab.dart` | Ressources pédagogiques |
| `TdStatsTab` | `td/td_stats_tab.dart` | Statistiques de progression |
| `TdLeaderboardTab` | `td/td_leaderboard_tab.dart` | Classement |

**Enseignant TD** (3 écrans dans `instructor/`) :
| Écran | Fichier | Fonction |
|---|---|---|
| `TeacherTdAssignmentsScreen` | `teacher_td_assignments_screen.dart` | Gestion des devoirs TD |
| `TeacherTdResourcesScreen` | `teacher_td_resources_screen.dart` | Progression des étudiants |
| `TeacherPrepScreen` | `teacher_prep_screen.dart` | Banques de questions (partagé prep) |

**Admin TD** (5 écrans) :
| Écran | Fonction |
|---|---|
| `AdminTdScreen` | Dashboard TD admin |
| `AdminTdAnalyticsScreen` | Analytics TD |
| `AdminTdCatalogScreen` | Catalogue TD admin |
| `AdminTdTeachersScreen` | Gestion enseignants TD |
| `AdminTdStudentRequestsScreen` | Demandes étudiants |

### 2.2 RPCs Supabase existantes (29 TD + 11 enseignant TD)

**29 RPCs `app_td_*`** : sessions, inscriptions, catalogues, gamification, messages, ressources, assignments
**11 RPCs `app_ci_*`** (enseignant) : cours en ligne, sessions live, forum

### 2.3 Ce qui MANQUE dans le TD actuel

| Manque | Impact |
|---|---|
| ❌ **IA tuteur intégré au TD** | L'IA concours (`prep-tutor-chat`) existe mais n'est PAS connectée au TD |
| ❌ **Correction IA des exercices TD** | L'enseignant TD doit tout corriger manuellement |
| ❌ **Regroupement par quartier/ville** | Impossible de former des groupes physiques locaux |
| ❌ **Matching matière × niveau × localisation** | Les étudiants ne peuvent pas trouver d'autres étudiants proches |
| ❌ **Système de demande de cours présentiel** | Pas de workflow pour demander un enseignant sur place |
| ❌ **Contenu pédagogique adapté aux universités BF** | Le contenu est générique, pas adapté aux programmes UJK, UNB, etc. |
| ❌ **Marketplace de services d'enseignement** | Pas de modèle de vente des services (IA vs humain) |

---

## 3. PROPOSITION — ARCHITECTURE HYBRIDE IA + HUMAIN + LOCAL

### 3.1 Les 3 piliers du nouveau TD

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    ONGLET TD — COURS D'APPUI HYBRIDE                    │
│                                                                         │
│  ┌─────────────────┐  ┌──────────────────┐  ┌──────────────────────┐   │
│  │  PILIER 1        │  │  PILIER 2         │  │  PILIER 3             │   │
│  │  IA TUTEUR       │  │  ENSEIGNANT       │  │  REGROUPEMENT         │   │
│  │  (24h/24)        │  │  HUMAIN           │  │  LOCAL                │   │
│  │                  │  │                   │  │                      │   │
│  │ • Correction IA  │  │ • Cours live      │  │ • Matching par        │   │
│  │   des exercices  │  │ • Correction      │  │   matière + quartier  │   │
│  │ • Explication    │  │   manuelle +      │  │ • Groupes de 3-8      │   │
│  │   pas à pas      │  │   commentaires    │  │   étudiants           │   │
│  │ • Quiz adaptatif │  │ • Sessions TD     │  │ • Enseignant affecté  │   │
│  │ • Méthodologie   │  │   présentielles   │  │   sur place           │   │
│  │   de résolution  │  │ • Suivi perso     │  │ • Salle ou domicile   │   │
│  │ • Basé sur les   │  │ • Disponible      │  │ • Géolocalisation     │   │
│  │   programmes BF  │  │   sur réservation │  │ • Planning auto       │   │
│  └────────┬─────────┘  └────────┬──────────┘  └──────────┬───────────┘   │
│           │                     │                         │              │
│           └─────────────────────┼─────────────────────────┘              │
│                                 │                                        │
│                    ┌────────────▼─────────────┐                          │
│                    │  MODÈLE ÉCONOMIQUE        │                          │
│                    │                          │                          │
│                    │  Gratuit : Quiz IA basique│                          │
│                    │  Premium : Correction IA  │                          │
│                    │  Premium+ : Enseignant    │                          │
│                    │  Groupe : Cours présentiel│                          │
│                    └──────────────────────────┘                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Pilier 1 — IA Tuteur TD (nouveau)

**Fonctionnement (inspiré de Khanmigo + Squirrel AI) :**

1. L'étudiant choisit sa matière (ex: "Analyse Mathématique L2") et son université (UJK, UNB, etc.)
2. L'IA a été nourrie avec les programmes, les méthodologies et des sujets types
3. L'étudiant soumet un exercice (texte, photo, PDF)
4. L'IA :
   - Identifie le type d'exercice
   - NE DONNE PAS la réponse directement (méthode socratique Khanmigo)
   - Guide étape par étape : "Quelle formule utiliserais-tu ici ?"
   - Si l'étudiant bloque → donne un indice progressif
   - À la fin → correction détaillée + méthodologie + exercices similaires
5. Tout est enregistré pour le suivi de progression

**Edge Function** : Réutilise `prep-tutor-chat` (déjà déployée) avec un prompt système adapté au TD universitaire

### 3.3 Pilier 2 — Enseignant Humain (enrichissement de l'existant)

**Ce qui existe** : sessions TD, inscriptions, ressources, devoirs, messages
**Ce qu'on ajoute** :
- L'enseignant voit les résultats de l'IA pour chaque étudiant
- Il intervient quand l'IA ne suffit pas (questions complexes, dissertations, cas pratiques)
- Il peut corriger en utilisant l'IA comme assistant (comme `prep-grade-assignment`)
- Il peut planifier des sessions de révision physiques ou live

### 3.4 Pilier 3 — Regroupement Local (INNOVATION MAJEURE)

**Flux complet :**

```
1. L'étudiant remplit son profil TD :
   - Université (UJK, UNB, UPB, privées...)
   - Filière et année (Droit L2, Maths L1, Médecine P2...)
   - Matières à renforcer (Analyse, Algèbre, Droit civil...)
   - Quartier de résidence à Ouagadougou (Dassasgho, Patte-d'oie,
     Pissy, 1200 lgts, Tampouy, Karpala, Zogona...)
     OU ville (Bobo-Dioulasso, Koudougou, Ouahigouya...)
   - Disponibilités (soirs, week-ends, matins...)

2. L'ALGORITHME DE MATCHING regroupe :
   - Même matière + même niveau (ou compatible)
   - Même quartier/ville (rayon de 3-5 km)
   - Disponibilités compatibles
   - Groupes de 3 à 8 étudiants (taille optimale)

3. NOTIFICATION : "Un groupe de 5 étudiants en Analyse L2 s'est
   formé dans votre quartier (Dassasgho). Session prévue samedi
   14h-17h. Enseignant : M. OUÉDRAOGO Abdoulaye."

4. L'ADMIN ou l'algorithme affecte un enseignant :
   - Enseignant inscrit sur la plateforme
   - Spécialité compatible
   - Disponible dans la zone géographique
   - Tarif défini (partagé entre les membres du groupe)

5. La session se déroule :
   - Physique : chez un membre, dans un espace loué, ou à l'université
   - L'enseignant utilise l'app pour suivre la session
   - Les exercices IA sont intégrés comme support
   - À la fin : évaluation mutuelle (étudiants notent l'enseignant)
```

---

## 4. NOUVEAUX ONGLETS PROPOSÉS

### 4.1 Onglet TD étudiant : de 7 à 10 sous-onglets

| # | Onglet | Existant | Nouveau | Contenu |
|---|--------|----------|---------|---------|
| 1 | **Accueil** | ✅ | Enrichi | + Section "IA Tuteur rapide" + "Groupes à proximité" |
| 2 | **Catalogue** | ✅ | Enrichi | + Filtre par université BF + filière + année |
| 3 | **Mes TD** | ✅ | — | Inscriptions existantes |
| 4 | **🤖 IA Tuteur** | ❌ | **NOUVEAU** | Chat IA adapté au programme universitaire BF, correction d'exercices, méthodologie pas à pas |
| 5 | **📝 Exercices** | ❌ | **NOUVEAU** | Exercices envoyés par l'enseignant + correction IA assistée |
| 6 | **📍 Groupes Locaux** | ❌ | **NOUVEAU** | Matching par matière/quartier, formation de groupes, sessions physiques planifiées, enseignant affecté |
| 7 | **Ressources** | ✅ | Enrichi | + Ressources par programme universitaire BF |
| 8 | **Stats** | ✅ | Enrichi | + Progression IA + Score prédictif |
| 9 | **Classement** | ✅ | — | Leaderboard existant |
| 10 | **💬 Messages** | ✅ | Enrichi | + Messages de groupe local + enseignant |

### 4.2 Onglet TD enseignant : de 3 à 5 sous-onglets

| # | Onglet | Existant | Nouveau | Contenu |
|---|--------|----------|---------|---------|
| 1 | **Mes TD** | ✅ | — | Devoirs existants |
| 2 | **Progression** | ✅ | Enrichi | + Dashboard IA par étudiant |
| 3 | **📍 Mes Groupes Locaux** | ❌ | **NOUVEAU** | Groupes physiques affectés, calendrier sessions, évaluation étudiants |
| 4 | **🤖 Correction IA** | ❌ | **NOUVEAU** | Correction assistée IA des devoirs/exercices |
| 5 | **💰 Mes revenus** | ❌ | **NOUVEAU** | Suivi des paiements pour les cours physiques |

### 4.3 Admin TD : enrichissements

| Fonction | Contenu |
|---|---|
| **Matching Dashboard** | Voir les groupes formés, les enseignants affectés, les sessions planifiées |
| **Géo-analytics** | Carte des groupes par quartier/ville, demandes non satisfaites |
| **Contenu universitaire** | Upload des programmes par université BF, vérification du contenu IA |
| **Pricing** | Configurer les tarifs (IA seul, IA+humain, cours physique groupe) |

---

## 5. TABLES SUPABASE À CRÉER

### 5.1 Profil TD étudiant (localisation + préférences)
```sql
td_student_profiles : student_id, university, faculty, year, 
  subjects_needed[], city, neighborhood, lat, lng, 
  availability_days[], availability_times[], max_group_size
```

### 5.2 Groupes locaux
```sql
td_local_groups : id, subject, level, city, neighborhood,
  lat, lng, max_members, current_members, status (forming/confirmed/active/completed),
  assigned_teacher_id, session_date, session_time, location_type (home/rented/university),
  location_address, price_per_student
```

### 5.3 Membres des groupes
```sql
td_local_group_members : group_id, student_id, joined_at, status
```

### 5.4 Sessions physiques
```sql
td_physical_sessions : group_id, teacher_id, date, start_time, end_time,
  location, status, notes, attendance JSONB, teacher_rating, student_ratings
```

### 5.5 Profil enseignant TD enrichi
```sql
td_teacher_profiles : teacher_id, specialties[], universities[],
  city, neighborhoods[], max_distance_km, hourly_rate, 
  availability_days[], availability_times[], rating, total_sessions
```

---

## 6. MODÈLE ÉCONOMIQUE

| Service | Prix indicatif | Qui paie | Qui reçoit |
|---|---|---|---|
| **Quiz IA basique** | Gratuit | — | — |
| **Correction IA détaillée** | 200-500 FCFA/exercice | Étudiant | Academia |
| **Chat IA illimité (mensuel)** | 2 000-5 000 FCFA/mois | Étudiant | Academia |
| **Cours physique groupe** (3-8 étudiants) | 1 500-3 000 FCFA/étudiant/séance | Étudiants du groupe | Enseignant (70%) + Academia (30%) |
| **Cours particulier présentiel** | 5 000-10 000 FCFA/h | Étudiant | Enseignant (80%) + Academia (20%) |
| **Session live en ligne** | 1 000-2 000 FCFA/séance | Étudiant | Enseignant (75%) + Academia (25%) |

---

## 7. PLAN D'IMPLÉMENTATION PROPOSÉ

| Phase | Contenu | Durée estimée |
|---|---|---|
| **1** | Supabase : nouvelles tables (profils TD, groupes locaux, sessions physiques, profils enseignants enrichis) + RPCs + RLS | 2j |
| **2** | Flutter étudiant : onglet "IA Tuteur TD" (réutilise prep-tutor-chat avec prompt universitaire BF) | 2j |
| **3** | Flutter étudiant : onglet "Groupes Locaux" (profil localisation, matching, carte des groupes, inscription) | 3j |
| **4** | Flutter étudiant : onglet "Exercices TD" (soumission + correction IA assistée, comme prep_assignments adapté au TD) | 2j |
| **5** | Flutter enseignant : "Mes Groupes Locaux" + "Correction IA" + calendrier sessions physiques | 2j |
| **6** | Admin : Matching dashboard + Géo-analytics + Configuration pricing | 2j |
| **7** | Algorithme de matching : regroupement automatique par matière × quartier × disponibilité | 2j |
| **8** | Notifications + workflow complet : formation groupe → affectation enseignant → session → évaluation | 1j |

**Total estimé : ~16 jours**

---

## 8. POURQUOI C'EST UNIQUE

| Critère | Khanmigo | Vedantu | Squirrel AI | Superprof | **Academia** |
|---|---|---|---|---|---|
| IA tuteur | ✅ | ❌ | ✅ | ❌ | ✅ |
| Cours live | ❌ | ✅ | ❌ | ❌ | ✅ |
| Enseignant physique | ❌ | ❌ | ✅ (centres) | ✅ (individuel) | ✅ |
| **Regroupement local par quartier** | ❌ | ❌ | ❌ | ❌ | **✅ UNIQUE** |
| Adapté au système BF | ❌ | ❌ (Inde) | ❌ (Chine) | ❌ (France) | **✅** |
| App mobile native | ❌ (web) | ✅ | ✅ | ❌ (web) | **✅** |
| Correction IA exercices | ✅ | ❌ | ✅ | ❌ | **✅** |
| Gamification | ❌ | ✅ | ❌ | ❌ | **✅** |
| Tarification groupe | ❌ | ❌ | ✅ (centres) | ❌ | **✅** |

**L'innovation d'Academia** : la combinaison **IA tuteur 24/7 + enseignant humain + regroupement automatique par quartier** dans une seule app mobile. Aucune plateforme au monde ne fait exactement ça, et encore moins adaptée au contexte burkinabè.
