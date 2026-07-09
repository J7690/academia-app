# PHASE D.5G – ADMIN TOOLCHAIN MAPPING

**Date** : 24 Juin 2026  
**Phase** : D.5G – Admin Toolchain Mapping  
**Mode** : FORENSIQUE

---

## OBJECTIF

Retrouver et cartographier l'intégralité des mécanismes d'administration déjà présents dans le projet Academia.

---

## MISSION 1 – INVENTAIRE COMPLET DES OUTILS D'ADMINISTRATION

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
- `deploy_upload_sessions_table.py` – Déploiement table upload sessions (via Supabase client)
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

### Scripts check_*.py (40)

**Supabase** :
- `check_admin_rpcs.py` – Vérification RPCs admin
- `check_app_schema.py` – Vérification schéma app
- `check_app_tables.py` – Vérification tables app
- `check_public_schema_whiteboard.py` – Vérification schéma public whiteboard
- `check_all_schemas_whiteboard.py` – Vérification tous schémas whiteboard
- `check_existing_whiteboard_tables.py` – Vérification tables whiteboard existantes
- `check_rpc.py` – Vérification RPC
- `check_rpc2.py` – Vérification RPC v2
- `check_rpc3.py` – Vérification RPC v3
- `check_schemas.py` – Vérification schémas
- `check_tables_direct.py` – Vérification tables directe
- `check_whiteboard_rpcs.py` – Vérification RPCs whiteboard
- `check_ai_action_prices.py` (v2-v9) – Vérification prix actions IA
- `check_upload_sessions_table.py` – Vérification table upload sessions
- `check_video_tables.py` – Vérification tables vidéo
- `check_students_structure.py` – Vérification structure students

**Kamatera** :
- `check_kamatera.py` – Vérification Kamatera
- `check_kamatera_services.py` – Vérification services Kamatera
- `check_systemd.py` – Vérification systemd
- `check_logs.py` – Vérification logs
- `check_logs_multi.py` – Vérification logs multi
- `check_logs_single.py` – Vérification logs single
- `check_logs_v2.py` – Vérification logs v2
- `check_resources_now.py` – Vérification ressources actuelles
- `check_ram_final.py` – Vérification RAM final
- `check_model_size.py` – Vérification taille modèle
- `check_model_state.py` – Vérification état modèle
- `check_openrouter_key.py` – Vérification clé OpenRouter
- `check_whisper_details.py` – Vérification détails Whisper

**Autres** :
- `check_assemble_chunks.py` – Vérification assemblage chunks
- `check_compress_service.py` – Vérification service compress
- `check_sessions.py` – Vérification sessions

### Scripts verify_*.py (4)

**Supabase** :
- `verify_lot1_deployment.py` – Vérification déploiement lot1
- `verify_mp4_d4a.py` – Vérification MP4 D.4A
- `verify_feed_visibility.py` – Vérification visibilité feed
- `verify_transcode_deploy.py` – Vérification déploiement transcode

### Scripts audit_*.py (31)

**Supabase** :
- `audit_tables_d4a.py` – Audit tables D.4A
- `audit_rpcs_d4a.py` – Audit RPCs D.4A
- `audit_storage_buckets.py` – Audit buckets Storage
- `audit_storage_d4a.py` – Audit Storage D.4A
- `audit_edge_functions.py` – Audit Edge Functions

**Kamatera** :
- `audit_kamatera_d4a.py` – Audit Kamatera D.4A
- `audit_kamatera_full.py` – Audit Kamatera complet
- `audit_kamatera_video.py` – Audit Kamatera vidéo
- `audit_render_jobs_d4a.py` – Audit render jobs D.4A

