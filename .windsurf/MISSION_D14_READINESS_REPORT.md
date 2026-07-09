# MISSION D.14 – RAPPORT DE PRÉPARATION À LA CRÉATION DES RPCs FLUTTER

**Date**: 2026-06-26
**Version app**: 1.0.6+11
**Statut**: ⏸️ EN ATTENTE DE VALIDATION

---

## RÉSUMÉ

La MISSION D.14 a analysé les appels Flutter dans `smart_whiteboard/`, comparé avec `pg_proc` (source de vérité), et généré le script de création des 7 RPCs manquantes.

**Aucune exécution n'a encore été faite**. Le tableau final est présenté ci-dessous pour validation avant CREATE.

---

## PHASE 1 – ANALYSE FLUTTER

**Fichiers analysés**:
- `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart`
- `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_render_service.dart`
- `academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart`

**Appels `.rpc()` identifiés**:
- `whiteboard_create_project` (service, ligne 24)
- `whiteboard_get_project` (service, ligne 41)
- `whiteboard_update_project` (service, ligne 61)
- `whiteboard_list_projects` (service, ligne 79 + provider, ligne 531)
- `whiteboard_delete_project` (service, ligne 91)
- `whiteboard_create_render_job` (render_service, ligne 18)
- `whiteboard_get_render_status` (render_service, ligne 30)

---

## PHASE 2 – INVENTAIRE FLUTTER

**Document produit**: `.windsurf/flutter_rpc_inventory_final.md`

Ce document contient pour chaque RPC:
- Fichier et ligne
- Paramètres exacts
- Signature SQL attendue
- Implémentation SQL complète

---

## PHASE 3 – COMPARAISON AVEC PG_PROC

**SQL de vérification**:
```sql
SELECT
    n.nspname,
    p.proname,
    pg_get_function_identity_arguments(p.oid)
FROM pg_proc p
JOIN pg_namespace n
ON n.oid=p.pronamespace
WHERE p.proname ILIKE '%whiteboard%'
ORDER BY n.nspname,p.proname;
```

**Résultat pg_proc (source de vérité)**:
- `app.whiteboard_ai_generations_updated_at` (trigger)
- `app.whiteboard_projects_updated_at` (trigger)
- `public.whiteboard_fetch_queued_jobs` (worker)
- `public.whiteboard_get_any_student_id` (worker)
- `public.whiteboard_mark_done` (worker)
- `public.whiteboard_mark_failed` (worker)
- `public.whiteboard_mark_processing` (worker)

**Nombre total de fonctions whiteboard**: 7

**Nombre de RPCs Flutter existantes**: 0

**Conclusion**: Les 7 RPCs Flutter sont **MISSING**.

---

## PHASE 4 – SCRIPT DE CRÉATION

**Document produit**: `.windsurf/create_missing_flutter_rpcs.sql`

Contenu:
- 7 `CREATE OR REPLACE FUNCTION` dans `public`
- 7 `DROP FUNCTION IF EXISTS` préalables pour éviter les conflits
- Aucune surcharge
- Aucune création dans `app`

---

## PHASE 5 – TABLEAU FINAL

### KEEP

| Nom | Schéma | Type | Raison |
|-----|--------|------|--------|
| whiteboard_ai_generations_updated_at | app | Trigger | Conservé du nettoyage D.13 |
| whiteboard_projects_updated_at | app | Trigger | Conservé du nettoyage D.13 |
| whiteboard_fetch_queued_jobs | public | RPC worker | Worker Python |
| whiteboard_get_any_student_id | public | RPC worker | Worker Python |
| whiteboard_mark_done | public | RPC worker | Worker Python |
| whiteboard_mark_failed | public | RPC worker | Worker Python |
| whiteboard_mark_processing | public | RPC worker | Worker Python |

### CREATE

| Nom | Schéma | Paramètres | Appel Flutter |
|-----|--------|------------|---------------|
| whiteboard_create_project | public | 6 | service.dart:24 |
| whiteboard_get_project | public | 1 | service.dart:41 |
| whiteboard_update_project | public | 7 | service.dart:61 |
| whiteboard_list_projects | public | 1 optionnel | service.dart:79 + provider.dart:531 |
| whiteboard_delete_project | public | 1 | service.dart:91 |
| whiteboard_create_render_job | public | 1 | render_service.dart:18 |
| whiteboard_get_render_status | public | 1 | render_service.dart:30 |

### DELETE

Aucune. Le nettoyage D.13 a déjà supprimé tous les doublons.

---

## COMMANDE D'EXÉCUTION PRÉVUE

```bash
python .windsurf/d14_execute_create.py
```

Ou exécution manuelle du SQL dans le SQL Editor Supabase:
`.windsurf/create_missing_flutter_rpcs.sql`

---

## RÈGLES RESPECTÉES

✅ Lecture exclusive de `smart_whiteboard/`
✅ Extraction de tous les appels `.rpc()`
✅ Vérification via `pg_proc` (source de vérité)
✅ Aucune création sans preuve
✅ Génération d'un seul script SQL sans surcharge
✅ Tableau final affiché avant toute exécution

---

## VALIDATION REQUISE

**Aucune RPC n'a encore été créée.**

Pour exécuter la création, répondre `exécuter` ou `valider`.
