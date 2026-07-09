# PHASE D.5H – DEPLOYMENT PLAN

**Date** : 24 Juin 2026  
**Phase** : D.5H – Whiteboard Production Deployment  
**Mode** : PRODUCTION

---

## OBJECTIF

Faire passer le Smart Whiteboard de C = Codé mais non déployé à A = Déployé et vérifié.

---

## RÉFÉRENCES OBLIGATOIRES

- `docs/ACADEMIA_MASTER_INDEX.md` – Index central
- `docs/ACADEMIA_TRUTH_MATRIX.md` – Matrice de vérité actuelle
- `docs/ACADEMIA_CHANGELOG.md` – Changelog
- `docs/ACADEMIA_DEPLOYMENT_STATUS.md` – Statut des déploiements
- `docs/PHASE_D5G_ADMIN_TOOLCHAIN_MAPPING.md` – Cartographie des outils d'administration

---

## ÉTAT ACTUEL (MATRICE DE VÉRITÉ)

### Tables Supabase
- app.whiteboard_projects : E (information_schema retourne 0 résultat)
- app.whiteboard_renders : E (information_schema retourne 0 résultat)
- app.whiteboard_ai_generations : Non listé

### RPCs Supabase
- app.whiteboard_fetch_queued_jobs : E
- app.whiteboard_mark_processing : E
- app.whiteboard_mark_done : E
- app.whiteboard_mark_failed : E
- app.whiteboard_get_any_student_id : E
- app.whiteboard_get_project : E
- app.whiteboard_update_project : E
- app.whiteboard_list_projects : E
- app.whiteboard_delete_project : E

### Storage Supabase
- whiteboard-renders : A (Bucket existe via Supabase Dashboard)
- whiteboard-narrations : A (Bucket existe via Supabase Dashboard)

### Edge Functions
- whiteboard-generate-storyboard : A (Déployée via Supabase CLI)

### Kamatera
- /opt/whiteboard-worker/whiteboard_render_worker.py : A (Fichier présent)
- /opt/whiteboard-worker/whiteboard_png_renderer.py : A (Fichier présent)
- /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py : A (Fichier présent)
- /opt/whiteboard-worker/whiteboard_upload_renderer.py : A (Fichier présent)
- Worker process : E (ps aux retourne 0 processus)
- Worker service : E (systemctl retourne 0 service)

### Pipeline
- Render job : E (Aucun job dans whiteboard_renders)
- PNG généré : E (Aucun PNG généré)
- MP4 généré : E (Aucun MP4 généré)
- URL Storage : E (Aucune URL disponible)

---

## CHEMIN DE DÉPLOIEMENT OFFICIEL (SELON PHASE_D5G)

### Pour créer une table
**Script recommandé** : `deploy_upload_sessions_via_rpc.py` (modèle)
**RPC** : `admin_execute_sql`
**Problème** : Réponses HTTP trompeuses (ok: true mais tables non créées)

**Alternative recommandée** : `execute_ddl`
**Raison** : Fonctionne correctement (selon mémoire système)

### Pour créer une RPC
**Script recommandé** : `deploy_whiteboard_editor_rpcs.py` (modèle)
**RPC** : `admin_execute_sql`
**Problème** : Réponses HTTP trompeuses (ok: true mais RPCs non créées)

**Alternative** : Vérification manuelle via Supabase Dashboard

### Pour modifier une table
**Script recommandé** : `phase_c3e_execute_c1.py` (modèle)
**RPC** : `execute_ddl`
**Statut** : Fonctionne correctement

### Pour vérifier
**Scripts recommandés** :
- `check_admin_rpcs.py` pour les RPCs
- `check_app_tables.py` pour les tables
- `check_existing_whiteboard_tables.py` pour les tables whiteboard

---

## PLAN DE DÉPLOIEMENT

### MISSION 1 – Déployer les tables Whiteboard

**Tables à déployer** :
1. app.whiteboard_projects
2. app.whiteboard_renders
3. app.whiteboard_ai_generations

**Script modèle** : `deploy_upload_sessions_via_rpc.py`

**RPC** : `execute_ddl` (recommandé) ou `admin_execute_sql` (historique)

**Fichiers SQL existants** :
- `.windsurf/sql_changes/change_20260624_whiteboard_tables_buckets.sql` – Tables whiteboard_projects et whiteboard_renders
- `.windsurf/sql_changes/change_20260624_whiteboard_content_agent.sql` – Table whiteboard_ai_generations

**Procédure** :
1. Créer un script Python basé sur `deploy_upload_sessions_via_rpc.py`
2. Utiliser `execute_ddl` avec le paramètre `ddl_query` pour chaque instruction DDL
3. Exécuter le script
4. Vérifier avec `check_app_tables.py`

### MISSION 2 – Preuve directe tables

**Pour chaque table** :
- Nom
- Schéma
- Colonnes
- Date de vérification

**Script de vérification** : `check_app_tables.py`

**Classification** : A ou B ou C

### MISSION 3 – Déployer les RPCs Whiteboard

**RPCs à déployer** :
1. public.whiteboard_fetch_queued_jobs
2. public.whiteboard_mark_processing
3. public.whiteboard_mark_done
4. public.whiteboard_mark_failed
5. public.whiteboard_get_any_student_id
6. app.whiteboard_get_project
7. app.whiteboard_update_project
8. app.whiteboard_list_projects
9. app.whiteboard_delete_project

**Script modèle** : `deploy_whiteboard_editor_rpcs.py`

**RPC** : `admin_execute_sql`

