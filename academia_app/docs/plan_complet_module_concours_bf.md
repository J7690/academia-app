# Plan Complet — Module Préparation Concours Burkina Faso
## Architecture Hybride : IA + Enseignants + Live + Prédiction
**Date** : 15 Mars 2026

---

## 1. VISION GLOBALE

### Le triangle d'apprentissage

```
                    ┌──────────────┐
                    │  ÉTUDIANT    │
                    │  (candidat)  │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
     ┌────────▼─────┐  ┌──▼──────┐  ┌──▼────────────┐
     │ IA TUTEUR    │  │ LIVE    │  │ ENSEIGNANT    │
     │ (24h/24)     │  │ (temps  │  │ (asynchrone)  │
     │              │  │  réel)  │  │               │
     │ • Quiz auto  │  │ • Cours │  │ • Exercices   │
     │ • Correction │  │ • Q&A   │  │ • Corrections │
     │ • Prédiction │  │ • Exam  │  │ • Feedback    │
     │ • RAG sujets │  │   blanc │  │ • Suivi perso │
     └──────────────┘  └─────────┘  └───────────────┘
              │            │            │
              └────────────┼────────────┘
                           │
                    ┌──────▼───────┐
                    │  BASE DE     │
                    │  SUJETS      │
                    │  RÉELS       │
                    │  (PDF → IA)  │
                    └──────────────┘
```

### Les 3 modes d'apprentissage

| Mode | Quand | Comment | Qui |
|------|-------|---------|-----|
| **IA Autonome** | 24h/24, sans connexion humaine | Quiz adaptatifs, corrections IA, chat tuteur, prédictions | IA (OpenRouter) |
| **Enseignant Asynchrone** | L'étudiant traite à son rythme | L'enseignant envoie un exercice → l'étudiant répond → l'enseignant corrige → l'IA enrichit la correction | Enseignant + IA |
| **Live (temps réel)** | Sessions planifiées | Cours en direct, exam blanc supervisé, Q&A, révision intensive | Enseignant via LiveKit/Zoom/Meet |

---

## 2. CE QUI EXISTE DÉJÀ DANS L'APP

### Audit complet des capacités existantes

| Composant | Statut | Détails |
|-----------|--------|---------|
| **LiveKit (vidéo live)** | ✅ Code complet | `LivekitRoomScreen`, `LivekitTokenService`, mic/caméra/chat/main levée. Actuellement désactivé (`_connect` retourne erreur statique) |
| **Sessions live (providers)** | ✅ 4 providers | `StudentLiveSessionsProvider`, `InstructorOnlineCourseLiveSessionsProvider`, `AdminLiveSessionsProvider`, `OnlineCourseLiveSessionsProvider` |
| **Écran enseignant live** | ✅ Complet | Planifier session (titre, description, provider Zoom/Meet/LiveKit, date, replay URL), soumettre, démarrer |
| **Écran admin live** | ✅ Complet | Filtrer par statut, approuver/rejeter, voir participants |
| **Écran étudiant live** | ✅ Complet | Voir mes sessions, rejoindre (LiveKit natif ou lien externe) |
| **Module TD (Travaux Dirigés)** | ✅ 20+ écrans | Catalogue, inscriptions, sessions, enseignant assigné, paiement |
| **Communautés/Chat** | ✅ Complet | Chat groupe, DM, réactions, mentions, médias, stories |
| **IA Tuteur (prep-tutor-chat)** | ✅ Edge Function déployée | Chat avec OpenRouter, historique Supabase, prompt contextuel |
| **IA Génération QCM** | ✅ Backend Python | `/ai/prep/generate` avec RAG chunks, rate limiting, déduplication |
| **Tables prep_* unifiées** | ✅ 24 tables | Questions, flashcards, badges, progress, AI conversations, etc. |
| **Système de notification push** | ✅ Déployé | FCM, 55 triggers, Edge Function temps réel |
| **Backend Python (FastAPI)** | ✅ Prêt | Endpoints IA, LiveKit token, vidéo processing |

### Ce qui manque (le gap)

