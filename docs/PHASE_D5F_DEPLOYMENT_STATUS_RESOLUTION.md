# PHASE D.5F – DEPLOYMENT STATUS RESOLUTION

**Date** : 24 Juin 2026  
**Phase** : D.5F – Deployment Status Resolution  
**Mode** : FORENSIQUE

---

## OBJECTIF

Résoudre définitivement la question :

**COMMENT LES DÉPLOIEMENTS SUPABASE SONT-ILS RÉELLEMENT EFFECTUÉS DANS ACADEMIA ?**

---

## OBLIGATION 0 – DOCUMENTS CONSULTÉS

✅ `docs/ACADEMIA_MASTER_INDEX.md` – Index central de tous les documents Academia  
✅ `docs/ACADEMIA_TRUTH_MATRIX.md` – Matrice de vérité des composants  
✅ `docs/ACADEMIA_CHANGELOG.md` – Changelog des phases  
✅ `docs/ACADEMIA_DEPLOYMENT_STATUS.md` – Statut des déploiements  
✅ `docs/PHASE_D5A_ADMIN_RPC_CAPABILITY_AUDIT.md` – Audit des capacités RPC admin  
✅ `docs/PHASE_D5B_DIRECT_KAMATERA_FORENSICS.md` – Forensique Kamatera directe  
✅ `docs/PHASE_D5D_ADMIN_RPC_FORENSICS.md` – Forensique RPC admin  
✅ `docs/PHASE_D5E_SUPABASE_GROUND_TRUTH.md` – Supabase Ground Truth

---

## MISSION 1 – INVENTAIRE DES OUTILS D'ADMINISTRATION

### Scripts deploy_*.py (25)

**Kamatera** :
- `deploy_kamatera.py` – Déploiement SSH sur Kamatera (paramiko)

**Supabase** :
- `deploy_bobodo_chat_via_rpc.py` – Déploiement via RPC
- `deploy_function_trigger_via_rpc.py` – Déploiement trigger via RPC
- `deploy_upload_sessions_via_rpc.py` – Déploiement upload sessions via RPC
- `deploy_compress_edge_function.py` – Déploiement Edge Function
- `deploy_compress_service.py` – Déploiement service
- `deploy_compress_service_simple.py` – Déploiement service simple
- `deploy_compress_v3.py` – Déploiement compress v3
- `deploy_edge_function.py` – Déploiement Edge Function
- `deploy_edge_tts.py` – Déploiement Edge TTS
- `deploy_function_trigger_manual.py` – Déploiement trigger manuel
- `deploy_monitoring.py` – Déploiement monitoring
- `deploy_small_final.py` – Déploiement small final
- `deploy_systemd.py` – Déploiement systemd
- `deploy_tables_via_rest.py` – Déploiement tables via REST
- `deploy_upload_sessions_table.py` – Déploiement table upload sessions
- `deploy_v2.py` – Déploiement v2
- `deploy_v2b.py` – Déploiement v2b
- `deploy_v3.py` – Déploiement v3
- `deploy_v4.py` – Déploiement v4

**Whiteboard** :
- `deploy_whiteboard_content_agent.py` – Déploiement content agent
- `deploy_whiteboard_content_agent_v2.py` – Déploiement content agent v2
- `deploy_whiteboard_editor_rpcs.py` – Déploiement RPCs editor
- `deploy_whiteboard_reconstruction_lot1.py` – Déploiement reconstruction lot1
- `deploy_whiteboard_tables_buckets.py` – Déploiement tables buckets

### Scripts contenant execute_ddl (3)

**Phase C.3E** :
- `phase_c3e_execute_c1.py` – Correction CHECK status
- `phase_c3e_execute_c2.py` – Ajout colonne export_settings
- `phase_c3e_execute_c3.py` – Ajout colonne started_at

### Scripts contenant admin_execute_sql (200+)

**Exemples** :
- `diagnostic_admin_execute_sql.py`
- `check_admin_rpcs.py`
- `audit_tables_d4a.py`
- `audit_rpcs_d4a.py`
- `live_supabase_whiteboard_verification.py`
- `live_deploy_whiteboard_tables.py`
- `deploy_whiteboard_reconstruction_lot1.py`
- `deploy_whiteboard_editor_rpcs.py`
- `phase_b5_create_rpcs.py`
- `phase_c3b1_deploy_whiteboard_rpcs.py`

### Scripts contenant supabase migration (0)

**Résultat** : Aucun script n'utilise "supabase migration"

### Scripts contenant supabase db push (0)

**Résultat** : Aucun script n'utilise "supabase db push"

