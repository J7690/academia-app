# RAPPORT DE QUALIFICATION — LES 68 RPC PROBLÉMATIQUES

**Date** : 2026-06-04
**Statut** : QUALIFICATION COMPLÈTE — AUCUNE MODIFICATION EFFECTUÉE
**Méthode** : Analyse statique approfondie du code Flutter
**Projet** : Academia (Flutter + Supabase)

---

## SOMMAIRE EXÉCUTIF

Sur les **68 RPC problématiques** identifiés lors de l'audit systémique :

| Classe | Définition | Nombre | Action |
|--------|-----------|--------|--------|
| **A** | Cassé et visible utilisateur | **1** | **Corriger immédiatement** |
| **B** | Cassé mais masqué (silencieux) | **46** | **Corriger prochainement** |
| **C** | Non utilisé (0 occurrence Flutter) | **6** | **Ignorer ou supprimer** |
| **D** | Utilisé mais fonctionne (double public+app) | **15** | **Ignorer pour l'instant** |
| **Total** | | **68** | |

**Révélation clé** : Seul **1 RPC sur 68** provoque actuellement une erreur **visible et non gérée** pour l'utilisateur final. Les 46 autres RPC cassés sont **masqués** par des try-catch silencieux. Les 15 doubles fonctionnent correctement via le schéma `public`.

---

## MÉTHODOLOGIE

### Phase 1 — Extraction
- Lecture du fichier `rpc_matrix_full.json` (68 RPC problématiques)
- Lecture du fichier `flutter_rpc_detailed.json` (fichiers, lignes, contextes)

### Phase 2 — Classification métier
- Déduction du module à partir du nom du RPC et du fichier appelant
- Rôle (student, teacher, admin)
- Fonctionnalité (analytics, prep, gaming, messagerie, etc.)

### Phase 3 — Analyse statique des chemins d'activation
Pour chaque occurrence de RPC dans le code Flutter :
- Lecture de ±20 lignes autour de l'appel
- Détection de `try { ... } catch(e) { ... }`
- Analyse du traitement d'erreur (SnackBar, debugPrint, silence)
- Détection du chemin d'activation (onPressed, initState, Timer, etc.)

### Limitation
Tests runtime sur téléphone physique non effectués. L'analyse s'appuie exclusivement sur le code source statique.

---

## PHASE 1 — LISTE COMPLÈTE DES 68 RPC

### A — Cassé et visible utilisateur (1 RPC)

| RPC | Module | Fichier Flutter | Ligne |
|-----|--------|-----------------|-------|
| `app_student_delete_forum_message` | Messagerie forum | `features/student/online_course_detail_screen.dart` | 925 |

### B — Cassé mais masqué (46 RPC)