| Manque | Impact |
|--------|--------|
| **Pipeline d'ingestion PDF** | Les sujets réels ne peuvent pas être indexés |
| **pgvector (embeddings)** | Pas de recherche sémantique = IA générique |
| **Analyse de tendances / prédiction** | Impossible de détecter les sujets récurrents |
| **Exercices asynchrones enseignant→étudiant** | L'enseignant ne peut pas envoyer d'exercices dans le module concours |
| **Sessions live spécifiques concours** | Le live est lié aux "cours en ligne", pas aux concours |
| **Correction collaborative IA+enseignant** | L'IA et l'enseignant ne collaborent pas |
| **Adaptation Burkina Faso** | Tout est encore configuré pour le Cameroun |

---

## 3. ARCHITECTURE TECHNIQUE DÉTAILLÉE

### 3.1 Pipeline d'ingestion et analyse des sujets réels

```
┌─────────────────────────────────────────────────────────────────────────┐
│  INGESTION (Admin/Enseignant upload PDF)                                │
│                                                                         │
│  PDF sujet réel ──→ Supabase Storage (prep-documents)                  │
│       │                                                                 │
│       ▼                                                                 │
│  Edge Function: prep-ingest-document                                    │
│   ├─ 1. Extraction texte (OpenRouter pdf-text = GRATUIT)               │
│   ├─ 2. Détection structure (questions numérotées, options A/B/C/D)    │
│   ├─ 3. Chunking intelligent (1 chunk = 1 question + réponses)         │
│   ├─ 4. Classification auto : concours_type, matière, année, difficulté│
│   ├─ 5. Tagging thématique (ex: "séparation des pouvoirs", "PIB BF")  │
│   ├─ 6. Embeddings (text-embedding-3-small via OpenRouter)             │
│   └─ 7. Stockage pgvector + métadonnées enrichies                      │
│                                                                         │
│  Résultat: chaque question du PDF est un chunk indexé avec :           │
│  - embedding vectoriel (pour recherche sémantique)                      │
│  - tags thématiques (pour analyse de récurrence)                        │
│  - concours + année + matière (pour filtrage)                           │
│  - question_text + options + correction (si disponible)                 │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Moteur de prédiction et analyse de tendances

**Inspiré de PaperPredict** (72/90 questions prédites correctement pour NEET 2025)

```
┌─────────────────────────────────────────────────────────────────────────┐
│  ANALYSE DE TENDANCES (automatique, après chaque ingestion)             │
│                                                                         │
│  Edge Function / RPC: prep-analyze-trends                               │
│                                                                         │
│  1. FRÉQUENCE THÉMATIQUE                                                │
│     Pour chaque tag thématique, compter :                               │
│     - Nombre d'apparitions dans les N dernières années                  │
│     - Fréquence par concours (ENAREF revient-il à la constitution?)    │
│     - Cycle de retour (sujet X revient tous les 2-3 ans?)              │
│     → Score de probabilité : "Constitution BF" = 85% ENAREF 2026      │
│                                                                         │
│  2. PATTERN DE QUESTIONS                                                │
│     - Types de questions récurrents (QCM vs ouvert)                     │
│     - Formulations similaires (clustering par embedding)                │
│     - Concepts "favoris des examinateurs"                               │
│     → Identifier les 20% de sujets qui couvrent 80% des questions      │
│                                                                         │
│  3. SCORING DE PROBABILITÉ                                              │
│     Chaque thème reçoit un score 0-100% :                               │
│     - Fréquence historique (40%)                                        │
│     - Cycle de retour (20%)                                             │
│     - Actualité du sujet (20%)                                          │
│     - Importance dans le programme officiel (20%)                       │
│     → "Sujets prédits" triés par probabilité                           │
│                                                                         │
│  4. OUTPUT                                                               │
│     Table: prep_topic_predictions                                       │
│     - topic_name, concours_type, probability_score, last_appeared,      │
│       frequency_count, cycle_years, reasoning                           │
│     → Affiché à l'étudiant : "🔮 Sujets probables pour ENAREF 2026"   │
│     → JAMAIS présenté comme certitude, toujours "basé sur l'analyse    │
│       des tendances des 5 dernières années"                             │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Mode Enseignant Asynchrone — Exercices & Corrections

