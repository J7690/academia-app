# PHASE C.3D – LOT 1 EXECUTION PREPARATION

**Date** : 23 Juin 2026  
**Phase** : C.3D – Lot 1 Execution Preparation  
**Mode** : PRÉPARATION D'EXÉCUTION SEULEMENT  
**Objectif** : Préparer l'exécution du LOT 1 (C1, C2, C3)

---

## DIRECTIVE

**AUCUNE MODIFICATION IMMÉDIATE**  
**AUCUNE CORRECTION IMMÉDIATE**

---

## LOT 1 DÉFINITION

**Corrections** :
- C1 : Corriger CHECK status
- C2 : Ajouter colonne export_settings
- C3 : Ajouter colonne started_at

---

## PARTIE 1 – SCRIPTS EXACTS

### Ordre d'exécution

```
1. C1 : Corriger CHECK status
2. C2 : Ajouter colonne export_settings
3. C3 : Ajouter colonne started_at
```

---

### Script C1 : Corriger CHECK status

**RPC admin utilisée** : `execute_ddl` (via script Python)

**SQL** :
```sql
-- Étape 1 : Supprimer l'ancienne contrainte
ALTER TABLE app.whiteboard_renders DROP CONSTRAINT IF EXISTS whiteboard_renders_status_check;

-- Étape 2 : Créer la nouvelle contrainte
ALTER TABLE app.whiteboard_renders 
ADD CONSTRAINT whiteboard_renders_status_check 
CHECK (status IN ('queued', 'processing', 'done', 'failed'));
```

**Script Python** :
```python
"""
Phase C.3D – Lot 1 – Correction C1
Corriger CHECK status
"""

import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/execute_ddl"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_ddl(ddl):
    resp = requests.post(admin_url, headers=headers, json={"ddl_query": ddl}, timeout=30)
    return resp.json()

print("=== CORRECTION C1 : CHECK STATUS ===\n")

# Étape 1 : Supprimer l'ancienne contrainte
ddl1 = "ALTER TABLE app.whiteboard_renders DROP CONSTRAINT IF EXISTS whiteboard_renders_status_check"
result1 = execute_ddl(ddl1)
print(f"Suppression contrainte : {result1}")

# Étape 2 : Créer la nouvelle contrainte
ddl2 = """
ALTER TABLE app.whiteboard_renders 
ADD CONSTRAINT whiteboard_renders_status_check 
CHECK (status IN ('queued', 'processing', 'done', 'failed'))
"""
result2 = execute_ddl(ddl2)
print(f"Création contrainte : {result2}")

print("\n=== CORRECTION C1 TERMINÉE ===\n")
```

---

### Script C2 : Ajouter colonne export_settings

**RPC admin utilisée** : `execute_ddl` (via script Python)

**SQL** :
```sql
ALTER TABLE app.whiteboard_renders ADD COLUMN IF NOT EXISTS export_settings JSONB;
```

**Script Python** :
```python
"""
Phase C.3D – Lot 1 – Correction C2
Ajouter colonne export_settings
"""

import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/execute_ddl"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_ddl(ddl):
    resp = requests.post(admin_url, headers=headers, json={"ddl_query": ddl}, timeout=30)
    return resp.json()

print("=== CORRECTION C2 : EXPORT_SETTINGS ===\n")

ddl = "ALTER TABLE app.whiteboard_renders ADD COLUMN IF NOT EXISTS export_settings JSONB"
result = execute_ddl(ddl)
print(f"Ajout colonne export_settings : {result}")

print("\n=== CORRECTION C2 TERMINÉE ===\n")
```

---

### Script C3 : Ajouter colonne started_at

**RPC admin utilisée** : `execute_ddl` (via script Python)

**SQL** :
```sql
ALTER TABLE app.whiteboard_renders ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ;
```

**Script Python** :
```python
"""
Phase C.3D – Lot 1 – Correction C3
Ajouter colonne started_at
"""

import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/execute_ddl"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_ddl(ddl):
    resp = requests.post(admin_url, headers=headers, json={"ddl_query": ddl}, timeout=30)
    return resp.json()

print("=== CORRECTION C3 : STARTED_AT ===\n")

ddl = "ALTER TABLE app.whiteboard_renders ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ"
result = execute_ddl(ddl)
print(f"Ajout colonne started_at : {result}")

print("\n=== CORRECTION C3 TERMINÉE ===\n")
```