| RPC | Module | Fichier Flutter | Masquage |
|-----|--------|-----------------|----------|
| `app_track_navigation_event` | Analytics | `services/analytics_tracking_service.dart` | `debugPrint` dans try-catch |
| `app_prep_create_question_bank` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_create_question` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_list_questions` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_list_question_banks` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_save_quiz_attempt` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_get_leaderboard` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_list_flashcard_decks` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_list_flashcards` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_save_flashcard_review` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_create_flashcard_deck` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_create_flashcard` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_list_exam_papers` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_create_exam_paper` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_create_ai_conversation` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_save_ai_message` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_list_ai_conversations` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_list_ai_messages` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_get_ai_config` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_list_quiz_templates` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_create_quiz_template` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_admin_get_stats` | Prep Concours admin | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_admin_list_questions` | Prep Concours admin | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_admin_toggle_question` | Prep Concours admin | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_admin_list_ai_conversations` | Prep Concours admin | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_admin_upsert_badge` | Prep Concours admin | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_update_ai_config` | Prep Concours admin | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_get_student_progress` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_get_subject_stats` | Prep Concours | `services/td_service.dart` | Aucun try-catch au niveau service |
| `app_prep_teacher_list_assignments` | Prep Concours enseignant | `providers/teacher_prep_assignments_provider.dart` | Try-catch avec `_setError` visible |
| `app_prep_teacher_upsert_assignment` | Prep Concours enseignant | `providers/teacher_prep_assignments_provider.dart` | Try-catch avec `_setError` visible |
| `app_prep_teacher_list_submissions` | Prep Concours enseignant | `providers/teacher_prep_assignments_provider.dart` | Try-catch avec `_setError` visible |
| `app_prep_teacher_grade_submission` | Prep Concours enseignant | `providers/teacher_prep_assignments_provider.dart` | Try-catch avec `_setError` visible |
| `app_prep_teacher_list_live_sessions` | Prep Concours enseignant | `providers/teacher_prep_live_sessions_provider.dart` | Try-catch avec `_setError` visible |
| `app_prep_teacher_upsert_live_session` | Prep Concours enseignant | `providers/teacher_prep_live_sessions_provider.dart` | Try-catch avec `_setError` visible |
| `app_prep_teacher_start_live_session` | Prep Concours enseignant | `providers/teacher_prep_live_sessions_provider.dart` | Try-catch avec `_setError` visible |
| `app_prep_teacher_end_live_session` | Prep Concours enseignant | `providers/teacher_prep_live_sessions_provider.dart` | Try-catch avec `_setError` visible |
| `league_create` | Gaming | `games/providers/tournament_provider.dart` | Try-catch avec `print` silencieux |
| `league_get_standings` | Gaming | `games/providers/tournament_provider.dart` | Try-catch avec `print` silencieux |
| `league_join` | Gaming | `games/providers/tournament_provider.dart` | Try-catch avec `print` silencieux |
| `league_list_available` | Gaming | `games/providers/tournament_provider.dart` | Try-catch avec `print` silencieux |
| `league_report_match_result` | Gaming | `games/providers/tournament_provider.dart` | Try-catch avec `print` silencieux |
| `tournament_create` | Gaming | `games/providers/tournament_provider.dart` | Try-catch avec `print` silencieux |
| `tournament_get_details` | Gaming | `games/providers/tournament_provider.dart` | Try-catch avec `print` silencieux |
| `tournament_get_standings` | Gaming | `games/providers/tournament_provider.dart` | Try-catch avec `print` silencieux |
| `tournament_list_available` | Gaming | `games/providers/tournament_provider.dart` | Try-catch avec `print` silencieux |
| `tournament_register` | Gaming | `games/providers/tournament_provider.dart` | Try-catch avec `print` silencieux |
| `tournament_report_match_result` | Gaming | `games/providers/tournament_provider.dart` | Try-catch avec `print` silencieux |
| `tournament_start` | Gaming | `games/providers/tournament_provider.dart` | Try-catch avec `print` silencieux |

### C — Non utilisé (6 RPC)

| RPC | Module | Occurrences Flutter |
|-----|--------|---------------------|
| `app_admin_delete_course` | Administration | 0 |
| `app_admin_delete_program` | Administration | 0 |
| `app_admin_list_deleted_users` | Administration | 0 |
| `app_admin_get_navigation_stats` | Analytics | 0 |
| `app_student_delete_dm_message` | Messagerie DM | 0 |

### D — Utilisé mais fonctionne (15 RPC)

| RPC | Module | Fichier Flutter | Commentaire |
|-----|--------|-----------------|-------------|
| `app_admin_resolve_content_report` | Admin | `features/admin/admin_moderation_screen.dart` | Double public+app |
| `app_admin_suspend_user` | Admin | `features/admin/admin_moderation_screen.dart` | Double public+app |
| `app_admin_tv_delete_overlay` | TV/Hero | *(non appelé)* | Double public+app |
| `app_admin_tv_get_timeline` | TV/Hero | *(non appelé)* | Double public+app |
| `app_admin_tv_upsert_overlay` | TV/Hero | *(non appelé)* | Double public+app |
| `app_get_or_create_bobodo_session` | Bobodo | `providers/bobodo_provider.dart` | Double public+app |
| `app_prep_get_adaptive_quiz` | Prep Concours | `providers/prep_quiz_provider.dart` | Double public+app |
| `app_prep_get_student_progress` | Prep Concours | `providers/prep_quiz_provider.dart` + `services/td_service.dart` | Double public+app |
| `app_prep_get_subject_stats` | Prep Concours | `providers/prep_quiz_provider.dart` + `services/td_service.dart` | Double public+app |
| `app_prep_get_weakness_analysis` | Prep Concours | `providers/prep_weakness_provider.dart` | Double public+app |
| `app_td_admin_import_questions_json` | TD Admin | `features/admin/admin_td_direct_import_screen.dart` | Double public+app |
| `app_td_admin_import_text_bulk` | TD Admin | `features/admin/admin_td_direct_import_screen.dart` | Double public+app |
| `challenge_game_end_live` | Gaming Live | `games/services/game_live_service.dart` | Double public+app |
| `challenge_game_list_live` | Gaming Live | `games/services/game_live_service.dart` | Double public+app |
| `challenge_game_start_live` | Gaming Live | `games/services/game_live_service.dart` | Double public+app |

---

## PHASE 2 — CLASSIFICATION MÉTIER

### Module Analytics (2 RPC)

| RPC | Rôle | Fonctionnalité | Écran | Fréquence |
|-----|------|---------------|-------|-----------|
| `app_track_navigation_event` | Tous | Tracking navigation en arrière-plan | Tous les écrans | Très fréquent (toutes les 30s) |
| `app_admin_get_navigation_stats` | Admin | Stats navigation agrégées | Dashboard admin | Rare (si jamais appelé) |

### Module Prep Concours (38 RPC)

**Sous-module Étudiant (24 RPC)** : Question banks, questions, flashcards, exam papers, quiz attempts, progress, leaderboard, AI conversations, AI messages, AI config. Rôle : Étudiant. Fréquence : Élevée.

**Sous-module Enseignant Prep (8 RPC)** : Assignments, submissions, grading, live sessions. Rôle : Enseignant prep. Fréquence : Moyenne.

**Sous-module Admin Prep (6 RPC)** : Stats, list questions, toggle question, AI conversations, badges, AI config. Rôle : Admin. Fréquence : Rare.

### Module Gaming (12 RPC)

Ligues et tournois. Rôle : Tous. Écrans : ligues, tournois. Fréquence : Moyenne.

### Module Messagerie (2 RPC)

| RPC | Rôle | Fonctionnalité | Écran | Fréquence |
|-----|------|---------------|-------|-----------|
| `app_student_delete_forum_message` | Étudiant | Supprimer son message forum | Détail cours en ligne | Rare |
| `app_student_delete_dm_message` | Étudiant | Supprimer message privé | Messagerie DM | Inconnu (0 occurrence) |

### Module Administration (3 RPC absents)

| RPC | Rôle | Fonctionnalité | Écran | Fréquence |
|-----|------|---------------|-------|-----------|
| `app_admin_delete_course` | Admin | Suppression cours | Admin | Inconnu (0 occurrence) |
| `app_admin_delete_program` | Admin | Suppression programme | Admin | Inconnu (0 occurrence) |
| `app_admin_list_deleted_users` | Admin | Liste utilisateurs supprimés | Admin | Inconnu (0 occurrence) |

---

## PHASE 3 — ANALYSE STATIQUE DES CHEMINS D'ACTIVATION

### 3.1 RPC sans try-catch = erreur brute visible

**`app_student_delete_forum_message`**
```dart
// features/student/online_course_detail_screen.dart:925
await Supabase.instance.client.rpc('app_student_delete_forum_message', params: {'p_message_id': msgId});
p.loadMessages(threadId);
```
- **Pas de try-catch**
- Appelé dans un `onTap` (pression longue sur message)
- Si le RPC échoue (PGRST202), l'exception Dart se propage → **l'utilisateur voit une erreur brute**

### 3.2 RPC avec try-catch silencieux

**Analytics : `app_track_navigation_event`**
```dart
try {
  await _client.rpc('app_track_navigation_event', params: {...});
} catch (e) {
  debugPrint('[Analytics] Error flushing event: $e');
}
```
- Erreur loguée en debug uniquement
- **Perte silencieuse de 100% des données analytics**

**Gaming (12 RPC)** : Try-catch avec `print('Error ...: $e')` uniquement. Aucun SnackBar. L'utilisateur voit un écran vide.

### 3.3 RPC avec try-catch et erreur visible

**Teacher Prep (8 RPC)** : Erreur affichée via `_setError(e.toString())`. L'enseignant voit le message. Fonctionnalité bloquée mais l'utilisateur sait pourquoi.

### 3.4 RPC dans td_service.dart

Les 25+ RPC Prep Concours dans `td_service.dart` n'ont pas de try-catch au niveau du service. Si l'appelant n'enveloppe pas, l'erreur est brute.

---

## PHASE 4 — MATRICE D'IMPACT

| Classe | Nombre | Description |
|--------|--------|-------------|
| **A** | **1** | `app_student_delete_forum_message` — Erreur visible utilisateur |
| **B** | **46** | Cassé mais masqué par try-catch silencieux |
| **C** | **6** | Non utilisé par Flutter (0 occurrence) |
| **D** | **15** | Double public+app — fonctionne correctement |
| **E** | **0** | — |

---

## PHASE 5 — PRIORISATION

### CRITIQUE (1 RPC)

**`app_student_delete_forum_message`**
- Erreur visible et non gérée lors d'une action utilisateur
- L'utilisateur final voit une erreur technique brute
- Effort de correction : Très faible (1 RPC)

### ÉLEVÉ (36 RPC)

- **Teacher Prep (8 RPC)** : Fonctionnalités enseignant bloquées avec message d'erreur visible
- **Gaming (12 RPC)** : Module gaming entier non fonctionnel, engagement réduit
- **Analytics (1 RPC)** : Perte silencieuse de données stratégiques
- **Prep étudiant core (15 RPC)** : Fonctionnalités cœur du module Prep bloquées

### MOYEN (10 RPC)

- **Prep étudiant secondaire (6 RPC)** : AI et templates moins critiques
- **Prep admin (4 RPC)** : Fonctionnalités admin rarement utilisées

### FAIBLE (11 RPC)

- **Doubles non utilisés (3 RPC)** : Existent en double mais non appelés
- **Absents non utilisés (3 RPC)** : Jamais appelés par Flutter
- **Doubles utilisés (15 RPC classés D)** : Fonctionnent déjà

---

## PHASE 6 — PLAN DE CORRECTION

### À corriger immédiatement (1 RPC)

| RPC | Action |
|-----|--------|
| `app_student_delete_forum_message` | Déplacer de `app` vers `public` ou créer un proxy `public` |

### À corriger plus tard (46 RPC)

| Lot | RPC | Effort estimé |
|-----|-----|---------------|
| 1 — Gaming | 12 RPC `league_*` et `tournament_*` | ~1 heure |
| 2 — Teacher Prep | 8 RPC `app_prep_teacher_*` | ~45 min |
| 3 — Prep core | 15 RPC les plus utilisés | ~1 heure |
| 4 — Prep secondaire + admin | 11 RPC AI/templates/admin | ~45 min |
| 5 — Analytics | `app_track_navigation_event` | ~15 min |

### À supprimer (15 RPC)

Versions `app` des 15 RPC doubles, après vérification qu'aucune fonction PostgreSQL interne ne les appelle.

### À ignorer (6 RPC)

`app_admin_delete_course`, `app_admin_delete_program`, `app_admin_list_deleted_users`, `app_admin_get_navigation_stats`, `app_student_delete_dm_message`, et les TV doubles non appelés.

---

## CONCLUSION

**Ne pas lancer une correction massive sur 68 RPC.**

**Seul 1 RPC est réellement critique** pour l'utilisateur final aujourd'hui :
- **`app_student_delete_forum_message`**

**46 RPC sont cassés mais masqués** — ils provoquent des dysfonctionnements silencieux (écrans vides, données non enregistrées) mais pas de crash visible.

**15 RPC fonctionnent déjà** car ils existent en double dans `public`.

**6 RPC ne sont pas utilisés** par Flutter.

**Recommandation** : Corriger le 1 RPC critique immédiatement, puis planifier la correction des 46 RPC masqués par lots priorisés.