```
┌─────────────────────────────────────────────────────────────────────────┐
│  FLUX EXERCICE ASYNCHRONE                                               │
│                                                                         │
│  ENSEIGNANT                              ÉTUDIANT                       │
│  ──────────                              ────────                       │
│  1. Crée un exercice :                                                  │
│     - Type : QCM / Dissertation / Cas pratique                          │
│     - Concours cible : ENAREF B                                         │
│     - Matière : Droit administratif                                     │
│     - Consigne + document PDF joint                                     │
│     - Deadline                                                          │
│     - Publié vers un groupe d'étudiants                                 │
│              │                                                          │
│              ▼                                                          │
│  2. Notification push → étudiant                  3. L'étudiant :      │
│                                                      - Lit l'exercice  │
│                                                      - Rédige sa       │
│                                                        réponse         │
│                                                      - Peut demander   │
│                                                        un indice à     │
│                                                        l'IA            │
│                                                      - Soumet          │
│              │                                          │               │
│              ▼                                          ▼               │
│  4. L'enseignant reçoit la soumission                                   │
│     - Lit la réponse de l'étudiant                                      │
│     - Corrige manuellement (note + commentaire)                         │
│     - OU clique "Correction assistée IA" :                              │
│       → L'IA analyse la réponse vs la correction type                   │
│       → Propose une correction détaillée                                │
│       → L'enseignant valide/modifie/enrichit                            │
│              │                                                          │
│              ▼                                                          │
│  5. L'étudiant reçoit la correction :                                   │
│     - Note + commentaire enseignant                                     │
│     - Correction IA enrichie                                            │
│     - Référence aux sujets réels similaires                             │
│     - Suggestion de révision ciblée                                     │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.4 Mode Live — Sessions temps réel pour concours

```
┌─────────────────────────────────────────────────────────────────────────┐
│  SESSIONS LIVE CONCOURS (réutilise LiveKit existant)                    │
│                                                                         │
│  Types de sessions :                                                    │
│                                                                         │
│  A. COURS DE RÉVISION LIVE                                              │
│     - Enseignant présente un cours (droit admin, économie...)           │
│     - Étudiants suivent en vidéo + chat                                 │
│     - Main levée pour poser des questions                               │
│     - L'IA transcrit en temps réel (optionnel, futur)                  │
│     - Replay disponible après                                           │
│                                                                         │
│  B. EXAMEN BLANC SUPERVISÉ                                              │
│     - L'enseignant lance un quiz de 40 QCM en temps réel               │
│     - Timer synchronisé pour tous les étudiants                         │
│     - Les étudiants répondent dans l'app                                │
│     - Résultats instantanés + classement                                │
│     - Correction en direct par l'enseignant                             │
│                                                                         │
│  C. SESSION Q&A (Questions/Réponses)                                    │
│     - L'étudiant pose ses questions                                     │
│     - L'enseignant répond en direct                                     │
│     - L'IA enrichit les réponses (contexte des sujets réels)           │
│     - Les Q&A sont sauvegardées pour les absents                        │
│                                                                         │
│  Infrastructure existante :                                              │
│  ✅ LiveKit natif (vidéo/audio)                                         │
│  ✅ Zoom/Meet (lien externe)                                            │
│  ✅ Providers étudiant/enseignant/admin                                 │
│  ✅ Workflow : créer → soumettre → admin approuve → démarrer            │
│  ❌ À ajouter : lier les sessions au module concours (pas cours en     │
│     ligne), quiz live synchronisé, replay indexé                        │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 4. NOUVELLES TABLES SUPABASE

### 4.1 Prédictions / Analyse de tendances

