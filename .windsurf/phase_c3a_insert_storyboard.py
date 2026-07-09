"""
Script pour Phase C.3A – Real Pipeline Validation
Insère un Storyboard réel (Photosynthèse) dans whiteboard_renders
"""

import requests
import json
import uuid

# Configuration
admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_sql(sql):
    resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
    return resp.json()

print("=== PHASE C.3A – INSERTION STORYBOARD RÉEL ===\n")
print("Sujet : Photosynthèse\n")

# Storyboard réel - Photosynthèse
storyboard_json = json.dumps({
    "id": "storyboard_photosynthesis",
    "title": "La Photosynthèse",
    "theme": {
        "name": "scientific",
        "background": "#0a192f",
        "text_color": "#ffffff",
        "accent_color": "#69f0ae"
    },
    "audio": {
        "type": "user_recording",
        "script": "La photosynthèse est le processus par lequel les plantes convertissent la lumière en énergie.",
        "timestamps": []
    },
    "metadata": {},
    "scenes": [
        {
            "id": "scene_001",
            "duration_ms": 5000,
            "blocks": [
                {
                    "id": "block_001",
                    "type": "title",
                    "content": "La Photosynthèse",
                    "animation": {
                        "type": "fade_in",
                        "duration": 0.5,
                        "delay": 0.0
                    },
                    "metadata": {},
                    "highlight": False,
                    "zoom": False,
                    "handwriting": False
                }
            ]
        },
        {
            "id": "scene_002",
            "duration_ms": 5000,
            "blocks": [
                {
                    "id": "block_002",
                    "type": "definition",
                    "content": "La photosynthèse est le processus biochimique par lequel les plantes, les algues et certaines bactéries convertissent l'énergie lumineuse en énergie chimique.",
                    "animation": {
                        "type": "fade_in",
                        "duration": 0.5,
                        "delay": 0.0
                    },
                    "metadata": {},
                    "highlight": False,
                    "zoom": False,
                    "handwriting": False
                }
            ]
        },
        {
            "id": "scene_003",
            "duration_ms": 5000,
            "blocks": [
                {
                    "id": "block_003",
                    "type": "paragraph",
                    "content": "Ce processus se déroule principalement dans les chloroplastes des cellules végétales, où la chlorophylle capture l'énergie lumineuse du soleil.",
                    "animation": {
                        "type": "fade_in",
                        "duration": 0.5,
                        "delay": 0.0
                    },
                    "metadata": {},
                    "highlight": False,
                    "zoom": False,
                    "handwriting": False
                }
            ]
        },
        {
            "id": "scene_004",
            "duration_ms": 5000,
            "blocks": [
                {
                    "id": "block_004",
                    "type": "exercise",
                    "content": "Quelle est l'équation simplifiée de la photosynthèse ?",
                    "animation": {
                        "type": "fade_in",
                        "duration": 0.5,
                        "delay": 0.0
                    },
                    "metadata": {},
                    "highlight": False,
                    "zoom": False,
                    "handwriting": False
                }
            ]
        },
        {
            "id": "scene_005",
            "duration_ms": 5000,
            "blocks": [
                {
                    "id": "block_005",
                    "type": "formula",
                    "content": "6CO2 + 6H2O → C6H12O6 + 6O2",
                    "animation": {
                        "type": "fade_in",
                        "duration": 0.5,
                        "delay": 0.0
                    },
                    "metadata": {},
                    "highlight": False,
                    "zoom": False,
                    "handwriting": False
                }
            ]
        },
        {
            "id": "scene_006",
            "duration_ms": 5000,
            "blocks": [
                {
                    "id": "block_006",
                    "type": "correction",
                    "content": "L'équation simplifiée est : 6CO2 + 6H2O → C6H12O6 + 6O2. Le dioxyde de carbone et l'eau sont convertis en glucose et oxygène.",
                    "animation": {
                        "type": "fade_in",
                        "duration": 0.5,
                        "delay": 0.0
                    },
                    "metadata": {},
                    "highlight": False,
                    "zoom": False,
                    "handwriting": False
                }
            ]
        }
    ]
})

# Échapper les guillemets dans le JSON pour SQL
storyboard_json_escaped = storyboard_json.replace("'", "''")

# Insérer le job
job_id = str(uuid.uuid4())
project_id = str(uuid.uuid4())

sql_insert = f"""
INSERT INTO app.whiteboard_renders (
    id,
    project_id,
    status,
    storyboard_json,
    created_at,
    updated_at
) VALUES (
    '{job_id}',
    '{project_id}',
    'queued',
    '{storyboard_json_escaped}'::jsonb,
    NOW(),
    NOW()
);
"""

print("1. Insertion du RenderJob...")
result = execute_sql(sql_insert)
print(f"   Job ID : {job_id}")
print(f"   Project ID : {project_id}")
print(f"   Statut : queued")
print()

# Vérifier l'insertion
sql_check = f"""
SELECT id, status, created_at 
FROM app.whiteboard_renders 
WHERE id = '{job_id}';
"""

result = execute_sql(sql_check)
print("2. Vérification de l'insertion...")
if result and len(result) > 0:
    print(f"   ✅ Job inséré avec succès")
    print(f"   ID : {result[0].get('id')}")
    print(f"   Statut : {result[0].get('status')}")
    print(f"   Créé à : {result[0].get('created_at')}")
else:
    print(f"   ❌ Erreur lors de l'insertion")

print()
print("=== PRÊT POUR VALIDATION ===")
print(f"Job ID : {job_id}")
print("Lancer le worker avec : python whiteboard_render_worker.py")
print("Surveiller avec : python .windsurf/phase_c3a_monitor.py")
print()