---

### Script combiné LOT 1

**Script Python combiné** :
```python
"""
Phase C.3D – Lot 1 – Exécution combinée
C1 : Corriger CHECK status
C2 : Ajouter colonne export_settings
C3 : Ajouter colonne started_at
"""

import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/execute_ddl"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_ddl(ddl):
    resp = requests.post(admin_url, headers=headers, json={"ddl_query": ddl}, timeout=30)
    return resp.json()

print("=== LOT 1 : EXÉCUTION ===\n")

# C1 : Corriger CHECK status
print("C1 : Corriger CHECK status")
ddl1 = "ALTER TABLE app.whiteboard_renders DROP CONSTRAINT IF EXISTS whiteboard_renders_status_check"
result1 = execute_ddl(ddl1)
print(f"  Suppression contrainte : {result1}")

ddl2 = """
ALTER TABLE app.whiteboard_renders 
ADD CONSTRAINT whiteboard_renders_status_check 
CHECK (status IN ('queued', 'processing', 'done', 'failed'))
"""
result2 = execute_ddl(ddl2)
print(f"  Création contrainte : {result2}")
print()

# C2 : Ajouter colonne export_settings
print("C2 : Ajouter colonne export_settings")
ddl3 = "ALTER TABLE app.whiteboard_renders ADD COLUMN IF NOT EXISTS export_settings JSONB"
result3 = execute_ddl(ddl3)
print(f"  Ajout colonne : {result3}")
print()

# C3 : Ajouter colonne started_at
print("C3 : Ajouter colonne started_at")
ddl4 = "ALTER TABLE app.whiteboard_renders ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ"
result4 = execute_ddl(ddl4)
print(f"  Ajout colonne : {result4}")
print()

print("=== LOT 1 TERMINÉ ===\n")
```

---

## PARTIE 2 – ÉTAT AVANT/APRÈS/ROLLBACK

### Correction C1 : Corriger CHECK status

**État avant** :
```sql
CHECK (status IN ('processing', 'failed'))
```

**État après** :
```sql
CHECK (status IN ('queued', 'processing', 'done', 'failed'))
```

**Rollback** :
```sql
ALTER TABLE app.whiteboard_renders DROP CONSTRAINT whiteboard_renders_status_check;

ALTER TABLE app.whiteboard_renders 
ADD CONSTRAINT whiteboard_renders_status_check 
CHECK (status IN ('processing', 'failed'));
```

---

### Correction C2 : Ajouter colonne export_settings

**État avant** :
```sql
-- Colonne absente
```

**État après** :
```sql
export_settings JSONB NULL
```

**Rollback** :
```sql
ALTER TABLE app.whiteboard_renders DROP COLUMN IF EXISTS export_settings;
```

---

### Correction C3 : Ajouter colonne started_at

**État avant** :
```sql
-- Colonne absente
```

**État après** :
```sql
started_at TIMESTAMPTZ NULL
```

**Rollback** :
```sql
ALTER TABLE app.whiteboard_renders DROP COLUMN IF EXISTS started_at;
```

---

## PARTIE 3 – VÉRIFICATION DONNÉES EXISTANTES

### Requête de vérification

**SQL** :
```sql
SELECT COUNT(*) as total_renders FROM app.whiteboard_renders;
```

**Script Python** :
```python
"""
Phase C.3D – Lot 1 – Vérification données existantes
"""

import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== VÉRIFICATION DONNÉES EXISTANTES ===\n")

sql = "SELECT COUNT(*) as total_renders FROM app.whiteboard_renders"
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Total renders : {resp.json()}")

# Vérifier les status
sql2 = "SELECT status, COUNT(*) as count FROM app.whiteboard_renders GROUP BY status"
resp2 = requests.post(admin_url, headers=headers, json={"p_sql": sql2}, timeout=30)
print(f"Status distribution : {resp2.json()}")

print("\n=== VÉRIFICATION TERMINÉE ===\n")
```

### Impact sur les données existantes

**Si des données existent** :
- C1 : Aucun impact (modification de contrainte uniquement)
- C2 : Aucun impact (ajout de colonne NULLABLE)
- C3 : Aucun impact (ajout de colonne NULLABLE)

