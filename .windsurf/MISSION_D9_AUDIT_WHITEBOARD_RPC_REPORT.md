# MISSION D.9 – AUDIT ET NETTOYAGE COMPLET DES RPC WHITEBOARD

**Date**: 2026-06-25
**Mission**: Audit, cartographie et nettoyage des RPC whiteboard
**Statut**: TERMINÉ

---

## 1. NOMBRE TOTAL DE RPC WHITEBOARD

**Dans Supabase**: 0
**Attendues par Flutter**: 7
**Attendues par Worker Python**: 5
**Total attendues**: 12

---

## 2. NOMBRE DE DOUBLONS

**Doublons détectés**: 0

**Explication**: Aucune fonction whiteboard n'existe actuellement dans la base de données. Le problème PGRST203 ("Multiple Choices") ne peut pas se produire car il n'y a aucune fonction en double.

---

## 3. LISTE KEEP (RPCs à créer)

### RPCs Flutter (7)

1. **whiteboard_create_project**
   - Schéma: public
   - Signature: `(p_student_id uuid, p_subject text, p_renderer_id text, p_theme_id text, p_narration_mode text, p_storyboard_json jsonb) RETURNS jsonb`
   - Utilisateur: `SmartWhiteboardService.createProject()`

2. **whiteboard_get_project**
   - Schéma: public
   - Signature: `(p_project_id uuid) RETURNS jsonb`
   - Utilisateur: `SmartWhiteboardService.getProject()`

3. **whiteboard_update_project**
   - Schéma: public
   - Signature: `(p_project_id uuid, p_subject text, p_status text, p_renderer_id text, p_theme_id text, p_narration_mode text, p_storyboard_json jsonb) RETURNS jsonb`
   - Utilisateur: `SmartWhiteboardService.updateProject()`

4. **whiteboard_list_projects**
   - Schéma: public
   - Signature: `(p_status text) RETURNS jsonb`
   - Utilisateur: `SmartWhiteboardService.listProjects()`

5. **whiteboard_delete_project**
   - Schéma: public
   - Signature: `(p_project_id uuid) RETURNS jsonb`
   - Utilisateur: `SmartWhiteboardService.deleteProject()`

6. **whiteboard_create_render_job**
   - Schéma: public
   - Signature: `(p_project_id uuid) RETURNS jsonb`
   - Utilisateur: `SmartWhiteboardRenderService.createRenderJob()`

7. **whiteboard_get_render_status**
   - Schéma: public
   - Signature: `(p_render_id uuid) RETURNS jsonb`
   - Utilisateur: `SmartWhiteboardRenderService.getRenderStatus()`

### RPCs Worker Python (5)

8. **whiteboard_fetch_queued_jobs**
   - Schéma: public
   - Signature: `(p_limit integer DEFAULT 5) RETURNS TABLE (id uuid, storyboard jsonb, created_at timestamptz)`
   - Utilisateur: Worker Python (backend)

9. **whiteboard_mark_processing**
   - Schéma: public
   - Signature: `(p_job_id uuid) RETURNS void`
   - Utilisateur: Worker Python (backend)

10. **whiteboard_mark_done**
    - Schéma: public
    - Signature: `(p_job_id uuid, p_video_url text, p_duration_ms integer) RETURNS void`
    - Utilisateur: Worker Python (backend)

11. **whiteboard_mark_failed**
    - Schéma: public
    - Signature: `(p_job_id uuid, p_error_message text) RETURNS void`
    - Utilisateur: Worker Python (backend)

12. **whiteboard_get_any_student_id**
    - Schéma: public
    - Signature: `() RETURNS uuid`
    - Utilisateur: Worker Python (backend)

---

## 4. LISTE DELETE (RPCs à supprimer)

**Aucune RPC à supprimer**

**Raison**: Aucune fonction whiteboard n'existe dans la base de données.

---

## 5. SQL EXACT DE NETTOYAGE