**Autres** :
- `audit_bobodo_phase2.py` – Audit Bobodo phase 2
- `audit_bobodo_reality.py` – Audit Bobodo réalité
- `audit_challenge_pipeline.py` – Audit pipeline Challenge
- `audit_flutter_ws_url.py` – Audit Flutter WebSocket URL
- `audit_k_buckets.py` – Audit buckets Kamatera
- `audit_l_rpc_all_schemas.py` – Audit RPC tous schémas
- `audit_missions_server.py` – Audit serveur missions
- `audit_option_e.py` – Audit option E
- `audit_protocol_current.py` – Audit protocole actuel
- `audit_reality_d4.py` – Audit réalité D.4
- `audit_resource_monitor.py` – Audit monitoring ressources
- `audit_resource_simple.py` – Audit monitoring simple
- `audit_storyboards_detailed.py` – Audit storyboards détaillé
- `audit_storyboards_from_results.py` – Audit storyboards depuis résultats
- `audit_stt_full.py` – Audit STT complet
- `audit_stt_isolated.py` – Audit STT isolé
- `audit_stt_precise.py` – Audit STT précis
- `audit_stt_single.py` – Audit STT simple
- `audit_ws_discovery.py` – Audit WebSocket découverte
- `audit_ws_read_files.py` – Audit WebSocket lecture fichiers
- `audit_ws_real_test.py` – Audit WebSocket test réel
- `audit_ws_traffic.py` – Audit WebSocket trafic

### Scripts rpc_*.py (0)

**Résultat** : Aucun script rpc_*.py trouvé

### Scripts admin_*.py (0)

**Résultat** : Aucun script admin_*.py trouvé

### Sous-dossiers

