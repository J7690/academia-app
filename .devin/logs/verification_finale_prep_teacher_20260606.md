# RAPPORT DE VÉRIFICATION FINALE — RPC PREPA ENSEIGNANT

**Projet:** academia_app
**Date:** 6 Juin 2026
**Objectif:** Vérifier la cohérence des 8 RPC app_prep_teacher_* avant migration

---

## PHASE 1 — Définition SQL complète et dépendances

### app_prep_teacher_list_assignments
- **Tables utilisées:** prep_assignments, prep_assignment_submissions
- **Vues utilisées:** Aucune
- **Fonctions appelées:** jsonb_agg, row_to_json (PostgreSQL intégrées)
- **Schémas utilisés:** app, auth

### app_prep_teacher_upsert_assignment
- **Tables utilisées:** prep_assignments
- **Vues utilisées:** Aucune
- **Fonctions appelées:** jsonb_build_object (PostgreSQL intégrée)
- **Schémas utilisés:** app, auth

### app_prep_teacher_list_submissions
- **Tables utilisées:** prep_assignments, prep_assignment_submissions, students
- **Vues utilisées:** Aucune
- **Fonctions appelées:** jsonb_agg, row_to_json, jsonb_build_object (PostgreSQL intégrées)
- **Schémas utilisés:** app, auth

### app_prep_teacher_grade_submission
- **Tables utilisées:** prep_assignment_submissions
- **Vues utilisées:** Aucune
- **Fonctions appelées:** jsonb_build_object (PostgreSQL intégrée)
- **Schémas utilisés:** app, auth

### app_prep_teacher_list_live_sessions
- **Tables utilisées:** prep_live_sessions, prep_live_participants
- **Vues utilisées:** Aucune
- **Fonctions appelées:** jsonb_agg, row_to_json (PostgreSQL intégrées)
- **Schémas utilisés:** app, auth

### app_prep_teacher_upsert_live_session
- **Tables utilisées:** prep_live_sessions
- **Vues utilisées:** Aucune
- **Fonctions appelées:** jsonb_build_object (PostgreSQL intégrée)
- **Schémas utilisés:** app, auth

### app_prep_teacher_start_live_session
- **Tables utilisées:** prep_live_sessions
- **Vues utilisées:** Aucune
- **Fonctions appelées:** jsonb_build_object (PostgreSQL intégrée)
- **Schémas utilisés:** app, auth

### app_prep_teacher_end_live_session
- **Tables utilisées:** prep_live_sessions
- **Vues utilisées:** Aucune
- **Fonctions appelées:** jsonb_build_object (PostgreSQL intégrée)
- **Schémas utilisés:** app, auth

---

## PHASE 2 — Vérification des tables référencées

| Table | Existe | Schéma | Enregistrements (est.) |
|-------|--------|--------|------------------------|
| prep_assignments | ✓ | app | -1 |
| prep_assignment_submissions | ✓ | app | -1 |
| prep_live_sessions | ✓ | app | -1 |
| prep_live_participants | ✓ | app | -1 |
| students | ✓ | app | 57 |

**Résultat:** Toutes les tables existent dans le schéma app.

---

## PHASE 3 — Vérification des vues référencées

**Résultat:** Aucune vue n'est utilisée par les 8 RPCs.

---

## PHASE 4 — Vérification des fonctions appelées

**Résultat:** Aucune RPC personnalisée n'est appelée. Seules des fonctions PostgreSQL intégrées sont utilisées:
- jsonb_agg
- row_to_json
- jsonb_build_object
- auth.uid()

Ces fonctions sont toujours disponibles dans PostgreSQL.

---

## PHASE 5 — Détermination de l'état des RPCs

**Question:** Les 8 RPC sont-elles A) complètement opérationnelles et simplement dans le mauvais schéma ou B) partiellement cassées car certaines dépendances n'existent pas ?

**Réponse:** A) complètement opérationnelles et simplement dans le mauvais schéma

**Justification:**
- Toutes les tables référencées existent
- Aucune vue n'est utilisée
- Aucune RPC personnalisée n'est appelée
- Seules des fonctions PostgreSQL intégrées sont utilisées
- Les RPCs s'exécutent correctement via execute_sql (test lecture seule)
- Le seul problème est le schéma (app au lieu de public)
- PostgREST n'expose que le schéma public par défaut

**Conclusion:** Les RPCs sont fonctionnelles mais inaccessibles via PostgREST car elles sont dans le schéma app au lieu de public. Le déplacement vers public résoudra le problème.

---

## PHASE 6 — Tableau final

| RPC | Dépendances | État | Prête au déplacement |
|-----|-------------|------|---------------------|
| app_prep_teacher_list_assignments | prep_assignments, prep_assignment_submissions | OK | OUI |
| app_prep_teacher_upsert_assignment | prep_assignments | OK | OUI |
| app_prep_teacher_list_submissions | prep_assignments, prep_assignment_submissions, students | OK | OUI |
| app_prep_teacher_grade_submission | prep_assignment_submissions | OK | OUI |
| app_prep_teacher_list_live_sessions | prep_live_sessions, prep_live_participants | OK | OUI |
| app_prep_teacher_upsert_live_session | prep_live_sessions | OK | OUI |
| app_prep_teacher_start_live_session | prep_live_sessions | OK | OUI |
| app_prep_teacher_end_live_session | prep_live_sessions | OK | OUI |

---

## CONCLUSION

Toutes les 8 RPCs sont:
- Complètement opérationnelles
- Toutes les dépendances existent
- Prêtes au déplacement vers public

Le fichier SQL de migration peut être exécuté en toute sécurité:
`C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\sql_changes\change_20260606_move_prep_teacher_rpcs_to_public.sql`

---

**FIN DU RAPPORT**