```sql
-- Thèmes extraits des sujets (tags)
CREATE TABLE app.prep_topics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category TEXT,           -- ex: "droit", "economie", "culture_gen"
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Lien question ↔ thèmes (many-to-many)
CREATE TABLE app.prep_question_topics (
    question_id UUID NOT NULL REFERENCES app.prep_questions(id),
    topic_id UUID NOT NULL REFERENCES app.prep_topics(id),
    PRIMARY KEY (question_id, topic_id)
);

-- Prédictions par concours
CREATE TABLE app.prep_topic_predictions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic_id UUID NOT NULL REFERENCES app.prep_topics(id),
    concours_type TEXT NOT NULL,
    target_year TEXT NOT NULL,       -- ex: "2026"
    probability_score INTEGER,      -- 0-100
    frequency_count INTEGER,        -- combien de fois en N ans
    last_appeared_year TEXT,
    cycle_years NUMERIC(3,1),       -- ex: 2.5 = revient tous les 2.5 ans
    reasoning TEXT,                  -- explication IA
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (topic_id, concours_type, target_year)
);
```

### 4.2 Exercices enseignant → étudiant (asynchrone)

```sql
-- Exercices créés par l'enseignant
CREATE TABLE app.prep_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id UUID NOT NULL REFERENCES auth.users(id),
    title TEXT NOT NULL,
    description TEXT,
    concours_type TEXT,
    subject_name TEXT,
    assignment_type TEXT NOT NULL DEFAULT 'qcm',  -- qcm, dissertation, cas_pratique
    content JSONB,            -- questions QCM ou consigne dissertation
    attachments JSONB,        -- [{bucket, path, filename}]
    deadline TIMESTAMPTZ,
    max_score INTEGER DEFAULT 20,
    is_published BOOLEAN NOT NULL DEFAULT false,
    target_group TEXT,        -- 'all' ou ID d'un groupe
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Soumissions des étudiants
CREATE TABLE app.prep_assignment_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assignment_id UUID NOT NULL REFERENCES app.prep_assignments(id),
    student_id UUID NOT NULL REFERENCES auth.users(id),
    answer_content JSONB,     -- réponses QCM ou texte dissertation
    attachments JSONB,
    submitted_at TIMESTAMPTZ DEFAULT now(),
    status TEXT NOT NULL DEFAULT 'submitted',  -- submitted, graded, returned
    -- Correction enseignant
    teacher_score INTEGER,
    teacher_comment TEXT,
    teacher_graded_at TIMESTAMPTZ,
    -- Correction IA (assistant)
    ai_score INTEGER,
    ai_correction TEXT,
    ai_explanation TEXT,
    ai_source_chunks UUID[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (assignment_id, student_id)
);
```

### 4.3 Sessions live concours (extension du système existant)

```sql
-- Sessions live liées au module concours (pas aux cours en ligne)
CREATE TABLE app.prep_live_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id UUID NOT NULL REFERENCES auth.users(id),
    title TEXT NOT NULL,
    description TEXT,
    session_type TEXT NOT NULL DEFAULT 'revision', -- revision, exam_blanc, qa
    concours_type TEXT,
    subject_name TEXT,
    provider TEXT DEFAULT 'livekit',  -- livekit, zoom, meet
    join_url TEXT,
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ,
    replay_url TEXT,
    max_participants INTEGER DEFAULT 100,
    status TEXT NOT NULL DEFAULT 'draft', -- draft, approved, running, ended
    quiz_template_id UUID REFERENCES app.prep_quiz_templates(id), -- pour exam blanc
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Participants aux sessions live concours
CREATE TABLE app.prep_live_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES app.prep_live_sessions(id),
    student_id UUID NOT NULL REFERENCES auth.users(id),
    joined_at TIMESTAMPTZ DEFAULT now(),
    left_at TIMESTAMPTZ,
    quiz_score INTEGER,      -- si exam blanc
    UNIQUE (session_id, student_id)
);
```

---

## 5. NOUVELLES EDGE FUNCTIONS