**sql_changes/** :
- `change_20260620_upload_sessions_table.sql` – Table upload_sessions
- `change_20260622_feed_instant_visibility.sql` – Feed instant visibility
- `change_20260623_whiteboard_renders_structure.sql` – Structure whiteboard_renders (SELECT)
- `change_20260623_whiteboard_worker_rpcs.sql` – RPCs worker whiteboard
- `change_20260624_whiteboard_content_agent.sql` – Content Agent
- `change_20260624_whiteboard_editor_rpcs.sql` – RPCs editor
- `change_20260624_whiteboard_tables_buckets.sql` – Tables et buckets whiteboard
- `manual_upload_sessions_function_trigger.sql` – Trigger upload_sessions

**scripts/** :
- `deploy_piper_server.ps1` – Déploiement Piper Server (PowerShell)

**utils/** : N'existe pas

**helpers/** : N'existe pas

---

## MISSION 2 – SCRIPTS PAR ACTION

### A. Créer une table

**Scripts** :
- `deploy_whiteboard_tables_buckets.py` – Création tables whiteboard via admin_execute_sql
- `deploy_upload_sessions_via_rpc.py` – Création table upload_sessions via admin_execute_sql
- `deploy_whiteboard_reconstruction_lot1.py` – Création tables whiteboard via admin_execute_sql
- `deploy_upload_sessions_table.py` – Création table upload_sessions via Supabase client (exec_sql)

### B. Modifier une table

**Scripts** :
- `phase_c3e_execute_c1.py` – ALTER TABLE DROP/ADD CONSTRAINT via execute_ddl
- `phase_c3e_execute_c2.py` – ALTER TABLE ADD COLUMN via execute_ddl
- `phase_c3e_execute_c3.py` – ALTER TABLE ADD COLUMN via execute_ddl

### C. Supprimer une table

**Scripts** :
- Aucun script spécifique trouvé pour la suppression de tables

### D. Créer une RPC

**Scripts** :
- `deploy_whiteboard_editor_rpcs.py` – Création RPCs editor via admin_execute_sql
- `deploy_whiteboard_reconstruction_lot1.py` – Création RPCs worker/editor via admin_execute_sql
- `deploy_function_trigger_via_rpc.py` – Création fonction/trigger via admin_execute_sql

### E. Modifier une RPC

**Scripts** :
- Aucun script spécifique trouvé pour la modification de RPCs

### F. Déployer une migration

**Scripts** :
- Aucun script n'utilise Supabase CLI (supabase migration, supabase db push, supabase deploy)

### G. Exécuter du DDL

**Scripts** :
- `phase_c3e_execute_c1.py` – ALTER TABLE via execute_ddl
- `phase_c3e_execute_c2.py` – ALTER TABLE via execute_ddl
- `phase_c3e_execute_c3.py` – ALTER TABLE via execute_ddl

### H. Exécuter du SQL

**Scripts** :
- Tous les scripts utilisant admin_execute_sql (200+ fichiers)
- `diagnostic_admin_execute_sql.py` – Diagnostic admin_execute_sql
- `check_admin_rpcs.py` – Vérification RPCs admin

### I. Vérifier un déploiement

**Scripts** :
- `verify_lot1_deployment.py` – Vérification déploiement lot1
- `check_admin_rpcs.py` – Vérification RPCs admin
- `check_app_tables.py` – Vérification tables app
- `check_existing_whiteboard_tables.py` – Vérification tables whiteboard existantes

### J. Interroger Kamatera

**Scripts** :
- `check_kamatera.py` – Vérification Kamatera
- `check_kamatera_services.py` – Vérification services Kamatera
- `deploy_kamatera.py` – Déploiement SSH sur Kamatera

---

## MISSION 3 – RPC D'ADMINISTRATION RÉELLES

### RPC 1 : admin_execute_sql

**Nom** : `admin_execute_sql`

**Schéma** : app

**Endpoint** : `/rest/v1/rpc/admin_execute_sql`

**Paramètre** : `{"p_sql": "..."}`

**Permissions** : service_role

**Rôle exact** : Exécution de SQL arbitraire (SELECT, DDL, DML)

**Utilisation** : 200+ scripts

**Exemple** :
```python
url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "Content-Type": "application/json"
}
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
```

**Problème identifié** : Réponses HTTP trompeuses (ok: true mais tables non créées)

### RPC 2 : execute_ddl

**Nom** : `execute_ddl`

**Schéma** : app

**Endpoint** : `/rest/v1/rpc/execute_ddl`

**Paramètre** : `{"ddl_query": "..."}`

**Permissions** : service_role

**Rôle exact** : Exécution de DDL (CREATE TABLE, ALTER TABLE, DROP, etc.)

**Utilisation** : 3 scripts (phase_c3e_execute_c1/c2/c3.py)

**Exemple** :
```python
admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/execute_ddl"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "Content-Type": "application/json"
}
resp = requests.post(admin_url, headers=headers, json={"ddl_query": ddl}, timeout=30)
```

**Statut** : Fonctionne correctement (selon mémoire système)

### RPC 3 : exec_sql

**Nom** : `exec_sql`

**Schéma** : Non spécifié

**Endpoint** : Non spécifié

**Paramètre** : `{"sql": "..."}`

**Permissions** : Non spécifié

**Rôle exact** : Exécution de SQL (SELECT uniquement, refuse DDL)

**Utilisation** : 1 script (deploy_upload_sessions_table.py)

**Statut** : Probablement non fonctionnel (selon mémoire système)

---

## MISSION 4 – CARTOGRAPHIE SCRIPT → RPC → ACTION

### Cartographie admin_execute_sql

```
deploy_whiteboard_tables_buckets.py
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
deploy_whiteboard_reconstruction_lot1.py
↓
admin_execute_sql (RPC)
↓
Supabase (/rest/v1/rpc/admin_execute_sql)
↓
CREATE TABLE app.whiteboard_projects
CREATE TABLE app.whiteboard_renders
CREATE OR REPLACE FUNCTION public.whiteboard_fetch_queued_jobs
CREATE OR REPLACE FUNCTION public.whiteboard_mark_processing
CREATE OR REPLACE FUNCTION public.whiteboard_mark_done
CREATE OR REPLACE FUNCTION public.whiteboard_mark_failed
CREATE OR REPLACE FUNCTION public.whiteboard_get_any_student_id
```

```
deploy_upload_sessions_via_rpc.py
↓
admin_execute_sql (RPC)
↓
Supabase (/rest/v1/rpc/admin_execute_sql)
↓
CREATE TABLE app.upload_sessions
CREATE INDEX idx_upload_sessions_*
ALTER TABLE app.upload_sessions ENABLE ROW LEVEL SECURITY
CREATE POLICY "Users can view own upload sessions"
CREATE POLICY "Users can insert own upload sessions"
CREATE POLICY "Users can update own upload sessions"
CREATE POLICY "Service role full access to upload_sessions"
CREATE OR REPLACE FUNCTION app.cleanup_expired_upload_sessions()
CREATE TRIGGER trigger_cleanup_expired_upload_sessions
```

```
deploy_function_trigger_via_rpc.py
↓
admin_execute_sql (RPC)
↓
Supabase (/rest/v1/rpc/admin_execute_sql)
↓
DO $$ ... $$ (création fonction/trigger)
```

```
check_admin_rpcs.py
↓
admin_execute_sql (RPC)
↓
Supabase (/rest/v1/rpc/admin_execute_sql)
↓
SELECT proname, pg_get_function_identity_arguments(oid) FROM pg_proc
```

```
diagnostic_admin_execute_sql.py
↓
admin_execute_sql (RPC)
↓
Supabase (/rest/v1/rpc/admin_execute_sql)
↓
SELECT 1 as test
SELECT current_user, current_database(), current_schema()
CREATE TEMP TABLE diagnostic_test
CREATE TABLE app.diagnostic_test
DROP TABLE IF EXISTS app.diagnostic_test
```

### Cartographie execute_ddl

```
phase_c3e_execute_c1.py
↓
execute_ddl (RPC)
↓
Supabase (/rest/v1/rpc/execute_ddl)
↓
ALTER TABLE app.whiteboard_renders DROP CONSTRAINT
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

### Cartographie exec_sql

```
deploy_upload_sessions_table.py
↓
exec_sql (RPC)
↓
Supabase (via Supabase client)
↓
CREATE TABLE app.upload_sessions
```

---

## MISSION 5 – CHEMIN OFFICIEL DE DÉPLOIEMENT ACADEMIA

### Pour déployer une nouvelle table Whiteboard aujourd'hui

**Script recommandé** : `deploy_upload_sessions_via_rpc.py` (modèle)

**Procédure** :
1. Créer un fichier SQL dans `.windsurf/sql_changes/`
2. Créer un script Python basé sur `deploy_upload_sessions_via_rpc.py`
3. Utiliser `admin_execute_sql` avec le paramètre `p_sql`
4. Exécuter le script
5. Vérifier avec `check_admin_rpcs.py` ou `check_app_tables.py`

**Exemple** :
```python
import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "Content-Type": "application/json"
}

with open('sql_changes/change_YYYYMMDD_new_table.sql', 'r') as f:
    sql = f.read()

resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print("STATUS:", resp.status_code)
print("BODY:", resp.text)
```

### Pour créer une nouvelle RPC aujourd'hui

**Script recommandé** : `deploy_whiteboard_editor_rpcs.py` (modèle)

**Procédure** :
1. Créer un fichier SQL dans `.windsurf/sql_changes/`
2. Créer un script Python basé sur `deploy_whiteboard_editor_rpcs.py`
3. Utiliser `admin_execute_sql` avec le paramètre `p_sql`
4. Exécuter le script
5. Vérifier avec `check_admin_rpcs.py`

### Pour modifier une table aujourd'hui

**Script recommandé** : `phase_c3e_execute_c1.py` (modèle)

**Procédure** :
1. Créer un script Python basé sur `phase_c3e_execute_c1.py`
2. Utiliser `execute_ddl` avec le paramètre `ddl_query`
3. Exécuter le script
4. Vérifier avec `check_app_tables.py`

**Exemple** :
```python
import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/execute_ddl"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "Content-Type": "application/json"
}

def execute_ddl(ddl):
    resp = requests.post(admin_url, headers=headers, json={"ddl_query": ddl}, timeout=30)
    return resp.json()

ddl = "ALTER TABLE app.whiteboard_renders ADD COLUMN new_column TEXT"
result = execute_ddl(ddl)
print(f"Résultat : {result}")
```

### Pour vérifier son existence demain

**Script recommandé** : `check_admin_rpcs.py` (pour RPCs) ou `check_app_tables.py` (pour tables)

**Procédure** :
1. Exécuter `check_admin_rpcs.py` pour vérifier les RPCs
2. Exécuter `check_app_tables.py` pour vérifier les tables
3. Exécuter `check_existing_whiteboard_tables.py` pour vérifier les tables whiteboard

---

## MATRICE DES PERMISSIONS

### RPC admin_execute_sql

**Permissions** : service_role

**Actions autorisées** :
- SELECT
- INSERT
- UPDATE
- DELETE
- CREATE TABLE
- ALTER TABLE
- DROP TABLE
- CREATE FUNCTION
- ALTER FUNCTION
- DROP FUNCTION
- CREATE TRIGGER
- DROP TRIGGER
- CREATE INDEX
- DROP INDEX

**Actions non autorisées** :
- Aucune (accès complet)

### RPC execute_ddl

**Permissions** : service_role

**Actions autorisées** :
- CREATE TABLE
- ALTER TABLE
- DROP TABLE
- CREATE INDEX
- DROP INDEX
- CREATE FUNCTION
- ALTER FUNCTION
- DROP FUNCTION

**Actions non autorisées** :
- SELECT (probablement)
- INSERT (probablement)
- UPDATE (probablement)
- DELETE (probablement)

### RPC exec_sql

**Permissions** : Non spécifié

**Actions autorisées** :
- SELECT (probablement)

**Actions non autorisées** :
- DDL (selon mémoire système)

---

## RECOMMANDATIONS D'UTILISATION

### Pour les créations de tables

**Recommandation** : Utiliser `execute_ddl` au lieu de `admin_execute_sql`

**Raison** : `execute_ddl` fonctionne correctement (selon mémoire système), alors que `admin_execute_sql` retourne des réponses HTTP trompeuses.

### Pour les créations de RPCs

**Recommandation** : Utiliser `admin_execute_sql` avec vérification manuelle

**Raison** : Aucune alternative identifiée pour les créations de RPCs. Vérifier manuellement via Supabase Dashboard après déploiement.

### Pour les modifications de tables

**Recommandation** : Utiliser `execute_ddl`

**Raison** : `execute_ddl` fonctionne correctement pour les ALTER TABLE.

### Pour les vérifications

**Recommandation** : Utiliser `check_admin_rpcs.py` et `check_app_tables.py`

**Raison** : Ces scripts interrogent directement Supabase et fournissent des résultats fiables.

---

## CRITÈRES DE SUCCÈS

### Réponses aux questions

**Quel script déploie réellement dans Supabase ?**
- `deploy_upload_sessions_via_rpc.py` pour les tables (modèle recommandé)
- `deploy_whiteboard_editor_rpcs.py` pour les RPCs (modèle recommandé)
- `phase_c3e_execute_c1.py` pour les modifications de tables (modèle recommandé)

**Quelle RPC admin exécute réellement le DDL ?**
- `execute_ddl` – Fonctionne correctement (selon mémoire système)

**Quelle RPC admin exécute réellement le SQL ?**
- `admin_execute_sql` – Réponses HTTP trompeuses (ok: true mais tables non créées)

**Quel script vérifie réellement un déploiement ?**
- `check_admin_rpcs.py` pour les RPCs
- `check_app_tables.py` pour les tables
- `verify_lot1_deployment.py` pour les déploiements complets

**Quel est le chemin officiel d'administration Supabase dans Academia ?**
- **Création de tables** : `deploy_upload_sessions_via_rpc.py` → `admin_execute_sql` → Supabase
- **Création de RPCs** : `deploy_whiteboard_editor_rpcs.py` → `admin_execute_sql` → Supabase
- **Modification de tables** : `phase_c3e_execute_c1.py` → `execute_ddl` → Supabase
- **Vérification** : `check_admin_rpcs.py` / `check_app_tables.py` → `admin_execute_sql` → Supabase

---

## CONCLUSION FINALE

### Outils d'administration identifiés

- **25 scripts deploy_*.py** – Déploiement
- **40 scripts check_*.py** – Vérification
- **4 scripts verify_*.py** – Vérification avancée
- **31 scripts audit_*.py** – Audit
- **3 scripts contenant execute_ddl** – Exécution DDL
- **200+ scripts contenant admin_execute_sql** – Exécution SQL

### RPC d'administration identifiées

- **admin_execute_sql** – Exécution SQL arbitraire (réponses trompeuses)
- **execute_ddl** – Exécution DDL (fonctionne correctement)
- **exec_sql** – Exécution SQL SELECT uniquement (probablement non fonctionnel)

### Chemin officiel de déploiement

**Historique** : `admin_execute_sql` (200+ scripts)

**Recommandé** : `execute_ddl` pour les DDL, `admin_execute_sql` pour les RPCs avec vérification manuelle

### Recommandation finale

1. Utiliser `execute_ddl` pour toutes les opérations DDL (CREATE TABLE, ALTER TABLE, etc.)
2. Utiliser `admin_execute_sql` pour les créations de RPCs avec vérification manuelle via Supabase Dashboard
3. Vérifier systématiquement les déploiements avec `check_admin_rpcs.py` et `check_app_tables.py`
4. Ne plus utiliser `admin_execute_sql` pour les créations de tables (réponses trompeuses)

---

**Fin de PHASE D.5G – ADMIN TOOLCHAIN MAPPING**