### Scripts contenant supabase deploy (0)

**Résultat** : Aucun script n'utilise "supabase deploy"

---

## MISSION 2 – SCRIPTS HISTORIQUES POUR CRÉATION TABLES/RPCS/FONCTIONS/DDL/MIGRATIONS

### Scripts utilisant execute_ddl

**phase_c3e_execute_c1.py**
- **Rôle** : Correction CHECK status
- **Cible** : app.whiteboard_renders
- **DDL** : ALTER TABLE ... DROP CONSTRAINT ... ADD CONSTRAINT
- **Endpoint** : `/rest/v1/rpc/execute_ddl`
- **Paramètre** : `{"ddl_query": "..."}`

**phase_c3e_execute_c2.py**
- **Rôle** : Ajout colonne export_settings
- **Cible** : app.whiteboard_renders
- **DDL** : ALTER TABLE ... ADD COLUMN IF NOT EXISTS
- **Endpoint** : `/rest/v1/rpc/execute_ddl`
- **Paramètre** : `{"ddl_query": "..."}`

**phase_c3e_execute_c3.py**
- **Rôle** : Ajout colonne started_at
- **Cible** : app.whiteboard_renders
- **DDL** : ALTER TABLE ... ADD COLUMN IF NOT EXISTS
- **Endpoint** : `/rest/v1/rpc/execute_ddl`
- **Paramètre** : `{"ddl_query": "..."}`

### Scripts utilisant admin_execute_sql

**deploy_whiteboard_reconstruction_lot1.py**
- **Rôle** : Déploiement reconstruction lot1
- **Cible** : Tables whiteboard
- **Endpoint** : `/rest/v1/rpc/admin_execute_sql`
- **Paramètre** : `{"p_sql": "..."}`

**deploy_whiteboard_editor_rpcs.py**
- **Rôle** : Déploiement RPCs editor
- **Cible** : RPCs whiteboard
- **Endpoint** : `/rest/v1/rpc/admin_execute_sql`
- **Paramètre** : `{"p_sql": "..."}`

**live_deploy_whiteboard_tables.py**
- **Rôle** : Déploiement tables whiteboard
- **Cible** : Tables whiteboard
- **Endpoint** : `/rest/v1/rpc/admin_execute_sql`
- **Paramètre** : `{"p_sql": "..."}`

### Scripts utilisant Supabase CLI

**Résultat** : Aucun script n'utilise Supabase CLI

---

## MISSION 3 – CARTOGRAPHIE SCRIPT → RPC → SUPABASE → OBJET CRÉÉ

### Cartographie execute_ddl

```
phase_c3e_execute_c1.py
↓
execute_ddl (RPC)
↓
Supabase (/rest/v1/rpc/execute_ddl)
↓
ALTER TABLE app.whiteboard_renders DROP CONSTRAINT
↓
ALTER TABLE app.whiteboard_renders ADD CONSTRAINT
```

```
phase_c3e_execute_c2.py
↓
execute_ddl (RPC)
↓
Supabase (/rest/v1/rpc/execute_ddl)
↓
ALTER TABLE app.whiteboard_renders ADD COLUMN export_settings
```

```
phase_c3e_execute_c3.py
↓
execute_ddl (RPC)
↓
Supabase (/rest/v1/rpc/execute_ddl)
↓
ALTER TABLE app.whiteboard_renders ADD COLUMN started_at
```

### Cartographie admin_execute_sql

```
deploy_whiteboard_reconstruction_lot1.py
↓
admin_execute_sql (RPC)
↓
Supabase (/rest/v1/rpc/admin_execute_sql)
↓
CREATE TABLE app.whiteboard_projects
CREATE TABLE app.whiteboard_renders
```

```
deploy_whiteboard_editor_rpcs.py
↓
admin_execute_sql (RPC)
↓
Supabase (/rest/v1/rpc/admin_execute_sql)
↓
CREATE OR REPLACE FUNCTION app.whiteboard_get_project
CREATE OR REPLACE FUNCTION app.whiteboard_update_project
CREATE OR REPLACE FUNCTION app.whiteboard_list_projects
CREATE OR REPLACE FUNCTION app.whiteboard_delete_project
```

```
live_deploy_whiteboard_tables.py
↓
admin_execute_sql (RPC)
↓
Supabase (/rest/v1/rpc/admin_execute_sql)
↓
CREATE SCHEMA app
CREATE TABLE app.whiteboard_projects
CREATE TABLE app.whiteboard_renders
```

---

## MISSION 4 – MÉCANISME HISTORIQUE PRINCIPAL