| Edge Function | Rôle | Utilise OpenRouter |
|---|---|---|
| **`prep-ingest-document`** | PDF → texte → chunks → tags → embeddings → pgvector | Oui (pdf-text gratuit + embeddings) |
| **`prep-generate-questions`** | RAG sémantique → QCM réalistes avec corrections | Oui (LLM génération) |
| **`prep-analyze-trends`** | Analyse fréquence thèmes → scores de probabilité → prédictions | Oui (LLM analyse) |
| **`prep-tutor-chat` v2** | Chat RAG sémantique + correction contextuelle | Oui (LLM chat) |
| **`prep-grade-assignment`** | Correction IA d'une soumission d'exercice | Oui (LLM correction) |

---

## 6. MODIFICATIONS FLUTTER

### 6.1 Onglet Concours étudiant — Nouveaux sous-onglets

L'écran principal `StudentPrepConcoursScreen` passe de 5 à 7 onglets :

| Onglet | Existant | Nouveau | Contenu |
|--------|----------|---------|---------|
| **Accueil** | ✅ | Enrichi | + Section "🔮 Sujets probables" avec prédictions |
| **Quiz** | ✅ | Enrichi | + Badge "sujet réel" sur questions issues de vrais concours |
| **Sujets** | ✅ | Enrichi | + Filtres BF, téléchargement PDF originaux |
| **IA Tutor** | ✅ | Enrichi | + RAG sémantique, citations de sources |
| **Stats** | ✅ | Enrichi | + Analyse forces/faiblesses vs prédictions |
| **📝 Exercices** | ❌ | **NOUVEAU** | Exercices de l'enseignant, soumissions, corrections |
| **🎥 Lives** | ❌ | **NOUVEAU** | Sessions live concours, exams blancs, replays |

### 6.2 Interface enseignant — Nouveaux écrans

| Écran | Contenu |
|-------|---------|
| **Mes exercices** | Créer, modifier, publier des exercices (QCM, dissertation, cas pratique) |
| **Soumissions** | Voir les réponses des étudiants, corriger, utiliser l'IA pour assister |
| **Sessions live concours** | Planifier des cours/exam blancs/Q&A spécifiques concours |
| **Analyse & prédictions** | Voir les tendances, générer des exercices ciblés sur les sujets probables |

### 6.3 Interface admin — Enrichissements

| Écran | Contenu |
|-------|---------|
| **Upload sujets** | Upload PDF + métadonnées (concours BF, matière, année) |
| **Indexation** | Suivi du pipeline : upload → extraction → indexation → prêt |
| **Prédictions** | Dashboard des thèmes récurrents, scores de probabilité |
| **Exercices enseignants** | Modération des exercices publiés |
| **Sessions live** | Approbation des sessions (déjà existant, à étendre) |

---

## 7. ALGORITHME DE PRÉDICTION — DÉTAIL TECHNIQUE

### 7.1 Méthode (inspirée de PaperPredict)

```
Pour chaque thème T et chaque concours C :

1. FRÉQUENCE (score F, 0-40 points)
   - Compter combien de fois T apparaît dans les sujets de C (N dernières années)
   - F = (nombre_apparitions / nombre_total_sujets) × 40

2. CYCLE (score Y, 0-20 points)
   - Calculer l'intervalle moyen entre apparitions de T
   - Si T est "dû" (dernière apparition + cycle ≈ année cible) → Y = 20
   - Sinon → Y proportionnel à la proximité

3. ACTUALITÉ (score A, 0-20 points)
   - L'IA évalue si T est lié à l'actualité récente du Burkina Faso
   - Exemples : nouvelle constitution, réforme fiscale, événements politiques
   - A = LLM scoring (0-20)

4. IMPORTANCE PROGRAMME (score P, 0-20 points)
   - Basé sur le programme officiel du concours
   - Fondamentaux (constitution, principes de droit) → P élevé
   - Sujets périphériques → P faible

SCORE FINAL = F + Y + A + P (0-100)

Présentation à l'étudiant :
  🔴 90-100% : "Très probable — À maîtriser absolument"
  🟠 70-89%  : "Probable — Révision recommandée"
  🟡 50-69%  : "Possible — À connaître"
  ⚪ < 50%   : "Peu probable cette année"
```

### 7.2 Disclaimer obligatoire