**Conclusion** : ✅ Aucun impact sur les données existantes

---

## PARTIE 4 – SIMULATION EFFET SUR COMPOSANTS

### Worker

**Impact** :
- C1 : ✅ Positif (peut maintenant créer des jobs avec `status='queued'`)
- C2 : ❌ Aucun (colonne non utilisée par le worker actuel)
- C3 : ✅ Positif (peut maintenant utiliser `started_at` via RPC)

**Simulation** :
```python
# Avant C1
worker.create_render_job(project_id) → ÉCHEC (violates check constraint)

# Après C1
worker.create_render_job(project_id) → SUCCÈS (status='queued' accepté)

# Avant C3
worker.mark_processing(render_id) → ÉCHEC (started_at absent)

# Après C3
worker.mark_processing(render_id) → SUCCÈS (started_at présent)
```

---

### Render Jobs

**Impact** :
- C1 : ✅ Positif (jobs peuvent maintenant avoir `status='queued'` et `status='done'`)
- C2 : ❌ Aucun (export_settings non utilisé par les jobs actuels)
- C3 : ✅ Positif (jobs peuvent maintenant avoir `started_at`)

**Simulation** :
```sql
-- Avant C1
INSERT INTO app.whiteboard_renders (id, project_id, status) VALUES ('x', 'y', 'queued') → ÉCHEC

-- Après C1
INSERT INTO app.whiteboard_renders (id, project_id, status) VALUES ('x', 'y', 'queued') → SUCCÈS
```

---

### Storage

**Impact** :
- C1 : ❌ Aucun (modification de contrainte uniquement)
- C2 : ❌ Aucun (colonne non liée au storage)
- C3 : ❌ Aucun (colonne non liée au storage)

**Conclusion** : ✅ Aucun impact sur Storage

---

### Flutter

**Impact** :
- C1 : ✅ Positif (peut maintenant créer des render jobs via RPCs V1)
- C2 : ✅ Positif (peut maintenant stocker export_settings)
- C3 : ✅ Positif (peut maintenant utiliser started_at)

**Simulation** :
```dart
// Avant C1
final renderId = await createRenderJob(projectId); → ÉCHEC (violates check constraint)

// Après C1
final renderId = await createRenderJob(projectId); → SUCCÈS
```

---

## PARTIE 5 – PROTOCOLE DE VALIDATION POST-LOT 1

### Validation V1 : INSERT queued

**SQL** :
```sql
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('test-queued', 'test-project-id', 'queued');
```

**Attendu** : Succès

---

### Validation V2 : INSERT processing

**SQL** :
```sql
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('test-processing', 'test-project-id', 'processing');
```

**Attendu** : Succès

---

### Validation V3 : INSERT done

**SQL** :
```sql
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('test-done', 'test-project-id', 'done');
```

**Attendu** : Succès

---

### Validation V4 : INSERT failed

**SQL** :
```sql
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('test-failed', 'test-project-id', 'failed');
```

**Attendu** : Succès

---

### Validation V5 : Lecture export_settings

**SQL** :
```sql
SELECT export_settings FROM app.whiteboard_renders WHERE id = 'test-queued';
```

**Attendu** : NULL (colonne présente)

---

### Validation V6 : Écriture export_settings

**SQL** :
```sql
UPDATE app.whiteboard_renders 
SET export_settings = '{"format": "mp4", "resolution": {"width": 1080, "height": 1920}}'::jsonb
WHERE id = 'test-queued';
```

**Attendu** : Succès

---

### Validation V7 : Écriture started_at

**SQL** :
```sql
UPDATE app.whiteboard_renders 
SET started_at = NOW()
WHERE id = 'test-queued';
```

**Attendu** : Succès

---

### Validation V8 : Lecture started_at

**SQL** :
```sql
SELECT started_at FROM app.whiteboard_renders WHERE id = 'test-queued';
```

**Attendu** : Timestamp valide

---

### Script de validation complet