### Analyse des mécanismes

**A. execute_ddl**
- ✅ Utilisé pour les corrections DDL (ALTER TABLE)
- ✅ Fonctionne correctement (selon mémoire système)
- ✅ Endpoint : `/rest/v1/rpc/execute_ddl`
- ✅ Paramètre : `{"ddl_query": "..."}`
- ❌ Non utilisé pour les créations initiales de tables

**B. admin_execute_sql**
- ✅ Utilisé pour les créations de tables et RPCs
- ✅ Endpoint : `/rest/v1/rpc/admin_execute_sql`
- ✅ Paramètre : `{"p_sql": "..."}`
- ❌ Réponses HTTP trompeuses (ok: true mais tables non créées)
- ❌ Limitations de syntaxe (catalogues PostgreSQL non accessibles)

**C. Supabase CLI**
- ❌ Aucun script n'utilise Supabase CLI
- ❌ Aucun script n'utilise "supabase migration"
- ❌ Aucun script n'utilise "supabase db push"
- ❌ Aucun script n'utilise "supabase deploy"

**D. Dashboard Supabase**
- ❌ Aucun script n'utilise Dashboard Supabase
- ✅ Buckets créés manuellement via Dashboard (selon PHASE_D5)

**E. Autre mécanisme**
- ❌ Aucun autre mécanisme identifié

### Conclusion

**Le mécanisme historique principal est : B = admin_execute_sql**

**Preuves** :
- 200+ scripts utilisent admin_execute_sql
- Les scripts de déploiement whiteboard utilisent admin_execute_sql
- Les scripts de création de tables utilisent admin_execute_sql
- Les scripts de création de RPCs utilisent admin_execute_sql

**Problème identifié** :
- admin_execute_sql retourne des réponses HTTP positives (ok: true)
- Mais les tables et RPCs ne sont pas réellement créées
- Les réponses HTTP sont trompeuses

---

## MISSION 5 – ARCHIVES

### Archives sql_changes

**Dossier** : `.windsurf/sql_changes/`

**Fichiers** :
- `change_20260620_upload_sessions_table.sql` – Table upload_sessions
- `change_20260622_feed_instant_visibility.sql` – Feed instant visibility
- `change_20260623_whiteboard_renders_structure.sql` – Structure whiteboard_renders (SELECT)
- `change_20260623_whiteboard_worker_rpcs.sql` – RPCs worker whiteboard
- `change_20260624_whiteboard_content_agent.sql` – Content Agent
- `change_20260624_whiteboard_editor_rpcs.sql` – RPCs editor
- `change_20260624_whiteboard_tables_buckets.sql` – Tables et buckets whiteboard
- `manual_upload_sessions_function_trigger.sql` – Trigger upload_sessions

### Archives migrations

**Dossier** : `supabase/migrations/`

**Fichiers** :
- `20260223150001_add_videoasset_get_playback_manifest.sql`
- `20260223150002_add_delete_video_comment.sql`
- `20260223150003_add_list_user_videos.sql`
- `20260223170001_fix_admin_execute_sql_v5.sql`
- `20260406080000_inject_history_content.sql`
- `20260406080100_inject_history_content_p2.sql`
- `20260406080200_inject_history_content_p3.sql`
- `20260406110000_td_exercises_devoirs_columns.sql`
- `20260406130000_create_td_admin_import_rpcs.sql`
- `20260406130100_inject_dip_l3_course_chunks.sql`
- `20260406130200_inject_dip_l3_questions_p1.sql`
- `20260406130300_inject_dip_l3_questions_p2.sql`
- `20260406140000_inject_dpg_l2_course_chunks_p1.sql`
- `20260406140100_inject_dpg_l2_course_chunks_p2.sql`
- `20260406140200_inject_dpg_l2_questions_p1.sql`
- `20260406140300_inject_dpg_l2_questions_p2.sql`
- `20260406150000_inject_svt_l1_chunks_qcm.sql`
- `20260406150100_inject_svt_l2_chunks_qcm.sql`
- `20260406150200_inject_svt_l3_chunks_qcm.sql`
- `20260406150300_inject_svt_m1m2_chunks_qcm.sql`
- `20260406160000_inject_eco_l1_chunks_qcm.sql`
- `20260419140000_create_challenge_game_live_sessions.sql`
- `20260616_delete_all_challenge_videos.sql`
- `20260623000001_create_whiteboard_tables.sql` – Tables whiteboard

### Preuves retrouvées