> "Ces prédictions sont basées sur l'analyse statistique des sujets des années précédentes.
> Elles ne garantissent pas le contenu de l'examen à venir. Utilisez-les comme guide de
> priorisation dans vos révisions, pas comme une certitude."

---

## 8. PLAN D'IMPLÉMENTATION — 12 PHASES

| Phase | Contenu | Durée | Prérequis |
|-------|---------|-------|-----------|
| **1** | Adaptation BF : seed data (14 concours + 19 matières), remplacement Cameroun→BF dans Flutter + Edge Functions | 2j | — |
| **2** | pgvector + enrichissement schéma : embeddings, métadonnées, tables topics/predictions | 1j | — |
| **3** | Edge Function `prep-ingest-document` : PDF → chunks → tags → embeddings | 2j | Phase 2 |
| **4** | Edge Function `prep-generate-questions` : RAG → QCM réalistes | 2j | Phase 3 |
| **5** | Edge Function `prep-analyze-trends` : analyse récurrence → prédictions | 2j | Phase 3 |
| **6** | Tuteur IA v2 : RAG sémantique + correction contextuelle | 1j | Phase 3 |
| **7** | Tables + RPCs exercices asynchrones (prep_assignments, prep_assignment_submissions) | 1j | — |
| **8** | Tables + RPCs sessions live concours (prep_live_sessions, prep_live_participants) | 1j | — |
| **9** | Flutter enseignant : écrans exercices + corrections + IA assistée | 2j | Phase 7 |
| **10** | Flutter enseignant : sessions live concours + exam blanc | 1j | Phase 8 |
| **11** | Flutter étudiant : onglets Exercices + Lives + prédictions + badges sujet réel | 2j | Phases 5,7,8 |
| **12** | Flutter admin : upload PDF + dashboard prédictions + modération | 1j | Phase 3,5 |

**Total : ~18 jours de développement**

### Ordre de priorité recommandé

1. **Phases 1-4** (7j) → L'app fonctionne avec les vrais sujets BF et l'IA génère des QCM réels
2. **Phase 5-6** (3j) → Prédictions + tuteur IA contextuel = différenciateur majeur
3. **Phases 7-9** (4j) → L'enseignant peut intervenir (exercices asynchrones)
4. **Phases 10-12** (4j) → Live concours + admin complet

**Livrable après 10 jours (Phases 1-6)** : L'étudiant peut déjà :
- S'entraîner avec des QCM issus de vrais sujets BF
- Voir les prédictions "sujets probables" pour son concours
- Discuter avec un tuteur IA qui cite les vrais sujets
- Le tout adapté au système burkinabè

---

## 9. COÛTS

| Poste | Estimation mensuelle |
|-------|---------------------|
| **OpenRouter** (mêmes crédits que Bobodo) | $15-40/mois |
| **Supabase** (pgvector inclus, Storage 1GB gratuit) | $0 supplémentaire |
| **LiveKit** (si utilisé pour les lives) | Gratuit jusqu'à 100 participants simultanés (plan communautaire) |
| **Total infra** | **$15-40/mois** |

---

## 10. AVANTAGE CONCURRENTIEL FINAL

| Critère | prepaconcoursbf.com | bfprepaconcours.com | SISANJO | **Academia** |
|---|---|---|---|---|
| App mobile native | ❌ | ❌ | ❌ | ✅ |
| IA tuteur 24/24 | ❌ | ❌ | ❌ | ✅ |
| Prédiction de sujets | ❌ | ❌ | ❌ | ✅ |
| Cours live vidéo | ❌ | ❌ | ✅ (présentiel) | ✅ (in-app) |
| Exercices enseignant | ❌ | ❌ | ✅ (papier) | ✅ (digital + IA) |
| Correction IA | ❌ | ❌ | ❌ | ✅ |
| Gamification | ❌ | ❌ | ❌ | ✅ |
| Communauté candidats | ❌ | ❌ | ❌ | ✅ |
| Prix | 3-10k FCFA/module | Gratuit/limité | Présentiel cher | **Freemium** |
| Marché adressable | — | — | — | **~2M candidatures/an** |