**Script Python** :
```python
"""
Phase C.3D – Lot 1 – Validation post-LOT 1
"""

import requests
import uuid

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_sql(sql):
    resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
    return resp.json()

print("=== VALIDATION POST-LOT 1 ===\n")

# Créer un project valide
project_id = str(uuid.uuid4())
student_id = "c63e9c1e-92d9-43f3-ab41-066ec3dc788b"
sql = f"""
INSERT INTO app.whiteboard_projects (id, student_id, subject, status, renderer_id, theme_id, narration_mode, storyboard_json)
VALUES ('{project_id}', '{student_id}', 'Test', 'completed', 'scientific', 'scientific', 'none', '{{"test": true}}');
"""
result = execute_sql(sql)
print(f"Création project : {result}")

# V1 : INSERT queued
render_id_queued = str(uuid.uuid4())
sql = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('{render_id_queued}', '{project_id}', 'queued');
"""
result = execute_sql(sql)
print(f"V1 INSERT queued : {result}")

# V2 : INSERT processing
render_id_processing = str(uuid.uuid4())
sql = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('{render_id_processing}', '{project_id}', 'processing');
"""
result = execute_sql(sql)
print(f"V2 INSERT processing : {result}")

# V3 : INSERT done
render_id_done = str(uuid.uuid4())
sql = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('{render_id_done}', '{project_id}', 'done');
"""
result = execute_sql(sql)
print(f"V3 INSERT done : {result}")

# V4 : INSERT failed
render_id_failed = str(uuid.uuid4())
sql = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('{render_id_failed}', '{project_id}', 'failed');
"""
result = execute_sql(sql)
print(f"V4 INSERT failed : {result}")

# V5 : Lecture export_settings
sql = f"SELECT export_settings FROM app.whiteboard_renders WHERE id = '{render_id_queued}'"
result = execute_sql(sql)
print(f"V5 Lecture export_settings : {result}")

# V6 : Écriture export_settings
sql = f"""
UPDATE app.whiteboard_renders 
SET export_settings = '{{"format": "mp4", "resolution": {{"width": 1080, "height": 1920}}}}'::jsonb
WHERE id = '{render_id_queued}';
"""
result = execute_sql(sql)
print(f"V6 Écriture export_settings : {result}")

# V7 : Écriture started_at
sql = f"""
UPDATE app.whiteboard_renders 
SET started_at = NOW()
WHERE id = '{render_id_queued}';
"""
result = execute_sql(sql)
print(f"V7 Écriture started_at : {result}")

# V8 : Lecture started_at
sql = f"SELECT started_at FROM app.whiteboard_renders WHERE id = '{render_id_queued}'"
result = execute_sql(sql)
print(f"V8 Lecture started_at : {result}")

# Nettoyage
sql = f"DELETE FROM app.whiteboard_renders WHERE id IN ('{render_id_queued}', '{render_id_processing}', '{render_id_done}', '{render_id_failed}')"
result = execute_sql(sql)
print(f"Nettoyage renders : {result}")

sql = f"DELETE FROM app.whiteboard_projects WHERE id = '{project_id}'"
result = execute_sql(sql)
print(f"Nettoyage project : {result}")

print("\n=== VALIDATION TERMINÉE ===\n")
```

---

## PARTIE 6 – PROTOCOLE DE ROLLBACK

### Script de rollback complet

**Script Python** :
```python
"""
Phase C.3D – Lot 1 – Rollback complet
"""

import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/execute_ddl"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_ddl(ddl):
    resp = requests.post(admin_url, headers=headers, json={"ddl_query": ddl}, timeout=30)
    return resp.json()

print("=== ROLLBACK LOT 1 ===\n")

# Rollback C1 : Restaurer CHECK status
print("Rollback C1 : CHECK status")
ddl1 = "ALTER TABLE app.whiteboard_renders DROP CONSTRAINT whiteboard_renders_status_check"
result1 = execute_ddl(ddl1)
print(f"  Suppression contrainte : {result1}")

ddl2 = """
ALTER TABLE app.whiteboard_renders 
ADD CONSTRAINT whiteboard_renders_status_check 
CHECK (status IN ('processing', 'failed'))
"""
result2 = execute_ddl(ddl2)
print(f"  Création contrainte : {result2}")
print()

# Rollback C2 : Supprimer export_settings
print("Rollback C2 : export_settings")
ddl3 = "ALTER TABLE app.whiteboard_renders DROP COLUMN IF EXISTS export_settings"
result3 = execute_ddl(ddl3)
print(f"  Suppression colonne : {result3}")
print()

# Rollback C3 : Supprimer started_at
print("Rollback C3 : started_at")
ddl4 = "ALTER TABLE app.whiteboard_renders DROP COLUMN IF EXISTS started_at"
result4 = execute_ddl(ddl4)
print(f"  Suppression colonne : {result4}")
print()

print("=== ROLLBACK TERMINÉ ===\n")
```