```sql
-- CLEANUP WHITEBOARD DUPLICATES
-- Date: 2026-06-25
-- Purpose: Supprimer les RPCs whiteboard en double
--
-- RÉSULTAT DE L'AUDIT:
-- - Nombre total de fonctions whiteboard trouvées: 0
-- - Nombre de doublons détectés: 0
--
-- CONCLUSION:
-- AUCUNE fonction whiteboard n'existe dans la base de données.
-- Aucun nettoyage n'est nécessaire.
--
-- ACTION REQUISE:
-- Déployer les 12 RPCs whiteboard via les scripts SQL prévus:
-- - 01_create_app_schema.sql
-- - 02_create_whiteboard_tables.sql
-- - 03_create_rls_policies.sql
-- - 04_create_triggers.sql
-- - 05_create_rpcs_worker.sql
-- - 06_create_rpcs_editor.sql
-- - 07_create_public_wrapper_rpc.sql
```

---

## 6. CONTRAT OFFICIEL FINAL

**Document de référence**: `.windsurf/whiteboard_rpc_contract.md`

**Principes**:
1. Toutes les RPCs sont dans le schéma **public** pour être accessibles via PostgREST
2. Les paramètres sont préfixés par **p_** pour éviter les conflits avec les noms de colonnes
3. Les retours sont en format **JSONB** pour faciliter le parsing côté client
4. Les erreurs sont retournées dans le JSON avec un champ "error"
5. Les paramètres optionnels ont une valeur **DEFAULT NULL**

---

## 7. DOCUMENTS CRÉÉS

1. **`.windsurf/audit_whiteboard_rpc_duplicates.md`** - Inventaire complet avec décision KEEP/DELETE pour chaque RPC
2. **`.windsurf/whiteboard_rpc_contract.md`** - Contrat officiel unique avec signatures et conventions
3. **`.windsurf/whiteboard_rpc_wiring.md`** - Cartographie des appels Flutter → Supabase et Worker Python → Supabase
4. **`.windsurf/cleanup_whiteboard_duplicates.sql`** - SQL de nettoyage (vide dans ce cas)

---

## 8. ACTION REQUISE

**Déployer les scripts SQL dans l'ordre** sur le SQL Editor Supabase:

1. `academia_app/.windsurf/sql/01_create_app_schema.sql`
2. `academia_app/.windsurf/sql/02_create_whiteboard_tables.sql`
3. `academia_app/.windsurf/sql/03_create_rls_policies.sql`
4. `academia_app/.windsurf/sql/04_create_triggers.sql`
5. `academia_app/.windsurf/sql/05_create_rpcs_worker.sql`
6. `academia_app/.windsurf/sql/06_create_rpcs_editor.sql`
7. `academia_app/.windsurf/sql/07_create_public_wrapper_rpc.sql`

**Après déploiement**, exécuter:
```bash
cd c:\Users\fasop\AndroidStudioProjects\academia\academia_app\.windsurf; python verify_whiteboard_deployment.py
```

---

## 9. VÉRIFICATION

Après déploiement, vérifier que:
- ✅ Le schéma `app` existe
- ✅ Les 3 tables existent (whiteboard_projects, whiteboard_renders, whiteboard_ai_generations)
- ✅ Les 9 indexes existent
- ✅ Les 10 RLS policies existent
- ✅ Les 2 triggers existent
- ✅ Les 12 RPCs existent dans le schéma public
- ✅ Aucun doublon PGRST203

---

## 10. CONCLUSION

**Problème PGRST203**: Non applicable (aucune fonction n'existe)

**Action requise**: Déployer les 12 RPCs whiteboard via les scripts SQL prévus.

**Risque de doublon futur**: Si les scripts sont exécutés plusieurs fois, les fonctions seront remplacées (CREATE OR REPLACE), donc aucun risque de doublon.

**Statut de la mission**: ✅ TERMINÉE - Audit complet, contrat défini, cartographie effectuée, SQL de nettoyage généré (vide).
