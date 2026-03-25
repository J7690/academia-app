---
description: Module Préparation Concours — Architecture, IA OpenRouter via Edge Function, gestion des quiz et flashcards
---

# Module Préparation Concours

## Architecture

### Architecture IA (Option A — OpenRouter via Edge Function)

```
Flutter (PrepAiService)
  → HTTP POST {message, conversation_id, subject}
  → Supabase Edge Function `prep-tutor-chat`
    → Charge system_prompt depuis td_ai_config (RPC)
    → Charge historique conversation (RPC)
    → Appelle OpenRouter API (même clé que Bobodo, env var serveur)
    → Sauvegarde messages user + assistant (RPC)
  ← {reply: "..."}
```

**Avantages :**
- Clé API **jamais exposée côté client** (env var Supabase)
- **Même clé que Bobodo** — zéro config admin nécessaire
- **200+ modèles** disponibles via OpenRouter (Gemini, Claude, GPT, Llama…)
- System prompt configurable par l'admin dans l'app
- Historique de conversation chargé côté serveur
- Fallback mode démo si Edge Function pas encore déployée

### Tables Supabase (schéma `app`)
- `td_question_banks` — Banques de questions par concours/matière
- `td_questions` — Questions QCM avec options, correction, difficulté
- `td_quiz_templates` — Templates de quiz (durée, nb questions, mode examen)
- `td_quiz_attempts` — Tentatives de quiz par étudiant (score, temps, réponses)
- `td_flashcard_decks` — Decks de flashcards
- `td_flashcards` — Cartes recto/verso
- `td_flashcard_progress` — Progression SM-2 par étudiant/carte
- `td_exam_papers` — Sujets d'épreuves (PDF, concours, année)
- `td_student_progress` — Progression globale (XP, streak, niveau)
- `td_badges` — Configuration des badges
- `td_student_badges` — Badges débloqués par étudiant
- `td_ai_conversations` — Conversations IA par étudiant
- `td_ai_messages` — Messages IA (user/assistant)
- `td_ai_config` — Configuration IA (prompt système, limite messages/jour)

### RPCs Supabase (28 fonctions `app_prep_*`)
Toutes dans `td_service.dart` méthodes `prep*()`.

### Edge Function
- `supabase/functions/prep-tutor-chat/index.ts` — Tuteur IA via OpenRouter

### Fichiers Flutter

| Fichier | Rôle |
|---|---|
| `lib/theme/prep_theme.dart` | Design system couleurs apprentissage |
| `lib/services/prep_ai_service.dart` | Appel Edge Function `prep-tutor-chat` (OpenRouter) |
| `lib/services/td_service.dart` | 40+ méthodes RPC prep_* |
| `lib/providers/prep_quiz_provider.dart` | État quiz, XP, streaks |
| `lib/providers/prep_flashcard_provider.dart` | Flashcards SM-2 |
| `lib/features/student/prep/prep_home_tab.dart` | Dashboard étudiant |
| `lib/features/student/prep/prep_quiz_tab.dart` | QCM + examen blanc + flashcards |
| `lib/features/student/prep/prep_subjects_tab.dart` | Banque d'épreuves |
| `lib/features/student/prep/prep_ai_tab.dart` | Chat IA OpenRouter |
| `lib/features/student/prep/prep_stats_tab.dart` | Analytics + badges |
| `lib/features/student/student_td_root_screen.dart` | 6 onglets (Accueil/Quiz/Sujets/IA/Stats/Catalogue) |
| `lib/features/instructor/teacher_prep_screen.dart` | Enseignant: création quiz, sujets, résultats |
| `lib/features/admin/admin_prep_screen.dart` | Admin: dashboard, questions, config IA, badges |

## Déployer l'Edge Function `prep-tutor-chat`

L'Edge Function doit être déployée via le Supabase CLI :

```bash
# Depuis la racine du projet
cd supabase
supabase functions deploy prep-tutor-chat
```

Elle réutilise automatiquement les mêmes variables d'environnement que `bobodo-chat` :
- `OPENROUTER_API_KEY` — clé API OpenRouter (déjà configurée)
- `OPENROUTER_MODEL` — modèle de chat (déjà configuré)
- `SUPABASE_URL` — URL du projet (automatique)
- `SUPABASE_SERVICE_ROLE_KEY` — clé service role (automatique)

**Sans déploiement**, l'IA fonctionne en mode démo (réponses pré-écrites).

## Configurer le prompt système (admin)

1. Se connecter en tant qu'admin
2. Onglet **Prépa Quiz/IA** du dashboard admin
3. Onglet **IA Config** → modifier le **Prompt système**
4. Le prompt est chargé par l'Edge Function à chaque requête

## Ajouter des questions (enseignant)

1. Se connecter en tant qu'enseignant
2. Onglet **Prépa** dans le dashboard enseignant
3. **Nouvelle banque** → créer une banque par concours/matière
4. **Nouvelle question** → sélectionner la banque, écrire la question, les 4 options, cocher la bonne réponse, ajouter l'explication

## Ajouter des sujets d'épreuves (enseignant)

1. Onglet **Sujets** dans le dashboard enseignant Prépa
2. **Ajouter un sujet d'épreuve** → remplir titre, concours, année, matière, difficulté

## Gérer les badges (admin)

1. Onglet **Badges** dans le dashboard admin Prépa Quiz/IA
2. **Créer un badge** → code unique, titre, emoji, XP récompense, condition

## Injecter les questions du document scanné (2026-03-24)

### Source
Document de préparation au concours (Burkina Faso) scanné à l'envers, reconverti et extrait.  
**20 questions QCM** couvrant 6 matières : Mathématiques, Physique, Chimie, Biologie, Économie, Droit.

### Méthode 1 — SQL direct (recommandée)

1. Ouvrir l'**éditeur SQL de Supabase** (dashboard → SQL Editor)
2. Coller et exécuter :  
   `.windsurf/sql_changes/20260324_inject_scanned_questions.sql`
3. Ce script crée : matières → chapitres → questions publiées → choix QCM
4. Vérification finale incluse dans le script (SELECT par matière)

### Méthode 2 — Via l'admin Flutter (injection par RPC)

1. Se connecter en tant qu'**admin** dans l'app
2. Aller dans **Admin → Prépa concours**
3. Taper le bouton **téléchargement** (icône `file_download_rounded`) en haut à droite
4. Suivre les instructions à l'écran → **Lancer l'injection**
5. Les questions sont créées via `app_admin_prep_create_ai_generation` + `app_admin_prep_publish_ai_generation`

> ⚠️ La **Méthode 2** nécessite que les matières existent déjà (exécuter d'abord la Méthode 1 ou créer les matières manuellement via le bouton "+ Matière").

### Fichiers créés lors de l'injection

| Fichier | Rôle |
|---|---|
| `assets/data/prep_concours_questions_burkina.json` | 20 questions structurées (source vérité) |
| `lib/services/prep_concours_questions_service.dart` | Service Flutter pour charger/filtrer les questions localement |
| `lib/features/admin/prep_concours/admin_prep_import_screen.dart` | Écran admin d'injection via RPCs |
| `.windsurf/sql_changes/20260324_inject_scanned_questions.sql` | Script SQL d'injection directe Supabase |

## Réappliquer le schéma SQL

```bash
cd .windsurf
python apply_prep_concours_schema.py
```

Fichiers SQL:
- `.windsurf/supabase_prep_concours_schema.sql` — Tables + seeds
- `.windsurf/supabase_prep_concours_rpcs.sql` — 28 fonctions RPC
- `.windsurf/fix_prep_rls_policies.sql` — Politiques RLS