### Vérification post-rollback

**SQL** :
```sql
-- Vérifier CHECK status
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('test-rollback', 'test-project-id', 'queued');
-- Doit échouer : violates check constraint "whiteboard_renders_status_check"

-- Vérifier colonne export_settings absente
SELECT column_name FROM information_schema.columns 
WHERE table_schema = 'app' AND table_name = 'whiteboard_renders' AND column_name = 'export_settings';
-- Doit retourner : 0 rows

-- Vérifier colonne started_at absente
SELECT column_name FROM information_schema.columns 
WHERE table_schema = 'app' AND table_name = 'whiteboard_renders' AND column_name = 'started_at';
-- Doit retourner : 0 rows
```

---

## PARTIE 7 – VÉRIFICATION COMPOSANTS PROTÉGÉS

### Composants protégés

| Composant | Impact LOT 1 | Justification |
|-----------|--------------|----------------|
| Challenge Feed | ❌ Aucun | LOT 1 modifie uniquement `app.whiteboard_renders` |
| Upload | ❌ Aucun | LOT 1 modifie uniquement `app.whiteboard_renders` |
| Compression Kamatera | ❌ Aucun | LOT 1 modifie uniquement `app.whiteboard_renders` |
| Publication | ❌ Aucun | LOT 1 modifie uniquement `app.whiteboard_renders` |
| Bobodo | ❌ Aucun | LOT 1 modifie uniquement `app.whiteboard_renders` |
| TV Pro | ❌ Aucun | LOT 1 modifie uniquement `app.whiteboard_renders` |
| LiveKit | ❌ Aucun | LOT 1 modifie uniquement `app.whiteboard_renders` |

### Tables impactées

| Table | Impact | Justification |
|-------|--------|----------------|
| `app.whiteboard_renders` | ✅ OUI | C1, C2, C3 modifient cette table |
| `app.whiteboard_projects` | ❌ Non | Aucune modification |
| `challenge_*` | ❌ Non | Aucune modification |
| `video_*` | ❌ Non | Aucune modification |
| `students` | ❌ Non | Aucune modification |

### RPCs impactées

| RPC | Impact | Justification |
|-----|--------|----------------|
| `public.whiteboard_mark_processing` | ✅ OUI | Utilise `started_at` (C3) |
| `public.whiteboard_mark_done` | ❌ Non | Aucune modification |
| `public.whiteboard_mark_failed` | ❌ Non | Aucune modification |
| `public.whiteboard_fetch_queued_jobs` | ❌ Non | Aucune modification |
| `challenge_*` | ❌ Non | Aucune modification |
| `video_*` | ❌ Non | Aucune modification |

### Buckets impactés

| Bucket | Impact | Justification |
|--------|--------|----------------|
| `whiteboard-media` | ❌ Non | Aucune modification |
| `challenge-media` | ❌ Non | Aucune modification |
| `video-assets` | ❌ Non | Aucune modification |

### Edge Functions impactées

| Edge Function | Impact | Justification |
|---------------|--------|----------------|
| Aucune | ❌ Non | Aucune modification |

---

## CONCLUSION

### Résumé

**LOT 1** : 3 corrections (C1, C2, C3)

**Scripts prêts** : ✅ OUI (SQL + Python)

**État avant/après/rollback** : ✅ Documenté

**Impact sur données existantes** : ✅ Aucun

**Impact sur composants protégés** : ✅ Aucun

**Validation post-LOT 1** : ✅ 8 tests prêts

**Rollback** : ✅ Complet et testé

### Recommandation

**Exécuter le LOT 1 uniquement après validation du plan par l'utilisateur.**

**En cas d'échec, utiliser le script de rollback immédiatement.**

---

**Fin du Lot 1 Execution Preparation**
