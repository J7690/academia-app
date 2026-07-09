import requests
import json
import uuid

supabase_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=" * 80)
print("CRÉATION JOB TEST WHITEBOARD (PHOTOSYNTHÈSE)")
print("=" * 80)

# ÉTAPE 1: Créer un projet whiteboard
project_id = str(uuid.uuid4())
student_id = "00000000-0000-0000-0000-000000000000"  # Placeholder

storyboard_json = json.dumps({
    "title": "Photosynthèse",
    "subject": "Biologie",
    "frames": [
        {
            "id": 1,
            "text": "La photosynthèse est le processus par lequel les plantes convertissent la lumiere en energie",
            "duration": 5
        },
        {
            "id": 2,
            "text": "L'equation: 6CO2 + 6H2O + lumiere -> C6H12O6 + 6O2",
            "duration": 5
        },
        {
            "id": 3,
            "text": "La chlorophylle absorbe la lumiere dans les chloroplastes",
            "duration": 5
        }
    ]
})

sql_create_project = f"""
INSERT INTO app.whiteboard_projects (id, student_id, subject, status, renderer_id, theme_id, narration_mode, storyboard_json)
VALUES ('{project_id}', '{student_id}', 'Biologie', 'draft', 'default', 'light', 'none', $${storyboard_json}$$::jsonb)
RETURNING id;
"""

print(f"\n--- Création projet ---")
print(f"Project ID: {project_id}")

resp = requests.post(supabase_url, headers=headers, json={"p_sql": sql_create_project}, timeout=30)
data = resp.json()

print(f"STATUS: {resp.status_code}")
print(f"BODY: {resp.text}")

if data.get("ok"):
    print("✅ Projet créé")
else:
    print("❌ Erreur création projet")
    exit(1)

# ÉTAPE 2: Créer un render job
render_id = str(uuid.uuid4())

sql_create_render = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('{render_id}', '{project_id}', 'queued')
RETURNING id;
"""

print(f"\n--- Création render job ---")
print(f"Render ID: {render_id}")

resp = requests.post(supabase_url, headers=headers, json={"p_sql": sql_create_render}, timeout=30)
data = resp.json()

print(f"STATUS: {resp.status_code}")
print(f"BODY: {resp.text}")

if data.get("ok"):
    print("✅ Render job créé")
else:
    print("❌ Erreur création render job")
    exit(1)

print(f"\n✅ Job test créé avec succès")
print(f"   Project ID: {project_id}")
print(f"   Render ID: {render_id}")
print(f"   Worker traitera ce job automatiquement")

print("\n" + "=" * 80)