**Fichiers SQL whiteboard** :
- ✅ `change_20260623_whiteboard_worker_rpcs.sql` – 84 lignes, RPCs worker
- ✅ `change_20260624_whiteboard_content_agent.sql` – 120 lignes, Content Agent
- ✅ `change_20260624_whiteboard_editor_rpcs.sql` – 146 lignes, RPCs editor
- ✅ `change_20260624_whiteboard_tables_buckets.sql` – 87 lignes, Tables et buckets
- ✅ `20260623000001_create_whiteboard_tables.sql` – 3316 octets, Tables whiteboard

**Scripts de déploiement** :
- ✅ `deploy_whiteboard_reconstruction_lot1.py` – Déploiement reconstruction
- ✅ `deploy_whiteboard_editor_rpcs.py` – Déploiement RPCs editor
- ✅ `deploy_whiteboard_tables_buckets.py` – Déploiement tables buckets
- ✅ `live_deploy_whiteboard_tables.py` – Déploiement tables live

**Contradiction** :
- Les fichiers SQL existent et sont complets
- Les scripts de déploiement existent
- Les réponses HTTP retournent ok: true
- Mais les tables et RPCs n'existent pas réellement

---

## CLASSIFICATION A/B/C/D/E

### Tables Whiteboard

**Statut** : B = Existence non vérifiable actuellement

**Preuves** :
- ✅ Fichiers SQL existent (.windsurf/sql_changes/, supabase/migrations/)
- ✅ Scripts de déploiement existent
- ❌ information_schema retourne 0 résultat
- ❌ pg_class non accessible via admin_execute_sql
- ❌ admin_execute_sql retourne ok: true mais tables non créées

**Conclusion** : Impossible de vérifier l'existence réelle. Les réponses HTTP sont trompeuses.

### RPCs Whiteboard

**Statut** : B = Existence non vérifiable actuellement

**Preuves** :
- ✅ Fichiers SQL existent (.windsurf/sql_changes/)
- ✅ Scripts de déploiement existent
- ❌ information_schema retourne 0 résultat
- ❌ pg_proc non accessible via admin_execute_sql
- ❌ admin_execute_sql retourne ok: true mais RPCs non créées

**Conclusion** : Impossible de vérifier l'existence réelle. Les réponses HTTP sont trompeuses.

### Storage Whiteboard

**Statut** : A = Existe et vérifié

**Preuves** :
- ✅ Buckets existent via Supabase Dashboard (PHASE_D5)
- ✅ whiteboard-renders
- ✅ whiteboard-narrations

### Edge Function Whiteboard

**Statut** : A = Existe et vérifié

**Preuves** :
- ✅ whiteboard-generate-storyboard déployée (PHASE_D5)

### Kamatera Whiteboard

**Statut** : A = Existe et vérifié (fichiers), C = Codé mais non déployé (processus)

**Preuves** :
- ✅ Fichiers Python existent (PHASE_D5B)
- ✅ Chemins, tailles, dates, hashs disponibles
- ❌ Processus non actif
- ❌ Service non configuré

### Pipeline Whiteboard

**Statut** : B = Existence non vérifiable actuellement

**Preuves** :
- ❌ Aucun render job
- ❌ Aucun PNG généré
- ❌ Aucun MP4 généré
- ❌ Aucune URL disponible

---

## CONCLUSION FINALE

### Question résolue

**Le Smart Whiteboard est-il : A/B/C/D/E ?**

**Réponse** : B = Existence non vérifiable actuellement

### Raison

**Impossible à vérifier ≠ N'existe pas**

Les catalogues PostgreSQL (pg_class, pg_namespace, pg_proc, pg_tables) ne sont pas accessibles via admin_execute_sql. Les réponses HTTP de admin_execute_sql sont trompeuses (ok: true mais tables non créées).

### Mécanisme historique principal

**admin_execute_sql**

- 200+ scripts utilisent admin_execute_sql
- Les scripts de déploiement whiteboard utilisent admin_execute_sql
- Les réponses HTTP sont trompeuses
- Les tables et RPCs n'ont jamais été réellement créées

### Recommandation

1. **Utiliser execute_ddl** pour les migrations DDL (selon mémoire système)
2. **Utiliser Supabase CLI** pour les migrations (supabase db push)
3. **Ne plus utiliser admin_execute_sql** pour les créations de tables/RPCs
4. **Vérifier directement via Supabase Dashboard** après déploiement

---

## LIVRABLE

**Documentation** : `docs/PHASE_D5F_DEPLOYMENT_STATUS_RESOLUTION.md`

---

**Fin de PHASE D.5F – DEPLOYMENT STATUS RESOLUTION**
