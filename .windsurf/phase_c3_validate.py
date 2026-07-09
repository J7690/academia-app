"""
Script de validation pour Phase C.3 – Renderer Core Implementation
Insère un Storyboard de test et valide le flux complet
"""

import requests
import json
import time
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

print("=== PHASE C.3 – VALIDATION AUTOMATISÉE ===\n")

# Storyboard de test
storyboard_json = json.dumps({
    "id": "storyboard_001",
    "title": "La photosynthèse",
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
                    "content": "La photosynthèse",
                    "animation": {
                        "type": "fade_in",
                        "duration": 0.5,
                        "delay": 0.0
                    },
                    "metadata": {},
                    "highlight": False,
                    "zoom": False,
                    "handwriting": False
                },
                {
                    "id": "block_002",
                    "type": "paragraph",
                    "content": "La photosynthèse est le processus par lequel les plantes convertissent la lumière en énergie.",
                    "animation": {
                        "type": "fade_in",
                        "duration": 0.5,
                        "delay": 0.5
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
print("1. Insertion du job de test...")
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

result = execute_sql(sql_insert)
print(f"   Job inséré : {job_id}")
print()

# Attendre le traitement du Worker
print("2. Attente du traitement du Worker (60 secondes max)...")
for i in range(60):
    time.sleep(1)
    
    # Vérifier le statut
    sql_check = f"""
    SELECT status, video_url, duration_ms, error_message, started_at, completed_at
    FROM app.whiteboard_renders
    WHERE id = '{job_id}';
    """
    
    result = execute_sql(sql_check)
    
    if result and len(result) > 0:
        status = result[0].get("status")
        print(f"   Statut : {status} ({i+1}s)")
        
        if status == "done":
            print("\n3. Validation réussie !")
            print(f"   video_url : {result[0].get('video_url')}")
            print(f"   duration_ms : {result[0].get('duration_ms')}")
            print(f"   started_at : {result[0].get('started_at')}")
            print(f"   completed_at : {result[0].get('completed_at')}")
            break
        elif status == "failed":
            print("\n3. Validation échouée !")
            print(f"   error_message : {result[0].get('error_message')}")
            break
else:
    print("\n3. Timeout : Le Worker n'a pas traité le job dans les 60 secondes")

print("\n=== FIN VALIDATION ===\n")