**Fichiers SQL existants** :
- `.windsurf/sql_changes/change_20260623_whiteboard_worker_rpcs.sql` – RPCs worker
- `.windsurf/sql_changes/change_20260624_whiteboard_editor_rpcs.sql` – RPCs editor

**Procédure** :
1. Créer un script Python basé sur `deploy_whiteboard_editor_rpcs.py`
2. Utiliser `admin_execute_sql` avec le paramètre `p_sql`
3. Exécuter le script
4. Vérifier manuellement via Supabase Dashboard
5. Vérifier avec `check_admin_rpcs.py`

### MISSION 4 – Preuve directe RPCs

**Pour chaque RPC** :
- Nom
- Schéma
- Paramètres
- Résultat de vérification

**Script de vérification** : `check_admin_rpcs.py`

**Classification** : A ou B ou C

### MISSION 5 – Validation Edge Function

**Edge Function** : whiteboard-generate-storyboard

**Critères** :
- Déployée
- Accessible
- Répond
- Génère un storyboard valide

**Procédure** :
1. Tester l'Edge Function via Supabase CLI
2. Vérifier la réponse
3. Valider le format du storyboard

**Classification** : A ou B ou C

### MISSION 6 – Validation Kamatera

**Composants** :
- /opt/whiteboard-worker/whiteboard_render_worker.py
- /opt/whiteboard-worker/whiteboard_png_renderer.py
- /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py
- /opt/whiteboard-worker/whiteboard_upload_renderer.py

**Critères** :
- Fichiers toujours présents
- Dépendances présentes
- Worker démarre

**Procédure** :
1. Vérifier la présence des fichiers
2. Vérifier les dépendances Python
3. Démarrer le worker manuellement
4. Vérifier les logs

**Classification** : A ou B ou C

### MISSION 7 – Test pipeline réel

**Flux** :
1. Créer un storyboard réel
2. Créer un render job réel
3. Worker réel
4. PNG généré
5. FFmpeg
6. MP4 généré
7. Storage

**Preuves requises** :
- Logs
- Statut job
- URL Storage
- Taille MP4
- HTTP 200

**Procédure** :
1. Appeler l'Edge Function whiteboard-generate-storyboard
2. Insérer un render job dans app.whiteboard_renders
3. Démarrer le worker Kamatera
4. Surveiller les logs
5. Vérifier le PNG généré
6. Vérifier le MP4 généré
7. Vérifier l'URL Storage

**Classification** : A ou B ou C

### MISSION 8 – Mise à jour de la matrice de vérité

**Document** : `docs/ACADEMIA_TRUTH_MATRIX.md`

**Mise à jour** :
- Tables Whiteboard : A ou B ou C
- RPCs Whiteboard : A ou B ou C
- Edge Function : A ou B ou C
- Kamatera : A ou B ou C
- Pipeline : A ou B ou C

### MISSION 9 – Document de clôture

**Document** : `docs/PHASE_D5H_PRODUCTION_DEPLOYMENT_REPORT.md`

**Contenu** :
1. Composants déployés
2. Composants vérifiés
3. Preuves directes
4. Classification A/B/C/D/E
5. Écarts restants
6. Décision GO / NO-GO

---

## CRITÈRES DE SUCCÈS

Le Smart Whiteboard sera considéré comme déployé lorsque les éléments suivants seront classés A :

- ✅ Tables Whiteboard (whiteboard_projects, whiteboard_renders, whiteboard_ai_generations)
- ✅ RPCs Whiteboard (9 RPCs)
- ✅ Edge Function (whiteboard-generate-storyboard)
- ✅ Worker Kamatera (fichiers + processus)
- ✅ Renderer (PNG + FFmpeg)
- ✅ Render Job (création + exécution)
- ✅ MP4 généré (taille + format)
- ✅ URL Storage accessible (HTTP 200)

Tant que l'un de ces éléments n'est pas classé A avec preuve directe, le Smart Whiteboard reste NON VALIDÉ en production.

---

## SCRIPTS À UTILISER

### Déploiement
- `deploy_upload_sessions_via_rpc.py` – Modèle pour les tables
- `deploy_whiteboard_editor_rpcs.py` – Modèle pour les RPCs
- `phase_c3e_execute_c1.py` – Modèle pour les modifications

### Vérification
- `check_admin_rpcs.py` – Vérification RPCs
- `check_app_tables.py` – Vérification tables
- `check_existing_whiteboard_tables.py` – Vérification tables whiteboard

### Validation
- `check_kamatera.py` – Vérification Kamatera
- `check_kamatera_services.py` – Vérification services Kamatera

---

## FICHIERS SQL À RÉUTILISER

- `.windsurf/sql_changes/change_20260624_whiteboard_tables_buckets.sql` – Tables whiteboard_projects et whiteboard_renders
- `.windsurf/sql_changes/change_20260624_whiteboard_content_agent.sql` – Table whiteboard_ai_generations
- `.windsurf/sql_changes/change_20260623_whiteboard_worker_rpcs.sql` – RPCs worker
- `.windsurf/sql_changes/change_20260624_whiteboard_editor_rpcs.sql` – RPCs editor

---

## RPC D'ADMINISTRATION À UTILISER

### execute_ddl (recommandé pour DDL)
- Endpoint : `/rest/v1/rpc/execute_ddl`
- Paramètre : `{"ddl_query": "..."}`
- Statut : Fonctionne correctement

### admin_execute_sql (historique pour RPCs)
- Endpoint : `/rest/v1/rpc/admin_execute_sql`
- Paramètre : `{"p_sql": "..."}`
- Statut : Réponses HTTP trompeuses

---

**Fin de PHASE_D5H_DEPLOYMENT_PLAN.md**
